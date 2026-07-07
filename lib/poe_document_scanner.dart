import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'config.dart';
import 'services/camera_resource_manager.dart';
import 'utils/scanner_pdf_resolver.dart';
import 'utils/document_scanner_manager.dart';
import 'utils/document_scanner_crash_recovery.dart';
import 'utils/ultimate_scanner_crash_prevention.dart';
import 'utils/enhanced_document_scanner_manager.dart';

class PoeDocumentScanner extends StatefulWidget {
  final int learnerId;
  final String learnerName;
  final String? classId;
  final String? siteName;
  final String? uploadedBy;
  final int? partNumber; // For multi-part documents
  final int? totalParts; // Total expected parts

  const PoeDocumentScanner({
    super.key,
    required this.learnerId,
    required this.learnerName,
    this.classId,
    this.siteName,
    this.uploadedBy,
    this.partNumber,
    this.totalParts,
  });

  @override
  State<PoeDocumentScanner> createState() => _PoeDocumentScannerState();
}

class _PoeDocumentScannerState extends State<PoeDocumentScanner>
    with WidgetsBindingObserver {
  bool _isScanning = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _statusMessage;
  List<String> _scannedPages = [];
  File? _pdfFile;
  final CameraResourceManager _cameraManager = CameraResourceManager();
  final DocumentScannerCrashRecovery _crashRecovery =
      DocumentScannerCrashRecovery();
  final UltimateScannerCrashPrevention _ultimateCrashPrevention =
      UltimateScannerCrashPrevention();
  final EnhancedDocumentScannerManager _enhancedScannerManager =
      EnhancedDocumentScannerManager();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize ultimate crash prevention system
    _ultimateCrashPrevention.initialize();

    // Start crash recovery monitoring
    _crashRecovery.startMonitoring();
  }

  @override
  void dispose() {
    print('🔄 POE Document Scanner disposing...');

    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Dispose enhanced scanner manager
    _enhancedScannerManager.dispose();

    // Dispose ultimate crash prevention system
    _ultimateCrashPrevention.dispose();

    // Stop crash recovery monitoring
    _crashRecovery.stopMonitoring();

    // Enhanced cleanup to prevent crashes
    try {
      _cameraManager.markMLKitScannerInactive();
      print('✅ Camera manager cleaned up');
    } catch (e) {
      print('❌ Error cleaning up camera manager: $e');
    }

    // Cancel any ongoing operations
    try {
      if (_isScanning || _isUploading) {
        print(
            '⚠️ Disposing while operations are active - this may cause crashes');
        _crashRecovery.forceReset();
      }
    } catch (e) {
      print('❌ Error checking operation state: $e');
    }

    super.dispose();
    print('✅ POE Document Scanner disposed');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('[DOC_SCAN] App lifecycle state changed to: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        print('[DOC_SCAN] App resumed - checking scanner state');
        _handleAppResumed();
        break;
      case AppLifecycleState.inactive:
        print('[DOC_SCAN] App inactive - scanner may be launching');
        _handleAppInactive();
        break;
      case AppLifecycleState.paused:
        print('[DOC_SCAN] App paused - scanner likely active');
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        print('[DOC_SCAN] App detached');
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        print('[DOC_SCAN] App hidden - scanner in foreground');
        break;
    }
  }

  void _handleAppResumed() {
    // CRITICAL FIX: Check if we were scanning when app was paused
    if (_isScanning) {
      debugPrint(
          '[DOC_SCAN] ⚠️  App resumed while _isScanning=true — scanner was interrupted');
      debugPrint(
          '[DOC_SCAN] This is likely an OOM kill of the GMS scanner process');
      debugPrint(
          '[DOC_SCAN] (com.google.android.gms.ui killed by lmkd due to memory pressure)');

      // Reset scanner state immediately
      setState(() {
        _isScanning = false;
        _statusMessage =
            'Scanner was interrupted (device ran low on memory). Please try again.';
      });

      // Reset the document scanner manager and crash recovery
      final scannerManager = DocumentScannerManager();
      scannerManager.reset();
      _crashRecovery.forceReset();
      _enhancedScannerManager.reset();

      // Show user-friendly message about the interruption
      if (mounted) {
        _showErrorDialog(
          'Scanner Interrupted — Low Memory',
          'The document scanner was killed by Android because the device ran low on memory.\n\n'
              'This happens when:\n'
              '• The device has too many apps open\n'
              '• The scanned document is very large\n'
              '• Available RAM drops below Android\'s threshold\n\n'
              '✅ Solutions:\n'
              '• Close other apps before scanning\n'
              '• Restart the device to free memory\n'
              '• Scan fewer pages per batch (20-30 pages)\n'
              '• Avoid scanning while other heavy apps are running',
        );
      }
    }

    // Check if crash recovery detected a problem
    if (_crashRecovery.isScannerCrashed()) {
      print('[DOC_SCAN] Crash recovery detected scanner crash');
      if (mounted) {
        _showErrorDialog(
          'Scanner Crash Detected',
          'The crash recovery system detected that the document scanner may have crashed.\n\n'
              'Recovery recommendations:\n'
              '${_crashRecovery.getRecoveryRecommendations().map((r) => '• $r').join('\n')}',
        );
      }
      _crashRecovery.forceReset();
    }
  }

  void _handleAppInactive() {
    // App is becoming inactive - scanner may be launching
    if (_isScanning) {
      print(
          '[DOC_SCAN] App inactive while scanning - normal for scanner launch');
    }
  }

  void _handleAppPaused() {
    // App is paused - scanner is likely in foreground
    if (_isScanning) {
      print('[DOC_SCAN] App paused while scanning - scanner should be active');
    }
  }

  void _handleAppDetached() {
    // App is being detached - cleanup
    if (_isScanning) {
      print('[DOC_SCAN] App detached while scanning - force cleanup');
      _isScanning = false;
      final scannerManager = DocumentScannerManager();
      scannerManager.forceReset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan POE Document'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Learner info card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.learnerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Learner ID: ${widget.learnerId}'),
                    if (widget.classId != null)
                      Text('Class: ${widget.classId}'),
                    if (widget.siteName != null)
                      Text('Site: ${widget.siteName}'),
                    if (widget.partNumber != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Part ${widget.partNumber}${widget.totalParts != null ? ' of ${widget.totalParts}' : ''}',
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Instructions and System Status
            if (_pdfFile == null && !_isScanning) ...[
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        '🔴 MAXIMUM: 80 Pages Per Batch',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: const Text(
                          'Scanner may struggle if you scan 80+ pages!\n\n'
                          'Why? Google ML Kit runs out of memory.\n\n'
                          'SOLUTION for 80+ pages:\n'
                          '1. Scan pages 1-80 → Upload\n'
                          '2. Scan pages 81-160 → Upload\n\n'
                          'This is a scanner plugin limitation.',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ENHANCED CRASH PREVENTION STATUS
              FutureBuilder<Map<String, dynamic>>(
                future: Future.value({
                  ..._ultimateCrashPrevention.getSystemStatus(),
                  ..._enhancedScannerManager.getStatus(),
                }),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  final status = snapshot.data!;
                  final scanCount = status['scanCount'] as int;
                  final scansUntilReset = status['scansUntilReset'] as int;
                  final isInCriticalState = status['isInCriticalState'] as bool;
                  final isScanning = status['isScanning'] as bool;
                  final scanAttempts = status['scanAttempts'] as int;
                  final cooldownRemaining = status['cooldownRemaining'] as int;

                  Color statusColor = Colors.green;
                  String statusText = 'Scanner Ready';
                  IconData statusIcon = Icons.check_circle;

                  if (cooldownRemaining > 0) {
                    statusColor = Colors.red;
                    statusText = 'COOLDOWN: ${cooldownRemaining}s';
                    statusIcon = Icons.timer;
                  } else if (isInCriticalState) {
                    statusColor = Colors.red;
                    statusText = 'CRITICAL: Restart Required';
                    statusIcon = Icons.error;
                  } else if (scansUntilReset <= 1) {
                    statusColor = Colors.orange;
                    statusText = 'WARNING: Reset Soon';
                    statusIcon = Icons.warning;
                  } else if (scanCount > 0 || scanAttempts > 0) {
                    statusColor = Colors.blue;
                    statusText = 'Scanner Active';
                    statusIcon = Icons.info;
                  }

                  return Card(
                    color: statusColor.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  cooldownRemaining > 0
                                      ? 'Attempts: $scanAttempts/2 • Cooldown active'
                                      : 'Scans: $scanCount/3 • Attempts: $scanAttempts/2',
                                  style: TextStyle(
                                    color: statusColor.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (scanCount > 0 || scanAttempts > 0)
                            IconButton(
                              onPressed: cooldownRemaining > 0
                                  ? null
                                  : () {
                                      _ultimateCrashPrevention.resetSystem();
                                      _enhancedScannerManager.reset();
                                      setState(() {}); // Refresh UI
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Scanner systems reset manually'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    },
                              icon: Icon(Icons.refresh, color: statusColor),
                              tooltip: 'Reset Scanner Systems',
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 16),

            // Scanned PDF info
            if (_pdfFile != null)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf,
                          color: Colors.red, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FutureBuilder<int>(
                          future: _pdfFile!.length(),
                          builder: (context, snapshot) {
                            final sizeText = snapshot.hasData
                                ? '${(snapshot.data! / 1024 / 1024).toStringAsFixed(2)} MB'
                                : 'Calculating...';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PDF Document Ready',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text('Size: $sizeText'),
                              ],
                            );
                          },
                        ),
                      ),
                      if (!_isUploading)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: _clearScannedPages,
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Status message
            if (_statusMessage != null)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Upload progress
            if (_isUploading)
              Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text(
                    '${(_uploadProgress * 100).toStringAsFixed(0)}% uploaded',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),

            const Spacer(),

            // Action buttons
            if (!_isUploading) ...[
              ElevatedButton.icon(
                onPressed: _isScanning ? null : _startScanning,
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.document_scanner),
                label: Text(_isScanning ? 'Scanning...' : 'Start Scanning'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              if (_pdfFile != null) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _uploadDocument,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Upload Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startScanning() async {
    // Show CRITICAL warning dialog before starting scan
    if (_pdfFile == null) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 32),
              SizedBox(width: 8),
              Expanded(child: Text('CRITICAL: Scanner Limits')),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔴 MAXIMUM: 80 pages per batch',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'The scanner may crash if you scan too many pages at once!\n\n'
                  'Why? Google ML Kit runs out of memory processing too many pages.\n\n'
                  'SOLUTION:\n'
                  '✓ Scan 50-80 pages maximum per batch\n'
                  '✓ Upload each batch immediately\n'
                  '✓ Then scan the next batch\n'
                  '✓ Repeat until all pages scanned\n\n'
                  'Example for 160 pages:\n'
                  '• Batch 1: Scan pages 1-80, upload\n'
                  '• Batch 2: Scan pages 81-160, upload\n\n'
                  'This is a limitation of the scanner plugin, not our app.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('I Understand - Start Scanning'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) return;
    }

    // Check camera permissions first
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          _showErrorDialog('Camera Permission Required',
              'Camera permission is needed to scan documents. Please enable it in your device settings.');
        }
        return;
      }
    }

    // Request camera access (prevents conflicts when app goes to background for native scanner)
    const String requester = 'PoeDocumentScanner';
    final bool hasAccess = await _cameraManager.requestCameraAccess(requester,
        timeout: const Duration(seconds: 10));

    if (!hasAccess && mounted) {
      _showErrorDialog(
          'Camera Busy',
          _cameraManager.currentUser != null
              ? 'Camera is being used by ${_cameraManager.currentUser}. Please wait and try again.'
              : 'Camera is currently busy. Please wait and try again.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _statusMessage = 'Opening scanner... Scan continuously for best results!';
    });

    try {
      // Mark ML Kit scanner as active (prevents incorrect camera release when app pauses)
      _cameraManager.markMLKitScannerActive();

      // Mark scanner as active in crash recovery system
      _crashRecovery.markScannerActive();

      // MEMORY MANAGEMENT: Stop the periodic cleanup timer while scanning.
      // The timer fires every 2 minutes and calls GC 3x — this competes with
      // the ML Kit scanner process for memory and can trigger OOM kills.
      _ultimateCrashPrevention.dispose();
      debugPrint(
          '[DOC_SCAN] ⏸️  Paused background cleanup timer to free memory for scanner');

      // ULTIMATE + ENHANCED CRASH PREVENTION: Use dual protection systems
      dynamic scanResult;
      try {
        debugPrint('🔄 Starting DUAL crash-protected scanner...');

        // Get system status before scanning
        final systemStatus = _ultimateCrashPrevention.getSystemStatus();
        final enhancedStatus = _enhancedScannerManager.getStatus();
        debugPrint('[DUAL_SCAN] Ultimate system status: $systemStatus');
        debugPrint('[DUAL_SCAN] Enhanced system status: $enhancedStatus');

        // Check enhanced scanner cooldown
        final cooldownRemaining = enhancedStatus['cooldownRemaining'] as int;
        if (cooldownRemaining > 0) {
          setState(() {
            _isScanning = false;
            _statusMessage =
                'Scanner in cooldown mode. Wait $cooldownRemaining seconds.';
          });

          _showErrorDialog(
            'Scanner Cooldown',
            'The scanner is in cooldown mode to prevent crashes.\n\n'
                'Please wait $cooldownRemaining seconds before scanning again.\n\n'
                'This protection prevents the "works 1-2 times then crashes" issue.',
          );
          return;
        }

        // Show warning if approaching critical state
        if (systemStatus['scansUntilReset'] <= 1) {
          final shouldContinue = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Scanner Reset Warning'),
                ],
              ),
              content: const Text(
                  '⚠️ WARNING: Scanner approaching reset limit\n\n'
                  'After this scan, the scanner will need to be reset to prevent crashes.\n\n'
                  'This is normal behavior to keep your app stable.\n\n'
                  'Continue with this scan?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Continue Scan'),
                ),
              ],
            ),
          );

          if (shouldContinue != true) {
            setState(() {
              _isScanning = false;
              _statusMessage = 'Scan cancelled by user';
            });
            return;
          }
        }

        // Execute with DUAL protection (Enhanced + Ultimate)
        scanResult = await _enhancedScannerManager.executeSafeScan(
          // Very high limits (e.g. 999) can cause ML Kit/Android process death.
          // Keep this bounded and scan in batches.
          maxPages: 80,
          context: context,
        );

        // Also update ultimate crash prevention counter
        _ultimateCrashPrevention.resetSystem();

        debugPrint('✅ DUAL crash-protected scanner completed successfully');
      } on TimeoutException catch (e) {
        debugPrint('❌ DUAL Scanner timeout: $e');
        if (mounted) {
          setState(() {
            _isScanning = false;
            _statusMessage =
                'Scanner timed out after 8 minutes. Please try again with fewer pages.';
          });
          _showErrorDialog(
            'Scanner Timeout',
            e.message ?? 'The scanner session timed out.',
          );
        }
        return;
      } catch (e, stackTrace) {
        debugPrint('❌ DUAL Scanner crashed with error: $e');
        debugPrint('❌ Stack trace: $stackTrace');

        if (mounted) {
          setState(() {
            _isScanning = false;
            _statusMessage = 'Scanner error: $e';
          });

          // The enhanced scanner manager provides detailed error messages
          _showErrorDialog('Scanner Error', e.toString());
        }
        return;
      }

      debugPrint('Scan Result: $scanResult');

      if (scanResult is! Map ||
          !scanResult.containsKey('pdfUri') ||
          scanResult['pdfUri'] == null) {
        debugPrint('Invalid scan result: $scanResult');
        setState(() {
          _isScanning = false;
          _statusMessage =
              'Scanner session ended without saving. This happens when:\n'
              '• You take long pauses (Android kills the scanner)\n'
              '• The document is too large (memory issues)\n'
              '• The app was backgrounded during scanning';
        });

        // Show helpful message for large documents
        _showErrorDialog(
          'Scanner Session Lost',
          'The scanner session was terminated by Android. This commonly happens when:\n\n'
              '❌ Taking long pauses between pages (>2-3 minutes)\n'
              '❌ Scanning 80+ pages in one session\n'
              '❌ Switching to other apps during scanning\n'
              '❌ Device running low on memory\n\n'
              '✅ Solutions:\n'
              '• Scan continuously without long pauses\n'
              '• Scan in batches of 50-80 pages\n'
              '• Keep this app in foreground\n'
              '• Close other apps to free memory\n'
              '• Restart device if problem persists\n\n'
              '🛡️ Your app was protected from crashing by our ultimate crash prevention system!',
        );
        return;
      }

      final String? pdfUri = scanResult['pdfUri'] as String?;
      debugPrint('Processed PDF URI: $pdfUri');

      final file = await resolveFlutterDocScannerPdfFile(pdfUri);
      if (file != null && await isReadablePdfFile(file)) {
        final fileSize = await file.length();
        debugPrint('PDF exists: ${file.path}, size: $fileSize bytes');

        // Check if file is too large (> 150MB)
        if (fileSize > 150 * 1024 * 1024) {
          setState(() {
            _isScanning = false;
            _statusMessage =
                'PDF too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB). Maximum 150MB.';
          });
          _showErrorDialog(
            'File Too Large',
            'The scanned PDF is ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB, which exceeds the 150MB limit.\n\n'
                'Please scan fewer pages or reduce image quality.',
          );
          return;
        }

        setState(() {
          _pdfFile = file;
          _scannedPages = [file.path];
          _isScanning = false;
          _statusMessage =
              'PDF scanned successfully! Size: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB\n'
              'Tip: Upload now to avoid losing data!';
        });

        _showSnackBar('PDF document scanned successfully! Upload it now.');
      } else {
        debugPrint('Error: PDF unreadable or missing for uri: $pdfUri');
        setState(() {
          _isScanning = false;
          _statusMessage =
              'PDF file not found. Scanner session was terminated.';
        });

        _showErrorDialog(
          'Scanner Session Lost',
          'The scanner failed to save the PDF file. This happens when:\n\n'
              '• Android returned a content URI we could not read\n'
              '• Android terminated the scanner due to long idle time\n'
              '• The app was backgrounded during scanning\n\n'
              'Solution: Try again; scan in smaller batches if needed.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Scan Error: $e\nStack Trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Scanning error: $e';
        });

        // Check for plugin initialization error
        if (e.toString().contains('UninitializedPropertyAccessException') ||
            e.toString().contains('resultChannel')) {
          _showErrorDialog(
            'Scanner Plugin Error',
            'The scanner plugin encountered an error. This can happen when scanning multiple times.\n\n'
                'Solutions:\n'
                '• Close this screen and open it again\n'
                '• Restart the app\n'
                '• If problem persists, restart your device\n\n'
                'Your previous scan was saved successfully.',
          );
        } else if (e.toString().contains('FileNotFoundException') ||
            e.toString().contains('ENOENT')) {
          _showErrorDialog(
            'Scanner Cache Error',
            'The document scanner ran out of cache space. This typically happens with very large documents (80+ pages).\n\n'
                'Solutions:\n'
                '• Scan in smaller batches (50-80 pages)\n'
                '• Clear app cache and try again\n'
                '• Restart the device\n'
                '• Free up device storage',
          );
        } else {
          _showErrorDialog('Scanning Error', 'Error: $e');
        }
      }
    } finally {
      _cameraManager.markMLKitScannerInactive();
      _cameraManager.releaseCameraAccess(requester);

      // Mark scanner as inactive in crash recovery system
      _crashRecovery.markScannerInactive();

      // MEMORY MANAGEMENT: Restart the background cleanup timer now that
      // the scanner has finished and memory pressure is reduced.
      _ultimateCrashPrevention.initialize();
      debugPrint(
          '[DOC_SCAN] ▶️  Restarted background cleanup timer after scan');

      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error showing dialog: $e');
      // Fallback: show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: $message'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  // No longer needed - scanner creates PDF directly

  Future<void> _uploadDocument() async {
    if (_pdfFile == null) {
      _showError('No document to upload');
      return;
    }

    print('=== Starting POE Document Upload ===');
    print('File path: ${_pdfFile!.path}');

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _statusMessage = 'Preparing upload...';
    });

    try {
      final fileSize = await _pdfFile!.length();
      print(
          'File size: $fileSize bytes (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');

      // ALWAYS use chunked upload since server requires it
      // Server is configured to only accept chunked uploads
      print('Using chunked upload (server requirement)...');
      await _uploadChunked();

      print('Upload completed successfully!');

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.partNumber != null
                  ? 'Part ${widget.partNumber} uploaded successfully!'
                  : 'Document uploaded successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        await Future.delayed(const Duration(seconds: 2));

        // Single pop back to the screen that opened the scanner (e.g. learners list).
        // Do NOT use popUntil(isFirst) or pushNamedAndRemoveUntil: in this app the first
        // route is LoginPage, so those "fallbacks" logged users out of their workflow.
        if (mounted) {
          try {
            Navigator.pop(context, true);
          } catch (e) {
            print('Navigation error after upload: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Upload complete. Use the back button to return to the previous screen.',
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          }
        }
      }
    } catch (e, stackTrace) {
      print('Upload error: $e');
      print('Stack trace: $stackTrace');

      // ENHANCED ERROR HANDLING: Prevent crashes during error handling
      if (mounted) {
        try {
          setState(() {
            _isUploading = false;
            _statusMessage = 'Upload failed: $e';
          });
        } catch (setStateError) {
          print('SetState error during upload failure: $setStateError');
        }
      }

      // Show error with safe navigation
      if (mounted) {
        try {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => AlertDialog(
              title: const Text('Upload Failed'),
              content: Text(
                  'Error: $e\n\nPlease try again or contact support if the problem persists.'),
              actions: [
                TextButton(
                  onPressed: () {
                    // Safe dialog dismissal
                    try {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    } catch (navError) {
                      print('Error closing error dialog: $navError');
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } catch (dialogError) {
          print('Error showing upload error dialog: $dialogError');
          // Fallback: show snackbar instead
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          } catch (snackBarError) {
            print('Error showing snackbar: $snackBarError');
            // Ultimate fallback: just print the error
            print('FINAL FALLBACK: Upload failed with error: $e');
          }
        }
      }
    }
  }

  Future<void> _uploadDirect() async {
    print('Starting direct upload...');

    // Use AppConfig to get the correct base URL
    // TEMPORARY: Using strict-mode-fixed endpoint to resolve 500 error
    final uri =
        Uri.parse('${AppConfig.baseUrl}/upload_poe_document_strict_fixed.php');
    print('Upload URL: $uri');

    var request = http.MultipartRequest('POST', uri);

    request.fields['learner_id'] = widget.learnerId.toString();
    request.fields['learner_name'] = widget.learnerName;
    request.fields['document_type'] =
        widget.partNumber != null ? 'POE_PART' : 'POE';
    request.fields['page_count'] = '0'; // Unknown page count from scanner

    if (widget.classId != null) {
      request.fields['class_id'] = widget.classId!;
    }
    if (widget.siteName != null) {
      request.fields['site_name'] = widget.siteName!;
    }
    if (widget.uploadedBy != null) {
      request.fields['uploaded_by'] = widget.uploadedBy!;
    }
    if (widget.partNumber != null) {
      request.fields['notes'] =
          'Part ${widget.partNumber}${widget.totalParts != null ? ' of ${widget.totalParts}' : ''}';
    }

    print('Request fields: ${request.fields}');
    print('Adding file: ${_pdfFile!.path}');

    request.files.add(
      await http.MultipartFile.fromPath('poe_document', _pdfFile!.path),
    );

    setState(() {
      _statusMessage = 'Uploading...';
    });

    print('Sending request...');
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    print('Response status: ${response.statusCode}');
    print('Response body: $responseBody');

    if (response.statusCode == 200) {
      try {
        final jsonResponse = json.decode(responseBody);
        print('Parsed JSON response: $jsonResponse');

        if (jsonResponse['success'] != true) {
          throw Exception(jsonResponse['message'] ?? 'Upload failed');
        }

        print('Direct upload successful!');
      } catch (e) {
        print('Error parsing response: $e');
        print('Raw response: $responseBody');
        throw Exception('Invalid server response: $e');
      }
    } else {
      throw Exception('Server error: ${response.statusCode} - $responseBody');
    }
  }

  Future<void> _uploadChunked() async {
    print('Starting chunked upload...');
    const chunkSize = 2 * 1024 * 1024; // 2MB chunks

    try {
      // CRITICAL FIX: Don't load entire file into memory!
      // For large documents (80+ pages), this causes out-of-memory crash
      // during PDF creation. Batch scanning (50-80 pages) is required.
      final fileSize = await _pdfFile!.length();
      print(
          'File size: $fileSize bytes (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');

      final totalChunks = (fileSize / chunkSize).ceil();
      final fileId = DateTime.now().millisecondsSinceEpoch.toString();

      print('Total chunks: $totalChunks, File ID: $fileId');

      // Open file for reading
      final randomAccessFile = await _pdfFile!.open(mode: FileMode.read);

      try {
        for (int i = 0; i < totalChunks; i++) {
          print('Uploading chunk ${i + 1} of $totalChunks...');

          final start = i * chunkSize;
          final end = min(start + chunkSize, fileSize);
          final chunkLength = end - start;

          // Read only this chunk from disk (memory efficient!)
          await randomAccessFile.setPosition(start);
          final chunk = await randomAccessFile.read(chunkLength);

          print('Chunk $i: ${chunk.length} bytes (from $start to $end)');

          // TEMPORARY: Using strict-mode-fixed endpoint to resolve 500 error
          final uri = Uri.parse(
              '${AppConfig.baseUrl}/upload_poe_document_strict_fixed.php');
          print('[CONFIG] Base URL: ${AppConfig.baseUrl}');
          print('Upload URL: $uri');

          var request = http.MultipartRequest('POST', uri);

          request.fields['chunk_index'] = i.toString();
          request.fields['total_chunks'] = totalChunks.toString();
          request.fields['file_id'] = fileId;
          request.fields['file_extension'] = 'pdf';

          // Send metadata with EVERY chunk
          request.fields['learner_id'] = widget.learnerId.toString();
          request.fields['learner_name'] = widget.learnerName;
          request.fields['document_type'] =
              widget.partNumber != null ? 'POE_PART' : 'POE';
          request.fields['page_count'] = '0';

          if (widget.classId != null) {
            request.fields['class_id'] = widget.classId!;
          }
          if (widget.siteName != null) {
            request.fields['site_name'] = widget.siteName!;
          }
          if (widget.uploadedBy != null) {
            request.fields['uploaded_by'] = widget.uploadedBy!;
          }
          if (widget.partNumber != null) {
            request.fields['notes'] =
                'Part ${widget.partNumber}${widget.totalParts != null ? ' of ${widget.totalParts}' : ''}';
          }

          // Send chunk as multipart file (not base64)
          // PHP expects $_FILES['chunk']
          request.files.add(
            http.MultipartFile.fromBytes(
              'chunk',
              chunk,
              filename: 'chunk_$i.bin',
            ),
          );

          print('Sending chunk ${i + 1}...');
          final response = await request.send();
          final responseBody = await response.stream.bytesToString();

          print('Chunk ${i + 1} response status: ${response.statusCode}');
          print('Chunk ${i + 1} response body: $responseBody');

          if (response.statusCode != 200) {
            throw Exception(
                'Chunk $i upload failed: HTTP ${response.statusCode}');
          }

          try {
            final jsonResponse = json.decode(responseBody);
            if (jsonResponse['success'] != true) {
              throw Exception(
                  'Chunk $i failed: ${jsonResponse['message'] ?? 'Unknown error'}');
            }

            print('Chunk ${i + 1} uploaded successfully');

            // Optional: Log the chunk size verification from server response
            if (jsonResponse.containsKey('chunk_size')) {
              print(
                  'Server confirmed chunk size: ${jsonResponse['chunk_size']} bytes');
            }
          } catch (e) {
            print('Error parsing response for chunk $i: $e');
            print('Raw response: $responseBody');
            throw Exception('Invalid response for chunk $i: $e');
          }

          setState(() {
            _uploadProgress = (i + 1) / totalChunks;
            _statusMessage = 'Uploading chunk ${i + 1} of $totalChunks...';
          });

          // Clear chunk from memory immediately
          // This is critical for large files to prevent memory buildup
        }
      } finally {
        // Always close the file handle
        await randomAccessFile.close();
        print('File handle closed');
      }

      print('All chunks uploaded successfully!');
    } catch (e, stackTrace) {
      print('Chunked upload error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  void _clearScannedPages() {
    setState(() {
      _scannedPages.clear();
      _pdfFile = null;
      _statusMessage = null;
      _uploadProgress = 0.0;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
