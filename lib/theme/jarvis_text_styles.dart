import 'package:flutter/material.dart';
import 'jarvis_colors.dart';

class JarvisTextStyles {
  JarvisTextStyles._();

  static const String _mono = 'Courier New';

  static const TextStyle hudLabel = TextStyle(
    fontFamily: _mono,
    color: JarvisColors.textSecondary,
    fontSize: 9,
    letterSpacing: 2.5,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static const TextStyle hudValue = TextStyle(
    fontFamily: _mono,
    color: JarvisColors.primary,
    fontSize: 13,
    letterSpacing: 1.5,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle scoreDisplay = TextStyle(
    fontFamily: _mono,
    color: JarvisColors.primary,
    fontSize: 26,
    letterSpacing: 1,
    fontWeight: FontWeight.w700,
    height: 1,
  );

  static const TextStyle guidance = TextStyle(
    fontFamily: _mono,
    color: JarvisColors.textPrimary,
    fontSize: 12,
    letterSpacing: 1.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle modeActive = TextStyle(
    fontFamily: _mono,
    color: JarvisColors.gold,
    fontSize: 11,
    letterSpacing: 2.5,
    fontWeight: FontWeight.w700,
    height: 1,
  );

  static const TextStyle modeInactive = TextStyle(
    fontFamily: _mono,
    color: JarvisColors.textDim,
    fontSize: 10,
    letterSpacing: 2,
    fontWeight: FontWeight.w400,
    height: 1,
  );

  static const TextStyle systemTitle = TextStyle(
    fontFamily: _mono,
    color: JarvisColors.primary,
    fontSize: 11,
    letterSpacing: 4,
    fontWeight: FontWeight.w700,
    height: 1,
  );

  static const TextStyle statusText = TextStyle(
    fontFamily: _mono,
    color: JarvisColors.textSecondary,
    fontSize: 8,
    letterSpacing: 2,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static const TextStyle metricValue = TextStyle(
    fontFamily: _mono,
    color: JarvisColors.primary,
    fontSize: 11,
    letterSpacing: 1,
    fontWeight: FontWeight.w600,
  );
}
