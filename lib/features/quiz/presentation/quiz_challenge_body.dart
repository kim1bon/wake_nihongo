import 'package:flutter/material.dart';

import '../domain/jp_to_kor_question.dart';

/// 일본어 제목 + 한국어 선택 버튼.
class QuizChallengeBody extends StatelessWidget {
  const QuizChallengeBody({
    super.key,
    required this.question,
    required this.onPickIndex,
    this.useAlarmStyleLayout = false,
    this.thumbnailAssetPath,
    this.feedbackWrong = false,
    /// 방금 선택한 오답 인덱스. 해당 버튼만 오류 색으로 채워 표시합니다.
    this.wrongPickIndex,
    /// 정답으로 확정된 선택지 인덱스. primary(파란색)로 채워 표시합니다.
    this.correctHighlightIndex,
  });

  final JpToKorQuestion question;
  final void Function(int index) onPickIndex;
  final bool useAlarmStyleLayout;
  final String? thumbnailAssetPath;
  final bool feedbackWrong;
  final int? wrongPickIndex;
  final int? correctHighlightIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = question.type == '단어' ? '4지선다 · 단어' : '2지선다 · ${question.type}';

    if (useAlarmStyleLayout) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth;
          final viewportHeight = constraints.maxHeight;
          final thumbnailSize = (cardWidth * 0.22).clamp(74.0, 92.0);
          final thumbnailRight = (cardWidth * 0.045).clamp(12.0, 20.0);
          final bubbleBottomGap = thumbnailSize * 0.48;
          final tailRight = thumbnailRight + thumbnailSize - (thumbnailSize * 0.16);
          final tailBottom = bubbleBottomGap + 2;
          final tailWidth = (thumbnailSize * 0.40).clamp(28.0, 38.0);
          final tailHeight = (thumbnailSize * 0.33).clamp(22.0, 30.0);
          const minResponsiveHeight = 568.0; // iPhone SE 1세대 높이 기준
          const maxResponsiveHeight = 760.0;
          final heightRatio = ((viewportHeight - minResponsiveHeight) /
                  (maxResponsiveHeight - minResponsiveHeight))
              .clamp(0.0, 1.0);
          final bubbleTopOffset = 80.0 + (20.0 * heightRatio);

          return Stack(
            children: [
              Positioned(
                top: bubbleTopOffset,
                left: 0,
                right: 0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      margin: EdgeInsets.only(bottom: bubbleBottomGap),
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.44),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            typeLabel,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '이 단어의 뜻을 골라주세요',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            question.promptJp,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: tailRight,
                      bottom: tailBottom,
                      child: _SpeechBubbleTail(
                        width: tailWidth,
                        height: tailHeight,
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
                            border: Border.all(color: Colors.white, width: 4),
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
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (feedbackWrong)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '틀렸습니다. 다시 선택해 주세요.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    GridView.builder(
                      shrinkWrap: true,
                      itemCount: question.koreanChoices.length,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.3,
                      ),
                      itemBuilder: (context, i) {
                        final label = question.koreanChoices[i];
                        final showCorrectFill =
                            correctHighlightIndex != null && correctHighlightIndex == i;
                        final showWrongFill =
                            feedbackWrong && wrongPickIndex != null && wrongPickIndex == i;
                        final background = showCorrectFill
                            ? theme.colorScheme.primary
                            : showWrongFill
                                ? theme.colorScheme.error
                                : Colors.white;
                        final foreground = showCorrectFill
                            ? theme.colorScheme.onPrimary
                            : showWrongFill
                                ? theme.colorScheme.onError
                                : theme.colorScheme.onSurface;

                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: background,
                            foregroundColor: foreground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 10,
                            ),
                          ),
                          onPressed: () => onPickIndex(i),
                          child: Text(
                            label,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: foreground,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        );
                      },
                    ),
                  ],
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
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.44),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                typeLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '이 단어의 뜻을 골라주세요',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                question.promptJp,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (feedbackWrong)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '틀렸습니다. 다시 선택해 주세요.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        GridView.builder(
          shrinkWrap: true,
          itemCount: question.koreanChoices.length,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.3,
          ),
          itemBuilder: (context, i) {
            final label = question.koreanChoices[i];
            final showCorrectFill =
                correctHighlightIndex != null && correctHighlightIndex == i;
            final showWrongFill =
                feedbackWrong && wrongPickIndex != null && wrongPickIndex == i;
            final background = showCorrectFill
                ? theme.colorScheme.primary
                : showWrongFill
                    ? theme.colorScheme.error
                    : Colors.white;
            final foreground = showCorrectFill
                ? theme.colorScheme.onPrimary
                : showWrongFill
                    ? theme.colorScheme.onError
                    : theme.colorScheme.onSurface;

            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: background,
                foregroundColor: foreground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 10,
                ),
              ),
              onPressed: () => onPickIndex(i),
              child: Text(
                label,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SpeechBubbleTail extends StatelessWidget {
  const _SpeechBubbleTail({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SpeechBubbleTailPainter(),
    );
  }
}

class _SpeechBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.44)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
