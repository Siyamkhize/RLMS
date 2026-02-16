// class FutronicService {
//   /// Check if the Futronic scanner is connected
//   Future<bool> isFutronicConnected() async {
//     try {
//       // TODO: Implement actual Futronic connection check
//       // For now, return false to indicate no Futronic scanner is available
//       return false;
//     } catch (e) {
//       print('Error checking Futronic connection: $e');
//       return false;
//     }
//   }
//
//   /// Request USB permission for Futronic scanner
//   Future<bool> requestUsbPermission() async {
//     try {
//       final bool? result = await _channel.invokeMethod('requestUsbPermission');
//       return result ?? false;
//     } catch (e) {
//       print('Error requesting USB permission: $e');
//       return false;
//     }
//   }
//   /// Verify fingerprint against both left and right templates
//   Future<bool> verifyBoth({
//     required String hintFinger,
//     String? leftTemplate,
//     String? rightTemplate,
//   }) async {
//     try {
//       // TODO: Implement actual Futronic verification
//       // For now, throw an exception to indicate the service is not implemented
//       throw Exception('Futronic service not implemented - please use ZKTeco scanner instead');
//     } catch (e) {
//       print('Futronic verification error: $e');
//       rethrow;
//     }
//   }
// }
import 'package:flutter/services.dart';

class FutronicService {
  static const MethodChannel _channel = MethodChannel('futronic_channel');

  /// Check if the Futronic scanner is connected
  Future<bool> isFutronicConnected() async {
    try {
      final bool? result = await _channel.invokeMethod('isFutronicConnected');
      return result ?? false;
    } catch (e) {
      print('Error checking Futronic connection: $e');
      return false;
    }
  }

  /// Request USB permission for Futronic scanner
  Future<bool> requestUsbPermission() async {
    try {
      final bool? result = await _channel.invokeMethod('requestUsbPermission');
      return result ?? false;
    } catch (e) {
      print('Error requesting USB permission: $e');
      return false;
    }
  }

  /// Check if USB permission is granted for Futronic scanner
  Future<bool> checkUsbPermission() async {
    try {
      final bool? result = await _channel.invokeMethod('checkUsbPermission');
      return result ?? false;
    } catch (e) {
      print('Error checking USB permission: $e');
      return false;
    }
  }

  /// Verify fingerprint against both left and right templates
  Future<bool> verifyBoth({
    required String hintFinger,
    String? leftTemplate,
    String? rightTemplate,
  }) async {
    try {
      final bool? result = await _channel.invokeMethod('verifyBoth', {
        'hintFinger': hintFinger,
        'templateLeft': leftTemplate,
        'templateRight': rightTemplate,
      });
      return result ?? false;
    } catch (e) {
      print('Futronic verification error: $e');
      rethrow;
    }
  }
}
