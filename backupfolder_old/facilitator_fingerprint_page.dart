import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:rlmss/services/fingerprint_service.dart';
import 'package:rlmss/database_helper.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'config.dart';
import 'utils/fingerprint_error_handler.dart';
import 'package:signature/signature.dart';

class FacilitatorFingerprintPage extends StatefulWidget {
  final int facilitatorId;
  final String facilitatorName;
  final bool
      isFirstTimeSetup; // True if this is initial setup, false if just clocking
  final bool requireClockIn; // True if clock-in is required before proceeding
  final String?
      nextRoute; // Route to navigate to after fingerprint verification
  final dynamic routeArguments; // Arguments to pass to the next route

  const FacilitatorFingerprintPage({
    super.key,
    required this.facilitatorId,
    required this.facilitatorName,
    this.isFirstTimeSetup = false,
    this.requireClockIn = false,
    this.nextRoute,
    this.routeArguments,
  });

  @override
  _FacilitatorFingerprintPageState createState() =>
      _FacilitatorFingerprintPageState();
}

class _FacilitatorFingerprintPageState
    extends State<FacilitatorFingerprintPage> {
  final FingerprintService _fingerprintService = FingerprintService();
  final FutronicService _futronicService = FutronicService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _isSensorConnected = false;
  String _enrollmentStatus = 'Initializing sensor...';
  bool _leftThumbEnrolled = false;
  bool _rightThumbEnrolled = false;
  bool _isEnrolling = false;
  bool _isInitializing = false;
  bool _enrollmentInProgress = false;

  // Stream subscriptions for proper disposal
  StreamSubscription? _enrollStatusSubscription;
  StreamSubscription? _enrollSuccessSubscription;
  String _activeScanner = 'auto'; // 'zkteco', 'futronic', or 'none'
  bool _isClocking = false; // Track if we're in clocking mode
  String? _clockingAction; // 'in' or 'out'
  SignatureController? _signatureController;
  bool?
      _hasScannerAvailable; // null = not asked, true = has scanner, false = no scanner
  bool _isCheckingClockIn = true; // Track if we're checking clock-in status

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyClockedIn(); // This will call _checkEnrolledThumbs() internally
    _setupStreamListeners();
  }

  @override
  void dispose() {
    // Cancel all subscriptions BEFORE disposing the service
    _enrollStatusSubscription?.cancel();
    _enrollSuccessSubscription?.cancel();

    // Dispose the fingerprint service AFTER cancelling subscriptions
    _fingerprintService.dispose();

    super.dispose();
  }

  // Check if facilitator already clocked in today
  Future<void> _checkIfAlreadyClockedIn() async {
    debugPrint(
        '[FAC_CHECK] Checking if facilitator already clocked in today...');
    debugPrint('[FAC_CHECK] requireClockIn: ${widget.requireClockIn}');
    debugPrint('[FAC_CHECK] isFirstTimeSetup: ${widget.isFirstTimeSetup}');

    // If not requiring clock-in (e.g., just managing fingerprints), skip clock-in check
    if (!widget.requireClockIn && !widget.isFirstTimeSetup) {
      debugPrint(
          '[FAC_CHECK] Skipping clock-in check - just managing fingerprints');

      // Sync fingerprint data from server
      await _checkEnrolledThumbs();

      setState(() {
        _isCheckingClockIn = false;
      });

      // Ask about scanner availability
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _askScannerAvailability();
        }
      });
      return;
    }

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final attendance = await _databaseHelper.getFacilitatorAttendanceForDay(
          widget.facilitatorId.toString(), today);

      debugPrint('[FAC_CHECK] Today attendance: $attendance');

      if (attendance != null && attendance['clock_in_time'] != null) {
        debugPrint(
            '[FAC_CHECK] ✅ Already clocked in today - navigating to dashboard');

        setState(() {
          _isCheckingClockIn = false;
        });

        // Already clocked in, navigate to dashboard
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;

          if (widget.nextRoute != null) {
            Navigator.pushReplacementNamed(
              context,
              widget.nextRoute!,
              arguments: widget.routeArguments,
            );
          } else {
            Navigator.pop(context, true);
          }
        }
      } else {
        debugPrint('[FAC_CHECK] ❌ Not clocked in yet - syncing data first...');

        // First sync fingerprint data from server, then show scanner dialog
        await _checkEnrolledThumbs();

        setState(() {
          _isCheckingClockIn = false;
        });

        // After syncing, ask about scanner availability
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _askScannerAvailability();
          }
        });
      }
    } catch (e) {
      debugPrint('[FAC_CHECK] Error checking clock-in status: $e');

      // Even on error, sync fingerprint data first
      try {
        await _checkEnrolledThumbs();
      } catch (syncError) {
        debugPrint('[FAC_CHECK] Error syncing enrolled thumbs: $syncError');
      }

      setState(() {
        _isCheckingClockIn = false;
      });

      // After syncing, ask about scanner availability
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _askScannerAvailability();
        }
      });
    }
  }

  // Ask if scanner is available
  Future<void> _askScannerAvailability() async {
    debugPrint('[FAC_SCANNER] Asking about scanner availability...');

    // Skip if already answered
    if (_hasScannerAvailable != null) {
      debugPrint(
          '[FAC_SCANNER] Scanner availability already determined: $_hasScannerAvailable');
      return;
    }

    final hasScanner = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Fingerprint Scanner'),
          content: const Text(
            'Do you have a fingerprint scanner available and connected?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
              child: const Text('No', style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Yes', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );

    debugPrint('[FAC_SCANNER] Scanner available: $hasScanner');

    setState(() {
      _hasScannerAvailable = hasScanner ?? false;
    });

    if (hasScanner == true) {
      // User has scanner, initialize it
      _initializeSensor();
    } else {
      // No scanner, set status accordingly
      setState(() {
        _enrollmentStatus = 'Use signature to clock in/out';
        _isSensorConnected = false;
        _activeScanner = 'none';
      });
    }
  }

  // Sync facilitator clock-in to server
  Future<bool> _syncClockInToServer(Map<String, dynamic> attendance) async {
    debugPrint('[FAC_SYNC] ========== CLOCK-IN SYNC STARTED ==========');

    try {
      debugPrint('[FAC_SYNC] Step 1: Checking connectivity...');
      final connectivityResult = await Connectivity().checkConnectivity();
      debugPrint('[FAC_SYNC] Connectivity: $connectivityResult');

      if (connectivityResult.first == ConnectivityResult.none) {
        debugPrint('[FAC_SYNC] ❌ No internet connection');
        return false;
      }

      debugPrint('[FAC_SYNC] Step 2: Preparing server data...');
      // Prepare data for server
      final serverData = {
        'facilitator_id': attendance['facilitator_id'].toString(),
        'clock_in_time': attendance['clock_in_time'],
        'clock_date': attendance['clock_date'],
        'user_latitude': attendance['user_latitude'] ?? '0.0',
        'user_longitude': attendance['user_longitude'] ?? '0.0',
        'user_accuracy': attendance['user_accuracy'] ?? '10.0',
      };

      debugPrint('[FAC_SYNC] Server data: $serverData');

      debugPrint('[FAC_SYNC] Step 3: Building URL...');
      final url = Uri.parse(AppConfig.facilitatorClockinUrl);
      debugPrint('[FAC_SYNC] URL: $url');
      debugPrint('[FAC_SYNC] Base URL: ${AppConfig.baseUrl}');

      debugPrint('[FAC_SYNC] Step 4: Sending HTTP POST request...');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(serverData),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[FAC_SYNC] Response status: ${response.statusCode}');
      debugPrint('[FAC_SYNC] Response body: ${response.body}');
      debugPrint('[FAC_SYNC] Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        debugPrint('[FAC_SYNC] Step 5: Parsing response...');
        try {
          final result = jsonDecode(response.body);
          debugPrint('[FAC_SYNC] Parsed result: $result');

          if (result['success'] == true) {
            debugPrint('[FAC_SYNC] ✅ Server sync successful');
            return true;
          } else {
            debugPrint(
                '[FAC_SYNC] ❌ Server returned error: ${result['message']}');
            return false;
          }
        } catch (parseError) {
          debugPrint('[FAC_SYNC] ❌ JSON parse error: $parseError');
          debugPrint('[FAC_SYNC] Raw response: ${response.body}');
          return false;
        }
      } else {
        debugPrint(
            '[FAC_SYNC] ❌ Server returned status ${response.statusCode}');
        debugPrint('[FAC_SYNC] Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[FAC_SYNC] ❌ Sync error: $e');
      debugPrint('[FAC_SYNC] Stack trace: ${StackTrace.current}');
      return false;
    } finally {
      debugPrint('[FAC_SYNC] ========== CLOCK-IN SYNC COMPLETED ==========');
    }
  }

  // Sync facilitator clock-out to server
  Future<bool> _syncClockOutToServer(Map<String, dynamic> attendance) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.first == ConnectivityResult.none) {
        debugPrint('[FAC_SYNC] No internet connection');
        return false;
      }

      // Prepare data for server
      final serverData = {
        'facilitator_id': attendance['facilitator_id'].toString(),
        'clock_out_time': attendance['clock_out_time'],
        'contact_time': attendance['contact_time'],
        'clock_date': attendance['clock_date'],
      };

      // TODO: Replace with your actual server endpoint
      final url = Uri.parse(AppConfig.facilitatorClockoutUrl);

      debugPrint('[FAC_SYNC] Syncing clock-out to server: $url');
      debugPrint('[FAC_SYNC] Data: $serverData');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(serverData),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('[FAC_SYNC] Clock-out sync successful');
          return true;
        } else {
          debugPrint('[FAC_SYNC] Server returned error: ${result['message']}');
          return false;
        }
      } else {
        debugPrint('[FAC_SYNC] Server returned status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[FAC_SYNC] Sync error: $e');
      return false;
    }
  }

  Future<void> _checkEnrolledThumbs() async {
    debugPrint(
        '[FAC_FP] Checking enrolled thumbs for facilitator ${widget.facilitatorId}');

    // Step 1: Check if online and sync from server first
    await _syncFacilitatorDataFromServer();

    final scanner = await _detectScanner();

    setState(() {
      _activeScanner = scanner;
      _isSensorConnected = scanner != 'none';
    });

    final templates =
        await _databaseHelper.getAllFacilitatorTemplates(widget.facilitatorId);
    debugPrint('[FAC_FP] Fetched facilitator templates: $templates');

    bool leftEnrolled = false;
    bool rightEnrolled = false;

    if (scanner == 'zkteco') {
      leftEnrolled = templates['zkteco_left_template'] != null &&
          templates['zkteco_left_template']!.isNotEmpty;
      rightEnrolled = templates['zkteco_right_template'] != null &&
          templates['zkteco_right_template']!.isNotEmpty;
      debugPrint(
          '[FAC_FP] ZKTeco enrollment status: left=$leftEnrolled, right=$rightEnrolled');
    } else if (scanner == 'futronic') {
      leftEnrolled = templates['futronic_left_template'] != null &&
          templates['futronic_left_template']!.isNotEmpty;
      rightEnrolled = templates['futronic_right_template'] != null &&
          templates['futronic_right_template']!.isNotEmpty;
      debugPrint(
          '[FAC_FP] Futronic enrollment status: left=$leftEnrolled, right=$rightEnrolled');
    } else {
      leftEnrolled = (templates['zkteco_left_template'] != null &&
              templates['zkteco_left_template']!.isNotEmpty) ||
          (templates['futronic_left_template'] != null &&
              templates['futronic_left_template']!.isNotEmpty);
      rightEnrolled = (templates['zkteco_right_template'] != null &&
              templates['zkteco_right_template']!.isNotEmpty) ||
          (templates['futronic_right_template'] != null &&
              templates['futronic_right_template']!.isNotEmpty);
      debugPrint(
          '[FAC_FP] No scanner - any enrollment status: left=$leftEnrolled, right=$rightEnrolled');
    }

    setState(() {
      _leftThumbEnrolled = leftEnrolled;
      _rightThumbEnrolled = rightEnrolled;

      if (scanner == 'none') {
        if (leftEnrolled || rightEnrolled) {
          _enrollmentStatus =
              'Fingerprints enrolled on other scanner. Connect scanner and tap refresh.';
        } else {
          _enrollmentStatus =
              'No scanner detected. Please connect a scanner and tap refresh.';
        }
      } else if (leftEnrolled && rightEnrolled) {
        _enrollmentStatus = widget.isFirstTimeSetup
            ? 'Both thumbs enrolled! You can now proceed.'
            : 'Both thumbs enrolled. Place finger to clock ${_clockingAction ?? 'in/out'}.';
      } else if (leftEnrolled) {
        _enrollmentStatus =
            'Left thumb enrolled. Right thumb ready for enrollment.';
      } else if (rightEnrolled) {
        _enrollmentStatus =
            'Right thumb enrolled. Left thumb ready for enrollment.';
      } else {
        _enrollmentStatus = widget.isFirstTimeSetup
            ? 'Welcome! Please enroll at least one fingerprint to continue.'
            : 'No fingerprints enrolled. Please enroll to clock in.';
      }
    });
  }

  // Sync facilitator data from server (templates + basic info)
  Future<void> _syncFacilitatorDataFromServer() async {
    try {
      debugPrint(
          '[FAC_SYNC] Checking connectivity for facilitator data sync...');
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult.first == ConnectivityResult.none) {
        debugPrint('[FAC_SYNC] Offline - using local data only');
        return;
      }

      debugPrint('[FAC_SYNC] Online - syncing facilitator data from server...');
      final url = Uri.parse('${AppConfig.baseUrl}/sync_facilitator.php');

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List facilitatorData = json.decode(response.body);
        debugPrint(
            '[FAC_SYNC] Received ${facilitatorData.length} facilitators from server');

        // Find current facilitator
        final currentFacilitator = facilitatorData.firstWhere(
          (f) =>
              f['facilitator_id'].toString() == widget.facilitatorId.toString(),
          orElse: () => null,
        );

        if (currentFacilitator != null) {
          debugPrint(
              '[FAC_SYNC] Found current facilitator on server: ${currentFacilitator['firstName']} ${currentFacilitator['lastName']}');

          // Update local database with server data (including templates)
          final db = await _databaseHelper.database;
          await db.insert(
            'facilitator',
            {
              'facilitator_id': currentFacilitator['facilitator_id'],
              'firstName': currentFacilitator['firstName'],
              'lastName': currentFacilitator['lastName'],
              'role': currentFacilitator['role'],
              'email': currentFacilitator['email'],
              'classID': currentFacilitator['classID'],
              'password': currentFacilitator['password'],
              'assessorNo': currentFacilitator['assessorNo'],
              'f_signature': currentFacilitator['f_signature'],
              'phoneNumber': currentFacilitator['phoneNumber'],
              'f_profile': currentFacilitator['f_profile'],
              'f_IDNumber': currentFacilitator['f_IDNumber'],
              'serial_number': currentFacilitator['serial_number'],
              'workNumber': currentFacilitator['workNumber'],
              'zkteco_left_template':
                  currentFacilitator['zkteco_left_template'],
              'zkteco_right_template':
                  currentFacilitator['zkteco_right_template'],
              'futronic_left_template':
                  currentFacilitator['futronic_left_template'],
              'futronic_right_template':
                  currentFacilitator['futronic_right_template'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          debugPrint('[FAC_SYNC] ✅ Synced facilitator data to local database');
        } else {
          debugPrint(
              '[FAC_SYNC] ⚠️ Facilitator ${widget.facilitatorId} not found on server');
        }
      } else {
        debugPrint('[FAC_SYNC] Server returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FAC_SYNC] Error syncing facilitator data: $e');
      // Continue with local data
    }
  }

  // Refresh scanner connection
  Future<void> _refreshScannerConnection() async {
    debugPrint('[FAC_FP] Refreshing scanner connection...');

    setState(() {
      _enrollmentStatus = 'Checking scanner connection...';
      _isInitializing = true;
    });

    try {
      // Re-initialize sensor
      await _initializeSensor();

      // Re-check enrolled thumbs
      await _checkEnrolledThumbs();

      if (mounted) {
        if (_isSensorConnected) {
          FingerprintErrorHandler.showSuccess(
              context, 'Scanner connected: $_activeScanner');
        } else {
          FingerprintErrorHandler.showError(context,
              'No scanner detected. Please check connection and try again.');
        }
      }
    } catch (e) {
      debugPrint('[FAC_FP] Error refreshing scanner: $e');
      if (mounted) {
        setState(() {
          _enrollmentStatus = 'Error checking scanner: $e';
        });
        FingerprintErrorHandler.showError(context, 'Scanner connection error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  void _setupStreamListeners() {
    _enrollStatusSubscription =
        _fingerprintService.enrollStatusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _enrollmentStatus = status;
        if (status.toLowerCase().contains('error') ||
            status.toLowerCase().contains('failed')) {
          _isEnrolling = false;
          _enrollmentInProgress = false;
          _isClocking = false;
        }
      });
    });

    // Note: ZKTeco verification uses direct method calls, not streams
    // The verification result is handled in the _verifyAndClock method

    _enrollSuccessSubscription =
        _fingerprintService.enrollSuccessStream.listen((result) async {
      if (!mounted) return;

      final finger = result['finger'] as String?;
      final template = result['template'];

      if (finger == null || template == null) {
        setState(() {
          _enrollmentStatus = 'Invalid enrollment data received';
          _isEnrolling = false;
        });
        return;
      }

      try {
        if (_isClocking) {
          // Handle fingerprint verification for clocking
          await _handleClockingVerification(template.toString());
        } else {
          // Handle fingerprint enrollment
          await _saveFacilitatorFingerprint(finger, template.toString());
        }
      } catch (e) {
        debugPrint('[FAC_FP] Error processing fingerprint: $e');
        if (mounted) {
          setState(() {
            _enrollmentStatus = 'Error: $e';
            _isEnrolling = false;
            _isClocking = false;
          });
        }
      }
    });
  }

  Future<void> _saveFacilitatorFingerprint(
      String finger, String template) async {
    try {
      debugPrint(
          '[FAC_FP] Saving fingerprint for facilitator ${widget.facilitatorId}, scanner: $_activeScanner, finger: $finger');

      // Check if template matches existing templates before saving
      final existingTemplates = await _databaseHelper
          .getAllFacilitatorTemplates(widget.facilitatorId);
      bool templateMatches = false;
      String matchedTemplate = '';

      if (_activeScanner == 'zkteco') {
        // Check against ZKTeco templates
        final leftTemplate = existingTemplates['zkteco_left_template'];
        final rightTemplate = existingTemplates['zkteco_right_template'];

        if (leftTemplate != null && leftTemplate.isNotEmpty) {
          try {
            final match = await _fingerprintService.matchTemplates(
                leftTemplate, template);
            if (match) {
              templateMatches = true;
              matchedTemplate = 'existing left template';
            }
          } catch (e) {
            debugPrint('[FAC_FP] Error matching with left template: $e');
          }
        }

        if (!templateMatches &&
            rightTemplate != null &&
            rightTemplate.isNotEmpty) {
          try {
            final match = await _fingerprintService.matchTemplates(
                rightTemplate, template);
            if (match) {
              templateMatches = true;
              matchedTemplate = 'existing right template';
            }
          } catch (e) {
            debugPrint('[FAC_FP] Error matching with right template: $e');
          }
        }
      } else if (_activeScanner == 'futronic') {
        // Check against Futronic templates
        final leftTemplate = existingTemplates['futronic_left_template'];
        final rightTemplate = existingTemplates['futronic_right_template'];

        if (leftTemplate != null && leftTemplate.isNotEmpty) {
          try {
            final match = await _futronicService.verify('left', leftTemplate);
            if (match) {
              templateMatches = true;
              matchedTemplate = 'existing left template';
            }
          } catch (e) {
            debugPrint('[FAC_FP] Error matching with left template: $e');
          }
        }

        if (!templateMatches &&
            rightTemplate != null &&
            rightTemplate.isNotEmpty) {
          try {
            final match = await _futronicService.verify('right', rightTemplate);
            if (match) {
              templateMatches = true;
              matchedTemplate = 'existing right template';
            }
          } catch (e) {
            debugPrint('[FAC_FP] Error matching with right template: $e');
          }
        }
      }

      if (templateMatches) {
        debugPrint(
            '[FAC_FP] Template matches $matchedTemplate - this appears to be the same finger!');
        if (mounted) {
          // Show dialog to ask if user wants to replace existing template
          final shouldReplace = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Duplicate Fingerprint Detected'),
                content: Text(
                    'This fingerprint matches your $matchedTemplate. Do you want to replace it with this new scan?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Replace'),
                  ),
                ],
              );
            },
          );

          if (shouldReplace == true) {
            debugPrint('[FAC_FP] User chose to replace existing template');
            // Continue with saving (will overwrite existing template)
          } else {
            setState(() {
              _enrollmentStatus =
                  'Enrollment cancelled. Please use a different finger.';
              _isEnrolling = false;
            });
            return; // Don't save duplicate template
          }
        } else {
          return; // Don't save duplicate template
        }
      }

      // Show saving message
      if (mounted) {
        setState(() {
          _enrollmentStatus = 'Saving $finger thumb fingerprint...';
        });
      }

      // Save and sync
      final synced = await _databaseHelper.saveFacilitatorTemplate(
        widget.facilitatorId,
        _activeScanner,
        finger,
        template,
      );

      debugPrint(
          '[FAC_FP] Saved fingerprint: facilitator=${widget.facilitatorId}, scanner=$_activeScanner, finger=$finger, synced=$synced');

      if (!mounted) return;

      // Show success message for new unique template
      if (mounted) {
        if (synced) {
          FingerprintErrorHandler.showSuccess(
              context, '${finger.toUpperCase()} thumb enrolled and synced!');
        } else {
          FingerprintErrorHandler.showInfo(context,
              '${finger.toUpperCase()} thumb enrolled locally (will sync later)');
        }
      }

      setState(() {
        if (finger == 'left') {
          _leftThumbEnrolled = true;
          _enrollmentStatus = synced
              ? 'Left thumb enrolled and synced to server!'
              : 'Left thumb enrolled locally (will sync when online)';
        } else {
          _rightThumbEnrolled = true;
          _enrollmentStatus = synced
              ? 'Right thumb enrolled and synced to server!'
              : 'Right thumb enrolled locally (will sync when online)';
        }
        _isEnrolling = false;
        _enrollmentInProgress = false;
      });

      // Message already shown above, this is duplicate - remove it

      // If this is first time setup and both thumbs are enrolled, show option to proceed
      if (widget.isFirstTimeSetup &&
          _leftThumbEnrolled &&
          _rightThumbEnrolled) {
        _showProceedDialog();
      }
    } catch (e) {
      debugPrint('[FAC_FP] Error saving fingerprint: $e');
      if (mounted) {
        setState(() {
          _enrollmentStatus = 'Error saving fingerprint: $e';
          _isEnrolling = false;
        });

        FingerprintErrorHandler.showError(
            context, 'Fingerprint enrollment failed');
      }
    }
  }

  Future<void> _handleClockingVerification(String scannedTemplate) async {
    debugPrint('[FAC_FP] ========== CLOCKING VERIFICATION STARTED ==========');
    debugPrint('[FAC_FP] Facilitator ID: ${widget.facilitatorId}');
    debugPrint('[FAC_FP] Active Scanner: $_activeScanner');
    debugPrint('[FAC_FP] Clocking Action: $_clockingAction');
    debugPrint('[FAC_FP] Scanned Template Length: ${scannedTemplate.length}');

    try {
      debugPrint('[FAC_FP] Step 1: Getting templates from database...');
      final templates = await _databaseHelper
          .getAllFacilitatorTemplates(widget.facilitatorId);
      debugPrint('[FAC_FP] Available templates: $templates');

      bool match = false;
      String matchDetails = '';

      if (_activeScanner == 'zkteco') {
        debugPrint('[FAC_FP] Step 2: Using ZKTeco verification...');
        final leftTemplate = templates['zkteco_left_template'];
        final rightTemplate = templates['zkteco_right_template'];

        debugPrint(
            '[FAC_FP] Left template available: ${leftTemplate != null && leftTemplate.isNotEmpty}');
        debugPrint(
            '[FAC_FP] Right template available: ${rightTemplate != null && rightTemplate.isNotEmpty}');

        if (leftTemplate != null && leftTemplate.isNotEmpty) {
          debugPrint('[FAC_FP] Step 3a: Checking left template...');
          match = await _fingerprintService.matchTemplates(
              leftTemplate, scannedTemplate);
          debugPrint('[FAC_FP] ZKTeco left template match: $match');
          if (match) matchDetails = 'left template';
        }
        if (!match && rightTemplate != null && rightTemplate.isNotEmpty) {
          debugPrint('[FAC_FP] Step 3b: Checking right template...');
          match = await _fingerprintService.matchTemplates(
              rightTemplate, scannedTemplate);
          debugPrint('[FAC_FP] ZKTeco right template match: $match');
          if (match) matchDetails = 'right template';
        }
      } else if (_activeScanner == 'futronic') {
        debugPrint('[FAC_FP] Step 2: Using Futronic verification...');
        final leftTemplate = templates['futronic_left_template'];
        final rightTemplate = templates['futronic_right_template'];

        debugPrint(
            '[FAC_FP] Left template available: ${leftTemplate != null && leftTemplate.isNotEmpty}');
        debugPrint(
            '[FAC_FP] Right template available: ${rightTemplate != null && rightTemplate.isNotEmpty}');

        // Try to verify with left template first
        if (leftTemplate != null && leftTemplate.isNotEmpty) {
          debugPrint('[FAC_FP] Step 3a: Checking left template...');
          try {
            match = await _futronicService.verify('left', leftTemplate);
            debugPrint('[FAC_FP] Futronic left template match: $match');
            if (match) matchDetails = 'left template';
          } catch (e) {
            debugPrint('[FAC_FP] Futronic left verification error: $e');
          }
        }

        // If left didn't match, try right template
        if (!match && rightTemplate != null && rightTemplate.isNotEmpty) {
          debugPrint('[FAC_FP] Step 3b: Checking right template...');
          try {
            match = await _futronicService.verify('right', rightTemplate);
            debugPrint('[FAC_FP] Futronic right template match: $match');
            if (match) matchDetails = 'right template';
          } catch (e) {
            debugPrint('[FAC_FP] Futronic right verification error: $e');
          }
        }
      } else {
        debugPrint('[FAC_FP] ERROR: No active scanner detected!');
      }

      debugPrint(
          '[FAC_FP] Step 4: Verification result - Match: $match, Details: $matchDetails');

      if (match) {
        debugPrint(
            '[FAC_FP] ========== FINGERPRINT MATCHED! PROCEEDING WITH CLOCKING ==========');
        if (mounted) {
          FingerprintErrorHandler.showSuccess(
              context, 'Fingerprint verified! Clocking in...');
        }
        await _performClocking();
      } else {
        debugPrint(
            '[FAC_FP] ========== FINGERPRINT VERIFICATION FAILED ==========');
        if (mounted) {
          FingerprintErrorHandler.showError(context,
              'Fingerprint not recognized. Please try with your enrolled finger.');
          setState(() {
            _isClocking = false;
            _enrollmentStatus = 'Verification failed. Please try again.';
          });
        }
      }
    } catch (e) {
      debugPrint('[FAC_FP] ========== VERIFICATION ERROR ==========');
      debugPrint('[FAC_FP] Error: $e');
      debugPrint('[FAC_FP] Stack trace: ${StackTrace.current}');

      if (mounted) {
        setState(() {
          _isClocking = false;
          _enrollmentStatus = 'Verification error: $e';
        });

        FingerprintErrorHandler.showError(
            context, 'Fingerprint verification failed. Please try again.');
      }
    }

    debugPrint(
        '[FAC_FP] ========== CLOCKING VERIFICATION COMPLETED ==========');
  }

  Future<void> _performClocking() async {
    debugPrint('[FAC_CLOCK] ========== PERFORMING CLOCKING ==========');
    debugPrint('[FAC_CLOCK] Action: $_clockingAction');
    debugPrint('[FAC_CLOCK] Facilitator ID: ${widget.facilitatorId}');

    try {
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      debugPrint('[FAC_CLOCK] Current time: $now');
      debugPrint('[FAC_CLOCK] Current date: $date');

      if (_clockingAction == 'in') {
        debugPrint('[FAC_CLOCK] ========== CLOCK-IN PROCESS ==========');

        // Clock in
        final attendance = {
          'facilitator_id': widget.facilitatorId,
          'clock_in_time': now,
          'clock_date': date,
          'synced': 0,
          'user_latitude': '0.0',
          'user_longitude': '0.0',
          'user_accuracy': '10.0',
        };

        debugPrint('[FAC_CLOCK] Attendance data: $attendance');

        // Save to local database first
        debugPrint('[FAC_CLOCK] Step 1: Saving to local database...');
        await _databaseHelper.insertFacilitatorClocking(attendance);
        debugPrint('[FAC_CLOCK] ✅ Saved clock-in to local database');

        // Check connectivity
        debugPrint('[FAC_CLOCK] Step 2: Checking connectivity...');
        final connectivityResult = await Connectivity().checkConnectivity();
        debugPrint('[FAC_CLOCK] Connectivity result: $connectivityResult');

        // Try to sync to server
        bool synced = false;
        if (connectivityResult.first != ConnectivityResult.none) {
          debugPrint('[FAC_CLOCK] Step 3: Online - attempting server sync...');
          try {
            synced = await _syncClockInToServer(attendance);
            debugPrint('[FAC_CLOCK] Server sync result: $synced');

            if (synced) {
              debugPrint(
                  '[FAC_CLOCK] Step 4: Updating local record as synced...');
              // Update local record to mark as synced
              final todayAttendance =
                  await _databaseHelper.getFacilitatorAttendanceForDay(
                      widget.facilitatorId.toString(), date);
              debugPrint(
                  '[FAC_CLOCK] Today attendance record: $todayAttendance');

              if (todayAttendance != null) {
                await _databaseHelper.updateFacilitatorClocking(
                    todayAttendance['clocking_id'], {'synced': 1});
                debugPrint('[FAC_CLOCK] ✅ Updated local record as synced');
              } else {
                debugPrint(
                    '[FAC_CLOCK] ⚠️ No attendance record found to update');
              }
              debugPrint(
                  '[FAC_CLOCK] ✅ Clock-in synced to server successfully');
            } else {
              debugPrint(
                  '[FAC_CLOCK] ❌ Server sync failed - saved locally only');
            }
          } catch (e) {
            debugPrint('[FAC_CLOCK] ❌ Error syncing to server: $e');
            debugPrint('[FAC_CLOCK] Stack trace: ${StackTrace.current}');
          }
        } else {
          debugPrint('[FAC_CLOCK] Step 3: Offline - skipping server sync');
        }

        debugPrint('[FAC_CLOCK] Step 5: Showing result to user...');
        if (mounted) {
          if (synced) {
            FingerprintErrorHandler.showSuccess(
                context, 'Clock-in synced to server!');
          } else {
            FingerprintErrorHandler.showInfo(
                context, 'Clock-in saved locally (will sync when online)');
          }

          debugPrint('[FAC_CLOCK] Step 6: Navigating back to main...');
          // Always return true to indicate successful clock-in
          // This allows main.dart to proceed to dashboard
          Navigator.pop(context, true);
        }
      } else if (_clockingAction == 'out') {
        // Clock out
        final existingAttendance =
            await _databaseHelper.getFacilitatorAttendanceForDay(
          widget.facilitatorId.toString(),
          date,
        );

        if (existingAttendance == null ||
            existingAttendance['clock_in_time'] == null) {
          if (mounted) {
            FingerprintErrorHandler.showInfo(
                context, 'Cannot clock out. No prior clock-in found.');
          }
          return;
        }

        final clockInTime = existingAttendance['clock_in_time'].toString();
        final contactTime = _calculateContactTime(clockInTime, now);

        final updatedAttendance = {
          'clock_out_time': now,
          'contact_time': contactTime,
          'synced': 0,
        };

        // Update local database first
        await _databaseHelper.updateFacilitatorClocking(
          existingAttendance['clocking_id'],
          updatedAttendance,
        );
        debugPrint('[FAC_CLOCK] Saved clock-out to local database');

        // Try to sync to server
        bool synced = false;
        try {
          final serverData = {
            'facilitator_id': widget.facilitatorId,
            'clock_out_time': now,
            'contact_time': contactTime,
            'clock_date': date,
          };
          synced = await _syncClockOutToServer(serverData);
          if (synced) {
            // Update local record to mark as synced
            await _databaseHelper.updateFacilitatorClocking(
                existingAttendance['clocking_id'], {'synced': 1});
            debugPrint('[FAC_CLOCK] Clock-out synced to server successfully');
          } else {
            debugPrint('[FAC_CLOCK] Clock-out saved locally, will sync later');
          }
        } catch (e) {
          debugPrint('[FAC_CLOCK] Error syncing clock-out to server: $e');
        }

        if (mounted) {
          if (synced) {
            FingerprintErrorHandler.showSuccess(
                context, 'Clock-out synced! Contact time: $contactTime');
          } else {
            FingerprintErrorHandler.showInfo(
                context, 'Clock-out saved locally! Contact time: $contactTime');
          }
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint('[FAC_FP] Error performing clocking: $e');
      if (mounted) {
        FingerprintErrorHandler.showError(
            context, 'Clock-in failed. Please try again.');
      }
    }
  }

  String _calculateContactTime(String clockIn, String clockOut) {
    try {
      final inTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse(clockIn);
      final outTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse(clockOut);
      final duration = outTime.difference(inTime);
      final hours = duration.inHours;
      final minutes = (duration.inMinutes % 60);
      final seconds = (duration.inSeconds % 60);
      return "${hours}h ${minutes}m ${seconds}s";
    } catch (_) {
      return "0h 0m 0s";
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

  Future<void> _initializeSensor() async {
    if (_isInitializing) return;

    setState(() {
      _isInitializing = true;
      _enrollmentStatus = 'Checking sensor connection...';
    });

    try {
      await _fingerprintService.cancelEnrollment().catchError((e) {
        debugPrint(
            '[FAC_FP] Cancel enrollment error (expected on first run): $e');
      });

      await Future.delayed(const Duration(milliseconds: 500));

      final isConnected = await _fingerprintService.isSensorConnected();
      if (!mounted) return;

      setState(() {
        _isSensorConnected = isConnected;
        _enrollmentStatus =
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
        _enrollmentStatus = 'Error initializing sensor: $e';
        _isSensorConnected = false;
        _isInitializing = false;
      });
      FingerprintErrorHandler.showError(
          context, 'Scanner initialization failed');
    }
  }

  Future<void> _enrollThumb(String finger) async {
    if (_isEnrolling || _enrollmentInProgress || _isInitializing) {
      FingerprintErrorHandler.showInfo(
          context, 'Please wait for current operation to complete');
      return;
    }

    setState(() {
      _isEnrolling = true;
      _enrollmentInProgress = true;
      _enrollmentStatus = 'Place $finger thumb on scanner...';
    });

    try {
      if (_activeScanner == 'zkteco') {
        // ZKTeco uses stream-based enrollment
        await _fingerprintService.startEnrollment(finger);
      } else if (_activeScanner == 'futronic') {
        // Futronic uses direct enrollment with return value
        final template = await _futronicService.enroll(finger);

        if (template != null && template.isNotEmpty) {
          // Save the template directly for Futronic
          await _saveFacilitatorFingerprint(finger, template);
        } else {
          throw Exception('Failed to capture fingerprint');
        }

        // Clear enrollment state for Futronic (ZKTeco handled by stream)
        if (mounted) {
          setState(() {
            _isEnrolling = false;
            _enrollmentInProgress = false;
          });
        }
      } else {
        throw Exception('No scanner connected');
      }
    } catch (e) {
      debugPrint('[FAC_FP] Enrollment error: $e');
      if (mounted) {
        setState(() {
          _enrollmentStatus = 'Enrollment error: $e';
          _isEnrolling = false;
          _enrollmentInProgress = false;
        });
        FingerprintErrorHandler.showError(
            context, 'Fingerprint enrollment failed');
      }
    }
  }

  Future<void> _verifyAndClock(String action) async {
    debugPrint('[FAC_CLOCK] ========== VERIFY AND CLOCK STARTED ==========');
    debugPrint('[FAC_CLOCK] Action: $action');
    debugPrint('[FAC_CLOCK] Facilitator ID: ${widget.facilitatorId}');
    debugPrint(
        '[FAC_CLOCK] Current state - isClocking: $_isClocking, isEnrolling: $_isEnrolling, enrollmentInProgress: $_enrollmentInProgress');

    if (_isClocking || _isEnrolling || _enrollmentInProgress) {
      debugPrint('[FAC_CLOCK] ❌ Operation already in progress');
      FingerprintErrorHandler.showInfo(
          context, 'Please wait for current operation to complete');
      return;
    }

    debugPrint(
        '[FAC_CLOCK] Step 1: Checking if facilitator has fingerprints...');
    // Check if facilitator has fingerprints enrolled
    final hasFingerprints =
        await _databaseHelper.facilitatorHasFingerprints(widget.facilitatorId);
    debugPrint('[FAC_CLOCK] Has fingerprints: $hasFingerprints');

    if (!hasFingerprints) {
      debugPrint('[FAC_CLOCK] ❌ No fingerprints enrolled');
      FingerprintErrorHandler.showError(
          context, 'Please enroll at least one fingerprint first');
      return;
    }

    debugPrint('[FAC_CLOCK] Step 2: Setting up clocking state...');
    setState(() {
      _isClocking = true;
      _clockingAction = action;
      _enrollmentStatus = 'Place finger on scanner to clock $action...';
    });

    try {
      debugPrint('[FAC_CLOCK] Step 3: Getting templates from database...');
      final templates = await _databaseHelper
          .getAllFacilitatorTemplates(widget.facilitatorId);
      debugPrint('[FAC_CLOCK] Available templates: $templates');

      String? template;

      if (_activeScanner == 'zkteco') {
        template = templates['zkteco_left_template'] ??
            templates['zkteco_right_template'];
        debugPrint(
            '[FAC_CLOCK] ZKTeco template selected: ${template != null ? 'Found (${template.length} chars)' : 'Not found'}');
      } else if (_activeScanner == 'futronic') {
        template = templates['futronic_left_template'] ??
            templates['futronic_right_template'];
        debugPrint(
            '[FAC_CLOCK] Futronic template selected: ${template != null ? 'Found (${template.length} chars)' : 'Not found'}');
      } else {
        debugPrint('[FAC_CLOCK] ❌ No active scanner detected: $_activeScanner');
      }

      if (template == null || template.isEmpty) {
        debugPrint(
            '[FAC_CLOCK] ❌ No fingerprint template found for active scanner');
        throw Exception('No fingerprint template found for active scanner');
      }

      debugPrint(
          '[FAC_CLOCK] Step 4: Starting fingerprint capture for verification...');

      if (_activeScanner == 'zkteco') {
        debugPrint('[FAC_CLOCK] Using ZKTeco verification...');
        // Set a timeout for ZKTeco verification
        try {
          final verifyResult =
              await _fingerprintService.verify('left', template).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('[FAC_CLOCK] ❌ ZKTeco verification timeout');
              throw Exception('Verification timeout - please try again');
            },
          );

          debugPrint('[FAC_CLOCK] ZKTeco verification result: $verifyResult');

          if (verifyResult == true) {
            debugPrint('[FAC_CLOCK] ✅ ZKTeco verification successful!');
            // Manually trigger the clocking process since we got the result directly
            await _performClocking();
          } else {
            debugPrint('[FAC_CLOCK] ❌ ZKTeco verification failed');
            if (mounted) {
              setState(() {
                _isClocking = false;
                _enrollmentStatus =
                    'Fingerprint verification failed. Please try again.';
              });
              FingerprintErrorHandler.showError(
                  context, 'Fingerprint not recognized. Please try again.');
            }
          }
        } catch (e) {
          debugPrint('[FAC_CLOCK] ❌ ZKTeco verification error: $e');
          if (mounted) {
            setState(() {
              _isClocking = false;
              _enrollmentStatus = 'Verification error: $e';
            });
            FingerprintErrorHandler.showError(
                context, 'Verification failed. Please try again.');
          }
        }
      } else if (_activeScanner == 'futronic') {
        debugPrint('[FAC_CLOCK] Using Futronic verification...');
        final leftTemplate = templates['futronic_left_template'];
        final rightTemplate = templates['futronic_right_template'];
        final hint = (leftTemplate != null && leftTemplate.isNotEmpty)
            ? 'left'
            : 'right';

        debugPrint(
            '[FAC_CLOCK] Futronic templates - Left: ${leftTemplate != null ? 'Available' : 'None'}, Right: ${rightTemplate != null ? 'Available' : 'None'}');
        debugPrint('[FAC_CLOCK] Using hint finger: $hint');

        try {
          final verifyResult = await _futronicService
              .verifyBoth(
            hintFinger: hint,
            leftTemplate: leftTemplate,
            rightTemplate: rightTemplate,
          )
              .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('[FAC_CLOCK] ❌ Futronic verification timeout');
              throw Exception('Verification timeout - please try again');
            },
          );

          debugPrint('[FAC_CLOCK] Futronic verification result: $verifyResult');

          if (verifyResult == true) {
            debugPrint('[FAC_CLOCK] ✅ Futronic verification successful!');
            // Manually trigger the clocking process since we got the result directly
            await _performClocking();
          } else {
            debugPrint('[FAC_CLOCK] ❌ Futronic verification failed');
            if (mounted) {
              setState(() {
                _isClocking = false;
                _enrollmentStatus =
                    'Fingerprint verification failed. Please try again.';
              });
              FingerprintErrorHandler.showError(
                  context, 'Fingerprint not recognized. Please try again.');
            }
          }
        } catch (e) {
          debugPrint('[FAC_CLOCK] ❌ Futronic verification error: $e');
          if (mounted) {
            setState(() {
              _isClocking = false;
              _enrollmentStatus = 'Verification error: $e';
            });
            FingerprintErrorHandler.showError(
                context, 'Verification failed. Please try again.');
          }
        }
      }
    } catch (e) {
      debugPrint('[FAC_FP] Verification error: $e');
      if (mounted) {
        setState(() {
          _isClocking = false;
          _enrollmentStatus = 'Verification error: $e';
        });
        FingerprintErrorHandler.showError(
            context, 'Verification failed. Please try again.');
      }
    }
  }

  // Clock in/out using signature as alternative to fingerprint
  Future<void> _clockWithSignature(String action) async {
    debugPrint('[FAC_SIGNATURE] ========== SIGNATURE CLOCK STARTED ==========');
    debugPrint('[FAC_SIGNATURE] Action: $action');
    debugPrint('[FAC_SIGNATURE] Facilitator ID: ${widget.facilitatorId}');

    if (_isClocking || _isEnrolling || _enrollmentInProgress) {
      debugPrint('[FAC_SIGNATURE] ❌ Operation already in progress');
      FingerprintErrorHandler.showInfo(
          context, 'Please wait for current operation to complete');
      return;
    }

    // Show signature capture dialog
    await _showSignatureDialog(action);
  }

  Future<void> _showSignatureDialog(String action) async {
    debugPrint('[FAC_SIGNATURE] Showing signature dialog for action: $action');

    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.blue,
      exportBackgroundColor: Colors.white,
    );

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Sign to Clock ${action == 'in' ? 'In' : 'Out'}'),
          content: SizedBox(
            width: 300,
            height: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Please sign below to confirm clock ${action == 'in' ? 'in' : 'out'}',
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Signature(
                      controller: _signatureController!,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _signatureController?.clear();
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () {
                _signatureController?.dispose();
                _signatureController = null;
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_signatureController!.isEmpty) {
                  FingerprintErrorHandler.showError(
                    dialogContext,
                    'Please provide your signature',
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'in' ? Colors.green : Colors.red,
              ),
              child: Text('Confirm Clock ${action == 'in' ? 'In' : 'Out'}'),
            ),
          ],
        );
      },
    );

    if (result == true &&
        _signatureController != null &&
        _signatureController!.isNotEmpty) {
      // Signature provided, proceed with clocking
      debugPrint(
          '[FAC_SIGNATURE] Signature captured, proceeding with clocking');

      setState(() {
        _isClocking = true;
        _clockingAction = action;
        _enrollmentStatus = 'Processing signature clock $action...';
      });

      try {
        // Perform the clocking without fingerprint verification
        await _performClocking();
        debugPrint(
            '[FAC_SIGNATURE] ✅ Signature clock $action completed successfully');
      } catch (e) {
        debugPrint('[FAC_SIGNATURE] ❌ Error during signature clocking: $e');
        if (mounted) {
          setState(() {
            _isClocking = false;
            _enrollmentStatus = 'Clocking error: $e';
          });
          FingerprintErrorHandler.showError(
              context, 'Failed to clock $action. Please try again.');
        }
      }
    } else {
      debugPrint(
          '[FAC_SIGNATURE] Signature dialog cancelled or no signature provided');
    }

    // Clean up signature controller
    _signatureController?.dispose();
    _signatureController = null;
  }

  void _showProceedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Fingerprints Enrolled'),
        content: const Text(
            'Both thumbs have been enrolled successfully. You can now proceed to your dashboard.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              if (widget.nextRoute != null) {
                Navigator.pushReplacementNamed(
                  context,
                  widget.nextRoute!,
                  arguments: widget.routeArguments,
                );
              } else {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation if clock-in is required
        if (widget.requireClockIn) {
          FingerprintErrorHandler.showInfo(
              context, 'Please clock in before proceeding');
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.requireClockIn
              ? 'Daily Clock-In Required'
              : widget.isFirstTimeSetup
                  ? 'Fingerprint Setup'
                  : 'Fingerprint Verification'),
          automaticallyImplyLeading:
              !widget.isFirstTimeSetup && !widget.requireClockIn,
          actions: [
            // Add refresh button to check scanner connection
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshScannerConnection,
              tooltip: 'Refresh Scanner Connection',
            ),
          ],
        ),
        body: _isCheckingClockIn
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading...',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Checking attendance and syncing data',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.requireClockIn
                          ? 'Good ${_getGreeting()}, ${widget.facilitatorName}!'
                          : widget.isFirstTimeSetup
                              ? 'Welcome, ${widget.facilitatorName}!'
                              : 'Facilitator: ${widget.facilitatorName}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (widget.isFirstTimeSetup)
                      const Text(
                        'Please enroll your fingerprints to secure your account and enable quick clock-in/out.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      )
                    else if (_hasScannerAvailable == true)
                      const Text(
                        'Use fingerprint scanner or signature to clock in/out.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      )
                    else if (_hasScannerAvailable == false)
                      const Text(
                        'Use your signature to clock in/out.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      )
                    else
                      const Text(
                        'Loading...',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isSensorConnected
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        border: Border.all(
                          color: _isSensorConnected ? Colors.green : Colors.red,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          if (_isInitializing)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              _isSensorConnected
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: _isSensorConnected
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _enrollmentStatus,
                              style: TextStyle(
                                color: _isInitializing
                                    ? Colors.blue
                                    : (_isSensorConnected
                                        ? Colors.green
                                        : Colors.red),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Show fingerprint enrollment only if scanner is available
                    if (_hasScannerAvailable == true &&
                        _activeScanner != 'none') ...[
                      Text(
                        'Scanner: ${_activeScanner.toUpperCase()}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isEnrolling ||
                                      _enrollmentInProgress ||
                                      _isClocking)
                                  ? null
                                  : () => _enrollThumb('left'),
                              icon: Icon(_leftThumbEnrolled
                                  ? Icons.check
                                  : Icons.fingerprint),
                              label: Text(_leftThumbEnrolled
                                  ? 'Re-enroll Left'
                                  : 'Enroll Left'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _leftThumbEnrolled
                                    ? Colors.green
                                    : Colors.blue,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isEnrolling ||
                                      _enrollmentInProgress ||
                                      _isClocking)
                                  ? null
                                  : () => _enrollThumb('right'),
                              icon: Icon(_rightThumbEnrolled
                                  ? Icons.check
                                  : Icons.fingerprint),
                              label: Text(_rightThumbEnrolled
                                  ? 'Re-enroll Right'
                                  : 'Enroll Right'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _rightThumbEnrolled
                                    ? Colors.green
                                    : Colors.blue,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Show clocking options based on scanner availability
                    if (!widget.isFirstTimeSetup &&
                        _hasScannerAvailable == true &&
                        (_leftThumbEnrolled || _rightThumbEnrolled)) ...[
                      // Scanner available AND fingerprints enrolled - show ONLY fingerprint options
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text(
                        'Clocking',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Using Fingerprint Scanner',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isEnrolling ||
                                      _enrollmentInProgress ||
                                      _isClocking)
                                  ? null
                                  : () => _verifyAndClock('in'),
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('Clock In'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isEnrolling ||
                                      _enrollmentInProgress ||
                                      _isClocking)
                                  ? null
                                  : () => _verifyAndClock('out'),
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('Clock Out'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // If no scanner available, show signature-only options
                    if (!widget.isFirstTimeSetup &&
                        _hasScannerAvailable == false) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      const Center(
                        child: Column(
                          children: [
                            Icon(Icons.edit, size: 48, color: Colors.teal),
                            SizedBox(height: 12),
                            Text(
                              'Fingerprint scanner not available',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Use signature to clock in/out',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Clock In/Out Using Signature',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isEnrolling ||
                                      _enrollmentInProgress ||
                                      _isClocking)
                                  ? null
                                  : () => _clockWithSignature('in'),
                              icon: const Icon(Icons.edit),
                              label: const Text('Sign In'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isEnrolling ||
                                      _enrollmentInProgress ||
                                      _isClocking)
                                  ? null
                                  : () => _clockWithSignature('out'),
                              icon: const Icon(Icons.edit),
                              label: const Text('Sign Out'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // For first time setup, scanner is required
                    if (widget.isFirstTimeSetup &&
                        _hasScannerAvailable == false) ...[
                      const Center(
                        child: Column(
                          children: [
                            Icon(Icons.warning, size: 64, color: Colors.orange),
                            SizedBox(height: 16),
                            Text(
                              'Scanner Required for Setup',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Please connect a fingerprint scanner for initial setup',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (widget.isFirstTimeSetup &&
                        (_leftThumbEnrolled || _rightThumbEnrolled))
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            if (widget.nextRoute != null) {
                              Navigator.pushReplacementNamed(
                                context,
                                widget.nextRoute!,
                                arguments: widget.routeArguments,
                              );
                            } else {
                              Navigator.pop(context, true);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                          ),
                          child: const Text(
                            'Continue to Dashboard',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  // Get greeting based on time of day
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'morning';
    } else if (hour < 17) {
      return 'afternoon';
    } else {
      return 'evening';
    }
  }
}

extension StringCasingExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
