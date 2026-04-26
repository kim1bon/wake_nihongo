import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants/alarm_sound_ids.dart';
import '../features/alarm/data/alarm_native_android.dart';
import '../features/alarm/presentation/alarm_ring_screen.dart';
import 'alarm_services.dart';

/// 알람 알림·포그라운드 서비스로 앱이 열리면 네이티브 루프를 멈추고 인앱 반복 + 전체 화면 해제 UI를 띄웁니다.
class AlarmRingCoordinator {
  AlarmRingCoordinator._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static bool _handling = false;

  static Future<void> handleNotificationResponse(NotificationResponse response) async {
    final soundId = _parseSoundId(response.payload);
    await handleAlarmTrigger(soundId: soundId);
  }

  static Future<void> handleAlarmTrigger({
    required String soundId,
  }) async {
    if (_handling) return;
    _handling = true;
    try {
      if (Platform.isAndroid) {
        await AlarmNativeAndroid.stopRinging();
      }
      await AlarmServices.ringtonePlayer.startLoop(soundId);

      final nav = navigatorKey.currentState;
      if (nav == null) return;

      await nav.push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => AlarmRingScreen(
            onDismiss: () async {
              await AlarmServices.ringtonePlayer.stop();
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

  static String _parseSoundId(String? payload) {
    if (payload == null || payload.isEmpty) {
      return AlarmSoundIds.defaultId;
    }
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final s = map['soundId'] as String?;
      if (AlarmSoundIds.isValid(s)) return s!;
    } catch (_) {}
    return AlarmSoundIds.defaultId;
  }
}

