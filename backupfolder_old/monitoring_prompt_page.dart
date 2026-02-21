import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'services/fingerprint_service.dart';
import 'services/random_prompt_service.dart';
import 'database_helper.dart';

class MonitoringPromptPage extends StatefulWidget {
  final int learnerId;
  final Map<String, dynamic> prompt;

  const MonitoringPromptPage({
    super.key,
    required this.learnerId,
    required this.prompt,
  });

  @override
  State<MonitoringPromptPage> createState() => _MonitoringPromptPageState();
}

class _MonitoringPromptPageState extends State<MonitoringPromptPage>
    with WidgetsBindingObserver {
  final FingerprintService _fingerprintService = FingerprintService();
  final RandomPromptService _promptService = RandomPromptService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  int _timeRemaining = 0;
  Timer? _countdownTimer;
  bool _isVerifying = false;
  bool _isCompleted = false;
  String _statusMessage = 'Please verify your fingerprint';
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTime = DateTime.now();
    _timeRemaining = widget.prompt['time_remaining'] ?? 180;
    _startCountdown();
    _vibrateOnStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Vibrate again when app comes to foreground
    if (state == AppLifecycleState.resumed && !_isCompleted) {
      _vibrateOnStart();
    }
  }

  Future<void> _vibrateOnStart() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        await Vibration.vibrate(duration: 500);
      }
    } catch (e) {
      debugPrint('[MONITORING] Vibration error: $e');
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeRemaining--;

          if (_timeRemaining <= 0) {
            _handleTimeout();
          } else if (_timeRemaining <= 10 && _timeRemaining % 2 == 0) {
            // Vibrate every 2 seconds in the last 10 seconds
            _vibrateOnStart();
          }
        });
      }
    });
  }

  void _handleTimeout() {
    _countdownTimer?.cancel();

    if (!_isCompleted) {
      setState(() {
        _isCompleted = true;
        _statusMessage = 'Time expired! Verification failed.';
      });

      // Update status on server
      final responseTime = DateTime.now().difference(_startTime!).inSeconds;
      _promptService.updatePromptStatus(
        monitoringId: widget.prompt['monitoring_id'],
        status: 'timeout',
        responseTime: responseTime,
      );

      _promptService.markPromptCompleted(widget.prompt['monitoring_id']);

      // Show error and go back
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop(false);
        }
      });
    }
  }

  Future<void> _verifyFingerprint() async {
    if (_isVerifying || _isCompleted) return;

    setState(() {
      _isVerifying = true;
      _statusMessage = 'Place your finger on the scanner...';
    });

    try {
      // Get learner's fingerprint templates from database
      final templates =
          await DatabaseHelper().getAllTemplates(widget.learnerId);

      final zkLeft = templates['zkteco_left_template'];
      final zkRight = templates['zkteco_right_template'];
      final futLeft = templates['futronic_left_template'];
      final futRight = templates['futronic_right_template'];

      if ((zkLeft == null || zkLeft.isEmpty) &&
          (zkRight == null || zkRight.isEmpty) &&
          (futLeft == null || futLeft.isEmpty) &&
          (futRight == null || futRight.isEmpty)) {
        throw Exception('No fingerprints enrolled for this learner');
      }

      setState(() {
        _statusMessage = 'Place your finger on the scanner...';
      });

      bool verified = false;

      // Try ZKTeco first if templates available
      if ((zkLeft != null && zkLeft.isNotEmpty) ||
          (zkRight != null && zkRight.isNotEmpty)) {
        try {
          if (zkLeft != null && zkLeft.isNotEmpty) {
            verified = await _fingerprintService.verify('left', zkLeft);
          }
          if (!verified && zkRight != null && zkRight.isNotEmpty) {
            verified = await _fingerprintService.verify('right', zkRight);
          }
        } catch (e) {
          debugPrint('[MONITORING] ZKTeco verification error: $e');
        }
      }

      // Try Futronic if ZKTeco failed or not available
      if (!verified &&
          ((futLeft != null && futLeft.isNotEmpty) ||
              (futRight != null && futRight.isNotEmpty))) {
        try {
          final futronicService = FutronicService();
          final hint =
              (futLeft != null && futLeft.isNotEmpty) ? 'left' : 'right';
          verified = await futronicService.verifyBoth(
            hintFinger: hint,
            leftTemplate: futLeft,
            rightTemplate: futRight,
          );
        } catch (e) {
          debugPrint('[MONITORING] Futronic verification error: $e');
        }
      }

      if (verified) {
        _handleSuccess();
      } else {
        _handleFailure();
      }
    } catch (e) {
      debugPrint('[MONITORING] Verification error: $e');
      setState(() {
        _isVerifying = false;
        _statusMessage = 'Error: ${e.toString()}\nPlease try again.';
      });
    }
  }

  void _handleSuccess() {
    _countdownTimer?.cancel();

    setState(() {
      _isCompleted = true;
      _isVerifying = false;
      _statusMessage = 'Verification successful! ✓';
    });

    // Update status on server
    final responseTime = DateTime.now().difference(_startTime!).inSeconds;
    _promptService.updatePromptStatus(
      monitoringId: widget.prompt['monitoring_id'],
      status: 'completed',
      responseTime: responseTime,
    );

    _promptService.markPromptCompleted(widget.prompt['monitoring_id']);

    // Show success and go back
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  void _handleFailure() {
    setState(() {
      _isVerifying = false;
      _statusMessage = 'Verification failed! Please try again.';
    });

    // Update status on server
    final responseTime = DateTime.now().difference(_startTime!).inSeconds;
    _promptService.updatePromptStatus(
      monitoringId: widget.prompt['monitoring_id'],
      status: 'failed',
      responseTime: responseTime,
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _timeRemaining <= 30;
    final isExpired = _timeRemaining <= 0;

    return WillPopScope(
      onWillPop: () async {
        // Prevent going back unless completed or expired
        return _isCompleted || isExpired;
      },
      child: Scaffold(
        backgroundColor: isExpired
            ? Colors.red[900]
            : isUrgent
                ? Colors.orange[900]
                : Colors.blue[900],
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Alert Icon
                  Icon(
                    isExpired
                        ? Icons.cancel
                        : isUrgent
                            ? Icons.warning
                            : Icons.fingerprint,
                    size: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    'Biometric Verification Required',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Countdown Timer
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      _formatTime(_timeRemaining),
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Status Message
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Verify Button
                  if (!_isCompleted && !isExpired)
                    ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyFingerprint,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor:
                            isUrgent ? Colors.orange[900] : Colors.blue[900],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 48, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isVerifying)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  isUrgent
                                      ? Colors.orange[900]
                                      : Colors.blue[900],
                                ),
                              ),
                            )
                          else
                            const Icon(Icons.fingerprint, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            _isVerifying ? 'Verifying...' : 'Verify Now',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Warning message
                  if (!_isCompleted && !isExpired)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You must verify your fingerprint before time expires.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
