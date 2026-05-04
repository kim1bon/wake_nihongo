import 'package:flutter/material.dart';

import 'app_palette.dart';

/// [ThemeData.extensions]에 넣는 **시맨틱 UI 색**. 위젯은 `context.wnColors`로 접근.
///
/// 다크 모드 등을 추가할 때 [copyWith] / [lerp]를 확장하면 됩니다.
@immutable
class WakeNihongoColors extends ThemeExtension<WakeNihongoColors> {
  const WakeNihongoColors({
    required this.navigationBarIndicator,
    required this.alarmBannerFill,
    required this.alarmBannerBorder,
    required this.alarmPrimaryButtonBorder,
    required this.successPrimaryButtonBorder,
    required this.successTopBannerBorder,
    required this.successCheckGlow,
    required this.successKorMeaningShadow,
    required this.pronunciationStrokeBlendGreen,
    required this.pronunciationFillBlendGreen,
    required this.quizBubbleBorder,
    required this.quizThumbnailRing,
    required this.quizTailBorder,
  });

  factory WakeNihongoColors.light() {
    return WakeNihongoColors(
      navigationBarIndicator: AppPalette.green.withValues(alpha: 0.28),
      alarmBannerFill: AppPalette.beigeSoft.withValues(alpha: 0.22),
      alarmBannerBorder: AppPalette.green.withValues(alpha: 0.35),
      alarmPrimaryButtonBorder: AppPalette.green.withValues(alpha: 0.40),
      successPrimaryButtonBorder: AppPalette.green.withValues(alpha: 0.45),
      successTopBannerBorder: AppPalette.green.withValues(alpha: 0.35),
      successCheckGlow: AppPalette.green.withValues(alpha: 0.35),
      successKorMeaningShadow: AppPalette.green.withValues(alpha: 0.35),
      pronunciationStrokeBlendGreen: AppPalette.green.withValues(alpha: 0.35),
      pronunciationFillBlendGreen: AppPalette.green.withValues(alpha: 0.10),
      quizBubbleBorder: AppPalette.beige.withValues(alpha: 0.45),
      quizThumbnailRing: AppPalette.beigeSoft,
      quizTailBorder: AppPalette.beige.withValues(alpha: 0.48),
    );
  }

  final Color navigationBarIndicator;
  final Color alarmBannerFill;
  final Color alarmBannerBorder;
  final Color alarmPrimaryButtonBorder;
  final Color successPrimaryButtonBorder;
  final Color successTopBannerBorder;
  final Color successCheckGlow;
  final Color successKorMeaningShadow;
  final Color pronunciationStrokeBlendGreen;
  final Color pronunciationFillBlendGreen;
  final Color quizBubbleBorder;
  final Color quizThumbnailRing;
  final Color quizTailBorder;

  LinearGradient get alarmRingScrim => AppPalette.alarmRingScrim;

  LinearGradient get quizSuccessScrim => AppPalette.quizSuccessScrim;

  @override
  WakeNihongoColors copyWith({
    Color? navigationBarIndicator,
    Color? alarmBannerFill,
    Color? alarmBannerBorder,
    Color? alarmPrimaryButtonBorder,
    Color? successPrimaryButtonBorder,
    Color? successTopBannerBorder,
    Color? successCheckGlow,
    Color? successKorMeaningShadow,
    Color? pronunciationStrokeBlendGreen,
    Color? pronunciationFillBlendGreen,
    Color? quizBubbleBorder,
    Color? quizThumbnailRing,
    Color? quizTailBorder,
  }) {
    return WakeNihongoColors(
      navigationBarIndicator:
          navigationBarIndicator ?? this.navigationBarIndicator,
      alarmBannerFill: alarmBannerFill ?? this.alarmBannerFill,
      alarmBannerBorder: alarmBannerBorder ?? this.alarmBannerBorder,
      alarmPrimaryButtonBorder:
          alarmPrimaryButtonBorder ?? this.alarmPrimaryButtonBorder,
      successPrimaryButtonBorder:
          successPrimaryButtonBorder ?? this.successPrimaryButtonBorder,
      successTopBannerBorder:
          successTopBannerBorder ?? this.successTopBannerBorder,
      successCheckGlow: successCheckGlow ?? this.successCheckGlow,
      successKorMeaningShadow:
          successKorMeaningShadow ?? this.successKorMeaningShadow,
      pronunciationStrokeBlendGreen:
          pronunciationStrokeBlendGreen ?? this.pronunciationStrokeBlendGreen,
      pronunciationFillBlendGreen:
          pronunciationFillBlendGreen ?? this.pronunciationFillBlendGreen,
      quizBubbleBorder: quizBubbleBorder ?? this.quizBubbleBorder,
      quizThumbnailRing: quizThumbnailRing ?? this.quizThumbnailRing,
      quizTailBorder: quizTailBorder ?? this.quizTailBorder,
    );
  }

  @override
  WakeNihongoColors lerp(ThemeExtension<WakeNihongoColors>? other, double t) {
    if (other is! WakeNihongoColors) return this;
    return WakeNihongoColors(
      navigationBarIndicator: Color.lerp(
        navigationBarIndicator,
        other.navigationBarIndicator,
        t,
      )!,
      alarmBannerFill: Color.lerp(alarmBannerFill, other.alarmBannerFill, t)!,
      alarmBannerBorder: Color.lerp(alarmBannerBorder, other.alarmBannerBorder, t)!,
      alarmPrimaryButtonBorder: Color.lerp(
        alarmPrimaryButtonBorder,
        other.alarmPrimaryButtonBorder,
        t,
      )!,
      successPrimaryButtonBorder: Color.lerp(
        successPrimaryButtonBorder,
        other.successPrimaryButtonBorder,
        t,
      )!,
      successTopBannerBorder: Color.lerp(
        successTopBannerBorder,
        other.successTopBannerBorder,
        t,
      )!,
      successCheckGlow: Color.lerp(successCheckGlow, other.successCheckGlow, t)!,
      successKorMeaningShadow: Color.lerp(
        successKorMeaningShadow,
        other.successKorMeaningShadow,
        t,
      )!,
      pronunciationStrokeBlendGreen: Color.lerp(
        pronunciationStrokeBlendGreen,
        other.pronunciationStrokeBlendGreen,
        t,
      )!,
      pronunciationFillBlendGreen: Color.lerp(
        pronunciationFillBlendGreen,
        other.pronunciationFillBlendGreen,
        t,
      )!,
      quizBubbleBorder: Color.lerp(quizBubbleBorder, other.quizBubbleBorder, t)!,
      quizThumbnailRing: Color.lerp(quizThumbnailRing, other.quizThumbnailRing, t)!,
      quizTailBorder: Color.lerp(quizTailBorder, other.quizTailBorder, t)!,
    );
  }
}

extension WakeNihongoColorsContext on BuildContext {
  WakeNihongoColors get wnColors {
    final ext = Theme.of(this).extension<WakeNihongoColors>();
    assert(ext != null, 'ThemeData.extensions에 WakeNihongoColors를 등록하세요.');
    return ext!;
  }
}
