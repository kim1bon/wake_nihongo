import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 1080x2340 디자인 기준(약 390x844 logical size)을 바탕으로 한 전역 반응형 스케일.
extension ResponsiveX on BuildContext {
  static const double _baseWidth = 390;
  static const double _baseHeight = 844;

  Size get _size => MediaQuery.sizeOf(this);

  double get _widthScale => (_size.width / _baseWidth).clamp(0.85, 1.2);
  double get _heightScale => (_size.height / _baseHeight).clamp(0.85, 1.2);
  double get _minScale => math.min(_widthScale, _heightScale);

  double w(double value) => value * _widthScale;
  double h(double value) => value * _heightScale;
  double r(double value) => value * _minScale;

  /// font scaling: 접근성을 해치지 않도록 완만한 최소 스케일 기준.
  double sp(double value) => value * _minScale;
}

