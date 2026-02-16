import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:signature/signature.dart';
import 'database_helper.dart';
import 'config.dart';

class GuardianDetailsPage extends StatefulWidget {
  final String learnerID;
  final Map<String, dynamic>? learnerData;

  const GuardianDetailsPage({
    super.key,
    required this.learnerID,
    this.learnerData,
  });

  @override
  _GuardianDetailsPageState createState() => _GuardianDetailsPageState();
}

class _GuardianDetailsPageState extends State<GuardianDetailsPage> {
  final TextEditingController _guardianFullNameController =
  TextEditingController();
  final TextEditingController _guardianIdNumberController =
  TextEditingController();
  final TextEditingController _guardianHomeAddressController =
  TextEditingController();
  final TextEditingController _guardianPostalAddressController =
  TextEditingController();
  final TextEditingController _guardianTelephoneController =
  TextEditingController();
  final TextEditingController _guardianEmailController =
  TextEditingController();
  final SignatureController _guardianSignatureController =
  SignatureController(penStrokeWidth: 2, penColor: Colors.black);
  final SignatureController _guardianWitnessSignatureController =
  SignatureController(penStrokeWidth: 2, penColor: Colors.black);

  bool _isLoading = true;
  bool _isSaving = false;

  // Validation error messages
  String? _idNumberError;
  String? _phoneNumberError;
  String? _emailError;

  // Saved signature URLs
  String? _savedGuardianSignatureUrl;
  String? _savedWitnessSignatureUrl;

  @override
  void initState() {
    super.initState();
    _loadGuardianData();

    // Add listeners for real-time validation
    _guardianIdNumberController.addListener(_validateIdNumber);
    _guardianTelephoneController.addListener(_validatePhoneNumber);
    _guardianEmailController.addListener(_validateEmail);
  }

  void _validateIdNumber() {
    final idNumber = _guardianIdNumberController.text.trim();
    setState(() {
      if (idNumber.isEmpty) {
        _idNumberError = null;
      } else if (idNumber.length < 13) {
        _idNumberError = 'ID number must be 13 digits (${idNumber.length}/13)';
      } else if (idNumber.length > 13) {
        _idNumberError = 'ID number cannot exceed 13 digits';
      } else if (!RegExp(r'^\d{13}$').hasMatch(idNumber)) {
        _idNumberError = 'ID number must contain only digits';
      } else {
        _idNumberError = null;
      }
    });
  }

  void _validatePhoneNumber() {
    final phoneNumber = _guardianTelephoneController.text.trim();
    setState(() {
      if (phoneNumber.isEmpty) {
        _phoneNumberError = null;
      } else if (phoneNumber.length < 10) {
        _phoneNumberError =
        'Phone number must be 10 digits (${phoneNumber.length}/10)';
      } else if (phoneNumber.length > 10) {
        _phoneNumberError = 'Phone number cannot exceed 10 digits';
      } else if (!RegExp(r'^\d{10}$').hasMatch(phoneNumber)) {
        _phoneNumberError = 'Phone number must contain only digits';
      } else {
        _phoneNumberError = null;
      }
    });
  }

  void _validateEmail() {
    final email = _guardianEmailController.text.trim();
    setState(() {
      if (email.isEmpty) {
        _emailError = null; // Email is optional
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _emailError = 'Please enter a valid email address';
      } else {
        _emailError = null;
      }
    });
  }

  @override
  void dispose() {
    _guardianIdNumberController.removeListener(_validateIdNumber);
    _guardianTelephoneController.removeListener(_validatePhoneNumber);
    _guardianEmailController.removeListener(_validateEmail);
    _guardianFullNameController.dispose();
    _guardianIdNumberController.dispose();
    _guardianHomeAddressController.dispose();
    _guardianPostalAddressController.dispose();
    _guardianTelephoneController.dispose();
    _guardianEmailController.dispose();
    _guardianSignatureController.dispose();
    _guardianWitnessSignatureController.dispose();
    super.dispose();
  }

  Future<void> _loadGuardianData() async {
    try {
      Map<String, dynamic>? guardianData;
      bool fetchedFromServer = false;

      // Try to fetch from server first
      try {
        final url =
            '${AppConfig.baseUrl}/get_guardian.php?learner_id=${widget.learnerID}';
        print('[GUARDIAN] Fetching from server: $url');

        final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == true && result['data'] != null) {
            guardianData = Map<String, dynamic>.from(result['data']);
            fetchedFromServer = true;
            print('[GUARDIAN] Data fetched from server');

            // Save to local database for offline access
            await _saveToLocalDatabase(guardianData);
          }
        }
      } catch (e) {
        print('[GUARDIAN] Server fetch failed: $e, trying local database');
      }

      // Fallback to local database if server fetch failed
      if (guardianData == null) {
        guardianData = await DatabaseHelper()
            .fetchGuardianDetails(int.parse(widget.learnerID));
        if (guardianData != null) {
          print('[GUARDIAN] Data loaded from local database');
        }
      }

      if (guardianData != null && mounted) {
        setState(() {
          _guardianFullNameController.text =
              guardianData!['full_name']?.toString() ?? '';
          _guardianIdNumberController.text =
              guardianData['id_number']?.toString() ?? '';
          _guardianHomeAddressController.text =
              guardianData['home_address']?.toString() ?? '';
          _guardianPostalAddressController.text =
              guardianData['postal_address']?.toString() ?? '';
          _guardianTelephoneController.text =
              guardianData['telephone']?.toString() ?? '';
          _guardianEmailController.text =
              guardianData['email']?.toString() ?? '';
          _isLoading = false;
        });

        // Load signature images if available
        await _loadSignatureImages(guardianData);

        print(
            '[GUARDIAN] Guardian data loaded for learner ${widget.learnerID}');
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[GUARDIAN] Error loading guardian data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveToLocalDatabase(Map<String, dynamic> guardianData) async {
    try {
      final db = await DatabaseHelper().database;

      // Check if guardian record exists
      final existing = await db.query(
        'guardian_details',
        where: 'learner_id = ?',
        whereArgs: [int.parse(widget.learnerID)],
      );

      if (existing.isNotEmpty) {
        // Update existing record
        await db.update(
          'guardian_details',
          {
            'full_name': guardianData['full_name'],
            'id_number': guardianData['id_number'],
            'home_address': guardianData['home_address'],
            'postal_address': guardianData['postal_address'] ?? '',
            'telephone': guardianData['telephone'],
            'email': guardianData['email'] ?? '',
            'signature_url': guardianData['signature_url'] ?? '',
            'witness_signature_url':
            guardianData['witness_signature_url'] ?? '',
            'synced': 1,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'learner_id = ?',
          whereArgs: [int.parse(widget.learnerID)],
        );
        print('[GUARDIAN] Updated local database with server data');
      } else {
        // Insert new record
        await db.insert(
          'guardian_details',
          {
            'learner_id': int.parse(widget.learnerID),
            'full_name': guardianData['full_name'],
            'id_number': guardianData['id_number'],
            'home_address': guardianData['home_address'],
            'postal_address': guardianData['postal_address'] ?? '',
            'telephone': guardianData['telephone'],
            'email': guardianData['email'] ?? '',
            'signature_url': guardianData['signature_url'] ?? '',
            'witness_signature_url':
            guardianData['witness_signature_url'] ?? '',
            'synced': 1,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
        print('[GUARDIAN] Inserted server data into local database');
      }
    } catch (e) {
      print('[GUARDIAN] Error saving to local database: $e');
    }
  }

  Future<void> _loadSignatureImages(Map<String, dynamic> guardianData) async {
    if (mounted) {
      setState(() {
        _savedGuardianSignatureUrl = guardianData['signature_url']?.toString();
        _savedWitnessSignatureUrl =
            guardianData['witness_signature_url']?.toString();
      });

      print('[GUARDIAN] Signature URLs loaded');
      print('[GUARDIAN] Guardian signature URL: $_savedGuardianSignatureUrl');
      print('[GUARDIAN] Witness signature URL: $_savedWitnessSignatureUrl');
    }
  }

  Future<void> _saveGuardianData() async {
    // Validate all required fields

    // 1. Full Name
    if (_guardianFullNameController.text.trim().isEmpty) {
      _showMessage('Please enter guardian full name', isError: true);
      return;
    }

    // 2. ID Number
    if (_guardianIdNumberController.text.trim().isEmpty) {
      _showMessage('Please enter guardian ID number', isError: true);
      return;
    }
    if (_idNumberError != null) {
      _showMessage(_idNumberError!, isError: true);
      return;
    }

    // 3. Home Address
    if (_guardianHomeAddressController.text.trim().isEmpty) {
      _showMessage('Please enter guardian home address', isError: true);
      return;
    }

    // 4. Postal Address (optional but validate if provided)
    // No validation needed - it's optional

    // 5. Phone Number
    if (_guardianTelephoneController.text.trim().isEmpty) {
      _showMessage('Please enter guardian telephone number', isError: true);
      return;
    }
    if (_phoneNumberError != null) {
      _showMessage(_phoneNumberError!, isError: true);
      return;
    }

    // 6. Email (optional but validate format if provided)
    if (_emailError != null) {
      _showMessage(_emailError!, isError: true);
      return;
    }

    // 7. Guardian Signature
    if (_guardianSignatureController.isEmpty) {
      _showMessage('Please provide guardian signature', isError: true);
      return;
    }

    // 8. Witness Signature
    if (_guardianWitnessSignatureController.isEmpty) {
      _showMessage('Please provide witness signature', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Convert signatures to base64
      final guardianSignatureBytes =
      await _guardianSignatureController.toPngBytes();
      final guardianWitnessSignatureBytes =
      await _guardianWitnessSignatureController.toPngBytes();

      final guardianSignatureBase64 = guardianSignatureBytes != null
          ? base64Encode(guardianSignatureBytes)
          : '';
      final guardianWitnessSignatureBase64 =
      guardianWitnessSignatureBytes != null
          ? base64Encode(guardianWitnessSignatureBytes)
          : '';

      final guardianData = {
        'learner_id': widget.learnerID,
        'full_name': _guardianFullNameController.text.trim(),
        'id_number': _guardianIdNumberController.text.trim(),
        'home_address': _guardianHomeAddressController.text.trim(),
        'postal_address': _guardianPostalAddressController.text.trim(),
        'telephone': _guardianTelephoneController.text.trim(),
        'email': _guardianEmailController.text.trim(),
        'signature': guardianSignatureBase64,
        'witness_signature': guardianWitnessSignatureBase64,
      };

      print('[GUARDIAN] Saving guardian data: ${guardianData.keys}');

      // Save to local database first
      await DatabaseHelper().saveGuardianDetails(guardianData);
      print('[GUARDIAN] Saved to local database');

      // Try to sync to server
      bool syncedOnline = false;
      try {
        final url = '${AppConfig.baseUrl}/save_guardian.php';
        print('[GUARDIAN] Syncing to server: $url');

        final response = await http
            .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(guardianData),
        )
            .timeout(const Duration(seconds: 10));

        print('[GUARDIAN] Server response status: ${response.statusCode}');
        print('[GUARDIAN] Server response body: ${response.body}');

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == true) {
            syncedOnline = true;
            print('[GUARDIAN] Successfully synced to server');
          } else {
            print('[GUARDIAN] Server returned error: ${result['message']}');
          }
        } else {
          print(
              '[GUARDIAN] Server returned status code: ${response.statusCode}');
        }
      } catch (e) {
        print('[GUARDIAN] Failed to sync to server: $e');
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        _showMessage(
          syncedOnline
              ? 'Guardian details saved and synced online'
              : 'Guardian details saved locally (will sync when online)',
          isError: false,
        );

        // Go back after successful save
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('[GUARDIAN] Error saving guardian data: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showMessage('Error saving guardian details: $e', isError: true);
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Details'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange[800], size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Parent or Guardian Details\n(Required for learners under 18 years)',
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _guardianFullNameController,
                decoration: const InputDecoration(
                  labelText: '3.1 Full name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _guardianIdNumberController,
                decoration: InputDecoration(
                  labelText: '3.2 Identity number *',
                  hintText: '13 digits (e.g., 8001015009087)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.badge),
                  errorText: _idNumberError,
                  errorMaxLines: 2,
                  helperText: _idNumberError == null
                      ? 'Must be exactly 13 digits'
                      : null,
                ),
                keyboardType: TextInputType.number,
                maxLength: 13,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _guardianHomeAddressController,
                decoration: const InputDecoration(
                  labelText: '3.3 Home address *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _guardianPostalAddressController,
                decoration: const InputDecoration(
                  labelText: '3.4 Postal address (if different)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.mail),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _guardianTelephoneController,
                decoration: InputDecoration(
                  labelText: '3.5 Telephone number *',
                  hintText: '10 digits (e.g., 0821234567)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone),
                  errorText: _phoneNumberError,
                  errorMaxLines: 2,
                  helperText: _phoneNumberError == null
                      ? 'Must be exactly 10 digits'
                      : null,
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _guardianEmailController,
                decoration: InputDecoration(
                  labelText: '3.6 E-mail address (optional)',
                  hintText: 'example@email.com',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                  errorText: _emailError,
                  errorMaxLines: 2,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Guardian Signature',
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Show saved signature if available
              if (_savedGuardianSignatureUrl != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Previously Saved Signature:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Image.network(
                            _savedGuardianSignatureUrl!,
                            height: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Text(
                                'Could not load saved signature',
                                style: TextStyle(color: Colors.red),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Draw new signature below to update:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Signature(
                  controller: _guardianSignatureController,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _guardianSignatureController.clear(),
                icon: const Icon(Icons.clear),
                label: const Text('Clear Signature'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Witness Signature',
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Show saved witness signature if available
              if (_savedWitnessSignatureUrl != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Previously Saved Witness Signature:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Image.network(
                            _savedWitnessSignatureUrl!,
                            height: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Text(
                                'Could not load saved witness signature',
                                style: TextStyle(color: Colors.red),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Draw new witness signature below to update:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Signature(
                  controller: _guardianWitnessSignatureController,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () =>
                    _guardianWitnessSignatureController.clear(),
                icon: const Icon(Icons.clear),
                label: const Text('Clear Witness Signature'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveGuardianData,
                  icon: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white),
                    ),
                  )
                      : const Icon(Icons.save),
                  label: Text(
                      _isSaving ? 'Saving...' : 'Save Guardian Details'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '* Required fields',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
