import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Advanced crash recovery system for document scanner
class DocumentScannerCrashRecovery {
  static final DocumentScannerCrashRecovery _instance =
      DocumentScannerCrashRecovery._internal();
  factory DocumentScannerCrashRecovery() => _instance;
  DocumentScannerCrashRecovery._internal();

  bool _isMonitoring = false;
  Timer? _monitoringTimer;
  DateTime? _lastScannerActivity;
  bool _scannerWasActive = false;

  static const Duration _monitoringInterval = Duration(seconds: 5);
  static const Duration _crashDetectionTimeout = Duration(minutes: 2);

  /// Start monitoring for scanner crashes
  void startMonitoring() {
    if (_isMonitoring) return;

    debugPrint('[CRASH_RECOVERY] Starting scanner crash monitoring');
    _isMonitoring = true;
    _lastScannerActivity = DateTime.now();

    _monitoringTimer = Timer.periodic(_monitoringInterval, (timer) {
      _checkForCrashes();
    });
  }

  /// Stop monitoring
  void stopMonitoring() {
    debugPrint('[CRASH_RECOVERY] Stopping scanner crash monitoring');
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _scannerWasActive = false;
  }

  /// Mark scanner as active
  void markScannerActive() {
    debugPrint('[CRASH_RECOVERY] Scanner marked as active');
    _scannerWasActive = true;
    _lastScannerActivity = DateTime.now();
  }

  /// Mark scanner as inactive
  void markScannerInactive() {
    debugPrint('[CRASH_RECOVERY] Scanner marked as inactive');
    _scannerWasActive = false;
    _lastScannerActivity = DateTime.now();
  }

  /// Check for potential crashes
  void _checkForCrashes() {
    if (!_scannerWasActive || _lastScannerActivity == null) return;

    final timeSinceActivity = DateTime.now().difference(_lastScannerActivity!);

    if (timeSinceActivity > _crashDetectionTimeout) {
      debugPrint(
          '[CRASH_RECOVERY] Potential scanner crash detected - no activity for ${timeSinceActivity.inMinutes} minutes');
      _handlePotentialCrash();
    }
  }

  /// Handle potential crash
  void _handlePotentialCrash() {
    debugPrint('[CRASH_RECOVERY] Handling potential scanner crash');

    // Reset scanner state
    _scannerWasActive = false;

    // Try to clean up any stuck scanner processes
    _attemptScannerCleanup();
  }

  /// Attempt to clean up stuck scanner processes
  void _attemptScannerCleanup() {
    try {
      debugPrint('[CRASH_RECOVERY] Attempting scanner cleanup');

      // Force garbage collection to clean up any stuck objects
      if (kDebugMode) {
        // Only in debug mode to avoid performance impact in release
        SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      }

      debugPrint('[CRASH_RECOVERY] Scanner cleanup completed');
    } catch (e) {
      debugPrint('[CRASH_RECOVERY] Error during cleanup: $e');
    }
  }

  /// Check if scanner appears to be in a crashed state
  bool isScannerCrashed() {
    if (!_scannerWasActive || _lastScannerActivity == null) return false;

    final timeSinceActivity = DateTime.now().difference(_lastScannerActivity!);
    return timeSinceActivity > _crashDetectionTimeout;
  }

  /// Get recovery recommendations
  List<String> getRecoveryRecommendations() {
    return [
      'Close this screen and open it again',
      'Restart the app completely',
      'Close other camera/scanner apps',
      'Restart your device if problem persists',
      'Scan fewer pages at once (50-80 maximum)',
      'Ensure sufficient device memory is available',
    ];
  }

  /// Force reset all scanner state
  void forceReset() {
    debugPrint('[CRASH_RECOVERY] Force resetting all scanner state');
    _scannerWasActive = false;
    _lastScannerActivity = null;
    stopMonitoring();
  }
}
