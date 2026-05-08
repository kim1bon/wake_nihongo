import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/alarm_pending_state_store.dart';
import '../../../app/alarm_services.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/responsive.dart';
import '../data/alarm_native_android.dart';
import '../data/alarm_reschedule_session_store.dart';
import '../domain/alarm.dart';
import 'alarm_providers.dart';
import '../../settings/presentation/alarm_quiz_question_count_notifier.dart';
import '../../settings/presentation/quiz_prompt_mode_notifier.dart';
import '../../quiz/domain/quiz_challenge_question.dart';
import '../../quiz/domain/quiz_generator.dart';
import '../../quiz/presentation/quiz_challenge_body.dart';
import '../../quiz/presentation/quiz_providers.dart';
import 'alarm_quiz_success_screen.dart';

/// 알림(전체 화면 인텐트 포함)으로 앱이 열렸을 때 표시하는 전용 화면. 뒤로 가기로는 닫히지 않습니다.
/// 시트에서 문제를 불러 정답을 맞춘 뒤에만 알람을 끌 수 있습니다. (불러오기 실패·출제 불가 시 건너뛰기 가능)
class AlarmRingScreen extends ConsumerStatefulWidget {
  const AlarmRingScreen({
    super.key,
    required this.onDismiss,
    this.alarmId = -1,
  });

  final Future<void> Function() onDismiss;

  /// 로컬 DB 알람 ID. 없으면 다시 알림을 쓸 수 없습니다.
  final int alarmId;

  @override
  ConsumerState<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends ConsumerState<AlarmRingScreen> {
  final _random = Random();

  bool _loadingQuiz = true;
  String? _loadError;
  QuizChallengeQuestion? _question;
  bool _quizSolved = false;
  int _requiredQuestions = AlarmQuizQuestionCountNotifier.defaultCount;
  int _correctSoFar = 0;
  bool _wrong = false;
  int? _wrongPickIndex;
  int? _correctPickIndex;

  Alarm? _boundAlarm;
  int _rescheduleRemaining = 0;

  bool get _mustSolveQuiz =>
      !_loadingQuiz && _loadError == null && _question != null;

  bool get _canDismiss =>
      _quizSolved || !_mustSolveQuiz;

  String get _bannerPrimaryLine {
    if (_quizSolved || !_mustSolveQuiz) {
      return '알람을 종료할 수 있어요';
    }
    if (_requiredQuestions > 1) {
      return '문제 ${_correctSoFar + 1}/$_requiredQuestions — 모두 맞히면 알람을 끌 수 있어요';
    }
    return '정답을 맞히면 알람을 끌 수 있어요';
  }

  bool get _showRescheduleButton {
    final a = _boundAlarm;
    return widget.alarmId >= 0 &&
        !_quizSolved &&
        a != null &&
        a.rescheduleEnabled &&
        _rescheduleRemaining > 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshRescheduleState();
      await _loadQuiz();
    });
  }

  Future<void> _refreshRescheduleState() async {
    if (widget.alarmId < 0) {
      if (mounted) {
        setState(() {
          _boundAlarm = null;
          _rescheduleRemaining = 0;
        });
      }
      return;
    }
    final alarm = await ref.read(alarmRepositoryProvider).getAlarm(widget.alarmId);
    final left = await AlarmRescheduleSessionStore.readRemaining(widget.alarmId);
    if (!mounted) return;
    setState(() {
      _boundAlarm = alarm;
      _rescheduleRemaining = left ?? 0;
    });
  }

  Future<void> _onReschedulePressed() async {
    final id = widget.alarmId;
    if (id < 0) return;
    final alarm = _boundAlarm ?? await ref.read(alarmRepositoryProvider).getAlarm(id);
    if (alarm == null || !alarm.rescheduleEnabled) return;
    final left = await AlarmRescheduleSessionStore.readRemaining(id);
    if (left == null || left <= 0) return;

    await ref.read(alarmRepositoryProvider).scheduleReschedule(
          alarmId: id,
          soundId: alarm.soundId,
          delayMinutes: alarm.rescheduleDelayMinutes,
        );
    await AlarmRescheduleSessionStore.decrementRemaining(id);

    await AlarmServices.ringtonePlayer.stop();
    await AlarmPendingStateStore.clear();
    if (Platform.isAndroid) {
      await AlarmNativeAndroid.stopRinging();
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _loadingQuiz = true;
      _loadError = null;
      _question = null;
      _quizSolved = false;
      _correctSoFar = 0;
      _wrong = false;
      _wrongPickIndex = null;
      _correctPickIndex = null;
    });
    try {
      final requiredRaw = await ref.read(alarmQuizQuestionCountProvider.future);
      if (!mounted) return;
      _requiredQuestions = requiredRaw.clamp(
        AlarmQuizQuestionCountNotifier.minCount,
        AlarmQuizQuestionCountNotifier.maxCount,
      );
      final filtered = await ref.read(quizFilteredEntriesProvider.future);
      final mode = await ref.read(quizPromptModeProvider.future);
      if (!mounted) return;
      final q = QuizGenerator.generate(filtered, random: _random, mode: mode);
      setState(() {
        _loadingQuiz = false;
        _question = q;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingQuiz = false;
        _loadError = '$e';
      });
    }
  }

  Future<void> _onCorrectAnswer() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _correctSoFar++;
      _correctPickIndex = null;
      if (_correctSoFar >= _requiredQuestions) {
        _quizSolved = true;
      }
    });
    if (!_quizSolved) {
      await _drawNextQuestion();
    }
  }

  Future<void> _drawNextQuestion() async {
    try {
      final filtered = await ref.read(quizFilteredEntriesProvider.future);
      final mode = await ref.read(quizPromptModeProvider.future);
      if (!mounted) return;
      final q = QuizGenerator.generate(filtered, random: _random, mode: mode);
      if (!mounted) return;
      setState(() {
        _question = q;
        _wrong = false;
        _wrongPickIndex = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _question = null;
      });
    }
  }

  Future<void> _onDismissPressed() async {
    await widget.onDismiss();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 현재 퀴즈 카테고리에 맞는 배경 이미지 asset 경로를 반환합니다.
  /// - "기초 1", "기초 2", "일상대화": 주택가 거리 배경
  /// - "쇼핑": 쇼핑 거리 배경
  /// - "식당": 이자카야/식당 골목 배경
  /// - 그 외: 기본적으로 주택가 거리 배경
  String _resolveBackgroundAsset() {
    final q = _question;
    final category = q?.category.trim() ?? '';
    switch (category) {
      case '기초 1':
      case '기초 2':
      case '일상대화':
        return 'assets/images/Backgrounds/Tx_bg_HouseStreet.png';
      case '쇼핑':
        return 'assets/images/Backgrounds/Tx_bg_ShoppingStreet.png';
      case '식당':
        return 'assets/images/Backgrounds/Tx_bg_IzakayaStreet.png';
      default:
        return 'assets/images/Backgrounds/Tx_bg_HouseStreet.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_quizSolved &&
        _question != null &&
        !_loadingQuiz &&
        _loadError == null) {
      return PopScope(
        canPop: false,
        child: AlarmQuizSuccessScreen(
          onStopAlarm: () {
            unawaited(_onDismissPressed());
          },
          backgroundAssetPath: _resolveBackgroundAsset(),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                _resolveBackgroundAsset(),
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: context.wnColors.alarmRingScrim,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.w(20),
                  context.h(12),
                  context.w(20),
                  context.h(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.w(14),
                        vertical: context.h(10),
                      ),
                      decoration: BoxDecoration(
                        color: context.wnColors.alarmBannerFill,
                        borderRadius: BorderRadius.circular(context.r(16)),
                        border: Border.all(
                          color: context.wnColors.alarmBannerBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.alarm,
                            size: context.r(24),
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          SizedBox(width: context.w(8)),
                          Text(
                            _bannerPrimaryLine,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: context.h(14)),
                    Expanded(child: _buildQuizSection(theme)),
                    SizedBox(height: context.h(12)),
                    if (_loadError != null) ...[
                      TextButton(
                        onPressed: () {
                          ref.invalidate(quizEntriesProvider);
                          _loadQuiz();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('문제 다시 불러오기'),
                      ),
                      SizedBox(height: context.h(8)),
                    ],
                    if (_showRescheduleButton) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                          padding: EdgeInsets.symmetric(vertical: context.h(16)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.r(14)),
                          ),
                        ),
                        onPressed: _onReschedulePressed,
                        child: Text(
                          '다시 알림 (${_boundAlarm!.rescheduleDelayMinutes}분 후 · 남음 $_rescheduleRemaining회)',
                        ),
                      ),
                      SizedBox(height: context.h(10)),
                    ],
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.beigeSoft,
                        foregroundColor: AppPalette.navy,
                        disabledBackgroundColor:
                            AppPalette.beigeSoft.withValues(alpha: 0.55),
                        disabledForegroundColor:
                            AppPalette.navy.withValues(alpha: 0.45),
                        padding: EdgeInsets.symmetric(vertical: context.h(18)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.r(14)),
                        ),
                        side: BorderSide(
                          color: context.wnColors.alarmPrimaryButtonBorder,
                        ),
                      ),
                      onPressed: _canDismiss ? _onDismissPressed : null,
                      child: Text(
                        _canDismiss ? '알람 끄기' : '정답 후 알람 끄기',
                      ),
                    ),
                    if (!_canDismiss && _mustSolveQuiz)
                      Padding(
                        padding: EdgeInsets.only(top: context.h(8)),
                        child: Text(
                          _requiredQuestions > 1
                              ? '$_requiredQuestions개 모두 맞히면 버튼이 활성화됩니다.'
                              : '정답을 선택하면 버튼이 활성화됩니다.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.86),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizSection(ThemeData theme) {
    if (_loadingQuiz) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text(
              '문제를 불러오는 중…',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '문제를 불러오지 못했습니다.\n$_loadError',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '네트워크 상태를 확인하거나, 구글 시트가 링크 공개·웹 게시되어 있는지 확인해 주세요.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      );
    }

    final q = _question;
    if (q == null) {
      return Center(
        child: Text(
          '지금 조건으로 출제할 수 있는 문제가 없습니다.\n알람만 종료할 수 있습니다.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return QuizChallengeBody(
      question: q,
      useAlarmStyleLayout: true,
      thumbnailAssetPath: 'assets/images/Tx_Thumbnail.png',
      feedbackWrong: _wrong,
      wrongPickIndex: _wrongPickIndex,
      correctHighlightIndex: _correctPickIndex,
      onPickIndex: (i) {
        if (i == q.correctChoiceIndex) {
          setState(() {
            _wrong = false;
            _wrongPickIndex = null;
            _correctPickIndex = q.correctChoiceIndex;
          });
          unawaited(_onCorrectAnswer());
        } else {
          setState(() {
            _wrong = true;
            _wrongPickIndex = i;
          });
        }
      },
    );
  }
}
