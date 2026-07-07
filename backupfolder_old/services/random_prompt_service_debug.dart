import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../config.dart';
import '../database_helper.dart';

class RandomPromptServiceDebug {
  static final RandomPromptServiceDebug _instance = RandomPromptServiceDebug._internal();
  factory RandomPromptServiceDebug() => _instance;
  RandomPromptServiceDebug._internal();

  Timer? _checkTimer;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  int? _currentLearnerId;
  bool _isAppInForeground = true;

  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[RANDOM_PROMPT_DEBUG] Initializing service...');
      
      // Initialize notifications
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(settings);

      _isInitialized = true;
      debugPrint('[RANDOM_PROMPT_DEBUG] Service initialized successfully');
    } catch (e) {
      debugPrint('[RANDOM_PROMPT_DEBUG] Initialization error: $e');
    }
  }

  // Start monitoring for a specific learner
  Future<void> startMonitoring(int learnerId) async {
    await initialize();
    _currentLearnerId = learnerId;
    
    debugPrint('[RANDOM_PROMPT_DEBUG] Starting monitoring for learner $learnerId');
    
    // Check immediately
    await _checkForPrompts();
    
    // Start periodic checking every 30 seconds
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      debugPrint('[RANDOM_PROMPT_DEBUG] Periodic check for learner $learnerId');
      _checkForPrompts();
    });
    
    debugPrint('[RANDOM_PROMPT_DEBUG] Monitoring started for learner $learnerId');
  }

  // Stop monitoring
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _currentLearnerId = null;
    debugPrint('[RANDOM_PROMPT_DEBUG] Monitoring stopped');
  }

  // Set app foreground status
  void setAppForegroundStatus(bool isForeground) {
    _isAppInForeground = isForeground;
    debugPrint('[RANDOM_PROMPT_DEBUG] App foreground status: $isForeground');
  }

  // Check for pending prompts
  Future<void> _checkForPrompts() async {
    if (_currentLearnerId == null) {
      debugPrint('[RANDOM_PROMPT_DEBUG] No current learner ID, skipping check');
      return;
    }

    try {
      debugPrint('[RANDOM_PROMPT_DEBUG] Checking for prompts for learner $_currentLearnerId');
      
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/check_monitoring_prompts.php'),
        body: {'learner_id': _currentLearnerId.toString()},
      ).timeout(const Duration(seconds: 10));

      debugPrint('[RANDOM_PROMPT_DEBUG] Server response status: ${response.statusCode}');
      debugPrint('[RANDOM_PROMPT_DEBUG] Server response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('[RANDOM_PROMPT_DEBUG] Parsed response: $data');
        
        if (data['success'] == true && data['has_prompt'] == true) {
          final prompt = data['current_prompt'];
          final timeRemaining = prompt['time_remaining'];
          
          debugPrint('[RANDOM_PROMPT_DEBUG] Prompt found! Time remaining: $timeRemaining seconds');
          
          // Trigger notification and vibration if app is in background
          if (!_isAppInForeground) {
            debugPrint('[RANDOM_PROMPT_DEBUG] App in background, showing notification and vibrating');
            await _showPromptNotification(prompt);
            await _vibratePhone();
          } else {
            debugPrint('[RANDOM_PROMPT_DEBUG] App in foreground, notification not needed');
          }
          
          // Store the prompt locally for when user opens the app
          await _storePromptLocally(prompt);
        } else {
          debugPrint('[RANDOM_PROMPT_DEBUG] No pending prompts found');
        }
      } else {
        debugPrint('[RANDOM_PROMPT_DEBUG] HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[RANDOM_PROMPT_DEBUG] Error checking prompts: $e');
    }
  }

  // Vibrate the phone
  Future<void> _vibratePhone() async {
    try {
      debugPrint('[RANDOM_PROMPT_DEBUG] Attempting to vibrate phone');
      if (await Vibration.hasVibrator() ?? false) {
        await Vibration.vibrate(duration: 500);
        debugPrint('[RANDOM_PROMPT_DEBUG] Phone vibrated successfully');
      } else {
        debugPrint('[RANDOM_PROMPT_DEBUG] Device does not support vibration');
      }
    } catch (e) {
      debugPrint('[RANDOM_PROMPT_DEBUG] Vibration error: $e');
    }
  }

  // Show notification to bring user back to app
  Future<void> _showPromptNotification(Map<String, dynamic> prompt) async {
    try {
      final timeRemaining = prompt['time_remaining'];
      final minutes = (timeRemaining / 60).floor();
      final seconds = timeRemaining % 60;
      
      debugPrint('[RANDOM_PROMPT_DEBUG] Showing notification: ${minutes}m ${seconds}s remaining');
      
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
        ongoing: true,
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
        999,
        '⚠️ Biometric Verification Required',
        'Please verify your fingerprint within ${minutes}m ${seconds}s. Tap to open app.',
        details,
        payload: json.encode(prompt),
      );
      
      debugPrint('[RANDOM_PROMPT_DEBUG] Notification shown successfully');
    } catch (e) {
      debugPrint('[RANDOM_PROMPT_DEBUG] Notification error: $e');
    }
  }

  // Store prompt locally in database
  Future<void> _storePromptLocally(Map<String, dynamic> prompt) async {
    try {
      debugPrint('[RANDOM_PROMPT_DEBUG] Storing prompt locally');
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
      
      debugPrint('[RANDOM_PROMPT_DEBUG] Prompt stored locally successfully');
    } catch (e) {
      debugPrint('[RANDOM_PROMPT_DEBUG] Error storing prompt: $e');
    }
  }

  // Get pending prompt from local database
  Future<Map<String, dynamic>?> getPendingPrompt(int learnerId) async {
    try {
      debugPrint('[RANDOM_PROMPT_DEBUG] Getting pending prompt for learner $learnerId');
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
        debugPrint('[RANDOM_PROMPT_DEBUG] Found pending prompt: ${results.first}');
        return results.first;
      } else {
        debugPrint('[RANDOM_PROMPT_DEBUG] No pending prompt found');
      }
    } catch (e) {
      debugPrint('[RANDOM_PROMPT_DEBUG] Error getting prompt: $e');
    }
    return null;
  }

  void dispose() {
    _checkTimer?.cancel();
    debugPrint('[RANDOM_PROMPT_DEBUG] Service disposed');
  }
}
