import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:collection';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'EnrollmentPage.dart';
import 'services/fingerprint_service.dart';
import 'DetailsPage.dart';
import 'sick_note_page.dart';
import 'database_helper.dart';
import 'sync_service.dart'
    show syncSingleClockIn, syncSingleClockOut, SyncService;
import 'utils/clocking_logger.dart';
import 'utils/fingerprint_error_handler.dart';
// MONITORING SYSTEM TEMPORARILY DISABLED - BUILD ISSUE
// import 'utils/monitoring_mixin.dart';
import 'debug_log_viewer.dart';
//import 'services/futronic_service.dart';

import 'config.dart';

// Extension must be top-level
extension StringCasingExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

class ClockInPage extends StatefulWidget {
  final String classID;
  final List<dynamic> learners;

  const ClockInPage({
    super.key,
    required this.classID,
    required this.learners,
  });

  @override
  State<ClockInPage> createState() => _ClockInPageState();
}

class _ClockInPageState extends State<ClockInPage> {
  // MonitoringMixin DISABLED - BUILD ISSUE
  final FingerprintService _fingerprintService = FingerprintService();
  final FutronicService _futronicService = FutronicService();
  Map<String, String> clockInTimes = {};
  Map<String, String> clockOutTimes = {};
  Map<String, String> contactTimes = {};
  final Map<String, bool> _isClockingIn = {};

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<dynamic> _filteredLearners = [];

  // Request queue and rate limiting for concurrent requests
  final Queue<Map<String, dynamic>> _requestQueue =
      Queue<Map<String, dynamic>>();
  bool _isProcessingQueue = false;
  final Duration _requestDelay =
      const Duration(milliseconds: 500); // 500ms between requests
  DateTime? _lastRequestTime;
  final int _maxConcurrentRequests = 3;
  int _activeRequests = 0;

  // CameraController? _cameraController;  // Temporarily disabled due to Java 21 compatibility issues
  // List<CameraDescription>? _cameras;  // Temporarily disabled due to Java 21 compatibility issues
  // int _selectedCameraIndex = 0;  // Temporarily disabled due to Java 21 compatibility issues
  // bool _isCameraReady = false;  // Temporarily disabled due to Java 21 compatibility issues
  // bool _isCapturing = false;  // Temporarily disabled due to Java 21 compatibility issues
  // XFile? _capturedImage;  // Temporarily disabled due to Java 21 compatibility issues
  bool _isVerifying = false;
  String _statusMessage = '';
  StreamSubscription? _enrollStatusSubscription;
  StreamSubscription? _enrollSuccessSubscription;
  StreamSubscription? _connectivitySubscription;
  Timer? _autoSyncTimer; // Periodic auto-sync timer
  bool _isSensorConnected = false;
  bool _isInitializing = false;
  String? _currentLearnerIdForClocking;
  String? _currentClockingAction; // 'in' or 'out'
  bool _isConnected = false; // Add real-time connectivity status

  @override
  void initState() {
    super.initState();
    databaseFactory = databaseFactoryFfi;
    ClockingLogger.instance.initialize();
    ClockingLogger.instance.logAppLifecycle('Clock-in page initialized',
        details: 'ClassID: ${widget.classID}');
    _initializeData();
    // _initializeCamera();  // Temporarily disabled due to Java 21 compatibility issues
    _initializeSensor(); // Add sensor initialization
    _setupStreams();
    _setupConnectivityListener();
    _checkInitialConnectivity(); // Check initial connectivity status
    // _setupAutoSync(); // DISABLED: Auto-sync causing fake clock-ins
  }

  @override
  void dispose() {
    _enrollStatusSubscription?.cancel();
    _enrollSuccessSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _autoSyncTimer?.cancel(); // Cancel periodic auto-sync
    _fingerprintService.dispose();
    // _cameraController?.dispose();  // Temporarily disabled due to Java 21 compatibility issues
    _searchController.dispose();
    // disposeMonitoring(); // Stop monitoring service - DISABLED - BUILD ISSUE
    super.dispose();
  }

  // Check initial connectivity status
  Future<void> _checkInitialConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    } catch (e) {
      print('Error checking initial connectivity: $e');
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
      }
    }
  }

  // Request queue management for handling concurrent requests
  Future<void> _addToRequestQueue(Map<String, dynamic> request) async {
    _requestQueue.add(request);
    if (!_isProcessingQueue) {
      _processRequestQueue();
    }
  }

  Future<void> _processRequestQueue() async {
    if (_isProcessingQueue || _requestQueue.isEmpty) return;

    _isProcessingQueue = true;

    while (
        _requestQueue.isNotEmpty && _activeRequests < _maxConcurrentRequests) {
      final request = _requestQueue.removeFirst();

      // Rate limiting: ensure minimum delay between requests
      if (_lastRequestTime != null) {
        final timeSinceLastRequest =
            DateTime.now().difference(_lastRequestTime!);
        if (timeSinceLastRequest < _requestDelay) {
          await Future.delayed(_requestDelay - timeSinceLastRequest);
        }
      }

      _activeRequests++;
      _lastRequestTime = DateTime.now();

      // Process the request
      _processRequest(request).then((_) {
        _activeRequests--;
        // Continue processing queue
        if (_requestQueue.isNotEmpty &&
            _activeRequests < _maxConcurrentRequests) {
          _processRequestQueue();
        }
      }).catchError((error) {
        _activeRequests--;
        print('[QUEUE] Error processing request: $error');
        // Continue processing queue even if one request fails
        if (_requestQueue.isNotEmpty &&
            _activeRequests < _maxConcurrentRequests) {
          _processRequestQueue();
        }
      });
    }

    _isProcessingQueue = false;
  }

  Future<void> _processRequest(Map<String, dynamic> request) async {
    final type = request['type'] as String;
    final learnerId = request['learnerId'] as String;
    final completer = request['completer'] as Completer<bool>;

    try {
      bool result = false;

      switch (type) {
        case 'clock_in':
          result = await _performClockInSync(learnerId, request['attendance']);
          break;
        case 'clock_out':
          result = await _performClockOutSync(learnerId, request['attendance']);
          break;
        default:
          throw Exception('Unknown request type: $type');
      }

      completer.complete(result);
    } catch (e) {
      completer.completeError(e);
    }
  }

  Future<bool> _performClockInSync(
      String learnerId, Map<String, dynamic> attendance) async {
    return await syncSingleClockIn(attendance);
  }

  Future<bool> _performClockOutSync(
      String learnerId, Map<String, dynamic> attendance) async {
    return await syncSingleClockOut(attendance);
  }

  // Manual connectivity refresh
  Future<void> _refreshConnectivityStatus() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });

        // Connectivity status tracked silently - no distracting messages
        debugPrint(
            '[CONNECTIVITY] Connection status: ${isConnected ? "Online" : "Offline"}');
      }
    } catch (e) {
      print('Error refreshing connectivity status: $e');
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
      }
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (List<ConnectivityResult> results) async {
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      final isConnected = result != ConnectivityResult.none;
      final wasOffline = !_isConnected;

      debugPrint(
          '[CONNECTIVITY] Status changed: $result, isConnected: $isConnected');

      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });

        if (isConnected && wasOffline) {
          debugPrint(
              '[CONNECTIVITY] Internet available - syncing offline records from previous days');
          // CRITICAL FIX: When coming back online, sync ALL offline records (including previous days)
          // This ensures previous day's records are uploaded before allowing new clock-ins
          await _syncOfflineClockIns(showMessages: false);
          debugPrint('[CONNECTIVITY] Offline records sync completed');
        } else if (isConnected) {
          debugPrint('[CONNECTIVITY] Internet available');
        } else {
          debugPrint(
              '[CONNECTIVITY] Internet connection lost - switching to offline mode');
          // No UI notification - tracked silently to avoid distraction
        }
      }
    }, onError: (error) {
      debugPrint('[CONNECTIVITY] Error in connectivity listener: $error');
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
      }
    });
  }

  // Set up periodic auto-sync (every 3 minutes)
  void _setupAutoSync() {
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 3), (timer) async {
      if (!mounted || !_isConnected) return;

      debugPrint('[AUTO_SYNC] 🔄 Running periodic auto-sync...');

      try {
        // 1. Sync offline records to server
        await _syncOfflineClockIns();

        // 2. Fetch current day's records from server to local
        await _fetchClockingDataFromServer();

        // 3. Reload data to display synced records
        await _loadLearnersFromLocalDatabase();

        debugPrint('[AUTO_SYNC] ✅ Periodic sync completed');
      } catch (e) {
        debugPrint('[AUTO_SYNC] ❌ Periodic sync error: $e');
      }
    });

    debugPrint('[AUTO_SYNC] ⏰ Periodic auto-sync enabled (every 3 minutes)');
  }

  Future<void> _initializeSensor() async {
    if (_isInitializing) return; // Prevent concurrent initialization

    setState(() {
      _isInitializing = true;
      _statusMessage = 'Checking sensor connection...';
    });

    try {
      // Cancel any ongoing operations to free up the sensor
      await _fingerprintService.cancelEnrollment().catchError((e) {
        print('[INIT] Cancel enrollment error (expected on first run): $e');
      });

      await Future.delayed(const Duration(milliseconds: 500));

      final isConnected = await _fingerprintService.isSensorConnected();
      if (!mounted) return;

      setState(() {
        _isSensorConnected = isConnected;
        _statusMessage =
            isConnected ? 'Sensor connected' : 'Sensor not connected';
        _isInitializing = false;
      });

      if (!isConnected) {
        FingerprintErrorHandler.showError(
            context, 'Scanner not connected. Please check USB connection.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error initializing sensor: $e';
        _isSensorConnected = false;
        _isInitializing = false;
      });
      FingerprintErrorHandler.showError(
          context, 'Scanner initialization failed: $e');
    }
  }

  void _setupStreams() {
    _enrollStatusSubscription =
        _fingerprintService.enrollStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _statusMessage = status;
          if (status.toLowerCase().contains('error') ||
              status.toLowerCase().contains('failed') ||
              status.toLowerCase().contains('timed out')) {
            _isVerifying = false;
            _hideProgressDialog();
            if (_currentLearnerIdForClocking != null) {
              setState(
                  () => _isClockingIn[_currentLearnerIdForClocking!] = false);
            }
            FingerprintErrorHandler.showError(context, status);
            // Only reset sensor on real error, not after every operation
          }
        });
      }
    });

    _enrollSuccessSubscription =
        _fingerprintService.enrollSuccessStream.listen((capturedData) async {
      debugPrint('[CLOCK_IN] enrollSuccessStream received: $capturedData');

      // CRITICAL FIX #1: Ignore fingerprints if no learner is actively clocking
      if (!mounted ||
          _currentLearnerIdForClocking == null ||
          _currentClockingAction == null) {
        debugPrint(
            '[CLOCK_IN] ❌ IGNORED: No active clocking session. CurrentLearner=$_currentLearnerIdForClocking, Action=$_currentClockingAction');
        return;
      }

      _hideProgressDialog(); // Always close the dialog after capture

      // CRITICAL FIX #2: Capture the current learner and action IMMEDIATELY to prevent race conditions
      final learnerId = _currentLearnerIdForClocking!;
      final action = _currentClockingAction!;
      final scannedTemplate = capturedData['template'] as String?;

      // CRITICAL FIX #3: Clear global state immediately to prevent other learners from interfering
      _currentLearnerIdForClocking = null;
      _currentClockingAction = null;

      debugPrint(
          '[CLOCK_IN] Processing fingerprint for learner: $learnerId, action: $action');

      // CRITICAL FIX #4: Verify this learner is still in the clocking process
      if (!_isClockingIn.containsKey(learnerId) ||
          _isClockingIn[learnerId] != true) {
        debugPrint(
            '[CLOCK_IN] ❌ SAFETY CHECK FAILED: Learner $learnerId is no longer in clocking process');
        return;
      }

      debugPrint(
          '[CLOCK_IN] Scanned template length: ${scannedTemplate?.length}');

      if (scannedTemplate == null) {
        FingerprintErrorHandler.showError(context, 'Fingerprint scan failed');
        setState(() => _isClockingIn[learnerId] = false);
        return;
      }

      try {
        final learnerIdInt = int.tryParse(learnerId);
        if (learnerIdInt == null) {
          debugPrint('[CLOCK_IN] Error: Invalid learner ID: $learnerId');
          FingerprintErrorHandler.showError(
              context, 'Invalid learner ID: $learnerId');
          return;
        }

        // Get ALL templates for this learner to check scanner-specific columns
        final templates = await DatabaseHelper().getAllTemplates(learnerIdInt);

        String? leftTemplate;
        String? rightTemplate;

        // Use the appropriate scanner templates based on the scanner type
        // Use the old getFingerprints method which returns the best available templates
        final storedTemplates =
            await DatabaseHelper().getFingerprints(learnerIdInt);
        leftTemplate = storedTemplates['left'];
        rightTemplate = storedTemplates['right'];

        debugPrint('[CLOCK_IN] Using available templates');
        debugPrint('[CLOCK_IN] Left template length: ${leftTemplate?.length}');
        debugPrint(
            '[CLOCK_IN] Right template length: ${rightTemplate?.length}');
        debugPrint(
            '[CLOCK_IN] Left template exists: ${leftTemplate != null && leftTemplate.isNotEmpty}');
        debugPrint(
            '[CLOCK_IN] Right template exists: ${rightTemplate != null && rightTemplate.isNotEmpty}');

        // Check if any fingerprints exist for this learner for the specific scanner
        if ((leftTemplate == null || leftTemplate.isEmpty) &&
            (rightTemplate == null || rightTemplate.isEmpty)) {
          debugPrint('[CLOCK_IN] No fingerprints found for learner $learnerId');
          FingerprintErrorHandler.showError(context,
              'No fingerprints enrolled for this learner. Please enroll fingerprints first.');
          return;
        }

        bool match = false;
        debugPrint(
            '[CLOCK_IN] ========== FINGERPRINT MATCHING STARTED ==========');
        debugPrint('[CLOCK_IN] Learner ID: $learnerId');
        debugPrint(
            '[CLOCK_IN] Scanned template size: ${scannedTemplate.length} bytes');

        if (leftTemplate != null && leftTemplate.isNotEmpty) {
          debugPrint(
              '[CLOCK_IN] Attempting match with LEFT template (size: ${leftTemplate.length} bytes)...');
          match = await _fingerprintService.matchTemplates(
              leftTemplate, scannedTemplate);
          debugPrint('[CLOCK_IN] LEFT template match result: $match');
        } else {
          debugPrint('[CLOCK_IN] No left template available for matching');
        }

        if (!match && rightTemplate != null && rightTemplate.isNotEmpty) {
          debugPrint(
              '[CLOCK_IN] Attempting match with RIGHT template (size: ${rightTemplate.length} bytes)...');
          match = await _fingerprintService.matchTemplates(
              rightTemplate, scannedTemplate);
          debugPrint('[CLOCK_IN] RIGHT template match result: $match');
        } else if (!match) {
          debugPrint('[CLOCK_IN] No right template available for matching');
        }

        debugPrint(
            '[CLOCK_IN] ========== FINAL MATCH RESULT: $match ==========');

        if (match) {
          debugPrint(
              '[CLOCK_IN] ✅ FINGERPRINT MATCH CONFIRMED for Learner $learnerId');
          if (action == 'in') {
            // GEOFENCING CHECK: Verify user is within 50 meters before allowing clock-in
            print('[CLOCK_IN] Fingerprint matched - checking geofence...');
            bool withinRadius = await _checkLocationAndRadius();

            if (!withinRadius) {
              print(
                  '[CLOCK_IN] ❌ Geofence check failed - user not within 50 meters');
              setState(() => _isClockingIn[learnerId] = false);
              return;
            }

            print(
                '[CLOCK_IN] ✅ Geofence check passed - proceeding with clock-in');

            final now = _getCurrentTimeString();
            final date = _getCurrentDateString();

            // FIRST: Check if learner already clocked in today
            final existingAttendance =
                await DatabaseHelper().getAttendanceForDay(learnerId, date);
            if (existingAttendance != null &&
                existingAttendance['clock_in_time'] != null &&
                existingAttendance['clock_in_time'].toString().isNotEmpty) {
              print(
                  '[CLOCK_IN] ❌ Learner $learnerId already clocked in today at ${existingAttendance['clock_in_time']}');
              FingerprintErrorHandler.showInfo(context,
                  'Already clocked in today at ${existingAttendance['clock_in_time']}');
              setState(() => _isClockingIn[learnerId] = false);
              return;
            }

            // Get current position for storing with attendance
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );

            final attendance = {
              'LearnerID': learnerId,
              'clock_in_time': now,
              'clock_out_time': '', // Empty for clock-in
              'contact_time': '', // Empty for clock-in
              'clock_date': date,
              'classID': widget.classID, // For sync only
              'synced': 0,
              'user_latitude': position.latitude.toString(),
              'user_longitude': position.longitude.toString(),
              'user_accuracy': position.accuracy.toString(),
            };

            print('[CLOCK_IN] Starting sync for clock-in...');
            print(
                '[CLOCK_IN] Location: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');
            ClockingLogger.instance.logClockInAttempt(
                learnerId, 'Manual user action',
                additionalData: attendance);

            bool synced = false;

            // Check if online - if so, try immediate sync first
            final connectivityCheck = await _checkConnectivity();
            print('[CLOCK_IN] Connectivity check result: $connectivityCheck');
            print('[CLOCK_IN] _isConnected state: $_isConnected');

            if (connectivityCheck) {
              print(
                  '[CLOCK_IN] ========== ONLINE MODE - SYNCING TO SERVER ==========');
              try {
                synced = await syncSingleClockIn(attendance);
                print('[CLOCK_IN] ========== SYNC RESULT: $synced ==========');
              } catch (e) {
                print('[CLOCK_IN] ========== SYNC FAILED: $e ==========');
                synced = false;
              }
            } else {
              print(
                  '[CLOCK_IN] ========== OFFLINE MODE - WILL SYNC LATER ==========');
              synced = false;
            }

            // If immediate sync failed or offline, use queue as fallback
            if (!synced) {
              print('[CLOCK_IN] Using queue fallback for sync...');
              final completer = Completer<bool>();
              await _addToRequestQueue({
                'type': 'clock_in',
                'learnerId': learnerId,
                'attendance': attendance,
                'completer': completer,
              });

              synced = await completer.future;
              print('[CLOCK_IN] Queue sync result: $synced');
            }

            print('[CLOCK_IN] Final sync result: $synced');

            // ALWAYS save to local database first (same as facilitator logic)
            print('[CLOCK_IN] Step 1: Saving to local database...');
            final dbData = {
              'LearnerID': learnerId,
              'clock_in_time': now,
              'clock_out_time': '', // Empty for clock-in
              'contact_time': '', // Empty for clock-in
              'clock_date': date,
              'synced':
                  synced ? 1 : 0, // Mark as synced if server sync succeeded
            };
            await DatabaseHelper().insertClocking(dbData);
            print(
                '[CLOCK_IN] ✅ Saved to local database with synced=${synced ? 1 : 0}');

            // Start monitoring service for this learner - DISABLED - BUILD ISSUE
            // initMonitoring(learnerId);

            // Show appropriate message
            if (synced) {
              print('[CLOCK_IN] ✅ Clock-in synced to server successfully');
              FingerprintErrorHandler.showSuccess(
                  context, 'Clock-in synced to server!',
                  duration: const Duration(seconds: 2));
            } else {
              print(
                  '[CLOCK_IN] 📱 Clock-in saved locally (will sync when online)');
              FingerprintErrorHandler.showInfo(
                  context, 'Saved locally (will sync when online)',
                  duration: const Duration(seconds: 2));
            }

            // Update UI immediately (DON'T wait for sync - update UI first!)
            setState(() {
              clockInTimes[learnerId] = now;
              _isClockingIn[learnerId] =
                  false; // Reset loading state immediately
            });
            print(
                '[CLOCK_IN] ✅ UI updated IMMEDIATELY with clock-in time: $now');
            print(
                '[CLOCK_IN] ✅ clockInTimes[$learnerId] = ${clockInTimes[learnerId]}');
            print(
                '[CLOCK_IN] ✅ clockOutTimes[$learnerId] = ${clockOutTimes[learnerId]}');

            // Show success message immediately
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Clock-in successful! Time: $now'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else if (action == 'out') {
            final existingAttendance = await DatabaseHelper()
                .getAttendanceForDay(learnerId, _getCurrentDateString());
            if (existingAttendance == null ||
                existingAttendance['clock_in_time'] == null) {
              FingerprintErrorHandler.showInfo(
                  context, 'Cannot clock out. No prior clock-in found.');
              setState(() => _isClockingIn[learnerId] = false);
            } else {
              // GEOFENCING CHECK: Verify user is within 50 meters before allowing clock-out
              print('[CLOCK_OUT] Fingerprint matched - checking geofence...');
              bool withinRadius = await _checkLocationAndRadius();

              if (!withinRadius) {
                print(
                    '[CLOCK_OUT] ❌ Geofence check failed - user not within 50 meters');
                setState(() => _isClockingIn[learnerId] = false);
                return;
              }

              print(
                  '[CLOCK_OUT] ✅ Geofence check passed - proceeding with clock-out');

              final now = _getCurrentTimeString();
              final clockInTime =
                  existingAttendance['clock_in_time'].toString();
              final contactTime = _calculateContactTime(clockInTime, now);

              // Get current position for storing with attendance
              Position position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
              );

              // Prepare complete attendance data for sync
              final attendance = {
                'LearnerID': learnerId,
                'clock_in_time': clockInTime,
                'clock_out_time': now,
                'contact_time': contactTime,
                'clock_date': _getCurrentDateString(),
                'classID': widget.classID, // For sync only
                'synced': 0,
                'user_latitude': position.latitude.toString(),
                'user_longitude': position.longitude.toString(),
                'user_accuracy': position.accuracy.toString(),
              };

              // Try to sync to server first
              print('[CLOCK_OUT] Starting sync for clock-out...');
              print(
                  '[CLOCK_OUT] Location: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');

              bool synced = false;

              // Check if online - if so, try immediate sync first
              if (_isConnected) {
                print(
                    '[CLOCK_OUT] Online - attempting immediate server sync...');
                try {
                  synced = await syncSingleClockOut(attendance);
                  print('[CLOCK_OUT] Immediate sync result: $synced');
                } catch (e) {
                  print('[CLOCK_OUT] Immediate sync failed: $e');
                  synced = false;
                }
              }

              // If immediate sync failed or offline, use queue as fallback
              if (!synced) {
                print('[CLOCK_OUT] Using queue fallback for sync...');
                final completer = Completer<bool>();
                await _addToRequestQueue({
                  'type': 'clock_out',
                  'learnerId': learnerId,
                  'attendance': attendance,
                  'completer': completer,
                });

                synced = await completer.future;
                print('[CLOCK_OUT] Queue sync result: $synced');
              }

              print('[CLOCK_OUT] Final sync result: $synced');

              if (synced) {
                print(
                    '[CLOCK_OUT] Sync SUCCESS - updating local DB with synced=1');
                // Sync successful - update local database with synced=1
                final updatedAttendance = {
                  'clock_out_time': now,
                  'contact_time': contactTime,
                  'synced': 1, // Mark as synced
                };
                await DatabaseHelper().updateClocking(
                    existingAttendance['clocking_id'], updatedAttendance);
                FingerprintErrorHandler.showSuccess(
                    context, 'Clock-out synced to server!');
              } else {
                print(
                    '[CLOCK_OUT] Sync FAILED - updating local DB with synced=0');
                // Sync failed - update local database with synced=0 for later sync
                final updatedAttendance = {
                  'clock_out_time': now,
                  'contact_time': contactTime,
                  'synced': 0, // Mark as not synced
                };
                await DatabaseHelper().updateClocking(
                    existingAttendance['clocking_id'], updatedAttendance);
                FingerprintErrorHandler.showInfo(
                    context, 'Clock-out saved locally (will sync when online)');
              }

              // Update UI immediately with clock-out time and contact time
              setState(() {
                clockOutTimes[learnerId] = now;
                contactTimes[learnerId] = contactTime;
                _isClockingIn[learnerId] =
                    false; // Reset loading state immediately
              });
              print(
                  '[CLOCK_OUT] ✅ UI updated IMMEDIATELY with clock-out time: $now, contact: $contactTime');

              // Show success message immediately
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Clock-out successful! Time: $now'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          }
        } else {
          debugPrint(
              '[CLOCK_IN] ❌ NO FINGERPRINT MATCH FOUND for Learner $learnerId!');
          debugPrint(
              '[CLOCK_IN] ❌ This fingerprint does NOT belong to this learner');
          debugPrint('[CLOCK_IN] ❌ CLOCKING DENIED - Fingerprint mismatch');
          FingerprintErrorHandler.showError(context,
              'Fingerprint does NOT match this learner! Clocking denied.');
          setState(() => _isClockingIn[learnerId] = false);
        }
      } catch (e) {
        debugPrint('[CLOCK_IN] Verification error: $e');
        FingerprintErrorHandler.showError(context, e.toString());
      } finally {
        setState(() {
          _isClockingIn[learnerId] = false;
          // Note: _currentLearnerIdForClocking and _currentClockingAction already cleared above
        });
      }
    });
  }

  // Future<void> _initializeCamera() async {  // Temporarily disabled due to Java 21 compatibility issues
  //   try {
  //     _cameras = await availableCameras();
  //     if (_cameras != null && _cameras!.isNotEmpty) {
  //       _selectedCameraIndex = _cameras!.length > 1 ? 0 : 0;
  //       _cameraController = CameraController(
  //         _cameras![_selectedCameraIndex],
  //         ResolutionPreset.low,
  //         enableAudio: false,
  //       );
  //       await _cameraController!.initialize();
  //       print('Camera initialized: ${_cameras![_selectedCameraIndex].name}');
  //       setState(() {
  //         _isCameraReady = true;
  //       });
  //     } else {
  //       print('No cameras available');
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('No cameras available')),
  //       );
  //     }
  //   } catch (e) {
  //     print('Camera initialization error: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to initialize camera: $e')),
  //     );
  //   }
  // }

  String _getCurrentTimeString() {
    // Use South African time (SAST - UTC+2)
    final saTime = DateTime.now().toUtc().add(const Duration(hours: 2));
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(saTime);
  }

  String _getCurrentDateString() {
    // Use South African date (SAST - UTC+2)
    final saTime = DateTime.now().toUtc().add(const Duration(hours: 2));
    return DateFormat('yyyy-MM-dd').format(saTime);
  }

  String _calculateContactTime(String clockIn, String clockOut) {
    try {
      DateTime? inTime;
      DateTime? outTime;

      final fullFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
      final timeFmt = DateFormat('HH:mm:ss');

      // Detect formats
      final inHasDate = clockIn.contains(' ');
      final outHasDate = clockOut.contains(' ');

      if (inHasDate) {
        inTime = fullFmt.parse(clockIn);
      } else {
        // Parse time-only
        final t = timeFmt.parse(clockIn);
        inTime = DateTime(1970, 1, 1, t.hour, t.minute, t.second);
      }

      if (outHasDate) {
        outTime = fullFmt.parse(clockOut);
      } else {
        final t = timeFmt.parse(clockOut);
        outTime = DateTime(1970, 1, 1, t.hour, t.minute, t.second);
      }

      // If one has date and the other doesn't, align date parts to the one that has it
      if (inHasDate && !outHasDate) {
        outTime = DateTime(inTime.year, inTime.month, inTime.day, outTime.hour,
            outTime.minute, outTime.second);
      } else if (!inHasDate && outHasDate) {
        inTime = DateTime(outTime.year, outTime.month, outTime.day, inTime.hour,
            inTime.minute, inTime.second);
      }

      final duration = outTime.difference(inTime);
      final totalSeconds = duration.inSeconds.abs();
      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;
      final seconds = totalSeconds % 60;
      return "${hours}h ${minutes}m ${seconds}s";
    } catch (_) {
      return "0h 0m 0s";
    }
  }

  // Calculate working days in a month (excluding weekends AND holidays)
  int _getWorkingDaysInMonth(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    final lastDay = DateTime(date.year, date.month + 1, 0);

    // Get South African holidays for the year
    final holidays = _getSouthAfricanHolidays(date.year);

    int workingDays = 0;
    for (int day = 1; day <= lastDay.day; day++) {
      final currentDay = DateTime(date.year, date.month, day);
      final dateStr = DateFormat('yyyy-MM-dd').format(currentDay);

      // Monday = 1, Sunday = 7, so weekdays are 1-5
      if (currentDay.weekday >= 1 && currentDay.weekday <= 5) {
        // Check if this weekday is a holiday
        if (!holidays.containsKey(dateStr)) {
          workingDays++;
        }
      }
    }
    return workingDays;
  }

  // Get South African public holidays for a given year
  Map<String, String> _getSouthAfricanHolidays(int year) {
    final holidays = <String, String>{};

    // Fixed holidays
    final fixedHolidays = {
      '$year-01-01': 'New Year\'s Day',
      '$year-03-21': 'Human Rights Day',
      '$year-04-27': 'Freedom Day',
      '$year-05-01': 'Workers\' Day',
      '$year-06-16': 'Youth Day',
      '$year-08-09': 'National Women\'s Day',
      '$year-09-24': 'Heritage Day',
      '$year-12-16': 'Day of Reconciliation',
      '$year-12-25': 'Christmas Day',
      '$year-12-26': 'Day of Goodwill',
    };

    // Add fixed holidays and check for Sunday observation
    fixedHolidays.forEach((date, name) {
      final holidayDate = DateTime.parse(date);
      if (holidayDate.weekday == DateTime.sunday) {
        // If holiday falls on Sunday, observe on Monday
        holidays[date] = name;
        final observedDate = holidayDate.add(const Duration(days: 1));
        holidays[DateFormat('yyyy-MM-dd').format(observedDate)] =
            '$name (Observed)';
      } else {
        holidays[date] = name;
      }
    });

    // Calculate Easter-based holidays
    final easter = _calculateEaster(year);
    final goodFriday = easter.subtract(const Duration(days: 2));
    final familyDay = easter.add(const Duration(days: 1));

    holidays[DateFormat('yyyy-MM-dd').format(goodFriday)] = 'Good Friday';
    holidays[DateFormat('yyyy-MM-dd').format(familyDay)] = 'Family Day';

    return holidays;
  }

  // Calculate Easter Sunday for a given year (Computus algorithm)
  DateTime _calculateEaster(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;

    return DateTime(year, month, day);
  }

  // Get clocking days count from server
  Future<int> _getServerClockingDaysCount(String learnerId,
      {bool includeToday = false}) async {
    try {
      final url = '${AppConfig.baseUrl}/get_clocking_days_count.php';
      final uri = Uri.parse(url).replace(queryParameters: {
        'learner_id': learnerId,
        'include_today': includeToday.toString(),
      });

      print('[SERVER_COUNT] Requesting: $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final serverCount = data['data']['clocking_days'] as int? ?? 0;
          print('[SERVER_COUNT] Server returned: $serverCount days');
          return serverCount;
        } else {
          print('[SERVER_COUNT] Server error: ${data['error']}');
          return 0;
        }
      } else {
        print('[SERVER_COUNT] HTTP error: ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      print('[SERVER_COUNT] Exception: $e');
      return 0;
    }
  }

  // Get clocking days count from local database
  Future<int> _getLocalClockingDaysCount(String learnerId,
      {bool includeToday = false}) async {
    try {
      final now = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 2)); // South African time
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth =
          includeToday ? now : DateTime(now.year, now.month, now.day - 1);

      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final result = await db.rawQuery('''
        SELECT COUNT(DISTINCT clock_date) as count
        FROM learner_clocking 
        WHERE LearnerID = ? 
        AND clock_in_time IS NOT NULL 
        AND clock_in_time != ''
        AND clock_date >= ? 
        AND clock_date <= ?
      ''', [
        learnerId,
        DateFormat('yyyy-MM-dd').format(firstDayOfMonth),
        DateFormat('yyyy-MM-dd').format(lastDayOfMonth),
      ]);

      final localCount =
          result.isNotEmpty ? (result.first['count'] as int? ?? 0) : 0;
      print('[LOCAL_COUNT] Local database returned: $localCount days');
      return localCount;
    } catch (e) {
      print('[LOCAL_COUNT] Error getting local clocking days count: $e');
      return 0;
    }
  }

  // Enhanced clocking days count that combines local and server data
  Future<Map<String, dynamic>> _getEnhancedClockingDaysCount(String learnerId,
      {bool includeToday = false}) async {
    print(
        '[ENHANCED_COUNT] Getting clocking days for learner $learnerId (includeToday: $includeToday)');

    // Get local count (always available)
    final localCount =
        await _getLocalClockingDaysCount(learnerId, includeToday: includeToday);

    // Try to get server count if online
    int serverCount = 0;
    bool serverAvailable = false;

    if (_isConnected) {
      print('[ENHANCED_COUNT] Online - fetching server count...');
      serverCount = await _getServerClockingDaysCount(learnerId,
          includeToday: includeToday);
      serverAvailable = serverCount > 0 ||
          localCount ==
              0; // Consider server available if it returns data or if local is empty
    } else {
      print('[ENHANCED_COUNT] Offline - using local count only');
    }

    // Use the higher count (server data is more comprehensive)
    final finalCount =
        serverAvailable ? math.max(localCount, serverCount) : localCount;

    print(
        '[ENHANCED_COUNT] Final result - Local: $localCount, Server: $serverCount, Final: $finalCount');

    return {
      'count': finalCount,
      'local_count': localCount,
      'server_count': serverCount,
      'server_available': serverAvailable,
      'source': serverAvailable ? 'server' : 'local',
    };
  }

  // Get clocking days count for a learner in the current month (backward compatibility)
  Future<int> _getClockingDaysCount(String learnerId,
      {bool includeToday = false}) async {
    final result = await _getEnhancedClockingDaysCount(learnerId,
        includeToday: includeToday);
    return result['count'] as int;
  }

  // Enhanced clocking days popup with server/local breakdown
  Future<void> _showClockingDaysPopup(String learnerId, String action) async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 2));
    final workingDays = _getWorkingDaysInMonth(now);

    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Loading clocking data...'),
            ],
          ),
        );
      },
    );

    // Get enhanced clocking data
    final clockingData = await _getEnhancedClockingDaysCount(learnerId,
        includeToday: action == 'out');
    final clockingDays = clockingData['count'] as int;
    final localCount = clockingData['local_count'] as int;
    final serverCount = clockingData['server_count'] as int;
    final serverAvailable = clockingData['server_available'] as bool;
    final source = clockingData['source'] as String;

    // Close loading dialog
    Navigator.of(context).pop();

    final monthName = DateFormat('MMMM yyyy').format(now);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Clocking Summary - $monthName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text(
              //   'Learner ID: $learnerId',
              //   style: const TextStyle(fontWeight: FontWeight.bold),
              // ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Actual Attended Days:'),
                  Text(
                    '$clockingDays',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Expected Attendance Days:'),
                  Text(
                    '$workingDays',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Actual Attended Days:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$clockingDays/$workingDays',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: clockingDays >= workingDays * 0.8
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
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

  Future<bool> _checkLocationAndRadius() async {
    try {
      print('[GEOFENCE] Checking location permissions...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Location services are disabled. Please enable GPS.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are denied'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permissions are permanently denied. Please enable in settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Get current position
      print('[GEOFENCE] Getting current position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      print(
          '[GEOFENCE] Current position: ${position.latitude}, ${position.longitude}');
      print('[GEOFENCE] Accuracy: ${position.accuracy} meters');

      // Check if within site radius (50 meters)
      return await _isWithinSiteRadius(
        widget.classID,
        position.latitude,
        position.longitude,
        position.accuracy,
      );
    } catch (e) {
      print('[GEOFENCE] Error checking location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _isWithinSiteRadius(String classID, double userLat,
      double userLon, double userAccuracy) async {
    if (userAccuracy > 50) {
      // Accuracy threshold for 50 meter radius
      print('[GEOFENCE] Geolocation accuracy too low: $userAccuracy meters');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('GPS accuracy too low. Please wait for better signal.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final classes = await db.query('class');
      final sites = await db.query('sites');
      print('[GEOFENCE] Class table contents: $classes');
      print('[GEOFENCE] Sites table contents: $sites');
      print(
          '[GEOFENCE] Querying coordinates for classID: $classID (type: ${classID.runtimeType})');

      final result = await db.rawQuery(
        'SELECT s.latitude, s.longitude FROM class c JOIN sites s ON c.siteID = s.siteID WHERE c.classID = ?',
        [classID.toString()],
      );

      if (result.isEmpty) {
        if (classes.isEmpty) {
          print('[GEOFENCE] Class table is empty');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('No class data available in local database.')),
            );
          }
        } else if (sites.isEmpty) {
          print('[GEOFENCE] Sites table is empty');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('No site data available in local database.')),
            );
          }
        } else {
          print(
              '[GEOFENCE] No matching class or site found for classID: $classID');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('No site coordinates found for class $classID.')),
            );
          }
        }
        return false;
      }

      final siteLat = double.tryParse(result.first['latitude'].toString());
      final siteLon = double.tryParse(result.first['longitude'].toString());

      if (siteLat == null || siteLon == null) {
        print(
            '[GEOFENCE] Invalid site coordinates for classID: $classID, lat: ${result.first['latitude']}, lon: ${result.first['longitude']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Invalid site coordinates in database.')),
          );
        }
        return false;
      }

      final distance = _calculateDistance(userLat, userLon, siteLat, siteLon);

      print(
          '[GEOFENCE] Distance to site for classID $classID: ${distance.toStringAsFixed(2)} meters');
      print('[GEOFENCE] Site coordinates: $siteLat, $siteLon');
      print('[GEOFENCE] User coordinates: $userLat, $userLon');

      if (distance > 50) {
        // 50 meters radius
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'You are ${distance.toStringAsFixed(0)} meters away. Must be within 50 meters to clock in/out.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return false;
      }

      print('[GEOFENCE] ✅ Within 50 meter radius - clocking allowed');
      return true;
    } catch (e, stackTrace) {
      print(
          '[GEOFENCE] Error checking site radius for classID $classID: $e\nStack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking location: $e')),
        );
      }
      return false;
    }
  }

  Future<String> _detectScanner() async {
    // Try ZKTeco first
    try {
      final isZkConnected = await _fingerprintService.isSensorConnected();
      if (isZkConnected) return 'zkteco';
    } catch (_) {}

    // Enhanced Futronic detection with retry
    return await _detectFutronicWithRetry();
  }

  Future<String> _detectFutronicWithRetry() async {
    const maxAttempts = 3;
    const delays = [500, 1000, 2000]; // Progressive delays

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        print('[DETECT] Futronic attempt $attempt/$maxAttempts...');
        final isFutronicConnected =
            await _futronicService.isFutronicConnected();

        if (isFutronicConnected) {
          print('[DETECT] ✅ Futronic detected on attempt $attempt!');
          return 'futronic';
        }

        // Wait before next attempt (except on last)
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: delays[attempt - 1]));
        }
      } catch (e) {
        print('[DETECT] Futronic attempt $attempt failed: $e');
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }

    print('[DETECT] ❌ No Futronic scanner detected after all attempts');
    return 'none';
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

    // CRITICAL SAFETY CHECK: Prevent multiple learners from clocking simultaneously
    if (_currentLearnerIdForClocking != null &&
        _currentLearnerIdForClocking != learnerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Another learner is currently clocking. Please wait.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show clocking days popup before proceeding
    await _showClockingDaysPopup(learnerId, 'in');

    final learnerIdInt = int.tryParse(learnerId);
    if (learnerIdInt == null) {
      FingerprintErrorHandler.showError(
          context, 'Invalid learner ID. Cannot proceed with clock-in.');
      return;
    }
    final templates = await DatabaseHelper().getAllTemplates(learnerIdInt);
    final scanner = await _detectScanner();

    // Evaluate available templates per scanner
    final hasZkLeft = (templates['zkteco_left_template']?.isNotEmpty ?? false);
    final hasZkRight =
        (templates['zkteco_right_template']?.isNotEmpty ?? false);
    final hasFutLeft =
        (templates['futronic_left_template']?.isNotEmpty ?? false);
    final hasFutRight =
        (templates['futronic_right_template']?.isNotEmpty ?? false);

    // If current scanner has no templates but the other scanner does, guide user
    if (scanner == 'futronic' &&
        !(hasFutLeft || hasFutRight) &&
        (hasZkLeft || hasZkRight)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'This learner\'s fingerprint is enrolled on ZKTeco. Please use the ZKTeco scanner or re-enroll on Futronic for this learner.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (scanner == 'zkteco' &&
        !(hasZkLeft || hasZkRight) &&
        (hasFutLeft || hasFutRight)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'This learner\'s fingerprint is enrolled on Futronic. Please use the Futronic scanner or re-enroll on ZKTeco for this learner.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? template;
    if (scanner == 'zkteco') {
      template = templates['zkteco_left_template'] ??
          templates['zkteco_right_template'];
    } else if (scanner == 'futronic') {
      template = templates['futronic_left_template'] ??
          templates['futronic_right_template'];
    }
    if (template == null || template.isEmpty) {
      // Navigate to EnrollmentPage and request auto-return after enrollment
      bool? enrolled;
      final parsedId = int.tryParse(learnerId);
      if (parsedId != null) {
        enrolled = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnrollmentPage(
              learnerId: parsedId,
              returnToClockAfterEnroll: true,
            ),
          ),
        );
      } else {
        final dynamic res = await Navigator.pushNamed(
          context,
          '/enrollment',
          arguments: {'learnerId': learnerId, 'returnToClockAfterEnroll': true},
        );
        if (res is bool) enrolled = res;
      }

      // If enrollment happened, re-attempt clock-in once
      if (enrolled == true) {
        if (!mounted) return;
        final refreshed = await DatabaseHelper().getAllTemplates(learnerIdInt);
        final hasNew =
            (refreshed['zkteco_left_template']?.isNotEmpty ?? false) ||
                (refreshed['zkteco_right_template']?.isNotEmpty ?? false) ||
                (refreshed['futronic_left_template']?.isNotEmpty ?? false) ||
                (refreshed['futronic_right_template']?.isNotEmpty ?? false);
        if (hasNew) {
          // Re-run verification flow
          await _verifyAndClockIn(learnerId);
          return;
        }
      }
      // If user backed out or no new template, show guidance
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enrollment required to clock in'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isClockingIn[learnerId] = true;
      _currentLearnerIdForClocking = learnerId;
      _currentClockingAction = 'in';
    });

    // Build guidance message based on available templates for active scanner
    String guidance = 'Place finger on scanner for clock-in...';
    if (scanner == 'futronic') {
      if (hasFutLeft && hasFutRight) {
        guidance = 'Place either thumb on Futronic scanner for clock-in...';
      } else if (hasFutLeft)
        guidance = 'Place LEFT thumb on Futronic scanner for clock-in...';
      else if (hasFutRight)
        guidance = 'Place RIGHT thumb on Futronic scanner for clock-in...';
    } else if (scanner == 'zkteco') {
      if (hasZkLeft && hasZkRight) {
        guidance = 'Place either thumb on ZKTeco scanner for clock-in...';
      } else if (hasZkLeft)
        guidance = 'Place LEFT thumb on ZKTeco scanner for clock-in...';
      else if (hasZkRight)
        guidance = 'Place RIGHT thumb on ZKTeco scanner for clock-in...';
    }
    _showProgressDialog(guidance);

    try {
      bool match = false;
      if (scanner == 'zkteco') {
        match = await _fingerprintService.verify('left', template) ||
            await _fingerprintService.verify('right', template);
      } else if (scanner == 'futronic') {
        try {
          debugPrint(
              '[CLOCK_IN] Attempting Futronic verification for learner $learnerId');
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
          debugPrint('[CLOCK_IN] Futronic verification error: $futronicError');
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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
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
        // GEOFENCING CHECK: Verify user is within 50 meters before allowing clock-in
        print('[CLOCK_IN] Fingerprint matched - checking geofence...');
        _showProgressDialog('Checking location...');

        bool withinRadius = await _checkLocationAndRadius();
        _hideProgressDialog();

        if (!withinRadius) {
          print(
              '[CLOCK_IN] ❌ Geofence check failed - user not within 50 meters');
          setState(() {
            _isClockingIn[learnerId] = false;
            _currentLearnerIdForClocking = null;
            _currentClockingAction = null;
          });
          return;
        }

        print('[CLOCK_IN] ✅ Geofence check passed - proceeding with clock-in');

        final now = _getCurrentTimeString();
        final date = _getCurrentDateString();

        // Get current position for storing with attendance
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final attendance = {
          'LearnerID': learnerId,
          'clock_in_time': now,
          'clock_out_time': '', // Empty for clock-in
          'contact_time': '', // Empty for clock-in
          'clock_date': date,
          'classID': widget.classID, // For sync only
          'synced': 0,
          'user_latitude': position.latitude.toString(),
          'user_longitude': position.longitude.toString(),
          'user_accuracy': position.accuracy.toString(),
        };

        print('[CLOCK_IN] Starting sync for clock-in...');
        print(
            '[CLOCK_IN] Location: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');

        bool synced = false;

        // Check if online - if so, try immediate sync first
        if (_isConnected) {
          print('[CLOCK_IN] Online - attempting immediate server sync...');
          try {
            synced = await syncSingleClockIn(attendance);
            print('[CLOCK_IN] Immediate sync result: $synced');
          } catch (e) {
            print('[CLOCK_IN] Immediate sync failed: $e');
            synced = false;
          }
        }

        // If immediate sync failed or offline, use queue as fallback
        if (!synced) {
          print('[CLOCK_IN] Using queue fallback for sync...');
          final completer = Completer<bool>();
          await _addToRequestQueue({
            'type': 'clock_in',
            'learnerId': learnerId,
            'attendance': attendance,
            'completer': completer,
          });

          synced = await completer.future;
          print('[CLOCK_IN] Queue sync result: $synced');
        }

        print('[CLOCK_IN] Final sync result: $synced');

        if (synced) {
          print('[CLOCK_IN] Sync SUCCESS - saving to local DB with synced=1');
          // Sync successful - save to local database with synced=1
          final dbData = {
            'LearnerID': learnerId,
            'clock_in_time': now,
            'clock_out_time': '', // Empty for clock-in
            'contact_time': '', // Empty for clock-in
            'clock_date': date,
            'synced': 1, // Mark as synced
          };
          await DatabaseHelper().insertClocking(dbData);

          // Start monitoring service for this learner - temporarily disabled
          // initMonitoring(learnerId);

          // UI already updated above, just show sync success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Clock-in synced to server!'),
                backgroundColor: Colors.blue),
          );
        } else {
          print('[CLOCK_IN] Sync FAILED - saving to local DB with synced=0');
          // Sync failed - save to local database with synced=0 for later sync
          final dbData = {
            'LearnerID': learnerId,
            'clock_in_time': now,
            'clock_out_time': '', // Empty for clock-in
            'contact_time': '', // Empty for clock-in
            'clock_date': date,
            'synced': 0, // Mark as not synced
          };
          await DatabaseHelper().insertClocking(dbData);

          // Start monitoring service for this learner - temporarily disabled
          // initMonitoring(learnerId);

          // UI already updated above, just show offline message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Clock-in saved locally (will sync when online)'),
                backgroundColor: Colors.orange),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Fingerprint does not match!'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      _hideProgressDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Verification error: $e'),
            backgroundColor: Colors.red),
      );
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

    // CRITICAL SAFETY CHECK: Prevent multiple learners from clocking simultaneously
    if (_currentLearnerIdForClocking != null &&
        _currentLearnerIdForClocking != learnerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Another learner is currently clocking. Please wait.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final existingAttendance = await DatabaseHelper()
        .getAttendanceForDay(learnerId, _getCurrentDateString());
    if (existingAttendance == null ||
        existingAttendance['clock_in_time'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please clock in first'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    // Show clocking days popup before proceeding
    await _showClockingDaysPopup(learnerId, 'out');

    final templates =
        await DatabaseHelper().getAllTemplates(int.parse(learnerId));
    final scanner = await _detectScanner();

    // Evaluate available templates per scanner
    final hasZkLeft = (templates['zkteco_left_template']?.isNotEmpty ?? false);
    final hasZkRight =
        (templates['zkteco_right_template']?.isNotEmpty ?? false);
    final hasFutLeft =
        (templates['futronic_left_template']?.isNotEmpty ?? false);
    final hasFutRight =
        (templates['futronic_right_template']?.isNotEmpty ?? false);

    // If current scanner has no templates but the other scanner does, guide user
    if (scanner == 'futronic' &&
        !(hasFutLeft || hasFutRight) &&
        (hasZkLeft || hasZkRight)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'This learner\'s fingerprint is enrolled on ZKTeco. Please use the ZKTeco scanner or re-enroll on Futronic for this learner.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (scanner == 'zkteco' &&
        !(hasZkLeft || hasZkRight) &&
        (hasFutLeft || hasFutRight)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'This learner\'s fingerprint is enrolled on Futronic. Please use the Futronic scanner or re-enroll on ZKTeco for this learner.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? template;
    if (scanner == 'zkteco') {
      template = templates['zkteco_left_template'] ??
          templates['zkteco_right_template'];
    } else if (scanner == 'futronic') {
      template = templates['futronic_left_template'] ??
          templates['futronic_right_template'];
    }
    if (template == null || template.isEmpty) {
      // Navigate to EnrollmentPage and request auto-return after enrollment
      bool? enrolled;
      final parsedId = int.tryParse(learnerId);
      if (parsedId != null) {
        enrolled = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnrollmentPage(
              learnerId: parsedId,
              returnToClockAfterEnroll: true,
            ),
          ),
        );
      } else {
        final dynamic res = await Navigator.pushNamed(
          context,
          '/enrollment',
          arguments: {'learnerId': learnerId, 'returnToClockAfterEnroll': true},
        );
        if (res is bool) enrolled = res;
      }

      if (enrolled == true) {
        final refreshed =
            await DatabaseHelper().getAllTemplates(int.parse(learnerId));
        final hasNew =
            (refreshed['zkteco_left_template']?.isNotEmpty ?? false) ||
                (refreshed['zkteco_right_template']?.isNotEmpty ?? false) ||
                (refreshed['futronic_left_template']?.isNotEmpty ?? false) ||
                (refreshed['futronic_right_template']?.isNotEmpty ?? false);
        if (hasNew) {
          // Re-run clock-out attempt
          await _verifyAndClockOut(learnerId);
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enrollment required to clock out'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isClockingIn[learnerId] = true;
      _currentLearnerIdForClocking = learnerId;
      _currentClockingAction = 'out';
    });

    // Build guidance message based on available templates for active scanner
    String guidance = 'Place finger on scanner for clock-out...';
    if (scanner == 'futronic') {
      if (hasFutLeft && hasFutRight) {
        guidance = 'Place either thumb on Futronic scanner for clock-out...';
      } else if (hasFutLeft)
        guidance = 'Place LEFT thumb on Futronic scanner for clock-out...';
      else if (hasFutRight)
        guidance = 'Place RIGHT thumb on Futronic scanner for clock-out...';
    } else if (scanner == 'zkteco') {
      if (hasZkLeft && hasZkRight) {
        guidance = 'Place either thumb on ZKTeco scanner for clock-out...';
      } else if (hasZkLeft)
        guidance = 'Place LEFT thumb on ZKTeco scanner for clock-out...';
      else if (hasZkRight)
        guidance = 'Place RIGHT thumb on ZKTeco scanner for clock-out...';
    }
    _showProgressDialog(guidance);

    try {
      bool match = false;
      if (scanner == 'zkteco') {
        match = await _fingerprintService.verify('left', template) ||
            await _fingerprintService.verify('right', template);
      } else if (scanner == 'futronic') {
        try {
          debugPrint(
              '[CLOCK_OUT] Attempting Futronic verification for learner $learnerId');
          // Capture once, compare both left/right templates if available
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
          debugPrint('[CLOCK_OUT] Futronic verification error: $futronicError');
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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
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
        // GEOFENCING CHECK: Verify user is within 50 meters before allowing clock-out
        print('[CLOCK_OUT] Fingerprint matched - checking geofence...');
        _showProgressDialog('Checking location...');

        bool withinRadius = await _checkLocationAndRadius();
        _hideProgressDialog();

        if (!withinRadius) {
          print(
              '[CLOCK_OUT] ❌ Geofence check failed - user not within 50 meters');
          setState(() {
            _isClockingIn[learnerId] = false;
            _currentLearnerIdForClocking = null;
            _currentClockingAction = null;
          });
          return;
        }

        print(
            '[CLOCK_OUT] ✅ Geofence check passed - proceeding with clock-out');

        final now = _getCurrentTimeString();
        final clockInTime = existingAttendance['clock_in_time'].toString();
        final contactTime = _calculateContactTime(clockInTime, now);

        // Get current position for storing with attendance
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Prepare complete attendance data for sync
        final attendance = {
          'LearnerID': learnerId,
          'clock_in_time': clockInTime,
          'clock_out_time': now,
          'contact_time': contactTime,
          'clock_date': _getCurrentDateString(),
          'classID': widget.classID, // For sync only
          'synced': 0,
          'user_latitude': position.latitude.toString(),
          'user_longitude': position.longitude.toString(),
          'user_accuracy': position.accuracy.toString(),
        };

        // Try to sync to server first
        print('[CLOCK_OUT] Starting sync for clock-out...');
        print(
            '[CLOCK_OUT] Location: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');

        bool synced = false;

        // Check if online - if so, try immediate sync first
        if (_isConnected) {
          print('[CLOCK_OUT] Online - attempting immediate server sync...');
          try {
            synced = await syncSingleClockOut(attendance);
            print('[CLOCK_OUT] Immediate sync result: $synced');
          } catch (e) {
            print('[CLOCK_OUT] Immediate sync failed: $e');
            synced = false;
          }
        }

        // If immediate sync failed or offline, use queue as fallback
        if (!synced) {
          print('[CLOCK_OUT] Using queue fallback for sync...');
          final completer = Completer<bool>();
          await _addToRequestQueue({
            'type': 'clock_out',
            'learnerId': learnerId,
            'attendance': attendance,
            'completer': completer,
          });

          synced = await completer.future;
          print('[CLOCK_OUT] Queue sync result: $synced');
        }

        print('[CLOCK_OUT] Final sync result: $synced');

        if (synced) {
          print('[CLOCK_OUT] Sync SUCCESS - updating local DB with synced=1');
          // Sync successful - update local database with synced=1
          final updatedAttendance = {
            'clock_out_time': now,
            'contact_time': contactTime,
            'synced': 1, // Mark as synced
          };
          await DatabaseHelper().updateClocking(
              existingAttendance['clocking_id'], updatedAttendance);
          // UI already updated above, just show sync success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Clock-out synced to server!'),
                backgroundColor: Colors.blue),
          );
        } else {
          print('[CLOCK_OUT] Sync FAILED - updating local DB with synced=0');
          // Sync failed - update local database with synced=0 for later sync
          final updatedAttendance = {
            'clock_out_time': now,
            'contact_time': contactTime,
            'synced': 0, // Mark as not synced
          };
          await DatabaseHelper().updateClocking(
              existingAttendance['clocking_id'], updatedAttendance);
          // UI already updated above, just show offline message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Clock-out saved locally (will sync when online)'),
                backgroundColor: Colors.orange),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Fingerprint does not match!'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      _hideProgressDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Verification error: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isClockingIn[learnerId] = false;
        _currentLearnerIdForClocking = null;
        _currentClockingAction = null;
      });
    }
  }

  Future<void> _initializeData() async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    final classes = await db.query('class');
    final sites = await db.query('sites');
    print('Class table contents on init: $classes');
    print('Sites table contents on init: $sites');

    // Check connectivity first to determine loading strategy
    final isConnected = await _checkConnectivity();

    if (isConnected) {
      // Online mode: Try to sync from server first, fallback to local
      try {
        print(
            '[INIT] Online mode - syncing learners from server for classID: ${widget.classID}');
        await dbHelper.syncLearnersFromServer(widget.classID);
        print(
            '[INIT] Successfully synced learners from server for classID: ${widget.classID}');
      } catch (e) {
        print('[INIT] Failed to sync learners from server: $e');
        print('[INIT] Falling back to local database');
        // Continue with local data even if sync fails
      }

      // CRITICAL FIX: Sync ALL offline records from previous days when coming online
      // This ensures previous day's records are uploaded before allowing new clock-ins
      print('[INIT] Checking for offline records from previous days...');
      await _syncOfflineClockIns(showMessages: false);
      print('[INIT] Offline records sync completed');
    } else {
      // Offline mode: Load only from local database
      print('[INIT] Offline mode - loading learners from local database only');
    }

    await _loadLearnersFromLocalDatabase();

    // DISABLED: Automatic server fetch on page load causes all learners to appear clocked in
    // This was fetching ALL server records and inserting them into local DB
    // Server sync should ONLY happen when manually triggered or after fingerprint verification
    // if (isConnected) {
    //   await _fetchClockingDataFromServer();
    // }

    _startPeriodicRefresh();

    // Check for unsynced records on startup
    _checkForUnsyncedRecords();

    // Initialize search
    _setupSearch();
  }

  Future<void> _checkForUnsyncedRecords() async {
    final unsyncedCount = await _getUnsyncedCount();
    if (unsyncedCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'You have $unsyncedCount offline record(s) that need to be synced. Tap the sync button to upload them.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Sync Now',
            onPressed: () => _syncOfflineClockIns(showMessages: true),
          ),
        ),
      );
    }
  }

  void _startPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
      // Increased to 30 seconds to reduce server load
      if (mounted) {
        _refreshDataWithoutClearingState();
        // DISABLED: Auto-sync causing fake clock-ins
        // if (_isConnected) {
        //   _syncOfflineClockIns();
        // }
        _startPeriodicRefresh();
      }
    });
  }

  Future<void> _fetchClockingDataFromServer() async {
    if (!_isConnected) return; // Only fetch if connected

    // DISABLED: Auto-sync causing fake clock-ins
    // await _syncOfflineClockIns();

    debugPrint(
        '[FETCH] ========== FETCHING CLOCKING DATA FROM SERVER ==========');
    debugPrint('[FETCH] ClassID: ${widget.classID}');
    debugPrint('[FETCH] This will ONLY sync existing server records for TODAY');
    debugPrint(
        '[FETCH] NO new clock-ins will be created - only displaying synced data');

    // Sync clocking data from server for this class only (current day)
    try {
      final syncService = SyncService();
      await syncService.syncClassClockingFromServer(widget.classID);
      print(
          '[FETCH] ✅ Synced CURRENT DAY clocking data from server for classID: ${widget.classID}');
    } catch (e) {
      print('[FETCH] ❌ Error syncing class clocking from server: $e');
    }

    // Reload local data to reflect the synced records (CURRENT DAY ONLY)
    debugPrint('[FETCH] Reloading learners from local database...');
    await _loadLearnersFromLocalDatabase();
    debugPrint('[FETCH] ========== FETCH COMPLETE ==========');
  }

  Future<void> _syncOfflineClockIns({bool showMessages = false}) async {
    // Check connectivity first
    if (!_isConnected) {
      print('[SYNC] No internet connection - skipping offline sync');
      // No UI notification - this runs automatically in background
      return;
    }

    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    // Sync ALL offline records when connectivity returns (not just today)
    final offlineRecords = await db.query(
      'learner_clocking',
      where: 'synced = ?',
      whereArgs: [0],
    );

    if (offlineRecords.isEmpty) {
      print('[SYNC] No offline records to sync');
      // No UI notification - user didn't trigger this manually
      return;
    }

    print('Found ${offlineRecords.length} offline records to sync');

    // If many records (>10), use bulk sync. Otherwise sync individually for better error handling
    if (offlineRecords.length > 10) {
      print('[SYNC] Using BULK sync for ${offlineRecords.length} records');
      try {
        final syncService = SyncService();
        await syncService.syncClockingDataToServer();

        // After bulk sync, cleanup
        await dbHelper.cleanupOldClockingRecords();

        if (mounted && showMessages) {
          FingerprintErrorHandler.showSuccess(
            context,
            'Synced ${offlineRecords.length} offline records',
            duration: const Duration(seconds: 2),
          );
        }
        return;
      } catch (e) {
        print('[SYNC] Bulk sync failed: $e, falling back to individual sync');
        // Fall through to individual sync if bulk fails
      }
    }

    print('[SYNC] Using INDIVIDUAL sync for ${offlineRecords.length} records');

    int successCount = 0;
    int failureCount = 0;

    for (var record in offlineRecords) {
      try {
        final learnerId = record['LearnerID'].toString();
        final clockInTime = record['clock_in_time']?.toString() ?? '';
        final clockOutTime = record['clock_out_time']?.toString() ?? '';
        final contactTime = record['contact_time']?.toString() ?? '';
        final clockDate = record['clock_date']?.toString() ?? '';
        final clockingId = record['clocking_id'];

        print('Attempting to sync offline record for $learnerId');

        bool synced = false;

        // If it's a clock-in record (has clock_in_time but no clock_out_time)
        if (clockInTime.isNotEmpty && clockOutTime.isEmpty) {
          final attendance = {
            'LearnerID': learnerId,
            'clock_in_time': clockInTime,
            'clock_out_time': '',
            'contact_time': '',
            'clock_date': clockDate,
            'classID': widget.classID,
            'synced': 0,
            'user_latitude': record['user_latitude']?.toString() ?? '0.0',
            'user_longitude': record['user_longitude']?.toString() ?? '0.0',
            'user_accuracy': record['user_accuracy']?.toString() ?? '10.0',
          };

          print('Syncing clock-in for $learnerId');
          synced = await syncSingleClockIn(attendance);
        }
        // If it's a clock-out record (has both clock_in_time and clock_out_time)
        else if (clockInTime.isNotEmpty && clockOutTime.isNotEmpty) {
          final attendance = {
            'LearnerID': learnerId,
            'clock_in_time': clockInTime,
            'clock_out_time': clockOutTime,
            'contact_time': contactTime,
            'clock_date': clockDate,
            'classID': widget.classID,
            'synced': 0,
            'user_latitude': record['user_latitude']?.toString() ?? '0.0',
            'user_longitude': record['user_longitude']?.toString() ?? '0.0',
            'user_accuracy': record['user_accuracy']?.toString() ?? '10.0',
          };

          print('Syncing clock-out for $learnerId');
          synced = await syncSingleClockOut(attendance);
        }

        if (synced) {
          // Mark as synced - cleanup will delete it later
          await db.update(
            'learner_clocking',
            {'synced': 1},
            where: 'clocking_id = ?',
            whereArgs: [clockingId],
          );
          print(
              'Successfully synced offline record for $learnerId (ID: $clockingId)');
          successCount++;
        } else {
          print('Failed to sync offline record for $learnerId');
          failureCount++;
        }
      } catch (e) {
        print('Error syncing offline record: $e');
        failureCount++;
      }
    }

    // Clean up old synced records after sync completes
    if (successCount > 0) {
      try {
        await dbHelper.cleanupOldClockingRecords();
        print('Cleaned up old records after sync');
      } catch (e) {
        print('Error cleaning up after sync: $e');
      }
    }

    // Show summary message only if user manually triggered sync
    if (mounted && showMessages) {
      if (successCount > 0 && failureCount == 0) {
        FingerprintErrorHandler.showSuccess(
            context, 'Synced $successCount offline record(s)',
            duration: const Duration(seconds: 2));
      } else if (successCount > 0 && failureCount > 0) {
        FingerprintErrorHandler.showInfo(
            context, 'Synced $successCount, $failureCount failed',
            duration: const Duration(seconds: 3));
      } else if (successCount == 0 && failureCount > 0) {
        FingerprintErrorHandler.showError(
            context, 'Failed to sync $failureCount offline record(s)');
      }
    } else if (successCount > 0) {
      // Silent background sync - just log
      print(
          '[SYNC] ✅ Background sync completed: $successCount synced, $failureCount failed');
    }
  }

  Future<void> _refreshDataWithoutClearingState() async {
    try {
      final dbHelper = DatabaseHelper();
      final learnersWithClockingData =
          await dbHelper.getLearnersWithClockingData(widget.classID);

      setState(() {
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
        }

        widget.learners.clear();
        for (var learner in learnersWithClockingData) {
          // Ensure all values are strings before adding to list
          final stringLearner = <String, String>{};
          learner.forEach((key, value) {
            stringLearner[key] = value?.toString() ?? '';
          });
          widget.learners.add(stringLearner);
        }

        // Update filtered learners after data refresh
        _filterLearners();
      });
    } catch (e) {
      print('Error refreshing data: $e');
    }
  }

  Future<void> _loadLearnersFromLocalDatabase() async {
    try {
      final dbHelper = DatabaseHelper();
      final learnersWithClockingData =
          await dbHelper.getLearnersWithClockingData(widget.classID);

      debugPrint(
          '[LOAD] ========== LOADING LEARNERS FROM LOCAL DATABASE ==========');
      debugPrint(
          '[LOAD] Found ${learnersWithClockingData.length} learners for classID: ${widget.classID}');

      setState(() {
        widget.learners.clear();
        int clockedInCount = 0;
        int clockedOutCount = 0;

        for (var learner in learnersWithClockingData) {
          String learnerId = learner['LearnerID']?.toString() ?? 'N/A';
          String learnerName = learner['Name']?.toString() ?? 'Unknown';
          String clockInTime = learner['clock_in_time']?.toString() ?? '';
          String clockOutTime = learner['clock_out_time']?.toString() ?? '';
          String contactTime = learner['contact_time']?.toString() ?? '';

          if (clockInTime.isNotEmpty &&
              clockInTime != 'N/A' &&
              clockInTime != 'null') {
            clockInTimes[learnerId] = clockInTime;
            clockedInCount++;
            debugPrint(
                '[LOAD] Learner $learnerId ($learnerName) - Clocked IN at $clockInTime');
          }
          if (clockOutTime.isNotEmpty &&
              clockOutTime != 'N/A' &&
              clockOutTime != 'null') {
            clockOutTimes[learnerId] = clockOutTime;
            clockedOutCount++;
            debugPrint(
                '[LOAD] Learner $learnerId ($learnerName) - Clocked OUT at $clockOutTime');
          }
          if (contactTime.isNotEmpty &&
              contactTime != 'N/A' &&
              contactTime != 'null') {
            contactTimes[learnerId] = contactTime;
          }

          widget.learners.add({
            'LearnerID': learnerId,
            'Name': learner['Name']?.toString() ?? 'N/A',
            'Surname': learner['Surname']?.toString() ?? 'N/A',
            'IDNumber': learner['IDNumber']?.toString() ?? 'N/A',
            'clock_in_time': clockInTime,
            'clock_out_time': clockOutTime,
            'contact_time': contactTime,
          });
        }

        debugPrint('[LOAD] ========== LOAD SUMMARY ==========');
        debugPrint('[LOAD] Total learners: ${widget.learners.length}');
        debugPrint('[LOAD] Clocked IN: $clockedInCount');
        debugPrint('[LOAD] Clocked OUT: $clockedOutCount');
        debugPrint('[LOAD] ========== LOAD COMPLETE ==========');

        // Initialize filtered learners after data load
        _filterLearners();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading offline learners: $e')),
      );
    }
  }

  // Load ALL learners from class with their earliest clocking data (if any)
  Future<void> _loadAllLearnersFromLocalDatabase() async {
    try {
      final dbHelper = DatabaseHelper();
      final allLearnersData =
          await dbHelper.getLearnersWithAllClockingData(widget.classID);

      setState(() {
        widget.learners.clear();
        clockInTimes.clear();
        clockOutTimes.clear();
        contactTimes.clear();

        // Process all learners (with or without clocking)
        for (var learner in allLearnersData) {
          String learnerId = learner['LearnerID']?.toString() ?? 'N/A';
          String clockInTime = learner['clock_in_time']?.toString() ?? '';
          String clockOutTime = learner['clock_out_time']?.toString() ?? '';
          String contactTime = learner['contact_time']?.toString() ?? '';
          String clockDate = learner['clock_date']?.toString() ?? '';
          bool hasClocking = learner['has_clocking'] ?? false;

          // Set clocking times if learner has clocking records
          if (hasClocking &&
              clockInTime.isNotEmpty &&
              clockInTime != 'N/A' &&
              clockInTime != 'null') {
            clockInTimes[learnerId] = clockInTime; // Earliest clock-in time
          }
          if (hasClocking &&
              clockOutTime.isNotEmpty &&
              clockOutTime != 'N/A' &&
              clockOutTime != 'null') {
            clockOutTimes[learnerId] = clockOutTime;
          }
          if (hasClocking &&
              contactTime.isNotEmpty &&
              contactTime != 'N/A' &&
              contactTime != 'null') {
            contactTimes[learnerId] = contactTime;
          }

          // Add learner to list (with or without clocking)
          widget.learners.add({
            'LearnerID': learnerId,
            'Name': learner['Name']?.toString() ?? 'N/A',
            'Surname': learner['Surname']?.toString() ?? 'N/A',
            'IDNumber': learner['IDNumber']?.toString() ?? 'N/A',
            'clock_in_time':
                hasClocking ? clockInTime : '', // Empty if no clocking
            'clock_out_time':
                hasClocking ? clockOutTime : '', // Empty if no clocking
            'contact_time':
                hasClocking ? contactTime : '', // Empty if no clocking
            'clock_date': hasClocking ? clockDate : '', // Empty if no clocking
            'has_clocking': hasClocking.toString(), // Convert boolean to string
          });
        }

        // Initialize filtered learners after data load
        _filterLearners();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading all learners: $e')),
      );
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371e3; // Earth radius in meters
    final double phi1 = lat1 * math.pi / 180;
    final double phi2 = lat2 * math.pi / 180;
    final double deltaPhi = (lat2 - lat1) * math.pi / 180;
    final double deltaLambda = (lon2 - lon1) * math.pi / 180;

    final double a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c; // Distance in meters
  }

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      // Update the state if it's different
      if (mounted && _isConnected != isConnected) {
        setState(() {
          _isConnected = isConnected;
        });
      }

      return isConnected;
    } catch (e) {
      print('Error checking connectivity: $e');
      return false;
    }
  }

  Future<int> _getUnsyncedCount() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM learner_clocking WHERE synced = 0',
      );
      return result.first['count'] as int;
    } catch (e) {
      print('Error getting unsynced count: $e');
      return 0;
    }
  }

  void _setupSearch() {
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _filterLearners();
      });
    });

    // Initialize filtered learners
    _filterLearners();
  }

  void _filterLearners() {
    if (_searchQuery.isEmpty) {
      _filteredLearners = List.from(widget.learners);
    } else {
      _filteredLearners = widget.learners.where((learner) {
        String idNumber = learner['IDNumber']?.toString().toLowerCase() ?? '';

        // Search by full ID number or first 6 digits
        return idNumber.contains(_searchQuery) ||
            (idNumber.length >= 6 &&
                idNumber.substring(0, 6).contains(_searchQuery));
      }).toList();
    }

    // Sort alphabetically by surname
    _filteredLearners.sort((a, b) {
      String surnameA = a['Surname']?.toString().toLowerCase() ?? '';
      String surnameB = b['Surname']?.toString().toLowerCase() ?? '';
      return surnameA.compareTo(surnameB);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filterLearners();
    });
  }

  void _showQueueStatus() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('System Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Connection: ${_isConnected ? 'Online' : 'Offline'}',
                    style: TextStyle(
                      color: _isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.sync, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('Active Requests: $_activeRequests'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.queue, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('Queued Requests: ${_requestQueue.length}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.settings, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Max Concurrent: $_maxConcurrentRequests'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Request Delay: ${_requestDelay.inMilliseconds}ms'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Learner List: Class ${widget.classID}'),
        actions: [
          // Status indicator for connectivity and queue
          GestureDetector(
            onTap: () {
              _showQueueStatus();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _isConnected
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isConnected ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    size: 16,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isConnected ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_activeRequests > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange, width: 1),
                      ),
                      child: Text(
                        '$_activeRequests',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (_requestQueue.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue, width: 1),
                      ),
                      child: Text(
                        'Q:${_requestQueue.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.orange),
            onPressed: _isConnected
                ? () async {
                    // Show loading indicator
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Syncing offline data...'),
                        backgroundColor: Colors.blue,
                        duration: Duration(seconds: 1),
                      ),
                    );

                    // Trigger fast sync
                    await _syncOfflineClockIns(showMessages: true);

                    // Refresh UI immediately after sync
                    await _loadLearnersFromLocalDatabase();
                  }
                : null,
            tooltip:
                _isConnected ? 'Sync Offline Data' : 'No Internet Connection',
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.green),
            onPressed: _isConnected
                ? () async {
                    // Show loading indicator
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Syncing current day records from server...'),
                        backgroundColor: Colors.blue,
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // Sync CURRENT DAY clocking records from server only
                    try {
                      final syncService = SyncService();
                      await syncService
                          .syncClassClockingFromServer(widget.classID);

                      // Refresh local data to show the synced records
                      await _loadAllLearnersFromLocalDatabase();

                      if (mounted) {
                        FingerprintErrorHandler.showSuccess(
                            context, 'Current day records synced from server!');
                      }
                    } catch (e) {
                      if (mounted) {
                        FingerprintErrorHandler.showError(context,
                            'Failed to sync current day records from server');
                      }
                    }
                  }
                : null,
            tooltip: _isConnected
                ? 'Sync Current Day Records from Server'
                : 'No Internet Connection',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            onPressed: _isConnected
                ? () async {
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
                  }
                : null,
            tooltip: _isConnected
                ? 'Sync Learners from Server'
                : 'No Internet Connection',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.orange),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DebugLogViewer()),
              );
            },
            tooltip: 'Debug Logs',
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Learner Actions: Clock In/Out, Upload Sick Notes, View Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: _getUnsyncedCount(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data! > 0) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning,
                            color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${snapshot.data} offline record(s) waiting to sync',
                          style: const TextStyle(
                              color: Colors.orange, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 8),
            // Connectivity status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isConnected
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                border: Border.all(
                  color: _isConnected ? Colors.green : Colors.red,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: _isConnected ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isConnected
                        ? 'Connected to Internet'
                        : 'No Internet Connection',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _refreshConnectivityStatus,
                    child: Icon(
                      Icons.refresh,
                      color: _isConnected ? Colors.green : Colors.red,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 14,
                color: _statusMessage.contains('error') ||
                        _statusMessage.contains('failed')
                    ? Colors.red
                    : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            // Search bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by ID Number',
                      hintText: 'Enter full ID or first 6 digits',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSearch,
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Results count
            if (_searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Found ${_filteredLearners.length} learner(s) matching "$_searchQuery"',
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _filteredLearners.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No data available for this class'
                          : 'No learners found matching "$_searchQuery"',
                      style: const TextStyle(fontSize: 16),
                    ),
                  )
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
                            DataColumn(label: Text('Fingerprint')),
                            DataColumn(label: Text('Clock In')),
                            DataColumn(label: Text('Clock Out')),
                            DataColumn(label: Text('Contact Time')),
                            DataColumn(label: Text('Sick Note')),
                            DataColumn(
                              label: Text(
                                'Action',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: _filteredLearners.map((learner) {
                            String learnerId =
                                learner['LearnerID']?.toString() ?? 'N/A';
                            String name = learner['Name']?.toString() ?? 'N/A';
                            String surname =
                                learner['Surname']?.toString() ?? 'N/A';
                            String clockInTime = clockInTimes[learnerId] ?? '';
                            String clockOutTime =
                                clockOutTimes[learnerId] ?? '';
                            String contactTime = contactTimes[learnerId] ?? '';
                            bool hasClocking =
                                (learner['has_clocking']?.toString() ==
                                        'true') ??
                                    false;

                            return DataRow(
                              cells: [
                                DataCell(Text(name)),
                                DataCell(Text(surname)),
                                DataCell(Text(
                                    learner['IDNumber']?.toString() ?? 'N/A')),
                                // Fingerprint status column
                                DataCell(
                                  FutureBuilder<Map<String, String?>>(
                                    future: DatabaseHelper()
                                        .getFingerprints(int.parse(learnerId)),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        );
                                      }

                                      if (snapshot.hasError) {
                                        return const Icon(Icons.error,
                                            color: Colors.red, size: 16);
                                      }

                                      final templates = snapshot.data ??
                                          {'left': null, 'right': null};
                                      final hasLeft =
                                          templates['left'] != null &&
                                              templates['left']!.isNotEmpty;
                                      final hasRight =
                                          templates['right'] != null &&
                                              templates['right']!.isNotEmpty;

                                      if (hasLeft || hasRight) {
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.fingerprint,
                                                color: Colors.green, size: 16),
                                            Text(
                                                hasLeft && hasRight
                                                    ? 'Both'
                                                    : hasLeft
                                                        ? 'Left'
                                                        : 'Right',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.green)),
                                          ],
                                        );
                                      } else {
                                        return const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.fingerprint,
                                                color: Colors.red, size: 16),
                                            Text('None',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.red)),
                                          ],
                                        );
                                      }
                                    },
                                  ),
                                ),
                                // Clock In column: show button or time
                                DataCell(
                                  Builder(
                                    builder: (context) {
                                      // Check if learner has clocked in (either in memory OR in database)
                                      final currentClockInTime =
                                          clockInTimes[learnerId];
                                      final hasCurrentClockIn =
                                          currentClockInTime != null &&
                                              currentClockInTime.isNotEmpty;

                                      if (!hasCurrentClockIn) {
                                        // No clock-in time - show button
                                        return Tooltip(
                                          message: hasClocking
                                              ? 'Clock in for today'
                                              : 'Learner has never clocked in',
                                          child: ElevatedButton(
                                            onPressed:
                                                _isClockingIn[learnerId] == true
                                                    ? null
                                                    : () => _verifyAndClockIn(
                                                        learnerId),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                            ),
                                            child: const Text('Clock In'),
                                          ),
                                        );
                                      } else {
                                        // Has clock-in time - show it
                                        return Tooltip(
                                          message: hasClocking
                                              ? 'Earliest clock-in: $currentClockInTime'
                                              : 'Clocked in today',
                                          child: Text(
                                            currentClockInTime,
                                            style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                // Clock Out column: show button, time, or status
                                DataCell(
                                  Builder(
                                    builder: (context) {
                                      // Check current state from memory
                                      final currentClockInTime =
                                          clockInTimes[learnerId];
                                      final currentClockOutTime =
                                          clockOutTimes[learnerId];
                                      final hasCurrentClockIn =
                                          currentClockInTime != null &&
                                              currentClockInTime.isNotEmpty;
                                      final hasCurrentClockOut =
                                          currentClockOutTime != null &&
                                              currentClockOutTime.isNotEmpty;

                                      // Debug logging
                                      if (learnerId ==
                                          widget.learners.first['LearnerID']) {
                                        print(
                                            '[CLOCK_OUT_UI] LearnerID: $learnerId');
                                        print(
                                            '[CLOCK_OUT_UI] currentClockInTime: $currentClockInTime');
                                        print(
                                            '[CLOCK_OUT_UI] currentClockOutTime: $currentClockOutTime');
                                        print(
                                            '[CLOCK_OUT_UI] hasCurrentClockIn: $hasCurrentClockIn');
                                        print(
                                            '[CLOCK_OUT_UI] hasCurrentClockOut: $hasCurrentClockOut');
                                        print(
                                            '[CLOCK_OUT_UI] hasClocking: $hasClocking');
                                      }

                                      if (!hasCurrentClockIn) {
                                        // No clock-in yet - can't clock out
                                        return Text(
                                          hasClocking
                                              ? '-'
                                              : 'Never clocked in',
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontStyle: FontStyle.italic),
                                        );
                                      } else if (hasCurrentClockOut) {
                                        // Has clocked out - show time
                                        return Text(
                                          currentClockOutTime,
                                          style: const TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold),
                                        );
                                      } else {
                                        // Clocked in but not out - show clock out button
                                        print(
                                            '[CLOCK_OUT_UI] Showing Clock Out button for learner $learnerId');
                                        return Tooltip(
                                          message: 'Clock out learner',
                                          child: ElevatedButton(
                                            onPressed:
                                                _isClockingIn[learnerId] == true
                                                    ? null
                                                    : () => _verifyAndClockOut(
                                                        learnerId),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: const Text('Clock Out'),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                // Contact Time column
                                DataCell(
                                  Builder(
                                    builder: (context) {
                                      // Check current state from memory (redefine here for this scope)
                                      final currentClockInTime =
                                          clockInTimes[learnerId];
                                      final currentContactTime =
                                          contactTimes[learnerId];
                                      final hasCurrentClockIn =
                                          currentClockInTime != null &&
                                              currentClockInTime.isNotEmpty;
                                      final hasCurrentContact =
                                          currentContactTime != null &&
                                              currentContactTime.isNotEmpty;

                                      if (!hasCurrentClockIn) {
                                        // No clock-in - no contact time possible
                                        return Text(
                                          hasClocking ? '-' : 'No records',
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontStyle: FontStyle.italic),
                                        );
                                      } else if (hasCurrentContact) {
                                        // Has contact time - show it
                                        return Text(
                                          currentContactTime,
                                          style: const TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold),
                                        );
                                      } else {
                                        // Clocked in but no contact time yet
                                        return const Text('-',
                                            style:
                                                TextStyle(color: Colors.grey));
                                      }
                                    },
                                  ),
                                ),
                                // Sick Note column
                                DataCell(
                                  Tooltip(
                                    message:
                                        'Upload a sick note for this learner',
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SickNotePage(
                                              learnerID: int.parse(learnerId),
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[100],
                                      ),
                                      icon: const Icon(Icons.medical_services,
                                          size: 18),
                                      label: const Text('Sick Note'),
                                    ),
                                  ),
                                ),
                                // Action column: only Details button
                                DataCell(
                                  Tooltip(
                                    message: 'View learner details',
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => DetailsPage(
                                              learnerID: int.parse(learnerId),
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                      ),
                                      child: const Text('Details'),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  )
          ],
        ),
      ),
    );
  }
}
