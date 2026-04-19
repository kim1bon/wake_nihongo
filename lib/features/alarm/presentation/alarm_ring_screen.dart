import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quiz/domain/jp_to_kor_question.dart';
import '../../quiz/domain/quiz_generator.dart';
import '../../quiz/presentation/quiz_challenge_body.dart';
import '../../quiz/presentation/quiz_providers.dart';
import '../../settings/presentation/quiz_alarm_types_notifier.dart';

/// 알림(전체 화면 인텐트 포함)으로 앱이 열렸을 때 표시하는 전용 화면. 뒤로 가기로는 닫히지 않습니다.
/// 시트에서 문제를 불러 정답을 맞춘 뒤에만 알람을 끌 수 있습니다. (불러오기 실패·출제 불가 시 건너뛰기 가능)
class AlarmRingScreen extends ConsumerStatefulWidget {
  const AlarmRingScreen({
    super.key,
    required this.onDismiss,
  });

  final Future<void> Function() onDismiss;

  @override
  ConsumerState<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends ConsumerState<AlarmRingScreen> {
  final _random = Random();

  bool _loadingQuiz = true;
  String? _loadError;
  JpToKorQuestion? _question;
  bool _quizSolved = false;
  bool _wrong = false;
  int? _wrongPickIndex;
  int? _correctPickIndex;

  bool get _mustSolveQuiz =>
      !_loadingQuiz && _loadError == null && _question != null;

  bool get _canDismiss =>
      _quizSolved || !_mustSolveQuiz;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuiz());
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _loadingQuiz = true;
      _loadError = null;
      _question = null;
      _quizSolved = false;
      _wrong = false;
      _wrongPickIndex = null;
      _correctPickIndex = null;
    });
    try {
      final entries = await ref.read(quizEntriesProvider.future);
      final enabledTypes = await ref.read(quizAlarmEnabledTypesProvider.future);
      if (!mounted) return;
      final filtered = QuizGenerator.filterByEnabledTypes(entries, enabledTypes);
      final q = QuizGenerator.generate(filtered, random: _random);
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

  Future<void> _onDismissPressed() async {
    await widget.onDismiss();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Icon(
                  Icons.alarm,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  '알람',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _mustSolveQuiz && !_quizSolved
                      ? '일본어의 뜻을 고른 뒤 알람을 끌 수 있습니다.'
                      : '알람음은 끄기 전까지 반복됩니다.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildQuizSection(theme)),
                const SizedBox(height: 12),
                if (_loadError != null) ...[
                  TextButton(
                    onPressed: () {
                      ref.invalidate(quizEntriesProvider);
                      _loadQuiz();
                    },
                    child: const Text('문제 다시 불러오기'),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  onPressed: _canDismiss ? _onDismissPressed : null,
                  child: Text(
                    _canDismiss ? '알람 끄기' : '정답 후 알람 끄기',
                  ),
                ),
                if (!_canDismiss && _mustSolveQuiz)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '정답을 선택하면 버튼이 활성화됩니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizSection(ThemeData theme) {
    if (_loadingQuiz) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('문제를 불러오는 중…'),
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

    if (_quizSolved) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '정답입니다!',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: QuizChallengeBody(
        question: q,
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
            unawaited(
              Future<void>.delayed(const Duration(milliseconds: 650), () {
                if (!mounted) return;
                setState(() {
                  _quizSolved = true;
                  _correctPickIndex = null;
                });
              }),
            );
          } else {
            setState(() {
              _wrong = true;
              _wrongPickIndex = i;
            });
          }
        },
      ),
    );
  }
}
