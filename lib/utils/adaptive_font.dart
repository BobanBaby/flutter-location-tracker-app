import 'dart:ui';
import 'package:flutter/material.dart';

class AdaptiveFont {
  /// Calculate fluid adaptive font size based on screen width
  /// Baseline width = 390px (e.g. iPhone 13/14 or modern Android)
  static double get(BuildContext context, double baseSize) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scale = clampDouble(screenWidth / 390.0, 0.85, 1.25);
    return baseSize * scale;
  }
}
