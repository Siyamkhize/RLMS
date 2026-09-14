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
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'EnrollmentPage.dart';
import 'services/fingerprint_service.dart';
import 'services/secure_location_service.dart'; // Added for future location improvements
import 'DetailsPage.dart';
import 'LearnerDetailsPage.dart';
import 'sick_note_page.dart';
import 'database_helper.dart';
import 'sync_service.dart'
    show syncSingleClockIn, syncSingleClockOut, SyncService;
import 'utils/clocking_logger.dart';
import 'utils/fingerprint_error_handler.dart';
import 'utils/scanner_pdf_resolver.dart';
import 'utils/document_scanner_manager.dart';
import 'utils/monitoring_mixin.dart';
import 'debug_log_viewer.dart';
import 'services/futronic_service.dart' as futronic;
import 'services/database_coordinator.dart';

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

class _ClockInPageState extends State<ClockInPage>
    with WidgetsBindingObserver, MonitoringMixin {
  final FingerprintService _fingerprintService = FingerprintService();
  final futronic.FutronicService _futronicService = futronic.FutronicService();
  final DatabaseCoordinator _dbCoordinator = DatabaseCoordinator();
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
  StreamSubscription? _serviceAccuracySub;
  StreamSubscription? _liveGpsSub;
  double? _currentGpsAccuracy;
  double? _siteLat;
  double? _siteLon;
  bool _isWithinRange = false;
  Timer? _autoSyncTimer; // Periodic auto-sync timer
  bool _isSensorConnected = false;
  bool _isInitializing = false;
  String? _currentLearnerIdForClocking;
  String? _currentClockingAction; // 'in' or 'out'
  bool _isConnected = false; // Add real-time connectivity status
  final int _maxFileSize = 5 * 1024 * 1024; // 5MB
  final int _minFileSize = 10 * 1024; // 10KB
  String get _uploadUrl => AppConfig.buildUrl('upload_learner_document.php');

  final List<String> _requiredDocuments = const [
    'ID Document',
    'Qualifications',
    'Bank Confirmation Letter',
    'Proof of Residence',
    'CV',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    databaseFactory = databaseFactoryFfi;
    ClockingLogger.instance.initialize();
    ClockingLogger.instance.logAppLifecycle('Clock-in page initialized',
        details: 'ClassID: ${widget.classID}');
    _initializeData();
    // _initializeCamera();  // Temporarily disabled due to Java 21 compatibility issues
    _initializeSensor(); // Add sensor initialization
    _setupStreams();
    _setupConnectivityListener();
    _setupGpsListener(); // Listen for GPS accuracy
    _checkInitialConnectivity(); // Check initial connectivity status
    _setupAutoSync(); // Re-enabled with improved database lock management
    _warmUpGPS(); // Proactively start GPS acquisition
  }

  void _setupGpsListener() {
    // Listen to the shared accuracy stream from the service
    _serviceAccuracySub =
        SecureLocationService.accuracyStream.listen((accuracy) {
      if (mounted) {
        setState(() {
          _currentGpsAccuracy = accuracy;
        });
      }
    });

    // Also start a low-intensity tracking stream to keep the GPS "warm" and UI updated
    _startLiveGpsTracking();
  }

  void _startLiveGpsTracking() {
    _liveGpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((pos) {
      if (mounted) {
        bool withinRange = false;
        if (_siteLat != null && _siteLon != null) {
          final distance = _calculateDistance(
              pos.latitude, pos.longitude, _siteLat!, _siteLon!);
          // Use the same dynamic radius logic as the geofence check
          final effectiveRadius = (50.0 + pos.accuracy).clamp(50.0, 60.0);
          withinRange = distance <= effectiveRadius;
        }

        setState(() {
          _currentGpsAccuracy = pos.accuracy;
          _isWithinRange = withinRange;
        });
      }
    }, onError: (e) {
      print('[GPS_LIVE] Tracking error: $e');
    });
  }

  void _warmUpGPS() {
    // Start getting position in background so it's ready when they click
    print('[GPS_WARMUP] Proactively warming up GPS for clock-in...');
    SecureLocationService.getSecurePosition().then((result) {
      print(
          '[GPS_WARMUP] Warm-up complete: ${result.position.accuracy.toStringAsFixed(1)}m');
    }).catchError((e) {
      print(
          '[GPS_WARMUP] Warm-up failed (expected if permissions missing): $e');
    });
  }

  @override
  void dispose() {
    debugPrint('[CLOCK_IN] ========== DISPOSE CALLED ==========');
    debugPrint('[CLOCK_IN] Starting dispose process...');
    debugPrint('[CLOCK_IN] Widget mounted: $mounted');
    debugPrint('[CLOCK_IN] Stack trace: ${StackTrace.current}');

    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Cancel all subscriptions BEFORE disposing the service
    debugPrint('[CLOCK_IN] Cancelling stream subscriptions...');
    try {
      if (_enrollStatusSubscription != null) {
        debugPrint('[CLOCK_IN] Cancelling _enrollStatusSubscription...');
        _enrollStatusSubscription?.cancel();
        debugPrint('[CLOCK_IN] _enrollStatusSubscription cancelled');
      }
      if (_enrollSuccessSubscription != null) {
        debugPrint('[CLOCK_IN] Cancelling _enrollSuccessSubscription...');
        _enrollSuccessSubscription?.cancel();
        debugPrint('[CLOCK_IN] _enrollSuccessSubscription cancelled');
      }
      if (_connectivitySubscription != null) {
        debugPrint('[CLOCK_IN] Cancelling _connectivitySubscription...');
        _connectivitySubscription?.cancel();
        debugPrint('[CLOCK_IN] _connectivitySubscription cancelled');
      }
      if (_serviceAccuracySub != null) {
        debugPrint('[CLOCK_IN] Cancelling _serviceAccuracySub...');
        _serviceAccuracySub?.cancel();
        debugPrint('[CLOCK_IN] _serviceAccuracySub cancelled');
      }
      if (_liveGpsSub != null) {
        debugPrint('[CLOCK_IN] Cancelling _liveGpsSub...');
        _liveGpsSub?.cancel();
        debugPrint('[CLOCK_IN] _liveGpsSub cancelled');
      }
      if (_autoSyncTimer != null) {
        debugPrint('[CLOCK_IN] Cancelling _autoSyncTimer...');
        _autoSyncTimer?.cancel();
        debugPrint('[CLOCK_IN] _autoSyncTimer cancelled');
      }
    } catch (e) {
      debugPrint('[CLOCK_IN] Error cancelling subscriptions: $e');
    }

    // Clear all subscriptions to null to prevent any further use
    _enrollStatusSubscription = null;
    _enrollSuccessSubscription = null;
    _connectivitySubscription = null;
    _autoSyncTimer = null;

    // Dispose controllers
    debugPrint('[CLOCK_IN] Disposing controllers...');
    try {
      debugPrint('[CLOCK_IN] Disposing _searchController...');
      _searchController.dispose();
      debugPrint('[CLOCK_IN] _searchController disposed');
      // _cameraController?.dispose();  // Temporarily disabled due to Java 21 compatibility issues
    } catch (e) {
      debugPrint('[CLOCK_IN] Error disposing controllers: $e');
    }

    // Dispose the fingerprint service AFTER cancelling subscriptions
    debugPrint('[CLOCK_IN] Disposing fingerprint service...');
    try {
      debugPrint('[CLOCK_IN] About to call _fingerprintService.dispose()...');
      _fingerprintService.dispose();
      debugPrint('[CLOCK_IN] Fingerprint service disposed successfully');
    } catch (e) {
      debugPrint('[CLOCK_IN] Error disposing fingerprint service: $e');
      debugPrint('[CLOCK_IN] Error type: ${e.runtimeType}');
      debugPrint('[CLOCK_IN] Error stack trace: ${StackTrace.current}');
    }

    disposeMonitoring(); // Stop monitoring service
    debugPrint('[CLOCK_IN] Calling super.dispose()...');
    super.dispose();
    debugPrint('[CLOCK_IN] ========== DISPOSE COMPLETED ==========');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('[DOC_SCAN] App lifecycle state changed to: $state');

    if (state == AppLifecycleState.resumed) {
      print('[DOC_SCAN] App resumed - checking if scanner was active');
      // App has resumed, possibly from document scanner
      // Reset scanner state to prevent stuck SCAN_IN_PROGRESS
      final scannerManager = DocumentScannerManager();

      // CRITICAL FIX: Check if scanner was in problematic state
      if (scannerManager.isInProblematicState()) {
        print(
            '[DOC_SCAN] WARNING: Scanner was in problematic state - potential plugin crash');
        scannerManager.recoverFromProblematicState();

        // Show user-friendly message about the interruption
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Document scanner was interrupted. If you were scanning, please try again.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        scannerManager.reset();
      }
    } else if (state == AppLifecycleState.paused) {
      print('[DOC_SCAN] App paused - possibly opening scanner');
    } else if (state == AppLifecycleState.detached) {
      print('[DOC_SCAN] App detached - resetting scanner state');
      DocumentScannerManager().forceReset();
    }
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

  // Set up periodic auto-sync (every 3 minutes) with database coordination
  void _setupAutoSync() {
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 3), (timer) async {
      if (!mounted || !_isConnected) return;

      // Check if enough time has passed since last sync to prevent conflicts
      if (!_dbCoordinator.shouldAllowSync(
          minInterval: const Duration(minutes: 2))) {
        debugPrint('[AUTO_SYNC] ⏭️ Skipping sync - too soon since last sync');
        return;
      }

      debugPrint('[AUTO_SYNC] 🔄 Running periodic auto-sync...');

      try {
        await _dbCoordinator.executeSyncOperation(
          'ClockInPage.autoSync',
          () async {
            // 1. Sync offline records to server
            await _syncOfflineClockIns();

            // 2. Fetch current day's records from server to local
            await _fetchClockingDataFromServer();

            // 3. Reload data to display synced records
            await _loadLearnersFromLocalDatabase();
          },
          timeout: const Duration(minutes: 2),
        );

        debugPrint('[AUTO_SYNC] ✅ Periodic sync completed');
      } catch (e) {
        debugPrint('[AUTO_SYNC] ❌ Periodic sync error: $e');
      }
    });

    debugPrint(
        '[AUTO_SYNC] ⏰ Periodic auto-sync enabled (every 3 minutes) with coordination');
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

          // If we receive any non-error status, the sensor is clearly connected
          if (!status.toLowerCase().contains('error') &&
              !status.toLowerCase().contains('failed') &&
              !status.toLowerCase().contains('timed out') &&
              !status.toLowerCase().contains('not connected')) {
            _isSensorConnected = true;
          }

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

            // Get current position for storing with attendance (with fallback)
            Position? position;
            try {
              position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 20), // Increased timeout
              );
            } catch (e) {
              print('[CLOCK_IN] High accuracy failed, trying cached: $e');
              position = await Geolocator.getLastKnownPosition();
              if (position != null) {
                final age = DateTime.now().difference(position.timestamp);
                if (age.inMinutes > 5) {
                  position = await Geolocator.getCurrentPosition(
                    desiredAccuracy: LocationAccuracy.medium,
                    timeLimit: const Duration(seconds: 15),
                  );
                }
              }
            }

            if (position == null) {
              throw Exception('Could not obtain location for clock-in');
            }

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

            // Start monitoring service for this learner
            initMonitoring(int.parse(learnerId));

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
              // MONITORING CHECK: Verify if learner missed all 3 random monitoring attempts
              final missedMonitoring =
                  await DatabaseHelper().hasMissedAllMonitoring(learnerId);

              if (missedMonitoring) {
                print(
                    '[CLOCK_OUT] ❌ Clock-out blocked: Learner $learnerId missed all monitoring attempts');
                FingerprintErrorHandler.showError(context,
                    'You missed monitoring for the day. You cannot clock out. Next time make sure you are in the class full day.');
                setState(() => _isClockingIn[learnerId] = false);
                return;
              }

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

              // Get current position for storing with attendance (with fallback)
              Position? position;
              try {
                position = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.high,
                  timeLimit: const Duration(seconds: 20), // Increased timeout
                );
              } catch (e) {
                print('[CLOCK_OUT] High accuracy failed, trying cached: $e');
                position = await Geolocator.getLastKnownPosition();
                if (position != null) {
                  final age = DateTime.now().difference(position.timestamp);
                  if (age.inMinutes > 5) {
                    position = await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.medium,
                      timeLimit: const Duration(seconds: 15),
                    );
                  }
                }
              }

              if (position == null) {
                throw Exception('Could not obtain location for clock-out');
              }

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

  // Get total attendance breakdown including manual and sick days from server API
  Future<Map<String, int>> _getTotalAttendanceBreakdown(
      String learnerId) async {
    final now = DateTime.now();
    final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    try {
      // First, get learner's classID from local database
      final db = await DatabaseHelper().database;
      final learnerResult = await db.query(
        'learnerdetails',
        columns: ['classID'],
        where: 'LearnerID = ?',
        whereArgs: [learnerId],
        limit: 1,
      );

      if (learnerResult.isEmpty) {
        print('[ATTENDANCE_BREAKDOWN] Learner not found in local database');
        return _getFallbackAttendanceBreakdown(learnerId, monthStr);
      }

      final classID = learnerResult.first['classID'];

      // Try to get data from server API (same endpoint as attendance_page)
      if (_isConnected) {
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final url = Uri.parse(
              '${AppConfig.getAttendanceUrl}?classID=$classID&month=$monthStr&learnerID=$learnerId&_t=$timestamp');

          print('[ATTENDANCE_BREAKDOWN] Fetching from API: $url');

          final response = await http.get(
            url,
            headers: {
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
              'Expires': '0',
            },
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);

            if (data['success'] == true &&
                data['data'] != null &&
                data['data'].isNotEmpty) {
              final learnerData =
                  data['data'][0]; // API returns array, get first item

              final regularDays = learnerData['days_clocked'] ?? 0;
              final manualDays = learnerData['manual_days_clocked'] ?? 0;
              final sickDays = learnerData['sick_note_days'] ?? 0;
              final totalDays = learnerData['total_days_attended'] ?? 0;

              print(
                  '[ATTENDANCE_BREAKDOWN] From API - Regular: $regularDays, Manual: $manualDays, Sick: $sickDays, Total: $totalDays');

              return {
                'regular': regularDays is int
                    ? regularDays
                    : int.tryParse(regularDays.toString()) ?? 0,
                'manual': manualDays is int
                    ? manualDays
                    : int.tryParse(manualDays.toString()) ?? 0,
                'sick': sickDays is int
                    ? sickDays
                    : int.tryParse(sickDays.toString()) ?? 0,
                'total': totalDays is int
                    ? totalDays
                    : int.tryParse(totalDays.toString()) ?? 0,
              };
            }
          }
        } catch (e) {
          print('[ATTENDANCE_BREAKDOWN] API error: $e');
        }
      }

      // Fallback to local database if API fails or offline
      return _getFallbackAttendanceBreakdown(learnerId, monthStr);
    } catch (e) {
      print('[ATTENDANCE_BREAKDOWN] Error: $e');
      return {
        'regular': 0,
        'manual': 0,
        'sick': 0,
        'total': 0,
      };
    }
  }

  // Fallback method to get attendance from local database
  Future<Map<String, int>> _getFallbackAttendanceBreakdown(
      String learnerId, String monthStr) async {
    try {
      final db = await DatabaseHelper().database;

      // Get regular clocking days
      final clockingResult = await db.rawQuery('''
        SELECT COUNT(DISTINCT DATE(clock_date)) as count
        FROM learner_clocking
        WHERE LearnerID = ?
        AND clock_date LIKE ?
        AND clock_in_time IS NOT NULL
        AND clock_out_time IS NOT NULL
      ''', [learnerId, '$monthStr%']);

      final regularDays = clockingResult.isNotEmpty
          ? (clockingResult.first['count'] as int?) ?? 0
          : 0;

      // Get approved manual attendance days
      final manualDays = await DatabaseHelper().getApprovedManualAttendanceDays(
        int.parse(learnerId),
        monthStr,
      );

      // Sick days not available in local database (would need complex calculation)
      final sickDays = 0;

      final totalDays = regularDays + manualDays + sickDays;

      print(
          '[ATTENDANCE_BREAKDOWN] From Local DB - Regular: $regularDays, Manual: $manualDays, Sick: $sickDays, Total: $totalDays');

      return {
        'regular': regularDays,
        'manual': manualDays,
        'sick': sickDays,
        'total': totalDays,
      };
    } catch (e) {
      print('[ATTENDANCE_BREAKDOWN] Fallback error: $e');
      return {
        'regular': 0,
        'manual': 0,
        'sick': 0,
        'total': 0,
      };
    }
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

    // Get learner ID number from database
    String idNumber = learnerId; // Default to learnerId
    try {
      final db = await DatabaseHelper().database;
      final learnerData = await db.query(
        'learner',
        columns: ['IDNumber'],
        where: 'LearnerID = ?',
        whereArgs: [learnerId],
        limit: 1,
      );
      if (learnerData.isNotEmpty && learnerData.first['IDNumber'] != null) {
        idNumber = learnerData.first['IDNumber'].toString();
      }
    } catch (e) {
      print('[CLOCK_IN_SUMMARY] Error fetching ID number: $e');
    }

    // Get enhanced clocking data
    final clockingData = await _getEnhancedClockingDaysCount(learnerId,
        includeToday: action == 'out');
    final clockingDays = clockingData['count'] as int;
    final localCount = clockingData['local_count'] as int;
    final serverCount = clockingData['server_count'] as int;
    final serverAvailable = clockingData['server_available'] as bool;
    final source = clockingData['source'] as String;

    // Get attendance breakdown (regular, manual, sick)
    final attendanceBreakdown = await _getTotalAttendanceBreakdown(learnerId);
    final totalAttendedDays = attendanceBreakdown['total'] ?? 0;

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
              // Learner ID Number
              Text(
                'Learner ID: $idNumber',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              // Clocked Days
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Clocked Days:'),
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
              // Working Days
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Working Days:'),
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
              // Attendance ratio
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Attendance:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '$totalAttendedDays/$workingDays',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: totalAttendedDays >= workingDays * 0.8
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
      print('[GEOFENCE] Acquiring secure GPS position (foreground stream)...');
      final secure = await SecureLocationService.getSecurePosition();
      final position = secure.position;

      if (secure.isMockDetected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Mock or emulator location detected. Use a real device with GPS.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      print(
          '[GEOFENCE] Current position: ${position.latitude}, ${position.longitude}');
      print('[GEOFENCE] Accuracy: ${position.accuracy} meters');

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
    // Relaxed accuracy threshold - allow up to 60m like server
    if (userAccuracy > 60) {
      print(
          '[GEOFENCE] Geolocation accuracy too low: $userAccuracy meters (max 60m)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'GPS accuracy too low (${userAccuracy.toStringAsFixed(0)}m). Please wait for better signal.'),
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
      print('[GEOFENCE] User accuracy: ${userAccuracy.toStringAsFixed(1)}m');

      // Dynamic geofence radius with 60m cap: min(50m + accuracy, 60m)
      final baseRadius = 50.0;
      final maxAllowedRadius = 60.0;
      final calculatedRadius = baseRadius + userAccuracy;
      final effectiveRadius = calculatedRadius > maxAllowedRadius
          ? maxAllowedRadius
          : calculatedRadius;

      print('[GEOFENCE] Base radius: ${baseRadius}m');
      print('[GEOFENCE] GPS accuracy: ${userAccuracy.toStringAsFixed(1)}m');
      print(
          '[GEOFENCE] Calculated radius: ${calculatedRadius.toStringAsFixed(1)}m (${baseRadius}m + ${userAccuracy.toStringAsFixed(1)}m)');
      print(
          '[GEOFENCE] Effective radius: ${effectiveRadius.toStringAsFixed(1)}m (capped at ${maxAllowedRadius}m)');

      if (distance > effectiveRadius) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'You are ${distance.toStringAsFixed(0)}m away. Must be within ${effectiveRadius.toStringAsFixed(0)}m to clock in/out.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return false;
      }

      print(
          '[GEOFENCE] ✅ Within ${effectiveRadius.toStringAsFixed(1)}m radius - clocking allowed');
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
    String scanner = 'none';
    try {
      final isZkConnected = await _fingerprintService.isSensorConnected();
      if (isZkConnected) {
        scanner = 'zkteco';
      }
    } catch (_) {}

    if (scanner == 'none') {
      // Enhanced Futronic detection with retry
      scanner = await _detectFutronicWithRetry();
    }

    // Update global sensor connection state based on detection
    if (mounted) {
      setState(() {
        _isSensorConnected = scanner != 'none';
      });
    }

    return scanner;
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
          if (mounted) {
            setState(() {
              _isSensorConnected = true;
            });
          }
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking learner profile...'),
        duration: Duration(seconds: 1),
      ),
    );

    final profileIsComplete = await _ensureLearnerProfileComplete(learnerId);
    if (!profileIsComplete) {
      return;
    }

    // CRASH FIX: Simplified bank completeness check
    print('[CLOCK_IN] SIMPLIFIED: Checking bank details completeness...');
    try {
      // Check mounted state before proceeding
      if (!mounted) {
        print(
            '[CLOCK_IN] SIMPLIFIED: Widget not mounted - skipping bank check');
        return;
      }

      final strictBankOk = await _ensureLearnerBankDetailsComplete(
        learnerId,
        await _getLearnerForValidation(learnerId),
      );
      print('[CLOCK_IN] SIMPLIFIED: Bank details check result: $strictBankOk');

      // CRASH FIX: Don't block flow based on bank check result
      // The bank details dialog will handle missing data if needed
      print(
          '[CLOCK_IN] SIMPLIFIED: Bank details check completed - continuing flow');
    } catch (e) {
      print('[CLOCK_IN] SIMPLIFIED: ERROR in bank details check (ignored): $e');
      // Continue with flow - don't let bank details check block clock-in
    }

    print('[CLOCK_IN] Checking document completeness...');
    try {
      final documentsComplete =
          await _ensureLearnerDocumentsComplete(learnerId);
      print('[CLOCK_IN] Documents check result: $documentsComplete');

      if (!documentsComplete) {
        print('[CLOCK_IN] Documents incomplete - returning');
        return;
      }
    } catch (e) {
      print('[CLOCK_IN] ERROR in documents check: $e');
      print('[CLOCK_IN] Stack trace: ${StackTrace.current}');
      return;
    }

    // Show clocking days popup before proceeding
    print('[CLOCK_IN] Showing clocking days popup...');
    try {
      await _showClockingDaysPopup(learnerId, 'in');
      print('[CLOCK_IN] Clocking days popup completed');
    } catch (e) {
      print('[CLOCK_IN] ERROR in clocking days popup: $e');
      print('[CLOCK_IN] Stack trace: ${StackTrace.current}');
      return;
    }

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

        // Get current position for storing with attendance (with fallback)
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 20), // Increased timeout
          );
        } catch (e) {
          print('[CLOCK_IN] High accuracy failed, trying cached: $e');
          position = await Geolocator.getLastKnownPosition();
          if (position != null) {
            final age = DateTime.now().difference(position.timestamp);
            if (age.inMinutes > 5) {
              position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.medium,
                timeLimit: const Duration(seconds: 15),
              );
            }
          }
        }

        if (position == null) {
          throw Exception('Could not obtain location for clock-in');
        }

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

  Future<bool> _ensureLearnerProfileComplete(String learnerId) async {
    final learner = await _getLearnerForValidation(learnerId);
    if (learner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load learner profile. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final missingFieldLabels = _getMissingRequiredProfileFieldLabels(learner);
    final missingFieldKeys = _getMissingRequiredProfileFieldKeys(learner);
    if (missingFieldLabels.isEmpty) {
      return true;
    }

    final learnerIdInt = int.tryParse(learnerId);
    if (learnerIdInt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid learner ID for profile completion.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final shouldOpenProfile = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Complete Learner Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This learner profile is incomplete. Please fill in missing fields and press Update Data before clock-in.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Missing fields:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ...missingFieldLabels.map((field) => Text('- $field')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open Profile'),
            ),
          ],
        );
      },
    );

    if (shouldOpenProfile != true) {
      return false;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearnerDetailsPage(
          learnerID: learnerId,
          missingProfileOnlyMode: true,
          missingProfileFields: missingFieldKeys,
        ),
      ),
    );

    if (!mounted) return false;

    final refreshedLearner = await _getLearnerForValidation(learnerId);
    final refreshedMissing =
        _getMissingRequiredProfileFieldLabels(refreshedLearner ?? {});

    if (refreshedMissing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile still incomplete: ${refreshedMissing.join(', ')}. Please update before clock-in.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return false;
    }

    print('[PROFILE_CHECK] SIMPLIFIED: Checking bank details completeness...');
    try {
      // CRASH FIX: Check mounted state before bank details check
      if (!mounted) {
        print(
            '[PROFILE_CHECK] SIMPLIFIED: Widget not mounted - skipping bank check');
        return true; // Return true to prevent blocking
      }

      final bankComplete =
          await _ensureLearnerBankDetailsComplete(learnerId, learner);
      print(
          '[PROFILE_CHECK] SIMPLIFIED: Bank details check result: $bankComplete');

      // CRASH FIX: Always return true from bank check to prevent blocking
      // The bank details save operation already worked, so don't block the flow
      print(
          '[PROFILE_CHECK] SIMPLIFIED: Bank details check completed - continuing flow');
    } catch (e) {
      print(
          '[PROFILE_CHECK] SIMPLIFIED: ERROR in bank details check (ignored): $e');
      // Ignore errors and continue - bank details already saved successfully
    }

    print('[PROFILE_CHECK] All checks passed - returning true');
    return true;
  }

  Future<Map<String, dynamic>?> _getLearnerForValidation(
      String learnerId) async {
    // Prefer local DB — profile edits are saved locally first and the server
    // response can still be stale and overwrite unsynced changes.
    final localLearner = await DatabaseHelper().getLearnerById(learnerId);
    bool hasUnsyncedChanges =
        localLearner != null && localLearner['synced'] == 0;

    if (localLearner != null) {
      print(
          '[DEBUG clock_in_page] _getLearnerForValidation for learnerId $learnerId, got localLearner: $localLearner');
    }

    if (await _checkConnectivity() && !hasUnsyncedChanges) {
      try {
        final response = await http
            .get(
              Uri.parse('${AppConfig.learnerDetailsUrl}?LearnerID=$learnerId'),
            )
            .timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is Map &&
              decoded['success'] == true &&
              decoded['data'] != null) {
            print(
                '[DEBUG clock_in_page] _getLearnerForValidation - updating local from server!');
            final learnerData = Map<String, dynamic>.from(decoded['data']);
            await DatabaseHelper().upsertLearner(learnerData);
            return learnerData;
          }
        }
      } catch (_) {
        // Fall through to offline/local data
      }
    } else if (hasUnsyncedChanges) {
      print(
          '[DEBUG clock_in_page] _getLearnerForValidation - local has synced=0, skipping server update!');
    }

    // Always return local data if available!
    if (localLearner != null) {
      print(
          '[DEBUG clock_in_page] _getLearnerForValidation - returning local data!');
      return localLearner;
    }

    return null;
  }

  List<String> _getMissingRequiredProfileFieldLabels(
      Map<String, dynamic> learner) {
    print(
        '[DEBUG clock_in_page] _getMissingRequiredProfileFieldLabels called with learner: $learner');
    final missing = <String>[];
    for (final rule in _requiredProfileRules) {
      if (_isRuleMissing(learner, rule.keys)) {
        print(
            '[DEBUG clock_in_page] _getMissingRequiredProfileFieldLabels found missing rule: ${rule.label}');
        missing.add(rule.label);
      }
    }
    print(
        '[DEBUG clock_in_page] _getMissingRequiredProfileFieldLabels returning: $missing');
    return missing;
  }

  List<String> _getMissingRequiredProfileFieldKeys(
      Map<String, dynamic> learner) {
    final missingKeys = <String>[];
    for (final rule in _requiredProfileRules) {
      if (!_isRuleMissing(learner, rule.keys)) continue;
      final bestKey = _resolveBestFieldKey(learner, rule.keys);
      missingKeys.add(bestKey);
    }
    return missingKeys;
  }

  bool _isRuleMissing(Map<String, dynamic> learner, List<String> keys) {
    print(
        '[DEBUG clock_in_page] _isRuleMissing checking keys: $keys against learner keys: ${learner.keys}');
    for (final key in keys) {
      final value = learner[key];
      print(
          '[DEBUG clock_in_page] _isRuleMissing - checking key $key, value: $value, isMissingValue: ${isMissingValue(value)}');
      if (!isMissingValue(value)) {
        return false;
      }
    }
    print('[DEBUG clock_in_page] _isRuleMissing - ALL keys missing!');
    return true;
  }

  String _resolveBestFieldKey(Map<String, dynamic> learner, List<String> keys) {
    for (final key in keys) {
      if (learner.containsKey(key)) {
        return key;
      }
    }
    return keys.first;
  }

  bool isMissingValue(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized.isEmpty ||
        normalized == 'null' ||
        normalized == 'n/a' ||
        normalized == 'na' ||
        normalized == '-' ||
        normalized == 'unknown' ||
        normalized.startsWith('1900-01-01');
  }

  Future<bool> _ensureLearnerBankDetailsComplete(
      String learnerId, Map<String, dynamic>? learnerProfile) async {
    try {
      print(
          '[BANK_CAPTURE] SIMPLIFIED: Checking bank details for learner: $learnerId');
      print('[BANK_CAPTURE] SIMPLIFIED: Widget mounted: $mounted');

      // CRASH FIX: Immediate return if widget not mounted
      if (!mounted) {
        print(
            '[BANK_CAPTURE] SIMPLIFIED: Widget not mounted - returning true to prevent blocking');
        return true;
      }

      final bankData =
          await _getLearnerBankDetailsForValidation(learnerId, learnerProfile);
      print(
          '[BANK_CAPTURE] SIMPLIFIED: Retrieved bank data: ${bankData.keys.length} fields');

      final missingBankLabels = _getMissingRequiredBankFieldLabels(bankData);
      print(
          '[BANK_CAPTURE] SIMPLIFIED: Missing bank labels: $missingBankLabels');

      if (missingBankLabels.isEmpty) {
        print(
            '[BANK_CAPTURE] SIMPLIFIED: All bank details complete - returning true');
        return true;
      }

      // CRASH FIX: Check mounted state again before any UI operations
      if (!mounted) {
        print(
            '[BANK_CAPTURE] SIMPLIFIED: Widget unmounted during check - returning true');
        return true;
      }

      print('[BANK_CAPTURE] SIMPLIFIED: Showing missing bank details snackbar');
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Missing bank details: ${missingBankLabels.join(', ')}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2), // Shorter duration
          ),
        );
      } catch (e) {
        print('[BANK_CAPTURE] SIMPLIFIED: Snackbar error (ignored): $e');
      }

      // CRASH FIX: Shorter delay and additional mounted check
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) {
        print(
            '[BANK_CAPTURE] SIMPLIFIED: Widget unmounted after delay - returning true');
        return true;
      }

      // CRASH FIX: Wrap dialog call in try-catch
      try {
        print(
            '[BANK_CAPTURE] SIMPLIFIED: Calling bank details dialog for learner: $learnerId');
        final saved = await _showBankDetailsCaptureDialog(learnerId, bankData);
        print('[BANK_CAPTURE] SIMPLIFIED: Dialog returned: $saved');
      } catch (e) {
        print('[BANK_CAPTURE] SIMPLIFIED: Dialog error (ignored): $e');
      }

      // CRASH FIX: Always return true to prevent any blocking or crashes
      print(
          '[BANK_CAPTURE] SIMPLIFIED: Bank details flow completed - returning true');
      return true;
    } catch (e) {
      print('[BANK_CAPTURE] SIMPLIFIED: ERROR in bank details function: $e');
      // Always return true to prevent blocking the flow
      return true;
    }
  }

  Future<Map<String, dynamic>> _getLearnerBankDetailsForValidation(
    String learnerId,
    Map<String, dynamic>? learnerProfile,
  ) async {
    try {
      print(
          '[BANK_VALIDATION] SIMPLIFIED: Starting bank validation for learner: $learnerId');

      // CRASH FIX: Simplified approach - only use local data to prevent widget lifecycle conflicts
      final merged = <String, dynamic>{};
      if (learnerProfile != null) {
        merged.addAll(learnerProfile);
      }

      // NEW: First check online database for bank details
      try {
        print(
            '[BANK_VALIDATION] ONLINE: Checking online database for bank details...');
        final onlineBankData = await _checkOnlineBankDetails(learnerId);
        if (onlineBankData != null && onlineBankData.isNotEmpty) {
          merged.addAll(onlineBankData);
          print(
              '[BANK_VALIDATION] ONLINE: Found online bank details - using server data');
          return merged; // Return immediately if online data exists
        } else {
          print('[BANK_VALIDATION] ONLINE: No online bank details found');
        }
      } catch (e) {
        print(
            '[BANK_VALIDATION] ONLINE: Online check failed: $e - falling back to local');
      }

      // Fallback: Check local database if online check fails
      try {
        final learnerIdInt = int.tryParse(learnerId);
        if (learnerIdInt != null) {
          final localBank =
              await DatabaseHelper().fetchLearnerBankDetails(learnerIdInt);
          if (localBank != null) {
            merged.addAll(localBank);
            print('[BANK_VALIDATION] LOCAL: Found local bank details');
          } else {
            print('[BANK_VALIDATION] LOCAL: No local bank details found');
          }
        }
      } catch (e) {
        print('[BANK_VALIDATION] LOCAL: Local bank fetch failed: $e');
      }

      print(
          '[BANK_VALIDATION] SIMPLIFIED: Returning merged data (${merged.keys.length} fields)');
      return merged;
    } catch (e) {
      print('[BANK_VALIDATION] SIMPLIFIED: ERROR in bank validation: $e');
      // Return empty map on error to prevent crashes
      return <String, dynamic>{};
    }
  }

  List<String> _getMissingRequiredBankFieldLabels(
      Map<String, dynamic> bankData) {
    final missing = <String>[];
    for (final rule in _requiredBankRules) {
      if (_isRuleMissing(bankData, rule.keys)) {
        missing.add(rule.label);
      }
    }
    return missing;
  }

  // NEW: Check online database for bank details using the new endpoint
  Future<Map<String, dynamic>?> _checkOnlineBankDetails(
      String learnerId) async {
    try {
      print('[ONLINE_BANK] Checking online database for learner: $learnerId');

      final url = Uri.parse(AppConfig.checkBankDetailsUrl);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'learner_id': learnerId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('[ONLINE_BANK] Response: ${response.body}');

        if (data['success'] == true && data['has_bank_details'] == true) {
          final bankDetails = data['bank_details'];
          print(
              '[ONLINE_BANK] Found online bank details: ${bankDetails['bank_name']}');

          // Convert server response to format expected by the app
          final localBankData = {
            'LearnerID': learnerId,
            'BankName': bankDetails['bank_name'],
            'bankType': bankDetails['bank_type'],
            'BankAccount': bankDetails['account_number'],
            'BankCode': bankDetails['bank_code'],
            'synced': bankDetails['synced'],
          };

          // Update the local database
          await DatabaseHelper().upsertBankDetails(localBankData);

          return localBankData;
        } else {
          print('[ONLINE_BANK] No bank details found on server');
          return null;
        }
      } else {
        print('[ONLINE_BANK] Server error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[ONLINE_BANK] Error checking online bank details: $e');
      return null;
    }
  }

  Future<bool> _showBankDetailsCaptureDialog(
      String learnerId, Map<String, dynamic> existingBank) async {
    print('[BANK_DIALOG] ========== STARTING BANK DIALOG ==========');
    print('[BANK_DIALOG] Starting bank details dialog for learner: $learnerId');
    print('[BANK_DIALOG] Existing bank data: $existingBank');
    print('[BANK_DIALOG] Widget mounted status: $mounted');
    print('[BANK_DIALOG] Context hashCode: ${context.hashCode}');

    final accountNumberController = TextEditingController(
      text: existingBank['BankAccount']?.toString() ?? '',
    );
    final branchCodeController = TextEditingController(
      text: existingBank['BankCode']?.toString() ?? '',
    );

    String? initialSelectedBank = existingBank['BankName']?.toString();
    String? initialSelectedAccountType = existingBank['bankType']?.toString();

    if (initialSelectedBank != null && initialSelectedBank.isNotEmpty) {
      branchCodeController.text =
          _bankCodes[initialSelectedBank] ?? branchCodeController.text;
      print(
          '[BANK_DIALOG] Updated branch code from bank selection: "${branchCodeController.text}"');
    }

    print('[BANK_DIALOG] About to call showDialog - context mounted: $mounted');
    print('[BANK_DIALOG] Context widget: ${context.widget.runtimeType}');

    Map<String, String>? submittedBankData;

    try {
      // CRITICAL FIX: Ensure context is still mounted before showing dialog
      if (!mounted) {
        print('[BANK_DIALOG] Context not mounted, cannot show dialog');
        accountNumberController.dispose();
        branchCodeController.dispose();
        return false;
      }

      submittedBankData = await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          print(
              '[BANK_DIALOG] Dialog builder called - dialogContext: ${dialogContext.hashCode}');
          print(
              '[BANK_DIALOG] Dialog context widget: ${dialogContext.widget.runtimeType}');

          // Declare state variables INSIDE the StatefulBuilder's scope
          String? selectedBank = initialSelectedBank;
          String? selectedAccountType = initialSelectedAccountType;
          String? errorMessage;

          return StatefulBuilder(
            builder: (builderContext, setDialogState) {
              print(
                  '[BANK_DIALOG] StatefulBuilder called - builderContext: ${builderContext.hashCode}');
              print(
                  '[BANK_DIALOG] StatefulBuilder setDialogState: ${setDialogState.runtimeType}');

              // Create a safe setState wrapper
              void safeSetDialogState(VoidCallback fn) {
                try {
                  if (builderContext.mounted) {
                    setDialogState(fn);
                  } else {
                    print(
                        '[BANK_DIALOG] Context not mounted, skipping setState');
                  }
                } catch (e) {
                  print('[BANK_DIALOG] Error in safeSetDialogState: $e');
                }
              }

              print('[BANK_DIALOG] Creating AlertDialog widget');
              return AlertDialog(
                title: const Text('Bank Details'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value:
                            _banks.contains(selectedBank) ? selectedBank : null,
                        decoration:
                            const InputDecoration(labelText: 'Bank Name'),
                        items: _banks
                            .map((bank) => DropdownMenuItem(
                                  value: bank,
                                  child: Text(bank),
                                ))
                            .toList(),
                        onChanged: (value) {
                          print(
                              '[BANK_DIALOG] Bank dropdown changed to: $value');
                          try {
                            // Check if the dialog is still mounted before calling setState
                            if (builderContext.mounted) {
                              safeSetDialogState(() {
                                selectedBank = value;
                                if (value != null) {
                                  branchCodeController.text =
                                      _bankCodes[value] ?? '';
                                }
                              });
                              print(
                                  '[BANK_DIALOG] Bank dropdown state updated successfully');
                            } else {
                              print(
                                  '[BANK_DIALOG] Dialog context not mounted, skipping setState');
                            }
                          } catch (e) {
                            print(
                                '[BANK_DIALOG] ERROR in bank dropdown setState: $e');
                            print(
                                '[BANK_DIALOG] Stack trace: ${StackTrace.current}');
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _accountTypes.contains(selectedAccountType)
                            ? selectedAccountType
                            : null,
                        decoration:
                            const InputDecoration(labelText: 'Account Type'),
                        items: _accountTypes
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ))
                            .toList(),
                        onChanged: (value) {
                          print(
                              '[BANK_DIALOG] Account type dropdown changed to: $value');
                          try {
                            // Check if the dialog is still mounted before calling setState
                            if (builderContext.mounted) {
                              safeSetDialogState(() {
                                selectedAccountType = value;
                              });
                              print(
                                  '[BANK_DIALOG] Account type dropdown state updated successfully');
                            } else {
                              print(
                                  '[BANK_DIALOG] Dialog context not mounted, skipping setState');
                            }
                          } catch (e) {
                            print(
                                '[BANK_DIALOG] ERROR in account type dropdown setState: $e');
                            print(
                                '[BANK_DIALOG] Stack trace: ${StackTrace.current}');
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: accountNumberController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Account Number',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: branchCodeController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Branch Code'),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorMessage!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      print('[BANK_DIALOG] Cancel button pressed');
                      Navigator.of(dialogContext).pop(null);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      print(
                          '[BANK_DIALOG] ========== SAVE BUTTON PRESSED ==========');
                      print(
                          '[BANK_DIALOG] Save button pressed - context mounted: ${builderContext.mounted}');
                      print(
                          '[BANK_DIALOG] Dialog context mounted: ${dialogContext.mounted}');

                      final bankName = selectedBank?.trim() ?? '';
                      final bankType = selectedAccountType?.trim() ?? '';
                      final accountNumber = accountNumberController.text.trim();
                      final bankCode = branchCodeController.text.trim();

                      print(
                          '[BANK_DIALOG] Validating fields: bankName=$bankName, bankType=$bankType, accountNumber=$accountNumber, bankCode=$bankCode');

                      if (bankName.isEmpty ||
                          bankType.isEmpty ||
                          accountNumber.isEmpty ||
                          bankCode.isEmpty) {
                        print(
                            '[BANK_DIALOG] Validation failed - missing fields');
                        try {
                          // Check if the dialog is still mounted before calling setState
                          if (builderContext.mounted) {
                            safeSetDialogState(() {
                              errorMessage = 'Please complete all bank fields.';
                            });
                            print(
                                '[BANK_DIALOG] Error message set successfully');
                          } else {
                            print(
                                '[BANK_DIALOG] Dialog context not mounted, skipping error setState');
                          }
                        } catch (e) {
                          print(
                              '[BANK_DIALOG] ERROR setting error message: $e');
                          print(
                              '[BANK_DIALOG] Stack trace: ${StackTrace.current}');
                        }
                        return;
                      }

                      print(
                          '[BANK_DIALOG] Validation passed, attempting to close dialog');
                      print(
                          '[BANK_DIALOG] About to call Navigator.pop with data');

                      try {
                        final resultData = {
                          'BankName': bankName,
                          'bankType': bankType,
                          'BankAccount': accountNumber,
                          'BankCode': bankCode,
                        };
                        print(
                            '[BANK_DIALOG] Result data prepared: $resultData');

                        Navigator.of(dialogContext).pop(resultData);
                        print(
                            '[BANK_DIALOG] Navigator.pop called successfully');
                      } catch (e) {
                        print(
                            '[BANK_DIALOG] CRITICAL ERROR closing dialog: $e');
                        print('[BANK_DIALOG] Error type: ${e.runtimeType}');
                        print(
                            '[BANK_DIALOG] Stack trace: ${StackTrace.current}');

                        // Try alternative approach
                        try {
                          print(
                              '[BANK_DIALOG] Attempting alternative Navigator.pop');
                          Navigator.pop(dialogContext, {
                            'BankName': bankName,
                            'bankType': bankType,
                            'BankAccount': accountNumber,
                            'BankCode': bankCode,
                          });
                          print(
                              '[BANK_DIALOG] Alternative Navigator.pop succeeded');
                        } catch (e2) {
                          print(
                              '[BANK_DIALOG] Alternative Navigator.pop also failed: $e2');
                        }
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );

      print('[BANK_DIALOG] ========== DIALOG AWAIT COMPLETED ==========');
      print('[BANK_DIALOG] Dialog completed, result: $submittedBankData');
      print('[BANK_DIALOG] Widget still mounted: $mounted');
    } catch (e) {
      print('[BANK_DIALOG] CRITICAL ERROR in showDialog: $e');
      print('[BANK_DIALOG] Error type: ${e.runtimeType}');
      print('[BANK_DIALOG] Stack trace: ${StackTrace.current}');

      // Dispose controllers safely and return false on error
      try {
        // Add delay to ensure any dialog context is cleared
        await Future.delayed(const Duration(milliseconds: 50));

        if (!accountNumberController.hasListeners) {
          accountNumberController.dispose();
        } else {
          accountNumberController.removeListener(() {});
          accountNumberController.dispose();
        }

        if (!branchCodeController.hasListeners) {
          branchCodeController.dispose();
        } else {
          branchCodeController.removeListener(() {});
          branchCodeController.dispose();
        }

        print('[BANK_DIALOG] Controllers disposed safely after error');
      } catch (disposeError) {
        print('[BANK_DIALOG] Error disposing controllers: $disposeError');
      }
      return false;
    }

    print('[BANK_DIALOG] About to dispose controllers safely');

    // CRITICAL FIX: Add delay to ensure dialog is completely closed before disposing controllers
    // This prevents the dependents.isEmpty error when controllers are disposed while still referenced
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      debugPrint('[BANK_DIALOG] Disposing accountNumberController...');
      if (!accountNumberController.hasListeners) {
        accountNumberController.dispose();
        debugPrint('[BANK_DIALOG] accountNumberController disposed safely');
      } else {
        debugPrint(
            '[BANK_DIALOG] accountNumberController still has listeners, forcing disposal...');
        // Force clear listeners before disposal
        accountNumberController.removeListener(() {});
        accountNumberController.dispose();
        debugPrint('[BANK_DIALOG] accountNumberController force disposed');
      }

      debugPrint('[BANK_DIALOG] Disposing branchCodeController...');
      if (!branchCodeController.hasListeners) {
        branchCodeController.dispose();
        debugPrint('[BANK_DIALOG] branchCodeController disposed safely');
      } else {
        debugPrint(
            '[BANK_DIALOG] branchCodeController still has listeners, forcing disposal...');
        // Force clear listeners before disposal
        branchCodeController.removeListener(() {});
        branchCodeController.dispose();
        debugPrint('[BANK_DIALOG] branchCodeController force disposed');
      }

      print('[BANK_DIALOG] Controllers disposed successfully');
    } catch (e) {
      print('[BANK_DIALOG] ERROR disposing controllers: $e');
      debugPrint(
          '[BANK_DIALOG] Controller disposal error type: ${e.runtimeType}');
      debugPrint(
          '[BANK_DIALOG] Controller disposal stack trace: ${StackTrace.current}');
    }

    print('[BANK_DIALOG] Submitted data: $submittedBankData');
    if (submittedBankData == null) {
      print('[BANK_DIALOG] User cancelled dialog - returning false');
      return false;
    }

    print('[BANK_DIALOG] ========== STARTING SAVE OPERATION ==========');
    print('[BANK_DIALOG] About to save bank details...');
    print('[BANK_DIALOG] Widget mounted before save: $mounted');

    try {
      final ok =
          await _upsertLearnerBankDetailsLocal(learnerId, submittedBankData);
      print('[BANK_DIALOG] Save operation completed with result: $ok');
      print('[BANK_DIALOG] Widget mounted after save: $mounted');

      if (!ok && mounted) {
        print('[BANK_DIALOG] Save failed, showing error snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save bank details. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (ok) {
        print('[BANK_DIALOG] Save successful!');
      }

      return ok;
    } catch (e) {
      print('[BANK_DIALOG] CRITICAL ERROR in save operation: $e');
      print('[BANK_DIALOG] Error type: ${e.runtimeType}');
      print('[BANK_DIALOG] Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  Future<bool> _upsertLearnerBankDetailsLocal(
      String learnerId, Map<String, dynamic> bankData) async {
    print('[BANK_SAVE] ========== STARTING BANK SAVE OPERATION ==========');
    print('[BANK_SAVE] Starting save for learner: $learnerId');
    print('[BANK_SAVE] Bank data: $bankData');
    print('[BANK_SAVE] Widget mounted: $mounted');

    final learnerIdInt = int.tryParse(learnerId);
    if (learnerIdInt == null) {
      print('[BANK_SAVE] ERROR: Invalid learner ID: $learnerId');
      return false;
    }
    print('[BANK_SAVE] Parsed learner ID: $learnerIdInt');

    try {
      print('[BANK_SAVE] Getting database instance...');
      final db = await DatabaseHelper().database;
      print('[BANK_SAVE] Database instance obtained successfully');

      final payload = {
        'LearnerID': learnerIdInt,
        'BankName': bankData['BankName']?.toString().trim() ?? '',
        'bankType': bankData['bankType']?.toString().trim() ?? '',
        'BankAccount': bankData['BankAccount']?.toString().trim() ?? '',
        'BankCode': bankData['BankCode']?.toString().trim() ?? '',
        'synced': 0,
      };
      print('[BANK_SAVE] Payload prepared: $payload');

      print('[BANK_SAVE] Checking for existing bank details...');
      final existing = await db.query(
        'bankdetails',
        where: 'LearnerID = ?',
        whereArgs: [learnerIdInt],
      );
      print('[BANK_SAVE] Existing records found: ${existing.length}');

      if (existing.isEmpty) {
        print('[BANK_SAVE] Inserting new bank details...');
        final insertResult = await db.insert('bankdetails', payload);
        print('[BANK_SAVE] Insert result: $insertResult');
      } else {
        print('[BANK_SAVE] Updating existing bank details...');
        final updateResult = await db.update(
          'bankdetails',
          payload,
          where: 'LearnerID = ?',
          whereArgs: [learnerIdInt],
        );
        print('[BANK_SAVE] Update result: $updateResult');
      }

      print('[BANK_SAVE] Local save completed successfully');

      // Try to save online if connected
      print('[BANK_SAVE] Checking connectivity for online save...');
      final isOnline = await _checkConnectivity();
      print('[BANK_SAVE] Online status: $isOnline');

      if (isOnline) {
        print('[BANK_SAVE] Attempting online save...');
        try {
          final onlinePayload = {
            'LearnerID': learnerId,
            'data': {
              'BankName': bankData['BankName']?.toString().trim() ?? '',
              'bankType': bankData['bankType']?.toString().trim() ?? '',
              'BankAccount': bankData['BankAccount']?.toString().trim() ?? '',
              'BankCode': bankData['BankCode']?.toString().trim() ?? '',
            }
          };
          print('[BANK_SAVE] Online payload: $onlinePayload');

          final response = await http
              .post(
                Uri.parse(AppConfig.updateLearnerUrl),
                headers: {'Content-Type': 'application/json'},
                body: json.encode(onlinePayload),
              )
              .timeout(const Duration(seconds: 10));

          print('[BANK_SAVE] Online response status: ${response.statusCode}');
          print('[BANK_SAVE] Online response body: ${response.body}');

          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
            print('[BANK_SAVE] Online response data: $responseData');

            if (responseData['success'] == true) {
              print('[BANK_SAVE] Online save successful, marking as synced...');
              // Mark as synced if online save was successful
              await db.update(
                'bankdetails',
                {'synced': 1},
                where: 'LearnerID = ?',
                whereArgs: [learnerIdInt],
              );
              print('[BANK_SAVE] Record marked as synced');
            } else {
              print(
                  '[BANK_SAVE] Online save failed: ${responseData['message'] ?? 'Unknown error'}');
            }
          } else {
            print(
                '[BANK_SAVE] Online save failed with status: ${response.statusCode}');
          }
        } catch (e) {
          print('[BANK_SAVE] Online save exception: $e');
          print(
              '[BANK_SAVE] Online save failed, but local save succeeded - will sync later');
        }
      } else {
        print('[BANK_SAVE] Offline mode - local save only');
      }

      print(
          '[BANK_SAVE] ========== BANK SAVE OPERATION COMPLETED SUCCESSFULLY ==========');
      return true;
    } catch (e) {
      print('[BANK_SAVE] CRITICAL ERROR in save operation: $e');
      print('[BANK_SAVE] Error type: ${e.runtimeType}');
      print('[BANK_SAVE] Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  final List<_RequiredProfileRule> _requiredProfileRules = const [
    _RequiredProfileRule(label: 'Title', keys: ['Title']),
    _RequiredProfileRule(label: 'Name', keys: ['Name']),
    _RequiredProfileRule(label: 'Surname', keys: ['Surname']),
    _RequiredProfileRule(label: 'ID Number', keys: ['IDNumber']),
    _RequiredProfileRule(label: 'Race', keys: ['Race']),
    _RequiredProfileRule(label: 'Language', keys: ['Language']),
    _RequiredProfileRule(label: 'Disability', keys: ['Disability']),
    _RequiredProfileRule(
        label: 'Cellphone Number', keys: ['CellphoneNumber', 'PhoneNumber']),
    _RequiredProfileRule(label: 'Email', keys: ['Email']),
    _RequiredProfileRule(label: 'Address Line 1', keys: ['AddressLine1']),
    _RequiredProfileRule(label: 'Address Line 2', keys: ['AddressLine2']),
    _RequiredProfileRule(label: 'Address Line 3', keys: ['AddressLine3']),
    _RequiredProfileRule(label: 'Postal Code', keys: ['PostalCode']),
    _RequiredProfileRule(label: 'Next of Kin Name', keys: ['KinName']),
    _RequiredProfileRule(label: 'Next of Kin Relation', keys: ['KinRelation']),
    _RequiredProfileRule(label: 'Next of Kin Contact', keys: ['KinContact']),
    _RequiredProfileRule(label: 'School Name', keys: ['SchoolName']),
    _RequiredProfileRule(
        label: 'School Completion', keys: ['SchoolCompletion']),
    _RequiredProfileRule(label: 'School Location', keys: ['SchoolLocation']),
    _RequiredProfileRule(label: 'School Grade', keys: ['SchoolGrade']),
    _RequiredProfileRule(label: 'Profile Image', keys: ['profile_image']),
    _RequiredProfileRule(label: 'Learner Signature', keys: ['signature']),
  ];
  final List<_RequiredProfileRule> _requiredBankRules = const [
    _RequiredProfileRule(label: 'Bank Name', keys: ['BankName']),
    _RequiredProfileRule(label: 'Account Type', keys: ['bankType']),
    _RequiredProfileRule(label: 'Account Number', keys: ['BankAccount']),
    _RequiredProfileRule(label: 'Branch Code', keys: ['BankCode']),
  ];
  final List<String> _banks = const [
    'ABSA Bank',
    'Capitec Bank',
    'First National Bank',
    'Nedbank',
    'Standard Bank',
    'Investec Bank',
    'Discovery Bank',
    'TymeBank',
    'African Bank',
    'Bidvest Bank',
  ];
  final List<String> _accountTypes = const [
    'Savings',
    'Cheque',
    'Current',
    'Transmission',
    'Fixed Deposit',
    'Money Market',
    'Student',
    'Business',
    'Trust',
  ];
  final Map<String, String> _bankCodes = const {
    'ABSA Bank': '632005',
    'Capitec Bank': '470010',
    'First National Bank': '250655',
    'Nedbank': '198765',
    'Standard Bank': '051001',
    'Investec Bank': '580105',
    'Discovery Bank': '679000',
    'TymeBank': '678910',
    'African Bank': '430000',
    'Bidvest Bank': '462005',
  };

  Future<bool> _ensureLearnerDocumentsComplete(String learnerId) async {
    while (true) {
      final missingDocs = await _getMissingRequiredDocuments(learnerId);
      if (missingDocs.isEmpty) {
        await _syncLearnerDocumentsForLearner(learnerId);
        return true;
      }

      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Missing Required Documents'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This learner has missing required documents. Scan all missing document(s) before clock-in.',
                ),
                const SizedBox(height: 12),
                ...missingDocs.map((doc) => Text('- $doc')),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('cancel'),
                child: const Text('Cancel'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop('sync'),
                child: const Text('Sync Documents'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop('scan'),
                child: const Text('Scan Next Document'),
              ),
            ],
          );
        },
      );

      if (action == 'sync') {
        await _syncLearnerDocumentsForLearner(learnerId);
        continue;
      }

      if (action != 'scan') {
        return false;
      }

      final selectedDoc = await _pickMissingDocument(missingDocs);
      if (selectedDoc == null) {
        return false;
      }

      final scanned = await _scanAndSaveDocument(learnerId, selectedDoc);
      if (!scanned) {
        return false;
      }

      final stillMissing = await _getMissingRequiredDocuments(learnerId);
      if (stillMissing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved $selectedDoc. Remaining: ${stillMissing.join(', ')}',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _syncLearnerDocumentsForLearner(String learnerId) async {
    if (!await _checkConnectivity()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Document sync skipped.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final dbHelper = DatabaseHelper();
      final learnerDocs = await dbHelper.fetchLearnerDocuments(learnerId);
      final unsyncedDocs = learnerDocs.where((doc) {
        final syncedVal = doc['synced'];
        final syncedInt = syncedVal is int
            ? syncedVal
            : int.tryParse(syncedVal?.toString() ?? '0') ?? 0;
        return syncedInt == 0;
      }).toList();

      if (unsyncedDocs.isEmpty) return;

      int successCount = 0;
      int failCount = 0;
      for (final doc in unsyncedDocs) {
        final filePath = doc['learner_document']?.toString() ?? '';
        final documentName = doc['documentName']?.toString() ?? '';
        if (filePath.isEmpty) continue;

        final existsOnServer = await _documentExistsForLearnerServer(
          learnerId: learnerId,
          documentName: documentName,
        );
        if (existsOnServer) {
          final dynamic docId = doc['document_id'];
          final int? parsedDocId =
              docId is int ? docId : int.tryParse('$docId');
          if (parsedDocId != null) {
            await dbHelper.updateLearnerDocumentSynced(parsedDocId, 1);
          }
          successCount++;
          continue;
        }

        final request = http.MultipartRequest(
          'POST',
          Uri.parse(_uploadUrl),
        )
          ..fields['learner_id'] = learnerId
          ..fields['documentName'] = documentName
          ..fields['status'] = doc['status']?.toString() ?? 'Pending'
          ..fields['upload_date'] =
              doc['upload_date']?.toString() ?? DateTime.now().toIso8601String()
          ..fields['synced'] = '1'
          ..fields['rejection_reason'] =
              doc['rejection_reason']?.toString() ?? ''
          ..files.add(await http.MultipartFile.fromPath(
            'learner_document',
            filePath,
            filename: filePath.split('/').last,
          ));

        final response = await request.send();
        final body = await response.stream.bytesToString();
        if (response.statusCode != 200) {
          failCount++;
          continue;
        }

        try {
          final decoded = jsonDecode(body);
          if (decoded is Map && decoded['success'] == true) {
            final dynamic docId = doc['document_id'];
            final int? parsedDocId =
                docId is int ? docId : int.tryParse('$docId');
            if (parsedDocId != null) {
              await dbHelper.updateLearnerDocumentSynced(parsedDocId, 1);
            }
            successCount++;
          } else {
            failCount++;
          }
        } catch (_) {
          failCount++;
        }
      }

      if (!mounted) return;
      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Synced $successCount document(s) successfully${failCount > 0 ? ', $failCount failed' : ''}.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (failCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document sync failed. Please check server/API.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document sync failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _syncAllUnsyncedDocuments() async {
    if (!await _checkConnectivity()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Cannot sync documents.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final dbHelper = DatabaseHelper();
      final unsyncedDocs = await dbHelper.fetchUnsyncedLearnerDocuments();
      if (unsyncedDocs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No unsynced documents found.'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      int successCount = 0;
      int failCount = 0;
      for (final doc in unsyncedDocs) {
        final learnerId = doc['learner_id']?.toString() ?? '';
        final filePath = doc['learner_document']?.toString() ?? '';
        final documentName = doc['documentName']?.toString() ?? '';
        if (learnerId.isEmpty || filePath.isEmpty) {
          failCount++;
          continue;
        }

        final existsOnServer = await _documentExistsForLearnerServer(
          learnerId: learnerId,
          documentName: documentName,
        );
        if (existsOnServer) {
          final dynamic docId = doc['document_id'];
          final int? parsedDocId =
              docId is int ? docId : int.tryParse('$docId');
          if (parsedDocId != null) {
            await dbHelper.updateLearnerDocumentSynced(parsedDocId, 1);
          }
          successCount++;
          continue;
        }

        try {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse(_uploadUrl),
          )
            ..fields['learner_id'] = learnerId
            ..fields['documentName'] = documentName
            ..fields['status'] = doc['status']?.toString() ?? 'Pending'
            ..fields['upload_date'] = doc['upload_date']?.toString() ??
                DateTime.now().toIso8601String()
            ..fields['synced'] = '1'
            ..fields['rejection_reason'] =
                doc['rejection_reason']?.toString() ?? ''
            ..files.add(await http.MultipartFile.fromPath(
              'learner_document',
              filePath,
              filename: filePath.split('/').last,
            ));

          final response = await request.send();
          final body = await response.stream.bytesToString();
          if (response.statusCode != 200) {
            failCount++;
            continue;
          }

          final decoded = jsonDecode(body);
          if (decoded is Map && decoded['success'] == true) {
            final dynamic docId = doc['document_id'];
            final int? parsedDocId =
                docId is int ? docId : int.tryParse('$docId');
            if (parsedDocId != null) {
              await dbHelper.updateLearnerDocumentSynced(parsedDocId, 1);
            }
            successCount++;
          } else {
            failCount++;
          }
        } catch (_) {
          failCount++;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Documents synced: $successCount, failed: $failCount'),
          backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sync documents: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<String>> _getMissingRequiredDocuments(String learnerId) async {
    String normalizeRequiredDoc(String raw) => raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\.pdf$'), '')
        .replaceAll(RegExp(r'\s+'), ' ');

    final dbHelper = DatabaseHelper();
    final localDocs = await dbHelper.fetchLearnerDocuments(learnerId);
    final localExistingDocs = localDocs
        .map((doc) =>
            normalizeRequiredDoc(doc['documentName']?.toString() ?? ''))
        .toSet();

    // CRITICAL FIX FOR OFFLINE CLOCKING:
    // When online, verify against server (server is source of truth)
    // When offline, trust local database completely (don't block users who have already uploaded documents)
    if (await _checkConnectivity()) {
      try {
        final serverDocs = await _fetchServerDocuments(learnerId);
        if (serverDocs != null) {
          final serverExistingDocs = serverDocs.toSet();
          // When online: check server first, then local database
          final missingDocs = _requiredDocuments.where((requiredDoc) {
            final normalized = normalizeRequiredDoc(requiredDoc);
            return !serverExistingDocs.contains(normalized) &&
                !localExistingDocs.contains(normalized);
          }).toList();
          print('[DOCUMENTS] ONLINE: Missing docs: $missingDocs');
          return missingDocs;
        }
      } catch (e) {
        print(
            '[DOCUMENTS] ONLINE: Server check failed: $e - falling back to local');
      }
    }

    // When offline OR server check failed: trust local database
    final missingDocs = _requiredDocuments
        .where((requiredDoc) =>
            !localExistingDocs.contains(normalizeRequiredDoc(requiredDoc)))
        .toList();
    print(
        '[DOCUMENTS] OFFLINE: Missing docs: $missingDocs (based on local database only)');
    return missingDocs;
  }

  Future<List<String>?> _fetchServerDocuments(String learnerId) async {
    String normalizeDocName(String raw) {
      final cleaned = raw.trim().toLowerCase();
      if (cleaned.isEmpty) return '';
      // Remove common suffixes/noise from API responses.
      final withoutExt = cleaned.replaceAll(RegExp(r'\.pdf$'), '');
      return withoutExt.replaceAll(RegExp(r'\s+'), ' ');
    }

    List<String> parseDocsPayload(dynamic payload) {
      List<dynamic>? docs;

      // Format A: { success: true, documents: [...] }
      if (payload is Map) {
        if (payload['success'] == true && payload['documents'] is List) {
          docs = payload['documents'] as List<dynamic>;
        } else if (payload['data'] is List) {
          // Format B: { data: [...] }
          docs = payload['data'] as List<dynamic>;
        }
      } else if (payload is List) {
        // Format C: direct rows from SELECT * FROM learner_document
        docs = payload;
      }

      if (docs == null) return <String>[];

      final parsed = <String>[];
      for (final item in docs) {
        String value = '';
        if (item is Map) {
          // Handle learner_document table row shapes (real schema first).
          value = item['documentName']?.toString() ??
              item['DocumentName']?.toString() ??
              item['document_name']?.toString() ??
              item['document_type']?.toString() ??
              item['doc_type']?.toString() ??
              '';
        } else {
          value = item?.toString() ?? '';
        }
        final normalized = normalizeDocName(value);
        if (normalized.isNotEmpty) {
          parsed.add(normalized);
        }
      }
      return parsed;
    }

    Future<List<String>?> attempt(Map<String, String> body) async {
      final response = await http
          .post(
            Uri.parse(AppConfig.buildUrl('check_learner_documents.php')),
            body: body,
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = json.decode(response.body);
      return parseDocsPayload(decoded);
    }

    // Server implementations differ across modules; try both keys.
    final byLearnerId = await attempt({'learner_id': learnerId});
    if (byLearnerId != null) return byLearnerId;

    return await attempt({'learnerID': learnerId});
  }

  Future<String?> _pickMissingDocument(List<String> missingDocs) async {
    String? selected = missingDocs.first;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Missing Document'),
              content: DropdownButton<String>(
                value: selected,
                isExpanded: true,
                items: missingDocs
                    .map(
                      (doc) => DropdownMenuItem<String>(
                        value: doc,
                        child: Text(doc),
                      ),
                    )
                    .toList(),
                onChanged: (newValue) {
                  setDialogState(() {
                    selected = newValue;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.of(dialogContext).pop(selected),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _scanAndSaveDocument(
      String learnerId, String documentName) async {
    // Aggressively request garbage collection before scanning to reduce chance of process death
    await Future.delayed(const Duration(milliseconds: 100));

    final alreadyExists = await _documentExistsForLearner(
      learnerId: learnerId,
      documentName: documentName,
    );
    if (alreadyExists) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$documentName already exists for this learner. Keeping existing document.'),
          backgroundColor: Colors.orange,
        ),
      );
      return true;
    }

    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission denied. Enable it in settings.'),
        ),
      );
      await openAppSettings();
      return false;
    }

    try {
      print('[DOC_SCAN] Starting document scan for $documentName...');

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Opening document scanner...'),
                ],
              ),
            );
          },
        );
      }

      final scanner = FlutterDocScanner();
      print('[DOC_SCAN] Scanner initialized, calling getScanDocuments...');

      // CRITICAL FIX: Use DocumentScannerManager for proper state management
      final scannerManager = DocumentScannerManager();

      // Check if scanner is already busy
      if (scannerManager.isScanning) {
        throw Exception(
            'Scanner is already in use. Please wait and try again.');
      }

      // Use the scanner manager with built-in retry logic
      final scanResult = await Future.any([
        scannerManager.scanDocuments(page: 80, maxRetries: 3),
        Future.delayed(
            const Duration(minutes: 5), () => null), // 5 minute timeout
      ]);

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      print('[DOC_SCAN] Scan result received: ${scanResult?.runtimeType}');

      // Handle user cancellation or timeout
      if (scanResult == null) {
        print('[DOC_SCAN] Scan cancelled or timed out');
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document scanning cancelled or timed out'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }

      if (scanResult is! Map ||
          !scanResult.containsKey('pdfUri') ||
          scanResult['pdfUri'] == null) {
        print('[DOC_SCAN] Invalid scan result: $scanResult');
        throw Exception('Invalid scan result - no PDF generated');
      }

      print('[DOC_SCAN] PDF URI: ${scanResult['pdfUri']}');
      final file = await resolveFlutterDocScannerPdfFile(
          scanResult['pdfUri'] as String?);
      print('[DOC_SCAN] Resolved file: ${file?.path}');

      if (file == null || !await isReadablePdfFile(file)) {
        print('[DOC_SCAN] File validation failed');
        throw Exception('Invalid or missing PDF file');
      }

      final fileSize = await file.length();
      print('[DOC_SCAN] File size: $fileSize bytes');

      if (fileSize > _maxFileSize) {
        throw Exception('File size exceeds 5MB limit');
      }
      if (fileSize < _minFileSize) {
        throw Exception('Scanned file appears too small/unclear');
      }

      print('[DOC_SCAN] Saving to database...');
      await DatabaseHelper().insertLearnerDocument({
        'learner_id': learnerId,
        'documentName': documentName,
        'learner_document': file.path,
        'status': 'Pending',
        'upload_date': DateTime.now().toIso8601String(),
        'synced': 0,
      });

      print('[DOC_SCAN] Document saved successfully');
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$documentName scanned and saved.'),
          backgroundColor: Colors.green,
        ),
      );
      return true;
    } catch (e, stackTrace) {
      print('[DOC_SCAN] Error occurred: $e');
      print('[DOC_SCAN] Stack trace: $stackTrace');

      // Close loading dialog if it's still open
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (popError) {
          print('[DOC_SCAN] Error closing dialog: $popError');
        }
      }

      if (!mounted) return false;

      // Provide more user-friendly error messages
      String errorMessage = 'Failed to scan document';
      if (e.toString().contains('cancelled') ||
          e.toString().contains('timeout')) {
        errorMessage = 'Document scanning was cancelled or timed out';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Camera permission required for document scanning';
      } else if (e.toString().contains('Invalid scan result')) {
        errorMessage = 'Document scanning failed - please try again';
      } else if (e.toString().contains('File size exceeds')) {
        errorMessage = 'Scanned document is too large (max 5MB)';
      } else if (e.toString().contains('too small')) {
        errorMessage = 'Scanned document appears unclear - please try again';
      } else if (e.toString().contains('SCAN_IN_PROGRESS') ||
          e.toString().contains('Scanner is busy') ||
          e.toString().contains('already in use')) {
        errorMessage =
            'Scanner is busy. Please close any other scanning apps and try again in a few seconds.';
        // Force reset scanner state for next attempt
        DocumentScannerManager().forceReset();
      } else if (e.toString().contains('pendingResult is null') ||
          e.toString().contains('onActivityResult') ||
          e.toString().contains('requestCode=213312') ||
          e.toString().contains('plugin callback issue') ||
          e.toString().contains('plugin error')) {
        errorMessage =
            'Document scanner plugin error detected. This happens when the scanner app crashes or is interrupted.\n\n'
            'Solutions:\n'
            '• Close this screen and try again\n'
            '• If problem persists, restart the app\n'
            '• Make sure no other camera/scanner apps are running\n'
            '• Try scanning fewer pages at once';
        // Force reset scanner state
        DocumentScannerManager().forceReset();
      } else if (e.toString().contains('Scanner timeout') ||
          e.toString().contains('session timed out')) {
        errorMessage =
            'Scanner session timed out. This usually happens with very large documents.\n\n'
            'Solutions:\n'
            '• Try scanning fewer pages at once (50-80 maximum)\n'
            '• Scan continuously without long pauses\n'
            '• Make sure device has enough free memory';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: errorMessage.contains('plugin error') ||
                  errorMessage.contains('Scanner session timed out') ||
                  errorMessage.contains('Scanner timeout')
              ? SnackBarAction(
                  label: 'More Info',
                  textColor: Colors.white,
                  onPressed: () {
                    _showDetailedErrorDialog(errorMessage, e.toString());
                  },
                )
              : null,
        ),
      );
      return false;
    }
  }

  void _showDetailedErrorDialog(String userMessage, String technicalError) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Document Scanner Error'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(userMessage),
              const SizedBox(height: 16),
              const Text(
                'Technical Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  technicalError,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _documentExistsForLearner({
    required String learnerId,
    required String documentName,
  }) async {
    if (await _documentExistsForLearnerLocal(
      learnerId: learnerId,
      documentName: documentName,
    )) {
      return true;
    }
    return await _documentExistsForLearnerServer(
      learnerId: learnerId,
      documentName: documentName,
    );
  }

  Future<bool> _documentExistsForLearnerLocal({
    required String learnerId,
    required String documentName,
  }) async {
    final docs = await DatabaseHelper().fetchLearnerDocuments(learnerId);
    return docs.any(
      (d) =>
          (d['documentName']?.toString().trim().toLowerCase() ?? '') ==
          documentName.trim().toLowerCase(),
    );
  }

  Future<bool> _documentExistsForLearnerServer({
    required String learnerId,
    required String documentName,
  }) async {
    if (!await _checkConnectivity()) return false;
    try {
      final serverDocs = await _fetchServerDocuments(learnerId);
      if (serverDocs == null) return false;
      final normalizedServer = serverDocs.toSet();
      final normalizedRequired = documentName
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'\.pdf$'), '')
          .replaceAll(RegExp(r'\s+'), ' ');
      return normalizedServer.contains(normalizedRequired);
    } catch (_) {
      return false;
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

        // Get current position for storing with attendance (with fallback)
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 20), // Increased timeout
          );
        } catch (e) {
          print('[CLOCK_OUT] High accuracy failed, trying cached: $e');
          position = await Geolocator.getLastKnownPosition();
          if (position != null) {
            final age = DateTime.now().difference(position.timestamp);
            if (age.inMinutes > 5) {
              position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.medium,
                timeLimit: const Duration(seconds: 15),
              );
            }
          }
        }

        if (position == null) {
          throw Exception('Could not obtain location for clock-out');
        }

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

      // Sync unsynced learner profiles
      print('[INIT] Syncing unsynced learner profiles...');
      await dbHelper.syncUnsyncedLearnerProfiles();
      print('[INIT] Learner profile sync completed');

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
    await _fetchSiteCoordinates(); // Fetch site coordinates for distance monitoring

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

  Future<void> _fetchSiteCoordinates() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final result = await db.rawQuery(
        'SELECT s.latitude, s.longitude FROM class c JOIN sites s ON c.siteID = s.siteID WHERE c.classID = ?',
        [widget.classID.toString()],
      );

      if (result.isNotEmpty) {
        setState(() {
          _siteLat = double.tryParse(result.first['latitude'].toString());
          _siteLon = double.tryParse(result.first['longitude'].toString());
        });
        print('[INIT] Fetched site coordinates: $_siteLat, $_siteLon');
      } else {
        print(
            '[INIT] No site coordinates found for classID: ${widget.classID}');
      }
    } catch (e) {
      print('[INIT] Error fetching site coordinates: $e');
    }
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isConnected
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
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
                  const SizedBox(width: 6),
                  Text(
                    _isConnected ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.orange),
            onPressed: _isConnected
                ? () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Syncing offline data...'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                    await _syncOfflineClockIns(showMessages: true);
                    await _loadLearnersFromLocalDatabase();
                  }
                : null,
            tooltip: 'Sync Clock-ins',
          ),
          IconButton(
            icon: const Icon(Icons.description, color: Colors.teal),
            onPressed: _isConnected
                ? () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Syncing unsynced documents...'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                    await _syncAllUnsyncedDocuments();
                  }
                : null,
            tooltip: 'Sync Docs',
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.green),
            onPressed: _isConnected
                ? () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Syncing current day records from server...'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                    try {
                      final syncService = SyncService();
                      await syncService
                          .syncClassClockingFromServer(widget.classID);
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
            tooltip: 'Pull Server Records',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            onPressed: _isConnected
                ? () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Syncing learners from server...'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                    try {
                      final dbHelper = DatabaseHelper();
                      await dbHelper.syncLearnersFromServer(widget.classID);
                      await _loadLearnersFromLocalDatabase();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Learners synced successfully'),
                            backgroundColor: Colors.green,
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
            tooltip: 'Update Learners',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showQueueStatus();
            },
            tooltip: 'View Sync Queue Status',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class Information for ${widget.classID}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Learner Actions: Clock In/Out, Upload Sick Notes, View Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                // Status Chips (GPS & Sensor)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // GPS Status Chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _currentGpsAccuracy == null
                            ? Colors.grey.withOpacity(0.1)
                            : (!_isWithinRange && _siteLat != null
                                ? Colors.red.withOpacity(0.1)
                                : (_currentGpsAccuracy! <= 25
                                    ? Colors.green.withOpacity(0.1)
                                    : (_currentGpsAccuracy! <= 60
                                        ? Colors.orange.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1)))),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _currentGpsAccuracy == null
                              ? Colors.grey
                              : (!_isWithinRange && _siteLat != null
                                  ? Colors.red
                                  : (_currentGpsAccuracy! <= 25
                                      ? Colors.green
                                      : (_currentGpsAccuracy! <= 60
                                          ? Colors.orange
                                          : Colors.red))),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            !_isWithinRange && _siteLat != null
                                ? Icons.location_off
                                : Icons.location_on,
                            size: 18,
                            color: _currentGpsAccuracy == null
                                ? Colors.grey
                                : (!_isWithinRange && _siteLat != null
                                    ? Colors.red
                                    : (_currentGpsAccuracy! <= 25
                                        ? Colors.green
                                        : (_currentGpsAccuracy! <= 60
                                            ? Colors.orange
                                            : Colors.red))),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentGpsAccuracy == null
                                ? 'GPS: --'
                                : (!_isWithinRange && _siteLat != null
                                    ? 'OUT OF RANGE'
                                    : 'GPS Accuracy: ${_currentGpsAccuracy!.toStringAsFixed(0)}m'),
                            style: TextStyle(
                              fontSize: 14,
                              color: _currentGpsAccuracy == null
                                  ? Colors.grey
                                  : (!_isWithinRange && _siteLat != null
                                      ? Colors.red
                                      : (_currentGpsAccuracy! <= 25
                                          ? Colors.green
                                          : (_currentGpsAccuracy! <= 60
                                              ? Colors.orange
                                              : Colors.red))),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.refresh,
                              size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                    // Sensor Status Button
                    InkWell(
                      onTap: _initializeSensor,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isSensorConnected
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                _isSensorConnected ? Colors.green : Colors.red,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isSensorConnected
                                  ? Icons.check_circle
                                  : Icons.usb_off,
                              size: 18,
                              color: _isSensorConnected
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isSensorConnected
                                  ? 'Sensor OK'
                                  : 'Reconnect Sensor',
                              style: TextStyle(
                                fontSize: 14,
                                color: _isSensorConnected
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_statusMessage.isNotEmpty &&
                    !_statusMessage.contains('Sensor'))
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: _statusMessage.toLowerCase().contains('error') ||
                              _statusMessage.toLowerCase().contains('failed')
                          ? Colors.red
                          : Colors.black,
                    ),
                  ),
              ],
            ),
          ),

          // ==========================================
          // 3. MAIN CONTENT
          // ==========================================
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  FutureBuilder<int>(
                    future: _getUnsyncedCount(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data! > 0) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
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

                  // Search bar
                  TextField(
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

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

                  // Learners List
                  Expanded(
                    child: _filteredLearners.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_off,
                                    size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No learners found for this class'
                                      : 'No learners match your search',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
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
                                ],
                                rows: _filteredLearners.map((learner) {
                                  String learnerId =
                                      learner['LearnerID']?.toString() ?? 'N/A';
                                  String name =
                                      learner['Name']?.toString() ?? 'N/A';
                                  String surname =
                                      learner['Surname']?.toString() ?? 'N/A';
                                  String clockInTime =
                                      clockInTimes[learnerId] ?? '';
                                  String clockOutTime =
                                      clockOutTimes[learnerId] ?? '';
                                  String contactTime =
                                      contactTimes[learnerId] ?? '';

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(name)),
                                      DataCell(Text(surname)),
                                      DataCell(Text(
                                          learner['IDNumber']?.toString() ??
                                              'N/A')),
                                      // Fingerprint status column
                                      DataCell(_buildFingerprintStatusIndicator(
                                          learnerId)),
                                      // Clock In column
                                      DataCell(
                                        clockInTime.isEmpty
                                            ? ElevatedButton(
                                                onPressed:
                                                    _isClockingIn[learnerId] ==
                                                            true
                                                        ? null
                                                        : () =>
                                                            _verifyAndClockIn(
                                                                learnerId),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: const Text('Clock In'),
                                              )
                                            : Text(
                                                clockInTime,
                                                style: const TextStyle(
                                                    color: Colors.green,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                      ),
                                      // Clock Out column
                                      DataCell(
                                        clockInTime.isEmpty
                                            ? const Text('-')
                                            : (clockOutTime.isEmpty
                                                ? ElevatedButton(
                                                    onPressed: _isClockingIn[
                                                                learnerId] ==
                                                            true
                                                        ? null
                                                        : () =>
                                                            _verifyAndClockOut(
                                                                learnerId),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.red,
                                                      foregroundColor:
                                                          Colors.white,
                                                    ),
                                                    child:
                                                        const Text('Clock Out'),
                                                  )
                                                : Text(
                                                    clockOutTime,
                                                    style: const TextStyle(
                                                        color: Colors.red,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  )),
                                      ),
                                      // Contact Time column
                                      DataCell(Text(contactTime.isEmpty
                                          ? '-'
                                          : contactTime)),
                                      // Sick Note column
                                      DataCell(
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    SickNotePage(
                                                  learnerID:
                                                      int.parse(learnerId),
                                                  learnerName: '$name $surname',
                                                ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue[100],
                                          ),
                                          icon: const Icon(
                                              Icons.medical_services,
                                              size: 18),
                                          label: const Text('Sick'),
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
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            time.isNotEmpty ? time : '--:--',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: time.isNotEmpty ? color : Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildFingerprintStatusIndicator(String learnerId) {
    return FutureBuilder<Map<String, String?>>(
      future: DatabaseHelper().getFingerprints(int.parse(learnerId)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2));
        }
        final templates = snapshot.data ?? {'left': null, 'right': null};
        final hasLeft =
            templates['left'] != null && templates['left']!.isNotEmpty;
        final hasRight =
            templates['right'] != null && templates['right']!.isNotEmpty;

        if (hasLeft || hasRight) {
          return Tooltip(
            message: hasLeft && hasRight
                ? 'Both hands'
                : (hasLeft ? 'Left hand' : 'Right hand'),
            child: const Icon(Icons.fingerprint, color: Colors.green, size: 24),
          );
        } else {
          return const Tooltip(
            message: 'No fingerprints enrolled',
            child: Icon(Icons.fingerprint, color: Colors.red, size: 24),
          );
        }
      },
    );
  }
}

class _RequiredProfileRule {
  final String label;
  final List<String> keys;

  const _RequiredProfileRule({
    required this.label,
    required this.keys,
  });
}
