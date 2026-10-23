import 'package:flutter/material.dart';
import '../theme/jarvis_colors.dart';
import '../theme/jarvis_text_styles.dart';

class JarvisGuidanceDisplay extends StatefulWidget {
  final String text;

  const JarvisGuidanceDisplay({super.key, required this.text});

  @override
  State<JarvisGuidanceDisplay> createState() => _JarvisGuidanceDisplayState();
}

class _JarvisGuidanceDisplayState extends State<JarvisGuidanceDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  String _displayed = '';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _durationFor(widget.text),
    );
    _ctrl.addListener(_onTick);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(JarvisGuidanceDisplay old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _ctrl.duration = _durationFor(widget.text);
      _ctrl.reset();
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTick);
    _ctrl.dispose();
    super.dispose();
  }

  Duration _durationFor(String t) =>
      Duration(milliseconds: (t.length * 35).clamp(200, 1200));

  void _onTick() {
    final chars = (_ctrl.value * widget.text.length).round();
    final next = widget.text.substring(0, chars.clamp(0, widget.text.length));
    if (next != _displayed) {
      setState(() => _displayed = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: JarvisColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: JarvisColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: JarvisColors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Blinking cursor prefix
          _BlinkingCursor(),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _displayed.toUpperCase(),
              style: JarvisTextStyles.guidance,
              textAlign: TextAlign.left,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
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
      builder: (_, __) => Opacity(
        opacity: _ctrl.value > 0.5 ? 1.0 : 0.0,
        child: Container(
          width: 2,
          height: 12,
          color: JarvisColors.primary,
        ),
      ),
    );
  }
}
