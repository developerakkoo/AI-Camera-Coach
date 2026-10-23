import 'package:flutter/material.dart';
import '../theme/jarvis_colors.dart';
import '../theme/jarvis_text_styles.dart';

class JarvisStatusBar extends StatelessWidget {
  final bool faceDetected;
  final bool focusLocked;
  final int cameraIndex;

  const JarvisStatusBar({
    super.key,
    required this.faceDetected,
    required this.focusLocked,
    required this.cameraIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            JarvisColors.background.withValues(alpha: 0.95),
            JarvisColors.background.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // JARVIS branding
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('J.A.R.V.I.S', style: JarvisTextStyles.systemTitle),
              const SizedBox(height: 1),
              Text(
                'VISION SYSTEM v2.0',
                style: JarvisTextStyles.statusText,
              ),
            ],
          ),

          const Spacer(),

          // Status indicators
          _StatusPill(
            label: faceDetected ? 'FACE LOCKED' : 'SCANNING',
            color: faceDetected ? JarvisColors.good : JarvisColors.textSecondary,
            pulse: !faceDetected,
          ),
          const SizedBox(width: 8),
          _StatusPill(
            label: focusLocked ? 'AF LOCKED' : 'AF AUTO',
            color: focusLocked ? JarvisColors.gold : JarvisColors.textDim,
          ),
          const SizedBox(width: 8),
          _StatusPill(
            label: cameraIndex == 0 ? 'FRONT' : 'REAR',
            color: JarvisColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatefulWidget {
  final String label;
  final Color color;
  final bool pulse;

  const _StatusPill({
    required this.label,
    required this.color,
    this.pulse = false,
  });

  @override
  State<_StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<_StatusPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final opacity = widget.pulse ? (0.4 + _ctrl.value * 0.6) : 1.0;
        return Opacity(
          opacity: opacity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.6),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: JarvisTextStyles.statusText.copyWith(
                  color: widget.color,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
