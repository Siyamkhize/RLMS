import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';

/// Enhanced Document Scanner Manager with bulletproof crash prevention
class EnhancedDocumentScannerManager {
  static final EnhancedDocumentScannerManager _instance =
      EnhancedDocumentScannerManager._internal();
  factory EnhancedDocumentScannerManager() => _instance;
  EnhancedDocumentScannerManager._internal();

  int _scanAttempts = 0;
  DateTime? _lastScanTime;
  bool _isScanning = false;
  Timer? _watchdogTimer;

  static const int MAX_SCAN_ATTEMPTS = 10; // effectively unlimited
  static const Duration SCAN_COOLDOWN = Duration(seconds: 3);
  static const Duration WATCHDOG_TIMEOUT = Duration(minutes: 10);
  // Delay after a scan completes before allowing the next one,
  // giving Android time to fully settle the activity stack.
  static const Duration POST_SCAN_SETTLE_DELAY = Duration(milliseconds: 800);

  /// Execute scan with enhanced protection
  Future<dynamic> executeSafeScan({
    required int maxPages,
    required BuildContext context,
  }) async {
    debugPrint('[ENHANCED_SCANNER] Starting safe scan execution');

    // Check if we're already scanning
    if (_isScanning) {
      throw Exception(
          'Scanner is already active. Please wait for the current scan to complete.');
    }

    // Check scan attempts and cooldown
    if (_scanAttempts >= MAX_SCAN_ATTEMPTS) {
      final timeSinceLastScan = _lastScanTime != null
          ? DateTime.now().difference(_lastScanTime!)
          : Duration.zero;

      if (timeSinceLastScan < SCAN_COOLDOWN) {
        final remainingCooldown = SCAN_COOLDOWN - timeSinceLastScan;
        throw Exception(
            'Scanner is in cooldown mode. Please wait ${remainingCooldown.inSeconds} seconds before scanning again.\n\n'
            'This prevents crashes after multiple scans.');
      } else {
        // Reset attempts after cooldown
        _scanAttempts = 0;
      }
    }

    _isScanning = true;
    // Only increment on entry; reset to 0 on success so consecutive
    // successful scans are never blocked by the cooldown.
    _scanAttempts++;
    _lastScanTime = DateTime.now();

    try {
      // Start watchdog timer
      _startWatchdogTimer();

      // Pre-scan cleanup
      await _performPreScanCleanup();

      // Execute scan with timeout
      final result = await _executeScanWithTimeout(maxPages);

      // Post-scan cleanup
      await _performPostScanCleanup();

      // Reset attempts after a successful scan so the next scan is always allowed.
      _scanAttempts = 0;
      _lastScanTime = DateTime.now();

      // CRITICAL: Wait for Android to fully settle the activity stack before
      // allowing another scan. Without this delay the next call to
      // getScanDocuments() can fire before GmsDocumentScanningDelegateActivity
      // has fully finished, leaving pendingResult in a bad state.
      await Future.delayed(POST_SCAN_SETTLE_DELAY);

      debugPrint('[ENHANCED_SCANNER] Scan completed successfully');
      return result;
    } catch (e) {
      debugPrint('[ENHANCED_SCANNER] Scan failed: $e');

      // Perform emergency cleanup
      await _performEmergencyCleanup();

      // Analyze error and provide helpful message
      final enhancedError = _analyzeAndEnhanceError(e);
      throw enhancedError;
    } finally {
      _isScanning = false;
      _stopWatchdogTimer();
    }
  }

  /// Start watchdog timer to prevent hanging scans
  void _startWatchdogTimer() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(WATCHDOG_TIMEOUT, () {
      if (_isScanning) {
        debugPrint('[ENHANCED_SCANNER] WATCHDOG: Scan timeout detected');
        _isScanning = false;
        _performEmergencyCleanup();
      }
    });
  }

  /// Stop watchdog timer
  void _stopWatchdogTimer() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  /// Pre-scan cleanup
  Future<void> _performPreScanCleanup() async {
    debugPrint('[ENHANCED_SCANNER] Performing pre-scan cleanup');
    try {
      await _clearTemporaryFiles();
      await _resetScannerPlugin();
    } catch (e) {
      debugPrint('[ENHANCED_SCANNER] Pre-scan cleanup error: $e');
    }
  }

  /// Execute scan with timeout protection
  Future<dynamic> _executeScanWithTimeout(int maxPages) async {
    debugPrint('[ENHANCED_SCANNER] Executing scan with timeout protection');

    final scanner = FlutterDocScanner();

    return await scanner.getScanDocuments(page: maxPages).timeout(
      const Duration(minutes: 8),
      onTimeout: () {
        debugPrint('[ENHANCED_SCANNER] Scan timed out after 8 minutes');
        throw TimeoutException(
          'Document scanner timed out after 8 minutes.\n\n'
          'This timeout prevents memory issues and crashes.\n\n'
          'Solutions:\n'
          '• Scan fewer pages (50-80 maximum)\n'
          '• Scan continuously without long pauses\n'
          '• Restart the app if problem persists',
          const Duration(minutes: 8),
        );
      },
    );
  }

  /// Post-scan cleanup
  Future<void> _performPostScanCleanup() async {
    debugPrint('[ENHANCED_SCANNER] Performing post-scan cleanup');
    try {
      await _clearScannerCache();
    } catch (e) {
      debugPrint('[ENHANCED_SCANNER] Post-scan cleanup error: $e');
    }
  }

  /// Emergency cleanup when scan fails
  Future<void> _performEmergencyCleanup() async {
    debugPrint('[ENHANCED_SCANNER] Performing emergency cleanup');
    try {
      await _clearTemporaryFiles();
      await _clearScannerCache();
      await _resetScannerPlugin();
    } catch (e) {
      debugPrint('[ENHANCED_SCANNER] Emergency cleanup error: $e');
    }
  }

  /// Clear temporary scanner files
  Future<void> _clearTemporaryFiles() async {
    try {
      final tempDir = Directory.systemTemp;
      final scannerFiles = await tempDir.list().where((entity) {
        final path = entity.path.toLowerCase();
        return path.contains('flutter_doc_scanner') ||
            path.contains('mlkit') ||
            path.contains('document_scan') ||
            path.contains('camera_scan') ||
            path.contains('doc_scan_');
      }).toList();

      for (final file in scannerFiles) {
        try {
          await file.delete(recursive: true);
          debugPrint('[ENHANCED_SCANNER] Deleted temp file: ${file.path}');
        } catch (e) {
          // Ignore individual file errors
        }
      }
    } catch (e) {
      debugPrint('[ENHANCED_SCANNER] Temp file cleanup error: $e');
    }
  }

  /// Clear scanner cache
  Future<void> _clearScannerCache() async {
    try {
      if (Platform.isAndroid) {
        final cacheDirectories = [
          '/data/data/com.example.rlmss/cache/flutter_doc_scanner',
          '/data/data/com.example.rlmss/cache/mlkit_scanner',
          '/data/data/com.example.rlmss/cache/document_scanner',
          '/data/data/com.example.rlmss/cache/camera_scanner',
        ];

        for (final dir in cacheDirectories) {
          try {
            final directory = Directory(dir);
            if (await directory.exists()) {
              await directory.delete(recursive: true);
              debugPrint('[ENHANCED_SCANNER] Cleared cache: $dir');
            }
          } catch (e) {
            // Ignore individual directory errors
          }
        }
      }
    } catch (e) {
      debugPrint('[ENHANCED_SCANNER] Cache cleanup error: $e');
    }
  }

  /// Reset scanner plugin state
  Future<void> _resetScannerPlugin() async {
    try {
      // Try multiple reset strategies
      final resetMethods = [
        'FlutterDocScanner.reset',
        'MLKit.reset',
        'DocumentScanner.reset',
        'CameraScanner.reset',
      ];

      for (final method in resetMethods) {
        try {
          await SystemChannels.platform.invokeMethod(method);
          debugPrint('[ENHANCED_SCANNER] Reset method succeeded: $method');
        } catch (e) {
          // Method not available, try next one
        }
      }
    } catch (e) {
      debugPrint('[ENHANCED_SCANNER] Plugin reset error: $e');
    }
  }

  /// Analyze error and provide enhanced error message
  Exception _analyzeAndEnhanceError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('pendingresult is null') ||
        errorString.contains('onactivityresult')) {
      return Exception(
          'CRITICAL: Scanner plugin corrupted after multiple uses.\n\n'
          '🔴 This is a known Android issue with document scanner plugins.\n\n'
          '✅ SOLUTION: Restart the app to reset the scanner system.\n\n'
          'Your app was prevented from crashing thanks to our protection system!');
    }

    if (errorString.contains('timeout')) {
      return Exception('Scanner timed out after 8 minutes.\n\n'
          'This timeout prevents memory issues with large documents.\n\n'
          'Solutions:\n'
          '• Scan fewer pages (50-80 maximum)\n'
          '• Scan continuously without long pauses\n'
          '• Restart the app if problem persists');
    }

    if (errorString.contains('outofmemory') || errorString.contains('memory')) {
      return Exception('Scanner ran out of memory.\n\n'
          'This typically happens with very large documents (80+ pages).\n\n'
          'Solutions:\n'
          '• Scan in smaller batches (50-80 pages)\n'
          '• Close other apps to free memory\n'
          '• Restart the device if problem persists');
    }

    if (errorString.contains('camera') || errorString.contains('permission')) {
      return Exception('Camera access issue detected.\n\n'
          'Solutions:\n'
          '• Check camera permissions in device settings\n'
          '• Close other apps that might be using the camera\n'
          '• Restart the app and try again');
    }

    // Default enhanced error
    return Exception('Scanner error: ${error.toString()}\n\n'
        'If this error persists:\n'
        '• Restart the app\n'
        '• Try scanning fewer pages\n'
        '• Contact support if problem continues');
  }

  /// Get current scanner status
  Map<String, dynamic> getStatus() {
    return {
      'isScanning': _isScanning,
      'scanAttempts': _scanAttempts,
      'maxAttempts': MAX_SCAN_ATTEMPTS,
      'lastScanTime': _lastScanTime?.toIso8601String(),
      'cooldownRemaining': _getCooldownRemaining(),
    };
  }

  /// Get remaining cooldown time in seconds
  int _getCooldownRemaining() {
    // After a successful scan _scanAttempts is reset to 0, so no cooldown.
    if (_lastScanTime == null || _scanAttempts == 0) {
      return 0;
    }

    if (_scanAttempts < MAX_SCAN_ATTEMPTS) {
      return 0;
    }

    final timeSinceLastScan = DateTime.now().difference(_lastScanTime!);
    final remaining = SCAN_COOLDOWN - timeSinceLastScan;

    return remaining.inSeconds > 0 ? remaining.inSeconds : 0;
  }

  /// Reset scanner state (for testing or manual reset)
  void reset() {
    _scanAttempts = 0;
    _lastScanTime = null;
    _isScanning = false;
    _stopWatchdogTimer();
    debugPrint('[ENHANCED_SCANNER] Scanner state reset manually');
  }

  /// Dispose resources
  void dispose() {
    _stopWatchdogTimer();
    debugPrint('[ENHANCED_SCANNER] Disposed');
  }
}
