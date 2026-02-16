import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'config.dart';

class SickNotePage extends StatefulWidget {
  final int learnerID;

  const SickNotePage({
    super.key,
    required this.learnerID,
  });

  @override
  State<SickNotePage> createState() => _SickNotePageState();
}

class _SickNotePageState extends State<SickNotePage> {
  static const _practitionerTypes = ['Doctor', 'Nurse', 'Other'];
  static const _maxFileSize = 5 * 1024 * 1024; // 5MB
  static const _minFileSize = 100 * 1024; // 100KB

  bool _isScanning = false;
  File? _scannedPdf;
  String? _learnerName;
  String? _learnerSurname;
  String? _selectedPractitionerType = 'Doctor';
  bool _showOtherPractitionerField = false;

  final _formKey = GlobalKey<FormState>();
  final _practiceNameController = TextEditingController();
  final _medicalPractitionerController = TextEditingController();
  final _practitionerNameController = TextEditingController();
  final _dateFromController = TextEditingController();
  final _dateToController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLearnerDetails();
  }

  @override
  void dispose() {
    _practiceNameController.dispose();
    _medicalPractitionerController.dispose();
    _practitionerNameController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  // UI Methods

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<bool> _showScanningInstructions() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scanning Instructions'),
        content: const Text(
          '1. Place document on a flat, contrasting surface (e.g., dark table).\n'
              '2. Ensure even, moderate lighting (avoid glare or shadows).\n'
              '3. Position camera to capture entire page.\n'
              '4. Scanner will auto-detect edges and focus on text.\n'
              '5. Hold steady until scan is captured.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _clearForm() {
    _practiceNameController.clear();
    _medicalPractitionerController.clear();
    _practitionerNameController.clear();
    _dateFromController.clear();
    _dateToController.clear();
    setState(() {
      _selectedPractitionerType = 'Doctor';
      _showOtherPractitionerField = false;
      _scannedPdf = null;
    });
  }

  // Data Validation Methods

  String? _validateDateFrom(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    try {
      final selectedDate = DateFormat('yyyy-MM-dd').parse(value);
      final now = DateTime.now();
      final fiveDaysAgo = now.subtract(const Duration(days: 5));
      return selectedDate.isBefore(fiveDaysAgo)
          ? 'Date must be within 5 days from today'
          : null;
    } catch (e) {
      return 'Invalid date format';
    }
  }

  String? _validateDateTo(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    try {
      final dateTo = DateFormat('yyyy-MM-dd').parse(value);
      final dateFrom = DateFormat('yyyy-MM-dd').parse(_dateFromController.text);
      return dateTo.isBefore(dateFrom)
          ? 'Date To must be on or after Date From'
          : null;
    } catch (e) {
      return 'Invalid date format';
    }
  }

  // Data Handling Methods

  Future<void> _fetchLearnerDetails() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final result = await db.query(
        'learnerdetails',
        where: 'LearnerID = ?',
        whereArgs: [widget.learnerID.toString()],
      );

      if (result.isNotEmpty) {
        setState(() {
          _learnerName = result.first['Name']?.toString() ?? 'Unknown';
          _learnerSurname = result.first['Surname']?.toString() ?? 'Unknown';
        });
      } else {
        _showSnackBar('Learner not found in database', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error fetching learner details: $e', isError: true);
    }
  }

  String _sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[^A-Za-z0-9.-]'), '_').trim();
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  // Submission Methods

  Future<void> _scanAndUploadSickNote() async {
    if (_isScanning || !_formKey.currentState!.validate()) {
      _showSnackBar('Please fill all required fields', isError: true);
      return;
    }

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showSnackBar('Camera permission denied. Please enable it in settings.',
          isError: true);
      await openAppSettings();
      return;
    }

    if (!await _showScanningInstructions()) return;

    setState(() => _isScanning = true);

    try {
      final scanResult = await FlutterDocScanner().getScanDocuments();
      if (scanResult is! Map ||
          !scanResult.containsKey('pdfUri') ||
          scanResult['pdfUri'] == null) {
        throw 'Invalid scan result';
      }

      final pdfPath = (scanResult['pdfUri'] as String).replaceFirst('file:///', '');
      final file = File(pdfPath);

      if (!await file.exists() || !pdfPath.endsWith('.pdf')) {
        throw 'Invalid or missing PDF file';
      }

      final fileSize = await file.length();
      if (fileSize > _maxFileSize) {
        throw 'File size exceeds 5MB limit';
      }
      if (fileSize < _minFileSize) {
        throw 'The scanned page may not be clear. Ensure text is sharp and entire page is captured.';
      }

      setState(() => _scannedPdf = file);

      final details = {
        'practice_name': _practiceNameController.text,
        'medical_practitioner': _medicalPractitionerController.text,
        'practitioner_name': _selectedPractitionerType == 'Other'
            ? _practitionerNameController.text
            : _selectedPractitionerType!,
        'date_from': _dateFromController.text,
        'date_to': _dateToController.text,
      };

      final learnerIDString = widget.learnerID.toString();
      if (await _checkConnectivity()) {
        await _sendSickNoteToBackend(learnerIDString, pdfPath, details);
      } else {
        await _saveSickNoteLocally(learnerIDString, pdfPath, details);
      }
    } catch (e) {
      _showSnackBar('$e', isError: true);
      _clearForm();
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _sendSickNoteToBackend(
      String learnerID, String filePath, Map<String, dynamic> details) async {
    try {
      final file = File(filePath);
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConfig.uploadSickNoteUrl),
      );

      request.files.add(http.MultipartFile(
        'sick_note',
        file.openRead(),
        await file.length(),
        filename: _sanitizeFileName(file.path.split('/').last),
        contentType: MediaType('application', 'pdf'),
      ));

      request.fields.addAll({
        'learner_id': learnerID,
        ...details,
      });

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = jsonDecode(responseBody);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final dbHelper = DatabaseHelper();
        final db = await dbHelper.database;
        await db.insert(
          'sick_note',
          {
            'learner_id': learnerID,
            'document_path': responseData['file_path'] ?? filePath,
            ...details,
            'upload_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
            'status': 'PENDING',
            'synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        _showSnackBar('Sick note uploaded successfully to server and saved locally');
        _clearForm();
      } else {
        final errorMessage = responseData['message'] ?? 'Unknown server error';
        throw 'Upload failed: $errorMessage';
      }
    } catch (e) {
      _showSnackBar('$e', isError: true);
      _clearForm();
      await _saveSickNoteLocally(learnerID, filePath, details);
    }
  }

  Future<void> _saveSickNoteLocally(
      String learnerID, String filePath, Map<String, dynamic> details) async {
    try {
      final file = File(filePath);
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = _sanitizeFileName('${learnerID}_sick_note_$timestamp.pdf');
      final savedPath = '${directory.path}/$fileName';
      await file.copy(savedPath);

      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      await db.insert(
        'sick_note',
        {
          'learner_id': learnerID,
          'document_path': savedPath,
          ...details,
          'upload_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          'status': 'PENDING',
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _showSnackBar('Sick note saved locally, pending sync when online');
      _clearForm();
    } catch (e) {
      _showSnackBar('Error saving sick note locally: $e', isError: true);
      _clearForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Sick Note'),
        elevation: 0,
        backgroundColor: Colors.grey[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learner Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Name: ${_learnerName ?? 'Loading...'}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Surname: ${_learnerSurname ?? 'Loading...'}', style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sick Note Details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _practiceNameController,
                        decoration: _inputDecoration('Practice Name'),
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _medicalPractitionerController,
                        decoration: _inputDecoration('Medical Practitioner'),
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedPractitionerType,
                        decoration: _inputDecoration('Practitioner Type'),
                        items: _practitionerTypes
                            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPractitionerType = value;
                            _showOtherPractitionerField = value == 'Other';
                            if (value != 'Other') _practitionerNameController.clear();
                          });
                        },
                        validator: (value) => value == null ? 'Required' : null,
                      ),
                      if (_showOtherPractitionerField) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _practitionerNameController,
                          decoration: _inputDecoration('Other Practitioner Name'),
                          validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dateFromController,
                        decoration: _inputDecoration('Date From (YYYY-MM-DD)', Icons.calendar_today),
                        readOnly: true,
                        onTap: () async {
                          final now = DateTime.now();
                          final fiveDaysAgo = now.subtract(const Duration(days: 5));
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: now,
                            firstDate: fiveDaysAgo,
                            lastDate: now,
                          );
                          if (picked != null) {
                            _dateFromController.text = DateFormat('yyyy-MM-dd').format(picked);
                          }
                        },
                        validator: _validateDateFrom,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dateToController,
                        decoration: _inputDecoration('Date To (YYYY-MM-DD)', Icons.calendar_today),
                        readOnly: true,
                        onTap: () async {
                          final dateFrom = _dateFromController.text.isNotEmpty
                              ? DateFormat('yyyy-MM-dd').parse(_dateFromController.text)
                              : DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dateFrom,
                            firstDate: dateFrom,
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            _dateToController.text = DateFormat('yyyy-MM-dd').format(picked);
                          }
                        },
                        validator: _validateDateTo,
                      ),
                      const SizedBox(height: 24),
                      if (_scannedPdf != null)
                        Column(
                          children: [
                            Container(
                              width: 120,
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    spreadRadius: 2,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.picture_as_pdf, size: 50, color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Scanned PDF: ${_scannedPdf!.path.split('/').last}',
                              style: const TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      else
                        Center(
                          child: Text(
                            'Tap the camera button to scan a sick note',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        ),
                      if (_isScanning)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 8),
                                Text('Scanning document...'),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isScanning
          ? null
          : FloatingActionButton(
        onPressed: _scanAndUploadSickNote,
        tooltip: 'Scan Sick Note',
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.document_scanner),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, [IconData? suffixIcon]) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.grey[100],
      suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
    );
  }
}