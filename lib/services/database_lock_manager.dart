import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:flutter/foundation.dart';

/// Global Database Lock Manager
/// Ensures only one database operation runs at a time during critical phases
/// This prevents the "database has been locked for 0:00:10.000000" warnings
class DatabaseLockManager {
  static final DatabaseLockManager _instance = DatabaseLockManager._internal();
  factory DatabaseLockManager() => _instance;
  DatabaseLockManager._internal();

  final Lock _globalLock = Lock();
  bool _isCriticalPhase = false;
  String? _currentOperation;
  final List<String> _operationQueue = [];

  /// Mark the start of a critical phase (like login)
  void startCriticalPhase() {
    _isCriticalPhase = true;
    if (kDebugMode) {
      print(
          '[DB_LOCK] Critical phase started - all DB operations will be serialized');
    }
  }

  /// Mark the end of a critical phase
  void endCriticalPhase() {
    _isCriticalPhase = false;
    if (kDebugMode) {
      print('[DB_LOCK] Critical phase ended - normal DB operations resumed');
    }
  }

  /// Execute a database operation with global serialization
  Future<T> executeOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Duration timeout = const Duration(seconds: 30),
    bool forceSerialization = false,
  }) async {
    // During critical phase or when forced, serialize all operations
    if (_isCriticalPhase || forceSerialization) {
      return await _globalLock.synchronized(() async {
        return await _executeWithLogging(operationName, operation, timeout);
      });
    } else {
      // Normal execution outside critical phase
      return await _executeWithLogging(operationName, operation, timeout);
    }
  }

  /// Execute operation with logging and timeout
  Future<T> _executeWithLogging<T>(
    String operationName,
    Future<T> Function() operation,
    Duration timeout,
  ) async {
    _currentOperation = operationName;
    _operationQueue.add(
        '${DateTime.now().toIso8601String().substring(11, 19)}: $operationName');

    if (kDebugMode) {
      print('[DB_LOCK] Executing: $operationName');
    }

    try {
      final result = await operation().timeout(timeout);

      if (kDebugMode) {
        print('[DB_LOCK] ✓ Completed: $operationName');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('[DB_LOCK] ✗ Failed: $operationName - $e');
      }
      rethrow;
    } finally {
      _currentOperation = null;
    }
  }

  /// Get current operation status
  String? getCurrentOperation() => _currentOperation;

  /// Check if in critical phase
  bool isCriticalPhase() => _isCriticalPhase;

  /// Get operation history
  List<String> getOperationHistory() => List.from(_operationQueue);

  /// Clear operation history
  void clearHistory() => _operationQueue.clear();
}
