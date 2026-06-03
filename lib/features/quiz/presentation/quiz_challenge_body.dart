import 'dart:math' as math;

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

  /// 모드·3/4지에 맞는 안내 문구 (질문과 같은 언어).
  String _promptInstruction(QuizChallengeQuestion q) {
    final isSentence = q.type.trim().toLowerCase() == 'sentence';
    return switch (q.mode) {
      QuizPromptMode.jpToKor => isSentence
          ? '次の文の意味を選んでください'
          : '次の日本語の意味を選んでください',
      QuizPromptMode.korToJp => isSentence
          ? '다음 문장에 맞는 일본어를 고르세요'
          : '다음 한국어에 맞는 일본어를 고르세요',
    };
  }

  Widget _buildPromptTexts(
    BuildContext context,
    ThemeData theme,
    QuizChallengeQuestion q,
  ) {
    final h = q.promptSecondary;
    final instructionStyle = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      height: 1.4,
    );
    final promptStyle = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.25,
    );
    final subStyle = theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _promptInstruction(q),
          style: instructionStyle,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: context.h(12)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: context.w(12),
            vertical: context.h(14),
          ),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              AppPalette.beige.withValues(alpha: 0.14),
              theme.colorScheme.surface.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(context.r(10)),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                q.promptPrimary,
                style: promptStyle,
                textAlign: TextAlign.center,
              ),
              if (h != null && h.isNotEmpty) ...[
                SizedBox(height: context.h(8)),
                Text(
                  h,
                  style: subStyle,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuizBubbleCard(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }

  String _wrongFeedbackMessage() {
    if (!feedbackWrong || wrongPickIndex == null) {
      return '틀렸습니다. 다시 선택해 주세요.';
    }
    final i = wrongPickIndex!;
    if (i < 0 || i >= question.choices.length) {
      return '틀렸습니다. 다시 선택해 주세요.';
    }

    switch (question.mode) {
      case QuizPromptMode.jpToKor:
        if (i >= question.wrongPickQuotes.length) {
          return '틀렸습니다. 다시 선택해 주세요.';
        }
        final jp = question.wrongPickQuotes[i].trim();
        final kor = question.choices[i].trim();
        if (jp.isEmpty || kor.isEmpty) {
          return '틀렸습니다. 다시 선택해 주세요.';
        }
        return '「$jp」의 뜻은 「$kor」입니다.';
      case QuizPromptMode.korToJp:
        final jp = question.wrongPickQuotes[i].trim();
        if (jp.isEmpty) {
          return '틀렸습니다. 다시 선택해 주세요.';
        }
        if (i < question.choiceKorMeanings.length) {
          final meaning = question.choiceKorMeanings[i]?.trim();
          if (meaning != null && meaning.isNotEmpty) {
            return '$jp는 "$meaning" 입니다.';
          }
        }
        return '틀렸습니다. 다시 선택해 주세요.';
    }
  }

  /// 단일열 선택지(전체 너비) 기준 답안 버튼 한 칸의 세로 높이.
  double _alarmChoiceButtonHeightAtFullWidth(
    BuildContext context,
    ThemeData theme,
    int index,
    double fullWidth,
    bool isCompactDevice,
  ) {
    final horizontalPad = context.w(isCompactDevice ? 8 : 10);
    final verticalStylePad = context.h((isCompactDevice ? 2.0 : 4.0) * 1.3);
    final childVerticalPad = context.h(4);
    final textMaxWidth =
        math.max(0.0, fullWidth - horizontalPad * 2).toDouble();
    const compact = true;

    final contentHeight = _measureChoiceContentHeight(
      theme: theme,
      index: index,
      maxWidth: textMaxWidth,
      compact: compact,
    );
    return verticalStylePad * 2 + childVerticalPad * 2 + contentHeight;
  }

  double _measureChoiceContentHeight({
    required ThemeData theme,
    required int index,
    required double maxWidth,
    required bool compact,
  }) {
    final label = question.choices[index];
    final titleStyle =
        (compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)
            ?.copyWith(fontWeight: FontWeight.w800);
    final subStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: compact ? 11 : null,
      fontWeight: FontWeight.w600,
    );

    final titlePainter = TextPainter(
      text: TextSpan(text: label, style: titleStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: compact ? 2 : null,
    )..layout(maxWidth: maxWidth);
    var height = titlePainter.height;

    final raw = index < question.choiceKorPronunciations.length
        ? question.choiceKorPronunciations[index]
        : null;
    final sub = raw?.trim();
    if (sub != null && sub.isNotEmpty) {
      height += 4;
      final subPainter = TextPainter(
        text: TextSpan(text: sub, style: subStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: compact ? 2 : null,
      )..layout(maxWidth: maxWidth);
      height += subPainter.height;
    }
    return height;
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
            /// 4지선다도 단일열 선택지와 동일한 텍스트·높이 기준(compact)을 씁니다.
            const alarmChoiceCompact = true;

            Widget buildChoiceButton(
              int i, {
              double? fixedHeight,
            }) {
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
              final button = ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: background,
                  foregroundColor: foreground,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    alarmChoiceCompact,
                  ),
                ),
              );
              if (fixedHeight == null) {
                return button;
              }
              return SizedBox(
                height: fixedHeight,
                width: double.infinity,
                child: button,
              );
            }

            Widget buildAlarmFourChoiceGrid(double fullWidth) {
              final crossSpacing = context.w(isCompactDevice ? 8 : 10);
              final mainSpacing = context.h(isCompactDevice ? 8 : 10);

              Widget rowCell(int index) {
                final height = _alarmChoiceButtonHeightAtFullWidth(
                  context,
                  theme,
                  index,
                  fullWidth,
                  isCompactDevice,
                );
                return Expanded(
                  child: buildChoiceButton(index, fixedHeight: height),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      rowCell(0),
                      SizedBox(width: crossSpacing),
                      rowCell(1),
                    ],
                  ),
                  SizedBox(height: mainSpacing),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      rowCell(2),
                      SizedBox(width: crossSpacing),
                      rowCell(3),
                    ],
                  ),
                ],
              );
            }

            return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildQuizBubbleCard(
                      context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPromptTexts(context, theme, question),
                        ],
                      ),
                    ),
                    SizedBox(height: context.h(14)),
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
                                  if (feedbackWrong)
                                    Padding(
                                      padding:
                                          EdgeInsets.only(bottom: context.h(12)),
                                      child: _buildQuizBubbleCard(
                                        context,
                                        child: Text(
                                          _wrongFeedbackMessage(),
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: theme.colorScheme.error,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
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
                                    buildAlarmFourChoiceGrid(
                                      constraints.maxWidth,
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
                _buildPromptTexts(context, theme, question),
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
