import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_helper.dart';
import 'package:intl/intl.dart';
import 'services/camera_resource_manager.dart';

import 'config.dart';
import 'utils/scanner_pdf_resolver.dart';

class CameraScanPage extends StatefulWidget {
  final String type;
  final String exercise;
  final String? unitStandard;
  final int learnerID;
  final String? logbookText;
  final bool autoUpload;

  const CameraScanPage({
    super.key,
    required this.type,
    required this.exercise,
    this.unitStandard,
    required this.learnerID,
    this.logbookText,
    this.autoUpload = true,
  });

  @override
  _CameraScanPageState createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<CameraScanPage> {
  bool isScanning = false;
  List<File> scannedImages = [];
  final TextEditingController _logbookTextController = TextEditingController();
  final CameraResourceManager _cameraManager = CameraResourceManager();

  @override
  void initState() {
    super.initState();
    if (![
      'LogBook',
      'Formative',
      'Summative',
      'FormativeRemedial',
      'SummativeRemedial',
      'ARPL'
    ].contains(widget.type)) {
      print('Error: Invalid type ${widget.type}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorSnackBar('Invalid assessment type: ${widget.type}');
        Navigator.pop(context);
      });
    }
    if (widget.type == 'LogBook' && widget.logbookText != null) {
      _logbookTextController.text = widget.logbookText!;
      print('Initialized LogBook Text: ${widget.logbookText}');
    }
  }

  String sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[^A-Za-z0-9.-]'), '_').trim();
  }

  Future<void> _scanDocument() async {
    if (isScanning) return;

    const String requester = 'DocumentScanner';

    // Check camera permissions first
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        _showErrorSnackBar('Camera permission denied', retryable: true);
        return;
      }
    }

    // Request camera access with timeout
    final bool hasAccess = await _cameraManager.requestCameraAccess(requester,
        timeout: const Duration(seconds: 10));

    if (!hasAccess) {
      _showErrorSnackBar(
          _cameraManager.currentUser != null
              ? 'Camera is being used by ${_cameraManager.currentUser}. Please wait and try again.'
              : 'Camera is currently busy. Please wait and try again.',
          retryable: true);
      return;
    }

    if (!mounted) return;
    setState(() => isScanning = true);
    try {
      // Mark ML Kit scanner as active before starting
      _cameraManager.markMLKitScannerActive();

      // All types (including LogBook) now use FlutterDocScanner for multi-page scanning with edge detection
      // IMPORTANT: Updated page limit from 10 to 80.
      // 80 is the recommended maximum to avoid GMS memory crashes on some devices.
      final dynamic scanResult =
          await FlutterDocScanner().getScanDocuments(page: 80);
      print('Scan Result: $scanResult');
      if (scanResult is! Map ||
          !scanResult.containsKey('pdfUri') ||
          scanResult['pdfUri'] == null) {
        print('Invalid scan result: $scanResult');
        _showErrorSnackBar('Document scanner returned invalid data',
            retryable: true);
        return;
      }
      final String? pdfUri = scanResult['pdfUri'] as String?;
      final file = await resolveFlutterDocScannerPdfFile(pdfUri);
      if (file == null || !await isReadablePdfFile(file)) {
        print('Unable to resolve pdfUri to readable PDF: $pdfUri');
        _showErrorSnackBar('Scanner returned an unreadable file (try again)',
            retryable: true);
        return;
      }

      print('PDF exists: ${file.path}, size: ${await file.length()} bytes');
      if (!mounted) return;
      setState(() => scannedImages = [file]);
      _showSnackBar('PDF document scanned successfully!');
    } catch (e, stackTrace) {
      print('Scan Error: $e\nStack Trace: $stackTrace');
      _showErrorSnackBar('Document scan error: $e', retryable: true);
    } finally {
      if (mounted) {
        setState(() => isScanning = false);
      }
      // Mark ML Kit scanner as inactive
      _cameraManager.markMLKitScannerInactive();
      // Always release camera access
      _cameraManager.releaseCameraAccess(requester);
    }
  }

  Future<void> _saveDocuments() async {
    if (scannedImages.isEmpty) {
      _showErrorSnackBar('No documents to save.');
      return;
    }

    if (widget.type == 'LogBook' &&
        _logbookTextController.text.trim().isEmpty) {
      _showErrorSnackBar('Log book text is required before saving the image.');
      return;
    }

    try {
      final List<String> filePaths =
          scannedImages.map((file) => file.path).toList();
      final String logbookText =
          widget.type == 'LogBook' ? _logbookTextController.text : '';

      if (widget.autoUpload) {
        if (await _checkConnectivity()) {
          await _uploadImages(filePaths, logbookText);
        } else {
          await _saveLocally(filePaths, logbookText);
        }
      } else {
        print(
            'Auto-upload disabled for CameraScanPage. Returning results to caller.');
      }

      if (mounted) {
        Navigator.pop(context, {
          'image': scannedImages.isNotEmpty ? File(filePaths.first) : null,
          'logbookText': logbookText,
        });
      }
    } catch (e, stackTrace) {
      print('Save Error: $e\nStack Trace: $stackTrace');
      _showErrorSnackBar('Error saving documents: $e');
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    }
  }

  Future<void> _uploadImages(
      List<String> imagePaths, String logbookText) async {
    try {
      final uri = Uri.parse(AppConfig.buildUrl(widget.type == 'ARPL'
          ? 'arpl_save_metadata.php'
          : 'save_metadata.php'));
      final request = http.MultipartRequest('POST', uri);

      // Extract unit standard ID for filename
      String unitStandardId = 'UNKNOWN';
      if (widget.unitStandard != null && widget.unitStandard!.isNotEmpty) {
        RegExp idPattern = RegExp(r'(?:US|Unit\s*Standard\s*)?(\d{4,10})\b');
        Match? match = idPattern.firstMatch(widget.unitStandard!);
        if (match != null) {
          unitStandardId = match.group(1)!;
        } else {
          String digits =
              widget.unitStandard!.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.isNotEmpty) {
            unitStandardId = digits;
          }
        }
      }

      for (int i = 0; i < imagePaths.length; i++) {
        final file = File(imagePaths[i]);
        if (await file.exists()) {
          print(
              'Uploading file: ${imagePaths[i]}, Size: ${await file.length()} bytes');

          // Generate standardized filename for server
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final sanitizedExercise = sanitizeFileName(widget.exercise);
          final extension = 'pdf';
          final standardizedName =
              '${widget.type}_${unitStandardId}_${sanitizedExercise}_${timestamp}_$i.$extension';

          final contentType = MediaType('application', 'pdf');
          request.files.add(
            http.MultipartFile(
              'files[]',
              file.openRead(),
              await file.length(),
              filename: standardizedName,
              contentType: contentType,
            ),
          );
          print('Assigned filename: $standardizedName');
        } else {
          print('Invalid file path for upload: ${imagePaths[i]}');
        }
      }

      request.fields.addAll({
        'type': widget.type,
        'exercise': widget.exercise,
        'learnerID': widget.learnerID.toString(),
        'unit_standard_name': (widget.unitStandard ?? '').trim(),
        if (widget.type == 'LogBook') 'logbook_text': logbookText,
      });
      print('Sending fields: ${request.fields}');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print(
          'Server Response: $responseBody (Status Code: ${response.statusCode})');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(responseBody);
        if (responseData['status'] == 'success') {
          final dbHelper = DatabaseHelper();
          final db = await dbHelper.database;
          final batch = db.batch();
          final timestamp = DateTime.now().toIso8601String();
          final String uniqueExercise = (widget.unitStandard != null &&
                  widget.unitStandard!.isNotEmpty &&
                  !widget.exercise.contains(widget.unitStandard!))
              ? '${widget.unitStandard} - ${widget.exercise}'
              : widget.exercise;

          for (final path in imagePaths) {
            if (File(path).existsSync()) {
              batch.insert(
                'poe',
                {
                  'learnerID': widget.learnerID,
                  'exercise': uniqueExercise,
                  'type': widget.type,
                  'filePath': path,
                  'logbook_text': widget.type == 'LogBook' ? logbookText : '',
                  'unitStandard': (widget.unitStandard ?? '').trim(),
                  'submitted_at': timestamp,
                  'synced': 1,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } else {
              print('Invalid file path for database update: $path');
            }
          }

          await batch.commit();
          print('Database updated with ${imagePaths.length} uploaded files');
          _showSnackBar('Documents uploaded and saved successfully!');
        } else {
          final errorMessage =
              'Server error: ${responseData['message'] ?? 'Unknown error'}';
          print(errorMessage);
          _showErrorSnackBar(errorMessage);
          await _saveLocally(imagePaths, logbookText);
        }
      } else {
        final errorMessage = 'Upload failed with status ${response.statusCode}';
        print(errorMessage);
        _showErrorSnackBar(errorMessage);
        await _saveLocally(imagePaths, logbookText);
      }
    } catch (e, stackTrace) {
      print('Upload Error: $e\nStack Trace: $stackTrace');
      _showErrorSnackBar('Upload error: $e');
      await _saveLocally(imagePaths, logbookText);
    }
  }

  Future<void> _saveLocally(List<String> imagePaths, String logbookText) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<String> savedPaths = [];
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final batch = db.batch();
      final dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
      final String uniqueExercise = (widget.unitStandard != null &&
              widget.unitStandard!.isNotEmpty &&
              !widget.exercise.contains(widget.unitStandard!))
          ? '${widget.unitStandard} - ${widget.exercise}'
          : widget.exercise;

      // Extract unit standard ID for filename
      String unitStandardId = 'UNKNOWN';
      if (widget.unitStandard != null && widget.unitStandard!.isNotEmpty) {
        RegExp idPattern = RegExp(r'(?:US|Unit\s*Standard\s*)?(\d{4,10})\b');
        Match? match = idPattern.firstMatch(widget.unitStandard!);
        if (match != null) {
          unitStandardId = match.group(1)!;
        } else {
          // Fallback: extract any digits or use a portion of the string
          String digits =
              widget.unitStandard!.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.isNotEmpty) {
            unitStandardId = digits;
          }
        }
      }

      for (int i = 0; i < imagePaths.length; i++) {
        final file = File(imagePaths[i]);
        if (await file.exists()) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final sanitizedExercise = sanitizeFileName(widget.exercise);
          // All types now use PDF from document scanner
          final extension = 'pdf';
          final fileName =
              '${widget.type}_${unitStandardId}_${sanitizedExercise}_${timestamp}_$i.$extension';
          final savedPath = '${directory.path}/$fileName';
          await file.copy(savedPath);
          savedPaths.add(savedPath);

          batch.insert(
            'poe',
            {
              'learnerID': widget.learnerID,
              'exercise': uniqueExercise,
              'type': widget.type,
              'filePath': savedPath,
              'logbook_text': widget.type == 'LogBook' ? logbookText : '',
              'unitStandard': (widget.unitStandard ?? '').trim(),
              'submitted_at': dateFormatter.format(DateTime.now()),
              'synced': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          print(
              'Local DB Insert: learnerID=${widget.learnerID}, exercise=$uniqueExercise, type=${widget.type}, logbook_text=$logbookText');
        } else {
          print('Invalid file path for local save: ${imagePaths[i]}');
        }
      }

      if (savedPaths.isEmpty) {
        _showErrorSnackBar('No valid files to save locally.');
        return;
      }

      await batch.commit();
      print('Database updated with ${savedPaths.length} local files');
      _showSnackBar('Documents saved locally due to no connectivity!');
    } catch (e, stackTrace) {
      print('Local Save Error: $e\nStack Trace: $stackTrace');
      _showErrorSnackBar('Error saving locally: $e');
    }
  }

  void _showSnackBar(String message) {
    print('SnackBar: $message');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message, {bool retryable = false}) {
    print('Error SnackBar: $message');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: retryable
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _scanDocument(),
              )
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _logbookTextController.dispose();
    // Ensure camera manager state isn't left "busy" if this page is closed mid-scan.
    _cameraManager.markMLKitScannerInactive();
    _cameraManager.releaseCameraAccess('DocumentScanner');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Document Scanner'),
        actions: [
          if (scannedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: isScanning ? null : _saveDocuments,
              tooltip: 'Save Documents',
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.type == 'LogBook')
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _logbookTextController,
                decoration: const InputDecoration(
                  labelText: 'Log Book Entry',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) {
                  print('LogBook TextField onChanged: $value');
                },
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                if (scannedImages.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: scannedImages.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Stack(
                              children: [
                                Container(
                                  width: 120,
                                  height: 150,
                                  color: Colors.grey[300],
                                  // All types now show PDF icon since they all use document scanner
                                  child: const Center(
                                    child: Icon(Icons.picture_as_pdf,
                                        size: 50, color: Colors.red),
                                  ),
                                ),
                                Positioned(
                                  top: 5,
                                  right: 5,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: isScanning
                                        ? null
                                        : () {
                                            setState(() {
                                              scannedImages.removeAt(index);
                                            });
                                          },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (isScanning)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                if (!isScanning && scannedImages.isEmpty)
                  const Center(
                    child: Text('Scan a PDF document to start'),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isScanning
          ? null
          : FloatingActionButton(
              onPressed: _scanDocument,
              tooltip: 'Scan PDF Document',
              child: const Icon(Icons.document_scanner),
            ),
    );
  }
}
