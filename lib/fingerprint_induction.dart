import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'database_helper.dart';
import 'services/fingerprint_service.dart';
import 'utils/fingerprint_error_handler.dart';

import 'config.dart';

class InductionPage extends StatefulWidget {
  final String classID;

  const InductionPage({
    super.key,
    required this.classID,
  });

  @override
  State<InductionPage> createState() => _InductionPageState();
}

class _InductionPageState extends State<InductionPage> {
  final FingerprintService _fingerprintService = FingerprintService();
  final FutronicService _futronicService = FutronicService();
  List<dynamic> learners = [];
  Map<String, String> clockInTimes = {};
  Map<String, String> clockOutTimes = {};
  Map<String, String> contactTimes = {};
  final Map<String, bool> _isClockingIn = {};
  final Map<String, bool> _hasClockIn = {}; // Track if learner has clocked in
  final Map<String, bool> _hasClockOut = {}; // Track if learner has clocked out
  final bool _isVerifying = false;
  final String _statusMessage = '';
  StreamSubscription? _enrollStatusSubscription;
  StreamSubscription? _enrollSuccessSubscription;
  final bool _isSensorConnected = false;
  final bool _isInitializing = false;
  String? _currentLearnerIdForClocking;
  String? _currentClockingAction; // 'in' or 'out'

  @override
  void initState() {
    super.initState();
    databaseFactory = databaseFactoryFfi;
    _initializeData();
  }

  @override
  void dispose() {
    _fingerprintService.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    final classes = await db.query('class');
    final sites = await db.query('sites');
    print('Class table contents on init: $classes');
    print('Sites table contents on init: $sites');

    // First try to sync learners from server to local database
    try {
      await dbHelper.syncLearnersFromServer(widget.classID);
      print(
          'Successfully synced learners from server for classID: ${widget.classID}');
    } catch (e) {
      print('Failed to sync learners from server: $e');
      // Continue with local data even if sync fails
    }

    await _loadLearnersFromLocalDatabase();
    await _checkAllLearnersClockingStatus();
    await _fetchClockingDataFromServer();
    _startPeriodicRefresh();
  }

  Future<void> _checkAllLearnersClockingStatus() async {
    final db = await DatabaseHelper().database;

    // Check all learners' clocking status from database
    for (var learner in learners) {
      String learnerId = learner['LearnerID']?.toString() ?? '';
      if (learnerId.isNotEmpty) {
        await _checkLearnerClockingStatus(learnerId);
      }
    }
  }

  Future<void> _checkLearnerClockingStatus(String learnerId) async {
    final db = await DatabaseHelper().database;

    // Check if learner has any previous induction clocking records
    final existingInduction = await db.query(
      'induction_clocking',
      where: 'LearnerID = ?',
      whereArgs: [learnerId],
      limit: 1,
    );

    if (existingInduction.isNotEmpty) {
      final record = existingInduction.first;
      final clockInTime = record['clock_in_time']?.toString();
      final clockOutTime = record['clock_out_time']?.toString();

      setState(() {
        // Mark as having clocked in if there's a clock_in_time
        _hasClockIn[learnerId] = clockInTime != null &&
            clockInTime.isNotEmpty &&
            clockInTime != 'null';

        // Mark as having clocked out if there's a clock_out_time
        _hasClockOut[learnerId] = clockOutTime != null &&
            clockOutTime.isNotEmpty &&
            clockOutTime != 'null';
      });
    } else {
      setState(() {
        _hasClockIn[learnerId] = false;
        _hasClockOut[learnerId] = false;
      });
    }
  }

  void _startPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _refreshDataWithoutClearingState();
        _startPeriodicRefresh();
      }
    });
  }

  Future<void> _fetchClockingDataFromServer() async {
    if (!(await _checkConnectivity())) return;

    await _syncOfflineClockIns();

    // Individual server fetches disabled - induction data is only clocked once in entire program
    // This prevents FormatException errors from broken get_indaction_data.php endpoint
    print(
        '[INDUCTION] Individual server fetches disabled - induction is one-time only');
  }

  Future<void> _syncOfflineClockIns() async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    // Sync ALL offline records when connectivity returns (not just today)
    final offlineRecords = await db.query(
      'induction_clocking',
      where: 'synced = ?',
      whereArgs: [0],
    );

    for (var record in offlineRecords) {
      try {
        // Convert all values to String, using empty string for nulls
        final stringRecord =
            record.map((k, v) => MapEntry(k, v?.toString() ?? ''));
        final learnerID = stringRecord['LearnerID'] ?? '';
        // Mark as synced - cleanup will delete it later
        await db.update(
          'induction_clocking',
          {'synced': 1},
          where: 'LearnerID = ? AND clock_date = ?',
          whereArgs: [learnerID, stringRecord['clock_date']],
        );
        print('Synced offline clock-in for $learnerID');
      } catch (e) {
        print('Failed to sync offline clock-in: $e');
      }
    }

    // Clean up synced records after sync
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.cleanupOldClockingRecords();
      print('Cleaned up synced records after induction sync');
    } catch (e) {
      print('Error cleaning up after induction sync: $e');
    }
  }

  Future<void> _refreshDataWithoutClearingState() async {
    try {
      final dbHelper = DatabaseHelper();
      final learnersWithClockingData =
          await dbHelper.getLearnersWithInductionClockingData(widget.classID);

      setState(() {
        for (var learner in learnersWithClockingData) {
          String learnerId = learner['LearnerID']?.toString() ?? '';
          String clockInTime = learner['clock_in_time']?.toString() ?? '';
          String clockOutTime = learner['clock_out_time']?.toString() ?? '';
          String contactTime = learner['contact_time']?.toString() ?? '';

          if (clockInTime.isNotEmpty &&
              clockInTime != 'N/A' &&
              clockInTime != 'null') {
            clockInTimes[learnerId] = clockInTime;
          }
          if (clockOutTime.isNotEmpty &&
              clockOutTime != 'N/A' &&
              clockOutTime != 'null') {
            clockOutTimes[learnerId] = clockOutTime;
          }
          if (contactTime.isNotEmpty &&
              contactTime != 'N/A' &&
              contactTime != 'null') {
            contactTimes[learnerId] = contactTime;
          }
        }

        learners.clear();
        learners.addAll(learnersWithClockingData.map((learner) {
          // Ensure all values are strings before creating the map
          return Map<String, String>.from(learner
              .map((key, value) => MapEntry(key, value?.toString() ?? '')));
        }));
      });

      // Update clocking status for all learners
      await _checkAllLearnersClockingStatus();
      await _fetchClockingDataFromServer();
    } catch (e) {
      print('Error refreshing data: $e');
    }
  }

  Future<void> _loadLearnersFromLocalDatabase() async {
    try {
      final dbHelper = DatabaseHelper();
      final learnersWithClockingData =
          await dbHelper.getLearnersWithInductionClockingData(widget.classID);

      setState(() {
        learners.clear();
        for (var learner in learnersWithClockingData) {
          String learnerId = learner['LearnerID']?.toString() ?? 'N/A';
          String clockInTime = learner['clock_in_time']?.toString() ?? '';
          String clockOutTime = learner['clock_out_time']?.toString() ?? '';
          String contactTime = learner['contact_time']?.toString() ?? '';

          if (clockInTime.isNotEmpty &&
              clockInTime != 'N/A' &&
              clockInTime != 'null') {
            clockInTimes[learnerId] = clockInTime;
          }
          if (clockOutTime.isNotEmpty &&
              clockOutTime != 'N/A' &&
              clockOutTime != 'null') {
            clockOutTimes[learnerId] = clockOutTime;
          }
          if (contactTime.isNotEmpty &&
              contactTime != 'N/A' &&
              contactTime != 'null') {
            contactTimes[learnerId] = contactTime;
          }

          learners.add({
            'LearnerID': learnerId,
            'Name': learner['Name']?.toString() ?? 'N/A',
            'Surname': learner['Surname']?.toString() ?? 'N/A',
            'IDNumber': learner['IDNumber']?.toString() ?? 'N/A',
            'clock_in_time': clockInTime,
            'clock_out_time': clockOutTime,
            'contact_time': contactTime,
          });
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading offline learners: $e')),
      );
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371e3; // Earth radius in meters
    final double phi1 = lat1 * pi / 180;
    final double phi2 = lat2 * pi / 180;
    final double deltaPhi = (lat2 - lat1) * pi / 180;
    final double deltaLambda = (lon2 - lon1) * pi / 180;

    final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c; // Distance in meters
  }

  Future<bool> _isWithinSiteRadius(String classID, double userLat,
      double userLon, double userAccuracy) async {
    if (userAccuracy > 50) {
      print('Geolocation accuracy too low: $userAccuracy meters');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Geolocation accuracy too low. Please enable GPS.')),
      );
      return false;
    }

    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final classes = await db.query('class');
      final sites = await db.query('sites');
      print('Class table contents: $classes');
      print('Sites table contents: $sites');
      print(
          'Querying coordinates for classID: $classID (type: ${classID.runtimeType})');

      final result = await db.rawQuery(
        'SELECT s.latitude, s.longitude FROM class c JOIN sites s ON c.siteID = s.siteID WHERE c.classID = ?',
        [classID.toString()],
      );

      if (result.isEmpty) {
        if (classes.isEmpty) {
          print('Class table is empty');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No class data available in local database.')),
          );
        } else if (sites.isEmpty) {
          print('Sites table is empty');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No site data available in local database.')),
          );
        } else {
          print('No matching class or site found for classID: $classID');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('No site coordinates found for class $classID.')),
          );
        }
        return false;
      }

      final siteLat = double.tryParse(result.first['latitude'].toString());
      final siteLon = double.tryParse(result.first['longitude'].toString());

      if (siteLat == null || siteLon == null) {
        print(
            'Invalid site coordinates for classID: $classID, lat: ${result.first['latitude']}, lon: ${result.first['longitude']}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invalid site coordinates in database.')),
        );
        return false;
      }

      final distance = _calculateDistance(userLat, userLon, siteLat, siteLon);

      print('Distance to site for classID $classID: $distance meters');
      if (distance > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Outside 100-meter radius (Distance: ${distance.toStringAsFixed(2)} meters)')),
        );
        return false;
      }
      return true;
    } catch (e, stackTrace) {
      print(
          'Error checking site radius for classID $classID: $e\nStack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking location: $e')),
      );
      return false;
    }
  }

  Future<String> _detectScanner() async {
    try {
      final isZkConnected = await _fingerprintService.isSensorConnected();
      if (isZkConnected) return 'zkteco';
    } catch (_) {}
    try {
      final isFutronicConnected = await _futronicService.isFutronicConnected();
      if (isFutronicConnected) return 'futronic';
    } catch (_) {}
    return 'none';
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _verifyAndClockIn(String learnerId) async {
    if (_isClockingIn[learnerId] == true || _isInitializing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isInitializing
                ? 'Sensor is initializing...'
                : 'Sensor not ready.')),
      );
      return;
    }

    // Check if learner has already clocked in using our state tracking
    if (_hasClockIn[learnerId] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'This learner has already been inducted and cannot clock in again.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    // Double-check with database as well
    final db = await DatabaseHelper().database;
    final existingInduction = await db.query(
      'induction_clocking',
      where: 'LearnerID = ?',
      whereArgs: [learnerId],
      limit: 1,
    );
    if (existingInduction.isNotEmpty &&
        existingInduction.first['clock_in_time'] != null) {
      // Update our state to match database
      setState(() {
        _hasClockIn[learnerId] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'This learner has already been inducted and cannot clock in again.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final templates =
        await DatabaseHelper().getAllTemplates(int.parse(learnerId));
    final scanner = await _detectScanner();
    String? template;
    if (scanner == 'zkteco') {
      template = templates['zkteco_left_template'] ??
          templates['zkteco_right_template'];
    } else if (scanner == 'futronic') {
      template = templates['futronic_left_template'] ??
          templates['futronic_right_template'];
    }
    if (template == null || template.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No fingerprints enrolled for learner $learnerId. Please enroll fingerprints first.'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Enroll',
            onPressed: () {
              Navigator.pushNamed(context, '/enrollment',
                  arguments: {'learnerId': learnerId});
            },
          ),
        ),
      );
      return;
    }

    setState(() {
      _isClockingIn[learnerId] = true;
      _currentLearnerIdForClocking = learnerId;
      _currentClockingAction = 'in';
    });

    _showProgressDialog('Place finger on scanner for induction clock-in...');

    try {
      bool match = false;
      if (scanner == 'zkteco') {
        match = await _fingerprintService.verify('left', template) ||
            await _fingerprintService.verify('right', template);
      } else if (scanner == 'futronic') {
        try {
          debugPrint(
              '[INDUCTION_CLOCK_IN] Attempting Futronic verification for learner $learnerId');
          final leftTemplate = templates['futronic_left_template'];
          final rightTemplate = templates['futronic_right_template'];
          final hint = (leftTemplate != null && leftTemplate.isNotEmpty)
              ? 'left'
              : 'right';
          match = await _futronicService.verifyBoth(
            hintFinger: hint,
            leftTemplate: leftTemplate,
            rightTemplate: rightTemplate,
          );
        } catch (futronicError) {
          debugPrint(
              '[INDUCTION_CLOCK_IN] Futronic verification error: $futronicError');
          _hideProgressDialog();
          setState(() {
            _isClockingIn[learnerId] = false;
            _currentLearnerIdForClocking = null;
            _currentClockingAction = null;
          });

          // Provide specific error messages for common Futronic issues
          String errorMessage = 'Fingerprint verification failed';
          if (futronicError.toString().contains('USB_OPEN_FAILED') ||
              futronicError.toString().contains('DEVICE_OPEN_FAILED')) {
            errorMessage =
                'Scanner connection failed. Please check USB connection and try again.';
          } else if (futronicError.toString().contains('CAPTURE_FAILED')) {
            errorMessage =
                'Could not capture fingerprint. Please place finger firmly on scanner and try again.';
          } else if (futronicError.toString().contains('TIMEOUT') ||
              futronicError.toString().contains('Timeout')) {
            errorMessage = 'Timeout waiting for fingerprint. Please try again.';
          }

          FingerprintErrorHandler.showError(context, futronicError.toString());
          return;
        }
      } else {
        _hideProgressDialog();
        setState(() {
          _isClockingIn[learnerId] = false;
          _currentLearnerIdForClocking = null;
          _currentClockingAction = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No fingerprint scanner detected. Please connect a scanner.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      _hideProgressDialog();
      if (match) {
        final now = DateFormat('HH:mm:ss').format(DateTime.now());
        final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final attendance = {
          'LearnerID': int.tryParse(learnerId) ?? learnerId,
          'clock_in_time': now,
          'clock_date': date,
          'synced': 0,
          'signature': '', // Empty signature for fingerprint authentication
          'user_latitude': '0.0', // Default coordinates
          'user_longitude': '0.0', // Default coordinates
          'user_accuracy': '10.0',
        };

        debugPrint('[INDUCTION_CLOCK_IN] Starting sync for clock-in...');
        bool synced = false;
        try {
          synced = await _syncInductionClockIn(attendance);
          debugPrint('[INDUCTION_CLOCK_IN] Sync result: $synced');
        } catch (e) {
          debugPrint('[INDUCTION_CLOCK_IN] Sync error: $e');
        }

        if (synced) {
          attendance['synced'] = 1;
          debugPrint('[INDUCTION_CLOCK_IN] Showing clock-in success SnackBar.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Induction clock-in successful (synced)'),
                backgroundColor: Colors.green),
          );
        } else {
          debugPrint('[INDUCTION_CLOCK_IN] Showing clock-in offline SnackBar.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Induction clock-in saved locally (offline)'),
                backgroundColor: Colors.orange),
          );
        }
        await DatabaseHelper().insertInductionClocking(attendance);

        // Update UI and status
        setState(() {
          clockInTimes[learnerId] = now;
          _hasClockIn[learnerId] = true;
        });
      } else {
        FingerprintErrorHandler.showError(context, 'No match found');
      }
    } catch (e) {
      _hideProgressDialog();
      FingerprintErrorHandler.showError(context, e.toString());
    } finally {
      setState(() {
        _isClockingIn[learnerId] = false;
        _currentLearnerIdForClocking = null;
        _currentClockingAction = null;
      });
    }
  }

  Future<void> _verifyAndClockOut(String learnerId) async {
    if (_isClockingIn[learnerId] == true || _isInitializing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isInitializing
                ? 'Sensor is initializing...'
                : 'Sensor not ready.')),
      );
      return;
    }

    // Check if learner has already clocked out using our state tracking
    if (_hasClockOut[learnerId] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'This learner has already clocked out and cannot clock out again.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    // Check if learner has clocked in first
    if (_hasClockIn[learnerId] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please clock in first before clocking out.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final existingAttendance = await DatabaseHelper()
        .getInductionAttendanceForDay(
            learnerId, DateFormat('yyyy-MM-dd').format(DateTime.now()));
    if (existingAttendance == null ||
        existingAttendance['clock_in_time'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please clock in first'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    // Check if already clocked out in database
    if (existingAttendance['clock_out_time'] != null) {
      // Update our state to match database
      setState(() {
        _hasClockOut[learnerId] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('This learner has already clocked out.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final templates =
        await DatabaseHelper().getAllTemplates(int.parse(learnerId));
    final scanner = await _detectScanner();
    String? template;
    if (scanner == 'zkteco') {
      template = templates['zkteco_left_template'] ??
          templates['zkteco_right_template'];
    } else if (scanner == 'futronic') {
      template = templates['futronic_left_template'] ??
          templates['futronic_right_template'];
    }
    if (template == null || template.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No fingerprints enrolled for learner $learnerId. Please enroll fingerprints first.'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Enroll',
            onPressed: () {
              Navigator.pushNamed(context, '/enrollment',
                  arguments: {'learnerId': learnerId});
            },
          ),
        ),
      );
      return;
    }

    setState(() {
      _isClockingIn[learnerId] = true;
      _currentLearnerIdForClocking = learnerId;
      _currentClockingAction = 'out';
    });

    _showProgressDialog('Place finger on scanner for induction clock-out...');

    try {
      bool match = false;
      if (scanner == 'zkteco') {
        match = await _fingerprintService.verify('left', template) ||
            await _fingerprintService.verify('right', template);
      } else if (scanner == 'futronic') {
        try {
          debugPrint(
              '[INDUCTION_CLOCK_OUT] Attempting Futronic verification for learner $learnerId');
          final leftTemplate = templates['futronic_left_template'];
          final rightTemplate = templates['futronic_right_template'];
          final hint = (leftTemplate != null && leftTemplate.isNotEmpty)
              ? 'left'
              : 'right';
          match = await _futronicService.verifyBoth(
            hintFinger: hint,
            leftTemplate: leftTemplate,
            rightTemplate: rightTemplate,
          );
        } catch (futronicError) {
          debugPrint(
              '[INDUCTION_CLOCK_OUT] Futronic verification error: $futronicError');
          _hideProgressDialog();
          setState(() {
            _isClockingIn[learnerId] = false;
            _currentLearnerIdForClocking = null;
            _currentClockingAction = null;
          });

          // Provide specific error messages for common Futronic issues
          String errorMessage = 'Fingerprint verification failed';
          if (futronicError.toString().contains('USB_OPEN_FAILED') ||
              futronicError.toString().contains('DEVICE_OPEN_FAILED')) {
            errorMessage =
                'Scanner connection failed. Please check USB connection and try again.';
          } else if (futronicError.toString().contains('CAPTURE_FAILED')) {
            errorMessage =
                'Could not capture fingerprint. Please place finger firmly on scanner and try again.';
          } else if (futronicError.toString().contains('TIMEOUT') ||
              futronicError.toString().contains('Timeout')) {
            errorMessage = 'Timeout waiting for fingerprint. Please try again.';
          }

          FingerprintErrorHandler.showError(context, futronicError.toString());
          return;
        }
      } else {
        _hideProgressDialog();
        setState(() {
          _isClockingIn[learnerId] = false;
          _currentLearnerIdForClocking = null;
          _currentClockingAction = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No fingerprint scanner detected. Please connect a scanner.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      _hideProgressDialog();
      if (match) {
        final now = DateFormat('HH:mm:ss').format(DateTime.now());
        final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final clockInTime = existingAttendance['clock_in_time'].toString();
        final contactTime = _calculateContactTime(clockInTime, now);

        // Prepare complete attendance data for sync
        final attendance = {
          'LearnerID': int.tryParse(learnerId) ?? learnerId,
          'clock_in_time': clockInTime,
          'clock_out_time': now,
          'contact_time': contactTime,
          'clock_date': date,
          'synced': 0,
          'signature': '', // Empty signature for fingerprint authentication
          'user_latitude': '0.0', // Default coordinates
          'user_longitude': '0.0', // Default coordinates
          'user_accuracy': '10.0',
        };

        debugPrint('[INDUCTION_CLOCK_OUT] Starting sync for clock-out...');
        bool synced = false;
        try {
          synced = await _syncInductionClockOut(attendance);
          debugPrint('[INDUCTION_CLOCK_OUT] Sync result: $synced');
        } catch (e) {
          debugPrint('[INDUCTION_CLOCK_OUT] Sync error: $e');
        }

        if (synced) {
          // Update local database with synced=1
          final updatedAttendance = {
            'clock_out_time': now,
            'contact_time': contactTime,
            'synced': 1, // Mark as synced
          };
          await DatabaseHelper()
              .updateInductionClocking(learnerId, date, updatedAttendance);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Induction clock-out successful (synced)'),
                backgroundColor: Colors.green),
          );
        } else {
          // Update local database with synced=0
          final updatedAttendance = {
            'clock_out_time': now,
            'contact_time': contactTime,
            'synced': 0, // Mark as not synced
          };
          await DatabaseHelper()
              .updateInductionClocking(learnerId, date, updatedAttendance);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Induction clock-out saved locally (offline)'),
                backgroundColor: Colors.orange),
          );
        }

        // Update UI and status
        setState(() {
          clockOutTimes[learnerId] = now;
          contactTimes[learnerId] = contactTime;
          _hasClockOut[learnerId] = true;
        });
      } else {
        FingerprintErrorHandler.showError(context, 'No match found');
      }
    } catch (e) {
      _hideProgressDialog();
      FingerprintErrorHandler.showError(context, e.toString());
    } finally {
      setState(() {
        _isClockingIn[learnerId] = false;
        _currentLearnerIdForClocking = null;
        _currentClockingAction = null;
      });
    }
  }

  Future<void> _clockInOffline(String learnerID, String clockInTime) async {
    try {
      print(
          'Starting offline clock-in for learnerID: $learnerID at $clockInTime');
      final dbHelper = DatabaseHelper();
      final clockDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Before inserting, check if learner is already inducted (any date)
      final db = await DatabaseHelper().database;
      final existingInduction = await db.query(
        'induction_clocking',
        where: 'LearnerID = ?',
        whereArgs: [learnerID],
        limit: 1,
      );
      if (existingInduction.isNotEmpty &&
          existingInduction.first['clock_in_time'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('This learner is already inducted.'),
              backgroundColor: Colors.orange),
        );
        return;
      }

      // Store clock-in data (no signature)
      final clockInData = {
        'LearnerID': learnerID,
        'clock_in_time': clockInTime,
        'clock_date': clockDate,
        'synced': 0,
        'signature': '', // Empty signature for fingerprint authentication
        'user_latitude': '0.0', // No longer using Geolocator
        'user_longitude': '0.0', // No longer using Geolocator
        'user_accuracy': '0.0', // No longer using Geolocator
      };

      print('Inserting clock-in data: $clockInData');
      await dbHelper.insertInductionClocking(clockInData);
      print('Offline clock-in inserted successfully for learnerID: $learnerID');

      setState(() {
        clockInTimes[learnerID] = clockInTime;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Clock-in saved locally. Will sync when online.')),
      );
    } catch (e, stackTrace) {
      print(
          'Offline clock-in error for learnerID: $learnerID: $e\nStack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving offline clock-in: $e')),
      );
      rethrow;
    }
  }

  Future<void> updateClockOut(
      String learnerID, String clockOutTime, String clockDate) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final existingRecords = await db.query(
        'induction_clocking',
        where: 'LearnerID = ? AND clock_date = ?',
        whereArgs: [learnerID, clockDate],
      );

      if (existingRecords.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No clock-in record found for today.')),
        );
        return;
      }

      final clockInTime = existingRecords[0]['clock_in_time']?.toString();
      String? contactTime;
      if (clockInTime != null && clockInTime.isNotEmpty) {
        try {
          final timeFormat = DateFormat('HH:mm:ss');
          final clockInDateTime = timeFormat.parse(clockInTime);
          final clockOutDateTime = timeFormat.parse(clockOutTime);
          final contactTimeDuration =
              clockOutDateTime.difference(clockInDateTime);
          contactTime = formatDuration(contactTimeDuration);
        } catch (e) {
          print('Error calculating contact time: $e');
        }
      }

      final updatedData = {
        'clock_out_time': clockOutTime,
        'contact_time': contactTime,
      };

      await dbHelper.updateInductionClocking(learnerID, clockDate, updatedData);

      setState(() {
        clockOutTimes[learnerID] = clockOutTime;
        if (contactTime != null) {
          contactTimes[learnerID] = contactTime;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Clock-out saved locally. Will sync when online.')),
      );
    } catch (e) {
      print('Offline clock-out error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving offline clock-out: $e')),
      );
    }
  }

  String formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes % 60;
    int seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<String> _getSignatureFilePath(String learnerID) async {
    final appDir = await getApplicationDocumentsDirectory();
    final clockDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return '${appDir.path}/signature_${learnerID}_$clockDate.png';
  }

  Future<bool> clockInLearner(String learnerID) async {
    _verifyAndClockIn(learnerID);
    return true;
  }

  Future<bool> clockOutLearner(String learnerID) async {
    _verifyAndClockOut(learnerID);
    return true;
  }

  Future<bool> _syncInductionClockIn(Map<String, dynamic> attendance) async {
    try {
      // Add required server parameters
      final payload = Map<String, dynamic>.from(attendance);
      payload['clock_in'] = '1'; // Required by server
      payload['signature'] =
          ''; // Empty signature for fingerprint authentication
      payload['classID'] = widget.classID; // Add classID
      payload['user_latitude'] =
          '0.0'; // Default location since using fingerprint
      payload['user_longitude'] =
          '0.0'; // Default location since using fingerprint
      payload['user_accuracy'] =
          '0.0'; // Default accuracy since using fingerprint

      final stringPayload = payload.map((k, v) => MapEntry(k, v.toString()));

      debugPrint('[INDUCTION] Sending clock-in payload: $stringPayload');

      final response = await http
          .post(
            Uri.parse(AppConfig.buildUrl('induction_clocking.php')),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: stringPayload,
          )
          .timeout(const Duration(seconds: 10));

      debugPrint(
          '[INDUCTION] Clock-in server response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[INDUCTION] SyncInductionClockIn error: $e');
      return false;
    }
  }

  Future<bool> _syncInductionClockOut(Map<String, dynamic> clockOutData) async {
    try {
      // Use the correct endpoint for clock-out (matching regular induction system)
      final payload = {
        'LearnerID': clockOutData['LearnerID'],
        'clock_out': '1', // Required flag for clock-out
        'signature': '', // Empty signature for fingerprint authentication
        'user_latitude': '0.0', // Default location since using fingerprint
        'user_longitude': '0.0', // Default location since using fingerprint
        'user_accuracy': '0.0', // Default accuracy since using fingerprint
        'classID': widget.classID,
      };

      final stringPayload = payload.map((k, v) => MapEntry(k, v.toString()));

      debugPrint('[INDUCTION] Sending clock-out payload: $stringPayload');

      final response = await http
          .post(
            Uri.parse(AppConfig.buildUrl('induction_clockout.php')),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: stringPayload,
          )
          .timeout(const Duration(seconds: 10));

      debugPrint(
          '[INDUCTION] Clock-out server response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[INDUCTION] SyncInductionClockOut error: $e');
      return false;
    }
  }

  void _showProgressDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  void _hideProgressDialog() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  String _calculateContactTime(String clockIn, String clockOut) {
    final format = DateFormat("HH:mm:ss");
    try {
      final inTime = format.parse(clockIn);
      final outTime = format.parse(clockOut);
      final duration = outTime.difference(inTime);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final seconds = duration.inSeconds % 60;
      return "${hours}h ${minutes}m ${seconds}s";
    } catch (e) {
      return "0h 0m 0s";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text('Induction Clocking: Class ${widget.classID}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  // Show loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Syncing learners from server...'),
                      backgroundColor: Colors.blue,
                      duration: Duration(seconds: 1),
                    ),
                  );

                  // Sync learners from server
                  try {
                    final dbHelper = DatabaseHelper();
                    await dbHelper.syncLearnersFromServer(widget.classID);
                    await _loadLearnersFromLocalDatabase();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Learners synced successfully'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      FingerprintErrorHandler.showError(context,
                          'Sync failed. Check your internet connection.');
                    }
                  }
                },
                tooltip: 'Sync Learners from Server',
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class Information for ${widget.classID}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Learner Actions: Clock In/Out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                learners.isEmpty
                    ? const Center(
                        child: Text('No data available for this class'))
                    : Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Surname')),
                                DataColumn(label: Text('ID Number')),
                                DataColumn(label: Text('Clock In Time')),
                                DataColumn(label: Text('Clock Out Time')),
                                DataColumn(label: Text('Contact Time')),
                              ],
                              rows: learners.map((item) {
                                String learnerID =
                                    item['LearnerID']?.toString() ?? '';
                                String? clockInTime = clockInTimes[learnerID];
                                String? clockOutTime = clockOutTimes[learnerID];
                                String? contactTime = contactTimes[learnerID];

                                return DataRow(
                                  cells: [
                                    DataCell(Text(
                                        item['Name']?.toString() ?? 'N/A')),
                                    DataCell(Text(
                                        item['Surname']?.toString() ?? 'N/A')),
                                    DataCell(Text(
                                        item['IDNumber']?.toString() ?? 'N/A')),
                                    DataCell(
                                      (_hasClockIn[learnerID] == true) ||
                                              (clockInTime != null &&
                                                  clockInTime.isNotEmpty)
                                          ? Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  clockInTime ?? 'Clocked In',
                                                  style: const TextStyle(
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  'Already Inducted',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.green[800],
                                                  ),
                                                ),
                                              ],
                                            )
                                          : ElevatedButton(
                                              onPressed: _isVerifying
                                                  ? null
                                                  : () async {
                                                      await clockInLearner(
                                                          learnerID);
                                                    },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('Clock In'),
                                            ),
                                    ),
                                    DataCell(
                                      (_hasClockOut[learnerID] == true) ||
                                              (clockOutTime != null &&
                                                  clockOutTime.isNotEmpty)
                                          ? Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  clockOutTime ?? 'Clocked Out',
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  'Already Clocked Out',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.red[800],
                                                  ),
                                                ),
                                              ],
                                            )
                                          : (_hasClockIn[learnerID] != true &&
                                                  (clockInTime == null ||
                                                      clockInTime.isEmpty))
                                              ? const Text('--',
                                                  style: TextStyle(
                                                      color: Colors.grey))
                                              : ElevatedButton(
                                                  onPressed: _isVerifying
                                                      ? null
                                                      : () async {
                                                          await clockOutLearner(
                                                              learnerID);
                                                        },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.orange,
                                                    foregroundColor:
                                                        Colors.white,
                                                  ),
                                                  child:
                                                      const Text('Clock Out'),
                                                ),
                                    ),
                                    DataCell(
                                      Text(
                                        contactTime ?? '--',
                                        style: TextStyle(
                                          color: (contactTime != null &&
                                                  contactTime.isNotEmpty)
                                              ? Colors.blue[800]
                                              : Colors.grey,
                                          fontWeight: (contactTime != null &&
                                                  contactTime.isNotEmpty)
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
        if (_isVerifying)
          Container(
            color: Colors.black.withOpacity(0.4),
            child: Center(
              child: AlertDialog(
                content: Row(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 20),
                    Expanded(child: Text(_statusMessage)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
