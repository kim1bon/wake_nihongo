import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'app_palette.dart';
import 'wake_nihongo_colors.dart';

/// 앱 전역 [ThemeData] 조립. 색 변경은 주로 [AppPalette]·[WakeNihongoColors]만 수정하면 됩니다.
abstract final class AppTheme {
  static ThemeData light() {
    final wn = WakeNihongoColors.light();
    final scheme = AppPalette.lightScheme;
    final baseTextTheme = Typography.material2021(colorScheme: scheme).black;
    final textTheme = baseTextTheme.apply(
      fontFamily: AppFonts.korean,
      fontFamilyFallback: AppFonts.fallbackAfterKorean,
    );
    final primaryTextTheme = Typography.material2021(colorScheme: scheme).white.apply(
      fontFamily: AppFonts.korean,
      fontFamilyFallback: AppFonts.fallbackAfterKorean,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: AppFonts.korean,
      fontFamilyFallback: AppFonts.fallbackAfterKorean,
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      scaffoldBackgroundColor: AppPalette.beigeSoft,
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.beigeSoft,
        foregroundColor: AppPalette.navy,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppPalette.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppPalette.beigeContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: AppPalette.green.withValues(alpha: 0.24),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppPalette.navy.withValues(alpha: 0.10),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppPalette.navy.withValues(alpha: 0.88),
        textColor: AppPalette.navy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.beigeContainer,
        selectedColor: AppPalette.greenContainer,
        secondarySelectedColor: AppPalette.greenContainer,
        side: BorderSide(color: AppPalette.navy.withValues(alpha: 0.18)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: AppPalette.navy,
          fontWeight: FontWeight.w600,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppPalette.green.withValues(alpha: 0.18);
            }
            return AppPalette.beigeContainer;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? AppPalette.navy
                : AppPalette.navy.withValues(alpha: 0.86);
          }),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? AppPalette.green.withValues(alpha: 0.54)
                  : AppPalette.navy.withValues(alpha: 0.18),
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[wn],
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.beigeSoft,
        indicatorColor: wn.navigationBarIndicator,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  /// 일본어 표기(가나·한자)를 JP 서브셋 우선으로 쓸 때 하위 트리에 적용.
  static ThemeData japanesePrimary(ThemeData base) {
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: AppFonts.japanese,
        fontFamilyFallback: AppFonts.fallbackAfterJapanese,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: AppFonts.japanese,
        fontFamilyFallback: AppFonts.fallbackAfterJapanese,
      ),
    );
  }
}
