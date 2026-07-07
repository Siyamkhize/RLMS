import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';
import '../database_helper.dart';
import '../sync_service.dart';
import 'database_lock_manager.dart';

/// Database Initialization Manager
/// Handles the critical login phase by serializing all database operations
/// and showing proper loading indicators
class DatabaseInitializationManager {
  static final DatabaseInitializationManager _instance =
      DatabaseInitializationManager._internal();
  factory DatabaseInitializationManager() => _instance;
  DatabaseInitializationManager._internal();

  final Lock _initializationLock = Lock();
  final DatabaseLockManager _lockManager = DatabaseLockManager();
  bool _isInitialized = false;
  bool _isInitializing = false;
  String _currentStatus = '';
  final List<String> _initializationSteps = [];

  // Callbacks for UI updates
  Function(String)? _statusCallback;
  Function(List<String>)? _stepsCallback;

  /// Set callbacks for UI updates
  void setCallbacks({
    Function(String)? onStatusUpdate,
    Function(List<String>)? onStepsUpdate,
  }) {
    _statusCallback = onStatusUpdate;
    _stepsCallback = onStepsUpdate;
  }

  /// Update status and notify UI (simplified for user-facing messages)
  void _updateStatus(String status) {
    _currentStatus = status;
    _initializationSteps
        .add('${DateTime.now().toIso8601String().substring(11, 19)}: $status');

    if (kDebugMode) {
      print('[DB_INIT] $status');
    }

    // Only send simple status updates to UI, not detailed technical messages
    // The UI will just show "Logging in..." throughout the process
    _statusCallback?.call('Signing in...');

    // Don't send detailed steps to UI anymore
    // _stepsCallback?.call(List.from(_initializationSteps));
  }

  /// Check if database is initialized
  bool get isInitialized => _isInitialized;

  /// Check if initialization is in progress
  bool get isInitializing => _isInitializing;

  /// Get current status
  String get currentStatus => _currentStatus;

  /// Get initialization steps
  List<String> get initializationSteps => List.from(_initializationSteps);

  /// Initialize database with proper serialization
  Future<bool> initializeDatabase({
    bool forceReinitialize = false,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    return await _initializationLock.synchronized(() async {
      if (_isInitialized && !forceReinitialize) {
        _updateStatus('Database already initialized');
        return true;
      }

      if (_isInitializing) {
        _updateStatus('Database initialization already in progress');
        return false;
      }

      try {
        _isInitializing = true;
        _isInitialized = false;
        _initializationSteps.clear();

        // Start critical phase - all DB operations will be serialized
        _lockManager.startCriticalPhase();

        _updateStatus('Starting database initialization...');

        final dbHelper = DatabaseHelper();

        // Step 1: Initialize database connection
        await _lockManager.executeOperation(
          'Initialize database connection',
          () async {
            _updateStatus('Connecting to SQLite database...');
            await dbHelper.database.timeout(const Duration(seconds: 10));
            _updateStatus('✓ Database connection established');
          },
        );

        // Step 2: Test database connectivity
        await _lockManager.executeOperation(
          'Test database connectivity',
          () async {
            _updateStatus('Testing database connectivity...');
            final isConnected = await dbHelper.isDatabaseConnected();
            if (!isConnected) {
              throw Exception('Database connectivity test failed');
            }
            _updateStatus('✓ Database connectivity verified');
          },
        );

        // Step 3: Initialize connectivity listener (non-blocking)
        _updateStatus('Setting up connectivity monitoring...');
        dbHelper.initConnectivityListener();
        _updateStatus('✓ Connectivity monitoring active');

        // Step 4: Perform essential database maintenance (serialized)
        await _lockManager.executeOperation(
          'Database maintenance',
          () async {
            _updateStatus('Performing database maintenance...');
            await _performDatabaseMaintenance(dbHelper);
            _updateStatus('✓ Database maintenance completed');
          },
        );

        _isInitialized = true;
        _updateStatus('✓ Database initialization completed successfully');

        return true;
      } catch (e) {
        _updateStatus('✗ Database initialization failed: $e');
        _isInitialized = false;
        if (kDebugMode) {
          print('[DB_INIT] Initialization error: $e');
        }
        return false;
      } finally {
        _isInitializing = false;
        // Keep critical phase active until login is complete
        // It will be ended by endCriticalPhase() method
      }
    }).timeout(timeout, onTimeout: () {
      _updateStatus('✗ Database initialization timed out');
      _isInitializing = false;
      _isInitialized = false;
      _lockManager.endCriticalPhase();
      return false;
    });
  }

  /// Perform database maintenance operations in sequence
  Future<void> _performDatabaseMaintenance(DatabaseHelper dbHelper) async {
    try {
      // Quick connectivity check for maintenance operations
      _updateStatus('Checking connectivity for maintenance...');

      // Only perform cleanup operations that are essential for login
      // Defer heavy operations until after login

      _updateStatus('Checking for critical database issues...');

      // Quick check for database locks or corruption
      try {
        await (await dbHelper.database)
            .rawQuery('SELECT 1')
            .timeout(const Duration(seconds: 3));
        _updateStatus('✓ Database integrity check passed');
      } catch (e) {
        _updateStatus('⚠ Database integrity issue detected, attempting fix...');
        // Try to fix database issues
        await dbHelper.resetDatabaseConnection();
        _updateStatus('✓ Database connection reset');
      }
    } catch (e) {
      _updateStatus('⚠ Database maintenance warning: $e');
      // Don't fail initialization for maintenance issues
      if (kDebugMode) {
        print('[DB_INIT] Maintenance warning: $e');
      }
    }
  }

  /// Schedule post-login operations (heavy operations that can wait)
  void schedulePostLoginOperations() {
    if (!_isInitialized) {
      if (kDebugMode) {
        print(
            '[DB_INIT] Cannot schedule post-login operations - database not initialized');
      }
      return;
    }

    _updateStatus('Scheduling post-login operations...');

    // Schedule heavy operations after a delay to avoid interfering with login flow
    Future.delayed(const Duration(seconds: 10), () async {
      try {
        _updateStatus('Running post-login database cleanup...');

        final dbHelper = DatabaseHelper();

        // Clean up old clocking records (keep only current day)
        await dbHelper.cleanupOldClockingRecords();
        _updateStatus('✓ Old records cleaned up');

        // Clean up duplicate clocking records
        await dbHelper.cleanupDuplicateClockingRecords();
        _updateStatus('✓ Duplicate records cleaned up');

        _updateStatus('✓ Post-login operations completed');
      } catch (e) {
        _updateStatus('⚠ Post-login operations warning: $e');
        if (kDebugMode) {
          print('[DB_INIT] Post-login operations error: $e');
        }
      }
    });
  }

  /// Schedule background sync operations (after login is complete)
  void scheduleBackgroundSync() {
    if (!_isInitialized) {
      if (kDebugMode) {
        print(
            '[DB_INIT] Cannot schedule background sync - database not initialized');
      }
      return;
    }

    _updateStatus('Background sync will be enabled after navigation...');

    // Don't start background sync during login - wait until after navigation
    // The sync will be started by the dashboard pages when they are ready
    if (kDebugMode) {
      print('[DB_INIT] Background sync scheduled for later activation');
    }
  }

  /// Start background sync (call this from dashboard pages after they're loaded)
  void startBackgroundSync() {
    if (!_isInitialized) {
      if (kDebugMode) {
        print(
            '[DB_INIT] Cannot start background sync - database not initialized');
      }
      return;
    }

    _updateStatus('Starting background sync...');

    // Start background sync with a delay to ensure dashboard is fully loaded
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        final syncService = SyncService();
        await syncService.initSync();
        _updateStatus('✓ Background sync started');
        if (kDebugMode) {
          print('[DB_INIT] Background sync started successfully');
        }
      } catch (e) {
        _updateStatus('⚠ Background sync warning: $e');
        if (kDebugMode) {
          print('[DB_INIT] Background sync error: $e');
        }
      }
    });
  }

  /// Execute a database operation with proper serialization
  Future<T> executeSerializedOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_isInitialized) {
      throw Exception(
          'Database not initialized. Call initializeDatabase() first.');
    }

    return await _lockManager.executeOperation(
      operationName,
      operation,
      timeout: timeout,
      forceSerialization:
          true, // Force serialization for all operations during login
    );
  }

  /// End the critical phase (call this after login is complete)
  void endCriticalPhase() {
    _lockManager.endCriticalPhase();
    _updateStatus('✓ Critical phase ended - normal operations resumed');
  }

  /// Wait for database initialization to complete
  Future<bool> waitForInitialization(
      {Duration timeout = const Duration(minutes: 3)}) async {
    final startTime = DateTime.now();

    while (!_isInitialized && DateTime.now().difference(startTime) < timeout) {
      if (_isInitializing) {
        // Wait a bit and check again
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        // Not initialized and not initializing - try to initialize
        return await initializeDatabase();
      }
    }

    return _isInitialized;
  }

  /// Reset initialization state (for testing or error recovery)
  void reset() {
    _isInitialized = false;
    _isInitializing = false;
    _currentStatus = '';
    _initializationSteps.clear();
    _updateStatus('Database initialization reset');
  }
}
