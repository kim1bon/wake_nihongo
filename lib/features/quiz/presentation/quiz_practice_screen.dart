import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/presentation/quiz_prompt_mode_notifier.dart';
import '../domain/quiz_challenge_question.dart';
import '../domain/quiz_entry.dart';
import '../domain/quiz_generator.dart';
import '../domain/quiz_prompt_mode.dart';
import 'quiz_challenge_body.dart';
import 'quiz_providers.dart';

/// 시트 데이터로 무작위 문제 연습 (알람 없이 종료 가능).
class QuizPracticeScreen extends ConsumerWidget {
  const QuizPracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(quizFilteredEntriesProvider);
    final asyncMode = ref.watch(quizPromptModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('일본어 퀴즈')),
      body: asyncEntries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '문제를 불러오지 못했습니다.\n$e',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(quizEntriesProvider),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        data: (entries) => asyncMode.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('설정을 불러오지 못했습니다.\n$e')),
          data: (mode) => _QuizPracticeLoaded(entries: entries, mode: mode),
        ),
      ),
    );
  }
}

class _QuizPracticeLoaded extends StatefulWidget {
  const _QuizPracticeLoaded({
    required this.entries,
    required this.mode,
  });

  final List<QuizEntry> entries;
  final QuizPromptMode mode;

  @override
  State<_QuizPracticeLoaded> createState() => _QuizPracticeLoadedState();
}

class _QuizPracticeLoadedState extends State<_QuizPracticeLoaded> {
  final _random = Random();
  QuizChallengeQuestion? _question;
  bool _wrong = false;
  int? _wrongPickIndex;
  int? _correctPickIndex;

  @override
  void initState() {
    super.initState();
    _question = QuizGenerator.generate(
      widget.entries,
      random: _random,
      mode: widget.mode,
    );
  }

  @override
  void didUpdateWidget(covariant _QuizPracticeLoaded oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode || oldWidget.entries != widget.entries) {
      _rollQuestion();
    }
  }

  void _rollQuestion() {
    setState(() {
      _wrong = false;
      _wrongPickIndex = null;
      _correctPickIndex = null;
      _question = QuizGenerator.generate(
        widget.entries,
        random: _random,
        mode: widget.mode,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _question;
    if (q == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(
                child: Center(
                  child: Text(
                    '출제 가능한 문제가 없습니다.\n'
                    '같은 카테고리·같은 타입 안에서 서로 다른 보기가 '
                    '충분해야 합니다.\n'
                    '(한→일: 서로 다른 일본어, 일→한: 서로 다른 한국어)\n'
                    'sentence는 2지, 그 외는 4지입니다.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _rollQuestion,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: QuizChallengeBody(
                  question: q,
                  forceSingleColumnChoices: true,
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('정답입니다.')),
                      );
                    } else {
                      setState(() {
                        _wrong = true;
                        _wrongPickIndex = i;
                        _correctPickIndex = null;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _rollQuestion,
              icon: const Icon(Icons.refresh),
              label: const Text('다른 문제'),
            ),
          ],
        ),
      ),
    );
  }
}
