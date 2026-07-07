import 'dart:async';
import 'package:flutter/material.dart';
import '../services/random_prompt_service.dart';
import '../monitoring_prompt_page.dart';

/// Mixin to add monitoring prompt checking to learner pages
mixin MonitoringMixin<T extends StatefulWidget> on State<T> {
  Timer? _monitoringCheckTimer;
  int? _currentLearnerId;
  bool _isCheckingPrompt = false;

  /// Initialize monitoring for a learner
  void initMonitoring(int learnerId) {
    _currentLearnerId = learnerId;
    
    // Start the monitoring service
    RandomPromptService().startMonitoring(learnerId);
    
    // Check immediately
    _checkForPrompts();
    
    // Check every 20 seconds
    _monitoringCheckTimer?.cancel();
    _monitoringCheckTimer = Timer.periodic(
      const Duration(seconds: 20),
      (timer) => _checkForPrompts(),
    );
    
    debugPrint('[MONITORING_MIXIN] Started monitoring for learner $learnerId');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _monitoringCheckTimer?.cancel();
    _monitoringCheckTimer = null;
    RandomPromptService().stopMonitoring();
    debugPrint('[MONITORING_MIXIN] Stopped monitoring');
  }

  /// Check for pending prompts
  Future<void> _checkForPrompts() async {
    if (_isCheckingPrompt || _currentLearnerId == null || !mounted) return;

    _isCheckingPrompt = true;
    
    try {
      final prompt = await RandomPromptService().getPendingPrompt(_currentLearnerId!);
      
      if (prompt != null && mounted) {
        debugPrint('[MONITORING_MIXIN] Pending prompt found, showing prompt page');
        
        // Show the monitoring prompt page
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MonitoringPromptPage(
              learnerId: _currentLearnerId!,
              prompt: prompt,
            ),
          ),
        );
        
        if (result == true) {
          debugPrint('[MONITORING_MIXIN] Prompt verification successful');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Biometric verification successful'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          debugPrint('[MONITORING_MIXIN] Prompt verification failed or timeout');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠ Biometric verification failed'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[MONITORING_MIXIN] Error checking prompts: $e');
    } finally {
      _isCheckingPrompt = false;
    }
  }

  /// Call this in dispose() of your widget
  void disposeMonitoring() {
    stopMonitoring();
  }
}

