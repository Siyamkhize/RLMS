import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'database_helper.dart';
import 'config.dart';
import 'package:sqflite/sqflite.dart';

/// Force facilitator sync - bypasses normal sync and directly inserts data
class ForceFacilitatorSync {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  /// Force sync facilitator data with detailed logging and verification
  Future<Map<String, dynamic>> forceSyncNow() async {
    print('');
    print('═══════════════════════════════════════════════════════════');
    print('FORCE FACILITATOR SYNC STARTED');
    print('═══════════════════════════════════════════════════════════');
    print('');
    
    try {
      // Step 1: Fetch from server
      print('[STEP 1] Fetching data from server...');
      print('URL: ${AppConfig.syncFacilitatorUrl}');
      
      final response = await http.get(Uri.parse(AppConfig.syncFacilitatorUrl))
          .timeout(const Duration(seconds: 30));
      
      print('[STEP 1] Server response: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }
      
      print('[STEP 1] Response body length: ${response.body.length} chars');
      
      // Step 2: Parse JSON
      print('[STEP 2] Parsing JSON...');
      final List<dynamic> facilitatorData = json.decode(response.body);
      print('[STEP 2] Parsed ${facilitatorData.length} facilitator records');
      
      if (facilitatorData.isEmpty) {
        return {
          'success': false,
          'message': 'Server returned no facilitator data',
          'records_synced': 0,
        };
      }
      
      // Step 3: Show first record
      print('[STEP 3] First record from server:');
      print(json.encode(facilitatorData[0], toEncodable: (obj) => obj.toString()));
      
      // Step 4: Get database
      print('[STEP 4] Opening database...');
      final db = await _dbHelper.database;
      
      // Step 5: Check current table state
      print('[STEP 5] Checking current table state...');
      final beforeCount = await db.rawQuery('SELECT COUNT(*) as count FROM facilitator');
      print('[STEP 5] Records before sync: ${beforeCount.first['count']}');
      
      // Step 6: Clear table
      print('[STEP 6] Clearing facilitator table...');
      await db.delete('facilitator');
      final afterClearCount = await db.rawQuery('SELECT COUNT(*) as count FROM facilitator');
      print('[STEP 6] Records after clear: ${afterClearCount.first['count']}');
      
      // Step 7: Insert each record with EXPLICIT column mapping
      print('[STEP 7] Inserting facilitator records...');
      int successCount = 0;
      int errorCount = 0;
      
      for (int i = 0; i < facilitatorData.length; i++) {
        final facilitator = facilitatorData[i];
        print('');
        print('─────────────────────────────────────────────────────────');
        print('Inserting record ${i + 1}/${facilitatorData.length}');
        print('─────────────────────────────────────────────────────────');
        
        try {
          // EXPLICIT mapping - take EXACTLY what server sends
          final Map<String, dynamic> recordToInsert = {
            'facilitator_id': facilitator['facilitator_id'],
            'firstName': facilitator['firstName'],
            'lastName': facilitator['lastName'],
            'role': facilitator['role'],
            'email': facilitator['email'],
            'classID': facilitator['classID'],
            'password': facilitator['password'],
            'assessorNo': facilitator['assessorNo'],
            'f_signature': facilitator['f_signature'],
            'phoneNumber': facilitator['phoneNumber'],
            'workNumber': facilitator['workNumber'],
            'f_profile': facilitator['f_profile'],
            'f_IDNumber': facilitator['f_IDNumber'],
            'serial_number': facilitator['serial_number'],
            'zkteco_left_template': facilitator['zkteco_left_template'],
            'zkteco_right_template': facilitator['zkteco_right_template'],
            'futronic_left_template': facilitator['futronic_left_template'],
            'futronic_right_template': facilitator['futronic_right_template'],
          };
          
          print('Data to insert:');
          print('  facilitator_id: ${recordToInsert['facilitator_id']}');
          print('  firstName: "${recordToInsert['firstName']}"');
          print('  lastName: "${recordToInsert['lastName']}"');
          print('  email: "${recordToInsert['email']}"');
          print('  role: "${recordToInsert['role']}"');
          print('  classID: ${recordToInsert['classID']}');
          print('  password length: ${recordToInsert['password']?.toString().length ?? 0} chars');
          
          // Insert with REPLACE conflict resolution
          final insertedId = await db.insert(
            'facilitator',
            recordToInsert,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          
          print('✅ INSERT SUCCESSFUL - Row ID: $insertedId');
          
          // VERIFY: Read back what was actually inserted
          final verifyResult = await db.query(
            'facilitator',
            where: 'facilitator_id = ?',
            whereArgs: [recordToInsert['facilitator_id']],
          );
          
          if (verifyResult.isNotEmpty) {
            final inserted = verifyResult.first;
            print('✅ VERIFICATION: Record found in database');
            print('  DB facilitator_id: ${inserted['facilitator_id']}');
            print('  DB firstName: "${inserted['firstName']}"');
            print('  DB lastName: "${inserted['lastName']}"');
            print('  DB email: "${inserted['email']}"');
            
            // Check for mismatches
            bool mismatch = false;
            if (inserted['firstName'] != recordToInsert['firstName']) {
              print('⚠️ MISMATCH: firstName - Expected "${recordToInsert['firstName']}", Got "${inserted['firstName']}"');
              mismatch = true;
            }
            if (inserted['lastName'] != recordToInsert['lastName']) {
              print('⚠️ MISMATCH: lastName - Expected "${recordToInsert['lastName']}", Got "${inserted['lastName']}"');
              mismatch = true;
            }
            if (inserted['email'] != recordToInsert['email']) {
              print('⚠️ MISMATCH: email - Expected "${recordToInsert['email']}", Got "${inserted['email']}"');
              mismatch = true;
            }
            
            if (!mismatch) {
              print('✅ DATA INTEGRITY: All fields match!');
              successCount++;
            } else {
              print('❌ DATA INTEGRITY: Mismatches detected!');
              errorCount++;
            }
          } else {
            print('❌ VERIFICATION FAILED: Record not found after insert!');
            errorCount++;
          }
          
        } catch (e, stackTrace) {
          print('❌ INSERT ERROR: $e');
          print('Stack trace: $stackTrace');
          errorCount++;
        }
      }
      
      // Step 8: Final verification
      print('');
      print('[STEP 8] Final table verification...');
      final finalCount = await db.rawQuery('SELECT COUNT(*) as count FROM facilitator');
      final finalRecords = await db.query('facilitator');
      
      print('[STEP 8] Final record count: ${finalCount.first['count']}');
      print('[STEP 8] All records in table:');
      for (var record in finalRecords) {
        print('  - ID: ${record['facilitator_id']}, Name: ${record['firstName']} ${record['lastName']}, Email: ${record['email']}');
      }
      
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('SYNC SUMMARY');
      print('═══════════════════════════════════════════════════════════');
      print('✅ Successful: $successCount');
      print('❌ Errors: $errorCount');
      print('📊 Total in DB: ${finalCount.first['count']}');
      print('═══════════════════════════════════════════════════════════');
      print('');
      
      return {
        'success': errorCount == 0,
        'message': errorCount == 0 
            ? 'All $successCount facilitators synced successfully!' 
            : 'Synced with $errorCount errors',
        'records_synced': successCount,
        'errors': errorCount,
        'total_in_db': finalCount.first['count'],
      };
      
    } catch (e, stackTrace) {
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('❌ SYNC FAILED');
      print('═══════════════════════════════════════════════════════════');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
      print('');
      
      return {
        'success': false,
        'message': 'Sync failed: $e',
        'error': e.toString(),
      };
    }
  }
  
  /// Show sync dialog and execute
  static Future<void> showSyncDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ForceSyncDialog(),
    );
    
    if (result != null && context.mounted) {
      final success = result['success'] ?? false;
      final message = result['message'] ?? 'Unknown result';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

class _ForceSyncDialog extends StatefulWidget {
  @override
  State<_ForceSyncDialog> createState() => _ForceSyncDialogState();
}

class _ForceSyncDialogState extends State<_ForceSyncDialog> {
  bool _syncing = false;
  String _status = 'Ready to sync facilitator data...';
  Map<String, dynamic>? _result;
  
  @override
  void initState() {
    super.initState();
    // Auto-start sync
    Future.delayed(const Duration(milliseconds: 500), _startSync);
  }
  
  Future<void> _startSync() async {
    if (_syncing) return;
    
    setState(() {
      _syncing = true;
      _status = 'Connecting to server...';
    });
    
    final syncer = ForceFacilitatorSync();
    final result = await syncer.forceSyncNow();
    
    setState(() {
      _syncing = false;
      _result = result;
      _status = result['message'] ?? 'Sync completed';
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Force Facilitator Sync'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_syncing) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
          ],
          Text(_status),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_result!['success'] ?? false) 
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                border: Border.all(
                  color: (_result!['success'] ?? false) ? Colors.green : Colors.red,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (_result!['success'] ?? false) ? '✅ Success' : '❌ Failed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (_result!['success'] ?? false) ? Colors.green : Colors.red,
                    ),
                  ),
                  if (_result!['records_synced'] != null)
                    Text('Records synced: ${_result!['records_synced']}'),
                  if (_result!['errors'] != null && _result!['errors'] > 0)
                    Text('Errors: ${_result!['errors']}'),
                  if (_result!['total_in_db'] != null)
                    Text('Total in database: ${_result!['total_in_db']}'),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!_syncing && _result != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(_result),
            child: const Text('Close'),
          ),
      ],
    );
  }
}

