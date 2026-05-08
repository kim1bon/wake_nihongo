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
    this.thumbnailAssetPath,
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
  final String? thumbnailAssetPath;
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
          final typeLabel = isSentence
              ? '2지선다 · ${question.type}'
              : '4지선다 · ${question.type}';
          /// sentence(2지): 기본 1열, 4지선다는 기본 2열이지만
          /// [forceSingleColumnChoices]가 true이면 항상 1열(세로 스택)로 배치합니다.
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
          final tunedChoiceGridChildAspectRatio = choiceGridChildAspectRatio +
              (isCompactDevice ? compactChoiceAspectStep : regularChoiceAspectStep);

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
                    vertical: context.h(isCompactDevice ? 2 : 4),
                    horizontal: context.w(isCompactDevice ? 8 : 10),
                  ),
                ),
                onPressed: () => onPickIndex(i),
                child: _choiceButtonChild(
                  theme,
                  i,
                  label,
                  foreground,
                  forceSingleColumnChoices,
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final wn = context.wnColors;
                final cardWidth = constraints.maxWidth;
                final bubbleFill = Color.alphaBlend(
                  AppPalette.beige.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.42),
                );
                final thumbnailSize = (cardWidth * 0.22).clamp(74.0, 92.0);
                final thumbnailRight = (cardWidth * 0.045).clamp(12.0, 20.0);
                final bubbleBottomGap = thumbnailSize * 0.48;
                final tailRight =
                    thumbnailRight + thumbnailSize - (thumbnailSize * 0.16);
                final tailBottom = bubbleBottomGap + 2;
                final tailWidth = (thumbnailSize * 0.40).clamp(28.0, 38.0);
                final tailHeight = (thumbnailSize * 0.33).clamp(22.0, 30.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          margin: EdgeInsets.only(bottom: bubbleBottomGap),
                          padding: EdgeInsets.fromLTRB(
                            context.w(18),
                            context.h(22),
                            context.w(18),
                            context.h(28),
                          ),
                          decoration: BoxDecoration(
                            color: bubbleFill,
                            borderRadius: BorderRadius.circular(context.r(24)),
                            border: Border.all(color: wn.quizBubbleBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                typeLabel,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: context.h(12)),
                              _buildPromptTexts(theme, question),
                            ],
                          ),
                        ),
                        Positioned(
                          right: tailRight,
                          bottom: tailBottom,
                          child: _SpeechBubbleTail(
                            width: tailWidth,
                            height: tailHeight,
                            fillColor: bubbleFill,
                            borderColor: wn.quizTailBorder,
                          ),
                        ),
                        if (thumbnailAssetPath != null)
                          Positioned(
                            right: thumbnailRight,
                            bottom: 0,
                            child: Container(
                              width: thumbnailSize,
                              height: thumbnailSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: wn.quizThumbnailRing,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                                image: DecorationImage(
                                  image: AssetImage(thumbnailAssetPath!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          ),
                      ],
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
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (choiceGridCrossAxisCount == 1)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < question.choices.length; i++) ...[
                                    buildChoiceButton(i),
                                    if (i != question.choices.length - 1)
                                      SizedBox(height: context.h(isCompactDevice ? 8 : 10)),
                                  ],
                                ],
                              )
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                itemCount: question.choices.length,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: context.h(isCompactDevice ? 8 : 10),
                                  crossAxisSpacing: context.w(isCompactDevice ? 8 : 10),
                                  childAspectRatio: isCompactDevice ? 2.48 : 2.3,
                                ),
                                itemBuilder: (context, i) => buildChoiceButton(i),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  context.w(16),
                  context.h(20),
                  context.w(16),
                  context.h(20),
                ),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    AppPalette.beige.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.44),
                  ),
                  borderRadius: BorderRadius.circular(context.r(24)),
                  border: Border.all(color: context.wnColors.quizBubbleBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: context.h(12)),
                    _buildPromptTexts(theme, question),
                  ],
                ),
              ),
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
              GridView.builder(
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
                      correctHighlightIndex != null &&
                      correctHighlightIndex == i;
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
                              ? theme.colorScheme.secondary
                                  .withValues(alpha: 0.9)
                              : showWrongFill
                                  ? theme.colorScheme.error
                                      .withValues(alpha: 0.9)
                                  : AppPalette.navy.withValues(alpha: 0.10),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: context.h(isCompactDevice ? 2 : 4),
                        horizontal: context.w(isCompactDevice ? 8 : 10),
                      ),
                    ),
                    onPressed: () => onPickIndex(i),
                    child: _choiceButtonChild(
                      theme,
                      i,
                      label,
                      foreground,
                      forceSingleColumnChoices,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SpeechBubbleTail extends StatelessWidget {
  const _SpeechBubbleTail({
    required this.width,
    required this.height,
    required this.fillColor,
    required this.borderColor,
  });

  final double width;
  final double height;
  final Color fillColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SpeechBubbleTailPainter(
        fillColor: fillColor,
        borderColor: borderColor,
      ),
    );
  }
}

class _SpeechBubbleTailPainter extends CustomPainter {
  _SpeechBubbleTailPainter({
    required this.fillColor,
    required this.borderColor,
  });

  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.2,
        size.width,
        size.height,
      )
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.9, 0, 0)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubbleTailPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}
