import 'dart:async';

/// Global camera resource manager to prevent conflicts between different camera operations
/// This ensures only one camera operation can run at a time across the entire app
/// Handles both Flutter camera operations and external ML Kit document scanning
class CameraResourceManager {
  static final CameraResourceManager _instance =
      CameraResourceManager._internal();
  factory CameraResourceManager() => _instance;
  CameraResourceManager._internal();

  bool _isCameraInUse = false;
  String? _currentUser;
  final List<Completer<void>> _waitingQueue = [];

  // Track ML Kit document scanner state
  bool _isMLKitScannerActive = false;
  Timer? _mlkitTimeoutTimer;

  /// Check if camera is currently in use (including ML Kit scanner)
  bool get isCameraInUse => _isCameraInUse || _isMLKitScannerActive;

  /// Get current camera user (for debugging)
  String? get currentUser => _currentUser;

  /// Request camera access - will wait if camera is busy
  Future<bool> requestCameraAccess(String requester,
      {Duration? timeout}) async {
    print('[CAMERA_MANAGER] $requester requesting camera access');

    // If camera is free (including ML Kit), grant access immediately
    if (!_isCameraInUse && !_isMLKitScannerActive) {
      _isCameraInUse = true;
      _currentUser = requester;
      print('[CAMERA_MANAGER] Camera access granted to $requester');
      return true;
    }

    // Camera is busy - either wait or return false based on timeout
    if (timeout != null) {
      String busyReason = _isMLKitScannerActive
          ? 'ML Kit Document Scanner'
          : _currentUser ?? 'Unknown';
      print(
          '[CAMERA_MANAGER] Camera busy (used by $busyReason), $requester waiting with timeout ${timeout.inSeconds}s');

      final completer = Completer<void>();
      _waitingQueue.add(completer);

      try {
        await completer.future.timeout(timeout);
        // If we get here, camera became available
        if (!_isCameraInUse && !_isMLKitScannerActive) {
          _isCameraInUse = true;
          _currentUser = requester;
          print(
              '[CAMERA_MANAGER] Camera access granted to $requester after wait');
          return true;
        }
      } catch (e) {
        // Timeout or other error
        _waitingQueue.remove(completer);
        print('[CAMERA_MANAGER] Camera access timeout for $requester');
        return false;
      }
    }

    String busyReason = _isMLKitScannerActive
        ? 'ML Kit Document Scanner'
        : _currentUser ?? 'Unknown';
    print(
        '[CAMERA_MANAGER] Camera busy (used by $busyReason), $requester denied access');
    return false;
  }

  /// Release camera access
  void releaseCameraAccess(String requester) {
    if (_currentUser == requester) {
      print('[CAMERA_MANAGER] Camera access released by $requester');
      _isCameraInUse = false;
      _currentUser = null;

      // Notify next in queue
      if (_waitingQueue.isNotEmpty) {
        final nextCompleter = _waitingQueue.removeAt(0);
        if (!nextCompleter.isCompleted) {
          nextCompleter.complete();
        }
      }
    } else {
      print(
          '[CAMERA_MANAGER] WARNING: $requester tried to release camera but current user is $_currentUser');
    }
  }

  /// Force release camera (for emergency situations)
  void forceReleaseCameraAccess(String reason) {
    print(
        '[CAMERA_MANAGER] FORCE RELEASE: $reason (was used by $_currentUser)');
    _isCameraInUse = false;
    _currentUser = null;

    // Complete all waiting requests (they'll need to re-request)
    for (final completer in _waitingQueue) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _waitingQueue.clear();
  }

  /// Get status for debugging
  Map<String, dynamic> getStatus() {
    return {
      'isCameraInUse': _isCameraInUse,
      'currentUser': _currentUser,
      'isMLKitScannerActive': _isMLKitScannerActive,
      'waitingQueueLength': _waitingQueue.length,
    };
  }

  /// Mark ML Kit document scanner as active
  void markMLKitScannerActive() {
    print('[CAMERA_MANAGER] ML Kit Document Scanner started');
    _isMLKitScannerActive = true;

    // Set a timeout to automatically release if ML Kit gets stuck
    _mlkitTimeoutTimer?.cancel();
    _mlkitTimeoutTimer = Timer(const Duration(minutes: 5), () {
      print('[CAMERA_MANAGER] ML Kit Scanner timeout - force releasing');
      markMLKitScannerInactive();
    });
  }

  /// Mark ML Kit document scanner as inactive
  void markMLKitScannerInactive() {
    print('[CAMERA_MANAGER] ML Kit Document Scanner finished');
    _isMLKitScannerActive = false;

    // Cancel timeout timer
    _mlkitTimeoutTimer?.cancel();
    _mlkitTimeoutTimer = null;

    // Notify next in queue
    if (_waitingQueue.isNotEmpty) {
      final nextCompleter = _waitingQueue.removeAt(0);
      if (!nextCompleter.isCompleted) {
        nextCompleter.complete();
      }
    }
  }

  /// Check if ML Kit scanner is active
  bool get isMLKitScannerActive => _isMLKitScannerActive;
}
