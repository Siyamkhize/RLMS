import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
// import 'package:camera/camera.dart';  // Temporarily disabled due to Java 21 compatibility issues
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;

class CameraQualityScreen extends StatefulWidget {
  const CameraQualityScreen({super.key});

  @override
  _CameraQualityScreenState createState() => _CameraQualityScreenState();
}

class _CameraQualityScreenState extends State<CameraQualityScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isProcessing = false;
  String? _qualityMessage;
  XFile? _capturedFile;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    // Delay initialization to avoid rapid open/close
    Future.delayed(const Duration(milliseconds: 100), _initializeCamera);
  }

  Future<void> _initializeCamera() async {
    if (_isCameraInitialized) {
      debugPrint('[CAMERA] Camera already initialized, skipping');
      return;
    }

    try {
      // Request camera permission
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        setState(() {
          _qualityMessage = 'Camera permission denied';
        });
        debugPrint('[CAMERA] Permission denied');
        return;
      }

      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _qualityMessage = 'No cameras available';
        });
        debugPrint('[CAMERA] No cameras available');
        return;
      }

      // Select back camera with highest resolution
      CameraDescription? selectedCamera;
      int maxPixels = 0;
      for (var camera in _cameras!) {
        final pixels = 1280 * 720; // Placeholder for resolution
        if (pixels > maxPixels &&
            camera.lensDirection == CameraLensDirection.back) {
          maxPixels = pixels;
          selectedCamera = camera;
        }
      }

      if (selectedCamera == null) {
        setState(() {
          _qualityMessage = 'No suitable back camera found';
        });
        debugPrint('[CAMERA] No suitable back camera');
        return;
      }

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium, // Use medium to reduce buffer load
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (!mounted) return;

      await _controller!.setFlashMode(FlashMode.off);
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);

      // Lock capture orientation to prevent buffer issues
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      setState(() {
        _isCameraInitialized = true;
      });
      debugPrint('[CAMERA] Camera initialized with resolution preset: medium');
    } catch (e) {
      debugPrint('[CAMERA] Initialization error: $e');
      setState(() {
        _qualityMessage = 'Camera initialization failed: $e';
        _isCameraInitialized = false;
      });
    }
  }

  Future<void> _onTapToFocus(
      TapDownDetails details, BoxConstraints constraints) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );

    try {
      await _controller!.setFocusPoint(offset);
      await _controller!.setExposurePoint(offset);
      debugPrint('[CAMERA] Focus set to: $offset');
    } catch (e) {
      debugPrint('[CAMERA] Focus point setting failed: $e');
    }
  }

  Future<img.Image?> _preprocessImage(img.Image image) async {
    try {
      // Resize to 640x480 for quality
      final highRes = img.copyResize(image, width: 640, height: 480);
      final grayscale = img.grayscale(highRes);
      // Enhance contrast for fingerprint ridges
      final contrast = img.adjustColor(grayscale, contrast: 1.5);
      // Normalize pixel values to [0, 1]
      final normalized = img.Image.from(contrast);
      for (int y = 0; y < contrast.height; y++) {
        for (int x = 0; x < contrast.width; x++) {
          final pixel = contrast.getPixel(x, y);
          final luminance = img.getLuminance(pixel).toDouble() / 255.0;
          normalized.setPixelRgba(x, y, luminance, luminance, luminance, 1.0);
        }
      }
      // Final resize for Siamese model
      final resized = img.copyResize(normalized, width: 224, height: 224);
      debugPrint(
          '[CAMERA] Preprocessed image: ${resized.width}x${resized.height}, channels: ${resized.numChannels}');
      return resized;
    } catch (e) {
      debugPrint('[CAMERA] Preprocessing error: $e');
      return null;
    }
  }

  Future<bool> _isImageBright(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('[CAMERA] Failed to decode image for brightness check');
        return false;
      }
      int sum = 0;
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          sum += img.getLuminance(image.getPixel(x, y)).toInt();
        }
      }
      double avg = sum / (image.width * image.height);
      bool isBright = avg > 30 && avg < 230;
      debugPrint('[CAMERA] Brightness check: avg=$avg, isBright=$isBright');
      return isBright;
    } catch (e) {
      debugPrint('[CAMERA] Brightness check error: $e');
      return false;
    }
  }

  img.Image laplacian(img.Image src) {
    final kernel = [
      [0, 1, 0],
      [1, -4, 1],
      [0, 1, 0]
    ];
    final w = src.width;
    final h = src.height;
    final out = img.Image(width: w, height: h);
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        int sum = 0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            int px = x + kx;
            int py = y + ky;
            int value = img.getLuminance(src.getPixel(px, py)).toInt();
            sum += value * kernel[ky + 1][kx + 1];
          }
        }
        sum = sum.abs().clamp(0, 255);
        out.setPixelRgba(x, y, sum, sum, sum, 255);
      }
    }
    return out;
  }

  Future<bool> _isImageBlurry(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('[CAMERA] Failed to decode image for blurriness check');
        return true;
      }
      final gray = img.grayscale(image);
      final lap = laplacian(gray);

      List<int> luminances = [];
      for (int y = 0; y < lap.height; y++) {
        for (int x = 0; x < lap.width; x++) {
          luminances.add(img.getLuminance(lap.getPixel(x, y)).toInt());
        }
      }
      if (luminances.isEmpty) {
        debugPrint('[CAMERA] No luminance data for blurriness check');
        return true;
      }

      double mean = luminances.reduce((a, b) => a + b) / luminances.length;
      double variance = luminances
              .map((v) => (v - mean) * (v - mean))
              .reduce((a, b) => a + b) /
          luminances.length;
      bool isBlurry = variance < 600;
      debugPrint(
          '[CAMERA] Blurriness check: variance=$variance, isBlurry=$isBlurry');
      return isBlurry;
    } catch (e) {
      debugPrint('[CAMERA] Blurriness check error: $e');
      return true;
    }
  }

  Future<void> _takePictureAndCheckQuality() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      setState(() {
        _qualityMessage = 'Camera not initialized';
        _isProcessing = false;
      });
      debugPrint('[CAMERA] Camera not initialized');
      return;
    }

    setState(() {
      _isProcessing = true;
      _qualityMessage = null;
    });

    try {
      // Pause preview to reduce buffer load
      await _controller!.pausePreview();
      final XFile file = await _controller!.takePicture();
      await _controller!.resumePreview();

      final isBright = await _isImageBright(file.path);
      final isBlurry = await _isImageBlurry(file.path);

      String qualityMessage = '';
      if (!isBright) qualityMessage += 'Image lighting may not be ideal. ';
      if (isBlurry) qualityMessage += 'Image may be blurry. ';

      setState(() {
        _isProcessing = false;
        _qualityMessage = qualityMessage.isEmpty
            ? 'Local quality check passed!'
            : '${qualityMessage}You can still use the image or retake.';
        _capturedFile = file;
      });
      debugPrint('[CAMERA] Quality check: $_qualityMessage');
    } catch (e) {
      debugPrint('[CAMERA] Capture error: $e');
      setState(() {
        _isProcessing = false;
        _qualityMessage = 'Error capturing image: $e';
      });
    } finally {
      if (_controller != null && _controller!.value.isPreviewPaused) {
        await _controller!.resumePreview();
      }
    }
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.pausePreview();
      _controller!.dispose();
      debugPrint('[CAMERA] Camera controller disposed');
      _controller = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fingerprint Capture'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: _isCameraInitialized == false ||
              _controller == null ||
              !_controller!.value.isInitialized
          ? Center(
              child: _qualityMessage != null
                  ? Text(
                      _qualityMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    )
                  : const CircularProgressIndicator(),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Text(
                    'Place your finger in the circle and tap to focus',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cameraAspectRatio =
                            _controller!.value.aspectRatio;
                        final screenAspectRatio =
                            constraints.maxWidth / constraints.maxHeight;

                        late double previewWidth;
                        late double previewHeight;

                        if (cameraAspectRatio > screenAspectRatio) {
                          previewWidth = constraints.maxWidth;
                          previewHeight =
                              constraints.maxWidth / cameraAspectRatio;
                        } else {
                          previewHeight = constraints.maxHeight;
                          previewWidth =
                              constraints.maxHeight * cameraAspectRatio;
                        }

                        return Center(
                          child: GestureDetector(
                            onTapDown: (details) =>
                                _onTapToFocus(details, constraints),
                            child: SizedBox(
                              width: previewWidth,
                              height: previewHeight,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRect(
                                    child: Transform.scale(
                                      scale: 1.0,
                                      child: CameraPreview(_controller!),
                                    ),
                                  ),
                                  CustomPaint(
                                    size: Size(previewWidth, previewHeight),
                                    painter: _FingerprintOverlayPainter(),
                                  ),
                                  if (_qualityMessage == null)
                                    Positioned(
                                      bottom: 20,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'Tap to focus',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (!_isProcessing)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt, size: 24),
                            label: const Text('Capture Fingerprint',
                                style: TextStyle(fontSize: 16)),
                            onPressed: _takePictureAndCheckQuality,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                          ),
                        ),
                      if (_isProcessing)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: Colors.blue),
                              SizedBox(height: 8),
                              Text('Analyzing image quality...'),
                            ],
                          ),
                        ),
                      // if (_capturedFile != null && !_isProcessing)  // Temporarily disabled due to Java 21 compatibility issues
                      //   Padding(
                      //     padding: const EdgeInsets.all(16),
                      //     child: Row(
                      //       children: [
                      //         Expanded(
                      //           child: SizedBox(
                      //             height: 50,
                      //             child: ElevatedButton.icon(
                      //               icon: const Icon(Icons.refresh, size: 24),
                      //               label: const Text('Retake', style: TextStyle(fontSize: 16)),
                      //               onPressed: () {
                      //                 setState(() {
                      //                   _capturedFile = null;
                      //                   _qualityMessage = null;
                      //                 });
                      //               },
                      //               style: ElevatedButton.styleFrom(
                      //                 backgroundColor: Colors.grey.shade600,
                      //                 foregroundColor: Colors.white,
                      //                 shape: RoundedRectangleBorder(
                      //                   borderRadius: BorderRadius.circular(25),
                      //                 ),
                      //               ),
                      //             ),
                      //           ),
                      //         ),
                      //         const SizedBox(width: 16),
                      //         Expanded(
                      //           child: SizedBox(
                      //             height: 50,
                      //             child: ElevatedButton.icon(
                      //               icon: const Icon(Icons.check, size: 24),
                      //               label: const Text('Use Image', style: TextStyle(fontSize: 16)),
                      //               onPressed: () async {
                      //                 final bytes = await File(_capturedFile!.path).readAsBytes();
                      //                 final image = img.decodeImage(bytes);
                      //                 if (image == null) {
                      //                   debugPrint('[CAMERA] Failed to decode captured image');
                      //                   setState(() {
                      //                     _qualityMessage = 'Failed to decode image';
                      //                   });
                      //                   return;
                      //                 }
                      //                 final processed = await _preprocessImage(image);
                      //                 if (processed == null) {
                      //                   debugPrint('[CAMERA] Preprocessing failed');
                      //                   setState(() {
                      //                     _qualityMessage = 'Failed to preprocess image';
                      //                   });
                      //                   return;
                      //                 }
                      //                 final processedBytes = img.encodePng(processed);
                      //                 final tempDir = await getTemporaryDirectory();
                      //                 final processedPath = path.join(tempDir.path, 'processed_${_capturedFile!.name}');
                      //                 await File(processedPath).writeAsBytes(processedBytes);
                      //                 Navigator.pop(context, processedPath);
                      //               },
                      //               style: ElevatedButton.styleFrom(
                      //                 backgroundColor: Colors.green.shade600,
                      //                 foregroundColor: Colors.white,
                      //                 shape: RoundedRectangleBorder(
                      //                   borderRadius: BorderRadius.circular(25),
                      //                 ),
                      //               ),
                      //             ),
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                      // if (_capturedFile != null)  // Temporarily disabled due to Java 21 compatibility issues
                      //   Padding(
                      //     padding: const EdgeInsets.symmetric(vertical: 8.0),
                      //     child: ClipRRect(
                      //       borderRadius: BorderRadius.circular(8),
                      //       child: Image.file(
                      //         File(_capturedFile!.path),
                      //         height: 100,
                      //         width: 100,
                      //         fit: BoxFit.cover,
                      //       ),
                      //     ),
                      //   ),
                      if (_qualityMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: _qualityMessage!.contains('passed')
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _qualityMessage!.contains('passed')
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _qualityMessage!.contains('passed')
                                    ? Icons.check_circle
                                    : Icons.warning,
                                color: _qualityMessage!.contains('passed')
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _qualityMessage!,
                                  style: TextStyle(
                                    color: _qualityMessage!.contains('passed')
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _FingerprintOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.15;

    canvas.drawCircle(center, radius, paint);

    final cornerPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final cornerLength = 20.0;
    final corners = [
      [
        Offset(center.dx - radius - 10, center.dy - radius - 10),
        Offset(center.dx - radius + cornerLength - 10, center.dy - radius - 10),
        Offset(center.dx - radius - 10, center.dy - radius + cornerLength - 10)
      ],
      [
        Offset(center.dx + radius + 10, center.dy - radius - 10),
        Offset(center.dx + radius - cornerLength + 10, center.dy - radius - 10),
        Offset(center.dx + radius + 10, center.dy - radius + cornerLength - 10)
      ],
      [
        Offset(center.dx - radius - 10, center.dy + radius + 10),
        Offset(center.dx - radius + cornerLength - 10, center.dy + radius + 10),
        Offset(center.dx - radius - 10, center.dy + radius - cornerLength + 10)
      ],
      [
        Offset(center.dx + radius + 10, center.dy + radius + 10),
        Offset(center.dx + radius - cornerLength + 10, center.dy + radius + 10),
        Offset(center.dx + radius + 10, center.dy + radius - cornerLength + 10)
      ],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], cornerPaint);
      canvas.drawLine(corner[0], corner[2], cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
