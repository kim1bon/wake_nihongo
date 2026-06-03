// 알람 퀴즈 정답 후 결과 화면.
//
// pubspec.yaml에 `assets/images/` 폴더가 이미 있으면 Tx_Background.png는 별도 줄 추가 없이 사용 가능합니다.
// 단일 파일만 쓰는 경우 예: `flutter: assets: - assets/images/Tx_Background.png`

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/ui/responsive.dart';

/// 응원 문구 한 세트.
class CheerMessage {
  const CheerMessage({
    required this.jp,
    required this.hiragana,
    required this.kor,
    required this.pronunciation,
  });

  final String jp;
  final String hiragana;
  final String kor;
  final String pronunciation;
}

List<CheerMessage> _defaultCheerMessages() => const [
  CheerMessage(
    jp: '今日もいい一日を！',
    hiragana: 'きょうも いい いちにち を',
    kor: '오늘도 좋은 하루 보내세요',
    pronunciation: '쿄-모 이-이 이치니치 오',
  ),
  CheerMessage(
    jp: '頑張ってね！',
    hiragana: 'がんばってね',
    kor: '힘내요!',
    pronunciation: '간밧테네',
  ),
  CheerMessage(
    jp: '素敵な一日を！',
    hiragana: 'すてきな いちにち を',
    kor: '멋진 하루 보내세요',
    pronunciation: '스테키나 이치니치 오',
  ),
];

CheerMessage _pickRandomCheer(Random random, List<CheerMessage> list) =>
    list[random.nextInt(list.length)];

/// 알람 퀴즈 정답 결과 UI.
class AlarmQuizSuccessScreen extends StatefulWidget {
  const AlarmQuizSuccessScreen({
    super.key,
    required this.onStopAlarm,
    this.backgroundAssetPath = 'assets/images/Tx_Background.png',
    this.messages,
  });

  final VoidCallback onStopAlarm;

  final String backgroundAssetPath;
  final List<CheerMessage>? messages;

  @override
  State<AlarmQuizSuccessScreen> createState() => _AlarmQuizSuccessScreenState();
}

class _AlarmQuizSuccessScreenState extends State<AlarmQuizSuccessScreen>
    with TickerProviderStateMixin {
  Timer? _buttonDelayTimer;

  late final Random _random;
  late CheerMessage _message;

  late final AnimationController _checkController;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkFade;

  late final AnimationController _titleController;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;

  late final AnimationController _cheerController;
  late final Animation<double> _cheerFade;
  late final Animation<Offset> _cheerSlide;

  late final AnimationController _buttonController;
  late final Animation<double> _buttonFade;

  List<CheerMessage> get _messages =>
      widget.messages ?? _defaultCheerMessages();

  @override
  void initState() {
    super.initState();
    _random = Random();
    _message = _pickRandomCheer(_random, _messages);

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkScale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeOutBack),
    );
    _checkFade = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOut,
    );

    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _titleFade = CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOut,
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.28), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _titleController, curve: Curves.easeOutCubic),
        );

    _cheerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _cheerFade = CurvedAnimation(
      parent: _cheerController,
      curve: Curves.easeOut,
    );
    _cheerSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _cheerController, curve: Curves.easeOutCubic),
        );

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _buttonFade = CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _runIntroAnimations());
  }

  Future<void> _runIntroAnimations() async {
    _buttonDelayTimer?.cancel();
    _buttonDelayTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      await _buttonController.forward();
    });

    await _checkController.forward();
    await _titleController.forward();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _cheerController.forward();
  }

  @override
  void dispose() {
    _buttonDelayTimer?.cancel();
    _checkController.dispose();
    _titleController.dispose();
    _cheerController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  /// 상단 안내 (알람 종료 가능)
  Widget _buildTopNotice() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.w(18),
          vertical: context.h(11),
        ),
        decoration: BoxDecoration(
          color: AppPalette.beigeSoft.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(context.r(999)),
          border: Border.all(color: context.wnColors.successTopBannerBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.alarm,
              size: context.r(20),
              color: Colors.white.withValues(alpha: 0.92),
            ),
            SizedBox(width: context.w(8)),
            Text(
              '알람을 종료할 수 있어요',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.94),
                fontWeight: FontWeight.w600,
                fontSize: context.sp(13.5),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 체크 + 정답입니다 + 장식선
  Widget _buildCorrectSection() {
    return Column(
      children: [
        FadeTransition(
          opacity: _checkFade,
          child: ScaleTransition(
            scale: _checkScale,
            child: Container(
              width: context.r(80),
              height: context.r(80),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: context.wnColors.successCheckGlow,
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.check_rounded,
                size: context.r(48),
                color: AppPalette.navy.withValues(alpha: 0.88),
              ),
            ),
          ),
        ),
        SizedBox(height: context.h(18)),
        FadeTransition(
          opacity: _titleFade,
          child: SlideTransition(
            position: _titleSlide,
            child: const Text(
              '정답입니다!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ),
        SizedBox(height: context.h(16)),
        _buildBeigeDivider(),
      ],
    );
  }

  Widget _buildBeigeDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppPalette.beige.withValues(alpha: 0.45),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.w(8)),
          child: Icon(
            Icons.diamond_outlined,
            size: context.r(12),
            color: AppPalette.beige.withValues(alpha: 0.75),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AppPalette.beige.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }

  /// 일본어 루비 + 한국어 뜻 + 발음 카드
  Widget _buildCheerMessage() {
    return FadeTransition(
      opacity: _cheerFade,
      child: SlideTransition(
        position: _cheerSlide,
        child: _buildCheerContent(_message),
      ),
    );
  }

  Widget _buildCheerContent(CheerMessage message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 루비: 위 작은 히라가나 → 아래 본문 일본어
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              message.hiragana,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: context.sp(11.5),
                height: 1.15,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: context.h(4)),
            Text(
              message.jp,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.28,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        SizedBox(height: context.h(22)),
        Text(
          message.kor,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppPalette.beige,
            fontSize: context.sp(18),
            fontWeight: FontWeight.w700,
            height: 1.4,
            letterSpacing: -0.2,
            shadows: [
              Shadow(
                color: context.wnColors.successKorMeaningShadow,
                blurRadius: 14,
              ),
            ],
          ),
        ),
        SizedBox(height: context.h(18)),
        _buildPronunciationCard(message.pronunciation),
      ],
    );
  }

  Widget _buildPronunciationCard(String pronunciation) {
    return _DashedBorderCard(
      borderRadius: 14,
      dashLength: 5,
      gapLength: 4,
      strokeColor: Color.alphaBlend(
        context.wnColors.pronunciationStrokeBlendGreen,
        Colors.white.withValues(alpha: 0.38),
      ),
      strokeWidth: 1.1,
      backgroundColor: Color.alphaBlend(
        context.wnColors.pronunciationFillBlendGreen,
        Colors.black.withValues(alpha: 0.22),
      ),
      padding: EdgeInsets.fromLTRB(
        context.w(16),
        context.h(14),
        context.w(16),
        context.h(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.headphones,
                size: context.r(17),
                color: Colors.white.withValues(alpha: 0.82),
              ),
              SizedBox(width: context.w(8)),
              Text(
                '한국어 발음',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: context.sp(12.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(8)),
          Text(
            pronunciation,
            style: TextStyle(
              color: Colors.white,
              fontSize: context.sp(16),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.35,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// 하단 고정: 알람 끄기
  Widget _buildBottomButtonArea(bool isCompactDevice) {
    const textStepSp = 0.5;
    final primaryFontSize = context.sp(isCompactDevice ? 15.5 : 16.5) -
        context.sp(textStepSp);
    return FadeTransition(
      opacity: _buttonFade,
      child: FilledButton(
        onPressed: widget.onStopAlarm,
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.beigeSoft,
          foregroundColor: AppPalette.navy,
          padding: EdgeInsets.symmetric(
            vertical: context.h(isCompactDevice ? 13 : 16),
          ),
          minimumSize: Size.fromHeight(context.h(isCompactDevice ? 46 : 52)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.r(14)),
          ),
          side: BorderSide(
            color: context.wnColors.successPrimaryButtonBorder,
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: context.r(isCompactDevice ? 19 : 21),
            ),
            SizedBox(width: context.w(isCompactDevice ? 8 : 10)),
            Text(
              '알람 끄기',
              style: TextStyle(
                fontSize: primaryFontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isCompactDevice = mq.size.width <= 380;
    final padH = context.w(22).clamp(18.0, 28.0);
    final viewInsets = mq.padding.bottom;

    return Theme(
      data: AppTheme.japanesePrimary(Theme.of(context)),
      child: Scaffold(
        backgroundColor: AppPalette.navyDeep,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                widget.backgroundAssetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: AppPalette.navyDeep),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: context.wnColors.quizSuccessScrim,
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(padH, context.h(10), padH, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopNotice(),
                    SizedBox(height: context.h(24)),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: EdgeInsets.only(
                              bottom: context.h(12) + viewInsets * 0.25,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildCorrectSection(),
                                  SizedBox(height: context.h(24)),
                                  _buildCheerMessage(),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: context.h(isCompactDevice ? 6 : 8),
                        bottom: context.h(isCompactDevice ? 6 : 8) + mq.padding.bottom,
                      ),
                      child: _buildBottomButtonArea(isCompactDevice),
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
}

/// 점선 테두리 + 반투명 배경 카드
class _DashedBorderCard extends StatelessWidget {
  const _DashedBorderCard({
    required this.child,
    required this.borderRadius,
    required this.backgroundColor,
    required this.padding,
    required this.strokeColor,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final Widget child;
  final double borderRadius;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;
  final Color strokeColor;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(
        radius: borderRadius,
        color: strokeColor,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        gapLength: gapLength,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.radius,
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final double radius;
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        final extract = metric.extractPath(
          distance,
          next > metric.length ? metric.length : next,
        );
        canvas.drawPath(extract, paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}
