import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/ui/responsive.dart';
import '../domain/quiz_challenge_question.dart';
import '../domain/quiz_prompt_mode.dart';

/// 질문(상단) + 객관식 선택 버튼.
class QuizChallengeBody extends StatelessWidget {
  const QuizChallengeBody({
    super.key,
    required this.question,
    required this.onPickIndex,
    this.useAlarmStyleLayout = false,
    this.forceSingleColumnChoices = false,

    /// true면 남는 세로 공간 안에서 선택지를 아래쪽에 붙입니다(연습 퀴즈 등).
    this.pinChoicesToBottom = false,
    this.feedbackWrong = false,

    /// 방금 선택한 오답 인덱스. 해당 버튼만 오류 색으로 채워 표시합니다.
    this.wrongPickIndex,

    /// 정답으로 확정된 선택지 인덱스. primary(파란색)로 채워 표시합니다.
    this.correctHighlightIndex,
  });

  final QuizChallengeQuestion question;
  final void Function(int index) onPickIndex;
  final bool useAlarmStyleLayout;
  final bool forceSingleColumnChoices;
  final bool pinChoicesToBottom;
  final bool feedbackWrong;
  final int? wrongPickIndex;
  final int? correctHighlightIndex;

  Widget _buildPromptTexts(ThemeData theme, QuizChallengeQuestion q) {
    final h = q.promptSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          q.promptPrimary,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (h != null && h.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            h,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  String _wrongFeedbackMessage() {
    if (!feedbackWrong || wrongPickIndex == null) {
      return '틀렸습니다. 다시 선택해 주세요.';
    }
    final i = wrongPickIndex!;
    if (i < 0 || i >= question.wrongPickQuotes.length) {
      return '틀렸습니다. 다시 선택해 주세요.';
    }
    final quoted = question.wrongPickQuotes[i].trim();
    if (quoted.isEmpty) {
      return '틀렸습니다. 다시 선택해 주세요.';
    }
    return '「$quoted」는(은) 정답이 아닙니다. 다시 선택해 주세요.';
  }

  Widget _choiceButtonChild(
    ThemeData theme,
    int index,
    String label,
    Color foreground,
    bool compact,
  ) {
    final raw = index < question.choiceKorPronunciations.length
        ? question.choiceKorPronunciations[index]
        : null;
    final sub = raw?.trim();
    if (sub == null || sub.isEmpty) {
      return Text(
        label,
        style: (compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)
            ?.copyWith(
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
        textAlign: TextAlign.center,
        maxLines: compact ? 2 : null,
        overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style:
              (compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)
                  ?.copyWith(
            fontWeight: FontWeight.w800,
            color: foreground,
          ),
          textAlign: TextAlign.center,
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
        ),
        const SizedBox(height: 4),
        Text(
          sub,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: compact ? 11 : null,
            color: foreground.withValues(alpha: 0.88),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final challengeTheme = question.mode == QuizPromptMode.jpToKor
        ? AppTheme.japanesePrimary(baseTheme)
        : baseTheme;

    return Theme(
      data: challengeTheme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final isCompactDevice = MediaQuery.sizeOf(context).width <= 380;
          // A/B 미세 튜닝: 값(0.0 / 0.12 / 0.16)만 바꿔 높이 단계를 조절합니다.
          const compactChoiceAspectStep = 0.16;
          const regularChoiceAspectStep = 0.12;
          final isSentence = question.type.trim().toLowerCase() == 'sentence';
          /// `sentence` 타입만 1열(세로 스택). 그 외는 2열(2×2) 그리드.
          /// [forceSingleColumnChoices]가 true이면 타입과 관계없이 1열.
          final isSingleColumn = forceSingleColumnChoices || isSentence;
          final choiceGridCrossAxisCount = isSingleColumn ? 1 : 2;
          /// 한→일은 발음 보조 줄 때문에 셀을 조금 더 높게.
          /// 1열(연습 모드·sentence)은 현재보다 약 50% 더 낮게 보이도록 가로:세로 비를 키웁니다.
          final choiceGridChildAspectRatio =
              switch ((isSingleColumn, question.mode, isCompactDevice)) {
            // 연습 퀴즈(1열) 슬롯 높이를 기존 대비 약 2/3 수준으로 줄이기 위해
            // childAspectRatio를 약 1.5배로 증가시킵니다.
            (true, QuizPromptMode.korToJp, true) => 5.6,
            (true, QuizPromptMode.korToJp, false) => 5.1,
            (true, _, true) => 6.2,
            (true, _, false) => 5.7,
            // 2열(기존 알람 퀴즈 레이아웃)은 기존 값 유지
            (false, QuizPromptMode.korToJp, true) => 2.12,
            (false, QuizPromptMode.korToJp, false) => 1.95,
            (false, _, true) => 2.48,
            (false, _, false) => 2.3,
          };
          final tunedChoiceGridChildAspectRatio =
              (choiceGridChildAspectRatio +
                      (isCompactDevice
                          ? compactChoiceAspectStep
                          : regularChoiceAspectStep)) /
                  1.3;

          if (useAlarmStyleLayout) {
            Widget buildChoiceButton(int i) {
              final label = question.choices[i];
              final showCorrectFill =
                  correctHighlightIndex != null && correctHighlightIndex == i;
              final showWrongFill =
                  feedbackWrong && wrongPickIndex != null && wrongPickIndex == i;
              final background = showCorrectFill
                  ? theme.colorScheme.secondary
                  : showWrongFill
                      ? theme.colorScheme.error
                      : AppPalette.beigeSoft;
              final foreground = showCorrectFill
                  ? theme.colorScheme.onSecondary
                  : showWrongFill
                      ? theme.colorScheme.onError
                      : theme.colorScheme.onSurface;
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: background,
                  foregroundColor: foreground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.r(14)),
                    side: BorderSide(
                      width: showCorrectFill || showWrongFill ? 1.2 : 0.8,
                      color: showCorrectFill
                          ? theme.colorScheme.secondary.withValues(alpha: 0.9)
                          : showWrongFill
                              ? theme.colorScheme.error.withValues(alpha: 0.9)
                              : AppPalette.navy.withValues(alpha: 0.10),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: context.h(
                      (isCompactDevice ? 2.0 : 4.0) * 1.3,
                    ),
                    horizontal: context.w(isCompactDevice ? 8 : 10),
                  ),
                ),
                onPressed: () => onPickIndex(i),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: context.h(4)),
                  child: _choiceButtonChild(
                    theme,
                    i,
                    label,
                    foreground,
                    isSingleColumn,
                  ),
                ),
              );
            }

            return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        context.w(14),
                        context.h(14),
                        context.w(14),
                        context.h(14),
                      ),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          AppPalette.beige.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.44),
                        ),
                        borderRadius: BorderRadius.circular(context.r(14)),
                        border: Border.all(
                          color: context.wnColors.quizBubbleBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPromptTexts(theme, question),
                        ],
                      ),
                    ),
                    SizedBox(height: context.h(14)),
                    if (feedbackWrong)
                      Padding(
                        padding: EdgeInsets.only(bottom: context.h(12)),
                        child: Text(
                          _wrongFeedbackMessage(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (choiceGridCrossAxisCount == 1)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (var i = 0;
                                            i < question.choices.length;
                                            i++) ...[
                                          buildChoiceButton(i),
                                          if (i != question.choices.length - 1)
                                            SizedBox(
                                              height: context.h(
                                                isCompactDevice ? 8 : 10,
                                              ),
                                            ),
                                        ],
                                      ],
                                    )
                                  else
                                    GridView.builder(
                                      shrinkWrap: true,
                                      itemCount: question.choices.length,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: context.h(
                                          isCompactDevice ? 8 : 10,
                                        ),
                                        crossAxisSpacing: context.w(
                                          isCompactDevice ? 8 : 10,
                                        ),
                                        childAspectRatio:
                                            tunedChoiceGridChildAspectRatio,
                                      ),
                                      itemBuilder: (context, i) =>
                                          buildChoiceButton(i),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
          }

          final questionCard = Container(
            padding: EdgeInsets.fromLTRB(
              context.w(14),
              context.h(14),
              context.w(14),
              context.h(14),
            ),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                AppPalette.beige.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.44),
              ),
              borderRadius: BorderRadius.circular(context.r(14)),
              border: Border.all(color: context.wnColors.quizBubbleBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPromptTexts(theme, question),
              ],
            ),
          );

          final practiceChoiceGrid = GridView.builder(
            shrinkWrap: true,
            itemCount: question.choices.length,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: choiceGridCrossAxisCount,
              mainAxisSpacing: context.h(10),
              crossAxisSpacing: context.w(10),
              childAspectRatio: tunedChoiceGridChildAspectRatio,
            ),
            itemBuilder: (context, i) {
              final label = question.choices[i];
              final showCorrectFill =
                  correctHighlightIndex != null && correctHighlightIndex == i;
              final showWrongFill =
                  feedbackWrong &&
                  wrongPickIndex != null &&
                  wrongPickIndex == i;
              final background = showCorrectFill
                  ? theme.colorScheme.secondary
                  : showWrongFill
                      ? theme.colorScheme.error
                      : AppPalette.beigeSoft;
              final foreground = showCorrectFill
                  ? theme.colorScheme.onSecondary
                  : showWrongFill
                      ? theme.colorScheme.onError
                      : theme.colorScheme.onSurface;

              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: background,
                  foregroundColor: foreground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.r(14)),
                    side: BorderSide(
                      width: showCorrectFill || showWrongFill ? 1.2 : 0.8,
                      color: showCorrectFill
                          ? theme.colorScheme.secondary.withValues(alpha: 0.9)
                          : showWrongFill
                              ? theme.colorScheme.error.withValues(alpha: 0.9)
                              : AppPalette.navy.withValues(alpha: 0.10),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: context.h(
                      (isCompactDevice ? 2.0 : 4.0) * 1.3,
                    ),
                    horizontal: context.w(isCompactDevice ? 8 : 10),
                  ),
                ),
                onPressed: () => onPickIndex(i),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: context.h(4)),
                  child: _choiceButtonChild(
                    theme,
                    i,
                    label,
                    foreground,
                    isSingleColumn,
                  ),
                ),
              );
            },
          );

          if (pinChoicesToBottom) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                questionCard,
                SizedBox(height: context.h(16)),
                if (feedbackWrong)
                  Padding(
                    padding: EdgeInsets.only(bottom: context.h(12)),
                    child: Text(
                      _wrongFeedbackMessage(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [practiceChoiceGrid],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              questionCard,
              SizedBox(height: context.h(16)),
              if (feedbackWrong)
                Padding(
                  padding: EdgeInsets.only(bottom: context.h(12)),
                  child: Text(
                    _wrongFeedbackMessage(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              practiceChoiceGrid,
            ],
          );
        },
      ),
    );
  }
}
