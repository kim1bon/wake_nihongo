import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/alarm_sound_ids.dart';
import '../core/theme/theme.dart';
import '../core/ui/responsive.dart';
import '../features/alarm/data/alarm_native_android.dart';
import '../features/alarm/presentation/alarm_providers.dart';
import '../features/auth/data/firebase_auth_service.dart';
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
  final _authService = FirebaseAuthService(FirebaseAuth.instance);
  Timer? _iosForegroundAlarmTimer;
  final Map<String, DateTime> _iosForegroundFiredAt = <String, DateTime>{};
  final Map<String, DateTime> _androidForegroundFiredAt = <String, DateTime>{};
  bool _profilePromptShown = false;

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
      unawaited(_runStartupSequence());
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

  Future<void> _runStartupSequence() async {
    // 1) 성별/연령대 팝업
    await _ensureProfileOnFirstLaunch();
    if (!mounted) return;

    // 2) 알람 권한 팝업
    await ref.read(alarmRepositoryProvider).ensureNotificationPermissions();
    if (!mounted) return;

    // 3) 구글 시트 갱신 팝업
    await _syncQuizOnLaunch();
    if (!mounted) return;

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
  }

  Future<void> _ensureProfileOnFirstLaunch() async {
    if (!mounted || _profilePromptShown) return;
    final shouldShow = await _shouldShowProfilePrompt();
    if (!mounted || !shouldShow) return;
    _profilePromptShown = true;
    final navContext = await _waitForNavigatorContext();
    if (!mounted || navContext == null) {
      _profilePromptShown = false;
      return;
    }

    final input = await showModalBottomSheet<_UserProfileInput>(
      context: navContext,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        String? selectedGender;
        String? selectedAgeBracket;
        const ageOptions = <_AgeChip>[
          _AgeChip(label: '18세 미만', value: 'under18'),
          _AgeChip(label: '18~24세', value: '18_24'),
          _AgeChip(label: '25~29세', value: '25_29'),
          _AgeChip(label: '30~34세', value: '30_34'),
          _AgeChip(label: '35~39세', value: '35_39'),
          _AgeChip(label: '40세 이상', value: '40_plus'),
        ];
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSubmit =
                selectedGender != null && selectedAgeBracket != null;
            final theme = Theme.of(context);
            final screenWidth = MediaQuery.of(context).size.width;
            final compact = screenWidth <= 420;
            return Padding(
              padding: EdgeInsets.only(
                left: compact ? context.w(12) : context.w(20),
                right: compact ? context.w(12) : context.w(20),
                top: compact ? context.h(10) : context.h(18),
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    (compact ? context.h(12) : context.h(20)),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height * (compact ? 0.84 : 0.88),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Container(
                    width: compact ? context.r(38) : context.r(46),
                    height: compact ? context.r(38) : context.r(46),
                    decoration: BoxDecoration(
                      color: AppPalette.green.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(context.r(14)),
                    ),
                    child: Icon(
                      Icons.badge_outlined,
                      color: AppPalette.green,
                      size: compact ? context.r(20) : context.r(24),
                    ),
                  ),
                  SizedBox(height: compact ? context.h(8) : context.h(12)),
                  Text(
                    '기본 정보 설정',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppPalette.navy,
                      fontSize: compact ? context.sp(20) : null,
                    ),
                  ),
                  SizedBox(height: context.h(6)),
                  Text(
                    '통계 분석을 위해 성별과 연령대를 선택해 주세요.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppPalette.navy.withValues(alpha: 0.75),
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: compact ? context.h(6) : context.h(8)),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      context.w(10),
                      context.h(8),
                      context.w(10),
                      context.h(8),
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(context.r(10)),
                      border: Border.all(
                        color: AppPalette.green.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: compact ? context.r(14) : context.r(16),
                          color: AppPalette.navy.withValues(alpha: 0.8),
                        ),
                        SizedBox(width: context.w(8)),
                        Expanded(
                          child: Text(
                            '수집한 정보는 더 효율적인 학습 내용 제공을 위한 통계 목적으로 사용됩니다.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppPalette.navy.withValues(alpha: 0.78),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? context.h(10) : context.h(14)),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.fromLTRB(
                              compact ? context.w(10) : context.w(14),
                              compact ? context.h(8) : context.h(12),
                              compact ? context.w(10) : context.w(14),
                              compact ? context.h(4) : context.h(8),
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.beigeContainer,
                              borderRadius: BorderRadius.circular(context.r(14)),
                              border: Border.all(
                                color: AppPalette.green.withValues(alpha: 0.30),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '성별',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: AppPalette.navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                RadioListTile<String>(
                                  value: 'male',
                                  groupValue: selectedGender,
                                  onChanged: (v) => setDialogState(() => selectedGender = v),
                                  title: Text('남', style: theme.textTheme.bodyMedium),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  visualDensity: const VisualDensity(vertical: -2),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  activeColor: AppPalette.green,
                                ),
                                RadioListTile<String>(
                                  value: 'female',
                                  groupValue: selectedGender,
                                  onChanged: (v) => setDialogState(() => selectedGender = v),
                                  title: Text('녀', style: theme.textTheme.bodyMedium),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  visualDensity: const VisualDensity(vertical: -2),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  activeColor: AppPalette.green,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: compact ? context.h(8) : context.h(10)),
                          Container(
                            padding: EdgeInsets.fromLTRB(
                              compact ? context.w(10) : context.w(14),
                              compact ? context.h(8) : context.h(12),
                              compact ? context.w(10) : context.w(14),
                              compact ? context.h(4) : context.h(8),
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.beigeContainer,
                              borderRadius: BorderRadius.circular(context.r(14)),
                              border: Border.all(
                                color: AppPalette.green.withValues(alpha: 0.30),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '연령대',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: AppPalette.navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                ...ageOptions.map(
                                  (item) => RadioListTile<String>(
                                    value: item.value,
                                    groupValue: selectedAgeBracket,
                                    onChanged: (v) =>
                                        setDialogState(() => selectedAgeBracket = v),
                                    title: Text(item.label, style: theme.textTheme.bodyMedium),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    visualDensity: const VisualDensity(vertical: -2),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    activeColor: AppPalette.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? context.h(8) : context.h(12)),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppPalette.green.withValues(alpha: 0.35),
                      padding: EdgeInsets.symmetric(
                        vertical: compact ? context.h(12) : context.h(14),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.r(12)),
                      ),
                    ),
                    onPressed: canSubmit
                        ? () {
                            Navigator.of(sheetContext).pop(
                              _UserProfileInput(
                                gender: selectedGender!,
                                ageBracket: selectedAgeBracket!,
                              ),
                            );
                          }
                        : null,
                    child: const Text('확인'),
                  ),
                ],
              ),
              ),
            );
          },
        );
      },
    );
    if (!mounted || input == null) return;

    try {
      await _authService.ensureSignedInAnonymously();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _saveUserProfileAndUpdateTotals(
        uid: user.uid,
        gender: input.gender,
        ageBracket: input.ageBracket,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(navContext)?.showSnackBar(
        const SnackBar(content: Text('기본 정보 저장에 실패했습니다. 다시 시도해 주세요.')),
      );
      _profilePromptShown = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_ensureProfileOnFirstLaunch());
      });
    }
  }

  Future<BuildContext?> _waitForNavigatorContext() async {
    for (var i = 0; i < 30; i++) {
      final navContext = AlarmRingCoordinator.navigatorKey.currentContext;
      if (navContext != null) return navContext;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  Future<bool> _shouldShowProfilePrompt() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;

    final snapshot =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!snapshot.exists) return true;

    final data = snapshot.data();
    final gender = (data?['gender'] as String?)?.trim() ?? '';
    final ageBracket = (data?['ageBracket'] as String?)?.trim() ?? '';
    return gender.isEmpty || ageBracket.isEmpty;
  }

  Future<void> _saveUserProfileAndUpdateTotals({
    required String uid,
    required String gender,
    required String ageBracket,
  }) async {
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(uid);
    final totalRef = db.collection('user_total').doc('global');

    await db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final existed = userSnap.exists;
      final prev = userSnap.data();
      final prevGender = prev?['gender'] as String?;
      final prevAgeBracket = prev?['ageBracket'] as String?;

      final userPayload = <String, dynamic>{
        'gender': gender,
        'ageBracket': ageBracket,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!existed) {
        userPayload['createdAt'] = FieldValue.serverTimestamp();
      }
      tx.set(userRef, userPayload, SetOptions(merge: true));

      final totalsUpdate = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!existed) {
        totalsUpdate['totalUsers'] = FieldValue.increment(1);
      }

      if (!existed || prevGender != gender) {
        if (prevGender == 'male' || prevGender == 'female') {
          totalsUpdate[prevGender!] = FieldValue.increment(-1);
        }
        totalsUpdate[gender] = FieldValue.increment(1);
      }

      if (!existed || prevAgeBracket != ageBracket) {
        final prevAgeField = _ageCountField(prevAgeBracket);
        if (prevAgeField != null) {
          totalsUpdate[prevAgeField] = FieldValue.increment(-1);
        }
        final nextAgeField = _ageCountField(ageBracket);
        if (nextAgeField != null) {
          totalsUpdate[nextAgeField] = FieldValue.increment(1);
        }
      }

      tx.set(totalRef, totalsUpdate, SetOptions(merge: true));
    });
  }

  String? _ageCountField(String? ageBracket) {
    return switch (ageBracket) {
      'under18' => 'age_under18',
      '18_24' => 'age_18_24',
      '25_29' => 'age_25_29',
      '30_34' => 'age_30_34',
      '35_39' => 'age_35_39',
      '40_plus' => 'age_40_plus',
      _ => null,
    };
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

class _UserProfileInput {
  const _UserProfileInput({
    required this.gender,
    required this.ageBracket,
  });

  final String gender;
  final String ageBracket;
}

class _AgeChip {
  const _AgeChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
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
