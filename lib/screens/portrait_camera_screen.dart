import 'dart:io';
import 'dart:math' show cos, sin, pi;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/face_detector_service.dart';
import '../services/portrait_guidance_engine.dart';
import '../services/lighting_analyzer.dart';
import '../services/background_analyzer.dart';
import '../services/camera_angle_analyzer.dart';
import '../services/eye_level_analyzer.dart';
import '../services/jawline_analyzer.dart';
import '../services/aesthetic_engine.dart';
import '../services/auto_camera_controller.dart';

import '../painters/jarvis_hex_grid_painter.dart';
import '../painters/jarvis_hud_border_painter.dart';
import '../painters/jarvis_grid_painter.dart';

import '../widgets/jarvis_face_frame.dart';
import '../widgets/jarvis_score_ring.dart';
import '../widgets/jarvis_lighting_ring.dart';
import '../widgets/jarvis_eye_line.dart';
import '../widgets/jarvis_guidance_display.dart';
import '../widgets/jarvis_status_bar.dart';
import '../widgets/jarvis_capture_button.dart';

import '../theme/jarvis_colors.dart';
import '../theme/jarvis_text_styles.dart';
import '../utils/input_image_from_camera_image.dart';
import 'full_screen_preview.dart';

enum CameraUIMode { video, photo, portrait, advanced }

class PortraitCameraScreen extends StatefulWidget {
  const PortraitCameraScreen({super.key});

  @override
  State<PortraitCameraScreen> createState() => _PortraitCameraScreenState();
}

class _PortraitCameraScreenState extends State<PortraitCameraScreen> {
  CameraController? _controller;
  final PageController _pageController = PageController(initialPage: 0);

  final FaceDetectorService _faceService = FaceDetectorService();
  final PortraitGuidanceEngine _guidanceEngine = PortraitGuidanceEngine();
  final LightingAnalyzer _lightingAnalyzer = LightingAnalyzer();
  final BackgroundAnalyzer _backgroundAnalyzer = BackgroundAnalyzer();
  final CameraAngleAnalyzer _angleAnalyzer = CameraAngleAnalyzer();
  final EyeLevelAnalyzer _eyeAnalyzer = EyeLevelAnalyzer();
  final JawlineAnalyzer _jawAnalyzer = JawlineAnalyzer();
  final AestheticEngine _aestheticEngine = AestheticEngine();
  final AutoCameraController _autoCam = AutoCameraController();

  List<Face> _faces = [];
  bool _isDetecting = false;
  bool _flash = false;
  int _frameCount = 0;
  static const int _frameSkip = 3;

  int _score = 0;
  String _guidanceText = 'POSITION FACE IN FRAME';
  File? _lastImage;
  String? _cameraError;

  // Feature state
  bool _showGrid = false;
  bool _isBursting = false;
  int _burstCount = 0;
  bool _showCapturedStamp = false;
  String _capturedStampText = 'CAPTURED';

  // Auto camera state
  bool _autoCamEnabled = true;
  int _autoThrottle = 0;
  static const int _autoEvery = 12; // apply every N processed frames (~1.2 s)
  String _autoZoomLabel = 'AUTO';
  String _autoEvLabel = 'AUTO';
  String _autoReason = '';

  double _minExposureOffset = 0;
  double _maxExposureOffset = 0;
  double _exposureStep = 0.5;
  double _currentExposureOffset = 0;
  bool _exposureSupported = false;

  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _isSwitchingCamera = false;

  bool _focusLocked = false;
  int _stableFaceFrames = 0;
  Offset? _lastFaceCenter;
  static const int _stableFramesToLock = 12;
  static const double _faceMoveThreshold = 0.06;

  CameraUIMode _selectedMode = CameraUIMode.portrait;
  final List<CameraUIMode> _modeOrder = const [
    CameraUIMode.video,
    CameraUIMode.photo,
    CameraUIMode.portrait,
    CameraUIMode.advanced,
  ];

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadLastPhoto();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _cameraError = 'NO CAMERA HARDWARE DETECTED');
        }
        return;
      }
      _cameras = cameras;
      final frontIndex =
          cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      _cameraIndex = frontIndex >= 0 ? frontIndex : 0;

      final imageFormat = Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888;

      _controller = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: imageFormat,
      );

      try {
        await _controller!.initialize();
      } catch (_) {
        if (Platform.isAndroid) {
          await _controller?.dispose();
          _controller = CameraController(
            _cameras[_cameraIndex],
            ResolutionPreset.max,
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.yuv420,
          );
          await _controller!.initialize();
        } else {
          rethrow;
        }
      }

      await _loadExposureRange();
      await _loadZoomRange();
      await _applyFocusMode();
      await _controller!.startImageStream(_processCameraImage);
      if (mounted) setState(() => _cameraError = null);
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = e.toString().toUpperCase());
      }
    }
  }

  Future<void> _applyFocusMode() async {
    try {
      await _controller?.setFocusMode(FocusMode.auto);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_controller == null || _cameras.length < 2 || _isSwitchingCamera) return;
    setState(() => _isSwitchingCamera = true);
    try {
      await _controller!.stopImageStream();
      final nextIndex = (_cameraIndex + 1) % _cameras.length;
      await _controller!.setDescription(_cameras[nextIndex]);
      _cameraIndex = nextIndex;
      await _loadExposureRange();
      await _loadZoomRange();
      await _controller!.setExposureOffset(
          _currentExposureOffset.clamp(_minExposureOffset, _maxExposureOffset));
      await _controller!.setZoomLevel(_currentZoom.clamp(_minZoom, _maxZoom));
      await _applyFocusMode();
      await _controller!.startImageStream(_processCameraImage);
    } catch (_) {}
    if (mounted) setState(() => _isSwitchingCamera = false);
  }

  Future<void> _loadExposureRange() async {
    try {
      final min = await _controller!.getMinExposureOffset();
      final max = await _controller!.getMaxExposureOffset();
      final step = await _controller!.getExposureOffsetStepSize();
      if (mounted) {
        setState(() {
          _minExposureOffset = min;
          _maxExposureOffset = max;
          _exposureStep = step > 0 ? step : 0.5;
          _exposureSupported = (max - min).abs() > 0.001;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _exposureSupported = false);
    }
  }

  Future<void> _loadZoomRange() async {
    try {
      final min = await _controller!.getMinZoomLevel();
      final max = await _controller!.getMaxZoomLevel();
      if (mounted) {
        setState(() {
          _minZoom = min;
          _maxZoom = max;
          _currentZoom = _currentZoom.clamp(_minZoom, _maxZoom);
        });
      }
    } catch (_) {}
  }

  Future<void> _setExposure(double value) async {
    if (_controller == null || !_exposureSupported) return;
    final step = _exposureStep;
    final rounded = (value / step).round() * step;
    final clamped = rounded.clamp(_minExposureOffset, _maxExposureOffset);
    try {
      final actual = await _controller!.setExposureOffset(clamped);
      if (mounted) setState(() => _currentExposureOffset = actual);
    } catch (_) {}
  }

  Future<void> _setZoom(double value) async {
    if (_controller == null) return;
    final clamped = value.clamp(_minZoom, _maxZoom);
    try {
      await _controller!.setZoomLevel(clamped);
      if (mounted) setState(() => _currentZoom = clamped);
    } catch (_) {}
  }

  Future<void> _setManualFocusLock(bool lock) async {
    if (_controller == null) return;
    try {
      await _controller!
          .setFocusMode(lock ? FocusMode.locked : FocusMode.auto);
      if (mounted) setState(() => _focusLocked = lock);
    } catch (_) {}
  }

  bool get _isPortraitMode => _selectedMode == CameraUIMode.portrait;
  bool get _isAdvancedMode => _selectedMode == CameraUIMode.advanced;

  String _modeLabel(CameraUIMode mode) {
    switch (mode) {
      case CameraUIMode.video:
        return 'VIDEO';
      case CameraUIMode.photo:
        return 'PHOTO';
      case CameraUIMode.portrait:
        return 'PORTRAIT';
      case CameraUIMode.advanced:
        return 'ADVANCED';
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('// FEATURE LOCKED — COMING SOON'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> _onModeSelected(CameraUIMode mode) async {
    if (mode == CameraUIMode.video || mode == CameraUIMode.photo) {
      _showComingSoon();
      return;
    }
    if (_selectedMode == mode) return;
    final wasPortrait = _isPortraitMode;
    setState(() => _selectedMode = mode);

    if (wasPortrait && mode == CameraUIMode.advanced) {
      _stableFaceFrames = 0;
      _lastFaceCenter = null;
      if (_focusLocked) await _setManualFocusLock(false);
      if (mounted) {
        setState(() {
          _faces = [];
          _guidanceText = 'ADVANCED MODE ACTIVE';
        });
      }
    } else if (mode == CameraUIMode.portrait) {
      await _setManualFocusLock(false);
      if (mounted) setState(() => _guidanceText = 'POSITION FACE IN FRAME');
    }
  }

  Future<void> _loadLastPhoto() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return;
    final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image, onlyAll: true);
    if (albums.isEmpty) return;
    final assets = await albums.first.getAssetListPaged(page: 0, size: 1);
    if (assets.isNotEmpty) {
      final file = await assets.first.file;
      if (file != null && mounted) setState(() => _lastImage = file);
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || _isBursting) return;
    HapticFeedback.mediumImpact();
    await _controller!.stopImageStream();
    setState(() => _flash = true);
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() => _flash = false);
    final file = await _controller!.takePicture();
    await PhotoManager.editor.saveImageWithPath(file.path);
    setState(() => _lastImage = File(file.path));
    await _controller!.startImageStream(_processCameraImage);
    _showCapturedFeedback('CAPTURED');
  }

  Future<void> _captureBurst() async {
    if (_controller == null || _isBursting) return;
    setState(() {
      _isBursting = true;
      _burstCount = 0;
    });

    await _controller!.stopImageStream();
    File? lastFile;

    for (int i = 1; i <= 5; i++) {
      if (!mounted) break;
      setState(() => _burstCount = i);
      HapticFeedback.lightImpact();

      setState(() => _flash = true);
      await Future.delayed(const Duration(milliseconds: 60));
      setState(() => _flash = false);

      final file = await _controller!.takePicture();
      await PhotoManager.editor.saveImageWithPath(file.path);
      lastFile = File(file.path);

      if (i < 5) await Future.delayed(const Duration(milliseconds: 260));
    }

    if (lastFile != null && mounted) setState(() => _lastImage = lastFile);
    await _controller!.startImageStream(_processCameraImage);

    if (mounted) setState(() { _isBursting = false; _burstCount = 0; });
    _showCapturedFeedback('BURST COMPLETE — 5 SHOTS');
  }

  void _showCapturedFeedback(String text) {
    if (!mounted) return;
    setState(() {
      _capturedStampText = text;
      _showCapturedStamp = true;
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showCapturedStamp = false);
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    _frameCount++;
    if (_frameCount % _frameSkip != 0) return;
    if (_isDetecting) return;
    _isDetecting = true;

    final inputImage = InputImageFromCameraImage.build(
      image: image,
      controller: _controller!,
    );
    if (inputImage == null) {
      _isDetecting = false;
      return;
    }

    if (!_isPortraitMode) {
      if (mounted && _faces.isNotEmpty) setState(() => _faces = []);
      _isDetecting = false;
      return;
    }

    final faces = await _faceService.detectFaces(inputImage);

    if (faces.isNotEmpty && _controller != null) {
      final face = faces.first;
      final previewSize = _controller!.value.previewSize!;
      final screenSize = Size(previewSize.height, previewSize.width);

      final rect = face.boundingBox;
      final nx =
          ((rect.left + rect.right) / 2 / image.width).clamp(0.0, 1.0);
      final ny =
          ((rect.top + rect.bottom) / 2 / image.height).clamp(0.0, 1.0);
      final faceCenter = Offset(nx, ny);

      final isStable = _lastFaceCenter != null &&
          (faceCenter - _lastFaceCenter!).distance < _faceMoveThreshold;
      if (isStable) {
        _stableFaceFrames++;
      } else {
        _stableFaceFrames = 0;
        if (_focusLocked) _unlockFocus();
      }
      _lastFaceCenter = faceCenter;

      if (_stableFaceFrames >= _stableFramesToLock && !_focusLocked) {
        _lockFocusAt(faceCenter);
      }

      final framingScore = _guidanceEngine.calculateScore(face, screenSize);
      _lightingAnalyzer.analyze(image, face);
      _backgroundAnalyzer.analyze(image, face);
      _angleAnalyzer.analyze(face);
      _eyeAnalyzer.analyze(face);
      _jawAnalyzer.analyze(face);

      final framingFeedback = _guidanceEngine.generateFeedback(face, screenSize);
      final angleFeedback = _angleAnalyzer.feedback;
      final lightingFeedback = _lightingAnalyzer.feedback;
      final backgroundFeedback = _backgroundAnalyzer.feedback;

      final String guidance;
      if (angleFeedback.isNotEmpty) {
        guidance = angleFeedback;
      } else if (_jawAnalyzer.feedback.isNotEmpty) {
        guidance = _jawAnalyzer.feedback;
      } else if (lightingFeedback.isNotEmpty) {
        guidance = lightingFeedback;
      } else if (backgroundFeedback.isNotEmpty) {
        guidance = backgroundFeedback;
      } else {
        guidance = framingFeedback;
      }

      final combinedScore = _aestheticEngine.calculate(
        framing: framingScore,
        lighting: _lightingAnalyzer.lightingScore,
        eye: _eyeAnalyzer.quality == EyeAlignmentQuality.perfect ? 100 : 60,
        jaw: _jawAnalyzer.quality == JawlineQuality.perfect ? 100 : 70,
        background:
            _backgroundAnalyzer.quality == BackgroundQuality.clean ? 100 : 60,
      );

      if (mounted) {
        setState(() {
          _faces = faces;
          _score = combinedScore;
          _guidanceText = guidance.toUpperCase();
        });
      }

      // ── Auto camera: zoom + EV ──────────────────────────────────────────
      _autoThrottle++;
      if (_autoCamEnabled && _autoThrottle >= _autoEvery) {
        _autoThrottle = 0;
        final result = _autoCam.compute(AutoCameraInput(
          faceRect: face.boundingBox,
          imageSize: Size(image.width.toDouble(), image.height.toDouble()),
          currentZoom: _currentZoom,
          minZoom: _minZoom,
          maxZoom: _maxZoom,
          currentEV: _currentExposureOffset,
          minEV: _minExposureOffset,
          maxEV: _maxExposureOffset,
          evStep: _exposureStep,
          faceBrightness: _lightingAnalyzer.faceBrightness,
          backgroundBrightness: _lightingAnalyzer.backgroundBrightness,
          lightingQuality: _lightingAnalyzer.quality,
          stableFrames: _stableFaceFrames,
          overallScore: combinedScore,
          smileProbability: face.smilingProbability,
        ));

        if (result.zoomTarget != null) _setZoom(result.zoomTarget!);
        if (result.evTarget != null) _setExposure(result.evTarget!);

        if (mounted) {
          setState(() {
            _autoZoomLabel = result.zoomLabel;
            _autoEvLabel = result.evLabel;
            _autoReason = result.reason;
          });
        }
      }
    } else {
      _stableFaceFrames = 0;
      _lastFaceCenter = null;
      if (_focusLocked) _unlockFocus();
      if (mounted) {
        setState(() {
          _faces = faces;
          _guidanceText = 'POSITION FACE IN FRAME';
          _autoZoomLabel = 'SCANNING';
          _autoEvLabel = 'HOLD';
        });
      }
    }

    _isDetecting = false;
  }

  Future<void> _lockFocusAt(Offset pt) async {
    if (_controller == null) return;
    try {
      await _controller!.setFocusPoint(pt);
      await Future.delayed(const Duration(milliseconds: 300));
      await _controller!.setFocusMode(FocusMode.locked);
      if (mounted) setState(() => _focusLocked = true);
    } catch (_) {
      try {
        await _controller!.setFocusMode(FocusMode.locked);
        if (mounted) setState(() => _focusLocked = true);
      } catch (_) {}
    }
  }

  Future<void> _unlockFocus() async {
    if (_controller == null) return;
    try {
      await _controller!.setFocusMode(FocusMode.auto);
      if (mounted) setState(() => _focusLocked = false);
    } catch (_) {}
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null) {
      return _buildErrorScreen(_cameraError!);
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: JarvisColors.background,
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) async {
          if (index == 1) {
            await _controller?.stopImageStream();
          } else {
            await _controller?.startImageStream(_processCameraImage);
          }
        },
        children: [
          _buildCameraPage(),
          _buildPreviewPage(),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: JarvisColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                color: JarvisColors.primary,
                strokeWidth: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'INITIALIZING VISION SYSTEM',
              style: JarvisTextStyles.statusText.copyWith(
                color: JarvisColors.textSecondary,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 6),
            Text('J.A.R.V.I.S', style: JarvisTextStyles.systemTitle),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      backgroundColor: JarvisColors.background,
      body: CustomPaint(
        painter: const _HexBgPainter(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off_outlined,
                    color: JarvisColors.critical, size: 48),
                const SizedBox(height: 20),
                Text(
                  'CAMERA OFFLINE',
                  style: JarvisTextStyles.systemTitle.copyWith(
                    color: JarvisColors.critical,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: JarvisColors.surface,
                    border:
                        Border.all(color: JarvisColors.critical.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    error,
                    textAlign: TextAlign.center,
                    style: JarvisTextStyles.statusText.copyWith(
                      color: JarvisColors.critical.withValues(alpha: 0.8),
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    setState(() => _cameraError = null);
                    _initCamera();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: JarvisColors.primary),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      'RETRY',
                      style: JarvisTextStyles.modeActive.copyWith(
                        color: JarvisColors.primary,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPage() {
    final previewSize = _controller!.value.previewSize!;
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // ── Camera preview ──────────────────────────────────────────────────
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewSize.height,
              height: previewSize.width,
              child: CameraPreview(_controller!),
            ),
          ),
        ),

        // ── Hex grid overlay ────────────────────────────────────────────────
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: const JarvisHexGridPainter(opacity: 0.04),
            ),
          ),
        ),

        // ── Rule of thirds grid ──────────────────────────────────────────────
        if (_showGrid)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: const JarvisGridPainter(),
              ),
            ),
          ),

        // ── Face detection frame ────────────────────────────────────────────
        if (_isPortraitMode)
          Positioned.fill(
            child: IgnorePointer(
              child: JarvisFaceFrame(
                faces: _faces,
                previewSize: Size(previewSize.height, previewSize.width),
                screenSize: screenSize,
                score: _score,
              ),
            ),
          ),

        // ── Eye level line ──────────────────────────────────────────────────
        if (_isPortraitMode) JarvisEyeLine(quality: _eyeAnalyzer.quality),

        // ── Advanced mode: Exposure slider (right) ──────────────────────────
        if (_isAdvancedMode && _exposureSupported)
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(child: _buildExposurePanel()),
          ),

        // ── Advanced mode: Zoom + Focus (left) ──────────────────────────────
        if (_isAdvancedMode)
          Positioned(
            left: 12,
            top: 110,
            bottom: 130,
            child: Center(child: _buildZoomFocusPanel()),
          ),

        // ── Flash overlay ────────────────────────────────────────────────────
        if (_flash)
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 80),
              opacity: 0.9,
              child: Container(color: Colors.white),
            ),
          ),

        // ── HUD border frame ─────────────────────────────────────────────────
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: const JarvisHudBorderPainter(),
            ),
          ),
        ),

        // ── Status bar ───────────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: JarvisStatusBar(
              faceDetected: _faces.isNotEmpty,
              focusLocked: _focusLocked,
              cameraIndex: _cameraIndex,
            ),
          ),
        ),

        // ── Top-right: Score ring ────────────────────────────────────────────
        if (_isPortraitMode)
          Positioned(
            top: 70,
            right: 16,
            child: JarvisScoreRing(score: _score, size: 80),
          ),

        // ── Auto camera HUD panel ────────────────────────────────────────────
        if (_isPortraitMode)
          Positioned(
            top: 160,
            right: 16,
            child: _buildAutoCamPanel(),
          ),

        // ── Top-left: Lighting ring ───────────────────────────────────────────
        if (_isPortraitMode)
          Positioned(
            top: 70,
            left: 16,
            child: JarvisLightingRing(quality: _lightingAnalyzer.quality, size: 64),
          ),

        // ── Grid toggle button ────────────────────────────────────────────────
        Positioned(
          top: 76,
          left: _isPortraitMode ? 92 : 16,
          child: _buildHudIconButton(
            icon: Icon(
              Icons.grid_3x3,
              color: _showGrid ? JarvisColors.gold : JarvisColors.textDim,
              size: 20,
            ),
            onTap: () => setState(() => _showGrid = !_showGrid),
            active: _showGrid,
          ),
        ),

        // ── Auto camera toggle ────────────────────────────────────────────────
        if (_isPortraitMode)
          Positioned(
            top: 76,
            left: _isPortraitMode ? 136 : 60,
            child: _buildHudIconButton(
              icon: Text(
                'AI',
                style: TextStyle(
                  fontFamily: 'Courier New',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _autoCamEnabled
                      ? JarvisColors.primary
                      : JarvisColors.textDim,
                  letterSpacing: 1,
                ),
              ),
              onTap: () => setState(() {
                _autoCamEnabled = !_autoCamEnabled;
                if (!_autoCamEnabled) {
                  _autoZoomLabel = 'MANUAL';
                  _autoEvLabel = 'MANUAL';
                }
              }),
              active: _autoCamEnabled,
            ),
          ),

        // ── Camera switch button ──────────────────────────────────────────────
        if (_cameras.length > 1)
          Positioned(
            top: 76,
            right: _isPortraitMode ? 108 : 16,
            child: _buildHudIconButton(
              icon: _isSwitchingCamera
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: JarvisColors.primary),
                    )
                  : const Icon(Icons.cameraswitch,
                      color: JarvisColors.primary, size: 20),
              onTap: _isSwitchingCamera ? null : _switchCamera,
            ),
          ),

        // ── Captured stamp overlay ────────────────────────────────────────────
        if (_showCapturedStamp)
          Positioned.fill(
            child: IgnorePointer(
              child: _CapturedStamp(text: _capturedStampText),
            ),
          ),

        // ── Last photo thumbnail ──────────────────────────────────────────────
        if (_lastImage != null)
          Positioned(
            bottom: 118,
            left: 24,
            child: _buildPhotoThumbnail(),
          ),

        // ── Guidance text ─────────────────────────────────────────────────────
        if (_isPortraitMode)
          Positioned(
            bottom: 118,
            left: 92,
            right: 24,
            child: JarvisGuidanceDisplay(text: _guidanceText),
          ),

        // ── Bottom bar (shutter + modes) ──────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomBar(),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            JarvisColors.background.withValues(alpha: 0.95),
            JarvisColors.background.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Burst hint label
          if (!_isBursting)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'HOLD FOR BURST',
                style: JarvisTextStyles.statusText.copyWith(
                  color: JarvisColors.textDim,
                  letterSpacing: 2,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'BURST  ${_burstCount}/5',
                style: JarvisTextStyles.statusText.copyWith(
                  color: JarvisColors.gold,
                  letterSpacing: 2,
                ),
              ),
            ),
          // Shutter button
          JarvisCaptureButton(
            onPressed: _capturePhoto,
            onLongPress: _captureBurst,
            isBursting: _isBursting,
            burstCount: _burstCount,
          ),
          const SizedBox(height: 10),
          // Mode selector
          _buildModeSelector(),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: _modeOrder.length,
        separatorBuilder: (_, __) => const SizedBox(width: 24),
        itemBuilder: (context, index) {
          final mode = _modeOrder[index];
          final selected = _selectedMode == mode;
          final unavailable =
              mode == CameraUIMode.video || mode == CameraUIMode.photo;

          return GestureDetector(
            onTap: () => _onModeSelected(mode),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: selected
                      ? JarvisTextStyles.modeActive
                      : JarvisTextStyles.modeInactive.copyWith(
                          color: unavailable
                              ? JarvisColors.textDim.withValues(alpha: 0.5)
                              : JarvisColors.textDim,
                        ),
                  child: Text(_modeLabel(mode)),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 2,
                  width: selected ? 28.0 : 0.0,
                  decoration: BoxDecoration(
                    color: JarvisColors.gold,
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: JarvisColors.gold.withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHudIconButton({
    required Widget icon,
    VoidCallback? onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active
              ? JarvisColors.gold.withValues(alpha: 0.12)
              : JarvisColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: active ? JarvisColors.gold : JarvisColors.border,
            width: 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: JarvisColors.gold.withValues(alpha: 0.3),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Center(child: icon),
      ),
    );
  }

  Widget _buildPhotoThumbnail() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                FullScreenPreview(imagePath: _lastImage!.path),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      },
      child: Hero(
        tag: 'lastPhoto',
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: JarvisColors.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: JarvisColors.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(_lastImage!, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildAutoCamPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: JarvisColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: _autoCamEnabled
              ? JarvisColors.primary.withValues(alpha: 0.5)
              : JarvisColors.border,
          width: 1,
        ),
        boxShadow: _autoCamEnabled
            ? [
                BoxShadow(
                  color: JarvisColors.primary.withValues(alpha: 0.12),
                  blurRadius: 10,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _autoCamEnabled
                      ? JarvisColors.primary
                      : JarvisColors.textDim,
                  boxShadow: _autoCamEnabled
                      ? [
                          BoxShadow(
                            color: JarvisColors.primary.withValues(alpha: 0.7),
                            blurRadius: 4,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _autoCamEnabled ? 'AI AUTO' : 'MANUAL',
                style: JarvisTextStyles.hudLabel.copyWith(
                  color: _autoCamEnabled
                      ? JarvisColors.primary
                      : JarvisColors.textDim,
                  letterSpacing: 2,
                  fontSize: 8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Zoom row
          _AutoRow(
            icon: Icons.zoom_in,
            label: _autoZoomLabel,
            active: _autoCamEnabled && _autoZoomLabel.startsWith('AUTO'),
          ),
          const SizedBox(height: 3),
          // EV row
          _AutoRow(
            icon: Icons.wb_sunny_outlined,
            label: _autoEvLabel,
            active: _autoCamEnabled && _autoEvLabel.startsWith('AUTO'),
          ),
          // Reason (only show when actively adjusting)
          if (_autoCamEnabled && _autoReason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _autoReason,
                style: JarvisTextStyles.statusText.copyWith(
                  color: JarvisColors.textDim,
                  fontSize: 7,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExposurePanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: JarvisColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: JarvisColors.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('EV', style: JarvisTextStyles.hudLabel),
          const SizedBox(height: 4),
          Text(
            '${_currentExposureOffset >= 0 ? '+' : ''}${_currentExposureOffset.toStringAsFixed(1)}',
            style: JarvisTextStyles.metricValue,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: _currentExposureOffset.clamp(
                    _minExposureOffset, _maxExposureOffset),
                min: _minExposureOffset,
                max: _maxExposureOffset,
                divisions: _exposureStep > 0
                    ? ((_maxExposureOffset - _minExposureOffset) / _exposureStep)
                        .round()
                        .clamp(1, 50)
                    : null,
                onChanged: _setExposure,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomFocusPanel() {
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: JarvisColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: JarvisColors.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _setManualFocusLock(!_focusLocked),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: _focusLocked ? JarvisColors.gold : JarvisColors.border,
                  width: 1,
                ),
                color: _focusLocked
                    ? JarvisColors.gold.withValues(alpha: 0.1)
                    : Colors.transparent,
              ),
              child: Icon(
                _focusLocked
                    ? Icons.center_focus_strong
                    : Icons.center_focus_weak,
                color:
                    _focusLocked ? JarvisColors.gold : JarvisColors.textSecondary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('ZOOM', style: JarvisTextStyles.hudLabel),
          const SizedBox(height: 2),
          Text(
            '${_currentZoom.toStringAsFixed(1)}x',
            style: JarvisTextStyles.metricValue,
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 120,
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: _currentZoom.clamp(_minZoom, _maxZoom),
                min: _minZoom,
                max: _maxZoom,
                onChanged: _setZoom,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPage() {
    if (_lastImage == null) {
      return Container(
        color: JarvisColors.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_outlined,
                  color: JarvisColors.textDim, size: 40),
              const SizedBox(height: 12),
              Text(
                'NO CAPTURES ON RECORD',
                style: JarvisTextStyles.statusText.copyWith(
                  color: JarvisColors.textDim,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: JarvisColors.background,
      child: Stack(
        children: [
          // Hex grid background
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: const JarvisHexGridPainter(opacity: 0.03),
              ),
            ),
          ),

          Center(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) =>
                        FullScreenPreview(imagePath: _lastImage!.path),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
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
                        color: JarvisColors.primary.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Image.file(_lastImage!, fit: BoxFit.contain),
                ),
              ),
            ),
          ),

          // HUD border
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: const JarvisHudBorderPainter(),
              ),
            ),
          ),

          // Back button
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
                    _buildHudIconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: JarvisColors.primary, size: 18),
                      onTap: () => _pageController.animateToPage(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'LAST CAPTURE',
                      style: JarvisTextStyles.systemTitle,
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

// ── Auto camera row widget ─────────────────────────────────────────────────

class _AutoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _AutoRow({required this.icon, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    final color = active ? JarvisColors.gold : JarvisColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 4),
        Text(
          label,
          style: JarvisTextStyles.statusText.copyWith(
            color: color,
            fontSize: 8,
            letterSpacing: 1,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        if (active) ...[
          const SizedBox(width: 3),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: JarvisColors.gold,
              boxShadow: [
                BoxShadow(
                    color: JarvisColors.gold.withValues(alpha: 0.7),
                    blurRadius: 3)
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Captured stamp overlay ─────────────────────────────────────────────────

class _CapturedStamp extends StatefulWidget {
  final String text;
  const _CapturedStamp({required this.text});

  @override
  State<_CapturedStamp> createState() => _CapturedStampState();
}

class _CapturedStampState extends State<_CapturedStamp>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ctrl);

    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.85, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 85),
    ]).animate(_ctrl);
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
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: JarvisColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: JarvisColors.good, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: JarvisColors.good.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check,
                      color: JarvisColors.good, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    widget.text,
                    style: const TextStyle(
                      fontFamily: 'Courier New',
                      color: JarvisColors.good,
                      fontSize: 12,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Lightweight hex grid used by the error screen
class _HexBgPainter extends CustomPainter {
  const _HexBgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JarvisColors.primary.withValues(alpha: 0.04)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    const r = 20.0;
    final h = r * 1.732;
    int col = 0;
    for (double x = -r; x < size.width + r; x += r * 1.5) {
      final yOff = col.isOdd ? h / 2 : 0.0;
      for (double y = -h + yOff; y < size.height + h; y += h) {
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a = pi / 180 * (60 * i - 30);
          final pt = Offset(x + r * cos(a), y + r * sin(a));
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
      col++;
    }
  }

  @override
  bool shouldRepaint(_HexBgPainter old) => false;
}
