// Test script for enhanced clocking days functionality
// This is a standalone test to verify the server API works

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('=== Testing Enhanced Clocking Days Count ===\n');
  
  // Test configuration
  const String baseUrl = 'https://rlms.rlms.co.za/mobile';
  const String testLearnerId = '1'; // Change this to a valid learner ID
  
  // Test 1: Get clocking days without including today
  print('Test 1: Get clocking days (excluding today)');
  await testClockingDaysCount(baseUrl, testLearnerId, false);
  
  print('\n' + '='*50 + '\n');
  
  // Test 2: Get clocking days including today
  print('Test 2: Get clocking days (including today)');
  await testClockingDaysCount(baseUrl, testLearnerId, true);
  
  print('\n=== Test Complete ===');
}

Future<void> testClockingDaysCount(String baseUrl, String learnerId, bool includeToday) async {
  try {
    final url = '$baseUrl/get_clocking_days_count.php';
    final uri = Uri.parse(url).replace(queryParameters: {
      'learner_id': learnerId,
      'include_today': includeToday.toString(),
    });
    
    print('Request URL: $uri');
    
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    
    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final clockingDays = data['data']['clocking_days'];
        final workingDays = data['data']['working_days'];
        final month = data['data']['month'];
        
        print('✅ SUCCESS:');
        print('  - Learner ID: $learnerId');
        print('  - Month: $month');
        print('  - Clocking Days: $clockingDays');
        print('  - Working Days: $workingDays');
        print('  - Include Today: $includeToday');
        print('  - Message: ${data['message']}');
      } else {
        print('❌ API Error: ${data['error']}');
      }
    } else {
      print('❌ HTTP Error: ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}