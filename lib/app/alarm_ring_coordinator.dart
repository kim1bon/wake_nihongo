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

/// 알람 알림·포그라운드 서비스로 앱이 열리면 네이티브 루프를 멈추고 인앱 반복 + 전체 화면 해제 UI를 띄웁니다.
class AlarmRingCoordinator {
  AlarmRingCoordinator._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static bool _handling = false;

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
    if (repo == null) return;
    await repo.cancelPendingReschedule(alarmId);
    final alarm = await repo.getAlarm(alarmId);
    if (alarm == null || !alarm.rescheduleEnabled) {
      await AlarmRescheduleSessionStore.clearForAlarm(alarmId);
      return;
    }
    await AlarmRescheduleSessionStore.startSession(
      alarmId: alarmId,
      remainingUses: alarm.rescheduleMaxCount,
    );
  }

  static Future<void> handleAlarmTrigger({
    required String soundId,
    int alarmId = -1,
    bool isReschedule = false,
  }) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    if (_handling) return;
    _handling = true;
    try {
      await _prepareRescheduleSession(alarmId: alarmId, isReschedule: isReschedule);
      if (Platform.isAndroid) {
        await AlarmNativeAndroid.stopRinging();
      }
      await AlarmPendingStateStore.save(
        alarmId: alarmId,
        soundId: soundId,
        triggeredAtMs: DateTime.now().millisecondsSinceEpoch,
        isReschedule: isReschedule,
      );
      await AlarmServices.ringtonePlayer.startLoop(soundId);

      await nav.push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => AlarmRingScreen(
            alarmId: alarmId,
            onDismiss: () async {
              await AlarmServices.ringtonePlayer.stop();
              await AlarmPendingStateStore.clear();
              if (alarmId >= 0) {
                await AlarmRescheduleSessionStore.clearForAlarm(alarmId);
                await AlarmServices.alarmRepository?.refreshScheduleAfterDismiss(alarmId);
              }
              if (Platform.isAndroid) {
                await AlarmNativeAndroid.stopRinging();
              }
            },
          ),
        ),
      );
    } finally {
      _handling = false;
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
