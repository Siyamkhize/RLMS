import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../config.dart';
import '../database_helper.dart';

class RandomPromptService {
  static final RandomPromptService _instance = RandomPromptService._internal();
  factory RandomPromptService() => _instance;
  RandomPromptService._internal();

  Timer? _checkTimer;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  int? _currentLearnerId;
  bool _isAppInForeground = true;

  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize notifications
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      _isInitialized = true;
      debugPrint('[RANDOM_PROMPT] Service initialized');
    } catch (e) {
      debugPrint('[RANDOM_PROMPT] Initialization error: $e');
    }
  }

  // Start monitoring for a specific learner
  Future<void> startMonitoring(int learnerId) async {
    await initialize();
    _currentLearnerId = learnerId;
    
    // Check immediately
    await _checkForPrompts();
    
    // Start periodic checking every 30 seconds
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkForPrompts();
    });
    
    debugPrint('[RANDOM_PROMPT] Started monitoring for learner $learnerId');
  }

  // Stop monitoring
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _currentLearnerId = null;
    debugPrint('[RANDOM_PROMPT] Stopped monitoring');
  }

  // Set app foreground status
  void setAppForegroundStatus(bool isForeground) {
    _isAppInForeground = isForeground;
    debugPrint('[RANDOM_PROMPT] App foreground status: $isForeground');
  }

  // Check for pending prompts
  Future<void> _checkForPrompts() async {
    if (_currentLearnerId == null) return;

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/check_monitoring_prompts.php'),
        body: {'learner_id': _currentLearnerId.toString()},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['has_prompt'] == true) {
          final prompt = data['current_prompt'];
          final timeRemaining = prompt['time_remaining'];
          
          debugPrint('[RANDOM_PROMPT] Prompt found: $timeRemaining seconds remaining');
          
          // Trigger notification and vibration if app is in background
          if (!_isAppInForeground) {
            await _showPromptNotification(prompt);
            await _vibratePhone();
          }
          
          // Store the prompt locally for when user opens the app
          await _storePromptLocally(prompt);
        }
      }
    } catch (e) {
      debugPrint('[RANDOM_PROMPT] Error checking prompts: $e');
    }
  }

  // Vibrate the phone
  Future<void> _vibratePhone() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        // Vibrate in pattern: wait 500ms, vibrate 1000ms, wait 500ms, vibrate 1000ms
        await Vibration.vibrate(
          pattern: [500, 1000, 500, 1000],
          intensities: [0, 255, 0, 255],
        );
        debugPrint('[RANDOM_PROMPT] Phone vibrated');
      }
    } catch (e) {
      debugPrint('[RANDOM_PROMPT] Vibration error: $e');
    }
  }

  // Show notification to bring user back to app
  Future<void> _showPromptNotification(Map<String, dynamic> prompt) async {
    try {
      final timeRemaining = prompt['time_remaining'];
      final minutes = (timeRemaining / 60).floor();
      final seconds = timeRemaining % 60;
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'biometric_prompts',
        'Biometric Verification',
        channelDescription: 'Random biometric verification prompts',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Biometric verification required',
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        ongoing: true, // Can't be dismissed
        autoCancel: false,
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      );
      
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _notificationsPlugin.show(
        999, // Fixed ID for biometric prompts
        '⚠️ Biometric Verification Required',
        'Please verify your fingerprint within ${minutes}m ${seconds}s. Tap to open app.',
        details,
        payload: json.encode(prompt),
      );
      
      debugPrint('[RANDOM_PROMPT] Notification shown');
    } catch (e) {
      debugPrint('[RANDOM_PROMPT] Notification error: $e');
    }
  }

  // Handle notification tap - opens the app
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[RANDOM_PROMPT] Notification tapped');
    // The app will automatically check for prompts when it opens
  }

  // Store prompt locally in database
  Future<void> _storePromptLocally(Map<String, dynamic> prompt) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      
      // Store or update the prompt
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_prompts (
          monitoring_id INTEGER PRIMARY KEY,
          learner_id INTEGER NOT NULL,
          prompt_type TEXT NOT NULL,
          prompt_time TEXT NOT NULL,
          countdown_duration INTEGER NOT NULL,
          time_remaining INTEGER NOT NULL,
          status TEXT DEFAULT 'pending'
        )
      ''');
      
      await db.rawInsert('''
        INSERT OR REPLACE INTO pending_prompts 
        (monitoring_id, learner_id, prompt_type, prompt_time, countdown_duration, time_remaining, status)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [
        prompt['monitoring_id'],
        prompt['learner_id'],
        prompt['prompt_type'],
        prompt['prompt_time'],
        prompt['countdown_duration'],
        prompt['time_remaining'],
        'pending',
      ]);
      
      debugPrint('[RANDOM_PROMPT] Prompt stored locally');
    } catch (e) {
      debugPrint('[RANDOM_PROMPT] Error storing prompt: $e');
    }
  }

  // Get pending prompt from local database
  Future<Map<String, dynamic>?> getPendingPrompt(int learnerId) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      
      final results = await db.query(
        'pending_prompts',
        where: 'learner_id = ? AND status = ?',
        whereArgs: [learnerId, 'pending'],
        orderBy: 'prompt_time DESC',
        limit: 1,
      );
      
      if (results.isNotEmpty) {
        return results.first;
      }
    } catch (e) {
      debugPrint('[RANDOM_PROMPT] Error getting prompt: $e');
    }
    return null;
  }

  // Mark prompt as completed locally
  Future<void> markPromptCompleted(int monitoringId) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      
      await db.update(
        'pending_prompts',
        {'status': 'completed'},
        where: 'monitoring_id = ?',
        whereArgs: [monitoringId],
      );
      
      // Also dismiss notification
      await _notificationsPlugin.cancel(999);
      
      debugPrint('[RANDOM_PROMPT] Prompt marked as completed');
    } catch (e) {
      debugPrint('[RANDOM_PROMPT] Error marking prompt completed: $e');
    }
  }

  // Update prompt status on server
  Future<bool> updatePromptStatus({
    required int monitoringId,
    required String status,
    required int responseTime,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/update_monitoring_status.php'),
        body: {
          'monitoring_id': monitoringId.toString(),
          'status': status,
          'response_time': responseTime.toString(),
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint('[RANDOM_PROMPT] Error updating status: $e');
    }
    return false;
  }

  void dispose() {
    _checkTimer?.cancel();
    debugPrint('[RANDOM_PROMPT] Service disposed');
  }
}

