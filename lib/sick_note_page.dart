import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'config.dart';
import 'services/camera_resource_manager.dart';
import 'utils/scanner_pdf_resolver.dart';

class SickNotePage extends StatefulWidget {
  final int learnerID;
  final String learnerName;

  const SickNotePage({
    Key? key,
    required this.learnerID,
    required this.learnerName,
  }) : super(key: key);

  @override
  _SickNotePageState createState() => _SickNotePageState();
}

class _SickNotePageState extends State<SickNotePage> {
  final TextEditingController _practiceNameController = TextEditingController();
  final TextEditingController _practitionerNameController =
      TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();

  String _practitionerType = 'Doctor';
  DateTime? _selectedDateFrom;
  DateTime? _selectedDateTo;
  File? _scannedPdf;
  String? _pdfFileName;

  bool _isSubmitting = false;
  bool _isScanning = false;
  bool _isCheckingEligibility = true;
  bool _isEligible = false;
  String? _eligibilityMessage;
  List<String> _validDates = []; // List of valid selectable dates
  Map<String, bool> _clockedDates = {}; // Map of dates where learner clocked in

  final CameraResourceManager _cameraManager = CameraResourceManager();

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  @override
  void dispose() {
    _practiceNameController.dispose();
    _practitionerNameController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    _cameraManager.markMLKitScannerInactive();
    super.dispose();
  }

  /// Check eligibility and get valid dates from backend
  Future<void> _checkEligibility() async {
    setState(() => _isCheckingEligibility = true);

    try {
      final response = await http.post(
        Uri.parse(AppConfig.getSickNoteEligibleDatesUrl),
        body: {'learner_id': widget.learnerID.toString()},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success' && data['is_eligible'] == true) {
          // Extract valid dates
          List<String> validDates = [];
          Map<String, bool> clockedDates = {};

          if (data['dates'] != null) {
            for (var dateObj in data['dates']) {
              String date = dateObj['date'];
              bool isSelectable = dateObj['is_selectable'] == true;

              if (isSelectable) {
                validDates.add(date);
              } else {
                // Mark as clocked/unavailable
                clockedDates[date] = true;
              }
            }
          }

          setState(() {
            _isEligible = true;
            _validDates = validDates;
            _clockedDates = clockedDates;
          });
        } else {
          setState(() {
            _isEligible = false;
            _eligibilityMessage =
                data['message'] ?? 'You are not eligible to upload sick notes.';
          });
        }
      } else {
        setState(() {
          _isEligible = false;
          _eligibilityMessage = 'Server error. Please try again later.';
        });
      }
    } catch (e) {
      setState(() {
        _isEligible = false;
        _eligibilityMessage = 'Connection error: $e';
      });
    } finally {
      setState(() => _isCheckingEligibility = false);
    }
  }

  /// Select Date From with validation
  Future<void> _selectDateFrom() async {
    if (_validDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid dates available for sick note upload'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Parse valid dates to DateTime
    List<DateTime> validDateTimes =
        _validDates.map((d) => DateTime.parse(d)).toList();
    DateTime firstDate = validDateTimes.reduce((a, b) => a.isBefore(b) ? a : b);
    DateTime lastDate = validDateTimes.reduce((a, b) => a.isAfter(b) ? a : b);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (DateTime date) {
        String dateStr = DateFormat('yyyy-MM-dd').format(date);
        return _validDates.contains(dateStr);
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF006341),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      String pickedStr = DateFormat('yyyy-MM-dd').format(picked);

      // Validate again
      if (!_validDates.contains(pickedStr)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Selected date is not valid. You may have already clocked in on this day.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _selectedDateFrom = picked;
        _dateFromController.text = pickedStr;

        // Auto-set Date To to same date
        _selectedDateTo = picked;
        _dateToController.text = pickedStr;
      });
    }
  }

  /// Select Date To with validation
  Future<void> _selectDateTo() async {
    if (_selectedDateFrom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Date From first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_validDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid dates available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Parse valid dates to DateTime
    List<DateTime> validDateTimes =
        _validDates.map((d) => DateTime.parse(d)).toList();
    DateTime firstDate = validDateTimes.reduce((a, b) => a.isBefore(b) ? a : b);
    DateTime lastDate = validDateTimes.reduce((a, b) => a.isAfter(b) ? a : b);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateFrom!,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (DateTime date) {
        String dateStr = DateFormat('yyyy-MM-dd').format(date);
        // Must be >= Date From and must be valid
        return date.isAfter(_selectedDateFrom!) ||
            date.isAtSameMomentAs(_selectedDateFrom!) &&
                _validDates.contains(dateStr);
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF006341),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      String pickedStr = DateFormat('yyyy-MM-dd').format(picked);

      // Validate
      if (!_validDates.contains(pickedStr)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Selected date is not valid. You may have already clocked in on this day.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _selectedDateTo = picked;
        _dateToController.text = pickedStr;
      });
    }
  }

  /// Scan document using camera
  Future<void> _scanDocument() async {
    if (_isScanning) return;

    const String requester = 'SickNoteScanner';

    // Check camera permissions
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Request camera access
    final bool hasAccess = await _cameraManager.requestCameraAccess(requester,
        timeout: const Duration(seconds: 10));

    if (!hasAccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _cameraManager.currentUser != null
                  ? 'Camera is being used by ${_cameraManager.currentUser}. Please wait.'
                  : 'Camera is currently busy. Please wait.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isScanning = true);

    try {
      _cameraManager.markMLKitScannerActive();

      final dynamic scanResult =
          await FlutterDocScanner().getScanDocuments(page: 80);

      if (scanResult is! Map ||
          !scanResult.containsKey('pdfUri') ||
          scanResult['pdfUri'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scanner returned invalid data'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final String? pdfUri = scanResult['pdfUri'] as String?;
      final file = await resolveFlutterDocScannerPdfFile(pdfUri);

      if (file == null || !await isReadablePdfFile(file)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scanner returned unreadable file. Try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _scannedPdf = file;
        _pdfFileName = 'sick_note_${DateTime.now().millisecondsSinceEpoch}.pdf';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document scanned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
      _cameraManager.markMLKitScannerInactive();
      _cameraManager.releaseCameraAccess(requester);
    }
  }

  /// Validate form
  bool _validateForm() {
    if (_practitionerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter medical practitioner name'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    if (_selectedDateFrom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Date From'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    if (_selectedDateTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Date To'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    if (_scannedPdf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please scan sick note document'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    // Validate file size (max 10MB)
    final fileSizeInMB = _scannedPdf!.lengthSync() / (1024 * 1024);
    if (fileSizeInMB > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File size must be less than 10MB'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  /// Submit sick note
  Future<void> _submitSickNote() async {
    if (!_validateForm()) return;

    setState(() => _isSubmitting = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConfig.submitSickNoteUrl),
      );

      request.fields['learner_id'] = widget.learnerID.toString();
      request.fields['date_from'] = _dateFromController.text;
      request.fields['date_to'] = _dateToController.text;
      request.fields['practice_name'] = _practiceNameController.text.trim();
      request.fields['practitioner_name'] =
          _practitionerNameController.text.trim();

      request.files.add(
        await http.MultipartFile.fromPath('document', _scannedPdf!.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green, size: 32),
                    SizedBox(width: 12),
                    Text('Success'),
                  ],
                ),
                content:
                    Text(data['message'] ?? 'Sick note submitted successfully'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message'] ?? 'Submission failed'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server error: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Split learner name
    List<String> nameParts = widget.learnerName.split(' ');
    String name = nameParts.isNotEmpty ? nameParts.first : '';
    String surname = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Sick Note'),
        backgroundColor: const Color(0xFF006341),
      ),
      body: _isCheckingEligibility
          ? const Center(child: CircularProgressIndicator())
          : !_isEligible
              ? _buildNotEligibleView()
              : _buildFormView(name, surname),
      floatingActionButton: _isEligible && !_isCheckingEligibility
          ? FloatingActionButton(
              onPressed: _isScanning ? null : _scanDocument,
              backgroundColor: const Color(0xFF673AB7),
              child: _isScanning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.camera_alt, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildNotEligibleView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 80, color: Colors.red[300]),
            const SizedBox(height: 24),
            Text(
              _eligibilityMessage ?? 'Not Eligible',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006341)),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView(String name, String surname) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Learner Information Card
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Learner Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5E35B1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Name: $name', style: const TextStyle(fontSize: 14)),
                  Text('Surname: $surname',
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sick Note Details Card
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sick Note Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5E35B1),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Practice Name
                  TextField(
                    controller: _practiceNameController,
                    decoration: const InputDecoration(
                      labelText: 'Practice Name',
                      hintText: 'Practice Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Medical Practitioner
                  TextField(
                    controller: _practitionerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Medical Practitioner',
                      hintText: 'Medical Practitioner',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Practitioner Type Dropdown
                  DropdownButtonFormField<String>(
                    value: _practitionerType,
                    decoration: const InputDecoration(
                      labelText: 'Practitioner Type',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Doctor', 'Nurse', 'Other']
                        .map((type) =>
                            DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _practitionerType = value!);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date From
                  TextField(
                    controller: _dateFromController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date From (YYYY-MM-DD)',
                      hintText: 'Date From (YYYY-MM-DD)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _selectDateFrom,
                      ),
                    ),
                    onTap: _selectDateFrom,
                  ),
                  const SizedBox(height: 16),

                  // Date To
                  TextField(
                    controller: _dateToController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date To (YYYY-MM-DD)',
                      hintText: 'Date To (YYYY-MM-DD)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _selectDateTo,
                      ),
                    ),
                    onTap: _selectDateTo,
                  ),
                  const SizedBox(height: 16),

                  // Instruction Text
                  const Text(
                    'Tap the camera button to scan a sick note',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),

                  // Scanned document indicator
                  if (_scannedPdf != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Document scanned: $_pdfFileName',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitSickNote,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006341),
                disabledBackgroundColor: Colors.grey,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Submit', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }
}
