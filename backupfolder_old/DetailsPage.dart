import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';
import 'CameraScanPage.dart';
import 'services/fingerprint_service.dart';

import 'config.dart';

class DetailsPage extends StatelessWidget {
  final int learnerID;
  const DetailsPage({super.key, required this.learnerID});

  @override
  Widget build(BuildContext context) {
    print('DetailsPage initialized with learnerID: $learnerID');
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Learner Details'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Photo'),
              Tab(text: 'POE'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const Center(child: Text('Photo Tab Content')),
            POETabContent(learnerID: learnerID),
          ],
        ),
      ),
    );
  }
}

class POETabContent extends StatefulWidget {
  final int learnerID;
  const POETabContent({super.key, required this.learnerID});

  @override
  _POETabContentState createState() => _POETabContentState();
}

class _POETabContentState extends State<POETabContent> {
  Map<String, dynamic>? pathwaysData;
  bool isLoading = true;
  String errorMessage = '';
  Map<String, bool> uploadedExercises = {};
  List<Map<String, String>> exerciseSequence = []; // Fixed: Initialize as List
  Map<String, TextEditingController> logBookControllers = {};
  int unsyncedCount = 0;
  bool isSyncing = false;

  // Add class-level fingerprint service instances like in clock_in_page.dart
  final FingerprintService _fingerprintService = FingerprintService();
  final FutronicService _futronicService = FutronicService();

  @override
  void initState() {
    super.initState();
    if (widget.learnerID <= 0) {
      setState(() {
        errorMessage = 'Invalid learner ID: ${widget.learnerID}';
        isLoading = false;
      });
      return;
    }
    fetchLearnerData().then((_) {
      print(
          'fetchLearnerData completed. pathwaysData: $pathwaysData, exerciseSequence: $exerciseSequence');
    }).catchError((e) {
      print('Error in fetchLearnerData: $e');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh upload status when page is focused
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUploadStatus();
    });
  }

  Future<void> _refreshUploadStatus() async {
    try {
      // Store current state to preserve recently completed exercises
      final currentUploadedExercises =
          Map<String, bool>.from(uploadedExercises);

      // Update unsynced count
      await _updateUnsyncedCount();

      if (await _checkConnectivity()) {
        // Try to sync offline POE data first
        await _syncOfflinePOE();
        await checkUploadedStatus();
      } else {
        await checkLocalUploadedStatus();
      }

      // Ensure recently completed exercises are not lost
      setState(() {
        currentUploadedExercises.forEach((key, value) {
          if (value == true) {
            uploadedExercises[key] = true;
          }
        });
      });
    } catch (e) {
      print('Error refreshing upload status: $e');
    }
  }

  Future<void> _updateUnsyncedCount() async {
    try {
      final DatabaseHelper dbHelper = DatabaseHelper();
      final List<Map<String, dynamic>> unsynced =
          await dbHelper.getUnsyncedPOE(widget.learnerID);
      setState(() {
        unsyncedCount = unsynced.length;
      });
    } catch (e) {
      print('Error updating unsynced count: $e');
    }
  }

  Future<Map<String, dynamic>> _getLearnerInfoWithClockingDays() async {
    try {
      // Get learner basic info from local database
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final learnerResult = await db.query(
        'learnerdetails',
        where: 'LearnerID = ?',
        whereArgs: [widget.learnerID],
        limit: 1,
      );

      if (learnerResult.isEmpty) {
        return {};
      }

      final learnerInfo = Map<String, dynamic>.from(learnerResult.first);

      // Get clocking days count from server
      try {
        final url = AppConfig.getClockingDaysCountUrl;
        final uri = Uri.parse(url).replace(queryParameters: {
          'learner_id': widget.learnerID.toString(),
          'include_today': 'true',
        });

        final response =
            await http.get(uri).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            learnerInfo['clocking_days'] = data['data']['clocking_days'] ?? 0;
            learnerInfo['working_days'] = data['data']['working_days'] ?? 0;
          }
        }
      } catch (e) {
        print('Error fetching clocking days: $e');
        // Set defaults if server call fails
        learnerInfo['clocking_days'] = 0;
        learnerInfo['working_days'] = 0;
      }

      return learnerInfo;
    } catch (e) {
      print('Error getting learner info: $e');
      return {};
    }
  }

  Future<void> _syncOfflinePOE() async {
    if (isSyncing) return;

    setState(() {
      isSyncing = true;
    });

    try {
      final DatabaseHelper dbHelper = DatabaseHelper();
      final List<Map<String, dynamic>> unsyncedPOE =
          await dbHelper.getUnsyncedPOE(widget.learnerID);

      if (unsyncedPOE.isEmpty) {
        print('[POE_SYNC] No unsynced POE data to upload');
        setState(() {
          isSyncing = false;
          unsyncedCount = 0;
        });
        return;
      }

      print('[POE_SYNC] Found ${unsyncedPOE.length} unsynced POE records');
      int successCount = 0;
      int failCount = 0;

      for (var poe in unsyncedPOE) {
        final id = poe['id'] as int;
        final type = poe['type'] as String;
        final exercise = poe['exercise'] as String;
        final filePath = poe['filePath'] as String;
        final logbookText = poe['logbook_text'] as String?;

        // Check if file exists
        final file = File(filePath);
        if (!await file.exists()) {
          print('[POE_SYNC] File not found, skipping: $filePath');
          failCount++;
          continue;
        }

        try {
          final url = Uri.parse(AppConfig.buildUrl('save_metadata.php'));
          var request = http.MultipartRequest('POST', url)
            ..fields['learnerID'] = widget.learnerID.toString()
            ..fields['exercise'] = exercise
            ..fields['type'] = type;

          if (type == 'LogBook' && logbookText != null) {
            request.fields['logbook_text'] = logbookText;
          }

          request.files
              .add(await http.MultipartFile.fromPath('files[]', filePath));

          final response = await request.send().timeout(
                const Duration(seconds: 30),
                onTimeout: () => throw Exception('Upload timeout'),
              );

          final responseBody = await response.stream.bytesToString();
          final decoded = json.decode(responseBody);

          if (decoded['status'] == 'success') {
            // Mark as synced in database
            await dbHelper.markPOEAsSynced(id);
            successCount++;
            print('[POE_SYNC] ✅ Synced: $type - $exercise');
          } else {
            failCount++;
            print('[POE_SYNC] ❌ Server error: ${decoded['message']}');
          }
        } catch (e) {
          failCount++;
          print('[POE_SYNC] ❌ Upload failed: $e');
        }
      }

      await _updateUnsyncedCount();

      if (successCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Synced $successCount POE record(s) to server'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      if (failCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $failCount POE record(s) failed to sync'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      print('[POE_SYNC] Complete: $successCount synced, $failCount failed');
    } catch (e) {
      print('[POE_SYNC] Error during sync: $e');
    } finally {
      setState(() {
        isSyncing = false;
      });
    }
  }

  Future<void> _manualMarkAsUploaded(String type, String exercise) async {
    // Show confirmation dialog
    bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Mark as Uploaded'),
              content: Text(
                'Are you sure you want to mark this $type exercise as uploaded?\n\n'
                'Exercise: $exercise\n\n'
                'This will allow you to continue with other exercises, but make sure you have actually completed this exercise.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Mark as Uploaded'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirmed) {
      try {
        final dbHelper = DatabaseHelper();
        final timestamp = DateTime.now().toIso8601String();

        // Save a manual entry to local database with synced=1
        await dbHelper.saveManualMarkToLocalPoe(
            widget.learnerID, type, exercise, 'MANUALLY_MARKED_$timestamp');

        if (type == 'LogBook') {
          await dbHelper.saveLogBookText(widget.learnerID.toString(), type,
              exercise, 'Manually marked as completed on $timestamp');
        }

        // Update the UI state
        setState(() {
          final uploadKey = '$type-$exercise-${widget.learnerID}';
          uploadedExercises[uploadKey] = true;
        });

        // Refresh upload status
        await _refreshUploadStatus();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $type exercise "$exercise" marked as uploaded'),
            backgroundColor: Colors.green,
          ),
        );

        print('Manual mark as uploaded: $type-$exercise-${widget.learnerID}');
      } catch (e) {
        print('Error manually marking as uploaded: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as uploaded: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Manual mark all formative questions
  Future<void> _manualMarkAllFormative(BuildContext context,
      List<dynamic> formativeQuestions, String unitStandard) async {
    print(
        'DEBUG: _manualMarkAllFormative called for unitStandard: $unitStandard');
    print('DEBUG: formativeQuestions count: ${formativeQuestions.length}');

    // Check how many questions are not yet completed
    List<String> pendingQuestions = [];
    for (var item in formativeQuestions) {
      final exercise = item['exercise']?.toString() ?? 'N/A';
      final uploadKey = 'Formative-$exercise-${widget.learnerID}';
      if (!(uploadedExercises[uploadKey] ?? false)) {
        pendingQuestions.add(exercise);
      }
    }

    if (pendingQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All formative questions are already completed.')),
      );
      return;
    }

    // Show confirmation dialog
    bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Manual Mark All Formative'),
              content: Text(
                'Are you sure you want to manually mark all pending formative questions as uploaded?\n\n'
                'Unit Standard: $unitStandard\n'
                'Pending Questions: ${pendingQuestions.length}\n\n'
                'This will mark all remaining questions as completed without scanning documents.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Mark All as Uploaded'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    try {
      final dbHelper = DatabaseHelper();
      int markedCount = 0;

      print(
          'Starting manual mark all for ${pendingQuestions.length} formative questions');

      // First, try to find an existing document from a completed formative question
      String? existingDocumentPath = await dbHelper.getExistingDocumentPath(
          widget.learnerID, 'Formative', unitStandard);

      print('Using existing document: $existingDocumentPath');

      // Apply the existing document to all pending questions
      for (var item in formativeQuestions) {
        final exercise = item['exercise']?.toString() ?? 'N/A';
        final uploadKey = 'Formative-$exercise-${widget.learnerID}';

        // Only mark if not already completed
        if (!(uploadedExercises[uploadKey] ?? false)) {
          // Use the same document path from the existing scan
          await dbHelper.saveManualMarkToLocalPoe(
              widget.learnerID,
              'Formative',
              exercise,
              existingDocumentPath ?? '' // Use the actual scanned document
              );

          setState(() {
            uploadedExercises[uploadKey] = true;
          });

          markedCount++;
          print(
              '✅ Linked formative exercise to existing document: $exercise ($markedCount/${pendingQuestions.length})');
        }
      }

      // Refresh upload status to update UI
      await _refreshUploadStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Linked $markedCount formative questions to existing scanned document'),
          backgroundColor: Colors.green,
        ),
      );

      print(
          'Manual mark all formative complete: $markedCount questions linked to document: $existingDocumentPath');
    } catch (e, stackTrace) {
      print('Error in _manualMarkAllFormative: $e\nStackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  // Manual mark all logbook items
  Future<void> _manualMarkAllLogBook(BuildContext context,
      List<dynamic> logBookItems, String unitStandard) async {
    print(
        'DEBUG: _manualMarkAllLogBook called for unitStandard: $unitStandard');
    print('DEBUG: logBookItems count: ${logBookItems.length}');

    // Check how many logbook items are not yet completed
    List<String> pendingItems = [];
    for (var item in logBookItems) {
      final exercise = item['exercise']?.toString() ?? 'N/A';
      final uploadKey = 'LogBook-$exercise-${widget.learnerID}';
      if (!(uploadedExercises[uploadKey] ?? false)) {
        pendingItems.add(exercise);
      }
    }

    if (pendingItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All logbook items are already completed.')),
      );
      return;
    }

    // Show confirmation dialog
    bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Manual Mark All LogBook'),
              content: Text(
                'Are you sure you want to manually mark all pending logbook items as uploaded?\n\n'
                'Unit Standard: $unitStandard\n'
                'Pending Items: ${pendingItems.length}\n\n'
                'This will mark all remaining logbook items as completed without scanning documents.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Mark All as Uploaded'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    try {
      final dbHelper = DatabaseHelper();
      int markedCount = 0;

      print(
          'Starting manual mark all for ${pendingItems.length} logbook items');

      // First, try to find an existing document from a completed logbook item
      String? existingDocumentPath = await dbHelper.getExistingDocumentPath(
          widget.learnerID, 'LogBook', unitStandard);

      print('Using existing document: $existingDocumentPath');

      // Apply the existing document to all pending logbook items
      for (var item in logBookItems) {
        final exercise = item['exercise']?.toString() ?? 'N/A';
        final uploadKey = 'LogBook-$exercise-${widget.learnerID}';

        // Only mark if not already completed
        if (!(uploadedExercises[uploadKey] ?? false)) {
          // Use the same document path from the existing scan
          await dbHelper.saveManualMarkToLocalPoe(
              widget.learnerID,
              'LogBook',
              exercise,
              existingDocumentPath ?? '' // Use the actual scanned document
              );

          // Also save logbook text
          await dbHelper.saveLogBookText(
              widget.learnerID.toString(),
              'LogBook',
              exercise,
              'Logbook entry for $exercise - $unitStandard (manually marked)');

          setState(() {
            uploadedExercises[uploadKey] = true;
          });

          markedCount++;
          print(
              '✅ Linked logbook item to existing document: $exercise ($markedCount/${pendingItems.length})');
        }
      }

      // Refresh upload status to update UI
      await _refreshUploadStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Linked $markedCount logbook items to existing scanned document'),
          backgroundColor: Colors.green,
        ),
      );

      print(
          'Manual mark all logbook complete: $markedCount items linked to document: $existingDocumentPath');
    } catch (e, stackTrace) {
      print('Error in _manualMarkAllLogBook: $e\nStackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  // Manual mark all summative questions
  Future<void> _manualMarkAllSummative(BuildContext context,
      List<dynamic> summativeQuestions, String unitStandard) async {
    print(
        'DEBUG: _manualMarkAllSummative called for unitStandard: $unitStandard');
    print('DEBUG: summativeQuestions count: ${summativeQuestions.length}');

    // Check how many questions are not yet completed
    List<String> pendingQuestions = [];
    for (var item in summativeQuestions) {
      final exercise = item['exercise']?.toString() ?? 'N/A';
      final uploadKey = 'Summative-$exercise-${widget.learnerID}';
      if (!(uploadedExercises[uploadKey] ?? false)) {
        pendingQuestions.add(exercise);
      }
    }

    if (pendingQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All summative questions are already completed.')),
      );
      return;
    }

    // Show confirmation dialog
    bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Manual Mark All Summative'),
              content: Text(
                'Are you sure you want to manually mark all pending summative questions as uploaded?\n\n'
                'Unit Standard: $unitStandard\n'
                'Pending Questions: ${pendingQuestions.length}\n\n'
                'This will mark all remaining questions as completed without scanning documents.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Mark All as Uploaded'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    try {
      final dbHelper = DatabaseHelper();
      int markedCount = 0;

      print(
          'Starting manual mark all for ${pendingQuestions.length} summative questions');

      // First, try to find an existing document from a completed summative question
      String? existingDocumentPath = await dbHelper.getExistingDocumentPath(
          widget.learnerID, 'Summative', unitStandard);

      print('Using existing document: $existingDocumentPath');

      // Apply the existing document to all pending questions
      for (var item in summativeQuestions) {
        final exercise = item['exercise']?.toString() ?? 'N/A';
        final uploadKey = 'Summative-$exercise-${widget.learnerID}';

        // Only mark if not already completed
        if (!(uploadedExercises[uploadKey] ?? false)) {
          // Use the same document path from the existing scan
          await dbHelper.saveManualMarkToLocalPoe(
              widget.learnerID,
              'Summative',
              exercise,
              existingDocumentPath ?? '' // Use the actual scanned document
              );

          setState(() {
            uploadedExercises[uploadKey] = true;
          });

          markedCount++;
          print(
              '✅ Linked summative exercise to existing document: $exercise ($markedCount/${pendingQuestions.length})');
        }
      }

      // Refresh upload status to update UI
      await _refreshUploadStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Linked $markedCount summative questions to existing scanned document'),
          backgroundColor: Colors.green,
        ),
      );

      print(
          'Manual mark all summative complete: $markedCount questions linked to document: $existingDocumentPath');
    } catch (e, stackTrace) {
      print('Error in _manualMarkAllSummative: $e\nStackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  Future<File?> _compressImage(File file) async {
    print(
        'Starting compression for: ${file.path}, original size: ${await file.length()} bytes');
    if (!await file.exists()) {
      print('Error: Input file does not exist at ${file.path}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Image file not found. Please try again.')),
      );
      return null;
    }

    if (file.path.toLowerCase().endsWith('.pdf')) {
      print('Skipping compression for PDF file: ${file.path}');
      return file;
    }

    final dir = await Directory.systemTemp.createTemp();
    String targetPath =
        '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    int quality = 30;
    int minWidth = 400;
    int minHeight = 400;
    const int maxSizeBytes = 2 * 1024 * 1024;

    File? currentFile = file;
    int currentSize = await currentFile.length();

    while (currentSize > maxSizeBytes && quality >= 10) {
      try {
        final result = await FlutterImageCompress.compressAndGetFile(
          currentFile!.path,
          targetPath,
          quality: quality,
          minWidth: minWidth,
          minHeight: minHeight,
        );
        if (result == null) {
          print('Compression failed at quality: $quality');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Image compression failed. Please try a different image.')),
          );
          return null;
        }
        currentFile = File(result.path);
        currentSize = await currentFile.length();
        print('Compressed size at quality $quality: $currentSize bytes');
        quality -= 5;
        targetPath =
            '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      } catch (e) {
        print('Compression error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to compress image. Please try again.')),
        );
        return null;
      }
    }

    if (currentFile == null) {
      print('Error: No valid file after compression');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Image compression failed. Please try again.')),
      );
      return null;
    }

    if (currentSize > maxSizeBytes) {
      print('Image too large after compression: $currentSize bytes');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Image too large after compression. Please select a smaller image.')),
      );
      return null;
    }

    print(
        'Compression successful: ${currentFile.path}, size: $currentSize bytes');
    return currentFile;
  }

  Future<File?> _createPdfFromImage(File image, String heading,
      {String? logbookText}) async {
    try {
      print('Starting PDF creation for image: ${image.path}');
      if (!await image.exists()) {
        print('Error: Image file does not exist at ${image.path}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Image file not found. Please try again.')),
        );
        return null;
      }

      final imageSize = await image.length();
      print('Image size: $imageSize bytes');
      if (imageSize == 0) {
        print('Error: Image file is empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Image file is empty. Please select a valid image.')),
        );
        return null;
      }

      final extension = image.path.toLowerCase().split('.').last;
      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        print('Error: Unsupported image format: $extension');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unsupported image format. Use JPG or PNG.')),
        );
        return null;
      }

      List<int> imageBytes;
      try {
        imageBytes = await image.readAsBytes();
      } catch (e) {
        print('Error reading image bytes: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to read image data. Please try again.')),
        );
        return null;
      }
      print('Image bytes length: ${imageBytes.length}');
      if (imageBytes.isEmpty) {
        print('Error: Empty image bytes');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Image data is empty. Please select a valid image.')),
        );
        return null;
      }

      final pdfImage = pw.MemoryImage(Uint8List.fromList(imageBytes));

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                heading,
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Image(pdfImage, fit: pw.BoxFit.contain),
              if (logbookText != null && logbookText.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Log Book Entry:',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  logbookText,
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      );

      final dir = await getTemporaryDirectory();
      print('Saving PDF to: ${dir.path}');
      final pdfPath =
          '${dir.path}/document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfFile = File(pdfPath);
      final pdfBytes = await pdf.save();
      print('PDF bytes length: ${pdfBytes.length}');
      try {
        await pdfFile.writeAsBytes(pdfBytes);
      } catch (e) {
        print('Error writing PDF: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save PDF file. Please try again.')),
        );
        return null;
      }

      final pdfSize = await pdfFile.length();
      print('Generated PDF size: $pdfSize bytes');
      if (pdfSize > 2 * 1024 * 1024) {
        print('PDF exceeds 2MB: $pdfSize bytes');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Generated PDF too large. Please use a smaller image.')),
        );
        return null;
      }

      print('PDF created successfully: ${pdfFile.path}');
      return pdfFile;
    } catch (e, stackTrace) {
      print('PDF generation error: $e\nStackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
      return null;
    }
  }

  Future<void> fetchLearnerData() async {
    print(
        '[FETCH] Starting fetchLearnerData for learnerID=${widget.learnerID}');
    bool isConnected = await _checkConnectivity();
    print('[FETCH] Connectivity check: ${isConnected ? "ONLINE" : "OFFLINE"}');

    if (isConnected) {
      print('[FETCH] Attempting online fetch...');
      bool onlineSuccess = await fetchOnlineLearnerData();
      if (onlineSuccess) {
        print('[FETCH] ✅ Online fetch successful, checking upload status...');
        await checkUploadedStatus();
      } else {
        // If online fetch failed, try offline
        print('[FETCH] ❌ Online fetch failed, trying offline data...');
        await fetchOfflineLearnerData();
        await checkLocalUploadedStatus();
      }
    } else {
      print('[FETCH] Device is offline, loading from cache...');
      await fetchOfflineLearnerData();
      await checkLocalUploadedStatus();
    }
    _buildExerciseSequence();
    print('[FETCH] fetchLearnerData complete');
  }

  Future<bool> fetchOnlineLearnerData() async {
    final url = Uri.parse(AppConfig.buildUrl('poe.php'));
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'learnerID': widget.learnerID.toString()},
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Request timed out');
      });
      print(
          'API Request: learnerID=${widget.learnerID}, statusCode=${response.statusCode}, url=$url');
      print('Response body: ${response.body}');
      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        print('Decoded Response: $decodedResponse');
        if (decodedResponse.containsKey('error')) {
          setState(() {
            errorMessage = decodedResponse['error'] ?? 'Unknown API error';
            if (decodedResponse['debug']?['learnerID_exists'] == false) {
              errorMessage =
                  'Learner ID ${widget.learnerID} not found in database.';
            }
            isLoading = false;
            pathwaysData = null;
          });
          print('API Error: ${decodedResponse['error']}');
          return false;
        }
        if (decodedResponse['pathways'] != null &&
            decodedResponse['pathways'] is Map) {
          final pathways =
              Map<String, dynamic>.from(decodedResponse['pathways']);

          // Save to local database for offline access
          await _saveLearnerDataLocally(pathways);

          setState(() {
            pathwaysData = pathways;
            isLoading = false;
            print('Assigned pathwaysData: $pathwaysData');
          });
          return true;
        } else {
          setState(() {
            errorMessage = 'No pathways data available for this learner.';
            isLoading = false;
            pathwaysData = null;
          });
          print('No valid pathways data in response');
          return false;
        }
      } else {
        setState(() {
          errorMessage = 'Server error: ${response.statusCode}';
          isLoading = false;
        });
        print('Server error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error retrieving data: $e';
        isLoading = false;
      });
      print('Error: $e');
      return false;
    }
    return false; // Default return for any unhandled cases
  }

  Future<void> _saveLearnerDataLocally(Map<String, dynamic> pathways) async {
    try {
      print(
          '[OFFLINE_CACHE] Starting to save learner data for learnerID=${widget.learnerID}');
      print('[OFFLINE_CACHE] Pathways data keys: ${pathways.keys}');

      final DatabaseHelper dbHelper = DatabaseHelper();
      // Save the pathways JSON as a cached response for offline use
      await dbHelper.saveLearnerPathwaysCache(widget.learnerID, pathways);

      print(
          '[OFFLINE_CACHE] ✅ Successfully saved learner pathway data for offline access');
      print(
          '[OFFLINE_CACHE] Data size: ${pathways.toString().length} characters');
    } catch (e, stackTrace) {
      print('[OFFLINE_CACHE] ❌ Error saving learner data locally: $e');
      print('[OFFLINE_CACHE] Stack trace: $stackTrace');
    }
  }

  Future<void> fetchOfflineLearnerData() async {
    try {
      print(
          '[OFFLINE_CACHE] Attempting to load cached data for learnerID=${widget.learnerID}');
      final DatabaseHelper dbHelper = DatabaseHelper();

      // First try to get cached pathways data (simpler and faster)
      final Map<String, dynamic>? cachedPathways =
          await dbHelper.getLearnerPathwaysCache(widget.learnerID);

      if (cachedPathways != null) {
        print('[OFFLINE_CACHE] ✅ Found cached pathway data!');
        print(
            '[OFFLINE_CACHE] Cache has ${cachedPathways.keys.length} pathway(s)');
        setState(() {
          pathwaysData = cachedPathways;
          isLoading = false;

          // Initialize logbook controllers from cached data
          pathwaysData?.forEach((pathwayName, pathwayData) {
            (pathwayData['qualifications'] as Map?)
                ?.forEach((qualificationName, qualData) {
              (qualData['unitstandards'] as Map?)
                  ?.forEach((unitStandardName, unitData) {
                final logbook = unitData['logbook'] ?? [];
                for (var item in logbook) {
                  final exercise = item['exercise']?.toString() ?? 'N/A';
                  final key = 'LogBook-$exercise-${widget.learnerID}';
                  if (!logBookControllers.containsKey(key)) {
                    logBookControllers[key] =
                        TextEditingController(text: item['logbook_text'] ?? '');
                  }
                }
              });
            });
          });
        });
        return;
      }

      // Fallback to complex database query if no cache exists
      print('[OFFLINE_CACHE] No cached data, trying database query...');
      final localData = await dbHelper.getLearnerData(widget.learnerID);
      print('Local data retrieved: ${localData.length} records');

      if (localData.isNotEmpty) {
        Map<String, dynamic> structuredData = {};

        for (var row in localData) {
          final Map<String, dynamic> typedRow =
              (row as Map).map((key, value) => MapEntry(key.toString(), value));

          String pathwayName =
              typedRow['pathway_name']?.toString() ?? 'Unknown Pathway';
          String qualificationName =
              typedRow['qualification_name']?.toString() ??
                  'Unknown Qualification';
          String unitStandardName =
              typedRow['unit_standard_name']?.toString() ??
                  'Unknown Unit Standard';
          String logBookText = typedRow['logbook_text']?.toString() ?? '';

          structuredData.putIfAbsent(pathwayName,
              () => <String, dynamic>{'qualifications': <String, dynamic>{}});
          final qualifications = structuredData[pathwayName]['qualifications']
              as Map<String, dynamic>;
          qualifications.putIfAbsent(qualificationName,
              () => <String, dynamic>{'unitstandards': <String, dynamic>{}});
          final unitStandards = qualifications[qualificationName]
              ['unitstandards'] as Map<String, dynamic>;
          unitStandards.putIfAbsent(
              unitStandardName,
              () => <String, dynamic>{
                    'formative': <Map<String, String>>[],
                    'summative': <Map<String, String>>[],
                    'logbook': <Map<String, String>>[],
                  });

          if (typedRow.containsKey('assessments') &&
              typedRow['assessments'] != null) {
            final assessments = typedRow['assessments'] as Map<String, dynamic>;

            print('Processing assessments for $unitStandardName:');
            print('  Formative: ${assessments['formative']?.length ?? 0}');
            print('  Summative: ${assessments['summative']?.length ?? 0}');
            print('  Logbook: ${assessments['logbook']?.length ?? 0}');

            if (assessments['formative'] != null) {
              final formativeList = unitStandards[unitStandardName]['formative']
                  as List<Map<String, String>>;
              assessments['formative'].forEach((assessment) {
                final entry = {
                  'exercise': assessment['exercise']?.toString() ?? 'N/A',
                  'question_number':
                      assessment['question_number']?.toString() ?? 'N/A',
                };
                bool isDuplicate = formativeList.any(
                  (a) =>
                      a['question_number'] == entry['question_number'] &&
                      a['exercise'] == entry['exercise'],
                );
                if (!isDuplicate) {
                  formativeList.add(entry);
                }
              });
            }

            if (assessments['summative'] != null) {
              final summativeList = unitStandards[unitStandardName]['summative']
                  as List<Map<String, String>>;
              assessments['summative'].forEach((assessment) {
                final entry = {
                  'exercise': assessment['exercise']?.toString() ?? 'N/A',
                  'question_number':
                      assessment['question_number']?.toString() ?? 'N/A',
                };
                bool isDuplicate = summativeList.any(
                  (a) =>
                      a['question_number'] == entry['question_number'] &&
                      a['exercise'] == entry['exercise'],
                );
                if (!isDuplicate) {
                  summativeList.add(entry);
                }
              });
            }

            if (assessments['logbook'] != null) {
              final logbookList = unitStandards[unitStandardName]['logbook']
                  as List<Map<String, String>>;
              assessments['logbook'].forEach((assessment) {
                final entry = {
                  'exercise': assessment['exercise']?.toString() ?? 'N/A',
                  'question_number':
                      assessment['question_number']?.toString() ?? 'N/A',
                  'logbook_text': logBookText,
                };
                bool isDuplicate = logbookList.any(
                  (a) =>
                      a['question_number'] == entry['question_number'] &&
                      a['exercise'] == entry['exercise'],
                );
                if (!isDuplicate) {
                  logbookList.add(entry);
                  print(
                      'Added logbook entry: ${entry['exercise']}, ${entry['question_number']}');
                }
              });
            }
          } else {
            String assessmentType =
                typedRow['assessment_type']?.toString().toLowerCase() ??
                    'unknown';
            String questionNumber =
                typedRow['question_number']?.toString() ?? 'N/A';
            String exercise = typedRow['exercise']?.toString() ?? 'N/A';

            print(
                'Fallback processing: $assessmentType assessment for $unitStandardName');

            if (assessmentType == 'formative' ||
                assessmentType == 'summative' ||
                assessmentType == 'logbook') {
              final assessmentList = unitStandards[unitStandardName]
                  [assessmentType] as List<Map<String, String>>;
              bool isDuplicate = assessmentList.any(
                (a) =>
                    a['question_number'] == questionNumber &&
                    a['exercise'] == exercise,
              );
              if (!isDuplicate) {
                final entry = {
                  'exercise': exercise,
                  'question_number': questionNumber,
                };
                if (assessmentType == 'logbook') {
                  entry['logbook_text'] = logBookText;
                }
                assessmentList.add(entry);
              } else {
                print(
                    'Duplicate assessment skipped: unit_standard_name=$unitStandardName, question_number=$questionNumber, exercise=$exercise');
              }
            }
          }
        }

        print('\nFinal structured data:');
        structuredData.forEach((pathwayName, pathwayData) {
          print('Pathway: $pathwayName');
          (pathwayData['qualifications'] as Map)
              .forEach((qualificationName, qualData) {
            print('  Qualification: $qualificationName');
            (qualData['unitstandards'] as Map)
                .forEach((unitStandardName, unitData) {
              print('    Unit Standard: $unitStandardName');
              print('      Formative: ${unitData['formative']?.length ?? 0}');
              print('      Summative: ${unitData['summative']?.length ?? 0}');
              print('      Logbook: ${unitData['logbook']?.length ?? 0}');
            });
          });
        });

        setState(() {
          pathwaysData = structuredData;
          isLoading = false;

          pathwaysData?.forEach((pathwayName, pathwayData) {
            (pathwayData['qualifications'] as Map)
                .forEach((qualificationName, qualData) {
              (qualData['unitstandards'] as Map)
                  .forEach((unitStandardName, unitData) {
                final logbook = unitData['logbook'] ?? [];
                print(
                    'Setting up controllers for $unitStandardName logbook entries: ${logbook.length}');
                for (var item in logbook) {
                  final exercise = item['exercise']?.toString() ?? 'N/A';
                  final key = 'LogBook-$exercise-${widget.learnerID}';
                  logBookControllers[key] =
                      TextEditingController(text: item['logbook_text'] ?? '');
                  print(
                      'Created controller for key: $key with text: "${item['logbook_text'] ?? ''}"');
                }
              });
            });
          });
        });
      } else {
        setState(() {
          errorMessage =
              'No offline data available.\n\nTo use offline POE functionality:\n1. Connect to internet\n2. Open this learner\'s POE tab\n3. Data will be cached automatically\n\nThen you can work offline.';
          isLoading = false;
          pathwaysData = null;
        });
        print(
            '[OFFLINE_CACHE] No cached or local data for learnerID: ${widget.learnerID}');
        print(
            '[OFFLINE_CACHE] User must load data online first to enable offline access');
      }
    } catch (e) {
      print('Error in fetchOfflineLearnerData: $e');
      setState(() {
        errorMessage = 'Error fetching offline data: $e';
        isLoading = false;
      });
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

  Future<void> checkUploadedStatus() async {
    try {
      final url = Uri.parse(AppConfig.buildUrl('check_uploads.php'));
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'learnerID': widget.learnerID.toString()},
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Request timed out');
      });

      print(
          'checkUploadedStatus Request: learnerID=${widget.learnerID}, statusCode=${response.statusCode}, url=$url');
      print('Raw response: ${response.body}');

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        if (decodedResponse is Map<String, dynamic>) {
          if (decodedResponse.containsKey('error')) {
            setState(() {
              errorMessage = decodedResponse['error'];
            });
            print('checkUploadedStatus Error: ${decodedResponse['error']}');
          } else {
            // Get local status first to preserve locally-saved records
            final dbHelper = DatabaseHelper();
            final localStatus = await dbHelper
                .getLocalUploadStatus(widget.learnerID.toString());

            // Merge server status with local status
            // Local status takes precedence to preserve completed exercises
            final serverStatus = decodedResponse
                .map((key, value) => MapEntry(key, value as bool));

            setState(() {
              // Start with server status
              uploadedExercises = Map.from(serverStatus);
              // Overlay local status (includes unsynced records and completed exercises)
              uploadedExercises.addAll(localStatus);
            });

            print(
                'Merged uploadedExercises: ${uploadedExercises.length} total (${serverStatus.length} from server, ${localStatus.length} from local)');
            print('Server status keys: ${serverStatus.keys.toList()}');
            print('Local status keys: ${localStatus.keys.toList()}');
            print('Final merged keys: ${uploadedExercises.keys.toList()}');
          }
        } else if (decodedResponse is List && decodedResponse.isEmpty) {
          // Server has no records, but check local database
          final dbHelper = DatabaseHelper();
          final localStatus =
              await dbHelper.getLocalUploadStatus(widget.learnerID.toString());

          setState(() {
            uploadedExercises = localStatus;
          });
          print(
              'Server empty, using local status: ${uploadedExercises.length} exercises');
        } else {
          setState(() {
            errorMessage = 'Unexpected response format from  .php';
          });
          print('Unexpected response format: $decodedResponse');
        }
      } else {
        setState(() {
          errorMessage = 'Server error: ${response.statusCode}';
        });
        print('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error checking upload status: $e';
      });
      print('Error checking upload status: $e');
    }
  }

  Future<void> checkLocalUploadedStatus() async {
    try {
      final dbHelper = DatabaseHelper();
      final localUploads =
          await dbHelper.getLocalUploadStatus(widget.learnerID.toString());
      setState(() {
        uploadedExercises = localUploads;
      });
      print('Local uploadedExercises: $uploadedExercises');
    } catch (e) {
      setState(() {
        errorMessage = 'Error checking local upload status: $e';
      });
      print('Error checking local upload status: $e');
    }
  }

  void _buildExerciseSequence() {
    exerciseSequence.clear();
    if (pathwaysData != null) {
      pathwaysData!.forEach((pathwayName, pathwayData) {
        if (pathwayData['qualifications'] != null) {
          (pathwayData['qualifications'] as Map)
              .forEach((qualificationName, qualData) {
            if (qualData['unitstandards'] != null) {
              (qualData['unitstandards'] as Map)
                  .forEach((unitStandardName, unitData) {
                final formative = unitData['formative'] ?? [];
                for (var item in formative) {
                  final exercise = item['exercise']?.toString() ?? 'N/A';
                  exerciseSequence.add({
                    'type': 'Formative',
                    'exercise': exercise,
                    'key': 'Formative-$exercise-${widget.learnerID}',
                    'unitStandard': unitStandardName,
                  });
                }
                final summative = unitData['summative'] ?? [];
                for (var item in summative) {
                  final exercise = item['exercise']?.toString() ?? 'N/A';
                  exerciseSequence.add({
                    'type': 'Summative',
                    'exercise': exercise,
                    'key': 'Summative-$exercise-${widget.learnerID}',
                    'unitStandard': unitStandardName,
                  });
                }
                final logbook = unitData['logbook'] ?? [];
                for (var item in logbook) {
                  final exercise = item['exercise']?.toString() ?? 'N/A';
                  exerciseSequence.add({
                    'type': 'LogBook',
                    'exercise': exercise,
                    'key': 'LogBook-$exercise-${widget.learnerID}',
                    'unitStandard': unitStandardName,
                  });
                }
              });
            }
          });
        }
      });
      print('Exercise Sequence: $exerciseSequence');
    } else {
      print('pathwaysData is null in _buildExerciseSequence');
    }
  }

  bool _isExerciseAllowed(String type, String exercise) {
    final currentKey = '$type-$exercise-${widget.learnerID}';
    print(
        'DEBUG: _isExerciseAllowed called for type: $type, exercise: $exercise');
    print('DEBUG: currentKey: $currentKey');
    print('DEBUG: exerciseSequence length: ${exerciseSequence.length}');
    print('DEBUG: uploadedExercises: $uploadedExercises');

    // If this exercise is already completed, don't allow re-upload
    if (uploadedExercises[currentKey] == true) {
      print('DEBUG: Exercise already completed: $currentKey');
      return false;
    }

    // If exercise sequence is empty, allow the first exercise
    if (exerciseSequence.isEmpty) {
      print('DEBUG: Exercise sequence is empty, allowing if not uploaded');
      return !(uploadedExercises[currentKey] ?? false);
    }

    // Check if this is the first exercise in the sequence
    if (exerciseSequence.isNotEmpty &&
        exerciseSequence[0]['key'] == currentKey) {
      print('DEBUG: This is the first exercise in sequence');
      return !(uploadedExercises[currentKey] ?? false);
    }

    // Find the current exercise in the sequence
    int currentIndex =
        exerciseSequence.indexWhere((e) => e['key'] == currentKey);
    print('DEBUG: currentIndex in sequence: $currentIndex');

    // If exercise not found in sequence, allow it (might be first unit standard)
    if (currentIndex == -1) {
      // Check if this is the first unit standard by looking at the exercise name
      // or if no exercises have been completed yet
      bool anyExercisesCompleted =
          uploadedExercises.values.any((completed) => completed);
      print(
          'DEBUG: Exercise not in sequence, anyExercisesCompleted: $anyExercisesCompleted');
      if (!anyExercisesCompleted) {
        print('DEBUG: No exercises completed yet, allowing this exercise');
        return !(uploadedExercises[currentKey] ?? false);
      }
      print('DEBUG: Some exercises completed, not allowing this exercise');
      return false; // Exercise not in sequence and some exercises are completed
    }

    // If it's the first exercise in the sequence
    if (currentIndex == 0) {
      print('DEBUG: This is the first exercise in sequence (index 0)');
      return !(uploadedExercises[currentKey] ?? false);
    }

    // Special handling for Summative exercises
    if (type == 'Summative') {
      print(
          'DEBUG: This is a Summative exercise, checking formative completion');

      // Find the unit standard for this exercise
      String? currentUnitStandard;
      for (var seq in exerciseSequence) {
        if (seq['key'] == currentKey) {
          currentUnitStandard = seq['unitStandard']?.toString();
          break;
        }
      }

      if (currentUnitStandard != null) {
        // Check if all formative exercises in this unit standard are completed
        bool allFormativeCompleted = true;
        for (var seq in exerciseSequence) {
          if (seq['type'] == 'Formative' &&
              seq['unitStandard']?.toString() == currentUnitStandard) {
            String formativeKey = seq['key']!.toString();
            if (!(uploadedExercises[formativeKey] ?? false)) {
              allFormativeCompleted = false;
              print('DEBUG: Formative exercise not completed: $formativeKey');
              break;
            }
          }
        }

        bool currentNotCompleted = !(uploadedExercises[currentKey] ?? false);
        print(
            'DEBUG: allFormativeCompleted: $allFormativeCompleted, currentNotCompleted: $currentNotCompleted');
        return allFormativeCompleted && currentNotCompleted;
      }
    }

    // For Formative and LogBook exercises, check if the previous one is completed
    // But allow the first exercise of a new unit standard
    final previousKey = exerciseSequence[currentIndex - 1]['key']!;
    final previousExercise = exerciseSequence[currentIndex - 1];
    final currentExercise = exerciseSequence[currentIndex];

    // Check if this is the first exercise of a new unit standard
    bool isFirstExerciseOfNewUnit = false;
    if (previousExercise['unitStandard'] != currentExercise['unitStandard']) {
      isFirstExerciseOfNewUnit = true;
      print('DEBUG: This is the first exercise of a new unit standard');
    }

    // For formative exercises within the same unit standard, allow them in any order
    if (type == 'Formative' && !isFirstExerciseOfNewUnit) {
      // Check if we're still in the same unit standard
      if (previousExercise['unitStandard'] == currentExercise['unitStandard']) {
        print(
            'DEBUG: Formative exercise in same unit standard - allowing if not completed');
        bool currentNotCompleted = !(uploadedExercises[currentKey] ?? false);
        return currentNotCompleted;
      }
    }

    // Special case: Allow any exercise within the same unit standard if some exercises in that unit are already completed
    // This handles cases where "Scan All" partially succeeded
    String? currentUnitStandard;
    for (var seq in exerciseSequence) {
      if (seq['key'] == currentKey) {
        currentUnitStandard = seq['unitStandard']?.toString();
        break;
      }
    }

    if (currentUnitStandard != null) {
      // Check if any exercise in this unit standard is already completed
      bool anyInUnitCompleted = false;
      for (var seq in exerciseSequence) {
        if (seq['unitStandard']?.toString() == currentUnitStandard) {
          String seqKey = seq['key']!.toString();
          if (uploadedExercises[seqKey] == true) {
            anyInUnitCompleted = true;
            break;
          }
        }
      }

      if (anyInUnitCompleted) {
        print(
            'DEBUG: Some exercises in unit $currentUnitStandard already completed, allowing $type-$exercise');
        return true;
      }
    }

    print('DEBUG: Checking previous exercise: $previousKey');
    bool previousCompleted = uploadedExercises[previousKey] ?? false;
    bool currentNotCompleted = !(uploadedExercises[currentKey] ?? false);
    print(
        'DEBUG: previousCompleted: $previousCompleted, currentNotCompleted: $currentNotCompleted, isFirstExerciseOfNewUnit: $isFirstExerciseOfNewUnit');

    // If this is the first exercise of a new unit standard, allow it if not completed
    if (isFirstExerciseOfNewUnit) {
      return currentNotCompleted;
    }

    // Otherwise, check if the previous exercise is completed
    return previousCompleted && currentNotCompleted;
  }

  // New method to determine if this exercise should show the camera icon
  bool _shouldShowCameraIcon(
      String type, String exercise, String unitStandard) {
    // Find the next available exercise in the sequence
    String? nextAvailableExercise = _getNextAvailableExercise();

    if (nextAvailableExercise == null) {
      // All exercises are completed
      return false;
    }

    // Check if this exercise is the next available one
    final currentKey = '$type-$exercise-${widget.learnerID}';
    return currentKey == nextAvailableExercise;
  }

  // Method to get the next available exercise in the sequence
  String? _getNextAvailableExercise() {
    if (exerciseSequence.isEmpty) return null;

    for (var exercise in exerciseSequence) {
      final key = exercise['key'] as String;
      if (!(uploadedExercises[key] ?? false)) {
        return key;
      }
    }

    return null; // All exercises completed
  }

  // Method to check if a unit standard is ready for formative
  bool _isUnitStandardReadyForFormative(String unitStandard) {
    // Check if this is the first unit standard
    if (unitStandard.contains('1') || unitStandard.contains('First')) {
      return true;
    }

    // For subsequent unit standards, check if previous unit standard is completed
    // This is a simplified check - you might need to adjust based on your data structure
    return true; // For now, allow all unit standards
  }

  // Method to check if a unit standard is ready for summative
  bool _isUnitStandardReadyForSummative(
      String unitStandard, List<dynamic> formativeQuestions) {
    // Check if all formative questions in this unit standard are completed
    for (var item in formativeQuestions) {
      final exercise = item['exercise']?.toString() ?? 'N/A';
      final uploadKey = 'Formative-$exercise-${widget.learnerID}';
      if (!(uploadedExercises[uploadKey] ?? false)) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _showFingerprintVerificationDialog(BuildContext context) async {
    try {
      // Get learner templates from database
      final DatabaseHelper dbHelper = DatabaseHelper();
      final templates = await dbHelper.getAllTemplates(widget.learnerID);

      // Detect available scanner using class-level instances
      final scanner = await _detectScanner();

      // Check if learner has fingerprints enrolled
      final hasZkLeft =
          (templates['zkteco_left_template']?.isNotEmpty ?? false);
      final hasZkRight =
          (templates['zkteco_right_template']?.isNotEmpty ?? false);
      final hasFutLeft =
          (templates['futronic_left_template']?.isNotEmpty ?? false);
      final hasFutRight =
          (templates['futronic_right_template']?.isNotEmpty ?? false);

      if (!hasZkLeft && !hasZkRight && !hasFutLeft && !hasFutRight) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No fingerprints enrolled for this learner. Please enroll fingerprints first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }

      // If current scanner has no templates but the other scanner does, guide user
      if (scanner == 'futronic' &&
          !(hasFutLeft || hasFutRight) &&
          (hasZkLeft || hasZkRight)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'This learner\'s fingerprint is enrolled on ZKTeco. Please use the ZKTeco scanner or re-enroll on Futronic for this learner.'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }
      if (scanner == 'zkteco' &&
          !(hasZkLeft || hasZkRight) &&
          (hasFutLeft || hasFutRight)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'This learner\'s fingerprint is enrolled on Futronic. Please use the Futronic scanner or re-enroll on ZKTeco for this learner.'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }

      if (scanner == 'none') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No fingerprint scanner detected. Please connect a scanner.'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      // Build guidance message based on available templates for active scanner
      String guidance = 'Place finger on scanner for verification...';
      if (scanner == 'futronic') {
        if (hasFutLeft && hasFutRight) {
          guidance =
              'Place either thumb on Futronic scanner for verification...';
        } else if (hasFutLeft)
          guidance = 'Place LEFT thumb on Futronic scanner for verification...';
        else if (hasFutRight)
          guidance =
              'Place RIGHT thumb on Futronic scanner for verification...';
      } else if (scanner == 'zkteco') {
        if (hasZkLeft && hasZkRight) {
          guidance = 'Place either thumb on ZKTeco scanner for verification...';
        } else if (hasZkLeft)
          guidance = 'Place LEFT thumb on ZKTeco scanner for verification...';
        else if (hasZkRight)
          guidance = 'Place RIGHT thumb on ZKTeco scanner for verification...';
      }

      // Show progress dialog
      _showProgressDialog(guidance);

      // Perform fingerprint verification using class-level instances
      bool match = false;
      try {
        if (scanner == 'zkteco') {
          // Use ZKTeco scanner with available templates
          final leftTemplate = templates['zkteco_left_template'];
          final rightTemplate = templates['zkteco_right_template'];

          if (leftTemplate != null && leftTemplate.isNotEmpty) {
            match = await _fingerprintService.verify('left', leftTemplate);
          }
          if (!match && rightTemplate != null && rightTemplate.isNotEmpty) {
            match = await _fingerprintService.verify('right', rightTemplate);
          }
        } else if (scanner == 'futronic') {
          // Use Futronic scanner with available templates
          final leftTemplate = templates['futronic_left_template'];
          final rightTemplate = templates['futronic_right_template'];
          final hint = (leftTemplate != null && leftTemplate.isNotEmpty)
              ? 'left'
              : 'right';
          match = await _futronicService.verifyBoth(
            hintFinger: hint,
            leftTemplate: leftTemplate,
            rightTemplate: rightTemplate,
          );
        }
      } catch (e) {
        print('Fingerprint verification error: $e');
        _hideProgressDialog();

        // Provide specific error messages for common issues
        String errorMessage = 'Fingerprint verification failed';
        if (e.toString().contains('USB_OPEN_FAILED') ||
            e.toString().contains('DEVICE_OPEN_FAILED')) {
          errorMessage =
              'Scanner connection failed. Please check USB connection and try again.';
        } else if (e.toString().contains('CAPTURE_FAILED')) {
          errorMessage =
              'Could not capture fingerprint. Please place finger firmly on scanner and try again.';
        } else if (e.toString().contains('TIMEOUT') ||
            e.toString().contains('Timeout')) {
          errorMessage = 'Timeout waiting for fingerprint. Please try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return false;
      }

      // Close the progress dialog
      _hideProgressDialog();

      if (match) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Fingerprint verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Fingerprint verification failed. Access denied.'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } catch (e) {
      print('Fingerprint verification error: $e');
      _hideProgressDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Future<String> _detectScanner() async {
    // Try ZKTeco first
    try {
      final isZkConnected = await _fingerprintService.isSensorConnected();
      if (isZkConnected) return 'zkteco';
    } catch (_) {}

    // Enhanced Futronic detection with retry
    return await _detectFutronicWithRetry();
  }

  Future<String> _detectFutronicWithRetry() async {
    const maxAttempts = 3;
    const delays = [500, 1000, 2000]; // Progressive delays

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        print('[DETECT] Futronic attempt $attempt/$maxAttempts...');
        final isFutronicConnected =
            await _futronicService.isFutronicConnected();

        if (isFutronicConnected) {
          print('[DETECT] ✅ Futronic detected on attempt $attempt!');
          return 'futronic';
        }

        // Wait before next attempt (except on last)
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: delays[attempt - 1]));
        }
      } catch (e) {
        print('[DETECT] Futronic attempt $attempt failed: $e');
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }

    print('[DETECT] ❌ No Futronic scanner detected after all attempts');
    return 'none';
  }

  void _showProgressDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  void _hideProgressDialog() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> openCamera(
      BuildContext context, String assessmentType, String exercise,
      {String? unitStandard}) async {
    if (!_isExerciseAllowed(assessmentType, exercise)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Complete the previous ${assessmentType.toLowerCase()} exercise first.')),
      );
      return;
    }

    bool verificationValid = await _showFingerprintVerificationDialog(context);
    if (!verificationValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Fingerprint verification failed. Document access denied.')),
      );
      return;
    }

    String? logbookText;
    final controllerKey = 'LogBook-$exercise-${widget.learnerID}';
    if (assessmentType == 'LogBook') {
      final controller = logBookControllers[controllerKey];
      logbookText = controller?.text;
      if (logbookText == null || logbookText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Log book text is required before uploading a document.')),
        );
        return;
      }
    }

    final imageSource = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Select Image Source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            child: const Text('Open Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            child: const Text('Upload Image'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (imageSource == null) {
      print('User cancelled image selection');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document selection cancelled')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text('Processing document...'),
          ],
        ),
      ),
    );

    try {
      File? document;
      String? updatedLogbookText;

      if (imageSource == ImageSource.camera) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CameraScanPage(
              type: assessmentType,
              exercise: exercise,
              learnerID: widget.learnerID,
              logbookText: logbookText,
            ),
          ),
        );

        if (result == null || result is! Map) {
          print('Error: No result returned from CameraScanPage');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Camera operation was cancelled or failed')),
          );
          return;
        }

        final file = result['image'] as File?;
        updatedLogbookText = result['logbookText'] as String?;

        if (file == null || !await file.exists()) {
          print('Error: No valid file returned from CameraScanPage');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid document captured')),
          );
          return;
        }

        if (assessmentType == 'LogBook') {
          final compressedImage = await _compressImage(file);
          if (compressedImage == null) {
            print('Error: Image compression failed');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to process captured image')),
            );
            return;
          }

          document = await _createPdfFromImage(
            compressedImage,
            'Log Book: $exercise',
            logbookText: updatedLogbookText ?? logbookText,
          );
        } else {
          if (!file.path.toLowerCase().endsWith('.pdf')) {
            print(
                'Error: Expected PDF file for $assessmentType, got ${file.path}');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Invalid file format. Expected a PDF for this assessment.')),
            );
            return;
          }
          document = file;
        }
      } else {
        if (assessmentType != 'LogBook') {
          print('Error: Gallery selection not supported for $assessmentType');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Gallery selection is only supported for LogBook assessments.')),
          );
          return;
        }

        final picker = ImagePicker();
        final pickedImage = await picker.pickImage(source: ImageSource.gallery);
        if (pickedImage == null) {
          print('Error: No image selected from gallery');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image selected')),
          );
          return;
        }

        final imageFile = File(pickedImage.path);
        if (!await imageFile.exists()) {
          print(
              'Error: Selected image file does not exist at ${imageFile.path}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected image file is invalid')),
          );
          return;
        }

        final compressedImage = await _compressImage(imageFile);
        if (compressedImage == null) {
          print('Error: Image compression failed');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to process selected image')),
          );
          return;
        }

        document = await _createPdfFromImage(
          compressedImage,
          'Log Book: $exercise',
          logbookText: logbookText,
        );
      }

      if (document == null) {
        print('Error: Document creation failed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to generate or process document')),
        );
        return;
      }

      if (_isExerciseAllowed(assessmentType, exercise)) {
        bool isConnected = await _checkConnectivity();
        if (isConnected) {
          final url = Uri.parse(AppConfig.buildUrl('save_metadata.php'));
          var request = http.MultipartRequest('POST', url)
            ..fields['learnerID'] = widget.learnerID.toString()
            ..fields['exercise'] = exercise
            ..fields['type'] = assessmentType;

          if (assessmentType == 'LogBook' && updatedLogbookText != null) {
            request.fields['logbook_text'] = updatedLogbookText;
          }

          print(
              'Uploading file: ${document.path}, Size: ${await document.length()} bytes');
          request.files
              .add(await http.MultipartFile.fromPath('files[]', document.path));

          try {
            // Add timeout to prevent hanging
            final response = await request.send().timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Upload timeout after 30 seconds');
              },
            );
            final responseBody = await response.stream.bytesToString();
            final decoded = json.decode(responseBody);

            if (decoded['status'] == 'success') {
              setState(() {
                final uploadKey =
                    '$assessmentType-$exercise-${widget.learnerID}';
                uploadedExercises[uploadKey] = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Uploaded to server: ${decoded['message']}')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Server error: ${decoded['message']}')),
              );
              await _saveLocally(document, assessmentType, exercise,
                  updatedLogbookText ?? logbookText);
            }
          } catch (e) {
            print('Upload error: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: $e. Saving locally.')),
            );
            await _saveLocally(document, assessmentType, exercise,
                updatedLogbookText ?? logbookText);
          }
        } else {
          await _saveLocally(document, assessmentType, exercise,
              updatedLogbookText ?? logbookText);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Cannot save document: Complete the previous exercise first.')),
        );
      }

      if (assessmentType == 'LogBook' && updatedLogbookText != null) {
        final controller = logBookControllers[controllerKey];
        if (controller != null) {
          controller.text = updatedLogbookText;
          print('Updated LogBook Controller Text: $updatedLogbookText');
          final dbHelper = DatabaseHelper();
          await dbHelper.saveLogBookText(
            widget.learnerID.toString(),
            assessmentType,
            exercise,
            updatedLogbookText,
          );
        }
      }
    } catch (e, stackTrace) {
      print('Error in openCamera: $e\nStackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      Navigator.of(context).pop();
    }
  }

  // New method for handling formative camera - scans all formative questions
  Future<void> _openFormativeCamera(BuildContext context,
      List<dynamic> formativeQuestions, String unitStandard) async {
    print('DEBUG: _openFormativeCamera called for unitStandard: $unitStandard');
    print('DEBUG: formativeQuestions count: ${formativeQuestions.length}');

    // Check if all formative questions are already completed
    bool allCompleted = true;
    for (var item in formativeQuestions) {
      final exercise = item['exercise']?.toString() ?? 'N/A';
      final uploadKey = 'Formative-$exercise-${widget.learnerID}';
      if (!(uploadedExercises[uploadKey] ?? false)) {
        allCompleted = false;
        break;
      }
    }

    if (allCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All formative questions are already completed.')),
      );
      return;
    }

    // Check if this is the first unit standard by checking if any exercises are completed
    bool anyExercisesCompleted =
        uploadedExercises.values.any((completed) => completed);
    print('DEBUG: anyExercisesCompleted: $anyExercisesCompleted');

    // If no exercises are completed yet, this is effectively the first unit standard
    bool isFirstUnitStandard = !anyExercisesCompleted;
    print('DEBUG: isFirstUnitStandard: $isFirstUnitStandard');

    // Check if all formative questions are allowed
    bool allAllowed = true;
    for (var item in formativeQuestions) {
      final exercise = item['exercise']?.toString() ?? 'N/A';
      print('DEBUG: Checking exercise: $exercise');

      if (isFirstUnitStandard) {
        // This is the first unit standard, allow all formative questions
        print('DEBUG: First unit standard detected, allowing formative');
        allAllowed = true;
        break;
      } else {
        // Check if previous unit standard is completed
        print('DEBUG: Not first unit standard, checking _isExerciseAllowed');
        if (!_isExerciseAllowed('Formative', exercise)) {
          print('DEBUG: Exercise not allowed: $exercise');
          allAllowed = false;
          break;
        }
      }
    }

    print('DEBUG: allAllowed result: $allAllowed');

    if (!allAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Complete the previous unit standard\'s formative exercises first.')),
      );
      return;
    }

    bool verificationValid = await _showFingerprintVerificationDialog(context);
    if (!verificationValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Fingerprint verification failed. Document access denied.')),
      );
      return;
    }

    final imageSource = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: const Text(
            'This will capture answers for all formative questions in this unit standard.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            child: const Text('Open Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            child: const Text('Upload Image'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (imageSource == null) {
      print('User cancelled image selection');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document selection cancelled')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text('Processing formative document...'),
          ],
        ),
      ),
    );

    try {
      File? document;

      if (imageSource == ImageSource.camera) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CameraScanPage(
              type: 'Formative',
              exercise: 'All Questions - $unitStandard',
              learnerID: widget.learnerID,
              logbookText: null,
            ),
          ),
        );

        if (result == null || result is! Map) {
          print('Error: No result returned from CameraScanPage');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Camera operation was cancelled or failed')),
          );
          return;
        }

        final file = result['image'] as File?;

        if (file == null || !await file.exists()) {
          print('Error: No valid file returned from CameraScanPage');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid document captured')),
          );
          return;
        }

        if (!file.path.toLowerCase().endsWith('.pdf')) {
          print('Error: Expected PDF file for Formative, got ${file.path}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Invalid file format. Expected a PDF for formative assessment.')),
          );
          return;
        }
        document = file;
      } else {
        // For gallery selection, we'll need to implement PDF selection
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Gallery selection for formative assessment not yet implemented.')),
        );
        return;
      }

      // Upload the same document for all formative questions
      bool isConnected = await _checkConnectivity();

      print('📊 FORMATIVE UPLOAD DEBUG:');
      print('   Total questions to process: ${formativeQuestions.length}');
      print(
          '   Questions list: ${formativeQuestions.map((q) => q['exercise']).toList()}');
      print('   Is connected: $isConnected');

      if (isConnected) {
        final url = Uri.parse(AppConfig.buildUrl('save_metadata.php'));

        int totalQuestions = formativeQuestions.length;
        int successfulUploads = 0;
        int failedUploads = 0;

        print('Starting formative upload for $totalQuestions questions');

        // Send a single bulk request for all formative questions
        var request = http.MultipartRequest('POST', url)
          ..fields['learnerID'] = widget.learnerID.toString()
          ..fields['type'] = 'Formative'
          ..fields['exercises'] = json.encode(formativeQuestions
              .map((item) => item['exercise']?.toString() ?? 'N/A')
              .toList())
          ..fields['unit_standard_upload'] = 'true'
          ..fields['unit_standard_name'] = unitStandard;

        print(
            'Uploading single formative document for ${formativeQuestions.length} questions: ${document.path}, Size: ${await document.length()} bytes');
        request.files
            .add(await http.MultipartFile.fromPath('files[]', document.path));

        try {
          // Add timeout to prevent hanging
          final response = await request.send().timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Upload timeout after 30 seconds');
            },
          );
          final responseBody = await response.stream.bytesToString();
          final decoded = json.decode(responseBody);

          if (decoded['status'] == 'success') {
            // Save to local database for all exercises
            for (var item in formativeQuestions) {
              final exercise = item['exercise']?.toString() ?? 'N/A';
              await _saveLocally(document, 'Formative', exercise, null);
            }
            successfulUploads = formativeQuestions.length;
            print(
                '✅ Successfully uploaded formative document for all ${formativeQuestions.length} questions');
          } else {
            print('❌ Server error for formative upload: ${decoded['message']}');
            // Save locally for all exercises
            for (var item in formativeQuestions) {
              final exercise = item['exercise']?.toString() ?? 'N/A';
              await _saveLocally(document, 'Formative', exercise, null);
            }
            failedUploads = formativeQuestions.length;
          }
        } catch (e) {
          print('❌ Upload error for formative: $e');
          // Save locally for all exercises
          for (var item in formativeQuestions) {
            final exercise = item['exercise']?.toString() ?? 'N/A';
            await _saveLocally(document, 'Formative', exercise, null);
          }
          failedUploads = formativeQuestions.length;
        }

        // Mark all exercises as completed in UI
        for (var item in formativeQuestions) {
          final exercise = item['exercise']?.toString() ?? 'N/A';
          setState(() {
            final uploadKey = 'Formative-$exercise-${widget.learnerID}';
            uploadedExercises[uploadKey] = true;
          });
        }

        print(
            'Formative upload complete: $successfulUploads successful, $failedUploads failed/saved locally');

        // Force UI update by ensuring all formative questions are marked as completed
        setState(() {
          for (var item in formativeQuestions) {
            final exercise = item['exercise']?.toString() ?? 'N/A';
            final uploadKey = 'Formative-$exercise-${widget.learnerID}';
            uploadedExercises[uploadKey] = true;
          }
        });

        // Refresh upload status to ensure UI is updated
        await _refreshUploadStatus();

        print(
            '📊 AFTER REFRESH - uploadedExercises count: ${uploadedExercises.length}');
        print(
            '   Formative exercises marked: ${uploadedExercises.keys.where((k) => k.startsWith('Formative-')).toList()}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '✅ All ${formativeQuestions.length} formative questions completed! ($successfulUploads uploaded, $failedUploads saved locally)')),
        );
      } else {
        // Save locally for all formative questions
        print(
            '[OFFLINE_SCAN] No internet connection, saving all ${formativeQuestions.length} formative questions locally');
        int localSaveCount = 0;

        for (var item in formativeQuestions) {
          final exercise = item['exercise']?.toString() ?? 'N/A';
          print(
              '[OFFLINE_SCAN] Processing question $localSaveCount/${formativeQuestions.length}: $exercise');

          await _saveLocally(document, 'Formative', exercise, null);
          localSaveCount++;

          // Verify it was marked
          final uploadKey = 'Formative-$exercise-${widget.learnerID}';
          print(
              '[OFFLINE_SCAN] Question $exercise marked as: ${uploadedExercises[uploadKey]}');
        }

        print(
            '[OFFLINE_SCAN] All $localSaveCount questions saved, forcing UI update...');

        // Force UI update by ensuring all formative questions are marked as completed
        setState(() {
          for (var item in formativeQuestions) {
            final exercise = item['exercise']?.toString() ?? 'N/A';
            final uploadKey = 'Formative-$exercise-${widget.learnerID}';
            uploadedExercises[uploadKey] = true;
          }
        });

        // Refresh upload status to update UI from database
        await _refreshUploadStatus();

        print('[OFFLINE_SCAN] UI refresh complete');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '✅ All $localSaveCount formative questions completed and saved locally!')),
        );
      }
    } catch (e, stackTrace) {
      print('Error in _openFormativeCamera: $e\nStackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      Navigator.of(context).pop();
    }
  }

  // New method for handling summative camera - scans all summative questions
  Future<void> _openSummativeCamera(BuildContext context,
      List<dynamic> summativeQuestions, String unitStandard) async {
    // Check if all summative questions are already completed
    bool allCompleted = true;
    for (var item in summativeQuestions) {
      final exercise = item['exercise']?.toString() ?? 'N/A';
      final uploadKey = 'Summative-$exercise-${widget.learnerID}';
      if (!(uploadedExercises[uploadKey] ?? false)) {
        allCompleted = false;
        break;
      }
    }

    if (allCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All summative questions are already completed.')),
      );
      return;
    }

    // Check if this is the first unit standard by checking if any exercises are completed
    bool anyExercisesCompleted =
        uploadedExercises.values.any((completed) => completed);
    bool isFirstUnitStandard = !anyExercisesCompleted;

    // Check if all summative questions are allowed
    bool allAllowed = true;
    for (var item in summativeQuestions) {
      final exercise = item['exercise']?.toString() ?? 'N/A';
      if (isFirstUnitStandard) {
        // This is the first unit standard, check if all formative questions in this unit are complete
        bool allFormativeCompleted = true;

        // Find all formative questions for this unit standard from pathwaysData
        if (pathwaysData != null) {
          pathwaysData!.forEach((pathwayName, pathwayData) {
            if (pathwayData['qualifications'] != null) {
              (pathwayData['qualifications'] as Map)
                  .forEach((qualificationName, qualData) {
                if (qualData['unitstandards'] != null) {
                  (qualData['unitstandards'] as Map)
                      .forEach((unitStandardName, unitData) {
                    if (unitStandardName == unitStandard) {
                      final formative = unitData['formative'] ?? [];
                      for (var formativeItem in formative) {
                        final formativeExercise =
                            formativeItem['exercise']?.toString() ?? 'N/A';
                        final formativeKey =
                            'Formative-$formativeExercise-${widget.learnerID}';
                        if (!(uploadedExercises[formativeKey] ?? false)) {
                          allFormativeCompleted = false;
                          print(
                              'DEBUG: Formative exercise not completed: $formativeExercise');
                          return;
                        }
                      }
                    }
                  });
                }
              });
            }
          });
        }

        if (!allFormativeCompleted) {
          allAllowed = false;
          break;
        }
      } else {
        // Check if previous unit standard is completed
        if (!_isExerciseAllowed('Summative', exercise)) {
          allAllowed = false;
          break;
        }
      }
    }

    if (!allAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Complete all formative exercises in this unit standard first.')),
      );
      return;
    }

    bool verificationValid = await _showFingerprintVerificationDialog(context);
    if (!verificationValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Fingerprint verification failed. Document access denied.')),
      );
      return;
    }

    final imageSource = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: const Text(
            'This will capture answers for all summative questions in this unit standard.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            child: const Text('Open Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            child: const Text('Upload Image'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (imageSource == null) {
      print('User cancelled image selection');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document selection cancelled')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text('Processing summative document...'),
          ],
        ),
      ),
    );

    try {
      File? document;

      if (imageSource == ImageSource.camera) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CameraScanPage(
              type: 'Summative',
              exercise: 'All Questions - $unitStandard',
              learnerID: widget.learnerID,
              logbookText: null,
            ),
          ),
        );

        if (result == null || result is! Map) {
          print('Error: No result returned from CameraScanPage');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Camera operation was cancelled or failed')),
          );
          return;
        }

        final file = result['image'] as File?;

        if (file == null || !await file.exists()) {
          print('Error: No valid file returned from CameraScanPage');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid document captured')),
          );
          return;
        }

        if (!file.path.toLowerCase().endsWith('.pdf')) {
          print('Error: Expected PDF file for Summative, got ${file.path}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Invalid file format. Expected a PDF for summative assessment.')),
          );
          return;
        }
        document = file;
      } else {
        // For gallery selection, we'll need to implement PDF selection
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Gallery selection for summative assessment not yet implemented.')),
        );
        return;
      }

      // Upload the same document for all summative questions
      bool isConnected = await _checkConnectivity();

      print('📊 SUMMATIVE UPLOAD DEBUG:');
      print('   Total questions to process: ${summativeQuestions.length}');
      print(
          '   Questions list: ${summativeQuestions.map((q) => q['exercise']).toList()}');
      print('   Is connected: $isConnected');

      if (isConnected) {
        final url = Uri.parse(AppConfig.buildUrl('save_metadata.php'));

        int totalQuestions = summativeQuestions.length;
        int successfulUploads = 0;
        int failedUploads = 0;

        print('Starting summative upload for $totalQuestions questions');

        // Send a single bulk request for all summative questions
        var request = http.MultipartRequest('POST', url)
          ..fields['learnerID'] = widget.learnerID.toString()
          ..fields['type'] = 'Summative'
          ..fields['exercises'] = json.encode(summativeQuestions
              .map((item) => item['exercise']?.toString() ?? 'N/A')
              .toList())
          ..fields['unit_standard_upload'] = 'true'
          ..fields['unit_standard_name'] = unitStandard;

        print(
            'Uploading single summative document for ${summativeQuestions.length} questions: ${document.path}, Size: ${await document.length()} bytes');
        request.files
            .add(await http.MultipartFile.fromPath('files[]', document.path));

        try {
          // Add timeout to prevent hanging
          final response = await request.send().timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Upload timeout after 30 seconds');
            },
          );
          final responseBody = await response.stream.bytesToString();
          final decoded = json.decode(responseBody);

          if (decoded['status'] == 'success') {
            // Save to local database for all exercises
            for (var item in summativeQuestions) {
              final exercise = item['exercise']?.toString() ?? 'N/A';
              await _saveLocally(document, 'Summative', exercise, null);
            }
            successfulUploads = summativeQuestions.length;
            print(
                '✅ Successfully uploaded summative document for all ${summativeQuestions.length} questions');
          } else {
            print('❌ Server error for summative upload: ${decoded['message']}');
            // Save locally for all exercises
            for (var item in summativeQuestions) {
              final exercise = item['exercise']?.toString() ?? 'N/A';
              await _saveLocally(document, 'Summative', exercise, null);
            }
            failedUploads = summativeQuestions.length;
          }
        } catch (e) {
          print('❌ Upload error for summative: $e');
          // Save locally for all exercises
          for (var item in summativeQuestions) {
            final exercise = item['exercise']?.toString() ?? 'N/A';
            await _saveLocally(document, 'Summative', exercise, null);
          }
          failedUploads = summativeQuestions.length;
        }

        // Mark all exercises as completed in UI
        for (var item in summativeQuestions) {
          final exercise = item['exercise']?.toString() ?? 'N/A';
          setState(() {
            final uploadKey = 'Summative-$exercise-${widget.learnerID}';
            uploadedExercises[uploadKey] = true;
          });
        }

        print(
            'Summative upload complete: $successfulUploads successful, $failedUploads failed/saved locally');

        // Force UI update by ensuring all summative questions are marked as completed
        setState(() {
          for (var item in summativeQuestions) {
            final exercise = item['exercise']?.toString() ?? 'N/A';
            final uploadKey = 'Summative-$exercise-${widget.learnerID}';
            uploadedExercises[uploadKey] = true;
          }
        });

        // Refresh upload status to ensure UI is updated
        await _refreshUploadStatus();

        print(
            '📊 AFTER REFRESH - uploadedExercises count: ${uploadedExercises.length}');
        print(
            '   Summative exercises marked: ${uploadedExercises.keys.where((k) => k.startsWith('Summative-')).toList()}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '✅ All ${summativeQuestions.length} summative questions completed! ($successfulUploads uploaded, $failedUploads saved locally)')),
        );
      } else {
        // Save locally for all summative questions
        print(
            '[OFFLINE_SCAN] No internet connection, saving all ${summativeQuestions.length} summative questions locally');
        int localSaveCount = 0;

        for (var item in summativeQuestions) {
          final exercise = item['exercise']?.toString() ?? 'N/A';
          print(
              '[OFFLINE_SCAN] Processing question $localSaveCount/${summativeQuestions.length}: $exercise');

          await _saveLocally(document, 'Summative', exercise, null);
          localSaveCount++;

          // Verify it was marked
          final uploadKey = 'Summative-$exercise-${widget.learnerID}';
          print(
              '[OFFLINE_SCAN] Question $exercise marked as: ${uploadedExercises[uploadKey]}');
        }

        print(
            '[OFFLINE_SCAN] All $localSaveCount questions saved, forcing UI update...');

        // Force UI update by ensuring all summative questions are marked as completed
        setState(() {
          for (var item in summativeQuestions) {
            final exercise = item['exercise']?.toString() ?? 'N/A';
            final uploadKey = 'Summative-$exercise-${widget.learnerID}';
            uploadedExercises[uploadKey] = true;
          }
        });

        // Refresh upload status to update UI from database
        await _refreshUploadStatus();

        print('[OFFLINE_SCAN] UI refresh complete');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '✅ All $localSaveCount summative questions completed and saved locally!')),
        );
      }
    } catch (e, stackTrace) {
      print('Error in _openSummativeCamera: $e\nStackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      Navigator.of(context).pop();
    }
  }

  // Remedial camera - optional, doesn't block anything
  Future<void> _openRemedialCamera(
      BuildContext context, String unitStandard, String remedialType) async {
    print(
        '[REMEDIAL] Opening $remedialType camera for unit standard: $unitStandard');

    // Remedial is always allowed - it's optional and doesn't block anything
    bool verificationValid = await _showFingerprintVerificationDialog(context);
    if (!verificationValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Fingerprint verification failed. Document access denied.')),
      );
      return;
    }

    final imageSource = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Scan $remedialType Document'),
        content: Text(
            '$remedialType assessments are optional and document additional support or re-assessment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            child: const Text('Open Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            child: const Text('Upload Image'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (imageSource == null) {
      print('[REMEDIAL] User cancelled');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text('Processing $remedialType document...'),
          ],
        ),
      ),
    );

    try {
      File? document;

      if (imageSource == ImageSource.camera) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CameraScanPage(
              type: remedialType,
              exercise: '$remedialType - $unitStandard',
              learnerID: widget.learnerID,
              logbookText: null,
            ),
          ),
        );

        if (result == null || result is! Map) {
          print('[REMEDIAL] No result from camera');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera operation cancelled')),
          );
          return;
        }

        final file = result['image'] as File?;
        if (file == null || !await file.exists()) {
          print('[REMEDIAL] No valid file');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid document captured')),
          );
          return;
        }

        document = file;
      } else {
        // Gallery selection
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Gallery selection not yet implemented for remedial')),
        );
        return;
      }

      // Save remedial document with specific type
      final exercise = '$remedialType-$unitStandard';
      bool isConnected = await _checkConnectivity();

      if (isConnected) {
        // Try to upload to server
        final url = Uri.parse(AppConfig.buildUrl('save_metadata.php'));
        var request = http.MultipartRequest('POST', url)
          ..fields['learnerID'] = widget.learnerID.toString()
          ..fields['exercise'] = exercise
          ..fields['type'] = remedialType;

        request.files
            .add(await http.MultipartFile.fromPath('files[]', document.path));

        try {
          final response = await request.send().timeout(
                const Duration(seconds: 30),
                onTimeout: () => throw Exception('Upload timeout'),
              );

          final responseBody = await response.stream.bytesToString();
          final decoded = json.decode(responseBody);

          if (decoded['status'] == 'success') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ $remedialType document uploaded to server'),
                backgroundColor: Colors.green,
              ),
            );
            print('[REMEDIAL] $remedialType uploaded to server successfully');
          } else {
            print('[REMEDIAL] Server error: ${decoded['message']}');
            await _saveLocally(document, remedialType, exercise, null);
          }
        } catch (e) {
          print('[REMEDIAL] Upload error: $e');
          await _saveLocally(document, remedialType, exercise, null);
        }
      } else {
        // Save locally
        await _saveLocally(document, remedialType, exercise, null);
      }

      print('[REMEDIAL] $remedialType document saved for $unitStandard');
    } catch (e, stackTrace) {
      print('[REMEDIAL] Error: $e\nStackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openLogBookCamera(BuildContext context,
      List<dynamic> logBookItems, String unitStandard) async {
    print('DEBUG: _openLogBookCamera called for unitStandard: $unitStandard');
    print('DEBUG: logBookItems count: ${logBookItems.length}');

    // Check if all logbook items are already completed
    bool allCompleted = true;
    for (var item in logBookItems) {
      final exercise = item['exercise']?.toString() ?? 'N/A';
      final uploadKey = 'LogBook-$exercise-${widget.learnerID}';
      if (!(uploadedExercises[uploadKey] ?? false)) {
        allCompleted = false;
        break;
      }
    }

    if (allCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All logbook items are already completed.')),
      );
      return;
    }

    // Check if previous exercises are completed (summative should be done first)
    bool previousCompleted = true;
    for (var item in logBookItems) {
      final exercise = item['exercise']?.toString() ?? 'N/A';
      if (!_isExerciseAllowed('LogBook', exercise)) {
        previousCompleted = false;
        break;
      }
    }

    if (!previousCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete the previous exercises first.')),
      );
      return;
    }

    bool verificationValid = await _showFingerprintVerificationDialog(context);
    if (!verificationValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Fingerprint verification failed. Document access denied.')),
      );
      return;
    }

    // LogBook uses scanner only (no gallery option)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Scan LogBook Document'),
        content: const Text(
            'This will open the scanner to capture logbook entries for all items in this unit standard.\n\nYou can scan multiple pages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.document_scanner),
            label: const Text('Open Scanner'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      print('User cancelled scanner');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan cancelled')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text('Processing logbook document...'),
          ],
        ),
      ),
    );

    try {
      File? document;

      // Open scanner (CameraScanPage) for multi-page document scanning
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScanPage(
            type: 'LogBook',
            exercise: 'All Entries - $unitStandard',
            learnerID: widget.learnerID,
            logbookText: null,
          ),
        ),
      );

      if (result == null || result is! Map) {
        print('Error: No result returned from CameraScanPage');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Scanner operation was cancelled or failed')),
        );
        return;
      }

      final file = result['image'] as File?;

      if (file == null || !await file.exists()) {
        print('Error: No valid file returned from CameraScanPage');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid document captured')),
        );
        return;
      }

      // LogBook uses scanner (CameraScanPage) which returns a PDF directly
      if (!file.path.toLowerCase().endsWith('.pdf')) {
        print('Error: Expected PDF file for LogBook, got ${file.path}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Invalid file format. Expected a PDF for logbook.')),
        );
        return;
      }
      document = file;

      // Upload the same document for all logbook items
      bool isConnected = await _checkConnectivity();
      if (isConnected) {
        final url = Uri.parse(AppConfig.buildUrl('save_metadata.php'));

        int totalItems = logBookItems.length;
        int successfulUploads = 0;
        int failedUploads = 0;

        print('Starting logbook upload for $totalItems items');

        // Send a single bulk request for all logbook items
        var request = http.MultipartRequest('POST', url)
          ..fields['learnerID'] = widget.learnerID.toString()
          ..fields['type'] = 'LogBook'
          ..fields['exercises'] = json.encode(logBookItems
              .map((item) => item['exercise']?.toString() ?? 'N/A')
              .toList())
          ..fields['unit_standard_upload'] = 'true'
          ..fields['unit_standard_name'] = unitStandard
          ..fields['logbook_text'] = 'Logbook entries for $unitStandard';

        print(
            'Uploading single logbook document for ${logBookItems.length} items: ${document.path}, Size: ${await document.length()} bytes');
        request.files
            .add(await http.MultipartFile.fromPath('files[]', document.path));

        try {
          // Add timeout to prevent hanging
          final response = await request.send().timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Upload timeout after 30 seconds');
            },
          );
          final responseBody = await response.stream.bytesToString();
          final decoded = json.decode(responseBody);

          if (decoded['status'] == 'success') {
            // Save to local database for all exercises
            for (var item in logBookItems) {
              final exercise = item['exercise']?.toString() ?? 'N/A';
              await _saveLocally(document, 'LogBook', exercise,
                  'Logbook entry for $exercise - $unitStandard');
            }
            successfulUploads = logBookItems.length;
            print(
                '✅ Successfully uploaded logbook document for all ${logBookItems.length} items');
          } else {
            print('❌ Server error for logbook upload: ${decoded['message']}');
            // Save locally for all exercises
            for (var item in logBookItems) {
              final exercise = item['exercise']?.toString() ?? 'N/A';
              await _saveLocally(document, 'LogBook', exercise,
                  'Logbook entry for $exercise - $unitStandard');
            }
            failedUploads = logBookItems.length;
          }
        } catch (e) {
          print('❌ Upload error for logbook: $e');
          // Save locally for all exercises
          for (var item in logBookItems) {
            final exercise = item['exercise']?.toString() ?? 'N/A';
            await _saveLocally(document, 'LogBook', exercise,
                'Logbook entry for $exercise - $unitStandard');
          }
          failedUploads = logBookItems.length;
        }

        // Mark all exercises as completed in UI
        for (var item in logBookItems) {
          final exercise = item['exercise']?.toString() ?? 'N/A';
          setState(() {
            final uploadKey = 'LogBook-$exercise-${widget.learnerID}';
            uploadedExercises[uploadKey] = true;
          });
        }

        print(
            'Logbook upload complete: $successfulUploads successful, $failedUploads failed/saved locally');

        // Force UI update by ensuring all logbook items are marked as completed
        setState(() {
          for (var item in logBookItems) {
            final exercise = item['exercise']?.toString() ?? 'N/A';
            final uploadKey = 'LogBook-$exercise-${widget.learnerID}';
            uploadedExercises[uploadKey] = true;
          }
        });

        // Refresh upload status to ensure UI is updated
        await _refreshUploadStatus();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '✅ All ${logBookItems.length} logbook items completed! ($successfulUploads uploaded, $failedUploads saved locally)')),
        );
      } else {
        // Save locally for all logbook items
        print(
            '[OFFLINE_SCAN] No internet connection, saving all ${logBookItems.length} logbook items locally');
        int localSaveCount = 0;

        for (var item in logBookItems) {
          final exercise = item['exercise']?.toString() ?? 'N/A';
          print(
              '[OFFLINE_SCAN] Processing logbook item $localSaveCount/${logBookItems.length}: $exercise');

          await _saveLocally(document, 'LogBook', exercise,
              'Logbook entry for $exercise - $unitStandard');
          localSaveCount++;

          // Verify it was marked
          final uploadKey = 'LogBook-$exercise-${widget.learnerID}';
          print(
              '[OFFLINE_SCAN] Logbook item $exercise marked as: ${uploadedExercises[uploadKey]}');
        }

        print(
            '[OFFLINE_SCAN] All $localSaveCount logbook items saved, forcing UI update...');

        // Force UI update by ensuring all logbook items are marked as completed
        setState(() {
          for (var item in logBookItems) {
            final exercise = item['exercise']?.toString() ?? 'N/A';
            final uploadKey = 'LogBook-$exercise-${widget.learnerID}';
            uploadedExercises[uploadKey] = true;
          }
        });

        // Refresh upload status to update UI from database
        await _refreshUploadStatus();

        print('[OFFLINE_SCAN] UI refresh complete');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '✅ All $localSaveCount logbook items completed and saved locally!')),
        );
      }
    } catch (e, stackTrace) {
      print('Error in _openLogBookCamera: $e\nStackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      Navigator.of(context).pop();
    }
  }

  Future<File?> _captureImage(BuildContext context) async {
    final pickedImage =
        await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image captured.')),
      );
      return null;
    }
    final imageFile = File(pickedImage.path);
    if (!await imageFile.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captured image file not found.')),
      );
      return null;
    }
    return imageFile;
  }

  Future<void> _uploadDocument(
      String assessmentType, String exercise, File image, Uint8List signature,
      {String? unitStandard}) async {
    final signatureImage = pw.MemoryImage(signature);

    // Read image bytes before creating PDF
    final imageBytes = await image.readAsBytes();
    final imageMemoryImage = pw.MemoryImage(imageBytes);

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '$assessmentType: $exercise',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Image(imageMemoryImage, fit: pw.BoxFit.contain),
            pw.SizedBox(height: 20),
            pw.Text(
              'Signature:',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Image(signatureImage, height: 100),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final pdfPath =
        '${dir.path}/document_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final pdfFile = File(pdfPath);
    final pdfBytes = await pdf.save();
    await pdfFile.writeAsBytes(pdfBytes);

    final isConnected = await _checkConnectivity();
    if (isConnected) {
      final url = Uri.parse(AppConfig.buildUrl('save_metadata.php'));
      var request = http.MultipartRequest('POST', url)
        ..fields['learnerID'] = widget.learnerID.toString()
        ..fields['exercise'] = exercise
        ..fields['type'] = assessmentType;

      if (unitStandard != null) {
        request.fields['unit_standard_name'] = unitStandard;
      }

      request.files
          .add(await http.MultipartFile.fromPath('files[]', pdfFile.path));
      request.files.add(http.MultipartFile.fromBytes('signature', signature));

      try {
        final response = await request.send();
        final responseBody = await response.stream.bytesToString();
        final decoded = json.decode(responseBody);

        if (decoded['status'] == 'success') {
          setState(() {
            final uploadKey = '$assessmentType-$exercise-${widget.learnerID}';
            uploadedExercises[uploadKey] = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Uploaded to server: ${decoded['message']}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: ${decoded['message']}')),
          );
          await _saveLocally(pdfFile, assessmentType, exercise, null);
        }
      } catch (e) {
        print('Upload error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload to server')),
        );
        await _saveLocally(pdfFile, assessmentType, exercise, null);
      }
    } else {
      await _saveLocally(pdfFile, assessmentType, exercise, null);
    }
  }

  Future<void> _saveLocally(File document, String assessmentType,
      String exercise, String? logbookText) async {
    final dbHelper = DatabaseHelper();
    String filePath = document.path;

    try {
      // Always copy file to app directory for persistence
      final appDir = await getApplicationDocumentsDirectory();
      final poeDir = Directory('${appDir.path}/POE');
      if (!poeDir.existsSync()) {
        poeDir.createSync(recursive: true);
      }

      final extension = filePath.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName =
          '${assessmentType}_${widget.learnerID}_${exercise.replaceAll(' ', '_')}_$timestamp.$extension';
      final newFilePath = '${poeDir.path}/$newFileName';

      // Copy file to app directory
      await document.copy(newFilePath);
      filePath = newFilePath;
      print('[POE_OFFLINE] Document saved to: $filePath');
    } catch (e) {
      print('[POE_OFFLINE] Error copying file: $e');
      // If copy fails, use original path
      filePath = document.path;
    }

    // Save to local database with synced=0 (pending sync)
    await dbHelper.saveUploadToLocalPoe(
        widget.learnerID, assessmentType, exercise, filePath);

    if (assessmentType == 'LogBook' && logbookText != null) {
      await dbHelper.saveLogBookText(
          widget.learnerID.toString(), assessmentType, exercise, logbookText);
    }

    // Mark as uploaded in UI (locally completed)
    setState(() {
      final uploadKey = '$assessmentType-$exercise-${widget.learnerID}';
      uploadedExercises[uploadKey] = true;
    });

    print(
        '[POE_OFFLINE] Saved locally: learnerID=${widget.learnerID}, exercise=$exercise, type=$assessmentType');

    // Show offline indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📱 Saved offline: $assessmentType - $exercise'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        'Building with pathwaysData: $pathwaysData, isLoading: $isLoading, errorMessage: $errorMessage');
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = '';
                });
                fetchLearnerData();
              },
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      );
    } else if (pathwaysData == null || pathwaysData!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No pathways data available'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = '';
                });
                fetchLearnerData();
              },
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      );
    } else {
      List<Map<String, dynamic>> allLogBooks = [];
      pathwaysData!.forEach((pathwayName, pathwayData) {
        (pathwayData['qualifications'] as Map)
            .forEach((qualificationName, qualData) {
          (qualData['unitstandards'] as Map)
              .forEach((unitStandardName, unitData) {
            final logbook = unitData['logbook'] ?? [];
            for (var item in logbook) {
              final exercise = item['exercise']?.toString() ?? 'N/A';
              final key = 'LogBook-$exercise-${widget.learnerID}';
              if (!logBookControllers.containsKey(key)) {
                logBookControllers[key] =
                    TextEditingController(text: item['logbook_text'] ?? '');
              }
              allLogBooks.add({
                'unitStandard': unitStandardName,
                'exercise': exercise,
                'logbook_text': item['logbook_text']?.toString() ?? '',
              });
            }
          });
        });
      });

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Learner Info Card with Clocking Days Counter
          FutureBuilder<Map<String, dynamic>>(
            future: _getLearnerInfoWithClockingDays(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final learnerInfo = snapshot.data;
              if (learnerInfo == null) {
                return const SizedBox.shrink();
              }

              final name = learnerInfo['Name']?.toString() ?? 'N/A';
              final surname = learnerInfo['Surname']?.toString() ?? 'N/A';
              final idNumber = learnerInfo['IDNumber']?.toString() ?? 'N/A';
              final clockingDays = learnerInfo['clocking_days'] as int? ?? 0;
              final workingDays = learnerInfo['working_days'] as int? ?? 0;
              final percentage =
                  workingDays > 0 ? (clockingDays / workingDays) * 100 : 0.0;

              // Color based on attendance percentage
              Color attendanceColor;
              if (percentage >= 80) {
                attendanceColor = Colors.green.shade700;
              } else if (percentage >= 50) {
                attendanceColor = Colors.orange.shade700;
              } else {
                attendanceColor = Colors.red.shade700;
              }

              return Card(
                margin: const EdgeInsets.all(12),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person,
                              color: Colors.blue, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$name $surname',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'ID: $idNumber',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: attendanceColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Days Clocked This Month:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$clockingDays/$workingDays',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: attendanceColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: attendanceColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: attendanceColor),
                            ),
                            child: Text(
                              '${percentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: attendanceColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Sync status banner
          if (unsyncedCount > 0)
            Container(
              color: Colors.orange[100],
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.cloud_upload, color: Colors.orange[800]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$unsyncedCount POE record(s) pending sync',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                          ),
                        ),
                        Text(
                          'Will sync automatically when online',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isSyncing)
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (await _checkConnectivity()) {
                          await _syncOfflinePOE();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No internet connection'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text('Sync Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    )
                  else
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ...pathwaysData!.entries.map((entry) {
            return ExpansionTile(
              title: Text(entry.key),
              children:
                  (entry.value['qualifications'] as Map<String, dynamic>? ?? {})
                      .entries
                      .map((qualEntry) {
                return ExpansionTile(
                  title: Text(qualEntry.key),
                  children: (qualEntry.value['unitstandards']
                              as Map<String, dynamic>? ??
                          {})
                      .entries
                      .map((unitEntry) {
                    final formative = unitEntry.value['formative'] ?? [];
                    final summative = unitEntry.value['summative'] ?? [];
                    final logbook = unitEntry.value['logbook'] ?? [];

                    print('[DEBUG] Unit Standard: ${unitEntry.key}');
                    print('[DEBUG]   Formative count: ${formative.length}');
                    print('[DEBUG]   Summative count: ${summative.length}');
                    print('[DEBUG]   LogBook count: ${logbook.length}');

                    return ExpansionTile(
                      title: Text(unitEntry.key),
                      children: [
                        if (formative.isNotEmpty)
                          ExpansionTile(
                            title: Row(
                              children: [
                                const Text('Formative'),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${formative.where((item) {
                                      final exercise =
                                          item['exercise']?.toString() ?? 'N/A';
                                      final uploadKey =
                                          'Formative-$exercise-${widget.learnerID}';
                                      return uploadedExercises[uploadKey] ??
                                          false;
                                    }).length}/${formative.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              // List all formative questions
                              ...formative.map<Widget>((item) {
                                final exercise =
                                    item['exercise']?.toString() ?? 'N/A';
                                final uploadKey =
                                    'Formative-$exercise-${widget.learnerID}';
                                final isUploaded =
                                    uploadedExercises[uploadKey] ?? false;
                                final shouldShowCamera = _shouldShowCameraIcon(
                                    'Formative', exercise, unitEntry.key);

                                return ListTile(
                                  leading: Icon(
                                    isUploaded
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color:
                                        isUploaded ? Colors.green : Colors.grey,
                                  ),
                                  title: Text('Question: $exercise'),
                                  subtitle: Text(
                                    isUploaded ? 'Completed' : 'Pending',
                                    style: TextStyle(
                                      color: isUploaded
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  trailing: !isUploaded
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (shouldShowCamera)
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.camera_alt,
                                                    color: Colors.blue),
                                                onPressed: () =>
                                                    _openFormativeCamera(
                                                        context,
                                                        formative,
                                                        unitEntry.key),
                                                tooltip: 'Scan All Formative',
                                              ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.check_box_outlined,
                                                  color: Colors.orange),
                                              onPressed: () =>
                                                  _manualMarkAsUploaded(
                                                      'Formative', exercise),
                                              tooltip: 'Mark as Uploaded',
                                            ),
                                          ],
                                        )
                                      : Container(
                                          padding: const EdgeInsets.all(8.0),
                                          decoration: BoxDecoration(
                                            color: Colors.green[100],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border:
                                                Border.all(color: Colors.green),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle,
                                                  color: Colors.green,
                                                  size: 16),
                                              SizedBox(width: 4),
                                              Text(
                                                'COMPLETED',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                );
                              }).toList(),
                              // Single camera button for all formative questions (only if ready)
                              if (_isUnitStandardReadyForFormative(
                                  unitEntry.key))
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: ElevatedButton.icon(
                                    onPressed: formative.where((item) {
                                              final exercise = item['exercise']
                                                      ?.toString() ??
                                                  'N/A';
                                              final uploadKey =
                                                  'Formative-$exercise-${widget.learnerID}';
                                              return uploadedExercises[
                                                      uploadKey] ??
                                                  false;
                                            }).length ==
                                            formative.length
                                        ? null // Disable if all completed
                                        : () => _openFormativeCamera(
                                            context, formative, unitEntry.key),
                                    icon: Icon(
                                      formative.where((item) {
                                                final exercise =
                                                    item['exercise']
                                                            ?.toString() ??
                                                        'N/A';
                                                final uploadKey =
                                                    'Formative-$exercise-${widget.learnerID}';
                                                return uploadedExercises[
                                                        uploadKey] ??
                                                    false;
                                              }).length ==
                                              formative.length
                                          ? Icons.check_circle
                                          : Icons.camera_alt,
                                    ),
                                    label: Text(
                                      formative.where((item) {
                                                final exercise =
                                                    item['exercise']
                                                            ?.toString() ??
                                                        'N/A';
                                                final uploadKey =
                                                    'Formative-$exercise-${widget.learnerID}';
                                                return uploadedExercises[
                                                        uploadKey] ??
                                                    false;
                                              }).length ==
                                              formative.length
                                          ? 'All Formative Completed ✓'
                                          : 'Scan All Formative Answers',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: formative.where((item) {
                                                final exercise =
                                                    item['exercise']
                                                            ?.toString() ??
                                                        'N/A';
                                                final uploadKey =
                                                    'Formative-$exercise-${widget.learnerID}';
                                                return uploadedExercises[
                                                        uploadKey] ??
                                                    false;
                                              }).length ==
                                              formative.length
                                          ? Colors.green
                                          : Colors.blue,
                                      foregroundColor: Colors.white,
                                      minimumSize:
                                          const Size(double.infinity, 50),
                                    ),
                                  ),
                                ),
                              // Manual Mark All Formative button
                              if (_isUnitStandardReadyForFormative(
                                  unitEntry.key))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: ElevatedButton.icon(
                                    onPressed: formative.where((item) {
                                              final exercise = item['exercise']
                                                      ?.toString() ??
                                                  'N/A';
                                              final uploadKey =
                                                  'Formative-$exercise-${widget.learnerID}';
                                              return uploadedExercises[
                                                      uploadKey] ??
                                                  false;
                                            }).length ==
                                            formative.length
                                        ? null // Disable if all completed
                                        : () => _manualMarkAllFormative(
                                            context, formative, unitEntry.key),
                                    icon: Icon(
                                      formative.where((item) {
                                                final exercise =
                                                    item['exercise']
                                                            ?.toString() ??
                                                        'N/A';
                                                final uploadKey =
                                                    'Formative-$exercise-${widget.learnerID}';
                                                return uploadedExercises[
                                                        uploadKey] ??
                                                    false;
                                              }).length ==
                                              formative.length
                                          ? Icons.check_circle
                                          : Icons.check_box_outlined,
                                    ),
                                    label: Text(
                                      formative.where((item) {
                                                final exercise =
                                                    item['exercise']
                                                            ?.toString() ??
                                                        'N/A';
                                                final uploadKey =
                                                    'Formative-$exercise-${widget.learnerID}';
                                                return uploadedExercises[
                                                        uploadKey] ??
                                                    false;
                                              }).length ==
                                              formative.length
                                          ? 'All Formative Completed ✓'
                                          : 'Manual Mark All Formative',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: formative.where((item) {
                                                final exercise =
                                                    item['exercise']
                                                            ?.toString() ??
                                                        'N/A';
                                                final uploadKey =
                                                    'Formative-$exercise-${widget.learnerID}';
                                                return uploadedExercises[
                                                        uploadKey] ??
                                                    false;
                                              }).length ==
                                              formative.length
                                          ? Colors.green
                                          : Colors.orange,
                                      foregroundColor: Colors.white,
                                      minimumSize:
                                          const Size(double.infinity, 50),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        else
                          const ListTile(
                            leading:
                                Icon(Icons.info_outline, color: Colors.grey),
                            title: Text('No formative data available'),
                            subtitle: Text(
                                'This unit standard may only have logbook entries'),
                          ),
                        if (summative.isNotEmpty)
                          ExpansionTile(
                            title: Row(
                              children: [
                                const Text('Summative'),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${summative.where((item) {
                                      final exercise =
                                          item['exercise']?.toString() ?? 'N/A';
                                      final uploadKey =
                                          'Summative-$exercise-${widget.learnerID}';
                                      return uploadedExercises[uploadKey] ??
                                          false;
                                    }).length}/${summative.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              // List all summative questions
                              ...summative.map<Widget>((item) {
                                final exercise =
                                    item['exercise']?.toString() ?? 'N/A';
                                final uploadKey =
                                    'Summative-$exercise-${widget.learnerID}';
                                final isUploaded =
                                    uploadedExercises[uploadKey] ?? false;
                                final shouldShowCamera = _shouldShowCameraIcon(
                                    'Summative', exercise, unitEntry.key);

                                return ListTile(
                                  leading: Icon(
                                    isUploaded
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color:
                                        isUploaded ? Colors.green : Colors.grey,
                                  ),
                                  title: Text('Question: $exercise'),
                                  subtitle: Text(
                                    isUploaded ? 'Completed' : 'Pending',
                                    style: TextStyle(
                                      color: isUploaded
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  trailing: !isUploaded
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (shouldShowCamera)
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.camera_alt,
                                                    color: Colors.orange),
                                                onPressed: () =>
                                                    _openSummativeCamera(
                                                        context,
                                                        summative,
                                                        unitEntry.key),
                                                tooltip: 'Scan All Summative',
                                              ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.check_box_outlined,
                                                  color: Colors.orange),
                                              onPressed: () =>
                                                  _manualMarkAsUploaded(
                                                      'Summative', exercise),
                                              tooltip: 'Mark as Uploaded',
                                            ),
                                          ],
                                        )
                                      : Container(
                                          padding: const EdgeInsets.all(8.0),
                                          decoration: BoxDecoration(
                                            color: Colors.green[100],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border:
                                                Border.all(color: Colors.green),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle,
                                                  color: Colors.green,
                                                  size: 16),
                                              SizedBox(width: 4),
                                              Text(
                                                'COMPLETED',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                );
                              }).toList(),
                              // Single camera button for all summative questions (only if ready)
                              if (_isUnitStandardReadyForSummative(
                                  unitEntry.key, formative))
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: ElevatedButton.icon(
                                    onPressed: summative.where((item) {
                                              final exercise = item['exercise']
                                                      ?.toString() ??
                                                  'N/A';
                                              final uploadKey =
                                                  'Summative-$exercise-${widget.learnerID}';
                                              return uploadedExercises[
                                                      uploadKey] ??
                                                  false;
                                            }).length ==
                                            summative.length
                                        ? null // Disable if all completed
                                        : () => _openSummativeCamera(
                                            context, summative, unitEntry.key),
                                    icon: Icon(
                                      summative.where((item) {
                                                final exercise =
                                                    item['exercise']
                                                            ?.toString() ??
                                                        'N/A';
                                                final uploadKey =
                                                    'Summative-$exercise-${widget.learnerID}';
                                                return uploadedExercises[
                                                        uploadKey] ??
                                                    false;
                                              }).length ==
                                              summative.length
                                          ? Icons.check_circle
                                          : Icons.camera_alt,
                                    ),
                                    label: Text(
                                      summative.where((item) {
                                                final exercise =
                                                    item['exercise']
                                                            ?.toString() ??
                                                        'N/A';
                                                final uploadKey =
                                                    'Summative-$exercise-${widget.learnerID}';
                                                return uploadedExercises[
                                                        uploadKey] ??
                                                    false;
                                              }).length ==
                                              summative.length
                                          ? 'All Summative Completed ✓'
                                          : 'Scan All Summative Answers',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: summative.where((item) {
                                                final exercise =
                                                    item['exercise']
                                                            ?.toString() ??
                                                        'N/A';
                                                final uploadKey =
                                                    'Summative-$exercise-${widget.learnerID}';
                                                return uploadedExercises[
                                                        uploadKey] ??
                                                    false;
                                              }).length ==
                                              summative.length
                                          ? Colors.green
                                          : Colors.orange,
                                      foregroundColor: Colors.white,
                                      minimumSize:
                                          const Size(double.infinity, 50),
                                    ),
                                  ),
                                ),
                              // Manual Mark All Summative button
                              if (_isUnitStandardReadyForSummative(
                                  unitEntry.key, formative))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: ElevatedButton.icon(
                                    onPressed: summative.where((item) {
                                              final exercise = item['exercise']
                                                      ?.toString() ??
                                                  'N/A';
                                              final uploadKey =
                                                  'Summative-$exercise-${widget.learnerID}';
                                              return uploadedExercises[
                                                      uploadKey] ??
                                                  false;
                                            }).length ==
                                            summative.length
                                        ? null // Disable if all completed
                                        : () => _manualMarkAllSummative(
                                            context, summative, unitEntry.key),
                                    icon: Icon(
                                      summative.where((item) {
                                                final exercise =
                                                    item['exercise']
                                                            ?.toString() ??
                                                        'N/A';
                                                final uploadKey =
                                                    'Summative-$exercise-${widget.learnerID}';
                                                return uploadedExercises[
                                                        uploadKey] ??
                                                    false;
                                              }).length ==
                                              summative.length
                                          ? Icons.check_circle
                                          : Icons.check_box_outlined,
                                    ),
                                    label: Text(
                                      summative.where((item) {
                                                final exercise =
                                                    item['exercise']
                                                            ?.toString() ??
                                                        'N/A';
                                                final uploadKey =
                                                    'Summative-$exercise-${widget.learnerID}';
                                                return uploadedExercises[
                                                        uploadKey] ??
                                                    false;
                                              }).length ==
                                              summative.length
                                          ? 'All Summative Completed ✓'
                                          : 'Manual Mark All Summative',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: summative.where((item) {
                                                final exercise =
                                                    item['exercise']
                                                            ?.toString() ??
                                                        'N/A';
                                                final uploadKey =
                                                    'Summative-$exercise-${widget.learnerID}';
                                                return uploadedExercises[
                                                        uploadKey] ??
                                                    false;
                                              }).length ==
                                              summative.length
                                          ? Colors.green
                                          : Colors.deepOrange,
                                      foregroundColor: Colors.white,
                                      minimumSize:
                                          const Size(double.infinity, 50),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        else
                          const ListTile(
                            leading:
                                Icon(Icons.info_outline, color: Colors.grey),
                            title: Text('No summative data available'),
                            subtitle: Text(
                                'This unit standard may only have logbook entries'),
                          ),
                        // Formative Remedial Section (Optional)
                        ExpansionTile(
                          title: Row(
                            children: [
                              const Text('Formative Remedial'),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Optional',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Optional: Document formative re-assessment or additional support. Does not block progress.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _openRemedialCamera(
                                        context,
                                        unitEntry.key,
                                        'FormativeRemedial'),
                                    icon: const Icon(Icons.camera_alt),
                                    label:
                                        const Text('Scan Formative Remedial'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                      minimumSize:
                                          const Size(double.infinity, 50),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Summative Remedial Section (Optional)
                        ExpansionTile(
                          title: Row(
                            children: [
                              const Text('Summative Remedial'),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Optional',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Optional: Document summative re-assessment or additional support. Does not block progress.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _openRemedialCamera(
                                        context,
                                        unitEntry.key,
                                        'SummativeRemedial'),
                                    icon: const Icon(Icons.camera_alt),
                                    label:
                                        const Text('Scan Summative Remedial'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      minimumSize:
                                          const Size(double.infinity, 50),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                );
              }).toList(),
            );
          }),
          // Group logbook items by unit standard for better organization
          ...(() {
            Map<String, List<Map<String, dynamic>>> logBooksByUnit = {};
            for (var item in allLogBooks) {
              final unitStandard =
                  item['unitStandard']?.toString() ?? 'Unknown';
              if (!logBooksByUnit.containsKey(unitStandard)) {
                logBooksByUnit[unitStandard] = [];
              }
              logBooksByUnit[unitStandard]!.add(item);
            }

            return logBooksByUnit.entries.map<Widget>((entry) {
              final unitStandard = entry.key;
              final logBookItems = entry.value;

              return ExpansionTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Log Book - $unitStandard',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${logBookItems.where((item) {
                          final exercise =
                              item['exercise']?.toString() ?? 'N/A';
                          final uploadKey =
                              'LogBook-$exercise-${widget.learnerID}';
                          return uploadedExercises[uploadKey] ?? false;
                        }).length}/${logBookItems.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                children: [
                  // List all logbook items for this unit standard
                  ...logBookItems.map<Widget>((item) {
                    final exercise = item['exercise']?.toString() ?? 'N/A';
                    final uploadKey = 'LogBook-$exercise-${widget.learnerID}';
                    final isUploaded = uploadedExercises[uploadKey] ?? false;
                    final shouldShowCamera = _shouldShowCameraIcon(
                        'LogBook', exercise, unitStandard);

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            isUploaded
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isUploaded ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LogBook: $exercise',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isUploaded ? 'Completed' : 'Pending',
                                  style: TextStyle(
                                    color: isUploaded
                                        ? Colors.green
                                        : Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isUploaded) ...[
                            if (shouldShowCamera)
                              IconButton(
                                icon: const Icon(Icons.camera_alt,
                                    color: Colors.green, size: 20),
                                onPressed: () => _openLogBookCamera(
                                    context, logBookItems, unitStandard),
                                tooltip: 'Scan All LogBook',
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                              ),
                            IconButton(
                              icon: const Icon(Icons.check_box_outlined,
                                  color: Colors.orange, size: 20),
                              onPressed: () =>
                                  _manualMarkAsUploaded('LogBook', exercise),
                              tooltip: 'Mark as Uploaded',
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ] else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 4.0),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'DONE',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  }),

                  // Scan All LogBook button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: logBookItems.where((item) {
                                final exercise =
                                    item['exercise']?.toString() ?? 'N/A';
                                final uploadKey =
                                    'LogBook-$exercise-${widget.learnerID}';
                                return uploadedExercises[uploadKey] ?? false;
                              }).length ==
                              logBookItems.length
                          ? null // Disable if all completed
                          : () => _openLogBookCamera(
                              context, logBookItems, unitStandard),
                      icon: Icon(
                        logBookItems.where((item) {
                                  final exercise =
                                      item['exercise']?.toString() ?? 'N/A';
                                  final uploadKey =
                                      'LogBook-$exercise-${widget.learnerID}';
                                  return uploadedExercises[uploadKey] ?? false;
                                }).length ==
                                logBookItems.length
                            ? Icons.check_circle
                            : Icons.camera_alt,
                      ),
                      label: Text(
                        logBookItems.where((item) {
                                  final exercise =
                                      item['exercise']?.toString() ?? 'N/A';
                                  final uploadKey =
                                      'LogBook-$exercise-${widget.learnerID}';
                                  return uploadedExercises[uploadKey] ?? false;
                                }).length ==
                                logBookItems.length
                            ? 'All LogBook Completed ✓'
                            : 'Scan All LogBook Entries',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: logBookItems.where((item) {
                                  final exercise =
                                      item['exercise']?.toString() ?? 'N/A';
                                  final uploadKey =
                                      'LogBook-$exercise-${widget.learnerID}';
                                  return uploadedExercises[uploadKey] ?? false;
                                }).length ==
                                logBookItems.length
                            ? Colors.green
                            : Colors.green[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),

                  // Manual Mark All LogBook button
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 8.0, left: 16.0, right: 16.0, bottom: 16.0),
                    child: ElevatedButton.icon(
                      onPressed: logBookItems.where((item) {
                                final exercise =
                                    item['exercise']?.toString() ?? 'N/A';
                                final uploadKey =
                                    'LogBook-$exercise-${widget.learnerID}';
                                return uploadedExercises[uploadKey] ?? false;
                              }).length ==
                              logBookItems.length
                          ? null // Disable if all completed
                          : () => _manualMarkAllLogBook(
                              context, logBookItems, unitStandard),
                      icon: Icon(
                        logBookItems.where((item) {
                                  final exercise =
                                      item['exercise']?.toString() ?? 'N/A';
                                  final uploadKey =
                                      'LogBook-$exercise-${widget.learnerID}';
                                  return uploadedExercises[uploadKey] ?? false;
                                }).length ==
                                logBookItems.length
                            ? Icons.check_circle
                            : Icons.check_box_outlined,
                      ),
                      label: Text(
                        logBookItems.where((item) {
                                  final exercise =
                                      item['exercise']?.toString() ?? 'N/A';
                                  final uploadKey =
                                      'LogBook-$exercise-${widget.learnerID}';
                                  return uploadedExercises[uploadKey] ?? false;
                                }).length ==
                                logBookItems.length
                            ? 'All LogBook Completed ✓'
                            : 'Manual Mark All LogBook',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: logBookItems.where((item) {
                                  final exercise =
                                      item['exercise']?.toString() ?? 'N/A';
                                  final uploadKey =
                                      'LogBook-$exercise-${widget.learnerID}';
                                  return uploadedExercises[uploadKey] ?? false;
                                }).length ==
                                logBookItems.length
                            ? Colors.green
                            : Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                ],
              );
            }).toList();
          })(),

          if (allLogBooks.isEmpty)
            const ListTile(
              title: Text('No log book data available'),
            ),
        ],
      );
    }
  }

  @override
  void dispose() {
    _fingerprintService.dispose();
    logBookControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }
}
