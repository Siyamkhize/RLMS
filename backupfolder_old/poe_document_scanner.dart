import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'config.dart';

class PoeDocumentScanner extends StatefulWidget {
  final int learnerId;
  final String learnerName;
  final String? classId;
  final String? siteName;
  final String? uploadedBy;
  final int? partNumber; // For multi-part documents
  final int? totalParts; // Total expected parts

  const PoeDocumentScanner({
    super.key,
    required this.learnerId,
    required this.learnerName,
    this.classId,
    this.siteName,
    this.uploadedBy,
    this.partNumber,
    this.totalParts,
  });

  @override
  State<PoeDocumentScanner> createState() => _PoeDocumentScannerState();
}

class _PoeDocumentScannerState extends State<PoeDocumentScanner> {
  bool _isScanning = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _statusMessage;
  List<String> _scannedPages = [];
  File? _pdfFile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan POE Document'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Learner info card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.learnerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Learner ID: ${widget.learnerId}'),
                    if (widget.classId != null)
                      Text('Class: ${widget.classId}'),
                    if (widget.siteName != null)
                      Text('Site: ${widget.siteName}'),
                    if (widget.partNumber != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Part ${widget.partNumber}${widget.totalParts != null ? ' of ${widget.totalParts}' : ''}',
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Instructions
            if (_pdfFile == null && !_isScanning)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        '🔴 MAXIMUM: 100 Pages Per Batch',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: const Text(
                          'Scanner WILL CRASH if you scan 200+ pages!\n\n'
                          'Why? Google ML Kit runs out of memory.\n\n'
                          'SOLUTION for 200 pages:\n'
                          '1. Scan pages 1-100 → Upload\n'
                          '2. Scan pages 101-200 → Upload\n\n'
                          'This is a scanner plugin limitation.',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Scanned PDF info
            if (_pdfFile != null)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FutureBuilder<int>(
                          future: _pdfFile!.length(),
                          builder: (context, snapshot) {
                            final sizeText = snapshot.hasData
                                ? '${(snapshot.data! / 1024 / 1024).toStringAsFixed(2)} MB'
                                : 'Calculating...';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PDF Document Ready',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text('Size: $sizeText'),
                              ],
                            );
                          },
                        ),
                      ),
                      if (!_isUploading)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: _clearScannedPages,
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Status message
            if (_statusMessage != null)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Upload progress
            if (_isUploading)
              Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text(
                    '${(_uploadProgress * 100).toStringAsFixed(0)}% uploaded',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),

            const Spacer(),

            // Action buttons
            if (!_isUploading) ...[
              ElevatedButton.icon(
                onPressed: _isScanning ? null : _startScanning,
                icon: _isScanning
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.document_scanner),
                label: Text(_isScanning ? 'Scanning...' : 'Start Scanning'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              if (_pdfFile != null) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _uploadDocument,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Upload Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startScanning() async {
    // Show CRITICAL warning dialog before starting scan
    if (_pdfFile == null) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning, color: Colors.red, size: 32),
              SizedBox(width: 8),
              Expanded(child: Text('CRITICAL: Scanner Limits')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '🔴 MAXIMUM: 100 pages per batch',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'The scanner WILL CRASH if you scan 200 pages at once!\n\n'
                  'Why? Google ML Kit runs out of memory processing too many pages.\n\n'
                  'SOLUTION:\n'
                  '✓ Scan 50-100 pages maximum per batch\n'
                  '✓ Upload each batch immediately\n'
                  '✓ Then scan the next batch\n'
                  '✓ Repeat until all pages scanned\n\n'
                  'Example for 200 pages:\n'
                  '• Batch 1: Scan pages 1-100, upload\n'
                  '• Batch 2: Scan pages 101-200, upload\n\n'
                  'This is a limitation of the scanner plugin, not our app.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('I Understand - Start Scanning'),
            ),
          ],
        ),
      );
      
      if (shouldContinue != true) return;
    }
    
    setState(() {
      _isScanning = true;
      _statusMessage = 'Opening scanner... Scan continuously for best results!';
    });

    try {
      // Use FlutterDocScanner with unlimited pages (same as CameraScanPage)
      // No timeout - let scanner run as long as needed for large documents
      final dynamic scanResult = await FlutterDocScanner().getScanDocuments(
        page: 999, // Unlimited pages
      );
      
      print('Scan Result: $scanResult');
      
      if (scanResult is! Map ||
          !scanResult.containsKey('pdfUri') ||
          scanResult['pdfUri'] == null) {
        print('Invalid scan result: $scanResult');
        setState(() {
          _isScanning = false;
          _statusMessage = 'Scanner session ended without saving. This happens when:\n'
              '• You take long pauses (Android kills the scanner)\n'
              '• The document is too large (memory issues)\n'
              '• The app was backgrounded during scanning';
        });
        
        // Show helpful message for large documents
        _showErrorDialog(
          'Scanner Session Lost',
          'The scanner session was terminated by Android. This commonly happens when:\n\n'
          '❌ Taking long pauses between pages (>2-3 minutes)\n'
          '❌ Scanning 100+ pages in one session\n'
          '❌ Switching to other apps during scanning\n'
          '❌ Device running low on memory\n\n'
          'Solutions:\n'
          '✓ Scan continuously without long pauses\n'
          '✓ Scan in batches of 50-80 pages\n'
          '✓ Keep this app in foreground\n'
          '✓ Close other apps to free memory\n'
          '✓ Restart device if problem persists',
        );
        return;
      }

      final String? pdfUri = scanResult['pdfUri'] as String?;
      final pdfPath = pdfUri!.replaceFirst('file:///', '');
      print('Processed PDF Path: $pdfPath');

      final file = File(pdfPath);
      if (await file.exists()) {
        final fileSize = await file.length();
        print('PDF exists: ${file.path}, size: $fileSize bytes');
        
        // Check if file is too large (> 150MB)
        if (fileSize > 150 * 1024 * 1024) {
          setState(() {
            _isScanning = false;
            _statusMessage = 'PDF too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB). Maximum 150MB.';
          });
          _showErrorDialog(
            'File Too Large',
            'The scanned PDF is ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB, which exceeds the 150MB limit.\n\n'
            'Please scan fewer pages or reduce image quality.',
          );
          return;
        }
        
        setState(() {
          _pdfFile = file;
          _scannedPages = [pdfPath]; // Store path for display
          _isScanning = false;
          _statusMessage = 'PDF scanned successfully! Size: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB\n'
              'Tip: Upload now to avoid losing data!';
        });
        
        _showSnackBar('PDF document scanned successfully! Upload it now.');
      } else {
        print('Error: PDF does not exist at $pdfPath');
        setState(() {
          _isScanning = false;
          _statusMessage = 'PDF file not found. Scanner session was terminated.';
        });
        
        _showErrorDialog(
          'Scanner Session Lost',
          'The scanner failed to save the PDF file. This happens when:\n\n'
          '• Android terminated the scanner due to long idle time\n'
          '• The document was too large for available memory\n'
          '• The app was backgrounded during scanning\n\n'
          'Solution: Scan in smaller batches (50-80 pages) without long pauses.',
        );
      }
    } catch (e, stackTrace) {
      print('Scan Error: $e\nStack Trace: $stackTrace');
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scanning error: $e';
      });
      
      // Check for plugin initialization error
      if (e.toString().contains('UninitializedPropertyAccessException') ||
          e.toString().contains('resultChannel')) {
        _showErrorDialog(
          'Scanner Plugin Error',
          'The scanner plugin encountered an error. This can happen when scanning multiple times.\n\n'
          'Solutions:\n'
          '• Close this screen and open it again\n'
          '• Restart the app\n'
          '• If problem persists, restart your device\n\n'
          'Your previous scan was saved successfully.',
        );
        return;
      }
      
      // Check if it's the Google ML Kit cache error
      if (e.toString().contains('FileNotFoundException') || 
          e.toString().contains('ENOENT')) {
        _showErrorDialog(
          'Scanner Cache Error',
          'The document scanner ran out of cache space. This typically happens with very large documents (100+ pages).\n\n'
          'Solutions:\n'
          '• Scan in smaller batches (50-100 pages)\n'
          '• Clear app cache and try again\n'
          '• Restart the device\n'
          '• Free up device storage',
        );
      } else {
        _showErrorDialog('Scanning Error', 'Error: $e');
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  // No longer needed - scanner creates PDF directly

  Future<void> _uploadDocument() async {
    if (_pdfFile == null) {
      _showError('No document to upload');
      return;
    }

    print('=== Starting POE Document Upload ===');
    print('File path: ${_pdfFile!.path}');
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _statusMessage = 'Preparing upload...';
    });

    try {
      final fileSize = await _pdfFile!.length();
      print('File size: $fileSize bytes (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
      
      // ALWAYS use chunked upload since server requires it
      // Server is configured to only accept chunked uploads
      print('Using chunked upload (server requirement)...');
      await _uploadChunked();

      print('Upload completed successfully!');
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.partNumber != null
                  ? 'Part ${widget.partNumber} uploaded successfully!'
                  : 'Document uploaded successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Close the scanner screen after successful upload
        // This prevents the plugin initialization error on subsequent scans
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e, stackTrace) {
      print('Upload error: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isUploading = false;
        _statusMessage = 'Upload failed: $e';
      });
      
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Upload Failed'),
            content: Text('Error: $e\n\nPlease try again or contact support if the problem persists.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _uploadDirect() async {
    print('Starting direct upload...');
    
    // Use AppConfig to get the correct base URL
    // TEMPORARY: Using strict-mode-fixed endpoint to resolve 500 error
    final uri = Uri.parse('${AppConfig.baseUrl}/upload_poe_document_strict_fixed.php');
    print('Upload URL: $uri');

    var request = http.MultipartRequest('POST', uri);

    request.fields['learner_id'] = widget.learnerId.toString();
    request.fields['learner_name'] = widget.learnerName;
    request.fields['document_type'] = widget.partNumber != null ? 'POE_PART' : 'POE';
    request.fields['page_count'] = '0'; // Unknown page count from scanner

    if (widget.classId != null) {
      request.fields['class_id'] = widget.classId!;
    }
    if (widget.siteName != null) {
      request.fields['site_name'] = widget.siteName!;
    }
    if (widget.uploadedBy != null) {
      request.fields['uploaded_by'] = widget.uploadedBy!;
    }
    if (widget.partNumber != null) {
      request.fields['notes'] = 'Part ${widget.partNumber}${widget.totalParts != null ? ' of ${widget.totalParts}' : ''}';
    }

    print('Request fields: ${request.fields}');
    print('Adding file: ${_pdfFile!.path}');
    
    request.files.add(
      await http.MultipartFile.fromPath('poe_document', _pdfFile!.path),
    );

    setState(() {
      _statusMessage = 'Uploading...';
    });

    print('Sending request...');
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    
    print('Response status: ${response.statusCode}');
    print('Response body: $responseBody');

    if (response.statusCode == 200) { 
      try {
        final jsonResponse = json.decode(responseBody);
        print('Parsed JSON response: $jsonResponse');
        
        if (jsonResponse['success'] != true) {
          throw Exception(jsonResponse['message'] ?? 'Upload failed');
        }
        
        print('Direct upload successful!');
      } catch (e) {
        print('Error parsing response: $e');
        print('Raw response: $responseBody');
        throw Exception('Invalid server response: $e');
      }
    } else {
      throw Exception('Server error: ${response.statusCode} - $responseBody');
    }
  }

 Future<void> _uploadChunked() async {
  print('Starting chunked upload...');
  const chunkSize = 2 * 1024 * 1024; // 2MB chunks
  
  try {
    // CRITICAL FIX: Don't load entire file into memory!
    // For 200 pages (~50MB+), this causes out-of-memory crash
    // Instead, read file size and stream chunks directly from disk
    final fileSize = await _pdfFile!.length();
    print('File size: $fileSize bytes (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
    
    final totalChunks = (fileSize / chunkSize).ceil();
    final fileId = DateTime.now().millisecondsSinceEpoch.toString();
    
    print('Total chunks: $totalChunks, File ID: $fileId');

    // Open file for reading
    final randomAccessFile = await _pdfFile!.open(mode: FileMode.read);
    
    try {
      for (int i = 0; i < totalChunks; i++) {
        print('Uploading chunk ${i + 1} of $totalChunks...');
        
        final start = i * chunkSize;
        final end = min(start + chunkSize, fileSize);
        final chunkLength = end - start;
        
        // Read only this chunk from disk (memory efficient!)
        await randomAccessFile.setPosition(start);
        final chunk = await randomAccessFile.read(chunkLength);
        
        print('Chunk $i: ${chunk.length} bytes (from $start to $end)');

        // TEMPORARY: Using strict-mode-fixed endpoint to resolve 500 error
        final uri = Uri.parse('${AppConfig.baseUrl}/upload_poe_document_strict_fixed.php');
        print('[CONFIG] Base URL: ${AppConfig.baseUrl}');
        print('Upload URL: $uri');
        
        var request = http.MultipartRequest('POST', uri);

        request.fields['chunk_index'] = i.toString();
        request.fields['total_chunks'] = totalChunks.toString();
        request.fields['file_id'] = fileId;
        request.fields['file_extension'] = 'pdf';
        
        // Send metadata with EVERY chunk
        request.fields['learner_id'] = widget.learnerId.toString();
        request.fields['learner_name'] = widget.learnerName;
        request.fields['document_type'] = widget.partNumber != null ? 'POE_PART' : 'POE';
        request.fields['page_count'] = '0';
        
        if (widget.classId != null) {
          request.fields['class_id'] = widget.classId!;
        }
        if (widget.siteName != null) {
          request.fields['site_name'] = widget.siteName!;
        }
        if (widget.uploadedBy != null) {
          request.fields['uploaded_by'] = widget.uploadedBy!;
        }
        if (widget.partNumber != null) {
          request.fields['notes'] = 'Part ${widget.partNumber}${widget.totalParts != null ? ' of ${widget.totalParts}' : ''}';
        }

        // Send chunk as multipart file (not base64)
        // PHP expects $_FILES['chunk']
        request.files.add(
          http.MultipartFile.fromBytes(
            'chunk',
            chunk,
            filename: 'chunk_$i.bin',
          ),
        );
        
        print('Sending chunk ${i + 1}...');
        final response = await request.send();
        final responseBody = await response.stream.bytesToString();
        
        print('Chunk ${i + 1} response status: ${response.statusCode}');
        print('Chunk ${i + 1} response body: $responseBody');

        if (response.statusCode != 200) {
          throw Exception('Chunk $i upload failed: HTTP ${response.statusCode}');
        }
        
        try {
          final jsonResponse = json.decode(responseBody);
          if (jsonResponse['success'] != true) {
            throw Exception('Chunk $i failed: ${jsonResponse['message'] ?? 'Unknown error'}');
          }
          
          print('Chunk ${i + 1} uploaded successfully');
          
          // Optional: Log the chunk size verification from server response
          if (jsonResponse.containsKey('chunk_size')) {
            print('Server confirmed chunk size: ${jsonResponse['chunk_size']} bytes');
          }
        } catch (e) {
          print('Error parsing response for chunk $i: $e');
          print('Raw response: $responseBody');
          throw Exception('Invalid response for chunk $i: $e');
        }

        setState(() {
          _uploadProgress = (i + 1) / totalChunks;
          _statusMessage = 'Uploading chunk ${i + 1} of $totalChunks...';
        });
        
        // Clear chunk from memory immediately
        // This is critical for large files to prevent memory buildup
      }
    } finally {
      // Always close the file handle
      await randomAccessFile.close();
      print('File handle closed');
    }
    
    print('All chunks uploaded successfully!');
  } catch (e, stackTrace) {
    print('Chunked upload error: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}

  void _clearScannedPages() {
    setState(() {
      _scannedPages.clear();
      _pdfFile = null;
      _statusMessage = null;
      _uploadProgress = 0.0;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
