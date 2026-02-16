import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'config.dart';
import 'utils/fingerprint_error_handler.dart';

class PoeBulkScanPage extends StatefulWidget {
  final int learnerID;
  final String unitStandard;
  final String assessmentType; // 'Formative', 'Summative', or 'LogBook'
  final List<Map<String, dynamic>> questions;

  const PoeBulkScanPage({
    Key? key,
    required this.learnerID,
    required this.unitStandard,
    required this.assessmentType,
    required this.questions,
  }) : super(key: key);

  @override
  State<PoeBulkScanPage> createState() => _PoeBulkScanPageState();
}

class _PoeBulkScanPageState extends State<PoeBulkScanPage> {
  final ImagePicker _picker = ImagePicker();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  List<File> _scannedImages = [];
  Set<String> _selectedQuestions = {};
  bool _isUploading = false;
  bool _selectAll = false;
  String _logbookText = '';

  @override
  void initState() {
    super.initState();
    // Automatically tag ALL questions - no manual selection needed
    _selectAll = true;
    _selectedQuestions = widget.questions
        .map((q) => q['exercise']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  Future<void> _scanDocument() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _scannedImages.add(File(image.path));
        });
        
        FingerprintErrorHandler.showSuccess(
          context,
          'Document scanned! Total: ${_scannedImages.length}',
        );
      }
    } catch (e) {
      FingerprintErrorHandler.showError(context, 'Failed to scan: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _scannedImages.addAll(images.map((img) => File(img.path)));
        });
        
        FingerprintErrorHandler.showSuccess(
          context,
          'Added ${images.length} documents! Total: ${_scannedImages.length}',
        );
      }
    } catch (e) {
      FingerprintErrorHandler.showError(context, 'Failed to add documents: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _scannedImages.removeAt(index);
    });
  }

  Future<void> _saveAndSync() async {
    if (_scannedImages.isEmpty) {
      FingerprintErrorHandler.showError(
        context,
        'Please scan at least one document',
      );
      return;
    }

    // All questions are automatically tagged - no need to check selection

    setState(() {
      _isUploading = true;
    });

    try {
      // Check connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult.first != ConnectivityResult.none;

      if (isOnline) {
        // ONLINE: Save locally first, then sync to server immediately
        debugPrint('[POE_BULK] Online - will save and sync to server');
        await _uploadToServer();
      } else {
        // OFFLINE: Save locally only
        debugPrint('[POE_BULK] Offline - saving locally only');
        await _saveLocally();
      }

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      debugPrint('[POE_BULK] Error: $e');
      FingerprintErrorHandler.showError(context, 'Failed to save: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _uploadToServer() async {
    try {
      // First save to local database
      await _saveToLocalDatabase(synced: 0);
      
      // Get the saved POE records
      final db = await _dbHelper.database;
      final unsyncedPoeRecords = await db.query(
        'poe',
        where: 'learnerID = ? AND synced = 0',
        whereArgs: [widget.learnerID],
      );
      
      int successCount = 0;
      int failCount = 0;
      
      // Sync each POE record using sync_PoeOnline.php
      for (final poeRecord in unsyncedPoeRecords) {
        final exercise = poeRecord['exercise']?.toString() ?? '';
        
        // Only sync records we just created (matching selected questions)
        if (!_selectedQuestions.contains(exercise)) {
          continue;
        }
        
        final syncSuccess = await _syncSinglePoeRecord(poeRecord);
        if (syncSuccess) {
          successCount++;
          // Mark as synced in local database
          await db.update(
            'poe',
            {'synced': 1},
            where: 'poe_id = ?',
            whereArgs: [poeRecord['poe_id']],
          );
        } else {
          failCount++;
        }
      }
      
      debugPrint('[POE_BULK] Sync complete: $successCount synced, $failCount failed');
      
      if (successCount > 0) {
        FingerprintErrorHandler.showSuccess(
          context,
          'POE synced! $successCount questions uploaded to server',
        );
      } else if (failCount > 0) {
        FingerprintErrorHandler.showInfo(
          context,
          'POE saved locally (${_selectedQuestions.length} questions). Will sync when online.',
        );
      }
      
    } catch (e) {
      debugPrint('[POE_BULK] Upload error: $e');
      // Already saved locally, just show info
      FingerprintErrorHandler.showInfo(
        context,
        'POE saved locally (${_selectedQuestions.length} questions). Will sync when online.',
      );
    }
  }
  
  Future<bool> _syncSinglePoeRecord(Map<String, dynamic> poeRecord) async {
    try {
      final url = Uri.parse(AppConfig.syncPoeOnlineUrl);
      final request = http.MultipartRequest('POST', url);
      
      // Add fields
      request.fields['learnerID'] = poeRecord['learnerID']?.toString() ?? '';
      request.fields['exercise'] = poeRecord['exercise']?.toString() ?? '';
      request.fields['type'] = poeRecord['type']?.toString() ?? '';
      request.fields['submitted_at'] = poeRecord['submitted_at']?.toString() ?? DateTime.now().toIso8601String();
      
      // Get file paths (comma-separated for multiple images)
      final filePaths = poeRecord['filePath']?.toString() ?? '';
      final pathList = filePaths.split(',').where((p) => p.isNotEmpty).toList();
      
      if (pathList.isEmpty || !File(pathList[0]).existsSync()) {
        debugPrint('[POE_BULK] No valid file for exercise ${poeRecord['exercise']}');
        return false;
      }
      
      // Use the first image file (sync_PoeOnline.php expects a single file)
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          pathList[0],
        ),
      );
      
      debugPrint('[POE_BULK] Syncing exercise ${poeRecord['exercise']} to server...');
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      debugPrint('[POE_BULK] Response (${response.statusCode}): $responseBody');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(responseBody);
        if (responseData['success'] == true) {
          debugPrint('[POE_BULK] ✅ Synced exercise ${poeRecord['exercise']}');
          return true;
        }
      }
      
      return false;
      
    } catch (e) {
      debugPrint('[POE_BULK] Error syncing POE record: $e');
      return false;
    }
  }

  Future<void> _saveLocally() async {
    await _saveToLocalDatabase(synced: 0);
    
    FingerprintErrorHandler.showInfo(
      context,
      'POE saved locally (${_selectedQuestions.length} questions). Will sync when online.',
    );
  }

  Future<void> _saveToLocalDatabase({required int synced}) async {
    try {
      final db = await _dbHelper.database;
      final timestamp = DateTime.now().toIso8601String();
      
      // Save scanned images to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final poeDir = Directory('${appDir.path}/POE');
      if (!poeDir.existsSync()) {
        poeDir.createSync(recursive: true);
      }

      List<String> savedPaths = [];
      for (int i = 0; i < _scannedImages.length; i++) {
        final fileName = 'poe_${widget.learnerID}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final savedPath = '${poeDir.path}/$fileName';
        await _scannedImages[i].copy(savedPath);
        savedPaths.add(savedPath);
      }

      // Create a single document path (first image or concatenated)
      final String documentPath = savedPaths.join(',');

      // Insert a record for each selected question with the same document
      final batch = db.batch();
      
      for (final exercise in _selectedQuestions) {
        batch.insert(
          'poe',
          {
            'learnerID': widget.learnerID,
            'exercise': exercise,
            'type': widget.assessmentType,
            'filePath': documentPath,
            'submitted_at': timestamp,
            'synced': synced,
            'logbook_text': widget.assessmentType == 'LogBook' ? _logbookText : '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit();
      
      debugPrint('[POE_BULK] Saved ${_selectedQuestions.length} questions with ${savedPaths.length} images (synced=$synced)');
    } catch (e) {
      debugPrint('[POE_BULK] Error saving to local database: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bulk POE - ${widget.assessmentType}'),
        backgroundColor: Colors.blue,
      ),
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading POE...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instructions Card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Scan documents once, tag multiple questions with the same evidence',
                              style: TextStyle(color: Colors.blue[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Scanned Documents Section
                  Text(
                    'Scanned Documents (${_scannedImages.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Scan Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _scanDocument,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Scan Document'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('From Gallery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Scanned Images Grid
                  if (_scannedImages.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _scannedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 100,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _scannedImages[index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Questions Summary (All Auto-Tagged)
                  Card(
                    color: Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700], size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'All ${widget.questions.length} Questions Tagged',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[900],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Scanned documents will be linked to all ${widget.questions.length} ${widget.assessmentType} questions',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Questions List (Read-only display)
                  Text(
                    'Questions to be tagged:',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Column(
                      children: widget.questions.map((question) {
                        final exercise = question['exercise']?.toString() ?? '';
                        final questionType = question['question_type']?.toString() ?? '';
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Question $exercise${questionType.isNotEmpty ? " - $questionType" : ""}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // LogBook Text Field (if LogBook type)
                  if (widget.assessmentType == 'LogBook') ...[
                    const Text(
                      'LogBook Entry',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Enter logbook details...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        _logbookText = value;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saveAndSync,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text(
                        'Save & Sync POE',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

