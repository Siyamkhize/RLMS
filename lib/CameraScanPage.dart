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

import 'config.dart';

class CameraScanPage extends StatefulWidget {
  final String type;
  final String exercise;
  final int learnerID;
  final String? logbookText;

  const CameraScanPage({
    super.key,
    required this.type,
    required this.exercise,
    required this.learnerID,
    this.logbookText,
  });

  @override
  _CameraScanPageState createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<CameraScanPage> {
  bool isScanning = false;
  List<File> scannedImages = [];
  final TextEditingController _logbookTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (![
      'LogBook',
      'Formative',
      'Summative',
      'FormativeRemedial',
      'SummativeRemedial'
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
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        _showErrorSnackBar('Camera permission denied', retryable: true);
        return;
      }
    }
    setState(() => isScanning = true);
    try {
      // All types (including LogBook) now use FlutterDocScanner for multi-page scanning with edge detection
      final dynamic scanResult = await FlutterDocScanner().getScanDocuments(
          // Remove page limitation by setting to unlimited (high number)
          page: 999);
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
      final pdfPath = pdfUri!.replaceFirst('file:///', '');
      print('Processed PDF Path: $pdfPath');
      final file = File(pdfPath);
      if (await file.exists()) {
        print('PDF exists: ${file.path}, size: ${await file.length()} bytes');
        setState(() {
          scannedImages = [file];
        });
        _showSnackBar('PDF document scanned successfully!');
      } else {
        print('Error: PDF does not exist at $pdfPath');
        _showErrorSnackBar('PDF file not found or invalid', retryable: true);
      }
    } catch (e, stackTrace) {
      print('Scan Error: $e\nStack Trace: $stackTrace');
      _showErrorSnackBar('Document scan error: $e', retryable: true);
    } finally {
      setState(() => isScanning = false);
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

      if (await _checkConnectivity()) {
        await _uploadImages(filePaths, logbookText);
      } else {
        await _saveLocally(filePaths, logbookText);
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
      final uri = Uri.parse(AppConfig.buildUrl('save_metadata.php'));
      final request = http.MultipartRequest('POST', uri);

      for (final path in imagePaths) {
        final file = File(path);
        if (await file.exists()) {
          print('Uploading file: $path, Size: ${await file.length()} bytes');
          // All types now use PDF from document scanner
          final contentType = MediaType('application', 'pdf');
          request.files.add(
            http.MultipartFile(
              'files[]',
              file.openRead(),
              await file.length(),
              filename: file.path.split('/').last,
              contentType: contentType,
            ),
          );
        } else {
          print('Invalid file path for upload: $path');
        }
      }

      request.fields.addAll({
        'type': widget.type,
        'exercise': widget.exercise,
        'learnerID': widget.learnerID.toString(),
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

          for (final path in imagePaths) {
            if (File(path).existsSync()) {
              batch.insert(
                'poe',
                {
                  'learnerID': widget.learnerID,
                  'exercise': widget.exercise,
                  'type': widget.type,
                  'filePath': path,
                  'logbook_text': widget.type == 'LogBook' ? logbookText : '',
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

      for (int i = 0; i < imagePaths.length; i++) {
        final file = File(imagePaths[i]);
        if (await file.exists()) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final sanitizedExercise = sanitizeFileName(widget.exercise);
          // All types now use PDF from document scanner
          final extension = 'pdf';
          final fileName =
              '${widget.learnerID}_${sanitizedExercise}_${timestamp}_$i.$extension';
          final savedPath = '${directory.path}/$fileName';
          await file.copy(savedPath);
          savedPaths.add(savedPath);

          batch.insert(
            'poe',
            {
              'learnerID': widget.learnerID,
              'exercise': widget.exercise,
              'type': widget.type,
              'filePath': savedPath,
              'logbook_text': widget.type == 'LogBook' ? logbookText : '',
              'submitted_at': dateFormatter.format(DateTime.now()),
              'synced': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          print(
              'Local DB Insert: learnerID=${widget.learnerID}, exercise=${widget.exercise}, type=${widget.type}, logbook_text=$logbookText');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message, {bool retryable = false}) {
    print('Error SnackBar: $message');
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
