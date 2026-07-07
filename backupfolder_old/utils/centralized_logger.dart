import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'clocking_logger.dart';

class CentralizedLogger {
  static const String _serverEndpoint = 'https://your-server.com/mobile/collect_logs.php';
  
  // Send logs to server for centralized collection
  static Future<void> sendLogsToServer() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final deviceId = androidInfo.id; // Unique device identifier
      
      final logs = await ClockingLogger.instance.getRecentLogs(maxLines: 100);
      
      final payload = {
        'device_id': deviceId,
        'device_model': androidInfo.model,
        'app_version': '1.0.0', // Your app version
        'timestamp': DateTime.now().toIso8601String(),
        'logs': logs,
      };
      
      final response = await http.post(
        Uri.parse(_serverEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      
      if (response.statusCode == 200) {
        print('✅ Logs sent to server successfully');
      } else {
        print('❌ Failed to send logs: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error sending logs to server: $e');
    }
  }
  
  // Get logs from all devices for a specific time period
  static Future<Map<String, dynamic>> getLogsFromAllDevices({
    required DateTime fromTime,
    required DateTime toTime,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_serverEndpoint?action=get_logs&from=${fromTime.toIso8601String()}&to=${toTime.toIso8601String()}'),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch centralized logs: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching centralized logs: $e');
    }
  }
}