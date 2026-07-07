import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'dart:async';

class DatabaseLockFix {
  static final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Diagnose and fix database lock issues
  static Future<Map<String, dynamic>> diagnoseAndFix() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'tests': <String, dynamic>{},
      'fixes_applied': <String>[],
      'recommendations': <String>[],
    };

    try {
      // Test 1: Basic database connectivity
      debugPrint('[DB_FIX] Testing basic database connectivity...');
      final connectivityStart = DateTime.now();
      final isConnected = await _dbHelper.isDatabaseConnected();
      final connectivityTime =
          DateTime.now().difference(connectivityStart).inMilliseconds;

      results['tests']['connectivity'] = {
        'passed': isConnected,
        'time_ms': connectivityTime,
        'status': isConnected ? 'OK' : 'FAILED'
      };

      if (!isConnected) {
        debugPrint(
            '[DB_FIX] Database connectivity failed - attempting reset...');
        await _dbHelper.resetDatabaseConnection();
        results['fixes_applied'].add('Database connection reset');

        // Retest after reset
        final retestConnected = await _dbHelper.isDatabaseConnected();
        results['tests']['connectivity_after_reset'] = {
          'passed': retestConnected,
          'status': retestConnected ? 'OK' : 'STILL_FAILED'
        };
      }

      // Test 2: Transaction timeout test
      debugPrint('[DB_FIX] Testing transaction handling...');
      final transactionStart = DateTime.now();
      bool transactionPassed = false;
      try {
        final db = await _dbHelper.database;
        await db.transaction((txn) async {
          await txn.rawQuery('SELECT COUNT(*) FROM sqlite_master');
          await Future.delayed(
              const Duration(milliseconds: 100)); // Small delay
        }).timeout(const Duration(seconds: 5));
        transactionPassed = true;
      } catch (e) {
        debugPrint('[DB_FIX] Transaction test failed: $e');
        if (e is TimeoutException) {
          results['fixes_applied'].add('Transaction timeout detected');
          results['recommendations']
              .add('Reduce transaction scope and duration');
        }
      }

      final transactionTime =
          DateTime.now().difference(transactionStart).inMilliseconds;
      results['tests']['transaction'] = {
        'passed': transactionPassed,
        'time_ms': transactionTime,
        'status': transactionPassed ? 'OK' : 'FAILED'
      };

      // Test 3: Concurrent access test
      debugPrint('[DB_FIX] Testing concurrent database access...');
      final concurrentStart = DateTime.now();
      bool concurrentPassed = false;
      try {
        final futures = List.generate(3, (index) async {
          final db = await _dbHelper.database;
          return await db
              .rawQuery('SELECT $index as test_id')
              .timeout(const Duration(seconds: 3));
        });

        await Future.wait(futures);
        concurrentPassed = true;
      } catch (e) {
        debugPrint('[DB_FIX] Concurrent access test failed: $e');
        results['recommendations']
            .add('Serialize database operations during startup');
      }

      final concurrentTime =
          DateTime.now().difference(concurrentStart).inMilliseconds;
      results['tests']['concurrent_access'] = {
        'passed': concurrentPassed,
        'time_ms': concurrentTime,
        'status': concurrentPassed ? 'OK' : 'FAILED'
      };

      // Test 4: Check for long-running operations
      debugPrint('[DB_FIX] Checking for potential lock sources...');
      final db = await _dbHelper.database;

      // Check table sizes that might cause slow operations
      final tableSizes = <String, int>{};
      final tables = [
        'learner_clocking',
        'learnerdetails',
        'facilitator',
        'poe'
      ];

      for (final table in tables) {
        try {
          final result = await db
              .rawQuery('SELECT COUNT(*) as count FROM $table')
              .timeout(const Duration(seconds: 2));
          tableSizes[table] = result.first['count'] as int? ?? 0;
        } catch (e) {
          tableSizes[table] = -1; // Error getting count
          debugPrint('[DB_FIX] Error getting count for $table: $e');
        }
      }

      results['tests']['table_sizes'] = tableSizes;

      // Generate recommendations based on table sizes
      tableSizes.forEach((table, count) {
        if (count > 10000) {
          results['recommendations'].add(
              'Large table detected: $table ($count records) - consider cleanup');
        }
      });

      // Test 5: WAL mode check (Write-Ahead Logging can help with concurrency)
      try {
        final walResult = await db.rawQuery('PRAGMA journal_mode');
        final journalMode = walResult.first.values.first.toString();
        results['tests']['journal_mode'] = {
          'current': journalMode,
          'recommended': 'WAL',
          'status': journalMode.toUpperCase() == 'WAL' ? 'OK' : 'SUBOPTIMAL'
        };

        if (journalMode.toUpperCase() != 'WAL') {
          results['recommendations']
              .add('Consider enabling WAL mode for better concurrency');
        }
      } catch (e) {
        debugPrint('[DB_FIX] Error checking journal mode: $e');
      }

      // Overall assessment
      final allTestsPassed = results['tests']
          .values
          .where((test) => test is Map && test.containsKey('passed'))
          .every((test) => test['passed'] == true);

      results['overall_status'] =
          allTestsPassed ? 'HEALTHY' : 'NEEDS_ATTENTION';

      if (!allTestsPassed) {
        results['recommendations']
            .add('Restart the app to clear any remaining locks');
        results['recommendations']
            .add('Avoid database operations during app startup');
      }
    } catch (e) {
      debugPrint('[DB_FIX] Error during diagnosis: $e');
      results['error'] = e.toString();
      results['overall_status'] = 'ERROR';
    }

    return results;
  }

  /// Quick fix for immediate database lock issues
  static Future<bool> quickFix() async {
    try {
      debugPrint('[DB_FIX] Applying quick fix for database locks...');

      // Step 1: Reset database connection
      await _dbHelper.resetDatabaseConnection();

      // Step 2: Test connectivity
      final isConnected = await _dbHelper.isDatabaseConnected();
      if (!isConnected) {
        debugPrint('[DB_FIX] Quick fix failed - database still not accessible');
        return false;
      }

      // Step 3: Clear any potential locks with a simple query
      final db = await _dbHelper.database;
      await db.rawQuery('SELECT 1').timeout(const Duration(seconds: 5));

      debugPrint('[DB_FIX] Quick fix completed successfully');
      return true;
    } catch (e) {
      debugPrint('[DB_FIX] Quick fix failed: $e');
      return false;
    }
  }

  /// Enable WAL mode for better concurrency (if not already enabled)
  static Future<bool> enableWALMode() async {
    try {
      final db = await _dbHelper.database;

      // Check current mode
      final currentMode = await db.rawQuery('PRAGMA journal_mode');
      final mode = currentMode.first.values.first.toString();

      if (mode.toUpperCase() == 'WAL') {
        debugPrint('[DB_FIX] WAL mode already enabled');
        return true;
      }

      // Enable WAL mode
      await db.rawQuery('PRAGMA journal_mode=WAL');

      // Verify it was set
      final newMode = await db.rawQuery('PRAGMA journal_mode');
      final verifyMode = newMode.first.values.first.toString();

      final success = verifyMode.toUpperCase() == 'WAL';
      debugPrint(
          '[DB_FIX] WAL mode ${success ? 'enabled' : 'failed to enable'}: $verifyMode');

      return success;
    } catch (e) {
      debugPrint('[DB_FIX] Error enabling WAL mode: $e');
      return false;
    }
  }
}
