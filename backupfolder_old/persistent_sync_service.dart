import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_helper.dart';
import 'config.dart';

/// Persistent Sync Service - Maintains local data for offline operations
/// 
/// Key Features:
/// - Never clears local data
/// - Uses UPSERT strategy (INSERT OR REPLACE)
/// - Maintains offline availability
/// - Incremental updates only
class PersistentSyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Sync learner details with UPSERT strategy (never clears existing data)
  Future<Map<String, dynamic>> syncLearnerDetailsPersistent({String? classID}) async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      if (!isOnline) {
        print('[PERSISTENT_SYNC] Offline - using cached local data');
        final localCount = await _getLocalLearnerCount(classID);
        return {
          'success': true,
          'message': 'Offline mode - using $localCount cached learners',
          'count': localCount,
          'mode': 'offline',
        };
      }

      print('[PERSISTENT_SYNC] Online - syncing learner data...');

      // Build URL with optional classID filter
      String url = AppConfig.syncLearnerDetailsUrl;
      if (classID != null) {
        url += '?classID=$classID';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> learners = json.decode(response.body);
        
        if (learners.isEmpty) {
          print('[PERSISTENT_SYNC] No learner data received from server');
          final localCount = await _getLocalLearnerCount(classID);
          return {
            'success': true,
            'message': 'No server data - using $localCount cached learners',
            'count': localCount,
            'mode': 'cached',
          };
        }

        print('[PERSISTENT_SYNC] Received ${learners.length} learners from server');

        int insertedCount = 0;
        int updatedCount = 0;
        int errorCount = 0;

        // CRITICAL: Use UPSERT instead of clearing data
        for (var learner in learners) {
          try {
            // Validate required fields
            if (learner['IDNumber'] == null || learner['classID'] == null) {
              print('[PERSISTENT_SYNC] Skipping invalid learner: Missing IDNumber or classID');
              errorCount++;
              continue;
            }

            // Check if learner exists locally
            final exists = await _learnerExists(learner['LearnerID']);
            
            // Upsert learner data (INSERT OR REPLACE)
            await _dbHelper.upsertLearner(learner);
            
            if (exists) {
              updatedCount++;
              print('[PERSISTENT_SYNC] ✅ Updated: ${learner['Name']} ${learner['Surname']} (ID: ${learner['LearnerID']})');
            } else {
              insertedCount++;
              print('[PERSISTENT_SYNC] ✅ Inserted: ${learner['Name']} ${learner['Surname']} (ID: ${learner['LearnerID']})');
            }
            
          } catch (e) {
            print('[PERSISTENT_SYNC] ❌ Error processing learner ${learner['LearnerID']}: $e');
            errorCount++;
          }
        }

        final totalLocal = await _getLocalLearnerCount(classID);
        
        print('[PERSISTENT_SYNC] Sync completed:');
        print('  - Inserted: $insertedCount');
        print('  - Updated: $updatedCount');
        print('  - Errors: $errorCount');
        print('  - Total local: $totalLocal');

        return {
          'success': true,
          'message': 'Synced successfully',
          'inserted': insertedCount,
          'updated': updatedCount,
          'errors': errorCount,
          'total': totalLocal,
          'mode': 'online',
        };

      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
      
    } catch (e, stackTrace) {
      print('[PERSISTENT_SYNC] Error: $e');
      print('[PERSISTENT_SYNC] Stack trace: $stackTrace');
      
      // Even on error, check if we have local data
      final localCount = await _getLocalLearnerCount(classID);
      
      return {
        'success': false,
        'message': 'Sync failed but $localCount learners available locally',
        'error': e.toString(),
        'count': localCount,
        'mode': 'error_fallback',
      };
    }
  }

  /// Check if learner exists in local database
  Future<bool> _learnerExists(int learnerID) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'learnerdetails',
      where: 'LearnerID = ?',
      whereArgs: [learnerID],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get count of learners in local database
  Future<int> _getLocalLearnerCount(String? classID) async {
    final db = await _dbHelper.database;
    
    String query = 'SELECT COUNT(*) as count FROM learnerdetails';
    List<dynamic> args = [];
    
    if (classID != null) {
      query += ' WHERE classID = ?';
      args.add(classID);
    }
    
    final result = await db.rawQuery(query, args);
    return result.first['count'] as int? ?? 0;
  }

  /// Check if local data is available for offline operations
  Future<bool> isDataAvailableOffline(String classID) async {
    final count = await _getLocalLearnerCount(classID);
    return count > 0;
  }

  /// Get local data status for diagnostics
  Future<Map<String, dynamic>> getLocalDataStatus(String? classID) async {
    final db = await _dbHelper.database;
    
    // Total learners
    final totalCount = await _getLocalLearnerCount(classID);
    
    // Learners with fingerprints
    String fingerprintQuery = '''
      SELECT COUNT(*) as count FROM learnerdetails 
      WHERE (zkteco_left_template IS NOT NULL AND zkteco_left_template != '')
         OR (zkteco_right_template IS NOT NULL AND zkteco_right_template != '')
         OR (futronic_left_template IS NOT NULL AND futronic_left_template != '')
         OR (futronic_right_template IS NOT NULL AND futronic_right_template != '')
    ''';
    
    if (classID != null) {
      fingerprintQuery += ' AND classID = ?';
    }
    
    final fingerprintResult = await db.rawQuery(
      fingerprintQuery,
      classID != null ? [classID] : [],
    );
    final fingerprintCount = fingerprintResult.first['count'] as int? ?? 0;
    
    // Sample records
    String sampleQuery = 'SELECT LearnerID, Name, Surname, IDNumber, classID FROM learnerdetails';
    if (classID != null) {
      sampleQuery += ' WHERE classID = ?';
    }
    sampleQuery += ' LIMIT 5';
    
    final sampleResult = await db.rawQuery(
      sampleQuery,
      classID != null ? [classID] : [],
    );
    
    return {
      'totalLearners': totalCount,
      'learnersWithFingerprints': fingerprintCount,
      'offlineReady': totalCount > 0,
      'sampleRecords': sampleResult,
      'classID': classID,
    };
  }

  /// Force refresh - clears and re-syncs all data (use sparingly)
  Future<Map<String, dynamic>> forceRefreshAllData() async {
    try {
      print('[PERSISTENT_SYNC] ⚠️ FORCE REFRESH - Clearing all local data');
      
      // Check connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      if (!isOnline) {
        return {
          'success': false,
          'message': 'Cannot force refresh while offline',
          'mode': 'offline',
        };
      }

      // Clear existing data
      await _dbHelper.clearTable('learnerdetails');
      print('[PERSISTENT_SYNC] Cleared existing learner data');

      // Re-sync from server
      return await syncLearnerDetailsPersistent();
      
    } catch (e) {
      print('[PERSISTENT_SYNC] Force refresh error: $e');
      return {
        'success': false,
        'message': 'Force refresh failed: $e',
        'error': e.toString(),
      };
    }
  }
}
