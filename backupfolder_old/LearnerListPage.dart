import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
// import 'package:geolocator/geolocator.dart';  // Temporarily commented out
import 'dart:async';
import 'dart:io';
import 'dart:math';

// Placeholder imports (replace with actual paths)
import 'DetailsPage.dart';
import 'sick_note_page.dart';
import 'ppe_sizes_page.dart';
import 'database_helper.dart';

import 'config.dart';
class Learnerlistpage extends StatefulWidget {
  final String classID;
  final List<dynamic> learners;

  const Learnerlistpage({
    super.key,
    required this.classID,
    required this.learners,
  });

  @override
  State<Learnerlistpage> createState() => _LearnerlistpageState();
}

class _LearnerlistpageState extends State<Learnerlistpage> {
  Map<String, String> clockInTimes = {};
  Map<String, String> clockOutTimes = {};
  Map<String, String> contactTimes = {};

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  // CameraController? _cameraController;  // Temporarily disabled due to Java 21 compatibility issues
  // List<CameraDescription>? _cameras;  // Temporarily disabled due to Java 21 compatibility issues
  // int _selectedCameraIndex = 0; // 0 for front, 1 for back  // Temporarily disabled due to Java 21 compatibility issues
  // bool _isCameraReady = false;  // Temporarily disabled due to Java 21 compatibility issues
  // bool _isCapturing = false;  // Temporarily disabled due to Java 21 compatibility issues
  // XFile? _capturedImage;  // Temporarily disabled due to Java 21 compatibility issues

  @override
  void initState() {
    super.initState();
    databaseFactory = databaseFactoryFfi;
    _initializeData();
    // _initializeCamera();  // Temporarily disabled due to Java 21 compatibility issues
  }

  // Future<void> _initializeCamera() async {  // Temporarily disabled due to Java 21 compatibility issues
  //   try {
  //     _cameras = await availableCameras();
  //     if (_cameras != null && _cameras!.isNotEmpty) {
  //       _selectedCameraIndex = _cameras!.length > 1 ? 0 : 0;
  //       _cameraController = CameraController(
  //         _cameras![_selectedCameraIndex],
  //         ResolutionPreset.low,
  //         enableAudio: false,
  //         imageFormatGroup: ImageFormatGroup.jpeg, // Reduce memory usage
  //       );
  //       await _cameraController!.initialize();
  //       print('Camera initialized: ${_cameras![_selectedCameraIndex].name}');
  //       setState(() {
  //         _isCameraReady = true;
  //       });
  //     } else {
  //       print('No cameras available');
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('No cameras available')),
  //       );
  //     }
  //   } catch (e) {
  //     print('Camera initialization error: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to initialize camera: $e')),
  //     );
  //   }
  // }

  // void _switchCamera() {  // Temporarily disabled due to Java 21 compatibility issues
  //   if (_cameras == null || _cameras!.length < 2) return;
  //   setState(() {
  //     _isCameraReady = false;
  //     _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
  //   });
  //   _cameraController?.dispose().then((_) async {
  //     _cameraController = CameraController(
  //       _cameras![_selectedCameraIndex],
  //       ResolutionPreset.low,
  //       enableAudio: false,
  //     );
  //     await _cameraController!.initialize();
  //     print('Switched to camera: ${_cameras![_selectedCameraIndex].name}');
  //     setState(() {
  //       _isCameraReady = true;
  //     });
  //   });
  // }

  // Future<void> _captureImageAndOpenSignature() async {  // Temporarily disabled due to Java 21 compatibility issues
  //   // Prevent multiple concurrent captures
  //   if (_isCapturing) {
  //     print('Capture already in progress, ignoring request');
  //     return;
  //   }

  //   try {
  //     if (_cameraController != null && _cameraController!.value.isInitialized) {
  //       setState(() {
  //         _isCapturing = true;
  //       });
  //       _capturedImage = await _cameraController!.takePicture();
  //       print('Image captured: ${_capturedImage!.path}');
  //       if (mounted) {
  //         Navigator.of(context).pop(true);
  //       }
  //     }
  //   } catch (e) {
  //     print('Error capturing image: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to capture image: $e')),
  //     );
  //     if (mounted) {
  //       Navigator.of(context).pop(false);
  //     }
  //   } finally {
  //     setState(() {
  //       _isCapturing = false;
  //     });
  //   }
  // }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _initializeData() async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    final classes = await db.query('class');
    final sites = await db.query('sites');
    print('Class table contents on init: $classes');
    print('Sites table contents on init: $sites');

    await _loadLearnersFromLocalDatabase();
    await _fetchClockingDataFromServer();
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

  Future<void> _fetchClockingDataFromServer() async {
    if (!(await _checkConnectivity())) return;

    await _syncOfflineClockIns();

    // Individual server fetches disabled - data is already synced via main sync endpoint
    // This prevents FormatException errors from broken get_clocking_data.php endpoint
    print('[LEARNER_LIST] Individual server fetches disabled - using main sync endpoint only');
  }

  Future<void> _syncOfflineClockIns() async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    final offlineRecords = await db.query(
      'learner_clocking',
      where: 'synced = ?',
      whereArgs: [0],
    );

    for (var record in offlineRecords) {
      try {
        final learnerID = record['LearnerID'].toString();
        final signaturePath = record['signature']?.toString() ?? '';
        await _clockInOnline(learnerID, signaturePath);
        await db.update(
          'learner_clocking',
          {'synced': 1},
          where: 'LearnerID = ? AND clock_date = ?',
          whereArgs: [learnerID, record['clock_date'].toString()],
        );
        print('Synced offline clock-in for $learnerID');
      } catch (e) {
        print('Failed to sync offline clock-in: $e');
      }
    }
  }

  Future<void> _refreshDataWithoutClearingState() async {
    try {
      final dbHelper = DatabaseHelper();
      final learnersWithClockingData = await dbHelper.getLearnersWithClockingData(widget.classID);

      setState(() {
        for (var learner in learnersWithClockingData) {
          String learnerId = learner['LearnerID']?.toString() ?? '';
          String clockInTime = learner['clock_in_time']?.toString() ?? '';
          String clockOutTime = learner['clock_out_time']?.toString() ?? '';
          String contactTime = learner['contact_time']?.toString() ?? '';

          if (clockInTime.isNotEmpty && clockInTime != 'N/A' && clockInTime != 'null') {
            clockInTimes[learnerId] = clockInTime;
          }
          if (clockOutTime.isNotEmpty && clockOutTime != 'N/A' && clockOutTime != 'null') {
            clockOutTimes[learnerId] = clockOutTime;
          }
          if (contactTime.isNotEmpty && contactTime != 'N/A' && contactTime != 'null') {
            contactTimes[learnerId] = contactTime;
          }
        }

        widget.learners.clear();
        widget.learners.addAll(learnersWithClockingData.map((learner) {
          // Convert Map<String, Object?> to Map<String, String>
          Map<String, String> convertedLearner = {};
          learner.forEach((key, value) {
            convertedLearner[key] = value?.toString() ?? '';
          });
          return convertedLearner;
        }));
      });

      await _fetchClockingDataFromServer();
    } catch (e) {
      print('Error refreshing data: $e');
    }
  }

  Future<void> _loadLearnersFromLocalDatabase() async {
    try {
      final dbHelper = DatabaseHelper();
      final learnersWithClockingData = await dbHelper.getLearnersWithClockingData(widget.classID);

      setState(() {
        widget.learners.clear();
        for (var learner in learnersWithClockingData) {
          String learnerId = learner['LearnerID']?.toString() ?? 'N/A';
          String clockInTime = learner['clock_in_time']?.toString() ?? '';
          String clockOutTime = learner['clock_out_time']?.toString() ?? '';
          String contactTime = learner['contact_time']?.toString() ?? '';

          if (clockInTime.isNotEmpty && clockInTime != 'N/A' && clockInTime != 'null') {
            clockInTimes[learnerId] = clockInTime;
          }
          if (clockOutTime.isNotEmpty && clockOutTime != 'N/A' && clockOutTime != 'null') {
            clockOutTimes[learnerId] = clockOutTime;
          }
          if (contactTime.isNotEmpty && contactTime != 'N/A' && contactTime != 'null') {
            contactTimes[learnerId] = contactTime;
          }

          // Convert Map<String, dynamic> to Map<String, String> explicitly
          final stringLearner = <String, String>{
            'LearnerID': learnerId,
            'Name': learner['Name']?.toString() ?? 'N/A',
            'Surname': learner['Surname']?.toString() ?? 'N/A',
            'IDNumber': learner['IDNumber']?.toString() ?? 'N/A',
            'clock_in_time': clockInTime,
            'clock_out_time': clockOutTime,
            'contact_time': contactTime,
          };
          widget.learners.add(stringLearner);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading offline learners: $e')),
      );
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371e3; // Earth radius in meters
    final double phi1 = lat1 * pi / 180;
    final double phi2 = lat2 * pi / 180;
    final double deltaPhi = (lat2 - lat1) * pi / 180;
    final double deltaLambda = (lon2 - lon1) * pi / 180;

    final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c; // Distance in meters
  }

  Future<bool> _isWithinSiteRadius(String classID, double userLat, double userLon, double userAccuracy) async {
    // Note: Accuracy validation removed to match PHP endpoint that accepts any accuracy
    print('Location accuracy: $userAccuracy meters');

    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final classes = await db.query('class');
      final sites = await db.query('sites');
      print('Class table contents: $classes');
      print('Sites table contents: $sites');
      print('Querying coordinates for classID: $classID (type: ${classID.runtimeType})');

      final result = await db.rawQuery(
        'SELECT s.latitude, s.longitude FROM class c JOIN sites s ON c.siteID = s.siteID WHERE c.classID = ?',
        [classID.toString()],
      );

      if (result.isEmpty) {
        if (classes.isEmpty) {
          print('Class table is empty');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No class data available in local database.')),
          );
        } else if (sites.isEmpty) {
          print('Sites table is empty');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No site data available in local database.')),
          );
        } else {
          print('No matching class or site found for classID: $classID');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No site coordinates found for class $classID.')),
          );
        }
        return false;
      }

      final siteLat = double.tryParse(result.first['latitude'].toString());
      final siteLon = double.tryParse(result.first['longitude'].toString());

      if (siteLat == null || siteLon == null) {
        print('Invalid site coordinates for classID: $classID, lat: ${result.first['latitude']}, lon: ${result.first['longitude']}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid site coordinates in database.')),
        );
        return false;
      }

      final distance = _calculateDistance(userLat, userLon, siteLat, siteLon);

      print('Distance to site for classID $classID: $distance meters');
      // Note: Geofencing disabled to match PHP endpoint - distance calculated for logging only
      return true;
    } catch (e, stackTrace) {
      print('Error checking site radius for classID $classID: $e\nStack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking location: $e')),
      );
      return false;
    }
  }

  // Future<bool> _performLivenessCheck() async {  // Temporarily disabled due to Java 21 compatibility issues
  //   if (!_isCameraReady || _cameraController == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Camera not available')),
  //     );
  //     return false;
  //   }

  //   setState(() {
  //     _isCapturing = false;
  //     _capturedImage = null;
  //   });

  //   bool confirmed = await showDialog<bool>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Capture Image'),
  //       content: SizedBox(
  //         height: 400,
  //         width: 300,
  //         child: Column(
  //           children: [
  //             Expanded(
  //               child: _isCameraReady
  //                   ? CameraPreview(_cameraController!)
  //                   : const Center(child: Text('Camera not available')),
  //             ),
  //             const SizedBox(height: 10),
  //             _isCapturing
  //                 ? const CircularProgressIndicator()
  //                 : ElevatedButton(
  //               onPressed: _isCapturing ? null : _captureImageAndOpenSignature,
  //               child: const Text('Capture'),
  //             ),
  //           ],
  //         ),
  //       ),
  //       actions: [
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             ElevatedButton(
  //               onPressed: _isCapturing ? null : _switchCamera,
  //               child: Text(_selectedCameraIndex == 0 ? 'Switch to Back' : 'Switch to Front'),
  //             ),
  //             ElevatedButton(
  //               onPressed: () {
  //                 Navigator.of(context).pop(false);
  //               },
  //               child: const Text('Cancel'),
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   ) ?? false;

  //   return confirmed;
  // }

  Future<void> _clockInOnline(String learnerID, String signaturePath) async {
    final url = Uri.parse(AppConfig.clockinUrl);
    try {
      // Validate classID
      if (widget.classID.isEmpty) {
        throw Exception('ClassID is missing or empty');
      }

      // Validate signature
      final signatureImage = await _signatureController.toPngBytes();
      if (signatureImage == null) {
        throw Exception('Failed to generate signature image.');
      }

      // Temporarily disabled geolocator functionality
      print('[LEARNER_LIST] Geolocator temporarily disabled - skipping location validation');

      // Prepare payload - updated to match new PHP script expectations
      final payload = {
        'LearnerID': learnerID,
        'clock_in': '1',
        'signature': base64Encode(signatureImage),
        'user_latitude': '0.0', // Default coordinates since geolocator is disabled
        'user_longitude': '0.0', // Default coordinates since geolocator is disabled
        'user_accuracy': '10.0', // Default accuracy since geolocator is disabled
        'isSynced': '0', // Changed from 'synced' to 'isSynced' to match PHP script
        'classID': widget.classID,
      };

      print('Sending online clock-in request for learnerID: $learnerID');
      print('Payload keys: ${payload.keys.toList()}');
      print('Signature length: ${payload['signature']?.toString().length ?? 0} characters');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: payload,
      ).timeout(const Duration(seconds: 30)); // Increased timeout for signature upload

      print('Raw server response (status ${response.statusCode}): "${response.body}"');

      // Handle different response status codes
      if (response.statusCode == 500) {
        throw Exception('Server internal error (500). Check PHP script logs. Response: "${response.body}"');
      }

      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}. Response: "${response.body}"');
      }

      // Check if response body is empty
      if (response.body.trim().isEmpty) {
        throw Exception('Server returned empty response. Check PHP script for fatal errors.');
      }

      dynamic result;
      try {
        result = jsonDecode(response.body);
      } catch (e) {
        throw Exception('Failed to parse server response: $e. Raw response: "${response.body}"');
      }

      if (result is Map<String, dynamic> && result['success'] == true) {
        setState(() {
          clockInTimes[learnerID] = result['clock_in_time'];
          clockOutTimes[learnerID] = result['clock_out_time'] ?? '';
          contactTimes[learnerID] = result['contact_time'] ?? '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Clock-in successful')),
        );
      } else {
        String errorMsg = 'Unknown server error';
        if (result is Map<String, dynamic>) {
          errorMsg = result['message'] ?? 'Server returned success=false';
        }
        throw Exception('Server error: ${response.statusCode} - $errorMsg');
      }
    } catch (e) {
      print('Online clock-in failed for learnerID: $learnerID: $e');

      // If server error, suggest falling back to offline mode
      if (e.toString().contains('500') || e.toString().contains('empty response')) {
        print('Server appears to be down. Consider falling back to offline mode.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server error detected. Data will be saved locally and synced later.'),
            duration: Duration(seconds: 5),
          ),
        );
      }

      throw Exception('Online clock-in failed: $e');
    }
  }

  Future<void> _clockOutOnline(String learnerID, String signaturePath, {bool synced = false}) async {
    final url = Uri.parse(AppConfig.clockoutUrl);
    final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      // Validate classID
      if (widget.classID.isEmpty) {
        throw Exception('ClassID is missing or empty');
      }

      // Prepare signature
      String signatureBase64 = '';
      try {
        final signatureImage = await _signatureController.toPngBytes();
        if (signatureImage != null) {
          signatureBase64 = base64Encode(signatureImage);
        } else {
          print('Warning: Failed to generate signature image, sending empty signature.');
        }
      } catch (e) {
        print('Warning: Signature generation failed: $e, sending empty signature.');
      }

      // Temporarily disabled geolocator functionality
      print('[LEARNER_LIST] Geolocator temporarily disabled - skipping location validation');

      // Prepare payload
      final payload = {
        'LearnerID': learnerID,
        'clock_out': '1',
        'signature': signatureBase64,
        'user_latitude': '0.0', // Default coordinates since geolocator is disabled
        'user_longitude': '0.0', // Default coordinates since geolocator is disabled
        'user_accuracy': '10.0', // Default accuracy since geolocator is disabled
        'synced': synced ? '1' : '0',
        'classID': widget.classID, // Added classID to payload
      };

      print('Sending online clock-out request: $payload');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: payload,
      ).timeout(const Duration(seconds: 30));

      print('Raw server response (status ${response.statusCode}): "${response.body}"');

      dynamic result;
      try {
        result = jsonDecode(response.body);
      } catch (e) {
        print('Failed to parse server response: "${response.body}"');
        throw Exception('Failed to parse server response: ${response.body}');
      }

      if (response.statusCode == 200 && result is Map<String, dynamic> && result['success'] == true) {
        String? contactTime = result['contact_time'];
        if (contactTime == null || contactTime.isEmpty) {
          final clockInTime = result['clock_in_time']?.toString();
          final clockOutTime = result['clock_out_time']?.toString();
          if (clockInTime != null && clockOutTime != null) {
            try {
              final timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
              final clockInDateTime = timeFormat.parse('$currentDate $clockInTime');
              final clockOutDateTime = timeFormat.parse('$currentDate $clockOutTime');
              final contactTimeDuration = clockOutDateTime.difference(clockInDateTime);
              contactTime = formatDuration(contactTimeDuration);
              print('Calculated contact time: $contactTime for learnerID=$learnerID');
            } catch (e) {
              print('Error calculating contact time: $e');
            }
          }
        }

        setState(() {
          clockOutTimes[learnerID] = result['clock_out_time'] ?? '';
          contactTimes[learnerID] = contactTime ?? '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      } else {
        throw Exception('Server error: ${response.statusCode} - ${result['message'] ?? response.body}');
      }
    } catch (e) {
      print('Online clock-out failed: $e');
      throw Exception('Online clock-out failed: $e');
    }
  }

  Future<void> _clockInOffline(String learnerID, String clockInTime) async {
    try {
      print('Starting offline clock-in for learnerID: $learnerID at $clockInTime');
      final dbHelper = DatabaseHelper();
      final clockDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Temporarily disabled geolocator functionality
      print('[LEARNER_LIST] Geolocator temporarily disabled - skipping location validation');

      // Save signature
      final appDir = await getApplicationDocumentsDirectory();
      final signaturePath = '${appDir.path}/signature_${learnerID}_$clockDate.png';
      final signatureFile = File(signaturePath);

      final signatureImage = await _signatureController.toPngBytes();
      if (signatureImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate signature image.')),
        );
        return;
      }
      await signatureFile.writeAsBytes(signatureImage);
      print('Signature saved at: $signaturePath, file exists: ${await signatureFile.exists()}');

      // Store clock-in data
      final clockInData = {
        'LearnerID': learnerID,
        'clock_in_time': clockInTime,
        'clock_date': clockDate,
        'signature': signaturePath,
        'synced': 0,
        'user_latitude': '0.0', // Default coordinates since geolocator is disabled
        'user_longitude': '0.0', // Default coordinates since geolocator is disabled
        'user_accuracy': '10.0', // Default accuracy since geolocator is disabled
        // 'classID': widget.classID, // Added classID for consistency
      };

      print('Inserting clock-in data: $clockInData');
      await dbHelper.insertClockInOffline(clockInData);
      print('Offline clock-in inserted successfully for learnerID: $learnerID');

      setState(() {
        clockInTimes[learnerID] = clockInTime;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clock-in saved locally. Will sync when online.')),
      );
    } catch (e, stackTrace) {
      print('Offline clock-in error for learnerID: $learnerID: $e\nStack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving offline clock-in: $e')),
      );
      rethrow;
    }
  }

  Future<void> updateClockOut(String learnerID, String clockOutTime, String clockDate) async {
    try {
      final db = await DatabaseHelper().database;
      final existingRecords = await db.query(
        'learner_clocking',
        where: 'LearnerID = ? AND clock_date = ?',
        whereArgs: [learnerID, clockDate],
      );

      if (existingRecords.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No clock-in record found for today.')),
        );
        return;
      }

      final clockInTime = existingRecords[0]['clock_in_time']?.toString();
      String? contactTime;
      if (clockInTime != null && clockInTime.isNotEmpty) {
        try {
          final timeFormat = DateFormat('HH:mm:ss');
          final clockInDateTime = timeFormat.parse(clockInTime);
          final clockOutDateTime = timeFormat.parse(clockOutTime);
          final contactTimeDuration = clockOutDateTime.difference(clockInDateTime);
          contactTime = formatDuration(contactTimeDuration);
        } catch (e) {
          print('Error calculating contact time: $e');
        }
      }

      final updatedData = {
        'clock_out_time': clockOutTime,
        'contact_time': contactTime,
      };

      await db.update(
        'learner_clocking',
        updatedData,
        where: 'LearnerID = ? AND clock_date = ?',
        whereArgs: [learnerID, clockDate],
      );

      setState(() {
        clockOutTimes[learnerID] = clockOutTime;
        if (contactTime != null) {
          contactTimes[learnerID] = contactTime;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clock-out saved locally. Will sync when online.')),
      );
    } catch (e) {
      print('Offline clock-out error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving offline clock-out: $e')),
      );
    }
  }

  String formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes % 60;
    int seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<String> _getSignatureFilePath(String learnerID) async {
    final appDir = await getApplicationDocumentsDirectory();
    final clockDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return '${appDir.path}/signature_${learnerID}_$clockDate.png';
  }

  Future<bool> clockInLearner(String learnerID) async {
    try {
      // final livenessPassed = await _performLivenessCheck();  // Temporarily disabled due to Java 21 compatibility issues
      // if (!livenessPassed) {  // Temporarily disabled due to Java 21 compatibility issues
      //   ScaffoldMessenger.of(context).showSnackBar(  // Temporarily disabled due to Java 21 compatibility issues
      //     const SnackBar(content: Text('Image capture cancelled or failed')),  // Temporarily disabled due to Java 21 compatibility issues
      //   );  // Temporarily disabled due to Java 21 compatibility issues
      //   return false;  // Temporarily disabled due to Java 21 compatibility issues
      // }  // Temporarily disabled due to Java 21 compatibility issues

      final signed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign to Clock In'),
          content: SizedBox(
            height: 300,
            width: 300,
            child: Column(
              children: [
                Expanded(
                  child: Signature(
                    controller: _signatureController,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () => _signatureController.clear(),
                      child: const Text('Clear'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (_signatureController.isNotEmpty) {
                          Navigator.of(context).pop(true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please provide a signature')),
                          );
                        }
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (signed != true) {
        return false;
      }

      final signaturePath = await _getSignatureFilePath(learnerID);
      final clockInTime = DateFormat('HH:mm:ss').format(DateTime.now());

      if (await _checkConnectivity()) {
        await _clockInOnline(learnerID, signaturePath);
      } else {
        await _clockInOffline(learnerID, clockInTime);
      }
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during clock-in: $e')),
      );
      return false;
    } finally {
      _signatureController.clear();
      setState(() {
        // _capturedImage = null;  // Temporarily disabled due to Java 21 compatibility issues
      });
    }
  }

  Future<void> clockOutLearner(String learnerID) async {
    final signed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign to Clock Out'),
        content: SizedBox(
          height: 300,
          width: 300,
          child: Column(
            children: [
              Expanded(
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: () => _signatureController.clear(),
                    child: const Text('Clear'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_signatureController.isNotEmpty) {
                        Navigator.of(context).pop(true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please provide a signature')),
                        );
                      }
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (signed != true) return;

    final clockOutTime = DateFormat('HH:mm:ss').format(DateTime.now());
    final signaturePath = await _getSignatureFilePath(learnerID);

    try {
      if (await _checkConnectivity()) {
        await _clockOutOnline(learnerID, signaturePath);
      } else {
        await updateClockOut(learnerID, clockOutTime, DateFormat('yyyy-MM-dd').format(DateTime.now()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record clock-out: $e')),
      );
    } finally {
      _signatureController.clear();
    }
  }

  @override
  void dispose() {
    // _cameraController?.dispose();  // Temporarily disabled due to Java 21 compatibility issues
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Learner List: Class ${widget.classID}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Class Information for ${widget.classID}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Learner Actions: Clock In/Out, Upload Sick Notes, View Details',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            widget.learners.isEmpty
                ? const Center(child: Text('No data available for this class'))
                : Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Surname')),
                      DataColumn(label: Text('ID Number')),
                      DataColumn(label: Text('Clock In Time')),
                      DataColumn(label: Text('Clock Out Time')),
                      DataColumn(label: Text('Contact Time')),
                      DataColumn(
                        label: Text(
                          'Actions (Sick Note/Details/PPE)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: widget.learners.map((item) {
                      String learnerID = item['LearnerID']?.toString() ?? '';
                      String? clockInTime = clockInTimes[learnerID];
                      String? clockOutTime = clockOutTimes[learnerID];
                      String? contactTime = contactTimes[learnerID];

                      return DataRow(
                        cells: [
                          DataCell(Text(item['Name']?.toString() ?? 'N/A')),
                          DataCell(Text(item['Surname']?.toString() ?? 'N/A')),
                          DataCell(Text(item['IDNumber']?.toString() ?? 'N/A')),
                          DataCell(
                            clockInTime != null && clockInTime.isNotEmpty
                                ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  clockInTime,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Clocked In',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ],
                            )
                                : ElevatedButton(
                              onPressed: () async {
                                final success = await clockInLearner(learnerID);
                                if (!success) {
                                  print('Clock-in failed for learnerID: $learnerID');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Clock In'),
                            ),
                          ),
                          DataCell(
                            clockOutTime != null && clockOutTime.isNotEmpty
                                ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  clockOutTime,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Clocked Out',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red[800],
                                  ),
                                ),
                              ],
                            )
                                : (clockInTime == null || clockInTime.isEmpty)
                                ? const Text('--', style: TextStyle(color: Colors.grey))
                                : ElevatedButton(
                              onPressed: () => clockOutLearner(learnerID),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Clock Out'),
                            ),
                          ),
                          DataCell(
                            Text(
                              contactTime ?? '--',
                              style: TextStyle(
                                color: (contactTime != null && contactTime.isNotEmpty)
                                    ? Colors.blue[800]
                                    : Colors.grey,
                                fontWeight: (contactTime != null && contactTime.isNotEmpty)
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: 'Upload a sick note for this learner',
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SickNotePage(
                                            learnerID: int.parse(learnerID),
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[100],
                                    ),
                                    icon: const Icon(Icons.medical_services, size: 18),
                                    label: const Text('Upload Sick Note'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'View learner details',
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DetailsPage(
                                            learnerID: int.parse(learnerID),
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                    ),
                                    child: const Text('Details'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'Collect PPE sizes (Conti-Suits & Safety Boots)',
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PPESizesPage(
                                            learnerID: int.parse(learnerID),
                                            learnerName: '${item['Name']} ${item['Surname']}',
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[100],
                                    ),
                                    icon: const Icon(Icons.checkroom, size: 18),
                                    label: const Text('PPE Sizes'),
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}