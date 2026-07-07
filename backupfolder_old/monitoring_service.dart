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

  // Scheduled monitoring times with random windows
  final Map<String, DateTime?> _scheduledPromptTimes = {
    'morning_learner_1': null, // Random between 9:00-9:30 AM
    'morning_learner_2': null, // Random between 10:30-11:00 AM
    'afternoon_learner_1': null, // Random between 13:15-13:45 (1:15-1:45 PM)
    'afternoon_learner_2': null, // Random between 14:00-15:15 (2:00-3:15 PM)
  };

  bool _learnersSelected =
      false; // Track if learners have been selected for the day

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

  /// Update the context reference (useful when navigating between pages)
  void updateContext(BuildContext context) {
    if (_isServiceRunning) {
      _context = context;
      debugPrint('[MONITORING_SERVICE] Context updated');
    }
  }

  void stopService() {
    _backgroundTimer?.cancel();
    _isServiceRunning = false;
    _isMonitoringActive = false;
    _learnersSelected = false;

    // Clear all selections and tracking for next day
    _morningSelectedLearners.clear();
    _afternoonSelectedLearners.clear();
    _promptAttempts.clear();
    _lastPromptTime.clear();
    _learnerResponded.clear();
    _scheduledPromptTimes.clear();

    debugPrint('[MONITORING_SERVICE] Stopped background monitoring service');
  }

  Future<void> _checkAndTriggerMonitoring() async {
    if (!_isServiceRunning || _currentClassID == null) {
      return;
    }

    // Check if context is available and mounted
    if (_context == null) {
      debugPrint('[MONITORING_SERVICE] ⚠️ Context is null - monitoring paused');
      return;
    }

    if (!_context!.mounted) {
      debugPrint(
          '[MONITORING_SERVICE] ⚠️ Context not mounted - monitoring paused');
      return;
    }

    try {
      final now = DateTime.now();
      final hour = now.hour;
      final minute = now.minute;

      debugPrint(
          '[MONITORING_SERVICE] Checking time: $hour:${minute.toString().padLeft(2, '0')}');

      // Skip if already showing a popup
      if (_isMonitoringActive) {
        return;
      }

      // Select learners for the day if not already done
      if (!_learnersSelected) {
        await _selectLearnersForDay();
        _setupScheduledTimes(now);
        _learnersSelected = true;
      }

      // Check each scheduled time slot
      await _checkScheduledPrompts(now);
    } catch (e) {
      debugPrint('[MONITORING_SERVICE] Error in background check: $e');
    }
  }

  /// Setup random scheduled times within specified windows for the day
  void _setupScheduledTimes(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    // Morning Learner 1: Random time between 9:00-9:30 AM
    final morning1Start = today.add(const Duration(hours: 9)); // 9:00 AM
    final morning1RandomMinutes = _random.nextInt(31); // 0-30 minutes
    _scheduledPromptTimes['morning_learner_1'] =
        morning1Start.add(Duration(minutes: morning1RandomMinutes));

    // Morning Learner 2: Random time between 10:30-11:00 AM
    final morning2Start =
        today.add(const Duration(hours: 10, minutes: 30)); // 10:30 AM
    final morning2RandomMinutes = _random.nextInt(31); // 0-30 minutes
    _scheduledPromptTimes['morning_learner_2'] =
        morning2Start.add(Duration(minutes: morning2RandomMinutes));

    // Afternoon Learner 1: Random time between 13:15-13:45 (1:15-1:45 PM)
    final afternoon1Start =
        today.add(const Duration(hours: 13, minutes: 15)); // 1:15 PM
    final afternoon1RandomMinutes = _random.nextInt(31); // 0-30 minutes
    _scheduledPromptTimes['afternoon_learner_1'] =
        afternoon1Start.add(Duration(minutes: afternoon1RandomMinutes));

    // Afternoon Learner 2: Random time between 14:00-15:15 (2:00-3:15 PM)
    final afternoon2Start = today.add(const Duration(hours: 14)); // 2:00 PM
    final afternoon2RandomMinutes =
        _random.nextInt(76); // 0-75 minutes (1 hour 15 minutes)
    _scheduledPromptTimes['afternoon_learner_2'] =
        afternoon2Start.add(Duration(minutes: afternoon2RandomMinutes));

    debugPrint('[MONITORING_SERVICE] 🎲 Random monitoring times generated:');
    debugPrint(
        '[MONITORING_SERVICE] Morning Learner 1: ${DateFormat('HH:mm').format(_scheduledPromptTimes['morning_learner_1']!)} (9:00-9:30 window)');
    debugPrint(
        '[MONITORING_SERVICE] Morning Learner 2: ${DateFormat('HH:mm').format(_scheduledPromptTimes['morning_learner_2']!)} (10:30-11:00 window)');
    debugPrint(
        '[MONITORING_SERVICE] Afternoon Learner 1: ${DateFormat('HH:mm').format(_scheduledPromptTimes['afternoon_learner_1']!)} (13:15-13:45 window)');
    debugPrint(
        '[MONITORING_SERVICE] Afternoon Learner 2: ${DateFormat('HH:mm').format(_scheduledPromptTimes['afternoon_learner_2']!)} (14:00-15:15 window)');
  }

  /// Check if any scheduled prompts should be triggered
  Future<void> _checkScheduledPrompts(DateTime now) async {
    // Check morning learner 1 (9:00 AM)
    if (_morningSelectedLearners.isNotEmpty) {
      await _checkAndPromptLearner(
          'morning_learner_1', _morningSelectedLearners[0], now);
    }

    // Check morning learner 2 (10:00 AM)
    if (_morningSelectedLearners.length > 1) {
      await _checkAndPromptLearner(
          'morning_learner_2', _morningSelectedLearners[1], now);
    }

    // Check afternoon learner 1 (1:00 PM)
    if (_afternoonSelectedLearners.isNotEmpty) {
      await _checkAndPromptLearner(
          'afternoon_learner_1', _afternoonSelectedLearners[0], now);
    }

    // Check afternoon learner 2 (2:00 PM)
    if (_afternoonSelectedLearners.length > 1) {
      await _checkAndPromptLearner(
          'afternoon_learner_2', _afternoonSelectedLearners[1], now);
    }
  }

  /// Check if a specific learner should be prompted at their scheduled time
  Future<void> _checkAndPromptLearner(
      String timeSlot, String learnerId, DateTime now) async {
    final scheduledTime = _scheduledPromptTimes[timeSlot];
    if (scheduledTime == null) return;

    // Skip if learner already responded
    if (_learnerResponded[learnerId] == true) {
      return;
    }

    final attempts = _promptAttempts[learnerId] ?? 0;
    final lastPrompt = _lastPromptTime[learnerId];

    // Check if it's time for the first prompt (within 1 minute of scheduled time)
    if (attempts == 0) {
      final timeDiff = now.difference(scheduledTime).inMinutes.abs();
      if (timeDiff <= 1 && now.isAfter(scheduledTime)) {
        debugPrint(
            '[MONITORING_SERVICE] ⏰ Time for $timeSlot - prompting learner $learnerId');
        await _promptLearner(learnerId);
        return;
      }
    }

    // Check for second prompt (10-15 minutes after first prompt)
    if (attempts == 1 && lastPrompt != null) {
      final timeSinceLastPrompt = now.difference(lastPrompt);
      final waitTime = 10 + _random.nextInt(6); // Random 10-15 minutes

      if (timeSinceLastPrompt.inMinutes >= waitTime) {
        debugPrint(
            '[MONITORING_SERVICE] 🔄 $waitTime minutes passed - second prompt for learner $learnerId');
        await _promptLearner(learnerId);
        return;
      }
    }

    // After 2 attempts, mark as non-responsive
    if (attempts >= 2 && lastPrompt != null) {
      final timeSinceLastPrompt = now.difference(lastPrompt);
      if (timeSinceLastPrompt.inMinutes >= 20) {
        // Give 20 minutes total
        debugPrint(
            '[MONITORING_SERVICE] ❌ Learner $learnerId did not respond after 2 attempts');
        _learnerResponded[learnerId] = false;
        await _saveMonitoringRecord(learnerId, 'ABSENT');
      }
    }
  }

  /// Select 4 random learners for the entire day (2 morning + 2 afternoon)
  Future<void> _selectLearnersForDay() async {
    try {
      final db = await _dbHelper.database;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Get all learners who clocked in today for this class
      final result = await db.rawQuery('''
        SELECT DISTINCT ld.LearnerID, ld.Name, ld.Surname
        FROM learner_clocking lc
        INNER JOIN learnerdetails ld ON lc.LearnerID = ld.LearnerID
        WHERE lc.clock_date = ? AND ld.classID = ?
        AND lc.clock_in_time IS NOT NULL AND lc.clock_in_time != ''
      ''', [today, _currentClassID]);

      if (result.isEmpty) {
        debugPrint('[MONITORING_SERVICE] No learners clocked in today');
        return;
      }

      if (result.length < 4) {
        debugPrint(
            '[MONITORING_SERVICE] Only ${result.length} learners available (need 4 for full schedule)');
      }

      // Randomly shuffle all available learners
      final shuffledLearners = List.from(result)..shuffle(_random);

      // Select up to 4 learners total
      final numToSelect =
          shuffledLearners.length >= 4 ? 4 : shuffledLearners.length;

      // Clear previous selections
      _morningSelectedLearners.clear();
      _afternoonSelectedLearners.clear();

      // Assign learners to sessions
      for (int i = 0; i < numToSelect; i++) {
        final learnerId = shuffledLearners[i]['LearnerID'].toString();
        final learnerName =
            '${shuffledLearners[i]['Name']} ${shuffledLearners[i]['Surname']}';

        // Initialize tracking
        _promptAttempts[learnerId] = 0;
        _learnerResponded[learnerId] = false;

        if (i < 2) {
          // First 2 learners go to morning session
          _morningSelectedLearners.add(learnerId);
          debugPrint(
              '[MONITORING_SERVICE] 🌅 Morning Learner ${i + 1}: $learnerName (ID: $learnerId)');
        } else {
          // Next 2 learners go to afternoon session
          _afternoonSelectedLearners.add(learnerId);
          debugPrint(
              '[MONITORING_SERVICE] 🌇 Afternoon Learner ${i - 1}: $learnerName (ID: $learnerId)');
        }
      }

      debugPrint(
          '[MONITORING_SERVICE] 📋 Selected ${_morningSelectedLearners.length} morning + ${_afternoonSelectedLearners.length} afternoon learners');
    } catch (e) {
      debugPrint('[MONITORING_SERVICE] Error selecting learners for day: $e');
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
      final sessionType = _getSessionTypeForLearner(learnerId);

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

  /// Get session type for a specific learner
  String _getSessionTypeForLearner(String learnerId) {
    if (_morningSelectedLearners.contains(learnerId)) {
      return 'morning';
    } else if (_afternoonSelectedLearners.contains(learnerId)) {
      return 'afternoon';
    }
    // Fallback to time-based detection
    final hour = DateTime.now().hour;
    return hour < 12 ? 'morning' : 'afternoon';
  }

  // Getters for external access
  bool get isServiceRunning => _isServiceRunning;
  bool get isMonitoringActive => _isMonitoringActive;
  bool get learnersSelected => _learnersSelected;
  int get morningLearnersCount => _morningSelectedLearners.length;
  int get afternoonLearnersCount => _afternoonSelectedLearners.length;

  // Get scheduled times for debugging
  Map<String, String> get scheduledTimes {
    final times = <String, String>{};
    _scheduledPromptTimes.forEach((key, dateTime) {
      if (dateTime != null) {
        times[key] = DateFormat('HH:mm').format(dateTime);
      }
    });
    return times;
  }
}
