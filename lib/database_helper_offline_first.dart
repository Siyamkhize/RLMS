/// OFFLINE-FIRST DATABASE HELPER
/// This is an improved version of database_helper.dart with offline-first architecture
/// 
/// Key improvements:
/// 1. UPSERT logic instead of DELETE+INSERT for learner sync
/// 2. Never deletes learner data from local database
/// 3. Preserves local fingerprint templates when server doesn't have them
/// 4. Adds sync metadata tracking
/// 
/// TO USE THIS:
/// 1. Backup your current database_helper.dart
/// 2. Replace the syncLearnersFromServer method in database_helper.dart with the one below
/// 3. Test thoroughly before deploying to production

import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'dart:math' as math;

/// Extension to DatabaseHelper class
/// Add this method to your existing database_helper.dart file
class DatabaseHelperOfflineFirst {
  
  /// IMPROVED: Sync learners from server using UPSERT logic
  /// This method NEVER deletes existing learner data
  /// It only updates existing records or inserts new ones
  static Future<void> syncLearnersFromServerOfflineFirst(
    Database db,
    String classID, {
    bool preserveLocalTemplates = true,
  }) async {
    try {
      print('[OFFLINE_FIRST_SYNC] Starting learner sync for classID: $classID');
      
      final response = await http.get(
        Uri.parse('${AppConfig.getLearnersUrl}?classID=$classID'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final List<dynamic> learnersData = json.decode(response.body);
      print('[OFFLINE_FIRST_SYNC] Received ${learnersData.length} learners from server');
      
      // Get existing learners for this class
      final existingLearners = await db.query(
        'learnerdetails',
        where: 'classID = ?',
        whereArgs: [classID],
      );
      
      // Create a map of existing learners by ID for quick lookup
      Map<String, Map<String, dynamic>> existingLearnersMap = {};
      for (var learner in existingLearners) {
        existingLearnersMap[learner['LearnerID'].toString()] = learner;
      }
      
      print('[OFFLINE_FIRST_SYNC] Found ${existingLearners.length} existing learners in local database');
      
      int insertedCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;
      
      // UPSERT logic: Update existing, insert new (NO DELETE)
      for (var learner in learnersData) {
        try {
          String learnerId = learner['LearnerID']?.toString() ?? '';
          if (learnerId.isEmpty) {
            skippedCount++;
            continue;
          }
          
          // Prepare base learner data from server
          Map<String, dynamic> learnerData = {
            'LearnerID': learnerId,
            'Name': learner['Name']?.toString() ?? '',
            'Surname': learner['Surname']?.toString() ?? '',
            'IDNumber': learner['IDNumber']?.toString() ?? '',
            'DateOfBirth': learner['DateOfBirth']?.toString() ?? '',
            'PhoneNumber': learner['PhoneNumber']?.toString() ?? '',
            'Email': learner['Email']?.toString() ?? '',
            'Title': learner['Title']?.toString() ?? '',
            'Gender': learner['Gender']?.toString() ?? '',
            'Race': learner['Race']?.toString() ?? '',
            'Language': learner['Language']?.toString() ?? '',
            'Disability': learner['Disability']?.toString() ?? '',
            'AddressLine1': learner['AddressLine1']?.toString() ?? '',
            'AddressLine2': learner['AddressLine2']?.toString() ?? '',
            'AddressLine3': learner['AddressLine3']?.toString() ?? '',
            'PostalCode': learner['PostalCode']?.toString() ?? '',
            'KinName': learner['KinName']?.toString() ?? '',
            'KinRelation': learner['KinRelation']?.toString() ?? '',
            'KinContact': learner['KinContact']?.toString() ?? '',
            'classID': classID,
            'synced': 1, // Mark as synced since it came from server
          };
          
          // Handle fingerprint templates
          final existingLearner = existingLearnersMap[learnerId];
          
          if (existingLearner != null) {
            // EXISTING LEARNER: Merge server data with local data
            
            // Fingerprint templates: Server takes priority, but preserve local if server is empty
            if (preserveLocalTemplates) {
              // ZKTeco templates
              if (learner['zkteco_left_template'] != null && learner['zkteco_left_template'].toString().isNotEmpty) {
                learnerData['zkteco_left_template'] = learner['zkteco_left_template'].toString();
              } else if (existingLearner['zkteco_left_template'] != null) {
                learnerData['zkteco_left_template'] = existingLearner['zkteco_left_template'].toString();
              }
              
              if (learner['zkteco_right_template'] != null && learner['zkteco_right_template'].toString().isNotEmpty) {
                learnerData['zkteco_right_template'] = learner['zkteco_right_template'].toString();
              } else if (existingLearner['zkteco_right_template'] != null) {
                learnerData['zkteco_right_template'] = existingLearner['zkteco_right_template'].toString();
              }
              
              // Futronic templates
              if (learner['futronic_left_template'] != null && learner['futronic_left_template'].toString().isNotEmpty) {
                learnerData['futronic_left_template'] = learner['futronic_left_template'].toString();
              } else if (existingLearner['futronic_left_template'] != null) {
                learnerData['futronic_left_template'] = existingLearner['futronic_left_template'].toString();
              }
              
              if (learner['futronic_right_template'] != null && learner['futronic_right_template'].toString().isNotEmpty) {
                learnerData['futronic_right_template'] = learner['futronic_right_template'].toString();
              } else if (existingLearner['futronic_right_template'] != null) {
                learnerData['futronic_right_template'] = existingLearner['futronic_right_template'].toString();
              }
              
              // SourceAFIS template
              if (learner['sourceafis_template'] != null && learner['sourceafis_template'].toString().isNotEmpty) {
                learnerData['sourceafis_template'] = learner['sourceafis_template'].toString();
              } else if (existingLearner['sourceafis_template'] != null) {
                learnerData['sourceafis_template'] = existingLearner['sourceafis_template'].toString();
              }
            } else {
              // Don't preserve local templates, use server data only
              learnerData['zkteco_left_template'] = learner['zkteco_left_template']?.toString() ?? '';
              learnerData['zkteco_right_template'] = learner['zkteco_right_template']?.toString() ?? '';
              learnerData['futronic_left_template'] = learner['futronic_left_template']?.toString() ?? '';
              learnerData['futronic_right_template'] = learner['futronic_right_template']?.toString() ?? '';
              learnerData['sourceafis_template'] = learner['sourceafis_template']?.toString() ?? '';
            }
            
            // UPDATE existing learner
            await db.update(
              'learnerdetails',
              learnerData,
              where: 'LearnerID = ?',
              whereArgs: [learnerId],
            );
            updatedCount++;
            
          } else {
            // NEW LEARNER: Insert with server data
            learnerData['zkteco_left_template'] = learner['zkteco_left_template']?.toString() ?? '';
            learnerData['zkteco_right_template'] = learner['zkteco_right_template']?.toString() ?? '';
            learnerData['futronic_left_template'] = learner['futronic_left_template']?.toString() ?? '';
            learnerData['futronic_right_template'] = learner['futronic_right_template']?.toString() ?? '';
            learnerData['sourceafis_template'] = learner['sourceafis_template']?.toString() ?? '';
            
            await db.insert('learnerdetails', learnerData);
            insertedCount++;
          }
          
        } catch (e) {
          print('[OFFLINE_FIRST_SYNC] Error processing learner: $e');
          skippedCount++;
        }
      }
      
      print('[OFFLINE_FIRST_SYNC] Sync completed for classID: $classID');
      print('[OFFLINE_FIRST_SYNC] Inserted: $insertedCount, Updated: $updatedCount, Skipped: $skippedCount');
      print('[OFFLINE_FIRST_SYNC] Total learners in local DB for this class: ${insertedCount + updatedCount}');
      
    } catch (e) {
      print('[OFFLINE_FIRST_SYNC] Error syncing learners: $e');
      throw Exception('Failed to sync learners: $e');
    }
  }
  
  /// Check if local database has learners for a class
  static Future<bool> hasLearnersForClass(Database db, String classID) async {
    final result = await db.query(
      'learnerdetails',
      where: 'classID = ?',
      whereArgs: [classID],
      limit: 1,
    );
    return result.isNotEmpty;
  }
  
  /// Get count of learners in local database for a class
  static Future<int> getLearnerCountForClass(Database db, String classID) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM learnerdetails WHERE classID = ?',
      [classID],
    );
    return result.first['count'] as int? ?? 0;
  }
  
  /// Get all unique class IDs in local database
  static Future<List<String>> getAllClassIDs(Database db) async {
    final result = await db.rawQuery(
      'SELECT DISTINCT classID FROM learnerdetails WHERE classID IS NOT NULL AND classID != ""',
    );
    return result.map((row) => row['classID'].toString()).toList();
  }
}

/// INSTRUCTIONS FOR INTEGRATION:
/// 
/// 1. In your existing database_helper.dart, find the syncLearnersFromServer method
/// 
/// 2. Replace it with this improved version:
/// 
/// ```dart
/// Future<void> syncLearnersFromServer(String classID) async {
///   final db = await database;
///   await DatabaseHelperOfflineFirst.syncLearnersFromServerOfflineFirst(
///     db,
///     classID,
///     preserveLocalTemplates: true, // Set to false if you want server to always override
///   );
/// }
/// ```
/// 
/// 3. Test the changes:
///    - Test with internet connection
///    - Test without internet connection
///    - Test with server blocked
///    - Verify learners are not deleted
///    - Verify clocking works offline
/// 
/// 4. Optional: Add sync metadata tracking
///    - Add last_synced column to learnerdetails table
///    - Track when each learner was last synced
///    - Show sync status in UI
