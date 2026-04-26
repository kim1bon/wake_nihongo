import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/alarm_sound_ids.dart';
import '../features/alarm/data/alarm_native_android.dart';
import '../features/alarm/presentation/alarm_providers.dart';
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

class _WakeNihongoAppState extends ConsumerState<WakeNihongoApp>
    with WidgetsBindingObserver {
  final _quizRepository = QuizRepository();
  Timer? _iosForegroundAlarmTimer;
  final Map<String, DateTime> _iosForegroundFiredAt = <String, DateTime>{};
  final Map<String, DateTime> _androidForegroundFiredAt = <String, DateTime>{};

  String _buildAndroidFireKey({
    required String soundId,
    required int alarmId,
    required DateTime now,
  }) {
    final minutePrefix =
        '${now.year}-${now.month}-${now.day}-${now.hour}-${now.minute}';
    return '$minutePrefix-$alarmId-$soundId';
  }

  Future<void> _handleAndroidAlarmLaunchPayload(Map<String, dynamic> map) async {
    final sid = map['soundId'] as String?;
    if (!AlarmSoundIds.isValid(sid)) return;
    final aid = map['alarmId'];
    final alarmId = aid is int ? aid : int.tryParse('$aid') ?? -1;
    final now = DateTime.now();
    final fireKey = _buildAndroidFireKey(
      soundId: sid!,
      alarmId: alarmId,
      now: now,
    );
    if (_androidForegroundFiredAt.containsKey(fireKey)) return;
    _androidForegroundFiredAt[fireKey] = now;

    await AlarmRingCoordinator.handleAlarmTriggerWhenNavigatorReady(
      soundId: sid,
      maxRetry: 8,
      retryInterval: const Duration(milliseconds: 140),
    );

    final cutoff = now.subtract(const Duration(hours: 2));
    _androidForegroundFiredAt.removeWhere(
      (_, firedAt) => firedAt.isBefore(cutoff),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid) {
      unawaited(
        AlarmNativeAndroid.bindAlarmLaunchIntentListener((payload) async {
          await _handleAndroidAlarmLaunchPayload(payload);
        }),
      );
    }
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
          unawaited(_handleAndroidAlarmLaunchPayload(map));
        }
      }
    });
    if (Platform.isIOS) {
      _startIosForegroundAlarmWatcher();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopIosForegroundAlarmWatcher();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!Platform.isIOS) return;
    if (state == AppLifecycleState.resumed) {
      _startIosForegroundAlarmWatcher();
    } else {
      _stopIosForegroundAlarmWatcher();
    }
  }

  void _startIosForegroundAlarmWatcher() {
    _iosForegroundAlarmTimer ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_checkAndFireIosForegroundAlarms()),
    );
    unawaited(_checkAndFireIosForegroundAlarms());
  }

  void _stopIosForegroundAlarmWatcher() {
    _iosForegroundAlarmTimer?.cancel();
    _iosForegroundAlarmTimer = null;
  }

  Future<void> _checkAndFireIosForegroundAlarms() async {
    if (!mounted || !Platform.isIOS) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final alarms = await ref.read(alarmRepositoryProvider).getAlarms();
    if (!mounted) return;

    final now = DateTime.now();
    final minuteKeyPrefix =
        '${now.year}-${now.month}-${now.day}-${now.hour}-${now.minute}';

    for (final alarm in alarms) {
      if (!alarm.enabled) continue;
      if (!alarm.weekdays.contains(now.weekday)) continue;
      if (alarm.hour != now.hour || alarm.minute != now.minute) continue;

      final fireKey = '$minuteKeyPrefix-${alarm.id}';
      if (_iosForegroundFiredAt.containsKey(fireKey)) continue;

      _iosForegroundFiredAt[fireKey] = now;
      unawaited(AlarmRingCoordinator.handleAlarmTrigger(soundId: alarm.soundId));
    }

    final cutoff = now.subtract(const Duration(hours: 2));
    _iosForegroundFiredAt.removeWhere((_, firedAt) => firedAt.isBefore(cutoff));
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
