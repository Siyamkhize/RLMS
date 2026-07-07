import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class GuardianApiResult {
  final bool success;
  final String message;

  const GuardianApiResult({required this.success, required this.message});
}

class GuardianApiService {
  static const _timeout = Duration(seconds: 15);

  static Future<GuardianApiResult> sendGuardianDetails(
      Map<String, dynamic> guardianData,
      ) async {
    final url = Uri.parse('${AppConfig.baseUrl}/save_guardian.php');

    // Sanitize payload (PHP script expects JSON fields, so make sure we send strings).
    final payload = guardianData.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
    );

    try {
      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return GuardianApiResult(
          success: false,
          message: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final decoded =
      response.body.isNotEmpty ? jsonDecode(response.body) : null;
      final success = decoded is Map<String, dynamic> &&
          (decoded['success'] == true ||
              decoded['success']?.toString().toLowerCase() == 'true');
      final message = decoded is Map<String, dynamic>
          ? (decoded['message']?.toString() ??
          (success ? 'Guardian synced' : 'Unknown server response'))
          : 'Invalid response';

      return GuardianApiResult(success: success, message: message);
    } catch (e) {
      return GuardianApiResult(success: false, message: e.toString());
    }
  }
}