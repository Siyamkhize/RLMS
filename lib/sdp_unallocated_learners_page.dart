import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'config.dart';
import 'database_helper.dart';
import 'LearnerDetailsPage.dart';
import 'finance_register_history.dart';

class UnallocatedLearnersPage extends StatefulWidget {
  final String sdpIdentifier;
  final String projectId;
  final String projectName;

  const UnallocatedLearnersPage({
    super.key,
    required this.sdpIdentifier,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<UnallocatedLearnersPage> createState() =>
      _UnallocatedLearnersPageState();
}

class _UnallocatedLearnersPageState extends State<UnallocatedLearnersPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _unallocatedLearners = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isScanning = false;

  final List<String> requiredDocuments = [
    'ID Document',
    'Qualifications',
    'Bank Confirmation Letter',
    'Proof of Residence',
    'CV',
    'Business form',
    'Learner agreement'
  ];
  final int _maxFileSize = 5 * 1024 * 1024; // 5MB
  final int _minFileSize = 10 * 1024; // 10KB

  // Server endpoints
  String get _uploadUrl => AppConfig.buildUrl('upload_learner_document.php');
  String get _checkDocsUrl => AppConfig.buildUrl('check_learner_documents.php');

  @override
  void initState() {
    super.initState();
    _createLocalTable();
    _fetchUnallocatedLearners();
  }

  /// Create learner_assignments table in local database
  Future<void> _createLocalTable() async {
    try {
      final db = await _dbHelper.database;

      await db.execute('''
        CREATE TABLE IF NOT EXISTS learner_assignments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          LearnerID INTEGER NOT NULL UNIQUE,
          Ward TEXT,
          councillor TEXT,
          projectID INTEGER,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          synced INTEGER DEFAULT 0
        )
      ''');

      // Create indexes
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_learner_id ON learner_assignments(LearnerID)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_project_id ON learner_assignments(projectID)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_ward ON learner_assignments(Ward)');

      debugPrint('[UNALLOCATED] learner_assignments table created/verified');
    } catch (e) {
      debugPrint('[UNALLOCATED] Error creating table: $e');
    }
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Fetch unallocated learners from server
  Future<void> _fetchUnallocatedLearners() async {
    setState(() => _isLoading = true);

    try {
      // First, sync learner_assignments from server to local
      await _syncLearnerAssignments();

      // Then get unallocated learners
      final response = await http
          .get(
            Uri.parse(
                '${AppConfig.baseUrl}/get_unallocated_learners.php?projectId=${widget.projectId}'),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          setState(() {
            _unallocatedLearners =
                List<Map<String, dynamic>>.from(data['learners'] ?? []);
            _isLoading = false;
          });

          debugPrint(
              '[UNALLOCATED] Loaded ${_unallocatedLearners.length} unallocated learners');
        } else {
          throw Exception(data['message'] ?? 'Failed to load learners');
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[UNALLOCATED] Error fetching learners: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading learners: $e')),
        );
      }
    }
  }

  /// Sync learner_assignments from server to local database
  Future<void> _syncLearnerAssignments() async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '${AppConfig.baseUrl}/get_learner_assignments.php?projectId=${widget.projectId}'),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final assignments =
              List<Map<String, dynamic>>.from(data['assignments'] ?? []);
          final db = await _dbHelper.database;

          // Insert/update assignments in local database
          for (final assignment in assignments) {
            await db.insert(
              'learner_assignments',
              {
                'LearnerID': assignment['LearnerID'],
                'Ward': assignment['Ward'],
                'councillor': assignment['councillor'],
                'projectID': assignment['projectID'],
                'created_at': assignment['created_at'],
                'updated_at': assignment['updated_at'],
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          debugPrint(
              '[UNALLOCATED] Synced ${assignments.length} learner assignments');
        }
      }
    } catch (e) {
      debugPrint('[UNALLOCATED] Error syncing assignments: $e');
    }
  }

  // Document management functions
  Future<bool> hasAnyDocuments(String learnerId) async {
    try {
      final localDocs = await _dbHelper.fetchLearnerDocuments(learnerId);

      if (localDocs.isNotEmpty) {
        return true;
      }

      if (await _checkConnectivity()) {
        final serverDocs = await _fetchServerDocuments(learnerId);
        return serverDocs.isNotEmpty;
      }

      return false;
    } catch (e) {
      print('Error checking documents: $e');
      return false;
    }
  }

  Future<List<String>> getExistingDocuments(String learnerId) async {
    try {
      List<String> existingDocs = [];

      final localDocs = await _dbHelper.fetchLearnerDocuments(learnerId);
      existingDocs =
          localDocs.map((doc) => doc['documentName'] as String).toList();

      if (await _checkConnectivity()) {
        final serverDocs = await _fetchServerDocuments(learnerId);
        for (var doc in serverDocs) {
          if (!existingDocs.contains(doc)) {
            existingDocs.add(doc);
          }
        }
      }

      return existingDocs;
    } catch (e) {
      print('Error getting existing documents: $e');
      return [];
    }
  }

  Future<bool> canUploadDocuments(String learnerId) async {
    try {
      final existingDocs = await getExistingDocuments(learnerId);
      return requiredDocuments.any((doc) => !existingDocs.contains(doc));
    } catch (e) {
      print('Error checking if documents can be uploaded: $e');
      return false;
    }
  }

  Future<List<String>> _fetchServerDocuments(String learnerId) async {
    try {
      final response = await http.post(
        Uri.parse(_checkDocsUrl),
        body: {'learner_id': learnerId},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return List<String>.from(jsonResponse['documents']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching server documents: $e');
      return [];
    }
  }

  Future<void> uploadDocument(
      String learnerId, String documentName, String filePath) async {
    try {
      final document = {
        'learner_id': learnerId,
        'documentName': documentName,
        'learner_document': filePath,
        'status': 'Pending',
        'upload_date': DateTime.now().toIso8601String(),
        'synced': 0,
      };
      await _dbHelper.insertLearnerDocument(document);

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$documentName uploaded locally')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload $documentName: $e')),
      );
      rethrow;
    }
  }

  void showDocumentUploadModal(BuildContext context, String learnerId) {
    String? selectedDocument;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return FutureBuilder<List<String>>(
              future: getExistingDocuments(learnerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AlertDialog(
                    title: Text('Loading...'),
                    content: Center(child: CircularProgressIndicator()),
                  );
                }

                final existingDocs = snapshot.data ?? [];
                final availableDocs = requiredDocuments
                    .where((doc) => !existingDocs.contains(doc))
                    .toList();

                if (availableDocs.isEmpty) {
                  return AlertDialog(
                    title: const Text('All Documents Uploaded'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'All required documents have already been uploaded for this learner.'),
                        const SizedBox(height: 8),
                        Text('Existing documents: ${existingDocs.join(', ')}'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  );
                }

                return AlertDialog(
                  title: const Text('Upload Document'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Available documents to upload: ${availableDocs.length}/${requiredDocuments.length}'),
                      const SizedBox(height: 8),
                      if (existingDocs.isNotEmpty)
                        Text('Already uploaded: ${existingDocs.join(', ')}'),
                      const SizedBox(height: 16),
                      DropdownButton<String>(
                        hint: const Text('Select Document Type'),
                        value: selectedDocument,
                        isExpanded: true,
                        items: availableDocs.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedDocument = newValue;
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: selectedDocument == null || _isScanning
                          ? null
                          : () async {
                              setState(() => _isScanning = true);
                              try {
                                final status =
                                    await Permission.camera.request();
                                if (!status.isGranted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Camera permission denied. Please enable it in settings.',
                                      ),
                                    ),
                                  );
                                  await openAppSettings();
                                  return;
                                }

                                final scanner = FlutterDocScanner();
                                final scanResult =
                                    await scanner.getScanDocuments(
                                  page: 999,
                                );
                                if (scanResult is! Map ||
                                    !scanResult.containsKey('pdfUri') ||
                                    scanResult['pdfUri'] == null) {
                                  throw 'Invalid scan result';
                                }

                                final pdfPath = (scanResult['pdfUri'] as String)
                                    .replaceFirst('file:///', '');
                                final file = File(pdfPath);

                                if (!await file.exists() ||
                                    !pdfPath.endsWith('.pdf')) {
                                  throw 'Invalid or missing PDF file';
                                }

                                final fileSize = await file.length();
                                if (fileSize > _maxFileSize) {
                                  throw 'File size exceeds 5MB limit';
                                }
                                if (fileSize < _minFileSize) {
                                  throw 'The scanned page may not be clear. Ensure text is sharp and entire page is captured.';
                                }

                                await uploadDocument(
                                    learnerId, selectedDocument!, pdfPath);
                                Navigator.pop(context);
                                this.setState(() {});
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Error scanning document: $e')),
                                );
                              } finally {
                                setState(() => _isScanning = false);
                              }
                            },
                      child: const Text('Scan and Upload'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> get _filteredLearners {
    if (_searchQuery.isEmpty) return _unallocatedLearners;

    return _unallocatedLearners.where((learner) {
      final name = '${learner['Name']} ${learner['Surname']}'.toLowerCase();
      final idNumber = learner['IDNumber']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return name.contains(query) || idNumber.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unallocated Learners'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUnallocatedLearners,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or ID number',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Learners list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLearners.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle,
                                size: 64, color: Colors.green),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'All learners are allocated!'
                                  : 'No learners found',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Surname')),
                              DataColumn(label: Text('ID Number')),
                              DataColumn(label: Text('Phone')),
                              DataColumn(label: Text('Action')),
                            ],
                            rows: _filteredLearners.map((learner) {
                              final learnerId =
                                  learner['LearnerID']?.toString() ?? 'N/A';
                              return DataRow(cells: [
                                DataCell(Text(learner['Name'] ?? '')),
                                DataCell(Text(learner['Surname'] ?? '')),
                                DataCell(Text(learner['IDNumber'] ?? '')),
                                DataCell(Text(learner['PhoneNumber'] ?? 'N/A')),
                                DataCell(
                                  Row(
                                    children: [
                                      FutureBuilder<bool>(
                                        future: hasAnyDocuments(learnerId),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const CircularProgressIndicator();
                                          }
                                          bool hasDocuments =
                                              snapshot.data ?? false;
                                          return ElevatedButton(
                                            onPressed: hasDocuments
                                                ? () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            LearnerDetailsPage(
                                                          learnerID: learnerId,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                : null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: hasDocuments
                                                  ? Colors.blue
                                                  : Colors.grey,
                                            ),
                                            child: const Text('View'),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      FutureBuilder<bool>(
                                        future: canUploadDocuments(learnerId),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const CircularProgressIndicator();
                                          }
                                          bool canUpload =
                                              snapshot.data ?? false;
                                          return ElevatedButton(
                                            onPressed: !canUpload || _isScanning
                                                ? null
                                                : () => showDocumentUploadModal(
                                                      context,
                                                      learnerId,
                                                    ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: canUpload
                                                  ? Colors.green
                                                  : Colors.grey,
                                            ),
                                            child: const Text('Documents'),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          final learnerName =
                                              '${learner['Surname'] ?? ''} ${learner['Name'] ?? ''}'
                                                  .trim();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  FinanceRegisterHistory(
                                                learnerId: learnerId,
                                                learnerName: learnerName,
                                                classId: widget.projectId,
                                                className: widget.projectName,
                                                financeId: widget.projectId,
                                              ),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                        ),
                                        child: const Text('Attendance'),
                                      ),
                                    ],
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
