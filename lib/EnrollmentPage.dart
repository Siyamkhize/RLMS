import 'package:flutter/material.dart';
import 'package:rlmss/services/fingerprint_service.dart';
import 'package:rlmss/database_helper.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class EnrollmentPage extends StatefulWidget {
  final int learnerId;
  final bool returnToClockAfterEnroll;
  const EnrollmentPage(
      {super.key,
      required this.learnerId,
      this.returnToClockAfterEnroll = false});

  @override
  _EnrollmentPageState createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  final FingerprintService _fingerprintService = FingerprintService();
  final FutronicService _futronicService = FutronicService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _isSensorConnected = false;
  String _enrollmentStatus = 'Initializing sensor...';
  bool _leftThumbEnrolled = false;
  bool _rightThumbEnrolled = false;
  bool _isEnrolling = false;
  bool _isInitializing = false;
  bool _enrollmentInProgress = false; // Extra lock to prevent interference
  DateTime? _lastEnrollmentStart; // Track enrollment timing
  DateTime? _enrollmentProtectionStart; // Independent protection timestamp
  int _leftEnrollCooldown = 0;
  int _rightEnrollCooldown = 0;
  Timer? _leftCooldownTimer;
  Timer? _rightCooldownTimer;
  String? _zktecoLeftTemplate;
  String? _zktecoRightTemplate;
  String? _futronicLeftTemplate;
  String? _futronicRightTemplate;
  String _activeScanner = 'auto'; // 'zkteco', 'futronic', or 'none'

  @override
  void initState() {
    super.initState();
    _checkEnrolledThumbs();
    _initializeSensor();
    _setupStreamListeners();
    // Start background fingerprint sync service
    _databaseHelper.startFingerprintSyncService();
    // Listen for connectivity changes to auto-sync
    _setupConnectivityListener();
  }

  Future<void> _checkEnrolledThumbs() async {
    debugPrint(
        '[CHECK_THUMBS] Starting enrollment check for learner ${widget.learnerId}');
    // First detect the currently connected scanner
    final scanner = await _detectScanner();

    // If scanner changed, clean up the previous scanner's state
    if (_activeScanner != scanner && _activeScanner != 'auto') {
      debugPrint(
          '[SCANNER_SWITCH] Switching from $_activeScanner to $scanner - cleaning up previous scanner');
      await _cleanupPreviousScanner(_activeScanner);
    }

    setState(() {
      _activeScanner = scanner;
      _isSensorConnected = scanner != 'none'; // Update sensor connection status
    });

    // Get all templates for this learner
    final templates = await _databaseHelper.getAllTemplates(widget.learnerId);
    debugPrint('[DB] Fetched all templates: $templates');

    // Also try the getFingerprints method for comparison
    debugPrint('[CHECK_THUMBS] Calling getFingerprints for comparison');
    final fingerprintTemplates =
        await _databaseHelper.getFingerprints(widget.learnerId);
    debugPrint('[CHECK_THUMBS] getFingerprints result: $fingerprintTemplates');

    bool leftEnrolled = false;
    bool rightEnrolled = false;

    if (scanner == 'zkteco') {
      // Check ZKTeco templates
      leftEnrolled = templates['zkteco_left_template'] != null &&
          templates['zkteco_left_template']!.isNotEmpty;
      rightEnrolled = templates['zkteco_right_template'] != null &&
          templates['zkteco_right_template']!.isNotEmpty;
      debugPrint(
          '[DB] ZKTeco enrollment status: left=$leftEnrolled, right=$rightEnrolled');
    } else if (scanner == 'futronic') {
      // Check Futronic templates
      leftEnrolled = templates['futronic_left_template'] != null &&
          templates['futronic_left_template']!.isNotEmpty;
      rightEnrolled = templates['futronic_right_template'] != null &&
          templates['futronic_right_template']!.isNotEmpty;
      debugPrint(
          '[DB] Futronic enrollment status: left=$leftEnrolled, right=$rightEnrolled');
    } else {
      // No scanner connected - check if any templates exist
      leftEnrolled = (templates['zkteco_left_template'] != null &&
              templates['zkteco_left_template']!.isNotEmpty) ||
          (templates['futronic_left_template'] != null &&
              templates['futronic_left_template']!.isNotEmpty);
      rightEnrolled = (templates['zkteco_right_template'] != null &&
              templates['zkteco_right_template']!.isNotEmpty) ||
          (templates['futronic_right_template'] != null &&
              templates['futronic_right_template']!.isNotEmpty);
      debugPrint(
          '[DB] No scanner - any enrollment status: left=$leftEnrolled, right=$rightEnrolled');
    }

    setState(() {
      _leftThumbEnrolled = leftEnrolled;
      _rightThumbEnrolled = rightEnrolled;

      if (scanner == 'none') {
        if (leftEnrolled || rightEnrolled) {
          _enrollmentStatus =
              'Learner has fingerprints enrolled on other scanner. Connect a scanner to enroll.';
        } else {
          _enrollmentStatus =
              'No scanner detected. Please connect a scanner to enroll.';
        }
      } else if (leftEnrolled && rightEnrolled) {
        _enrollmentStatus =
            'Both thumbs enrolled on $scanner scanner. Tap buttons to update fingerprints.';
      } else if (leftEnrolled) {
        _enrollmentStatus =
            'Left thumb enrolled on $scanner scanner. Right thumb ready for enrollment.';
      } else if (rightEnrolled) {
        _enrollmentStatus =
            'Right thumb enrolled on $scanner scanner. Left thumb ready for enrollment.';
      } else {
        _enrollmentStatus = 'Ready to enroll on $scanner scanner.';
      }
    });
  }

  void _setupStreamListeners() {
    _fingerprintService.enrollStatusStream.listen((status) {
      debugPrint('[ENROLL_STATUS_STREAM] $status'); // Debug log
      if (!mounted) return;

      // Check if this status will clear enrollment state
      bool willClearState = status.toLowerCase().contains('error') ||
          status.toLowerCase().contains('failed');
      if (willClearState) {
        debugPrint(
            '[ENROLL_STATUS_STREAM] Status will clear enrollment state: $status');
      }

      setState(() {
        _enrollmentStatus = status;
        if (willClearState) {
          debugPrint(
              '[ENROLL_STATUS_STREAM] Clearing enrollment state due to error/failed status');
          _isEnrolling = false;
          _enrollmentInProgress = false; // Clear lock on error
          _lastEnrollmentStart = null; // Clear enrollment protection
          // DON'T clear _enrollmentProtectionStart here - let it timeout naturally
          // Clear emergency block on enrollment status error (temporarily disabled)
          // _fingerprintService.setEmergencyBlock(false);
          // Don't show snackbar for cleanup messages
          if (!status.toLowerCase().contains('cancelling enrollment')) {
            _showSnackBar('Enrollment issue: $status');
          }
          // Only reset sensor on real error, not after every operation
        }
      });
    });

    _fingerprintService.enrollSuccessStream.listen((result) async {
      debugPrint('[ENROLL_SUCCESS_STREAM] $result'); // Debug log
      if (!mounted) return;

      debugPrint(
          '[ENROLL_SUCCESS_STREAM] State before processing: _isEnrolling=$_isEnrolling, _enrollmentInProgress=$_enrollmentInProgress');

      final finger = result['finger'] as String?;
      final template = result['template'];
      debugPrint(
          '[ENROLL] Received enrollSuccessStream: finger=$finger, template type=${template?.runtimeType}, template length=${template != null ? template.toString().length : 0}');

      if (finger == null || template == null) {
        setState(() {
          _enrollmentStatus = 'Invalid enrollment data received';
          _isEnrolling = false;
        });
        _showSnackBar('Invalid enrollment data');
        debugPrint(
            '[ENROLL] Invalid enrollment data: finger=$finger, template=$template');
        return;
      }

      try {
        // Basic guard to reject partial/too-small ZKTeco templates as well
        // Keep ZKTeco acceptance more permissive and rely on device's own quality metrics.

        final bool isSynced = await _databaseHelper.saveFingerprintSmart(
            widget.learnerId, finger, template,
            scannerType: 'zkteco');
        debugPrint(
            '[ENROLL] Saved ZKTeco fingerprint for learnerId= ${widget.learnerId}, finger=$finger, template length=${template.toString().length}, synced=$isSynced');
        debugPrint(
            '[ENROLL] ZKTeco template preview: ${template.toString().isNotEmpty ? template.toString().substring(0, template.toString().length > 50 ? 50 : template.toString().length) : 'EMPTY'}');
        debugPrint('[ENROLL] ZKTeco template type: ${template.runtimeType}');
        debugPrint('[ENROLL] ZKTeco template is null: ${template == null}');
        debugPrint(
            '[ENROLL] ZKTeco template is empty string: ${template.toString().isEmpty}');

        if (!mounted) return;

        // First set the enrollment state and update UI
        setState(() {
          if (finger == 'left') {
            _leftThumbEnrolled = true;
            _enrollmentStatus =
                'Left thumb enrolled successfully! Preparing for next enrollment...';
            _leftEnrollCooldown = 5; // Reduced from 20 to 5 seconds
            _leftCooldownTimer?.cancel();
            debugPrint('[TIMER] Starting left thumb cooldown');
            _leftCooldownTimer =
                Timer.periodic(const Duration(seconds: 1), (timer) {
              if (!mounted) return;
              setState(() {
                if (_leftEnrollCooldown > 0) {
                  _leftEnrollCooldown--;
                  debugPrint('[TIMER] Left cooldown: $_leftEnrollCooldown');
                }
                if (_leftEnrollCooldown == 0) {
                  debugPrint('[TIMER] Left cooldown finished');
                  _leftCooldownTimer?.cancel();
                }
              });
            });
          } else if (finger == 'right') {
            _rightThumbEnrolled = true;
            _enrollmentStatus =
                'Right thumb enrolled successfully! Preparing for next enrollment...';
            _rightEnrollCooldown = 5; // Reduced from 20 to 5 seconds
            _rightCooldownTimer?.cancel();
            debugPrint('[TIMER] Starting right thumb cooldown');
            _rightCooldownTimer =
                Timer.periodic(const Duration(seconds: 1), (timer) {
              if (!mounted) return;
              setState(() {
                if (_rightEnrollCooldown > 0) {
                  _rightEnrollCooldown--;
                  debugPrint('[TIMER] Right cooldown: $_rightEnrollCooldown');
                }
                if (_rightEnrollCooldown == 0) {
                  debugPrint('[TIMER] Right cooldown finished');
                  _rightCooldownTimer?.cancel();
                }
              });
            });
          }
          _isEnrolling = false;
          _enrollmentInProgress = false; // Clear lock on success
          _lastEnrollmentStart = null; // Clear enrollment protection
          _enrollmentProtectionStart =
              null; // Clear independent protection on successful enrollment
          // Emergency block will be cleared by FingerprintService automatically on success
        });

        // Explicitly clear fingerprint service state to prevent stuck enrollment
        _fingerprintService.manualReset();
        debugPrint('[ENROLL] Manual reset after successful ZKTeco enrollment');

        // Reset sensor properly and ensure it's ready for next operation
        // Add a small delay to ensure enrollment completion before reset
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _resetSensorAfterEnrollment();
          }
        });

        // Show appropriate message based on sync status
        if (isSynced) {
          _showSnackBar(
              'Fingerprint enrolled and synced to server for $finger thumb');
        } else {
          _showSnackBar(
              'Fingerprint enrolled locally for $finger thumb (will sync when online)');
        }

        // If requested, navigate back automatically once at least one thumb is enrolled
        if (widget.returnToClockAfterEnroll &&
            (_leftThumbEnrolled || _rightThumbEnrolled)) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context)
                  .pop(true); // return true to indicate enrollment happened
            }
          });
        }
      } catch (e) {
        setState(() {
          _enrollmentStatus = 'Failed to save fingerprint: $e';
          _isEnrolling = false;
          _enrollmentInProgress = false; // Clear lock on save error
          _lastEnrollmentStart = null; // Clear enrollment protection
          // DON'T clear _enrollmentProtectionStart here - let it timeout naturally
        });

        // Clear emergency block on save error and reset sensor
        _fingerprintService.manualReset();
        debugPrint('[ENROLL] Manual reset after save error');
        _showSnackBar('Failed to save fingerprint: $e');
        debugPrint('[ENROLL] Failed to save fingerprint: $e');
      }
    });

    _fingerprintService.sensorStatusStream.listen((status) {
      debugPrint('[SENSOR_STATUS_STREAM] Received: $status');
      debugPrint(
          '[SENSOR_STATUS_STREAM] Current state: _isEnrolling=$_isEnrolling, _enrollmentInProgress=$_enrollmentInProgress');

      if (!mounted) return;

      // Check independent protection window first
      bool inIndependentProtection = false;
      if (_enrollmentProtectionStart != null) {
        final timeSinceProtectionStart =
            DateTime.now().difference(_enrollmentProtectionStart!);
        inIndependentProtection = timeSinceProtectionStart.inSeconds < 15;
      }

      // Check if we're within enrollment protection window
      bool inProtectionWindow = false;
      if (_lastEnrollmentStart != null) {
        final timeSinceEnrollment =
            DateTime.now().difference(_lastEnrollmentStart!);
        inProtectionWindow = timeSinceEnrollment.inSeconds < 10;
      }

      // Be less aggressive with state updates during enrollment
      if (_isEnrolling ||
          _enrollmentInProgress ||
          inProtectionWindow ||
          inIndependentProtection) {
        // Only update connection status, don't change enrollment status during active enrollment
        setState(() {
          _isSensorConnected = status == 'Sensor initialized';
        });
        debugPrint(
            '[SENSOR_STATUS] During enrollment/protection: $status (ignored status update, independent=${inIndependentProtection ? 'active' : 'inactive'}, regular=${inProtectionWindow ? 'active' : 'inactive'})');
        return;
      }

      debugPrint(
          '[SENSOR_STATUS_STREAM] Not protected, will update enrollment status');
      setState(() {
        _isSensorConnected = status == 'Sensor initialized';
        // Only update enrollment status if we're not actively enrolling or initializing
        if (!_isEnrolling &&
            !_isInitializing &&
            !_enrollmentInProgress &&
            !inProtectionWindow &&
            !inIndependentProtection) {
          _enrollmentStatus = _isSensorConnected ? 'Ready to enroll' : status;
        }
      });
      debugPrint('[SENSOR_STATUS] $status');
    });
  }

  Future<void> _initializeSensor() async {
    // Check independent protection window first (most important)
    if (_enrollmentProtectionStart != null) {
      final timeSinceProtectionStart =
          DateTime.now().difference(_enrollmentProtectionStart!);
      if (timeSinceProtectionStart.inSeconds < 15) {
        // 15 second independent protection window
        debugPrint(
            '[INIT] Skipping initialization: Within independent protection window (${timeSinceProtectionStart.inSeconds}s since protection start)');
        return;
      } else {
        // Clear expired protection
        _enrollmentProtectionStart = null;
        debugPrint('[INIT] Cleared expired enrollment protection');
      }
    }

    if (_isInitializing || _isEnrolling || _enrollmentInProgress) {
      debugPrint(
          '[INIT] Skipping initialization: _isInitializing=$_isInitializing, _isEnrolling=$_isEnrolling, _enrollmentInProgress=$_enrollmentInProgress');
      return; // Prevent concurrent initialization or during enrollment
    }

    // Check if we're still within the enrollment protection window
    if (_lastEnrollmentStart != null) {
      final timeSinceEnrollment =
          DateTime.now().difference(_lastEnrollmentStart!);
      if (timeSinceEnrollment.inSeconds < 10) {
        // 10 second protection window
        debugPrint(
            '[INIT] Skipping initialization: Still within enrollment protection window (${timeSinceEnrollment.inSeconds}s since start)');
        return;
      }
    }

    debugPrint('[INIT] Starting sensor initialization');
    setState(() {
      _isInitializing = true;
      _enrollmentStatus = 'Checking for scanners...';
    });

    try {
      // Check for both scanners using auto-detection with crash protection
      final scanner = await _detectScannerSafely();

      if (!mounted) return;

      setState(() {
        _activeScanner = scanner;
        _isSensorConnected = scanner != 'none';
        _isInitializing = false;
      });

      // Check enrollment status based on the detected scanner
      await _checkEnrolledThumbs();

      if (scanner == 'none') {
        if (!mounted) return;
        setState(() {
          _enrollmentStatus = 'No scanner found, retrying in 3 seconds';
        });
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) _initializeSensor();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enrollmentStatus = 'Error checking scanners: $e';
        _isSensorConnected = false;
        _isInitializing = false;
        _activeScanner = 'none';
      });
      _showSnackBar('Scanner check error: $e');
    }
  }

  Future<void> _startEnrollment(String finger) async {
    debugPrint('[ENROLL] _startEnrollment called for $finger');
    debugPrint(
        '[ENROLL] State check: _isEnrolling=$_isEnrolling, _isSensorConnected=$_isSensorConnected, _isInitializing=$_isInitializing');

    try {
      // More robust state checking
      if (_isEnrolling || _enrollmentInProgress) {
        debugPrint(
            '[ENROLL] Cannot start - enrollment already in progress: _isEnrolling=$_isEnrolling, _enrollmentInProgress=$_enrollmentInProgress');
        _showSnackBar('Enrollment already in progress. Please wait.');
        return;
      }

      if (_isInitializing) {
        debugPrint('[ENROLL] Cannot start - sensor is initializing');
        _showSnackBar('Sensor is initializing. Please wait.');
        return;
      }

      // Check cooldown for the specific finger
      if (finger == 'left' && _leftEnrollCooldown > 0) {
        debugPrint('[ENROLL] Cannot start - left finger in cooldown');
        _showSnackBar(
            'Please wait ${_leftEnrollCooldown}s before enrolling left thumb again.');
        return;
      }

      if (finger == 'right' && _rightEnrollCooldown > 0) {
        debugPrint('[ENROLL] Cannot start - right finger in cooldown');
        _showSnackBar(
            'Please wait ${_rightEnrollCooldown}s before enrolling right thumb again.');
        return;
      }

      // Allow re-enrollment/updating of existing fingerprints
      if ((finger == 'left' && _leftThumbEnrolled) ||
          (finger == 'right' && _rightThumbEnrolled)) {
        debugPrint(
            '[ENROLL] Updating existing $finger thumb on $_activeScanner scanner');
        _showSnackBar('Updating existing $finger thumb fingerprint...');
        // Continue with enrollment to update the existing fingerprint
      }

      // Use the new auto-detection enrollment logic
      await _enroll(finger);
    } catch (unexpectedError) {
      // Catch any unexpected errors that might be causing silent failures
      debugPrint(
          '[ENROLL] UNEXPECTED ERROR in _startEnrollment: $unexpectedError');
      debugPrint('[ENROLL] Stack trace: ${StackTrace.current}');

      if (mounted) {
        setState(() {
          _isEnrolling = false;
          _enrollmentInProgress = false;
          _lastEnrollmentStart = null;
          _enrollmentStatus = 'Unexpected error: $unexpectedError';
        });

        _showSnackBar('Unexpected enrollment error: $unexpectedError');
      }
    }
  }

  Future<void> _cancelEnrollment() async {
    if (!_isEnrolling) return;

    setState(() {
      _enrollmentStatus = 'Cancelling enrollment...';
    });

    try {
      await _fingerprintService.cancelEnrollment();
      setState(() {
        _enrollmentStatus = 'Enrollment cancelled';
        _isEnrolling = false;
        _enrollmentInProgress = false; // Clear lock on cancel
        _lastEnrollmentStart = null; // Clear enrollment protection
        // DON'T clear _enrollmentProtectionStart here - let it timeout naturally
      });

      // Clear emergency block on manual cancellation (temporarily disabled)
      // _fingerprintService.setEmergencyBlock(false);
      debugPrint('[ENROLL] Emergency block clear temporarily disabled');
      _showSnackBar('Enrollment cancelled');
    } catch (e) {
      setState(() {
        _enrollmentStatus = 'Error cancelling enrollment: $e';
        _isEnrolling = false;
        _enrollmentInProgress = false; // Clear lock on cancel error
        _lastEnrollmentStart = null; // Clear enrollment protection
        // DON'T clear _enrollmentProtectionStart here - let it timeout naturally
      });

      // Clear emergency block on cancellation error (temporarily disabled)
      // _fingerprintService.setEmergencyBlock(false);
      debugPrint('[ENROLL] Emergency block clear temporarily disabled');
      _showSnackBar('Error cancelling enrollment: $e');
    }
  }

  Future<void> _resetSensorAfterEnrollment() async {
    debugPrint('[RESET] Starting sensor reset after enrollment');
    try {
      // Wait a moment to ensure native cleanup is complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Reset sensor to ensure clean state, but don't await to avoid blocking
      _fingerprintService.resetSensor().then((_) {
        debugPrint('[RESET] Background sensor reset completed');
      }).catchError((e) {
        debugPrint('[RESET] Background sensor reset error: $e');
      });

      // Just update the status without extensive sensor checking
      if (!mounted) return;
      setState(() {
        _isSensorConnected =
            true; // Assume connected after successful enrollment
        // Only update status if we're not currently enrolling
        if (!_isEnrolling && !_isInitializing) {
          _enrollmentStatus = 'Ready for next enrollment';
        }
      });

      debugPrint('[RESET] Sensor reset initiated, ready for next enrollment');
    } catch (e) {
      debugPrint('[RESET] Error during sensor reset: $e');
      if (!mounted) return;
      setState(() {
        _enrollmentStatus = 'Sensor reset error: $e';
        _isSensorConnected = false;
      });
    }
  }

  Future<void> _resetSensor() async {
    setState(() {
      _enrollmentStatus = 'Resetting sensor...';
      _isEnrolling = false;
      _isSensorConnected = false;
    });

    try {
      await _fingerprintService.resetSensor();

      // Wait for reset to complete
      await Future.delayed(const Duration(seconds: 2));

      // Reinitialize
      await _initializeSensor();
    } catch (e) {
      setState(() {
        _enrollmentStatus = 'Error resetting sensor: $e';
      });
      _showSnackBar('Error resetting sensor: $e');
    }
  }

  void _clearEnrollmentLocks() {
    _isEnrolling = false;
    _enrollmentInProgress = false;
    _lastEnrollmentStart = null;
    // DON'T clear _enrollmentProtectionStart here - let it timeout naturally
    debugPrint(
        '[LOCKS] Standard enrollment locks cleared (independent protection remains)');
  }

  void _setupConnectivityListener() {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      if (result != ConnectivityResult.none) {
        debugPrint(
            '[CONNECTIVITY] Internet available, attempting to sync fingerprints');
        // Auto-sync when internet becomes available
        _databaseHelper.syncUnsyncedFingerprints().then((_) {
          debugPrint('[CONNECTIVITY] Auto-sync completed');
        }).catchError((e) {
          debugPrint('[CONNECTIVITY] Auto-sync failed: $e');
        });
      }
    });
  }

  Future<void> _cleanupPreviousScanner(String previousScanner) async {
    try {
      debugPrint('[CLEANUP] Cleaning up previous scanner: $previousScanner');

      if (previousScanner == 'zkteco') {
        // Clean up ZKTeco service state
        debugPrint('[CLEANUP] Cleaning up ZKTeco service');
        await _fingerprintService.cancelEnrollment().catchError((e) {
          debugPrint('[CLEANUP] ZKTeco cancel enrollment error: $e');
        });

        // Manual reset to clear any stuck state
        _fingerprintService.manualReset();
        debugPrint('[CLEANUP] ZKTeco manual reset completed');

        // Wait a moment for cleanup
        await Future.delayed(const Duration(milliseconds: 500));
      } else if (previousScanner == 'futronic') {
        // Clean up Futronic service state if needed
        debugPrint('[CLEANUP] Cleaning up Futronic service');
        // Add any Futronic-specific cleanup here if needed
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Clear any enrollment locks
      _isEnrolling = false;
      _enrollmentInProgress = false;
      _lastEnrollmentStart = null;
      _enrollmentProtectionStart = null;

      debugPrint('[CLEANUP] Previous scanner cleanup completed');
    } catch (e) {
      debugPrint('[CLEANUP] Error during previous scanner cleanup: $e');
    }
  }

  Future<void> _cleanupFingerprintService() async {
    try {
      debugPrint('[CLEANUP] Ensuring FingerprintService state is clean');

      // First try regular cleanup
      await _fingerprintService.cancelEnrollment().catchError((e) {
        debugPrint('[CLEANUP] Cancel operation result: $e');
      });

      // Wait a moment for cleanup to complete
      await Future.delayed(const Duration(milliseconds: 200));

      // Check if still busy after regular cleanup
      bool isStillBusy = _fingerprintService.isBusy;
      debugPrint('[CLEANUP] After regular cleanup, still busy: $isStillBusy');

      // If still busy, manually reset the service state
      if (isStillBusy) {
        debugPrint(
            '[CLEANUP] Regular cleanup failed, manually resetting service state');

        // Use simple manual reset to clear stuck states
        _fingerprintService.manualReset();
        debugPrint('[CLEANUP] Manual reset completed');

        // Wait for reset to take effect
        await Future.delayed(const Duration(milliseconds: 300));

        // Check final state
        isStillBusy = _fingerprintService.isBusy;
        debugPrint('[CLEANUP] After manual reset, still busy: $isStillBusy');
      }

      debugPrint(
          '[CLEANUP] FingerprintService cleanup complete, final busy state: $isStillBusy');
    } catch (e) {
      debugPrint('[CLEANUP] Error during FingerprintService cleanup: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildThumbCard(String thumb) {
    final bool isLeft = thumb == 'left';
    final bool isEnrolled = isLeft ? _leftThumbEnrolled : _rightThumbEnrolled;
    final int cooldown = isLeft ? _leftEnrollCooldown : _rightEnrollCooldown;
    final String thumbName = isLeft ? 'Left Thumb' : 'Right Thumb';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fingerprint, size: 24, color: Colors.blue),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    thumbName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isEnrolled)
              Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: !_isEnrolling &&
                            !_isInitializing &&
                            !_enrollmentInProgress &&
                            cooldown == 0
                        ? () {
                            debugPrint(
                                '[UI] Re-enroll $thumbName button pressed');
                            // Force re-check scanner connection before re-enrollment
                            _initializeSensor().then((_) {
                              _startEnrollment(thumb);
                            });
                          }
                        : () {
                            // DEBUG: Log why button is disabled
                            debugPrint(
                                '[UI] Re-enroll button DISABLED - Reasons:');
                            debugPrint('[UI]   _isEnrolling: $_isEnrolling');
                            debugPrint(
                                '[UI]   _isInitializing: $_isInitializing');
                            debugPrint(
                                '[UI]   _enrollmentInProgress: $_enrollmentInProgress');
                            debugPrint('[UI]   cooldown: $cooldown');

                            // Force reset all blocking states
                            setState(() {
                              _isEnrolling = false;
                              _isInitializing = false;
                              _enrollmentInProgress = false;
                              _leftEnrollCooldown = 0;
                              _rightEnrollCooldown = 0;
                            });

                            // Clear timers
                            _leftCooldownTimer?.cancel();
                            _rightCooldownTimer?.cancel();

                            // Reset fingerprint service
                            _fingerprintService.manualReset();

                            // Clear protection windows
                            _lastEnrollmentStart = null;
                            _enrollmentProtectionStart = null;

                            debugPrint(
                                '[UI] Force unblocked re-enrollment button');

                            // Show message to user
                            _showSnackBar(
                                'Re-enrollment unblocked. Try again.');
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(140, 45),
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Re-enroll'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$thumbName enrolled. Tap Re-enroll to update.',
                    style: TextStyle(
                        color: Colors.green[800], fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            else if (cooldown > 0 && !_isEnrolling && !_isInitializing)
              Column(
                children: [
                  const Icon(Icons.hourglass_bottom,
                      color: Colors.orange, size: 32),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(140, 45),
                      backgroundColor: Colors.orange,
                    ),
                    child: Text('Wait ${cooldown}s...'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Please wait before enrolling again.',
                    style: TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            else
              Column(
                children: [
                  const Icon(Icons.cancel, color: Colors.red, size: 32),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: !isEnrolled &&
                            !_isEnrolling &&
                            !_isInitializing &&
                            !_enrollmentInProgress &&
                            cooldown == 0
                        ? () {
                            debugPrint('[UI] Enroll $thumbName button pressed');
                            // Force re-check scanner connection before enrollment
                            _initializeSensor().then((_) {
                              _startEnrollment(thumb);
                            });
                          }
                        : () {
                            // DEBUG: Log why button is disabled
                            debugPrint(
                                '[UI] Enroll button DISABLED - Reasons:');
                            debugPrint('[UI]   isEnrolled: $isEnrolled');
                            debugPrint('[UI]   _isEnrolling: $_isEnrolling');
                            debugPrint(
                                '[UI]   _isInitializing: $_isInitializing');
                            debugPrint(
                                '[UI]   _enrollmentInProgress: $_enrollmentInProgress');
                            debugPrint('[UI]   cooldown: $cooldown');

                            if (isEnrolled) {
                              _showSnackBar(
                                  'This thumb is enrolled. You can update it by tapping the enrollment button.');
                            } else {
                              // Force reset all blocking states
                              setState(() {
                                _isEnrolling = false;
                                _isInitializing = false;
                                _enrollmentInProgress = false;
                                _leftEnrollCooldown = 0;
                                _rightEnrollCooldown = 0;
                              });

                              // Clear timers
                              _leftCooldownTimer?.cancel();
                              _rightCooldownTimer?.cancel();

                              // Reset fingerprint service
                              _fingerprintService.manualReset();

                              // Clear protection windows
                              _lastEnrollmentStart = null;
                              _enrollmentProtectionStart = null;

                              debugPrint(
                                  '[UI] Force unblocked enrollment button');

                              // Show message to user
                              _showSnackBar('Enrollment unblocked. Try again.');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(140, 45),
                      backgroundColor: Colors.blue,
                    ),
                    child: Text('Enroll $thumbName'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$thumbName not enrolled.',
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Safe scanner detection with crash protection
  Future<String> _detectScannerSafely() async {
    try {
      debugPrint('[DETECT_SAFE] Starting safe scanner detection...');

      // Add timeout to prevent hanging
      return await _detectScanner().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint(
              '[DETECT_SAFE] Scanner detection timed out, returning none');
          return 'none';
        },
      );
    } catch (e) {
      debugPrint('[DETECT_SAFE] Scanner detection crashed: $e');
      // Return 'none' instead of crashing the app
      return 'none';
    }
  }

  Future<String> _detectScanner() async {
    debugPrint('[DETECT] Starting enhanced scanner detection...');

    // Try ZKTeco first
    try {
      debugPrint('[DETECT] Checking ZKTeco scanner...');
      final isZkConnected = await _fingerprintService.isSensorConnected();
      debugPrint('[DETECT] ZKTeco result: $isZkConnected');
      if (isZkConnected) {
        debugPrint('[DETECT] ZKTeco scanner detected!');
        return 'zkteco';
      }
    } catch (e) {
      debugPrint('[DETECT] ZKTeco check failed: $e');
    }

    // Enhanced Futronic detection with multiple attempts
    return await _detectFutronicWithRetry();
  }

  Future<String> _detectFutronicWithRetry() async {
    const maxAttempts = 3;
    const delays = [500, 1000, 2000]; // Progressive delays in milliseconds

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        debugPrint('[DETECT] Futronic attempt $attempt/$maxAttempts...');

        // Add timeout and crash protection for Futronic detection
        final isFutronicConnected =
            await _futronicService.isFutronicConnected().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint(
                '[DETECT] Futronic detection attempt $attempt timed out');
            return false;
          },
        );
        debugPrint(
            '[DETECT] Futronic attempt $attempt result: $isFutronicConnected');

        if (isFutronicConnected) {
          debugPrint(
              '[DETECT] ✅ Futronic scanner detected on attempt $attempt!');
          return 'futronic';
        }

        // Wait before next attempt (except on last attempt)
        if (attempt < maxAttempts) {
          final delay = delays[attempt - 1];
          debugPrint('[DETECT] Waiting ${delay}ms before next attempt...');
          await Future.delayed(Duration(milliseconds: delay));
        }
      } catch (e) {
        debugPrint('[DETECT] Futronic attempt $attempt failed: $e');

        // Wait before retry on error (except on last attempt)
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 1000));
        }
      }
    }

    debugPrint('[DETECT] ❌ No scanner detected after all attempts');
    return 'none';
  }

  Future<void> _enroll(String finger) async {
    setState(() {
      _isEnrolling = true;
      _enrollmentInProgress = true;
      _lastEnrollmentStart = DateTime.now();
      _enrollmentProtectionStart = DateTime.now();
      _enrollmentStatus = 'Detecting scanner...';
    });

    final scanner = await _detectScanner();
    setState(() {
      _activeScanner = scanner;
    });

    try {
      if (scanner == 'zkteco') {
        // Pre-enrollment cleanup for ZKTeco to prevent "enrollment in progress" errors
        debugPrint('[ENROLL] Pre-enrollment cleanup for ZKTeco');
        try {
          await _fingerprintService.cancelEnrollment().catchError((e) {
            debugPrint('[ENROLL] Pre-cleanup cancel error (expected): $e');
          });
          _fingerprintService.manualReset();
          await Future.delayed(const Duration(milliseconds: 300));
          debugPrint('[ENROLL] Pre-enrollment cleanup completed');
        } catch (e) {
          debugPrint('[ENROLL] Pre-enrollment cleanup error: $e');
        }

        setState(() {
          _enrollmentStatus = 'Enrolling with ZKTeco...';
        });
        // ZKTeco uses the existing stream-based enrollment
        await _fingerprintService.startEnrollment(finger);
      } else if (scanner == 'futronic') {
        setState(() {
          _enrollmentStatus =
              'Enrolling with Futronic... Place your finger on the scanner';
        });

        debugPrint(
            '[FUTRONIC_ENROLL] Starting Futronic enrollment for $finger finger');
        final template = await _futronicService.enroll(finger);

        if (template != null && template.isNotEmpty) {
          // Rely on native Futronic partial detection; no additional Dart-side length check
          debugPrint(
              '[FUTRONIC_ENROLL] Successfully got template, length: ${template.length}');

          // Save to database using the same method as ZKTeco for consistency
          try {
            final bool isSynced = await _databaseHelper.saveFingerprintSmart(
                widget.learnerId, finger, template,
                scannerType: 'futronic');
            debugPrint(
                '[FUTRONIC_ENROLL] Saved Futronic fingerprint for learnerId=${widget.learnerId}, finger=$finger, synced=$isSynced');

            if (!mounted) return;

            // Update UI to reflect successful enrollment
            setState(() {
              if (finger == 'left') {
                _leftThumbEnrolled = true;
                _enrollmentStatus =
                    'Left thumb enrolled successfully with Futronic!';
                _leftEnrollCooldown = 5;
                _leftCooldownTimer?.cancel();
                _leftCooldownTimer =
                    Timer.periodic(const Duration(seconds: 1), (timer) {
                  if (!mounted) return;
                  setState(() {
                    if (_leftEnrollCooldown > 0) {
                      _leftEnrollCooldown--;
                    }
                    if (_leftEnrollCooldown == 0) {
                      _leftCooldownTimer?.cancel();
                    }
                  });
                });
              } else if (finger == 'right') {
                _rightThumbEnrolled = true;
                _enrollmentStatus =
                    'Right thumb enrolled successfully with Futronic!';
                _rightEnrollCooldown = 5;
                _rightCooldownTimer?.cancel();
                _rightCooldownTimer =
                    Timer.periodic(const Duration(seconds: 1), (timer) {
                  if (!mounted) return;
                  setState(() {
                    if (_rightEnrollCooldown > 0) {
                      _rightEnrollCooldown--;
                    }
                    if (_rightEnrollCooldown == 0) {
                      _rightCooldownTimer?.cancel();
                    }
                  });
                });
              }
              _isEnrolling = false;
              _enrollmentInProgress = false;
              _lastEnrollmentStart = null;
              _enrollmentProtectionStart = null;
            });

            // Show success message
            if (isSynced) {
              _showSnackBar(
                  'Futronic fingerprint enrolled and synced to server for $finger thumb');
            } else {
              _showSnackBar(
                  'Futronic fingerprint enrolled locally for $finger thumb (will sync when online)');
            }

            debugPrint(
                '[FUTRONIC_ENROLL] Successfully completed Futronic enrollment for $finger finger');
          } catch (saveError) {
            debugPrint('[FUTRONIC_ENROLL] Error saving template: $saveError');
            setState(() {
              _enrollmentStatus =
                  'Failed to save Futronic fingerprint: $saveError';
              _isEnrolling = false;
              _enrollmentInProgress = false;
              _lastEnrollmentStart = null;
              _enrollmentProtectionStart = null;
            });
            _showSnackBar('Failed to save Futronic fingerprint: $saveError');
          }
        } else {
          debugPrint(
              '[FUTRONIC_ENROLL] No template received from Futronic service');
          setState(() {
            _enrollmentStatus =
                'Futronic enrollment failed - no template captured';
            _isEnrolling = false;
            _enrollmentInProgress = false;
            _lastEnrollmentStart = null;
            _enrollmentProtectionStart = null;
          });
          _showSnackBar('Futronic enrollment failed - please try again');
        }
      } else {
        setState(() {
          _enrollmentStatus = 'No scanner detected! Please connect a scanner.';
          _isEnrolling = false;
          _enrollmentInProgress = false;
          _lastEnrollmentStart = null;
          _enrollmentProtectionStart = null;
        });
        _showSnackBar('No fingerprint scanner detected');
      }
    } catch (e) {
      debugPrint('[ENROLL] Enrollment error: $e');
      setState(() {
        _enrollmentStatus = 'Enrollment failed: $e';
        _isEnrolling = false;
        _enrollmentInProgress = false;
        _lastEnrollmentStart = null;
        _enrollmentProtectionStart = null;
      });
      _showSnackBar('Enrollment failed: $e');
    }
  }

  Future<bool> _verify(String finger) async {
    final scanner = await _detectScanner();
    final templates = await _databaseHelper.getAllTemplates(widget.learnerId);
    if (scanner == 'zkteco') {
      final template = finger == 'left'
          ? templates['zkteco_left_template']
          : templates['zkteco_right_template'];
      return await _fingerprintService.verify(finger, template ?? '');
    } else if (scanner == 'futronic') {
      final template = finger == 'left'
          ? templates['futronic_left_template']
          : templates['futronic_right_template'];
      return await _futronicService.verify(finger, template ?? '');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '[BUILD] leftThumbEnrolled=$_leftThumbEnrolled, rightThumbEnrolled=$_rightThumbEnrolled, leftCooldown=$_leftEnrollCooldown, rightCooldown=$_rightEnrollCooldown, isEnrolling=$_isEnrolling, isInitializing=$_isInitializing, enrollmentInProgress=$_enrollmentInProgress, isSensorConnected=$_isSensorConnected, activeScanner=$_activeScanner');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fingerprint Enrollment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              try {
                setState(() {
                  _enrollmentStatus = 'Syncing fingerprints from server...';
                });

                // Get classID for this learner first
                final classID = await _databaseHelper
                    .getClassIDForLearner(widget.learnerId);
                if (classID != null) {
                  // Trigger a full learner sync to get fingerprint data from server
                  await _databaseHelper.syncLearnersFromServer(classID);
                } else {
                  debugPrint(
                      '[SYNC_ERROR] Could not find classID for learner ${widget.learnerId}');
                }

                await _databaseHelper.syncUnsyncedFingerprints();

                // Refresh enrollment status after sync
                await _checkEnrolledThumbs();

                _showSnackBar('Fingerprint sync completed');
                setState(() {
                  _enrollmentStatus = _isSensorConnected
                      ? 'Scanner ready for enrollment'
                      : 'No scanner detected';
                });
              } catch (e) {
                debugPrint('[SYNC_ERROR] Full sync failed: $e');
                _showSnackBar('Sync failed: $e');
                setState(() {
                  _enrollmentStatus = 'Sync failed: $e';
                });
              }
            },
            tooltip: 'Sync Fingerprints from Server',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              debugPrint('[REFRESH] Manual refresh requested');
              await _checkEnrolledThumbs();
            },
            tooltip: 'Refresh Enrollment Status',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _resetSensor,
            tooltip: 'Reset Sensor',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      _enrollmentStatus,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _activeScanner == 'none'
                            ? Colors.red[100]
                            : Colors.green[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Scanner: ${_activeScanner == 'none' ? 'None Detected' : _activeScanner.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _activeScanner == 'none'
                              ? Colors.red[800]
                              : Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_isEnrolling || _isInitializing)
                const CircularProgressIndicator()
              else
                // --- Refined UI for Left and Right Thumb Enrollment ---
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Use flexible layout for smaller screens
                    if (constraints.maxWidth < 600) {
                      return Column(
                        children: [
                          _buildThumbCard('left'),
                          const SizedBox(height: 16),
                          _buildThumbCard('right'),
                        ],
                      );
                    } else {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(child: _buildThumbCard('left')),
                          Expanded(child: _buildThumbCard('right')),
                        ],
                      );
                    }
                  },
                ),
              const SizedBox(height: 16),
              // Add scanner detection controls
              if (_activeScanner == 'none')
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        setState(() {
                          _enrollmentStatus = 'Forcing scanner detection...';
                          _isInitializing = true;
                        });
                        await _initializeSensor();
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Force Detect Scanner'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No scanner detected. Try connecting your scanner and tap "Force Detect Scanner"',
                      style: TextStyle(color: Colors.orange[800], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              const SizedBox(height: 8),
              // --- End Refined UI ---
              const SizedBox(height: 20),
              // Require both thumbs enrolled before leaving the page
              ElevatedButton.icon(
                onPressed: (_leftThumbEnrolled &&
                        _rightThumbEnrolled &&
                        !_isEnrolling &&
                        !_isInitializing)
                    ? () {
                        Navigator.of(context).maybePop();
                      }
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Done (Both thumbs must be enrolled)'),
                style:
                    ElevatedButton.styleFrom(minimumSize: const Size(220, 44)),
              ),
              const SizedBox(height: 12),
              // Debug info section
              if (true) // Set to false to hide debug info
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Debug Info:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      Text('Scanner: $_activeScanner',
                          style: TextStyle(fontSize: 10)),
                      Text('Connected: $_isSensorConnected',
                          style: TextStyle(fontSize: 10)),
                      Text('Left Enrolled: $_leftThumbEnrolled',
                          style: TextStyle(fontSize: 10)),
                      Text('Right Enrolled: $_rightThumbEnrolled',
                          style: TextStyle(fontSize: 10)),
                      Text('Is Enrolling: $_isEnrolling',
                          style: TextStyle(fontSize: 10)),
                      Text('Is Initializing: $_isInitializing',
                          style: TextStyle(fontSize: 10)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              debugPrint('[FORCE_RESET] Force reset requested');
                              _fingerprintService.manualReset();
                              setState(() {
                                _isEnrolling = false;
                                _enrollmentInProgress = false;
                                _lastEnrollmentStart = null;
                                _enrollmentProtectionStart = null;
                              });
                              _showSnackBar('Force reset completed');
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: const Size(0, 30),
                            ),
                            child: const Text('Force Reset',
                                style: TextStyle(fontSize: 10)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              debugPrint(
                                  '[FORCE_CLEANUP] Force cleanup requested');
                              await _cleanupPreviousScanner(_activeScanner);
                              _showSnackBar('Force cleanup completed');
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: const Size(0, 30),
                            ),
                            child: const Text('Force Cleanup',
                                style: TextStyle(fontSize: 10)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _leftThumbEnrolled
                          ? Colors.green[100]
                          : Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Left Thumb: ${_leftThumbEnrolled ? 'Enrolled' : 'Not Enrolled'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _leftThumbEnrolled
                            ? Colors.green[800]
                            : Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _rightThumbEnrolled
                          ? Colors.green[100]
                          : Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Right Thumb: ${_rightThumbEnrolled ? 'Enrolled' : 'Not Enrolled'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _rightThumbEnrolled
                            ? Colors.green[800]
                            : Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _leftCooldownTimer?.cancel();
    _rightCooldownTimer?.cancel();
    // Clear enrollment locks
    _isEnrolling = false;
    _enrollmentInProgress = false;
    _lastEnrollmentStart = null;
    _enrollmentProtectionStart = null; // Clear on dispose
    // Clear emergency block on dispose (temporarily disabled)
    // _fingerprintService.setEmergencyBlock(false);
    // Ensure cleanup on dispose
    _fingerprintService.cancelEnrollment().catchError((e) => null);
    _fingerprintService.dispose();
    super.dispose();
  }
}
