import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'config.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static Database? _database;
  final String _dbName = 'local_data.db';
  final String _unsyncedTable = 'unsynced_data';

  // Initialize the database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Clean up old clocking records and sync unsynced ones
  Future<void> cleanupOldClockingRecords() async {
    try {
      final db = await database;
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Step 1: CRITICAL FIX - Attempt to sync unsynced records BEFORE cleanup
      final unsyncedRecords = await db.query(
        'learner_clocking',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (unsyncedRecords.isNotEmpty) {
        print(
            '[CLEANUP] Found ${unsyncedRecords.length} unsynced records - attempting to sync before cleanup');

        // Check if we have internet connectivity
        bool hasInternet = false;
        try {
          final connectivityResult = await Connectivity().checkConnectivity();
          hasInternet = connectivityResult.isNotEmpty &&
              connectivityResult.first != ConnectivityResult.none;
        } catch (e) {
          print('[CLEANUP] Error checking connectivity: $e');
        }

        if (hasInternet) {
          print(
              '[CLEANUP] Internet available - syncing ${unsyncedRecords.length} unsynced records');

          // Attempt to sync each unsynced record
          int syncedCount = 0;
          for (var record in unsyncedRecords) {
            try {
              final success = await _syncSingleRecord(record);
              if (success) {
                // Mark as synced
                await db.update(
                  'learner_clocking',
                  {'synced': 1},
                  where: 'clocking_id = ?',
                  whereArgs: [record['clocking_id']],
                );
                syncedCount++;
              }
            } catch (e) {
              print(
                  '[CLEANUP] Failed to sync record ${record['clocking_id']}: $e');
            }
          }

          print(
              '[CLEANUP] Successfully synced $syncedCount/${unsyncedRecords.length} records');
        } else {
          print(
              '[CLEANUP] No internet - preserving ${unsyncedRecords.length} unsynced records');
          // Don't delete unsynced records when offline
        }
      }

      // Step 2: Delete OLD synced records (synced=1) from previous days only
      // KEEP today's synced records so they remain visible when offline
      final deletedSyncedLearner = await db.delete(
        'learner_clocking',
        where: 'synced = ? AND clock_date < ?',
        whereArgs: [1, today],
      );

      // DON'T delete induction_clocking records (keep them permanently)
      // final deletedSyncedInduction = await db.delete(
      //   'induction_clocking',
      //   where: 'synced = ?',
      //   whereArgs: [1],
      // );

      // Step 3: The above step already handles old synced records
      // This step is now redundant but kept for clarity
      final deletedOld = 0; // No additional deletion needed

      // DON'T delete old induction_clocking records (keep them permanently)
      // final deletedOldInduction = await db.delete(
      //   'induction_clocking',
      //   where: 'clock_date < ?',
      //   whereArgs: [today],
      // );

      final totalDeleted = deletedSyncedLearner + deletedOld;

      if (totalDeleted > 0) {
        print(
            '[CLEANUP] Deleted $totalDeleted learner_clocking records: synced=$deletedSyncedLearner, old=$deletedOld');
      } else {
        print(
            '[CLEANUP] No old learner_clocking records to delete - database clean');
      }

      // Log what's remaining
      final remainingCount =
          await db.rawQuery('SELECT COUNT(*) as count FROM learner_clocking');
      final remaining = remainingCount.first['count'];
      print(
          '[CLEANUP] Remaining learner_clocking records: $remaining (current day only)');

      // Log induction_clocking count (not cleaned up)
      final inductionCount =
          await db.rawQuery('SELECT COUNT(*) as count FROM induction_clocking');
      final inductionRemaining = inductionCount.first['count'];
      print(
          '[CLEANUP] induction_clocking records: $inductionRemaining (kept permanently, NOT deleted)');
    } catch (e) {
      print('[CLEANUP] Error cleaning up old records: $e');
    }
  }

  // Helper method to sync a single record to the server
  Future<bool> _syncSingleRecord(Map<String, Object?> record) async {
    try {
      final learnerId = record['LearnerID'].toString();
      final clockInTime = record['clock_in_time']?.toString() ?? '';
      final clockOutTime = record['clock_out_time']?.toString() ?? '';
      final contactTime = record['contact_time']?.toString() ?? '';
      final clockDate = record['clock_date']?.toString() ?? '';
      final classID = record['classID']?.toString() ?? '';

      // Prepare attendance data for sync
      final attendance = {
        'LearnerID': learnerId,
        'clock_in_time': clockInTime,
        'clock_out_time': clockOutTime,
        'contact_time': contactTime,
        'clock_date': clockDate,
        'classID': classID,
        'synced': 0,
        'user_latitude': record['user_latitude']?.toString() ?? '0.0',
        'user_longitude': record['user_longitude']?.toString() ?? '0.0',
        'user_accuracy': record['user_accuracy']?.toString() ?? '10.0',
      };

      // Determine if this is a clock-in or clock-out record
      bool success = false;
      if (clockInTime.isNotEmpty && clockOutTime.isEmpty) {
        // Clock-in only record
        success = await _syncClockInToServer(attendance);
      } else if (clockInTime.isNotEmpty && clockOutTime.isNotEmpty) {
        // Complete clock-in/out record
        success = await _syncClockOutToServer(attendance);
      }

      return success;
    } catch (e) {
      print('[SYNC_SINGLE] Error syncing record: $e');
      return false;
    }
  }

  // Sync clock-in record to server
  Future<bool> _syncClockInToServer(Map<String, dynamic> attendance) async {
    try {
      final url = '${AppConfig.baseUrl}/mobile/clocking/clockin.php';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'learner_id': attendance['LearnerID'].toString(),
          'clock_in_time': attendance['clock_in_time'].toString(),
          'clock_date': attendance['clock_date'].toString(),
          'class_id': attendance['classID'].toString(),
          'user_latitude': attendance['user_latitude'].toString(),
          'user_longitude': attendance['user_longitude'].toString(),
          'user_accuracy': attendance['user_accuracy'].toString(),
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('[SYNC_CLOCK_IN] Error: $e');
      return false;
    }
  }

  // Sync clock-out record to server
  Future<bool> _syncClockOutToServer(Map<String, dynamic> attendance) async {
    try {
      final url = '${AppConfig.baseUrl}/mobile/clocking/clockout.php';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'learner_id': attendance['LearnerID'].toString(),
          'clock_in_time': attendance['clock_in_time'].toString(),
          'clock_out_time': attendance['clock_out_time'].toString(),
          'contact_time': attendance['contact_time'].toString(),
          'clock_date': attendance['clock_date'].toString(),
          'class_id': attendance['classID'].toString(),
          'user_latitude': attendance['user_latitude'].toString(),
          'user_longitude': attendance['user_longitude'].toString(),
          'user_accuracy': attendance['user_accuracy'].toString(),
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('[SYNC_CLOCK_OUT] Error: $e');
      return false;
    }
  }

  // Clear all learners for a specific class
  Future<void> clearLearners(String classID) async {
    try {
      final db = await database;
      await db
          .delete('learnerdetails', where: 'classID = ?', whereArgs: [classID]);
      print('Cleared all learners for class ID: $classID');
    } catch (e) {
      print('Error clearing learners for class $classID: $e');
      throw Exception('Failed to clear learners: $e');
    }
  }

  // Clean up duplicate clocking records for the same learner on the same day
  Future<void> cleanupDuplicateClockingRecords() async {
    try {
      final db = await database;
      final today = DateTime.now().toIso8601String().split('T')[0];

      print('[CLEANUP_DUPLICATES] Starting duplicate cleanup for date: $today');

      // Find all duplicate records (same learner, same date)
      final duplicates = await db.rawQuery('''
        SELECT LearnerID, clock_date, COUNT(*) as count
        FROM learner_clocking 
        WHERE clock_date = ?
        GROUP BY LearnerID, clock_date
        HAVING COUNT(*) > 1
      ''', [today]);

      if (duplicates.isEmpty) {
        print('[CLEANUP_DUPLICATES] No duplicate records found');
        return;
      }

      print(
          '[CLEANUP_DUPLICATES] Found ${duplicates.length} learners with duplicates');

      for (var duplicate in duplicates) {
        final learnerId = duplicate['LearnerID'];
        final date = duplicate['clock_date'];

        print(
            '[CLEANUP_DUPLICATES] Cleaning up duplicates for LearnerID: $learnerId, date: $date');

        // Get all records for this learner on this date, ordered by clocking_id (newest first)
        final records = await db.query(
          'learner_clocking',
          where: 'LearnerID = ? AND clock_date = ?',
          whereArgs: [learnerId, date],
          orderBy: 'clocking_id DESC',
        );

        if (records.length > 1) {
          // Keep the first (newest) record, delete the rest
          final recordToKeep = records.first;
          final recordsToDelete = records.skip(1);

          print(
              '[CLEANUP_DUPLICATES] Keeping record ID: ${recordToKeep['clocking_id']}, deleting ${recordsToDelete.length} duplicates');

          for (var recordToDelete in recordsToDelete) {
            await db.delete(
              'learner_clocking',
              where: 'clocking_id = ?',
              whereArgs: [recordToDelete['clocking_id']],
            );
            print(
                '[CLEANUP_DUPLICATES] Deleted duplicate record ID: ${recordToDelete['clocking_id']}');
          }
        }
      }

      print('[CLEANUP_DUPLICATES] Duplicate cleanup completed');
    } catch (e) {
      print('[CLEANUP_DUPLICATES] Error cleaning up duplicates: $e');
    }
  }

  // DEPRECATED: Use getAllTemplates instead
  Future<void> updateFingerprintTemplates(
      String learnerID, String templatesJson) async {
    debugPrint(
        '[DEPRECATED] updateFingerprintTemplates called - use saveZkTecoTemplate or saveFutronicTemplate instead');
    // This method is kept for backward compatibility but should not be used
  }

  /// Upsert learner data (INSERT OR REPLACE) - for persistent offline storage
  /// This method NEVER clears existing data, only updates or inserts
  Future<void> upsertLearner(Map<String, dynamic> learnerData) async {
    try {
      final db = await database;

      // Sanitize data to handle nulls properly
      final sanitizedData = _sanitizeLearnerData(learnerData);

      // Use INSERT OR REPLACE to upsert
      await db.insert(
        'learnerdetails',
        sanitizedData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint(
          '[DB_HELPER] Upserted learner: ${sanitizedData['Name']} ${sanitizedData['Surname']} (ID: ${sanitizedData['LearnerID']})');
    } catch (e) {
      debugPrint('[DB_HELPER] Error upserting learner: $e');
      rethrow;
    }
  }

  /// Sanitize learner data to handle null values
  Map<String, dynamic> _sanitizeLearnerData(Map<String, dynamic> rawData) {
    return {
      'LearnerID': rawData['LearnerID'] ?? 0,
      'Title': _sanitizeString(rawData['Title']),
      'Name': _sanitizeString(rawData['Name']),
      'Surname': _sanitizeString(rawData['Surname']),
      'IDNumber': _sanitizeString(rawData['IDNumber']),
      'DateOfBirth': _sanitizeDate(rawData['DateOfBirth']),
      'PhoneNumber': _sanitizeString(rawData['PhoneNumber']),
      'Email': _sanitizeString(rawData['Email']),
      'Age': _sanitizeInt(rawData['Age']),
      'Gender': _sanitizeString(rawData['Gender']),
      'Race': _sanitizeString(rawData['Race']),
      'Language': _sanitizeString(rawData['Language']),
      'Disability': _sanitizeString(rawData['Disability']),
      'AddressLine1': _sanitizeString(rawData['AddressLine1']),
      'AddressLine2': _sanitizeString(rawData['AddressLine2']),
      'AddressLine3': _sanitizeString(rawData['AddressLine3']),
      'PostalCode': _sanitizeString(rawData['PostalCode']),
      'KinName': _sanitizeString(rawData['KinName']),
      'KinRelation': _sanitizeString(rawData['KinRelation']),
      'KinContact': _sanitizeString(rawData['KinContact']),
      'SchoolName': _sanitizeString(rawData['SchoolName']),
      'SchoolCompletion': _sanitizeDate(rawData['SchoolCompletion']),
      'SchoolLocation': _sanitizeString(rawData['SchoolLocation']),
      'SchoolGrade': _sanitizeString(rawData['SchoolGrade']),
      'classID': rawData['classID'] ?? 0,
      'profile_image': _sanitizeString(rawData['profile_image']),
      'signature': _sanitizeString(rawData['signature']),
      'synced': rawData['synced'] ?? 0,
      'zkteco_left_template': _sanitizeString(rawData['zkteco_left_template']),
      'zkteco_right_template':
          _sanitizeString(rawData['zkteco_right_template']),
      'futronic_left_template':
          _sanitizeString(rawData['futronic_left_template']),
      'futronic_right_template':
          _sanitizeString(rawData['futronic_right_template']),
      'imagePath': _sanitizeString(rawData['imagePath']),
      'activity_statu': _sanitizeString(rawData['activity_statu']),
      'witness_initials': _sanitizeString(rawData['witness_initials']),
      'learner_initials': _sanitizeString(rawData['learner_initials']),
      'witness_signature': _sanitizeString(rawData['witness_signature']),
    };
  }

  String _sanitizeString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  int? _sanitizeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // --- MONITORING METHODS ---

  Future<int> saveMonitoringRecordLocally(Map<String, dynamic> record) async {
    try {
      final db = await database;

      // Check if a record already exists for this learner and date to prevent duplicates
      final existing = await db.query(
        'monitoring_records',
        where: 'learner_id = ? AND monitoring_date = ?',
        whereArgs: [record['learner_id'], record['monitoring_date']],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final id = existing.first['id'] as int;
        debugPrint(
            '[DB_HELPER] Updating existing monitoring record for learner ${record['learner_id']} on ${record['monitoring_date']}');
        await db.update(
          'monitoring_records',
          record,
          where: 'id = ?',
          whereArgs: [id],
        );
        return id;
      }

      final id = await db.insert('monitoring_records', record);
      debugPrint('[DB_HELPER] Monitoring record saved locally with ID: $id');
      return id;
    } catch (e) {
      debugPrint('[DB_HELPER] Error saving monitoring record locally: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getUnsyncedMonitoringRecords() async {
    try {
      final db = await database;
      return await db.query(
        'monitoring_records',
        where: 'synced = ?',
        whereArgs: [0],
      );
    } catch (e) {
      debugPrint('[DB_HELPER] Error fetching unsynced monitoring records: $e');
      return [];
    }
  }

  Future<void> markMonitoringRecordAsSynced(int id) async {
    try {
      final db = await database;
      await db.update(
        'monitoring_records',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('[DB_HELPER] Monitoring record $id marked as synced');
    } catch (e) {
      debugPrint('[DB_HELPER] Error marking monitoring record as synced: $e');
    }
  }

  String? _sanitizeDate(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      try {
        DateTime.parse(value);
        return value;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Check if local learner data is available for a class (for offline operations)
  Future<bool> hasLocalLearnerData(String classID) async {
    try {
      final db = await database;
      final result = await db.query(
        'learnerdetails',
        where: 'classID = ?',
        whereArgs: [classID],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('[DB_HELPER] Error checking local data: $e');
      return false;
    }
  }

  /// Get count of local learners for a class
  Future<int> getLocalLearnerCount(String classID) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM learnerdetails WHERE classID = ?',
        [classID],
      );
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('[DB_HELPER] Error getting learner count: $e');
      return 0;
    }
  }

  // DEPRECATED: Use getAllTemplates instead
  Future<Map<String, String?>> getFingerprintTemplates(String learnerID) async {
    debugPrint(
        '[DEPRECATED] getFingerprintTemplates called - use getAllTemplates instead');
    // Return empty templates for backward compatibility
    return {'left': null, 'right': null};
  }

  Future<void> insertClocking(Map<String, dynamic> row) async {
    final db = await database;

    // CRITICAL VALIDATION: Prevent fake clock-ins
    final learnerId = row['LearnerID']?.toString();
    final clockInTime = row['clock_in_time']?.toString();

    // Validate that this is a legitimate clock-in
    if (learnerId == null || learnerId.isEmpty) {
      throw Exception('Invalid learner ID for clock-in');
    }

    if (clockInTime == null || clockInTime.isEmpty) {
      throw Exception('Invalid clock-in time');
    }

    // Prevent suspicious early morning clock-ins (00:00-06:00) unless explicitly allowed
    final time = DateTime.tryParse(clockInTime);
    if (time != null) {
      final hour = time.hour;
      if (hour >= 0 && hour < 6) {
        // Check if this is a legitimate early morning clock-in
        final currentTime = DateTime.now();
        final timeDiff = currentTime.difference(time).inMinutes.abs();

        // If the clock-in time is more than 1 hour different from current time, it's suspicious
        if (timeDiff > 60) {
          throw Exception('Suspicious clock-in time detected: $clockInTime');
        }
      }
    }

    // Remove classID from the data to avoid database errors
    final cleanRow = Map<String, dynamic>.from(row);
    cleanRow.remove('classID');

    // Check if a record already exists for this learner and date
    final existing = await db.query(
      'learner_clocking',
      where: 'LearnerID = ? AND clock_date = ?',
      whereArgs: [cleanRow['LearnerID'], cleanRow['clock_date']],
    );
    if (existing.isEmpty) {
      await db.insert('learner_clocking', cleanRow);
    } else {
      // Update the existing record instead
      await db.update(
        'learner_clocking',
        cleanRow,
        where: 'LearnerID = ? AND clock_date = ?',
        whereArgs: [cleanRow['LearnerID'], cleanRow['clock_date']],
      );
    }
  }

  Future<Map<String, dynamic>?> getAttendanceForDay(
      String learnerID, String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'learner_clocking',
      where: 'LearnerID = ? AND clock_date = ?',
      whereArgs: [learnerID, date],
      orderBy: 'clocking_id DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }

    // Server fetch disabled - data is already synced via main sync endpoint
    // This prevents FormatException errors from broken get_clocking_data.php endpoint
    print(
        '[DB_HELPER] No local record found for LearnerID: $learnerID, date: $date');

    return null;
  }

  Future<void> updateClocking(int clockingId, Map<String, dynamic> row) async {
    final db = await database;
    await db.update(
      'learner_clocking',
      row,
      where: 'clocking_id = ?',
      whereArgs: [clockingId],
    );
  }

  /// Check if a learner has missed all monitoring attempts for the current day
  /// Returns true if the learner was selected for monitoring but missed 3 attempts
  Future<bool> hasMissedAllMonitoring(String learnerId) async {
    try {
      final db = await database;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Check for 'MISSED' status in monitoring_records for today
      // Also check if they were prompted 3 times but never responded
      final result = await db.query(
        'monitoring_records',
        where: 'learner_id = ? AND monitoring_date = ?',
        whereArgs: [learnerId, today],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final record = result.first;
        final finalStatus = record['final_status']?.toString().toUpperCase();

        // If status is 'MISSED' or 'ABSENT', check if it was after 3 attempts
        if (finalStatus == 'MISSED' || finalStatus == 'ABSENT') {
          // If attempt_3_time is set but they still missed, it's a hard block
          // Note: Older records might only have 2 attempts, so we check for both
          if (record['attempt_3_time'] != null ||
              record['attempt_2_time'] != null) {
            debugPrint(
                '[DB_HELPER] Learner $learnerId MISSED monitoring for today. Blocking clock-out.');
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('[DB_HELPER] Error checking monitoring status: $e');
      return false;
    }
  }

  Future<Database> _initDatabase() async {
    final path = await getDatabasesPath();
    return openDatabase(join(path, _dbName), version: 10,
        onUpgrade: (db, oldVersion, newVersion) async {
      debugPrint(
          '[DB] Upgrading database from version $oldVersion to $newVersion');
      if (oldVersion < 2) {
        // Update BankCode column type from INTEGER to VARCHAR
        try {
          await db.execute(
              'ALTER TABLE bankdetails MODIFY COLUMN BankCode VARCHAR(50)');
          debugPrint('[DB] Updated BankCode column type to VARCHAR(50)');
        } catch (e) {
          debugPrint('[DB] Error updating BankCode column: $e');
          // If the column doesn't exist or can't be modified, recreate the table
          try {
            await db.execute('DROP TABLE IF EXISTS bankdetails');
            await db.execute('''
                CREATE TABLE bankdetails (
                  BankID INTEGER PRIMARY KEY AUTOINCREMENT,
                  LearnerID INTEGER,
                  BankName VARCHAR(50),
                  bankType VARCHAR(50),
                  BankAccount VARCHAR(50),
                  BankCode VARCHAR(50),
                  synced INTEGER DEFAULT 0,
                  FOREIGN KEY (LearnerID) REFERENCES learnerdetails(LearnerID)
                )
              ''');
            debugPrint('[DB] Recreated bankdetails table with correct schema');
          } catch (e2) {
            debugPrint('[DB] Error recreating bankdetails table: $e2');
          }
        }
      }
      if (oldVersion < 3) {
        // Add fingerprint columns to facilitator table
        try {
          await db.execute(
              'ALTER TABLE facilitator ADD COLUMN zkteco_left_template longtext');
          await db.execute(
              'ALTER TABLE facilitator ADD COLUMN zkteco_right_template longtext');
          await db.execute(
              'ALTER TABLE facilitator ADD COLUMN futronic_left_template longtext');
          await db.execute(
              'ALTER TABLE facilitator ADD COLUMN futronic_right_template longtext');
          debugPrint('[DB] Added fingerprint columns to facilitator table');
        } catch (e) {
          debugPrint(
              '[DB] Error adding fingerprint columns to facilitator: $e');
        }

        // Create facilitator_clocking table
        try {
          await db.execute('''
              CREATE TABLE IF NOT EXISTS facilitator_clocking (
                clocking_id INTEGER PRIMARY KEY AUTOINCREMENT,
                facilitator_id INTEGER NOT NULL,
                clock_date DATE NOT NULL,
                clock_in_time DATETIME NOT NULL,
                clock_out_time DATETIME,
                contact_time TEXT,
                synced INTEGER NOT NULL DEFAULT 0,
                user_latitude DECIMAL(10,6),
                user_longitude DECIMAL(10,6),
                user_accuracy DECIMAL(10,6)
              )
            ''');
          debugPrint('[DB] Created facilitator_clocking table');
        } catch (e) {
          debugPrint('[DB] Error creating facilitator_clocking table: $e');
        }
      }

      if (oldVersion < 4) {
        // Create learner pathways cache table for offline POE access
        try {
          await db.execute('''
              CREATE TABLE IF NOT EXISTS learner_pathways_cache (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                learnerID INTEGER UNIQUE NOT NULL,
                pathways_json TEXT NOT NULL,
                cached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
              )
            ''');
          debugPrint(
              '[DB] Created learner_pathways_cache table for offline POE support');
        } catch (e) {
          debugPrint('[DB] Error creating learner_pathways_cache table: $e');
        }
      }

      if (oldVersion < 5) {
        // Create pothole_checklist_scanned_documents table
        try {
          await db.execute('''
              CREATE TABLE IF NOT EXISTS pothole_checklist_scanned_documents (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                learner_id TEXT NOT NULL,
                assessor_id TEXT NOT NULL,
                document_path TEXT NOT NULL,
                assessment_date TEXT NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                synced INTEGER DEFAULT 0
              )
            ''');
          debugPrint('[DB] Created pothole_checklist_scanned_documents table');
        } catch (e) {
          debugPrint(
              '[DB] Error creating pothole_checklist_scanned_documents table: $e');
        }
      }

      if (oldVersion < 6) {
        // Add assessorExpiryDate column to facilitator table
        try {
          await db.execute(
              'ALTER TABLE facilitator ADD COLUMN assessorExpiryDate TEXT');
          debugPrint(
              '[DB] Added assessorExpiryDate column to facilitator table');
        } catch (e) {
          debugPrint(
              '[DB] Error adding assessorExpiryDate column to facilitator: $e');
        }
      }

      if (oldVersion < 7) {
        // Create work_experience table
        try {
          await db.execute('''
              CREATE TABLE IF NOT EXISTS work_experience (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                learner_id TEXT NOT NULL,
                employer_name TEXT NOT NULL,
                position_held TEXT NOT NULL,
                period_from TEXT NOT NULL,
                period_to TEXT NOT NULL,
                responsibilities TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                synced INTEGER DEFAULT 0
              )
            ''');
          debugPrint('[DB] Created work_experience table');
        } catch (e) {
          debugPrint('[DB] Error creating work_experience table: $e');
        }
      }

      if (oldVersion < 8) {
        // Add unitStandard column to poe table (prevents exercise key collisions
        // across unit standards, which can cause "wrong tick" behaviour).
        try {
          final columns = await db.rawQuery("PRAGMA table_info('poe')");
          final hasUnitStandard = columns.any(
              (c) => (c['name']?.toString().toLowerCase() == 'unitstandard'));
          if (!hasUnitStandard) {
            await db.execute('ALTER TABLE poe ADD COLUMN unitStandard TEXT');
            debugPrint('[DB] Added unitStandard column to poe table');
          }
        } catch (e) {
          debugPrint('[DB] Error adding unitStandard column to poe: $e');
        }

        // Create facilitator_material_issues table
        try {
          await db.execute('''
              CREATE TABLE IF NOT EXISTS facilitator_material_issues (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                logistics_id TEXT NOT NULL,
                logistics_name TEXT NOT NULL,
                site_id TEXT NOT NULL,
                site_name TEXT NOT NULL,
                class_id TEXT NOT NULL,
                class_name TEXT NOT NULL,
                facilitator_id TEXT NOT NULL,
                facilitator_name TEXT NOT NULL,
                material_type TEXT NOT NULL,
                quantity INTEGER NOT NULL DEFAULT 1,
                description TEXT NOT NULL,
                comments TEXT,
                issue_date TEXT NOT NULL,
                facilitator_signature TEXT,
                logistics_signature TEXT,
                created_at TEXT NOT NULL,
                synced INTEGER DEFAULT 0
              )
            ''');
          debugPrint('[DB] Created facilitator_material_issues table');
        } catch (e) {
          debugPrint(
              '[DB] Error creating facilitator_material_issues table: $e');
        }
      }

      if (oldVersion < 9) {
        // Create monitoring_records table for offline monitoring support
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS monitoring_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              learner_id TEXT NOT NULL,
              learner_name TEXT NOT NULL,
              person_type TEXT DEFAULT 'learner',
              class_id TEXT NOT NULL,
              monitoring_date DATE NOT NULL,
              attempt_1_time DATETIME,
              attempt_1_status TEXT,
              attempt_2_time DATETIME,
              attempt_2_status TEXT,
              attempt_3_time DATETIME,
              attempt_3_status TEXT,
              final_status TEXT NOT NULL,
              verification_time DATETIME,
              verification_method TEXT,
              scanner_type TEXT,
              fingerprint_matched INTEGER DEFAULT 0,
              session_type TEXT,
              created_at DATETIME NOT NULL,
              synced INTEGER DEFAULT 0,
              UNIQUE(learner_id, monitoring_date)
            )
          ''');
          debugPrint('[DB] Created monitoring_records table for version 9');
        } catch (e) {
          debugPrint('[DB] Error creating monitoring_records table: $e');
        }
      }

      if (oldVersion < 10) {
        // Add missing columns to material_receipt_form table
        try {
          // Check if each column exists before adding
          final columns =
              await db.rawQuery("PRAGMA table_info('material_receipt_form')");
          final existingColumns =
              columns.map((c) => c['name']?.toString().toLowerCase()).toSet();

          if (!existingColumns.contains('sub_description')) {
            await db.execute(
                'ALTER TABLE material_receipt_form ADD COLUMN sub_description TEXT');
            debugPrint(
                '[DB] Added sub_description column to material_receipt_form');
          }

          if (!existingColumns.contains('date_aor_created')) {
            await db.execute(
                'ALTER TABLE material_receipt_form ADD COLUMN date_aor_created TEXT');
            debugPrint(
                '[DB] Added date_aor_created column to material_receipt_form');
          }

          if (!existingColumns.contains('facilitator_signature')) {
            await db.execute(
                'ALTER TABLE material_receipt_form ADD COLUMN facilitator_signature TEXT');
            debugPrint(
                '[DB] Added facilitator_signature column to material_receipt_form');
          }

          if (!existingColumns.contains('learnerid')) {
            await db.execute(
                'ALTER TABLE material_receipt_form ADD COLUMN learnerID TEXT');
            debugPrint('[DB] Added learnerID column to material_receipt_form');
          }
        } catch (e) {
          debugPrint('[DB] Error adding columns to material_receipt_form: $e');
        }
      }
    }, onCreate: (db, dbVersion) async {
      // Create example tables
      await db.execute(
        '''
          CREATE TABLE users (
            userID INTEGER PRIMARY KEY AUTOINCREMENT,
            email VARCHAR(255),
            password VARCHAR(255),
            role VARCHAR(50),
            classID INTEGER
          )
          ''',
      );

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
    assessorExpiryDate TEXT,
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

      await db.execute(
        '''
          CREATE TABLE learnerdetails (
              LearnerID INTEGER PRIMARY KEY,
              Title VARCHAR(50) NOT NULL,
              Name VARCHAR(100) NOT NULL,
              Surname VARCHAR(100) NOT NULL,
              IDNumber VARCHAR(20) NOT NULL,
              DateOfBirth DATE NOT NULL,
              PhoneNumber VARCHAR(20),
              Email VARCHAR(100),
              Age INTEGER,
              Gender VARCHAR(10),
              Race VARCHAR(50),
              Language VARCHAR(50),
              Disability VARCHAR(100),
              AddressLine1 VARCHAR(100),
              KinName VARCHAR(100),
              KinRelation VARCHAR(50),
              KinContact VARCHAR(15),
              SchoolName VARCHAR(100),
              SchoolCompletion DATE,
              SchoolLocation VARCHAR(100),
              SchoolGrade VARCHAR(50),
              classID INTEGER,
              profile_image VARCHAR(255),
              signature VARCHAR(255),
              synced INTEGER DEFAULT 0,
              zkteco_left_template longtext,
              imagePath VARCHAR(255),
              zkteco_right_template longtext,
              AddressLine2 VARCHAR(100),
              AddressLine3 VARCHAR(100),
              PostalCode VARCHAR(100),
              activity_statu TEXT(255),
              witness_initials VARCHAR(100),
              learner_initials VARCHAR(100),
              witness_signature VARCHAR(255),
              sourceafis_template longtext,
              futronic_left_template longtext,
              futronic_right_template longtext
          )
          ''',
      );

      await db.execute(
        '''
         CREATE TABLE learner_clocking (
    clocking_id INTEGER PRIMARY KEY AUTOINCREMENT,
    LearnerID INTEGER NOT NULL,
    clock_date DATE NOT NULL,
    clock_in_time TIME NOT NULL,
    clock_out_time TIME,
    contact_time TIME,
    signature TEXT,
    synced INTEGER NOT NULL DEFAULT 0,
    user_latitude DECIMAL(10,6),
    user_longitude DECIMAL(10,6),
    user_accuracy DECIMAL(10,6)
 ); 
          ''',
      );

      //Clocking log
      await db.execute(
        '''
          CREATE TABLE clocking_log (
           log_id INTEGER PRIMARY KEY AUTOINCREMENT,
            learnerID INTEGER,
            action VARCHAR,
            attempt_time DATETIME,
            user_latitude DECIMAL,
            accuracy VARCHAR,
            site_latitude VARCHAR,
             site_longitude VARCHAR,
             user_longitude DECIMAL,
             reason VARCHAR
          )
          ''',
      );

      // Facilitator clocking table
      await db.execute(
        '''
          CREATE TABLE facilitator_clocking (
            clocking_id INTEGER PRIMARY KEY AUTOINCREMENT,
            facilitator_id INTEGER NOT NULL,
            clock_date DATE NOT NULL,
            clock_in_time DATETIME NOT NULL,
            clock_out_time DATETIME,
            contact_time TEXT,
            synced INTEGER NOT NULL DEFAULT 0,
            user_latitude DECIMAL(10,6),
            user_longitude DECIMAL(10,6),
            user_accuracy DECIMAL(10,6)
          )
          ''',
      );

      // Create unsynced data table
      await db.execute(
        '''
          CREATE TABLE $_unsyncedTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT,
            data TEXT,
            synced INTEGER DEFAULT 0
          )
          ''',
      );
      await db.execute(
        '''
          CREATE TABLE sdp (
           sdp_id INTEGER PRIMARY KEY AUTOINCREMENT,
            sdp_name TEXT,
            Reg_number TEXT,
            b_description TEXT,
            accreditation_n TEXT,
            p_address TEXT,
            province TEXT,
            district TEXT,
            municipality TEXT,
            email TEXT,
            sdp_logo TEXT,
            password TEXT,
            role TEXT,
            client_name TEXT,
            signature_image TEXT
          )
          ''',
      );
      await db.execute(
        '''
          CREATE TABLE sites (
            siteID INTEGER PRIMARY KEY AUTOINCREMENT,
            siteName VARCHAR(255),
            beneficiaries VARCHAR(255),
            latitude VARCHAR(50),
            longitude VARCHAR(50),
            sdp_id INTEGER(20),
            Province VARCHAR(50),
            District VARCHAR(50),
            Municipality VARCHAR(50),
            Category VARCHAR(50),
            project_id INTEGER(20),
            Project_pathway VARCHAR(255),
            first_name VARCHAR(255),
            last_name VARCHAR(255),
            cell_phone VARCHAR(15),
            email VARCHAR(255),
            qualification_id VARCHAR(100)
          )
          ''',
      );
      await db.execute(
        '''
    CREATE TABLE bankdetails (
    BankID INTEGER PRIMARY KEY AUTOINCREMENT,
    LearnerID INTEGER,
    BankName VARCHAR(50),
    bankType VARCHAR(50),
    BankAccount VARCHAR(50),
    BankCode VARCHAR(50),
    synced INTEGER DEFAULT 0,
    FOREIGN KEY (LearnerID) REFERENCES learnerdetails(LearnerID)
)

          ''',
      );
      await db.execute(
        '''
         CREATE TABLE class (
    classID INTEGER PRIMARY KEY AUTOINCREMENT,
    className TEXT,
    numberOfLearners INTEGER,
    siteID INTEGER,
    phase_id INTEGER,
    phase_name VARCHAR(255),
    pathway_id VARCHAR(50),
    qualification_id VARCHAR(50)
)

          ''',
      );
      await db.execute(
        '''
         CREATE TABLE learningpathway (
    pathway_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    synced INTEGER DEFAULT 0  
)

          ''',
      );

      await db.execute(
        '''
         CREATE TABLE qualification (
         id INTEGER,
         qualification_id INTEGER PRIMARY KEY AUTOINCREMENT,
         name TEXT,
         description TEXT,
         level INTEGER,
         credits INTEGER,
         qualification_type VARCHAR(255),
         has_cat VARCHAR(50),
         synced INTEGER DEFAULT 0  
)

          ''',
      );
      await db.execute(
        '''
         CREATE TABLE qualifications (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         name TEXT
)
          ''',
      );
      await db.execute(
        '''
         CREATE TABLE unitstandard (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         unitstandard_id INTEGER,
         qualification_id INTEGER,
         unit_standard_name TEXT,
         level INTEGER,
         credits INTEGER,
         synced INTEGER DEFAULT 0  
)

          ''',
      );
      await db.execute(
        '''
         CREATE TABLE assessments (
         assessment_id INTEGER PRIMARY KEY AUTOINCREMENT,
         project_id VARCHAR(50),
         unit_standard_id INTEGER,
         question_number TEXT,
         specific_outcome TEXT,
         assessment_criteria TEXT,
         exercise TEXT,
          answer LONGTEXT,
         marks INTEGER,
         assessment_type TEXT,
         start_date DATE,
         end_date DATE,
         created_at timestamp,
         synced INTEGER DEFAULT 0,
         question_type TEXT
)

          ''',
      );
      await db.execute(
        '''
         CREATE TABLE poe (
         poe_id  INTEGER PRIMARY KEY AUTOINCREMENT,
         learnerID INTEGER,
         exercise TEXT,
         type TEXT,
         filePath TEXT,
         submitted_at timestamp,
         synced INTEGER DEFAULT 0,
         logbook_text TEXT 
)
          ''',
      );

      // Create learner pathways cache table for offline POE access
      await db.execute(
        '''
         CREATE TABLE learner_pathways_cache (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         learnerID INTEGER UNIQUE NOT NULL,
         pathways_json TEXT NOT NULL,
         cached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
         updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
          ''',
      );

      await db.execute(
        '''
CREATE TABLE material_forms(
id INTEGER PRIMARY KEY AUTOINCREMENT, 
classID INTEGER,
facilitator_full_name TEXT,
representative_full_name TEXT,
qualification_name TEXT,
facilitator_signature TEXT NOT NULL,  -- Changed to TEXT instead of BLOB
representative_signature TEXT NOT NULL,  -- Changed to TEXT instead of BLOB
description TEXT,
quantity INTEGER,
is_synced BOOLEAN, 
created_at TIMESTAMP,
updated_at TIMESTAMP
)

          ''',
      );
      await db.execute('''
   CREATE TABLE IF NOT EXISTS material_receipt_form (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id_number TEXT NOT NULL,
      student_full_name TEXT NOT NULL,
      learnerID TEXT,
      class_name TEXT NOT NULL,
       received TEXT NOT NULL CHECK(received IN ('Yes', 'No')) DEFAULT 'No',
      quantity INTEGER NOT NULL DEFAULT 1,
      description TEXT,
      sub_description TEXT,
      date_received TEXT,
      date_aor_created TEXT,
      practitioner_full_name TEXT,  -- Matches MySQL
      learner_signature TEXT,  -- Matches MySQL
      facilitator_signature TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      synced INTEGER NOT NULL DEFAULT 0
    )
''');

      // Create monitoring_records table for offline monitoring support
      await db.execute('''
        CREATE TABLE IF NOT EXISTS monitoring_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          learner_id TEXT NOT NULL,
          learner_name TEXT NOT NULL,
          person_type TEXT DEFAULT 'learner',
          class_id TEXT NOT NULL,
          monitoring_date DATE NOT NULL,
          attempt_1_time DATETIME,
          attempt_1_status TEXT,
          attempt_2_time DATETIME,
          attempt_2_status TEXT,
          attempt_3_time DATETIME,
          attempt_3_status TEXT,
          final_status TEXT NOT NULL,
          verification_time DATETIME,
          verification_method TEXT,
          scanner_type TEXT,
          fingerprint_matched INTEGER DEFAULT 0,
          session_type TEXT,
          created_at DATETIME NOT NULL,
          synced INTEGER DEFAULT 0,
          UNIQUE(learner_id, monitoring_date)
        )
      ''');

      // Create the project table
      await db.execute('''
      CREATE TABLE project (
        project_id INTEGER PRIMARY KEY AUTOINCREMENT,
        sdp_name TEXT NOT NULL,
        client_name TEXT NOT NULL,
        Project_name TEXT NOT NULL,
        Contract_no TEXT NOT NULL,
        Financial_year TEXT NOT NULL,
        Start_date TEXT NOT NULL,
        End_date TEXT NOT NULL,
        Project_pathway TEXT NOT NULL,
        Project_funder TEXT NOT NULL,
        n_beneficiaries TEXT NOT NULL,
        Province TEXT NOT NULL,
        District TEXT NOT NULL,
        Municipality TEXT NOT NULL,
        PPE TEXT NOT NULL,
        Learning_material TEXT NOT NULL,
        Toolkit TEXT NOT NULL,
        Consumables TEXT NOT NULL,
        Budget TEXT NOT NULL,
        pathway_start_dates TEXT,
        pathway_end_dates TEXT,
        pathway_stipends TEXT,
        pathway_stipend_types TEXT,
        pathway_uif_status TEXT
      )
    ''');
      await db.execute('''
         CREATE TABLE learner_document (
    document_id INTEGER PRIMARY KEY AUTOINCREMENT,
    documentName TEXT,
    learner_document TEXT,
    status TEXT,
    learner_id TEXT,
    upload_date TEXT,
    synced INTEGER DEFAULT 0,
    rejection_reason TEXT
)''');
      await db.execute('''
  CREATE TABLE sick_note (
    note_id INTEGER PRIMARY KEY AUTOINCREMENT,
    learner_id INTEGER,
    document_path TEXT,
    practice_name TEXT,
    medical_practitioner TEXT,
    practitioner_name TEXT,
    date_from TEXT,
    date_to TEXT,
    upload_date TEXT,
    status TEXT DEFAULT 'PENDING',
    rejection_reason TEXT,
    synced INTEGER DEFAULT 0
  )
''');

      await db.execute('''
  CREATE TABLE manual_clocking (
    manual_id INTEGER PRIMARY KEY AUTOINCREMENT,
    clocking_id INTEGER,
    LearnerID INTEGER NOT NULL,
    clock_date TEXT NOT NULL,
    clock_in_time TEXT,
    clock_out_time TEXT,
    contact_time TEXT,
    manual_reason TEXT,
    fdp_document TEXT,
    status TEXT DEFAULT 'Pending',
    reviewed_by TEXT,
    reviewed_at TEXT,
    rejection_reason TEXT,
    is_manual_attendance INTEGER DEFAULT 1,
    synced INTEGER DEFAULT 0
  )
''');

      await db.execute(
        '''
         CREATE TABLE induction_clocking (
    clocking_id INTEGER PRIMARY KEY AUTOINCREMENT,
    LearnerID INTEGER NOT NULL,
    clock_date DATE NOT NULL,
    clock_in_time TIME NOT NULL,
    clock_out_time TIME,
    contact_time TIME,
    signature TEXT,
    synced INTEGER NOT NULL DEFAULT 0,
    user_latitude DECIMAL(10,6),
    user_longitude DECIMAL(10,6),
    user_accuracy DECIMAL(10,6)
 );
          ''',
      );

      // Create pothole_checklist_scanned_documents table
      await db.execute(
        '''
         CREATE TABLE pothole_checklist_scanned_documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    learner_id TEXT NOT NULL,
    assessor_id TEXT NOT NULL,
    document_path TEXT NOT NULL,
    assessment_date TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    synced INTEGER DEFAULT 0
 );
          ''',
      );
      await db.execute('''
              CREATE TABLE IF NOT EXISTS guardian_details (
                guardian_id INTEGER PRIMARY KEY AUTOINCREMENT,
                learner_id INTEGER NOT NULL,
                full_name VARCHAR(255),
                id_number VARCHAR(13),
                home_address TEXT,
                postal_address TEXT,
                telephone VARCHAR(50),
                email VARCHAR(255),
                signature TEXT,
                witness_signature TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                synced INTEGER DEFAULT 0,
                FOREIGN KEY (learner_id) REFERENCES learnerdetails(LearnerID)
              )
            ''');

      // Create work_experience table
      await db.execute('''
              CREATE TABLE IF NOT EXISTS work_experience (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                learner_id TEXT NOT NULL,
                employer_name TEXT NOT NULL,
                position_held TEXT NOT NULL,
                period_from TEXT NOT NULL,
                period_to TEXT NOT NULL,
                responsibilities TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                synced INTEGER DEFAULT 0
              )
            ''');

      // Create facilitator_material_issues table
      await db.execute('''
              CREATE TABLE IF NOT EXISTS facilitator_material_issues (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                logistics_id TEXT NOT NULL,
                logistics_name TEXT NOT NULL,
                site_id TEXT NOT NULL,
                site_name TEXT NOT NULL,
                class_id TEXT NOT NULL,
                class_name TEXT NOT NULL,
                facilitator_id TEXT NOT NULL,
                facilitator_name TEXT NOT NULL,
                material_type TEXT NOT NULL,
                quantity INTEGER NOT NULL DEFAULT 1,
                description TEXT NOT NULL,
                comments TEXT,
                issue_date TEXT NOT NULL,
                facilitator_signature TEXT,
                logistics_signature TEXT,
                created_at TEXT NOT NULL,
                synced INTEGER DEFAULT 0
              )
            ''');
    });
  }

  // Method to hash passwords
  String hashPassword(String password) {
    var bytes = utf8.encode(password); // Convert password to bytes
    var digest = sha256.convert(bytes); // Hash using SHA-256
    return digest.toString();
  }

  // Method to fetch a user by their username (email) and validate password
  Future<Map<String, dynamic>?> getUser(String email, String password) async {
    var db = await database; // Open the database

    // Query the database for the user matching the provided email and password
    var result = await db.query(
      'facilitator', // The name of the table where users are stored
      where: 'email = ? AND password = ?', // Match email and password
      whereArgs: [email, password], // The email and password to search for
    );
    // Debug: Print the query result
    print("Query result: $result");
    // If result is found, return the first record
    if (result.isNotEmpty) {
      return result.first; // Returns the first matching user
    } else {
      return null; // No user found
    }
  }

  // Sync facilitator data to the local database
  Future<void> syncFacilitatorData(String email) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.getFacilitatorDataUrl}?email=$email'),
      );

      if (response.statusCode == 200) {
        final db = await database;
        final data = json.decode(response.body); // Assuming response is JSON

        // Clear the local facilitator table
        await db.delete('facilitator');

        // Insert the facilitator data into the local database
        await db.insert('facilitator', {
          'email': data['email'],
          'password': data['password'],
          'role': data['role'],
          'classID': data['classID'],
        });

        print('Facilitator data synced successfully.');
      } else {
        print('Failed to fetch facilitator data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing facilitator data: $e');
    }
  }

  // Store user credentials for offline use (storing hashed password)
  Future<void> storeUserCredentials(
      String email, String password, String role, String classID) async {
    final db = await database;
    String hashedPassword = hashPassword(password);

    // Store the facilitator data in the local database
    await db.insert('facilitator', {
      'email': email,
      'password': hashedPassword,
      'role': role,
      'classID': classID,
    });
  }

  // Fetch user credentials for offline login
  Future<Map<String, dynamic>?> getUserCredentials(String email) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'facilitator',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // Validate user credentials offline (check with hashed password)
  Future<bool> validateUserOffline(String email, String password) async {
    final db = await database;
    String hashedPassword = hashPassword(password);

    final List<Map<String, dynamic>> result = await db.query(
      'facilitator',
      where: 'email = ? AND password = ?',
      whereArgs: [email, hashedPassword],
    );
    return result.isNotEmpty;
  }

  // Check if facilitator data is available in the database
  Future<void> checkFacilitatorData() async {
    final db = await database;
    final result = await db.query('facilitator');
    print("Facilitator table data: $result");
  }

  // Insert unsynced data into the tracking table
  Future<void> insertUnsyncedData(
      String tableName, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      _unsyncedTable,
      {
        'table_name': tableName,
        'data': json.encode(data),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Connectivity Listener
  void initConnectivityListener() {
    try {
      Connectivity().onConnectivityChanged.listen(
          (List<ConnectivityResult> resultList) {
        try {
          _updateConnectionStatus(
              resultList); // Pass the entire list to the update method
        } catch (e) {
          print('Error in connectivity listener: $e');
          // Don't let connectivity errors crash the app
        }
      }, onError: (error) {
        print('Connectivity listener error: $error');
        // Don't let connectivity errors crash the app
      });
    } catch (e) {
      print('Error initializing connectivity listener: $e');
      // Don't let connectivity errors crash the app
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    try {
      // Assuming the first result is the relevant one (since the list may contain multiple results)
      ConnectivityResult result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;

      if (result != ConnectivityResult.none) {
        print('Internet available - syncing offline data...');
        // Sync unsynced learners (profile, images, etc.) when back online
        syncUnsyncedLearnersWhenOnline().catchError((error) {
          print('Error syncing learner data: $error');
        });
        // Don't block the UI with sync operations
        syncUnsyncedData().catchError((error) {
          print('Error syncing data: $error');
          // Don't let sync errors crash the app
        });
      } else {
        print('No internet connection.');
      }
    } catch (e) {
      print('Error updating connection status: $e');
      // Don't let connectivity errors crash the app
    }
  }

  /// Sync unsynced learners to server when back online (no UI - for connectivity listener)
  Future<void> syncUnsyncedLearnersWhenOnline() async {
    final db = await database;
    if (!await _checkConnectivity()) return;

    final unsyncedLearners = await db.query(
      'learnerdetails',
      where: 'synced = ?',
      whereArgs: [0],
    );
    if (unsyncedLearners.isEmpty) return;

    print(
        '[SYNC] Found ${unsyncedLearners.length} unsynced learners - syncing to server');
    List<Map<String, dynamic>> allDataToSync = [];
    for (var learner in unsyncedLearners) {
      try {
        int localLearnerId = learner['LearnerID'] as int;
        final bankDetails = await db.query(
          'bankdetails',
          where: 'LearnerID = ?',
          whereArgs: [localLearnerId],
        );
        Map<String, dynamic> learnerData =
            await _prepareLearnerDataWithBase64Images(Map.from(learner));
        allDataToSync.add({
          'learner': learnerData,
          'bank': bankDetails.isNotEmpty ? Map.from(bankDetails.first) : null,
        });
      } catch (e) {
        print('Error preparing learner ${learner['IDNumber']}: $e');
      }
    }
    final responseData = await _sendAllDataToBackend(allDataToSync);
    if (responseData != null && responseData['status'] == 'success') {
      List<dynamic> syncedLearners = responseData['learners'] ?? [];
      for (var syncedLearner in syncedLearners) {
        try {
          await updateSyncedStatus(
              syncedLearner['IDNumber'], syncedLearner['LearnerID']);
        } catch (e) {
          print('Error updating sync status: $e');
        }
      }
      print('[SYNC] Successfully synced ${syncedLearners.length} learners');
    }
  }

  // Sync unsynced data to the server
  Future<void> syncUnsyncedData() async {
    final db = await database;
    final List<Map<String, dynamic>> unsyncedData = await db.query(
      _unsyncedTable,
      where: 'synced = ?',
      whereArgs: [0],
    );

    for (var data in unsyncedData) {
      try {
        final response = await http.post(
          Uri.parse(AppConfig.syncDataUrl),
          body: {'table_name': data['table_name'], 'data': data['data']},
        );

        if (response.statusCode == 200) {
          await db.update(
            _unsyncedTable,
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [data['id']],
          );
          print('Data synced successfully');
        } else {
          print('Failed to sync data: ${response.statusCode}');
        }
      } catch (e) {
        print('Error syncing data: $e');
      }
    }
  }

  // General database operations
  Future<void> insertData(String tableName, Map<String, dynamic> data) async {
    final db = await database;
    try {
      Map<String, dynamic> mappedData = Map<String, dynamic>.from(data);

      // Only learnerdetails table has special column mapping
      // All other tables (including facilitator) use data exactly as-is from server
      if (tableName == 'learnerdetails') {
        // Map old column names to new ones for backwards compatibility
        if (mappedData.containsKey('fingerprint_template')) {
          final fingerprintTemplate =
              mappedData['fingerprint_template']?.toString() ?? '';
          final isLeftHand = mappedData['isLeftHand']?.toString() ?? '';

          // Map fingerprint template based on scanner type and hand
          if (fingerprintTemplate.isNotEmpty) {
            print(
                '[MAPPING] Processing fingerprint_template: ${fingerprintTemplate.length} chars, isLeftHand: $isLeftHand');

            if (isLeftHand == '1' || isLeftHand.toLowerCase() == 'true') {
              // isLeftHand=true means LEFT hand template
              mappedData['futronic_left_template'] = fingerprintTemplate;
              print(
                  '[MAPPING] ✅ Mapped fingerprint_template to futronic_left_template (isLeftHand=true)');
            } else {
              // isLeftHand=false/0 means RIGHT hand template
              mappedData['futronic_right_template'] = fingerprintTemplate;
              print(
                  '[MAPPING] ✅ Mapped fingerprint_template to futronic_right_template (isLeftHand=false)');
            }
          }
          mappedData.remove('fingerprint_template');
        }

        if (mappedData.containsKey('isLeftHand')) {
          mappedData.remove('isLeftHand');
          print('Removed old isLeftHand field');
        }
      }

      // For facilitator table, log what we're about to insert
      if (tableName == 'facilitator') {
        print('[DB_INSERT] Facilitator data being inserted:');
        print('[DB_INSERT]   ID: ${mappedData['facilitator_id']}');
        print(
            '[DB_INSERT]   Name: ${mappedData['firstName']} ${mappedData['lastName']}');
        print('[DB_INSERT]   Email: ${mappedData['email']}');
        print('[DB_INSERT]   Role: ${mappedData['role']}');
        print('[DB_INSERT]   ClassID: ${mappedData['classID']}');
        print('[DB_INSERT]   All keys: ${mappedData.keys.toList()}');
      }

      // learnerdetails has strict NOT NULL columns in local schema.
      // Some sync payloads are partial and omit these fields, so ensure
      // defaults to prevent SQLITE_CONSTRAINT_NOTNULL failures.
      if (tableName == 'learnerdetails') {
        mappedData['LearnerID'] = mappedData['LearnerID'] ?? 0;
        mappedData['Title'] =
            (mappedData['Title']?.toString().trim().isNotEmpty ?? false)
                ? mappedData['Title']
                : 'N/A';
        mappedData['Name'] =
            (mappedData['Name']?.toString().trim().isNotEmpty ?? false)
                ? mappedData['Name']
                : 'N/A';
        mappedData['Surname'] =
            (mappedData['Surname']?.toString().trim().isNotEmpty ?? false)
                ? mappedData['Surname']
                : 'N/A';
        mappedData['IDNumber'] =
            (mappedData['IDNumber']?.toString().trim().isNotEmpty ?? false)
                ? mappedData['IDNumber']
                : 'UNKNOWN';
        mappedData['DateOfBirth'] =
            (mappedData['DateOfBirth']?.toString().trim().isNotEmpty ?? false)
                ? mappedData['DateOfBirth']
                : '1900-01-01';
      }

      // Insert data as-is (with mappings only for learnerdetails)
      await db.insert(tableName, mappedData,
          conflictAlgorithm: ConflictAlgorithm.replace);
      print('Successfully inserted data into $tableName');
    } catch (e) {
      print('Error inserting data into $tableName: $e');
      print('Data keys: ${data.keys.toList()}');
      print('Data values: ${data.values.toList()}');
      rethrow;
    }
  }

  // Specific method for inserting learner details with complete field validation
  Future<void> insertLearnerDetails(Map<String, dynamic> learnerData) async {
    final db = await database;
    try {
      // Ensure all required fields are present with proper defaults
      Map<String, dynamic> completeLearnerData = {
        'LearnerID': learnerData['LearnerID'] ?? 0,
        'Title': learnerData['Title'] ?? 'N/A',
        'Name': learnerData['Name'] ?? '',
        'Surname': learnerData['Surname'] ?? '',
        'IDNumber': learnerData['IDNumber'] ?? '',
        'DateOfBirth': learnerData['DateOfBirth'] ?? '1900-01-01',
        'PhoneNumber': learnerData['PhoneNumber'] ?? '',
        'Email': learnerData['Email'] ?? '',
        'Age': learnerData['Age'] ?? 0,
        'Gender': learnerData['Gender'] ?? '',
        'Race': learnerData['Race'] ?? '',
        'Language': learnerData['Language'] ?? '',
        'Disability': learnerData['Disability'] ?? '',
        'AddressLine1': learnerData['AddressLine1'] ?? '',
        'AddressLine2': learnerData['AddressLine2'] ?? '',
        'AddressLine3': learnerData['AddressLine3'] ?? '',
        'PostalCode': learnerData['PostalCode'] ?? '',
        'KinName': learnerData['KinName'] ?? '',
        'KinRelation': learnerData['KinRelation'] ?? '',
        'KinContact': learnerData['KinContact'] ?? '',
        'SchoolName': learnerData['SchoolName'] ?? '',
        'SchoolCompletion': learnerData['SchoolCompletion'] ?? '1900-01-01',
        'SchoolLocation': learnerData['SchoolLocation'] ?? '',
        'SchoolGrade': learnerData['SchoolGrade'] ?? '',
        'classID': learnerData['classID'] ?? 0,
        'profile_image': learnerData['profile_image'] ?? '',
        'signature': learnerData['signature'] ?? '',
        'synced': learnerData['synced'] ?? 0,
        'zkteco_left_template': learnerData['zkteco_left_template'] ?? '',
        'zkteco_right_template': learnerData['zkteco_right_template'] ?? '',
        'futronic_left_template': learnerData['futronic_left_template'] ?? '',
        'futronic_right_template': learnerData['futronic_right_template'] ?? '',
        'imagePath': learnerData['imagePath'] ?? '',
        'activity_statu': learnerData['activity_statu'] ?? '',
        'witness_initials': learnerData['witness_initials'] ?? '',
        'learner_initials': learnerData['learner_initials'] ?? '',
        'witness_signature': learnerData['witness_signature'] ?? '',
        'sourceafis_template': learnerData['sourceafis_template'] ?? '',
      };

      await db.insert('learnerdetails', completeLearnerData,
          conflictAlgorithm: ConflictAlgorithm.replace);
      print(
          'Successfully inserted learner details with all fields: ${completeLearnerData.keys.toList()}');
    } catch (e) {
      print('Error inserting learner details: $e');
      print('Learner data keys: ${learnerData.keys.toList()}');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchData(String tableName) async {
    final db = await database;
    return await db.query(tableName);
  }

  // Method to clear a table
  Future<void> clearTable(String tableName) async {
    final db = await database;
    await db.delete(tableName); // Deletes all records from the table
    print('Table $tableName cleared successfully');
  }

  // Future<Map<String, dynamic>?> getFacilitator(String email,
  //     String password) async {
  //   final db = await database; // Assuming 'database' is your SQLite database instance.
  //
  //   // Query the database for a facilitator with the provided email and password.
  //   final result = await db.query(
  //     'facilitator',
  //     where: 'email = ? AND password = ?',
  //     whereArgs: [email, password],
  //   );
  //
  //   // Print the result to the console for debugging
  //   print("Facilitator Query Result: $result");
  //
  //   if (result.isNotEmpty) {
  //     // Return the first match (assuming you expect one or more matches)
  //     return result.first;
  //   } else {
  //     // If no facilitator is found, return null
  //     return null;
  //   }
  // }

  Future<void> deleteData(String tableName, int id) async {
    final db = await database;
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  // Check if database is connected
  Future<bool> isDatabaseConnected() async {
    try {
      var db = await database;
      var result = await db.rawQuery("SELECT 1");
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getLearnersByClass(String classID) async {
    final db = await database; // Access the SQLite database
    return await db.query(
      'learnerdetails',
      where: 'classID = ?',
      whereArgs: [classID],
    );
  }

  /// Resolve classID, siteID, and project_id for a learner via local SQLite.
  Future<Map<String, String?>> getLearnerTraceability(String learnerId) async {
    final db = await database;

    final results = await db.rawQuery('''
      SELECT ld.classID, c.siteID, s.project_id
      FROM learnerdetails ld
      LEFT JOIN class c ON ld.classID = c.classID
      LEFT JOIN sites s ON c.siteID = s.siteID
      WHERE ld.LearnerID = ?
    ''', [learnerId]);

    String? classId;
    String? siteId;
    String? projectId;

    if (results.isNotEmpty) {
      classId = results.first['classID']?.toString();
      siteId = results.first['siteID']?.toString();
      projectId = results.first['project_id']?.toString();
    }

    if (classId != null &&
        classId.isNotEmpty &&
        (siteId == null ||
            siteId.isEmpty ||
            projectId == null ||
            projectId.isEmpty)) {
      final classResults = await db.rawQuery('''
        SELECT c.siteID, s.project_id
        FROM class c
        LEFT JOIN sites s ON c.siteID = s.siteID
        WHERE c.classID = ?
      ''', [classId]);
      if (classResults.isNotEmpty) {
        siteId ??= classResults.first['siteID']?.toString();
        projectId ??= classResults.first['project_id']?.toString();
      }
    }

    return {
      'classID': classId,
      'siteID': siteId,
      'project_id': projectId,
    };
  }

  //get data with clockindata
  Future<List<Map<String, dynamic>>> getLearnersWithClockingData(
      String classID) async {
    final db = await database;

    // Use South African time (SAST - UTC+2)
    final saTime = DateTime.now().toUtc().add(const Duration(hours: 2));
    final currentDate = DateFormat('yyyy-MM-dd').format(saTime);

    debugPrint(
        '[LOAD_LEARNERS] Getting learners for classID: $classID, date: $currentDate (SAST)');

    final result = await db.rawQuery('''
    SELECT 
      l.LearnerID, 
      l.Name, 
      l.Surname,
      l.IDNumber,
      l.zkteco_left_template,
      l.zkteco_right_template,
      l.futronic_left_template,
      l.futronic_right_template,
      l.sourceafis_template,
      lc.clock_in_time, 
      lc.clock_out_time,
      lc.contact_time
    FROM learnerdetails l
    LEFT JOIN (
      SELECT LearnerID, clock_date, 
             MIN(clock_in_time) as clock_in_time, 
             MAX(clock_out_time) as clock_out_time,
             MAX(contact_time) as contact_time
      FROM learner_clocking
      WHERE clock_date = ?
      GROUP BY LearnerID
    ) lc ON l.LearnerID = lc.LearnerID 
    WHERE l.classID = ?
  ''', [
      currentDate, // Current date in SAST
      classID
    ]);

    debugPrint(
        '[LOAD_LEARNERS] Found ${result.length} learners with clocking data for today');
    return result;
  }

  // Get ONLY learners who have clocked in today
  Future<List<Map<String, dynamic>>> getClockedInLearnersOnly(
      String classID) async {
    final db = await database;

    // Use South African time (SAST - UTC+2)
    final saTime = DateTime.now().toUtc().add(const Duration(hours: 2));
    final currentDate = DateFormat('yyyy-MM-dd').format(saTime);

    debugPrint(
        '[CLOCKED_IN_ONLY] Getting clocked-in learners for classID: $classID, date: $currentDate (SAST)');

    final result = await db.rawQuery('''
    SELECT 
      l.LearnerID, 
      l.Name, 
      l.Surname,
      l.IDNumber,
      l.zkteco_left_template,
      l.zkteco_right_template,
      l.futronic_left_template,
      l.futronic_right_template,
      l.sourceafis_template,
      lc.clock_in_time, 
      lc.clock_out_time,
      lc.contact_time
    FROM learnerdetails l
    INNER JOIN (
      SELECT LearnerID, clock_date, 
             MIN(clock_in_time) as clock_in_time, 
             MAX(clock_out_time) as clock_out_time,
             MAX(contact_time) as contact_time
      FROM learner_clocking
      WHERE clock_date = ?
      GROUP BY LearnerID
    ) lc ON l.LearnerID = lc.LearnerID 
    WHERE l.classID = ?
    AND lc.clock_in_time IS NOT NULL
    AND lc.clock_in_time != ''
    ORDER BY lc.clock_in_time DESC
  ''', [
      currentDate, // Current date in SAST
      classID
    ]);

    debugPrint(
        '[CLOCKED_IN_ONLY] Found ${result.length} learners who clocked in today');
    return result;
  }

  // Get ALL learners from class with their earliest clocking data (if any)
  Future<List<Map<String, dynamic>>> getLearnersWithAllClockingData(
      String classID) async {
    final db = await database;

    // First get all learners from the class
    final allLearners = await db.query(
      'learnerdetails',
      where: 'classID = ?',
      whereArgs: [classID],
      orderBy: 'LearnerID ASC',
    );

    List<Map<String, dynamic>> result = [];

    // For each learner, get their earliest clocking record (if any)
    for (var learner in allLearners) {
      final learnerId = learner['LearnerID'];

      // Get earliest clocking record for this learner
      final earliestClocking = await db.query(
        'learner_clocking',
        where: 'LearnerID = ?',
        whereArgs: [learnerId],
        orderBy: 'clock_date ASC, clock_in_time ASC',
        limit: 1,
      );

      // Combine learner data with earliest clocking data (if exists)
      var combinedData = Map<String, dynamic>.from(learner);

      if (earliestClocking.isNotEmpty) {
        final clocking = earliestClocking.first;
        combinedData['clock_in_time'] = clocking['clock_in_time'];
        combinedData['clock_out_time'] = clocking['clock_out_time'];
        combinedData['contact_time'] = clocking['contact_time'];
        combinedData['clock_date'] = clocking['clock_date'];
        combinedData['has_clocking'] = true;
      } else {
        // No clocking records for this learner
        combinedData['clock_in_time'] = null;
        combinedData['clock_out_time'] = null;
        combinedData['contact_time'] = null;
        combinedData['clock_date'] = null;
        combinedData['has_clocking'] = false;
      }

      result.add(combinedData);
    }

    return result;
  }

  // Get approved manual attendance days for a learner in a specific month
  Future<int> getApprovedManualAttendanceDays(
      int learnerId, String monthStr) async {
    final db = await database;

    try {
      // Query approved manual clocking records for the month
      final result = await db.rawQuery('''
        SELECT COUNT(DISTINCT DATE(clock_date)) as count
        FROM manual_clocking
        WHERE LearnerID = ?
        AND clock_date LIKE ?
        AND (status = 'Approved' OR status = 'approved' OR status = 'APPROVED')
      ''', [learnerId, '$monthStr%']);

      if (result.isNotEmpty && result.first['count'] != null) {
        return result.first['count'] as int;
      }
      return 0;
    } catch (e) {
      print(
          '[DATABASE] Error getting approved manual attendance for learner $learnerId: $e');
      return 0;
    }
  }

  // Method to check if clock-in exists for a specific learner and date
  Future<Map<String, dynamic>?> getClockInForDate(
      String learnerID, String clockDate) async {
    final db = await database;
    final result = await db.query(
      'learner_clocking',
      where: 'LearnerID = ? AND clock_date = ? AND clock_out_time IS NULL',
      whereArgs: [learnerID, clockDate],
    );
    if (result.isEmpty) return null;

    // Ensure only ONE open record per learner/date by cleaning up duplicates
    if (result.length > 1) {
      // Keep the earliest record by clocking_id, delete the rest
      result.sort((a, b) {
        final aId = (a['clocking_id'] ?? 0) as int;
        final bId = (b['clocking_id'] ?? 0) as int;
        return aId.compareTo(bId);
      });
      final keepId = result.first['clocking_id'] as int;
      final deleted = await db.delete(
        'learner_clocking',
        where:
            'LearnerID = ? AND clock_date = ? AND clock_out_time IS NULL AND clocking_id != ?',
        whereArgs: [learnerID, clockDate, keepId],
      );
      print(
          '[CLOCKING_CLEANUP] Removed $deleted duplicate open learner_clocking rows for learner=$learnerID, date=$clockDate, kept clocking_id=$keepId');
    }

    return result.first;
  }

//find all data for clockins
  // Method to get all clocking data for today
  Future<List<Map<String, dynamic>>> getClockingDataForToday() async {
    final db = await database;
    final today =
        DateFormat('yyyy-MM-dd').format(DateTime.now()); // Format today's date

    // Query to fetch data where the clock_date matches today's date
    return await db.query(
      'learner_clocking',
      where: 'clock_date = ?',
      whereArgs: [today], // Pass today's date as a parameter
    );
  }

  // Insert clock-in record into the database
  Future<void> insertClockInOffline(Map<String, dynamic> clockInData) async {
    final db = await database;

    // Retrieve the clock-in record for the specific learner and date
    final clockDate = clockInData['clock_date'];
    final learnerID = clockInData['LearnerID'];

    final existingClockIn = await db.query(
      'learner_clocking',
      where: 'LearnerID = ? AND clock_date = ?',
      whereArgs: [learnerID, clockDate],
    );

    if (existingClockIn.isEmpty) {
      // If no existing record, insert a new clock-in record
      await db.insert('learner_clocking', clockInData);
      print('Learner Clock In Data Inserted: $clockInData');
      return;
    }

    // If multiple records exist for this learner/date, clean them up: keep one, delete others
    if (existingClockIn.length > 1) {
      existingClockIn.sort((a, b) {
        final aId = (a['clocking_id'] ?? 0) as int;
        final bId = (b['clocking_id'] ?? 0) as int;
        return aId.compareTo(bId);
      });
      final keepId = existingClockIn.first['clocking_id'] as int;
      final deleted = await db.delete(
        'learner_clocking',
        where: 'LearnerID = ? AND clock_date = ? AND clocking_id != ?',
        whereArgs: [learnerID, clockDate, keepId],
      );
      print(
          '[CLOCKING_CLEANUP] Removed $deleted duplicate learner_clocking rows for learner=$learnerID, date=$clockDate, kept clocking_id=$keepId');
    }

    // Update the single remaining record
    await db.update(
      'learner_clocking',
      clockInData,
      where: 'LearnerID = ? AND clock_date = ?',
      whereArgs: [learnerID, clockDate],
    );
    print('Learner Clock In Data Updated: $clockInData');
  }

//update clock out
  Future<void> updateClockOutOffline(Map<String, dynamic> clockOutData) async {
    final db = await database;

    // Retrieve the learner ID and clock-out date from clockOutData
    String learnerID = clockOutData['LearnerID'];
    String clockDate = clockOutData['clock_date'];

    // Retrieve the clock-in data for the learner on the current date
    Map<String, dynamic>? clockInData =
        await getClockInForDate(learnerID, clockDate);

    if (clockInData != null) {
      // If clock-in exists, calculate the contact time (time difference between clock-in and clock-out)
      DateTime clockInTime = DateTime.parse(clockInData['clock_in_time']);
      DateTime clockOutTime = DateTime.parse(clockOutData['clock_out_time']);
      Duration contactTimeDuration = clockOutTime.difference(clockInTime);
      String contactTime = contactTimeDuration.toString();

      // Prepare the data to update the record
      // Mark as unsynced so full offline record can be pushed to server
      Map<String, dynamic> updatedData = {
        'clock_out_time': clockOutData['clock_out_time'],
        'contact_time': contactTime, // Directly use the value of inMinutes
        'synced': 0,
      };

      print('Learner Clock Out Data Updated: $updatedData');
      // Update the clock-out time and contact time in the same record
      await db.update(
        'learner_clocking',
        updatedData,
        where: 'LearnerID = ? AND clock_date = ? AND clock_out_time IS NULL',
        whereArgs: [learnerID, clockDate],
      );

      // Display updated clock-out data in the console
      print('Learner Clock Out Data Updated: $clockOutData');
    } else {
      // If no clock-in data exists, log and handle this scenario
      print('No matching clock-in data found for this learner on this date.');
    }
  }

//getClockOutForDate
  Future<Map<String, dynamic>?> getClockOutForDate(
      String learnerID, String date) async {
    final db = await database;
    final result = await db.query(
      'learner_clocking',
      where: 'LearnerID = ? AND clock_date = ? AND clock_out_time IS NOT NULL',
      whereArgs: [learnerID, date],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> insertSdp(Map<String, dynamic> sdp) async {
    final db = await database;
    return await db.insert('sdp', sdp);
  }

  Future<List<Map<String, dynamic>>> getAllSdps() async {
    final db = await database;
    return await db.query('sdp');
  }

  Future<Map<String, dynamic>?> getSdpById(int id) async {
    final db = await database;
    final result = await db.query(
      'sdp',
      where: 'sdp_id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateSdp(int id, Map<String, dynamic> sdp) async {
    final db = await database;
    return await db.update(
      'sdp',
      sdp,
      where: 'sdp_id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSdp(int id) async {
    final db = await database;
    return await db.delete(
      'sdp',
      where: 'sdp_id = ?',
      whereArgs: [id],
    );
  }

  // start password

  Future<Map<String, dynamic>?> getSdp(String email, String password) async {
    final db = await database;

    // Query the database for a user with the provided email only
    final result = await db.query(
      'sdp',
      where: 'email = ?',
      whereArgs: [email],
    );

    print("sdp Query Result: $result");

    if (result.isNotEmpty) {
      final user = result.first;
      final hashedPassword = user['password'] as String;

      // Verify the password using bcrypt
      if (BCrypt.checkpw(password, hashedPassword)) {
        return user;
      } else {
        print("Password verification failed for SDP user");
        return null;
      }
    } else {
      print("No SDP user found with email: $email");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getFacilitator(
      String email, String password) async {
    final db = await database;

    // Query the database for a facilitator with the provided email only
    final result = await db.query(
      'facilitator',
      where: 'email = ?',
      whereArgs: [email],
    );

    print("Facilitator Query Result: $result");

    if (result.isNotEmpty) {
      final facilitator = result.first;
      final hashedPassword = facilitator['password'] as String;

      // Verify the password using bcrypt
      if (BCrypt.checkpw(password, hashedPassword)) {
        return facilitator;
      } else {
        print("Password verification failed for facilitator");
        return null;
      }
    } else {
      print("No facilitator found with email: $email");
      return null;
    }
  }

// Alternative method if you want to handle both user types in one function
  Future<Map<String, dynamic>?> authenticateUser(
      String email, String password, String userType) async {
    final db = await database;

    final tableName = userType == 'facilitator' ? 'facilitator' : 'sdp';

    final result = await db.query(
      tableName,
      where: 'email = ?',
      whereArgs: [email],
    );

    print("$tableName Query Result: $result");

    if (result.isNotEmpty) {
      final user = result.first;
      final hashedPassword = user['password'] as String;

      // Verify the password using bcrypt
      if (BCrypt.checkpw(password, hashedPassword)) {
        return user;
      } else {
        print("Password verification failed for $tableName user");
        return null;
      }
    } else {
      print("No $tableName user found with email: $email");
      return null;
    }
  }
  //end

  // Future<Map<String, dynamic>?> getSdp(String email, String password) async {
  //   final db = await database; // Assuming 'database' is your SQLite database instance.
  //
  //   // Query the database for a facilitator with the provided email and password.
  //   final result = await db.query(
  //     'sdp',
  //     where: 'email = ? AND password = ?',
  //     whereArgs: [email, password],
  //   );
  //
  //   // Print the result to the console for debugging
  //   print("sdp Query Result: $result");
  //
  //   if (result.isNotEmpty) {
  //     // Return the first match (assuming you expect one or more matches)
  //     return result.first;
  //   } else {
  //     // If no facilitator is found, return null
  //     return null;
  //   }
  // }

  // Insert a new site into the database
  Future<void> insertSite(Map<String, dynamic> siteData) async {
    final db = await database;
    await db.insert(
      'sites',
      siteData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insert or replace bank details for a learner
  Future<void> upsertBankDetails(Map<String, dynamic> bankData) async {
    final db = await database;
    await db.insert(
      'bankdetails',
      bankData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print(
        '[DB_HELPER] Upserted bank details for learner: ${bankData['LearnerID']}');
  }

  // Get all sites from the database
  Future<List<Map<String, dynamic>>> getAllSites() async {
    final db = await database;
    return await db.query('sites');
  }

  // Get a single site by its ID
  Future<Map<String, dynamic>?> getSiteById(int siteID) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'sites',
      where: 'siteID = ?',
      whereArgs: [siteID],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Update a site by its ID
  Future<void> updateSite(int siteID, Map<String, dynamic> updatedData) async {
    final db = await database;
    await db.update(
      'sites',
      updatedData,
      where: 'siteID = ?',
      whereArgs: [siteID],
    );
  }

  // Delete a site by its ID
  Future<void> deleteSite(int siteID) async {
    final db = await database;
    await db.delete(
      'sites',
      where: 'siteID = ?',
      whereArgs: [siteID],
    );
  }

  // Get sites by a specific field, for example, `sdp_id`
  Future<List<Map<String, dynamic>>> getSitesBySdpId(int sdpId) async {
    final db = await database; // Your database reference

    // Query to fetch sites where sdp_id matches the provided sdpId
    final List<Map<String, dynamic>> sites = await db.query(
      'sites', // Assuming your table is called 'sites'
      where: 'sdp_id = ?', // Filter by sdp_id
      whereArgs: [sdpId], // Pass the sdpId value
    );

    return sites;
  }

  // Save SDP sites for offline use
  Future<void> saveSdpSitesForOffline(
      String sdpId, List<Map<String, dynamic>> sites) async {
    final db = await database;

    // Parse sdpId to int if needed
    final sdpIdInt = int.tryParse(sdpId);

    // Use a batch operation for better performance
    final batch = db.batch();

    for (var site in sites) {
      // Map and convert the API data to match the sites table schema
      final mappedSite = <String, dynamic>{
        'siteID': _parseToInt(site['siteID']),
        'siteName': site['siteName']?.toString(),
        'beneficiaries': site['beneficiaries']?.toString(),
        'latitude': site['coordinates']?.toString().split(',')[0].trim(),
        'longitude': site['coordinates']?.toString().split(',')[1].trim(),
        'sdp_id': sdpIdInt ?? _parseToInt(site['sdp_id']),
        'Province': site['province']?.toString(),
        'District': site['District']?.toString(),
        'Municipality': site['Municipality']?.toString(),
        'Category': site['category']?.toString(),
        'project_id': _parseToInt(site['project_id']),
        'Project_pathway': site['project_pathway']?.toString(),
        'qualification_id': site['qualification_id']?.toString(),
        'first_name': site['first_name']?.toString(),
        'last_name': site['last_name']?.toString(),
        'cell_phone': site['cell_phone']?.toString(),
        'email': site['email']?.toString(),
      };

      // Remove null values
      mappedSite.removeWhere((key, value) => value == null);

      batch.insert(
        'sites',
        mappedSite,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // Helper method to safely parse integers
  int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  // Helper method to safely parse coordinates
  String? _parseCoordinate(dynamic coordinates, int index) {
    if (coordinates == null) return null;
    final coordStr = coordinates.toString();
    if (!coordStr.contains(',')) return null;
    final parts = coordStr.split(',');
    if (parts.length <= index) return null;
    return parts[index].trim();
  }

  // Fetch class data by siteID from SQLite
  Future<List<Map<String, dynamic>>> fetchClassDataBySiteID(
      String siteID) async {
    final db = await database;
    return await db.query(
      'classData',
      where: 'siteID = ?',
      whereArgs: [siteID], // Filter by siteID
    );
  }

  // Insert class data into SQLite
  Future<void> insertClassData(List<dynamic> classData) async {
    final db = await database;

    for (var item in classData) {
      await db.insert(
        'classData',
        {
          'siteID': item['siteID'], // Insert siteID
          'classID': item['classID'],
          'className': item['className'],
          'learnerCount': item['learnerCount'],
          'learnersClockedIn': item['learnersClockedIn'],
          'learnersClockedOut': item['learnersClockedOut'],
          'learnersAbsent': item['learnersAbsent'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // Get sites based on a specific project_id
  Future<List<Map<String, dynamic>>> getSitesByProjectId(int projectId) async {
    final db = await database;
    return await db.query(
      'sites',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
  }

  // Clear the sites table (for example, when syncing or resetting)
  Future<void> clearSites() async {
    final db = await database;
    await db.delete('sites');
  }

  // Retrieve all sites data
  // Method to get sites where sdp_id exists (is not null)
  Future<List<Map<String, dynamic>>> getSites() async {
    final db =
        await database; // Assuming database is a reference to your SQLite database
    return await db.query(
      'sites',
      where: 'sdp_id IS NOT NULL', // Filter sites where sdp_id is not null
    );
  }

  Future<List<Map<String, dynamic>>> getClassData(String classID) async {
    final db = await database;
    return await db.query('class', where: 'siteID = ?', whereArgs: [classID]);
  }

  Future<List<Map<String, dynamic>>> getLearnersForClass(int siteID) async {
    final db = await database;
    return await db.query('class', where: 'classID = ?', whereArgs: [siteID]);
  }

  // Future<List<dynamic>> getLearnersForClass(String classID) async {
  // final db = await database;
  // var result = await db.query('class', where: 'siteID = ?', whereArgs: [classID]);
  // return result.isNotEmpty ? result : [];
  // }
// 1. Insert a new class
  Future<int> insertClass(Map<String, dynamic> classData) async {
    final db = await database;
    return await db.insert(_unsyncedTable, classData);
  }

  // 2. Get all classes
  Future<List<Map<String, dynamic>>> getAllClasses() async {
    final db = await database;
    return await db.query(_unsyncedTable);
  }

  // 3. Get a specific class by classID
  Future<Map<String, dynamic>?> getClassById(int classID) async {
    final db = await database;
    var result = await db.query(
      _unsyncedTable,
      where: 'classID = ?',
      whereArgs: [classID],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // 4. Update class details
  Future<int> updateClass(int classID, Map<String, dynamic> updatedData) async {
    final db = await database;
    return await db.update(
      _unsyncedTable,
      updatedData,
      where: 'classID = ?',
      whereArgs: [classID],
    );
  }

  // 5. Delete a class by classID
  Future<int> deleteClass(int classID) async {
    final db = await database;
    return await db.delete(
      _unsyncedTable,
      where: 'classID = ?',
      whereArgs: [classID],
    );
  }

  Future<Map<String, dynamic>?> fetchLearnerByID(String learnerID) async {
    final db = await database; // Assuming you have your database instance here
    final result = await db.query(
      'learnerdetails',
      where: 'LearnerID = ?',
      whereArgs: [learnerID],
    );

    return result.isNotEmpty
        ? Map<String, dynamic>.from(result.first) // Create mutable copy
        : null; // Return the first result or null
  }

  // Method to save signature locally if offline
  /// Save the signature locally in the `learnerdetails` table

  Future<void> saveSignatureLocally(
      String learnerID, String signaturePath, String fieldName) async {
    try {
      final db = await database;
      await db.update(
        'learnerdetails',
        {fieldName: signaturePath, 'synced': 0},
        where: 'LearnerID = ?',
        whereArgs: [learnerID],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('$fieldName saved locally for learner ID: $learnerID');
    } catch (e) {
      print('Error saving $fieldName locally: $e');
    }
  }

  Future<void> saveInitialsLocally(
      String learnerID, String initials, String fieldName) async {
    try {
      final db = await database;
      await db.update(
        'learnerdetails',
        {fieldName: initials, 'synced': 0},
        where: 'LearnerID = ?',
        whereArgs: [learnerID],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('$fieldName saved locally for learner ID: $learnerID');
    } catch (e) {
      print('Error saving $fieldName locally: $e');
    }
  }

  Future<void> saveImageLocally(String learnerID, String imagePath) async {
    try {
      final db = await database;
      await db.update(
        'learnerdetails',
        {'profile_image': imagePath, 'synced': 0},
        where: 'LearnerID = ?',
        whereArgs: [learnerID],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('Image path saved locally for learner ID: $learnerID');
    } catch (e) {
      print('Error saving image locally: $e');
    }
  }

  Future<void> saveLearnerDocumentToDatabase(
      String learnerID,
      String documentName,
      String documentPath,
      String status,
      String uploadDate) async {
    try {
      final db = await database;
      await db.insert(
        'learner_document',
        {
          'learner_id': learnerID,
          'documentName': documentName,
          'learner_document': documentPath,
          'status': status,
          'upload_date': uploadDate,
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('Document saved to database: $documentName');
    } catch (e) {
      print('Error saving document to database: $e');
    }
  }

  /// end of signature and initials
  /// Update the learner's profile image in the `learnerdetails` table
  Future<void> updateLearnerProfileImage(
      int learnerID, String imagePath) async {
    final db = await database;

    await db.update(
      'learnerdetails',
      {'profile_image': imagePath},
      where: 'LearnerID = ?',
      whereArgs: [learnerID],
    );

    print('Updated learner $learnerID profile_image with path: $imagePath');
  }

  /// Function to update the image path in the database
  Future<void> updateImagePathInDatabase(
      int learnerID, String imagePath) async {
    final db = await database;

    await db.update(
      'learnerdetails',
      {'profile_image': imagePath},
      where: 'LearnerID = ?',
      whereArgs: [learnerID],
    );

    print('Image path updated in database for learnerID: $learnerID');
  }

  //get data for class

  Future<Map<String, dynamic>> fetchClassDetailsAndAttendance(
      String classID) async {
    try {
      final db = await database;

      // 1. Fetch class data using the classID
      final classData = await db.query(
        'class',
        where: 'classID = ?',
        whereArgs: [classID],
      );

      print('Class Data: $classData'); // Debugging

      if (classData.isEmpty) {
        throw Exception('Class not found');
      }

      // Extract class information
      final classInfo = classData.first;
      final className =
          classInfo['className']; // Assuming the column is named 'className'
      final classMax = classInfo[
          'numberOfLearners']; // Assuming the column is named 'numberOfLearners'
      final siteID =
          classInfo['siteID']; // Assuming the column is named 'siteID'

      // 2. Fetch site name using the siteID from the sites table
      final siteData = await db.query(
        'sites',
        where: 'siteID = ?',
        whereArgs: [siteID],
      );

      print('Site Data: $siteData'); // Debugging

      if (siteData.isEmpty) {
        throw Exception('Site not found');
      }

      final siteInfo = siteData.first;
      final siteName =
          siteInfo['siteName']; // Assuming the column is named 'siteName'

      // 3. Fetch facilitator data using the classID
      final facilitatorData = await db.query(
        'facilitator',
        where: 'classID = ?',
        whereArgs: [classID],
      );

      print('Facilitator Data: $facilitatorData'); // Debugging

      if (facilitatorData.isEmpty) {
        throw Exception('Facilitator not found');
      }

      final facilitatorInfo = facilitatorData.first;
      final facilitatorName =
          '${facilitatorInfo['firstName']} ${facilitatorInfo['lastName']}';

      // 4. Get total learners for the class
      final int totalLearners = await _getTotalLearners(classID);

      // 5. Get total attendance for the class
      final int attendanceData = await _getAttendance(
          classID, DateFormat('yyyy-MM-dd').format(DateTime.now()));
      print('total atendance to day is : $attendanceData');

      // 6. Return the combined data in a Map
      return {
        'class_name': className,
        'facilitator_name': facilitatorName,
        'class_max': classMax,
        'site_name': siteName,
        'total_learners': totalLearners,
        'total_attendance': attendanceData,
        'total_absent': totalLearners - attendanceData,
        'site Name': siteName,
      };
    } catch (e) {
      print('Error fetching class data: $e'); // Debugging error
      throw Exception('Failed to load class data: $e');
    }
  }

// Helper methods to get total learners and attendance count

  Future<int> _getTotalLearners(String classID) async {
    final db = await database;
    final learnerData = await db
        .query('learnerdetails', where: 'classID = ?', whereArgs: [classID]);
    return learnerData.length;
  }

  //get attendance data
  Future<int> _getAttendance(String classID, String clockDate) async {
    try {
      final db = await database;

      // Fetch learner IDs linked to the classID
      final learnerIDsData = await db.query(
        'learnerdetails',
        columns: ['LearnerID'],
        where: 'classID = ?',
        whereArgs: [classID],
      );

      if (learnerIDsData.isEmpty) {
        print('No learners found for classID: $classID');
        return 0; // No learners linked to the class
      }

      // Extract learner IDs into a list, ensuring correct type
      final learnerIDs = learnerIDsData
          .map((row) =>
              row['LearnerID'].toString()) // Convert to String explicitly
          .toList();

      if (learnerIDs.isEmpty) {
        print('No valid learner IDs found for classID: $classID');
        return 0;
      }

      print('Learner IDs for classID $classID: $learnerIDs'); // Debugging

      // Count attendance for learners with clock_in_time on the given day
      // Changed from contact_time to clock_in_time to properly count clocked-in learners
      final attendanceData = await db.rawQuery(
        '''
      SELECT COUNT(DISTINCT LearnerID) as count
      FROM learner_clocking
      WHERE LearnerID IN (${learnerIDs.map((_) => '?').join(', ')})
      AND clock_in_time IS NOT NULL
      AND clock_date = ?
      ''',
        [...learnerIDs, clockDate], // Add clockDate to the parameters
      );

      print(
          '[ATTENDANCE] Counting attendance for classID $classID on date $clockDate: ${attendanceData.first['count']} learners');

      if (attendanceData.isEmpty || attendanceData.first['count'] == null) {
        print(
            'No attendance records found for classID: $classID on date: $clockDate');
        return 0;
      }

      // Safely parse the count
      final attendanceCount =
          int.tryParse(attendanceData.first['count'].toString()) ?? 0;

      print(
          'Total attendance for classID $classID on date $clockDate: $attendanceCount');
      return attendanceCount;
    } catch (e) {
      print('Error fetching attendance data: $e');
      return 0; // Return 0 on error
    }
  }

  Future<void> insertLearningpathway(
      Map<String, dynamic> learningpathwayData) async {
    final db = await database;
    await db.insert(
      'learningpathway',
      learningpathwayData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertLearnerClocking(Map<String, dynamic> clockingData) async {
    final db = await database;
    await db.insert(
      'learner_clocking',
      clockingData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertPathway_selection(
      Map<String, dynamic> pathwaySelectiondata) async {
    final db = await database;
    await db.insert(
      'pathway_selection',
      pathwaySelectiondata,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertQualification(
      Map<String, dynamic> qualificationData) async {
    final db = await database;
    await db.insert(
      'qualification',
      qualificationData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertQualification_selection(
      Map<String, dynamic> qualificationSelectiondata) async {
    final db = await database;
    await db.insert(
      'qualification_selection',
      qualificationSelectiondata,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertQualification_pathway(
      Map<String, dynamic> qualificationPathwaydata) async {
    final db = await database;
    await db.insert(
      'qualification_pathway',
      qualificationPathwaydata,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertQualificationunitstandard(
      Map<String, dynamic> qualificationunitstandardData) async {
    final db = await database;
    await db.insert(
      'qualificationunitstandard',
      qualificationunitstandardData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertUnitstandard(Map<String, dynamic> unitstandardData) async {
    final db = await database;
    await db.insert(
      'unitstandard',
      unitstandardData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertUnit_standard_selection(
      Map<String, dynamic> unitStandardSelectiondata) async {
    final db = await database;
    await db.insert(
      'unit_standard_selection',
      unitStandardSelectiondata,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertAssessments(Map<String, dynamic> assessmentsData) async {
    final db = await database;
    await db.insert(
      'assessments',
      assessmentsData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertPoe(Map<String, dynamic> poeData) async {
    try {
      final db = await database;
      await db.insert(
        'poe',
        poeData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print("Data inserted successfully: $poeData");
    } catch (e) {
      print("Error inserting data into poe: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getLearnerData(int learnerID) async {
    final db = await database;

    // Fetch raw data including the raw Project_pathway JSON string
    var result = await db.rawQuery('''
    SELECT 
      ld.classID, 
      s.project_id,
      pr.Project_pathway,
      a.unit_standard_id,
      a.assessment_type,
      a.question_type,
      a.question_number,
      a.specific_outcome,
      a.assessment_criteria,
      a.exercise,
      a.marks
    FROM learnerdetails ld
    LEFT JOIN class c ON ld.classID = c.classID
    LEFT JOIN sites s ON c.siteID = s.siteID
    LEFT JOIN project pr ON s.project_id = pr.project_id
    LEFT JOIN assessments a ON a.project_id = pr.project_id 
      AND a.unit_standard_id IS NOT NULL 
      AND a.unit_standard_id != ''
    WHERE ld.learnerID  = ?;
  ''', [learnerID]);

    if (result.isEmpty) {
      print('No data found for learnerID: $learnerID');
      return [];
    }

    // Process data from all rows to handle multiple classes/projects if they exist
    List<Map<String, dynamic>> finalResult = [];
    Map<String, List<Map<String, dynamic>>> unitStandardAssessments = {};
    List<dynamic> unitStandardsList = [];
    Map<String, String> allowedUnitStandardNames = {};

    // Track unique projects to avoid redundant parsing
    Set<String> processedProjects = {};

    for (var row in result) {
      final projectId = row['project_id']?.toString() ?? 'Unknown';
      final rawPathwayJson = row['Project_pathway'] as String? ?? '[]';

      if (!processedProjects.contains(projectId)) {
        processedProjects.add(projectId);

        try {
          final pathwayData = jsonDecode(rawPathwayJson);
          if (pathwayData is List) {
            for (var pathway in pathwayData) {
              final currentPathwayName =
                  pathway['name']?.toString() ?? 'Unknown Pathway';

              if (pathway['qual_types'] is List) {
                for (var qualType in pathway['qual_types']) {
                  if (qualType['qualification'] != null) {
                    final qual = qualType['qualification'];
                    final currentQualName =
                        qual['name']?.toString() ?? 'Unknown Qualification';

                    if (qual['unitStandards'] is List) {
                      for (var us in qual['unitStandards']) {
                        final id = us['id']?.toString().trim();
                        if (id != null) {
                          allowedUnitStandardNames[id] =
                              us['name']?.toString() ?? 'Unknown Unit Standard';

                          bool alreadyExists = unitStandardsList.any(
                              (existing) =>
                                  existing['id']?.toString().trim() == id);

                          if (!alreadyExists) {
                            unitStandardsList.add({
                              'id': id,
                              'name': us['name'],
                              'pathway_name': currentPathwayName,
                              'qualification_name': currentQualName,
                              'classID': row['classID'],
                              'project_id': row['project_id'],
                            });
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          print(
              'Error parsing Project_pathway JSON for project $projectId: $e');
        }
      }

      // Group assessments by unit standard ID
      final usId = row['unit_standard_id']?.toString().trim();
      if (usId != null && allowedUnitStandardNames.containsKey(usId)) {
        final type = row['assessment_type']?.toString().toLowerCase() ?? '';
        final qType = row['question_type']?.toString() ?? 'Knowledge';

        // Determine bucket
        String bucket = type;
        if (qType == 'Practical') bucket = 'logbook';

        if (!unitStandardAssessments.containsKey(usId)) {
          unitStandardAssessments[usId] = [];
        }

        // Deduplicate assessments
        bool isDuplicate = unitStandardAssessments[usId]!.any((a) =>
            a['question_number'] == row['question_number'] &&
            a['exercise'] == row['exercise'] &&
            a['assessment_type'] == bucket);

        if (!isDuplicate) {
          unitStandardAssessments[usId]!.add({
            'assessment_type': bucket,
            'question_number': row['question_number']?.toString() ?? 'N/A',
            'specific_outcome': row['specific_outcome']?.toString() ?? '',
            'assessment_criteria': row['assessment_criteria']?.toString() ?? '',
            'exercise': row['exercise']?.toString() ?? 'N/A',
            'marks': row['marks']?.toString() ?? '',
            'question_type': qType,
          });
        }
      }
    }

    // Build the final result list using the allowed unit standards list
    for (var us in unitStandardsList) {
      final usId = us['id']?.toString().trim() ?? '';
      final usRawName =
          us['name']?.toString().trim() ?? 'Unknown Unit Standard';

      // Aggressively remove ID from the start if it exists (e.g., "259604 - ...")
      final idPattern = RegExp('^' + RegExp.escape(usId) + r'[\s:\-–—]*',
          caseSensitive: false);
      final usCleanName = usRawName.replaceFirst(idPattern, '');
      final fullUsName = "$usId - $usCleanName";

      final assessments = unitStandardAssessments[usId] ?? [];

      finalResult.add({
        'classID': us['classID'],
        'project_id': us['project_id'],
        'pathway_name': us['pathway_name'],
        'qualification_name': us['qualification_name'],
        'unit_standards_list': unitStandardsList,
        'unit_standard_id': usId,
        'unit_standard_name': fullUsName,
        'assessments': {
          'formative': assessments
              .where((a) => a['assessment_type'] == 'formative')
              .toList(),
          'summative': assessments
              .where((a) => a['assessment_type'] == 'summative')
              .toList(),
          'logbook': assessments
              .where((a) => a['assessment_type'] == 'logbook')
              .toList(),
          'formativeremedial': assessments
              .where((a) => a['assessment_type'] == 'formativeremedial')
              .toList(),
          'summativeremedial': assessments
              .where((a) => a['assessment_type'] == 'summativeremedial')
              .toList(),
        },
      });
    }

    return finalResult;
  }

  Future<void> saveUploadToLocalPoe(
      int learnerID, String type, String exercise, String filePath,
      {String? unitStandard, int synced = 0}) async {
    try {
      final db = await database;

      // Remove unitStandard handling (we don't use it anymore)
      String uniqueExercise = exercise;

      // Check if record already exists
      final existing = await db.query(
        'poe',
        where: 'learnerID = ? AND type = ? AND exercise = ?',
        whereArgs: [
          learnerID.toString(),
          type,
          uniqueExercise,
        ],
      );

      if (existing.isNotEmpty) {
        // Update existing record
        await db.update(
          'poe',
          {
            'filePath': filePath,
            'submitted_at': DateTime.now().toIso8601String(),
            'synced': synced,
          },
          where: 'learnerID = ? AND type = ? AND exercise = ?',
          whereArgs: [
            learnerID.toString(),
            type,
            uniqueExercise,
          ],
        );
        print(
            "POE upload updated (synced=$synced): learnerID=$learnerID, type=$type, exercise=$uniqueExercise, filePath=$filePath");
      } else {
        // Insert new record
        await db.insert(
          'poe',
          {
            'learnerID': learnerID.toString(),
            'type': type,
            'exercise': uniqueExercise,
            'filePath': filePath,
            'submitted_at': DateTime.now().toIso8601String(),
            'synced': synced,
          },
        );
        print(
            "POE upload inserted (synced=$synced): learnerID=$learnerID, type=$type, exercise=$uniqueExercise, filePath=$filePath");
      }
    } catch (e, stackTrace) {
      print("Error saving POE upload: $e\nStackTrace: $stackTrace");
      rethrow;
    }
  }

  Future<void> saveManualMarkToLocalPoe(
      int learnerID, String type, String exercise, String filePath,
      {String? unitStandard}) async {
    try {
      final db = await database;

      String uniqueExercise = exercise;

      // Check if record already exists
      final existing = await db.query(
        'poe',
        where: 'learnerID = ? AND type = ? AND exercise = ?',
        whereArgs: [
          learnerID.toString(),
          type,
          uniqueExercise,
        ],
      );

      if (existing.isNotEmpty) {
        // Update existing record
        await db.update(
          'poe',
          {
            'filePath': filePath,
            'submitted_at': DateTime.now().toIso8601String(),
            'synced':
                0, // Set to 0 for manual entries so they can be updated later by a scan
          },
          where: 'learnerID = ? AND type = ? AND exercise = ?',
          whereArgs: [
            learnerID.toString(),
            type,
            uniqueExercise,
          ],
        );
        print(
            "Manual POE entry updated: learnerID=$learnerID, type=$type, exercise=$uniqueExercise, filePath=$filePath");
      } else {
        // Insert new record
        await db.insert(
          'poe',
          {
            'learnerID': learnerID.toString(),
            'type': type,
            'exercise': uniqueExercise,
            'filePath': filePath,
            'submitted_at': DateTime.now().toIso8601String(),
            'synced':
                0, // Set to 0 for manual entries so they can be updated later by a scan
          },
        );
        print(
            "Manual POE entry inserted: learnerID=$learnerID, type=$type, exercise=$uniqueExercise, filePath=$filePath");
      }
    } catch (e, stackTrace) {
      print("Error saving manual POE entry: $e\nStackTrace: $stackTrace");
      rethrow;
    }
  }

  Future<Map<String, bool>> getLocalUploadStatus(String learnerID) async {
    try {
      final db = await database;
      final uploads = await db.query(
        'poe',
        where: 'learnerID = ?',
        whereArgs: [learnerID],
      );
      final uploadStatus = <String, bool>{};

      for (var upload in uploads) {
        final type = upload['type']?.toString() ?? '';
        final exercise = upload['exercise']?.toString() ?? '';

        // Generate old-style keys (type-exercise-learnerID) for maximum compatibility
        final oldKeyRaw = '$type-$exercise-$learnerID';
        uploadStatus[oldKeyRaw] = true;

        String normalizedTypeOld = type;
        if (type.toLowerCase() == 'formative') normalizedTypeOld = 'Formative';
        if (type.toLowerCase() == 'summative') normalizedTypeOld = 'Summative';
        if (type.toLowerCase() == 'logbook') normalizedTypeOld = 'LogBook';
        if (type.toLowerCase() == 'formativeremedial')
          normalizedTypeOld = 'FormativeRemedial';
        if (type.toLowerCase() == 'summativeremedial')
          normalizedTypeOld = 'SummativeRemedial';

        final oldKeyNorm = '$normalizedTypeOld-$exercise-$learnerID';
        uploadStatus[oldKeyNorm] = true;
      }

      return uploadStatus;
    } catch (e) {
      print('Error getting local upload status: $e');
      return {};
    }
  }

  // Helper function to get all questions from API
  Future<List<Map<String, dynamic>>> _getAllQuestionsFromAPI(
      String learnerID) async {
    try {
      final questions = <Map<String, dynamic>>[];

      // Make API call to get POE data
      final url = AppConfig.poeUrl;
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'learnerID': learnerID},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['pathways'] != null) {
          // Extract all questions from all unit standards
          for (var pathway in data['pathways'].values) {
            if (pathway['qualifications'] != null) {
              for (var qualification in pathway['qualifications'].values) {
                if (qualification['unitstandards'] != null) {
                  for (var unitStandardName
                      in qualification['unitstandards'].keys) {
                    final unitStandard =
                        qualification['unitstandards'][unitStandardName];

                    // Extract unit standard ID from name
                    final unitIdMatch =
                        RegExp(r'^(\d{4,10})').firstMatch(unitStandardName);
                    final unitId = unitIdMatch?.group(1) ?? '';

                    // Add formative questions
                    if (unitStandard['formative'] != null) {
                      for (var formative in unitStandard['formative']) {
                        questions.add({
                          'type': 'Formative',
                          'exercise': formative['exercise'],
                          'unitStandardId': unitId,
                          'unitStandardName': unitStandardName,
                        });
                      }
                    }

                    // Add summative questions
                    if (unitStandard['summative'] != null) {
                      for (var summative in unitStandard['summative']) {
                        questions.add({
                          'type': 'Summative',
                          'exercise': summative['exercise'],
                          'unitStandardId': unitId,
                          'unitStandardName': unitStandardName,
                        });
                      }
                    }

                    // Add logbook questions
                    if (unitStandard['logbook'] != null) {
                      for (var logbook in unitStandard['logbook']) {
                        questions.add({
                          'type': 'LogBook',
                          'exercise': logbook['exercise'],
                          'unitStandardId': unitId,
                          'unitStandardName': unitStandardName,
                        });
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      print(
          'Retrieved ${questions.length} questions from API for learner $learnerID');
      return questions;
    } catch (e) {
      print('Error getting questions from API: $e');
      return [];
    }
  }

  // Helper function to get full unit standard name from ID
  String? _getFullUnitStandardName(String unitId) {
    // Check if the ID exists in our known list
    final unitStandardNames = {
      '9964': '9964 - Apply health and safety to a work area',
      '9986': '9986 - Apply quality principles on a construction site',
      '9966': '9966 - Establish and prepare a work area',
      '14336': '14336 - Maintain records on a constuction site',
      '9965': '9965 - Render basic first aid',
      '9962': '9962 - Calculate construction quantities to develop a work plan',
      '9968': '9968 - Procure materials, tools and equipment',
      '14580':
          '14580 - Read and interpret construction drawings and specifications',
      '14555': '14555 - Conduct a bituminous seal operation',
      '13958': '13958 - Maintain and repair bituminous road surfaces',
      '261661': '261661 - Develop construction work plans',
      '261664':
          '261664 - Erect, use and dismantle access equipment for construction work',
      '259604':
          '259604 - Verify compliance to safety, health and environmental requirements in the workplace',
      '14672':
          '14672 - Describe the composition, roleplayers and the role of the construction industry in the South African economy',
    };

    if (unitStandardNames.containsKey(unitId)) {
      return unitStandardNames[unitId];
    }

    // DYNAMIC FALLBACK: If ID is not in hardcoded list, we'll return a placeholder
    // that the UI can still use to match against the pathway JSON.
    return "$unitId - Unknown Unit Standard";
  }

  // Helper function to extract unit standard mapping from exercises
  Future<Map<String, String>> _extractUnitStandardFromExercise() async {
    // This could be enhanced to build a mapping from exercise content to unit standards
    // For now, return empty map as the regex matching above should handle most cases
    return {};
  }

  Future<String?> getExistingDocumentPath(
      int learnerID, String type, String unitStandard) async {
    try {
      // First, try to get document path from server if connected (specific to unit standard)
      String? serverDocumentPath =
          await _getServerDocumentPath(learnerID, type, unitStandard);
      if (serverDocumentPath != null) {
        print(
            "Found existing document from server for $type in unit $unitStandard: $serverDocumentPath");
        return serverDocumentPath;
      }

      // If no server document, check local database with improved criteria
      final db = await database;

      // Try to find the most recent document for this learner and type
      // Note: POE table might not have unit standard field, so we search by type and time
      final uploads = await db.rawQuery('''
        SELECT filePath, exercise, submitted_at FROM poe 
        WHERE learnerID = ? AND type = ? AND synced = 1
        AND filePath NOT LIKE 'MANUALLY_MARKED%'
        ORDER BY submitted_at DESC 
        LIMIT 5
      ''', [learnerID.toString(), type]);

      print(
          "Found ${uploads.length} potential documents in local DB for $type");

      for (var upload in uploads) {
        final filePath = upload['filePath']?.toString();
        final exercise = upload['exercise']?.toString();
        final submittedAt = upload['submitted_at']?.toString();

        // Check if the file actually exists
        if (filePath != null &&
            filePath.isNotEmpty &&
            !filePath.startsWith('MANUALLY_MARKED') &&
            File(filePath).existsSync()) {
          print(
              "Found existing document from local DB for $type (exercise: $exercise, submitted: $submittedAt): $filePath");
          return filePath;
        }
      }

      print(
          "No existing document found for learnerID=$learnerID, type=$type, unitStandard=$unitStandard");
      return null;
    } catch (e, stackTrace) {
      print("Error finding existing document: $e\nStackTrace: $stackTrace");
      return null;
    }
  }

  Future<String?> _getServerDocumentPath(
      int learnerID, String type, String unitStandard) async {
    try {
      // Check connectivity first
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print("No internet connection, skipping server check");
        return null;
      }

      // Use existing poe.php endpoint to get POE data with document paths
      final url = Uri.parse(AppConfig.poeUrl);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'learnerID': learnerID.toString()},
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Server request timed out');
      });

      print(
          'Server POE request for document path: learnerID=$learnerID, type=$type, unitStandard=$unitStandard, statusCode=${response.statusCode}');

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);

        if (decodedResponse is Map<String, dynamic>) {
          // Look through all pathways/qualifications/unitstandards for POE data
          for (var pathwayEntry in decodedResponse.entries) {
            final pathwayData = pathwayEntry.value;
            if (pathwayData['qualifications'] != null) {
              for (var qualEntry
                  in (pathwayData['qualifications'] as Map).entries) {
                final qualData = qualEntry.value;
                if (qualData['unitstandards'] != null) {
                  for (var unitEntry
                      in (qualData['unitstandards'] as Map).entries) {
                    final unitStandardName = unitEntry.key.toString();
                    final unitData = unitEntry.value;

                    // Only check the specific unit standard we're working with
                    if (unitStandardName == unitStandard) {
                      print(
                          'Found matching unit standard on server: $unitStandardName');

                      // Check the specific type (formative/summative) for uploaded documents
                      List<dynamic>? exercises;
                      if (type.toLowerCase() == 'formative' &&
                          unitData['formative'] != null) {
                        exercises = unitData['formative'] as List<dynamic>;
                      } else if (type.toLowerCase() == 'summative' &&
                          unitData['summative'] != null) {
                        exercises = unitData['summative'] as List<dynamic>;
                      }

                      if (exercises != null) {
                        for (var exercise in exercises) {
                          // Look for uploaded POE data with file paths
                          if (exercise['uploaded_poe'] != null) {
                            final uploadedPoe =
                                exercise['uploaded_poe'] as List<dynamic>;
                            for (var poeItem in uploadedPoe) {
                              final filePath = poeItem['filePath']?.toString();
                              if (filePath != null &&
                                  filePath.isNotEmpty &&
                                  !filePath.startsWith('MANUALLY_MARKED')) {
                                print(
                                    'Server returned document path from POE data for unit $unitStandard: $filePath');
                                return filePath;
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      } else {
        print('Server error: ${response.statusCode}');
      }

      print(
          'No document path found on server for learnerID=$learnerID, type=$type, unitStandard=$unitStandard');
      return null;
    } catch (e, stackTrace) {
      print(
          "Error getting document path from server: $e\nStackTrace: $stackTrace");
      return null;
    }
  }

  Future<void> saveLogBookText(String learnerID, String type, String exercise,
      String logbookText) async {
    try {
      final db = await database;
      final count = await db.query(
        'poe',
        where: 'learnerID = ? AND type = ? AND exercise = ?',
        whereArgs: [learnerID, type, exercise],
      );

      if (count.isNotEmpty) {
        await db.update(
          'poe',
          {
            'logbook_text': logbookText,
            'submitted_at': DateTime.now().toIso8601String(),
          },
          where: 'learnerID = ? AND type = ? AND exercise = ?',
          whereArgs: [learnerID, type, exercise],
        );
      } else {
        await db.insert(
          'poe',
          {
            'learnerID': learnerID,
            'type': type,
            'exercise': exercise,
            'logbook_text': logbookText,
            'submitted_at': DateTime.now().toIso8601String(),
            'synced': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      print(
          "LogBook text saved: learnerID=$learnerID, type=$type, exercise=$exercise, logbook_text=$logbookText");
    } catch (e, stackTrace) {
      print("Error saving LogBook text: $e\nStackTrace: $stackTrace");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUnsyncedPOE(int learnerID) async {
    try {
      final db = await database;
      final unsyncedRecords = await db.query(
        'poe',
        where: 'learnerID = ? AND synced = 0',
        whereArgs: [learnerID.toString()],
        orderBy: 'submitted_at ASC',
      );
      print(
          "[POE_SYNC] Found ${unsyncedRecords.length} unsynced POE records for learnerID=$learnerID");
      return unsyncedRecords;
    } catch (e, stackTrace) {
      print("Error fetching unsynced POE: $e\nStackTrace: $stackTrace");
      return [];
    }
  }

  Future<void> markPOEAsSynced(int id) async {
    try {
      final db = await database;
      await db.update(
        'poe',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      print("[POE_SYNC] Marked POE record as synced: id=$id");
    } catch (e, stackTrace) {
      print("Error marking POE as synced: $e\nStackTrace: $stackTrace");
      rethrow;
    }
  }

  // Ensure learner_pathways_cache table exists
  Future<void> _ensureCacheTableExists() async {
    try {
      final db = await database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS learner_pathways_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          learnerID INTEGER UNIQUE NOT NULL,
          pathways_json TEXT NOT NULL,
          cached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      print("[OFFLINE_CACHE] Cache table verified/created");
    } catch (e) {
      print("[OFFLINE_CACHE] Error ensuring cache table exists: $e");
    }
  }

  // Save learner pathways data to cache for offline access
  Future<void> saveLearnerPathwaysCache(
      int learnerID, Map<String, dynamic> pathways) async {
    try {
      await _ensureCacheTableExists();
      final db = await database;
      final pathwaysJson = jsonEncode(pathways);

      await db.insert(
        'learner_pathways_cache',
        {
          'learnerID': learnerID,
          'pathways_json': pathwaysJson,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print("[OFFLINE_CACHE] Saved pathways cache for learnerID=$learnerID");
    } catch (e, stackTrace) {
      print("Error saving learner pathways cache: $e\nStackTrace: $stackTrace");
      rethrow;
    }
  }

  // Get cached learner pathways data for offline access
  Future<Map<String, dynamic>?> getLearnerPathwaysCache(int learnerID) async {
    try {
      await _ensureCacheTableExists();
      final db = await database;
      final results = await db.query(
        'learner_pathways_cache',
        where: 'learnerID = ?',
        whereArgs: [learnerID],
      );

      if (results.isEmpty) {
        print(
            "[OFFLINE_CACHE] No cached pathways found for learnerID=$learnerID");
        return null;
      }

      final pathwaysJson = results.first['pathways_json'] as String;
      final pathways = jsonDecode(pathwaysJson) as Map<String, dynamic>;

      print(
          "[OFFLINE_CACHE] Retrieved cached pathways for learnerID=$learnerID");
      return pathways;
    } catch (e, stackTrace) {
      print(
          "Error getting learner pathways cache: $e\nStackTrace: $stackTrace");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getLearnerss(
      String classID, String selectedItem) async {
    final db = await database;

    // Start building the query
    String query = '''
  
   SELECT 
    ld.LearnerID,
    ld.IDNumber,
    ld.PhoneNumber,
    CONCAT(ld.Name, ' ', ld.Surname) AS full_name,
    ld.IDNumber AS LearnerIDNumber,
    p.Project_name,
    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.project_pathway, '\$[0].name')), 'Unknown') AS pathway_name,
    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.project_pathway, '\$[0].qual_types[0].qualification.name')), 'Unknown') AS qualification_name,
    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.project_pathway, '\$[0].qual_types[0].qualification.id')), 'Unknown') AS qualification_id,
    CONCAT(f.firstName, ' ', f.lastName) AS FacilitatorFullName,
    c.className AS ClassName
FROM learnerdetails ld
JOIN class c ON ld.classID = c.classID
JOIN sites site ON c.siteID = site.siteID
JOIN project p ON site.project_id = p.project_id
LEFT JOIN sdp s ON p.sdp_name = s.sdp_name
JOIN facilitator f ON c.classID = f.classID
JOIN learner_clocking lc ON lc.LearnerID = ld.LearnerID
LEFT JOIN material_receipt_form mr ON mr.student_id_number = ld.IDNumber AND mr.class_name = c.className
WHERE ld.classID = ?
  AND f.role = 'Facilitator'
  AND lc.clock_in_time IS NOT NULL
  AND DATE(lc.clock_date) = CURDATE();
  ''';

    // Add condition for selectedItem if it's not 'Select'
    if (selectedItem != 'Select') {
      query += '''
    AND NOT EXISTS (
      SELECT 1
      FROM material_receipt_form mrf
      WHERE mrf.student_id_number = ld.IDNumber 
        AND mrf.class_name = c.className 
        AND mrf.description = ?
    )
    ''';
    }

    // Execute the query with appropriate parameters
    List<Map<String, dynamic>> result;
    try {
      if (selectedItem == 'Select') {
        result = await db.rawQuery(query, [classID]); // Only bind classID
      } else {
        result = await db.rawQuery(query,
            [classID, selectedItem]); // Bind both classID and selectedItem
      }
      return result;
    } catch (e) {
      print('Error executing query: $e');
      rethrow; // Re-throw the error for further handling if needed
    }
  }

  //get profile for facilitator
  Future<List<Map<String, dynamic>>> getLearnerDetailsByClassID(
      String classID) async {
    final db = await database;

    try {
      final result = await db.rawQuery('''
    SELECT 
    p.Project_name,
    JSON_UNQUOTE(JSON_EXTRACT(p.project_pathway, '\$[0].name')) AS pathway_name,
    JSON_UNQUOTE(JSON_EXTRACT(p.project_pathway, '\$[0].qual_types[0].qualification.name')) AS qualification_name,
    JSON_UNQUOTE(JSON_EXTRACT(p.project_pathway, '\$[0].qual_types[0].qualification.id')) AS qualification_id,
    CONCAT(f.firstName, ' ', f.lastName) AS FacilitatorFullName,
    c.className AS ClassName
FROM learnerdetails ld
JOIN class c ON ld.classID = c.classID
JOIN sites site ON c.siteID = site.siteID
JOIN project p ON site.project_id = p.project_id
LEFT JOIN sdp s ON p.sdp_name = s.sdp_name
JOIN facilitator f ON c.classID = f.classID
WHERE ld.classID =?
GROUP BY p.project_id, p.Project_name, JSON_EXTRACT(p.project_pathway, '\$[0].name'), 
         JSON_EXTRACT(p.project_pathway, '\$[0].qual_types[0].qualification.name'), 
         JSON_EXTRACT(p.project_pathway, '\$[0].qual_types[0].qualification.id'), 
         f.firstName, f.lastName, c.className;
    ''', [classID]);

      print('Query Result: $result'); // Print the result to see the data

      if (result.isNotEmpty) {
        return result;
      } else {
        print('No data found for classID: $classID');
        return []; // Return an empty list if no data is found
      }
    } catch (e) {
      print('Error executing query: $e');
      return []; // Return an empty list in case of an error
    }
  }

  // Insert material form into the local database
  Future<int> insertMaterialForm(Map<String, dynamic> materialForm) async {
    final db =
        await database; // Open the database (replace `database` with your DB object)
    return await db.insert(
      'material_forms',
      materialForm,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Fetch all unsynced material forms.
  Future<List<Map<String, dynamic>>> fetchUnsyncedMaterialForms() async {
    final db = await database;
    final result = await db.query(
      'material_forms',
      where: 'is_synced = ?',
      whereArgs: [0], // Only unsynced records
    );
    print('Unsynced records: $result'); // Debug print
    return result;
  }

  // Update the sync status of a material form to synced (is_synced = 1).
  Future<void> updateSyncStatus(int id) async {
    final db = await database;
    await db.update(
      'material_forms',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Insert new record into material_receipt_form
  Future<List<Map<String, dynamic>>> fetchAllMaterialForms() async {
    final db = await database;
    return await db.query('material_forms');
  }

  // Insert new record into material_receipt_form
  Future<int> insertMaterialReceiptForm(Map<String, dynamic> data) async {
    final db = await database; // Get the database instance
    return await db.insert('material_receipt_form', data);
  }

  Future<List<Map<String, dynamic>>> query(String sql,
      [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments ?? []);
  }

// Insert a record into the database
  Future<void> insertReceiptForm(Map<String, dynamic> record) async {
    final db = await database;
    await db.insert(
      'material_receipt_form',
      record,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Update synced status
  Future<void> _updateSyncedStatus(List<Map<String, dynamic>> records) async {
    final db = await database;
    for (var record in records) {
      await db.update(
        'material_receipt_form',
        {'synced': 1}, // Mark as synced
        where: 'student_id_number = ?',
        whereArgs: [record['student_id_number'].toString()],
      );
    }
  }

//save
  Future<void> saveLearnerDetailsOffline(
      String classID, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'facilitator',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertProject(Map<String, dynamic> projectData) async {
    final db = await database;
    return await db.insert('project', projectData);
  }

  // Example function to fetch all projects
  Future<List<Map<String, dynamic>>> fetchProjects() async {
    final db = await database;
    return await db.query('project');
  }

  Future<List<Map<String, dynamic>>> getAllDocuments() async {
    final db = await database;
    return await db.query('learner_document');
  }

  Future<List<Map<String, dynamic>>> getDocumentsByLearnerId(
      String learnerId) async {
    final db = await database;
    return await db.query(
      'learner_document',
      where: 'learner_id = ?',
      whereArgs: [learnerId],
    );
  }

  final String tableLearnerDetails = 'learnerdetails'; // Define table name

  Future<int> markAsSynced(String IDNumber) async {
    final db = await database;
    return await db.update(tableLearnerDetails, {'synced': 1},
        where: 'IDNumber = ?', whereArgs: [IDNumber]);
  }

  Future<List<Map<String, dynamic>>> fetchLearnerDocuments(
      String learnerId) async {
    final db = await database;
    return await db.query(
      'learner_document',
      where: 'learner_id = ?',
      whereArgs: [learnerId],
    );
  }

  Future<void> insertLearnerDocument(Map<String, dynamic> document) async {
    final db = await database;
    await db.insert('learner_document', document);
  }

  Future<List<Map<String, dynamic>>> fetchUnsyncedLearnerDocuments() async {
    final db = await database;
    return await db.query(
      'learner_document',
      where: 'synced = ?',
      whereArgs: [0],
    );
  }

  Future<void> updateLearnerDocumentSynced(int documentId, int synced) async {
    final db = await database;
    await db.update(
      'learner_document',
      {'synced': synced},
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
  }

  Future<int> getLastInsertedDocumentId() async {
    final db = await database;
    final result = await db.rawQuery('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  Future<Map<String, dynamic>> getFacilitatorDetailsByClassID(
      String classID) async {
    final db = await database;
    try {
      List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT f.facilitator_id, f.firstName, f.lastName, f.role, f.email, f.classID,
             f.phoneNumber, f.f_IDNumber, f.assessorNo, f.assessorExpiryDate, f.f_signature, f.f_profile, 
             c.className
      FROM facilitator f
      LEFT JOIN class c ON f.classID = c.classID
      WHERE f.classID = ?
    ''', [classID]);

      if (result.isNotEmpty) {
        Map<String, dynamic> facilitator = result.first;
        String firstName = facilitator['firstName']?.toString() ?? 'N/A';
        String lastName = facilitator['lastName']?.toString() ?? 'N/A';
        String fullName = (firstName != 'N/A' || lastName != 'N/A')
            ? '$firstName $lastName'.trim()
            : 'N/A';

        return {
          'facilitator_id': facilitator['facilitator_id']?.toString() ?? 'N/A',
          'firstName': firstName,
          'lastName': lastName,
          'fullName': fullName,
          'role': facilitator['role']?.toString() ?? 'N/A',
          'email': facilitator['email']?.toString() ?? 'N/A',
          'classID': facilitator['classID']?.toString() ?? classID,
          'phoneNumber': facilitator['phoneNumber']?.toString() ?? '',
          'f_IDNumber': facilitator['f_IDNumber']?.toString() ?? '',
          'assessorNo': facilitator['assessorNo']?.toString() ?? '',
          'assessorExpiryDate':
              facilitator['assessorExpiryDate']?.toString() ?? '',
          'className': facilitator['className']?.toString() ?? 'N/A',
          'f_profile': facilitator['f_profile']?.toString(),
          'f_signature': facilitator['f_signature']?.toString(),
        };
      } else {
        return {
          'facilitator_id': 'N/A',
          'firstName': 'N/A',
          'lastName': 'N/A',
          'fullName': 'N/A',
          'role': 'N/A',
          'email': 'N/A',
          'classID': classID,
          'phoneNumber': '',
          'f_IDNumber': '',
          'assessorNo': '',
          'assessorExpiryDate': '',
          'className': 'N/A',
          'f_profile': null,
          'f_signature': null,
        };
      }
    } catch (e) {
      throw Exception('Failed to fetch facilitator data: $e');
    }
  }

  Future<void> saveFacilitatorDetailsOffline(
      String classID, Map<String, dynamic> data) async {
    final db = await database;
    try {
      // First, check if facilitator already exists and get existing templates
      final facilitatorId = data['facilitator_id'];
      Map<String, String?>? existingTemplates;

      if (facilitatorId != null) {
        final existing = await db.query(
          'facilitator',
          where: 'facilitator_id = ?',
          whereArgs: [facilitatorId],
        );

        if (existing.isNotEmpty) {
          // Preserve existing fingerprint templates
          existingTemplates = {
            'zkteco_left_template':
                existing.first['zkteco_left_template'] as String?,
            'zkteco_right_template':
                existing.first['zkteco_right_template'] as String?,
            'futronic_left_template':
                existing.first['futronic_left_template'] as String?,
            'futronic_right_template':
                existing.first['futronic_right_template'] as String?,
          };
          debugPrint(
              '[DB] Preserving existing fingerprint templates for facilitator $facilitatorId');
        }
      }

      // Prepare facilitator data
      final facilitatorData = {
        'classID': classID,
        'firstName': data['firstName'],
        'lastName': data['lastName'],
        'email': data['email'],
        'phoneNumber': data['phoneNumber'] ?? '',
        'f_IDNumber': data['f_IDNumber'] ?? '',
        'assessorNo': data['assessorNo'] ?? '',
        'f_signature': data['f_signature'],
        'f_profile': data['f_profile'],
        'role': data['role'],
      };

      // Add facilitator_id if provided
      if (data['facilitator_id'] != null) {
        facilitatorData['facilitator_id'] = data['facilitator_id'];
      }

      // PRESERVE EXISTING FINGERPRINT TEMPLATES - DON'T OVERWRITE!
      if (existingTemplates != null) {
        if (existingTemplates['zkteco_left_template'] != null &&
            existingTemplates['zkteco_left_template']!.isNotEmpty) {
          facilitatorData['zkteco_left_template'] =
              existingTemplates['zkteco_left_template'];
        }
        if (existingTemplates['zkteco_right_template'] != null &&
            existingTemplates['zkteco_right_template']!.isNotEmpty) {
          facilitatorData['zkteco_right_template'] =
              existingTemplates['zkteco_right_template'];
        }
        if (existingTemplates['futronic_left_template'] != null &&
            existingTemplates['futronic_left_template']!.isNotEmpty) {
          facilitatorData['futronic_left_template'] =
              existingTemplates['futronic_left_template'];
        }
        if (existingTemplates['futronic_right_template'] != null &&
            existingTemplates['futronic_right_template']!.isNotEmpty) {
          facilitatorData['futronic_right_template'] =
              existingTemplates['futronic_right_template'];
        }
        debugPrint(
            '[DB] ✅ Preserved fingerprint templates during facilitator update');
      }

      await db.insert(
        'facilitator',
        facilitatorData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint(
          '[DB] Saved facilitator to local database: ${data['firstName']} ${data['lastName']}, classID: $classID');
    } catch (e) {
      debugPrint('[DB] Failed to save facilitator details: $e');
      throw Exception('Failed to save facilitator details: $e');
    }
  }

  Future<String?> getFacilitatorProfileImage(String classID) async {
    final db = await database;
    try {
      List<Map<String, dynamic>> result = await db.query(
        'facilitator',
        columns: ['f_profile'],
        where: 'classID = ?',
        whereArgs: [classID],
      );
      return result.isNotEmpty ? result.first['f_profile'] as String? : null;
    } catch (e) {
      throw Exception('Failed to fetch profile image: $e');
    }
  }

  Future<String?> getFacilitatorSignature(String classID) async {
    final db = await database;
    try {
      List<Map<String, dynamic>> result = await db.query(
        'facilitator',
        columns: ['f_signature'],
        where: 'classID = ?',
        whereArgs: [classID],
      );
      return result.isNotEmpty ? result.first['f_signature'] as String? : null;
    } catch (e) {
      throw Exception('Failed to fetch signature: $e');
    }
  }

  Future<void> updateFacilitatorSignature(
      String classID, String base64Signature) async {
    final db = await database;
    try {
      await db.update(
        'facilitator',
        {'f_signature': base64Signature},
        where: 'classID = ?',
        whereArgs: [classID],
      );
    } catch (e) {
      throw Exception('Failed to update signature: $e');
    }
  }

  Future<void> updateFacilitatorProfileImage(
      String classID, String base64Image) async {
    final db = await database;
    try {
      await db.update(
        'facilitator',
        {'f_profile': base64Image},
        where: 'classID = ?',
        whereArgs: [classID],
      );
    } catch (e) {
      throw Exception('Failed to update profile image: $e');
    }
  }

  Future<void> updateFacilitatorDetails(
      String classID, Map<String, dynamic> updatedData) async {
    debugPrint('[DB] updateFacilitatorDetails called with classID: $classID');
    debugPrint('[DB] updatedData: $updatedData');

    final db = await database;
    try {
      final result = await db.update(
        'facilitator',
        {
          'phoneNumber': updatedData['phoneNumber'] ?? '',
          'f_IDNumber': updatedData['f_IDNumber'] ?? '',
          'assessorNo': updatedData['assessorNo'] ?? '',
          'assessorExpiryDate': updatedData['assessorExpiryDate'] ?? '',
        },
        where: 'classID = ?',
        whereArgs: [classID],
      );
      debugPrint('[DB] Update result: $result rows affected');
    } catch (e) {
      debugPrint('[DB] Error updating facilitator details: $e');
      throw Exception('Failed to update facilitator details: $e');
    }
  }

  Future<String?> convertBase64ToFile(
      String base64Data, String fileName) async {
    try {
      final bytes = base64Decode(base64Data);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      print('Error converting base64 to file: $e');
      return null;
    }
  }

  Future<void> updateSyncedStatus(String idNumber, int serverLearnerId) async {
    final db = await database;
    try {
      // Query LearnerID based on IDNumber
      final learnerResult = await db.query(
        'learnerdetails',
        where: 'IDNumber = ?',
        whereArgs: [idNumber],
      );
      if (learnerResult.isEmpty) {
        print('No learner found with IDNumber: $idNumber');
        return;
      }
      int localLearnerId = learnerResult.first['LearnerID'] as int;

      // Update learnerdetails with server LearnerID and synced status
      await db.update(
        'learnerdetails',
        {'LearnerID': serverLearnerId, 'synced': 1},
        where: 'IDNumber = ?',
        whereArgs: [idNumber],
      );

      // Update bankdetails with new LearnerID
      await db.update(
        'bankdetails',
        {'LearnerID': serverLearnerId},
        where: 'LearnerID = ?',
        whereArgs: [localLearnerId],
      );

      print(
          'Synced status updated for learner ID: $serverLearnerId (IDNumber: $idNumber)');
    } catch (e) {
      print('Error updating synced status: $e');
      rethrow;
    }
  }

  Future<void> updateBankDetailsSyncedStatus(
      int bankId, int syncedStatus) async {
    final db = await database;
    try {
      await db.update(
        'bankdetails',
        {'synced': syncedStatus},
        where: 'BankID = ?',
        whereArgs: [bankId],
      );
      print('Synced status updated for bank ID: $bankId');
    } catch (e) {
      print('Error updating bank details synced status: $e');
      rethrow;
    }
  }

  // Fetch unsynced learners for a specific class with bank details
  Future<List<Map<String, dynamic>>> fetchUnsyncedLearners(
      String classID) async {
    final db = await database;
    try {
      // First, get all unsynced learners
      final learners = await db.query(
        'learnerdetails',
        where: 'classID = ? AND synced = ?',
        whereArgs: [classID, 0], // 0 means unsynced
      );

      print('Found ${learners.length} unsynced learners for class $classID');

      // For each learner, fetch their bank details
      List<Map<String, dynamic>> learnersWithBankDetails = [];
      for (var learner in learners) {
        final learnerID = learner['LearnerID'];

        // Fetch bank details for this learner
        final bankDetails = await db.query(
          'bankdetails',
          where: 'LearnerID = ?',
          whereArgs: [learnerID],
        );

        // Create a copy of learner data
        Map<String, dynamic> learnerWithBank = Map.from(learner);

        // Add bank details if they exist
        if (bankDetails.isNotEmpty) {
          final bank = bankDetails.first;
          learnerWithBank['BankName'] = bank['BankName'] ?? '';
          learnerWithBank['bankType'] = bank['bankType'] ?? '';
          learnerWithBank['BankAccount'] = bank['BankAccount'] ?? '';
          learnerWithBank['BankCode'] = bank['BankCode'] ?? '';
        } else {
          // Set empty bank details if none exist
          learnerWithBank['BankName'] = '';
          learnerWithBank['bankType'] = '';
          learnerWithBank['BankAccount'] = '';
          learnerWithBank['BankCode'] = '';
        }

        learnersWithBankDetails.add(learnerWithBank);
      }

      return learnersWithBankDetails;
    } catch (e) {
      print('Error fetching unsynced learners: $e');
      return [];
    }
  }

  // Mark a learner as synced (both learnerdetails and bankdetails)
  Future<void> markLearnerAsSynced(dynamic learnerID) async {
    final db = await database;
    try {
      // Mark learner as synced
      await db.update(
        'learnerdetails',
        {'synced': 1},
        where: 'LearnerID = ?',
        whereArgs: [learnerID],
      );

      // Mark bank details as synced
      await db.update(
        'bankdetails',
        {'synced': 1},
        where: 'LearnerID = ?',
        whereArgs: [learnerID],
      );

      print('Marked learner $learnerID and their bank details as synced');
    } catch (e) {
      print('Error marking learner as synced: $e');
      rethrow;
    }
  }

  // Update local LearnerID with server LearnerID
  Future<void> updateLearnerID(
      dynamic oldLearnerID, dynamic newLearnerID) async {
    final db = await database;
    try {
      // Update learnerdetails table
      await db.update(
        'learnerdetails',
        {'LearnerID': newLearnerID},
        where: 'LearnerID = ?',
        whereArgs: [oldLearnerID],
      );

      // Update bankdetails table
      await db.update(
        'bankdetails',
        {'LearnerID': newLearnerID},
        where: 'LearnerID = ?',
        whereArgs: [oldLearnerID],
      );
    } catch (e) {
      print('Error updating LearnerID: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchLearnerByIDNumber(String idNumber) async {
    final db = await database;
    try {
      final result = await db.query(
        'learnerdetails',
        where: 'IDNumber = ?',
        whereArgs: [idNumber],
      );
      return result.isNotEmpty
          ? Map<String, dynamic>.from(result.first)
          : null; // Create mutable copy
    } catch (e) {
      print('Error fetching learner by IDNumber: $e');
      return null;
    }
  }

  /// Fetch all learners for a specific class ID
  Future<List<Map<String, dynamic>>> fetchLearners(String classID) async {
    final db = await database;
    try {
      final result = await db.query(
        'learnerdetails',
        where: 'classID = ?',
        whereArgs: [classID],
      );
      // Return mutable copies of all results
      return result.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (e) {
      print('Error fetching learners for classID $classID: $e');
      return [];
    }
  }

  /// Encodes local image/signature files as base64 for offline sync.
  /// When profile_image, signature, or witness_signature contain device paths
  /// to existing files, reads and encodes them for server upload.
  Future<Map<String, dynamic>> _prepareLearnerDataWithBase64Images(
      Map<String, dynamic> learnerData) async {
    final result = Map<String, dynamic>.from(learnerData);
    final learnerId = learnerData['LearnerID']?.toString() ?? '';

    // Helper to encode local file as base64 if it exists
    Future<void> encodeIfLocalFile(
        String fieldName, String base64FieldName) async {
      final path = learnerData[fieldName]?.toString();
      if (path == null || path.isEmpty) return;
      try {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          result[base64FieldName] = base64Encode(bytes);
        }
      } catch (e) {
        debugPrint('[SYNC] Error encoding $fieldName: $e');
      }
    }

    await encodeIfLocalFile('profile_image', 'profile_image_base64');
    await encodeIfLocalFile('signature', 'signature_base64');
    await encodeIfLocalFile('witness_signature', 'witness_signature_base64');

    return result;
  }

  Future<bool> _checkConnectivity() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('Error checking connectivity: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _sendAllDataToBackend(
      List<Map<String, dynamic>> allData) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.syncLearnerUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(allData),
      );

      if (response.statusCode == 200) {
        print('All data successfully sent to backend');
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          return responseData;
        } else {
          print('Server response error: ${responseData['message']}');
          return null;
        }
      } else {
        print('Failed to send data to backend: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error sending data to backend: $e');
      return null;
    }
  }

  Future<void> syncAllData(BuildContext context) async {
    final db = await database;
    bool isConnected = await _checkConnectivity();

    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No internet connection, cannot sync data')),
      );
      return;
    }

    // Fetch all unsynced learners
    final unsyncedLearners = await db.query(
      'learnerdetails',
      where: 'synced = ?',
      whereArgs: [0],
    );

    print('Found ${unsyncedLearners.length} unsynced learners');

    if (unsyncedLearners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to sync')),
      );
      return;
    }

    // Prepare all data for batch sync (with base64 images for offline sync)
    List<Map<String, dynamic>> allDataToSync = [];

    for (var learner in unsyncedLearners) {
      try {
        int localLearnerId = learner['LearnerID'] as int;

        // Fetch associated bank details
        final bankDetails = await db.query(
          'bankdetails',
          where: 'LearnerID = ?',
          whereArgs: [localLearnerId],
        );

        Map<String, dynamic> learnerData = Map.from(learner);
        learnerData = await _prepareLearnerDataWithBase64Images(learnerData);

        Map<String, dynamic>? bankData =
            bankDetails.isNotEmpty ? Map.from(bankDetails.first) : null;

        // Add to batch data
        allDataToSync.add({
          'learner': learnerData,
          'bank': bankData,
        });
      } catch (e) {
        print(
            'Error preparing learner data for IDNumber ${learner['IDNumber']}: $e');
      }
    }

    // Send all data in one request
    final responseData = await _sendAllDataToBackend(allDataToSync);

    if (responseData != null && responseData['status'] == 'success') {
      // Process successful syncs
      List<dynamic> syncedLearners = responseData['learners'] ?? [];
      List<dynamic> failedLearners = responseData['failed'] ?? [];

      print('Successfully synced ${syncedLearners.length} learners');
      if (failedLearners.isNotEmpty) {
        print('Failed to sync ${failedLearners.length} learners');
      }

      // Update local database with server IDs
      for (var syncedLearner in syncedLearners) {
        try {
          String idNumber = syncedLearner['IDNumber'];
          int serverLearnerId = syncedLearner['LearnerID'];

          await updateSyncedStatus(idNumber, serverLearnerId);

          // Update bank details sync status if BankID is provided
          if (syncedLearner['BankID'] != null) {
            // Find the local bank record and update its sync status
            final localBankResult = await db.query(
              'bankdetails',
              where: 'LearnerID = ?',
              whereArgs: [serverLearnerId],
            );

            if (localBankResult.isNotEmpty) {
              int localBankId = localBankResult.first['BankID'] as int;
              await updateBankDetailsSyncedStatus(localBankId, 1);
            }
          }

          print('Successfully processed sync for learner: $idNumber');
        } catch (e) {
          print(
              'Error processing synced learner ${syncedLearner['IDNumber']}: $e');
        }
      }

      String message = 'Sync completed: ${syncedLearners.length} successful';
      if (failedLearners.isNotEmpty) {
        message += ', ${failedLearners.length} failed';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync failed - please try again')),
      );
    }
  }

  Future<void> submitLearnerData(BuildContext context,
      Map<String, dynamic> learnerData, Map<String, dynamic>? bankData) async {
    try {
      int learnerId = await insertOrUpdateLearner(learnerData, bankData);
      bool isConnected = await _checkConnectivity();

      if (isConnected) {
        // Only sync if there's internet connection
        await syncAllData(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('No internet connection, learner data saved locally')),
        );
        await syncBankDetails(); // Verify and store bank details locally
      }
    } catch (e) {
      print('Error submitting learner data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving data: $e')),
      );
    }
  }

  // Helper method to validate and format dates for database
  String _validateAndFormatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty || dateString == 'N/A') {
      return '1900-01-01'; // Default date for invalid/null dates
    }

    try {
      // Try different date formats
      List<String> dateFormats = [
        'yyyy-MM-dd',
        'dd/MM/yyyy',
        'MM/dd/yyyy',
        'yyyy/MM/dd'
      ];
      DateTime? parsedDate;

      for (String format in dateFormats) {
        try {
          parsedDate = DateFormat(format).parse(dateString);
          break;
        } catch (e) {
          continue;
        }
      }

      if (parsedDate != null) {
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      } else {
        print('Could not parse date: $dateString, using default');
        return '1900-01-01';
      }
    } catch (e) {
      print('Error parsing date: $dateString, using default: $e');
      return '1900-01-01';
    }
  }

  Future<int> insertOrUpdateLearner(Map<String, dynamic> learnerData,
      [Map<String, dynamic>? bankData]) async {
    final db = await database;
    int learnerId = 0;

    debugPrint('[DB] insertOrUpdateLearner called with:');
    debugPrint('[DB] learnerData: $learnerData');
    debugPrint('[DB] bankData: $bankData');

    await db.transaction((txn) async {
      // Get project_id from classID (via class -> sites join)
      int? projectId;
      if (learnerData['classID'] != null) {
        final projectResult = await txn.rawQuery('''
          SELECT s.project_id 
          FROM class c 
          JOIN sites s ON c.siteID = s.siteID 
          WHERE c.classID = ?
        ''', [learnerData['classID'].toString()]);

        if (projectResult.isNotEmpty &&
            projectResult.first['project_id'] != null) {
          projectId =
              int.tryParse(projectResult.first['project_id'].toString());
          debugPrint(
              '[DB] Found project_id: $projectId for classID: ${learnerData['classID']}');
        }
      }

      // Check if learner already exists by IDNumber AND project_id
      List<Map<String, dynamic>> existingLearner = [];
      if (projectId != null) {
        // Check for duplicate in same project
        existingLearner = await txn.rawQuery('''
          SELECT ld.* 
          FROM learnerdetails ld
          JOIN class c ON ld.classID = c.classID
          JOIN sites s ON c.siteID = s.siteID
          WHERE ld.IDNumber = ? AND s.project_id = ?
        ''', [learnerData['IDNumber'], projectId]);

        debugPrint(
            '[DB] Checking for duplicate: IDNumber=${learnerData['IDNumber']}, project_id=$projectId');
        debugPrint(
            '[DB] Found ${existingLearner.length} existing learner(s) in same project');
      } else {
        // Fallback to old behavior if project_id not found
        existingLearner = await txn.query(
          'learnerdetails',
          where: 'IDNumber = ?',
          whereArgs: [learnerData['IDNumber']],
        );
        debugPrint('[DB] No project_id found, using old duplicate check');
      }

      Map<String, dynamic> learnerOnlyData = Map.from(learnerData)
        ..remove('BankName')
        ..remove('bankType')
        ..remove('BankAccount')
        ..remove('BankCode');

      // Validate and format DateOfBirth if present
      if (learnerOnlyData.containsKey('DateOfBirth')) {
        final originalDate = learnerOnlyData['DateOfBirth']?.toString();
        learnerOnlyData['DateOfBirth'] = _validateAndFormatDate(originalDate);
        debugPrint(
            '[DB] DateOfBirth: $originalDate -> ${learnerOnlyData['DateOfBirth']}');
      }

      if (existingLearner.isNotEmpty) {
        // Update existing learner in same project
        learnerId = existingLearner.first['LearnerID'] as int;
        await txn.update(
          'learnerdetails',
          learnerOnlyData,
          where: 'LearnerID = ?',
          whereArgs: [learnerId],
        );
        debugPrint(
            '[DB] Updated existing learner with ID: $learnerId (same project)');
        print('Updated existing learner with ID: $learnerId (same project)');
      } else {
        // Insert new learner (either new or duplicate in different project)
        learnerOnlyData['synced'] = 0; // Ensure synced is 0 for new entries
        learnerId = await txn.insert('learnerdetails', learnerOnlyData);
        debugPrint('[DB] Inserted new learner with ID: $learnerId');
        print('Inserted new learner with ID: $learnerId');
      }

      // Handle bank data
      if (bankData != null && bankData.isNotEmpty) {
        debugPrint('[DB] Bank data received: $bankData');

        Map<String, dynamic> bankDetails = {
          'LearnerID': learnerId,
          'BankName': bankData['BankName'] ?? '',
          'bankType': bankData['bankType'] ?? '',
          'BankAccount': bankData['BankAccount'] ?? '',
          'BankCode': bankData['BankCode']?.toString() ?? '',
          'synced': 0,
        };

        // Check if bank details already exist for this learner
        final existingBank = await txn.query(
          'bankdetails',
          where: 'LearnerID = ?',
          whereArgs: [learnerId],
        );

        if (existingBank.isNotEmpty) {
          // Update existing bank details
          await txn.update(
            'bankdetails',
            bankDetails,
            where: 'LearnerID = ?',
            whereArgs: [learnerId],
          );
          debugPrint(
              '[DB] Updated existing bank details for learner: $learnerId');
          print('Updated existing bank details for learner: $learnerId');
        } else {
          // Insert new bank details
          int bankId = await txn.insert('bankdetails', bankDetails);
          debugPrint('[DB] Inserted new bank details with ID: $bankId');
          print('Inserted new bank details with ID: $bankId');
        }
      } else {
        debugPrint(
            '[DB] No bank data to insert/update - bankData is null or empty');
        print('No bank data to insert/update - bankData is null or empty');
      }
    });

    // Verify what was actually inserted/updated
    try {
      final insertedLearner = await db.query(
        'learnerdetails',
        where: 'LearnerID = ?',
        whereArgs: [learnerId],
      );
      debugPrint(
          '[DB] Verification - inserted/updated learner data: ${insertedLearner.first}');

      if (bankData != null && bankData.isNotEmpty) {
        final insertedBank = await db.query(
          'bankdetails',
          where: 'LearnerID = ?',
          whereArgs: [learnerId],
        );
        debugPrint(
            '[DB] Verification - inserted/updated bank data: ${insertedBank.isNotEmpty ? insertedBank.first : 'NONE'}');
      }
    } catch (e) {
      debugPrint('[DB] Error during verification: $e');
    }

    return learnerId;
  }

  // Check if learner exists in the same project
  Future<Map<String, dynamic>?> checkLearnerExistsInProject(
      String idNumber, String classID) async {
    final db = await database;

    try {
      // Get project_id from classID
      final projectResult = await db.rawQuery('''
        SELECT s.project_id 
        FROM class c 
        JOIN sites s ON c.siteID = s.siteID 
        WHERE c.classID = ?
      ''', [classID]);

      if (projectResult.isEmpty || projectResult.first['project_id'] == null) {
        debugPrint(
            '[DB] No project_id found for classID: $classID, cannot check duplicate');
        return null;
      }

      final projectId = projectResult.first['project_id'];

      // Check if learner exists in same project
      final existingLearner = await db.rawQuery('''
        SELECT ld.*, c.className, s.siteName, s.project_id
        FROM learnerdetails ld
        JOIN class c ON ld.classID = c.classID
        JOIN sites s ON c.siteID = s.siteID
        WHERE ld.IDNumber = ? AND s.project_id = ?
      ''', [idNumber, projectId]);

      if (existingLearner.isNotEmpty) {
        debugPrint(
            '[DB] Learner with IDNumber $idNumber exists in project $projectId');
        return existingLearner.first;
      }

      debugPrint(
          '[DB] Learner with IDNumber $idNumber does NOT exist in project $projectId');
      return null;
    } catch (e) {
      debugPrint('[DB] Error checking learner duplicate: $e');
      return null;
    }
  }

  Future<void> syncBankDetails() async {
    final db = await database;
    final unsyncedBankDetails = await db.query(
      'bankdetails',
      where: 'synced = ?',
      whereArgs: [0],
    );

    print(
        'Found ${unsyncedBankDetails.length} unsynced bank details for offline storage');

    for (var bankDetail in unsyncedBankDetails) {
      try {
        if (bankDetail['LearnerID'] == null || bankDetail['BankName'] == null) {
          print(
              'Invalid bank detail for BankID ${bankDetail['BankID']}: Missing required fields');
          continue;
        }
        print(
            'Bank details for LearnerID ${bankDetail['LearnerID']} verified and stored offline');
      } catch (e) {
        print(
            'Error processing bank details for BankID ${bankDetail['BankID']}: $e');
      }
    }
  }

  // Sync learner documents from server to local database
  Future<void> syncLearnerDocuments() async {
    try {
      print('[SYNC] Starting learner documents sync...');

      // Make request to sync endpoint
      final response = await http.get(
        Uri.parse(AppConfig.syncLearnerDocumentsUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          final documents = jsonData['documents'] as List;
          print(
              '[SYNC] Retrieved ${documents.length} learner documents from server');

          final db = await database;
          int syncedCount = 0;

          for (var document in documents) {
            try {
              // Check if document already exists
              final existing = await db.query(
                'learner_document',
                where: 'document_id = ?',
                whereArgs: [document['document_id']],
              );

              if (existing.isEmpty) {
                // Insert new document
                await db.insert('learner_document', {
                  'document_id': document['document_id'],
                  'documentName': document['documentName'],
                  'learner_document': document['learner_document'],
                  'status': document['status'],
                  'learner_id': document['learner_id'],
                  'upload_date': document['upload_date'],
                  'synced': 1, // Mark as synced
                  'rejection_reason': document['rejection_reason'],
                });
                syncedCount++;
              } else {
                // Update existing document (in case status changed on server)
                await db.update(
                  'learner_document',
                  {
                    'documentName': document['documentName'],
                    'learner_document': document['learner_document'],
                    'status': document['status'],
                    'upload_date': document['upload_date'],
                    'synced': 1,
                    'rejection_reason': document['rejection_reason'],
                  },
                  where: 'document_id = ?',
                  whereArgs: [document['document_id']],
                );
              }
            } catch (e) {
              print(
                  '[SYNC] Error syncing document ${document['document_id']}: $e');
            }
          }

          print(
              '[SYNC] Successfully synced $syncedCount new learner documents');
        } else {
          print('[SYNC] Server returned error: ${jsonData['message']}');
        }
      } else {
        print('[SYNC] HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('[SYNC] Error syncing learner documents: $e');
    }
  }

  // Fetch bank details for a specific learner
  Future<Map<String, dynamic>?> fetchLearnerBankDetails(int learnerId) async {
    final db = await database;
    try {
      final result = await db.query(
        'bankdetails',
        where: 'LearnerID = ?',
        whereArgs: [learnerId],
      );

      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      debugPrint('[DB] Error fetching bank details for learner $learnerId: $e');
      return null;
    }
  }

  // Fetch all bank details (for debugging)
  Future<List<Map<String, dynamic>>> fetchAllBankDetails() async {
    final db = await database;
    try {
      final result = await db.query('bankdetails');
      debugPrint('[DB] Fetched ${result.length} bank details records');
      return result;
    } catch (e) {
      debugPrint('[DB] Error fetching all bank details: $e');
      return [];
    }
  }

  // Debug method to check database structure
  Future<void> debugDatabaseStructure() async {
    final db = await database;
    try {
      // Check if bankdetails table exists
      final tables = await db.query('sqlite_master',
          where: 'type = ? AND name = ?', whereArgs: ['table', 'bankdetails']);
      if (tables.isEmpty) {
        debugPrint('[DEBUG] bankdetails table does not exist!');
        return;
      }

      debugPrint('[DEBUG] bankdetails table exists');

      // Get table schema
      final schema = await db.rawQuery('PRAGMA table_info(bankdetails)');
      debugPrint('[DEBUG] bankdetails table schema:');
      for (var column in schema) {
        debugPrint(
            '[DEBUG] Column: ${column['name']} - Type: ${column['type']}');
      }

      // Check if table has any data
      final count =
          await db.rawQuery('SELECT COUNT(*) as count FROM bankdetails');
      debugPrint('[DEBUG] bankdetails table has ${count.first['count']} rows');

      // Show sample data
      final sampleData = await db.query('bankdetails', limit: 5);
      debugPrint('[DEBUG] Sample bankdetails data: $sampleData');

      // Show all bank details
      final allBankDetails = await fetchAllBankDetails();
      debugPrint('[DEBUG] All bank details: $allBankDetails');
    } catch (e) {
      debugPrint('[DEBUG] Error checking database structure: $e');
    }
  }

// Add this method to manually trigger sync
  Future<void> forceSyncAllData(BuildContext context) async {
    try {
      // Sync all unsynced data
      await syncUnsyncedFingerprints();
      await syncBankDetails();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data synced successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Get classID for a specific learner
  Future<String?> getClassIDForLearner(int learnerId) async {
    try {
      final db = await database;
      final result = await db.query(
        'learnerdetails',
        columns: ['classID'],
        where: 'LearnerID = ?',
        whereArgs: [learnerId],
      );

      if (result.isNotEmpty) {
        final classID = result.first['classID'];
        debugPrint('[DB] Found classID: $classID for learner: $learnerId');
        return classID?.toString();
      } else {
        debugPrint('[DB] No classID found for learner: $learnerId');
        return null;
      }
    } catch (e) {
      debugPrint('[DB] Error getting classID for learner $learnerId: $e');
      return null;
    }
  }

  // Sync learners from server to local database
  Future<void> syncLearnersFromServer(String classID) async {
    try {
      debugPrint('[SYNC-CLASS] Starting learner sync for classID: $classID');

      // Try primary sync endpoint first
      http.Response? response;
      try {
        debugPrint(
            '[SYNC-CLASS] Trying primary endpoint: syncLearnersByClassUrl');
        response = await http
            .get(
              Uri.parse('${AppConfig.syncLearnersByClassUrl}?classID=$classID'),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          debugPrint(
              '[SYNC-CLASS] Primary endpoint returned ${response.statusCode}, trying fallback...');
          response = null;
        }
      } catch (e) {
        debugPrint(
            '[SYNC-CLASS] Primary endpoint failed: $e, trying fallback...');
        response = null;
      }

      // Fallback to alternative endpoint if primary fails
      if (response == null) {
        debugPrint('[SYNC-CLASS] Trying fallback endpoint: getLearnersUrl');
        response = await http
            .get(
              Uri.parse('${AppConfig.getLearnersUrl}?classID=$classID'),
            )
            .timeout(const Duration(seconds: 10));
      }

      if (response.statusCode == 200) {
        List<dynamic> learnersDataRaw = json.decode(response.body);

        // Deduplicate learners by LearnerID to prevent duplicate processing
        Map<String, dynamic> uniqueLearnersMap = {};
        for (var learner in learnersDataRaw) {
          String? id = learner['LearnerID']?.toString();
          if (id != null && id.isNotEmpty) {
            uniqueLearnersMap[id] = learner;
          }
        }
        final List<dynamic> learnersData = uniqueLearnersMap.values.toList();

        debugPrint('[SYNC-CLASS] ===== CLASS LEARNER SYNC DEBUG START =====');
        debugPrint(
            '[SYNC-CLASS] Received ${learnersDataRaw.length} raw records, ${learnersData.length} unique learners from server for classID: $classID');
        debugPrint(
            '[SYNC-CLASS] First learner data sample: ${learnersData.isNotEmpty ? learnersData.first : 'No learners'}');

        // Debug fingerprint data from server for multiple learners
        if (learnersData.isNotEmpty) {
          for (int i = 0; i < math.min(3, learnersData.length); i++) {
            final learner = learnersData[i];
            debugPrint(
                '[SYNC-CLASS] Learner ${i + 1} (ID: ${learner['LearnerID']}) fingerprint fields:');
            debugPrint(
                '[SYNC-CLASS]   zkteco_left_template: ${learner['zkteco_left_template']?.toString().length ?? 'null'} chars');
            debugPrint(
                '[SYNC-CLASS]   zkteco_right_template: ${learner['zkteco_right_template']?.toString().length ?? 'null'} chars');
            debugPrint(
                '[SYNC-CLASS]   futronic_left_template: ${learner['futronic_left_template']?.toString().length ?? 'null'} chars');
            debugPrint(
                '[SYNC-CLASS]   futronic_right_template: ${learner['futronic_right_template']?.toString().length ?? 'null'} chars');
            debugPrint(
                '[SYNC-CLASS]   sourceafis_template: ${learner['sourceafis_template']?.toString().length ?? 'null'} chars');
          }
        }
        debugPrint('[SYNC-CLASS] ===== CLASS LEARNER SYNC DEBUG END =====');

        final db = await database;

        // Get existing learners with fingerprint templates before clearing
        final existingLearners = await db.query(
          'learnerdetails',
          where: 'classID = ?',
          whereArgs: [classID],
        );

        // OFFLINE-FIRST FIX: Create a map of existing learners for UPSERT logic
        // Don't delete existing learners - preserve local data for offline operation
        Map<String, Map<String, dynamic>> existingLearnersMap = {};
        for (var learner in existingLearners) {
          existingLearnersMap[learner['LearnerID'].toString()] = learner;
        }

        debugPrint(
            '[SYNC] Found ${existingLearners.length} existing learners in local database');
        debugPrint(
            '[SYNC] Using UPSERT logic - preserving existing learners for offline operation');

        // Insert new learners
        for (var learner in learnersData) {
          try {
            String learnerId = learner['LearnerID']?.toString() ?? '';
            // Check if learner exists locally
            final existingLearner = existingLearnersMap[learnerId];

            // Build learner data, merging server and existing local data
            // For each field: use server value if present, otherwise use existing local value
            Map<String, dynamic> learnerData = {
              'LearnerID': learnerId,
              'classID': classID,
              'synced': 1, // Mark as synced since it came from server
            };

            // List of all fields we want to merge
            final fieldsToMerge = [
              'Title', 'Name', 'Surname', 'IDNumber', 'DateOfBirth',
              'PhoneNumber', 'Email', 'Age', 'Gender', 'Race',
              'Language', 'Disability', 'AddressLine1', 'AddressLine2',
              'AddressLine3', 'PostalCode', 'KinName', 'KinRelation',
              'KinContact', 'SchoolName', 'SchoolCompletion',
              'SchoolLocation', 'SchoolGrade', 'profile_image',
              'signature', 'imagePath', 'activity_statu',
              'witness_initials', 'learner_initials', 'witness_signature',
              // Fingerprint fields handled separately below
            ];

            for (var field in fieldsToMerge) {
              final serverValue = learner[field]?.toString();
              final localValue = existingLearner?[field]?.toString();

              // Use server value if it's present and not empty, otherwise use local value
              if (serverValue != null && serverValue.isNotEmpty) {
                learnerData[field] = serverValue;
              } else if (localValue != null && localValue.isNotEmpty) {
                learnerData[field] = localValue;
              }
            }

            // Process fingerprint templates - merge server data with existing local data
            // Server data takes priority, but preserve local data if server has none
            Map<String, String> fingerprintData = {};

            // Start with existing local templates if any
            if (existingLearner != null) {
              // Preserve existing fingerprint templates
              if (existingLearner['zkteco_left_template'] != null &&
                  existingLearner['zkteco_left_template']
                      .toString()
                      .isNotEmpty) {
                fingerprintData['zkteco_left_template'] =
                    existingLearner['zkteco_left_template'].toString();
              }
              if (existingLearner['zkteco_right_template'] != null &&
                  existingLearner['zkteco_right_template']
                      .toString()
                      .isNotEmpty) {
                fingerprintData['zkteco_right_template'] =
                    existingLearner['zkteco_right_template'].toString();
              }
              if (existingLearner['futronic_left_template'] != null &&
                  existingLearner['futronic_left_template']
                      .toString()
                      .isNotEmpty) {
                fingerprintData['futronic_left_template'] =
                    existingLearner['futronic_left_template'].toString();
              }
              if (existingLearner['futronic_right_template'] != null &&
                  existingLearner['futronic_right_template']
                      .toString()
                      .isNotEmpty) {
                fingerprintData['futronic_right_template'] =
                    existingLearner['futronic_right_template'].toString();
              }
              if (existingLearner['fingerprint_template'] != null &&
                  existingLearner['fingerprint_template']
                      .toString()
                      .isNotEmpty) {
                fingerprintData['fingerprint_template'] =
                    existingLearner['fingerprint_template'].toString();
              }
              if (existingLearner['isLeftHand'] != null &&
                  existingLearner['isLeftHand'].toString().isNotEmpty) {
                fingerprintData['isLeftHand'] =
                    existingLearner['isLeftHand'].toString();
              }
              if (existingLearner['sourceafis_template'] != null &&
                  existingLearner['sourceafis_template']
                      .toString()
                      .isNotEmpty) {
                fingerprintData['sourceafis_template'] =
                    existingLearner['sourceafis_template'].toString();
              }
              debugPrint(
                  '[SYNC] Starting with existing local templates for learner: $learnerId');
            }

            // Override with server data if it exists (server takes priority)

            // Add new format fields from server if they exist
            if (learner['zkteco_left_template'] != null &&
                learner['zkteco_left_template'].toString().isNotEmpty) {
              fingerprintData['zkteco_left_template'] =
                  learner['zkteco_left_template'].toString();
              debugPrint(
                  '[SYNC] Server provided zkteco_left_template for learner: $learnerId');
            }
            if (learner['zkteco_right_template'] != null &&
                learner['zkteco_right_template'].toString().isNotEmpty) {
              fingerprintData['zkteco_right_template'] =
                  learner['zkteco_right_template'].toString();
              debugPrint(
                  '[SYNC] Server provided zkteco_right_template for learner: $learnerId');
            }
            if (learner['futronic_left_template'] != null &&
                learner['futronic_left_template'].toString().isNotEmpty) {
              fingerprintData['futronic_left_template'] =
                  learner['futronic_left_template'].toString();
              debugPrint(
                  '[SYNC] Server provided futronic_left_template for learner: $learnerId');
            }
            if (learner['futronic_right_template'] != null &&
                learner['futronic_right_template'].toString().isNotEmpty) {
              fingerprintData['futronic_right_template'] =
                  learner['futronic_right_template'].toString();
              debugPrint(
                  '[SYNC] Server provided futronic_right_template for learner: $learnerId');
            }
            if (learner['sourceafis_template'] != null &&
                learner['sourceafis_template'].toString().isNotEmpty) {
              fingerprintData['sourceafis_template'] =
                  learner['sourceafis_template'].toString();
              debugPrint(
                  '[SYNC] Server provided sourceafis_template for learner: $learnerId');
            }

            // Add old format fields for backwards compatibility mapping
            if (learner['fingerprint_template'] != null &&
                learner['fingerprint_template'].toString().isNotEmpty) {
              fingerprintData['fingerprint_template'] =
                  learner['fingerprint_template'].toString();
              debugPrint(
                  '[SYNC] Server provided fingerprint_template (old format) for learner: $learnerId');
            }
            if (learner['isLeftHand'] != null &&
                learner['isLeftHand'].toString().isNotEmpty) {
              fingerprintData['isLeftHand'] = learner['isLeftHand'].toString();
              debugPrint(
                  '[SYNC] Server provided isLeftHand (old format) for learner: $learnerId');
            }

            learnerData.addAll(fingerprintData);

            // Debug what we're about to insert
            debugPrint(
                '[SYNC] ===== INSERTING LEARNER ${learnerData['LearnerID']} =====');
            debugPrint(
                '[SYNC] Pre-insert learnerData keys: ${learnerData.keys.toList()}');
            debugPrint('[SYNC] Fingerprint data before insert:');
            debugPrint(
                '[SYNC]   fingerprint_template: ${learnerData['fingerprint_template']?.toString().length ?? 'null'} chars');
            debugPrint('[SYNC]   isLeftHand: ${learnerData['isLeftHand']}');
            debugPrint(
                '[SYNC]   zkteco_left_template: ${learnerData['zkteco_left_template']?.toString().length ?? 'null'} chars');
            debugPrint(
                '[SYNC]   zkteco_right_template: ${learnerData['zkteco_right_template']?.toString().length ?? 'null'} chars');
            debugPrint(
                '[SYNC]   futronic_left_template: ${learnerData['futronic_left_template']?.toString().length ?? 'null'} chars');
            debugPrint(
                '[SYNC]   futronic_right_template: ${learnerData['futronic_right_template']?.toString().length ?? 'null'} chars');

            // Use insertData instead of direct db.insert to ensure proper column mapping
            // OFFLINE-FIRST: Use UPSERT logic (update if exists, insert if new)
            if (existingLearner != null) {
              // UPDATE existing learner
              await db.update(
                'learnerdetails',
                learnerData,
                where: 'LearnerID = ?',
                whereArgs: [learnerId],
              );
              debugPrint(
                  '[SYNC] Updated existing learner: ${learnerData['Name']} ${learnerData['Surname']} (ID: $learnerId)');
            } else {
              // INSERT new learner
              await insertData('learnerdetails', learnerData);
              debugPrint(
                  '[SYNC] Inserted new learner: ${learnerData['Name']} ${learnerData['Surname']} (ID: $learnerId)');
            }

            // Verify what was actually inserted
            final verifyResult = await db.query(
              'learnerdetails',
              columns: [
                'LearnerID',
                'Name',
                'Surname',
                'zkteco_left_template',
                'zkteco_right_template',
                'futronic_left_template',
                'futronic_right_template'
              ],
              where: 'LearnerID = ?',
              whereArgs: [learnerData['LearnerID']],
            );
            if (verifyResult.isNotEmpty) {
              final row = verifyResult.first;
              debugPrint('[SYNC] ===== VERIFICATION POST-INSERT =====');
              debugPrint(
                  '[SYNC] Learner ${row['LearnerID']} (${row['Name']} ${row['Surname']}) fingerprint columns:');
              debugPrint(
                  '[SYNC]   zkteco_left_template: ${row['zkteco_left_template']?.toString().length ?? 'null'} chars');
              debugPrint(
                  '[SYNC]   zkteco_right_template: ${row['zkteco_right_template']?.toString().length ?? 'null'} chars');
              debugPrint(
                  '[SYNC]   futronic_left_template: ${row['futronic_left_template']?.toString().length ?? 'null'} chars');
              debugPrint(
                  '[SYNC]   futronic_right_template: ${row['futronic_right_template']?.toString().length ?? 'null'} chars');
              debugPrint('[SYNC] ===== END VERIFICATION =====');
            }
          } catch (e) {
            debugPrint('[SYNC] Error inserting learner: $e');
          }
        }

        debugPrint(
            '[SYNC] Successfully synced ${learnersData.length} learners for classID: $classID');
      } else {
        debugPrint(
            '[SYNC] Server returned status code: ${response.statusCode}');
        throw Exception('Failed to fetch learners from server');
      }
    } catch (e) {
      debugPrint('[SYNC] Error syncing learners: $e');
      throw Exception('Failed to sync learners: $e');
    }
  }

  Future<void> syncUnsyncedLearnerProfiles() async {
    try {
      debugPrint(
          '[SYNC-LEARNER-PROFILE] Starting sync of unsynced learner profiles');

      final db = await database;
      final unsyncedLearners = await db.query(
        'learnerdetails',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (unsyncedLearners.isEmpty) {
        debugPrint('[SYNC-LEARNER-PROFILE] No unsynced learner profiles found');
        return;
      }

      debugPrint(
          '[SYNC-LEARNER-PROFILE] Found ${unsyncedLearners.length} unsynced learner profiles');

      // Check internet connectivity
      bool hasInternet = false;
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        hasInternet = connectivityResult.isNotEmpty &&
            connectivityResult.first != ConnectivityResult.none;
      } catch (e) {
        debugPrint('[SYNC-LEARNER-PROFILE] Error checking connectivity: $e');
      }

      if (!hasInternet) {
        debugPrint(
            '[SYNC-LEARNER-PROFILE] No internet - skipping sync of learner profiles');
        return;
      }

      int syncedCount = 0;
      for (var learner in unsyncedLearners) {
        try {
          final learnerId = learner['LearnerID'].toString();

          // Build update data with all non-null, non-empty fields
          Map<String, dynamic> updateData = {};

          // List of fields we want to sync
          final fieldsToSync = [
            'Title',
            'Name',
            'Surname',
            'IDNumber',
            'DateOfBirth',
            'PhoneNumber',
            'Email',
            'Age',
            'Gender',
            'Race',
            'Language',
            'Disability',
            'AddressLine1',
            'AddressLine2',
            'AddressLine3',
            'PostalCode',
            'KinName',
            'KinRelation',
            'KinContact',
            'SchoolName',
            'SchoolCompletion',
            'SchoolLocation',
            'SchoolGrade',
            'profile_image',
            'signature',
            'imagePath',
            'activity_statu',
            'witness_initials',
            'learner_initials',
            'witness_signature',
            'zkteco_left_template',
            'zkteco_right_template',
            'futronic_left_template',
            'futronic_right_template',
            'sourceafis_template',
            'fingerprint_template',
            'isLeftHand',
          ];

          for (var field in fieldsToSync) {
            final value = learner[field];
            if (value != null && value.toString().isNotEmpty) {
              updateData[field] = value;
            }
          }

          if (updateData.isEmpty) {
            debugPrint(
                '[SYNC-LEARNER-PROFILE] No fields to sync for learner $learnerId - marking as synced');
            await db.update(
              'learnerdetails',
              {'synced': 1},
              where: 'LearnerID = ?',
              whereArgs: [learnerId],
            );
            syncedCount++;
            continue;
          }

          debugPrint(
              '[SYNC-LEARNER-PROFILE] Syncing learner profile for $learnerId with fields: ${updateData.keys}');

          final response = await http
              .post(
                Uri.parse(AppConfig.updateLearnerUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'LearnerID': learnerId,
                  'data': updateData,
                }),
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final jsonResponse = jsonDecode(response.body);
            if (jsonResponse['success'] == true) {
              debugPrint(
                  '[SYNC-LEARNER-PROFILE] Successfully synced learner profile for $learnerId');
              await db.update(
                'learnerdetails',
                {'synced': 1},
                where: 'LearnerID = ?',
                whereArgs: [learnerId],
              );
              syncedCount++;
            } else {
              debugPrint(
                  '[SYNC-LEARNER-PROFILE] Server rejected update for learner $learnerId: ${jsonResponse['message']}');
            }
          } else {
            debugPrint(
                '[SYNC-LEARNER-PROFILE] Failed to sync learner $learnerId: HTTP ${response.statusCode}');
          }
        } catch (e) {
          debugPrint(
              '[SYNC-LEARNER-PROFILE] Error syncing learner profile: $e');
        }
      }

      debugPrint(
          '[SYNC-LEARNER-PROFILE] Successfully synced $syncedCount/${unsyncedLearners.length} learner profiles');
    } catch (e) {
      debugPrint(
          '[SYNC-LEARNER-PROFILE] Error syncing unsynced learner profiles: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLearnersWithInductionClockingData(
      String classID) async {
    final db = await database;
    try {
      final result = await db.rawQuery('''
        SELECT l.LearnerID, l.Name, l.Surname, l.IDNumber, ic.clock_in_time, ic.clock_out_time, ic.contact_time
        FROM learnerdetails l
        LEFT JOIN (
          SELECT LearnerID, clock_date, 
                 MIN(clock_in_time) as clock_in_time, 
                 MAX(clock_out_time) as clock_out_time,
                 MAX(contact_time) as contact_time
          FROM induction_clocking
          WHERE clock_date = ?
          GROUP BY LearnerID
        ) ic ON l.LearnerID = ic.LearnerID
        WHERE l.classID = ?
      ''', [DateFormat('yyyy-MM-dd').format(DateTime.now()), classID]);
      print('Fetched learners with clocking data: $result');
      return result;
    } catch (e) {
      print('Error fetching learners with clocking data: $e');
      rethrow;
    }
  }

  Future<void> insertInductionClocking(Map<String, dynamic> data) async {
    final db = await database;
    // Check if a record for this learner already exists
    final existing = await db.query(
      'induction_clocking',
      where: 'LearnerID = ?',
      whereArgs: [data['LearnerID']],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('induction_clocking', data);
    } else {
      // Update the existing record for this learner
      await db.update(
        'induction_clocking',
        data,
        where: 'LearnerID = ?',
        whereArgs: [data['LearnerID']],
      );
    }
  }

  Future<void> updateInductionClocking(
      String learnerID, String clockDate, Map<String, dynamic> data) async {
    final db = await database;
    try {
      await db.update(
        'induction_clocking',
        data,
        where: 'LearnerID = ? AND clock_date = ?',
        whereArgs: [learnerID, clockDate],
      );
      print(
          'Updated clocking data for LearnerID: $learnerID on $clockDate: $data');
    } catch (e) {
      print('Error updating induction_clocking: $e');
      rethrow;
    }
  }

  /// Save fingerprint template online if possible, otherwise locally for later sync
  /// Returns true if synced to server, false if saved locally
  /// scannerType: 'zkteco' or 'futronic' to determine which column to save to
  Future<bool> saveFingerprintSmart(
      int learnerId, String finger, dynamic template,
      {String scannerType = 'futronic'}) async {
    try {
      final db = await database;
      final templateStr = template.toString();

      // Skip if template is empty
      if (templateStr.isEmpty) {
        debugPrint(
            '[SAVE] Skipping save for empty template: $scannerType $finger for learner $learnerId');
        return false;
      }

      // Save to the appropriate column based on scanner type
      if (scannerType == 'zkteco') {
        await saveZkTecoTemplate(learnerId, templateStr,
            isLeft: finger == 'left');
        debugPrint(
            '[SAVE] Saved ZKTeco template to ${finger == 'left' ? 'zkteco_left_template' : 'zkteco_right_template'}');
      } else if (scannerType == 'futronic') {
        await saveFutronicTemplate(learnerId, templateStr,
            isLeft: finger == 'left');
        debugPrint(
            '[SAVE] Saved Futronic template to ${finger == 'left' ? 'futronic_left_template' : 'futronic_right_template'}');
      } else {
        throw Exception('Unknown scanner type: $scannerType');
      }

      // Mark as unsynced so it gets synced to server
      await db.update(
        'learnerdetails',
        {'synced': 0},
        where: 'LearnerID = ?',
        whereArgs: [learnerId],
      );

      // Try to sync immediately if network is available
      try {
        // Check connectivity first
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult != ConnectivityResult.none) {
          debugPrint(
              '[SYNC] Internet available, attempting immediate sync for $scannerType template');

          // Try to sync just this specific template first
          await _syncSingleTemplate(
              learnerId,
              scannerType == 'zkteco'
                  ? (finger == 'left' ? 'zkteco_left' : 'zkteco_right')
                  : (finger == 'left' ? 'futronic_left' : 'futronic_right'),
              templateStr);

          debugPrint('[SYNC] Individual template sync completed successfully');

          // Mark this specific learner as synced
          await db.update(
            'learnerdetails',
            {'synced': 1},
            where: 'LearnerID = ?',
            whereArgs: [learnerId],
          );

          debugPrint(
              '[SYNC] Immediate sync completed successfully for $scannerType $finger template');
          return true; // Successfully synced
        } else {
          debugPrint('[SYNC] No internet connection, will sync later');
          return false; // Saved locally but not synced (no internet)
        }
      } catch (e) {
        debugPrint('[SYNC] Immediate sync failed, will retry later: $e');
        // Don't throw here - we still saved locally
        return false; // Saved locally but not synced
      }
    } catch (e) {
      print('Error saving fingerprint: $e');
      rethrow;
    }
  }

  // DEPRECATED: Use saveZkTecoTemplate or saveFutronicTemplate instead
  Future<void> saveFingerprint(
      int learnerId, String finger, String wsqTemplate) async {
    debugPrint(
        '[DEPRECATED] saveFingerprint called - use saveZkTecoTemplate or saveFutronicTemplate instead');
    // This method is kept for backward compatibility but should not be used
  }

  // Comprehensive fingerprint detection method
  Future<Map<String, String?>> getFingerprintsComprehensive(
      int learnerId) async {
    final db = await database;

    print('[DB_DEBUG] getFingerprintsComprehensive for learner $learnerId');

    // Query ALL columns to see what data exists
    final result = await db.query(
      'learnerdetails',
      where: 'LearnerID = ?',
      whereArgs: [learnerId],
    );

    if (result.isNotEmpty) {
      final row = result.first;
      String? leftTemplate;
      String? rightTemplate;

      // Check for fingerprint data in ANY column that might contain it
      row.forEach((key, value) {
        if (value != null &&
            value.toString().isNotEmpty &&
            value.toString() != 'null') {
          final keyLower = key.toLowerCase();
          final valueStr = value.toString();

          // Look for potential fingerprint template data
          if ((keyLower.contains('template') || keyLower.contains('finger')) &&
              valueStr.length > 50) {
            // Fingerprint templates are usually quite long
            print(
                '[DB_DEBUG] Found potential fingerprint data in column "$key": ${valueStr.length} chars');

            // Try to determine if it's left or right hand
            if (keyLower.contains('left') ||
                keyLower.contains('futronic_left') ||
                keyLower.contains('zkteco_left')) {
              leftTemplate = valueStr;
            } else if (keyLower.contains('right') ||
                keyLower.contains('futronic_right') ||
                keyLower.contains('zkteco_right')) {
              rightTemplate = valueStr;
            } else if (leftTemplate == null) {
              // If no specific hand specified, use as left template
              leftTemplate = valueStr;
            } else
              rightTemplate ??= valueStr;
          }
        }
      });

      print(
          '[DB_DEBUG] Comprehensive search result - Left: ${leftTemplate != null}, Right: ${rightTemplate != null}');
      return {
        'left': leftTemplate,
        'right': rightTemplate,
      };
    }

    return {'left': null, 'right': null};
  }

  Future<Map<String, String?>> getFingerprints(int learnerId) async {
    final db = await database;

    // First, let's see what columns actually exist in the table
    try {
      final tableInfo = await db.rawQuery('PRAGMA table_info(learnerdetails)');
      print('[DB_DEBUG] learnerdetails table columns:');
      for (var col in tableInfo) {
        if (col['name'].toString().toLowerCase().contains('template') ||
            col['name'].toString().toLowerCase().contains('finger')) {
          print('[DB_DEBUG]   ${col['name']}: ${col['type']}');
        }
      }
    } catch (e) {
      print('[DB_DEBUG] Error getting table info: $e');
    }

    // Enhanced debugging - check all possible template columns
    final result = await db.query(
      'learnerdetails',
      columns: [
        'LearnerID',
        'zkteco_left_template',
        'zkteco_right_template',
        'futronic_left_template',
        'futronic_right_template',
        'sourceafis_template'
      ],
      where: 'LearnerID = ?',
      whereArgs: [learnerId],
    );

    print('[DB_DEBUG] getFingerprints for learner $learnerId:');
    print('[DB_DEBUG] Query result count: ${result.length}');

    if (result.isNotEmpty) {
      final row = result.first;
      print('[DB_DEBUG] Raw row data keys: ${row.keys.toList()}');

      // Try to get templates from any available scanner
      final zkLeft = row['zkteco_left_template'] as String?;
      final zkRight = row['zkteco_right_template'] as String?;
      final futronicLeft = row['futronic_left_template'] as String?;
      final futronicRight = row['futronic_right_template'] as String?;
      final sourceafis = row['sourceafis_template'] as String?;

      print(
          '[DB_DEBUG] ZKTeco left template: ${zkLeft?.length ?? 0} chars, null: ${zkLeft == null}');
      print(
          '[DB_DEBUG] ZKTeco right template: ${zkRight?.length ?? 0} chars, null: ${zkRight == null}');
      print(
          '[DB_DEBUG] Futronic left template: ${futronicLeft?.length ?? 0} chars, null: ${futronicLeft == null}');
      print(
          '[DB_DEBUG] Futronic right template: ${futronicRight?.length ?? 0} chars, null: ${futronicRight == null}');
      print(
          '[DB_DEBUG] SourceAFIS template: ${sourceafis?.length ?? 0} chars, null: ${sourceafis == null}');

      // If no templates found, check if data might be in a different format
      if ((zkLeft == null || zkLeft.isEmpty) &&
          (zkRight == null || zkRight.isEmpty) &&
          (futronicLeft == null || futronicLeft.isEmpty) &&
          (futronicRight == null || futronicRight.isEmpty) &&
          (sourceafis == null || sourceafis.isEmpty)) {
        print(
            '[DB_DEBUG] No templates found in standard columns, checking for any non-null template data...');
        // Let's see if there's ANY fingerprint data for this learner
        final allData = await db.query(
          'learnerdetails',
          where: 'LearnerID = ?',
          whereArgs: [learnerId],
        );

        if (allData.isNotEmpty) {
          final allRow = allData.first;
          print('[DB_DEBUG] All available columns for learner $learnerId:');
          allRow.forEach((key, value) {
            if (key.toLowerCase().contains('template') ||
                key.toLowerCase().contains('finger')) {
              print(
                  '[DB_DEBUG]   $key: ${value != null ? "${value.toString().length} chars" : "NULL"}');
            }
          });
        }
      }

      // Prefer ZKTeco templates if available, otherwise use Futronic
      var leftTemplate = (zkLeft != null && zkLeft.isNotEmpty)
          ? zkLeft
          : (futronicLeft != null && futronicLeft.isNotEmpty)
              ? futronicLeft
              : null;
      var rightTemplate = (zkRight != null && zkRight.isNotEmpty)
          ? zkRight
          : (futronicRight != null && futronicRight.isNotEmpty)
              ? futronicRight
              : null;

      // If no templates found in standard columns, try comprehensive search
      if ((leftTemplate == null || leftTemplate.isEmpty) &&
          (rightTemplate == null || rightTemplate.isEmpty)) {
        print(
            '[DB_DEBUG] No templates found in standard columns, trying comprehensive search...');
        final comprehensiveResult =
            await getFingerprintsComprehensive(learnerId);
        leftTemplate = comprehensiveResult['left'];
        rightTemplate = comprehensiveResult['right'];
      }

      // Debug logging
      print(
          '[DB_DEBUG] ZKTeco left template exists: ${zkLeft != null && zkLeft.isNotEmpty}');
      print(
          '[DB_DEBUG] ZKTeco right template exists: ${zkRight != null && zkRight.isNotEmpty}');
      print(
          '[DB_DEBUG] Futronic left template exists: ${futronicLeft != null && futronicLeft.isNotEmpty}');
      print(
          '[DB_DEBUG] Futronic right template exists: ${futronicRight != null && futronicRight.isNotEmpty}');
      print(
          '[DB_DEBUG] Final left template exists: ${leftTemplate != null && leftTemplate.isNotEmpty}');
      print(
          '[DB_DEBUG] Final right template exists: ${rightTemplate != null && rightTemplate.isNotEmpty}');

      return {
        'left': leftTemplate,
        'right': rightTemplate,
      };
    } else {
      print('[DB_DEBUG] No learner found with ID $learnerId');
    }
    return {'left': null, 'right': null};
  }

  Future<Map<String, dynamic>?> getInductionAttendanceForDay(
      String learnerId, String date) async {
    final db = await database;
    final result = await db.query(
      'induction_clocking',
      where: 'LearnerID = ? AND clock_date = ?',
      whereArgs: [learnerId, date],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first;
    }

    // Server fetch disabled - data is already synced via main sync endpoint
    // This prevents FormatException errors from broken get_indaction_data.php endpoint
    print(
        '[DB_HELPER] No local induction record found for LearnerID: $learnerId, date: $date');

    return null;
  }

  // Add this method for contact_less.dart
  Future<img.Image?> getFingerprintImage(int learnerId) async {
    final db = await database;
    final result = await db.query(
      'learnerdetails',
      columns: [
        'zkteco_left_template',
        'zkteco_right_template',
        'futronic_left_template',
        'futronic_right_template'
      ],
      where: 'LearnerID = ?',
      whereArgs: [learnerId],
    );
    if (result.isNotEmpty) {
      // Try to get any available template
      final zkLeft = result.first['zkteco_left_template'] as String?;
      final zkRight = result.first['zkteco_right_template'] as String?;
      final futronicLeft = result.first['futronic_left_template'] as String?;
      final futronicRight = result.first['futronic_right_template'] as String?;

      final template = (zkLeft != null && zkLeft.isNotEmpty)
          ? zkLeft
          : (zkRight != null && zkRight.isNotEmpty)
              ? zkRight
              : (futronicLeft != null && futronicLeft.isNotEmpty)
                  ? futronicLeft
                  : (futronicRight != null && futronicRight.isNotEmpty)
                      ? futronicRight
                      : null;

      if (template != null) {
        try {
          final bytes = base64Decode(template);
          return img.decodeImage(bytes);
        } catch (e) {
          print('Error decoding fingerprint image: $e');
          return null;
        }
      }
    }
    return null;
  }

  // Store fingerprint feature vector (as base64 string) for a learner
  Future<void> saveFingerprintFeatures(
      int learnerId, Uint8List featureBytes) async {
    final db = await database;
    final base64Features = base64Encode(featureBytes);
    await db.update(
      'learnerdetails',
      {
        'sourceafis_template': base64Features
      }, // Reusing the same column for feature vectors
      where: 'LearnerID = ?',
      whereArgs: [learnerId],
    );
  }

  // Retrieve fingerprint feature vector (as bytes) for a learner
  Future<Uint8List?> getFingerprintFeatures(int learnerId) async {
    final db = await database;
    final result = await db.query(
      'learnerdetails',
      columns: [
        'sourceafis_template'
      ], // Reusing the same column for feature vectors
      where: 'LearnerID = ?',
      whereArgs: [learnerId],
    );
    if (result.isNotEmpty && result.first['sourceafis_template'] != null) {
      final base64Str = result.first['sourceafis_template'] as String;
      try {
        return base64Decode(base64Str);
      } catch (e) {
        print('Error decoding fingerprint features: $e');
        return null;
      }
    }
    return null;
  }

  // DEPRECATED: Use getAllTemplates instead
  Future<Uint8List?> getIsLefthand(int learnerId) async {
    debugPrint(
        '[DEPRECATED] getIsLefthand called - use getAllTemplates instead');
    // This method is kept for backward compatibility but should not be used
    return null;
  }

  // Get sourceafis_template for a learner
  Future<Uint8List?> getSourceafisTemplate(int learnerId) async {
    final db = await database;
    final result = await db.query(
      'learnerdetails',
      columns: ['sourceafis_template'],
      where: 'LearnerID = ?',
      whereArgs: [learnerId],
    );
    if (result.isNotEmpty && result.first['sourceafis_template'] != null) {
      final base64Str = result.first['sourceafis_template'] as String;
      try {
        return base64Decode(base64Str);
      } catch (e) {
        print('Error decoding sourceafis_template: $e');
        return null;
      }
    }
    return null;
  }

  // Clear corrupted fingerprint templates for a learner
  Future<void> clearFingerprintTemplates(int learnerId) async {
    final db = await database;
    await db.update(
      'learnerdetails',
      {
        'zkteco_left_template': null,
        'zkteco_right_template': null,
        'futronic_left_template': null,
        'futronic_right_template': null,
        'sourceafis_template': null,
        'synced': 0
      },
      where: 'LearnerID = ?',
      whereArgs: [learnerId],
    );
    print('Cleared all fingerprint templates for learner $learnerId');
  }

  // ==================== RANDOM BIOMETRIC MONITORING METHODS ====================

  // Create monitoring table
  Future<void> createMonitoringTable() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS monitoring (
        monitoring_id INTEGER PRIMARY KEY AUTOINCREMENT,
        learner_id INTEGER NOT NULL,
        prompt_type TEXT NOT NULL DEFAULT 'random_biometric',
        prompt_time TEXT NOT NULL,
        countdown_duration INTEGER NOT NULL DEFAULT 180,
        status TEXT NOT NULL DEFAULT 'pending',
        verification_time TEXT,
        verification_method TEXT DEFAULT 'fingerprint',
        response_time TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (learner_id) REFERENCES learnerdetails(LearnerID)
      )
    ''');

    // Create indexes
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_monitoring_learner_status ON monitoring (learner_id, status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_monitoring_prompt_type ON monitoring (prompt_type, status)');
  }

  // Get random learners who are currently clocked in
  Future<List<Map<String, dynamic>>> getRandomClockedLearners(
      {int count = 2}) async {
    final db = await database;
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Get learners who are clocked in today
    final result = await db.rawQuery('''
      SELECT DISTINCT l.LearnerID, l.firstName, l.lastName, l.classID,
             c.clock_in_time, c.clock_out_time
      FROM learnerdetails l
      INNER JOIN clocking c ON l.LearnerID = c.LearnerID
      WHERE c.clock_date = ? 
        AND c.clock_in_time IS NOT NULL 
        AND c.clock_out_time IS NULL
        AND l.LearnerID NOT IN (
          SELECT learner_id FROM monitoring 
          WHERE prompt_time >= datetime('now', '-1 hour') 
            AND status = 'pending'
        )
      ORDER BY RANDOM()
      LIMIT ?
    ''', [now, count]);

    debugPrint('[MONITORING] Found ${result.length} random clocked learners');
    return result;
  }

  // Create random biometric prompt
  Future<int> createRandomPrompt(int learnerId,
      {int countdownDuration = 180}) async {
    final db = await database;
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final monitoringId = await db.insert('monitoring', {
      'learner_id': learnerId,
      'prompt_type': 'random_biometric',
      'prompt_time': now,
      'countdown_duration': countdownDuration,
      'status': 'pending',
    });

    debugPrint(
        '[MONITORING] Created random prompt for learner $learnerId, monitoring_id: $monitoringId');
    return monitoringId;
  }

  /// Update monitoring status with proper type conversion
  Future<void> updateMonitoringStatus(
    int monitoringId,
    String status, {
    int? responseTime,
  }) async {
    final db = await database;
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    // Build update data with proper string conversion for response_time
    final Map<String, dynamic> updateData = {
      'status': status,
      'verification_time': now,
      'verification_method': 'fingerprint',
      'updated_at': now,
      if (responseTime != null) 'response_time': '$responseTime',
    };

    await db.update(
      'monitoring',
      updateData,
      where: 'monitoring_id = ?',
      whereArgs: [monitoringId],
    );

    debugPrint(
        '[MONITORING] Updated monitoring_id $monitoringId status to $status');
  }

  // Get pending monitoring records
  Future<List<Map<String, dynamic>>> getPendingMonitoringRecords() async {
    final db = await database;

    final result = await db.query(
      'monitoring',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'prompt_time ASC',
    );

    return result;
  }

  // Check if learner has pending prompt
  Future<bool> hasPendingPrompt(int learnerId) async {
    final db = await database;

    final result = await db.query(
      'monitoring',
      columns: ['monitoring_id'],
      where: 'learner_id = ? AND status = ?',
      whereArgs: [learnerId, 'pending'],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // Get monitoring statistics
  Future<Map<String, dynamic>> getMonitoringStats() async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_prompts,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
        SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed,
        SUM(CASE WHEN status = 'timeout' THEN 1 ELSE 0 END) as timeout,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending,
        AVG(CASE WHEN response_time IS NOT NULL THEN response_time ELSE NULL END) as avg_response_time
      FROM monitoring
      WHERE prompt_time >= datetime('now', '-24 hours')
    ''');

    return result.isNotEmpty ? result.first : {};
  }

  // ==================== FACILITATOR FINGERPRINT METHODS ====================

  // Save facilitator fingerprint template (ZKTeco or Futronic) with server sync
  Future<bool> saveFacilitatorTemplate(int facilitatorId, String scannerType,
      String finger, String templateStr) async {
    try {
      final db = await database;

      // Determine column name based on scanner and finger
      String columnName;
      if (scannerType == 'zkteco') {
        columnName =
            finger == 'left' ? 'zkteco_left_template' : 'zkteco_right_template';
      } else if (scannerType == 'futronic') {
        columnName = finger == 'left'
            ? 'futronic_left_template'
            : 'futronic_right_template';
      } else {
        throw Exception('Unknown scanner type: $scannerType');
      }

      debugPrint(
          '[FAC_FP] Saving $scannerType $finger template for facilitator $facilitatorId (${templateStr.length} chars)');

      // Save template to local database first
      final updateResult = await db.update(
        'facilitator',
        {columnName: templateStr},
        where: 'facilitator_id = ?',
        whereArgs: [facilitatorId],
      );

      debugPrint('[FAC_FP] Update result: $updateResult rows affected');
      debugPrint(
          '[FAC_FP] Successfully saved $scannerType $finger template to local database');

      // Verify the template was saved
      final verifyResult = await db.query(
        'facilitator',
        columns: [columnName],
        where: 'facilitator_id = ?',
        whereArgs: [facilitatorId],
      );

      if (verifyResult.isNotEmpty) {
        final savedTemplate = verifyResult.first[columnName] as String?;
        debugPrint(
            '[FAC_FP] Template verification: ${savedTemplate != null ? 'SAVED (${savedTemplate.length} chars)' : 'NOT SAVED'}');
      } else {
        debugPrint(
            '[FAC_FP] ERROR: Facilitator not found after template save!');
      }

      // Try to sync to server
      bool synced = false;
      try {
        synced = await _syncFacilitatorTemplateToServer(
            facilitatorId, columnName, templateStr);
        if (synced) {
          debugPrint(
              '[FAC_FP] Successfully synced $columnName to server for facilitator $facilitatorId');
        } else {
          debugPrint(
              '[FAC_FP] Template saved locally, will sync to server later');
        }
      } catch (e) {
        debugPrint('[FAC_FP] Error syncing to server (saved locally): $e');
      }

      return synced;
    } catch (e) {
      print('[FAC_FP] Error saving facilitator fingerprint: $e');
      rethrow;
    }
  }

  // Sync facilitator fingerprint template to server
  Future<bool> _syncFacilitatorTemplateToServer(
      int facilitatorId, String templateType, String templateData) async {
    try {
      // Skip sync if template is empty
      if (templateData.isEmpty) {
        debugPrint(
            '[FAC_FP_SYNC] Skipping sync for empty template: $templateType for facilitator $facilitatorId');
        return false;
      }

      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.first == ConnectivityResult.none) {
        debugPrint('[FAC_FP_SYNC] No internet connection');
        return false;
      }

      // Prepare data for server
      final serverData = {
        'facilitator_id': facilitatorId,
        'template_type': templateType,
        'template_data': templateData,
      };

      final url =
          Uri.parse('${AppConfig.baseUrl}/sync_facilitator_fingerprint.php');

      debugPrint('[FAC_FP_SYNC] Syncing template to server: $url');
      debugPrint(
          '[FAC_FP_SYNC] Template type: $templateType, length: ${templateData.length}');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(serverData),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint(
              '[FAC_FP_SYNC] Server sync successful: ${result['message']}');
          return true;
        } else {
          debugPrint(
              '[FAC_FP_SYNC] Server returned error: ${result['message']}');
          return false;
        }
      } else {
        debugPrint(
            '[FAC_FP_SYNC] Server returned status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[FAC_FP_SYNC] Sync error: $e');
      return false;
    }
  }

  // Get all fingerprint templates for a facilitator
  Future<Map<String, String?>> getAllFacilitatorTemplates(
      int facilitatorId) async {
    final db = await database;

    debugPrint('[DB] Getting templates for facilitator_id: $facilitatorId');

    final result = await db.query(
      'facilitator',
      columns: [
        'facilitator_id',
        'zkteco_left_template',
        'zkteco_right_template',
        'futronic_left_template',
        'futronic_right_template'
      ],
      where: 'facilitator_id = ?',
      whereArgs: [facilitatorId],
    );

    debugPrint('[DB] Query result: $result');

    if (result.isNotEmpty) {
      final row = result.first;
      final templates = {
        'zkteco_left_template': row['zkteco_left_template'] as String?,
        'zkteco_right_template': row['zkteco_right_template'] as String?,
        'futronic_left_template': row['futronic_left_template'] as String?,
        'futronic_right_template': row['futronic_right_template'] as String?,
      };

      debugPrint('[DB] Retrieved templates: $templates');
      return templates;
    }

    debugPrint('[DB] No facilitator found with facilitator_id: $facilitatorId');
    return {
      'zkteco_left_template': null,
      'zkteco_right_template': null,
      'futronic_left_template': null,
      'futronic_right_template': null,
    };
  }

  // Get facilitator fingerprints (best available templates)
  Future<Map<String, String?>> getFacilitatorFingerprints(
      int facilitatorId) async {
    final db = await database;

    final result = await db.query(
      'facilitator',
      columns: [
        'zkteco_left_template',
        'zkteco_right_template',
        'futronic_left_template',
        'futronic_right_template'
      ],
      where: 'facilitator_id = ?',
      whereArgs: [facilitatorId],
    );

    if (result.isNotEmpty) {
      final row = result.first;

      final zkLeft = row['zkteco_left_template'] as String?;
      final zkRight = row['zkteco_right_template'] as String?;
      final futronicLeft = row['futronic_left_template'] as String?;
      final futronicRight = row['futronic_right_template'] as String?;

      // Prefer ZKTeco templates if available, otherwise use Futronic
      var leftTemplate = (zkLeft != null && zkLeft.isNotEmpty)
          ? zkLeft
          : (futronicLeft != null && futronicLeft.isNotEmpty)
              ? futronicLeft
              : null;
      var rightTemplate = (zkRight != null && zkRight.isNotEmpty)
          ? zkRight
          : (futronicRight != null && futronicRight.isNotEmpty)
              ? futronicRight
              : null;

      return {
        'left': leftTemplate,
        'right': rightTemplate,
      };
    }

    return {'left': null, 'right': null};
  }

  // ==================== FACILITATOR CLOCKING METHODS ====================

  // Insert facilitator clock-in record
  Future<void> insertFacilitatorClocking(Map<String, dynamic> row) async {
    final db = await database;

    // Check if a record already exists for this facilitator and date
    final existing = await db.query(
      'facilitator_clocking',
      where: 'facilitator_id = ? AND clock_date = ?',
      whereArgs: [row['facilitator_id'], row['clock_date']],
    );

    if (existing.isEmpty) {
      await db.insert('facilitator_clocking', row);
    } else {
      // Update the existing record instead
      await db.update(
        'facilitator_clocking',
        row,
        where: 'facilitator_id = ? AND clock_date = ?',
        whereArgs: [row['facilitator_id'], row['clock_date']],
      );
    }
  }

  // Get facilitator attendance for a specific day
  Future<Map<String, dynamic>?> getFacilitatorAttendanceForDay(
      String facilitatorId, String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'facilitator_clocking',
      where: 'facilitator_id = ? AND clock_date = ?',
      whereArgs: [facilitatorId, date],
      orderBy: 'clocking_id DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Update facilitator clocking record
  Future<void> updateFacilitatorClocking(
      int clockingId, Map<String, dynamic> row) async {
    final db = await database;
    await db.update(
      'facilitator_clocking',
      row,
      where: 'clocking_id = ?',
      whereArgs: [clockingId],
    );
  }

  // Check if facilitator has any fingerprints enrolled
  Future<bool> facilitatorHasFingerprints(int facilitatorId) async {
    final templates = await getAllFacilitatorTemplates(facilitatorId);

    return (templates['zkteco_left_template']?.isNotEmpty ?? false) ||
        (templates['zkteco_right_template']?.isNotEmpty ?? false) ||
        (templates['futronic_left_template']?.isNotEmpty ?? false) ||
        (templates['futronic_right_template']?.isNotEmpty ?? false);
  }

  // Check if facilitator has clocked in today
  Future<bool> facilitatorClockedInToday(int facilitatorId) async {
    try {
      // Use South African time (SAST - UTC+2)
      final saTime = DateTime.now().toUtc().add(const Duration(hours: 2));
      final today = DateFormat('yyyy-MM-dd').format(saTime);
      final attendance =
          await getFacilitatorAttendanceForDay(facilitatorId.toString(), today);

      if (attendance != null && attendance['clock_in_time'] != null) {
        final clockInTime = attendance['clock_in_time'].toString();
        debugPrint(
            '[FAC_CLOCK] Facilitator $facilitatorId clocked in today at $clockInTime');
        return clockInTime.isNotEmpty && clockInTime != 'null';
      }

      debugPrint(
          '[FAC_CLOCK] Facilitator $facilitatorId has NOT clocked in today');
      return false;
    } catch (e) {
      debugPrint('[FAC_CLOCK] Error checking clock-in status: $e');
      return false;
    }
  }

  // Get facilitator clock-in time for today
  Future<String?> getFacilitatorTodayClockIn(int facilitatorId) async {
    try {
      // Use South African time (SAST - UTC+2)
      final saTime = DateTime.now().toUtc().add(const Duration(hours: 2));
      final today = DateFormat('yyyy-MM-dd').format(saTime);
      final attendance =
          await getFacilitatorAttendanceForDay(facilitatorId.toString(), today);

      if (attendance != null && attendance['clock_in_time'] != null) {
        return attendance['clock_in_time'].toString();
      }
      return null;
    } catch (e) {
      debugPrint('[FAC_CLOCK] Error getting today clock-in: $e');
      return null;
    }
  }

  /// Generate neural network features from WSQ template for contactless verification
  // Future<void> _generateNeuralNetworkFeatures(int learnerId, String wsqTemplate) async {
  //   try {
  //     print('[NEURAL_GEN] Starting neural network feature generation for learner $learnerId');
  //
  //     // Check connectivity first
  //     final connectivityResult = await Connectivity().checkConnectivity();
  //     if (connectivityResult == ConnectivityResult.none) {
  //       print('[NEURAL_GEN] No internet connection - neural features will be generated during first contactless verification');
  //       return;
  //     }
  //
  //     // Find a working server URL
  //     List<String> serverUrls = [
  //       'http://10.0.2.2:5001',
  //       'http://192.168.68.105:5001',
  //       'http://localhost:5001',
  //       'http://127.0.0.1:5001'
  //     ];
  //
  //     String? workingUrl;
  //     for (String url in serverUrls) {
  //       try {
  //         final healthResponse = await http.get(
  //           Uri.parse('$url/health'),
  //           headers: {'Content-Type': 'application/json'},
  //         ).timeout(Duration(seconds: 5));
  //
  //         if (healthResponse.statusCode == 200) {
  //           workingUrl = url;
  //           print('[NEURAL_GEN] Found working server: $url');
  //           break;
  //         }
  //       } catch (e) {
  //         print('[NEURAL_GEN] Server $url not reachable: $e');
  //         continue;
  //       }
  //     }
  //
  //     if (workingUrl == null) {
  //       print('[NEURAL_GEN] No servers available - neural features will be generated during first contactless verification');
  //       return;
  //     }
  //
  //     print('[NEURAL_GEN] Sending WSQ template to server for neural feature extraction...');
  //
  //     // Send WSQ template to server for neural network feature extraction
  //     final response = await http.post(
  //       Uri.parse('$workingUrl/extract'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: json.encode({
  //         'LearnerID': learnerId,
  //         'image_base64': wsqTemplate,  // WSQ template as base64
  //       }),
  //     ).timeout(Duration(seconds: 30));
  //
  //     if (response.statusCode == 200) {
  //       final responseData = json.decode(response.body);
  //       if (responseData['success'] == true) {
  //         print('[NEURAL_GEN] ✅ Neural network features generated successfully for learner $learnerId');
  //         print('[NEURAL_GEN] Feature dimensions: ${responseData['feature_dimensions']}');
  //
  //         // Save the neural features to local SQLite database
  //         final featuresBase64 = responseData['features_base64'] as String;
  //         final featuresBytes = base64Decode(featuresBase64);
  //
  //         print('[NEURAL_GEN] Saving ${featuresBytes.length} bytes of neural features to local database...');
  //         await saveFingerprintFeatures(learnerId, featuresBytes);
  //
  //         // Verify the save
  //         final savedFeatures = await getFingerprintFeatures(learnerId);
  //         if (savedFeatures != null) {
  //           print('[NEURAL_GEN] ✅ Confirmed: ${savedFeatures.length} bytes saved to local database');
  //         } else {
  //           print('[NEURAL_GEN] ⚠️ Warning: Features not found in local database after save');
  //         }
  //
  //       } else {
  //         print('[NEURAL_GEN] ❌ Server failed to generate features: ${responseData['error']}');
  //       }
  //     } else {
  //       print('[NEURAL_GEN] ❌ Server returned status ${response.statusCode}: ${response.body}');
  //     }
  //
  //   } catch (e) {
  //     print('[NEURAL_GEN] ❌ Error generating neural network features: $e');
  //     // Don't throw - this is optional enhancement, main enrollment should still succeed
  //   }
  // }

  // Sync unsynced fingerprints to server
  Future<void> syncUnsyncedFingerprints() async {
    try {
      final db = await database;

      // Get unsynced fingerprints using the new template columns
      debugPrint('[SYNC] Querying for unsynced fingerprints...');
      final fingerprints = await db.query(
        'learnerdetails',
        where:
            'synced = ? AND (zkteco_left_template IS NOT NULL OR zkteco_right_template IS NOT NULL OR futronic_left_template IS NOT NULL OR futronic_right_template IS NOT NULL)',
        whereArgs: [0],
      );

      // Also query to see what synced status looks like
      final allFingerprints = await db.query(
        'learnerdetails',
        columns: [
          'LearnerID',
          'synced',
          'zkteco_left_template',
          'zkteco_right_template',
          'futronic_left_template',
          'futronic_right_template'
        ],
        where:
            'zkteco_left_template IS NOT NULL OR zkteco_right_template IS NOT NULL OR futronic_left_template IS NOT NULL OR futronic_right_template IS NOT NULL',
      );

      debugPrint(
          '[SYNC] Total learners with fingerprint templates: ${allFingerprints.length}');
      for (final fp in allFingerprints.take(5)) {
        debugPrint(
            '[SYNC] Learner ${fp['LearnerID']}: synced=${fp['synced']}, zkteco_left=${fp['zkteco_left_template'] != null}, zkteco_right=${fp['zkteco_right_template'] != null}, futronic_left=${fp['futronic_left_template'] != null}, futronic_right=${fp['futronic_right_template'] != null}');
      }

      print('Found ${fingerprints.length} unsynced fingerprints');

      for (final fingerprint in fingerprints) {
        final learnerId = fingerprint['LearnerID'] as int;
        print('Syncing fingerprints for learner: $learnerId');
        print(
            '  - ZKTeco left template exists: ${fingerprint['zkteco_left_template'] != null}');
        print(
            '  - ZKTeco right template exists: ${fingerprint['zkteco_right_template'] != null}');
        print(
            '  - Futronic left template exists: ${fingerprint['futronic_left_template'] != null}');
        print(
            '  - Futronic right template exists: ${fingerprint['futronic_right_template'] != null}');

        // Check which templates exist and are not empty
        bool hasZkTecoLeft = fingerprint['zkteco_left_template'] != null &&
            (fingerprint['zkteco_left_template'] as String).isNotEmpty;
        bool hasZkTecoRight = fingerprint['zkteco_right_template'] != null &&
            (fingerprint['zkteco_right_template'] as String).isNotEmpty;
        bool hasFutronicLeft = fingerprint['futronic_left_template'] != null &&
            (fingerprint['futronic_left_template'] as String).isNotEmpty;
        bool hasFutronicRight =
            fingerprint['futronic_right_template'] != null &&
                (fingerprint['futronic_right_template'] as String).isNotEmpty;

        List<String> syncErrors = [];
        int successfulSyncs = 0;

        // Sync each template that exists - continue even if one fails
        if (hasZkTecoLeft) {
          try {
            debugPrint(
                '[SYNC] Syncing ZKTeco left template, length: ${(fingerprint['zkteco_left_template'] as String).length}');
            await _syncSingleTemplate(learnerId, 'zkteco_left',
                fingerprint['zkteco_left_template'] as String);
            successfulSyncs++;
            debugPrint('[SYNC] ZKTeco left template synced successfully');
          } catch (e) {
            syncErrors.add('ZKTeco left: $e');
            debugPrint('[SYNC] Failed to sync ZKTeco left template: $e');
          }
        }

        if (hasZkTecoRight) {
          try {
            debugPrint(
                '[SYNC] Syncing ZKTeco right template, length: ${(fingerprint['zkteco_right_template'] as String).length}');
            await _syncSingleTemplate(learnerId, 'zkteco_right',
                fingerprint['zkteco_right_template'] as String);
            successfulSyncs++;
            debugPrint('[SYNC] ZKTeco right template synced successfully');
          } catch (e) {
            syncErrors.add('ZKTeco right: $e');
            debugPrint('[SYNC] Failed to sync ZKTeco right template: $e');
          }
        }

        if (hasFutronicLeft) {
          try {
            debugPrint(
                '[SYNC] Syncing Futronic left template, length: ${(fingerprint['futronic_left_template'] as String).length}');
            await _syncSingleTemplate(learnerId, 'futronic_left',
                fingerprint['futronic_left_template'] as String);
            successfulSyncs++;
            debugPrint('[SYNC] Futronic left template synced successfully');
          } catch (e) {
            syncErrors.add('Futronic left: $e');
            debugPrint('[SYNC] Failed to sync Futronic left template: $e');
          }
        }

        if (hasFutronicRight) {
          try {
            debugPrint(
                '[SYNC] Syncing Futronic right template, length: ${(fingerprint['futronic_right_template'] as String).length}');
            await _syncSingleTemplate(learnerId, 'futronic_right',
                fingerprint['futronic_right_template'] as String);
            successfulSyncs++;
            debugPrint('[SYNC] Futronic right template synced successfully');
          } catch (e) {
            syncErrors.add('Futronic right: $e');
            debugPrint('[SYNC] Failed to sync Futronic right template: $e');
          }
        }

        // Mark as synced if at least one template was successfully synced
        if (successfulSyncs > 0) {
          await db.update(
            'learnerdetails',
            {'synced': 1},
            where: 'LearnerID = ?',
            whereArgs: [learnerId],
          );
          print(
              'Marked learner $learnerId as synced ($successfulSyncs templates synced successfully)');
        }

        // Log any errors but don't stop the overall sync
        if (syncErrors.isNotEmpty) {
          print('Sync errors for learner $learnerId: ${syncErrors.join(', ')}');
        }
      }

      print('Fingerprint sync completed');
    } catch (e) {
      print('Error during fingerprint sync: $e');
    }
  }

  Future<void> _syncSingleTemplate(
      int learnerId, String templateType, String template) async {
    try {
      debugPrint(
          '[SYNC] Starting sync for learner $learnerId, type: $templateType');
      debugPrint('[SYNC] Template length: ${template.length}');
      debugPrint(
          '[SYNC] Template preview: ${template.isNotEmpty ? template.substring(0, template.length > 50 ? 50 : template.length) : 'EMPTY'}...');
      debugPrint('[SYNC] Template is empty: ${template.isEmpty}');

      // Skip sync if template is empty
      if (template.isEmpty) {
        debugPrint(
            '[SYNC] Skipping sync for empty template: $templateType for learner $learnerId');
        return;
      }

      final response = await http.post(
        Uri.parse(AppConfig.buildUrl('sync_fingerprint.php')),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization':
              'Bearer rlmss_2025_8e7d2f6e-3c4b-4c8f-b1e6-4a01a1b2e9f7',
        },
        body: {
          'learner_id': learnerId.toString(),
          'template_type':
              templateType, // e.g., 'zkteco_left', 'futronic_right'
          'template': template,
        },
      ).timeout(const Duration(seconds: 15)); // Add timeout

      debugPrint('[SYNC] Response status: ${response.statusCode}');
      debugPrint('[SYNC] Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            debugPrint(
                '[SYNC] Successfully synced $templateType template for learner $learnerId');
            print(
                'Successfully synced $templateType template for learner $learnerId');
          } else {
            debugPrint(
                '[SYNC] Server error syncing $templateType for learner $learnerId: ${data['message']}');
            print(
                'Server error syncing $templateType for learner $learnerId: ${data['message']}');
            throw Exception('Server error: ${data['message']}');
          }
        } catch (jsonError) {
          debugPrint('[SYNC] JSON parse error: $jsonError');
          debugPrint('[SYNC] Raw response: ${response.body}');
          throw Exception('Invalid JSON response: ${response.body}');
        }
      } else {
        debugPrint('[SYNC] HTTP error: ${response.statusCode}');
        debugPrint('[SYNC] Response body: ${response.body}');
        throw Exception(
            'HTTP error: ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException catch (e) {
      debugPrint(
          '[SYNC] Timeout syncing $templateType for learner $learnerId: $e');
      throw Exception('Sync timeout: $e');
    } catch (e) {
      debugPrint(
          '[SYNC] Exception syncing $templateType for learner $learnerId: $e');
      print('Exception syncing $templateType for learner $learnerId: $e');
      rethrow;
    }
  }

  // Start background fingerprint sync service
  Future<void> startFingerprintSyncService() async {
    // Check for unsynced fingerprints every 30 seconds when internet is available
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult != ConnectivityResult.none) {
          await syncUnsyncedFingerprints();
        }
      } catch (e) {
        print('Error in background fingerprint sync: $e');
      }
    });
  }

  Future<void> updateLearnerLocally(
      String learnerID, Map<String, dynamic> updateData) async {
    try {
      final db = await database;

      // learnerdetails uses DateOfBirth — there is no DOB column locally.
      updateData.remove('DOB');

      // Add synced status to indicate this needs to be synced later
      updateData['synced'] = 0;

      await db.update(
        'learnerdetails',
        updateData,
        where: 'LearnerID = ?',
        whereArgs: [learnerID],
      );

      print('Learner information updated locally for learner ID: $learnerID');
      print('Updated fields: ${updateData.keys.toList()}');
    } catch (e) {
      print('Error updating learner information locally: $e');
      throw Exception('Failed to update learner information locally: $e');
    }
  }

  // Save ZKTeco template (left or right)
  Future<void> saveZkTecoTemplate(int learnerId, String? template,
      {required bool isLeft}) async {
    final db = await database;
    await db.update(
      'learnerdetails',
      isLeft
          ? {'zkteco_left_template': template, 'synced': 0}
          : {'zkteco_right_template': template, 'synced': 0},
      where: 'LearnerID = ?',
      whereArgs: [learnerId],
    );
    debugPrint(
        '[SAVE] Marked learner $learnerId as unsynced after saving ${isLeft ? 'left' : 'right'} ZKTeco template');
  }

  // Save Futronic template (left or right)
  Future<void> saveFutronicTemplate(int learnerId, String? template,
      {required bool isLeft}) async {
    final db = await database;
    await db.update(
      'learnerdetails',
      isLeft
          ? {'futronic_left_template': template, 'synced': 0}
          : {'futronic_right_template': template, 'synced': 0},
      where: 'LearnerID = ?',
      whereArgs: [learnerId],
    );
    debugPrint(
        '[SAVE] Marked learner $learnerId as unsynced after saving ${isLeft ? 'left' : 'right'} Futronic template');
  }

  // Get all templates for a learner (both ZKTeco and Futronic)
  Future<Map<String, String?>> getAllTemplates(int learnerId) async {
    final db = await database;
    final result = await db.query(
      'learnerdetails',
      columns: [
        'zkteco_left_template',
        'zkteco_right_template',
        'futronic_left_template',
        'futronic_right_template'
      ],
      where: 'LearnerID = ?',
      whereArgs: [learnerId],
    );

    if (result.isNotEmpty) {
      return {
        'zkteco_left_template': result.first['zkteco_left_template'] as String?,
        'zkteco_right_template':
            result.first['zkteco_right_template'] as String?,
        'futronic_left_template':
            result.first['futronic_left_template'] as String?,
        'futronic_right_template':
            result.first['futronic_right_template'] as String?,
      };
    }
    return {
      'zkteco_left_template': null,
      'zkteco_right_template': null,
      'futronic_left_template': null,
      'futronic_right_template': null,
    };
  }

  // ==================== POTHOLE CHECKLIST SCANNED DOCUMENTS ====================

  /// Save scanned document for pothole checklist
  Future<int> saveScannedPotholeChecklist({
    required String learnerId,
    required String assessorId,
    required String documentPath,
    required String assessmentDate,
  }) async {
    final db = await database;
    return await db.insert(
      'pothole_checklist_scanned_documents',
      {
        'learner_id': learnerId,
        'assessor_id': assessorId,
        'document_path': documentPath,
        'assessment_date': assessmentDate,
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get scanned document for a specific learner and assessor
  Future<Map<String, dynamic>?> getScannedPotholeChecklist({
    required String learnerId,
    required String assessorId,
    required String assessmentDate,
  }) async {
    final db = await database;
    final results = await db.query(
      'pothole_checklist_scanned_documents',
      where: 'learner_id = ? AND assessor_id = ? AND assessment_date = ?',
      whereArgs: [learnerId, assessorId, assessmentDate],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  /// Check if checklist exists (either scanned or system-generated)
  Future<Map<String, dynamic>> checkPotholeChecklistStatus({
    required String learnerId,
    required String assessorId,
    required String assessmentDate,
  }) async {
    // Check for scanned document
    final scannedDoc = await getScannedPotholeChecklist(
      learnerId: learnerId,
      assessorId: assessorId,
      assessmentDate: assessmentDate,
    );

    if (scannedDoc != null) {
      return {
        'exists': true,
        'type': 'scanned',
        'data': scannedDoc,
      };
    }

    // Check for system-generated checklist (from server)
    // This will be checked via API call in the UI
    return {
      'exists': false,
      'type': 'none',
      'data': null,
    };
  }

  /// Get all unsynced scanned documents
  Future<List<Map<String, dynamic>>> getUnsyncedScannedChecklists() async {
    final db = await database;
    return await db.query(
      'pothole_checklist_scanned_documents',
      where: 'synced = ?',
      whereArgs: [0],
    );
  }

  /// Mark scanned document as synced
  Future<void> markScannedChecklistAsSynced(int id) async {
    final db = await database;
    await db.update(
      'pothole_checklist_scanned_documents',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete scanned document
  Future<void> deleteScannedPotholeChecklist(int id) async {
    final db = await database;
    await db.delete(
      'pothole_checklist_scanned_documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Guardian methods
  Future<void> saveGuardianDetails(Map<String, dynamic> guardianData) async {
    try {
      final db = await database;

      // Check if guardian record exists
      final existing = await db.query(
        'guardian_details',
        where: 'learner_id = ?',
        whereArgs: [guardianData['learner_id']],
      );

      if (existing.isNotEmpty) {
        // Update existing record
        await db.update(
          'guardian_details',
          {
            ...guardianData,
            'updated_at': DateTime.now().toIso8601String(),
            'synced': 0,
          },
          where: 'learner_id = ?',
          whereArgs: [guardianData['learner_id']],
        );
        print(
            'Guardian details updated for learner ${guardianData['learner_id']}');
      } else {
        // Insert new record
        await db.insert(
          'guardian_details',
          {
            ...guardianData,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'synced': 0,
          },
        );
        print(
            'Guardian details inserted for learner ${guardianData['learner_id']}');
      }
    } catch (e) {
      print('Error saving guardian details: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchGuardianDetails(int learnerID) async {
    try {
      final db = await database;
      final result = await db.query(
        'guardian_details',
        where: 'learner_id = ?',
        whereArgs: [learnerID],
      );

      if (result.isNotEmpty) {
        print('Guardian details found for learner $learnerID');
        return result.first;
      } else {
        print('No guardian details found for learner $learnerID');
        return null;
      }
    } catch (e) {
      print('Error fetching guardian details: $e');
      return null;
    }
  }

  // ========================================
  // WORK EXPERIENCE METHODS
  // ========================================

  Future<List<Map<String, dynamic>>> getWorkExperiences(
      String learnerID) async {
    try {
      final db = await database;
      final result = await db.query(
        'work_experience',
        where: 'learner_id = ?',
        whereArgs: [learnerID],
        orderBy: 'period_from DESC',
      );
      print(
          '[WORK_EXP] Found ${result.length} work experiences for learner $learnerID');
      return result;
    } catch (e) {
      print('[WORK_EXP] Error fetching work experiences: $e');
      return [];
    }
  }

  Future<int> insertWorkExperience(Map<String, dynamic> data) async {
    try {
      final db = await database;
      data['created_at'] = DateTime.now().toIso8601String();
      data['updated_at'] = DateTime.now().toIso8601String();
      final id = await db.insert('work_experience', data);
      print('[WORK_EXP] Inserted work experience with ID: $id');
      return id;
    } catch (e) {
      print('[WORK_EXP] Error inserting work experience: $e');
      rethrow;
    }
  }

  Future<void> updateWorkExperience(Map<String, dynamic> data) async {
    try {
      final db = await database;
      data['updated_at'] = DateTime.now().toIso8601String();
      final id = data['id'];
      await db.update(
        'work_experience',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
      print('[WORK_EXP] Updated work experience ID: $id');
    } catch (e) {
      print('[WORK_EXP] Error updating work experience: $e');
      rethrow;
    }
  }

  Future<void> deleteWorkExperience(int id) async {
    try {
      final db = await database;
      await db.delete(
        'work_experience',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('[WORK_EXP] Deleted work experience ID: $id');
    } catch (e) {
      print('[WORK_EXP] Error deleting work experience: $e');
      rethrow;
    }
  }

  Future<void> markWorkExperienceSynced(int id) async {
    try {
      final db = await database;
      await db.update(
        'work_experience',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      print('[WORK_EXP] Marked work experience ID $id as synced');
    } catch (e) {
      print('[WORK_EXP] Error marking work experience as synced: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUnsyncedWorkExperiences() async {
    try {
      final db = await database;
      final result = await db.query(
        'work_experience',
        where: 'synced = ?',
        whereArgs: [0],
      );
      print('[WORK_EXP] Found ${result.length} unsynced work experiences');
      return result;
    } catch (e) {
      print('[WORK_EXP] Error fetching unsynced work experiences: $e');
      return [];
    }
  }

  /// Fetch every learner linked to the supplied SDP (identifier can be id or name).
  Future<List<Map<String, dynamic>>> getLearnersBySdp(
      String sdpIdentifier) async {
    final db = await database;
    final identifier = sdpIdentifier.trim();

    if (identifier.isEmpty) {
      throw Exception('SDP identifier is required to load learners.');
    }

    final int? parsedId = int.tryParse(identifier);
    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (parsedId != null) {
      whereClauses.add('site.sdp_id = ?');
      whereArgs.add(parsedId);
    }

    whereClauses.add('LOWER(COALESCE(s.sdp_name, "")) = LOWER(?)');
    whereArgs.add(identifier);

    final whereStatement =
        whereClauses.map((clause) => '($clause)').join(' OR ');

    final query = '''
      SELECT 
        l.LearnerID,
        l.Name,
        l.Surname,
        l.IDNumber,
        l.classID,
        c.className,
        site.siteID,
        site.siteName,
        COALESCE(s.sdp_name, ?) AS sdp_name
      FROM learnerdetails l
      LEFT JOIN class c ON l.classID = c.classID
      LEFT JOIN sites site ON c.siteID = site.siteID
      LEFT JOIN sdp s ON site.sdp_id = s.sdp_id
      WHERE $whereStatement
      ORDER BY 
        c.className COLLATE NOCASE ASC,
        l.Surname COLLATE NOCASE ASC,
        l.Name COLLATE NOCASE ASC
    ''';

    return await db.rawQuery(query, [...whereArgs, identifier]);
  }

  // Get unit standards for a class using efficient SQLite JSON operators
  Future<List<Map<String, dynamic>>> getClassUnitStandards(
      String classID) async {
    final db = await database;

    try {
      print('\n=== GETTING CLASS UNIT STANDARDS (SQLite) ===');
      print('ClassID: $classID');

      // Use SQLite JSON operators to extract unit standards directly
      var result = await db.rawQuery('''
        SELECT 
          c.classID,
          c.className,
          s.project_id,
          pr.Project_pathway->'\$[0].name' AS pathway_name,
          pr.Project_pathway->'\$[0].qual_types[0].qualification.name' AS qualification_name,
          pr.Project_pathway->'\$[0].qual_types[0].qualification.unitStandards' AS unit_standards
        FROM class c
        LEFT JOIN sites s ON c.siteID = s.siteID
        LEFT JOIN project pr ON s.project_id = pr.project_id
        WHERE c.classID = ?
      ''', [classID]);

      print('Raw query results (count: ${result.length}):');
      for (var row in result) {
        print('Row: $row');
      }

      List<Map<String, dynamic>> processedResult = [];

      // Process query results
      for (var row in result) {
        String? unitStandardsJson = row['unit_standards'] as String?;

        // Create a new map for the row
        Map<String, dynamic> enrichedRow = Map<String, dynamic>.from(row);

        // Initialize default values
        enrichedRow['unit_standards_list'] = [];

        if (unitStandardsJson != null &&
            unitStandardsJson.isNotEmpty &&
            unitStandardsJson.startsWith('[')) {
          try {
            List<dynamic> unitStandards = jsonDecode(unitStandardsJson);
            enrichedRow['unit_standards_list'] = unitStandards;

            print('✅ Parsed ${unitStandards.length} unit standards from JSON');

            // Process each unit standard to ensure proper format
            List<Map<String, dynamic>> formattedUnitStandards = [];
            for (var us in unitStandards) {
              formattedUnitStandards.add({
                'unitstandard_id': us['id']?.toString() ?? '',
                'unit_standard_name':
                    us['name']?.toString() ?? 'Unknown Unit Standard',
                'qualification_id': us['qualification_id']?.toString() ?? '',
                'level': us['level']?.toString() ?? '',
                'credits': us['credits']?.toString() ?? '',
                'description': us['description']?.toString() ?? '',
              });
            }

            enrichedRow['formatted_unit_standards'] = formattedUnitStandards;

            print(
                'Formatted unit standards: ${formattedUnitStandards.length} items');
            for (int i = 0; i < formattedUnitStandards.length && i < 3; i++) {
              print(
                  '  - ${formattedUnitStandards[i]['unitstandard_id']}: ${formattedUnitStandards[i]['unit_standard_name']}');
            }
          } catch (e) {
            print(
                '❌ JSON parsing error: $e, for unit_standards: $unitStandardsJson');
            enrichedRow['unit_standards_list'] = [];
            enrichedRow['formatted_unit_standards'] = [];
          }
        } else {
          print('❌ Invalid or empty unit_standards: $unitStandardsJson');
          enrichedRow['formatted_unit_standards'] = [];
        }

        processedResult.add(enrichedRow);
      }

      print('=== CLASS UNIT STANDARDS FETCH COMPLETE ===\n');
      return processedResult;
    } catch (e) {
      print('❌ Error fetching class unit standards: $e');
      return [];
    }
  }

  // Methods for SDP learner syncing
  Future<Map<String, dynamic>?> getLearnerById(dynamic learnerId) async {
    try {
      final db = await database;
      final results = await db.query(
        'learnerdetails',
        where: 'LearnerID = ?',
        whereArgs: [learnerId],
        limit: 1,
      );

      if (results.isNotEmpty) {
        return results.first;
      }
      return null;
    } catch (e) {
      print('Error getting learner by ID: $e');
      return null;
    }
  }

  Future<void> insertLearner(Map<String, dynamic> learnerData) async {
    try {
      final db = await database;

      // Ensure required fields have default values
      final sanitizedData = Map<String, dynamic>.from(learnerData);
      sanitizedData['synced'] = sanitizedData['synced'] ??
          1; // Mark as synced since it came from server
      sanitizedData['created_at'] =
          sanitizedData['created_at'] ?? DateTime.now().toIso8601String();

      await db.insert(
        'learnerdetails',
        sanitizedData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('Inserted learner: ${sanitizedData['LearnerID']}');
    } catch (e) {
      print('Error inserting learner: $e');
      rethrow;
    }
  }

  Future<void> updateLearner(Map<String, dynamic> learnerData) async {
    try {
      final db = await database;

      // Ensure synced status is maintained
      final sanitizedData = Map<String, dynamic>.from(learnerData);
      sanitizedData['synced'] = sanitizedData['synced'] ??
          1; // Mark as synced since it came from server
      sanitizedData['updated_at'] = DateTime.now().toIso8601String();

      await db.update(
        'learnerdetails',
        sanitizedData,
        where: 'LearnerID = ?',
        whereArgs: [learnerData['LearnerID']],
      );

      print('Updated learner: ${sanitizedData['LearnerID']}');
    } catch (e) {
      print('Error updating learner: $e');
      rethrow;
    }
  }
}
