import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/connectivity_service.dart';
import 'package:jcg_fitness/features/ai_scanner/screens/image_preview_screen.dart';
import 'package:jcg_fitness/features/ai_scanner/ai_scanner_provider.dart';

class CameraScreen extends ConsumerStatefulWidget {
  final String mealType;

  const CameraScreen({super.key, required this.mealType});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  FlashMode _flashMode = FlashMode.off;
  bool _isInitialized = false;
  bool _hasPermission = false;
  bool _permissionChecked = false;
  bool _permissionPermanentlyDenied = false;
  bool _noCameras = false;
  bool _isInitializing = false;
  bool _isTakingPhoto = false;
  bool _isLiveInferenceBusy = false;
  static const _liveInferenceDefault = bool.fromEnvironment(
    'JCG_LIVE_PREVIEW',
    defaultValue: false,
  );
  bool _liveInferenceEnabled = _liveInferenceDefault;
  int _liveInferenceGeneration = 0;
  DateTime? _lastLiveInferenceAt;
  String? _liveFoodName;
  double _liveConfidence = 0;
  int _stableFrameCount = 0;
  String? _stableFoodName;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeCamera(updateState: false));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isInitialized && !_isInitializing) {
        _initCamera();
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeCamera();
    }
  }

  Future<void> _initCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;
    if (mounted) {
      setState(() {
        _permissionChecked = false;
        _noCameras = false;
        _cameraError = null;
      });
    }
    try {
      await _requestPermission();
      if (!_hasPermission) return;

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _noCameras = true;
            _permissionChecked = true;
          });
        }
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selectedCamera,
        // Medium keeps the preview responsive on budget phones. The final
        // shutter image still goes through the full recognition pipeline.
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _controller?.dispose();
      setState(() {
        _controller = controller;
        _isInitialized = true;
        _permissionChecked = true;
        _noCameras = false;
        _lastLiveInferenceAt = null;
      });
      if (_liveInferenceEnabled) {
        unawaited(_startLiveInference(controller));
      }
    } on CameraException catch (e) {
      if (mounted) {
        final denied = e.code == 'CameraAccessDenied' ||
            e.code == 'CameraAccessDeniedWithoutPrompt' ||
            e.code == 'CameraAccessRestricted';
        setState(() {
          _hasPermission = !denied;
          _permissionPermanentlyDenied =
              e.code == 'CameraAccessDeniedWithoutPrompt';
          _noCameras = !denied;
          _cameraError = e.description ?? e.code;
          _permissionChecked = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _noCameras = true;
          _cameraError = e.toString();
          _permissionChecked = true;
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _requestPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    _hasPermission = status.isGranted;
    _permissionPermanentlyDenied = status.isPermanentlyDenied;
    if (!_hasPermission && mounted) {
      setState(() => _permissionChecked = true);
    }
  }

  Future<void> _disposeCamera({bool updateState = true}) async {
    final controller = _controller;
    _controller = null;
    _liveInferenceGeneration++;
    if (controller?.value.isStreamingImages == true) {
      try {
        await controller!.stopImageStream();
      } catch (_) {
        // The controller may already be closing during an app lifecycle change.
      }
    }
    if (updateState && mounted) setState(() => _isInitialized = false);
    await controller?.dispose();
  }

  Future<void> _toggleLiveInference() async {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;

    if (_liveInferenceEnabled) {
      setState(() => _liveInferenceEnabled = false);
      await _stopLiveInference();
      return;
    }

    setState(() => _liveInferenceEnabled = true);
    await _startLiveInference(controller);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    const modes = FlashMode.values;
    final currentIndex = modes.indexOf(_flashMode);
    final nextMode = modes[(currentIndex + 1) % modes.length];
    try {
      await _controller!.setFlashMode(nextMode);
      if (mounted) setState(() => _flashMode = nextMode);
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.description ?? 'Flash is unavailable')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1920,
    );
    if (picked != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ImagePreviewScreen(
            imagePath: picked.path,
            mealType: widget.mealType,
          ),
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    if (_isTakingPhoto ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    try {
      setState(() => _isTakingPhoto = true);
      await _stopLiveInference();
      final xfile = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ImagePreviewScreen(
            imagePath: xfile.path,
            mealType: widget.mealType,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to take photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  Future<void> _startLiveInference(CameraController controller) async {
    if (!_liveInferenceEnabled) return;
    if (controller.value.isStreamingImages) return;
    try {
      await controller.startImageStream(_onCameraImage);
    } on CameraException {
      // Live preview is an enhancement; the shutter still works if the device
      // cannot provide a compatible image stream.
      if (mounted) setState(() => _liveInferenceEnabled = false);
    }
  }

  Future<void> _stopLiveInference() async {
    final controller = _controller;
    _liveInferenceGeneration++;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {
        // Ignore a stream that was already stopped by the camera plugin.
      }
    }
    if (mounted) {
      setState(() {
        _isLiveInferenceBusy = false;
        _liveFoodName = null;
        _liveConfidence = 0;
        _stableFrameCount = 0;
        _stableFoodName = null;
      });
    }
  }

  void _onCameraImage(CameraImage image) {
    if (!_liveInferenceEnabled ||
        _isTakingPhoto ||
        _isLiveInferenceBusy ||
        !mounted) {
      return;
    }
    final now = DateTime.now();
    final last = _lastLiveInferenceAt;
    if (last != null && now.difference(last).inMilliseconds < 900) return;
    _lastLiveInferenceAt = now;
    _isLiveInferenceBusy = true;
    final generation = ++_liveInferenceGeneration;
    Future<void>(() async {
      try {
        final jpeg = _cameraImageToJpeg(image);
        if (jpeg == null || !mounted) return;
        final recognitions = await ref
            .read(localFoodRecognitionServiceProvider)
            .recognizeBytes(jpeg);
        if (!mounted ||
            generation != _liveInferenceGeneration ||
            recognitions.isEmpty) {
          return;
        }
        final top = recognitions.first;
        final isSame = top.foodName == _stableFoodName;
        final nextStableCount = isSame ? _stableFrameCount + 1 : 1;
        setState(() {
          _liveFoodName = top.foodName;
          _liveConfidence = top.confidence;
          _stableFoodName = top.foodName;
          _stableFrameCount = nextStableCount;
        });
      } catch (_) {
        // Keep the preview usable; the final still scan reports actionable
        // errors and can use the online fallback.
      } finally {
        if (generation == _liveInferenceGeneration) {
          _isLiveInferenceBusy = false;
        }
      }
    });
  }

  Uint8List? _cameraImageToJpeg(CameraImage image) {
    final format = image.format.group;
    if (format != ImageFormatGroup.yuv420 &&
        format != ImageFormatGroup.bgra8888) {
      return null;
    }
    final width = image.width;
    final height = image.height;
    if (width <= 0 || height <= 0 || image.planes.isEmpty) return null;

    // Live inference is a preview hint, not a photo export. Downsample before
    // any conversion so a 1080p camera frame never becomes a million-pixel
    // Dart loop on the UI isolate.
    final scale = math.min(1.0, 320 / math.max(width, height));
    final sampledWidth = math.max(1, (width * scale).round());
    final sampledHeight = math.max(1, (height * scale).round());
    final output = img.Image(width: sampledWidth, height: sampledHeight);

    int readByte(Plane plane, int row, int column) {
      final bytesPerPixel = plane.bytesPerPixel ?? 1;
      final index = row * plane.bytesPerRow + column * bytesPerPixel;
      if (index < 0 || index >= plane.bytes.length) return 128;
      return plane.bytes[index];
    }

    for (var y = 0; y < sampledHeight; y++) {
      final sourceY = (y * height / sampledHeight).floor().clamp(0, height - 1);
      for (var x = 0; x < sampledWidth; x++) {
        final sourceX = (x * width / sampledWidth).floor().clamp(0, width - 1);
        int red;
        int green;
        int blue;
        if (format == ImageFormatGroup.bgra8888) {
          final plane = image.planes.first;
          final bytesPerPixel = plane.bytesPerPixel ?? 4;
          final index = sourceY * plane.bytesPerRow + sourceX * bytesPerPixel;
          if (index < 0 || index + 2 >= plane.bytes.length) return null;
          blue = plane.bytes[index];
          green = plane.bytes[index + 1];
          red = plane.bytes[index + 2];
        } else {
          if (image.planes.length < 3) return null;
          final yPlane = image.planes[0];
          final uPlane = image.planes[1];
          final vPlane = image.planes[2];
          final yValue = readByte(yPlane, sourceY, sourceX);
          final uvRow = sourceY ~/ 2;
          final uvColumn = sourceX ~/ 2;
          final uValue = readByte(uPlane, uvRow, uvColumn);
          final vValue = readByte(vPlane, uvRow, uvColumn);
          final luminance = yValue.toDouble();
          red = (luminance + 1.402 * (vValue - 128)).round();
          green = (luminance -
                  0.344136 * (uValue - 128) -
                  0.714136 * (vValue - 128))
              .round();
          blue = (luminance + 1.772 * (uValue - 128)).round();
        }
        output.setPixelRgb(
          x,
          y,
          red.clamp(0, 255),
          green.clamp(0, 255),
          blue.clamp(0, 255),
        );
      }
    }
    return Uint8List.fromList(img.encodeJpg(output, quality: 60));
  }

  Widget _buildLiveStatus(ThemeData theme) {
    final label = _liveFoodName;
    final isStable = _stableFrameCount >= 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isStable ? AppColors.success : Colors.white24,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isStable ? Icons.check_circle : Icons.center_focus_strong,
            color: isStable ? AppColors.success : Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label == null
                  ? _liveInferenceEnabled
                      ? 'Point the camera at one dish'
                      : 'Live analysis off • preview stays smooth'
                  : isStable
                      ? 'Preview: $label'
                      : 'Hold steady: $label',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (label != null)
            Text(
              '${(_liveConfidence * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
        ],
      ),
    );
  }

  void _showTipsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Photography Tips',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _tipItem('Use good lighting for best results'),
              _tipItem('Center the food in the frame'),
              _tipItem('Avoid blurry photos'),
              _tipItem('Include the full plate'),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _tipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Photo'),
        actions: [
          if (_isInitialized)
            IconButton(
              icon: Icon(
                _liveInferenceEnabled
                    ? Icons.auto_awesome
                    : Icons.auto_awesome_outlined,
              ),
              onPressed: _toggleLiveInference,
              tooltip: _liveInferenceEnabled
                  ? 'Turn off live analysis'
                  : 'Turn on live analysis',
            ),
          if (_isInitialized)
            IconButton(
              icon: Icon(
                _flashMode == FlashMode.off
                    ? Icons.flash_off
                    : _flashMode == FlashMode.always
                        ? Icons.flash_on
                        : Icons.flash_auto,
              ),
              onPressed: _toggleFlash,
              tooltip: 'Toggle Flash',
            ),
        ],
      ),
      body: _buildBody(theme, isOnline),
    );
  }

  Widget _buildBody(ThemeData theme, bool isOnline) {
    if (!_permissionChecked) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography,
                  size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Camera Access Required',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please grant camera access in your device settings to use the food scanner.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnAccent,
                ),
              ),
              if (_permissionPermanentlyDenied) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: openAppSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open App Settings'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_noCameras) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  size: 64, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                'No Camera Detected',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _cameraError == null
                    ? 'We couldn\'t find a camera on this device. You can still upload a photo from your gallery.'
                    : 'Camera unavailable: $_cameraError\nYou can still upload a photo from your gallery.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose from Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        CameraPreview(_controller!),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Take a clear photo of your food',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: _buildLiveStatus(theme),
        ),
        if (!isOnline)
          Positioned(
            top: 78,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: AppColors.textPrimary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'On-device Adobo/Sinigang recognition works offline. Cloud refinement is unavailable.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_flashMode == FlashMode.off)
          Positioned(
            bottom: 140,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Improve lighting for better results',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 56,
          left: 24,
          child: GestureDetector(
            onTap: _showTipsSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.textMuted, width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: AppColors.textPrimary, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Tips',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _isTakingPhoto ? null : _takePhoto,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.textPrimary,
                  border: Border.all(
                    color: AppColors.textSecondary,
                    width: 4,
                  ),
                ),
                child: _isTakingPhoto
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.surface,
                        ),
                      )
                    : Container(
                        margin: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.textPrimary,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
