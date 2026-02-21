import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'config.dart';
import 'services/futronic_service.dart' as futronic;

class RandomMonitoringPage extends StatefulWidget {
  final String classID;

  const RandomMonitoringPage({
    super.key,
    required this.classID,
  });

  @override
  _RandomMonitoringPageState createState() => _RandomMonitoringPageState();
}

class _RandomMonitoringPageState extends State<RandomMonitoringPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Monitoring state
  bool _isMonitoringActive = false;
  bool _isLunchBreak = false;
  bool _isAfternoonSession = false;

  // Current monitoring session
  Map<String, dynamic>? _currentLearner;
  int _currentAttempt = 0;
  int _countdownSeconds = 300; // 5 minutes = 300 seconds
  Timer? _countdownTimer;
  Timer? _monitoringTimer;

  // Lists for tracking
  List<Map<String, dynamic>> _availableLearners = [];
  List<Map<String, dynamic>> _monitoringHistory = [];
  List<String> _verifiedToday = [];

  // Random generator
  final Random _random = Random();

  // USB Permission state
  bool _usbPermissionGranted = false;
  final futronic.FutronicService _futronicService = futronic.FutronicService();

  @override
  void initState() {
    super.initState();
    _checkUsbPermission();
    _initializeMonitoring();
    _startTimeChecking();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _monitoringTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkUsbPermission() async {
    try {
      final bool hasPermission = await _futronicService.checkUsbPermission();
      setState(() {
        _usbPermissionGranted = hasPermission;
      });
      print('[USB] Permission status: $hasPermission');
    } catch (e) {
      print('[USB] Error checking permission: $e');
      setState(() {
        _usbPermissionGranted = false;
      });
    }
  }

  Future<void> _requestUsbPermission() async {
    try {
      final bool granted = await _futronicService.requestUsbPermission();

      // Wait a bit and check again (permission dialog takes time)
      await Future.delayed(const Duration(seconds: 1));
      final bool finalStatus = await _futronicService.checkUsbPermission();

      setState(() {
        _usbPermissionGranted = finalStatus;
      });

      if (!mounted) return;

      if (finalStatus) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('USB permission granted for Futronic scanner'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'USB permission denied. Please allow access to use the fingerprint scanner.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('[USB] Error requesting permission: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error requesting USB permission: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _initializeMonitoring() async {
    await _loadAvailableLearners();
    await _loadTodaysHistory();
    _checkTimeAndStartMonitoring();
  }

  void _startTimeChecking() {
    // Check time every minute
    _monitoringTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkTimeAndStartMonitoring();
    });
  }

  void _checkTimeAndStartMonitoring() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;

    setState(() {
      // Lunch break: 12:00 - 13:00
      _isLunchBreak = (hour == 12) || (hour == 13 && minute == 0);

      // Afternoon session: 13:15 - 16:00
      _isAfternoonSession =
          (hour == 13 && minute >= 15) || (hour >= 14 && hour < 16);

      // Morning session: Before 12:00
      bool isMorningSession = hour < 12;

      // Auto-start monitoring if conditions are met
      if (!_isLunchBreak &&
          (isMorningSession || _isAfternoonSession) &&
          !_isMonitoringActive) {
        if (_availableLearners.isNotEmpty) {
          _startRandomMonitoring();
        }
      } else if (_isLunchBreak && _isMonitoringActive) {
        _pauseMonitoring();
      }
    });
  }

  Future<void> _loadAvailableLearners() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Get learners who clocked in today
      final clockedInLearners = await _dbHelper.getClockingDataForToday();

      // Get all learners from class
      final allLearners = await _dbHelper.getLearnersByClass(widget.classID);

      // Filter to only include those who clocked in and haven't been verified today
      List<Map<String, dynamic>> available = [];

      for (var learner in allLearners) {
        final learnerId = learner['LearnerID'].toString();

        // Check if learner clocked in today
        bool clockedInToday = clockedInLearners
            .any((clocking) => clocking['LearnerID'].toString() == learnerId);

        // Check if already verified today
        bool alreadyVerified = _verifiedToday.contains(learnerId);

        if (clockedInToday && !alreadyVerified) {
          available.add(learner);
        }
      }

      setState(() {
        _availableLearners = available;
      });

      print(
          '[MONITORING] Available learners for monitoring: ${available.length}');
    } catch (e) {
      print('[MONITORING] Error loading available learners: $e');
    }
  }

  Future<void> _loadTodaysHistory() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final db = await _dbHelper.database;

      final history = await db.query(
        'monitoring_records',
        where: 'monitoring_date = ?',
        whereArgs: [today],
        orderBy: 'created_at DESC',
      );

      // Extract verified learner IDs
      List<String> verified = [];
      for (var record in history) {
        if (record['final_status'] == 'PRESENT') {
          verified.add(record['learner_id'].toString());
        }
      }

      setState(() {
        _monitoringHistory = history;
        _verifiedToday = verified;
      });
    } catch (e) {
      print('[MONITORING] Error loading today\'s history: $e');
    }
  }

  void _startRandomMonitoring() {
    if (_availableLearners.isEmpty) {
      print('[MONITORING] No available learners to monitor');
      return;
    }

    // Select random learner
    final randomIndex = _random.nextInt(_availableLearners.length);
    final selectedLearner = _availableLearners[randomIndex];

    setState(() {
      _isMonitoringActive = true;
      _currentLearner = selectedLearner;
      _currentAttempt = 1;
      _countdownSeconds = 300; // 5 minutes
    });

    _startCountdown();
    _createMonitoringRecord();

    print(
        '[MONITORING] Started monitoring: ${selectedLearner['Name']} ${selectedLearner['Surname']}');
  }

  void _startCountdown() {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdownSeconds--;
      });

      if (_countdownSeconds <= 0) {
        _handleTimeExpired();
      }
    });
  }

  void _handleTimeExpired() {
    _countdownTimer?.cancel();

    if (_currentAttempt < 3) {
      // Move to next attempt
      setState(() {
        _currentAttempt++;
        _countdownSeconds = 300; // Reset to 5 minutes
      });

      _updateMonitoringRecord('NO_SHOW_ATTEMPT_$_currentAttempt');
      _startCountdown();

      print(
          '[MONITORING] Attempt $_currentAttempt failed, starting next attempt');
    } else {
      // All 3 attempts failed - mark as ABSENT
      _markAsAbsent();
    }
  }

  void _markAsPresent() {
    _countdownTimer?.cancel();

    _updateMonitoringRecord('PRESENT');

    // Add to verified list
    if (_currentLearner != null) {
      _verifiedToday.add(_currentLearner!['LearnerID'].toString());
    }

    // Remove from available list
    _availableLearners.removeWhere(
        (learner) => learner['LearnerID'] == _currentLearner!['LearnerID']);

    setState(() {
      _isMonitoringActive = false;
      _currentLearner = null;
      _currentAttempt = 0;
    });

    // Decide next action based on session
    if (_isAfternoonSession) {
      // Afternoon: immediately call next person
      Future.delayed(const Duration(seconds: 2), () {
        if (_availableLearners.isNotEmpty) {
          _startRandomMonitoring();
        }
      });
    } else {
      // Morning: stop and wait for lunch
      print(
          '[MONITORING] Morning verification complete, waiting for afternoon session');
    }

    _loadTodaysHistory(); // Refresh history
  }

  void _markAsAbsent() {
    _updateMonitoringRecord('ABSENT');

    // Remove from available list
    _availableLearners.removeWhere(
        (learner) => learner['LearnerID'] == _currentLearner!['LearnerID']);

    setState(() {
      _isMonitoringActive = false;
      _currentLearner = null;
      _currentAttempt = 0;
    });

    // Immediately call next person (both morning and afternoon)
    Future.delayed(const Duration(seconds: 2), () {
      if (_availableLearners.isNotEmpty && !_isLunchBreak) {
        _startRandomMonitoring();
      }
    });

    _loadTodaysHistory(); // Refresh history

    print('[MONITORING] Marked as ABSENT, moving to next learner');
  }

  void _pauseMonitoring() {
    _countdownTimer?.cancel();

    setState(() {
      _isMonitoringActive = false;
      _currentLearner = null;
      _currentAttempt = 0;
    });

    print('[MONITORING] Monitoring paused for lunch break');
  }

  Future<void> _createMonitoringRecord() async {
    if (_currentLearner == null) return;

    try {
      final db = await _dbHelper.database;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      await db.insert('monitoring_records', {
        'learner_id': _currentLearner!['LearnerID'],
        'learner_name':
            '${_currentLearner!['Name']} ${_currentLearner!['Surname']}',
        'monitoring_date': today,
        'attempt_1_time': now,
        'attempt_1_status': 'IN_PROGRESS',
        'final_status': 'IN_PROGRESS',
        'created_at': now,
      });
    } catch (e) {
      print('[MONITORING] Error creating monitoring record: $e');
    }
  }

  Future<void> _updateMonitoringRecord(String status) async {
    if (_currentLearner == null) return;

    try {
      final db = await _dbHelper.database;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      Map<String, dynamic> updateData = {};

      if (_currentAttempt == 1) {
        updateData['attempt_1_status'] = status;
      } else if (_currentAttempt == 2) {
        updateData['attempt_2_time'] = now;
        updateData['attempt_2_status'] = status;
      } else if (_currentAttempt == 3) {
        updateData['attempt_3_time'] = now;
        updateData['attempt_3_status'] = status;
      }

      if (status == 'PRESENT' || status == 'ABSENT') {
        updateData['final_status'] = status;
        updateData['verification_time'] = now;
      }

      await db.update(
        'monitoring_records',
        updateData,
        where: 'learner_id = ? AND monitoring_date = ?',
        whereArgs: [_currentLearner!['LearnerID'], today],
      );

      // Try to sync to server
      _syncMonitoringRecords();
    } catch (e) {
      print('[MONITORING] Error updating monitoring record: $e');
    }
  }

  Future<void> _syncMonitoringRecords() async {
    try {
      final db = await _dbHelper.database;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Get all monitoring records for today
      final records = await db.query(
        'monitoring_records',
        where: 'monitoring_date = ?',
        whereArgs: [today],
      );

      if (records.isEmpty) return;

      final response = await http.post(
        Uri.parse(AppConfig.syncMonitoringRecordsUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'records': records}),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          print(
              '[MONITORING] Successfully synced ${result['synced_count']} records');
        } else {
          print('[MONITORING] Sync failed: ${result['error']}');
        }
      } else {
        print('[MONITORING] Sync failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('[MONITORING] Error syncing monitoring records: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  String _formatCountdown() {
    final minutes = _countdownSeconds ~/ 60;
    final seconds = _countdownSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildCurrentMonitoringCard() {
    if (!_isMonitoringActive || _currentLearner == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.schedule, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                _isLunchBreak
                    ? 'Lunch Break (12:00 - 13:00)'
                    : _availableLearners.isEmpty
                        ? 'No learners available for monitoring'
                        : 'Monitoring will start automatically',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Currently Monitoring',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Learner info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(
                    '${_currentLearner!['Name'][0]}${_currentLearner!['Surname'][0]}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currentLearner!['Name']} ${_currentLearner!['Surname']}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'ID: ${_currentLearner!['LearnerID']}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Attempt info
            Text(
              'Attempt $_currentAttempt of 3',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),

            const SizedBox(height: 12),

            // Countdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _countdownSeconds <= 60
                    ? Colors.red[100]
                    : Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatCountdown(),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _countdownSeconds <= 60
                      ? Colors.red[700]
                      : Colors.orange[700],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _markAsPresent,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('PRESENT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _markAsAbsent,
                    icon: const Icon(Icons.cancel),
                    label: const Text('ABSENT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsbPermissionCard() {
    return Card(
      color: _usbPermissionGranted ? Colors.green[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _usbPermissionGranted ? Icons.usb : Icons.usb_off,
              color: _usbPermissionGranted ? Colors.green : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _usbPermissionGranted
                        ? 'Futronic Scanner Ready'
                        : 'USB Permission Required',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _usbPermissionGranted
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _usbPermissionGranted
                        ? 'Fingerprint scanner is accessible'
                        : 'Allow RLMS to access Futronic Fingerprint Scanner 2.0',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (!_usbPermissionGranted)
              ElevatedButton(
                onPressed: _requestUsbPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Allow'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);

    String sessionStatus;
    Color statusColor;

    if (_isLunchBreak) {
      sessionStatus = 'Lunch Break';
      statusColor = Colors.orange;
    } else if (now.hour < 12) {
      sessionStatus = 'Morning Session';
      statusColor = Colors.blue;
    } else if (_isAfternoonSession) {
      sessionStatus = 'Afternoon Session';
      statusColor = Colors.green;
    } else {
      sessionStatus = 'Monitoring Ended';
      statusColor = Colors.grey;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sessionStatus,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Current time: $timeStr',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Text(
              '${_availableLearners.length} remaining',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // Manual sync method for monitoring records
  Future<void> _manualSyncMonitoringRecords() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Syncing monitoring records...'),
              ],
            ),
          ),
        ),
      );

      // Get unsynced records count first
      final unsyncedRecords = await _dbHelper.getUnsyncedMonitoringClockin();
      print('[SYNC_BUTTON] Found ${unsyncedRecords.length} unsynced records');

      if (unsyncedRecords.isEmpty) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No records to sync'),
            backgroundColor: Colors.blue,
          ),
        );
        return;
      }

      // Perform sync
      final result = await _dbHelper.syncMonitoringClockinToServer();

      Navigator.of(context).pop(); // Close loading dialog

      if (result['success'] == true) {
        final syncedCount = result['synced_count'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✓ Successfully synced $syncedCount monitoring records to server'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Reload history to show updated sync status
        await _loadTodaysHistory();
      } else {
        final error = result['error'] ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if still open
      print('[SYNC_BUTTON] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Random Monitoring System'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadAvailableLearners();
              _loadTodaysHistory();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _manualSyncMonitoringRecords,
        icon: const Icon(Icons.cloud_upload),
        label: const Text('SYNC'),
        backgroundColor: Colors.green,
        tooltip: 'Sync monitoring records to server',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadAvailableLearners();
          await _loadTodaysHistory();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUsbPermissionCard(),
              const SizedBox(height: 16),
              _buildStatusCard(),
              const SizedBox(height: 16),
              _buildCurrentMonitoringCard(),
              const SizedBox(height: 24),

              // Today's History
              const Text(
                'Today\'s Monitoring History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (_monitoringHistory.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No monitoring records for today',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                )
              else
                ...(_monitoringHistory
                    .map((record) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  record['final_status'] == 'PRESENT'
                                      ? Colors.green
                                      : record['final_status'] == 'ABSENT'
                                          ? Colors.red
                                          : Colors.orange,
                              child: Icon(
                                record['final_status'] == 'PRESENT'
                                    ? Icons.check
                                    : record['final_status'] == 'ABSENT'
                                        ? Icons.close
                                        : Icons.schedule,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(record['learner_name'] ?? 'Unknown'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status: ${record['final_status']}'),
                                if (record['verification_time'] != null)
                                  Text(
                                      'Verified: ${DateFormat('HH:mm').format(DateTime.parse(record['verification_time']))}'),
                              ],
                            ),
                            trailing: Text(
                              'Attempts: ${_getAttemptCount(record)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ))
                    .toList()),
            ],
          ),
        ),
      ),
    );
  }

  int _getAttemptCount(Map<String, dynamic> record) {
    int count = 0;
    if (record['attempt_1_status'] != null) count++;
    if (record['attempt_2_status'] != null) count++;
    if (record['attempt_3_status'] != null) count++;
    return count;
  }
}
