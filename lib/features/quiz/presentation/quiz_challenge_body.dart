import 'package:flutter/material.dart';

import '../domain/jp_to_kor_question.dart';

/// 일본어 제목 + 한국어 선택 버튼.
class QuizChallengeBody extends StatelessWidget {
  const QuizChallengeBody({
    super.key,
    required this.question,
    required this.onPickIndex,
    this.feedbackWrong = false,
    /// 방금 선택한 오답 인덱스. 해당 버튼만 오류 색으로 채워 표시합니다.
    this.wrongPickIndex,
    /// 정답으로 확정된 선택지 인덱스. primary(파란색)로 채워 표시합니다.
    this.correctHighlightIndex,
  });

  final JpToKorQuestion question;
  final void Function(int index) onPickIndex;
  final bool feedbackWrong;
  final int? wrongPickIndex;
  final int? correctHighlightIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = question.type == '단어' ? '4지선다 · 단어' : '2지선다 · ${question.type}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          typeLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          question.promptJp,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (feedbackWrong)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '틀렸습니다. 다시 선택해 주세요.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ...List.generate(question.koreanChoices.length, (i) {
          final label = question.koreanChoices[i];
          final showCorrectFill =
              correctHighlightIndex != null && correctHighlightIndex == i;
          final showWrongFill =
              feedbackWrong && wrongPickIndex != null && wrongPickIndex == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: showCorrectFill
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                    ),
                    onPressed: () => onPickIndex(i),
                    child: Text(label, textAlign: TextAlign.center),
                  )
                : showWrongFill
                    ? FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                        ),
                        onPressed: () => onPickIndex(i),
                        child: Text(label, textAlign: TextAlign.center),
                      )
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                        ),
                        onPressed: () => onPickIndex(i),
                        child: Text(label, textAlign: TextAlign.center),
                      ),
          );
        }),
      ],
    );
  }
}
