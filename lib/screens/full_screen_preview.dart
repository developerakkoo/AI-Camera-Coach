import 'dart:io';
import 'package:flutter/material.dart';
import '../painters/jarvis_hex_grid_painter.dart';
import '../painters/jarvis_hud_border_painter.dart';
import '../theme/jarvis_colors.dart';
import '../theme/jarvis_text_styles.dart';

class FullScreenPreview extends StatefulWidget {
  final String imagePath;

  const FullScreenPreview({super.key, required this.imagePath});

  @override
  State<FullScreenPreview> createState() => _FullScreenPreviewState();
}

class _FullScreenPreviewState extends State<FullScreenPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanCtrl;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisColors.background,
      body: Stack(
        children: [
          // Hex grid background
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: const JarvisHexGridPainter(opacity: 0.04),
              ),
            ),
          ),

          // Photo with reveal animation
          Center(
            child: AnimatedBuilder(
              animation: _scanCtrl,
              builder: (_, child) {
                return ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: _scanCtrl.value,
                    child: child,
                  ),
                );
              },
              child: Hero(
                tag: 'lastPhoto',
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: JarvisColors.primary.withValues(alpha: 0.4),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: JarvisColors.primary.withValues(alpha: 0.18),
                        blurRadius: 24,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // Scan line that sweeps during reveal
          AnimatedBuilder(
            animation: _scanCtrl,
            builder: (_, __) {
              if (_scanCtrl.value >= 1.0) return const SizedBox.shrink();
              final screenH = MediaQuery.of(context).size.height;
              final y = _scanCtrl.value * screenH;
              return Positioned(
                top: y,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        JarvisColors.primary.withValues(alpha: 0.8),
                        JarvisColors.primary,
                        JarvisColors.primary.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: JarvisColors.primary.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // HUD border
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: const JarvisHudBorderPainter(),
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    _HudButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CAPTURE ANALYSIS',
                            style: JarvisTextStyles.systemTitle),
                        const SizedBox(height: 2),
                        Text(
                          'VISUAL RECORD — CLASSIFIED',
                          style: JarvisTextStyles.statusText,
                        ),
                      ],
                    ),
                    const Spacer(),
                    _HudButton(
                      icon: Icons.share_outlined,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HudButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: JarvisColors.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: JarvisColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: JarvisColors.primary.withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: JarvisColors.primary, size: 18),
      ),
    );
  }
}
