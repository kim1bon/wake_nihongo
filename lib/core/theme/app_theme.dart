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
