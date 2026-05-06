import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/alarm_sound_ids.dart';
import '../core/theme/theme.dart';
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
      alarmId: alarmId,
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
        unawaited(
          AlarmRingCoordinator.handleNotificationResponseWhenNavigatorReady(
            pending,
          ),
        );
      }
      unawaited(AlarmRingCoordinator.restorePendingAlarmIfAny());
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
      const Duration(seconds: 1),
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
      unawaited(
        AlarmRingCoordinator.handleAlarmTrigger(
          soundId: alarm.soundId,
          alarmId: alarm.id,
        ),
      );
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
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          backgroundColor: AppPalette.beigeSoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: AppPalette.green.withValues(alpha: 0.28),
            ),
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          contentPadding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          actionsPadding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppPalette.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.quiz_outlined,
                  size: 20,
                  color: AppPalette.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '퀴즈 버전 확인',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.navy,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: AppPalette.beigeContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppPalette.green.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                '퀴즈 버전이 다릅니다. 갱신하겠습니까?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: AppPalette.navy,
                ),
              ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppPalette.navy.withValues(alpha: 0.9),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: AppPalette.navy.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('아니오'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('예'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
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

    final progressNotifier = ValueNotifier<QuizDownloadProgress?>(null);
    // navigatorKey.currentContext는 Navigator 조상에 Overlay가 없어 maybeOf가 null이 될 수 있음.
    final overlayState = AlarmRingCoordinator.navigatorKey.currentState?.overlay;
    OverlayEntry? overlayEntry;
    if (overlayState != null) {
      overlayEntry = OverlayEntry(
        builder: (context) => _QuizDownloadOverlay(
          progressListenable: progressNotifier,
        ),
      );
      overlayState.insert(overlayEntry);
    }

    QuizSyncResult result;
    try {
      result = await _quizRepository.updateQuizFromRemote(
        status: status,
        onDownloadProgress: (p) {
          progressNotifier.value = p;
        },
      );
    } finally {
      overlayEntry?.remove();
      progressNotifier.dispose();
    }

    if (!mounted) return;
    if (!result.updated) return;

    ref.invalidate(localQuizVersionProvider);
    ref.invalidate(remoteQuizVersionProvider);
    ref.invalidate(quizEntriesProvider);
    ref.invalidate(quizFilteredEntriesProvider);

    await showDialog<void>(
      context: uiContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          backgroundColor: AppPalette.beigeSoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: AppPalette.green.withValues(alpha: 0.28),
            ),
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          contentPadding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          actionsPadding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppPalette.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: AppPalette.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '알림',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.navy,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: AppPalette.beigeContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppPalette.green.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                '퀴즈 버전 ${result.previousQuizVersion} → '
                '${result.currentQuizVersion}으로 갱신되었습니다.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: AppPalette.navy,
                ),
              ),
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('확인'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AlarmRingCoordinator.navigatorKey,
      title: '일어나',
      theme: AppTheme.light(),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      home: const MainTabsScreen(),
    );
  }
}

/// 퀴즈 동기화 중 전체 화면 반투명 + 시트 진행(n/N) + 불확정 프로그래스바.
class _QuizDownloadOverlay extends StatelessWidget {
  const _QuizDownloadOverlay({
    required this.progressListenable,
  });

  final ValueListenable<QuizDownloadProgress?> progressListenable;

  static String _titleFor(QuizDownloadProgress? p) {
    if (p == null) return '퀴즈를 준비하는 중…';
    return switch (p.phase) {
      QuizDownloadPhase.preparingIndex => '퀴즈 목록을 불러오는 중',
      QuizDownloadPhase.downloadingSheet => '시트 다운로드 중',
      QuizDownloadPhase.legacyCsv => '퀴즈 파일 다운로드 중',
    };
  }

  static String _countLineFor(QuizDownloadProgress? p) {
    if (p == null) return '';
    return switch (p.phase) {
      QuizDownloadPhase.preparingIndex => '',
      QuizDownloadPhase.downloadingSheet =>
        p.total > 0 ? '${p.current} / ${p.total}' : '',
      QuizDownloadPhase.legacyCsv => '1 / 1',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: ValueListenableBuilder<QuizDownloadProgress?>(
                valueListenable: progressListenable,
                builder: (context, progress, _) {
                  final countLine = _countLineFor(progress);
                  final label = progress?.contentLabel;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _titleFor(progress),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (countLine.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          countLine,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          minHeight: 6,
                        ),
                      ),
                      if (label != null && label.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
