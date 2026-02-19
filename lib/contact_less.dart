import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/intl.dart';
// import 'package:geolocator/geolocator.dart';  // Temporarily commented out
import 'package:image/image.dart' as img;
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

// Placeholder imports (replace with actual paths)
import 'CameraQualityScreen.dart';
import 'EnrollmentPage.dart';
import 'database_helper.dart';

// Extension must be top-level
extension StringCasingExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

class ContactlessClockInPage extends StatefulWidget {
  final String classID;
  final List<dynamic> learners;

  const ContactlessClockInPage({
    super.key,
    required this.classID,
    required this.learners,
  });

  @override
  State<ContactlessClockInPage> createState() => _ContactlessClockInPageState();
}

class _ContactlessClockInPageState extends State<ContactlessClockInPage> {
  Map<String, String> clockInTimes = {};
  Map<String, String> clockOutTimes = {};
  Map<String, String> contactTimes = {};
  final Map<String, bool> _isClockingIn = {};
  String? _currentLearnerIdForClocking;
  String? _currentClockingAction; // 'in' or 'out'
  bool _isCapturing = false;
  String _statusMessage = '';
  String? _workingServerUrl;

  @override
  void initState() {
    super.initState();
    databaseFactory = databaseFactoryFfi;
    _initializeData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Validate base64 strings
  bool isValidBase64(String str) {
    try {
      base64Decode(str);
      return true;
    } catch (e) {
      debugPrint('[CONTACTLESS] Invalid base64 string: $e');
      return false;
    }
  }

  Future<bool> _checkServerHealth() async {
    try {
      final urls = [
        'http://10.0.2.2:5001', // Emulator
        'http://192.168.0.53:5001', // Local network
        'http://localhost:5001', // Localhost
        'http://127.0.0.1:5001', // Localhost IP
      ];

      for (final testUrl in urls) {
        try {
          debugPrint('[CONTACTLESS] Testing server: $testUrl/health');
          final response = await http.get(
            Uri.parse('$testUrl/health'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 5));

          debugPrint(
              '[CONTACTLESS] Response: ${response.statusCode} ${response.body}');
          if (response.statusCode == 200) {
            final result = jsonDecode(response.body);
            if (result['status'] == 'healthy') {
              _workingServerUrl = testUrl;
              debugPrint('[CONTACTLESS] Server found at: $testUrl');
              return true;
            }
          }
        } catch (e) {
          debugPrint('[CONTACTLESS] Failed to reach $testUrl: $e');
        }
      }
      debugPrint('[CONTACTLESS] All server URLs failed');
      return false;
    } catch (e) {
      debugPrint('[CONTACTLESS] Health check error: $e');
      return false;
    }
  }

  Future<bool> _verifyWithSiameseModel(String capturedImageBase64,
      String storedTemplateBase64, String learnerId) async {
    try {
      if (learnerId.isEmpty || learnerId == 'REPLACE_WITH_LEARNER_ID') {
        debugPrint('[CONTACTLESS] Invalid LearnerID: $learnerId');
        setState(() {
          _statusMessage = 'Invalid learner ID';
        });
        return false;
      }

      if (!isValidBase64(capturedImageBase64) ||
          !isValidBase64(storedTemplateBase64)) {
        debugPrint('[CONTACTLESS] Invalid base64 data');
        setState(() {
          _statusMessage = 'Invalid image data';
        });
        return false;
      }

      if (storedTemplateBase64.isEmpty) {
        debugPrint('[CONTACTLESS] storedTemplateBase64 is empty');
        setState(() {
          _statusMessage = 'No fingerprint template available';
        });
        return false;
      }

      final serverHealthy = await _checkServerHealth();
      if (!serverHealthy) {
        debugPrint('[CONTACTLESS] Server health check failed');
        setState(() {
          _statusMessage = 'Server is not reachable';
        });
        return false;
      }

      debugPrint(
          '[CONTACTLESS] Sending verification request: learnerId=$learnerId');
      final url = '$_workingServerUrl/verify';
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'image_base64': capturedImageBase64,
        'stored_features_base64': storedTemplateBase64,
        'LearnerID': learnerId,
        'action': _currentClockingAction ?? 'in',
      });

      debugPrint('[CONTACTLESS] Request URL: $url');
      debugPrint(
          '[CONTACTLESS] Request body preview: image_base64.length=${capturedImageBase64.length}, stored_features_base64.length=${storedTemplateBase64.length}');

      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
          '[CONTACTLESS] Response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final isMatch = result['is_match'] == true;
          final distance = result['distance'];
          final threshold = result['threshold'];
          debugPrint(
              '[CONTACTLESS] Result - Distance: $distance, IsMatch: $isMatch, Threshold: $threshold');
          return isMatch;
        } else {
          setState(() {
            _statusMessage = result['message'] ?? 'Verification failed';
          });
          debugPrint(
              '[CONTACTLESS] Server error: ${result['message'] ?? result['error']}');
          return false;
        }
      } else {
        setState(() {
          _statusMessage = 'Server error: ${response.statusCode}';
        });
        debugPrint('[CONTACTLESS] HTTP error: ${response.statusCode}');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('[CONTACTLESS] Verification error: $e');
      debugPrint('[CONTACTLESS] Stack trace: $stackTrace');
      setState(() {
        _statusMessage = 'Connection error: $e';
      });
      return false;
    }
  }

  Future<void> _captureAndVerify(img.Image captured) async {
    if (_currentLearnerIdForClocking == null ||
        _currentLearnerIdForClocking == 'REPLACE_WITH_LEARNER_ID' ||
        _currentLearnerIdForClocking!.isEmpty) {
      setState(() {
        _statusMessage = 'Invalid learner selection';
        _isCapturing = false;
        _isClockingIn[_currentLearnerIdForClocking ?? ''] = false;
        _currentLearnerIdForClocking = null;
        _currentClockingAction = null;
      });
      debugPrint(
          '[CONTACTLESS] Invalid learner ID: $_currentLearnerIdForClocking');
      return;
    }

    final learnerId = _currentLearnerIdForClocking!;
    setState(() {
      _statusMessage = 'Processing fingerprint...';
      _isCapturing = true;
    });

    try {
      // Image is already preprocessed by CameraQualityScreen (224x224, normalized)
      final capturedPngBytes = img.encodePng(captured);
      final capturedBase64 = base64Encode(capturedPngBytes);

      // Get stored templates (use the working method that returns the right data type)
      final storedTemplates =
          await DatabaseHelper().getFingerprints(int.parse(learnerId));
      final sourceafisTemplate = storedTemplates['left'];
      final isLeftHandTemplate = storedTemplates['right'];

      debugPrint('[CONTACTLESS] Learner ID: $learnerId');
      debugPrint(
          '[CONTACTLESS] sourceafisTemplate: ${sourceafisTemplate != null ? "${sourceafisTemplate.length} bytes" : "NULL"}');
      debugPrint(
          '[CONTACTLESS] isLeftHandTemplate: ${isLeftHandTemplate != null ? "${isLeftHandTemplate.length} bytes" : "NULL"}');

      if ((sourceafisTemplate == null || sourceafisTemplate.isEmpty) &&
          (isLeftHandTemplate == null || isLeftHandTemplate.isEmpty)) {
        setState(() {
          _statusMessage = 'No fingerprint template found for this learner';
          _isCapturing = false;
          _isClockingIn[learnerId] = false;
          _currentLearnerIdForClocking = null;
          _currentClockingAction = null;
        });
        debugPrint('[CONTACTLESS] No templates for learner $learnerId');
        return;
      }

      bool matchFound = false;

      if (sourceafisTemplate != null && sourceafisTemplate.isNotEmpty) {
        try {
          // sourceafisTemplate is already base64 encoded from getFingerprints
          final templateBytes = base64Decode(sourceafisTemplate);
          final features = Float32List.view(templateBytes.buffer);
          bool hasNaN = false;
          for (int i = 0; i < features.length; i++) {
            if (features[i].isNaN || features[i].isInfinite) {
              hasNaN = true;
              break;
            }
          }
          if (hasNaN) {
            debugPrint(
                '[CONTACTLESS] WARNING: sourceafis_template contains NaN/Inf');
            _showCorruptionDialog(learnerId);
            return;
          }
        } catch (e) {
          debugPrint('[CONTACTLESS] Error checking sourceafis_template: $e');
        }

        // sourceafisTemplate is already base64 encoded
        matchFound = await _verifyWithSiameseModel(
            capturedBase64, sourceafisTemplate, learnerId);
        debugPrint('[CONTACTLESS] Match with sourceafis_template: $matchFound');
      }

      if (!matchFound &&
          isLeftHandTemplate != null &&
          isLeftHandTemplate.isNotEmpty) {
        try {
          // isLeftHandTemplate is already base64 encoded from getFingerprints
          final templateBytes = base64Decode(isLeftHandTemplate);
          final features = Float32List.view(templateBytes.buffer);
          bool hasNaN = false;
          for (int i = 0; i < features.length; i++) {
            if (features[i].isNaN || features[i].isInfinite) {
              hasNaN = true;
              break;
            }
          }
          if (hasNaN) {
            debugPrint(
                '[CONTACTLESS] WARNING: isLeftHand_template contains NaN/Inf');
            _showCorruptionDialog(learnerId);
            return;
          }
        } catch (e) {
          debugPrint('[CONTACTLESS] Error checking isLeftHand_template: $e');
        }

        // isLeftHandTemplate is already base64 encoded
        matchFound = await _verifyWithSiameseModel(
            capturedBase64, isLeftHandTemplate, learnerId);
        debugPrint('[CONTACTLESS] Match with isLeftHand_template: $matchFound');
      }

      if (matchFound) {
        debugPrint('[CONTACTLESS] Fingerprint match for learner $learnerId');
        await _onFingerprintMatch(learnerId);
      } else {
        setState(() {
          _statusMessage = 'Fingerprint verification failed';
          _isCapturing = false;
          _isClockingIn[learnerId] = false;
          _currentLearnerIdForClocking = null;
          _currentClockingAction = null;
        });
        debugPrint('[CONTACTLESS] No match for learner $learnerId');
      }
    } catch (e, stackTrace) {
      debugPrint('[CONTACTLESS] Verification error: $e');
      debugPrint('[CONTACTLESS] Stack trace: $stackTrace');
      setState(() {
        _statusMessage = 'Error: $e';
        _isCapturing = false;
        _isClockingIn[learnerId] = false;
        _currentLearnerIdForClocking = null;
        _currentClockingAction = null;
      });
    }
  }

  void _showCorruptionDialog(String learnerId) {
    setState(() {
      _statusMessage = 'Fingerprint template corrupted. Please re-enroll.';
      _isCapturing = false;
      _isClockingIn[learnerId] = false;
      _currentLearnerIdForClocking = null;
      _currentClockingAction = null;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Corrupted Fingerprint Template'),
        content: Text(
            'The fingerprint template for learner $learnerId is invalid and cannot be used for verification.\n\nPlease choose an option to resolve this issue:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _generateFeaturesFromWSQ(int.parse(learnerId));
            },
            child: const Text('🔄 Regenerate from Scanner'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseHelper()
                  .clearFingerprintTemplates(int.parse(learnerId));
              setState(() {
                _statusMessage =
                    'Templates cleared. Please re-enroll using the Enroll button.';
              });
              _showMessage('Templates cleared. Please re-enroll.');
            },
            child: const Text('🗑️ Clear & Re-enroll'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        backgroundColor: message.startsWith('✅')
            ? Colors.green
            : message.startsWith('❌')
                ? Colors.red
                : Colors.blue,
      ),
    );
  }

  Future<void> _onFingerprintMatch(String learnerId) async {
    debugPrint('[CONTACTLESS] Fingerprint match for learner $learnerId');
    setState(() {
      _statusMessage = 'Fingerprint match! Clocking in/out...';
    });
    final now = DateFormat('HH:mm:ss').format(DateTime.now());
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final action = _currentClockingAction;

    if (action == 'in') {
      final attendance = {
        'LearnerID': learnerId,
        'clock_in_time': now,
        'clock_date': date,
        'synced': 0,
      };
      await DatabaseHelper().insertClocking(attendance);
      debugPrint('[CONTACTLESS] Clock-in successful for learner $learnerId');
    } else if (action == 'out') {
      final existingAttendance =
          await DatabaseHelper().getAttendanceForDay(learnerId, date);
      if (existingAttendance == null ||
          existingAttendance['clock_in_time'] == null) {
        debugPrint(
            '[CONTACTLESS] Cannot clock out. No prior clock-in for learner $learnerId');
        setState(() {
          _statusMessage = 'Cannot clock out: No prior clock-in found';
        });
      } else {
        final clockInTime = existingAttendance['clock_in_time'].toString();
        final updatedAttendance = {
          'clock_out_time': now,
          'contact_time': _calculateContactTime(clockInTime, now),
          'synced': 0,
        };
        try {
          final clockingId =
              int.parse(existingAttendance['clocking_id'].toString());
          await DatabaseHelper().updateClocking(clockingId, updatedAttendance);
          debugPrint(
              '[CONTACTLESS] Clock-out successful for learner $learnerId');
        } catch (e) {
          debugPrint('[CONTACTLESS] Error updating clocking: $e');
        }
      }
    }

    setState(() {
      _isCapturing = false;
      _statusMessage = '';
      _isClockingIn[learnerId] = false;
      _currentLearnerIdForClocking = null;
      _currentClockingAction = null;
    });
    _refreshDataWithoutClearingState();
    Navigator.of(context).pop();
  }

  String _calculateContactTime(String clockIn, String clockOut) {
    final format = DateFormat("HH:mm:ss");
    try {
      final inTime = format.parse(clockIn);
      final outTime = format.parse(clockOut);
      final duration = outTime.difference(inTime);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final seconds = duration.inSeconds % 60;
      return "${hours}h ${minutes}m ${seconds}s";
    } catch (e) {
      return "0h 0m 0s";
    }
  }

  Future<void> _verifyAndClockIn(String learnerId) async {
    if (learnerId.isEmpty ||
        learnerId == 'N/A' ||
        learnerId == 'REPLACE_WITH_LEARNER_ID') {
      setState(() {
        _statusMessage = 'Invalid learner ID';
      });
      return;
    }
    setState(() {
      _isClockingIn[learnerId] = true;
      _currentLearnerIdForClocking = learnerId;
      _currentClockingAction = 'in';
    });
    await _showCameraModal(context);
  }

  Future<void> _verifyAndClockOut(String learnerId) async {
    if (learnerId.isEmpty ||
        learnerId == 'N/A' ||
        learnerId == 'REPLACE_WITH_LEARNER_ID') {
      setState(() {
        _statusMessage = 'Invalid learner ID';
      });
      return;
    }
    setState(() {
      _isClockingIn[learnerId] = true;
      _currentLearnerIdForClocking = learnerId;
      _currentClockingAction = 'out';
    });
    await _showCameraModal(context);
  }

  Future<void> _showCameraModal(BuildContext context) async {
    if (_isCapturing) {
      return;
    }
    setState(() {
      _isCapturing = true;
    });
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CameraQualityScreen(),
        ),
      );
      if (result != null && result is String) {
        debugPrint('[CONTACTLESS] Image captured at path: $result');
        try {
          final file = File(result);
          final bytes = await file.readAsBytes();
          final decodedImage = img.decodeImage(bytes)!;
          await _captureAndVerify(decodedImage);
        } catch (e) {
          debugPrint('[CONTACTLESS] Error processing image: $e');
          setState(() {
            _isCapturing = false;
            _statusMessage = 'Error processing image: $e';
            _isClockingIn[_currentLearnerIdForClocking!] = false;
            _currentLearnerIdForClocking = null;
            _currentClockingAction = null;
          });
        }
      } else {
        setState(() {
          _isCapturing = false;
          _statusMessage = '';
          _isClockingIn[_currentLearnerIdForClocking!] = false;
          _currentLearnerIdForClocking = null;
          _currentClockingAction = null;
        });
      }
    } catch (e) {
      debugPrint('[CONTACTLESS] Error opening CameraQualityScreen: $e');
      setState(() {
        _isCapturing = false;
        _statusMessage = 'Error opening camera: $e';
        _isClockingIn[_currentLearnerIdForClocking!] = false;
        _currentLearnerIdForClocking = null;
        _currentClockingAction = null;
      });
    }
  }

  Future<void> _generateFeaturesFromWSQ(int learnerId) async {
    try {
      debugPrint(
          '[CONTACTLESS] Generating neural features for learner $learnerId');
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final result = await db.query(
        'learnerdetails',
        columns: [
          'zkteco_left_template',
          'zkteco_right_template',
          'futronic_left_template',
          'futronic_right_template'
        ],
        where: 'LearnerID = ?',
        whereArgs: [learnerId],
      );

      if (result.isEmpty) {
        debugPrint('[CONTACTLESS] No learner found with ID $learnerId');
        _showMessage('❌ Learner not found in database');
        return;
      }

      final row = result.first;
      String? wsqTemplate;
      String templateSource = '';

      // Try to get templates from any available scanner
      final zkLeft = row['zkteco_left_template'] as String?;
      final zkRight = row['zkteco_right_template'] as String?;
      final futronicLeft = row['futronic_left_template'] as String?;
      final futronicRight = row['futronic_right_template'] as String?;

      // Prefer ZKTeco templates if available, otherwise use Futronic
      if (zkLeft != null && zkLeft.isNotEmpty && !zkLeft.startsWith('{')) {
        wsqTemplate = zkLeft;
        templateSource = 'zkteco_left_template';
        debugPrint('[CONTACTLESS] Using zkteco_left_template');
      } else if (zkRight != null &&
          zkRight.isNotEmpty &&
          !zkRight.startsWith('{')) {
        wsqTemplate = zkRight;
        templateSource = 'zkteco_right_template';
        debugPrint('[CONTACTLESS] Using zkteco_right_template');
      } else if (futronicLeft != null &&
          futronicLeft.isNotEmpty &&
          !futronicLeft.startsWith('{')) {
        wsqTemplate = futronicLeft;
        templateSource = 'futronic_left_template';
        debugPrint('[CONTACTLESS] Using futronic_left_template');
      } else if (futronicRight != null &&
          futronicRight.isNotEmpty &&
          !futronicRight.startsWith('{')) {
        wsqTemplate = futronicRight;
        templateSource = 'futronic_right_template';
        debugPrint('[CONTACTLESS] Using futronic_right_template');
      }

      if (wsqTemplate == null) {
        debugPrint(
            '[CONTACTLESS] No WSQ templates found for learner $learnerId');
        _showMessage(
            '❌ No scanner templates found. Please re-enroll using the fingerprint scanner.');
        return;
      }

      debugPrint(
          '[CONTACTLESS] WSQ template from $templateSource, length: ${wsqTemplate.length}');

      await _checkServerHealth();
      if (_workingServerUrl == null) {
        _showMessage('❌ Neural network server not available');
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Converting WSQ Template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Converting scanner template to neural network features...'),
            ],
          ),
        ),
      );

      final response = await http
          .post(
            Uri.parse('$_workingServerUrl/extract'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'LearnerID': learnerId,
              'image_base64': wsqTemplate,
            }),
          )
          .timeout(const Duration(seconds: 30));

      Navigator.pop(context);

      debugPrint('[CONTACTLESS] Server response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          debugPrint('[CONTACTLESS] Neural features generated');
          final featuresBase64 = responseData['features_base64'] as String;
          final featuresBytes = base64Decode(featuresBase64);
          await DatabaseHelper()
              .saveFingerprintFeatures(learnerId, featuresBytes);
          _showMessage('✅ Neural network features generated and saved');
        } else {
          debugPrint('[CONTACTLESS] Server error: ${responseData['error']}');
          _showMessage(
              '❌ Failed to generate features: ${responseData['error']}');
        }
      } else {
        debugPrint(
            '[CONTACTLESS] Server error ${response.statusCode}: ${response.body}');
        _showMessage('❌ Server error (${response.statusCode})');
      }
    } catch (e) {
      Navigator.pop(context);
      debugPrint('[CONTACTLESS] Error generating features: $e');
      _showMessage('❌ Error: $e');
    }
  }

  Future<void> _initializeData() async {
    debugPrint(
        '[CONTACTLESS] Initializing data for classID: ${widget.classID}');
    await _loadLearnersFromLocalDatabase();
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _refreshDataWithoutClearingState();
        _startPeriodicRefresh();
      }
    });
  }

  Future<void> _refreshDataWithoutClearingState() async {
    try {
      final dbHelper = DatabaseHelper();
      final learnersWithClockingData =
          await dbHelper.getLearnersWithClockingData(widget.classID);
      setState(() {
        for (var learner in learnersWithClockingData) {
          String learnerId = learner['LearnerID']?.toString() ?? 'N/A';
          String clockInTime = learner['clock_in_time']?.toString() ?? '';
          String clockOutTime = learner['clock_out_time']?.toString() ?? '';
          String contactTime = learner['contact_time']?.toString() ?? '';
          if (clockInTime.isNotEmpty &&
              clockInTime != 'N/A' &&
              clockInTime != 'null') {
            clockInTimes[learnerId] = clockInTime;
          }
          if (clockOutTime.isNotEmpty &&
              clockOutTime != 'N/A' &&
              clockOutTime != 'null') {
            clockOutTimes[learnerId] = clockOutTime;
          }
          if (contactTime.isNotEmpty &&
              contactTime != 'N/A' &&
              contactTime != 'null') {
            contactTimes[learnerId] = contactTime;
          }
        }
        widget.learners.clear();
        widget.learners.addAll(learnersWithClockingData.map((learner) {
          return Map<String, String>.from(learner
              .map((key, value) => MapEntry(key, value?.toString() ?? '')));
        }).toList());
      });
    } catch (e) {
      debugPrint('[CONTACTLESS] Error refreshing data: $e');
      setState(() {
        _statusMessage = 'Error refreshing data: $e';
      });
    }
  }

  Future<void> _loadLearnersFromLocalDatabase() async {
    try {
      final dbHelper = DatabaseHelper();
      final learnersWithClockingData =
          await dbHelper.getLearnersWithClockingData(widget.classID);
      setState(() {
        widget.learners.clear();
        for (var learner in learnersWithClockingData) {
          String learnerId = learner['LearnerID']?.toString() ?? 'N/A';
          String clockInTime = learner['clock_in_time']?.toString() ?? '';
          String clockOutTime = learner['clock_out_time']?.toString() ?? '';
          String contactTime = learner['contact_time']?.toString() ?? '';
          if (clockInTime.isNotEmpty &&
              clockInTime != 'N/A' &&
              clockInTime != 'null') {
            clockInTimes[learnerId] = clockInTime;
          }
          if (clockOutTime.isNotEmpty &&
              clockOutTime != 'N/A' &&
              clockOutTime != 'null') {
            clockOutTimes[learnerId] = clockOutTime;
          }
          if (contactTime.isNotEmpty &&
              contactTime != 'N/A' &&
              contactTime != 'null') {
            contactTimes[learnerId] = contactTime;
          }
          widget.learners.add({
            'LearnerID': learnerId,
            'Name': learner['Name']?.toString() ?? 'N/A',
            'Surname': learner['Surname']?.toString() ?? 'N/A',
            'clock_in_time': clockInTime,
            'clock_out_time': clockOutTime,
            'contact_time': contactTime,
          });
        }
      });
      debugPrint(
          '[CONTACTLESS] Loaded learners: ${widget.learners.map((l) => l['LearnerID']).toList()}');
    } catch (e) {
      debugPrint('[CONTACTLESS] Error loading learners: $e');
      setState(() {
        _statusMessage = 'Error loading learners: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contactless Clocking')),
      body: Column(
        children: [
          if (_statusMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  color: _statusMessage.contains('Error') ||
                          _statusMessage.contains('failed')
                      ? Colors.red
                      : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: widget.learners.isEmpty
                ? const Center(child: Text('No data available for this class'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Surname')),
                          DataColumn(label: Text('ID Number')),
                          DataColumn(label: Text('Clock In')),
                          DataColumn(label: Text('Clock Out')),
                          DataColumn(label: Text('Contact Time')),
                          DataColumn(label: Text('Enroll (Debug)')),
                        ],
                        rows: widget.learners
                            .where((learner) =>
                                learner['LearnerID'] != null &&
                                learner['LearnerID'].toString() != 'N/A' &&
                                learner['LearnerID'].toString() !=
                                    'REPLACE_WITH_LEARNER_ID' &&
                                learner['LearnerID'].toString().isNotEmpty)
                            .map((learner) {
                          String learnerId =
                              learner['LearnerID']?.toString() ?? 'N/A';
                          String name = learner['Name']?.toString() ?? 'N/A';
                          String surname =
                              learner['Surname']?.toString() ?? 'N/A';
                          String clockInTime = clockInTimes[learnerId] ?? '';
                          String clockOutTime = clockOutTimes[learnerId] ?? '';
                          String contactTime = contactTimes[learnerId] ?? '';
                          return DataRow(
                            cells: [
                              DataCell(Text(name)),
                              DataCell(Text(surname)),
                              DataCell(Text(
                                  learner['IDNumber']?.toString() ?? 'N/A')),
                              DataCell(
                                clockInTime.isEmpty
                                    ? ElevatedButton(
                                        onPressed:
                                            _isClockingIn[learnerId] == true
                                                ? null
                                                : () async {
                                                    await _verifyAndClockIn(
                                                        learnerId);
                                                  },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                        child: const Text('Clock In'),
                                      )
                                    : Text(
                                        clockInTime,
                                        style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),
                              DataCell(
                                clockInTime.isNotEmpty && clockOutTime.isEmpty
                                    ? ElevatedButton(
                                        onPressed:
                                            _isClockingIn[learnerId] == true
                                                ? null
                                                : () async {
                                                    await _verifyAndClockOut(
                                                        learnerId);
                                                  },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Text('Clock Out'),
                                      )
                                    : Text(
                                        clockOutTime.isNotEmpty
                                            ? clockOutTime
                                            : '-',
                                        style: TextStyle(
                                          color: clockOutTime.isNotEmpty
                                              ? Colors.red
                                              : Colors.grey,
                                          fontWeight: clockOutTime.isNotEmpty
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                              ),
                              DataCell(
                                Text(
                                  contactTime.isNotEmpty ? contactTime : '-',
                                  style: TextStyle(
                                    color: contactTime.isNotEmpty
                                        ? Colors.blue
                                        : Colors.grey,
                                    fontWeight: contactTime.isNotEmpty
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              DataCell(
                                ElevatedButton(
                                  onPressed: (_isCapturing)
                                      ? null
                                      : () async {
                                          debugPrint(
                                              '[CONTACTLESS] Enroll button for learner $learnerId');
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  EnrollmentPage(
                                                      learnerId:
                                                          int.parse(learnerId)),
                                            ),
                                          );
                                        },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue),
                                  child: const Text('Enroll'),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
