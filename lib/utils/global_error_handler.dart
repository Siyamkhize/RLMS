import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';

/// Global error handler to catch uncaught exceptions and prevent app crashes
class GlobalErrorHandler {
  static void initialize() {
    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('[GLOBAL_ERROR] Flutter Error: ${details.exception}');
      debugPrint('[GLOBAL_ERROR] Stack trace: ${details.stack}');

      // ENHANCED: Check for all document scanner related errors
      if (_isDocumentScannerError(details.exception.toString()) ||
          _isDocumentScannerError(details.stack.toString())) {
        debugPrint(
            '[GLOBAL_ERROR] Document scanner error detected - preventing crash');
        // Don't crash the app for scanner errors
        return;
      }

      // For other errors, use default handling
      FlutterError.presentError(details);
    };

    // Catch async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('[GLOBAL_ERROR] Platform Error: $error');
      debugPrint('[GLOBAL_ERROR] Stack trace: $stack');

      // ENHANCED: Check for all document scanner related errors
      if (_isDocumentScannerError(error.toString()) ||
          _isDocumentScannerError(stack.toString())) {
        debugPrint(
            '[GLOBAL_ERROR] Document scanner platform error detected - preventing crash');
        return true; // Handled, don't crash
      }

      return false; // Not handled, use default behavior
    };

    // Catch zone errors
    runZonedGuarded(() {
      // App initialization will happen here
    }, (error, stack) {
      debugPrint('[GLOBAL_ERROR] Zone Error: $error');
      debugPrint('[GLOBAL_ERROR] Stack trace: $stack');

      // ENHANCED: Check for all document scanner related errors
      if (_isDocumentScannerError(error.toString()) ||
          _isDocumentScannerError(stack.toString())) {
        debugPrint(
            '[GLOBAL_ERROR] Document scanner zone error detected - preventing crash');
        // Don't crash for scanner errors
        return;
      }
    });
  }

  /// ENHANCED: Comprehensive check for document scanner related errors
  static bool _isDocumentScannerError(String errorString) {
    final scannerErrorPatterns = [
      // Flutter Doc Scanner plugin errors
      'FlutterDocScanner',
      'flutter_doc_scanner',
      'pendingResult',
      'onActivityResult',
      'requestCode=213312',

      // ML Kit Document Scanner errors
      'GmsDocumentScanningDelegateActivity',
      'DocumentScanningActivity',
      'mlkit.vision.documentscanner',
      'com.google.mlkit.vision.documentscanner',
      'com.google.android.gms.mlkit.docscan',

      // Activity lifecycle errors during scanning
      'ActivityRecord{.*DocumentScanningActivity',
      'ActivityRecord{.*GmsDocumentScanningDelegateActivity',

      // Camera/Scanner resource errors
      'Camera.*scanner',
      'Scanner.*camera',
      'MLKit.*scanner',

      // Memory errors during large document scanning
      'OutOfMemoryError.*scanner',
      'OutOfMemoryError.*document',

      // Plugin callback errors
      'MethodChannel.*scanner',
      'MethodChannel.*document',
      'PlatformException.*scanner',

      // Activity transition errors
      'TransitionRecord.*DocumentScanning',
      'TransitionRecord.*GmsDocumentScanning',

      // Surface/UI errors during scanner
      'Surface.*DocumentScanning',
      'Surface.*GmsDocumentScanning',
    ];

    return scannerErrorPatterns.any((pattern) =>
        RegExp(pattern, caseSensitive: false).hasMatch(errorString));
  }

  /// Show a user-friendly error dialog for document scanner issues
  static void showDocumentScannerError(BuildContext context, String error) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Scanner Error'),
          ],
        ),
        content: const Text(
          'The document scanner encountered an error and was safely recovered.\n\n'
          'This is a known issue with the scanner plugin. Please try again or restart the app if the problem persists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
