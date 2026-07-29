import 'package:flutter/material.dart';
import 'lib/database_lock_fix.dart';
import 'lib/database_helper.dart';

/// Test script to verify database lock fixes
/// Run this with: flutter run test_database_fix.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('=== Database Lock Fix Test ===');
  print('Testing database connectivity and lock prevention...\n');

  try {
    // Test 1: Basic connectivity
    print('1. Testing basic database connectivity...');
    final dbHelper = DatabaseHelper();
    final isConnected = await dbHelper.isDatabaseConnected();
    print('   Result: ${isConnected ? 'CONNECTED' : 'FAILED'}');

    if (!isConnected) {
      print('   Attempting quick fix...');
      final fixed = await DatabaseLockFix.quickFix();
      print('   Quick fix: ${fixed ? 'SUCCESS' : 'FAILED'}');
    }

    // Test 2: Run full diagnostics
    print('\n2. Running full database diagnostics...');
    final diagnostics = await DatabaseLockFix.diagnoseAndFix();
    print('   Overall status: ${diagnostics['overall_status']}');

    if (diagnostics['tests'] != null) {
      print('   Test results:');
      diagnostics['tests'].forEach((testName, result) {
        if (result is Map && result.containsKey('status')) {
          print(
              '     - $testName: ${result['status']} (${result['time_ms'] ?? 'N/A'}ms)');
        }
      });
    }

    if (diagnostics['recommendations'] != null &&
        diagnostics['recommendations'].isNotEmpty) {
      print('   Recommendations:');
      for (final rec in diagnostics['recommendations']) {
        print('     - $rec');
      }
    }

    // Test 3: WAL mode
    print('\n3. Testing WAL mode...');
    final walEnabled = await DatabaseLockFix.enableWALMode();
    print('   WAL mode: ${walEnabled ? 'ENABLED' : 'FAILED'}');

    // Test 4: Concurrent access simulation
    print('\n4. Testing concurrent database access...');
    final futures = List.generate(5, (index) async {
      try {
        final db = await dbHelper.database;
        final result = await db
            .rawQuery('SELECT $index as test_id, datetime("now") as timestamp')
            .timeout(const Duration(seconds: 3));
        return 'Query $index: SUCCESS (${result.first['timestamp']})';
      } catch (e) {
        return 'Query $index: FAILED ($e)';
      }
    });

    final results = await Future.wait(futures);
    for (final result in results) {
      print('   $result');
    }

    print('\n=== Test Complete ===');
    print(
        'If you see any FAILED results, the database lock issue may still exist.');
    print('Try restarting the app or running the quick fix again.');
  } catch (e) {
    print('ERROR: Test failed with exception: $e');
  }
}
