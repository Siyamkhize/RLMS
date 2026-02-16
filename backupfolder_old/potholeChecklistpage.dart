import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:signature/signature.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'database_helper.dart';
import 'config.dart';

class PotholeChecklistPage extends StatefulWidget {
  final String learnerId;
  final String? learnerFirstName;
  final String? learnerLastName;
  final String? learnerIdNumber;
  final String? facilitatorId;
  final String? classId;

  const PotholeChecklistPage({
    super.key,
    required this.learnerId,
    this.learnerFirstName,
    this.learnerLastName,
    this.learnerIdNumber,
    this.facilitatorId,
    this.classId,
  });

  @override
  State<PotholeChecklistPage> createState() => _PotholeChecklistPageState();
}

class _PotholeChecklistPageState extends State<PotholeChecklistPage> {
  final TextEditingController _learnerNameController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _assessorNameController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  DateTime _date = DateTime.now();
  
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;
  String? _checklistType; // 'system', 'scanned', or null
  String? _scannedDocumentPath;
  bool _checklistExists = false;
  bool _hasCheckedStatus = false;
  bool _isViewMode = false; // true when viewing existing form, false when editing
  
  // LogBook Unit Standards
  List<Map<String, dynamic>> _logbookUnitStandards = [];
  final Map<String, TextEditingController> _logbookMarksControllers = {};
  bool _isLoadingLogbook = false;
  bool _isLogbookExpanded = false; // Main logbook section expansion
  final Map<String, bool> _unitStandardExpanded = {}; // Individual unit standard expansion

  // Signature controllers
  final SignatureController _learnerSignatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  final SignatureController _assessorSignatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  late final List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    
    // Initialize items first
    _items = [
      {
        'section': 'PRE – OPERATIONAL SAFETY',
        'entries': [
          {'label': 'Wears appropriate PPE', 'value': true, 'notes': ''},
        ],
      },
      {
        'section': 'PREPARATION',
        'entries': [
          {
            'label':
            'Cleans the pothole of all loose material, debris and water',
            'value': true,
            'notes': ''
          },
          {
            'label':
            'Setting out done correctly (marking, straightness, corners)',
            'value': true,
            'notes': ''
          },
        ],
      },
      {
        'section': 'MATERIAL PREPARATION',
        'entries': [
          {'label': 'Crusher material', 'value': true, 'notes': ''},
          {'label': 'Cold asphalt', 'value': true, 'notes': ''},
        ],
      },
      {
        'section': 'APPLICATION AND COMPACTION',
        'entries': [
          {
            'label': 'Filled the hole with crusher material',
            'value': true,
            'notes': ''
          },
          {
            'label': 'Applied tack coat (bonding liquid)',
            'value': true,
            'notes': ''
          },
          {'label': 'Filled asphalt in the hole', 'value': true, 'notes': ''},
          {
            'label': 'All the corners sealed and squared',
            'value': true,
            'notes': ''
          },
          {
            'label': 'Compacted each layer thoroughly using the compactor',
            'value': true,
            'notes': ''
          },
          {
            'label': 'Added 10 mm excess material for final compaction',
            'value': true,
            'notes': ''
          },
          {
            'label':
            'Final compacted surface is flush with surrounding road surfaces',
            'value': true,
            'notes': ''
          },
        ],
      },
      {
        'section': 'POST – OPERATION',
        'entries': [
          {'label': 'Housekeeping', 'value': true, 'notes': ''},
        ],
      },
    ];
    
    // Now initialize other data
    final learnerFullName = [widget.learnerFirstName, widget.learnerLastName]
        .where((e) => (e ?? '').trim().isNotEmpty)
        .join(' ');
    _learnerNameController.text = learnerFullName;
    _idNumberController.text = widget.learnerIdNumber ?? '';

    if (widget.facilitatorId != null) {
      _populateAssessor(widget.facilitatorId!);
    }
    if (widget.classId != null) {
      _populateVenue(widget.classId!);
    }

    // Load existing checklist data if available
    _loadExistingChecklist();
    
    // Load logbook unit standards
    _loadLogbookUnitStandards();
  }

  Future<void> _populateAssessor(String facilitatorId) async {
    try {
      final response = await http.get(Uri.parse(
          '${AppConfig.baseUrl}/fetch_facilitator_details.php?facilitator_id=$facilitatorId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String first = data['firstName']?.toString() ?? '';
        final String last = data['lastName']?.toString() ?? '';
        setState(() {
          _assessorNameController.text =
              [first, last].where((e) => e.trim().isNotEmpty).join(' ');
        });
      }
    } catch (_) {}
  }

  Future<void> _populateVenue(String classId) async {
    try {
      final response = await http.get(Uri.parse(
          '${AppConfig.baseUrl}/fetch_class_name.php?class_id=$classId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String name = data['className']?.toString() ?? '';
        setState(() {
          _venueController.text = name;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadExistingChecklist() async {
    if (widget.learnerId.isEmpty || widget.facilitatorId == null) {
      print('DEBUG: Cannot load checklist - missing learner_id or facilitator_id');
      return;
    }

    try {
      final url = '${AppConfig.baseUrl}/view_pothole_checklists.php?learner_id=${widget.learnerId}&assessor_id=${widget.facilitatorId}&assessment_date=${_date.toIso8601String().split('T').first}';
      print('DEBUG: Loading checklist from: $url');
      
      final response = await http.get(Uri.parse(url));
      
      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('DEBUG: Parsed data status: ${data['status']}');
        
        if (data['status'] == 'success' && data['data'] != null) {
          final checklistData = data['data'];
          print('DEBUG: Checklist found! Loading data...');

          // Populate form fields
          setState(() {
            _learnerNameController.text = checklistData['learner_name'] ?? '';
            _idNumberController.text = checklistData['learner_id_number'] ?? '';
            _assessorNameController.text = checklistData['assessor_name'] ?? '';
            _venueController.text = checklistData['venue'] ?? '';
            
            // Mark that checklist exists
            _checklistExists = true;
            _checklistType = 'system';
            _isViewMode = true; // Start in view mode

            // Note: Signatures will need to be re-entered as the signature package
            // doesn't support loading from database in this version
            // This is a limitation that can be addressed in future updates

            // Load checklist items
            final itemsData = checklistData['checklist_items'] ?? {};
            print('DEBUG: Loading ${itemsData.length} sections');
            
            for (var section in _items) {
              final sectionName = section['section'] as String;
              if (itemsData.containsKey(sectionName)) {
                final sectionItems = itemsData[sectionName] as List;
                for (int i = 0;
                i < (section['entries'] as List).length &&
                    i < sectionItems.length;
                i++) {
                  final item = sectionItems[i];
                  (section['entries'] as List)[i]['value'] =
                  (item['value'] == 1 || item['value'] == true) ? true :
                  ((item['value'] == 0 || item['value'] == false) ? false : true);
                  (section['entries'] as List)[i]['notes'] =
                      item['notes'] ?? '';
                }
              }
            }
          });
          
          print('DEBUG: Checklist loaded successfully in view mode');
        } else {
          print('DEBUG: No checklist found - ${data['message'] ?? 'Unknown error'}');
        }
      } else {
        print('DEBUG: HTTP error - status code: ${response.statusCode}');
      }
    } catch (e) {
      print('ERROR loading existing checklist: $e');
    }
  }

  /// Check if checklist exists (system or scanned)
  Future<Map<String, dynamic>> _checkChecklistStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final assessmentDate = _date.toIso8601String().split('T').first;
      
      // Check local database for scanned document
      final scannedDoc = await _dbHelper.getScannedPotholeChecklist(
        learnerId: widget.learnerId,
        assessorId: widget.facilitatorId ?? '',
        assessmentDate: assessmentDate,
      );
      
      if (scannedDoc != null) {
        setState(() => _isLoading = false);
        return {
          'exists': true,
          'type': 'scanned',
          'data': scannedDoc,
        };
      }
      
      // Check server for system-generated checklist
      try {
        final response = await http.get(Uri.parse(
          '${AppConfig.baseUrl}/view_pothole_checklists.php?learner_id=${widget.learnerId}&assessor_id=${widget.facilitatorId}&assessment_date=$assessmentDate'
        )).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success' && data['data'] != null) {
            setState(() => _isLoading = false);
            return {
              'exists': true,
              'type': 'system',
              'data': data['data'],
            };
          }
        }
      } catch (e) {
        print('Server check failed (offline?): $e');
      }
      
      setState(() => _isLoading = false);
      return {
        'exists': false,
        'type': 'none',
        'data': null,
      };
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error checking checklist status: $e');
      return {
        'exists': false,
        'type': 'none',
        'data': null,
      };
    }
  }

  /// Scan document using flutter_doc_scanner
  Future<void> _scanDocument() async {
    try {
      final docScanner = FlutterDocScanner();
      final scannedDoc = await docScanner.getScanDocuments();
      
      if (scannedDoc != null && scannedDoc.isNotEmpty) {
        // Get the first scanned document
        final scannedPath = scannedDoc.first;
        
        // Save to permanent location
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'pothole_checklist_${widget.learnerId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final permanentPath = '${appDir.path}/$fileName';
        
        // Copy file to permanent location
        final file = File(scannedPath);
        await file.copy(permanentPath);
        
        // Save to database
        final assessmentDate = _date.toIso8601String().split('T').first;
        await _dbHelper.saveScannedPotholeChecklist(
          learnerId: widget.learnerId,
          assessorId: widget.facilitatorId ?? '',
          documentPath: permanentPath,
          assessmentDate: assessmentDate,
        );
        
        setState(() {
          _checklistType = 'scanned';
          _scannedDocumentPath = permanentPath;
          _checklistExists = true;
          _hasCheckedStatus = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document scanned and saved successfully! Click "View Scanned Document" to open it.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Sync to server if online
        _syncScannedDocument(permanentPath, assessmentDate);
      }
    } catch (e) {
      _showError('Error scanning document: $e');
    }
  }

  /// Sync scanned document to server
  Future<void> _syncScannedDocument(String documentPath, String assessmentDate) async {
    try {
      final file = File(documentPath);
      if (!await file.exists()) {
        print('File does not exist: $documentPath');
        return;
      }
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/upload_scanned_pothole_checklist.php'),
      );
      
      request.fields['learner_id'] = widget.learnerId;
      request.fields['assessor_id'] = widget.facilitatorId ?? '';
      request.fields['assessment_date'] = assessmentDate;
      
      request.files.add(await http.MultipartFile.fromPath(
        'document',
        documentPath,
      ));
      
      final response = await request.send().timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = jsonDecode(responseData);
        
        if (data['status'] == 'success') {
          print('Scanned document synced successfully');
          // Mark as synced in local database
          final scannedDoc = await _dbHelper.getScannedPotholeChecklist(
            learnerId: widget.learnerId,
            assessorId: widget.facilitatorId ?? '',
            assessmentDate: assessmentDate,
          );
          if (scannedDoc != null) {
            await _dbHelper.markScannedChecklistAsSynced(scannedDoc['id'] as int);
          }
        }
      }
    } catch (e) {
      print('Error syncing scanned document (will retry later): $e');
      // Document remains unsynced and will be synced later
    }
  }

  /// View scanned document
  Future<void> _viewScannedDocument(String documentPath) async {
    try {
      final file = File(documentPath);
      if (await file.exists()) {
        await OpenFile.open(documentPath);
      } else {
        _showError('Document file not found');
      }
    } catch (e) {
      _showError('Error opening document: $e');
    }
  }

  /// Get smart button label based on checklist status
  String _getSmartButtonLabel() {
    if (!_hasCheckedStatus) {
      return 'Open Checklist';
    }
    
    if (_checklistExists) {
      if (_checklistType == 'scanned') {
        return 'View Scanned Document';
      } else if (_checklistType == 'system') {
        return 'View Checklist';
      }
    }
    
    return 'Create Checklist';
  }

  /// Get smart button icon based on checklist status
  IconData _getSmartButtonIcon() {
    if (!_hasCheckedStatus) {
      return Icons.folder_open;
    }
    
    if (_checklistExists) {
      if (_checklistType == 'scanned') {
        return Icons.picture_as_pdf;
      } else if (_checklistType == 'system') {
        return Icons.visibility;
      }
    }
    
    return Icons.add_circle_outline;
  }

  /// Get smart button color based on checklist status
  Color _getSmartButtonColor() {
    if (!_hasCheckedStatus) {
      return Colors.orange;
    }
    
    if (_checklistExists) {
      return Colors.blue;
    }
    
    return Colors.green;
  }

  /// Handle smart button press - changes behavior based on status
  Future<void> _handleSmartButtonPress() async {
    // First time - check status
    if (!_hasCheckedStatus) {
      await _checkAndUpdateStatus();
      return;
    }
    
    // If checklist exists - view it
    if (_checklistExists) {
      if (_checklistType == 'scanned') {
        _viewScannedDocument(_scannedDocumentPath!);
      } else if (_checklistType == 'system') {
        _loadExistingChecklist();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checklist loaded. You can view and edit below.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return;
    }
    
    // No checklist exists - show creation options
    _showCreationOptionsDialog();
  }

  /// Check checklist status and update button state
  Future<void> _checkAndUpdateStatus() async {
    final status = await _checkChecklistStatus();
    
    if (!mounted) return;
    
    setState(() {
      _hasCheckedStatus = true;
      _checklistExists = status['exists'] == true;
      _checklistType = status['type'];
      if (status['type'] == 'scanned' && status['data'] != null) {
        _scannedDocumentPath = status['data']['document_path'] as String?;
      }
    });
    
    // Show feedback
    if (_checklistExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _checklistType == 'scanned'
                ? 'Scanned checklist found. Click again to view.'
                : 'System checklist found. Click again to view.',
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No checklist found. Click again to create one.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Show creation options dialog
  Future<void> _showCreationOptionsDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Checklist'),
        content: const Text('How would you like to create the checklist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _scanDocument();
            },
            icon: const Icon(Icons.document_scanner),
            label: const Text('Scan Document'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fill in the form below and save'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            icon: const Icon(Icons.edit),
            label: const Text('Fill Form'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Show checklist options dialog
  Future<void> _showChecklistOptionsDialog() async {
    final status = await _checkChecklistStatus();
    
    if (!mounted) return;
    
    if (status['exists'] == true) {
      // Checklist exists - show view option
      final type = status['type'];
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Checklist Found'),
          content: Text(
            type == 'scanned'
                ? 'A scanned checklist document exists for this learner.'
                : 'A system-generated checklist exists for this learner.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                if (type == 'scanned') {
                  final docPath = status['data']['document_path'] as String;
                  _viewScannedDocument(docPath);
                } else {
                  // Load system checklist
                  _loadExistingChecklist();
                }
              },
              icon: const Icon(Icons.visibility),
              label: const Text('View Checklist'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } else {
      // No checklist exists - show creation options
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create Checklist'),
          content: const Text('How would you like to create the checklist?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _scanDocument();
              },
              icon: const Icon(Icons.document_scanner),
              label: const Text('Scan Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // User will fill the form on this page
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fill in the form below and save'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Fill Form'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _saveChecklist() async {
    // Client-side validation
    final assessorId = widget.facilitatorId ?? '';
    if (_learnerNameController.text.trim().isEmpty) {
      _showError('Learner name is required');
      return;
    }
    if (assessorId.isEmpty) {
      _showError('Assessor ID is required (facilitator not assigned)');
      return;
    }
    if (_assessorNameController.text.trim().isEmpty) {
      _showError('Assessor name is required');
      return;
    }
    if (_venueController.text.trim().isEmpty) {
      _showError('Venue is required');
      return;
    }

    try {
      // Prepare checklist items data
      final List<Map<String, dynamic>> checklistItems = [];
      for (var section in _items) {
        final sectionName = section['section'] as String;
        for (var entry in section['entries'] as List) {
          checklistItems.add({
            'section': sectionName,
            'label': entry['label'],
            'value': entry['value'],
            'notes': entry['notes'] ?? '',
          });
        }
      }

      // Get signature data - using simple approach for now
      // Note: Full signature support can be implemented with proper package methods
      final learnerSignatureData =
      _learnerSignatureController.isEmpty ? null : 'signature_present';
      final assessorSignatureData =
      _assessorSignatureController.isEmpty ? null : 'signature_present';

      final payload = {
        'learner_id': widget.learnerId,
        'learner_name': _learnerNameController.text.trim(),
        'learner_id_number': _idNumberController.text.trim(),
        'assessor_id': assessorId,
        'assessor_name': _assessorNameController.text.trim(),
        'assessor_reg_number': '', // You can add this field if needed
        'venue': _venueController.text.trim(),
        'assessment_date': _date.toIso8601String().split('T').first,
        'learner_signature': learnerSignatureData ?? '',
        'assessor_signature': assessorSignatureData ?? '',
        'checklist_items': checklistItems,
      };

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/save_pothole_checklist.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _checklistType = 'system';
            _checklistExists = true;
            _hasCheckedStatus = true;
          });
          
          // Also save logbook marks
          await _saveLogbookMarks();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _showError('Error saving checklist: $e');
    }
  }

  /// Load LogBook Unit Standards for this learner
  Future<void> _loadLogbookUnitStandards() async {
    if (widget.learnerId.isEmpty) return;
    
    setState(() => _isLoadingLogbook = true);
    
    try {
      final response = await http.get(Uri.parse(
        '${AppConfig.baseUrl}/get_logbook_unit_standards.php?learner_id=${widget.learnerId}'
      ));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _logbookUnitStandards = List<Map<String, dynamic>>.from(data['data'] ?? []);
            
            // Create controllers for each unit standard
            for (var us in _logbookUnitStandards) {
              _logbookMarksControllers[us['unit_standard_id'].toString()] = TextEditingController();
            }
          });
          
          // Load existing marks if checklist exists
          if (_checklistExists) {
            await _loadLogbookMarks();
          }
        }
      }
    } catch (e) {
      print('Error loading logbook unit standards: $e');
    } finally {
      setState(() => _isLoadingLogbook = false);
    }
  }

  /// Load existing LogBook marks
  Future<void> _loadLogbookMarks() async {
    if (widget.learnerId.isEmpty || widget.facilitatorId == null) return;
    
    try {
      final assessmentDate = _date.toIso8601String().split('T').first;
      final assessorId = widget.facilitatorId ?? '';
      
      final response = await http.get(Uri.parse(
        '${AppConfig.baseUrl}/get_logbook_marks.php?learner_id=${widget.learnerId}&assessor_id=$assessorId&assessment_date=$assessmentDate'
      ));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final marks = data['data'] as Map<String, dynamic>;
          
          setState(() {
            marks.forEach((unitStandardId, mark) {
              if (_logbookMarksControllers.containsKey(unitStandardId)) {
                _logbookMarksControllers[unitStandardId]!.text = mark.toString();
              }
            });
          });
        }
      }
    } catch (e) {
      print('Error loading logbook marks: $e');
    }
  }

  /// Save LogBook marks
  Future<void> _saveLogbookMarks() async {
    if (_logbookUnitStandards.isEmpty) return;
    
    // Validate and collect marks
    List<Map<String, dynamic>> unitStandardsMarks = [];
    
    for (var us in _logbookUnitStandards) {
      final controller = _logbookMarksControllers[us['unit_standard_id'].toString()];
      if (controller != null && controller.text.isNotEmpty) {
        final marks = int.tryParse(controller.text);
        if (marks == null || marks < 0 || marks > 50) {
          _showError('Marks for ${us['unit_standard_name']} must be between 0 and 50');
          return;
        }
        unitStandardsMarks.add({
          'unit_standard_id': us['unit_standard_id'],
          'marks': marks
        });
      }
    }
    
    if (unitStandardsMarks.isEmpty) {
      return; // No marks to save
    }
    
    try {
      final assessmentDate = _date.toIso8601String().split('T').first;
      final assessorId = widget.facilitatorId ?? '';
      
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/save_logbook_marks.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learner_id': widget.learnerId,
          'assessor_id': assessorId,
          'assessment_date': assessmentDate,
          'unit_standards_marks': unitStandardsMarks
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          print('LogBook marks saved successfully');
        } else {
          throw Exception(data['message']);
        }
      }
    } catch (e) {
      print('Error saving logbook marks: $e');
      // Don't show error to user, just log it
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _learnerNameController.dispose();
    _idNumberController.dispose();
    _assessorNameController.dispose();
    _venueController.dispose();
    _learnerSignatureController.dispose();
    _assessorSignatureController.dispose();
    _logbookMarksControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasFacilitator = widget.facilitatorId != null && widget.facilitatorId!.isNotEmpty;
    final bool hasClass = widget.classId != null && widget.classId!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pothole Patching Checklist'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'POTHOLE PATCHING CHECKLIST',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    if (_isViewMode && _checklistExists) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.visibility, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Viewing existing checklist - Click "Edit Checklist" below to make changes',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Learner Information Section
                    _buildInfoSection(
                      'LEARNER INFORMATION',
                      [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _learnerNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Name & Surname',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person),
                                ),
                                readOnly: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _idNumberController,
                                decoration: const InputDecoration(
                                  labelText: 'ID Number',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.badge),
                                ),
                                readOnly: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _date,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setState(() => _date = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Date',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  child: Text(
                                      _date.toIso8601String().split('T').first),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _venueController,
                                decoration: const InputDecoration(
                                  labelText: 'Venue',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.location_on),
                                ),
                                readOnly: hasClass,  // Editable if no class provided
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSignaturePad(
                            'Learner Signature', _learnerSignatureController),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Checklist Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ASSESSMENT CRITERIA',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._items.map((section) => _buildSection(section)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // LogBook Unit Standards Section
            _buildLogbookSection(),

            const SizedBox(height: 16),

            // Assessor Information Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ASSESSOR INFORMATION',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _assessorNameController,
                            decoration: const InputDecoration(
                              labelText: 'Name and Surname',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            readOnly: hasFacilitator,  // Editable if no facilitator provided
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Assessor Reg. Number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge),
                            ),
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child:
                            Text(_date.toIso8601String().split('T').first),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(), // Empty space for alignment
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSignaturePad(
                        'Assessor Signature', _assessorSignatureController),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons - Show different buttons based on view/edit mode
            if (_isViewMode && _checklistExists)
              // View Mode - Show Edit button
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isViewMode = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You can now edit the form'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Checklist'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              )
            else
              // Edit Mode - Show Save button
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveChecklist,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Saving...' : 'Save Checklist'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildSignaturePad(String title, SignatureController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
            color: _isViewMode ? Colors.grey.shade100 : Colors.white,
          ),
          child: AbsorbPointer(
            absorbing: _isViewMode,
            child: Signature(
              controller: controller,
              backgroundColor: _isViewMode ? Colors.grey.shade100 : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!_isViewMode)
              TextButton.icon(
                onPressed: () => controller.clear(),
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            if (controller.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Signed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(Map<String, dynamic> section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              section['section'] as String,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children:
              List<Widget>.from((section['entries'] as List).map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['label'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool?>(
                              dense: false,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                              title: const Text(
                                'YES',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              value: true,
                              groupValue: entry['value'] as bool?,
                              onChanged: _isViewMode ? null : (v) =>
                                  setState(() => entry['value'] = v),
                              activeColor: Colors.green,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool?>(
                              dense: false,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                              title: const Text(
                                'NO',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              value: false,
                              groupValue: entry['value'] as bool?,
                              onChanged: _isViewMode ? null : (v) =>
                                  setState(() => entry['value'] = v),
                              activeColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: entry['notes '] as String? ?? '',
                        onChanged: _isViewMode ? null : (t) => entry['notes'] = t,
                        readOnly: _isViewMode,
                        decoration: const InputDecoration(
                          labelText: 'Notes & observations by assessor',
                          border: OutlineInputBorder(),
                          hintText: 'Enter your observations...',
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                );
              })),
            ),
          ),
        ],
      ),
    );
  }

  /// Build LogBook Unit Standards Section (Collapsible)
  Widget _buildLogbookSection() {
    if (_logbookUnitStandards.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      elevation: 2,
      color: Colors.orange.shade50,
      child: Column(
        children: [
          // Main LogBook Header (Collapsible)
          InkWell(
            onTap: () {
              setState(() {
                _isLogbookExpanded = !_isLogbookExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.book, color: Colors.orange.shade700, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'LogBook',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  Icon(
                    _isLogbookExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.orange.shade700,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Content
          if (_isLogbookExpanded) ...[
            const Divider(height: 1),
            if (_isLoadingLogbook)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: _logbookUnitStandards.map((us) => _buildUnitStandardCard(us)).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Build individual Unit Standard card (Collapsible)
  Widget _buildUnitStandardCard(Map<String, dynamic> unitStandard) {
    final unitStandardId = unitStandard['unit_standard_id'].toString();
    final controller = _logbookMarksControllers[unitStandardId];
    final isExpanded = _unitStandardExpanded[unitStandardId] ?? false;
    
    // Parse specific outcomes - handle both List and null
    List<dynamic> specificOutcomes = [];
    if (unitStandard.containsKey('specific_outcomes') && unitStandard['specific_outcomes'] != null) {
      final outcomes = unitStandard['specific_outcomes'];
      if (outcomes is List) {
        specificOutcomes = outcomes;
      }
    }
    
    // Debug print
    print('Unit Standard: $unitStandardId, Outcomes count: ${specificOutcomes.length}');
    if (specificOutcomes.isNotEmpty) {
      print('First outcome: ${specificOutcomes[0]}');
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 1,
      color: Colors.white,
      child: Column(
        children: [
          // Unit Standard Header (Collapsible)
          InkWell(
            onTap: () {
              setState(() {
                _unitStandardExpanded[unitStandardId] = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${unitStandard['unit_standard_number']} - ${unitStandard['unit_standard_name']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade600,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Content
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Debug: Show outcomes count
                  Text(
                    'DEBUG: ${specificOutcomes.length} outcomes',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  
                  // Specific Outcomes (if any)
                  if (specificOutcomes.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Specific Outcomes:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...specificOutcomes.map((outcome) {
                            final outcomeText = outcome['outcome_text']?.toString() ?? '';
                            print('Rendering outcome: $outcomeText');
                            
                            if (outcomeText.isEmpty) {
                              print('Empty outcome text, skipping');
                              return const SizedBox.shrink();
                            }
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      outcomeText,
                                      style: const TextStyle(fontSize: 14, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const Text(
                      'DEBUG: No outcomes to display',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Marks Input
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Mark (0-50)',
                            border: OutlineInputBorder(),
                            hintText: 'Enter mark out of 50',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          ),
                          keyboardType: TextInputType.number,
                          readOnly: _isViewMode,
                          enabled: !_isViewMode,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}