import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Manages document scanner state to prevent SCAN_IN_PROGRESS errors
class DocumentScannerManager {
  static final DocumentScannerManager _instance =
      DocumentScannerManager._internal();
  factory DocumentScannerManager() => _instance;
  DocumentScannerManager._internal();

  bool _isScanning = false;
  DateTime? _lastScanTime;
  static const Duration _minTimeBetweenScans = Duration(seconds: 2);

  /// Check if scanner is currently busy
  bool get isScanning => _isScanning;

  /// Get time since last scan
  Duration? get timeSinceLastScan {
    if (_lastScanTime == null) return null;
    return DateTime.now().difference(_lastScanTime!);
  }

  /// Safely start a document scan with automatic retry logic and enhanced error handling
  Future<dynamic> scanDocuments({int page = 10, int maxRetries = 3}) async {
    // ENHANCED: Check for problematic state before starting
    if (isInProblematicState()) {
      debugPrint('[SCANNER_MGR] Scanner in problematic state - recovering...');
      recoverFromProblematicState();
      await Future.delayed(const Duration(seconds: 3));
    }

    // Wait if a scan was recently completed
    if (_lastScanTime != null) {
      final timeSince = timeSinceLastScan!;
      if (timeSince < _minTimeBetweenScans) {
        final waitTime = _minTimeBetweenScans - timeSince;
        debugPrint(
            '[SCANNER_MGR] Waiting ${waitTime.inMilliseconds}ms before next scan');
        await Future.delayed(waitTime);
      }
    }

    // Check if already scanning
    if (_isScanning) {
      throw Exception('Scanner is already in use. Please wait and try again.');
    }

    _isScanning = true;
    _lastScanTime = DateTime.now(); // Mark start time

    try {
      final scanner = FlutterDocScanner();
      dynamic result;
      int retryCount = 0;

      while (retryCount < maxRetries) {
        try {
          debugPrint(
              '[SCANNER_MGR] Scan attempt ${retryCount + 1}/$maxRetries');

          // CRITICAL FIX: Add timeout to prevent hanging on pendingResult null issue
          result = await scanner.getScanDocuments(page: page).timeout(
            const Duration(minutes: 10),
            onTimeout: () {
              debugPrint(
                  '[SCANNER_MGR] Scanner timeout - likely pendingResult null issue');
              throw Exception(
                  'Scanner timeout - please try again. If this persists, restart the app.');
            },
          );

          debugPrint('[SCANNER_MGR] Scan completed successfully');
          break;
        } catch (e) {
          debugPrint('[SCANNER_MGR] Scan attempt ${retryCount + 1} failed: $e');

          // ENHANCED ERROR HANDLING: Handle specific plugin errors
          if (e.toString().contains('pendingResult is null') ||
              e.toString().contains('onActivityResult') ||
              e.toString().contains('requestCode=213312') ||
              e.toString().contains('GmsDocumentScanningDelegateActivity') ||
              e.toString().contains('DocumentScanningActivity')) {
            debugPrint(
                '[SCANNER_MGR] Detected plugin callback error - Android activity issue');
            retryCount++;
            if (retryCount < maxRetries) {
              final waitTime = Duration(seconds: 5 * retryCount);
              debugPrint(
                  '[SCANNER_MGR] Waiting ${waitTime.inSeconds}s before retry for plugin reset...');
              await Future.delayed(waitTime);
              continue;
            } else {
              throw Exception(
                  'Document scanner plugin error. The scanner activity was interrupted by Android. Please close this screen and try again, or restart the app if the problem persists.');
            }
          } else if (e.toString().contains('SCAN_IN_PROGRESS')) {
            retryCount++;
            if (retryCount < maxRetries) {
              // Exponential backoff: wait longer between retries
              final waitTime = Duration(seconds: 3 * retryCount);
              debugPrint(
                  '[SCANNER_MGR] SCAN_IN_PROGRESS detected, waiting ${waitTime.inSeconds}s before retry...');
              await Future.delayed(waitTime);
              continue;
            } else {
              debugPrint(
                  '[SCANNER_MGR] Max retries reached for SCAN_IN_PROGRESS');
              throw Exception(
                  'Scanner is busy. Please close any other scanning apps and try again.');
            }
          } else if (e.toString().contains('timeout') ||
              e.toString().contains('Scanner timeout')) {
            // Don't retry timeouts - they indicate a deeper issue
            debugPrint('[SCANNER_MGR] Scanner timeout detected - not retrying');
            throw Exception(
                'Scanner session timed out. This may happen with very large documents. Try scanning fewer pages at once.');
          } else if (e.toString().contains('OutOfMemoryError') ||
              e.toString().contains('memory')) {
            debugPrint('[SCANNER_MGR] Memory error detected - not retrying');
            throw Exception(
                'Scanner ran out of memory. Please scan fewer pages (50-80 maximum) or restart the app.');
          } else if (e.toString().contains('Camera') ||
              e.toString().contains('camera')) {
            debugPrint('[SCANNER_MGR] Camera error detected');
            retryCount++;
            if (retryCount < maxRetries) {
              final waitTime = Duration(seconds: 2 * retryCount);
              debugPrint(
                  '[SCANNER_MGR] Camera issue, waiting ${waitTime.inSeconds}s before retry...');
              await Future.delayed(waitTime);
              continue;
            } else {
              throw Exception(
                  'Camera access error. Please close other camera apps and try again.');
            }
          } else {
            // For other errors, don't retry
            debugPrint('[SCANNER_MGR] Non-retryable error: $e');
            rethrow;
          }
        }
      }

      return result;
    } finally {
      _isScanning = false;
      _lastScanTime = DateTime.now(); // Update completion time
      debugPrint('[SCANNER_MGR] Scanner state reset');
    }
  }

  /// Reset scanner state (call this if app lifecycle changes)
  void reset() {
    debugPrint('[SCANNER_MGR] Resetting scanner state');
    _isScanning = false;
    _lastScanTime = null;
  }

  /// Force reset scanner state (emergency use only)
  void forceReset() {
    debugPrint('[SCANNER_MGR] Force resetting scanner state');
    _isScanning = false;
    _lastScanTime = DateTime.now().subtract(const Duration(minutes: 1));
  }

  /// Check if the scanner is in a problematic state (e.g., pendingResult null)
  bool isInProblematicState() {
    // If scanning has been active for more than 15 minutes, likely stuck
    if (_isScanning && _lastScanTime != null) {
      final timeSinceStart = DateTime.now().difference(_lastScanTime!);
      if (timeSinceStart > const Duration(minutes: 15)) {
        debugPrint(
            '[SCANNER_MGR] Scanner appears stuck - active for ${timeSinceStart.inMinutes} minutes');
        return true;
      }
    }
    return false;
  }

  /// Recover from problematic state
  void recoverFromProblematicState() {
    if (isInProblematicState()) {
      debugPrint('[SCANNER_MGR] Recovering from problematic state');
      forceReset();
    }
  }
}
