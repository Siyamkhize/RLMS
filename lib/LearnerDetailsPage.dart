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

  // Dropdown field definitions
  final Map<String, List<String>> _dropdownOptions = {
    'Title': ['Mr', 'Mrs', 'Miss', 'Ms', 'Dr', 'Prof'],
    'Gender': ['Male', 'Female', 'Other'],
    'Race': ['African', 'Coloured', 'Indian', 'Asian', 'White', 'Other'],
    'Language': [
      'Afrikaans',
      'English',
      'isiNdebele',
      'isiXhosa',
      'isiZulu',
      'Sepedi',
      'Sesotho',
      'Setswana',
      'siSwati',
      'Tshivenda',
      'Xitsonga'
    ],
    'Disability': [
      'None',
      'Visual Impairment',
      'Hearing Impairment',
      'Physical Disability',
      'Mental Disability',
      'Other'
    ],
  };

  // Required dropdown fields
  final Set<String> _requiredDropdownFields = {
    'Race',
    'Language',
    'Disability'
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 5, vsync: this); // Will be updated after data loads
    _controllers = {};
    fetchLearnerDetails();
    syncLocalData();

    // Add listeners to controllers for real-time dropdown updates
    _setupControllerListeners();
  }

  void _setupControllerListeners() {
    // Add listeners for dropdown fields to update UI when cleared
    for (String field in _dropdownOptions.keys) {
      // Will be set up after controllers are initialized in fetchLearnerDetails
    }
  }

  void _addControllerListeners() {
    // Add listeners to dropdown field controllers for real-time UI updates
    for (String field in _dropdownOptions.keys) {
      if (_controllers[field] != null) {
        _controllers[field]!.addListener(() {
          if (mounted) {
            setState(() {}); // Refresh UI when text changes
          }
        });
      }
    }

    // Add listener to ID number field for automatic age, gender, and DOB calculation
    if (_controllers['IDNumber'] != null) {
      _controllers['IDNumber']!.addListener(() {
        if (mounted) {
          _calculateAndUpdateFromIDNumber();
        }
      });
    }
  }

  // Get database priority value for dropdowns
  String? _getDatabasePriorityValue(String fieldName) {
    // Prioritize database value over controller text
    final dbValue = learnerData?[fieldName]?.toString().trim();
    if (dbValue != null && dbValue.isNotEmpty && dbValue != 'null') {
      return dbValue;
    }
    return null;
  }

  // Check if dropdown should be used
  bool _shouldUseDropdown(String fieldName) {
    // Use dropdown when controller text is empty
    return (_controllers[fieldName]?.text.trim().isEmpty ?? true);
  }

  // Calculate and update age, gender, and DOB when ID number changes
  void _calculateAndUpdateFromIDNumber() {
    final idNumber = _controllers['IDNumber']?.text.trim();

    if (idNumber == null || idNumber.length < 6) {
      // Need at least 6 characters for date calculation
      return;
    }

    try {
      // Calculate values from ID number
      final age = _calculateAgeFromID(idNumber);
      final dob = _calculateDOBFromID(idNumber);

      // Gender requires 10 characters (7th digit)
      final gender =
          idNumber.length >= 10 ? _calculateGenderFromID(idNumber) : null;

      setState(() {
        // Update Age field
        if (age != null) {
          learnerData!['Age'] = age.toString();
          if (_controllers['Age'] != null) {
            _controllers['Age']!.text = age.toString();
          }
        }

        // Update Gender field (only if we have enough digits)
        if (gender != null) {
          learnerData!['Gender'] = gender;
          if (_controllers['Gender'] != null) {
            _controllers['Gender']!.text = gender;
          }
        }

        // Update Date of Birth field (DateOfBirth is visible, DOB is hidden)
        if (dob != null) {
          final dobString =
              '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
          learnerData!['DateOfBirth'] = dobString;
          if (_controllers['DateOfBirth'] != null) {
            _controllers['DateOfBirth']!.text = dobString;
          }
          // Also store in DOB field for database compatibility (but DOB field is hidden from UI)
          learnerData!['DOB'] = dobString;
        }

        // Update minor status
        _isMinor = age != null && age < 18;
      });

      print(
          '[ID_CALC] Auto-calculated from ID $idNumber: Age=$age, Gender=$gender, DOB=$dob, IsMinor=$_isMinor');
    } catch (e) {
      print('[ID_CALC] Error calculating from ID number: $e');
    }
  }

  // Get user-friendly field labels
  String _getFieldLabel(String fieldName) {
    switch (fieldName) {
      case 'AddressLine1':
        return 'Street Name';
      case 'AddressLine2':
        return 'Suburb';
      case 'AddressLine3':
        return 'City/Town';
      case 'PostalCode':
        return 'Postal Code';
      case 'classID':
        return 'Class ID';
      case 'IDNumber':
        return 'ID Number';
      case 'CellphoneNumber':
        return 'Cellphone Number';
      case 'DateOfBirth':
        return 'Date of Birth';
      case 'Title':
        return 'Title';
      case 'Grade':
        return 'School Grade';
      case 'SchoolGrade':
        return 'School Grade';
      case 'EducationLevel':
        return 'Education Level';
      case 'Qualification':
        return 'Qualification';
      case 'SchoolLocation':
        return 'School Location';
      case 'School':
        return 'School';
      case 'Institution':
        return 'Institution';
      default:
        return fieldName;
    }
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

      // Validate month and day
      if (month < 1 || month > 12) {
        print('[GUARDIAN] Invalid month: $month');
        return null;
      }
      if (day < 1 || day > 31) {
        print('[GUARDIAN] Invalid day: $day');
        return null;
      }

      // Determine century (00-24 = 2000s, 25-99 = 1900s)
      final year = yearPrefix <= 24 ? 2000 + yearPrefix : 1900 + yearPrefix;

      // Validate the date can be created
      final birthDate = DateTime(year, month, day);
      final today = DateTime.now();

      // Check if birth date is not in the future
      if (birthDate.isAfter(today)) {
        print('[GUARDIAN] Birth date is in the future: $birthDate');
        return null;
      }

      int age = today.year - birthDate.year;

      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }

      print('[GUARDIAN] Birth date: $birthDate, Age: $age');
      return age;
    } catch (e) {
      print('[GUARDIAN] Error calculating age from ID: $e');
      return null;
    }
  }

  // Calculate gender from South African ID number
  String? _calculateGenderFromID(String? idNumber) {
    if (idNumber == null || idNumber.length < 10) {
      return null;
    }

    try {
      // Gender digit is at position 6 (0-indexed)
      final genderDigit = int.parse(idNumber.substring(6, 7));

      // 0-4 = Female, 5-9 = Male
      return genderDigit < 5 ? 'Female' : 'Male';
    } catch (e) {
      print('[GENDER] Error calculating gender from ID: $e');
      return null;
    }
  }

  // Calculate DOB from ID number
  DateTime? _calculateDOBFromID(String? idNumber) {
    if (idNumber == null || idNumber.length < 6) {
      return null;
    }

    try {
      final yearPrefix = int.parse(idNumber.substring(0, 2));
      final month = int.parse(idNumber.substring(2, 4));
      final day = int.parse(idNumber.substring(4, 6));

      // Validate month and day
      if (month < 1 || month > 12) {
        print('[DOB] Invalid month: $month');
        return null;
      }
      if (day < 1 || day > 31) {
        print('[DOB] Invalid day: $day');
        return null;
      }

      // Determine century (00-24 = 2000s, 25-99 = 1900s)
      final year = yearPrefix <= 24 ? 2000 + yearPrefix : 1900 + yearPrefix;

      final birthDate = DateTime(year, month, day);

      // Check if birth date is not in the future
      if (birthDate.isAfter(DateTime.now())) {
        print('[DOB] Birth date is in the future: $birthDate');
        return null;
      }

      return birthDate;
    } catch (e) {
      print('[DOB] Error calculating DOB from ID: $e');
      return null;
    }
  }

  // Update database field individually
  Future<void> _updateDatabaseField(String fieldName, dynamic value) async {
    try {
      Map<String, dynamic> updateData = {fieldName: value};

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
            print('[UPDATE_FIELD] $fieldName updated successfully online');
          } else {
            print(
                '[UPDATE_FIELD] Failed to update $fieldName online: ${jsonResponse['message']}');
            await DatabaseHelper()
                .updateLearnerLocally(widget.learnerID, updateData);
          }
        } else {
          print(
              '[UPDATE_FIELD] Server error for $fieldName: ${response.statusCode}');
          await DatabaseHelper()
              .updateLearnerLocally(widget.learnerID, updateData);
        }
      } else {
        await DatabaseHelper()
            .updateLearnerLocally(widget.learnerID, updateData);
        print('[UPDATE_FIELD] $fieldName updated locally (offline)');
      }
    } catch (e) {
      print('[UPDATE_FIELD] Error updating $fieldName: $e');
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
              // Set up controller listeners after controllers are initialized
              _addControllerListeners();
              // Perform initial calculations from ID number
              _calculateAndUpdateFromIDNumber();
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
          // Set up controller listeners after controllers are initialized
          _addControllerListeners();
          // Perform initial calculations from ID number
          _calculateAndUpdateFromIDNumber();
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

  // Update Age and Gender based on ID number
  Future<void> _updateAgeRelatedFields() async {
    try {
      final idNumber = learnerData?['IDNumber']?.toString();
      if (idNumber == null || idNumber.length < 6) {
        print('[AGE_UPDATE] ID number not available or invalid: $idNumber');
        return;
      }

      final age = _calculateAgeFromID(idNumber);
      final gender = _calculateGenderFromID(idNumber);

      if (age != null || gender != null) {
        Map<String, dynamic> updateData = {};

        if (age != null) {
          updateData['Age'] = age.toString();
          print('[AGE_UPDATE] Calculated age: $age');
        }

        if (gender != null) {
          updateData['Gender'] = gender;
          print('[AGE_UPDATE] Calculated gender: $gender');
        }

        // Update local data first
        setState(() {
          if (age != null) {
            learnerData!['Age'] = age.toString();
            _controllers['Age']?.text = age.toString();
          }
          if (gender != null) {
            learnerData!['Gender'] = gender;
            _controllers['Gender']?.text = gender;
          }
        });

        // Update database
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
              print('[AGE_UPDATE] Age/Gender updated successfully online');
            } else {
              print(
                  '[AGE_UPDATE] Failed to update online: ${jsonResponse['message']}');
              await DatabaseHelper()
                  .updateLearnerLocally(widget.learnerID, updateData);
            }
          } else {
            print('[AGE_UPDATE] Server error: ${response.statusCode}');
            await DatabaseHelper()
                .updateLearnerLocally(widget.learnerID, updateData);
          }
        } else {
          await DatabaseHelper()
              .updateLearnerLocally(widget.learnerID, updateData);
          print('[AGE_UPDATE] Age/Gender updated locally (offline)');
        }
      }
    } catch (e) {
      print('[AGE_UPDATE] Error updating age/gender: $e');
    }
  }

  // Force update Age and Gender (guaranteed update)
  Future<void> _forceUpdateAgeAndGender() async {
    try {
      final idNumber = learnerData?['IDNumber']?.toString();
      if (idNumber == null || idNumber.length < 6) {
        print('[FORCE_UPDATE] ID number not available: $idNumber');
        return;
      }

      final age = _calculateAgeFromID(idNumber);
      final gender = _calculateGenderFromID(idNumber);

      if (age != null || gender != null) {
        Map<String, dynamic> forceUpdateData = {};

        if (age != null) {
          forceUpdateData['Age'] = age.toString();
        }
        if (gender != null) {
          forceUpdateData['Gender'] = gender;
        }

        print('[FORCE_UPDATE] Force updating Age: $age, Gender: $gender');

        // Update local data first
        setState(() {
          if (age != null) {
            learnerData!['Age'] = age.toString();
            _controllers['Age']?.text = age.toString();
          }
          if (gender != null) {
            learnerData!['Gender'] = gender;
            _controllers['Gender']?.text = gender;
          }
        });

        // Always update database regardless of current values
        bool isConnected = await _checkConnectivity();
        if (isConnected) {
          final response = await http.post(
            Uri.parse(AppConfig.updateLearnerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'LearnerID': widget.learnerID,
              'data': forceUpdateData,
            }),
          );

          if (response.statusCode == 200) {
            print('[FORCE_UPDATE] Force update successful online');
          } else {
            print('[FORCE_UPDATE] Online force update failed, saving locally');
            await DatabaseHelper()
                .updateLearnerLocally(widget.learnerID, forceUpdateData);
          }
        } else {
          await DatabaseHelper()
              .updateLearnerLocally(widget.learnerID, forceUpdateData);
          print('[FORCE_UPDATE] Force update saved locally');
        }
      }
    } catch (e) {
      print('[FORCE_UPDATE] Error in force update: $e');
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

      // Always update Age and Gender if calculable from ID number
      await _updateAgeRelatedFields();
      await _forceUpdateAgeAndGender();

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
              // Update local learnerData map with the new values
              setState(() {
                updateData.forEach((key, value) {
                  learnerData![key] = value;
                });
              });
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
          // Update local learnerData map with the new values
          setState(() {
            updateData.forEach((key, value) {
              learnerData![key] = value;
            });
          });
        }
      }
    } catch (e) {
      print('Error updating learner information: $e');
      rethrow;
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data updated successfully')),
      );
    } catch (e) {
      print('Error updating data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating data: $e')),
      );
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
    if (learnerData == null || learnerData!.isEmpty) {
      return const Center(child: Text('No learner data available'));
    }

    // Create custom field ordering and filter out unwanted fields
    final allEntries = learnerData!.entries.toList();

    // Fields to hide
    final hiddenFields = {'DOB'};

    // Define field order - school grade below school location, classID below school grade
    final fieldOrder = [
      'LearnerID',
      'Title', // Title goes below Learner ID
      'Name',
      'Surname',
      'IDNumber',
      'Age',
      'Gender',
      'DateOfBirth', // DateOfBirth field (DOB is hidden)
      'Race',
      'Language',
      'Disability',
      'CellphoneNumber', // Phone number above email
      'Email',
      'AddressLine1', // Street Name
      'AddressLine2', // Suburb
      'AddressLine3', // City/Town
      'PostalCode', // Postal Code
      'SchoolLocation', // School location (if it exists)
      'School', // Alternative school field name
      'Institution', // Institution field
      'Grade', // School grade below school location
      'SchoolGrade', // Alternative school grade field name
      'EducationLevel', // Education level field
      'Qualification', // Qualification field
      'classID', // classID comes after school grade
    ];

    // Create ordered entries list
    final orderedEntries = <MapEntry<String, dynamic>>[];

    // First add fields in the specified order
    for (final fieldName in fieldOrder) {
      final entry = allEntries
          .where((e) => e.key == fieldName)
          .firstWhere((e) => true, orElse: () => const MapEntry('', null));
      if (entry.key.isNotEmpty && !hiddenFields.contains(entry.key)) {
        orderedEntries.add(entry);
      }
    }

    // Then add any remaining fields that weren't in the order list
    for (final entry in allEntries) {
      if (!fieldOrder.contains(entry.key) &&
          !hiddenFields.contains(entry.key)) {
        orderedEntries.add(entry);
      }
    }

    final entries = orderedEntries;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Image Section
          Center(
            child: _buildProfileImage(),
          ),
          const SizedBox(height: 20),

          // Age Display
          _buildAgeDisplay(),
          const SizedBox(height: 20),

          // Bank Details (if available)
          if (bankDetails != null) ...[
            _buildBankDetails(),
            const SizedBox(height: 20),
          ],

          // Learner Data Fields
          _buildDataList(entries),

          const SizedBox(height: 20),

          // Update Button
          Center(
            child: ElevatedButton.icon(
              onPressed: _updateData,
              icon: const Icon(Icons.save),
              label: const Text('Update Data'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    // Check for profile image in learner data
    String? imagePath = learnerData?['profile_image']?.toString();

    if (imagePath != null && imagePath.isNotEmpty && imagePath != 'null') {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[300]!, width: 2),
        ),
        child: ClipOval(
          child: Image.network(
            '${AppConfig.learnerImagesUrl}/$imagePath',
            fit: BoxFit.cover,
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
              return _buildDefaultImage();
            },
          ),
        ),
      );
    }

    // Check for captured image
    if (capturedImage != null) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[300]!, width: 2),
        ),
        child: ClipOval(
          child: Image.file(
            File(capturedImage!.path),
            fit: BoxFit.cover,
          ),
        ),
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

    // First try to get age from the Age field in learnerData
    if (learnerData!['Age'] != null) {
      age = int.tryParse(learnerData!['Age'].toString());
    }

    // If Age field doesn't exist or is invalid, calculate from ID number
    age ??= _calculateAgeFromID(learnerData!['IDNumber']);

    return Card(
      elevation: 3,
      color: age != null && age < 18 ? Colors.orange[50] : Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
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
      'Age', // Age is calculated from ID, so read-only in UI
      'DateOfBirth', // DateOfBirth is calculated from ID, so read-only in UI
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((entry) {
        // Skip profile_image from display (it's shown separately)
        if (entry.key == 'profile_image') return const SizedBox.shrink();

        // Check if this field should be read-only
        final bool isReadOnly = readOnlyFields.contains(entry.key);
        final bool isDropdownField = _dropdownOptions.containsKey(entry.key);
        final bool shouldUseDropdown =
            isDropdownField && _shouldUseDropdown(entry.key);
        final bool isRequired = _requiredDropdownFields.contains(entry.key);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Card(
            elevation: 2,
            color: isReadOnly ? Colors.grey[200] : null,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getFieldLabel(entry.key),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isRequired) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Required',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (isReadOnly) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.lock,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'System',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8.0),

                  // Show dropdown or text field based on conditions
                  if (shouldUseDropdown) ...[
                    // Dropdown widget
                    DropdownButtonFormField<String>(
                      value: null, // Always start with null for empty dropdowns
                      decoration: InputDecoration(
                        labelText: _getFieldLabel(entry.key),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 8.0,
                        ),
                        isDense: true,
                        hintText: 'Select ${_getFieldLabel(entry.key)}',
                        suffixIcon: isRequired
                            ? const Icon(Icons.star,
                                color: Colors.red, size: 16)
                            : null,
                      ),
                      items: _dropdownOptions[entry.key]!.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _controllers[entry.key]!.text = newValue;
                            learnerData![entry.key] = newValue;
                          });
                        }
                      },
                      validator: isRequired
                          ? (value) {
                              if (value == null || value.isEmpty) {
                                return '${_getFieldLabel(entry.key)} is required';
                              }
                              return null;
                            }
                          : null,
                    ),
                  ] else ...[
                    // Regular text field
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _controllers[entry.key],
                            enabled: !isReadOnly,
                            readOnly: isReadOnly,
                            maxLines: isReadOnly &&
                                    (entry.value?.toString().length ?? 0) > 50
                                ? 3
                                : 1,
                            decoration: InputDecoration(
                              labelText: _getFieldLabel(entry.key),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                                horizontal: 8.0,
                              ),
                              isDense: true,
                              filled: isReadOnly,
                              fillColor: isReadOnly ? Colors.grey[100] : null,
                              helperText:
                                  isReadOnly ? 'System-managed field' : null,
                              helperStyle: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                              suffixIcon: isRequired
                                  ? const Icon(Icons.star,
                                      color: Colors.red, size: 16)
                                  : null,
                            ),
                            style: TextStyle(
                              color:
                                  isReadOnly ? Colors.grey[700] : Colors.black,
                              fontSize: isReadOnly ? 12 : 14,
                            ),
                            validator: isRequired
                                ? (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return '${_getFieldLabel(entry.key)} is required';
                                    }
                                    return null;
                                  }
                                : null,
                          ),
                        ),
                        // Clear button for dropdown fields when they have content
                        if (isDropdownField &&
                            !_shouldUseDropdown(entry.key)) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              setState(() {
                                _controllers[entry.key]!.clear();
                              });
                            },
                            tooltip: 'Clear to show dropdown',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  // Helper text for dropdown fields
                  if (isDropdownField && shouldUseDropdown) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Select from dropdown or type to search',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
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
                  ],
                ),
              ),
            ),
          ],
        ),
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

  Future<void> saveImageLocally(String imagePath) async {
    try {
      await DatabaseHelper().saveImageLocally(widget.learnerID, imagePath);
      print('Image saved locally for learner_id: ${widget.learnerID}');
    } catch (e) {
      print('Error saving image locally: $e');
    }
  }
}

// Camera Preview Screen for image capture
class CameraPreviewScreen extends StatefulWidget {
  final CameraController cameraController;
  final String learnerID;

  const CameraPreviewScreen({
    super.key,
    required this.cameraController,
    required this.learnerID,
  });

  @override
  _CameraPreviewScreenState createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Photo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          CameraPreview(widget.cameraController),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: _capturePhoto,
                backgroundColor: Colors.white,
                child: const Icon(Icons.camera_alt, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _capturePhoto() async {
    try {
      final image = await widget.cameraController.takePicture();
      Navigator.pop(context, image.path);
    } catch (e) {
      print('Error capturing photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing photo: $e')),
      );
    }
  }
}
