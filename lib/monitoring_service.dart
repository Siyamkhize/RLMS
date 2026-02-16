import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'config.dart';
import 'database_helper.dart';
import 'monitoring_popup_dialog.dart';

class MonitoringService {
  static final MonitoringService _instance = MonitoringService._internal();
  factory MonitoringService() => _instance;
  MonitoringService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  Timer? _backgroundTimer;
  bool _isServiceRunning = false;
  String? _currentClassID;
  BuildContext? _context;

  // Monitoring state
  bool _isMonitoringActive = false;
  bool _isLunchBreak = false;
  bool _isAfternoonSession = false;
  Map<String, dynamic>? _currentPerson;
  List<String> _verifiedToday = [];
  List<Map<String, dynamic>> _availablePeople = [];

  // Random generator
  final Random _random = Random();

  void startService(BuildContext context, String classID) {
    _context = context;
    _currentClassID = classID;

    if (_isServiceRunning) return;

    _isServiceRunning = true;
    debugPrint(
        '[MONITORING_SERVICE] Starting background monitoring service for class: $classID');

    // Check every 30 seconds for monitoring triggers
    _backgroundTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _checkAndTriggerMonitoring();
    });

    // Initial check
    _checkAndTriggerMonitoring();
  }

  void stopService() {
    _backgroundTimer?.cancel();
    _isServiceRunning = false;
    _isMonitoringActive = false;
    debugPrint('[MONITORING_SERVICE] Stopped background monitoring service');
  }

  Future<void> _checkAndTriggerMonitoring() async {
    if (!_isServiceRunning || _currentClassID == null || _context == null) {
      return;
    }

    try {
      final now = DateTime.now();
      final hour = now.hour;
      final minute = now.minute;

      // Update session status
      _isLunchBreak = (hour == 12) || (hour == 13 && minute == 0);
      _isAfternoonSession =
          (hour == 13 && minute >= 15) || (hour >= 14 && hour < 16);
      bool isMorningSession = hour < 12;

      // TIME RESTRICTIONS RESTORED
      // Skip if lunch break (12:00 PM - 1:15 PM)
      if (_isLunchBreak) {
        debugPrint('[MONITORING_SERVICE] Lunch break - monitoring paused');
        return;
      }

      // Skip if outside monitoring hours (before 12 PM or after 4 PM)
      if (!isMorningSession && !_isAfternoonSession) {
        return;
      }

      // Skip if already monitoring
      if (_isMonitoringActive) {
        return;
      }

      // Load available people (learners + facilitators)
      await _loadAvailablePeople();

      // Get total class size and calculate 30% requirement
      final totalClassSize = await _getTotalClassSize();
      final requiredVerifications = (totalClassSize * 0.3).ceil();

      debugPrint(
          '[MONITORING_SERVICE] Class size: $totalClassSize, Required verifications: $requiredVerifications, Verified today: ${_verifiedToday.length}');

      // Check if we need to start monitoring
      bool shouldStartMonitoring = false;

      if (isMorningSession) {
        // Morning: Start if haven't reached 30% yet and people are available
        shouldStartMonitoring = _verifiedToday.length < requiredVerifications &&
            _availablePeople.isNotEmpty;

        if (shouldStartMonitoring) {
          debugPrint(
              '[MONITORING_SERVICE] Morning session - need ${requiredVerifications - _verifiedToday.length} more verifications to reach 30%');
        }
      } else if (_isAfternoonSession) {
        // Afternoon: Continue until 30% requirement is met
        shouldStartMonitoring = _verifiedToday.length < requiredVerifications &&
            _availablePeople.isNotEmpty;

        if (shouldStartMonitoring) {
          debugPrint(
              '[MONITORING_SERVICE] Afternoon session - need ${requiredVerifications - _verifiedToday.length} more verifications to reach 30%');
        } else if (_verifiedToday.length >= requiredVerifications) {
          debugPrint(
              '[MONITORING_SERVICE] 30% verification requirement met (${_verifiedToday.length}/$requiredVerifications) - monitoring complete for today');
        }
      }

      if (shouldStartMonitoring) {
        await _triggerMonitoringPopup();
      }
    } catch (e) {
      debugPrint('[MONITORING_SERVICE] Error in background check: $e');
    }
  }

  /// Get total class size (registered learners)
  Future<int> _getTotalClassSize() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM learnerdetails WHERE classID = ?',
        [_currentClassID],
      );

      final count = result.first['count'] as int;
      debugPrint('[MONITORING_SERVICE] Total class size: $count');
      return count;
    } catch (e) {
      debugPrint('[MONITORING_SERVICE] Error getting class size: $e');
      return 0;
    }
  }

  Future<void> _loadAvailablePeople() async {
    try {
      // Get all people who clocked in today (learners + facilitators)
      _availablePeople =
          await _dbHelper.getAllClockedInPeopleForClass(_currentClassID!);

      // Load today's verified people
      await _loadVerifiedToday();

      // Filter out already verified people
      _availablePeople = _availablePeople.where((person) {
        String personKey = person['person_type'] == 'facilitator'
            ? 'F${person['person_id']}'
            : person['person_id'].toString();
        return !_verifiedToday.contains(personKey);
      }).toList();

      debugPrint(
          '[MONITORING_SERVICE] Available people: ${_availablePeople.length}');
    } catch (e) {
      debugPrint('[MONITORING_SERVICE] Error loading available people: $e');
    }
  }

  Future<void> _loadVerifiedToday() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final db = await _dbHelper.database;

      // IMPORTANT: Filter by class_id to track 30% per class
      final records = await db.query(
        'monitoring_records',
        where: 'monitoring_date = ? AND class_id = ? AND final_status = ?',
        whereArgs: [today, _currentClassID, 'PRESENT'],
      );

      _verifiedToday =
          records.map((record) => record['learner_id'].toString()).toList();

      debugPrint(
          '[MONITORING_SERVICE] Verified today in class $_currentClassID: ${_verifiedToday.length}');
    } catch (e) {
      debugPrint('[MONITORING_SERVICE] Error loading verified people: $e');
    }
  }

  Future<void> _triggerMonitoringPopup() async {
    if (_availablePeople.isEmpty || _context == null) return;

    // Select random person
    final randomIndex = _random.nextInt(_availablePeople.length);
    _currentPerson = _availablePeople[randomIndex];
    _isMonitoringActive = true;

    // Vibrate to alert
    await _vibrateAlert();

    // Show popup dialog
    if (_context != null && _context!.mounted) {
      showDialog(
        context: _context!,
        barrierDismissible: false,
        builder: (context) => MonitoringPopupDialog(
          person: _currentPerson!,
          onPresent: _handlePresent,
          onAbsent: _handleAbsent,
          classID: _currentClassID!,
        ),
      );
    }

    debugPrint(
        '[MONITORING_SERVICE] Triggered monitoring for: ${_currentPerson!['person_name']}');
  }

  Future<void> _vibrateAlert() async {
    try {
      // Vibrate pattern: short-long-short-long
      await HapticFeedback.heavyImpact();
      await Future.delayed(Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
      await Future.delayed(Duration(milliseconds: 500));
      await HapticFeedback.heavyImpact();
      await Future.delayed(Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('[MONITORING_SERVICE] Error with vibration: $e');
    }
  }

  Future<void> _handlePresent() async {
    if (_currentPerson == null) return;

    // Add to verified list
    String personKey =
        (_currentPerson!['person_type']?.toString() ?? '') == 'facilitator'
            ? 'F${_currentPerson!['person_id']}'
            : _currentPerson!['person_id'].toString();
    _verifiedToday.add(personKey);

    // Remove from available list
    _availablePeople.removeWhere((person) =>
        person['person_id'] == _currentPerson!['person_id'] &&
        person['person_type'] == _currentPerson!['person_type']);

    _isMonitoringActive = false;

    // Get total class size and calculate 30% requirement
    final totalClassSize = await _getTotalClassSize();
    final requiredVerifications = (totalClassSize * 0.3).ceil();

    debugPrint(
        '[MONITORING_SERVICE] Person marked as PRESENT: ${_currentPerson!['person_name']}');
    debugPrint(
        '[MONITORING_SERVICE] Verified today: ${_verifiedToday.length}/$requiredVerifications (30% requirement)');
    debugPrint(
        '[MONITORING_SERVICE] Available people count: ${_availablePeople.length}');

    // Save to database BEFORE clearing _currentPerson - AWAIT the operation
    await _saveMonitoringRecord('PRESENT');

    _currentPerson = null;

    // Check if 30% requirement is met
    if (_verifiedToday.length >= requiredVerifications) {
      debugPrint(
          '[MONITORING_SERVICE] ✅ 30% verification requirement met! Monitoring complete for today.');
      return;
    }

    // Continue monitoring if requirement not met and people available
    if (_availablePeople.isNotEmpty && !_isLunchBreak) {
      final now = DateTime.now();
      final hour = now.hour;
      final minute = now.minute;
      final isMorningSession = hour < 12;
      final isAfternoonSession =
          (hour == 13 && minute >= 15) || (hour >= 14 && hour < 16);

      // Continue in both morning and afternoon until 30% is reached
      if (isMorningSession || isAfternoonSession) {
        Timer(Duration(seconds: 3), () {
          debugPrint(
              '[MONITORING_SERVICE] Triggering next person - need ${requiredVerifications - _verifiedToday.length} more verifications');
          _triggerMonitoringPopup();
        });
      }
    } else {
      debugPrint(
          '[MONITORING_SERVICE] No more people available for monitoring');
    }
  }

  Future<void> _handleAbsent() async {
    if (_currentPerson == null) return;

    // Remove from available list
    _availablePeople.removeWhere((person) =>
        person['person_id'] == _currentPerson!['person_id'] &&
        person['person_type'] == _currentPerson!['person_type']);

    _isMonitoringActive = false;

    debugPrint(
        '[MONITORING_SERVICE] Person marked as ABSENT: ${_currentPerson!['person_name']}');

    // Save to database BEFORE clearing _currentPerson - AWAIT the operation
    await _saveMonitoringRecord('ABSENT');

    _currentPerson = null;

    // Get total class size and calculate 30% requirement
    final totalClassSize = await _getTotalClassSize();
    final requiredVerifications = (totalClassSize * 0.3).ceil();

    // Check if 30% requirement is met
    if (_verifiedToday.length >= requiredVerifications) {
      debugPrint(
          '[MONITORING_SERVICE] ✅ 30% verification requirement met! Monitoring complete for today.');
      return;
    }

    // Continue monitoring if requirement not met and people available
    if (_availablePeople.isNotEmpty && !_isLunchBreak) {
      final now = DateTime.now();
      final hour = now.hour;
      final minute = now.minute;
      final isMorningSession = hour < 12;
      final isAfternoonSession =
          (hour == 13 && minute >= 15) || (hour >= 14 && hour < 16);

      // Continue in both morning and afternoon until 30% is reached
      if (isMorningSession || isAfternoonSession) {
        Timer(Duration(seconds: 2), () {
          debugPrint(
              '[MONITORING_SERVICE] Triggering next person after ABSENT - need ${requiredVerifications - _verifiedToday.length} more verifications');
          _triggerMonitoringPopup();
        });
      }
    }
  }

  Future<void> _saveMonitoringRecord(String status) async {
    debugPrint(
        '[MONITORING_SERVICE] _saveMonitoringRecord called with status: $status');
    debugPrint('[MONITORING_SERVICE] _currentPerson: $_currentPerson');

    if (_currentPerson == null) {
      debugPrint(
          '[MONITORING_SERVICE] ERROR: Cannot save record - _currentPerson is null');
      return;
    }

    try {
      final db = await _dbHelper.database;

      // First, verify the table exists and has correct structure
      try {
        final tableInfo =
            await db.rawQuery("PRAGMA table_info(monitoring_records)");
        debugPrint('[MONITORING_SERVICE] Table structure: $tableInfo');

        if (tableInfo.isEmpty) {
          debugPrint(
              '[MONITORING_SERVICE] ERROR: monitoring_records table does not exist!');
          // Try to create the table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS monitoring_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              learner_id TEXT NOT NULL,
              learner_name TEXT NOT NULL,
              monitoring_date DATE NOT NULL,
              attempt_1_time DATETIME,
              attempt_1_status TEXT,
              attempt_2_time DATETIME,
              attempt_2_status TEXT,
              attempt_3_time DATETIME,
              attempt_3_status TEXT,
              final_status TEXT NOT NULL DEFAULT 'IN_PROGRESS',
              verification_time DATETIME,
              created_at DATETIME NOT NULL
            )
          ''');
          debugPrint('[MONITORING_SERVICE] Created monitoring_records table');
        }
      } catch (e) {
        debugPrint('[MONITORING_SERVICE] Error checking/creating table: $e');
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      // Add comprehensive null safety checks
      if (_currentPerson == null) {
        debugPrint('[MONITORING_SERVICE] ERROR: _currentPerson is null');
        return;
      }

      if (_currentPerson!['person_id'] == null) {
        debugPrint(
            '[MONITORING_SERVICE] ERROR: person_id is null in _currentPerson: $_currentPerson');
        return;
      }

      String personKey =
          (_currentPerson!['person_type']?.toString() ?? '') == 'facilitator'
              ? 'F${_currentPerson!['person_id']}'
              : _currentPerson!['person_id'].toString();

      // Ensure person_name is not null - for facilitators, combine firstName + lastName if needed
      String personName;
      if (_currentPerson!['person_name']?.toString().isNotEmpty == true) {
        personName = _currentPerson!['person_name'].toString();
      } else if ((_currentPerson!['person_type']?.toString() ?? '') ==
          'facilitator') {
        // For facilitators, try to get firstName + lastName from database
        try {
          final facilitatorId =
              int.parse(_currentPerson!['person_id'].toString());
          final db = await _dbHelper.database;
          final facilitatorData = await db.query(
            'facilitator',
            columns: ['firstName', 'lastName'],
            where: 'facilitator_id = ?',
            whereArgs: [facilitatorId],
          );

          if (facilitatorData.isNotEmpty) {
            final firstName =
                facilitatorData.first['firstName']?.toString() ?? '';
            final lastName =
                facilitatorData.first['lastName']?.toString() ?? '';
            personName = '$firstName $lastName'.trim();
            if (personName.isEmpty) personName = 'Facilitator $facilitatorId';
          } else {
            personName = 'Facilitator ${_currentPerson!['person_id']}';
          }
        } catch (e) {
          debugPrint('[MONITORING_SERVICE] Error getting facilitator name: $e');
          personName = 'Facilitator ${_currentPerson!['person_id']}';
        }
      } else {
        // For learners, try to get Name + Surname from database
        try {
          final learnerId = int.parse(_currentPerson!['person_id'].toString());
          final db = await _dbHelper.database;
          final learnerData = await db.query(
            'learnerdetails',
            columns: ['Name', 'Surname'],
            where: 'LearnerID = ?',
            whereArgs: [learnerId],
          );

          if (learnerData.isNotEmpty) {
            final name = learnerData.first['Name']?.toString() ?? '';
            final surname = learnerData.first['Surname']?.toString() ?? '';
            personName = '$name $surname'.trim();
            if (personName.isEmpty) personName = 'Learner $learnerId';
          } else {
            personName = 'Learner ${_currentPerson!['person_id']}';
          }
        } catch (e) {
          debugPrint('[MONITORING_SERVICE] Error getting learner name: $e');
          personName = 'Learner ${_currentPerson!['person_id']}';
        }
      }

      final recordData = {
        'learner_id': personKey,
        'learner_name': personName,
        'person_type': _currentPerson!['person_type'] ?? 'learner',
        'class_id': _currentClassID,
        'monitoring_date': today,
        'attempt_1_time': now,
        'attempt_1_status': status,
        'final_status': status,
        'verification_time': now,
        'verification_method':
            _currentPerson!['verification_method'] ?? 'fingerprint',
        'scanner_type': _currentPerson!['scanner_type'] ?? 'unknown',
        'fingerprint_matched': _currentPerson!['fingerprint_matched'] ?? 0,
        'session_type': _isAfternoonSession ? 'afternoon' : 'morning',
        'created_at': now,
        'synced': 0,
      };

      debugPrint('[MONITORING_SERVICE] Attempting to save monitoring record:');
      debugPrint('[MONITORING_SERVICE] _currentPerson data: $_currentPerson');
      debugPrint('[MONITORING_SERVICE] Resolved person name: $personName');
      debugPrint('[MONITORING_SERVICE] Record data: $recordData');

      // Use database helper's insertMonitoringClockin which has online-first logic
      final result = await _dbHelper.insertMonitoringClockin(recordData);

      debugPrint(
          '[MONITORING_SERVICE] ✅ Successfully saved monitoring record with ID: $result');
      debugPrint('[MONITORING_SERVICE] Status: $status for $personName');

      // Verify the record was saved
      final savedRecords = await db.query(
        'monitoring_records',
        where: 'learner_id = ? AND monitoring_date = ?',
        whereArgs: [personKey, today],
      );
      debugPrint(
          '[MONITORING_SERVICE] Verification: Found ${savedRecords.length} records for $personKey today');

      // Try to sync to server immediately (online-first)
      try {
        debugPrint(
            '[MONITORING_SERVICE] 🌐 Attempting online-first save to server...');
        final response = await http
            .post(
              Uri.parse(AppConfig.saveMonitoringRecordsUrl),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(recordData),
            )
            .timeout(Duration(seconds: 10));

        if (response.statusCode == 200) {
          final serverResult = json.decode(response.body);
          if (serverResult['success'] == true) {
            debugPrint('[MONITORING_SERVICE] ✅ Saved to server successfully');
            // Mark as synced
            await _dbHelper.markMonitoringClockinAsSynced(result);
          }
        }
      } catch (e) {
        debugPrint(
            '[MONITORING_SERVICE] ⚠️ Server save failed (will sync later): $e');
      }
    } catch (e, stackTrace) {
      debugPrint('[MONITORING_SERVICE] ❌ ERROR saving monitoring record: $e');
      debugPrint('[MONITORING_SERVICE] Stack trace: $stackTrace');
    }
  }

  // Getters for external access
  bool get isServiceRunning => _isServiceRunning;
  bool get isMonitoringActive => _isMonitoringActive;
  int get availablePeopleCount => _availablePeople.length;
  int get verifiedTodayCount => _verifiedToday.length;
}
