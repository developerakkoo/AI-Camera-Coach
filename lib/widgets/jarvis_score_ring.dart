import 'package:flutter/material.dart';
import '../painters/jarvis_arc_painter.dart';
import '../theme/jarvis_colors.dart';
import '../theme/jarvis_text_styles.dart';

class JarvisScoreRing extends StatelessWidget {
  final int score;
  final double size;

  const JarvisScoreRing({
    super.key,
    required this.score,
    this.size = 88,
  });

  Color get _scoreColor {
    if (score >= 80) return JarvisColors.good;
    if (score >= 50) return JarvisColors.warning;
    return JarvisColors.critical;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (score / 100.0).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, animProgress, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Arc ring
              CustomPaint(
                size: Size(size, size),
                painter: JarvisArcPainter(
                  progress: animProgress,
                  strokeWidth: 4,
                  startAngleDeg: 135,
                  sweepDeg: 270,
                  showTicks: true,
                ),
              ),

              // Score label
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score.toString().padLeft(2, '0'),
                    style: JarvisTextStyles.scoreDisplay.copyWith(
                      color: _scoreColor,
                      fontSize: size * 0.28,
                      shadows: [
                        Shadow(
                          color: _scoreColor.withValues(alpha: 0.6),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'SCORE',
                    style: JarvisTextStyles.hudLabel.copyWith(
                      fontSize: size * 0.09,
                      letterSpacing: 2,
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
