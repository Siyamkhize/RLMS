import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'database_helper.dart';
import 'config.dart';

/// Complete database repair tool for facilitator sync issues
class DatabaseRepairTool {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  /// Complete repair: Drop table, recreate, and sync
  Future<Map<String, dynamic>> repairFacilitatorTable() async {
    print('\n');
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║       DATABASE REPAIR TOOL - FACILITATOR TABLE           ║');
    print('╚═══════════════════════════════════════════════════════════╝');
    print('\n');
    
    try {
      final db = await _dbHelper.database;
      
      // Step 1: Check current state
      print('┌─────────────────────────────────────────────────────────┐');
      print('│ STEP 1: Analyzing Current Database State               │');
      print('└─────────────────────────────────────────────────────────┘');
      
      try {
        final currentCount = await db.rawQuery('SELECT COUNT(*) as count FROM facilitator');
        print('✓ Current records: ${currentCount.first['count']}');
        
        final tableInfo = await db.rawQuery('PRAGMA table_info(facilitator)');
        print('✓ Current columns: ${tableInfo.length}');
        print('  Columns: ${tableInfo.map((c) => c['name']).join(', ')}');
      } catch (e) {
        print('⚠ Table may not exist or is corrupted: $e');
      }
      
      // Step 2: Drop existing table
      print('\n┌─────────────────────────────────────────────────────────┐');
      print('│ STEP 2: Dropping Old Table                             │');
      print('└─────────────────────────────────────────────────────────┘');
      
      await db.execute('DROP TABLE IF EXISTS facilitator');
      print('✓ Old table dropped');
      
      // Step 3: Create fresh table with correct schema
      print('\n┌─────────────────────────────────────────────────────────┐');
      print('│ STEP 3: Creating Fresh Table                           │');
      print('└─────────────────────────────────────────────────────────┘');
      
      await db.execute('''
        CREATE TABLE facilitator (
          facilitator_id INTEGER PRIMARY KEY,
          firstName TEXT,
          lastName TEXT,
          role TEXT,
          email TEXT,
          classID INTEGER,
          password TEXT,
          assessorNo TEXT,
          f_signature TEXT,
          phoneNumber TEXT,
          workNumber TEXT,
          f_profile TEXT,
          f_IDNumber TEXT,
          serial_number TEXT,
          zkteco_left_template TEXT,
          zkteco_right_template TEXT,
          futronic_left_template TEXT,
          futronic_right_template TEXT
        )
      ''');
      print('✓ Fresh table created with correct schema');
      
      // Verify table creation
      final newTableInfo = await db.rawQuery('PRAGMA table_info(facilitator)');
      print('✓ Verified columns: ${newTableInfo.length}');
      for (var col in newTableInfo) {
        print('  - ${col['name']} (${col['type']})');
      }
      
      // Step 4: Fetch data from server
      print('\n┌─────────────────────────────────────────────────────────┐');
      print('│ STEP 4: Fetching Data from Server                      │');
      print('└─────────────────────────────────────────────────────────┘');
      
      print('URL: ${AppConfig.syncFacilitatorUrl}');
      final response = await http.get(Uri.parse(AppConfig.syncFacilitatorUrl))
          .timeout(const Duration(seconds: 30));
      
      print('✓ Server response: ${response.statusCode}');
      print('✓ Response size: ${response.body.length} bytes');
      
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      
      final List<dynamic> serverData = json.decode(response.body);
      print('✓ Parsed ${serverData.length} facilitator records');
      
      if (serverData.isEmpty) {
        return {
          'success': false,
          'message': 'Server has no facilitator data',
          'step_failed': 'fetch',
        };
      }
      
      // Show first record
      print('\nFirst record from server:');
      final first = serverData[0];
      print('  facilitator_id: ${first['facilitator_id']}');
      print('  firstName: "${first['firstName']}"');
      print('  lastName: "${first['lastName']}"');
      print('  email: "${first['email']}"');
      print('  classID: ${first['classID']}');
      
      // Step 5: Insert data with explicit SQL
      print('\n┌─────────────────────────────────────────────────────────┐');
      print('│ STEP 5: Inserting Data (Direct SQL)                    │');
      print('└─────────────────────────────────────────────────────────┘');
      
      int successCount = 0;
      int errorCount = 0;
      
      for (var i = 0; i < serverData.length; i++) {
        final facilitator = serverData[i];
        
        print('\nRecord ${i + 1}/${serverData.length}:');
        print('  ID: ${facilitator['facilitator_id']}');
        print('  Name: ${facilitator['firstName']} ${facilitator['lastName']}');
        
        try {
          // Use direct SQL INSERT to ensure data goes in exactly as-is
          await db.rawInsert('''
            INSERT INTO facilitator (
              facilitator_id, firstName, lastName, role, email, classID,
              password, assessorNo, f_signature, phoneNumber, workNumber,
              f_profile, f_IDNumber, serial_number,
              zkteco_left_template, zkteco_right_template,
              futronic_left_template, futronic_right_template
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            facilitator['facilitator_id'],
            facilitator['firstName'],
            facilitator['lastName'],
            facilitator['role'],
            facilitator['email'],
            facilitator['classID'],
            facilitator['password'],
            facilitator['assessorNo'],
            facilitator['f_signature'],
            facilitator['phoneNumber'],
            facilitator['workNumber'],
            facilitator['f_profile'],
            facilitator['f_IDNumber'],
            facilitator['serial_number'],
            facilitator['zkteco_left_template'],
            facilitator['zkteco_right_template'],
            facilitator['futronic_left_template'],
            facilitator['futronic_right_template'],
          ]);
          
          print('  ✓ Inserted successfully');
          
          // IMMEDIATE VERIFICATION
          final verify = await db.rawQuery(
            'SELECT facilitator_id, firstName, lastName, email FROM facilitator WHERE facilitator_id = ?',
            [facilitator['facilitator_id']]
          );
          
          if (verify.isNotEmpty) {
            final row = verify.first;
            print('  ✓ Verified in DB:');
            print('    facilitator_id: ${row['facilitator_id']}');
            print('    firstName: "${row['firstName']}"');
            print('    lastName: "${row['lastName']}"');
            print('    email: "${row['email']}"');
            
            // Check for data integrity
            if (row['firstName'] == facilitator['firstName'] &&
                row['lastName'] == facilitator['lastName']) {
              print('  ✓ DATA INTEGRITY: Perfect match!');
              successCount++;
            } else {
              print('  ✗ DATA INTEGRITY FAILED!');
              print('    Expected: ${facilitator['firstName']} ${facilitator['lastName']}');
              print('    Got: ${row['firstName']} ${row['lastName']}');
              errorCount++;
            }
          } else {
            print('  ✗ VERIFICATION FAILED: Not found in DB');
            errorCount++;
          }
          
        } catch (e) {
          print('  ✗ Insert error: $e');
          errorCount++;
        }
      }
      
      // Step 6: Final verification
      print('\n┌─────────────────────────────────────────────────────────┐');
      print('│ STEP 6: Final Database Verification                    │');
      print('└─────────────────────────────────────────────────────────┘');
      
      final finalCount = await db.rawQuery('SELECT COUNT(*) as count FROM facilitator');
      final allRecords = await db.rawQuery('SELECT facilitator_id, firstName, lastName, email FROM facilitator');
      
      print('✓ Total records in database: ${finalCount.first['count']}');
      print('\nAll facilitators:');
      for (var record in allRecords) {
        print('  - ID ${record['facilitator_id']}: ${record['firstName']} ${record['lastName']} (${record['email']})');
      }
      
      // Summary
      print('\n╔═══════════════════════════════════════════════════════════╗');
      print('║                    REPAIR SUMMARY                         ║');
      print('╠═══════════════════════════════════════════════════════════╣');
      print('║ ✓ Successful inserts: ${successCount.toString().padLeft(3)}                             ║');
      print('║ ✗ Failed inserts: ${errorCount.toString().padLeft(3)}                                 ║');
      print('║ 📊 Total in database: ${(finalCount.first['count'] as int).toString().padLeft(3)}                             ║');
      print('╚═══════════════════════════════════════════════════════════╝');
      print('\n');
      
      return {
        'success': errorCount == 0 && successCount > 0,
        'message': errorCount == 0 
            ? 'Database repair successful! All data synced.' 
            : 'Repair completed with $errorCount errors',
        'records_synced': successCount,
        'errors': errorCount,
        'total_in_db': finalCount.first['count'],
      };
      
    } catch (e, stackTrace) {
      print('\n╔═══════════════════════════════════════════════════════════╗');
      print('║                    REPAIR FAILED                          ║');
      print('╚═══════════════════════════════════════════════════════════╝');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('\n');
      
      return {
        'success': false,
        'message': 'Database repair failed: $e',
        'error': e.toString(),
      };
    }
  }
  
  /// Quick diagnostic check
  Future<Map<String, dynamic>> diagnose() async {
    print('\n🔍 Running diagnostics...\n');
    
    try {
      final db = await _dbHelper.database;
      
      // Check table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='facilitator'"
      );
      
      if (tables.isEmpty) {
        return {
          'table_exists': false,
          'message': 'Facilitator table does not exist!',
          'action': 'Run repair to create table',
        };
      }
      
      // Check schema
      final schema = await db.rawQuery('PRAGMA table_info(facilitator)');
      final columns = schema.map((c) => c['name']).toList();
      
      // Check data
      final count = await db.rawQuery('SELECT COUNT(*) as count FROM facilitator');
      final records = await db.rawQuery(
        'SELECT facilitator_id, firstName, lastName, email FROM facilitator LIMIT 5'
      );
      
      return {
        'table_exists': true,
        'column_count': columns.length,
        'columns': columns,
        'record_count': count.first['count'],
        'sample_records': records,
        'message': 'Table exists with ${count.first['count']} records',
      };
      
    } catch (e) {
      return {
        'error': true,
        'message': 'Diagnostic failed: $e',
      };
    }
  }
}

/// UI Widget for database repair
class DatabaseRepairPage extends StatefulWidget {
  const DatabaseRepairPage({super.key});

  @override
  State<DatabaseRepairPage> createState() => _DatabaseRepairPageState();
}

class _DatabaseRepairPageState extends State<DatabaseRepairPage> {
  final _repairTool = DatabaseRepairTool();
  bool _repairing = false;
  bool _diagnosing = false;
  Map<String, dynamic>? _diagnosticResult;
  Map<String, dynamic>? _repairResult;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() => _diagnosing = true);
    final result = await _repairTool.diagnose();
    setState(() {
      _diagnosticResult = result;
      _diagnosing = false;
    });
  }

  Future<void> _runRepair() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirm Repair'),
        content: const Text(
          'This will:\n'
          '1. Drop the existing facilitator table\n'
          '2. Create a fresh table\n'
          '3. Download and insert data from server\n\n'
          'Continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Repair Now'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _repairing = true);
    final result = await _repairTool.repairFacilitatorTable();
    setState(() {
      _repairResult = result;
      _repairing = false;
    });

    // Refresh diagnostics
    await _runDiagnostics();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Repair completed'),
          backgroundColor: result['success'] == true ? Colors.green : Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Repair Tool'),
        backgroundColor: Colors.red.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning card
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.warning, size: 48, color: Colors.orange.shade700),
                    const SizedBox(height: 8),
                    Text(
                      'Database Not Syncing',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Facilitator data from server is not syncing to local database. '
                      'Use this tool to repair the database and force sync.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Diagnostic results
            if (_diagnosing)
              const Center(child: CircularProgressIndicator())
            else if (_diagnosticResult != null) ...[
              Text(
                'Current Status',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusRow('Table Exists', _diagnosticResult!['table_exists'] == true),
                      if (_diagnosticResult!['column_count'] != null)
                        _buildInfoRow('Columns', '${_diagnosticResult!['column_count']}'),
                      if (_diagnosticResult!['record_count'] != null)
                        _buildInfoRow('Records', '${_diagnosticResult!['record_count']}'),
                      const Divider(),
                      Text(
                        _diagnosticResult!['message'] ?? 'Unknown status',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Repair button
            ElevatedButton.icon(
              onPressed: _repairing ? null : _runRepair,
              icon: _repairing 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.build),
              label: Text(_repairing ? 'REPAIRING...' : 'REPAIR DATABASE NOW'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextButton.icon(
              onPressed: _diagnosing ? null : _runDiagnostics,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Diagnostics'),
            ),
            
            // Repair result
            if (_repairResult != null) ...[
              const SizedBox(height: 24),
              Text(
                'Repair Result',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                color: _repairResult!['success'] == true 
                    ? Colors.green.shade50 
                    : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _repairResult!['success'] == true 
                                ? Icons.check_circle 
                                : Icons.error,
                            color: _repairResult!['success'] == true 
                                ? Colors.green 
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _repairResult!['message'] ?? 'Completed',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      if (_repairResult!['records_synced'] != null) ...[
                        const Divider(),
                        _buildInfoRow('✓ Synced', '${_repairResult!['records_synced']}'),
                        if (_repairResult!['errors'] != null)
                          _buildInfoRow('✗ Errors', '${_repairResult!['errors']}'),
                        if (_repairResult!['total_in_db'] != null)
                          _buildInfoRow('📊 Total', '${_repairResult!['total_in_db']}'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What This Tool Does:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Drops the old facilitator table'),
                    const Text('2. Creates a fresh table with correct schema'),
                    const Text('3. Downloads data from server'),
                    const Text('4. Inserts data using direct SQL'),
                    const Text('5. Verifies each record'),
                    const SizedBox(height: 8),
                    Text(
                      'Check the console for detailed logs!',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool success) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.cancel,
            color: success ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }
}

