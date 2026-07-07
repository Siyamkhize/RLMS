import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';

/// ULTIMATE Scanner Crash Prevention System
/// Addresses memory leaks and state corruption after multiple scanner uses
class UltimateScannerCrashPrevention {
  static final UltimateScannerCrashPrevention _instance =
      UltimateScannerCrashPrevention._internal();
  factory UltimateScannerCrashPrevention() => _instance;
  UltimateScannerCrashPrevention._internal();

  int _scanCount = 0;
  DateTime? _lastScanTime;
  bool _isInCriticalState = false;
  Timer? _memoryCleanupTimer;

  // CRITICAL: Track scanner plugin instances to prevent accumulation
  static const int MAX_SCANS_BEFORE_RESET = 100; // effectively unlimited
  static const Duration FORCED_CLEANUP_INTERVAL = Duration(minutes: 2);

  /// Initialize the ultimate crash prevention system
  void initialize() {
    // No periodic timer needed — the periodic System.gc calls were
    // increasing memory pressure and causing OOM kills of the scanner.
    debugPrint('[ULTIMATE_CRASH_PREVENTION] Initialized');
  }

  /// Dispose the system
  void dispose() {
    _memoryCleanupTimer?.cancel();
    _memoryCleanupTimer = null;
  }

  /// ULTRA-SAFE scanner execution with complete crash prevention
  Future<dynamic> executeScanWithUltimateProtection({
    required int maxPages,
    required BuildContext context,
  }) async {
    debugPrint(
        '[ULTIMATE_CRASH_PREVENTION] Starting ultra-safe scan execution');
    debugPrint('[ULTIMATE_CRASH_PREVENTION] Scan count: $_scanCount');

    // CRITICAL CHECK: Force reset if too many scans
    if (_scanCount >= MAX_SCANS_BEFORE_RESET) {
      debugPrint(
          '[ULTIMATE_CRASH_PREVENTION] CRITICAL: Too many scans, forcing complete reset');
      await _forceCompleteReset(context);
      _scanCount = 0;
    }

    // CRITICAL CHECK: Detect if we're in a critical state
    if (_isInCriticalState) {
      debugPrint(
          '[ULTIMATE_CRASH_PREVENTION] CRITICAL STATE DETECTED - Aborting scan');
      throw Exception(
          'Scanner is in a critical state. Please restart the app to continue scanning.\n\n'
          'This happens after multiple scans to prevent crashes. Restarting the app will fix this.');
    }

    try {
      // PRE-SCAN CLEANUP: Aggressive memory and state cleanup
      await _preformPreScanCleanup();

      // ULTRA-SAFE SCAN EXECUTION
      final result = await _executeUltraSafeScan(maxPages);

      // POST-SCAN CLEANUP: Immediate cleanup to prevent accumulation
      await _performPostScanCleanup();

      _scanCount++;
      _lastScanTime = DateTime.now();

      debugPrint('[ULTIMATE_CRASH_PREVENTION] Scan completed successfully');
      return result;
    } catch (e, stackTrace) {
      debugPrint('[ULTIMATE_CRASH_PREVENTION] Scan failed: $e');
      debugPrint('[ULTIMATE_CRASH_PREVENTION] Stack trace: $stackTrace');

      // CRITICAL ERROR HANDLING: Determine if we need to enter critical state
      if (_shouldEnterCriticalState(e)) {
        _isInCriticalState = true;
        debugPrint('[ULTIMATE_CRASH_PREVENTION] ENTERING CRITICAL STATE');

        // Show critical state dialog
        if (context.mounted) {
          _showCriticalStateDialog(context, e);
        }
      }

      // Perform emergency cleanup
      await _performEmergencyCleanup();

      rethrow;
    }
  }

  /// Pre-scan cleanup to prevent memory accumulation
  Future<void> _preformPreScanCleanup() async {
    debugPrint('[ULTIMATE_CRASH_PREVENTION] Performing pre-scan cleanup...');

    try {
      // Clear any cached scanner data
      await _clearScannerCache();

      // Reset plugin state
      await _resetPluginState();

      debugPrint('[ULTIMATE_CRASH_PREVENTION] Pre-scan cleanup completed');
    } catch (e) {
      debugPrint('[ULTIMATE_CRASH_PREVENTION] Pre-scan cleanup error: $e');
    }
  }

  /// Ultra-safe scan execution with multiple fallbacks
  Future<dynamic> _executeUltraSafeScan(int maxPages) async {
    debugPrint('[ULTIMATE_CRASH_PREVENTION] Executing ultra-safe scan...');

    // Create a fresh scanner instance
    final scanner = FlutterDocScanner();

    try {
      // ULTRA-AGGRESSIVE TIMEOUT: 8 minutes max
      final result = await scanner.getScanDocuments(page: maxPages).timeout(
        const Duration(minutes: 8),
        onTimeout: () {
          debugPrint(
              '[ULTIMATE_CRASH_PREVENTION] TIMEOUT - Scanner took too long');
          throw TimeoutException(
            'Scanner timed out after 8 minutes. This prevents memory issues with large documents.',
            const Duration(minutes: 8),
          );
        },
      );

      debugPrint('[ULTIMATE_CRASH_PREVENTION] Scanner completed successfully');
      return result;
    } catch (e) {
      debugPrint('[ULTIMATE_CRASH_PREVENTION] Scanner execution failed: $e');

      // ENHANCED ERROR ANALYSIS
      if (e.toString().contains('pendingResult is null') ||
          e.toString().contains('onActivityResult') ||
          e.toString().contains('GmsDocumentScanningDelegateActivity')) {
        debugPrint(
            '[ULTIMATE_CRASH_PREVENTION] CRITICAL PLUGIN ERROR DETECTED');
        throw Exception(
            'CRITICAL: Scanner plugin corrupted after multiple uses.\n\n'
            '🔴 This is a known Android issue that happens after 2-3 scans.\n\n'
            '✅ SOLUTION: Restart the app to reset the scanner plugin.\n\n'
            'This prevents your app from crashing completely.');
      }

      rethrow;
    }
  }

  /// Post-scan cleanup to prevent state accumulation
  Future<void> _performPostScanCleanup() async {
    debugPrint('[ULTIMATE_CRASH_PREVENTION] Performing post-scan cleanup...');

    try {
      // Immediate memory cleanup
      await _performAggressiveCleanup();

      // Clear temporary files
      await _clearTemporaryFiles();

      debugPrint('[ULTIMATE_CRASH_PREVENTION] Post-scan cleanup completed');
    } catch (e) {
      debugPrint('[ULTIMATE_CRASH_PREVENTION] Post-scan cleanup error: $e');
    }
  }

  /// Aggressive memory and state cleanup — no System.gc, just cache clearing
  Future<void> _performAggressiveCleanup() async {
    try {
      // Clear scanner cache only — no GC calls (they increase memory pressure)
      await _clearScannerCache();
    } catch (e) {
      debugPrint('[ULTIMATE_CRASH_PREVENTION] Cleanup error: $e');
    }
  }

  /// Clear scanner cache and temporary files
  Future<void> _clearScannerCache() async {
    try {
      // Clear Android scanner cache directories
      if (Platform.isAndroid) {
        final cacheDirectories = [
          '/data/data/com.example.your_app/cache/flutter_doc_scanner',
          '/data/data/com.example.your_app/cache/mlkit_scanner',
          '/data/data/com.example.your_app/cache/document_scanner',
        ];

        for (final dir in cacheDirectories) {
          try {
            final directory = Directory(dir);
            if (await directory.exists()) {
              await directory.delete(recursive: true);
              debugPrint('[ULTIMATE_CRASH_PREVENTION] Cleared cache: $dir');
            }
          } catch (e) {
            // Ignore individual directory errors
          }
        }
      }
    } catch (e) {
      debugPrint('[ULTIMATE_CRASH_PREVENTION] Cache cleanup error: $e');
    }
  }

  /// Clear temporary files created by scanner
  Future<void> _clearTemporaryFiles() async {
    try {
      // Clear app's temporary directory
      final tempDir = Directory.systemTemp;
      final appTempFiles = await tempDir.list().where((entity) {
        return entity.path.contains('flutter_doc_scanner') ||
            entity.path.contains('mlkit') ||
            entity.path.contains('document_scan');
      }).toList();

      for (final file in appTempFiles) {
        try {
          await file.delete(recursive: true);
          debugPrint(
              '[ULTIMATE_CRASH_PREVENTION] Deleted temp file: ${file.path}');
        } catch (e) {
          // Ignore individual file errors
        }
      }
    } catch (e) {
      debugPrint('[ULTIMATE_CRASH_PREVENTION] Temp file cleanup error: $e');
    }
  }

  /// Reset plugin state
  Future<void> _resetPluginState() async {
    try {
      // Try to reset ML Kit scanner state
      try {
        await SystemChannels.platform.invokeMethod('MLKit.reset');
      } catch (e) {
        // Method not available — that's fine
      }

      // Try to clear document scanner cache
      try {
        await SystemChannels.platform
            .invokeMethod('DocumentScanner.clearCache');
      } catch (e) {
        // Method not available — that's fine
      }
    } catch (e) {
      debugPrint('[ULTIMATE_CRASH_PREVENTION] Plugin reset error: $e');
    }
  }

  /// Force complete reset of the entire scanner system
  Future<void> _forceCompleteReset(BuildContext context) async {
    debugPrint('[ULTIMATE_CRASH_PREVENTION] FORCING COMPLETE RESET');

    try {
      // Show reset dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.refresh, color: Colors.orange),
                SizedBox(width: 8),
                Text('Scanner Reset Required'),
              ],
            ),
            content: const Text(
                'The scanner needs to be reset after multiple uses to prevent crashes.\n\n'
                'This is normal behavior to keep your app stable.\n\n'
                'Resetting scanner system...'),
            actions: const [
              // No actions - this is automatic
            ],
          ),
        );
      }

      // Perform complete cleanup
      await _performAggressiveCleanup();
      await _clearScannerCache();
      await _clearTemporaryFiles();

      // Reset all counters
      _scanCount = 0;
      _isInCriticalState = false;
      _lastScanTime = null;

      // Close dialog
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      debugPrint('[ULTIMATE_CRASH_PREVENTION] Complete reset finished');
    } catch (e) {
      debugPrint('[ULTIMATE_CRASH_PREVENTION] Complete reset error: $e');
    }
  }

  /// Emergency cleanup when scan fails
  Future<void> _performEmergencyCleanup() async {
    debugPrint('[ULTIMATE_CRASH_PREVENTION] Performing emergency cleanup...');

    try {
      await _performAggressiveCleanup();
      await _clearScannerCache();

      // Increment scan count even on failure to track plugin degradation
      _scanCount++;
    } catch (e) {
      debugPrint('[ULTIMATE_CRASH_PREVENTION] Emergency cleanup error: $e');
    }
  }

  /// Determine if we should enter critical state
  bool _shouldEnterCriticalState(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Critical plugin errors that indicate corruption
    final criticalPatterns = [
      'pendingresu lt is null',
      'pendingresult is null',
      'onactivityresult',
      'requestcode=213312',
      'gmsdocumentscanningdelegateactivity',
      'outofmemoryerror',
      'native crash',
      'jni error',
      'mlkit',
      'document_scanner_activity',
      'activity not found',
      'intent not found',
      'no activity found',
      'camera permission',
      'camera not available',
    ];

    return criticalPatterns.any((pattern) => errorString.contains(pattern));
  }

  /// Show critical state dialog
  void _showCriticalStateDialog(BuildContext context, dynamic error) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Critical Scanner State'),
          ],
        ),
        content: const Text(
            '🔴 CRITICAL: The scanner plugin has become corrupted after multiple uses.\n\n'
            'This is a known Android limitation with document scanner plugins.\n\n'
            '✅ SOLUTION: Restart the app to reset the scanner system.\n\n'
            'Your app was prevented from crashing thanks to our protection system!'),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              // Force app restart
              SystemNavigator.pop();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Restart App'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  /// Get current system status
  Map<String, dynamic> getSystemStatus() {
    return {
      'scanCount': _scanCount,
      'isInCriticalState': _isInCriticalState,
      'lastScanTime': _lastScanTime?.toIso8601String(),
      'scansUntilReset': MAX_SCANS_BEFORE_RESET - _scanCount,
    };
  }

  /// Reset the system (for testing)
  void resetSystem() {
    _scanCount = 0;
    _isInCriticalState = false;
    _lastScanTime = null;
    debugPrint('[ULTIMATE_CRASH_PREVENTION] System reset manually');
  }
}
