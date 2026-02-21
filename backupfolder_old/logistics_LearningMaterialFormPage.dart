import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'config.dart';
import 'services/fingerprint_service.dart';
import 'package:geolocator/geolocator.dart';
import 'logistics_learner_material_selection_page.dart';

class LogisticsLearningMaterialFormPage extends StatefulWidget {
  final String classID;
  final String? logisticsId;
  final String? logisticsName;
  final String? siteId;
  final String? siteName;
  final String? classId;
  final String? className;
  final String? facilitatorId;
  final String? facilitatorName;

  const LogisticsLearningMaterialFormPage({
    super.key,
    required this.classID,
    this.logisticsId,
    this.logisticsName,
    this.siteId,
    this.siteName,
    this.classId,
    this.className,
    this.facilitatorId,
    this.facilitatorName,
  });

  @override
  State<LogisticsLearningMaterialFormPage> createState() =>
      _LogisticsLearningMaterialFormPageState();
}

class _LogisticsLearningMaterialFormPageState
    extends State<LogisticsLearningMaterialFormPage> {
  List<Map<String, dynamic>> learners = [];
  List<Map<String, dynamic>> allLearners =
      []; // Store all learners before filtering
  List<Map<String, dynamic>> unitStandards = [];
  List<String> issuedLearnerNames =
      []; // Learners who already received current material
  bool isLoading = true;

  // Selection interface variables
  String qualification = '';
  String logisticsFullName = 'Unknown Logistics';
  String selectedLearningMaterialType = 'Select';

  // Material type options
  final List<String> materialTypes = [
    'Select',
    'Learning Material',
    'PPE',
    'ToolKit',
    'Consumables',
  ];

  // PPE-specific variables
  String? selectedContiSuitSize;
  int contiSuitQuantity = 0;
  String? selectedBootsSize;
  int bootsQuantity = 0;

  // PPE sizes
  final List<String> contiSuitSizes = List.generate(
    41, // 66 - 26 + 1 = 41 items
    (index) => (26 + index).toString(),
  );

  final List<String> bootsSizes = List.generate(
    12, // 14 - 3 + 1 = 12 items
    (index) => (3 + index).toString(),
  );

  // Fingerprint services
  final FingerprintService _fingerprintService = FingerprintService();
  final FutronicService _futronicService = FutronicService();
  String activeScanner = 'none';
  bool isVerifying = false;

  @override
  void initState() {
    super.initState();

    // Set logistics name from widget parameter
    logisticsFullName = widget.logisticsName ?? 'Unknown Logistics';

    _fetchAllLearners();
    _fetchUnitStandards();
    _detectScanner();
  }

  Future<void> _detectScanner() async {
    try {
      // Try ZKTeco first
      try {
        debugPrint('[SCANNER] Checking ZKTeco...');
        final isZkConnected = await _fingerprintService.isSensorConnected();
        debugPrint('[SCANNER] ZKTeco result: $isZkConnected');
        if (isZkConnected == true) {
          setState(() => activeScanner = 'zkteco');
          debugPrint('[SCANNER] ✅ ZKTeco scanner detected');
          return;
        }
      } catch (e) {
        debugPrint('[SCANNER] ❌ ZKTeco not available: $e');
      }

      // Try Futronic
      try {
        debugPrint('[SCANNER] Checking Futronic...');
        final isFutronicConnected =
            await _futronicService.isFutronicConnected();
        debugPrint('[SCANNER] Futronic result: $isFutronicConnected');
        if (isFutronicConnected == true) {
          setState(() => activeScanner = 'futronic');
          debugPrint('[SCANNER] ✅ Futronic scanner detected');
          return;
        }
      } catch (e) {
        debugPrint('[SCANNER] ❌ Futronic not available: $e');
      }

      // No scanner found
      setState(() => activeScanner = 'none');
      debugPrint('[SCANNER] ⚠️ No fingerprint scanner detected');
    } catch (e) {
      debugPrint('[SCANNER] ❌ Error detecting scanner: $e');
      setState(() => activeScanner = 'none');
    }
  }

  Future<void> _fetchAllLearners() async {
    try {
      setState(() => isLoading = true);

      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      debugPrint(
          '[LOGISTICS] Fetching learners for classID: ${widget.classID}');

      // STEP 1: Try to fetch learners directly from server API (like facilitator does)
      try {
        debugPrint('[LOGISTICS] Fetching learners from server API...');

        final response = await http
            .get(
              Uri.parse(
                  '${AppConfig.getLearnersUrl}?classID=${widget.classID}'),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List<dynamic> learnersData = json.decode(response.body);
          debugPrint(
              '[LOGISTICS] ✅ Received ${learnersData.length} learners from server API');

          // Store all learners from API
          allLearners = learnersData.map((learner) {
            return {
              'LearnerID': learner['LearnerID'],
              'IDNumber': learner['IDNumber'],
              'FullName': '${learner['Name']} ${learner['Surname']}',
              'Name': learner['Name'],
              'Surname': learner['Surname'],
              'ClockInTime': null, // Logistics doesn't require clock-in
            };
          }).toList();

          debugPrint(
              '[LOGISTICS] Fetched ${allLearners.length} learners from API');

          // Apply filtering based on selected material type
          await _filterLearnersByMaterialType();

          setState(() => isLoading = false);
          return; // Success - exit early
        } else {
          debugPrint(
              '[LOGISTICS] ⚠️ Server API returned status ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('[LOGISTICS] ⚠️ Failed to fetch from server API: $e');
        debugPrint('[LOGISTICS] Falling back to local database...');
      }

      // STEP 2: Fallback to local database if API fails
      debugPrint('[LOGISTICS] Using local database as fallback...');

      // Check if learners exist in local database
      final totalQuery = 'SELECT COUNT(*) as total FROM learnerdetails';
      final totalResult = await db.rawQuery(totalQuery);
      final totalLearners = totalResult.first['total'];
      debugPrint(
          '[LOGISTICS] Total learners in local database: $totalLearners');

      // NEVER SYNC - Only use existing local data
      if (totalLearners == null || (totalLearners as int) == 0) {
        debugPrint('[LOGISTICS] ❌ No data in local database');
        debugPrint(
            '[LOGISTICS] Please sync data from another role first (Facilitator, Admin, or SDP)');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No learner data available. Please sync from another role first.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }

        setState(() => isLoading = false);
        return;
      } else {
        debugPrint(
            '[LOGISTICS] ✅ Using local data ($totalLearners learners already synced)');
      }

      // Try to convert classID to integer in case there's a type mismatch
      dynamic classIdParam = widget.classID;
      try {
        classIdParam = int.parse(widget.classID);
        debugPrint('[LOGISTICS] Converted classID to integer: $classIdParam');
      } catch (e) {
        debugPrint(
            '[LOGISTICS] ClassID is not numeric, using as string: ${widget.classID}');
      }

      // Check if our specific classID exists
      final classCheckQuery =
          'SELECT COUNT(*) as count FROM learnerdetails WHERE classID = ?';
      final classCheckResult =
          await db.rawQuery(classCheckQuery, [classIdParam]);
      final classLearnerCount = classCheckResult.first['count'];
      debugPrint(
          '[LOGISTICS] Learners found for classID ${widget.classID}: $classLearnerCount');

      // If no learners found, let's see what classIDs exist
      if (classLearnerCount == 0) {
        final allClassesQuery =
            'SELECT DISTINCT classID, COUNT(*) as count FROM learnerdetails GROUP BY classID';
        final allClassesResult = await db.rawQuery(allClassesQuery);
        debugPrint('[LOGISTICS] Available classIDs in database:');
        for (var classData in allClassesResult) {
          debugPrint(
              '  - classID: ${classData['classID']}, count: ${classData['count']}');
        }
      }

      // Get all learners for this class (removed clock-in requirement for logistics)
      final query = '''
        SELECT DISTINCT
          ld.LearnerID,
          ld.IDNumber,
          ld.Name,
          ld.Surname,
          ld.classID
        FROM learnerdetails ld
        WHERE ld.classID = ?
        ORDER BY ld.Surname, ld.Name
      ''';

      // Use the converted integer parameter if available
      final results = await db.rawQuery(query, [classIdParam]);

      debugPrint('[LOGISTICS] Raw query results: ${results.length} rows found');
      if (results.isNotEmpty) {
        debugPrint('[LOGISTICS] First result: ${results.first}');
      }

      // Store all learners
      allLearners = results.map((row) {
        return {
          'LearnerID': row['LearnerID'],
          'IDNumber': row['IDNumber'],
          'FullName': '${row['Name']} ${row['Surname']}',
          'Name': row['Name'],
          'Surname': row['Surname'],
          'ClockInTime': null, // No longer tracking clock-in time for logistics
        };
      }).toList();

      debugPrint(
          '[LOGISTICS] Fetched ${allLearners.length} learners (clock-in requirement removed for logistics)');

      // Apply filtering based on selected material type
      await _filterLearnersByMaterialType();

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint('[LOGISTICS] Error fetching learners: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading learners: $e')),
        );
      }
    }
  }

  Future<void> _fetchIssuedLearners() async {
    if (selectedLearningMaterialType == 'Select') {
      setState(() {
        issuedLearnerNames = [];
      });
      return;
    }

    try {
      if (selectedLearningMaterialType == 'Learning Material') {
        // For Learning Material: NEVER hide learners
        // Show ALL learners with checkboxes indicating what they've received
        // The checkbox system (get_logistics_checkbox_status.php) handles showing what's received vs not received
        debugPrint(
            '[FILTER] Learning Material selected - showing ALL learners (no filtering)');
        setState(() {
          issuedLearnerNames = []; // Empty list = no learners filtered out
        });
      } else if (selectedLearningMaterialType == 'PPE') {
        // For PPE, check if learner has received PPE (either Conti-Suit or Safety Boots)
        debugPrint('[FILTER] Fetching learners who received PPE');
        final response = await http.get(
          Uri.parse(
              '${AppConfig.baseUrl}/get_learners_with_ppe.php?classID=${widget.classID}'),
        );

        if (response.statusCode == 200) {
          final List<dynamic> ppeData = json.decode(response.body);
          setState(() {
            issuedLearnerNames = ppeData
                .map((item) => '${item['Name']} ${item['Surname']}')
                .toList()
                .cast<String>();
          });
          debugPrint('[FILTER] Learners with PPE: $issuedLearnerNames');
        }
      } else {
        // For other material types (ToolKit, Consumables)
        debugPrint(
            '[FILTER] Fetching learners who received $selectedLearningMaterialType');
        final response = await http.get(
          Uri.parse(AppConfig.buildUrl(
              'get_issued_learners.php?classID=${widget.classID}&materialType=$selectedLearningMaterialType')),
        );

        if (response.statusCode == 200) {
          final List<dynamic> issuedData = json.decode(response.body);
          setState(() {
            issuedLearnerNames = issuedData
                .map((item) => '${item['Name']} ${item['Surname']}')
                .toList()
                .cast<String>();
          });
          debugPrint('[FILTER] Issued learners: $issuedLearnerNames');
        }
      }
    } catch (e) {
      debugPrint('[FILTER] Error fetching issued learners: $e');
    }
  }

  Future<void> _filterLearnersByMaterialType() async {
    // Fetch list of learners who already received this material
    await _fetchIssuedLearners();

    // Filter out learners based on material type
    if (selectedLearningMaterialType == 'Select') {
      // Show all learners for 'Select'
      setState(() {
        learners = List.from(allLearners);
      });
      debugPrint(
          '[FILTER] Showing all ${learners.length} learners (Select mode)');
    } else {
      // Filter out learners who already completed the material
      // This works for PPE, ToolKit, Consumables, AND Learning Material
      setState(() {
        learners = allLearners.where((learner) {
          final fullName = (learner['FullName'] as String).trim();

          // Case-insensitive and trimmed comparison
          final alreadyCompleted = issuedLearnerNames.any((issuedName) {
            return issuedName.trim().toLowerCase() == fullName.toLowerCase();
          });

          // Debug logging for each learner
          debugPrint('[FILTER-CHECK] Learner: "$fullName"');
          debugPrint('[FILTER-CHECK] Already completed: $alreadyCompleted');
          if (issuedLearnerNames.isNotEmpty) {
            debugPrint(
                '[FILTER-CHECK] Issued names: ${issuedLearnerNames.map((n) => "\"$n\"").toList()}');
          }

          if (alreadyCompleted) {
            if (selectedLearningMaterialType == 'Learning Material') {
              debugPrint(
                  '[FILTER] ✓ Filtering out: $fullName (completed ALL unit standards)');
            } else {
              debugPrint(
                  '[FILTER] ✓ Filtering out: $fullName (already received $selectedLearningMaterialType)');
            }
          }
          return !alreadyCompleted;
        }).toList();
      });
      debugPrint(
          '[FILTER] After filtering: ${learners.length} learners remaining');
    }
  }

  void _navigateToLearnerMaterialSelection(Map<String, dynamic> learner) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogisticsLearnerMaterialSelectionPage(
          learner: learner,
          classID: widget.classID,
        ),
      ),
    );

    // Refresh the list if materials were issued
    if (result == true) {
      _fetchAllLearners();
    }
  }

  Future<void> _fetchUnitStandards() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final projectQuery = '''
        SELECT
          c.classID,
          c.className,
          s.siteID,
          s.project_id,
          pr.Project_pathway
        FROM class c
        LEFT JOIN sites s ON c.siteID = s.siteID
        LEFT JOIN project pr ON s.project_id = pr.project_id
        WHERE c.classID = ?
      ''';

      final projectResult = await db.rawQuery(projectQuery, [widget.classID]);

      debugPrint('[QUALIFICATION] Query result count: ${projectResult.length}');

      if (projectResult.isNotEmpty) {
        final projectPathway =
            projectResult.first['Project_pathway'] as String?;

        debugPrint('[QUALIFICATION] Project_pathway: $projectPathway');

        if (projectPathway != null && projectPathway.isNotEmpty) {
          final pathwayJson = jsonDecode(projectPathway);

          debugPrint('[QUALIFICATION] Parsed JSON: $pathwayJson');

          if (pathwayJson is List && pathwayJson.isNotEmpty) {
            final firstPathway = pathwayJson[0];

            debugPrint('[QUALIFICATION] First pathway: $firstPathway');

            if (firstPathway['qual_types'] != null &&
                firstPathway['qual_types'] is List &&
                firstPathway['qual_types'].isNotEmpty) {
              final qualificationData =
                  firstPathway['qual_types'][0]['qualification'];

              debugPrint(
                  '[QUALIFICATION] Qualification data: $qualificationData');

              if (qualificationData != null) {
                // Try multiple possible field names for qualification
                final qualName = qualificationData['name']?.toString() ??
                    qualificationData['qualification_name']?.toString() ??
                    qualificationData['qualificationName']?.toString() ??
                    qualificationData['title']?.toString() ??
                    'Unknown Qualification';

                debugPrint('[QUALIFICATION] Extracted name: $qualName');

                if (qualificationData['unitStandards'] != null) {
                  final unitStandardsList = qualificationData['unitStandards'];

                  if (unitStandardsList is List) {
                    setState(() {
                      qualification = qualName;
                      unitStandards = unitStandardsList
                          .map((us) => {
                                'unitstandard_id': us['id']?.toString() ?? '',
                                'unit_standard_name': us['name']?.toString() ??
                                    'Unknown Unit Standard',
                              })
                          .toList();
                    });
                    debugPrint(
                        '[QUALIFICATION] ✅ Set qualification: $qualification');
                    debugPrint(
                        '[QUALIFICATION] ✅ Set ${unitStandards.length} unit standards');
                  }
                } else {
                  // Even if no unit standards, still set the qualification name
                  setState(() {
                    qualification = qualName;
                  });
                  debugPrint(
                      '[QUALIFICATION] ✅ Set qualification (no unit standards): $qualification');
                }
              }
            }
          }
        } else {
          debugPrint('[QUALIFICATION] ⚠️ Project_pathway is null or empty');
        }
      } else {
        debugPrint(
            '[QUALIFICATION] ⚠️ No project result found for classID: ${widget.classID}');
      }
    } catch (e) {
      debugPrint('[QUALIFICATION] ❌ Error fetching unit standards: $e');
    }
  }

  // Fingerprint verification for PPE/ToolKit/Consumables
  Future<void> _verifyAndIssueMaterial(Map<String, dynamic> learner) async {
    if (selectedLearningMaterialType == 'Select') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a material type first')),
      );
      return;
    }

    setState(() => isVerifying = true);

    try {
      // STEP 1: Check geofencing (location within 50 meters)
      debugPrint('[VERIFY] Step 1: Checking geofencing...');
      bool isWithinRadius = await _checkLocationAndRadius();
      if (!isWithinRadius) {
        setState(() => isVerifying = false);
        return;
      }
      debugPrint('[VERIFY] ✓ Geofencing check passed');

      // STEP 2: Re-detect scanner when button is clicked (this should trigger USB permission)
      debugPrint('[VERIFY] Step 2: Re-detecting scanner on button click...');
      debugPrint('[VERIFY] Current scanner state: $activeScanner');

      // Force re-detection to trigger USB permission dialog
      setState(() => activeScanner = 'none');
      await _detectScanner();

      // Check if scanner is available after detection
      if (activeScanner == 'none') {
        _showError(
            'No fingerprint scanner detected. Please connect a scanner and try again.');
        setState(() => isVerifying = false);
        return;
      }

      debugPrint('[VERIFY] Scanner detected: $activeScanner');

      // STEP 3: Show progress dialog and verify fingerprint
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Verifying fingerprint...'),
              ],
            ),
          );
        },
      );

      // Get learner's fingerprint template from database
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final learnerData = await db.query(
        'learnerdetails',
        where: 'IDNumber = ?',
        whereArgs: [learner['IDNumber']],
      );

      if (learnerData.isEmpty) {
        Navigator.pop(context); // Close progress dialog
        _showError('Learner not found in database');
        return;
      }

      final learnerRecord = learnerData.first;
      String? enrolledTemplate;

      // Try to get template based on active scanner
      if (activeScanner == 'futronic') {
        enrolledTemplate = learnerRecord['futronic_left_template'] as String? ??
            learnerRecord['futronic_right_template'] as String?;
      } else {
        enrolledTemplate = learnerRecord['zkteco_left_template'] as String? ??
            learnerRecord['zkteco_right_template'] as String?;
      }

      if (enrolledTemplate == null || enrolledTemplate.isEmpty) {
        Navigator.pop(context); // Close progress dialog
        _showError('No fingerprint enrolled for ${learner['FullName']}');
        return;
      }

      // Capture and verify fingerprint
      bool verified = await _captureAndVerifyFingerprint(enrolledTemplate);

      Navigator.pop(context); // Close progress dialog

      if (verified) {
        // Save material issuance
        await _saveMaterialIssuance(learner);
      } else {
        _showError(
            'Fingerprint verification failed for ${learner['FullName']}');
      }
    } catch (e) {
      Navigator.pop(context); // Close progress dialog
      debugPrint('Error in fingerprint verification: $e');
      _showError('Verification error: $e');
    } finally {
      setState(() => isVerifying = false);
    }
  }

  Future<bool> _captureAndVerifyFingerprint(String enrolledTemplate) async {
    try {
      debugPrint(
          '[VERIFY-MAIN] Starting fingerprint verification with scanner: $activeScanner');
      debugPrint('[VERIFY-MAIN] Template length: ${enrolledTemplate.length}');

      if (activeScanner == 'futronic') {
        // Futronic - use verifyBoth for better UX (single scan checks both templates)
        debugPrint('[VERIFY-MAIN] Using Futronic verifyBoth method');
        final result = await _futronicService.verifyBoth(
          hintFinger: 'left',
          leftTemplate: enrolledTemplate,
          rightTemplate: enrolledTemplate,
        );
        debugPrint('[VERIFY-MAIN] Futronic verification result: $result');
        return result == true;
      } else {
        // ZKTeco - try left finger first, then right
        debugPrint('[VERIFY-MAIN] Using ZKTeco verify method');
        try {
          final result =
              await _fingerprintService.verify('left', enrolledTemplate);
          debugPrint('[VERIFY-MAIN] ZKTeco left finger result: $result');
          if (result == true) return true;
        } catch (e) {
          debugPrint('[VERIFY-MAIN] Left finger verification failed: $e');
        }

        // Try right finger
        final result =
            await _fingerprintService.verify('right', enrolledTemplate);
        debugPrint('[VERIFY-MAIN] ZKTeco right finger result: $result');
        return result == true;
      }
    } catch (e) {
      debugPrint('[VERIFY-MAIN] Error capturing fingerprint: $e');
      return false;
    }
  }

  Future<void> _saveMaterialIssuance(Map<String, dynamic> learner) async {
    try {
      debugPrint('[SAVE] ========== SAVE MATERIAL ISSUANCE START ==========');
      debugPrint('[SAVE] Material type: $selectedLearningMaterialType');
      debugPrint('[SAVE] Learner: ${learner['FullName']}');
      debugPrint('[SAVE] Learner ID: ${learner['IDNumber']}');
      debugPrint('[SAVE] ClassID: ${widget.classID}');
      debugPrint('[SAVE] Logistics: $logisticsFullName');

      // Standardize IDs:
      // - learnerID: internal LearnerID (preferred) so learner_issued_unit_standards is consistent
      // - IDNumber: always send so material_receipt_form uses the real ID number
      final internalLearnerID = learner['LearnerID'];
      final idNumber = learner['IDNumber'];
      final learnerID = internalLearnerID ?? idNumber ?? '';
      if (learnerID.toString().isEmpty) {
        throw Exception('Learner ID not found');
      }
      if (idNumber == null || idNumber.toString().isEmpty) {
        throw Exception('IDNumber not found');
      }

      // Save via logistics endpoint (handles both old/new formats and keeps IDs consistent)
      final requestBody = {
        'classID': widget.classID,
        'learnerID': learnerID,
        'IDNumber': idNumber,
        'learnerName': learner['FullName'],
        'materialType': selectedLearningMaterialType,
        'issuedBy': logisticsFullName,
        'selections': {
          selectedLearningMaterialType: true, // Mark as selected
        },
        'quantities': {
          selectedLearningMaterialType: 1, // Default quantity
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      final url = AppConfig.buildUrl('save_logistics_learner_materials.php');
      debugPrint('[SAVE] URL: $url');
      debugPrint('[SAVE] Request body: ${json.encode(requestBody)}');

      final response = await http
          .post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout - server not responding');
        },
      );

      debugPrint('[SAVE] Response status: ${response.statusCode}');
      debugPrint('[SAVE] Response headers: ${response.headers}');
      debugPrint('[SAVE] Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final result = json.decode(response.body);
          debugPrint('[SAVE] Parsed result: $result');
          debugPrint('[SAVE] Success field: ${result['success']}');
          debugPrint('[SAVE] Message field: ${result['message']}');

          if (result['success'] == true) {
            debugPrint('[SAVE] ✅ Save successful!');
            _showSuccess(
                '✅ $selectedLearningMaterialType issued to ${learner['FullName']}');

            // Refresh learner list to remove the learner who just received the material
            await _filterLearnersByMaterialType();
          } else {
            final errorMsg =
                result['error'] ?? result['message'] ?? 'Unknown error';
            debugPrint('[SAVE] ❌ Server returned error: $errorMsg');
            _showError('Failed to save: $errorMsg');
          }
        } catch (jsonError) {
          debugPrint('[SAVE] ❌ JSON parse error: $jsonError');
          debugPrint('[SAVE] Raw response: ${response.body}');
          _showError('Invalid response from server');
        }
      } else {
        debugPrint('[SAVE] ❌ HTTP error: ${response.statusCode}');
        _showError('Server error: ${response.statusCode}');
      }

      debugPrint('[SAVE] ========== SAVE MATERIAL ISSUANCE END ==========');
    } catch (e, stackTrace) {
      debugPrint('[SAVE] ❌ Exception: $e');
      debugPrint('[SAVE] Stack trace: $stackTrace');
      _showError('Error saving: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Geofencing methods
  Future<bool> _checkLocationAndRadius() async {
    // GEOFENCING ENABLED - Check if user is within 50 meters of site
    try {
      debugPrint('[GEOFENCE] Checking location and radius...');

      // Validate location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled. Please enable GPS.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are denied.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError(
            'Location permissions are permanently denied. Please enable in settings.');
        return false;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      debugPrint(
          '[GEOFENCE] Current position: ${position.latitude}, ${position.longitude}');
      debugPrint('[GEOFENCE] Accuracy: ${position.accuracy} meters');

      // Validate site radius (50 meters)
      bool isWithinRadius = await _isWithinSiteRadius(
        widget.classID,
        position.latitude,
        position.longitude,
        position.accuracy,
      );

      return isWithinRadius;
    } catch (e) {
      debugPrint('[GEOFENCE] Error checking location: $e');
      _showError('Error checking location: $e');
      return false;
    }
  }

  Future<bool> _isWithinSiteRadius(String classID, double userLat,
      double userLon, double userAccuracy) async {
    if (userAccuracy > 100) {
      debugPrint(
          '[GEOFENCE] Geolocation accuracy too low: $userAccuracy meters');
      _showError('Geolocation accuracy too low. Please enable GPS.');
      return false;
    }

    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      debugPrint('[GEOFENCE] Querying coordinates for classID: $classID');

      final result = await db.rawQuery(
        'SELECT s.latitude, s.longitude FROM class c JOIN sites s ON c.siteID = s.siteID WHERE c.classID = ?',
        [classID.toString()],
      );

      if (result.isEmpty) {
        debugPrint('[GEOFENCE] No site coordinates found for class $classID');
        _showError('No site coordinates found for class $classID.');
        return false;
      }

      final siteLat = double.tryParse(result.first['latitude'].toString());
      final siteLon = double.tryParse(result.first['longitude'].toString());

      if (siteLat == null || siteLon == null) {
        debugPrint('[GEOFENCE] Invalid site coordinates');
        _showError('Invalid site coordinates in database.');
        return false;
      }

      final distance = _calculateDistance(userLat, userLon, siteLat, siteLon);

      debugPrint(
          '[GEOFENCE] Distance to site: ${distance.toStringAsFixed(2)} meters');
      debugPrint('[GEOFENCE] Site coordinates: $siteLat, $siteLon');
      debugPrint('[GEOFENCE] User coordinates: $userLat, $userLon');

      if (distance > 50) {
        // 50 meters radius
        _showError(
            'Outside 50-meter radius. Distance: ${distance.toStringAsFixed(2)} meters');
        return false;
      }

      debugPrint('[GEOFENCE] ✓ Within 50-meter radius');
      return true;
    } catch (e, stackTrace) {
      debugPrint(
          '[GEOFENCE] Error checking site radius: $e\nStack trace: $stackTrace');
      _showError('Error checking location: $e');
      return false;
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371e3; // Earth radius in meters
    final double phi1 = lat1 * pi / 180;
    final double phi2 = lat2 * pi / 180;
    final double deltaPhi = (lat2 - lat1) * pi / 180;
    final double deltaLambda = (lon2 - lon1) * pi / 180;

    final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c; // Distance in meters
  }

  void _showUnitStandardsPopup(Map<String, dynamic> learner) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _LogisticsUnitStandardsDialog(
          learner: learner,
          classID: widget.classID,
          unitStandards: unitStandards,
          logisticsFullName: logisticsFullName,
        );
      },
    );
  }

  void _showPPEPopup(Map<String, dynamic> learner) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _LogisticsPPEDialog(
          learner: learner,
          classID: widget.classID,
          contiSuitSizes: contiSuitSizes,
          bootsSizes: bootsSizes,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Learning Materials'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAllLearners,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : learners.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 64, color: Colors.orange.shade700),
                        const SizedBox(height: 16),
                        const Text(
                          'No learners found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'ClassID: ${widget.classID}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          color: Colors.orange.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.orange.shade700),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Possible reasons:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                    '• Server database is empty for this class'),
                                const Text(
                                    '• Learners need to be added through the app'),
                                const Text('• Network connection issue'),
                                const Text('• ClassID mismatch'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchAllLearners,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Selection Interface at the top
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              // Qualification Section
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Qualification',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      qualification.isEmpty
                                          ? 'No qualification assigned'
                                          : qualification,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Full Name and Selection Row
                              Row(
                                children: [
                                  // Full Name Section
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          const Text(
                                            'Full Name',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            logisticsFullName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Selection Dropdown
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          const Text(
                                            'Selection',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          DropdownButton<String>(
                                            value: selectedLearningMaterialType,
                                            isExpanded: true,
                                            underline: Container(),
                                            items: materialTypes
                                                .map((String value) {
                                              return DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(
                                                  value,
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged:
                                                (String? newValue) async {
                                              setState(() {
                                                selectedLearningMaterialType =
                                                    newValue!;
                                              });
                                              // Filter learners based on new material type
                                              await _filterLearnersByMaterialType();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Info Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.blue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedLearningMaterialType == 'Select'
                                      ? 'Showing ${learners.length} learner${learners.length != 1 ? 's' : ''}. Tap a learner to issue materials.'
                                      : selectedLearningMaterialType ==
                                              'Learning Material'
                                          ? issuedLearnerNames.isEmpty
                                              ? 'Showing ${learners.length} learner${learners.length != 1 ? 's' : ''} (none completed all unit standards yet).'
                                              : 'Showing ${learners.length} learner${learners.length != 1 ? 's' : ''} (${issuedLearnerNames.length} completed all unit standards).'
                                          : selectedLearningMaterialType ==
                                                  'PPE'
                                              ? issuedLearnerNames.isEmpty
                                                  ? 'Showing ${learners.length} learner${learners.length != 1 ? 's' : ''} (none have received PPE yet).'
                                                  : 'Showing ${learners.length} learner${learners.length != 1 ? 's' : ''} (${issuedLearnerNames.length} already received PPE).'
                                              : issuedLearnerNames.isEmpty
                                                  ? 'Showing ${learners.length} learner${learners.length != 1 ? 's' : ''} (none have received $selectedLearningMaterialType yet).'
                                                  : 'Showing ${learners.length} learner${learners.length != 1 ? 's' : ''} (${issuedLearnerNames.length} already received $selectedLearningMaterialType).',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Learners List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: learners.length,
                        itemBuilder: (context, index) {
                          final learner = learners[index];
                          final bool showUnitStandards =
                              selectedLearningMaterialType ==
                                  'Learning Material';
                          final bool showPPE =
                              selectedLearningMaterialType == 'PPE';

                          // Debug print
                          if (index == 0) {
                            debugPrint(
                                'Selected Material Type: $selectedLearningMaterialType');
                            debugPrint(
                                'Show Unit Standards: $showUnitStandards');
                            debugPrint('Show PPE: $showPPE');
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  // Learner Info Section
                                  Expanded(
                                    flex:
                                        (showUnitStandards || showPPE) ? 3 : 4,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.blue,
                                          child: Text(
                                            learner['FullName']
                                                    ?.toString()
                                                    .substring(0, 1)
                                                    .toUpperCase() ??
                                                '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                learner['FullName'] ??
                                                    'Unknown',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                'ID: ${learner['IDNumber'] ?? 'N/A'}',
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
                                  ),

                                  // Unit Standards Button (only for Learning Material)
                                  if (showUnitStandards) ...[
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _showUnitStandardsPopup(learner),
                                        icon: const Icon(Icons.checklist,
                                            size: 18),
                                        label: const Text('Unit Standards'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],

                                  // PPE Button (only for PPE)
                                  if (showPPE) ...[
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showPPEPopup(learner),
                                        icon: const Icon(Icons.security,
                                            size: 18),
                                        label: const Text('Issue PPE'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],

                                  // All Materials Button / Verify Button
                                  // Hide Verify button when PPE is selected (verification is in PPE dialog)
                                  if (showUnitStandards)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () =>
                                          _navigateToLearnerMaterialSelection(
                                              learner),
                                      tooltip: 'All Materials',
                                    )
                                  else if (!showPPE)
                                    ElevatedButton.icon(
                                      onPressed: isVerifying
                                          ? null
                                          : () =>
                                              _verifyAndIssueMaterial(learner),
                                      icon: const Icon(Icons.fingerprint,
                                          size: 18),
                                      label: const Text('Verify'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

// Unit Standards Dialog Widget
class _LogisticsUnitStandardsDialog extends StatefulWidget {
  final Map<String, dynamic> learner;
  final String classID;
  final List<Map<String, dynamic>> unitStandards;
  final String logisticsFullName;

  const _LogisticsUnitStandardsDialog({
    required this.learner,
    required this.classID,
    required this.unitStandards,
    required this.logisticsFullName,
  });

  @override
  State<_LogisticsUnitStandardsDialog> createState() =>
      _LogisticsUnitStandardsDialogState();
}

class _LogisticsUnitStandardsDialogState
    extends State<_LogisticsUnitStandardsDialog> {
  Map<String, bool> selectedUnitStandards = {};
  Map<String, int> unitStandardQuantities = {};
  Map<String, int> existingUnitStandardQuantities = {};
  Map<String, String> existingUnitStandardRepresentatives = {};
  bool isLoading = true;

  // Fingerprint services
  final FingerprintService _fingerprintService = FingerprintService();
  final FutronicService _futronicService = FutronicService();
  String activeScanner = 'none';

  @override
  void initState() {
    super.initState();
    _initializeSelections();
    _loadExistingSubmissions();
    _detectScanner();
  }

  Future<void> _detectScanner() async {
    try {
      // Try ZKTeco first
      try {
        final isZkConnected = await _fingerprintService.isSensorConnected();
        if (isZkConnected == true) {
          setState(() => activeScanner = 'zkteco');
          return;
        }
      } catch (e) {
        debugPrint('ZKTeco not available: $e');
      }

      // Try Futronic
      try {
        final isFutronicConnected =
            await _futronicService.isFutronicConnected();
        if (isFutronicConnected == true) {
          setState(() => activeScanner = 'futronic');
          return;
        }
      } catch (e) {
        debugPrint('Futronic not available: $e');
      }

      // No scanner found
      setState(() => activeScanner = 'none');
    } catch (e) {
      debugPrint('Error detecting scanner: $e');
      setState(() => activeScanner = 'none');
    }
  }

  void _initializeSelections() {
    for (var us in widget.unitStandards) {
      String usId = us['unitstandard_id'].toString();

      // Initialize unit standard
      selectedUnitStandards[usId] = false;
      unitStandardQuantities[usId] = 0;
      existingUnitStandardQuantities[usId] = 0;
      existingUnitStandardRepresentatives[usId] = '';

      // Initialize learner guide
      String lgId = '${usId}_LG';
      selectedUnitStandards[lgId] = false;
      unitStandardQuantities[lgId] = 0;
      existingUnitStandardQuantities[lgId] = 0;
      existingUnitStandardRepresentatives[lgId] = '';

      // Initialize formative
      String formId = '${usId}_FORM';
      selectedUnitStandards[formId] = false;
      unitStandardQuantities[formId] = 0;
      existingUnitStandardQuantities[formId] = 0;
      existingUnitStandardRepresentatives[formId] = '';

      // Initialize summative
      String sumId = '${usId}_SUM';
      selectedUnitStandards[sumId] = false;
      unitStandardQuantities[sumId] = 0;
      existingUnitStandardQuantities[sumId] = 0;
      existingUnitStandardRepresentatives[sumId] = '';
    }
  }

  Future<void> _loadExistingSubmissions() async {
    try {
      // Load from server what this specific learner has already received
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl(
            'get_logistics_checkbox_status.php?classID=${widget.classID}&learnerID=${widget.learner['IDNumber']}')),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final checkboxStatus = data['checkboxStatus'] ?? {};
          final quantities = data['quantities'] ?? {};
          final representatives = data['representatives'] ?? {};

          setState(() {
            checkboxStatus.forEach((key, value) {
              if (value == true) {
                selectedUnitStandards[key] = true;
              }
            });

            quantities.forEach((key, value) {
              existingUnitStandardQuantities[key] =
                  value is int ? value : int.tryParse(value.toString()) ?? 0;
            });

            representatives.forEach((key, value) {
              existingUnitStandardRepresentatives[key] = value.toString();
            });
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading existing submissions: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _submitSelections() async {
    // Check if at least one item is selected
    bool hasSelection =
        selectedUnitStandards.values.any((selected) => selected);
    if (!hasSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item')),
      );
      return;
    }

    // STEP 1: Check geofencing (location within 50 meters)
    debugPrint('[SUBMIT] Step 1: Checking geofencing...');
    bool isWithinRadius = await _checkLocationAndRadius();
    if (!isWithinRadius) {
      return;
    }
    debugPrint('[SUBMIT] ✓ Geofencing check passed');

    // STEP 2: Re-detect scanner to trigger USB permission dialog
    debugPrint('[SUBMIT] Step 2: Re-detecting scanner...');
    debugPrint('[SUBMIT] Current scanner state: $activeScanner');
    setState(() => activeScanner = 'none');
    await _detectScanner();

    // Check if scanner is available
    if (activeScanner == 'none') {
      _showError(
          'No fingerprint scanner detected. Please connect a scanner and try again.');
      return;
    }

    debugPrint('[SUBMIT] Scanner detected: $activeScanner');

    // STEP 3: Verify fingerprint
    setState(() => isLoading = true);

    try {
      // Show fingerprint verification dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Verifying fingerprint...'),
                SizedBox(height: 8),
                Text(
                  'Please scan your finger',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      );

      // Get learner's fingerprint template from database
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final learnerData = await db.query(
        'learnerdetails',
        where: 'IDNumber = ?',
        whereArgs: [widget.learner['IDNumber']],
      );

      if (learnerData.isEmpty) {
        Navigator.pop(context); // Close fingerprint dialog
        _showError('Learner not found in database');
        setState(() => isLoading = false);
        return;
      }

      final learnerRecord = learnerData.first;
      String? enrolledTemplate;

      // Try to get template based on active scanner
      if (activeScanner == 'futronic') {
        enrolledTemplate = learnerRecord['futronic_left_template'] as String? ??
            learnerRecord['futronic_right_template'] as String?;
      } else {
        enrolledTemplate = learnerRecord['zkteco_left_template'] as String? ??
            learnerRecord['zkteco_right_template'] as String?;
      }

      if (enrolledTemplate == null || enrolledTemplate.isEmpty) {
        Navigator.pop(context); // Close fingerprint dialog
        _showError('No fingerprint enrolled for ${widget.learner['FullName']}');
        setState(() => isLoading = false);
        return;
      }

      // Capture and verify fingerprint
      bool verified = await _captureAndVerifyFingerprint(enrolledTemplate);

      Navigator.pop(context); // Close fingerprint dialog

      if (!verified) {
        _showError('Fingerprint verification failed. Materials not issued.');
        setState(() => isLoading = false);
        return;
      }

      // Fingerprint verified, now save the selections
      await _saveSelectionsToServer();
    } catch (e) {
      Navigator.pop(context); // Close fingerprint dialog if still open
      debugPrint('Error in fingerprint verification: $e');
      _showError('Verification error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<bool> _captureAndVerifyFingerprint(String enrolledTemplate) async {
    try {
      debugPrint(
          '[VERIFY-DIALOG] Starting fingerprint verification with scanner: $activeScanner');
      debugPrint('[VERIFY-DIALOG] Template length: ${enrolledTemplate.length}');

      if (activeScanner == 'futronic') {
        // Futronic - use verifyBoth for better UX (single scan checks both templates)
        debugPrint('[VERIFY-DIALOG] Using Futronic verifyBoth method');
        final result = await _futronicService.verifyBoth(
          hintFinger: 'left',
          leftTemplate: enrolledTemplate,
          rightTemplate: enrolledTemplate,
        );
        debugPrint('[VERIFY-DIALOG] Futronic verification result: $result');
        return result == true;
      } else {
        // ZKTeco - try left finger first, then right
        debugPrint('[VERIFY-DIALOG] Using ZKTeco verify method');
        try {
          final result =
              await _fingerprintService.verify('left', enrolledTemplate);
          debugPrint('[VERIFY-DIALOG] ZKTeco left finger result: $result');
          if (result == true) return true;
        } catch (e) {
          debugPrint('[VERIFY-DIALOG] Left finger verification failed: $e');
        }

        // Try right finger
        final result =
            await _fingerprintService.verify('right', enrolledTemplate);
        debugPrint('[VERIFY-DIALOG] ZKTeco right finger result: $result');
        return result == true;
      }
    } catch (e) {
      debugPrint('[VERIFY-DIALOG] Error capturing fingerprint: $e');
      return false;
    }
  }

  Future<void> _saveSelectionsToServer() async {
    try {
      // Prepare submission data
      Map<String, dynamic> submissionData = {
        'classID': widget.classID,
        'learnerID': widget.learner['LearnerID'] ?? widget.learner['IDNumber'],
        'IDNumber': widget.learner['IDNumber'],
        'learnerName': widget.learner['FullName'],
        'materialType': 'Learning Material',
        'issuedBy': widget.logisticsFullName,
        'selections': selectedUnitStandards,
        'quantities': unitStandardQuantities,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse(AppConfig.buildUrl('save_logistics_learner_materials.php')),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(submissionData),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    '✅ Fingerprint verified! Materials issued successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          throw Exception(result['error'] ?? 'Submission failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error submitting materials: $e');
      _showError('Error saving: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Geofencing methods for dialog
  Future<bool> _checkLocationAndRadius() async {
    // GEOFENCING ENABLED - Check if user is within 50 meters of site
    try {
      debugPrint('[GEOFENCE-DIALOG] Checking location and radius...');

      // Validate location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled. Please enable GPS.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are denied.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError(
            'Location permissions are permanently denied. Please enable in settings.');
        return false;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      debugPrint(
          '[GEOFENCE-DIALOG] Current position: ${position.latitude}, ${position.longitude}');
      debugPrint('[GEOFENCE-DIALOG] Accuracy: ${position.accuracy} meters');

      // Validate site radius (50 meters)
      bool isWithinRadius = await _isWithinSiteRadius(
        widget.classID,
        position.latitude,
        position.longitude,
        position.accuracy,
      );

      return isWithinRadius;
    } catch (e) {
      debugPrint('[GEOFENCE-DIALOG] Error checking location: $e');
      _showError('Error checking location: $e');
      return false;
    }
  }

  Future<bool> _isWithinSiteRadius(String classID, double userLat,
      double userLon, double userAccuracy) async {
    if (userAccuracy > 100) {
      debugPrint(
          '[GEOFENCE-DIALOG] Geolocation accuracy too low: $userAccuracy meters');
      _showError('Geolocation accuracy too low. Please enable GPS.');
      return false;
    }

    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      debugPrint(
          '[GEOFENCE-DIALOG] Querying coordinates for classID: $classID');

      final result = await db.rawQuery(
        'SELECT s.latitude, s.longitude FROM class c JOIN sites s ON c.siteID = s.siteID WHERE c.classID = ?',
        [classID.toString()],
      );

      if (result.isEmpty) {
        debugPrint(
            '[GEOFENCE-DIALOG] No site coordinates found for class $classID');
        _showError('No site coordinates found for class $classID.');
        return false;
      }

      final siteLat = double.tryParse(result.first['latitude'].toString());
      final siteLon = double.tryParse(result.first['longitude'].toString());

      if (siteLat == null || siteLon == null) {
        debugPrint('[GEOFENCE-DIALOG] Invalid site coordinates');
        _showError('Invalid site coordinates in database.');
        return false;
      }

      final distance = _calculateDistance(userLat, userLon, siteLat, siteLon);

      debugPrint(
          '[GEOFENCE-DIALOG] Distance to site: ${distance.toStringAsFixed(2)} meters');
      debugPrint('[GEOFENCE-DIALOG] Site coordinates: $siteLat, $siteLon');
      debugPrint('[GEOFENCE-DIALOG] User coordinates: $userLat, $userLon');

      if (distance > 50) {
        // 50 meters radius
        _showError(
            'Outside 50-meter radius. Distance: ${distance.toStringAsFixed(2)} meters');
        return false;
      }

      debugPrint('[GEOFENCE-DIALOG] ✓ Within 50-meter radius');
      return true;
    } catch (e, stackTrace) {
      debugPrint(
          '[GEOFENCE-DIALOG] Error checking site radius: $e\nStack trace: $stackTrace');
      _showError('Error checking location: $e');
      return false;
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371e3; // Earth radius in meters
    final double phi1 = lat1 * pi / 180;
    final double phi2 = lat2 * pi / 180;
    final double deltaPhi = (lat2 - lat1) * pi / 180;
    final double deltaLambda = (lon2 - lon1) * pi / 180;

    final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c; // Distance in meters
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unit Standards',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.learner['FullName'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Content
            if (isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (widget.unitStandards.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No unit standards found'),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: widget.unitStandards.length,
                  itemBuilder: (context, index) {
                    final us = widget.unitStandards[index];
                    final usId = us['unitstandard_id'].toString();
                    final usName = us['unit_standard_name'] ?? 'Unknown';

                    final existingUS =
                        existingUnitStandardQuantities[usId] ?? 0;
                    final existingLG =
                        existingUnitStandardQuantities['${usId}_LG'] ?? 0;
                    final existingFORM =
                        existingUnitStandardQuantities['${usId}_FORM'] ?? 0;
                    final existingSUM =
                        existingUnitStandardQuantities['${usId}_SUM'] ?? 0;

                    // Check if all items for this unit standard are already received
                    final allItemsReceived =
                        existingLG > 0 && existingFORM > 0 && existingSUM > 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Unit Standard
                            _buildUnitStandardItem(
                              usId: usId,
                              usName: usName,
                              itemType: 'Unit Standard',
                              existing: existingUS,
                              color: Colors.green,
                            ),

                            const SizedBox(height: 8),

                            // Learner Guide
                            Container(
                              margin: const EdgeInsets.only(left: 20),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: existingLG > 0
                                    ? Colors.grey.shade200
                                    : Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: existingLG > 0
                                        ? Colors.grey.shade400
                                        : Colors.purple.shade200),
                              ),
                              child: _buildUnitStandardItem(
                                usId: '${usId}_LG',
                                usName: '$usId - Learner Guide',
                                itemType: 'Learner Guide',
                                existing: existingLG,
                                color: existingLG > 0
                                    ? Colors.grey
                                    : Colors.purple,
                              ),
                            ),

                            // Formative
                            const SizedBox(height: 8),
                            Container(
                              margin: const EdgeInsets.only(left: 20),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: existingFORM > 0
                                    ? Colors.grey.shade200
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: existingFORM > 0
                                        ? Colors.grey.shade400
                                        : Colors.orange.shade200),
                              ),
                              child: _buildUnitStandardItem(
                                usId: '${usId}_FORM',
                                usName: '$usId - Formative',
                                itemType: 'Formative',
                                existing: existingFORM,
                                color: existingFORM > 0
                                    ? Colors.grey
                                    : Colors.orange,
                              ),
                            ),

                            // Summative
                            const SizedBox(height: 8),
                            Container(
                              margin: const EdgeInsets.only(left: 20),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: existingSUM > 0
                                    ? Colors.grey.shade200
                                    : Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: existingSUM > 0
                                        ? Colors.grey.shade400
                                        : Colors.teal.shade200),
                              ),
                              child: _buildUnitStandardItem(
                                usId: '${usId}_SUM',
                                usName: '$usId - Summative',
                                itemType: 'Summative',
                                existing: existingSUM,
                                color:
                                    existingSUM > 0 ? Colors.grey : Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Submit Button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submitSelections,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fingerprint, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      activeScanner == 'none'
                          ? 'Submit (No Scanner)'
                          : 'Verify & Submit',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitStandardItem({
    required String usId,
    required String usName,
    required String itemType,
    required int existing,
    required Color color,
  }) {
    final isSelected = selectedUnitStandards[usId] ?? false;
    final isChecked = isSelected || existing > 0;
    final currentQuantity = unitStandardQuantities[usId] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: isChecked,
              onChanged: (bool? value) {
                if (value == false && existing > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Cannot uncheck items with previous submissions'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                setState(() {
                  selectedUnitStandards[usId] = value ?? false;
                });
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ID: ${usId.replaceAll('_LG', '').replaceAll('_FORM', '').replaceAll('_SUM', '')}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: color,
                    ),
                  ),
                  Text(
                    itemType,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (existing > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              'Previously issued: $existing units',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (isSelected) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Quantity:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 80,
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: currentQuantity,
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      setState(() {
                        unitStandardQuantities[usId] = newValue;
                      });
                    }
                  },
                  items: List.generate(51, (index) => index).map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(value.toString()),
                    );
                  }).toList(),
                ),
              ),
              if (existing > 0) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      'Total: $existing + $currentQuantity = ${existing + currentQuantity}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

// PPE Dialog Widget
class _LogisticsPPEDialog extends StatefulWidget {
  final Map<String, dynamic> learner;
  final String classID;
  final List<String> contiSuitSizes;
  final List<String> bootsSizes;

  const _LogisticsPPEDialog({
    required this.learner,
    required this.classID,
    required this.contiSuitSizes,
    required this.bootsSizes,
  });

  @override
  State<_LogisticsPPEDialog> createState() => _LogisticsPPEDialogState();
}

class _LogisticsPPEDialogState extends State<_LogisticsPPEDialog> {
  String? selectedContiSuitSize;
  int contiSuitQuantity = 0;
  String? selectedBootsSize;
  int bootsQuantity = 0;
  bool isLoading = false;

  // Fingerprint services
  final FingerprintService _fingerprintService = FingerprintService();
  final FutronicService _futronicService = FutronicService();
  String activeScanner = 'none';

  @override
  void initState() {
    super.initState();
    _detectScanner();
    _loadExistingPPE();
  }

  Future<void> _detectScanner() async {
    try {
      // Try ZKTeco first
      try {
        final isZkConnected = await _fingerprintService.isSensorConnected();
        if (isZkConnected == true) {
          setState(() => activeScanner = 'zkteco');
          return;
        }
      } catch (e) {
        debugPrint('ZKTeco not available: $e');
      }

      // Try Futronic
      try {
        final isFutronicConnected =
            await _futronicService.isFutronicConnected();
        if (isFutronicConnected == true) {
          setState(() => activeScanner = 'futronic');
          return;
        }
      } catch (e) {
        debugPrint('Futronic not available: $e');
      }

      // No scanner found
      setState(() => activeScanner = 'none');
    } catch (e) {
      debugPrint('Error detecting scanner: $e');
      setState(() => activeScanner = 'none');
    }
  }

  Future<void> _loadExistingPPE() async {
    try {
      final response = await http.get(
        Uri.parse(
            '${AppConfig.baseUrl}/get_learner_ppe.php?learnerID=${widget.learner['LearnerID']}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            selectedContiSuitSize = data['data']['conti_suit_size'];
            contiSuitQuantity = data['data']['conti_suit_quantity'] ?? 0;
            selectedBootsSize = data['data']['boots_size'];
            bootsQuantity = data['data']['boots_quantity'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading existing PPE: $e');
    }
  }

  Future<void> _submitPPE() async {
    // Validate at least one PPE item is selected
    if (contiSuitQuantity == 0 && bootsQuantity == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please select at least one PPE item with quantity > 0'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate sizes are selected if quantities > 0
    if (contiSuitQuantity > 0 && selectedContiSuitSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Conti-Suit size'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (bootsQuantity > 0 && selectedBootsSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Safety Boots size'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check scanner
    if (activeScanner == 'none') {
      _showError(
          'No fingerprint scanner detected. Please connect a scanner and try again.');
      return;
    }

    setState(() => isLoading = true);

    try {
      // Show fingerprint verification dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Verifying fingerprint...'),
                SizedBox(height: 8),
                Text(
                  'Please scan your finger',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      );

      // Get learner's fingerprint template
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final learnerData = await db.query(
        'learnerdetails',
        where: 'IDNumber = ?',
        whereArgs: [widget.learner['IDNumber']],
      );

      if (learnerData.isEmpty) {
        Navigator.pop(context); // Close fingerprint dialog
        _showError('Learner not found in database');
        setState(() => isLoading = false);
        return;
      }

      final learnerRecord = learnerData.first;
      String? enrolledTemplate;

      // Get template based on active scanner
      if (activeScanner == 'futronic') {
        enrolledTemplate = learnerRecord['futronic_left_template'] as String? ??
            learnerRecord['futronic_right_template'] as String?;
      } else {
        enrolledTemplate = learnerRecord['zkteco_left_template'] as String? ??
            learnerRecord['zkteco_right_template'] as String?;
      }

      if (enrolledTemplate == null || enrolledTemplate.isEmpty) {
        Navigator.pop(context); // Close fingerprint dialog
        _showError('No fingerprint enrolled for ${widget.learner['FullName']}');
        setState(() => isLoading = false);
        return;
      }

      // Verify fingerprint
      bool verified = await _captureAndVerifyFingerprint(enrolledTemplate);

      Navigator.pop(context); // Close fingerprint dialog

      if (!verified) {
        _showError('Fingerprint verification failed. PPE not issued.');
        setState(() => isLoading = false);
        return;
      }

      // Fingerprint verified, save PPE issuance
      await _savePPEToServer();
    } catch (e) {
      Navigator.pop(context); // Close fingerprint dialog if still open
      debugPrint('Error in fingerprint verification: $e');
      _showError('Verification error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<bool> _captureAndVerifyFingerprint(String enrolledTemplate) async {
    try {
      if (activeScanner == 'futronic') {
        final result = await _futronicService.verifyBoth(
          hintFinger: 'left',
          leftTemplate: enrolledTemplate,
          rightTemplate: enrolledTemplate,
        );
        return result == true;
      } else {
        try {
          final result =
              await _fingerprintService.verify('left', enrolledTemplate);
          if (result == true) return true;
        } catch (e) {
          debugPrint('Left finger verification failed: $e');
        }

        final result =
            await _fingerprintService.verify('right', enrolledTemplate);
        return result == true;
      }
    } catch (e) {
      debugPrint('Error capturing fingerprint: $e');
      return false;
    }
  }

  Future<void> _savePPEToServer() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Create local table if doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS learner_ppe_issuance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          LearnerID INTEGER NOT NULL,
          learner_name TEXT,
          classID TEXT,
          conti_suit_size TEXT,
          conti_suit_quantity INTEGER DEFAULT 0,
          boots_size TEXT,
          boots_quantity INTEGER DEFAULT 0,
          issued_date TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      final ppeData = {
        'LearnerID': widget.learner['LearnerID'],
        'learner_name': widget.learner['FullName'],
        'classID': widget.classID,
        'conti_suit_size': selectedContiSuitSize,
        'conti_suit_quantity': contiSuitQuantity,
        'boots_size': selectedBootsSize,
        'boots_quantity': bootsQuantity,
        'issued_date': DateTime.now().toIso8601String(),
        'synced': 0,
      };

      // Save to local database first
      await db.insert(
        'learner_ppe_issuance',
        ppeData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[PPE-SAVE] Saved to local database');

      // Try to sync to server if online
      bool synced = false;
      try {
        final response = await http
            .post(
              Uri.parse('${AppConfig.baseUrl}/save_learner_ppe.php'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(ppeData),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          if (result['success'] == true) {
            synced = true;
            // Update local record as synced
            await db.update(
              'learner_ppe_issuance',
              {'synced': 1},
              where: 'LearnerID = ?',
              whereArgs: [widget.learner['LearnerID']],
            );
            debugPrint('[PPE-SAVE] Synced to server successfully');
          }
        }
      } catch (e) {
        debugPrint('[PPE-SAVE] Server sync failed (offline): $e');
      }

      if (synced) {
        _showSuccess('PPE issued and synced successfully!');
      } else {
        _showSuccess('PPE issued locally (will sync when online)');
      }

      Navigator.pop(context, true); // Close dialog and refresh list
    } catch (e) {
      debugPrint('Error saving PPE: $e');
      _showError('Error saving PPE: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Issue PPE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.learner['FullName'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Conti-Suit Section
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.checkroom, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                const Text(
                                  'Conti-Suit',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: selectedContiSuitSize,
                              decoration: InputDecoration(
                                labelText: 'Size',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: widget.contiSuitSizes.map((size) {
                                return DropdownMenuItem<String>(
                                  value: size,
                                  child: Text('Size $size'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedContiSuitSize = value;
                                  if (contiSuitQuantity == 0) {
                                    contiSuitQuantity = 1;
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text(
                                  'Quantity:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  onPressed: contiSuitQuantity > 0
                                      ? () {
                                          setState(() {
                                            contiSuitQuantity--;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    contiSuitQuantity.toString(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: contiSuitQuantity < 10
                                      ? () {
                                          setState(() {
                                            contiSuitQuantity++;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Safety Boots Section
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.work_outline,
                                    color: Colors.orange[700]),
                                const SizedBox(width: 8),
                                const Text(
                                  'Safety Boots',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: selectedBootsSize,
                              decoration: InputDecoration(
                                labelText: 'Size',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: widget.bootsSizes.map((size) {
                                return DropdownMenuItem<String>(
                                  value: size,
                                  child: Text('Size $size'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedBootsSize = value;
                                  if (bootsQuantity == 0) {
                                    bootsQuantity = 1;
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text(
                                  'Quantity:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  onPressed: bootsQuantity > 0
                                      ? () {
                                          setState(() {
                                            bootsQuantity--;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    bootsQuantity.toString(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: bootsQuantity < 10
                                      ? () {
                                          setState(() {
                                            bootsQuantity++;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer with Submit Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : _submitPPE,
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.fingerprint),
                      label:
                          Text(isLoading ? 'Processing...' : 'Verify & Issue'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
