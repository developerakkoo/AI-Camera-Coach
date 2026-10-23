import 'package:flutter/material.dart';
import '../painters/jarvis_arc_painter.dart';
import '../services/lighting_analyzer.dart';
import '../theme/jarvis_colors.dart';
import '../theme/jarvis_text_styles.dart';

class JarvisLightingRing extends StatelessWidget {
  final LightingQuality quality;
  final double size;

  const JarvisLightingRing({
    super.key,
    required this.quality,
    this.size = 72,
  });

  Color get _color {
    switch (quality) {
      case LightingQuality.good:
        return JarvisColors.good;
      case LightingQuality.okay:
        return JarvisColors.warning;
      case LightingQuality.poor:
        return JarvisColors.critical;
    }
  }

  double get _progress {
    switch (quality) {
      case LightingQuality.good:
        return 1.0;
      case LightingQuality.okay:
        return 0.55;
      case LightingQuality.poor:
        return 0.2;
    }
  }

  String get _label {
    switch (quality) {
      case LightingQuality.good:
        return 'GOOD';
      case LightingQuality.okay:
        return 'OKAY';
      case LightingQuality.poor:
        return 'POOR';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: _progress),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (_, p, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: JarvisArcPainter(
                  progress: p,
                  arcColor: _color,
                  strokeWidth: 3,
                  startAngleDeg: 135,
                  sweepDeg: 270,
                  showTicks: false,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wb_sunny_outlined,
                    color: _color,
                    size: size * 0.26,
                    shadows: [
                      Shadow(
                        color: _color.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _label,
                    style: JarvisTextStyles.hudLabel.copyWith(
                      color: _color,
                      fontSize: size * 0.1,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
