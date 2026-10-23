import 'dart:ui';
import 'lighting_analyzer.dart';

/// All inputs the controller needs for one decision cycle.
class AutoCameraInput {
  final Rect faceRect;
  final Size imageSize;

  final double currentZoom;
  final double minZoom;
  final double maxZoom;

  final double currentEV;
  final double minEV;
  final double maxEV;
  final double evStep;

  /// 0–255 raw luminance of face pixels (from LightingAnalyzer).
  final double faceBrightness;
  /// 0–255 raw luminance of background pixels (from LightingAnalyzer).
  final double backgroundBrightness;
  final LightingQuality lightingQuality;

  /// Frames the face has been stable without moving.
  final int stableFrames;
  /// Overall aesthetic score 0–100.
  final int overallScore;
  /// ML Kit smile probability 0.0–1.0 (null if not available).
  final double? smileProbability;

  const AutoCameraInput({
    required this.faceRect,
    required this.imageSize,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.currentEV,
    required this.minEV,
    required this.maxEV,
    required this.evStep,
    required this.faceBrightness,
    required this.backgroundBrightness,
    required this.lightingQuality,
    required this.stableFrames,
    required this.overallScore,
    this.smileProbability,
  });
}

/// What the controller recommends applying this cycle.
class AutoCameraOutput {
  /// Recommended absolute zoom level. Null = no change needed.
  final double? zoomTarget;
  /// Recommended absolute EV offset. Null = no change needed.
  final double? evTarget;

  /// Short human-readable status shown in JARVIS HUD.
  final String zoomLabel;
  final String evLabel;
  /// One-line reason (for debug / guidance text override).
  final String reason;

  const AutoCameraOutput({
    this.zoomTarget,
    this.evTarget,
    required this.zoomLabel,
    required this.evLabel,
    this.reason = '',
  });
}

class AutoCameraController {
  // ── Zoom tuning ────────────────────────────────────────────────────────────
  /// Ideal face-height / frame-height ratio for portrait (35–50 % is flattering).
  static const double _targetFaceRatio = 0.42;
  /// Don't nudge zoom if ratio is within this band.
  static const double _zoomDeadband = 0.07;
  /// Maximum zoom change per decision cycle.
  static const double _zoomMaxStep = 0.07;

  // ── EV tuning ──────────────────────────────────────────────────────────────
  /// Target face brightness (0–255). ~115 is film-portrait ideal: rich but not
  /// blown out. Slightly under 128 preserves skin texture.
  static const double _targetBrightness = 115.0;
  /// Don't nudge EV if brightness is within ±this.
  static const double _evBrightnessDeadband = 14.0;
  /// Backlight ratio: if background is this much brighter than face, treat as
  /// backlit and boost EV more aggressively.
  static const double _backlightRatio = 1.55;

  // ── Stability gates ────────────────────────────────────────────────────────
  /// Minimum stable frames before we touch anything.
  static const int _minStableFrames = 6;

  AutoCameraOutput compute(AutoCameraInput i) {
    // ── Gate: face must be stable ──────────────────────────────────────────
    if (i.stableFrames < _minStableFrames) {
      return const AutoCameraOutput(
        zoomLabel: 'TRACKING',
        evLabel: 'HOLD',
        reason: 'Face not stable',
      );
    }

    // ── Gate: don't disturb a smiling subject ─────────────────────────────
    final smiling = (i.smileProbability ?? 0) > 0.72;

    // ── 1. Zoom decision ───────────────────────────────────────────────────
    final double? zoomTarget;
    final String zoomLabel;
    final String zoomReason;

    final faceRatio = i.faceRect.height / i.imageSize.height;
    final ratioDelta = faceRatio - _targetFaceRatio;

    if (ratioDelta.abs() <= _zoomDeadband || smiling) {
      // Within deadband or subject smiling — hold zoom
      zoomTarget = null;
      zoomLabel = '${i.currentZoom.toStringAsFixed(1)}x';
      zoomReason = smiling ? 'Smile locked' : 'Zoom optimal';
    } else {
      // Zoom out if face too large, zoom in if too small
      final direction = ratioDelta > 0 ? -1.0 : 1.0;
      final step = _zoomMaxStep * _urgency(ratioDelta.abs(), _zoomDeadband, 0.25);
      final proposed =
          (i.currentZoom + direction * step).clamp(i.minZoom, i.maxZoom);

      if ((proposed - i.currentZoom).abs() < 0.01) {
        zoomTarget = null;
        zoomLabel = '${i.currentZoom.toStringAsFixed(1)}x';
        zoomReason = 'At zoom limit';
      } else {
        zoomTarget = proposed;
        final arrow = direction > 0 ? '↑' : '↓';
        zoomLabel = 'AUTO $arrow ${proposed.toStringAsFixed(1)}x';
        zoomReason = direction > 0 ? 'Face too small' : 'Face too large';
      }
    }

    // ── 2. EV decision ─────────────────────────────────────────────────────
    final double? evTarget;
    final String evLabel;
    final String evReason;

    if (i.minEV == i.maxEV) {
      // Camera doesn't support manual EV
      evTarget = null;
      evLabel = 'N/A';
      evReason = 'EV not supported';
    } else {
      // Backlight compensation: if background >> face, we need more exposure
      final isBacklit = i.backgroundBrightness > i.faceBrightness * _backlightRatio;
      final effectiveTarget = isBacklit ? _targetBrightness + 25 : _targetBrightness;

      final brightnessDelta = effectiveTarget - i.faceBrightness;

      if (brightnessDelta.abs() <= _evBrightnessDeadband) {
        evTarget = null;
        final sign = i.currentEV >= 0 ? '+' : '';
        evLabel = 'EV $sign${i.currentEV.toStringAsFixed(1)}';
        evReason = 'Exposure optimal';
      } else {
        // Map brightness error → EV change
        // 255 brightness range → full EV range
        final evRange = i.maxEV - i.minEV;
        final rawEvDelta = (brightnessDelta / 255.0) * evRange;

        // Scale by urgency, cap at ±0.5 EV per step
        final urgency = _urgency(brightnessDelta.abs(), _evBrightnessDeadband, 80.0);
        final cappedDelta = rawEvDelta.clamp(-0.5, 0.5) * urgency;

        final step = i.evStep > 0 ? i.evStep : 0.1;
        final rawProposed = i.currentEV + cappedDelta;
        final proposed = ((rawProposed / step).round() * step)
            .clamp(i.minEV, i.maxEV);

        if ((proposed - i.currentEV).abs() < step * 0.5) {
          evTarget = null;
          final sign = i.currentEV >= 0 ? '+' : '';
          evLabel = 'EV $sign${i.currentEV.toStringAsFixed(1)}';
          evReason = 'EV step too small';
        } else {
          evTarget = proposed;
          final sign = proposed >= 0 ? '+' : '';
          evLabel = isBacklit
              ? 'AUTO EV $sign${proposed.toStringAsFixed(1)} ☀'
              : 'AUTO EV $sign${proposed.toStringAsFixed(1)}';
          evReason = isBacklit
              ? 'Backlight compensation'
              : brightnessDelta > 0
                  ? 'Face underexposed'
                  : 'Face overexposed';
        }
      }
    }

    return AutoCameraOutput(
      zoomTarget: zoomTarget,
      evTarget: evTarget,
      zoomLabel: zoomLabel,
      evLabel: evLabel,
      reason: [zoomReason, evReason].where((s) => s.isNotEmpty).join(' · '),
    );
  }

  /// Returns 0→1 scaling based on how far beyond the deadband the error is.
  /// [error] = absolute error, [deadband] = minimum before acting,
  /// [fullScale] = error at which urgency hits 1.0.
  double _urgency(double error, double deadband, double fullScale) {
    if (error <= deadband) return 0;
    return ((error - deadband) / (fullScale - deadband)).clamp(0.0, 1.0);
  }
}
