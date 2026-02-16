import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_helper.dart';
import 'config.dart';

class SyncServiceNullSafe {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Enhanced sync learnerdetails with null value handling
  Future<void> syncLearnerDetailsNullSafe() async {
    try {
      // Verify connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.wifi) &&
          !connectivityResult.contains(ConnectivityResult.mobile)) {
        print("No network available, skipping learner details sync");
        return;
      }

      // Use the null-safe endpoint
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/sync_learnerdetails_null_safe.php'),
        headers: {'Content-Type': 'application/json'},
      );

      print("Server response status: ${response.statusCode}");
      print("Server response body length: ${response.body.length}");

      if (response.statusCode == 200) {
        final List<dynamic> learners = json.decode(response.body);
        if (learners.isEmpty) {
          print("Warning: No learner data received from API");
          return;
        }

        print("Received ${learners.length} learners from server");

        final db = await _dbHelper.database;

        // Clear existing learner details
        await _dbHelper.clearTable('learnerdetails');
        print("Cleared existing learner details");

        int successCount = 0;
        int errorCount = 0;

        // Insert records one by one with enhanced null handling
        for (var learner in learners) {
          try {
            // Validate required fields
            if (learner['IDNumber'] == null || learner['classID'] == null) {
              print("Skipping invalid learner record: Missing IDNumber or classID");
              errorCount++;
              continue;
            }

            // Create a sanitized copy of the learner data
            Map<String, dynamic> sanitizedLearnerData = _sanitizeLearnerData(learner);

            // Insert using the enhanced insertData method
            await _dbHelper.insertData('learnerdetails', sanitizedLearnerData);
            
            print("✅ Successfully inserted learner: ${sanitizedLearnerData['Name']} ${sanitizedLearnerData['Surname']} (ID: ${sanitizedLearnerData['IDNumber']})");
            successCount++;
            
          } catch (e) {
            print("❌ Error inserting learner ${learner['IDNumber']}: $e");
            errorCount++;
            // Continue with other learners even if one fails
          }
        }

        print("Sync completed: $successCount successful, $errorCount errors");
        
        // Verify the sync
        final insertedCount = await db.rawQuery('SELECT COUNT(*) as count FROM learnerdetails');
        final count = insertedCount.first['count'];
        print("Verification: $count learners now in local database");

      } else {
        throw Exception("Failed to sync learner details. Status code: ${response.statusCode}");
      }
    } catch (e, stackTrace) {
      print("Error syncing learner details: $e");
      print("Stack trace: $stackTrace");
      rethrow;
    }
  }

  // Sanitize learner data to handle null values properly
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
      'zkteco_right_template': _sanitizeString(rawData['zkteco_right_template']),
      'futronic_left_template': _sanitizeString(rawData['futronic_left_template']),
      'futronic_right_template': _sanitizeString(rawData['futronic_right_template']),
      'imagePath': _sanitizeString(rawData['imagePath']),
      'activity_statu': _sanitizeString(rawData['activity_statu']),
      'witness_initials': _sanitizeString(rawData['witness_initials']),
      'learner_initials': _sanitizeString(rawData['learner_initials']),
      'witness_signature': _sanitizeString(rawData['witness_signature']),
    };
  }

  // Helper methods for sanitizing different data types
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

  String? _sanitizeDate(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      // Validate date format
      try {
        DateTime.parse(value);
        return value;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Test method to check sync status
  Future<Map<String, dynamic>> testSyncStatus() async {
    try {
      final db = await _dbHelper.database;
      
      // Count total learners
      final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM learnerdetails');
      final totalCount = totalResult.first['count'];
      
      // Count learners with null values in key fields
      final nullNameResult = await db.rawQuery('SELECT COUNT(*) as count FROM learnerdetails WHERE Name IS NULL OR Name = ""');
      final nullNameCount = nullNameResult.first['count'];
      
      final nullPhoneResult = await db.rawQuery('SELECT COUNT(*) as count FROM learnerdetails WHERE PhoneNumber IS NULL OR PhoneNumber = ""');
      final nullPhoneCount = nullPhoneResult.first['count'];
      
      // Sample some records
      final sampleResult = await db.rawQuery('SELECT LearnerID, Name, Surname, IDNumber, PhoneNumber FROM learnerdetails LIMIT 5');
      
      return {
        'status': 'success',
        'totalLearners': totalCount,
        'learnersWithNullName': nullNameCount,
        'learnersWithNullPhone': nullPhoneCount,
        'sampleRecords': sampleResult,
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }
}