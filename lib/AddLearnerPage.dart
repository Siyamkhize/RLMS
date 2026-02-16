import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'config.dart';

class AddLearnerPage extends StatefulWidget {
  final String classID;
  
  const AddLearnerPage({super.key, required this.classID});

  @override
  _AddLearnerPageState createState() => _AddLearnerPageState();
}

class _AddLearnerPageState extends State<AddLearnerPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Personal Information Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  
  // Address Controllers
  final TextEditingController _addressStreetController = TextEditingController();
  final TextEditingController _addressSuburbController = TextEditingController();
  final TextEditingController _addressCityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  
  // School Information Controllers
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _schoolCompletionController = TextEditingController();
  final TextEditingController _schoolLocationController = TextEditingController();
  final TextEditingController _schoolGradeController = TextEditingController();
  
  // Next of Kin Controllers
  final TextEditingController _kinNameController = TextEditingController();
  final TextEditingController _kinRelationController = TextEditingController();
  final TextEditingController _kinContactController = TextEditingController();
  
  // Banking Details Controllers
  final TextEditingController _bankAccountTypeController = TextEditingController();
  final TextEditingController _bankAccountNumberController = TextEditingController();
  final TextEditingController _bankBranchCodeController = TextEditingController();
  
  // Dropdown Selections
  String? _selectedTitle;
  String? _selectedGender;
  String? _selectedRace;
  String? _selectedLanguage;
  String? _selectedDisability;
  String? _selectedBank;
  
  // Dropdown Options
  final List<String> _titles = ['Mr', 'Mrs', 'Miss', 'Dr', 'Prof'];
  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _races = ['Black', 'White', 'Coloured', 'Indian', 'Other'];
  final List<String> _languages = ['English', 'Afrikaans', 'Zulu', 'Xhosa', 'Sotho', 'Other'];
  final List<String> _disabilities = ['None', 'Physical', 'Visual', 'Hearing', 'Learning', 'Other'];
  final List<String> _banks = [
    'ABSA', 'FNB', 'Nedbank', 'Standard Bank', 'Capitec', 'African Bank',
    'Bidvest Bank', 'Discovery Bank', 'TymeBank', 'Bank Zero', 'Other'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _idNumberController.dispose();
    _dobController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _addressStreetController.dispose();
    _addressSuburbController.dispose();
    _addressCityController.dispose();
    _postalCodeController.dispose();
    _schoolNameController.dispose();
    _schoolCompletionController.dispose();
    _schoolLocationController.dispose();
    _schoolGradeController.dispose();
    _kinNameController.dispose();
    _kinRelationController.dispose();
    _kinContactController.dispose();
    _bankAccountTypeController.dispose();
    _bankAccountNumberController.dispose();
    _bankBranchCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleFormSubmission(BuildContext context) async {
    // Prepare learner data (only fields for learnerdetails table)
    Map<String, dynamic> learnerData = {
      'classID': widget.classID,
      'Title': _selectedTitle ?? 'N/A',
      'Name': _nameController.text,
      'Surname': _surnameController.text,
      'IDNumber': _idNumberController.text,
      'DateOfBirth': _dobController.text.isEmpty ? 'N/A' : _dobController.text,
      'PhoneNumber': _contactNumberController.text.isEmpty
          ? 'N/A'
          : _contactNumberController.text,
      'Email': _emailController.text.isEmpty ? 'N/A' : _emailController.text,
      'Age': _ageController.text.isEmpty ? '0' : _ageController.text,
      'Gender': _selectedGender ?? 'Unknown',
      'Race': _selectedRace ?? '',
      'Language': _selectedLanguage ?? '',
      'Disability': _selectedDisability ?? '',
      'AddressLine1': _addressStreetController.text.isEmpty
          ? ''
          : _addressStreetController.text,
      'AddressLine2': _addressSuburbController.text.isEmpty
          ? ''
          : _addressSuburbController.text,
      'AddressLine3': _addressCityController.text.isEmpty
          ? ''
          : _addressCityController.text,
      'PostalCode':
          _postalCodeController.text.isEmpty ? '' : _postalCodeController.text,
      'KinName': _kinNameController.text.isEmpty ? '' : _kinNameController.text,
      'KinRelation': _kinRelationController.text.isEmpty
          ? ''
          : _kinRelationController.text,
      'KinContact':
          _kinContactController.text.isEmpty ? '' : _kinContactController.text,
      'SchoolName':
          _schoolNameController.text.isEmpty ? '' : _schoolNameController.text,
      'SchoolCompletion': _schoolCompletionController.text.isEmpty
          ? ''
          : _schoolCompletionController.text,
      'SchoolLocation': _schoolLocationController.text.isEmpty
          ? ''
          : _schoolLocationController.text,
      'SchoolGrade': _schoolGradeController.text.isEmpty
          ? ''
          : _schoolGradeController.text,
      'profile_image': '',
      'signature': '',
      'synced': 0,
      'zkteco_left_template': '',
      'imagePath': '',
      'zkteco_right_template': '',
      'activity_statu': '',
      'witness_initials': '',
      'learner_initials': '',
      'witness_signature': '',
    };

    // Prepare bank data (only fields for bankdetails table)
    Map<String, dynamic>? bankData;
    if (_bankAccountNumberController.text.isNotEmpty ||
        _bankAccountTypeController.text.isNotEmpty ||
        _bankBranchCodeController.text.isNotEmpty) {
      bankData = {
        'BankName': _selectedBank ?? '',
        'bankType': _bankAccountTypeController.text,
        'BankAccount': _bankAccountNumberController.text,
        'BankCode': _bankBranchCodeController.text,
      };
    }

    // Debug print
    print('Learner Data: $learnerData');
    print('Bank Data: $bankData');

    // Validate required fields
    if (_nameController.text.isEmpty || _surnameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    // Submit data
    bool success = await _submitLearnerData(context, learnerData, bankData);
    if (success) {
      // Clear form
      _nameController.clear();
      _surnameController.clear();
      _idNumberController.clear();
      _dobController.clear();
      _contactNumberController.clear();
      _emailController.clear();
      _ageController.clear();
      _addressStreetController.clear();
      _addressSuburbController.clear();
      _addressCityController.clear();
      _postalCodeController.clear();
      _schoolNameController.clear();
      _schoolCompletionController.clear();
      _schoolLocationController.clear();
      _schoolGradeController.clear();
      _kinNameController.clear();
      _kinRelationController.clear();
      _kinContactController.clear();
      _bankAccountTypeController.clear();
      _bankAccountNumberController.clear();
      _bankBranchCodeController.clear();
      setState(() {
        _selectedTitle = null;
        _selectedGender = null;
        _selectedRace = null;
        _selectedLanguage = null;
        _selectedDisability = null;
        _selectedBank = null;
      });
    }
  }

  Future<bool> _submitLearnerData(BuildContext context, Map<String, dynamic> learnerData, Map<String, dynamic>? bankData) async {
    try {
      // Insert into local database first
      final dbHelper = DatabaseHelper();
      final learnerId = await dbHelper.insertOrUpdateLearner(learnerData, bankData);
      
      // Sync with backend server
      final syncResult = await _syncWithBackend(learnerData, bankData);
      
      // Show appropriate success message based on sync result
      if (syncResult) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Learner added successfully and synced with server'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Learner saved locally but failed to sync with server. Will retry when online.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      // Navigate back
      Navigator.pop(context, true); // Return true to indicate success
      return true;
      
    } catch (e) {
      print('Error adding learner: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding learner: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Future<bool> _syncWithBackend(Map<String, dynamic> learnerData, Map<String, dynamic>? bankData) async {
    try {
      // Merge learner data with bank data for backend
      final Map<String, dynamic> requestData = Map.from(learnerData);
      
      if (bankData != null) {
        requestData.addAll(bankData);
      }
      
      // Use the proper configuration URL
      final url = AppConfig.addLearnerUrl;
      
      print('=== BACKEND SYNC DEBUG ===');
      print('Full URL: $url');
      print('Request data: $requestData');
      print('========================');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      ).timeout(const Duration(seconds: 30));
      
      print('Backend response status: ${response.statusCode}');
      print('Backend response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          print('Successfully synced with backend');
          return true;
        } else {
          print('Backend sync failed: ${responseData['message']}');
          return false;
        }
      } else {
        print('Backend sync failed with status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error syncing with backend: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Learner'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Personal Information Section
            _buildSectionHeader('Personal Information'),
            _buildDropdownField('Title', _selectedTitle, _titles, (value) {
              setState(() => _selectedTitle = value);
            }),
            _buildTextField('Name *', _nameController, isRequired: true),
            _buildTextField('Surname *', _surnameController, isRequired: true),
            _buildTextField('ID Number', _idNumberController),
            _buildTextField('Date of Birth', _dobController),
            _buildTextField('Phone Number', _contactNumberController),
            _buildTextField('Email', _emailController),
            _buildTextField('Age', _ageController),
            _buildDropdownField('Gender', _selectedGender, _genders, (value) {
              setState(() => _selectedGender = value);
            }),
            _buildDropdownField('Race', _selectedRace, _races, (value) {
              setState(() => _selectedRace = value);
            }),
            _buildDropdownField('Language', _selectedLanguage, _languages, (value) {
              setState(() => _selectedLanguage = value);
            }),
            _buildDropdownField('Disability', _selectedDisability, _disabilities, (value) {
              setState(() => _selectedDisability = value);
            }),
            
            const SizedBox(height: 20),
            
            // Address Section
            _buildSectionHeader('Address Information'),
            _buildTextField('Street Address', _addressStreetController),
            _buildTextField('Suburb', _addressSuburbController),
            _buildTextField('City', _addressCityController),
            _buildTextField('Postal Code', _postalCodeController),
            
            const SizedBox(height: 20),
            
            // School Information Section
            _buildSectionHeader('School Information'),
            _buildTextField('School Name', _schoolNameController),
            _buildTextField('School Completion Year', _schoolCompletionController),
            _buildTextField('School Location', _schoolLocationController),
            _buildTextField('School Grade', _schoolGradeController),
            
            const SizedBox(height: 20),
            
            // Next of Kin Section
            _buildSectionHeader('Next of Kin Information'),
            _buildTextField('Kin Name', _kinNameController),
            _buildTextField('Kin Relation', _kinRelationController),
            _buildTextField('Kin Contact', _kinContactController),
            
            const SizedBox(height: 20),
            
            // Banking Details Section
            _buildSectionHeader('Banking Details (Optional)'),
            _buildDropdownField('Bank Name', _selectedBank, _banks, (value) {
              setState(() => _selectedBank = value);
            }),
            _buildTextField('Account Type', _bankAccountTypeController),
            _buildTextField('Account Number', _bankAccountNumberController),
            _buildTextField('Branch Code', _bankBranchCodeController),
            
            const SizedBox(height: 30),
            
            // Submit Button
            ElevatedButton(
              onPressed: () => _handleFormSubmission(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Add Learner',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isRequired = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: isRequired ? (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required';
          }
          return null;
        } : null,
      ),
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> options, Function(String?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        items: options.map((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
