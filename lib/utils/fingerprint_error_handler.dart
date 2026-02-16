import 'package:flutter/material.dart';

class FingerprintErrorHandler {
  
  /// Convert raw system errors to user-friendly messages
  static String getFriendlyErrorMessage(String error) {
    if (error.isEmpty) return 'Unknown error occurred';
    
    // Convert to lowercase for easier matching
    String lowerError = error.toLowerCase();
    
    // Partial fingerprint errors
    if (lowerError.contains('capture_partial') || lowerError.contains('partial')) {
      return 'Finger not placed properly. Please place your full thumb on the scanner.';
    }
    
    // Wrong finger errors
    if (lowerError.contains('no_match') || lowerError.contains('verification_failed')) {
      return 'Fingerprint not recognized. Please try with your enrolled finger.';
    }
    
    // Connection errors
    if (lowerError.contains('usb_open_failed') || lowerError.contains('device_open_failed')) {
      return 'Scanner not connected. Please check USB connection and try again.';
    }
    
    // Capture errors
    if (lowerError.contains('capture_failed') || lowerError.contains('capture_error')) {
      return 'Could not capture fingerprint. Please place finger firmly on scanner.';
    }
    
    // Timeout errors
    if (lowerError.contains('timeout') || lowerError.contains('timed_out')) {
      return 'Timeout waiting for fingerprint. Please try again.';
    }
    
    // Sensor busy errors
    if (lowerError.contains('sensor_busy') || lowerError.contains('busy')) {
      return 'Scanner is busy. Please wait a moment and try again.';
    }
    
    // Template errors
    if (lowerError.contains('template') && lowerError.contains('invalid')) {
      return 'Fingerprint template corrupted. Please re-enroll your fingerprints.';
    }
    
    // General platform exceptions
    if (lowerError.contains('platformexception')) {
      return 'Scanner communication error. Please try again.';
    }
    
    // If no specific match, return a generic friendly message
    return 'Fingerprint verification failed. Please try again.';
  }
  
  /// Show error message with appropriate styling
  static void showError(BuildContext context, String error, {Duration duration = const Duration(seconds: 3)}) {
    String friendlyMessage = getFriendlyErrorMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                friendlyMessage,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  /// Show success message
  static void showSuccess(BuildContext context, String message, {Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  /// Show info message
  static void showInfo(BuildContext context, String message, {Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  /// Get appropriate icon for error type
  static IconData getErrorIcon(String error) {
    String lowerError = error.toLowerCase();
    
    if (lowerError.contains('partial') || lowerError.contains('capture')) {
      return Icons.touch_app;
    }
    
    if (lowerError.contains('connection') || lowerError.contains('usb')) {
      return Icons.usb_off;
    }
    
    if (lowerError.contains('timeout')) {
      return Icons.timer_off;
    }
    
    if (lowerError.contains('busy')) {
      return Icons.hourglass_empty;
    }
    
    return Icons.warning;
  }
  
  /// Get appropriate color for error type
  static Color getErrorColor(String error) {
    String lowerError = error.toLowerCase();
    
    if (lowerError.contains('partial') || lowerError.contains('capture')) {
      return Colors.orange[700]!;
    }
    
    if (lowerError.contains('connection') || lowerError.contains('usb')) {
      return Colors.red[700]!;
    }
    
    if (lowerError.contains('timeout')) {
      return Colors.amber[700]!;
    }
    
    return Colors.red[700]!;
  }
}
