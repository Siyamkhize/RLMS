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
  Map<String, dynamic>? _currentPerson;

  // Track selected learners and their prompt status
  final List<String> _morningSelectedLearners = []; // 2 learners for morning
  final List<String> _afternoonSelectedLearners =
      []; // 2 learners for afternoon
  final Map<String, int> _promptAttempts =
      {}; // Track prompt attempts per learner
  final Map<String, DateTime> _lastPromptTime =
      {}; // Track when learner was last prompted
  final Map<String, bool> _learnerResponded = {}; // Track if learner responded

  DateTime? _firstClockInTime; // Track first clock-in of the day
  bool _monitoringStarted = false; // Track if 2-hour wait has passed

  // Random generator
  final Random _random = Random();

  void startService(BuildContext context, String classID) {
    _context = context;
    _currentClassID = classID;

    if (_isServiceRunning) return;

    _isServiceRunning = true;
    debugPrint(
        '[MONITORING_SERVICE] Starting background monitoring service for class: $classID');

    // Check every 1 minute for monitoring triggers
    _backgroundTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
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

      // Determine session type
      final isLunchBreak = (hour == 12) || (hour == 13 && minute < 15);
      final isMorningSession = hour >= 8 && hour < 12;
      final isAfternoonSession =
          (hour == 13 && minute >= 15) || (hour >= 14 && hour < 16);

      // Skip if lunch break
      if (isLunchBreak) {
        debugPrint('[MONITORING_SERVICE] Lunch break - monitoring paused');
        return;
      }

      // Skip if outside monitoring hours
      if (!isMorningSession && !isAfternoonSession) {
        return;
      }

      // Skip if already showing a popup
      if (_isMonitoringActive) {
        return;
      }

      // Get first clock-in time if not set
      if (_firstClockInTime == null) {
        _firstClockInTime = await _getFirstClockInTime();
        if (_firstClockInTime != null) {
          debugPrint(
              '[MONITORING_SERVICE] First clock-in time: $_firstClockInTime');
        }
      }

      // Check if 2 hours have passed since first clock-in
      if (_firstClockInTime != null && !_monitoringStarted) {
        final timeSinceFirstClockIn = now.difference(_firstClockInTime!);
        if (timeSinceFirstClockIn.inHours >= 2) {
          _monitoringStarted = true;
          debugPrint(
              '[MONITORING_SERVICE] ✅ 2 hours passed since first clock-in - monitoring activated!');
        } else {
          debugPrint(
              '[MONITORING_SERVICE] Waiting for 2 hours since first clock-in (${timeSinceFirstClockIn.inMinutes} minutes elapsed)');
          return;
        }
      }

      if (!_monitoringStarted) {
        return; // Don't start monitoring until 2 hours have passed
      }

      // Select learners for the session if not already selected
      if (isMorningSession && _morningSelectedLearners.isEmpty) {
        await _selectLearnersForSession('morning');
      } else if (isAfternoonSession && _afternoonSelectedLearners.isEmpty) {
        await _selectLearnersForSession('afternoon');
      }

      // Get learners to prompt based on session
      final learnersToPrompt = isMorningSession
          ? _morningSelectedLearners
          : _afternoonSelectedLearners;

      if (learnersToPrompt.isEmpty) {
        debugPrint(
            '[MONITORING_SERVICE] No learners selected for this session');
        return;
      }

      // Check each learner and prompt if needed
      for (final learnerId in learnersToPrompt) {
        // Skip if learner already responded
        if (_learnerResponded[learnerId] == true) {
          continue;
        }

        final attempts = _promptAttempts[learnerId] ?? 0;
        final lastPrompt = _lastPromptTime[learnerId];

        // First prompt - trigger immediately
        if (attempts == 0) {
          await _promptLearner(learnerId);
          break; // Only prompt one learner at a time
        }

        // Second prompt - wait 10-15 minutes after first prompt
        if (attempts == 1 && lastPrompt != null) {
          final timeSinceLastPrompt = now.difference(lastPrompt);
          final waitTime = 10 + _random.nextInt(6); // Random 10-15 minutes

          if (timeSinceLastPrompt.inMinutes >= waitTime) {
            debugPrint(
                '[MONITORING_SERVICE] $waitTime minutes passed - prompting learner again');
            await _promptLearner(learnerId);
            break; // Only prompt one learner at a time
          }
        }

        // After 2 attempts, mark as non-responsive and move to next learner
        if (attempts >= 2) {
          debugPrint(
              '[MONITORING_SERVICE] Learner $learnerId did not respond after 2 attempts');
          _learnerResponded[learnerId] = false;
          await _saveMonitoringRecord(learnerId, 'ABSENT');
        }
      }
    } catch (e) {
      debugPrint('[MONITORING_SERVICE] Error in background check: $e');
    }
  }

  /// Get the first clock-in time of the day for this class
  Future<DateTime?> _getFirstClockInTime() async {
    try {
      final db = await _dbHelper.database;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final result = await db.rawQuery('''
        SELECT MIN(clock_in_time) as first_clock_in
        FROM learner_clocking
        WHERE clock_date = ? 
        AND LearnerID IN (SELECT LearnerID FROM learnerdetails WHERE classID = ?)
      ''', [today, _currentClassID]);

      if (result.isNotEmpty && result.first['first_clock_in'] != null) {
        final clockInStr = result.first['first_clock_in'] as String;
        return DateTime.parse('$today $clockInStr');
      }
      return null;
    } catch (e) {
      debugPrint('[MONITORING_SERVICE] Error getting first clock-in time: $e');
      return null;
    }
  }

  /// Select 2 random learners for the session (morning or afternoon)
  Future<void> _selectLearnersForSession(String session) async {
    try {
      final db = await _dbHelper.database;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Get all learners who clocked in today for this class
      final result = await db.rawQuery('''
        SELECT DISTINCT ld.LearnerID, ld.Name, ld.Surname
        FROM learner_clocking lc
        INNER JOIN learnerdetails ld ON lc.LearnerID = ld.LearnerID
        WHERE lc.clock_date = ? AND ld.classID = ?
      ''', [today, _currentClassID]);

      if (result.isEmpty) {
        debugPrint('[MONITORING_SERVICE] No learners clocked in today');
        return;
      }

      // Filter out learners already selected in other session
      final allSelectedLearners = [
        ..._morningSelectedLearners,
        ..._afternoonSelectedLearners
      ];
      final availableLearners = result.where((learner) {
        final learnerId = learner['LearnerID'].toString();
        return !allSelectedLearners.contains(learnerId);
      }).toList();

      if (availableLearners.isEmpty) {
        debugPrint(
            '[MONITORING_SERVICE] No available learners (all already selected)');
        return;
      }

      // Randomly select 2 learners (or less if not enough available)
      final numToSelect =
          availableLearners.length >= 2 ? 2 : availableLearners.length;
      final selectedLearners = <String>[];

      final shuffled = List.from(availableLearners)..shuffle(_random);
      for (int i = 0; i < numToSelect; i++) {
        final learnerId = shuffled[i]['LearnerID'].toString();
        selectedLearners.add(learnerId);
        _promptAttempts[learnerId] = 0;
        _learnerResponded[learnerId] = false;
      }

      if (session == 'morning') {
        _morningSelectedLearners.clear();
        _morningSelectedLearners.addAll(selectedLearners);
        debugPrint(
            '[MONITORING_SERVICE] Selected ${selectedLearners.length} learners for MORNING: $selectedLearners');
      } else {
        _afternoonSelectedLearners.clear();
        _afternoonSelectedLearners.addAll(selectedLearners);
        debugPrint(
            '[MONITORING_SERVICE] Selected ${selectedLearners.length} learners for AFTERNOON: $selectedLearners');
      }
    } catch (e) {
      debugPrint('[MONITORING_SERVICE] Error selecting learners: $e');
    }
  }

  /// Prompt a specific learner
  Future<void> _promptLearner(String learnerId) async {
    try {
      final db = await _dbHelper.database;

      // Get learner details
      final result = await db.query(
        'learnerdetails',
        where: 'LearnerID = ?',
        whereArgs: [int.parse(learnerId)],
      );

      if (result.isEmpty) {
        debugPrint('[MONITORING_SERVICE] Learner $learnerId not found');
        return;
      }

      final learner = result.first;
      _currentPerson = {
        'person_id': learnerId,
        'person_name': '${learner['Name']} ${learner['Surname']}',
        'person_type': 'learner',
      };

      // Update prompt tracking
      _promptAttempts[learnerId] = (_promptAttempts[learnerId] ?? 0) + 1;
      _lastPromptTime[learnerId] = DateTime.now();
      _isMonitoringActive = true;

      debugPrint(
          '[MONITORING_SERVICE] Prompting learner: ${_currentPerson!['person_name']} (Attempt ${_promptAttempts[learnerId]})');

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
    } catch (e) {
      debugPrint('[MONITORING_SERVICE] Error prompting learner: $e');
      _isMonitoringActive = false;
    }
  }

  Future<void> _vibrateAlert() async {
    try {
      // Vibrate pattern: short-long-short-long
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 500));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('[MONITORING_SERVICE] Error with vibration: $e');
    }
  }

  Future<void> _handlePresent() async {
    if (_currentPerson == null) return;

    final learnerId = _currentPerson!['person_id'].toString();

    // Mark learner as responded
    _learnerResponded[learnerId] = true;
    _isMonitoringActive = false;

    debugPrint('[MONITORING_SERVICE] Learner $learnerId marked as PRESENT');

    // Save to database
    await _saveMonitoringRecord(learnerId, 'PRESENT');

    _currentPerson = null;
  }

  Future<void> _handleAbsent() async {
    if (_currentPerson == null) return;

    final learnerId = _currentPerson!['person_id'].toString();

    // Mark learner as responded (but absent)
    _learnerResponded[learnerId] = false;
    _isMonitoringActive = false;

    debugPrint('[MONITORING_SERVICE] Learner $learnerId marked as ABSENT');

    // Save to database
    await _saveMonitoringRecord(learnerId, 'ABSENT');

    _currentPerson = null;
  }

  Future<void> _saveMonitoringRecord(String learnerId, String status) async {
    try {
      final db = await _dbHelper.database;

      // Create table if doesn't exist
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
          final_status TEXT NOT NULL,
          verification_time DATETIME,
          verification_method TEXT,
          scanner_type TEXT,
          fingerprint_matched INTEGER DEFAULT 0,
          session_type TEXT,
          created_at DATETIME NOT NULL,
          synced INTEGER DEFAULT 0
        )
      ''');

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final hour = DateTime.now().hour;
      final sessionType = hour < 12 ? 'morning' : 'afternoon';

      // Get learner name
      final learnerResult = await db.query(
        'learnerdetails',
        where: 'LearnerID = ?',
        whereArgs: [int.parse(learnerId)],
      );

      String learnerName = 'Unknown';
      if (learnerResult.isNotEmpty) {
        learnerName =
            '${learnerResult.first['Name']} ${learnerResult.first['Surname']}';
      }

      final attempts = _promptAttempts[learnerId] ?? 1;

      final recordData = {
        'learner_id': learnerId,
        'learner_name': learnerName,
        'person_type': 'learner',
        'class_id': _currentClassID,
        'monitoring_date': today,
        'attempt_1_time': attempts >= 1 ? now : null,
        'attempt_1_status': attempts >= 1 ? status : null,
        'attempt_2_time': attempts >= 2 ? now : null,
        'attempt_2_status': attempts >= 2 ? status : null,
        'final_status': status,
        'verification_time': now,
        'verification_method':
            _currentPerson?['verification_method'] ?? 'fingerprint',
        'scanner_type': _currentPerson?['scanner_type'] ?? 'unknown',
        'fingerprint_matched': _currentPerson?['fingerprint_matched'] ?? 0,
        'session_type': sessionType,
        'created_at': now,
        'synced': 0,
      };

      debugPrint('[MONITORING_SERVICE] Saving monitoring record: $recordData');

      await db.insert('monitoring_records', recordData);

      // Try to sync to server
      try {
        final response = await http
            .post(
              Uri.parse(AppConfig.saveMonitoringRecordsUrl),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(recordData),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          if (result['success'] == true) {
            debugPrint('[MONITORING_SERVICE] ✅ Saved to server successfully');
            await db.update(
              'monitoring_records',
              {'synced': 1},
              where: 'learner_id = ? AND monitoring_date = ?',
              whereArgs: [learnerId, today],
            );
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
  bool get monitoringStarted => _monitoringStarted;
  int get morningLearnersCount => _morningSelectedLearners.length;
  int get afternoonLearnersCount => _afternoonSelectedLearners.length;
}
