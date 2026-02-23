import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'config.dart';
import 'database_helper.dart';
import 'LearnerDetailsPage.dart';

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
  final PagingController<int, Map<String, dynamic>> _pagingController =
      PagingController(firstPageKey: 0);

  String _searchQuery = '';
  bool _isScanning = false;
  static const int _pageSize = 20;

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
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  /// Create local tables for offline support
  Future<void> _createLocalTable() async {
    try {
      final db = await _dbHelper.database;

      // Table 1: Learner assignments
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

      // Table 2: Sites and classes cache
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sdp_sites_classes_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sdp_id TEXT NOT NULL,
          project_id TEXT NOT NULL,
          site_data TEXT NOT NULL,
          cached_at TEXT DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(sdp_id, project_id)
        )
      ''');

      // Table 3: Unallocated learners cache
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sdp_unallocated_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sdp_id TEXT NOT NULL,
          project_id TEXT NOT NULL,
          learner_id INTEGER NOT NULL,
          learner_data TEXT NOT NULL,
          cached_at TEXT DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(sdp_id, project_id, learner_id)
        )
      ''');

      // Table 4: Pending assignments (offline queue)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sdp_pending_assignments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          learner_id INTEGER NOT NULL,
          class_id INTEGER NOT NULL,
          class_name TEXT,
          assigned_at TEXT DEFAULT CURRENT_TIMESTAMP,
          synced INTEGER DEFAULT 0,
          UNIQUE(learner_id)
        )
      ''');

      // Create indexes
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_learner_id ON learner_assignments(LearnerID)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_project_id ON learner_assignments(projectID)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_ward ON learner_assignments(Ward)');

      debugPrint('[UNALLOCATED] Offline tables created/verified');
    } catch (e) {
      debugPrint('[UNALLOCATED] Error creating tables: $e');
    }
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Fetch paginated learners from server
  Future<void> _fetchPage(int pageKey) async {
    try {
      // First, sync learner_assignments from server to local
      if (pageKey == 0) {
        await _syncLearnerAssignments();
      }

      // Calculate offset
      final offset = pageKey * _pageSize;

      // Fetch learners with pagination
      final response = await http
          .get(
            Uri.parse(
                '${AppConfig.baseUrl}/get_unallocated_learners.php?projectId=${widget.projectId}&limit=$_pageSize&offset=$offset&search=$_searchQuery'),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final learners =
              List<Map<String, dynamic>>.from(data['learners'] ?? []);
          final isLastPage = learners.length < _pageSize;

          if (isLastPage) {
            _pagingController.appendLastPage(learners);
          } else {
            final nextPageKey = pageKey + 1;
            _pagingController.appendPage(learners, nextPageKey);
          }

          debugPrint(
              '[UNALLOCATED] Loaded ${learners.length} learners for page $pageKey');
        } else {
          _pagingController.error =
              data['message'] ?? 'Failed to load learners';
        }
      } else {
        _pagingController.error = 'Server returned ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('[UNALLOCATED] Error fetching learners: $e');
      _pagingController.error = e;
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

  Future<void> _syncDocument(Map<String, dynamic> document) async {
    try {
      final filePath = document['learner_document'] as String;
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Document file not found: $filePath');
      }

      var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['learner_id'] = document['learner_id'].toString();
      request.fields['documentName'] = document['documentName'];
      request.fields['status'] = document['status'];
      request.fields['upload_date'] = document['upload_date'];
      request.fields['synced'] = '1';
      if (document['rejection_reason'] != null) {
        request.fields['rejection_reason'] = document['rejection_reason'];
      }

      request.files.add(await http.MultipartFile.fromPath(
        'learner_document',
        filePath,
        filename: filePath.split('/').last,
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        if (jsonResponse['success'] == true) {
          await _dbHelper.updateLearnerDocumentSynced(
              document['document_id'], 1);
          print(
              'Document synced: ${document['documentName']} for learner ${document['learner_id']}');
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to sync document');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing document: $e');
      rethrow;
    }
  }

  Future<void> syncUnsyncedDocuments() async {
    if (!await _checkConnectivity()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection, cannot sync')),
      );
      return;
    }

    try {
      // Sync documents
      final unsyncedDocs = await _dbHelper.fetchUnsyncedLearnerDocuments();
      print('Found ${unsyncedDocs.length} unsynced documents');

      for (var doc in unsyncedDocs) {
        await _syncDocument(doc);
      }

      // Sync pending assignments
      await _syncPendingAssignments();

      if (unsyncedDocs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Synced ${unsyncedDocs.length} documents to server')),
        );
      }

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error syncing: $e')),
      );
    }
  }

  // Sync pending assignments
  Future<void> _syncPendingAssignments() async {
    try {
      final db = await _dbHelper.database;

      final pending = await db.query(
        'sdp_pending_assignments',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (pending.isEmpty) {
        debugPrint('[SYNC] No pending assignments to sync');
        return;
      }

      debugPrint('[SYNC] Syncing ${pending.length} pending assignments');
      int synced = 0;

      for (var assignment in pending) {
        try {
          final response = await http.post(
            Uri.parse('${AppConfig.baseUrl}/assign_learner_to_class.php'),
            body: {
              'learner_id': assignment['learner_id'].toString(),
              'class_id': assignment['class_id'].toString(),
            },
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['success'] == true) {
              // Mark as synced
              await db.update(
                'sdp_pending_assignments',
                {'synced': 1},
                where: 'id = ?',
                whereArgs: [assignment['id']],
              );
              synced++;
              debugPrint('[SYNC] Synced assignment ${assignment['id']}');
            }
          }
        } catch (e) {
          debugPrint('[SYNC] Error syncing assignment ${assignment['id']}: $e');
        }
      }

      if (synced > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synced $synced learner assignments')),
        );

        // Clean up synced assignments
        await db.delete(
          'sdp_pending_assignments',
          where: 'synced = ?',
          whereArgs: [1],
        );

        // Refresh the list
        _pagingController.refresh();
      }
    } catch (e) {
      debugPrint('[SYNC] Error syncing assignments: $e');
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

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _pagingController.refresh();
  }

  // Fetch sites for this project and SDP (with offline support)
  Future<List<Map<String, dynamic>>> _fetchSites() async {
    try {
      final isOnline = await _checkConnectivity();

      if (isOnline) {
        // Try to fetch from server
        final response = await http
            .get(
              Uri.parse(
                  '${AppConfig.baseUrl}/get_sites_and_classes.php?action=get_sites&sdp_id=${widget.sdpIdentifier}&project_id=${widget.projectId}'),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            final sites = List<Map<String, dynamic>>.from(data['data'] ?? []);

            // Cache the sites data
            await _cacheSitesData(sites);

            return sites;
          }
        }
      }

      // Fallback to cached data (offline or server error)
      return await _getCachedSites();
    } catch (e) {
      debugPrint('[ASSIGN] Error fetching sites: $e');
      // Return cached data on error
      return await _getCachedSites();
    }
  }

  // Cache sites data locally
  Future<void> _cacheSitesData(List<Map<String, dynamic>> sites) async {
    try {
      final db = await _dbHelper.database;

      await db.insert(
        'sdp_sites_classes_cache',
        {
          'sdp_id': widget.sdpIdentifier,
          'project_id': widget.projectId,
          'site_data': json.encode(sites),
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('[ASSIGN] Cached ${sites.length} sites');
    } catch (e) {
      debugPrint('[ASSIGN] Error caching sites: $e');
    }
  }

  // Get cached sites data
  Future<List<Map<String, dynamic>>> _getCachedSites() async {
    try {
      final db = await _dbHelper.database;

      final results = await db.query(
        'sdp_sites_classes_cache',
        where: 'sdp_id = ? AND project_id = ?',
        whereArgs: [widget.sdpIdentifier, widget.projectId],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final siteData = json.decode(results.first['site_data'] as String);
        final sites = List<Map<String, dynamic>>.from(siteData);
        debugPrint('[ASSIGN] Loaded ${sites.length} sites from cache');
        return sites;
      }

      return [];
    } catch (e) {
      debugPrint('[ASSIGN] Error loading cached sites: $e');
      return [];
    }
  }

  // Assign learner to a class (with offline support)
  Future<void> _assignLearnerToClass(
      String learnerId, String classId, String className) async {
    try {
      final isOnline = await _checkConnectivity();

      if (isOnline) {
        // Try to assign online
        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}/assign_learner_to_class.php'),
          body: {
            'learner_id': learnerId,
            'class_id': classId,
          },
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('Learner assigned to $className successfully')),
              );
            }
            // Refresh the list
            _pagingController.refresh();
            return;
          } else {
            throw Exception(data['message'] ?? 'Failed to assign learner');
          }
        } else {
          throw Exception('Server returned ${response.statusCode}');
        }
      } else {
        // Queue for offline sync
        await _queueOfflineAssignment(learnerId, classId, className);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Assignment queued (offline). Will sync when online.'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        // Refresh the list
        _pagingController.refresh();
      }
    } catch (e) {
      // On error, queue for offline sync
      await _queueOfflineAssignment(learnerId, classId, className);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Assignment queued (offline). Will sync when online.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Refresh the list
      _pagingController.refresh();
    }
  }

  // Queue assignment for offline sync
  Future<void> _queueOfflineAssignment(
      String learnerId, String classId, String className) async {
    try {
      final db = await _dbHelper.database;

      await db.insert(
        'sdp_pending_assignments',
        {
          'learner_id': int.parse(learnerId),
          'class_id': int.parse(classId),
          'class_name': className,
          'assigned_at': DateTime.now().toIso8601String(),
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint(
          '[ASSIGN] Queued offline assignment: Learner $learnerId → Class $classId');
    } catch (e) {
      debugPrint('[ASSIGN] Error queuing assignment: $e');
      rethrow;
    }
  }

  // Show dialog to assign learner to class
  void _showAssignToClassDialog(
      BuildContext context, String learnerId, Map<String, dynamic> learner) {
    String? selectedSiteId;
    String? selectedClassId;
    String? selectedClassName;
    List<Map<String, dynamic>> sites = [];
    List<Map<String, dynamic>> classes = [];
    bool isLoadingSites = true;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Load sites on first build
            if (isLoadingSites && sites.isEmpty) {
              _fetchSites().then((fetchedSites) {
                if (context.mounted) {
                  setState(() {
                    sites = fetchedSites;
                    isLoadingSites = false;
                  });
                }
              });
            }

            return AlertDialog(
              title: Text(
                  'Assign ${learner['Name']} ${learner['Surname']} to Class'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${learner['IDNumber']}'),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Site:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (isLoadingSites)
                      const Center(child: CircularProgressIndicator())
                    else if (sites.isEmpty)
                      const Text('No sites available for this project')
                    else
                      DropdownButton<String>(
                        hint: const Text('Select Site'),
                        value: selectedSiteId,
                        isExpanded: true,
                        items: sites.map((site) {
                          return DropdownMenuItem<String>(
                            value: site['siteID'].toString(),
                            child: Text(site['siteName'] ?? 'Unknown Site'),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedSiteId = newValue;
                            selectedClassId = null;
                            selectedClassName = null;

                            // Get classes from the selected site
                            final selectedSite = sites.firstWhere(
                              (s) => s['siteID'].toString() == newValue,
                            );
                            classes = List<Map<String, dynamic>>.from(
                                selectedSite['classes'] ?? []);
                          });
                        },
                      ),
                    const SizedBox(height: 16),
                    if (selectedSiteId != null) ...[
                      const Text(
                        'Select Class:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (classes.isEmpty)
                        const Text('No classes available for this site')
                      else
                        DropdownButton<String>(
                          hint: const Text('Select Class'),
                          value: selectedClassId,
                          isExpanded: true,
                          items: classes.map((classItem) {
                            return DropdownMenuItem<String>(
                              value: classItem['classID'].toString(),
                              child: Text(
                                  classItem['className'] ?? 'Unknown Class'),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              selectedClassId = newValue;
                              selectedClassName = classes.firstWhere((c) =>
                                  c['classID'].toString() ==
                                  newValue)['className'];
                            });
                          },
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: selectedClassId == null
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);
                          await _assignLearnerToClass(
                            learnerId,
                            selectedClassId!,
                            selectedClassName ?? 'Selected Class',
                          );
                        },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unallocated Learners'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: syncUnsyncedDocuments,
            tooltip: 'Sync Documents',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _pagingController.refresh(),
            tooltip: 'Refresh',
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
              onChanged: _onSearchChanged,
            ),
          ),

          // Paginated learners list
          Expanded(
            child: PagedListView<int, Map<String, dynamic>>(
              pagingController: _pagingController,
              builderDelegate: PagedChildBuilderDelegate<Map<String, dynamic>>(
                itemBuilder: (context, learner, index) {
                  final learnerId = learner['LearnerID']?.toString() ?? 'N/A';

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${learner['Name']} ${learner['Surname']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('ID: ${learner['IDNumber']}'),
                                if (learner['PhoneNumber'] != null)
                                  Text('Phone: ${learner['PhoneNumber']}'),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              // Assign to Class button
                              ElevatedButton(
                                onPressed: () => _showAssignToClassDialog(
                                  context,
                                  learnerId,
                                  learner,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  minimumSize: const Size(80, 36),
                                ),
                                child: const Text('Assign'),
                              ),
                              const SizedBox(height: 8),
                              FutureBuilder<bool>(
                                future: hasAnyDocuments(learnerId),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  }
                                  bool hasDocuments = snapshot.data ?? false;
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
                                      minimumSize: const Size(80, 36),
                                    ),
                                    child: const Text('View'),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              FutureBuilder<bool>(
                                future: canUploadDocuments(learnerId),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  }
                                  bool canUpload = snapshot.data ?? false;
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
                                      minimumSize: const Size(80, 36),
                                    ),
                                    child: const Text('Docs'),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                firstPageErrorIndicatorBuilder: (context) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${_pagingController.error}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _pagingController.refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                noItemsFoundIndicatorBuilder: (context) => Center(
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
