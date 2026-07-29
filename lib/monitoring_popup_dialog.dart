import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
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
  final _MonitoringAlarm _alarm = _MonitoringAlarm();

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

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _initialVibrationAndSoundAlert();
    _setupFingerprintStreams();
    _initializeSensor(); // Initialize fingerprint scanner like clocking system
    _startPeriodicSoundAlerts(); // Start periodic sound alerts
    _alarm.start(); // Start the looping alarm
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _soundTimer?.cancel(); // Cancel sound timer
    _alarm.stop(); // Stop the alarm
    _alarm.dispose();
    _enrollStatusSubscription?.cancel();
    _enrollSuccessSubscription?.cancel();
    _fingerprintService
        .dispose(); // Dispose fingerprint service like clocking system
    super.dispose();
  }

  void _initialVibrationAndSoundAlert() async {
    // Initial vibration alert
    for (int i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  void _startPeriodicSoundAlerts() {
    // We now use _MonitoringAlarm for looping sounds
  }

  void _playAttentionSound() async {
    // Handled by _MonitoringAlarm
  }

  void _playReminderSound() async {
    // Handled by _MonitoringAlarm
  }

  void _playUrgentSound() async {
    try {
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.triTone,
        looping: false,
        volume: 1.0,
      );
      HapticFeedback.vibrate();
    } catch (e) {
      debugPrint('[MONITORING_SOUND] Error playing urgent sound: $e');
      HapticFeedback.vibrate();
    }
  }

  void _playSuccessSound() async {
    try {
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.glass,
        looping: false,
        volume: 1.0,
      );
    } catch (e) {
      debugPrint('[MONITORING_SOUND] Error playing success sound: $e');
    }
  }

  void _playErrorSound() async {
    try {
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        looping: false,
        volume: 1.0,
      );
    } catch (e) {
      debugPrint('[MONITORING_SOUND] Error playing error sound: $e');
    }
  }

  void _playTestSound() async {
    try {
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.glass,
        looping: false,
        volume: 1.0,
      );
    } catch (e) {
      debugPrint('[MONITORING_SOUND] Error playing test sound: $e');
    }
  }

  void _playAlternativeSuccessSound() async {
    try {
      await FlutterRingtonePlayer().playNotification();
    } catch (e) {
      debugPrint(
          '[MONITORING_SOUND] Error playing alternative success sound: $e');
    }
  }

  void _playAlternativeErrorSound() async {
    try {
      await FlutterRingtonePlayer().playAlarm();
    } catch (e) {
      debugPrint(
          '[MONITORING_SOUND] Error playing alternative error sound: $e');
    }
  }

  Future<void> _initializeSensor() async {
    if (_isInitializing) return;

    setState(() {
      _isInitializing = true;
      _verificationStatus = 'Initializing scanner...';
    });

    try {
      await _fingerprintService.cancelEnrollment().catchError((e) {
        debugPrint('[MONITORING_INIT] Cancel enrollment error: $e');
      });

      await Future.delayed(const Duration(milliseconds: 500));

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
      FingerprintErrorHandler.showError(
          context, 'Scanner initialization failed: $e');
    }
  }

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
      // NOTE: This stream listener is now only used for debugging or non-ZKTeco capture if needed.
      // ZKTeco verification is now handled directly via _fingerprintService.verify()
      // in _startFingerprintVerification() to match the clocking system.
      debugPrint('[MONITORING_FINGERPRINT] Captured template received');
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _countdownSeconds--;
      });

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
    if (_currentAttempt < 3) {
      setState(() {
        _currentAttempt++;
        _countdownSeconds = 300;
      });
      _startCountdown();
    } else {
      _handleAbsent();
    }
  }

  void _handlePresent() async {
    if (_fingerprintRequired && !_isVerifying) {
      _startFingerprintVerification();
      return;
    }

    if (!_fingerprintRequired) {
      _countdownTimer?.cancel();
      _alarm.stop();
      HapticFeedback.lightImpact();

      widget.person['verification_method'] = _activeScanner == 'futronic'
          ? 'fingerprint_futronic'
          : 'fingerprint_zkteco';
      widget.person['scanner_type'] = _activeScanner;
      widget.person['fingerprint_matched'] = 1;

      widget.onPresent();
      Navigator.of(context).pop();
    }
  }

  void _handleAbsent() async {
    _countdownTimer?.cancel();
    _alarm.stop();
    HapticFeedback.heavyImpact();

    widget.person['verification_method'] = 'manual';
    widget.person['scanner_type'] = 'none';
    widget.person['fingerprint_matched'] = 0;

    widget.onAbsent();
    Navigator.of(context).pop();
  }

  Future<void> _startFingerprintVerification() async {
    if (_isVerifying) return;

    final personId = widget.person['person_id'].toString();
    final personType = widget.person['person_type'];

    setState(() {
      _isVerifying = true;
      _verificationStatus = 'Checking scanner connection...';
    });

    try {
      // Cancel any ongoing operations first to ensure sensor is free
      // This is important because the Dashboard might have a scanner instance active
      try {
        await _fingerprintService.cancelEnrollment();
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('[MONITORING_VERIFY] Cleanup error (can ignore): $e');
      }

      final scanner = await _detectScanner();
      if (scanner == 'none') {
        setState(() => _isVerifying = false);
        FingerprintErrorHandler.showError(context,
            'No fingerprint scanner detected. Biometric verification is required.');
        return;
      }

      _currentPersonIdForVerification = personId;

      // Fetch templates from database - USE EXACT SAME METHOD AS CLOCKING SYSTEM
      final allTemplates = await _dbHelper.getAllTemplates(int.parse(personId));

      final zkLeft = allTemplates['zkteco_left_template'];
      final zkRight = allTemplates['zkteco_right_template'];
      final futLeft = allTemplates['futronic_left_template'];
      final futRight = allTemplates['futronic_right_template'];

      if ((zkLeft == null || zkLeft.isEmpty) &&
          (zkRight == null || zkRight.isEmpty) &&
          (futLeft == null || futLeft.isEmpty) &&
          (futRight == null || futRight.isEmpty)) {
        debugPrint(
            '[MONITORING_VERIFY] ❌ No templates found for learner $personId');
        throw Exception('No fingerprints enrolled for this person');
      }

      // Build guidance message based on available templates and scanner
      String guidance = 'Place finger on scanner...';
      if (scanner == 'zkteco') {
        if (zkLeft != null && zkLeft.isNotEmpty) {
          guidance = 'Place LEFT finger on ZKTeco scanner...';
        } else if (zkRight != null && zkRight.isNotEmpty) {
          guidance = 'Place RIGHT finger on ZKTeco scanner...';
        }
      } else if (scanner == 'futronic') {
        if (futLeft != null && futLeft.isNotEmpty) {
          guidance = 'Place LEFT thumb on Futronic scanner...';
        } else if (futRight != null && futRight.isNotEmpty) {
          guidance = 'Place RIGHT thumb on Futronic scanner...';
        }
      }

      setState(() => _verificationStatus = guidance);
      _showProgressDialog(guidance);

      bool match = false;
      if (scanner == 'zkteco') {
        // Match MonitoringPromptPage logic exactly
        if (zkLeft != null && zkLeft.isNotEmpty) {
          debugPrint('[MONITORING_VERIFY] Attempting ZKTeco LEFT finger match');
          match = await _fingerprintService.verify('left', zkLeft);
        }

        if (!match && zkRight != null && zkRight.isNotEmpty) {
          debugPrint(
              '[MONITORING_VERIFY] Attempting ZKTeco RIGHT finger match');
          match = await _fingerprintService.verify('right', zkRight);
        }
      } else if (scanner == 'futronic') {
        final hint = (futLeft != null && futLeft.isNotEmpty) ? 'left' : 'right';
        match = await _futronicService.verifyBoth(
          hintFinger: hint,
          leftTemplate: futLeft,
          rightTemplate: futRight,
        );
      }

      _hideProgressDialog();
      setState(() => _isVerifying = false);

      if (match) {
        _playSuccessSound();
        setState(() {
          _verificationStatus = 'Fingerprint verified! ✅';
          _fingerprintRequired = false;
        });

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _handlePresent();
        });
      } else {
        _playErrorSound();
        setState(() {
          _verificationStatus =
              'Fingerprint does NOT match! Please try again ❌';
        });
        FingerprintErrorHandler.showError(context,
            'Fingerprint does NOT match this person! Please try again.');
      }
    } catch (e) {
      _hideProgressDialog();
      setState(() {
        _isVerifying = false;
        _verificationStatus = 'Verification error: $e';
      });
      FingerprintErrorHandler.showError(context, e.toString());
    }
  }

  Future<String> _detectScanner() async {
    try {
      if (await _fingerprintService.isSensorConnected()) return 'zkteco';
      if (await _futronicService.isFutronicConnected()) return 'futronic';
    } catch (_) {}
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
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
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
                        child: Text('ATTENDANCE MONITORING',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold))),
                    Text('Attempt $_currentAttempt/3',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Text(widget.person['person_name'] ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$personType ID: ${widget.person['person_id']}',
                        style: const TextStyle(fontSize: 14)),
                    Text('Class: ${widget.classID}',
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: isLowTime ? Colors.red[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    const Text('Time Remaining',
                        style: TextStyle(fontSize: 14)),
                    Text(_formatCountdown(),
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isLowTime ? Colors.red : Colors.green)),
                    if (isLowTime)
                      const Text('⚠️ TIME RUNNING OUT!',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                      ),
                      child: Text(_fingerprintRequired ? 'VERIFY' : 'PRESENT'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _handleAbsent,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white),
                      child: const Text('ABSENT'),
                    ),
                  ),
                ],
              ),
              if (_verificationStatus.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_verificationStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _verificationStatus.contains('❌')
                            ? Colors.red
                            : Colors.blue)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonitoringAlarm {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _loopTimer;
  bool _isPlaying = false;

  void start() async {
    if (_isPlaying) return;
    _isPlaying = true;
    _playOnce();
    _loopTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      _playOnce();
    });
  }

  void _playOnce() async {
    try {
      // Fallback to FlutterRingtonePlayer since alarm.mp3 is missing from assets
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        looping: false,
        volume: 0.8,
      );
    } catch (e) {
      debugPrint('[MONITORING_ALARM] Error playing ringtone: $e');
      HapticFeedback.vibrate();
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        HapticFeedback.heavyImpact();
      }
    }
  }

  void stop() {
    _isPlaying = false;
    _loopTimer?.cancel();
    _audioPlayer.stop();
  }

  void dispose() {
    stop();
    _audioPlayer.dispose();
  }
}
