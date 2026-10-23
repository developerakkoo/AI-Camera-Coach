import 'package:flutter/material.dart';
import 'package:my_ai_camera_guide/services/lighting_analyzer.dart';

class LightingIndicator extends StatelessWidget {
  final LightingQuality quality;

  const LightingIndicator({super.key, required this.quality});

  Color getColor() {
    switch (quality) {
      case LightingQuality.good:
        return Colors.greenAccent;
      case LightingQuality.okay:
        return Colors.orangeAccent;
      case LightingQuality.poor:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: getColor(),
          width: 4,
        ),
      ),
    );
  }
}