import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/constants/alarm_sound_ids.dart';
import '../features/alarm/data/alarm_native_android.dart';
import 'alarm_ring_coordinator.dart';
import 'pending_alarm_launch.dart';
import '../features/alarm/presentation/alarm_list_screen.dart';

class WakeNihongoApp extends StatefulWidget {
  const WakeNihongoApp({super.key});

  @override
  State<WakeNihongoApp> createState() => _WakeNihongoAppState();
}

class _WakeNihongoAppState extends State<WakeNihongoApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pending = PendingAlarmLaunch.notificationResponse;
      PendingAlarmLaunch.notificationResponse = null;
      if (pending != null) {
        unawaited(AlarmRingCoordinator.handleNotificationResponse(pending));
      }
      if (Platform.isAndroid) {
        final map = await AlarmNativeAndroid.takePendingAlarmLaunch();
        if (map != null) {
          final sid = map['soundId'] as String?;
          if (AlarmSoundIds.isValid(sid)) {
            final aid = map['alarmId'];
            unawaited(
              AlarmRingCoordinator.handleNotificationResponse(
                NotificationResponse(
                  notificationResponseType: NotificationResponseType.selectedNotification,
                  payload: jsonEncode({
                    'soundId': sid,
                    'alarmId': aid is int ? aid : int.tryParse('$aid') ?? -1,
                  }),
                ),
              ),
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AlarmRingCoordinator.navigatorKey,
      title: 'WakeNihongo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      home: const AlarmListScreen(),
    );
  }
}
