import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

// Optimized sync methods for DatabaseHelper class
// Add these methods to your existing DatabaseHelper class

class OptimizedSyncMethods {
  
  /// Fast sync for learners with NULL field optimization
  /// This method handles NULL values efficiently and provides batch processing
  static Future<void> syncLearnersOptimized(Database db, String classID, {
    bool basicFieldsOnly = true,
    int batchSize = 25,
    Function(String)? onProgress,
  }) async {
    try {
      debugPrint('[FAST_SYNC] Starting optimized learner sync for classID: $classID');
      onProgress?.call('Starting sync...');
      
      // Use the optimized endpoint
      final url = basicFieldsOnly 
          ? 'https://www.rlms.rlms.co.za/sync_learners_fast.php?classID=$classID&basicOnly=true'
          : 'https://www.rlms.rlms.co.za/sync_learners_fast.php?classID=$classID&basicOnly=false';
      
      debugPrint('[FAST_SYNC] Fetching from: $url');
      onProgress?.call('Fetching learner data...');
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['status'] != 'success') {
          throw Exception('Server error: ${responseData['message']}');
        }
        
        final List<dynamic> learnersData = responseData['data'];
        final meta = responseData['meta'];
        
        debugPrint('[FAST_SYNC] ===== OPTIMIZATION RESULTS =====');
        debugPrint('[FAST_SYNC] Received ${learnersData.length} learners');
        debugPrint('[FAST_SYNC] Response size: ${meta['optimizedSize']} bytes');
        debugPrint('[FAST_SYNC] Estimated original size: ${meta['estimatedOriginalSize']} bytes');
        debugPrint('[FAST_SYNC] Size savings: ${meta['sizeSavings']} bytes (${meta['compressionRatio']}%)');
        debugPrint('[FAST_SYNC] Basic fields only: ${meta['basicFieldsOnly']}');
        debugPrint('[FAST_SYNC] ===== END OPTIMIZATION RESULTS =====');
        
        onProgress?.call('Processing ${learnersData.length} learners...');
        
        // Get existing learners to preserve fingerprint data
        final existingLearners = await db.query(
          'learnerdetails',
          columns: ['LearnerID', 'zkteco_left_template', 'zkteco_right_template', 'futronic_left_template', 'futronic_right_template'],
          where: 'classID = ?',
          whereArgs: [classID],
        );
        
        // Create fingerprint preservation map
        Map<String, Map<String, String?>> fingerprintMap = {};
        for (var learner in existingLearners) {
          fingerprintMap[learner['LearnerID'].toString()] = {
            'zkteco_left_template': learner['zkteco_left_template']?.toString(),
            'zkteco_right_template': learner['zkteco_right_template']?.toString(),
            'futronic_left_template': learner['futronic_left_template']?.toString(),
            'futronic_right_template': learner['futronic_right_template']?.toString(),
          };
        }
        
        // Clear existing learners for this class
        await db.delete(
          'learnerdetails',
          where: 'classID = ?',
          whereArgs: [classID],
        );
        debugPrint('[FAST_SYNC] Cleared existing learners for classID: $classID');
        
        // Process learners in batches for better performance
        final batches = <List<dynamic>>[];
        for (int i = 0; i < learnersData.length; i += batchSize) {
          batches.add(learnersData.sublist(i, math.min(i + batchSize, learnersData.length)));
        }
        
        int processedCount = 0;
        for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
          final batch = batches[batchIndex];
          
          onProgress?.call('Processing batch ${batchIndex + 1}/${batches.length} (${batch.length} learners)...');
          
          // Use transaction for batch processing
          await db.transaction((txn) async {
            for (var learnerData in batch) {
              try {
                String learnerId = learnerData['LearnerID']?.toString() ?? '';
                
                // Create optimized learner record with NULL handling
                Map<String, dynamic> learnerRecord = {
                  'LearnerID': learnerId,
                  'classID': classID,
                  'synced': 1,
                };
                
                // Add only non-null fields from server data
                final fieldsToProcess = [
                  'Name', 'Surname', 'IDNumber', 'PhoneNumber', 'Title', 'DateOfBirth',
                  'Email', 'Age', 'Gender', 'Race', 'Language', 'Disability',
                  'AddressLine1', 'AddressLine2', 'AddressLine3', 'PostalCode',
                  'KinName', 'KinRelation', 'KinContact', 'SchoolName', 'SchoolCompletion',
                  'SchoolLocation', 'SchoolGrade', 'profile_image', 'signature',
                  'imagePath', 'activity_statu', 'witness_initials', 'learner_initials',
                  'witness_signature'
                ];
                
                for (String field in fieldsToProcess) {
                  final value = learnerData[field];
                  if (value != null && value.toString().isNotEmpty) {
                    learnerRecord[field] = value.toString();
                  }
                  // Don't add NULL or empty values - let database handle defaults
                }
                
                // Preserve existing fingerprint templates if they exist
                if (fingerprintMap.containsKey(learnerId)) {
                  final fingerprints = fingerprintMap[learnerId]!;
                  fingerprints.forEach((key, value) {
                    if (value != null && value.isNotEmpty) {
                      learnerRecord[key] = value;
                    }
                  });
                }
                
                // Insert the optimized record
                await txn.insert('learnerdetails', learnerRecord);
                processedCount++;
                
              } catch (e) {
                debugPrint('[FAST_SYNC] Error processing learner ${learnerData['LearnerID']}: $e');
                // Continue with next learner instead of failing entire batch
              }
            }
          });
          
          debugPrint('[FAST_SYNC] Completed batch ${batchIndex + 1}/${batches.length}');
        }
        
        // Handle bank details separately if they exist
        if (!basicFieldsOnly) {
          onProgress?.call('Processing bank details...');
          await _processBankDetailsOptimized(db, learnersData);
        }
        
        debugPrint('[FAST_SYNC] Successfully processed $processedCount learners');
        onProgress?.call('Sync completed: $processedCount learners processed');
        
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FAST_SYNC] Error in optimized sync: $e');
      onProgress?.call('Sync failed: $e');
      throw Exception('Failed to sync learners: $e');
    }
  }
  
  /// Process bank details separately to avoid NULL field issues
  static Future<void> _processBankDetailsOptimized(Database db, List<dynamic> learnersData) async {
    try {
      // Clear existing bank details for learners in this sync
      final learnerIds = learnersData.map((l) => l['LearnerID']?.toString()).where((id) => id != null).toList();
      if (learnerIds.isNotEmpty) {
        final placeholders = learnerIds.map((_) => '?').join(',');
        await db.delete(
          'bankdetails',
          where: 'LearnerID IN ($placeholders)',
          whereArgs: learnerIds,
        );
      }
      
      // Insert bank details only for learners that have bank information
      for (var learner in learnersData) {
        final learnerId = learner['LearnerID']?.toString();
        if (learnerId == null) continue;
        
        // Check if learner has any bank information
        final hasBankInfo = (learner['BankName'] != null && learner['BankName'].toString().isNotEmpty) ||
                           (learner['bankType'] != null && learner['bankType'].toString().isNotEmpty) ||
                           (learner['BankAccount'] != null && learner['BankAccount'].toString().isNotEmpty) ||
                           (learner['BankCode'] != null && learner['BankCode'].toString().isNotEmpty);
        
        if (hasBankInfo) {
          Map<String, dynamic> bankData = {
            'LearnerID': learnerId,
          };
          
          // Add only non-null bank fields
          final bankFields = ['BankName', 'bankType', 'BankAccount', 'BankCode'];
          for (String field in bankFields) {
            final value = learner[field];
            if (value != null && value.toString().isNotEmpty) {
              bankData[field] = value.toString();
            }
          }
          
          await db.insert('bankdetails', bankData);
          debugPrint('[FAST_SYNC] Saved bank details for learner: $learnerId');
        }
      }
    } catch (e) {
      debugPrint('[FAST_SYNC] Error processing bank details: $e');
      // Don't throw - bank details are optional
    }
  }
  
  /// Paginated sync for very large classes
  static Future<void> syncLearnersPaginated(Database db, String classID, {
    int pageSize = 50,
    Function(String)? onProgress,
  }) async {
    try {
      int page = 1;
      bool hasMore = true;
      int totalProcessed = 0;
      
      onProgress?.call('Starting paginated sync...');
      
      while (hasMore) {
        debugPrint('[PAGINATED_SYNC] Fetching page $page with $pageSize learners');
        onProgress?.call('Fetching page $page...');
        
        final url = 'https://www.rlms.rlms.co.za/get_learners_optimized.php?classID=$classID&page=$page&limit=$pageSize&includeFingerprints=false';
        
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          
          if (responseData['status'] != 'success') {
            throw Exception('Server error: ${responseData['message']}');
          }
          
          final List<dynamic> learnersData = responseData['data'];
          final pagination = responseData['pagination'];
          
          debugPrint('[PAGINATED_SYNC] Page $page: ${learnersData.length} learners');
          
          // Process this page
          if (learnersData.isNotEmpty) {
            await _processLearnerBatch(db, learnersData, classID, page == 1);
            totalProcessed += learnersData.length;
          }
          
          hasMore = pagination['hasNext'] == true;
          page++;
          
          onProgress?.call('Processed $totalProcessed learners...');
          
        } else {
          throw Exception('Server returned status code: ${response.statusCode}');
        }
      }
      
      debugPrint('[PAGINATED_SYNC] Completed: $totalProcessed learners processed');
      onProgress?.call('Sync completed: $totalProcessed learners');
      
    } catch (e) {
      debugPrint('[PAGINATED_SYNC] Error: $e');
      onProgress?.call('Sync failed: $e');
      throw Exception('Paginated sync failed: $e');
    }
  }
  
  /// Process a batch of learners efficiently
  static Future<void> _processLearnerBatch(Database db, List<dynamic> learners, String classID, bool clearFirst) async {
    await db.transaction((txn) async {
      // Clear existing learners only on first batch
      if (clearFirst) {
        await txn.delete(
          'learnerdetails',
          where: 'classID = ?',
          whereArgs: [classID],
        );
      }
      
      // Insert learners in batch
      for (var learner in learners) {
        Map<String, dynamic> learnerRecord = {
          'LearnerID': learner['LearnerID']?.toString() ?? '',
          'classID': classID,
          'synced': 1,
        };
        
        // Add non-null fields only
        learner.forEach((key, value) {
          if (key != 'LearnerID' && value != null && value.toString().isNotEmpty) {
            learnerRecord[key] = value.toString();
          }
        });
        
        await txn.insert('learnerdetails', learnerRecord);
      }
    });
  }
}