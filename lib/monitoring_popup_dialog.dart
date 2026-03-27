import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'database_helper.dart';
import 'services/fingerprint_service.dart';
import 'services/futronic_service.dart' as futronic;
import 'utils/fingerprint_error_handler.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class MonitoringPopupDialog extends StatefulWidget {
  final Map<String, dynamic> person;
  final VoidCallback onPresent;
  final VoidCallback onAbsent;
  final String classID;

  const MonitoringPopupDialog({
    super.key,
    required this.person,
    required this.onPresent,
    required this.onAbsent,
    required this.classID,
  });

  @override
  State<MonitoringPopupDialog> createState() => _MonitoringPopupDialogState();
}

class _MonitoringPopupDialogState extends State<MonitoringPopupDialog> {
  int _countdownSeconds = 300; // 5 minutes
  int _currentAttempt = 1;
  Timer? _countdownTimer;
  Timer? _soundTimer; // Timer for periodic sound alerts

  // Fingerprint verification - SAME AS CLOCKING SYSTEM
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FingerprintService _fingerprintService = FingerprintService();
  final futronic.FutronicService _futronicService = futronic.FutronicService();
  bool _isVerifying = false;
  String _verificationStatus = '';
  bool _fingerprintRequired = true;
  String? _currentPersonIdForVerification;
  StreamSubscription? _enrollStatusSubscription;
  StreamSubscription? _enrollSuccessSubscription;
  bool _isSensorConnected = false;
  bool _isInitializing = false;
  String _activeScanner = 'none';
  final bool _isLunchBreak = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _initialVibrationAndSoundAlert();
    _setupFingerprintStreams();
    _initializeSensor(); // Initialize fingerprint scanner like clocking system
    _startPeriodicSoundAlerts(); // Start periodic sound alerts
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _soundTimer?.cancel(); // Cancel sound timer
    _enrollStatusSubscription?.cancel();
    _enrollSuccessSubscription?.cancel();
    _fingerprintService
        .dispose(); // Dispose fingerprint service like clocking system
    super.dispose();
  }

  void _initialVibrationAndSoundAlert() async {
    // Play initial attention sound
    _playAttentionSound();

    // Strong initial vibration pattern
    for (int i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  void _startPeriodicSoundAlerts() {
    // Play sound every 30 seconds to keep user's attention
    _soundTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_countdownSeconds > 0) {
        _playReminderSound();

        // Extra urgent sound when time is running low
        if (_countdownSeconds <= 60) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _playUrgentSound();
          });
        }
      }
    });
  }

  void _playAttentionSound() async {
    try {
      // Play notification sound to get attention
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.glass,
        looping: false,
        volume: 1.0,
      );
    } catch (e) {
      print('[MONITORING_SOUND] Error playing attention sound: $e');
    }
  }

  void _playReminderSound() async {
    try {
      // Play reminder sound (softer)
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.glass,
        looping: false,
        volume: 0.7,
      );
    } catch (e) {
      print('[MONITORING_SOUND] Error playing reminder sound: $e');
    }
  }

  void _playUrgentSound() async {
    try {
      // Play urgent sound when time is running out
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        looping: false,
        volume: 1.0,
      );
    } catch (e) {
      print('[MONITORING_SOUND] Error playing urgent sound: $e');
    }
  }

  void _playSuccessSound() async {
    try {
      print('[MONITORING_SOUND] 🔊 Playing SUCCESS sound...');
      // Play success sound when fingerprint is verified
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.glass,
        looping: false,
        volume: 1.0,
      );
      print('[MONITORING_SOUND] ✅ SUCCESS sound played successfully');
    } catch (e) {
      print('[MONITORING_SOUND] ❌ Error playing success sound: $e');
    }
  }

  void _playErrorSound() async {
    try {
      print('[MONITORING_SOUND] 🔊 Playing ERROR sound...');
      // Play error sound when fingerprint doesn't match - use alarm for distinction
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        looping: false,
        volume: 1.0,
      );
      print('[MONITORING_SOUND] ✅ ERROR sound played successfully');
    } catch (e) {
      print('[MONITORING_SOUND] ❌ Error playing error sound: $e');
    }
  }

  void _playTestSound() async {
    try {
      print('[MONITORING_SOUND] 🔊 Playing TEST sound...');
      // Test sound to verify sound system is working
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.glass,
        looping: false,
        volume: 1.0,
      );
      print('[MONITORING_SOUND] ✅ TEST sound played successfully');
    } catch (e) {
      print('[MONITORING_SOUND] ❌ Error playing test sound: $e');
    }
  }

  void _playAlternativeSuccessSound() async {
    try {
      print('[MONITORING_SOUND] 🔊 Playing ALTERNATIVE SUCCESS sound...');
      // Alternative success sound using system beep
      await FlutterRingtonePlayer().playNotification();
      print('[MONITORING_SOUND] ✅ ALTERNATIVE SUCCESS sound played');
    } catch (e) {
      print('[MONITORING_SOUND] ❌ Error playing alternative success sound: $e');
    }
  }

  void _playAlternativeErrorSound() async {
    try {
      print('[MONITORING_SOUND] 🔊 Playing ALTERNATIVE ERROR sound...');
      // Alternative error sound using system alarm
      await FlutterRingtonePlayer().playAlarm();
      print('[MONITORING_SOUND] ✅ ALTERNATIVE ERROR sound played');
    } catch (e) {
      print('[MONITORING_SOUND] ❌ Error playing alternative error sound: $e');
    }
  }

  // Initialize fingerprint sensor - SAME AS CLOCKING SYSTEM (supports both ZKTeco and Futronic)
  Future<void> _initializeSensor() async {
    if (_isInitializing) return; // Prevent concurrent initialization

    setState(() {
      _isInitializing = true;
      _verificationStatus = 'Initializing scanner...';
    });

    try {
      // Cancel any ongoing operations to free up the sensor
      await _fingerprintService.cancelEnrollment().catchError((e) {
        debugPrint('[MONITORING_INIT] Cancel enrollment error (expected): $e');
      });

      await Future.delayed(const Duration(milliseconds: 500));

      // Detect scanner - try both ZKTeco and Futronic like clocking system
      final scanner = await _detectScanner();
      if (!mounted) return;

      setState(() {
        _activeScanner = scanner;
        _isSensorConnected = scanner != 'none';
        _verificationStatus = scanner != 'none'
            ? 'Scanner ready ($scanner) - click VERIFY to start'
            : 'Scanner not detected - please check USB connection';
        _isInitializing = false;
      });

      debugPrint('[MONITORING_INIT] Scanner detected: $scanner');

      if (scanner == 'none') {
        FingerprintErrorHandler.showError(
            context, 'No scanner connected. Please check USB connection.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verificationStatus = 'Scanner initialization error: $e';
        _isSensorConnected = false;
        _isInitializing = false;
        _activeScanner = 'none';
      });
      debugPrint('[MONITORING_INIT] Scanner initialization failed: $e');
      FingerprintErrorHandler.showError(
          context, 'Scanner initialization failed: $e');
    }
  }

  // EXACT SAME FINGERPRINT STREAM SETUP AS CLOCKING
  void _setupFingerprintStreams() {
    _enrollStatusSubscription =
        _fingerprintService.enrollStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _verificationStatus = status;
          if (status.toLowerCase().contains('error') ||
              status.toLowerCase().contains('failed') ||
              status.toLowerCase().contains('timed out')) {
            _isVerifying = false;
            _hideProgressDialog();
            FingerprintErrorHandler.showError(context, status);
          }
        });
      }
    });

    _enrollSuccessSubscription =
        _fingerprintService.enrollSuccessStream.listen((capturedData) async {
      debugPrint('[MONITORING] enrollSuccessStream received: $capturedData');

      // CRITICAL: Ignore fingerprints if no person is actively verifying
      if (!mounted || _currentPersonIdForVerification == null) {
        debugPrint('[MONITORING] ❌ IGNORED: No active verification session');
        return;
      }

      _hideProgressDialog();

      // Capture the current person ID immediately
      final personId = _currentPersonIdForVerification!;
      final personType = widget.person['person_type'];
      final scannedTemplate = capturedData['template'] as String?;

      // Clear global state immediately
      _currentPersonIdForVerification = null;

      debugPrint(
          '[MONITORING] Processing fingerprint for person: $personId, type: $personType');

      if (scannedTemplate == null) {
        FingerprintErrorHandler.showError(context, 'Fingerprint scan failed');
        setState(() => _isVerifying = false);
        return;
      }

      try {
        // Get fingerprint templates based on person type - EXACT SAME AS CLOCKING
        Map<String, String?> templates;
        if (personType == 'facilitator') {
          final facilitatorId = int.tryParse(personId);
          if (facilitatorId == null) {
            FingerprintErrorHandler.showError(
                context, 'Invalid facilitator ID');
            return;
          }
          templates = await _dbHelper.getAllFacilitatorTemplates(facilitatorId);
        } else {
          final learnerIdInt = int.tryParse(personId);
          if (learnerIdInt == null) {
            FingerprintErrorHandler.showError(context, 'Invalid learner ID');
            return;
          }
          templates = await _dbHelper.getAllTemplates(learnerIdInt);
        }

        // Use the same template selection logic as clocking
        final storedTemplates = personType == 'facilitator'
            ? await _dbHelper.getFacilitatorFingerprints(int.parse(personId))
            : await _dbHelper.getFingerprints(int.parse(personId));

        final leftTemplate = storedTemplates['left'];
        final rightTemplate = storedTemplates['right'];

        debugPrint('[MONITORING] Using available templates');
        debugPrint(
            '[MONITORING] Left template exists: ${leftTemplate != null && leftTemplate.isNotEmpty}');
        debugPrint(
            '[MONITORING] Right template exists: ${rightTemplate != null && rightTemplate.isNotEmpty}');

        // Check if any fingerprints exist
        if ((leftTemplate == null || leftTemplate.isEmpty) &&
            (rightTemplate == null || rightTemplate.isEmpty)) {
          debugPrint('[MONITORING] No fingerprints found for person $personId');
          FingerprintErrorHandler.showError(
              context, 'No fingerprints enrolled for this person');
          setState(() => _isVerifying = false);
          return;
        }

        // EXACT SAME MATCHING LOGIC AS CLOCKING
        bool match = false;
        debugPrint(
            '[MONITORING] ========== FINGERPRINT MATCHING STARTED ==========');
        debugPrint('[MONITORING] Person ID: $personId');
        debugPrint(
            '[MONITORING] Scanned template size: ${scannedTemplate.length} bytes');

        if (leftTemplate != null && leftTemplate.isNotEmpty) {
          debugPrint('[MONITORING] Attempting match with LEFT template...');
          match = await _fingerprintService.matchTemplates(
              leftTemplate, scannedTemplate);
          debugPrint('[MONITORING] LEFT template match result: $match');
        }

        if (!match && rightTemplate != null && rightTemplate.isNotEmpty) {
          debugPrint('[MONITORING] Attempting match with RIGHT template...');
          match = await _fingerprintService.matchTemplates(
              rightTemplate, scannedTemplate);
          debugPrint('[MONITORING] RIGHT template match result: $match');
        }

        debugPrint(
            '[MONITORING] ========== FINAL MATCH RESULT: $match ==========');

        if (match) {
          debugPrint(
              '[MONITORING] ✅ FINGERPRINT MATCH CONFIRMED for Person $personId');
          setState(() {
            _verificationStatus = 'Fingerprint verified! ✅';
            _fingerprintRequired = false;
            _isVerifying = false;
          });

          // Auto-proceed after successful verification
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              _handlePresent();
            }
          });
        } else {
          debugPrint(
              '[MONITORING] ❌ NO FINGERPRINT MATCH FOUND for Person $personId!');
          // Show error and ask to try again - DON'T insert record yet
          setState(() {
            _verificationStatus =
                'Fingerprint does NOT match! Please try again ❌';
            _isVerifying = false;
          });

          FingerprintErrorHandler.showError(context,
              'Fingerprint does NOT match this person! Please try again with the correct finger.');
        }
      } catch (e) {
        debugPrint('[MONITORING] Verification error: $e');
        FingerprintErrorHandler.showError(context, e.toString());
        setState(() {
          _verificationStatus = 'Verification error: $e';
          _isVerifying = false;
        });
      }
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdownSeconds--;
      });

      // Play urgent sound every 10 seconds when under 1 minute
      if (_countdownSeconds <= 60 && _countdownSeconds % 10 == 0) {
        _playUrgentSound();
        HapticFeedback.heavyImpact();
      }

      if (_countdownSeconds <= 0) {
        _handleTimeExpired();
      }
    });
  }

  void _handleTimeExpired() {
    _countdownTimer?.cancel();
    _soundTimer?.cancel(); // Stop sound alerts

    if (_currentAttempt < 3) {
      // Move to next attempt
      setState(() {
        _currentAttempt++;
        _countdownSeconds = 300; // Reset to 5 minutes
      });
      _startCountdown();
      _startPeriodicSoundAlerts(); // Restart sound alerts for new attempt
      _playAttentionSound(); // Play attention sound for new attempt
    } else {
      // All 3 attempts failed - auto mark as ABSENT
      _handleAbsent();
    }
  }

  void _handlePresent() async {
    debugPrint(
        '[MONITORING_POPUP] _handlePresent called, fingerprintRequired: $_fingerprintRequired, isVerifying: $_isVerifying');

    // REQUIRE FINGERPRINT VERIFICATION FOR BOTH LEARNERS AND FACILITATORS
    if (_fingerprintRequired && !_isVerifying) {
      debugPrint('[MONITORING_POPUP] Starting fingerprint verification...');
      _startFingerprintVerification();
      return;
    }

    // Only proceed if fingerprint was verified successfully
    if (!_fingerprintRequired) {
      debugPrint(
          '[MONITORING_POPUP] Fingerprint verified - marking person as PRESENT');
      _countdownTimer?.cancel();
      _soundTimer?.cancel(); // Stop sound alerts
      HapticFeedback.lightImpact();

      // Update person data with verification details
      widget.person['verification_method'] = _activeScanner == 'futronic'
          ? 'fingerprint_futronic'
          : 'fingerprint_zkteco';
      widget.person['scanner_type'] = _activeScanner;
      widget.person['fingerprint_matched'] = 1;

      // Call the service's onPresent callback - service will handle saving
      widget.onPresent();
      Navigator.of(context).pop();
    } else {
      // This shouldn't happen, but just in case
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify fingerprint first'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _handleAbsent() async {
    debugPrint('[MONITORING_POPUP] _handleAbsent called - person not present');
    _countdownTimer?.cancel();
    _soundTimer?.cancel(); // Stop sound alerts
    HapticFeedback.heavyImpact();

    // Update person data with verification details (absent = no fingerprint)
    widget.person['verification_method'] = 'manual';
    widget.person['scanner_type'] = 'none';
    widget.person['fingerprint_matched'] = 0;

    // Call the service's onAbsent callback - service will handle saving
    widget.onAbsent();
    Navigator.of(context).pop();
  }

  // EXACT SAME FINGERPRINT VERIFICATION WORKFLOW AS CLOCKING
  Future<void> _startFingerprintVerification() async {
    if (_isVerifying) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification already in progress...')),
      );
      return;
    }

    final personId = widget.person['person_id'].toString();
    final personType = widget.person['person_type'];

    // CRITICAL SAFETY CHECK: Prevent multiple verifications
    if (_currentPersonIdForVerification != null &&
        _currentPersonIdForVerification != personId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Another verification is in progress. Please wait.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _verificationStatus = 'Checking scanner connection...';
    });

    try {
      // Get templates first to check if person has fingerprints
      Map<String, String?> templates;
      if (personType == 'facilitator') {
        final facilitatorId = int.tryParse(personId);
        if (facilitatorId == null) {
          setState(() {
            _verificationStatus = 'Invalid facilitator ID';
            _isVerifying = false;
          });
          return;
        }
        templates = await _dbHelper.getAllFacilitatorTemplates(facilitatorId);
      } else {
        final learnerIdInt = int.tryParse(personId);
        if (learnerIdInt == null) {
          setState(() {
            _verificationStatus = 'Invalid learner ID';
            _isVerifying = false;
          });
          return;
        }
        templates = await _dbHelper.getAllTemplates(learnerIdInt);
      }

      // Detect scanner - REQUIRE BIOMETRIC VERIFICATION LIKE CLOCKING
      final scanner = await _detectScanner();
      if (scanner == 'none') {
        // NO SCANNER DETECTED - REQUIRE SCANNER CONNECTION LIKE CLOCKING SYSTEM
        setState(() {
          _verificationStatus =
              'No fingerprint scanner detected. Please connect a scanner to verify attendance.';
          _isVerifying = false;
        });

        FingerprintErrorHandler.showError(context,
            'No fingerprint scanner detected. Please connect a ZKTeco scanner to verify attendance. Biometric verification is required for monitoring.');
        return;
      }

      // Use same template logic as clocking system - supports both ZKTeco and Futronic
      final hasZkLeft =
          (templates['zkteco_left_template']?.isNotEmpty ?? false);
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
        setState(() {
          _verificationStatus =
              'This person\'s fingerprint is enrolled on ZKTeco. Please use the ZKTeco scanner.';
          _isVerifying = false;
        });
        FingerprintErrorHandler.showError(context,
            'This person\'s fingerprint is enrolled on ZKTeco. Please use the ZKTeco scanner or re-enroll on Futronic.');
        return;
      }
      if (scanner == 'zkteco' &&
          !(hasZkLeft || hasZkRight) &&
          (hasFutLeft || hasFutRight)) {
        setState(() {
          _verificationStatus =
              'This person\'s fingerprint is enrolled on Futronic. Please use the Futronic scanner.';
          _isVerifying = false;
        });
        FingerprintErrorHandler.showError(context,
            'This person\'s fingerprint is enrolled on Futronic. Please use the Futronic scanner or re-enroll on ZKTeco.');
        return;
      }

      // Check if templates exist for active scanner
      String? template;
      if (scanner == 'zkteco') {
        template = templates['zkteco_left_template'] ??
            templates['zkteco_right_template'];
      } else if (scanner == 'futronic') {
        template = templates['futronic_left_template'] ??
            templates['futronic_right_template'];
      }

      if (template == null || template.isEmpty) {
        setState(() {
          _verificationStatus =
              'No fingerprints enrolled for this person on $scanner scanner';
          _isVerifying = false;
        });
        FingerprintErrorHandler.showError(context,
            'No fingerprints enrolled for this person. Please enroll fingerprints first.');
        return;
      }

      // Set current person for verification
      _currentPersonIdForVerification = personId;

      // Build guidance message based on available templates for active scanner
      String guidance = 'Place finger on scanner for verification...';
      if (scanner == 'futronic') {
        if (hasFutLeft && hasFutRight) {
          guidance = 'Place either thumb on Futronic scanner...';
        } else if (hasFutLeft) {
          guidance = 'Place LEFT thumb on Futronic scanner...';
        } else if (hasFutRight) {
          guidance = 'Place RIGHT thumb on Futronic scanner...';
        }
      } else if (scanner == 'zkteco') {
        if (hasZkLeft && hasZkRight) {
          guidance = 'Place either thumb on ZKTeco scanner...';
        } else if (hasZkLeft) {
          guidance = 'Place LEFT thumb on ZKTeco scanner...';
        } else if (hasZkRight) {
          guidance = 'Place RIGHT thumb on ZKTeco scanner...';
        }
      }

      setState(() {
        _verificationStatus = guidance;
      });

      _showProgressDialog(guidance);

      // Start verification - SAME AS CLOCKING SYSTEM (supports both scanners)
      bool match = false;
      if (scanner == 'zkteco') {
        match = await _fingerprintService.verify('left', template) ||
            await _fingerprintService.verify('right', template);
      } else if (scanner == 'futronic') {
        try {
          debugPrint(
              '[MONITORING] Attempting Futronic verification for person $personId');
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
              '[MONITORING] Futronic verification error: $futronicError');
          _hideProgressDialog();
          setState(() {
            _isVerifying = false;
            _currentPersonIdForVerification = null;
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

          if (mounted) {
            FingerprintErrorHandler.showError(context, errorMessage);
          }
          return;
        }
      }

      _hideProgressDialog();

      if (match) {
        debugPrint('[MONITORING] ✅ FINGERPRINT MATCH CONFIRMED (method 2)');
        setState(() {
          _verificationStatus = 'Fingerprint verified! ✅';
          _fingerprintRequired = false;
          _isVerifying = false;
        });

        // Auto-proceed after successful verification
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _handlePresent();
          }
        });
      } else {
        debugPrint('[MONITORING] ❌ FINGERPRINT MISMATCH (method 2)');
        setState(() {
          _verificationStatus =
              'Fingerprint does not match! Please try again ❌';
          _isVerifying = false;
        });
        FingerprintErrorHandler.showError(context,
            'Fingerprint does not match this person! Please try again.');
      }
    } catch (e) {
      debugPrint('[MONITORING] Verification error: $e');
      setState(() {
        _verificationStatus = 'Verification error: $e';
        _isVerifying = false;
      });
      FingerprintErrorHandler.showError(context, e.toString());
    } finally {
      setState(() {
        _currentPersonIdForVerification = null;
      });
    }
  }

  // SAME SCANNER DETECTION AS CLOCKING SYSTEM - supports both ZKTeco and Futronic
  Future<String> _detectScanner() async {
    // Try ZKTeco first
    try {
      final isZkConnected = await _fingerprintService.isSensorConnected();
      if (isZkConnected) {
        debugPrint('[MONITORING] ✅ ZKTeco scanner detected');
        return 'zkteco';
      }
    } catch (e) {
      debugPrint('[MONITORING] ZKTeco detection error: $e');
    }

    // Enhanced Futronic detection with retry (same as clocking system)
    return await _detectFutronicWithRetry();
  }

  Future<String> _detectFutronicWithRetry() async {
    const maxAttempts = 3;
    const delays = [500, 1000, 2000]; // Progressive delays

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        debugPrint('[MONITORING] Futronic attempt $attempt/$maxAttempts...');
        final isFutronicConnected =
            await _futronicService.isFutronicConnected();

        if (isFutronicConnected) {
          debugPrint('[MONITORING] ✅ Futronic detected on attempt $attempt!');
          return 'futronic';
        }

        // Wait before next attempt (except on last)
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: delays[attempt - 1]));
        }
      } catch (e) {
        debugPrint('[MONITORING] Futronic attempt $attempt failed: $e');
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }

    debugPrint(
        '[MONITORING] ❌ No Futronic scanner detected after all attempts');
    return 'none';
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
              Expanded(child: Text(message)),
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

  String _formatCountdown() {
    final minutes = _countdownSeconds ~/ 60;
    final seconds = _countdownSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isLowTime = _countdownSeconds <= 60;
    final personType = widget.person['person_type'] == 'facilitator'
        ? 'Facilitator'
        : 'Learner';

    return PopScope(
      canPop: false,
      child: Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fingerprint, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ATTENDANCE MONITORING',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'Attempt $_currentAttempt/3',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Person Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.person['person_name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$personType ID: ${widget.person['person_id']}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Class: ${widget.classID}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Countdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLowTime ? Colors.red[100] : Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Time Remaining',
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      _formatCountdown(),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isLowTime ? Colors.red : Colors.green,
                      ),
                    ),
                    if (isLowTime)
                      const Text(
                        '⚠️ TIME RUNNING OUT!',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _handlePresent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _fingerprintRequired
                            ? Colors.blue[600]
                            : Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _fingerprintRequired
                                ? Icons.fingerprint
                                : Icons.check_circle,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _fingerprintRequired ? 'VERIFY' : 'PRESENT',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _handleAbsent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cancel, size: 16),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'ABSENT',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Test Sound Buttons (temporary for debugging)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        print(
                            '[MONITORING] 🔊 Test notification sound button pressed');
                        _playTestSound();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child: const Text('TEST', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        print(
                            '[MONITORING] 🔊 Test success sound button pressed');
                        _playAlternativeSuccessSound();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child:
                          const Text('SUCCESS', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        print(
                            '[MONITORING] 🔊 Test error sound button pressed');
                        _playAlternativeErrorSound();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child:
                          const Text('ERROR', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      isLowTime ? Icons.warning : Icons.info,
                      color: isLowTime ? Colors.orange : Colors.blue,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isLowTime
                            ? '⚠️ TIME RUNNING OUT! Please verify attendance immediately.'
                            : _fingerprintRequired
                                ? '👆 Click "VERIFY" to confirm presence with biometric verification.'
                                : '✅ Fingerprint verified! Click "PRESENT" to confirm attendance.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
