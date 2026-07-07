import 'dart:async';
import 'package:synchronized/synchronized.dart';

/// Database Operation Coordinator
/// Prevents multiple sync operations from running simultaneously and causing database locks
class DatabaseCoordinator {
  static final DatabaseCoordinator _instance = DatabaseCoordinator._internal();
  factory DatabaseCoordinator() => _instance;
  DatabaseCoordinator._internal();

  final Lock _syncLock = Lock();
  final Lock _transactionLock = Lock();

  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// Execute a sync operation with coordination
  Future<T> executeSyncOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Duration? timeout,
  }) async {
    return await _syncLock.synchronized(() async {
      if (_isSyncing) {
        print(
            '[DB_COORDINATOR] Sync operation "$operationName" skipped - another sync in progress');
        throw Exception('Another sync operation is already in progress');
      }

      try {
        _isSyncing = true;
        print('[DB_COORDINATOR] Starting sync operation: $operationName');

        final result = await operation().timeout(
          timeout ?? const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Sync operation "$operationName" timed out');
          },
        );

        _lastSyncTime = DateTime.now();
        print('[DB_COORDINATOR] Completed sync operation: $operationName');
        return result;
      } finally {
        _isSyncing = false;
      }
    });
  }

  /// Execute a database transaction with coordination
  Future<T> executeTransaction<T>(
    String operationName,
    Future<T> Function() transaction, {
    Duration? timeout,
  }) async {
    return await _transactionLock.synchronized(() async {
      print('[DB_COORDINATOR] Starting transaction: $operationName');

      try {
        final result = await transaction().timeout(
          timeout ?? const Duration(seconds: 8),
          onTimeout: () {
            throw TimeoutException('Transaction "$operationName" timed out');
          },
        );

        print('[DB_COORDINATOR] Completed transaction: $operationName');
        return result;
      } catch (e) {
        print('[DB_COORDINATOR] Transaction "$operationName" failed: $e');
        rethrow;
      }
    });
  }

  /// Check if a sync operation is currently running
  bool isSyncing() => _isSyncing;

  /// Get the last sync time
  DateTime? getLastSyncTime() => _lastSyncTime;

  /// Check if enough time has passed since last sync (prevents too frequent syncs)
  bool shouldAllowSync({Duration minInterval = const Duration(minutes: 1)}) {
    if (_lastSyncTime == null) return true;
    return DateTime.now().difference(_lastSyncTime!) >= minInterval;
  }
}
