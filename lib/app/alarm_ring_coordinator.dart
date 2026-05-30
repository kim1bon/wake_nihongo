import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants/alarm_sound_ids.dart';
import 'alarm_pending_state_store.dart';
import 'alarm_services.dart';
import '../features/alarm/data/alarm_native_android.dart';
import '../features/alarm/data/alarm_reschedule_session_store.dart';
import '../features/alarm/domain/alarm_payload_kind.dart';
import '../features/alarm/presentation/alarm_ring_screen.dart';

/// Android: 네이티브 포그라운드 서비스가 소리를 담당하고, 앱은 퀴즈 UI만 띄웁니다.
/// iOS: 인앱 반복 재생 + 전체 화면 해제 UI.
class AlarmRingCoordinator {
  AlarmRingCoordinator._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static bool _handling = false;
  static int? _activeAlarmId;

  /// 한 번의 알람 체인에서 최대 울림(5분) 횟수.
  static const int defaultMaxCycles = 5;

  static Future<void> handleNotificationResponse(NotificationResponse response) async {
    final parsed = _parsePayload(response.payload);
    await handleAlarmTrigger(
      soundId: parsed.soundId,
      alarmId: parsed.alarmId,
      isReschedule: parsed.isReschedule,
    );
  }

  static Future<void> handleNotificationResponseWhenNavigatorReady(
    NotificationResponse response, {
    int maxRetry = 10,
    Duration retryInterval = const Duration(milliseconds: 150),
  }) async {
    final parsed = _parsePayload(response.payload);
    await handleAlarmTriggerWhenNavigatorReady(
      soundId: parsed.soundId,
      alarmId: parsed.alarmId,
      isReschedule: parsed.isReschedule,
      maxRetry: maxRetry,
      retryInterval: retryInterval,
    );
  }

  static Future<void> _prepareRescheduleSession({
    required int alarmId,
    required bool isReschedule,
  }) async {
    if (alarmId < 0) return;
    if (isReschedule) return;
    final repo = AlarmServices.alarmRepository;
    if (repo != null) {
      await repo.cancelPendingReschedule(alarmId);
    }
    // Android는 네이티브 [AlarmRingSessionManager]가 세션을 시작합니다.
    if (!Platform.isAndroid) {
      await AlarmRescheduleSessionStore.startSession(
        alarmId: alarmId,
        remainingUses: defaultMaxCycles,
      );
    }
  }

  static Future<void> handleAlarmTrigger({
    required String soundId,
    int alarmId = -1,
    bool isReschedule = false,
  }) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    if (_handling && _activeAlarmId == alarmId) {
      await _ensureAndroidRinging(alarmId: alarmId, soundId: soundId);
      return;
    }

    _handling = true;
    _activeAlarmId = alarmId;
    try {
      await _prepareRescheduleSession(alarmId: alarmId, isReschedule: isReschedule);

      await AlarmPendingStateStore.save(
        alarmId: alarmId,
        soundId: soundId,
        triggeredAtMs: DateTime.now().millisecondsSinceEpoch,
        isReschedule: isReschedule,
      );

      await _ensureAndroidRinging(alarmId: alarmId, soundId: soundId);
      if (!Platform.isAndroid) {
        await AlarmServices.ringtonePlayer.startLoop(soundId);
      }

      await nav.push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => AlarmRingScreen(
            alarmId: alarmId,
            onDismiss: () async {
              if (!Platform.isAndroid) {
                await AlarmServices.ringtonePlayer.stop();
              }
              await AlarmPendingStateStore.clear();
              if (alarmId >= 0) {
                await AlarmRescheduleSessionStore.clearForAlarm(alarmId);
                await AlarmServices.alarmRepository?.refreshScheduleAfterDismiss(alarmId);
              }
              if (Platform.isAndroid) {
                await AlarmNativeAndroid.stopRinging(alarmId: alarmId);
              }
            },
          ),
        ),
      );
    } finally {
      _handling = false;
      if (_activeAlarmId == alarmId) {
        _activeAlarmId = null;
      }
    }
  }

  static Future<void> _ensureAndroidRinging({
    required int alarmId,
    required String soundId,
  }) async {
    if (!Platform.isAndroid || alarmId < 0) return;
    final ringing = await AlarmNativeAndroid.isRinging();
    if (!ringing) {
      await AlarmNativeAndroid.ensureRinging(
        alarmId: alarmId,
        soundId: soundId,
      );
    }
  }

  static Future<void> handleAlarmTriggerWhenNavigatorReady({
    required String soundId,
    int alarmId = -1,
    bool isReschedule = false,
    int maxRetry = 6,
    Duration retryInterval = const Duration(milliseconds: 160),
  }) async {
    for (var i = 0; i <= maxRetry; i++) {
      if (navigatorKey.currentState != null) {
        await handleAlarmTrigger(
          soundId: soundId,
          alarmId: alarmId,
          isReschedule: isReschedule,
        );
        return;
      }
      if (i < maxRetry) {
        await Future<void>.delayed(retryInterval);
      }
    }
  }

  static Future<void> restorePendingAlarmIfAny() async {
    final pending = await AlarmPendingStateStore.read();
    if (pending == null) return;
    await AlarmRingCoordinator.handleAlarmTriggerWhenNavigatorReady(
      soundId: pending.soundId,
      alarmId: pending.alarmId,
      isReschedule: pending.isReschedule,
      maxRetry: 12,
      retryInterval: const Duration(milliseconds: 160),
    );
  }

  static _ParsedAlarmPayload _parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return const _ParsedAlarmPayload(
        soundId: AlarmSoundIds.defaultId,
        alarmId: -1,
        isReschedule: false,
      );
    }
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final s = map['soundId'] as String?;
      final idRaw = map['alarmId'];
      final alarmId = idRaw is int ? idRaw : int.tryParse('$idRaw') ?? -1;
      final kind = alarmPayloadKindFromString(map['kind'] as String?);
      final isReschedule = kind == AlarmPayloadKind.reschedule;
      if (AlarmSoundIds.isValid(s)) {
        return _ParsedAlarmPayload(soundId: s!, alarmId: alarmId, isReschedule: isReschedule);
      }
    } catch (_) {}
    return const _ParsedAlarmPayload(
      soundId: AlarmSoundIds.defaultId,
      alarmId: -1,
      isReschedule: false,
    );
  }
}

class _ParsedAlarmPayload {
  const _ParsedAlarmPayload({
    required this.soundId,
    required this.alarmId,
    required this.isReschedule,
  });

  final String soundId;
  final int alarmId;
  final bool isReschedule;
}
