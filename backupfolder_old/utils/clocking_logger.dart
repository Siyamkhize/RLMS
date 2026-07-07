import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ClockingLogger {
  static ClockingLogger? _instance;
  static ClockingLogger get instance => _instance ??= ClockingLogger._();
  
  ClockingLogger._();
  
  late String _logFilePath;
  bool _initialized = false;

  // Initialize the logger with file path
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFilePath = '${directory.path}/clocking_debug.log';
      _initialized = true;
      
      // Write session start marker
      await _writeToFile('\n${'='*80}');
      await _writeToFile('🚀 NEW CLOCKING SESSION STARTED: ${_getTimestamp()}');
      await _writeToFile('📱 App Version: ${DateTime.now().millisecondsSinceEpoch}');
      await _writeToFile('${'='*80}\n');
    } catch (e) {
      print('Failed to initialize ClockingLogger: $e');
    }
  }

  // Get current timestamp
  String _getTimestamp() {
    return DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
  }

  // Write to log file
  Future<void> _writeToFile(String message) async {
    if (!_initialized) await initialize();
    
    try {
      final file = File(_logFilePath);
      await file.writeAsString('$message\n', mode: FileMode.append);
    } catch (e) {
      print('Failed to write to log file: $e');
    }
  }

  // Log clock-in attempt
  Future<void> logClockInAttempt(String learnerID, String source, {Map<String, dynamic>? additionalData}) async {
    final timestamp = _getTimestamp();
    final message = '''
🟢 CLOCK-IN ATTEMPT
📅 Time: $timestamp
👤 LearnerID: $learnerID
📍 Source: $source
📊 Additional Data: ${additionalData != null ? jsonEncode(additionalData) : 'None'}
${'─' * 60}''';
    
    await _writeToFile(message);
    print('🟢 [CLOCK-IN] $learnerID via $source at $timestamp');
  }

  // Log clock-out attempt
  Future<void> logClockOutAttempt(String learnerID, String source, {Map<String, dynamic>? additionalData}) async {
    final timestamp = _getTimestamp();
    final message = '''
🔴 CLOCK-OUT ATTEMPT
📅 Time: $timestamp
👤 LearnerID: $learnerID
📍 Source: $source
📊 Additional Data: ${additionalData != null ? jsonEncode(additionalData) : 'None'}
${'─' * 60}''';
    
    await _writeToFile(message);
    print('🔴 [CLOCK-OUT] $learnerID via $source at $timestamp');
  }

  // Log data changes from server fetch
  Future<void> logServerDataChange(String learnerID, String changeType, String? oldValue, String? newValue) async {
    final timestamp = _getTimestamp();
    final message = '''
🔄 SERVER DATA CHANGE DETECTED
📅 Time: $timestamp
👤 LearnerID: $learnerID
🔄 Change Type: $changeType
📤 Old Value: ${oldValue ?? 'null'}
📥 New Value: ${newValue ?? 'null'}
⚠️  Source: Server Fetch (get_clocking_data.php)
${'─' * 60}''';
    
    await _writeToFile(message);
    print('🔄 [SERVER-CHANGE] $learnerID $changeType: "$oldValue" → "$newValue"');
  }

  // Log sync operations
  Future<void> logSyncOperation(String operation, String status, {Map<String, dynamic>? details}) async {
    final timestamp = _getTimestamp();
    final message = '''
🔄 SYNC OPERATION
📅 Time: $timestamp
🔧 Operation: $operation
📊 Status: $status
📋 Details: ${details != null ? jsonEncode(details) : 'None'}
${'─' * 60}''';
    
    await _writeToFile(message);
    print('🔄 [SYNC] $operation: $status');
  }

  // Log database operations
  Future<void> logDatabaseOperation(String operation, String table, String learnerID, Map<String, dynamic> data) async {
    final timestamp = _getTimestamp();
    final message = '''
💾 DATABASE OPERATION
📅 Time: $timestamp
🔧 Operation: $operation
📋 Table: $table
👤 LearnerID: $learnerID
📊 Data: ${jsonEncode(data)}
${'─' * 60}''';
    
    await _writeToFile(message);
    print('💾 [DB] $operation on $table for $learnerID');
  }

  // Log fingerprint verification
  Future<void> logFingerprintVerification(String learnerID, bool success, String scanner, {String? error}) async {
    final timestamp = _getTimestamp();
    final status = success ? '✅ SUCCESS' : '❌ FAILED';
    final message = '''
👆 FINGERPRINT VERIFICATION
📅 Time: $timestamp
👤 LearnerID: $learnerID
📊 Result: $status
🖨️ Scanner: $scanner
${error != null ? '❌ Error: $error' : ''}
${'─' * 60}''';
    
    await _writeToFile(message);
    print('👆 [FINGERPRINT] $learnerID $status via $scanner');
  }

  // Log HTTP requests
  Future<void> logHttpRequest(String method, String url, Map<String, dynamic>? payload, int statusCode, String response) async {
    final timestamp = _getTimestamp();
    final message = '''
🌐 HTTP REQUEST
📅 Time: $timestamp
🔧 Method: $method
🌍 URL: $url
📤 Payload: ${payload != null ? jsonEncode(payload) : 'None'}
📊 Status Code: $statusCode
📥 Response: ${response.length > 500 ? '${response.substring(0, 500)}...[TRUNCATED]' : response}
${'─' * 60}''';
    
    await _writeToFile(message);
    print('🌐 [HTTP] $method $url → $statusCode');
  }

  // Log periodic refresh cycles
  Future<void> logPeriodicRefresh(int learnersChecked, List<String> changedLearners) async {
    final timestamp = _getTimestamp();
    final message = '''
🔄 PERIODIC REFRESH CYCLE
📅 Time: $timestamp
👥 Learners Checked: $learnersChecked
🔄 Changes Detected: ${changedLearners.length}
👤 Changed Learners: ${changedLearners.join(', ')}
${'─' * 60}''';
    
    await _writeToFile(message);
    if (changedLearners.isNotEmpty) {
      print('🔄 [REFRESH] Changes detected for: ${changedLearners.join(', ')}');
    }
  }

  // Log app lifecycle events
  Future<void> logAppLifecycle(String event, {String? details}) async {
    final timestamp = _getTimestamp();
    final message = '''
📱 APP LIFECYCLE EVENT
📅 Time: $timestamp
🔧 Event: $event
📋 Details: ${details ?? 'None'}
${'─' * 60}''';
    
    await _writeToFile(message);
    print('📱 [LIFECYCLE] $event');
  }

  // Log errors and exceptions
  Future<void> logError(String context, dynamic error, {StackTrace? stackTrace}) async {
    final timestamp = _getTimestamp();
    final message = '''
❌ ERROR OCCURRED
📅 Time: $timestamp
📍 Context: $context
🚨 Error: $error
📋 Stack Trace: ${stackTrace?.toString() ?? 'Not provided'}
${'─' * 60}''';
    
    await _writeToFile(message);
    print('❌ [ERROR] $context: $error');
  }

  // Get log file path for sharing/debugging
  String get logFilePath => _logFilePath;

  // Clear old logs (optional maintenance)
  Future<void> clearOldLogs() async {
    if (!_initialized) await initialize();
    
    try {
      final file = File(_logFilePath);
      if (await file.exists()) {
        await file.writeAsString('');
        await _writeToFile('🧹 LOG FILE CLEARED: ${_getTimestamp()}');
      }
    } catch (e) {
      print('Failed to clear log file: $e');
    }
  }

  // Read recent logs (for debugging)
  Future<String> getRecentLogs({int maxLines = 100}) async {
    if (!_initialized) await initialize();
    
    try {
      final file = File(_logFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final lines = content.split('\n');
        final recentLines = lines.length > maxLines 
            ? lines.sublist(lines.length - maxLines)
            : lines;
        return recentLines.join('\n');
      }
    } catch (e) {
      print('Failed to read log file: $e');
    }
    return 'No logs available';
  }

  // Create a summary report
  Future<void> generateSummaryReport() async {
    final timestamp = _getTimestamp();
    final message = '''

📊 CLOCKING SESSION SUMMARY REPORT
📅 Generated: $timestamp
${'='*80}

🔍 TO ANALYZE ISSUES:
1. Look for patterns in clock-out timing
2. Check for SERVER DATA CHANGE entries that show unexpected clock-outs
3. Monitor SYNC OPERATION entries for data overwrites
4. Review HTTP REQUEST entries for unexpected calls to clockout.php
5. Check PERIODIC REFRESH entries for unwanted data changes

🚨 RED FLAGS TO WATCH FOR:
- Clock-out changes with "Source: Server Fetch"
- Sync operations clearing/replacing local data
- HTTP requests to clockout.php you didn't initiate
- Database operations showing unexpected clock_out_time updates

${'='*80}

''';
    
    await _writeToFile(message);
    print('📊 Summary report generated in log file');
  }
}