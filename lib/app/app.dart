import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/alarm_sound_ids.dart';
import '../features/alarm/data/alarm_native_android.dart';
import '../features/quiz/data/quiz_repository.dart';
import '../features/quiz/presentation/quiz_providers.dart';
import 'alarm_ring_coordinator.dart';
import 'pending_alarm_launch.dart';
import 'main_tabs_screen.dart';

class WakeNihongoApp extends ConsumerStatefulWidget {
  const WakeNihongoApp({super.key});

  @override
  ConsumerState<WakeNihongoApp> createState() => _WakeNihongoAppState();
}

class _WakeNihongoAppState extends ConsumerState<WakeNihongoApp> {
  final _quizRepository = QuizRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncQuizOnLaunch());
    });
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

  Future<void> _syncQuizOnLaunch() async {
    QuizVersionStatus? status;
    for (var i = 0; i < 2; i++) {
      status = await _quizRepository.checkVersionStatus();
      if (status != null) break;
      if (!mounted) return;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted || status == null || !status.quizVersionDifferent) return;

    final uiContext = AlarmRingCoordinator.navigatorKey.currentContext;
    if (uiContext == null) return;

    final shouldUpdate = await showDialog<bool>(
      context: uiContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('퀴즈 버전 확인'),
        content: const Text('퀴즈 버전이 다릅니다. 갱신하겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니오'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('예'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (shouldUpdate != true) {
      final messenger = ScaffoldMessenger.maybeOf(uiContext);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('기존 퀴즈 데이터를 유지합니다.'),
        ),
      );
      return;
    }

    final result = await _quizRepository.updateQuizFromRemote(status: status);
    if (!mounted || !result.updated) return;

    ref.invalidate(localQuizVersionProvider);
    ref.invalidate(remoteQuizVersionProvider);
    ref.invalidate(quizEntriesProvider);
    ref.invalidate(quizFilteredEntriesProvider);

    await showDialog<void>(
      context: uiContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('알림'),
        content: Text(
          '퀴즈 버전 ${result.previousQuizVersion} → ${result.currentQuizVersion}으로 갱신되었습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
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
      home: const MainTabsScreen(),
    );
  }
}
