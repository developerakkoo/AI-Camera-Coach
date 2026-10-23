import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/jarvis_colors.dart';

class JarvisCaptureButton extends StatefulWidget {
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final bool isBursting;
  final int burstCount;

  const JarvisCaptureButton({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.isBursting = false,
    this.burstCount = 0,
  });

  @override
  State<JarvisCaptureButton> createState() => _JarvisCaptureButtonState();
}

class _JarvisCaptureButtonState extends State<JarvisCaptureButton>
    with TickerProviderStateMixin {
  late AnimationController _rotateCtrl;
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _pressCtrl.forward();
  void _onTapUp(TapUpDetails _) => _pressCtrl.reverse();
  void _onTapCancel() => _pressCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.isBursting ? null : widget.onPressed,
      onLongPress: widget.isBursting ? null : widget.onLongPress,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotateCtrl, _pressCtrl]),
        builder: (_, __) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating outer ring
                  Transform.rotate(
                    angle: _rotateCtrl.value * 2 * pi,
                    child: CustomPaint(
                      size: const Size(88, 88),
                      painter: _RotatingRingPainter(),
                    ),
                  ),

                  // Static middle ring with glow
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: JarvisColors.primary.withValues(alpha: 0.6),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: JarvisColors.primary.withValues(alpha: 0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),

                  // Arc reactor core
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: JarvisColors.surface,
                      border: Border.all(
                        color: widget.isBursting
                            ? JarvisColors.gold
                            : JarvisColors.primaryDim,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isBursting
                                  ? JarvisColors.gold
                                  : JarvisColors.primary)
                              .withValues(alpha: 0.5 + _pressCtrl.value * 0.4),
                          blurRadius: 16 + _pressCtrl.value * 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.isBursting
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${widget.burstCount}',
                                  style: const TextStyle(
                                    fontFamily: 'Courier New',
                                    color: JarvisColors.gold,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                ),
                                const Text(
                                  '/5',
                                  style: TextStyle(
                                    fontFamily: 'Courier New',
                                    color: JarvisColors.goldDim,
                                    fontSize: 9,
                                    height: 1,
                                  ),
                                ),
                              ],
                            )
                          : CustomPaint(
                              size: const Size(32, 32),
                              painter: _ArcReactorCorePainter(
                                glowIntensity: _pressCtrl.value,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RotatingRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    const segments = 24;
    const gapFraction = 0.3;

    for (int i = 0; i < segments; i++) {
      final start = (i / segments) * 2 * pi - pi / 2;
      final sweep = (1 - gapFraction) / segments * 2 * pi;
      final isMajor = i % 6 == 0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        Paint()
          ..color = isMajor
              ? JarvisColors.primary.withValues(alpha: 0.7)
              : JarvisColors.primaryDim.withValues(alpha: 0.3)
          ..strokeWidth = isMajor ? 2 : 1
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RotatingRingPainter old) => false;
}

class _ArcReactorCorePainter extends CustomPainter {
  final double glowIntensity;

  const _ArcReactorCorePainter({required this.glowIntensity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseColor = Color.lerp(
      JarvisColors.primary,
      Colors.white,
      glowIntensity * 0.6,
    )!;

    // Outer glow circle
    canvas.drawCircle(
      center,
      size.width / 2,
      Paint()
        ..color = baseColor.withValues(alpha: 0.15 + glowIntensity * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Triangle segments (arc reactor style)
    const segments = 3;
    for (int i = 0; i < segments; i++) {
      final angle = (i / segments) * 2 * pi - pi / 2;
      final path = Path();
      const innerR = 5.0;
      const outerR = 13.0;
      const halfAngle = pi / 8;

      path.moveTo(
        center.dx + innerR * cos(angle - halfAngle),
        center.dy + innerR * sin(angle - halfAngle),
      );
      path.lineTo(
        center.dx + outerR * cos(angle),
        center.dy + outerR * sin(angle),
      );
      path.lineTo(
        center.dx + innerR * cos(angle + halfAngle),
        center.dy + innerR * sin(angle + halfAngle),
      );
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = baseColor.withValues(alpha: 0.7 + glowIntensity * 0.3)
          ..style = PaintingStyle.fill,
      );
    }

    // Center dot
    canvas.drawCircle(
      center,
      4,
      Paint()
        ..color = baseColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + glowIntensity * 4),
    );
    canvas.drawCircle(
      center,
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_ArcReactorCorePainter old) =>
      old.glowIntensity != glowIntensity;
}
