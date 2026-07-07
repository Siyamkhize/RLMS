import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../database_helper.dart';
import '../config.dart';
import 'database_coordinator.dart';

/// Persistent Sync Service for Offline-First Architecture
/// Ensures learner data is always available locally for offline clocking
class PersistentSyncService {
  static final PersistentSyncService _instance =
      PersistentSyncService._internal();
  factory PersistentSyncService() => _instance;
  PersistentSyncService._internal();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicSyncTimer;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  final DatabaseCoordinator _coordinator = DatabaseCoordinator();

  /// Start listening for connectivity changes and trigger auto-sync
  void startAutoSync() {
    print('[PERSISTENT_SYNC] Starting auto-sync service');

    // Listen for connectivity changes
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      if (result != ConnectivityResult.none) {
        print('[PERSISTENT_SYNC] Connectivity restored: $result');
        _triggerBackgroundSync();
      }
    });

    // Periodic sync every 30 minutes when online (reduced frequency to prevent conflicts)
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _triggerBackgroundSync();
    });
  }

  /// Stop auto-sync service
  void stopAutoSync() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    print('[PERSISTENT_SYNC] Auto-sync service stopped');
  }

  /// Trigger background sync (non-blocking)
  Future<void> _triggerBackgroundSync() async {
    // Check if enough time has passed since last sync
    if (!_coordinator.shouldAllowSync(
        minInterval: const Duration(minutes: 2))) {
      print('[PERSISTENT_SYNC] Skipping sync - too soon since last sync');
      return;
    }

    // Check connectivity first to avoid unnecessary work
    final connectivityResult = await Connectivity().checkConnectivity();
    final isConnected = connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none;

    if (!isConnected) {
      print('[PERSISTENT_SYNC] No connectivity, skipping sync');
      return;
    }

    try {
      await _coordinator.executeSyncOperation(
        'PersistentSyncService.syncAllData',
        () async {
          await syncAllData();
          _lastSyncTime = DateTime.now();
        },
        timeout: const Duration(minutes: 5),
      );
    } catch (e) {
      print('[PERSISTENT_SYNC] Background sync failed: $e');
    }
  }

  /// Sync all data (learners, clocking records, etc.)
  Future<SyncResult> syncAllData() async {
    print('[PERSISTENT_SYNC] Starting full data sync');

    final result = SyncResult();

    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      if (!isConnected) {
        result.success = false;
        result.message = 'No internet connection';
        return result;
      }

      final dbHelper = DatabaseHelper();

      // 1. Sync learners for all classes
      await _syncAllLearners(dbHelper, result);

      // 2. Sync offline clocking records
      await _syncOfflineClockingRecords(dbHelper, result);

      // 3. Sync other pending data
      await _syncOtherPendingData(dbHelper, result);

      result.success = true;
      result.message = 'Sync completed successfully';
      print('[PERSISTENT_SYNC] Full sync completed: ${result.message}');
    } catch (e) {
      result.success = false;
      result.message = 'Sync failed: $e';
      print('[PERSISTENT_SYNC] Sync error: $e');
    }

    return result;
  }

  /// Sync learners for all classes in local database
  Future<void> _syncAllLearners(
      DatabaseHelper dbHelper, SyncResult result) async {
    try {
      final db = await dbHelper.database;

      // Get all unique class IDs from local database
      final classes = await db.rawQuery(
          'SELECT DISTINCT classID FROM learnerdetails WHERE classID IS NOT NULL');

      print('[PERSISTENT_SYNC] Found ${classes.length} classes to sync');

      for (var classRow in classes) {
        final classID = classRow['classID']?.toString();
        if (classID != null && classID.isNotEmpty) {
          try {
            await _syncLearnersForClass(classID, dbHelper);
            result.learnersSynced++;
          } catch (e) {
            print('[PERSISTENT_SYNC] Failed to sync class $classID: $e');
            result.errors.add('Class $classID: $e');
          }
        }
      }
    } catch (e) {
      print('[PERSISTENT_SYNC] Error syncing learners: $e');
      result.errors.add('Learners sync: $e');
    }
  }

  /// Sync learners for a specific class using UPSERT logic
  Future<void> _syncLearnersForClass(
      String classID, DatabaseHelper dbHelper) async {
    print('[PERSISTENT_SYNC] Syncing learners for class: $classID');

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.getLearnersUrl}?classID=$classID'),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final List<dynamic> serverLearners = json.decode(response.body);
      print(
          '[PERSISTENT_SYNC] Received ${serverLearners.length} learners from server for class $classID');

      final db = await dbHelper.database;

      // Use shorter transactions to prevent database locks
      // Process learners in batches of 10 to avoid long-running transactions
      const batchSize = 10;
      for (int i = 0; i < serverLearners.length; i += batchSize) {
        final batch = serverLearners.skip(i).take(batchSize).toList();

        await db.transaction((txn) async {
          for (var learner in batch) {
            final learnerID = learner['LearnerID']?.toString();
            if (learnerID == null || learnerID.isEmpty) continue;

            // Check if learner exists
            final existing = await txn.query(
              'learnerdetails',
              where: 'LearnerID = ?',
              whereArgs: [learnerID],
            );

            // Prepare learner data
            final learnerData = {
              'LearnerID': learnerID,
              'Name': learner['Name']?.toString() ?? '',
              'Surname': learner['Surname']?.toString() ?? '',
              'IDNumber': learner['IDNumber']?.toString() ?? '',
              'DateOfBirth': learner['DateOfBirth']?.toString() ?? '',
              'PhoneNumber': learner['PhoneNumber']?.toString() ?? '',
              'Email': learner['Email']?.toString() ?? '',
              'Title': learner['Title']?.toString() ?? '',
              'classID': classID,
              'synced': 1,
              // Preserve fingerprint templates from server
              'zkteco_left_template':
                  learner['zkteco_left_template']?.toString() ?? '',
              'zkteco_right_template':
                  learner['zkteco_right_template']?.toString() ?? '',
              'futronic_left_template':
                  learner['futronic_left_template']?.toString() ?? '',
              'futronic_right_template':
                  learner['futronic_right_template']?.toString() ?? '',
              'sourceafis_template':
                  learner['sourceafis_template']?.toString() ?? '',
            };

            if (existing.isEmpty) {
              // Insert new learner
              await txn.insert('learnerdetails', learnerData);
              print('[PERSISTENT_SYNC] Inserted new learner: $learnerID');
            } else {
              // Update existing learner (merge with local data)
              final existingData = existing.first;

              // Preserve local fingerprint templates if server doesn't have them
              if (learnerData['zkteco_left_template']!.toString().isEmpty &&
                  existingData['zkteco_left_template'] != null) {
                learnerData['zkteco_left_template'] =
                    existingData['zkteco_left_template'].toString();
              }
              if (learnerData['zkteco_right_template']!.toString().isEmpty &&
                  existingData['zkteco_right_template'] != null) {
                learnerData['zkteco_right_template'] =
                    existingData['zkteco_right_template'].toString();
              }
              if (learnerData['futronic_left_template']!.toString().isEmpty &&
                  existingData['futronic_left_template'] != null) {
                learnerData['futronic_left_template'] =
                    existingData['futronic_left_template'].toString();
              }
              if (learnerData['futronic_right_template']!.toString().isEmpty &&
                  existingData['futronic_right_template'] != null) {
                learnerData['futronic_right_template'] =
                    existingData['futronic_right_template'].toString();
              }

              await txn.update(
                'learnerdetails',
                learnerData,
                where: 'LearnerID = ?',
                whereArgs: [learnerID],
              );
              print('[PERSISTENT_SYNC] Updated learner: $learnerID');
            }
          }
        }).timeout(const Duration(seconds: 5)); // Add timeout to prevent locks

        // Small delay between batches to allow other operations
        if (i + batchSize < serverLearners.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      print(
          '[PERSISTENT_SYNC] Successfully synced ${serverLearners.length} learners for class $classID');
    } catch (e) {
      print('[PERSISTENT_SYNC] Error syncing class $classID: $e');
      rethrow;
    }
  }

  /// Sync offline clocking records to server
  Future<void> _syncOfflineClockingRecords(
      DatabaseHelper dbHelper, SyncResult result) async {
    try {
      final db = await dbHelper.database;

      // Get all unsynced clocking records
      final unsyncedRecords = await db.query(
        'learner_clocking',
        where: 'synced = ?',
        whereArgs: [0],
      );

      print(
          '[PERSISTENT_SYNC] Found ${unsyncedRecords.length} unsynced clocking records');

      for (var record in unsyncedRecords) {
        try {
          // Sync individual record
          await _syncSingleClockingRecord(record, dbHelper);
          result.clockingRecordsSynced++;
        } catch (e) {
          print(
              '[PERSISTENT_SYNC] Failed to sync clocking record ${record['clocking_id']}: $e');
          result.errors.add('Clocking ${record['clocking_id']}: $e');
        }
      }
    } catch (e) {
      print('[PERSISTENT_SYNC] Error syncing clocking records: $e');
      result.errors.add('Clocking sync: $e');
    }
  }

  /// Sync a single clocking record
  Future<void> _syncSingleClockingRecord(
      Map<String, dynamic> record, DatabaseHelper dbHelper) async {
    // Determine if it's clock-in or clock-out
    final hasClockOut = record['clock_out_time'] != null &&
        record['clock_out_time'].toString().isNotEmpty;

    final endpoint = hasClockOut ? AppConfig.clockoutUrl : AppConfig.clockinUrl;

    final response = await http.post(
      Uri.parse(endpoint),
      body: {
        'LearnerID': record['LearnerID'].toString(),
        'clock_date': record['clock_date'].toString(),
        'clock_in_time': record['clock_in_time'].toString(),
        if (hasClockOut) 'clock_out_time': record['clock_out_time'].toString(),
        'user_latitude': record['user_latitude']?.toString() ?? '',
        'user_longitude': record['user_longitude']?.toString() ?? '',
        'user_accuracy': record['user_accuracy']?.toString() ?? '',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      // Mark as synced
      final db = await dbHelper.database;
      await db.update(
        'learner_clocking',
        {'synced': 1},
        where: 'clocking_id = ?',
        whereArgs: [record['clocking_id']],
      );
      print(
          '[PERSISTENT_SYNC] Synced clocking record ${record['clocking_id']}');
    } else {
      throw Exception('Server returned ${response.statusCode}');
    }
  }

  /// Sync other pending data (POE, documents, etc.)
  Future<void> _syncOtherPendingData(
      DatabaseHelper dbHelper, SyncResult result) async {
    // Add other sync operations as needed
    print('[PERSISTENT_SYNC] Syncing other pending data...');
  }

  /// Get last sync time
  DateTime? getLastSyncTime() => _lastSyncTime;

  /// Check if sync is in progress
  bool isSyncing() => _isSyncing;
}

/// Result of a sync operation
class SyncResult {
  bool success = false;
  String message = '';
  int learnersSynced = 0;
  int clockingRecordsSynced = 0;
  List<String> errors = [];

  @override
  String toString() {
    return 'SyncResult(success: $success, learners: $learnersSynced, clocking: $clockingRecordsSynced, errors: ${errors.length})';
  }
}
