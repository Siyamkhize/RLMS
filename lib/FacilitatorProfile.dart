import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:signature/signature.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'database_helper.dart';
import 'facilitator_fingerprint_page.dart';

import 'config.dart';
/// Configuration class for app constants.
class Config {
  static String get baseUrl => AppConfig.baseUrl; // Use AppConfig for consistent URL management
}

/// FacilitatorProfile screen to display and edit facilitator details.
class FacilitatorProfile extends StatefulWidget {
  final String classID;

  const FacilitatorProfile({Key? key, required this.classID}) : super(key: key);

  @override
  _FacilitatorProfileState createState() => _FacilitatorProfileState();
}

class _FacilitatorProfileState extends State<FacilitatorProfile> {
  late Future<Map<String, dynamic>> facilitatorData;
  String? profileImagePath;
  String? onlineProfileImageUrl;
  String? signaturePath;
  String? onlineSignatureUrl;
  bool isEditing = false;
  bool isImageLoading = false;
  bool isSignatureLoading = false;
  bool _isSignatureFileValid = false;
  bool _isProfileImageValid = false;
  int? _facilitatorId; // Store facilitator ID for fingerprint management

// Controllers for editable fields
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _assessorController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _assessorExpiryController = TextEditingController();

// Signature controller
  SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

// Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    facilitatorData = _fetchFacilitatorData();
    _loadOnlineProfileImage();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _assessorController.dispose();
    _idNumberController.dispose();
    _assessorExpiryController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  /// Validates a South African phone number.
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    String cleanNumber = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleanNumber.startsWith('+27')) {
      cleanNumber = '0${cleanNumber.substring(3)}';
    } else if (cleanNumber.startsWith('27') && cleanNumber.length == 11) {
      cleanNumber = '0${cleanNumber.substring(2)}';
    }
    final mobilePattern = RegExp(r'^0[6-8][0-9]{8}$');
    final landlinePattern = RegExp(r'^0[1-5][0-9]{7,8}$');
    if (!mobilePattern.hasMatch(cleanNumber) && !landlinePattern.hasMatch(cleanNumber)) {
      return 'Enter valid SA number:\nMobile: 082 123 4567\nLandline: 011 555 1234';
    }
    return null;
  }

  /// Validates a South African ID number.
  String? _validateIdNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'ID number is required';
    }
    if (value.length != 13) return 'SA ID must be exactly 13 digits';
    if (!RegExp(r'^\d{13}$').hasMatch(value)) return 'ID number must contain only digits';
    int year = int.parse(value.substring(0, 2));
    int month = int.parse(value.substring(2, 4));
    int day = int.parse(value.substring(4, 6));
    int fullYear = year <= 21 ? 2000 + year : 1900 + year;
    if (month < 1 || month > 12) return 'Invalid month in ID number';
    if (day < 1 || day > 31) return 'Invalid day in ID number';
    List<int> daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && (fullYear % 4 == 0 && fullYear % 100 != 0 || fullYear % 400 == 0)) {
      daysInMonth[1] = 29;
    }
    if (day > daysInMonth[month - 1]) return 'Invalid date in ID number';
    int sum = 0;
    for (int i = 0; i < 12; i += 2) {
      sum += int.parse(value[i]);
    }
    String evenDigits = '';
    for (int i = 1; i < 12; i += 2) {
      evenDigits += value[i];
    }
    int evenSum = int.parse(evenDigits) * 2;
    String evenSumStr = evenSum.toString();
    for (int i = 0; i < evenSumStr.length; i++) {
      sum += int.parse(evenSumStr[i]);
    }
    int checkDigit = (10 - (sum % 10)) % 10;
    if (checkDigit != int.parse(value[12])) return 'Invalid SA ID number checksum';
    return null;
  }

  /// Validates an assessor number (6-10 alphanumeric characters).
  String? _validateAssessorNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Assessor number is required';
    }
    if (!RegExp(r'^[A-Z0-9]{6,10}$').hasMatch(value)) {
      return 'Assessor number must be 6-10 alphanumeric characters';
    }
    return null;
  }

  /// Validates assessor certificate expiry date.
  String? _validateAssessorExpiryDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Assessor certificate expiry date is required';
    }
    
    try {
      final parts = value.split('/');
      if (parts.length != 3) return 'Please select a valid date';
      
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      
      // Basic date validation
      if (day < 1 || day > 31) return 'Invalid day';
      if (month < 1 || month > 12) return 'Invalid month';
      if (year < 2020 || year > 2050) return 'Year must be between 2020 and 2050';
      
      // Create date and validate it's a real date
      final date = DateTime(year, month, day);
      if (date.day != day || date.month != month || date.year != year) {
        return 'Invalid date selected';
      }
      
      // Check if expired (validation error)
      final now = DateTime.now();
      if (date.isBefore(DateTime(now.year, now.month, now.day))) {
        return 'Certificate has expired. Please renew your assessor certificate.';
      }
      
      return null; // Valid date
    } catch (e) {
      return 'Please select a valid date';
    }
  }

  /// Loads assessor expiry date from server if missing locally.
  Future<void> _loadAssessorExpiryFromServer(Map<String, dynamic> localData) async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        final response = await http.get(
          Uri.parse('${Config.baseUrl}/get_facilitator_profile.php?classID=${widget.classID}'),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] && data['data'] != null) {
            final serverExpiryDate = data['data']['assessorExpiryDate'];
            if (serverExpiryDate != null && serverExpiryDate.toString().isNotEmpty) {
              // Update the local data map with server data
              localData['assessorExpiryDate'] = serverExpiryDate.toString();
            }
          }
        }
      } catch (e) {
        // Silently handle server connection errors
      }
    }
  }

  /// Loads profile image and signature from the server.
  // Future<void> _loadOnlineProfileImage() async {
  //   var connectivityResult = await Connectivity().checkConnectivity();
  //   if (connectivityResult != ConnectivityResult.none) {
  //     try {
  //       final response = await http.get(
  //         Uri.parse('${Config.baseUrl}/get_facilitator_profile.php?classID=${widget.classID}'),
  //       );
  //       if (response.statusCode == 200) {
  //         final data = json.decode(response.body);
  //         if (data['success']) {
  //           setState(() {
  //             onlineProfileImageUrl = data['profile_url'] != null ? '${Config.baseUrl}/${data['profile_url']}' : null;
  //             onlineSignatureUrl = data['signature_url'] != null ? '${Config.baseUrl}/${data['signature_url']}' : null;
  //           });
  //         }
  //       }
  //     } catch (e) {
  //       debugPrint('Failed to load online profile data: $e');
  //     }
  //   }
  // }
  Future<void> _loadOnlineProfileImage() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        final response = await http.get(
          Uri.parse('${Config.baseUrl}/get_facilitator_profile.php?classID=${widget.classID}'),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success']) {
            setState(() {
              // Use the URLs directly from the response, as they are already full URLs
              onlineProfileImageUrl = data['profile_url'];
              onlineSignatureUrl = data['signature_url'];
            });
          }
        }
      } catch (e) {
        // Silently handle network errors
      }
    }
  }

  /// Fetches facilitator data from local database with offline fallback.
  Future<Map<String, dynamic>> _fetchFacilitatorData() async {
    try {
      final data = await DatabaseHelper().getFacilitatorDetailsByClassID(widget.classID);
      
      // If local database doesn't have assessorExpiryDate, try to get it from server
      if (data['assessorExpiryDate'] == null || data['assessorExpiryDate'].toString().isEmpty) {
        await _loadAssessorExpiryFromServer(data);
      }
      
      String? storedImagePath = await DatabaseHelper().getFacilitatorProfileImage(widget.classID);
      String? storedSignaturePath = await DatabaseHelper().getFacilitatorSignature(widget.classID);
      setState(() {
        profileImagePath = storedImagePath;
        signaturePath = storedSignaturePath;
        _isProfileImageValid = storedImagePath != null && File(storedImagePath).existsSync();
        _isSignatureFileValid = storedSignaturePath != null && File(storedSignaturePath).existsSync();
        _phoneController.text = data['phoneNumber']?.toString() ?? '';
        _assessorController.text = data['assessorNo']?.toString() ?? '';
        _idNumberController.text = data['f_IDNumber']?.toString() ?? '';
        _assessorExpiryController.text = data['assessorExpiryDate']?.toString() ?? '';
      });
      return data;
    } catch (e) {
      final offlineData = await DatabaseHelper().getFacilitatorDetailsByClassID(widget.classID);
      if (offlineData.isNotEmpty) return offlineData;
      throw 'No data available offline';
    }
  }

  /// Shows bottom sheet for image source selection.
  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Picks and saves an image from the specified source.
  Future<void> _getImage(ImageSource source) async {
    setState(() => isImageLoading = true);
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (image != null) {
      final directory = await getApplicationDocumentsDirectory();
      final imageDirectory = Directory('${directory.path}/profile_images');
      if (!await imageDirectory.exists()) await imageDirectory.create(recursive: true);
      final imagePath = '${imageDirectory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await image.saveTo(imagePath);
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      setState(() {
        profileImagePath = imagePath;
        onlineProfileImageUrl = null;
        _isProfileImageValid = true;
      });
      await DatabaseHelper().updateFacilitatorProfileImage(widget.classID, base64Image);
      await _syncProfileImageOnline();
    }
    setState(() => isImageLoading = false);
  }

  /// Shows a responsive signature pad dialog with customizable stroke width.
  Future<void> _showSignaturePad() async {
    double strokeWidth = _signatureController.penStrokeWidth;
    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add Signature'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: size.width * 0.8,
                      height: size.height * 0.3,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('Pen Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                    Slider(
                      value: strokeWidth,
                      min: 1.0,
                      max: 5.0,
                      divisions: 4,
                      label: strokeWidth.toStringAsFixed(1),
                      onChanged: (value) {
                        setDialogState(() {
                          strokeWidth = value;
                          final points = _signatureController.points; // Preserve current signature
                          _signatureController = SignatureController(
                            penStrokeWidth: strokeWidth,
                            penColor: Colors.black,
                            exportBackgroundColor: Colors.white,
                            points: points,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => _signatureController.clear(),
                  child: Text('Clear'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_signatureController.isNotEmpty) {
                      await _saveSignature();
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please provide a signature'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Saves the signature to local storage and syncs online.
  Future<void> _saveSignature() async {
    if (_signatureController.isNotEmpty) {
      setState(() => isSignatureLoading = true);
      final data = await _signatureController.toPngBytes();
      if (data != null) {
        final directory = await getApplicationDocumentsDirectory();
        final signatureDirectory = Directory('${directory.path}/signatures');
        if (!await signatureDirectory.exists()) await signatureDirectory.create(recursive: true);
        final signaturePath = '${signatureDirectory.path}/${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(signaturePath);
        await file.writeAsBytes(data);
        final base64Signature = base64Encode(data);
        setState(() {
          this.signaturePath = signaturePath;
          onlineSignatureUrl = null;
          _isSignatureFileValid = true;
        });
        await DatabaseHelper().updateFacilitatorSignature(widget.classID, base64Signature);
        await _syncDataOnline();
      }
      setState(() => isSignatureLoading = false);
    }
  }

  /// Saves form changes locally and syncs online.
  Future<void> _saveChanges() async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Saving changes...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );

      if (!_formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fix validation errors'), backgroundColor: Colors.red),
        );
        return;
      }
      
      final updatedData = {
        'phoneNumber': _phoneController.text,
        'assessorNo': _assessorController.text,
        'f_IDNumber': _idNumberController.text,
        'assessorExpiryDate': _assessorExpiryController.text,
      };
      
      // Save to local database
      await DatabaseHelper().updateFacilitatorDetails(widget.classID, updatedData);
      
      // Sync to server
      await _syncDataOnline();
      
      // Update UI
      setState(() {
        isEditing = false;
        facilitatorData = _fetchFacilitatorData();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Changes saved successfully'), backgroundColor: Colors.green),
      );
    } catch (e, stackTrace) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving changes: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  /// Syncs profile image to the server using multipart request.
  Future<void> _syncProfileImageOnline() async {
    if (profileImagePath == null || !await Connectivity().checkConnectivity().then((r) => r != ConnectivityResult.none)) {
      return;
    }
    int maxRetries = 3;
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${Config.baseUrl}/save_facilitator_profile.php'),
        );
        request.fields['classID'] = widget.classID;
        request.files.add(await http.MultipartFile.fromPath('f_profile', profileImagePath!));
        var response = await request.send();
        var responseData = await http.Response.fromStream(response);
        if (response.statusCode == 200) {
          final data = json.decode(responseData.body);
          if (data['success']) {
            setState(() {
              onlineProfileImageUrl = data['image_url'] != null ? '${Config.baseUrl}/${data['image_url']}' : null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Profile image uploaded successfully'), backgroundColor: Colors.green),
            );
            return;
          }
          throw Exception(data['message']);
        }
        throw Exception('Server returned ${response.statusCode}');
      } catch (e) {
        attempt++;
        if (attempt == maxRetries) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload profile image: $e'), backgroundColor: Colors.red),
          );
        }
        await Future.delayed(Duration(seconds: 2));
      }
    }
  }

  /// Syncs facilitator data to the server with retry mechanism.
  Future<void> _syncDataOnline() async {
    if (!await Connectivity().checkConnectivity().then((r) => r != ConnectivityResult.none)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No internet connection'), backgroundColor: Colors.orange),
      );
      return;
    }
    int maxRetries = 3;
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        final data = await DatabaseHelper().getFacilitatorDetailsByClassID(widget.classID);
        
        final apiData = {
          'classID': widget.classID,
          'firstName': data['firstName'],
          'lastName': data['lastName'],
          'email': data['email'],
          'phoneNumber': _phoneController.text,
          'f_IDNumber': _idNumberController.text,
          'assessorNo': _assessorController.text,
          'assessorExpiryDate': _assessorExpiryController.text,
          'f_signature': signaturePath != null ? await _imageToBase64(signaturePath!) : null,
        };
        
        final response = await http.post(
          Uri.parse('${Config.baseUrl}/save_facilitator.php'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(apiData),
        );
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Data synced successfully'), backgroundColor: Colors.green),
            );
            return;
          }
          throw Exception(responseData['message']);
        }
        throw Exception('Server returned ${response.statusCode}');
      } catch (e) {
        attempt++;
        if (attempt == maxRetries) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to sync data: $e'), backgroundColor: Colors.red),
          );
        }
        await Future.delayed(Duration(seconds: 2));
      }
    }
  }

  /// Converts an image to Base64 string.
  Future<String?> _imageToBase64(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      return null;
    }
  }

  /// Formats the assessor expiry date for display with status indication.
  String _formatExpiryDateForDisplay(String? expiryDate) {
    if (expiryDate == null || expiryDate.isEmpty) {
      return 'Not Set';
    }
    
    try {
      final parts = expiryDate.split('/');
      if (parts.length != 3) return expiryDate;
      
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final date = DateTime(year, month, day);
      final now = DateTime.now();
      
      // Check if expired
      if (date.isBefore(DateTime(now.year, now.month, now.day))) {
        return '$expiryDate\n(EXPIRED)';
      }
      
      // Check if expiring soon (within 30 days)
      final daysUntilExpiry = date.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (daysUntilExpiry <= 30) {
        return '$expiryDate\n(${daysUntilExpiry} days left)';
      }
      
      return expiryDate;
    } catch (e) {
      return expiryDate;
    }
  }

  /// Builds the profile image widget.
  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          Container(
            width: 140,
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(70),
              child: _getProfileImageWidget(),
            ),
          ),
          if (isImageLoading)
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(70),
              ),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the appropriate profile image widget.
  Widget _getProfileImageWidget() {
    if (_isProfileImageValid) {
      return Image.file(File(profileImagePath!), fit: BoxFit.cover, width: 140, height: 140);
    } else if (onlineProfileImageUrl != null) {
      return CachedNetworkImage(
        imageUrl: onlineProfileImageUrl!,
        fit: BoxFit.cover,
        width: 140,
        height: 140,
        placeholder: (context, url) => Container(
          width: 140,
          height: 140,
          color: Colors.grey[300],
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          width: 140,
          height: 140,
          color: Colors.grey[300],
          child: Icon(Icons.person, size: 60, color: Colors.white),
        ),
      );
    }
    return Container(
      width: 140,
      height: 140,
      color: Colors.grey[300],
      child: Icon(Icons.camera_alt, size: 40, color: Colors.white),
    );
  }

  /// Returns the appropriate signature widget.
  Widget _getSignatureWidget() {
    if (_isSignatureFileValid) {
      return Container(
        constraints: BoxConstraints(maxHeight: 150, minHeight: 80),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(signaturePath!), fit: BoxFit.contain, width: double.infinity),
        ),
      );
    } else if (onlineSignatureUrl != null) {
      return Container(
        constraints: BoxConstraints(maxHeight: 150, minHeight: 80),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: onlineSignatureUrl!,
            fit: BoxFit.contain,
            width: double.infinity,
            placeholder: (context, url) => Container(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              height: 100,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 30, color: Colors.red.shade400),
                    SizedBox(height: 8),
                    Text('Failed to load signature', style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.draw, size: 30, color: Colors.grey.shade400),
            SizedBox(height: 8),
            Text(
              'No signature added yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF7EC8E3),
        title: Text("Facilitator Profile"),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            onPressed: isEditing 
                ? () {
                    _saveChanges();
                  }
                : () {
                    debugPrint('[PROFILE] Edit button pressed');
                    setState(() => isEditing = true);
                  },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _loadOnlineProfileImage();
              setState(() => facilitatorData = _fetchFacilitatorData());
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: facilitatorData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            var data = snapshot.data!;
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProfileImage(),
                    SizedBox(height: 16),
                    Text(
                      data['fullName'] ?? 'N/A',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Email: ${data['email'] ?? 'N/A'}',
                      style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 20),
                    Divider(thickness: 2, color: Colors.lightBlueAccent),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildInfoCard('Class Name', data['className'] ?? 'N/A'),
                        _buildInfoCard('Role', data['role'] ?? 'N/A'),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildInfoCard('Assessor Number', data['assessorNo'] ?? 'N/A'),
                        _buildExpiryInfoCard('Certificate Expiry', data['assessorExpiryDate']),
                      ],
                    ),
                    SizedBox(height: 20),
                    _buildEditableSection('Contact Information', [
                      _buildEditableField(
                        'Phone Number',
                        _phoneController,
                        Icons.phone,
                        validator: _validatePhoneNumber,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-\(\)\+]')),
                          LengthLimitingTextInputFormatter(15),
                        ],
                        hintText: '082 123 4567 or 011 555 1234',
                      ),
                      _buildEditableField(
                        'ID Number',
                        _idNumberController,
                        Icons.badge,
                        validator: _validateIdNumber,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(13),
                        ],
                        hintText: '13-digit SA ID number',
                      ),
                      _buildEditableField(
                        'Assessor Number',
                        _assessorController,
                        Icons.assignment_ind,
                        validator: _validateAssessorNumber,
                        hintText: 'AS123456',
                      ),
                      _buildDatePickerField(
                        'Assessor Certificate Expiry Date',
                        _assessorExpiryController,
                        validator: _validateAssessorExpiryDate,
                      ),
                    ]),
                    SizedBox(height: 20),
                    _buildFingerprintSection(data),
                    SizedBox(height: 20),
                    _buildSignatureSection(),
                  ],
                ),
              ),
            );
          }
          return Center(child: Text('No data available'));
        },
      ),
    );
  }
  
  /// Builds the fingerprint management section
  Widget _buildFingerprintSection(Map<String, dynamic> data) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getFacilitatorIdByClassID(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        
        final facilitatorData = snapshot.data;
        final facilitatorId = facilitatorData?['facilitator_id'] as int?;
        final fullName = facilitatorData?['fullName'] as String?;
        
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Fingerprint Security',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: facilitatorId != null 
                            ? () => _navigateToFingerprintPage(facilitatorId, fullName ?? 'Facilitator')
                            : null,
                        icon: Icon(Icons.fingerprint, size: 18),
                        label: Text(
                          'Manage',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size(0, 36),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (facilitatorId != null)
                  FutureBuilder<bool>(
                    future: DatabaseHelper().facilitatorHasFingerprints(facilitatorId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      
                      final hasFingerprints = snapshot.data ?? false;
                      
                      return Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: hasFingerprints ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hasFingerprints ? Colors.green : Colors.orange,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              hasFingerprints ? Icons.check_circle : Icons.warning,
                              color: hasFingerprints ? Colors.green : Colors.orange,
                              size: 32,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hasFingerprints ? 'Fingerprints Enrolled' : 'No Fingerprints Enrolled',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: hasFingerprints ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    hasFingerprints 
                                        ? 'Your fingerprints are enrolled. Tap "Manage" to update or clock in/out.'
                                        : 'Enroll your fingerprints for secure clock-in/out and quick access.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Fingerprint features not available',
                        style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// Get facilitator ID by classID (the old way)
  Future<Map<String, dynamic>> _getFacilitatorIdByClassID() async {
    try {
      final db = await DatabaseHelper().database;
      final result = await db.query(
        'facilitator',
        where: 'classID = ?',
        whereArgs: [widget.classID],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        final facilitator = result.first;
        final facilitatorId = facilitator['facilitator_id'] as int?;
        final firstName = facilitator['firstName']?.toString() ?? '';
        final lastName = facilitator['lastName']?.toString() ?? '';
        final fullName = '$firstName $lastName'.trim();
        
        return {
          'facilitator_id': facilitatorId,
          'fullName': fullName.isNotEmpty ? fullName : 'Facilitator',
        };
      }
      
      return {};
    } catch (e) {
      debugPrint('[PROFILE] Error getting facilitator by classID: $e');
      return {};
    }
  }
  
  /// Navigate to fingerprint management page
  void _navigateToFingerprintPage(int facilitatorId, String facilitatorName) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilitatorFingerprintPage(
          facilitatorId: facilitatorId,
          facilitatorName: facilitatorName,
          isFirstTimeSetup: false,
          requireClockIn: false,
        ),
      ),
    );
    
    // Refresh the profile data after returning
    if (result == true && mounted) {
      setState(() {
        facilitatorData = _fetchFacilitatorData();
      });
    }
  }

  /// Builds an info card for displaying key-value pairs.
  Widget _buildInfoCard(String title, String content) {
    return Container(
      width: 150,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 2, blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
          SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(fontSize: 14, color: Colors.black),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Builds a specialized info card for assessor certificate expiry with status colors.
  Widget _buildExpiryInfoCard(String title, String? expiryDate) {
    debugPrint('[PROFILE] _buildExpiryInfoCard called with: "$expiryDate"');
    
    Color cardColor = Colors.white;
    Color textColor = Colors.black;
    Color titleColor = Colors.blueAccent;
    String displayText = 'Not Set';
    String statusText = '';
    
    if (expiryDate != null && expiryDate.isNotEmpty) {
      try {
        final parts = expiryDate.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          final date = DateTime(year, month, day);
          final now = DateTime.now();
          
          displayText = expiryDate;
          
          // Check if expired
          if (date.isBefore(DateTime(now.year, now.month, now.day))) {
            cardColor = Colors.red.shade50;
            textColor = Colors.red.shade700;
            titleColor = Colors.red.shade600;
            statusText = 'EXPIRED';
          }
          // Check if expiring soon (within 30 days)
          else {
            final daysUntilExpiry = date.difference(DateTime(now.year, now.month, now.day)).inDays;
            if (daysUntilExpiry <= 30) {
              cardColor = Colors.orange.shade50;
              textColor = Colors.orange.shade700;
              titleColor = Colors.orange.shade600;
              statusText = '$daysUntilExpiry days left';
            } else {
              cardColor = Colors.green.shade50;
              textColor = Colors.green.shade700;
              titleColor = Colors.green.shade600;
              statusText = 'Valid';
            }
          }
        }
      } catch (e) {
        displayText = expiryDate;
      }
    }
    
    return Container(
      width: 150,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 2, blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
          ),
          SizedBox(height: 8),
          Text(
            displayText,
            style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (statusText.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 12, 
                color: textColor, 
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds a section for editable fields.
  Widget _buildEditableSection(String title, List<Widget> fields) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            SizedBox(height: 16),
            ...fields,
          ],
        ),
      ),
    );
  }

  /// Builds an editable text field with validation.
  Widget _buildEditableField(
      String label,
      TextEditingController controller,
      IconData icon, {
        String? Function(String?)? validator,
        TextInputType? keyboardType,
        List<TextInputFormatter>? inputFormatters,
        String? hintText,
      }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: isEditing,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blueAccent),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.red),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          filled: !isEditing,
          fillColor: isEditing ? null : Colors.grey.shade50,
          errorMaxLines: 2,
        ),
      ),
    );
  }

  /// Builds a date picker field for assessor certificate expiry date.
  Widget _buildDatePickerField(
      String label,
      TextEditingController controller, {
        String? Function(String?)? validator,
      }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: isEditing,
        validator: validator,
        readOnly: true,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onTap: isEditing ? () => _selectDate(context, controller) : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Tap to select date',
          prefixIcon: Icon(Icons.calendar_today, color: Colors.blueAccent),
          suffixIcon: isEditing ? Icon(Icons.arrow_drop_down, color: Colors.blueAccent) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blueAccent),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.red),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          filled: !isEditing,
          fillColor: isEditing ? null : Colors.grey.shade50,
          errorMaxLines: 2,
        ),
      ),
    );
  }

  /// Shows date picker and updates the controller with selected date.
  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    // Parse existing date if available
    DateTime? initialDate;
    if (controller.text.isNotEmpty) {
      try {
        final parts = controller.text.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          initialDate = DateTime(year, month, day);
        }
      } catch (e) {
        // If parsing fails, use current date
        initialDate = DateTime.now();
      }
    } else {
      // Default to current date
      initialDate = DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
      helpText: 'Select Assessor Certificate Expiry Date',
      cancelText: 'Cancel',
      confirmText: 'Select',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Format date as DD/MM/YYYY
      final formattedDate = '${picked.day.toString().padLeft(2, '0')}/'
          '${picked.month.toString().padLeft(2, '0')}/'
          '${picked.year}';
      controller.text = formattedDate;
      
      // Show warning if certificate is expired or expiring soon
      final now = DateTime.now();
      final daysUntilExpiry = picked.difference(now).inDays;
      
      if (daysUntilExpiry < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Certificate has expired! Please renew your assessor certificate.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      } else if (daysUntilExpiry <= 30) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Certificate expires in $daysUntilExpiry days. Consider renewing soon.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Builds the digital signature section.
  Widget _buildSignatureSection() {
    bool hasSignature = _isSignatureFileValid || onlineSignatureUrl != null;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Digital Signature',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: _showSignaturePad,
                    icon: Icon(Icons.draw, size: 18),
                    label: Text(
                      hasSignature ? 'Update' : 'Add',
                      style: TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size(0, 36),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: hasSignature ? Colors.white : Colors.grey.shade50,
              ),
              child: hasSignature ? Padding(padding: EdgeInsets.all(8), child: _getSignatureWidget()) : _getSignatureWidget(),
            ),
            if (hasSignature)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      _isSignatureFileValid ? Icons.phone_android : Icons.cloud_download,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(width: 4),
                    Text(
                      _isSignatureFileValid ? 'Local signature' : 'Server signature',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}