import 'package:flutter/material.dart';

/// 앱 브랜드 **원색·그라데이션·ColorScheme**의 단일 정의.
/// 화면 위젯에서는 가능하면 [Theme.of] / [WakeNihongoColors] 시맨틱 토큰을 우선 사용하세요.
abstract final class AppPalette {
  // ——— 브랜드 원색 ———
  static const Color navy = Color(0xFF212A39);
  static const Color navyDeep = Color(0xFF1A2230);
  static const Color navyMuted = Color(0xFF2F3D52);

  static const Color beige = Color(0xFFE6C9A8);
  static const Color beigeSoft = Color(0xFFF7F0E6);
  static const Color beigeContainer = Color(0xFFF0E4D6);

  static const Color green = Color(0xFF4D7568);
  static const Color greenLight = Color(0xFF6D9A89);
  static const Color greenContainer = Color(0xFFD4E8DF);

  static const Color onPrimaryForeground = Color(0xFFFDFBF7);
  static const Color error = Color(0xFFB3261E);
  static const Color onSurfaceVariantTone = Color(0xFF4A5568);
  static const Color surfaceContainerHighestTone = Color(0xFFE8DFD2);

  // ——— 전역 라이트 ColorScheme ———
  static ColorScheme get lightScheme => ColorScheme.fromSeed(
        seedColor: navy,
        brightness: Brightness.light,
        primary: navy,
        onPrimary: onPrimaryForeground,
        secondary: green,
        onSecondary: Colors.white,
        tertiary: beige,
        onTertiary: navy,
        surface: beigeSoft,
        error: error,
      ).copyWith(
        primaryContainer: navyMuted,
        onPrimaryContainer: beige,
        secondaryContainer: greenContainer,
        onSecondaryContainer: navy,
        tertiaryContainer: beigeContainer,
        onTertiaryContainer: navy,
        surfaceContainerHighest: surfaceContainerHighestTone,
        onSurface: navy,
        onSurfaceVariant: onSurfaceVariantTone,
        outline: navy.withValues(alpha: 0.30),
        outlineVariant: beige.withValues(alpha: 0.45),
        surfaceTint: green.withValues(alpha: 0.22),
      );

  // ——— 화면 전용 그라데이션 ———
  static LinearGradient get alarmRingScrim => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(navy, green, 0.14)!.withValues(alpha: 0.50),
          navy.withValues(alpha: 0.58),
          navyDeep.withValues(alpha: 0.52),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  static LinearGradient get quizSuccessScrim => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(navy, green, 0.12)!.withValues(alpha: 0.80),
          navy.withValues(alpha: 0.82),
          Color.lerp(navyDeep, green, 0.08)!.withValues(alpha: 0.78),
        ],
        stops: const [0.0, 0.55, 1.0],
      );
}
