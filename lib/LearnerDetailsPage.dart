import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'EnrollmentPage.dart';
import 'database_helper.dart';
import 'config.dart';
import 'GuardianDetailsPage.dart';
import 'WorkExperienceForm.dart';
import 'package:intl/intl.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;

class LearnerDetailsPage extends StatefulWidget {
  final String learnerID;

  const LearnerDetailsPage({super.key, required this.learnerID});

  @override
  _LearnerDetailsPageState createState() => _LearnerDetailsPageState();
}

class _LearnerDetailsPageState extends State<LearnerDetailsPage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? learnerData;
  Map<String, dynamic>? bankDetails;
  XFile? capturedImage;
  bool isLoading = true;
  late TabController _tabController;
  final SignatureController _learnerSignatureController =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);
  final SignatureController _witnessSignatureController =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);
  final TextEditingController _learnerInitialsController =
      TextEditingController();
  final TextEditingController _witnessInitialsController =
      TextEditingController();
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  final bool _isWitnessSignatureCompleted = false;
  late Map<String, TextEditingController> _controllers;

  // Guardian fields
  bool _isMinor = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 5, vsync: this); // Will be updated after data loads
    _controllers = {};
    fetchLearnerDetails();
    syncLocalData();
  }

  void _updateTabController() {
    final newLength = _isMinor ? 6 : 5;
    print(
        '[GUARDIAN] Updating tab controller: isMinor=$_isMinor, newLength=$newLength, currentLength=${_tabController.length}');
    if (_tabController.length != newLength) {
      final oldIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: newLength,
        vsync: this,
        initialIndex: oldIndex < newLength ? oldIndex : 0,
      );
      print('[GUARDIAN] Tab controller updated to $newLength tabs');
    }
  }

  // Calculate age from ID number (South African format: YYMMDDGGGGSAAZ)
  int? _calculateAgeFromID(String? idNumber) {
    print('[GUARDIAN] Calculating age from ID: $idNumber');

    if (idNumber == null || idNumber.length < 6) {
      print('[GUARDIAN] ID number is null or too short');
      return null;
    }

    try {
      final yearPrefix = int.parse(idNumber.substring(0, 2));
      final month = int.parse(idNumber.substring(2, 4));
      final day = int.parse(idNumber.substring(4, 6));

      // Dynamic century determination based on current year
      // If year prefix would make person older than 100, assume 2000s
      // Otherwise, use the century that makes most sense
      final currentYear = DateTime.now().year;
      final currentYearPrefix = currentYear % 100; // e.g., 2026 → 26

      int year;
      if (yearPrefix <= currentYearPrefix) {
        // Could be 2000s (e.g., 26 in 2026 = born 2026, age 0)
        year = 2000 + yearPrefix;
      } else {
        // Must be 1900s (e.g., 87 in 2026 = born 1987, age 38)
        year = 1900 + yearPrefix;
      }

      // Validate: if calculated age would be > 100, assume 2000s instead
      final birthDate = DateTime(year, month, day);
      final today = DateTime.now();
      int age = today.year - birthDate.year;

      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }

      // If age is negative or > 100, recalculate with opposite century
      if (age < 0 || age > 100) {
        if (year >= 2000) {
          year = 1900 + yearPrefix;
        } else {
          year = 2000 + yearPrefix;
        }
        final newBirthDate = DateTime(year, month, day);
        age = today.year - newBirthDate.year;
        if (today.month < newBirthDate.month ||
            (today.month == newBirthDate.month &&
                today.day < newBirthDate.day)) {
          age--;
        }
        print('[GUARDIAN] Adjusted birth date: $newBirthDate, Age: $age');
      } else {
        print('[GUARDIAN] Birth date: $birthDate, Age: $age');
      }

      return age;
    } catch (e) {
      print('[GUARDIAN] Error calculating age from ID: $e');
      return null;
    }
  }

  // Calculate date of birth from ID number
  DateTime? _calculateDOBFromID(String? idNumber) {
    if (idNumber == null || idNumber.length < 6) {
      return null;
    }

    try {
      final yearPrefix = int.parse(idNumber.substring(0, 2));
      final month = int.parse(idNumber.substring(2, 4));
      final day = int.parse(idNumber.substring(4, 6));

      // Dynamic century determination based on current year
      final currentYear = DateTime.now().year;
      final currentYearPrefix = currentYear % 100;

      int year;
      if (yearPrefix <= currentYearPrefix) {
        year = 2000 + yearPrefix;
      } else {
        year = 1900 + yearPrefix;
      }

      // Validate: if age would be > 100, use opposite century
      final birthDate = DateTime(year, month, day);
      final today = DateTime.now();
      int age = today.year - birthDate.year;

      if (age < 0 || age > 100) {
        year = year >= 2000 ? 1900 + yearPrefix : 2000 + yearPrefix;
      }

      return DateTime(year, month, day);
    } catch (e) {
      print('[DOB] Error calculating DOB from ID: $e');
      return null;
    }
  }

  // Extract gender from ID number (digits 7-10: 0000-4999 = Female, 5000-9999 = Male)
  String? _extractGenderFromID(String? idNumber) {
    if (idNumber == null || idNumber.length < 10) {
      return null;
    }

    try {
      final genderDigits = int.parse(idNumber.substring(6, 10));
      return genderDigits < 5000 ? 'Female' : 'Male';
    } catch (e) {
      print('[GENDER] Error extracting gender from ID: $e');
      return null;
    }
  }

  // Update a single field in the database
  Future<void> _updateDatabaseField(String fieldName, dynamic value) async {
    try {
      final db = await DatabaseHelper().database;
      await db.update(
        'learnerdetails',
        {
          fieldName: value,
          'synced': 0
        }, // Mark as unsynced so it uploads to server
        where: 'LearnerID = ?',
        whereArgs: [int.parse(widget.learnerID)],
      );
      print(
          '[DB_UPDATE] Updated $fieldName to $value for learner ${widget.learnerID}');

      // Update local learnerData map so UI stays in sync
      if (learnerData != null) {
        learnerData![fieldName] = value;
      }
    } catch (e) {
      print('[DB_UPDATE] Error updating $fieldName: $e');
    }
  }

  Future<void> fetchBankDetails() async {
    try {
      final db = await DatabaseHelper().database;
      final result = await db.query(
        'bankdetails',
        where: 'LearnerID = ?',
        whereArgs: [widget.learnerID],
      );

      if (result.isNotEmpty) {
        setState(() {
          bankDetails = result.first;
        });
        print('[BANK] Bank details loaded: ${bankDetails!['BankName']}');
      } else {
        print('[BANK] No bank details found for learner ${widget.learnerID}');
      }
    } catch (e) {
      print('[BANK] Error fetching bank details: $e');
    }
  }

  Future<void> fetchGuardianData() async {
    if (!_isMinor) return; // Only fetch for minors

    try {
      final guardianData = await DatabaseHelper()
          .fetchGuardianDetails(int.parse(widget.learnerID));

      if (guardianData != null) {
        print(
            '[GUARDIAN] Guardian data loaded for learner ${widget.learnerID}');
      }
    } catch (e) {
      print('[GUARDIAN] Error fetching guardian data: $e');
    }
  }

  Future<void> fetchLearnerDetails() async {
    try {
      bool hasConnectivity = await _checkConnectivity();
      if (hasConnectivity) {
        // Try to fetch from online database first
        final response = await http.get(
          Uri.parse(
              '${AppConfig.learnerDetailsUrl}?LearnerID=${widget.learnerID}'),
        );
        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          if (jsonResponse['success'] == true) {
            setState(() {
              learnerData = jsonResponse['data'];
              isLoading = false;
              // Initialize controllers with fetched data
              learnerData!.forEach((key, value) {
                _controllers[key] =
                    TextEditingController(text: value?.toString() ?? '');
              });
              // Check if learner is a minor - use Age field from data or calculate from ID
              int? age;
              if (learnerData!['Age'] != null) {
                age = int.tryParse(learnerData!['Age'].toString());
              } else {
                age = _calculateAgeFromID(learnerData!['IDNumber']);
              }
              _isMinor = age != null && age < 18;
              print('[GUARDIAN] ===== ONLINE FETCH =====');
              print(
                  '[GUARDIAN] IDNumber: ${learnerData!['IDNumber']}, Age: $age, Is Minor: $_isMinor');
              print(
                  '[GUARDIAN] Tab controller will be updated to ${_isMinor ? 5 : 4} tabs');
              _updateTabController();
            });
            print(
                'Learner data fetched from online database: ${learnerData!.keys.toList()}');
            await fetchBankDetails();
            await fetchGuardianData();
            return;
          } else {
            print('Online fetch failed: ${jsonResponse['message']}');
          }
        } else {
          print('Online fetch failed with status: ${response.statusCode}');
        }
      }

      // Fallback to local database
      print('Fetching from local database...');
      final localLearnerData =
          await DatabaseHelper().fetchLearnerByID(widget.learnerID);
      if (localLearnerData != null) {
        setState(() {
          learnerData = localLearnerData;
          isLoading = false;
          // Initialize controllers with local data
          learnerData!.forEach((key, value) {
            _controllers[key] =
                TextEditingController(text: value?.toString() ?? '');
          });
          // Check if learner is a minor - use Age field from data or calculate from ID
          int? age;
          if (learnerData!['Age'] != null) {
            age = int.tryParse(learnerData!['Age'].toString());
          } else {
            age = _calculateAgeFromID(learnerData!['IDNumber']);
          }
          _isMinor = age != null && age < 18;
          print('[GUARDIAN] ===== LOCAL FETCH =====');
          print(
              '[GUARDIAN] IDNumber: ${learnerData!['IDNumber']}, Age: $age, Is Minor: $_isMinor');
          print(
              '[GUARDIAN] Tab controller will be updated to ${_isMinor ? 5 : 4} tabs');
          _updateTabController();
        });
        print(
            'Learner data fetched from local database: ${learnerData!.keys.toList()}');
        await fetchBankDetails();
        await fetchGuardianData();
      } else {
        setState(() {
          learnerData = {"message": "No learner data found"};
          isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No learner data found')),
          );
        }
      }
    } catch (e) {
      print('Error fetching learner details: $e');
      if (mounted) {
        setState(() {
          learnerData = {"message": "Error: $e"};
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading learner details: $e')),
        );
      }
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> syncLocalData() async {
    // Signatures and initials are stored in learnerdetails table
    // and will be synced automatically with learner data
    // No separate sync needed
    print(
        'Sync local data called - signatures/initials stored in learnerdetails table');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _learnerSignatureController.dispose();
    _witnessSignatureController.dispose();
    _learnerInitialsController.dispose();
    _witnessInitialsController.dispose();
    _cameraController?.dispose();
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final firstCamera = cameras.first;
      _cameraController =
          CameraController(firstCamera, ResolutionPreset.medium);
      await _cameraController!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print("Camera initialization failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera initialization failed: $e')),
      );
    }
  }

  Future<void> _updateData() async {
    print('Updating learner data for learner_id: ${widget.learnerID}');
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updating learner data...')),
      );

      // Update learner information if any fields have changed
      await _updateLearnerInformation();

      // Handle image upload
      if (capturedImage != null) {
        print('Uploading captured image...');
        await _uploadImage(capturedImage!.path);
      }

      // Handle learner signature
      final learnerSignatureBytes =
          await _learnerSignatureController.toPngBytes();
      if (learnerSignatureBytes != null) {
        final signaturePath = await _saveSignatureImage(
            learnerSignatureBytes, 'learner_signature');
        bool isConnected = await _checkConnectivity();
        if (isConnected) {
          await _uploadSignature(signaturePath, 'signature');
        } else {
          await DatabaseHelper().saveSignatureLocally(
              widget.learnerID, signaturePath, 'signature');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Learner signature saved locally')),
          );
        }
      }

      // Handle witness signature
      final witnessSignatureBytes =
          await _witnessSignatureController.toPngBytes();
      if (witnessSignatureBytes != null) {
        final signaturePath = await _saveSignatureImage(
            witnessSignatureBytes, 'witness_signature');
        bool isConnected = await _checkConnectivity();
        if (isConnected) {
          await _uploadSignature(signaturePath, 'witness_signature');
        } else {
          await DatabaseHelper().saveSignatureLocally(
              widget.learnerID, signaturePath, 'witness_signature');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Witness signature saved locally')),
          );
        }
      }

      // Handle learner initials
      if (_learnerInitialsController.text.isNotEmpty) {
        bool isConnected = await _checkConnectivity();
        if (isConnected) {
          await _uploadInitialsToServer(
              _learnerInitialsController.text, 'learner_initials');
        } else {
          await DatabaseHelper().saveInitialsLocally(widget.learnerID,
              _learnerInitialsController.text, 'learner_initials');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Learner initials saved locally')),
          );
        }
      }

      // Handle witness initials
      if (_witnessInitialsController.text.isNotEmpty) {
        bool isConnected = await _checkConnectivity();
        if (isConnected) {
          await _uploadInitialsToServer(
              _witnessInitialsController.text, 'witness_initials');
        } else {
          await DatabaseHelper().saveInitialsLocally(widget.learnerID,
              _witnessInitialsController.text, 'witness_initials');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Witness initials saved locally')),
          );
        }
      }

      // Refresh the data to show updated information
      await fetchLearnerDetails();

      print('Learner data update completed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Learner data updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating learner details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateLearnerInformation() async {
    try {
      // Prepare the data to update
      Map<String, dynamic> updateData = {};

      // Add all the form fields that have been modified
      _controllers.forEach((key, controller) {
        if (controller.text.isNotEmpty &&
            controller.text != learnerData?[key]?.toString()) {
          updateData[key] = controller.text;
        }
      });

      // If there's data to update, send it to the server
      if (updateData.isNotEmpty) {
        bool isConnected = await _checkConnectivity();
        if (isConnected) {
          final response = await http.post(
            Uri.parse(AppConfig.updateLearnerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'LearnerID': widget.learnerID,
              'data': updateData,
            }),
          );

          if (response.statusCode == 200) {
            final jsonResponse = jsonDecode(response.body);
            if (jsonResponse['success'] == true) {
              print('Learner information updated successfully');
            } else {
              print(
                  'Failed to update learner information: ${jsonResponse['message']}');
              throw Exception(jsonResponse['message']);
            }
          } else {
            print(
                'Failed to update learner information: HTTP ${response.statusCode}');
            throw Exception('Server error: ${response.statusCode}');
          }
        } else {
          // Save locally if no internet connection
          await DatabaseHelper()
              .updateLearnerLocally(widget.learnerID, updateData);
          print('Learner information saved locally');
        }
      }
    } catch (e) {
      print('Error updating learner information: $e');
      rethrow;
    }
  }

  Future<void> _captureImage(bool isPhoto) async {
    if (!_isCameraInitialized) await _initializeCamera();
    final imagePath = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraPreviewScreen(
          cameraController: _cameraController!,
          learnerID: widget.learnerID,
        ),
      ),
    );

    if (imagePath != null) {
      print('Image captured: $imagePath');
      final directory = await getApplicationDocumentsDirectory();
      final savedImagePath =
          '${directory.path}/learnerImages_${widget.learnerID}.png';
      try {
        final capturedFile = File(imagePath);
        final savedImageFile = await capturedFile.copy(savedImagePath);
        print('Image saved to: $savedImagePath');
        bool isConnected = await _checkConnectivity();
        if (isConnected) {
          await saveImagePathToDatabase(savedImagePath);
        } else {
          await saveImageLocally(savedImagePath);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image saved locally')),
          );
        }
        setState(() {
          capturedImage = XFile(savedImagePath);
        });
      } catch (e) {
        print('Error saving image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving image: $e')),
        );
      }
    } else {
      print('No image captured');
    }
  }

  Future<void> saveImagePathToDatabase(String imagePath) async {
    final imageName = imagePath.split('/').last;
    try {
      final response = await http.post(
        Uri.parse(AppConfig.saveImageUrl),
        body: {
          'profile_image': imageName,
          'LearnerID': widget.learnerID.trim(),
        },
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          print('Image path saved to server');
        } else {
          print('Failed to save image path: ${jsonResponse['message']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to save image path: ${jsonResponse['message']}')),
          );
          await saveImageLocally(imagePath);
        }
      } else {
        print('Failed to save image path: HTTP ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to save image path: Server error (${response.statusCode})')),
        );
        await saveImageLocally(imagePath);
      }
    } catch (e) {
      print('Error saving image path: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image path: $e')),
      );
      await saveImageLocally(imagePath);
    }
  }

  Future<void> saveImageLocally(String imagePath) async {
    try {
      await DatabaseHelper().saveImageLocally(widget.learnerID, imagePath);
      print('Image saved locally for learner_id: ${widget.learnerID}');
    } catch (e) {
      print('Error saving image locally: $e');
    }
  }

  Future<String> _saveSignatureImage(
      Uint8List signatureBytes, String fileNamePrefix) async {
    final tempDir = await getTemporaryDirectory();
    final signatureFilePath =
        '${tempDir.path}/${fileNamePrefix}_${widget.learnerID}.png';
    final signatureFile = File(signatureFilePath);
    await signatureFile.writeAsBytes(signatureBytes);
    return signatureFilePath;
  }

  Future<void> _uploadSignature(String signaturePath, String fieldName) async {
    final imageName = signaturePath.split('/').last;
    final imageBytes = await File(signaturePath).readAsBytes();
    try {
      print('Uploading $fieldName for learner_id: ${widget.learnerID}');
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConfig.saveSignatureUrl),
      );
      request.files.add(http.MultipartFile.fromBytes(
        fieldName,
        imageBytes,
        filename: imageName,
      ));
      request.fields['learner_id'] = widget.learnerID.trim();
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      print('$fieldName upload response: $responseBody');
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(responseBody);
        if (jsonResponse['success']) {
          print('$fieldName uploaded successfully');
        } else {
          print('$fieldName upload failed: ${jsonResponse['message']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to upload $fieldName: ${jsonResponse['message']}')),
          );
          await DatabaseHelper()
              .saveSignatureLocally(widget.learnerID, signaturePath, fieldName);
        }
      } else {
        print('Failed to upload $fieldName: HTTP ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to upload $fieldName: Server error (${response.statusCode})')),
        );
        await DatabaseHelper()
            .saveSignatureLocally(widget.learnerID, signaturePath, fieldName);
      }
    } catch (e) {
      print('Error uploading $fieldName: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading $fieldName: $e')),
      );
      await DatabaseHelper()
          .saveSignatureLocally(widget.learnerID, signaturePath, fieldName);
    }
  }

  Future<void> _uploadInitialsToServer(
      String initials, String fieldName) async {
    try {
      print('Uploading $fieldName for learner_id: ${widget.learnerID}');
      final response = await http.post(
        Uri.parse(AppConfig.saveInitialsUrl),
        body: {
          'learner_id': widget.learnerID.trim(),
          'field': fieldName,
          'value': initials,
        },
      );
      print('$fieldName upload response: ${response.body}');
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          print('$fieldName uploaded successfully');
        } else {
          print('$fieldName upload failed: ${jsonResponse['message']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to upload $fieldName: ${jsonResponse['message']}')),
          );
          await DatabaseHelper()
              .saveInitialsLocally(widget.learnerID, initials, fieldName);
        }
      } else {
        print('Failed to upload $fieldName: HTTP ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to upload $fieldName: Server error (${response.statusCode})')),
        );
        await DatabaseHelper()
            .saveInitialsLocally(widget.learnerID, initials, fieldName);
      }
    } catch (e) {
      print('Error uploading $fieldName: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading $fieldName: $e')),
      );
      await DatabaseHelper()
          .saveInitialsLocally(widget.learnerID, initials, fieldName);
    }
  }

  Future<bool> _promptSignature(
      String title, SignatureController controller, String fieldName) async {
    bool saved = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 300,
          height: 200,
          child:
              Signature(controller: controller, backgroundColor: Colors.white),
        ),
        actions: [
          TextButton(
              onPressed: () => controller.clear(), child: const Text('Clear')),
          TextButton(
            onPressed: () async {
              if (controller.isNotEmpty) {
                final signatureBytes = await controller.toPngBytes();
                if (signatureBytes != null) {
                  final signaturePath =
                      await _saveSignatureImage(signatureBytes, fieldName);
                  bool isConnected = await _checkConnectivity();
                  if (isConnected) {
                    await _uploadSignature(signaturePath, fieldName);
                  } else {
                    await DatabaseHelper().saveSignatureLocally(
                        widget.learnerID, signaturePath, fieldName);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$fieldName saved locally')),
                    );
                  }
                  saved = true;
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return saved;
  }

  Future<bool> _promptInitials(
      String title, TextEditingController controller, String fieldName) async {
    bool saved = false;
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter $title'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'e.g., JD'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Field cannot be empty'
                : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                bool isConnected = await _checkConnectivity();
                if (isConnected) {
                  await _uploadInitialsToServer(controller.text, fieldName);
                } else {
                  await DatabaseHelper().saveInitialsLocally(
                      widget.learnerID, controller.text, fieldName);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$fieldName saved locally')),
                  );
                }
                saved = true;
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return saved;
  }

  Future<void> _openWitnessSignaturePad() async {
    final witnessSignatureSaved = await _promptSignature(
        'Witness Signature', _witnessSignatureController, 'witness_signature');
    if (witnessSignatureSaved) {
      await _promptInitials(
          'Witness Initials', _witnessInitialsController, 'witness_initials');
    }
  }

  Future<void> _openInitialsDialog() async {
    final learnerInitialsSaved = await _promptInitials(
        'Learner Initials', _learnerInitialsController, 'learner_initials');
    if (learnerInitialsSaved) {
      await _promptInitials(
          'Witness Initials', _witnessInitialsController, 'witness_initials');
    }
  }

  Future<void> _openSignaturePad() async {
    final signatureSaved = await _promptSignature(
        'Learner Signature', _learnerSignatureController, 'signature');
    if (signatureSaved) {
      await _promptInitials(
          'Learner Initials', _learnerInitialsController, 'learner_initials');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learner Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              fetchLearnerDetails();
            },
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: 'Details'),
            if (_isMinor) const Tab(text: 'Guardian'),
            const Tab(text: 'Signature'),
            const Tab(text: 'Finger Print'),
            const Tab(text: 'Work Experience'),
            const Tab(text: 'Agreement'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(),
                if (_isMinor) _buildGuardianTab(),
                _buildSignatureTab(),
                _buildFingerprintTab(context),
                _buildWorkExperienceTab(),
                _buildAgreementTab(),
              ],
            ),
    );
  }

  Widget _buildDetailsTab() {
    return learnerData != null && !learnerData!.containsKey('message')
        ? Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Image Section
                  GestureDetector(
                    onTap: () => _captureImage(true),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        child: ClipOval(
                          child: _buildProfileImage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Tap to update profile image',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  // Age Display
                  _buildAgeDisplay(),
                  const SizedBox(height: 16.0),
                  // Bank Details
                  _buildBankDetails(),
                  const SizedBox(height: 16.0),
                  _buildDataList(learnerData!.entries.toList()),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _updateData,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32.0, vertical: 12.0),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Update Learner Data'),
                  ),
                ],
              ),
            ),
          )
        : Center(child: Text(learnerData?['message'] ?? 'No data available'));
  }

  Widget _buildProfileImage() {
    // First check if there's a captured image
    if (capturedImage != null) {
      return Image.file(
        File(capturedImage!.path),
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultImage();
        },
      );
    }

    // Then check if there's a profile image from the database
    if (learnerData != null &&
        learnerData!['profile_image'] != null &&
        learnerData!['profile_image'].toString().isNotEmpty) {
      return Image.network(
        '${AppConfig.learnerImagesUrl}/${learnerData!['profile_image']}',
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 120,
            height: 120,
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('Error loading profile image: $error');
          return _buildDefaultImage();
        },
      );
    }

    // Finally, show default image
    return _buildDefaultImage();
  }

  Widget _buildDefaultImage() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: 60,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildAgeDisplay() {
    int? age;
    DateTime? dob;
    String? gender;

    // First try to get age from the Age field in learnerData
    if (learnerData!['Age'] != null &&
        learnerData!['Age'].toString().isNotEmpty) {
      age = int.tryParse(learnerData!['Age'].toString());
    }

    // If Age field doesn't exist or is invalid, calculate from ID number
    age ??= _calculateAgeFromID(learnerData!['IDNumber']);

    // Try to get DOB from database first (format: 1981-01-19)
    if (learnerData!['DateOfBirth'] != null &&
        learnerData!['DateOfBirth'].toString().isNotEmpty) {
      try {
        final dobString = learnerData!['DateOfBirth'].toString().trim();
        // Handle both "1981-01-19" and "1981-01-19 00:00:00" formats
        if (dobString.contains(' ')) {
          dob = DateTime.parse(dobString.split(' ')[0]);
        } else {
          dob = DateTime.parse(dobString);
        }
      } catch (e) {
        print('[DOB] Error parsing DOB from database: $e');
        dob = _calculateDOBFromID(learnerData!['IDNumber']);
      }
    } else {
      // Calculate from ID number if not in database
      dob = _calculateDOBFromID(learnerData!['IDNumber']);
    }

    // Try to get gender from database first
    if (learnerData!['Gender'] != null &&
        learnerData!['Gender'].toString().trim().isNotEmpty) {
      gender = learnerData!['Gender'].toString().trim();
    } else {
      // Extract from ID number if not in database
      gender = _extractGenderFromID(learnerData!['IDNumber']);
    }

    return Card(
      elevation: 3,
      color: age != null && age < 18 ? Colors.orange[50] : Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cake,
                  size: 32,
                  color: age != null && age < 18 ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Age',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      age != null ? '$age years old' : 'Age not available',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: age != null && age < 18
                            ? Colors.orange[800]
                            : Colors.blue[800],
                      ),
                    ),
                    if (age != null && age < 18)
                      const Text(
                        'Minor - Guardian info required',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (dob != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 20, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Date of Birth: ${DateFormat('dd MMM yyyy').format(dob)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ],
            if (gender != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    gender == 'Male' ? Icons.male : Icons.female,
                    size: 20,
                    color:
                        gender == 'Male' ? Colors.blue[700] : Colors.pink[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Gender: $gender',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBankDetails() {
    if (bankDetails == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 3,
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, size: 32, color: Colors.green[700]),
                const SizedBox(width: 12),
                Text(
                  'Bank Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildBankDetailRow('Bank Name', bankDetails!['BankName']),
            _buildBankDetailRow('Account Type', bankDetails!['bankType']),
            _buildBankDetailRow('Account Number', bankDetails!['BankAccount']),
            _buildBankDetailRow('Branch Code', bankDetails!['BankCode']),
          ],
        ),
      ),
    );
  }

  Widget _buildBankDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'Not provided',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataList(List<MapEntry<String, dynamic>> entries) {
    // Define fields that should be read-only (system-managed fields)
    final List<String> readOnlyFields = [
      'LearnerID',
      'classID',
      'signature',
      'synced',
      'zkteco_right_template',
      'imagePath',
      'zkteco_left_template',
      'activity_statu',
      'witness_initials',
      'learner_initials',
      'witness_signature',
      'sourceafis_template',
      'futronic_left_template',
      'futronic_right_template',
      'profile_image',
      'Age',
      'DateOfBirth',
      'Gender',
    ];

    // Fields that should use dropdowns when empty
    final Map<String, List<String>> dropdownFields = {
      'Title': ['Mr', 'Mrs', 'Miss', 'Ms', 'Dr', 'Prof'],
      'Gender': ['Male', 'Female'],
    };

    // Reorder entries to group address fields together
    final List<MapEntry<String, dynamic>> reorderedEntries = [];
    final Map<String, MapEntry<String, dynamic>> addressFieldsMap = {};

    // Collect address fields (except AddressLine1)
    for (var entry in entries) {
      if (entry.key == 'AddressLine2' ||
          entry.key == 'AddressLine3' ||
          entry.key == 'PostalCode') {
        addressFieldsMap[entry.key] = entry;
      }
    }

    // Build reordered list
    for (var entry in entries) {
      // Skip address fields (except AddressLine1) as we'll add them after AddressLine1
      if (entry.key == 'AddressLine2' ||
          entry.key == 'AddressLine3' ||
          entry.key == 'PostalCode') {
        continue;
      }

      reorderedEntries.add(entry);

      // After AddressLine1, add the other address fields in order
      if (entry.key == 'AddressLine1') {
        // Add in specific order: AddressLine2, AddressLine3, PostalCode
        if (addressFieldsMap.containsKey('AddressLine2')) {
          reorderedEntries.add(addressFieldsMap['AddressLine2']!);
        }
        if (addressFieldsMap.containsKey('AddressLine3')) {
          reorderedEntries.add(addressFieldsMap['AddressLine3']!);
        }
        if (addressFieldsMap.containsKey('PostalCode')) {
          reorderedEntries.add(addressFieldsMap['PostalCode']!);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: reorderedEntries.map((entry) {
        // Skip profile_image from display (it's shown separately)
        if (entry.key == 'profile_image') return const SizedBox.shrink();

        // Check if this field should be read-only
        final bool isReadOnly = readOnlyFields.contains(entry.key);

        // Force Age, DateOfBirth, and Gender to ALWAYS be read-only
        final bool isAlwaysReadOnly = isReadOnly ||
            entry.key == 'Age' ||
            entry.key == 'DateOfBirth' ||
            entry.key == 'Gender';

        // Check if field value is null or empty
        final bool isEmptyValue =
            entry.value == null || entry.value.toString().trim().isEmpty;

        // Check if field has invalid/placeholder values that should be recalculated
        final bool hasInvalidValue = (entry.key == 'Age' &&
                (entry.value == null ||
                    entry.value.toString().trim().isEmpty ||
                    entry.value.toString() == '0')) ||
            (entry.key == 'Gender' &&
                (entry.value == null ||
                    entry.value.toString().trim().isEmpty ||
                    entry.value.toString().toLowerCase() == 'unknown')) ||
            (entry.key == 'DateOfBirth' &&
                (entry.value == null ||
                    entry.value.toString().trim().isEmpty ||
                    entry.value.toString().startsWith('1900-01-01')));

        // Auto-populate Gender from ID if empty or invalid
        if (entry.key == 'Gender' && hasInvalidValue) {
          final extractedGender =
              _extractGenderFromID(learnerData!['IDNumber']);
          if (extractedGender != null && _controllers[entry.key] != null) {
            _controllers[entry.key]!.text = extractedGender;
            // Update database with correct value
            _updateDatabaseField('Gender', extractedGender);
          }
        }

        // Auto-populate Age from ID if empty or invalid
        if (entry.key == 'Age' && hasInvalidValue) {
          final calculatedAge = _calculateAgeFromID(learnerData!['IDNumber']);
          if (calculatedAge != null && _controllers[entry.key] != null) {
            _controllers[entry.key]!.text = calculatedAge.toString();
            // Update database with correct value
            _updateDatabaseField('Age', calculatedAge);
          }
        }

        // Auto-populate DateOfBirth from ID if empty or invalid
        if (entry.key == 'DateOfBirth' && hasInvalidValue) {
          final calculatedDOB = _calculateDOBFromID(learnerData!['IDNumber']);
          if (calculatedDOB != null && _controllers[entry.key] != null) {
            // Format as YYYY-MM-DD to match database format
            final formattedDOB = DateFormat('yyyy-MM-dd').format(calculatedDOB);
            _controllers[entry.key]!.text = formattedDOB;
            // Update database with correct value
            _updateDatabaseField('DateOfBirth', formattedDOB);
          }
        }

        // Check if this field should use a dropdown (only when empty and NOT read-only)
        final bool shouldUseDropdown = dropdownFields.containsKey(entry.key) &&
            isEmptyValue &&
            !isAlwaysReadOnly;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Card(
            elevation: 2,
            color: isAlwaysReadOnly ? Colors.grey[200] : null,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isAlwaysReadOnly) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.lock,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          entry.key == 'Age' ||
                                  entry.key == 'DateOfBirth' ||
                                  entry.key == 'Gender'
                              ? 'From ID'
                              : 'System',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (shouldUseDropdown) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_drop_down_circle,
                          size: 16,
                          color: Colors.blue[600],
                        ),
                      ],
                      // Show auto-filled indicator for Age, DOB, Gender
                      if ((entry.key == 'Age' ||
                              entry.key == 'DateOfBirth' ||
                              entry.key == 'Gender') &&
                          isEmptyValue &&
                          !isReadOnly) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Colors.green[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Auto',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  if (shouldUseDropdown)
                    DropdownButtonFormField<String>(
                      value: _controllers[entry.key]?.text.isNotEmpty == true
                          ? _controllers[entry.key]!.text
                          : null,
                      decoration: InputDecoration(
                        labelText: entry.key,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 12.0,
                        ),
                        isDense: true,
                      ),
                      items: dropdownFields[entry.key]!
                          .map((value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _controllers[entry.key]!.text = newValue;
                          });
                        }
                      },
                      hint: Text('Select ${entry.key}'),
                    )
                  else
                    TextFormField(
                      controller: _controllers[entry.key],
                      enabled: !isAlwaysReadOnly,
                      readOnly: isAlwaysReadOnly,
                      maxLines: isAlwaysReadOnly &&
                              (entry.value?.toString().length ?? 0) > 50
                          ? 3
                          : 1,
                      decoration: InputDecoration(
                        labelText: entry.key,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 8.0,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor:
                            isAlwaysReadOnly ? Colors.grey[200] : Colors.white,
                        helperText: isAlwaysReadOnly
                            ? (entry.key == 'Age' ||
                                    entry.key == 'DateOfBirth' ||
                                    entry.key == 'Gender'
                                ? 'Calculated from ID number - Cannot be edited'
                                : 'System-managed field')
                            : null,
                        helperStyle: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                      style: TextStyle(
                        color:
                            isAlwaysReadOnly ? Colors.grey[700] : Colors.black,
                        fontSize: isAlwaysReadOnly ? 12 : 14,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGuardianTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.family_restroom,
              size: 80,
              color: Colors.orange[700],
            ),
            const SizedBox(height: 24),
            const Text(
              'Guardian Information Required',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'This learner is under 18 years old.\nParent or guardian details must be provided.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GuardianDetailsPage(
                      learnerID: widget.learnerID,
                      learnerData: learnerData,
                    ),
                  ),
                );
                // Refresh guardian data if saved
                if (result == true) {
                  await fetchGuardianData();
                }
              },
              icon: const Icon(Icons.edit, size: 24),
              label: const Text(
                'Enter Guardian Details',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Learner Signature Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Learner Signature',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSignatureDisplay('signature', 'Learner Signature'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openSignaturePad(),
                            icon: const Icon(Icons.edit),
                            label: const Text('Capture New Signature'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Witness Signature Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person_add, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Witness Signature',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSignatureDisplay(
                        'witness_signature', 'Witness Signature'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openWitnessSignaturePad(),
                            icon: const Icon(Icons.person_add),
                            label: const Text('Capture Witness Signature'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Initials Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.text_fields, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Initials',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Learner Initials:'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  learnerData?['learner_initials']
                                          ?.toString() ??
                                      'Not captured',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Witness Initials:'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  learnerData?['witness_initials']
                                          ?.toString() ??
                                      'Not captured',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openInitialsDialog(),
                            icon: const Icon(Icons.text_fields),
                            label: const Text('Update Initials'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureDisplay(String signatureField, String title) {
    String? signaturePath = learnerData?[signatureField]?.toString();

    if (signaturePath != null && signaturePath.isNotEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            '${AppConfig.signaturesUrl}/$signaturePath',
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 150,
                color: Colors.grey[200],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.grey[600], size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Signature not found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit, color: Colors.grey[600], size: 40),
              const SizedBox(height: 8),
              Text(
                'No signature captured',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildFingerprintTab(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fingerprint, size: 60, color: Colors.blue),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              try {
                final learnerId = int.parse(widget.learnerID);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EnrollmentPage(learnerId: learnerId),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invalid learner ID format: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Enroll Fingerprint'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkExperienceTab() {
    return WorkExperienceForm(learnerID: widget.learnerID);
  }

  Future<void> _uploadImage(String imagePath) async {
    final imageName = imagePath.split('/').last;
    final imageBytes = await File(imagePath).readAsBytes();
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConfig.saveImageUrl),
      );
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: imageName,
      ));
      request.fields['learner_id'] = widget.learnerID.trim();
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      print('Image upload response: $responseBody');
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(responseBody);
        if (jsonResponse['success']) {
          print('Image uploaded successfully');
        } else {
          print('Image upload failed: ${jsonResponse['message']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Failed to upload image: ${jsonResponse['message']}')),
          );
          await saveImageLocally(imagePath);
        }
      } else {
        print('Failed to upload image: HTTP ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to upload image: Server error (${response.statusCode})')),
        );
        await saveImageLocally(imagePath);
      }
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      await saveImageLocally(imagePath);
    }
  }

  Widget _buildAgreementTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.description, color: Colors.blue, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Learner Agreement',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete all required signatures and initials to generate the agreement document',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Agreement Status Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agreement Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusIndicator('Learner Signature', 'signature'),
                    const SizedBox(height: 12),
                    _buildStatusIndicator(
                        'Learner Initials', 'learner_initials'),
                    const SizedBox(height: 12),
                    _buildStatusIndicator(
                        'Witness Signature', 'witness_signature'),
                    const SizedBox(height: 12),
                    _buildStatusIndicator(
                        'Witness Initials', 'witness_initials'),
                    const SizedBox(height: 16),
                    _buildOverallStatus(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Signatures Display Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Captured Signatures',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSignatureCard(
                              'Learner Signature', 'signature', Colors.blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSignatureCard('Witness Signature',
                              'witness_signature', Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isAgreementComplete()
                                ? _downloadAgreement
                                : null,
                            icon: const Icon(Icons.download),
                            label: const Text('Download Agreement'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isAgreementComplete()
                                  ? Colors.green
                                  : Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openSignaturePad,
                            icon: const Icon(Icons.edit),
                            label: const Text('Capture Signatures'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openInitialsDialog,
                            icon: const Icon(Icons.text_fields),
                            label: const Text('Update Initials'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                isLoading = true;
                              });
                              fetchLearnerDetails();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String title, String field) {
    bool isCompleted = _isFieldCompleted(field);
    return Row(
      children: [
        Icon(
          isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isCompleted ? Colors.green : Colors.grey,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
              color: isCompleted ? Colors.green : Colors.grey[600],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green[100] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isCompleted ? 'Completed' : 'Pending',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isCompleted ? Colors.green[800] : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverallStatus() {
    bool isComplete = _isAgreementComplete();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isComplete ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isComplete ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isComplete ? Icons.check_circle : Icons.warning,
            color: isComplete ? Colors.green : Colors.orange,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isComplete ? 'Agreement Ready' : 'Agreement Incomplete',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isComplete ? Colors.green[800] : Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isComplete
                      ? 'All required signatures and initials have been captured. You can now download the agreement.'
                      : 'Please complete all required signatures and initials to generate the agreement.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isComplete ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureCard(String title, String field, Color color) {
    String? signaturePath = learnerData?[field]?.toString();
    bool hasSignature = signaturePath != null && signaturePath.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: hasSignature ? color : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasSignature ? color : Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasSignature ? Icons.check : Icons.edit,
                  color: hasSignature ? Colors.white : Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasSignature ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 120,
            child: hasSignature
                ? ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    child: Image.network(
                      '${AppConfig.signaturesUrl}/$signaturePath',
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[100],
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error,
                                    color: Colors.grey[600], size: 24),
                                const SizedBox(height: 4),
                                Text(
                                  'Not found',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Container(
                    color: Colors.grey[50],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit, color: Colors.grey[400], size: 32),
                          const SizedBox(height: 4),
                          Text(
                            'No signature',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _isFieldCompleted(String field) {
    if (field == 'signature' || field == 'witness_signature') {
      String? signaturePath = learnerData?[field]?.toString();
      return signaturePath != null && signaturePath.isNotEmpty;
    } else if (field == 'learner_initials' || field == 'witness_initials') {
      String? initials = learnerData?[field]?.toString();
      return initials != null && initials.isNotEmpty;
    }
    return false;
  }

  bool _isAgreementComplete() {
    return _isFieldCompleted('signature') &&
        _isFieldCompleted('learner_initials') &&
        _isFieldCompleted('witness_signature') &&
        _isFieldCompleted('witness_initials');
  }

  Future<void> _downloadAgreement() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading agreement...')),
      );
      await _downloadAndSaveWordDocument();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading agreement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadAndSaveWordDocument() async {
    final downloadUrl =
        '${AppConfig.newAgreementUrl}?LearnerID=${widget.learnerID}';
    try {
      print('Downloading agreement for LearnerID: ${widget.learnerID}');
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        // Attempt to decode as JSON to check for error
        try {
          final jsonResponse = jsonDecode(response.body);
          if (jsonResponse.containsKey('error')) {
            print('Server error: ${jsonResponse['error']}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Error: ${jsonResponse['error']}. Please contact support if this persists.'),
                duration: const Duration(seconds: 5),
              ),
            );
            return;
          }
        } catch (e) {
          // If not JSON (e.g., binary data like .docx), proceed with file handling
          final tempDir = await getTemporaryDirectory();
          final fileName = 'learner_agreement_${widget.learnerID}.docx';
          final tempFilePath = '${tempDir.path}/$fileName';
          final tempFile = File(tempFilePath);
          await tempFile.writeAsBytes(response.bodyBytes);
          print('Agreement downloaded to: $tempFilePath');
          await OpenFile.open(tempFilePath);
        }
      } else {
        print('Failed to download agreement: HTTP ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to download agreement: Server error (${response.statusCode})')),
        );
      }
    } catch (e) {
      print('Error downloading agreement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading agreement: $e')),
      );
    }
  }

  String _updatePlaceholdersInDocument(
      String documentXml, Map<String, String> replacements) {
    var updatedXml = documentXml;
    for (final entry in replacements.entries) {
      updatedXml = updatedXml.replaceAll(entry.key, entry.value);
    }
    return updatedXml;
  }

  int _getNextRelationshipId(String relsXml) {
    final document = xml.XmlDocument.parse(relsXml);
    final relationships = document.findAllElements('Relationship');
    final ids = relationships
        .map((e) =>
            int.tryParse(e.getAttribute('Id')?.replaceAll('rId', '') ?? '0') ??
            0)
        .toList();
    return (ids.isEmpty ? 0 : ids.reduce((a, b) => a > b ? a : b)) + 1;
  }

  String _addRelationship(String relsXml, String relId, String target) {
    final document = xml.XmlDocument.parse(relsXml);
    final relationships = document.findElements('Relationships').first;
    relationships.children.add(
      xml.XmlElement(
        xml.XmlName('Relationship'),
        [
          xml.XmlAttribute(xml.XmlName('Id'), relId),
          xml.XmlAttribute(xml.XmlName('Type'),
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image'),
          xml.XmlAttribute(xml.XmlName('Target'), target),
        ],
      ),
    );
    return document.toXmlString();
  }

  String _replaceSignaturePlaceholder(
      String documentXml, String placeholder, String relId) {
    final document = xml.XmlDocument.parse(documentXml);
    final textNodes = document.findAllElements('w:t');
    for (final node in textNodes) {
      if (node.text.contains(placeholder)) {
        final parent = node.parent;
        if (parent != null) {
          final drawing = xml.XmlElement(
            xml.XmlName('w:drawing'),
            [],
            [
              xml.XmlElement(
                xml.XmlName('wp:inline'),
                [],
                [
                  xml.XmlElement(
                    xml.XmlName('wp:extent'),
                    [
                      xml.XmlAttribute(xml.XmlName('cx'), '914400'),
                      xml.XmlAttribute(xml.XmlName('cy'), '914400'),
                    ],
                  ),
                  xml.XmlElement(
                    xml.XmlName('wp:docPr'),
                    [
                      xml.XmlAttribute(xml.XmlName('id'), '1'),
                      xml.XmlAttribute(xml.XmlName('name'), 'Picture 1'),
                    ],
                  ),
                  xml.XmlElement(
                    xml.XmlName('a:graphic'),
                    [],
                    [
                      xml.XmlElement(
                        xml.XmlName('a:graphicData'),
                        [
                          xml.XmlAttribute(xml.XmlName('uri'),
                              'http://schemas.openxmlformats.org/drawingml/2006/picture')
                        ],
                        [
                          xml.XmlElement(
                            xml.XmlName('pic:pic'),
                            [],
                            [
                              xml.XmlElement(xml.XmlName('pic:nvPicPr')),
                              xml.XmlElement(
                                xml.XmlName('pic:blipFill'),
                                [],
                                [
                                  xml.XmlElement(
                                    xml.XmlName('a:blip'),
                                    [
                                      xml.XmlAttribute(
                                          xml.XmlName('r:embed'), relId)
                                    ],
                                  ),
                                ],
                              ),
                              xml.XmlElement(xml.XmlName('pic:spPr')),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
          parent.children.clear();
          parent.children.add(drawing);
        }
      }
    }
    return document.toXmlString();
  }

  Future<void> _generateAndOpenOfflineAgreement() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final docDir = await getApplicationDocumentsDirectory();
      final templatePath = '${tempDir.path}/Cleaned_Updated_Agreement_V4.docx';
      final templateFile = File(templatePath);

      // Load the template from assets
      if (!await templateFile.exists()) {
        final byteData =
            await rootBundle.load('assets/Cleaned_Updated_Agreement_V4.docx');
        await templateFile.writeAsBytes(byteData.buffer.asUint8List());
      }

      final bytes = await templateFile.readAsBytes();
      final originalArchive = ZipDecoder().decodeBytes(bytes);
      final documentXmlFile = originalArchive.firstWhere(
        (file) => file.name == 'word/document.xml',
        orElse: () => throw 'document.xml not found',
      );
      var documentXml =
          String.fromCharCodes(documentXmlFile.content as List<int>);
      final relsFile = originalArchive.firstWhere(
        (file) => file.name == 'word/_rels/document.xml.rels',
        orElse: () => throw 'document.xml.rels not found',
      );
      var relsXml = String.fromCharCodes(relsFile.content as List<int>);

      final learnerData =
          await DatabaseHelper().fetchLearnerByID(widget.learnerID);
      if (learnerData == null) throw 'Learner data not found';

      final replacements = <String, String>{
        r'${Name}': learnerData['Name']?.toString() ?? 'N/A',
        r'${Surname}': learnerData['Surname']?.toString() ?? 'N/A',
        r'${IDNumber}': learnerData['IDNumber']?.toString() ?? 'N/A',
        r'${PhoneNumber}': learnerData['PhoneNumber']?.toString() ?? 'N/A',
        r'${Date}': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        r'${Project_name}': learnerData['Project_name']?.toString() ?? 'N/A',
        r'${Start_date}': learnerData['Start_date']?.toString() ?? 'N/A',
        r'${End_date}': learnerData['End_date']?.toString() ?? 'N/A',
        r'${sdp_name}': learnerData['sdp_name']?.toString() ?? 'N/A',
        r'${sdp_logo}': learnerData['sdp_logo']?.toString() ?? 'N/A',
        r'${learner_initials}':
            learnerData['learner_initials']?.toString() ?? 'N/A',
        r'${witness_initials}':
            learnerData['witness_initials']?.toString() ?? 'N/A',
        r'${qualification_name}':
            learnerData['qualification_name']?.toString() ?? 'N/A',
        r'${qualification_id}':
            learnerData['qualification_id']?.toString() ?? 'N/A',
        r'${pathway_name}': learnerData['pathway_name']?.toString() ?? 'N/A',
        r'${Project_pathway}':
            learnerData['Project_pathway']?.toString() ?? 'N/A',
      };
      documentXml = _updatePlaceholdersInDocument(documentXml, replacements);

      final newArchive = Archive();
      int nextRelId = _getNextRelationshipId(relsXml);
      final imagePlaceholders = {
        r'${learner_signature}': learnerData['signature']?.toString() ?? 'N/A',
        r'${witness_signature}':
            learnerData['witness_signature']?.toString() ?? 'N/A',
      };

      for (final entry in imagePlaceholders.entries) {
        final placeholder = entry.key;
        var filePath = entry.value;
        if (filePath != 'N/A') {
          final fullImagePath =
              filePath.startsWith('/') ? filePath : '${docDir.path}/$filePath';
          final imageFile = File(fullImagePath);
          if (await imageFile.exists()) {
            final imageBytes = await imageFile.readAsBytes();
            final imageRelId = 'rId$nextRelId';
            final imageName =
                placeholder.replaceAll(r'${', '').replaceAll('}', '');
            newArchive.addFile(ArchiveFile(
                'word/media/$imageName.png', imageBytes.length, imageBytes));
            relsXml =
                _addRelationship(relsXml, imageRelId, 'media/$imageName.png');
            documentXml = _replaceSignaturePlaceholder(
                documentXml, placeholder, imageRelId);
            nextRelId++;
          }
        }
      }

      for (final file in originalArchive) {
        if (file.name == 'word/document.xml') {
          newArchive.addFile(ArchiveFile(
              'word/document.xml', documentXml.length, documentXml.codeUnits));
        } else if (file.name == 'word/_rels/document.xml.rels') {
          newArchive.addFile(ArchiveFile('word/_rels/document.xml.rels',
              relsXml.length, relsXml.codeUnits));
        } else {
          newArchive.addFile(file);
        }
      }

      final updatedDocxBytes = ZipEncoder().encode(newArchive);
      if (updatedDocxBytes == null) throw 'Failed to encode DOCX';
      final updatedDocxPath =
          '${tempDir.path}/Learner_Agreement_${widget.learnerID}.docx';
      final updatedDocxFile = File(updatedDocxPath);
      await updatedDocxFile.writeAsBytes(updatedDocxBytes);

      final uploadDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await DatabaseHelper().saveLearnerDocumentToDatabase(
        widget.learnerID,
        'Learner_Agreement_${widget.learnerID}.docx',
        updatedDocxPath,
        'pending',
        uploadDate,
      );

      final result = await OpenFile.open(updatedDocxPath);
      if (result.type != ResultType.done) {
        throw 'Failed to open file: ${result.message}';
      }
    } catch (e) {
      print('Error generating offline agreement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating agreement: $e')),
      );
    }
  }
}

class FacialRecognitionPage extends StatefulWidget {
  const FacialRecognitionPage({super.key});

  @override
  _FacialRecognitionPageState createState() => _FacialRecognitionPageState();
}

class _FacialRecognitionPageState extends State<FacialRecognitionPage> {
  CameraController? _controller;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.first;
      _controller = CameraController(camera, ResolutionPreset.high);
      await _controller!.initialize();
      setState(() {
        _isCameraReady = true;
      });
    } catch (e) {
      print('Camera initialization failed: $e');
    }
  }

  Future<void> _captureFaceImage() async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        final image = await _controller!.takePicture();
        final bytes = await image.readAsBytes();
        await _sendImageToBackend(bytes);
      } catch (e) {
        print('Error capturing face image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing face image: $e')),
        );
      }
    }
  }

  Future<void> _sendImageToBackend(Uint8List imageBytes) async {
    try {
      final uri = Uri.parse(AppConfig.uploadImageUrl);
      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes('face_image', imageBytes,
            filename: 'face_image.jpg'));
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print('Face image upload response: $responseBody');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        if (jsonResponse['success']) {
          print('Face image uploaded successfully');
        } else {
          print('Face image upload failed: ${jsonResponse['message']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to upload face image: ${jsonResponse['message']}')),
          );
        }
      } else {
        print('Failed to upload face image: HTTP ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to upload face image: Server error (${response.statusCode})')),
        );
      }
    } catch (e) {
      print('Error uploading face image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading face image: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Facial Recognition")),
      body: const Center(
        child: Text('Camera functionality temporarily disabled'),
      ),
    );
  }
}

class CameraPreviewScreen extends StatelessWidget {
  final CameraController cameraController;
  final String learnerID;

  const CameraPreviewScreen({
    super.key,
    required this.cameraController,
    required this.learnerID,
  });

  Future<String?> _takePicture() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final imageFile = await cameraController.takePicture();
      final imagePath = '${tempDir.path}/learner_${learnerID}_photo.jpg';
      await imageFile.saveTo(imagePath);
      return imagePath;
    } catch (e) {
      print('Error taking picture: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(cameraController),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: () async {
                  final imagePath = await _takePicture();
                  Navigator.pop(context, imagePath);
                },
                child: const Icon(Icons.camera_alt),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
