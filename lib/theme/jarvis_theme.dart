import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'jarvis_colors.dart';

class JarvisTheme {
  JarvisTheme._();

  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: JarvisColors.background,
      colorScheme: const ColorScheme.dark(
        primary: JarvisColors.primary,
        secondary: JarvisColors.gold,
        surface: JarvisColors.surface,
        onPrimary: JarvisColors.background,
        onSecondary: JarvisColors.background,
        onSurface: JarvisColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: JarvisColors.background,
        foregroundColor: JarvisColors.primary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: JarvisColors.surface,
        contentTextStyle: const TextStyle(
          fontFamily: 'Courier New',
          color: JarvisColors.primary,
          fontSize: 12,
          letterSpacing: 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: JarvisColors.border, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: JarvisColors.primary,
        inactiveTrackColor: JarvisColors.border,
        thumbColor: JarvisColors.primary,
        overlayColor: JarvisColors.primary.withValues(alpha: 0.15),
        trackHeight: 1.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
      ),
      iconTheme: const IconThemeData(color: JarvisColors.primary, size: 22),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: JarvisColors.primary,
      ),
    );
  }
}
