import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:geolocator/geolocator.dart';  // Temporarily commented out
import 'database_helper.dart';
import 'config.dart';
import 'dart:io'; // For File
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:sqflite/sqflite.dart'; // For ConflictAlgorithm
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'utils/clocking_logger.dart';

Future<bool> syncSingleClockIn(Map<String, dynamic> attendance) async {
  print('=== CLOCK-IN SYNC START ===');
  print('Input attendance: $attendance');

  final connectivityResult = await Connectivity().checkConnectivity();
  print('Connectivity result: $connectivityResult');

  // Handle both List and single ConnectivityResult
  final isOffline = connectivityResult is List
      ? (connectivityResult.isEmpty ||
          connectivityResult.first == ConnectivityResult.none)
      : (connectivityResult == ConnectivityResult.none);

  if (isOffline) {
    print('No internet connection - returning false');
    return false;
  }

  print('✅ Internet connection available - proceeding with sync');

  // Retry logic with exponential backoff
  const int maxRetries = 2; // Reduced retries for faster response
  const Duration baseTimeout =
      Duration(seconds: 8); // Reduced timeout for faster response

  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      final url = Uri.parse(AppConfig.clockinUrl);
      print('Target URL: $url (attempt $attempt/$maxRetries)');

      // Prepare payload exactly like LearnerListPage.dart
      final payload = {
        'LearnerID': attendance['LearnerID'],
        'clock_in': '1',
        'signature': '', // Empty signature for now
        'user_latitude': attendance['user_latitude'] ?? '0.0',
        'user_longitude': attendance['user_longitude'] ?? '0.0',
        'user_accuracy':
            attendance['user_accuracy'] ?? '10.0', // Server expects this field
        'synced': '0',
        'classID': attendance['classID'] ?? '',
        'fingerprint_verified':
            'true', // CRITICAL: Indicate fingerprint was verified
        'request_source': 'mobile_app', // CRITICAL: Indicate request source
        'sync_request': 'true', // CRITICAL: Indicate this is a sync request
      };

      print('Sending clock-in sync request: $payload');

      // Convert payload to URL-encoded format
      final body = payload.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');

      print('Encoded body: $body');

      // Use exponential backoff for timeout
      final timeout = Duration(seconds: baseTimeout.inSeconds * attempt);

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body,
          )
          .timeout(timeout);

      print(
          'Clock-in sync response (status ${response.statusCode}): "${response.body}"');
      ClockingLogger.instance.logHttpRequest(
          'POST', url.toString(), payload, response.statusCode, response.body);

      if (response.statusCode == 200) {
        try {
          final responseJson = json.decode(response.body);
          print('Parsed response JSON: $responseJson');

          // Check for different possible success indicators
          bool success = false;
          if (responseJson is Map<String, dynamic>) {
            success = responseJson['success'] == true ||
                responseJson['status'] == 'success' ||
                responseJson['success'] == 'true';
          }

          print('Sync success: $success');
          return success;
        } catch (e) {
          print('Error parsing response JSON: $e');
          print('Raw response body: "${response.body}"');
          if (attempt == maxRetries) return false;
          // Continue to next attempt
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        print('Response body: "${response.body}"');
        if (attempt == maxRetries) return false;
        // Continue to next attempt
      }
    } catch (e) {
      print('Error syncing clock-in (attempt $attempt): $e');
      if (attempt == maxRetries) return false;

      // Wait before retry with exponential backoff
      final delay = Duration(seconds: attempt * 2); // 2s, 4s, 6s
      print('Waiting ${delay.inSeconds} seconds before retry...');
      await Future.delayed(delay);
    }
  }

  return false;
}

Future<bool> syncSingleClockOut(Map<String, dynamic> attendance) async {
  print('=== CLOCK-OUT SYNC START ===');
  print('Input attendance: $attendance');

  final connectivityResult = await Connectivity().checkConnectivity();
  print('Connectivity result: $connectivityResult');

  // Handle both List and single ConnectivityResult
  final isOffline = connectivityResult is List
      ? (connectivityResult.isEmpty ||
          connectivityResult.first == ConnectivityResult.none)
      : (connectivityResult == ConnectivityResult.none);

  if (isOffline) {
    print('No internet connection - returning false');
    return false;
  }

  print('✅ Internet connection available - proceeding with sync');

  // Retry logic with exponential backoff
  const int maxRetries = 2; // Reduced retries for faster response
  const Duration baseTimeout =
      Duration(seconds: 8); // Reduced timeout for faster response

  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      final url = Uri.parse(AppConfig.clockoutUrl);
      print('Target URL: $url (attempt $attempt/$maxRetries)');

      // Prepare payload exactly like LearnerListPage.dart
      final payload = {
        'LearnerID': attendance['LearnerID'],
        'clock_out': '1',
        'signature': '', // Empty signature for now
        'user_latitude': attendance['user_latitude'] ?? '0.0',
        'user_longitude': attendance['user_longitude'] ?? '0.0',
        'user_accuracy':
            attendance['user_accuracy'] ?? '10.0', // Server expects this field
        'synced': '0',
        'classID': attendance['classID'] ?? '',
        'fingerprint_verified':
            'true', // CRITICAL: Indicate fingerprint was verified
        'request_source': 'mobile_app', // CRITICAL: Indicate request source
        'sync_request': 'true', // CRITICAL: Indicate this is a sync request
      };

      print('Sending clock-out sync request: $payload');

      // Convert payload to URL-encoded format
      final body = payload.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');

      print('Encoded body: $body');

      // Use exponential backoff for timeout
      final timeout = Duration(seconds: baseTimeout.inSeconds * attempt);

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body,
          )
          .timeout(timeout);

      print(
          'Clock-out sync response (status ${response.statusCode}): "${response.body}"');
      ClockingLogger.instance.logHttpRequest(
          'POST', url.toString(), payload, response.statusCode, response.body);

      if (response.statusCode == 200) {
        try {
          final responseJson = json.decode(response.body);
          print('Parsed response JSON: $responseJson');

          // Check for different possible success indicators
          bool success = false;
          if (responseJson is Map<String, dynamic>) {
            success = responseJson['success'] == true ||
                responseJson['status'] == 'success' ||
                responseJson['success'] == 'true';
          }

          print('Sync success: $success');
          return success;
        } catch (e) {
          print('Error parsing response JSON: $e');
          print('Raw response body: "${response.body}"');
          if (attempt == maxRetries) return false;
          // Continue to next attempt
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        print('Response body: "${response.body}"');
        if (attempt == maxRetries) return false;
        // Continue to next attempt
      }
    } catch (e) {
      print('Error syncing clock-out (attempt $attempt): $e');
      if (attempt == maxRetries) return false;

      // Wait before retry with exponential backoff
      final delay = Duration(seconds: attempt * 2); // 2s, 4s, 6s
      print('Waiting ${delay.inSeconds} seconds before retry...');
      await Future.delayed(delay);
    }
  }

  return false;
}

class SyncService extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Initialize the app and download data if online
  Future<void> initSync() async {
    await syncData();
  }

  // Sync all tables from the server to the local database
  Future<void> syncData() async {
    await _syncUsers();
    await _syncLearnerDetails();
    // Only sync current day's clocking data to avoid loading old records
    await _syncLearnerClocking(currentDayOnly: true);
    await _syncFacilitator();
    await _syncSdp();
    await syncSites();
    await _syncClass();
    await _syncLearningpathway();
    await _syncPathwaySelection();
    await _syncQualification();
    await _syncQualification_selection();
    await _syncQualification_pathway();
    await _syncQualificationunitstandard();
    await _syncUnitstandard();
    await _syncUnit_standard_selection();
    await _syncAssessment();
    await _syncPoe();
    await syncAcknowledgmentOfReceiptToServer();
    await syncDataFromServer();
    await syncMaterialReceiptFormData();
    await syncMaterialsReceivedData();
    await syncProjectData();
    await syncSickNotesToServer();
    await _syncBankDetails();
    await _syncInductionClocking();
    await sync_inductionClocking();
  }

  // Sync users table
  Future<void> _syncUsers() async {
    try {
      final response = await http.get(Uri.parse(AppConfig.syncUsersUrl));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        print('Users data from server: $data'); // Debug the response

        // SMART SYNC: Update existing, insert new (no delete)
        print('Syncing ${data.length} users using UPDATE/INSERT pattern');

        final db = await _dbHelper.database;

        // Insert each user into the SQLite database
        for (var user in data) {
          await db.insert(
            'users',
            user,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          print('Synced user: $user'); // Debug insertion
        }
        print(
            "Users table synchronized and data inserted into local database successfully.");
      } else {
        print('Failed to sync users. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during users sync: $e');
    }
  }

  // Fetch and print local data to confirm insertion
  Future<void> printLocalUsers() async {
    final db = await _dbHelper.database;
    final users = await db.query('users');
    print("Users in local database: $users");
  }

  // Sync learnerdetails table
  Future<void> _syncLearnerDetails() async {
    try {
      // Verify connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.wifi) &&
          !connectivityResult.contains(ConnectivityResult.mobile)) {
        print("No network available, skipping learner details sync");
        return;
      }

      // Make GET request to fetch learner details
      final response = await http.get(
        Uri.parse(AppConfig.syncLearnerDetailsUrl),
        headers: {'Content-Type': 'application/json'},
      );

      print("Server response status: ${response.statusCode}");
      print("Server response body: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> learners = json.decode(response.body);
        if (learners.isEmpty) {
          print("Warning: No learner data received from API");
          return;
        }

        final db = await _dbHelper.database;

        // Create a mapping of IDNumber to server LearnerID for existing records
        Map<String, int> idNumberToServerId = {};
        for (var learner in learners) {
          if (learner['IDNumber'] != null && learner['LearnerID'] != null) {
            idNumberToServerId[learner['IDNumber'].toString()] =
                learner['LearnerID'] as int;
          }
        }

        // Get existing local learners to create ID mapping
        final existingLearners = await db.query('learnerdetails');
        Map<int, int> localToServerIdMapping = {};

        for (var existingLearner in existingLearners) {
          String idNumber = existingLearner['IDNumber']?.toString() ?? '';
          int localId = existingLearner['LearnerID'] as int;

          if (idNumberToServerId.containsKey(idNumber)) {
            int serverId = idNumberToServerId[idNumber]!;
            localToServerIdMapping[localId] = serverId;
            print(
                "Mapping local ID $localId to server ID $serverId for IDNumber $idNumber");
          }
        }

        // Update related tables with new IDs before syncing learnerdetails
        if (localToServerIdMapping.isNotEmpty) {
          await _updateRelatedTablesWithNewIds(db, localToServerIdMapping);
        }

        // SMART SYNC: Update existing, insert new (no delete)
        print(
            'Syncing ${learners.length} learner details using UPDATE/INSERT pattern');

        // Insert records one by one
        for (var learner in learners) {
          // Validate required fields
          if (learner['IDNumber'] == null || learner['classID'] == null) {
            print("Skipping invalid learner record: $learner");
            continue;
          }

          // Extract bank details before inserting learner
          Map<String, dynamic>? bankDetails;
          if (learner['BankName'] != null || learner['BankAccount'] != null) {
            bankDetails = {
              'LearnerID': learner['LearnerID'],
              'BankName': learner['BankName'] ?? '',
              'bankType': learner['bankType'] ?? '',
              'BankAccount': learner['BankAccount'] ?? '',
              'BankCode': learner['BankCode'] ?? '',
              'synced': 0,
            };
          }

          // Create learner data WITHOUT bank fields
          Map<String, dynamic> learnerData = Map<String, dynamic>.from(learner);
          learnerData.remove('BankName');
          learnerData.remove('bankType');
          learnerData.remove('BankAccount');
          learnerData.remove('BankCode');

          try {
            // Insert/update learner details
            await db.insert(
              'learnerdetails',
              learnerData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            // Insert/update bank details if they exist
            if (bankDetails != null) {
              await db.insert(
                'bankdetails',
                bankDetails,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }

            print(
                "Successfully synced learner with IDNumber: ${learner['IDNumber']}, Server ID: ${learner['LearnerID']}");
          } catch (e) {
            print(
                "Error syncing learner with IDNumber ${learner['IDNumber']}: $e");
            // Continue with other learners even if one fails
          }
        }

        print("Successfully synchronized ${learners.length} learner records");
      } else {
        throw Exception(
            "Failed to sync learner details. Status code: ${response.statusCode}");
      }
    } catch (e, stackTrace) {
      print("Error syncing learner details: $e");
      print("Stack trace: $stackTrace");
      rethrow;
    }
  }

  // Helper method to update related tables with new LearnerIDs
  Future<void> _updateRelatedTablesWithNewIds(
      Database db, Map<int, int> idMapping) async {
    try {
      // Update learner_clocking table
      for (var entry in idMapping.entries) {
        int oldId = entry.key;
        int newId = entry.value;

        await db.update(
          'learner_clocking',
          {'LearnerID': newId},
          where: 'LearnerID = ?',
          whereArgs: [oldId],
        );
        print("Updated learner_clocking: $oldId -> $newId");
      }

      // Update bankdetails table
      for (var entry in idMapping.entries) {
        int oldId = entry.key;
        int newId = entry.value;

        await db.update(
          'bankdetails',
          {'LearnerID': newId},
          where: 'LearnerID = ?',
          whereArgs: [oldId],
        );
        print("Updated bankdetails: $oldId -> $newId");
      }

      // Update poe table
      for (var entry in idMapping.entries) {
        int oldId = entry.key;
        int newId = entry.value;

        await db.update(
          'poe',
          {'learnerID': newId},
          where: 'learnerID = ?',
          whereArgs: [oldId],
        );
        print("Updated poe: $oldId -> $newId");
      }

      // Update learner_document table
      for (var entry in idMapping.entries) {
        int oldId = entry.key;
        int newId = entry.value;

        await db.update(
          'learner_document',
          {'learner_id': newId},
          where: 'learner_id = ?',
          whereArgs: [oldId],
        );
        print("Updated learner_document: $oldId -> $newId");
      }

      print("Successfully updated all related tables with new LearnerIDs");
    } catch (e) {
      print("Error updating related tables: $e");
      rethrow;
    }
  }

  // Sync bank details table
  Future<void> _syncBankDetails() async {
    try {
      final response = await http.get(Uri.parse(AppConfig.syncBankLocalUrl));

      if (response.statusCode == 200) {
        List details = json.decode(response.body);

        // SMART SYNC: Update existing, insert new (no delete)
        print(
            'Syncing ${details.length} bank details using UPDATE/INSERT pattern');

        final db = await _dbHelper.database;

        for (var detail in details) {
          await db.insert(
            'bankdetails',
            detail,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        print("bankdetails table synchronized successfully.");
      } else {
        print(
            "Failed to sync bankdetails. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing bankdetails: $e");
    }
  }

  //facilitator
  // Public method to sync facilitator data (including fingerprints)
  Future<void> syncFacilitatorData() async {
    await _syncFacilitator();
  }

  Future<void> _syncFacilitator() async {
    try {
      final response = await http.get(Uri.parse(AppConfig.syncFacilitatorUrl));

      if (response.statusCode == 200) {
        List facilitatorData = json.decode(response.body);
        print(
            "[FAC_SYNC] Received ${facilitatorData.length} facilitators from server");

        final db = await _dbHelper.database;

        // Clear table
        await db.delete('facilitator');
        print("[FAC_SYNC] Cleared facilitator table");

        // Insert using direct SQL to avoid any data transformation issues
        int successCount = 0;
        for (var facilitator in facilitatorData) {
          try {
            // Direct SQL insert - no helpers, no transformations
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

            successCount++;
            print(
                "[FAC_SYNC] ✓ Synced facilitator ID ${facilitator['facilitator_id']}: ${facilitator['firstName']} ${facilitator['lastName']}");
          } catch (e) {
            print(
                "[FAC_SYNC] ✗ Error inserting facilitator ${facilitator['facilitator_id']}: $e");
          }
        }

        print(
            "[FAC_SYNC] Sync complete: $successCount/${facilitatorData.length} facilitators synced");
      } else {
        print("[FAC_SYNC] Server error: ${response.statusCode}");
      }
    } catch (e) {
      print("[FAC_SYNC] Sync error: $e");
    }
  }

  // Sync learner_clocking table (ALL records, optionally filtered by classID)
  Future<void> _syncLearnerClocking(
      {String? classID, bool currentDayOnly = false}) async {
    try {
      String url = AppConfig.syncLearnerClockingUrl;
      String? today; // Declare today variable outside the if block

      // Use South African time (SAST - UTC+2)
      final saTime = DateTime.now().toUtc().add(const Duration(hours: 2));
      final todayDate = DateFormat('yyyy-MM-dd').format(saTime);

      // Add date filter only if currentDayOnly is true
      if (currentDayOnly) {
        today = todayDate;
        url += '?clock_date=$today';
      }

      // Add classID filter if provided
      if (classID != null && classID.isNotEmpty) {
        if (currentDayOnly) {
          url += '&classID=$classID';
          print(
              "[SYNC] Fetching learner_clocking for date: $today (SAST), classID: $classID");
        } else {
          url += '?classID=$classID';
          print(
              "[SYNC] Fetching ALL learner_clocking records for classID: $classID");
        }
      } else if (!currentDayOnly) {
        print("[SYNC] Fetching ALL learner_clocking records (all classes)");
      } else {
        print(
            "[SYNC] Fetching learner_clocking for date: $today (SAST), all classes");
      }

      final response = await http.get(Uri.parse(url));

      print("[SYNC] Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        var decodedData = json.decode(response.body);
        if (decodedData is List) {
          List clockingData = decodedData;
          print(
              "[SYNC] Fetched ${clockingData.length} records for $todayDate (SAST)");
          int insertedCount = 0;
          int skippedCount = 0;

          print(
              "[SYNC] Merging ${clockingData.length} server records (currentDayOnly: $currentDayOnly)");

          // Insert or update each record
          for (var clocking in clockingData) {
            // Map JSON keys to match table schema - include ALL columns for full sync
            final raw = clocking as Map<String, dynamic>;
            var mappedClocking = <String, dynamic>{
              'clocking_id': raw['clocking_id'],
              'LearnerID': raw['LearnerID'] ?? raw['learner_id'],
              'clock_date': raw['clock_date'],
              'clock_in_time': raw['clock_in_time'],
              'clock_out_time': raw['clock_out_time'],
              'contact_time': raw['contact_time'],
              'signature': raw['signature'],
              'synced': raw['synced'] ?? 1,
              'user_latitude': raw['user_latitude'],
              'user_longitude': raw['user_longitude'],
              'user_accuracy': raw['user_accuracy'],
            };

            // Validate required fields
            if (mappedClocking['clocking_id'] == null ||
                mappedClocking['LearnerID'] == null ||
                mappedClocking['clock_date'] == null ||
                mappedClocking['clock_in_time'] == null) {
              print("Skipping invalid record: $mappedClocking");
              skippedCount++;
              continue;
            }

            // CRITICAL: If currentDayOnly is true, ONLY insert today's records
            if (currentDayOnly && mappedClocking['clock_date'] != todayDate) {
              print(
                  "⏩ Skipping non-current day record: ${mappedClocking['clock_date']} (not today: $todayDate)");
              skippedCount++;
              continue;
            }

            print("Merging server record: $mappedClocking");
            try {
              final db = await _dbHelper.database;
              // Check for existing record with same learner and date ONLY.
              // This guarantees max ONE local record per learner per date.
              final existingRecords = await db.query(
                'learner_clocking',
                where: 'LearnerID = ? AND clock_date = ?',
                whereArgs: [
                  mappedClocking['LearnerID'],
                  mappedClocking['clock_date'],
                ],
              );

              if (existingRecords.isNotEmpty) {
                // NEVER overwrite local records - local is source of truth.
                // Also, do NOT create a second record for the same learner/date.
                print(
                    "⏭️ PRESERVING local record for ${mappedClocking['LearnerID']} (clock_date=${mappedClocking['clock_date']}) - not inserting duplicate for day");
                skippedCount++;
              } else {
                // Insert new record from server (no existing record for that learner/date)
                await db.insert(
                  'learner_clocking',
                  mappedClocking,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
                print(
                    "✅ Inserted new server record for ${mappedClocking['LearnerID']}");
                insertedCount++;
              }
            } catch (e) {
              print("Error merging record $mappedClocking: $e");
            }
          }
          print(
              "✅ Sync complete: $insertedCount inserted/updated, $skippedCount skipped (currentDayOnly: $currentDayOnly)");
        } else {
          print(
              "Error: Expected List, got ${decodedData.runtimeType}: $decodedData");
        }
      } else {
        print(
            "Failed to sync. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      print("Error syncing learner_clocking: $e");
    }
  }

  bool isSyncing = false;
  String syncMessage = '';

  // Public method to sync clocking data for a specific class (current day only)
  Future<void> syncClassClockingFromServer(String classID) async {
    try {
      print(
          "[SYNC] Syncing clocking data for classID: $classID (current day only)");
      await _syncLearnerClocking(classID: classID, currentDayOnly: true);
      print("[SYNC] Class clocking sync completed for classID: $classID");
    } catch (e) {
      print("[SYNC] Error syncing class clocking: $e");
    }
  }

  // Public method to sync ALL clocking data for a specific class (all dates)
  Future<void> syncAllClassClockingFromServer(String classID) async {
    try {
      print("[SYNC] Syncing ALL clocking data for classID: $classID");
      await _syncLearnerClocking(classID: classID, currentDayOnly: false);
      print("[SYNC] All class clocking sync completed for classID: $classID");
    } catch (e) {
      print("[SYNC] Error syncing all class clocking: $e");
    }
  }

  Future<void> syncClockingDataToServer() async {
    final db = await _dbHelper.database;

    isSyncing = true;
    syncMessage = 'Syncing data to the server...';
    notifyListeners();

    try {
      // Sync ALL unsynced records for the last 10 days (including clock-in only)
      // This allows devices to be offline for a few days but avoids sending very old data.
      final now = DateTime.now();
      final cutoffDate =
          DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 10)));

      final List<Map<String, dynamic>> clockingDataList = await db.query(
        'learner_clocking',
        where: 'synced = ? AND clock_date >= ?',
        whereArgs: [0, cutoffDate],
      );

      if (clockingDataList.isEmpty) {
        syncMessage = 'No data to sync!';
        notifyListeners();
        return;
      }

      const maxRetries = 3;
      for (var clockingData in clockingDataList) {
        final clockingId = clockingData['clocking_id'];
        final LearnerID = clockingData['LearnerID'];
        final clockInTime = clockingData['clock_in_time'];
        final clockOutTime = clockingData['clock_out_time'];
        final contactTime = clockingData['contact_time'];
        // We no longer send signature for clocking sync; always null on server
        final userLatitude = clockingData['user_latitude'];
        final userLongitude = clockingData['user_longitude'];
        final userAccuracy = clockingData['user_accuracy'];
        final clockDate = clockingData['clock_date'] ??
            DateTime.now().toIso8601String().split('T')[0];

        bool synced = false;
        for (var attempt = 1; attempt <= maxRetries; attempt++) {
          try {
            // Prepare multipart request
            var request = http.MultipartRequest(
              'POST',
              Uri.parse(AppConfig.syncClockingUrl),
            );

            // Add fields
            request.fields['clocking_id'] = clockingId.toString();
            request.fields['LearnerID'] = LearnerID.toString();
            request.fields['clock_in_time'] = clockInTime ?? '';
            request.fields['clock_out_time'] = clockOutTime ?? '';
            request.fields['contact_time'] = contactTime ?? '';
            request.fields['clock_date'] = clockDate;
            request.fields['user_latitude'] = userLatitude?.toString() ?? '';
            request.fields['user_longitude'] = userLongitude?.toString() ?? '';
            request.fields['user_accuracy'] = userAccuracy?.toString() ?? '';

            // Log request details
            print('Attempt $attempt: Request fields: ${request.fields}');
            print(
                'Attempt $attempt: Request files: ${request.files.map((f) => f.filename).toList()}');

            // Send request
            final response =
                await request.send().timeout(const Duration(seconds: 30));
            final responseString = await response.stream.bytesToString();

            print(
                'Attempt $attempt: Server response for clocking_id $clockingId: $responseString (Status: ${response.statusCode})');

            if (response.statusCode == 200) {
              if (responseString.isEmpty) {
                print(
                    'Attempt $attempt: Empty response received for clocking_id $clockingId');
                syncMessage =
                    'Empty response from server for record $clockingId';
                if (attempt == maxRetries) {
                  syncMessage =
                      'Max retries reached for record $clockingId: Empty response';
                }
                await Future.delayed(const Duration(seconds: 1));
                continue;
              }

              try {
                final responseData = json.decode(responseString);
                if (responseData['status'] == 'success') {
                  await db.update(
                    'learner_clocking',
                    {'synced': true},
                    where: 'clocking_id = ?',
                    whereArgs: [clockingId],
                  );
                  syncMessage = 'Record $clockingId synced successfully!';
                  synced = true;
                  break;
                } else {
                  syncMessage =
                      'Server error for record $clockingId: ${responseData['message']}';
                  if (attempt == maxRetries) {
                    syncMessage =
                        'Max retries reached for record $clockingId: ${responseData['message']}';
                  }
                  await Future.delayed(const Duration(seconds: 1));
                  continue;
                }
              } catch (e) {
                print(
                    'Attempt $attempt: JSON parse error for clocking_id $clockingId: $e');
                syncMessage =
                    'Invalid response format for record $clockingId: $e';
                if (attempt == maxRetries) {
                  syncMessage =
                      'Max retries reached for record $clockingId: Invalid response';
                }
                await Future.delayed(const Duration(seconds: 1));
                continue;
              }
            } else {
              print(
                  'Attempt $attempt: Failed for clocking_id $clockingId: Status ${response.statusCode}, Response: $responseString');
              syncMessage =
                  'Failed to sync record $clockingId. Status: ${response.statusCode}, Response: $responseString';
              if (attempt == maxRetries) {
                syncMessage =
                    'Max retries reached for record $clockingId: Status ${response.statusCode}';
              }
              await Future.delayed(const Duration(seconds: 1));
              continue;
            }
          } catch (e) {
            print('Attempt $attempt: Error for clocking_id $clockingId: $e');
            syncMessage = 'Error syncing record $clockingId: $e';
            if (attempt == maxRetries) {
              syncMessage = 'Max retries reached for record $clockingId: $e';
            }
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
        }

        if (!synced) {
          syncMessage =
              'Failed to sync record $clockingId after $maxRetries attempts';
          notifyListeners();
        }
      }

      if (syncMessage.contains('Failed') || syncMessage.contains('Error')) {
        // Keep syncMessage as is to reflect the last error
      } else {
        syncMessage = 'All data synced successfully!';
      }
    } catch (e) {
      syncMessage = 'Sync failed: $e';
      print('Error syncing data: $e');
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  // Method to synchronize unsynced data to the server
  Future<void> syncUnsyncedData() async {
    try {
      List<Map<String, dynamic>> unsyncedData =
          await _dbHelper.fetchData('unsynced_data');

      for (var data in unsyncedData) {
        final response = await http.post(
          Uri.parse(AppConfig.syncUnsyncedDataUrl),
          body: json.encode(data),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          await _dbHelper.deleteData('unsynced_data', data['id']);
          print("Unsynced data synced successfully.");
        } else {
          print(
              "Failed to sync unsynced data. Status code: ${response.statusCode}");
        }
      }
    } catch (e) {
      print("Error syncing unsynced data: $e");
    }
  }

  // Upload a local SDP to the server
  Future<void> _syncSdp() async {
    try {
      // Sending GET request to the PHP server to sync sdp data
      final response = await http.get(Uri.parse(AppConfig.getSdpUrl));

      if (response.statusCode == 200) {
        // Parse the response body as a map
        Map<String, dynamic> data = json.decode(response.body);

        // Ensure that 'data' is a list before proceeding
        if (data['status'] == 'success' && data['data'] is List) {
          List sdpData = data['data']; // Extract the 'data' list

          print("sdp data received from server: $sdpData");

          // SMART SYNC: Update existing, insert new (no delete)
          final db = await _dbHelper.database;

          for (var sdp in sdpData) {
            print("Syncing sdp: $sdp"); // Debug log

            // Check if record exists
            final existing = await db.query(
              'sdp',
              where: 'sdp_id = ?',
              whereArgs: [sdp['sdp_id']],
              limit: 1,
            );

            final sdpRecord = {
              'sdp_id': sdp['sdp_id'],
              'sdp_name': sdp['sdp_name'],
              'Reg_number': sdp['Reg_number'],
              'b_description': sdp['b_description'],
              'accreditation_n': sdp['accreditation_n'],
              'p_address': sdp['p_address'],
              'province': sdp['province'],
              'district': sdp['district'],
              'municipality': sdp['municipality'],
              'email': sdp['email'],
              'sdp_logo': sdp['sdp_logo'],
              'password': sdp['password'],
              'role': sdp['role'],
              'client_name': sdp['client_name'],
              'signature_image': sdp['signature_image'],
            };

            if (existing.isNotEmpty) {
              // Update existing record
              await db.update(
                'sdp',
                sdpRecord,
                where: 'sdp_id = ?',
                whereArgs: [sdp['sdp_id']],
              );
              print("Updated sdp: ${sdp['sdp_id']}");
            } else {
              // Insert new record
              await _dbHelper.insertData('sdp', sdpRecord);
              print("Inserted new sdp: ${sdp['sdp_id']}");
            }
          }

          // Query the local sdp table to check if data is synced
          final sdp = await db.query('sdp');
          print("sdp in local database: ${sdp.length} records");

          print("sdp table synchronized successfully.");
        } else {
          print("Failed to sync sdp. Unexpected response format.");
        }
      } else {
        print("Failed to sync sdp. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing sdp: $e");
    }
  }

  Future<void> syncSites() async {
    try {
      final response = await http.get(Uri.parse(AppConfig.syncSitesUrl));

      if (response.statusCode == 200) {
        // Parse the response body
        var data = json.decode(response.body);
        if (data['status'] == 'success') {
          List sitesData = data['data'];
          print('Sites data received: ${sitesData.length} sites');

          // Process the data and insert it into the local database (SQLite)
          for (var sites in sitesData) {
            // Insert each site into the local database with ALL fields
            await _dbHelper.insertSite({
              'siteID': sites['siteID'],
              'siteName': sites['siteName'],
              'beneficiaries': sites['beneficiaries'],
              'latitude': sites['latitude'],
              'longitude': sites['longitude'],
              'sdp_id': sites['sdp_id'],
              'Province': sites['Province'],
              'District': sites['District'],
              'Municipality': sites['Municipality'],
              'Category': sites['Category'],
              'project_id': sites['project_id'],
              'Project_pathway': sites['Project_pathway'],
              'qualification_id': sites['qualification_id'],
              'first_name': sites['first_name'],
              'last_name': sites['last_name'],
              'cell_phone': sites['cell_phone'],
              'email': sites['email'],
            });
          }

          // Ensure that the database is opened before querying
          final db = await _dbHelper.database;

          // Query the local sites table to check if data is inserted
          final localSites = await db.query('sites');
          print("Sites in local database: ${localSites.length} records");

          print("Sites table synchronized successfully.");
        } else {
          print("Failed to sync sites. Unexpected response format.");
        }
      } else {
        print("Failed to sync sites. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing sites: $e");
    }
  }

  Future<void> _syncClass() async {
    try {
      // Sending GET request to the PHP server to sync class data
      final response = await http.get(Uri.parse(AppConfig.syncClassUrl));

      if (response.statusCode == 200) {
        // Parse the response body as a Map first
        Map<String, dynamic> responseBody = json.decode(response.body);

        // Check the status of the response
        if (responseBody['status'] == 'success') {
          // Extract the list of classes from the 'data' key
          List classData = responseBody['data'] ?? [];

          print("Class data received from server: $classData");

          // SMART SYNC: Update existing, insert new (no delete)
          print(
              'Syncing ${classData.length} classes using UPDATE/INSERT pattern');

          final db = await _dbHelper.database;

          // Insert each class record into the local database
          for (var classEntry in classData) {
            print("Syncing class: $classEntry"); // Debug log
            await db.insert(
              'class',
              {
                'classID': classEntry['classID'],
                'className': classEntry['className'],
                'numberOfLearners': classEntry['numberOfLearners'],
                'siteID': classEntry['siteID'],
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          // Query the local class table to check if data is inserted
          final localClassData = await db.query('class');
          print("Class in local database: ${localClassData.length} records");

          print("Class table synchronized successfully.");
        } else {
          print("Failed to sync class. Server responded with error.");
        }
      } else {
        print("Failed to sync class. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing class: $e");
    }
  }

  //sync to online server for learner_clocking
  Future<List<Map<String, dynamic>>> fetchDataFromLocalDatabase() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> results = await db.query(
        'learner_clocking',
        where: 'synced = ?',
        whereArgs: [0],
      );
      if (results.isNotEmpty) {
        print(
            "Fetched ${results.length} unsynced record(s) from local database.");
        return results;
      } else {
        print("No unsynced data found in local database.");
        return [];
      }
    } catch (e) {
      print("Error fetching data from local database: $e");
      rethrow;
    }
  }

  Future<void> markIsSynced(int clockingId) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'learner_clocking',
        {'synced': 1},
        where: 'clocking_id = ?',
        whereArgs: [clockingId],
      );
      print("Marked clocking_id $clockingId as synced.");
    } catch (e) {
      print("Error marking entry as synced: $e");
      throw Exception("Failed to update sync status.");
    }
  }

  Future<void> syncDataToServer({int maxRetries = 3}) async {
    try {
      if (!await isConnected()) {
        print("No internet connection. Sync aborted.");
        showSyncError("No internet connection.");
        return;
      }

      final unsyncedRecords = await fetchDataFromLocalDatabase();
      if (unsyncedRecords.isEmpty) {
        print("No data to sync.");
        return;
      }

      for (final localData in unsyncedRecords) {
        int attempts = 0;
        bool synced = false;
        while (attempts < maxRetries && !synced) {
          try {
            // Validate required fields
            if (!localData.containsKey('LearnerID') ||
                localData['LearnerID'] == null ||
                !localData.containsKey('clock_in_time') ||
                localData['clock_in_time'] == null ||
                !localData.containsKey('clocking_id') ||
                localData['clocking_id'] == null) {
              print(
                  "Skipping record ${localData['clocking_id']}: Missing required fields");
              break;
            }

            final url = Uri.parse(AppConfig.syncClockingUrl);
            var request = http.MultipartRequest('POST', url)
              ..headers['Content-Type'] = 'multipart/form-data';

            // Add fields, ensuring non-null values
            localData.forEach((key, value) {
              if (value != null && key != 'signature') {
                request.fields[key] = value.toString();
              }
            });
            print("Request fields: ${request.fields}");

            // Handle signature file
            if (localData['signature'] != null) {
              final signaturePath = localData['signature'].toString();
              final signatureFile = File(signaturePath);
              if (await signatureFile.exists()) {
                var multipartFile = await http.MultipartFile.fromPath(
                    'signature', signaturePath);
                request.files.add(multipartFile);
                print("Signature file added: $signaturePath");
              } else {
                print("Signature file not found: $signaturePath");
              }
            }

            final response = await request.send();
            final responseBody = await response.stream.bytesToString();
            print("Server response: $responseBody");

            if (response.statusCode == 200) {
              final responseJson =
                  json.decode(responseBody) as Map<String, dynamic>;
              if (responseJson['status'] == 'success') {
                await markIsSynced(localData['clocking_id']);
                print("Record ${localData['clocking_id']} synced.");
                synced = true;
              } else {
                throw Exception("Sync failed: ${responseJson['message']}");
              }
            } else {
              throw Exception(
                  "Status code: ${response.statusCode}, response: $responseBody");
            }
          } catch (e) {
            attempts++;
            print(
                "Attempt $attempts failed for clocking_id ${localData['clocking_id']}: $e");
            if (attempts == maxRetries) {
              print(
                  "Max retries reached for clocking_id ${localData['clocking_id']}");
              showSyncError(
                  "Failed to sync record ${localData['clocking_id']}");
            }
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }
    } catch (e) {
      print("Error during data sync: $e");
      showSyncError("Sync error: $e");
      rethrow;
    }
  }

  Future<bool> isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  void showSyncError(String message) {
    print("Sync error: $message");
    // Add SnackBar or other UI feedback if needed
  }

  // Sync learnerdetails table
  Future<void> _syncLearningpathway() async {
    try {
      final response =
          await http.get(Uri.parse(AppConfig.syncLearningPathwayUrl));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        List insertLearningpathway;

        // If the response is a Map with a key pointing to the actual list, access it properly
        if (decodedResponse is Map) {
          // Assuming the data is nested inside a key, like 'data'
          insertLearningpathway = decodedResponse['data'] ??
              []; // Modify based on your actual structure
        } else if (decodedResponse is List) {
          // If the response is already a list
          insertLearningpathway = decodedResponse;
        } else {
          insertLearningpathway = [];
        }

        // SMART SYNC: Update existing, insert new (no delete)
        print(
            'Syncing ${insertLearningpathway.length} learning pathways using UPDATE/INSERT pattern');

        final db = await _dbHelper.database;

        for (var pathwayData in insertLearningpathway) {
          await db.insert(
            'learningpathway',
            pathwayData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        print("Pathway selection table synchronized successfully.");
      } else {
        print(
            "Failed to sync pathway selection. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing pathway selection: $e");
    }
  }

  Future<void> _syncPathwaySelection() async {
    try {
      final response =
          await http.get(Uri.parse(AppConfig.syncPathwaySelectionUrl));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        List pathwaySelectionlist = [];

        // If the response is a Map with a key pointing to the actual list
        if (decodedResponse is Map) {
          // Assuming the data is inside a key like 'data', modify based on your actual structure
          pathwaySelectionlist = decodedResponse['data'] ??
              []; // Replace 'data' with the correct key if necessary
        } else if (decodedResponse is List) {
          // If the response is already a list
          pathwaySelectionlist = decodedResponse;
        }

        // SMART SYNC: Update existing, insert new (no delete)
        print(
            'Syncing ${pathwaySelectionlist.length} pathway selections using UPDATE/INSERT pattern');

        final db = await _dbHelper.database;

        for (var pathway_selectionData in pathwaySelectionlist) {
          await db.insert(
            'pathway_selection',
            pathway_selectionData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print("Pathway selection table synchronized successfully.");
      } else {
        print(
            "Failed to sync pathway selection. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing pathway selection: $e");
    }
  }

  Future<void> _syncQualification() async {
    try {
      final response =
          await http.get(Uri.parse(AppConfig.syncQualificationUrl));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        List qualificationList = [];

        // If the response is a Map with a key pointing to the actual list
        if (decodedResponse is Map) {
          // Assuming the data is inside a key like 'data', modify based on your actual structure
          qualificationList = decodedResponse['data'] ??
              []; // Replace 'data' with the correct key if necessary
        } else if (decodedResponse is List) {
          // If the response is already a list
          qualificationList = decodedResponse;
        }

        // SMART SYNC: Update existing, insert new (no delete)
        print(
            'Syncing ${qualificationList.length} qualifications using UPDATE/INSERT pattern');

        final db = await _dbHelper.database;

        for (var qualificationData in qualificationList) {
          await db.insert(
            'qualification',
            qualificationData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print("Qualification table synchronized successfully.");
      } else {
        print(
            "Failed to sync qualification. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing qualification data: $e");
    }
  }

  Future<void> _syncQualification_selection() async {
    try {
      final response =
          await http.get(Uri.parse(AppConfig.syncQualificationSelectionUrl));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        List qualificationSelectionlist = [];

        // If the response is a Map with a key pointing to the actual list
        if (decodedResponse is Map) {
          // Assuming the data is inside a key like 'data', modify based on your actual structure
          qualificationSelectionlist = decodedResponse['data'] ??
              []; // Replace 'data' with the correct key if necessary
        } else if (decodedResponse is List) {
          // If the response is already a list
          qualificationSelectionlist = decodedResponse;
        }

        // SMART SYNC: Update existing, insert new (no delete)
        print(
            'Syncing ${qualificationSelectionlist.length} qualification selections using UPDATE/INSERT pattern');

        final db = await _dbHelper.database;

        for (var qualification_selectionData in qualificationSelectionlist) {
          await db.insert(
            'qualification_selection',
            qualification_selectionData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print("Qualification selection table synchronized successfully.");
      } else {
        print(
            "Failed to sync qualification selection. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing qualification data: $e");
    }
  }

  Future<void> _syncQualification_pathway() async {
    try {
      final response =
          await http.get(Uri.parse(AppConfig.syncQualificationPathwayUrl));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        List qualificationPathwaylist = [];

        // If the response is a Map with a key pointing to the actual list
        if (decodedResponse is Map) {
          // Assuming the data is inside a key like 'data', modify based on your actual structure
          qualificationPathwaylist = decodedResponse['data'] ??
              []; // Replace 'data' with the correct key if necessary
        } else if (decodedResponse is List) {
          // If the response is already a list
          qualificationPathwaylist = decodedResponse;
        }

        // SMART SYNC: Update existing, insert new (no delete)
        print(
            'Syncing ${qualificationPathwaylist.length} qualification pathways using UPDATE/INSERT pattern');

        final db = await _dbHelper.database;

        for (var qualification_pathwayData in qualificationPathwaylist) {
          await db.insert(
            'qualification_pathway',
            qualification_pathwayData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print("Qualification pathway table synchronized successfully.");
      } else {
        print(
            "Failed to sync qualification pathway. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing qualification data: $e");
    }
  }

  Future<void> _syncQualificationunitstandard() async {
    try {
      final response =
          await http.get(Uri.parse(AppConfig.syncQualificationUnitStandardUrl));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        List qualificationunitstandardList = [];

        // If the response is a Map with a key pointing to the actual list
        if (decodedResponse is Map) {
          // Assuming the data is inside a key like 'data', modify based on your actual structure
          qualificationunitstandardList = decodedResponse['data'] ??
              []; // Replace 'data' with the correct key if necessary
        } else if (decodedResponse is List) {
          // If the response is already a list
          qualificationunitstandardList = decodedResponse;
        }

        // SMART SYNC: Update existing, insert new (no delete)
        print(
            'Syncing ${qualificationunitstandardList.length} qualification unit standards using UPDATE/INSERT pattern');

        final db = await _dbHelper.database;

        for (var qualificationunitstandardData
            in qualificationunitstandardList) {
          await db.insert(
            'qualificationunitstandard',
            qualificationunitstandardData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print("Qualification unitstandard table synchronized successfully.");
      } else {
        print(
            "Failed to sync qualification unitstandard. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing qualification data: $e");
    }
  }

  Future<void> _syncUnitstandard() async {
    try {
      final response = await http.get(Uri.parse(AppConfig.syncUnitStandardUrl));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        List unitstandardList = [];

        // If the response is a Map with a key pointing to the actual list
        if (decodedResponse is Map) {
          // Assuming the data is inside a key like 'data', modify based on your actual structure
          unitstandardList = decodedResponse['data'] ??
              []; // Replace 'data' with the correct key if necessary
        } else if (decodedResponse is List) {
          // If the response is already a list
          unitstandardList = decodedResponse;
        }

        // SMART SYNC: Update existing, insert new (no delete)
        print(
            'Syncing ${unitstandardList.length} unit standards using UPDATE/INSERT pattern');

        final db = await _dbHelper.database;

        for (var unitstandardData in unitstandardList) {
          await db.insert(
            'unitstandard',
            unitstandardData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print("Unitstandard table synchronized successfully.");
      } else {
        print(
            "Failed to sync unitstandard. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing unitstandard data: $e");
    }
  }

  Future<void> _syncUnit_standard_selection() async {
    try {
      final response =
          await http.get(Uri.parse(AppConfig.syncUnitStandardSelectionUrl));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        List unitstandardSelectionList = [];

        // If the response is a Map with a key pointing to the actual list
        if (decodedResponse is Map) {
          // Assuming the data is inside a key like 'data', modify based on your actual structure
          unitstandardSelectionList = decodedResponse['data'] ??
              []; // Replace 'data' with the correct key if necessary
        } else if (decodedResponse is List) {
          // If the response is already a list
          unitstandardSelectionList = decodedResponse;
        }

        // SMART SYNC: Update existing, insert new (no delete)
        print(
            'Syncing ${unitstandardSelectionList.length} unit standard selections using UPDATE/INSERT pattern');

        final db = await _dbHelper.database;

        for (var unitstandardSelectionData in unitstandardSelectionList) {
          await db.insert(
            'unit_standard_selection',
            unitstandardSelectionData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print("Unit standard selection table synchronized successfully.");
      } else {
        print(
            "Failed to sync unit standard selection. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing unit standard selection: $e");
    }
  }

  Future<void> _syncAssessment() async {
    try {
      final response = await http.get(Uri.parse(AppConfig.syncAssessmentUrl));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        List assessmentsList = [];

        // If the response is a Map with a key pointing to the actual list
        if (decodedResponse is Map) {
          // Assuming the data is inside a key like 'data', modify based on your actual structure
          assessmentsList = decodedResponse['data'] ??
              []; // Replace 'data' with the correct key if necessary
        } else if (decodedResponse is List) {
          // If the response is already a list
          assessmentsList = decodedResponse;
        }

        // SMART SYNC: Update existing, insert new (no delete)
        print(
            'Syncing ${assessmentsList.length} assessments using UPDATE/INSERT pattern');

        final db = await _dbHelper.database;

        for (var assessmentsData in assessmentsList) {
          await db.insert(
            'assessments',
            assessmentsData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print("Assessments table synchronized successfully.");
      } else {
        print(
            "Failed to sync assessments. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing assessments: $e");
    }
  }

  Future<void> _syncPoe() async {
    try {
      final response = await http.get(Uri.parse(AppConfig.syncPoeUrl));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        List poeList = [];

        // If the response is a Map with a key pointing to the actual list
        if (decodedResponse is Map) {
          // Assuming the data is inside a key like 'data', modify based on your actual structure
          poeList = decodedResponse['data'] ??
              []; // Replace 'data' with the correct key if necessary
        } else if (decodedResponse is List) {
          // If the response is already a list
          poeList = decodedResponse;
        }

        // SMART SYNC: Update existing, insert new (no delete)
        print(
            'Syncing ${poeList.length} POE records using UPDATE/INSERT pattern');

        final db = await _dbHelper.database;

        for (var poeData in poeList) {
          await db.insert(
            'poe',
            poeData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        print("Poe table synchronized successfully.");
      } else {
        print("Failed to sync poe. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error syncing poe: $e");
    }
  }

  //Aknowledgement
  // Fetch unsynced records from the local database
  Future<List<Map<String, dynamic>>> getUnsyncedRecords() async {
    final db = await DatabaseHelper().database;
    final unsyncedRecords = await db
        .query('material_receipt_form', where: 'synced = ?', whereArgs: [0]);

    // Log the result
    print("Unsynced records fetched: $unsyncedRecords");

    return unsyncedRecords;
  }

  Future<Map<String, dynamic>> _getMultipartFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return {};
    final file = File(filePath);
    return await file.exists()
        ? {'name': file.path.split('/').last, 'tmp_name': file.path}
        : {};
  }

  Future<void> syncAcknowledgmentOfReceiptToServer() async {
    print("Syncing Acknowledgment of Receipt...");
    final unsyncedRecords = await getUnsyncedRecords();
    if (unsyncedRecords.isEmpty) {
      print("No records to sync.");
      return;
    }

    print("Found ${unsyncedRecords.length} unsynced records.");
    final Uri url = Uri.parse(AppConfig.syncAcknowledgmentDataUrl);
    List<Map<String, dynamic>> validRecords = [];
    var request = http.MultipartRequest('POST', url);

    for (int i = 0; i < unsyncedRecords.length; i++) {
      var record = unsyncedRecords[i];
      print("Processing record ${record['student_id_number']}");

      if ([
        'student_id_number',
        'student_full_name',
        'class_name',
        'description',
        'date_received',
        'learner_signature'
      ].any((key) => record[key] == null || record[key].toString().isEmpty)) {
        print(
            "Skipping record ${record['student_id_number']} due to missing required fields.");
        continue;
      }

      List<String> signaturePaths = [];
      if (record['learner_signature'] is String) {
        signaturePaths = [record['learner_signature']];
      } else if (record['learner_signature'] is List) {
        signaturePaths = List<String>.from(record['learner_signature']);
      }

      print(
          "Signature paths for record ${record['student_id_number']}: $signaturePaths");
      if (signaturePaths.isEmpty || !await _allFilesExist(signaturePaths)) {
        print(
            "Skipping record ${record['student_id_number']} - Missing or invalid signature files.");
        continue;
      }

      validRecords.add(record);
      for (int j = 0; j < signaturePaths.length; j++) {
        print("Adding signature file for record $i: ${signaturePaths[j]}");
        request.files.add(await http.MultipartFile.fromPath(
          'signature[]', // Simplified field name
          signaturePaths[j],
          contentType: MediaType('image', 'png'),
        ));
      }
    }

    if (validRecords.isEmpty) {
      print("No valid records to sync in form.");
      return;
    }

    print("Sending data to server: ${json.encode(validRecords)}");
    request.fields['data'] = json.encode(validRecords);

    try {
      var response = await request.send();
      String responseBody = await response.stream.bytesToString();
      print("Server response status: ${response.statusCode}");
      print("Server response body: $responseBody");

      if (response.statusCode == 200) {
        print("Batch sync successful for ${validRecords.length} records.");
        await _updateSyncedStatus(validRecords);
      } else {
        print(
            "Batch sync failed. Response: ${response.statusCode}, Body: $responseBody");
      }
    } catch (e) {
      print("Error syncing batch: $e");
    }
  }

  Future<bool> _allFilesExist(List<String> paths) async {
    for (String path in paths) {
      final file = File(path);
      if (!await file.exists()) {
        print("File does not exist: $path");
        return false;
      }
    }
    return true;
  }

  Future<void> _updateSyncedStatus(List<Map<String, dynamic>> records) async {
    final db = await DatabaseHelper().database;

    for (var record in records) {
      try {
        // Ensure the record has the 'id' field
        if (record['id'] == null) {
          print("Skipping record due to missing 'id' field: $record");
          continue;
        }

        print("Marking record ${record['id']} as synced.");

        // Update the 'synced' status to 1 for the record with the given 'id'
        await db.update(
          'material_receipt_form', // Ensure this is the correct table name
          {'synced': 1}, // Set the 'synced' column to 1
          where: 'id = ?', // Use 'id' as the primary key
          whereArgs: [
            record['id'].toString()
          ], // Pass the 'id' from the record as the argument
        );
      } catch (e) {
        // Log any error encountered while updating the record
        print("Error updating record ${record['id']}: $e");
      }
    }
  }

  // from sever to offline
  Future<void> syncDataFromServer() async {
    final serverUrl = AppConfig.syncMaterialFormsUrl; // Server endpoint

    try {
      // Fetch material forms from the server
      final response = await http.get(Uri.parse(serverUrl));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Check if the response is successful
        if (responseData['success'] == true) {
          List<dynamic> materialForms = responseData['data'];
          print(
              'Fetched ${materialForms.length} material forms from the server.');

          DatabaseHelper dbHelper = DatabaseHelper();

          // Insert each material form into the local SQLite database
          for (var form in materialForms) {
            print('Processing form: ${form['id']}');

            Map<String, dynamic> materialForm = {
              'id': form['id'],
              'classID': form['classID'],
              'facilitator_full_name': form['facilitator_full_name'],
              'representative_full_name': form['representative_full_name'],
              'qualification_name': form['qualification_name'],
              'facilitator_signature': form['facilitator_signature'],
              'representative_signature': form['representative_signature'],
              'description': form['description'],
              'quantity': form['quantity'],
              'is_synced': form['is_synced'],
              'created_at': form['created_at'],
              'updated_at': form['updated_at'],
            };

            // Print data before insertion
            print('Inserting form data: $materialForm');

            // Insert the material form data into the local database
            int result = await dbHelper.insertMaterialForm(materialForm);
            if (result > 0) {
              print('Successfully inserted form with ID: ${form['id']}');
            } else {
              print('Failed to insert form with ID: ${form['id']}');
            }
          }

          print(
              'Data successfully synced from the server to the local database');
        } else {
          print('Failed to fetch data from the server');
        }
      } else {
        print('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing data from server: $e');
    }
  }

  //Sync Function to Upload Data to Server
  Future<String> convertFileToBase64(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      return base64Encode(bytes); // Convert the file bytes to Base64
    } catch (e) {
      print('Error converting file to Base64: $e');
      return ''; // Return an empty string if there is an error
    }
  }

  // sync to online
  Future<void> syncMaterialFormsWithServer() async {
    final serverUrl = AppConfig.uploadSaveMaterialFormUrl; // Server endpoint

    try {
      // Fetch unsynced material forms from local SQLite database
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> unsyncedForms =
          await dbHelper.fetchUnsyncedMaterialForms();
      print('Unsynced records fetched: $unsyncedForms');

      // Loop through the unsynced material forms
      for (var form in unsyncedForms) {
        String classID = form['classID'].toString();
        String facilitatorFullName = form['facilitator_full_name'];
        String representativeFullName = form['representative_full_name'];
        String qualificationName = form['qualification_name'];
        String description = form['description'];
        int quantity = form['quantity'];
        bool isSynced = form['is_synced'] == 1;

        // Get the file paths for the signatures
        String facilitatorSignaturePath = form['facilitator_signature'];
        String representativeSignaturePath = form['representative_signature'];

        // Debug print to check values
        print('classID: $classID');
        print('facilitatorFullName: $facilitatorFullName');
        print('representativeFullName: $representativeFullName');
        print('qualificationName: $qualificationName');
        print('description: $description');
        print('facilitatorSignaturePath: $facilitatorSignaturePath');
        print('representativeSignaturePath: $representativeSignaturePath');

        // Get the created_at and updated_at values
        String createdAt = form['created_at'];
        String updatedAt = form['updated_at'];

        // Prepare the multipart request
        final request = http.MultipartRequest('POST', Uri.parse(serverUrl))
          ..fields['classID'] = classID
          ..fields['facilitatorFullName'] = facilitatorFullName
          ..fields['representativeFullName'] = representativeFullName
          ..fields['qualificationName'] = qualificationName
          ..fields['description'] = description
          ..fields['quantity'] = quantity.toString()
          ..fields['createdAt'] = createdAt
          ..fields['isSynced'] = isSynced.toString()
          ..fields['updatedAt'] = updatedAt;

        // Add the facilitator's signature image file
        var facilitatorSignatureFile = await http.MultipartFile.fromPath(
            'facilitatorSignature', facilitatorSignaturePath);
        request.files.add(facilitatorSignatureFile);

        // Add the representative's signature image file
        var representativeSignatureFile = await http.MultipartFile.fromPath(
            'representativeSignature', representativeSignaturePath);
        request.files.add(representativeSignatureFile);

        print('Uploading material form data for class ID: $classID');

        // Send the request
        final response = await request.send();

        if (response.statusCode == 200) {
          final responseData = await response.stream.bytesToString();
          final responseJson = json.decode(responseData);

          if (responseJson['success'] == true) {
            print('Material form synced successfully with server');
            // Update sync status in local database
            await dbHelper.updateSyncStatus(form['id']);
          } else {
            print('Failed to sync material form: ${responseJson['message']}');
          }
        } else {
          print('Server error: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error syncing material forms with server: $e');
    }
  }

  //for acknowlagment form
  Future<void> syncMaterialReceiptFormData() async {
    try {
      final response = await http.get(Uri.parse(AppConfig.saveReceiptFormUrl));

      if (response.statusCode == 200) {
        print('Response body: ${response.body}');

        final decodedResponse = jsonDecode(response.body);

        if (decodedResponse['status'] == 'success') {
          List<dynamic> receiptForms = decodedResponse['data'];

          if (receiptForms.isEmpty) {
            print('No material receipt forms found to sync.');
            return;
          }

          final db = await _dbHelper.database;

          await db.transaction((txn) async {
            await txn.delete('material_receipt_form');

            for (var receiptForm in receiptForms) {
              try {
                // Check for missing fields and log the specific ones
                if (receiptForm['student_id_number'] == null) {
                  print('Skipping record due to missing student_id_number');
                  continue;
                }
                if (receiptForm['class_name'] == null) {
                  print('Skipping record due to missing class_name');
                  continue;
                }

                // Handle missing fields with defaults
                String studentFullName =
                    receiptForm['student_full_name'] ?? 'Unknown';
                String received =
                    (receiptForm['received'] == 'Yes') ? 'Yes' : 'No';
                int quantity = receiptForm['quantity'] ?? 1;
                String description =
                    receiptForm['description'] ?? 'No description';
                String dateReceived = receiptForm['date_received'] ?? '';
                String practitionerName =
                    receiptForm['practitioner_full_name'] ?? 'Unknown';
                String learnerSignature =
                    receiptForm['learner_signature'] ?? '';
                int synced = receiptForm['synced'] ?? 0;

                await txn.insert(
                  'material_receipt_form',
                  {
                    'student_id_number': receiptForm['student_id_number'],
                    'student_full_name': studentFullName,
                    'class_name': receiptForm['class_name'],
                    'received': received,
                    'quantity': quantity,
                    'description': description,
                    'date_received': dateReceived,
                    'practitioner_full_name': practitionerName,
                    'learner_signature': learnerSignature,
                    'created_at':
                        receiptForm['created_at'] ?? DateTime.now().toString(),
                    'synced': synced,
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );

                print(
                    'Successfully inserted: ${receiptForm['student_id_number']}');
              } catch (e) {
                print('Error inserting material receipt form: $e');
              }
            }

            print('Material receipt form data synced successfully.');
          });
        } else {
          print(
              'Error syncing material receipt form data: ${decodedResponse['message']}');
        }
      } else {
        print(
            'Error: Failed to fetch material receipt form data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing material receipt form data: $e');
    }
  }

  Future<void> syncMaterialsReceivedData() async {
    try {
      // Define the PHP API URL for materials received data
      final apiUrl = AppConfig.saveMaterialsReceivedUrl;

      // Make the API call
      final response = await http.get(Uri.parse(apiUrl));

      // Check if the response is successful
      if (response.statusCode == 200) {
        print(
            'Response body: ${response.body}'); // Print the response for debugging

        try {
          // Decode the JSON response into a Map
          final Map<String, dynamic> data = jsonDecode(response.body);

          // Check if the response contains 'status' as 'success'
          if (data['status'] == 'success') {
            // Access the 'data' field which contains the list of materials received
            List<dynamic> materialsReceived = data['data'];

            if (materialsReceived.isEmpty) {
              print('No materials received data to sync.');
              return;
            }

            // Get an instance of the database
            final db = await _dbHelper.database;

            // Start a database transaction to insert the materials received data
            await db.transaction((txn) async {
              // Clear existing data in the 'materials_received' table before inserting new data
              await txn.delete('materials_received');

              // Insert each material into the table
              for (var material in materialsReceived) {
                try {
                  await txn.insert(
                    'materials_received',
                    {
                      'quantity':
                          material['quantity'] ?? 0, // Default value if missing
                      'received': material['received'] ??
                          'Unknown', // Default value if missing
                      'LearnerID': material['LearnerID'] ??
                          'Unknown', // Default value if missing
                      'Description': material['Description'] ??
                          'Unknown', // Default value if missing
                      'date_received': material['date_received'] ??
                          'Unknown', // Default value if missing
                      'facilitator_name': material['facilitator_name'] ??
                          'Unknown', // Default value if missing
                      'representative_name': material['representative_name'] ??
                          'Unknown', // Default value if missing
                      'signature': material['signature'] ??
                          'Unknown', // Default value if missing
                      'synced': 0, // Mark as unsynced
                    },
                    conflictAlgorithm: ConflictAlgorithm
                        .replace, // Or ConflictAlgorithm.ignore
                  );
                  print(
                      'Inserted material: ${material['LearnerID']}'); // Log inserted material
                } catch (e) {
                  print('Error inserting material: $e');
                }
              }
            });

            print('Materials received data synced successfully.');
          } else {
            print('Error syncing materials received data: ${data['message']}');
          }
        } catch (e) {
          print('Error decoding JSON response: $e');
        }
      } else {
        print(
            'Error: Failed to fetch materials received data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing materials received data: $e');
    }
  }

  // Method to sync project data
  Future<void> syncProjectData() async {
    try {
      // Define your PHP API URL
      final apiUrl = AppConfig.syncProjectUrl;

      // Make the API call
      final response = await http.get(Uri.parse(apiUrl));

      // Check if the response is successful
      if (response.statusCode == 200) {
        print(
            'Response body: ${response.body}'); // Print the response for debugging

        try {
          // Decode the JSON response into a Map
          final Map<String, dynamic> data = jsonDecode(response.body);

          // Check if the response contains 'status' as 'success'
          if (data['status'] == 'success') {
            // Access the 'data' field which contains the list of projects
            List<dynamic> projects = data['data'];

            // Get an instance of the database
            final db = await _dbHelper.database;

            // SMART SYNC: Update existing, insert new (no delete)
            print(
                'Syncing ${projects.length} projects using UPDATE/INSERT pattern');

            for (var project in projects) {
              // Check if required fields are missing and provide default values if necessary
              String projectName =
                  project['Project_name'] ?? 'Unknown Project'; // Default value
              String contractNo =
                  project['Contract_no'] ?? 'N/A'; // Default value
              String financialYear =
                  project['Financial_year'] ?? 'Unknown'; // Default value
              String startDate =
                  project['Start_date'] ?? 'Unknown'; // Default value
              String endDate =
                  project['End_date'] ?? 'Unknown'; // Default value
              String projectPathway =
                  project['Project_pathway'] ?? 'N/A'; // Default value
              String projectFunder =
                  project['Project_funder'] ?? 'N/A'; // Default value
              String province =
                  project['Province'] ?? 'Unknown'; // Default value
              String district =
                  project['District'] ?? 'Unknown'; // Default value
              String municipality =
                  project['Municipality'] ?? 'Unknown'; // Default value
              String ppe = project['PPE'] ?? 'Unknown'; // Default value
              String learningMaterial =
                  project['Learning_material'] ?? 'Unknown'; // Default value
              String toolkit = project['Toolkit'] ?? 'Unknown'; // Default value
              String consumables =
                  project['Consumables'] ?? 'Unknown'; // Default value
              String budget = project['Budget'] ?? 'Unknown'; // Default value
              String nBeneficiaries =
                  project['n_beneficiaries'] ?? '0'; // Default value

              await db.insert(
                'project',
                {
                  'project_id': project['project_id'],
                  'sdp_name': project['sdp_name'],
                  'client_name': project['client_name'],
                  'Project_name': projectName, // Ensure this is not NULL
                  'Contract_no': contractNo, // Ensure this is not NULL
                  'Financial_year': financialYear, // Ensure this is not NULL
                  'Start_date': startDate, // Ensure this is not NULL
                  'End_date': endDate, // Ensure this is not NULL
                  'Project_pathway': projectPathway, // Ensure this is not NULL
                  'Project_funder': projectFunder, // Ensure this is not NULL
                  'n_beneficiaries': nBeneficiaries, // Ensure this is not NULL
                  'Province': province, // Ensure this is not NULL
                  'District': district, // Ensure this is not NULL
                  'Municipality': municipality, // Ensure this is not NULL
                  'PPE': ppe, // Ensure this is not NULL
                  'Learning_material':
                      learningMaterial, // Ensure this is not NULL
                  'Toolkit': toolkit, // Ensure this is not NULL
                  'Consumables': consumables, // Ensure this is not NULL
                  'Budget': budget, // Ensure this is not NULL
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }

            print('Project data synced successfully.');
          } else {
            print('Error syncing project data: ${data['message']}');
          }
        } catch (e) {
          print('Error decoding JSON response: $e');
        }
      } else {
        print(
            'Error: Failed to fetch project data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing project data: $e');
    }
  }

  Future<void> syncToServerPOE(Map<String, dynamic> poe) async {
    try {
      final url = Uri.parse(AppConfig.syncPoeOnlineUrl);
      var request = http.MultipartRequest('POST', url);

      // Validate required fields
      String? learnerId = poe['learnerID']?.toString();
      if (learnerId == null ||
          learnerId.isEmpty ||
          poe['exercise'] == null ||
          poe['exercise'].toString().isEmpty ||
          poe['type'] == null ||
          poe['type'].toString().isEmpty ||
          poe['submitted_at'] == null ||
          poe['submitted_at'].toString().isEmpty) {
        print("Error: Missing required fields!");
        return;
      }

      // Get file path from poe record
      String? filePath = poe['filePath'];
      if (filePath == null || !await File(filePath).exists()) {
        print("No POE PDF found for $learnerId at $filePath");
        return;
      }

      // Add fields
      request.fields['learnerID'] = learnerId;
      request.fields['exercise'] = poe['exercise'].toString();
      request.fields['type'] = poe['type'].toString();
      request.fields['submitted_at'] = poe['submitted_at'].toString();

      // Attach PDF file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType('application', 'pdf'),
      ));

      print("Uploading POE PDF for LearnerID: $learnerId...");

      // Retry logic
      int maxRetries = 3;
      int retryCount = 0;
      while (retryCount < maxRetries) {
        try {
          final response =
              await request.send().timeout(const Duration(seconds: 30));
          final responseBody = await http.Response.fromStream(response);

          print("Server Response: ${responseBody.body}");

          if (responseBody.statusCode == 200) {
            var jsonResponse = jsonDecode(responseBody.body);
            if (jsonResponse['success'] == true) {
              await markAsSyncedPOE(poe['poe_id']);
              print("POE PDF for $learnerId synced successfully.");
              break;
            } else {
              print("Sync failed: ${jsonResponse['message']}");
            }
          } else {
            print("Sync failed: HTTP ${responseBody.statusCode}");
          }
        } catch (e) {
          retryCount++;
          print(
              "Retry $retryCount/$maxRetries for LearnerID: $learnerId, Error: $e");
          if (retryCount == maxRetries) {
            print("Max retries reached for LearnerID: $learnerId");
          }
          await Future.delayed(const Duration(seconds: 5));
        }
      }
    } catch (e) {
      print("Error syncing POE PDF: $e");
    }
  }

// Load unsynced POE data from local SQLite database
  Future<List<Map<String, dynamic>>> loadFromLocalPOE(Database db) async {
    try {
      List<Map<String, dynamic>> unsyncedData = await db.query(
        'poe',
        where: 'synced = 0', // Load only unsynced records
      );
      print("Loaded ${unsyncedData.length} unsynced POE records.");
      return unsyncedData;
    } catch (e) {
      print("Error loading POE data from local database: $e");
      return [];
    }
  }

// Mark POE record as synced in local database
  Future<void> markAsSyncedPOE(int poeId) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'poe',
        {'synced': 1},
        where: 'poe_id = ?',
        whereArgs: [poeId],
      );
      print("POE ID $poeId marked as synced.");
    } catch (e) {
      print("Error marking POE ID $poeId as synced: $e");
    }
  }

// Function to sync all unsynced POE records
  Future<void> syncAllPOERecords() async {
    final db = await _dbHelper.database;
    List<Map<String, dynamic>> unsyncedRecords = await loadFromLocalPOE(db);

    for (var poe in unsyncedRecords) {
      await syncToServerPOE(poe);
    }
  }

  // Helper to get unsynced learners
  Future<List<Map<String, dynamic>>> _getUnsyncedLearners() async {
    print('DEBUG: Starting _getUnsyncedLearners');
    final db = await _dbHelper.database;
    print('DEBUG: Database path: ${db.path}');
    try {
      final result = await db.query(
        'learnerdetails',
        where: 'synced = ?',
        whereArgs: [0],
      );
      print('DEBUG: Retrieved ${result.length} unsynced learners: $result');
      return result;
    } catch (e) {
      print('DEBUG: Error querying unsynced learners: $e');
      return [];
    }
  }

  Future<void> _markAsSynced(String learnerID) async {
    print('DEBUG: Marking learner $learnerID as synced');
    final db = await _dbHelper.database;
    final updatedRows = await db.update(
      'learnerdetails',
      {'synced': 1},
      where: 'LearnerID = ?',
      whereArgs: [learnerID],
    );
    print('DEBUG: Updated $updatedRows rows for LearnerID $learnerID');
  }

  Future<Map<String, dynamic>> syncLearnerDetails() async {
    print('DEBUG: Starting syncLearnerDetails');
    try {
      List<Map<String, dynamic>> unsyncedLearners =
          await _getUnsyncedLearners();
      print(
          'DEBUG: Found ${unsyncedLearners.length} unsynced learners to process');

      if (unsyncedLearners.isEmpty) {
        return {
          'success': true,
          'message': 'No unsynced learner records to sync.',
          'syncedCount': 0,
        };
      }

      int syncedCount = 0;
      List<String> errors = [];

      for (var learner in unsyncedLearners) {
        try {
          String? learnerID = learner['LearnerID']?.toString();
          if (learnerID == null || learnerID.isEmpty) {
            errors.add(
                'Skipping learner due to missing LearnerID: ${learner['Name'] ?? 'Unknown'}');
            print('DEBUG: ${errors.last}');
            continue;
          }

          String? idNumber = learner['IDNumber']?.toString();
          if (idNumber == null || idNumber.isEmpty) {
            errors.add(
                'Skipping learner due to missing IDNumber: ${learner['Name'] ?? 'Unknown'}');
            print('DEBUG: ${errors.last}');
            continue;
          }

          print('DEBUG: Sending request for learner $learnerID');

          var request = http.MultipartRequest(
            'POST',
            Uri.parse(AppConfig.syncOnlineDetailsUrl),
          );

          // Helper function to check if a value should be excluded
          bool shouldExcludeValue(String? value) {
            if (value == null) return true;
            final trimmed = value.trim();
            if (trimmed.isEmpty) return true;
            // Exclude common default/placeholder values
            final excludeValues = [
              'N/A',
              'n/a',
              '1900-01-01',
              '0',
              '0.0',
              'false',
              'null',
              'NULL',
              'undefined'
            ];
            return excludeValues.contains(trimmed);
          }

          // Always include required fields
          request.fields['LearnerID'] = learnerID;
          request.fields['IDNumber'] = idNumber;
          request.fields['classID'] = learner['classID']?.toString() ?? '0';
          request.fields['synced'] = '1';

          // Add a special flag to indicate this is a partial update
          request.fields['partial_update'] = 'true';

          // Add optional fields only if they have meaningful values
          final optionalFields = [
            'Title',
            'Name',
            'Surname',
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
            'activity_statu',
            'witness_initials',
            'learner_initials',
            'witness_signature',
            'zkteco_left_template',
            'zkteco_right_template',
            'futronic_left_template',
            'futronic_right_template',
            'imagePath'
          ];

          for (final key in optionalFields) {
            final value = learner[key]?.toString();
            if (!shouldExcludeValue(value)) {
              request.fields[key] = value!;
              print('DEBUG: Including field $key = $value');
            } else {
              print(
                  'DEBUG: Excluding field $key = $value (empty/default value)');
            }
          }

          print(
              'DEBUG: Final request fields for learner $learnerID (${request.fields.length} fields): ${request.fields}');

          // Add file uploads if they exist
          if (learner['profile_image'] != null &&
              File(learner['profile_image'].toString()).existsSync()) {
            print(
                'DEBUG: Adding profile_image for $learnerID: ${learner['profile_image']}');
            request.files.add(await http.MultipartFile.fromPath(
              'profile_image',
              learner['profile_image'].toString(),
            ));
          }

          if (learner['signature'] != null &&
              File(learner['signature'].toString()).existsSync()) {
            print(
                'DEBUG: Adding signature for $learnerID: ${learner['signature']}');
            request.files.add(await http.MultipartFile.fromPath(
              'signature',
              learner['signature'].toString(),
            ));
          }

          if (learner['witness_signature'] != null &&
              File(learner['witness_signature'].toString()).existsSync()) {
            print(
                'DEBUG: Adding witness_signature for $learnerID: ${learner['witness_signature']}');
            request.files.add(await http.MultipartFile.fromPath(
              'witness_signature',
              learner['witness_signature'].toString(),
            ));
          }

          var response = await request.send().timeout(
            const Duration(seconds: 120),
            onTimeout: () {
              errors.add('Request timed out for LearnerID $learnerID');
              print('DEBUG: ${errors.last}');
              return http.StreamedResponse(const Stream.empty(), 408);
            },
          );

          print(
              'DEBUG: Response status for $learnerID: ${response.statusCode}');
          print('DEBUG: Response headers: ${response.headers}');

          String responseBody = await response.stream.bytesToString();
          print('DEBUG: Raw response body for $learnerID: "$responseBody"');

          if (response.statusCode != 200) {
            errors.add(
                'Server error for LearnerID $learnerID: Status ${response.statusCode}, Response: $responseBody');
            print('DEBUG: ${errors.last}');
            continue;
          }

          if (responseBody.isEmpty) {
            errors.add('Empty server response for LearnerID $learnerID');
            print('DEBUG: ${errors.last}');
            continue;
          }

          try {
            Map<String, dynamic> jsonResponse = jsonDecode(responseBody);
            if (jsonResponse['success'] == true) {
              await _markAsSynced(learnerID);
              syncedCount++;
              print('DEBUG: Successfully synced learner $learnerID');
            } else {
              errors.add(
                  'Server error for LearnerID $learnerID: ${jsonResponse['error'] ?? 'Unknown server error'}');
              print('DEBUG: ${errors.last}');
            }
          } catch (e) {
            errors.add(
                'Failed to parse server response for LearnerID $learnerID: $e. Response: $responseBody');
            print('DEBUG: ${errors.last}');
          }
        } catch (e) {
          errors.add(
              'Error syncing LearnerID ${learner['LearnerID'] ?? 'unknown'}: $e - Data: $learner');
          print('DEBUG: ${errors.last}');
        }
      }

      final result = {
        'success': errors.isEmpty,
        'message': errors.isEmpty
            ? 'Synced $syncedCount records successfully'
            : 'Synced $syncedCount records with ${errors.length} errors',
        'syncedCount': syncedCount,
        'errors': errors.isEmpty ? null : errors,
      };
      print('DEBUG: Sync result: $result');
      return result;
    } catch (e) {
      print('DEBUG: Sync process failed: $e');
      return {
        'success': false,
        'message': 'Sync failed: $e',
        'syncedCount': 0,
      };
    }
  }

  Future<void> syncSickNotesToServer() async {
    print("Syncing Sick Notes to server...");
    final serverUrl = AppConfig.syncSickNotesUrl;

    try {
      // Fetch unsynced sick note records from local database
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> unsyncedRecords = await db.query(
        'sick_note',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (unsyncedRecords.isEmpty) {
        print("No unsynced sick notes to sync.");
        return;
      }

      print("Found ${unsyncedRecords.length} unsynced sick note records.");

      // Prepare multipart request for batch sync
      final request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      List<Map<String, dynamic>> validRecords = [];
      List<String> localFilePaths = [];

      for (int i = 0; i < unsyncedRecords.length; i++) {
        var record = unsyncedRecords[i];
        print("Processing sick note record: $record");

        // Check for required fields with null safety
        String? learnerId = record['learner_id']?.toString();
        String? documentPath = record['document_path']?.toString();
        String? practiceName = record['practice_name']?.toString();
        String? medicalPractitioner =
            record['medical_practitioner']?.toString();
        String? practitionerName = record['practitioner_name']?.toString();
        String? dateFrom = record['date_from']?.toString();
        String? dateTo = record['date_to']?.toString();
        String? uploadDate = record['upload_date']?.toString();
        String? status = record['status']?.toString();
        String? rejectionReason = record['rejection_reason']?.toString();

        // Validate required fields (all except rejection_reason)
        if (learnerId == null ||
            documentPath == null ||
            practiceName == null ||
            medicalPractitioner == null ||
            practitionerName == null ||
            dateFrom == null ||
            dateTo == null ||
            uploadDate == null ||
            status == null) {
          print(
              "Skipping record ${record['note_id']} due to null required fields.");
          continue;
        }

        // Validate document file existence
        try {
          final file = File(documentPath);
          if (!await file.exists()) {
            print(
                "Document file not found for record ${record['note_id']}: $documentPath");
            continue;
          }

          // Extract filename from document_path
          String fileName = path.basename(documentPath);

          // Add fields to validRecords, excluding 'note_id' and 'synced', using filename for document_path
          validRecords.add({
            'learner_id': learnerId,
            'document_path': fileName,
            'practice_name': practiceName,
            'medical_practitioner': medicalPractitioner,
            'practitioner_name': practitionerName,
            'date_from': dateFrom,
            'date_to': dateTo,
            'upload_date': uploadDate,
            'status': status,
            'rejection_reason': rejectionReason ?? '',
          });

          // Add document file to multipart request using a consistent field name
          request.files.add(await http.MultipartFile.fromPath(
            'document_file[]', // Use 'document_file[]' to group files
            documentPath,
            contentType: MediaType('application', 'pdf'),
            filename: fileName,
          ));
          print(
              "Added document file for record ${record['note_id']}: $documentPath (filename: $fileName)");

          // Track local file path for potential deletion
          localFilePaths.add(documentPath);
        } catch (e) {
          print(
              "Error adding document file for record ${record['note_id']}: $e");
          continue;
        }
      }

      if (validRecords.isEmpty) {
        print("No valid sick note records to sync.");
        return;
      }

      // Add valid records as JSON to the request
      print("Sending sick note data to server: ${json.encode(validRecords)}");
      request.fields['data'] = json.encode(validRecords);

      // Send the request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print("Server response status: ${response.statusCode}");
      print("Server response body: $responseBody");

      if (response.statusCode == 200) {
        try {
          final responseJson = json.decode(responseBody);
          if (responseJson['success'] == true) {
            print(
                "Batch sync successful for ${validRecords.length} sick note records.");
            // Update sync status for valid records
            await _updateSickNoteSyncedStatus(unsyncedRecords, validRecords);
          } else {
            print("Batch sync failed: ${responseJson['message']}");
          }
        } catch (e) {
          print("Error parsing server response: $e");
        }
      } else {
        print(
            "Batch sync failed. Response: ${response.statusCode}, Body: $responseBody");
      }
    } catch (e) {
      print("Error syncing sick notes to server: $e");
      rethrow;
    }
  }

// Helper method to update sync status for sick note records
  Future<void> _updateSickNoteSyncedStatus(
    List<Map<String, dynamic>> unsyncedRecords,
    List<Map<String, dynamic>> validRecords,
  ) async {
    final db = await _dbHelper.database;

    // Map valid records to their local IDs for updating
    for (int i = 0; i < validRecords.length; i++) {
      try {
        final localId = unsyncedRecords[i]['note_id'];
        if (localId == null) {
          print(
              "Skipping record due to missing 'note_id' field: ${unsyncedRecords[i]}");
          continue;
        }

        print("Marking sick note record $localId as synced.");
        await db.update(
          'sick_note',
          {'synced': 1},
          where: 'note_id = ?',
          whereArgs: [localId],
        );
      } catch (e) {
        print(
            "Error updating sick note record ${unsyncedRecords[i]['note_id']}: $e");
      }
    }
  }

  Future<void> sync_inductionClocking() async {
    final db = await _dbHelper.database;

    isSyncing = true;
    syncMessage = 'Syncing data to the server...';
    notifyListeners();

    try {
      // Only sync current day's records
      final today = DateTime.now().toIso8601String().split('T')[0];
      final List<Map<String, dynamic>> clockingDataList = await db.query(
        'induction_clocking',
        where: 'synced = ? AND clock_date = ?',
        whereArgs: [false, today],
      );

      if (clockingDataList.isEmpty) {
        syncMessage = 'No data to sync!';
        notifyListeners();
        return;
      }

      const maxRetries = 3;
      for (var clockingData in clockingDataList) {
        final clockingId = clockingData['clocking_id'];
        final LearnerID = clockingData['LearnerID'];
        final clockInTime = clockingData['clock_in_time'];
        final clockOutTime = clockingData['clock_out_time'];
        final contactTime = clockingData['contact_time'];
        final signaturePath = clockingData['signature_path'] ?? clockingData['signature'];
        final userLatitude = clockingData['user_latitude'];
        final userLongitude = clockingData['user_longitude'];
        final userAccuracy = clockingData['user_accuracy'];
        final clockDate = clockingData['clock_date'] ??
            DateTime.now().toIso8601String().split('T')[0];

        bool synced = false;
        for (var attempt = 1; attempt <= maxRetries; attempt++) {
          try {
            // Prepare multipart request
            var request = http.MultipartRequest(
              'POST',
              Uri.parse(AppConfig.syncInductionUrl),
            );

            // Add fields
            request.fields['clocking_id'] = clockingId.toString();
            request.fields['LearnerID'] = LearnerID.toString();
            request.fields['clock_in_time'] = clockInTime ?? '';
            request.fields['clock_out_time'] = clockOutTime ?? '';
            request.fields['contact_time'] = contactTime ?? '';
            request.fields['clock_date'] = clockDate;
            request.fields['user_latitude'] = userLatitude?.toString() ?? '';
            request.fields['user_longitude'] = userLongitude?.toString() ?? '';
            request.fields['user_accuracy'] = userAccuracy?.toString() ?? '';

            // Add signature file if it exists
            if (signaturePath != null && File(signaturePath).existsSync()) {
              var signatureFile = File(signaturePath);
              var signatureStream = http.ByteStream(signatureFile.openRead());
              var signatureLength = await signatureFile.length();
              var extension = path
                  .extension(signaturePath)
                  .toLowerCase()
                  .replaceFirst('.', '');
              var mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';

              var signatureMultipart = http.MultipartFile(
                'signature',
                signatureStream,
                signatureLength,
                filename: path.basename(signaturePath),
                contentType: MediaType.parse(mimeType),
              );
              request.files.add(signatureMultipart);
              print(
                  'Attempt $attempt: Signature file added: $signaturePath, MIME type: $mimeType');
            } else if (signaturePath != null) {
              print(
                  'Attempt $attempt: Signature file not found: $signaturePath');
            }

            // Log request details
            print('Attempt $attempt: Request fields: ${request.fields}');
            print(
                'Attempt $attempt: Request files: ${request.files.map((f) => f.filename).toList()}');

            // Send request
            final response =
                await request.send().timeout(const Duration(seconds: 30));
            final responseString = await response.stream.bytesToString();

            print(
                'Attempt $attempt: Server response for clocking_id $clockingId: $responseString (Status: ${response.statusCode})');

            if (response.statusCode == 200) {
              if (responseString.isEmpty) {
                print(
                    'Attempt $attempt: Empty response received for clocking_id $clockingId');
                syncMessage =
                    'Empty response from server for record $clockingId';
                if (attempt == maxRetries) {
                  syncMessage =
                      'Max retries reached for record $clockingId: Empty response';
                }
                await Future.delayed(const Duration(seconds: 1));
                continue;
              }

              try {
                final responseData = json.decode(responseString);
                if (responseData['status'] == 'success') {
                  await db.update(
                    'induction_clocking',
                    {'synced': true},
                    where: 'clocking_id = ?',
                    whereArgs: [clockingId],
                  );
                  syncMessage = 'Record $clockingId synced successfully!';
                  synced = true;
                  break;
                } else {
                  syncMessage =
                      'Server error for record $clockingId: ${responseData['message']}';
                  if (attempt == maxRetries) {
                    syncMessage =
                        'Max retries reached for record $clockingId: ${responseData['message']}';
                  }
                  await Future.delayed(const Duration(seconds: 1));
                  continue;
                }
              } catch (e) {
                print(
                    'Attempt $attempt: JSON parse error for clocking_id $clockingId: $e');
                syncMessage =
                    'Invalid response format for record $clockingId: $e';
                if (attempt == maxRetries) {
                  syncMessage =
                      'Max retries reached for record $clockingId: Invalid response';
                }
                await Future.delayed(const Duration(seconds: 1));
                continue;
              }
            } else {
              print(
                  'Attempt $attempt: Failed for clocking_id $clockingId: Status ${response.statusCode}, Response: $responseString');
              syncMessage =
                  'Failed to sync record $clockingId. Status: ${response.statusCode}, Response: $responseString';
              if (attempt == maxRetries) {
                syncMessage =
                    'Max retries reached for record $clockingId: Status ${response.statusCode}';
              }
              await Future.delayed(const Duration(seconds: 1));
              continue;
            }
          } catch (e) {
            print('Attempt $attempt: Error for clocking_id $clockingId: $e');
            syncMessage = 'Error syncing record $clockingId: $e';
            if (attempt == maxRetries) {
              syncMessage = 'Max retries reached for record $clockingId: $e';
            }
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
        }

        if (!synced) {
          syncMessage =
              'Failed to sync record $clockingId after $maxRetries attempts';
          notifyListeners();
        }
      }

      if (syncMessage.contains('Failed') || syncMessage.contains('Error')) {
        // Keep syncMessage as is to reflect the last error
      } else {
        syncMessage = 'All data synced successfully!';
      }
    } catch (e) {
      syncMessage = 'Sync failed: $e';
      print('Error syncing data: $e');
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncInductionClocking() async {
    try {
      final response =
          await http.get(Uri.parse(AppConfig.syncInductionClockingUrl));

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        var decodedData = json.decode(response.body);
        if (decodedData is List) {
          List clockingData = decodedData;
          print("Fetched ${clockingData.length} records");

          // DON'T clear the local table - preserve local clock-in states
          // await _dbHelper.clearTable('induction_clocking');
          print(
              "Syncing induction_clocking data without clearing local records");

          // Insert each record
          for (var clocking in clockingData) {
            // Map JSON keys to match table schema if needed
            var mappedClocking = {
              'clocking_id': clocking['clocking_id'],
              'LearnerID': clocking['LearnerID'] ??
                  clocking['learner_id'], // Handle key mismatch
              'clock_date': clocking['clock_date'],
              'clock_in_time': clocking['clock_in_time'],
              'clock_out_time': clocking['clock_out_time'],
              'contact_time': clocking['contact_time'],
              'signature': clocking['signature'],
              'synced': clocking['synced'] ?? 0, // Default to 0 if missing
              'user_latitude': clocking['user_latitude'],
              'user_longitude': clocking['user_longitude'],
              'user_accuracy': clocking['user_accuracy'],
            };

            // Validate required fields
            if (mappedClocking['clocking_id'] == null ||
                mappedClocking['LearnerID'] == null ||
                mappedClocking['clock_date'] == null ||
                mappedClocking['clock_in_time'] == null) {
              print("Skipping invalid record: $mappedClocking");
              continue;
            }

            print("Merging record: $mappedClocking");
            try {
              // Check if record exists locally
              final db = await _dbHelper.database;
              final existingRecords = await db.query(
                'induction_clocking',
                where: 'LearnerID = ? AND clock_date = ?',
                whereArgs: [
                  mappedClocking['LearnerID'],
                  mappedClocking['clock_date']
                ],
              );

              if (existingRecords.isNotEmpty) {
                final existingRecord = existingRecords.first;

                // PRESERVE local clock-in state if learner is currently clocked in
                // Only update if server has more recent complete data
                if (existingRecord['clock_in_time'] != null &&
                    existingRecord['clock_out_time'] == null &&
                    mappedClocking['clock_out_time'] != null) {
                  // Server has clock-out but we have local clock-in without clock-out
                  // This might be auto-generated - DON'T overwrite
                  print(
                      "PRESERVING local clock-in state for ${mappedClocking['LearnerID']} - server has auto clock-out");
                  continue;
                }

                // Update existing record with server data
                await db.update(
                  'induction_clocking',
                  mappedClocking,
                  where: 'LearnerID = ? AND clock_date = ?',
                  whereArgs: [
                    mappedClocking['LearnerID'],
                    mappedClocking['clock_date']
                  ],
                );
                print(
                    "Updated existing record for ${mappedClocking['LearnerID']}");
              } else {
                // Insert new record
                await _dbHelper.insertData(
                    'induction_clocking', mappedClocking);
                print("Inserted new record for ${mappedClocking['LearnerID']}");
              }
            } catch (e) {
              print("Error merging record $mappedClocking: $e");
            }
          }
          print("Synchronized ${clockingData.length} records");
        } else {
          print(
              "Error: Expected List, got ${decodedData.runtimeType}: $decodedData");
        }
      } else {
        print(
            "Failed to sync. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      print("Error syncing induction_clocking: $e");
    }
  }
}
