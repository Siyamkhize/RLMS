import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/fingerprint_error_handler.dart';

class FingerprintService {
  static const _channel = MethodChannel('com.example.rlmss/fingerprint');

  final _enrollStatusController = StreamController<String>.broadcast();
  final _enrollSuccessController = StreamController<Map<String, dynamic>>.broadcast();
  final _sensorStatusController = StreamController<String>.broadcast();
  final _verifyResultController = StreamController<bool>.broadcast();

  // Track ongoing operations to prevent conflicts
  bool _isEnrolling = false;
  bool _isCapturing = false;
  bool _isChecking = false;
  bool _isVerifying = false;
  Timer? _operationTimeout;
  bool _blockAllOperations = false; // Emergency block for stuck states

  Stream<String> get enrollStatusStream => _enrollStatusController.stream;
  Stream<Map<String, dynamic>> get enrollSuccessStream => _enrollSuccessController.stream;
  Stream<String> get sensorStatusStream => _sensorStatusController.stream;
  Stream<bool> get verifyResultStream => _verifyResultController.stream;

  // Getters for operation status
  bool get isEnrolling => _isEnrolling;
  bool get isCapturing => _isCapturing;
  bool get isVerifying => _isVerifying;
  bool get isBusy => _isEnrolling || _isCapturing || _isChecking || _isVerifying;

  FingerprintService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onStatusChanged':
          if (call.arguments is String) {
            _sensorStatusController.add(call.arguments as String);
          } else {
            _sensorStatusController.addError('Invalid sensor status data');
          }
          break;
        case 'onEnrollStatus':
          if (call.arguments is String) {
            final status = call.arguments as String;
            _enrollStatusController.add(status);

            // Check if enrollment operation completed
            if (status.toLowerCase().contains('success') ||
                status.toLowerCase().contains('complete') ||
                status.toLowerCase().contains('error') ||
                status.toLowerCase().contains('failed') ||
                status.toLowerCase().contains('cancelled')) {
              _isEnrolling = false;
              _blockAllOperations = false; // Clear block when enrollment completes
              _operationTimeout?.cancel();
              if (kDebugMode) {
                print('Enrollment completed, emergency block cleared');
              }
            }
          } else {
            _enrollStatusController.addError('Invalid enroll status data');
          }
          break;
        case 'onEnrollSuccess':
          if (call.arguments is Map) {
            _enrollSuccessController.add(Map<String, dynamic>.from(call.arguments));
            _isEnrolling = false;
            _isCapturing = false;
            _blockAllOperations = false; // Clear block on enrollment success
            _operationTimeout?.cancel();
            if (kDebugMode) {
              print('Enrollment success, emergency block cleared');
            }
          } else {
            _enrollSuccessController.addError('Invalid success data');
          }
          break;
        case 'onCaptureSuccess':
          if (call.arguments is String) {
            _enrollSuccessController.add({'template': call.arguments});
            _isEnrolling = false;
            _isCapturing = false;
            _blockAllOperations = false; // Clear block on enrollment success
            _operationTimeout?.cancel();
            if (kDebugMode) {
              print('Enrollment success (string), emergency block cleared');
            }
          } else if (call.arguments is Map) {
            _enrollSuccessController.add(Map<String, dynamic>.from(call.arguments));
            _isEnrolling = false;
            _isCapturing = false;
            _blockAllOperations = false; // Clear block on enrollment success
            _operationTimeout?.cancel();
            if (kDebugMode) {
              print('Enrollment success (map), emergency block cleared');
            }
          } else {
            _enrollSuccessController.addError('Invalid success data');
          }
          break;
        case 'onEnrollProgress':
          if (call.arguments is Map) {
            _enrollSuccessController.add(Map<String, dynamic>.from(call.arguments));
          } else {
            _enrollSuccessController.addError('Invalid enroll progress data');
          }
          break;
        case 'onVerifyResult':
          if (call.arguments is bool) {
            _verifyResultController.add(call.arguments as bool);
          } else {
            _verifyResultController.addError('Invalid verification result data');
          }
          _isVerifying = false; // Verification attempt is complete
          _operationTimeout?.cancel();
          break;
        default:
          if (kDebugMode) {
            print('FingerprintService: Unknown method call: ${call.method}');
          }
      }
    } catch (e) {
      if (kDebugMode) {
        print('FingerprintService: Error handling method call: $e');
      }
    }
  }

  Future<void> verifyFingerprint({required String storedTemplate1, String? storedTemplate2}) async {
    if (isBusy) {
      _sensorStatusController.add('Sensor is busy. Please wait.');
      return;
    }

    _isVerifying = true;
    _sensorStatusController.add('Place finger on scanner for verification...');

    // Set a timeout for the verification operation
    _operationTimeout = Timer(const Duration(seconds: 15), () {
      if (_isVerifying) {
        _isVerifying = false;
        _verifyResultController.addError('Verification timed out.');
        _sensorStatusController.add('Verification timed out. Please try again.');
      }
    });

    try {
      await _channel.invokeMethod('verifyFingerprint', {
        'storedTemplate1': storedTemplate1,
        'storedTemplate2': storedTemplate2,
      });
    } on PlatformException catch (e) {
      _isVerifying = false;
      _operationTimeout?.cancel();
      
      String friendlyError = FingerprintErrorHandler.getFriendlyErrorMessage(e.message ?? e.toString());
      _verifyResultController.addError(friendlyError);
      _sensorStatusController.add(friendlyError);
    }
  }

  Future<bool> isSensorConnected() async {
    if (_blockAllOperations) {
      if (kDebugMode) {
        print('isSensorConnected: Blocked due to emergency block');
      }
      return true; // Assume connected during block
    }
    
    if (_isChecking) {
      if (kDebugMode) {
        print('isSensorConnected: Already checking sensor status');
      }
      return false;
    }

    _isChecking = true;
    try {
      final bool? isConnected = await _channel.invokeMethod('isSensorConnected');
      if (kDebugMode) {
        print('isSensorConnected: $isConnected');
      }
      return isConnected ?? false;
    } on PlatformException catch (e) {
      String friendlyError = FingerprintErrorHandler.getFriendlyErrorMessage(e.message ?? e.toString());
      _sensorStatusController.add(friendlyError);
      if (kDebugMode) {
        print('isSensorConnected error: ${e.message}');
      }
      return false;
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _ensureSensorFree() async {
    if (isBusy) {
      if (kDebugMode) {
        print('Sensor is busy, attempting to cancel current operation');
      }

      try {
        await _forceCancel();
        // Wait for sensor to be free
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (e) {
        if (kDebugMode) {
          print('Error during force cancel: $e');
        }
      }
    }
  }

  Future<void> _forceCancel() async {
    try {
      await _channel.invokeMethod('cancelEnrollment');
      _isEnrolling = false;
      _isCapturing = false;
      _operationTimeout?.cancel();
      if (kDebugMode) {
        print('Force cancelled all operations');
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Force cancel error: ${e.message}');
      }
    }
  }

  /// Emergency block to prevent any operations during critical periods
  void setEmergencyBlock(bool blocked) {
    _blockAllOperations = blocked;
    if (kDebugMode) {
      print('Emergency block ${blocked ? 'ENABLED' : 'DISABLED'}');
    }
  }

  /// Force clear ALL busy states - use only when service is stuck
  Future<void> forceResetAllStates() async {
    if (kDebugMode) {
      print('Force resetting ALL FingerprintService states');
      print('Before reset: isEnrolling=$_isEnrolling, isCapturing=$_isCapturing, isChecking=$_isChecking, isVerifying=$_isVerifying, blocked=$_blockAllOperations');
    }
    
    // Enable emergency block to prevent interference during reset
    _blockAllOperations = true;
    
    try {
      // Try to cancel any ongoing operations first
      await _channel.invokeMethod('cancelEnrollment').catchError((e) {
        if (kDebugMode) print('Cancel during force reset: $e');
      });
    } catch (e) {
      if (kDebugMode) print('Error during cancel in force reset: $e');
    }
    
    // Force clear ALL internal flags
    _isEnrolling = false;
    _isCapturing = false;
    _isChecking = false;
    _isVerifying = false;
    _operationTimeout?.cancel();
    
    // Wait a moment for everything to settle
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Disable emergency block
    _blockAllOperations = false;
    
    if (kDebugMode) {
      print('After reset: isEnrolling=$_isEnrolling, isCapturing=$_isCapturing, isChecking=$_isChecking, isVerifying=$_isVerifying, blocked=$_blockAllOperations');
      print('Force reset complete, isBusy=$isBusy');
    }
  }

  /// Simple manual reset for stuck states
  void manualReset() {
    if (kDebugMode) {
      print('Manual reset: Clearing all busy states');
      print('Before manual reset: isEnrolling=$_isEnrolling, isCapturing=$_isCapturing, isChecking=$_isChecking, isVerifying=$_isVerifying');
    }
    
    _isEnrolling = false;
    _isCapturing = false;
    _isChecking = false;
    _isVerifying = false;
    _operationTimeout?.cancel();
    _blockAllOperations = false;
    
    if (kDebugMode) {
      print('After manual reset: isEnrolling=$_isEnrolling, isCapturing=$_isCapturing, isChecking=$_isChecking, isVerifying=$_isVerifying');
      print('Manual reset complete, isBusy=$isBusy');
    }
  }

  Future<void> startEnrollment(String finger) async {
    debugPrint('[ENROLL] FingerprintService.startEnrollment called for $finger');
    if (_isEnrolling) {
      throw PlatformException(
        code: 'OPERATION_IN_PROGRESS',
        message: 'Enrollment already in progress',
      );
    }

    // Enable emergency block to prevent interference during enrollment
    _blockAllOperations = true;
    debugPrint('[ENROLL] Emergency block enabled for enrollment');

    try {
      // Ensure sensor is free before starting
      await _ensureSensorFree();

      _isEnrolling = true;

      // Set a timeout for the enrollment operation
      _operationTimeout = Timer(const Duration(seconds: 60), () {
        if (_isEnrolling) {
          _isEnrolling = false;
          _blockAllOperations = false; // Clear block on timeout
          _enrollStatusController.add('Enrollment timeout - please try again');
          if (kDebugMode) {
            print('Enrollment timeout for $finger');
          }
        }
      });

      await _channel.invokeMethod('startEnrollment', {'finger': finger});
      debugPrint('[ENROLL] FingerprintService.startEnrollment completed for $finger');
      if (kDebugMode) {
        print('Started enrollment for $finger');
      }
    } on PlatformException catch (e) {
      _isEnrolling = false;
      _blockAllOperations = false; // Clear block on error
      _operationTimeout?.cancel();

      if (e.message?.toLowerCase().contains('busy') == true) {
        // Sensor is busy, try to reset it
        await _resetSensor();
        throw PlatformException(
          code: 'SENSOR_BUSY',
          message: 'Sensor is busy. Please try again after reset.',
        );
      }

      _enrollStatusController.add('Error starting enrollment: ${e.message}');
      if (kDebugMode) {
        print('startEnrollment error: ${e.message}');
      }
      rethrow;
    }
  }

  Future<void> startCapture() async {
    if (_isCapturing) {
      throw PlatformException(
        code: 'OPERATION_IN_PROGRESS',
        message: 'Capture already in progress',
      );
    }

    // Ensure sensor is free before starting
    await _ensureSensorFree();

    try {
      _isCapturing = true;

      // Set a timeout for the capture operation
      _operationTimeout = Timer(const Duration(seconds: 30), () {
        if (_isCapturing) {
          _isCapturing = false;
          _enrollStatusController.add('Capture timeout - please try again');
          if (kDebugMode) {
            print('Capture timeout');
          }
        }
      });

      await _channel.invokeMethod('startCapture');
      if (kDebugMode) {
        print('Started fingerprint capture');
      }
    } on PlatformException catch (e) {
      _isCapturing = false;
      _operationTimeout?.cancel();

      if (e.message?.toLowerCase().contains('busy') == true) {
        // Sensor is busy, try to reset it
        await _resetSensor();
        throw PlatformException(
          code: 'SENSOR_BUSY',
          message: 'Sensor is busy. Please try again after reset.',
        );
      }

      _enrollStatusController.add('Error starting capture: ${e.message}');
      if (kDebugMode) {
        print('startCapture error: ${e.message}');
      }
      rethrow;
    }
  }

  Future<bool> matchTemplates(String storedTemplate, String scannedTemplate) async {
    try {
      final bool? match = await _channel.invokeMethod('matchTemplates', {
        'storedTemplate': storedTemplate,
        'scannedTemplate': scannedTemplate,
      });
      if (kDebugMode) {
        print('matchTemplates: stored length=${storedTemplate.length}, scanned length=${scannedTemplate.length}, match=$match');
      }
      return match ?? false;
    } on PlatformException catch (e) {
      _enrollStatusController.add('Error matching templates: ${e.message}');
      if (kDebugMode) {
        print('matchTemplates error: ${e.message}');
      }
      return false;
    }
  }

  Future<bool> verify(String finger, String template) async {
    return await _channel.invokeMethod('verify', {'finger': finger, 'template': template});
  }

  Future<void> cancelEnrollment() async {
    try {
      // Only call cancelEnrollment if an enrollment is actually in progress
      if (!isEnrolling) return;
      await _channel.invokeMethod('cancelEnrollment');
      _isEnrolling = false;
      _isCapturing = false;
      _operationTimeout?.cancel();
      if (kDebugMode) {
        print('Enrollment cancelled');
      }
    } on PlatformException catch (e) {
      _enrollStatusController.add('Error cancelling enrollment: ${e.message}');
      if (kDebugMode) {
        print('cancelEnrollment error: ${e.message}');
      }
      rethrow;
    }
  }

  Future<void> _resetSensor() async {
    try {
      if (kDebugMode) {
        print('Attempting to reset sensor...');
      }

      // Cancel any ongoing operations
      await _forceCancel();

      // Wait for sensor to reset
      await Future.delayed(const Duration(seconds: 2));

      // Try to reinitialize sensor connection
      await isSensorConnected();

      if (kDebugMode) {
        print('Sensor reset completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during sensor reset: $e');
      }
    }
  }

  // Public method to reset sensor
  Future<void> resetSensor() async {
    await _resetSensor();
  }

  // Method to check if sensor is ready for operations
  Future<bool> isSensorReady() async {
    if (isBusy) {
      return false;
    }
    return await isSensorConnected();
  }

  void dispose() {
    _enrollStatusController.close();
    _enrollSuccessController.close();
    _sensorStatusController.close();
    _verifyResultController.close();
    _operationTimeout?.cancel();
    if (kDebugMode) {
      print('FingerprintService disposed');
    }
  }
}

class FutronicService {
  static const MethodChannel _channel = MethodChannel('futronic_channel');

  Future<String?> enroll(String finger) async {
    return await _channel.invokeMethod('enroll', {'finger': finger});
  }

  Future<bool> verify(String finger, String template) async {
    return await _channel.invokeMethod('verify', {'finger': finger, 'template': template});
  }

    // Capture once and compare against left and right templates to reduce repeated prompts
    Future<bool> verifyBoth({required String hintFinger, String? leftTemplate, String? rightTemplate}) async {
      return await _channel.invokeMethod('verifyBoth', {
        'hintFinger': hintFinger,
        'templateLeft': leftTemplate,
        'templateRight': rightTemplate,
      });
    }

  Future<bool> isFutronicConnected() async {
    return await _channel.invokeMethod('isFutronicConnected');
  }
}