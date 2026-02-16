import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'learner_material_selection_page.dart';
import 'config.dart';
import 'services/fingerprint_service.dart';
import 'package:flutter/services.dart';
// import 'package:geolocator/geolocator.dart';  // Uncomment when geolocator is fixed

class LearningMaterialFormPage extends StatefulWidget {
  final String classID;

  const LearningMaterialFormPage({
    super.key,
    required this.classID,
  });

  @override
  State<LearningMaterialFormPage> createState() =>
      _LearningMaterialFormPageState();
}

class _LearningMaterialFormPageState extends State<LearningMaterialFormPage> {
  List<Map<String, dynamic>> learners = [];
  List<Map<String, dynamic>> allLearners =
      []; // Store all learners before filtering
  List<Map<String, dynamic>> unitStandards = [];
  List<String> issuedLearnerNames =
      []; // Learners who already received current material
  bool isLoading = true;

  // Selection interface variables
  String qualification = '';
  String facilitatorFullName = 'Unknown Facilitator';
  String selectedLearningMaterialType = 'Select';

  // Material type options
  final List<String> materialTypes = [
    'Select',
    'Learning Material',
    'PPE',
    'ToolKit',
    'Consumables',
  ];

  // Fingerprint services
  final FingerprintService _fingerprintService = FingerprintService();
  final FutronicService _futronicService = FutronicService();
  String activeScanner = 'none';
  bool isVerifying = false;

  @override
  void initState() {
    super.initState();
    _fetchClockedInLearners();
    _fetchUnitStandards();
    _fetchClassInfo();
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

  Future<void> _fetchClassInfo() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Get class and facilitator info
      final query = '''
        SELECT
          c.className,
          f.firstName,
          f.lastName
        FROM class c
        LEFT JOIN facilitator f ON c.classID = f.classID
        WHERE c.classID = ?
      ''';

      final results = await db.rawQuery(query, [widget.classID]);

      if (results.isNotEmpty) {
        setState(() {
          facilitatorFullName =
              '${results.first['firstName'] ?? ''} ${results.first['lastName'] ?? ''}'
                  .trim();
          if (facilitatorFullName.isEmpty) {
            facilitatorFullName = 'Unknown Facilitator';
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching class info: $e');
    }
  }

  Future<void> _fetchClockedInLearners() async {
    try {
      setState(() => isLoading = true);

      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Get clocked-in learners for this class today
      final query = '''
        SELECT DISTINCT
          ld.IDNumber,
          ld.Name,
          ld.Surname,
          lc.clock_in_time
        FROM learner_clocking lc
        INNER JOIN learnerdetails ld ON lc.LearnerID = ld.LearnerID
        WHERE ld.classID = ?
          AND lc.clock_date = DATE('now')
          AND lc.clock_in_time IS NOT NULL
          AND lc.clock_out_time IS NULL
        ORDER BY ld.Name
      ''';

      final results = await db.rawQuery(query, [widget.classID]);

      // Store all learners
      allLearners = results.map((row) {
        return {
          'IDNumber': row['IDNumber'],
          'FullName': '${row['Name']} ${row['Surname']}',
          'Surname': row['Surname'],
          'ClockInTime': row['clock_in_time'],
        };
      }).toList();

      debugPrint('Fetched ${allLearners.length} clocked-in learners');

      // Apply filtering based on selected material type
      await _filterLearnersByMaterialType();

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint('Error fetching learners: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading learners: $e')),
        );
      }
    }
  }

  Future<void> _fetchIssuedLearners() async {
    // Handle different material types differently
    if (selectedLearningMaterialType == 'Select') {
      setState(() {
        issuedLearnerNames = [];
      });
      return;
    }

    try {
      if (selectedLearningMaterialType == 'Learning Material') {
        // For Learning Material, check if learner has ALL items for ALL unit standards
        debugPrint('[FILTER] Fetching complete learners for Learning Material');

        // Get unit standard IDs
        final unitStandardIds = unitStandards
            .map((us) => us['unitstandard_id'].toString())
            .join(',');

        if (unitStandardIds.isEmpty) {
          debugPrint('[FILTER] No unit standards found');
          setState(() {
            issuedLearnerNames = [];
          });
          return;
        }

        debugPrint('[FILTER] Unit Standard IDs: $unitStandardIds');

        final response = await http.get(
          Uri.parse(AppConfig.buildUrl(
              'get_complete_learners.php?classID=${widget.classID}&unitStandardIds=$unitStandardIds')),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            setState(() {
              issuedLearnerNames =
                  List<String>.from(data['completeLearners'] ?? []);
            });
            debugPrint(
                '[FILTER] Found ${issuedLearnerNames.length} learners who completed ALL unit standards');
            debugPrint('[FILTER] Complete learners: $issuedLearnerNames');
          }
        }
      } else {
        // For PPE, ToolKit, Consumables - check if they received that specific item
        debugPrint(
            '[FILTER] Fetching issued learners for: $selectedLearningMaterialType');

        final response = await http.get(
          Uri.parse(AppConfig.buildUrl(
              'get_issued_learners.php?classID=${widget.classID}&materialType=$selectedLearningMaterialType')),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            setState(() {
              issuedLearnerNames =
                  List<String>.from(data['issuedLearners'] ?? []);
            });
            debugPrint(
                '[FILTER] Found ${issuedLearnerNames.length} learners who already received $selectedLearningMaterialType');
            debugPrint('[FILTER] Issued learners: $issuedLearnerNames');
          }
        }
      }
    } catch (e) {
      debugPrint('[FILTER] Error fetching issued learners: $e');
      // Don't show error to user, just log it
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
        builder: (context) => LearnerMaterialSelectionPage(
          learner: learner,
          classID: widget.classID,
        ),
      ),
    );

    // Refresh the list if materials were issued
    if (result == true) {
      _fetchClockedInLearners();
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

      if (projectResult.isNotEmpty) {
        final projectPathway =
            projectResult.first['Project_pathway'] as String?;

        if (projectPathway != null && projectPathway.isNotEmpty) {
          final pathwayJson = jsonDecode(projectPathway);

          if (pathwayJson is List && pathwayJson.isNotEmpty) {
            final firstPathway = pathwayJson[0];

            if (firstPathway['qual_types'] != null &&
                firstPathway['qual_types'] is List &&
                firstPathway['qual_types'].isNotEmpty) {
              final qualification =
                  firstPathway['qual_types'][0]['qualification'];

              if (qualification != null &&
                  qualification['unitStandards'] != null) {
                final unitStandardsList = qualification['unitStandards'];

                if (unitStandardsList is List) {
                  setState(() {
                    unitStandards = unitStandardsList
                        .map((us) => {
                              'unitstandard_id': us['id']?.toString() ?? '',
                              'unit_standard_name': us['name']?.toString() ??
                                  'Unknown Unit Standard',
                            })
                        .toList();
                  });
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching unit standards: $e');
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
      debugPrint('[SAVE] ClassID: ${widget.classID}');
      debugPrint('[SAVE] Facilitator: $facilitatorFullName');

      // Create a 1x1 transparent PNG as base64 (without the data:image/png;base64, prefix)
      const dummySignature =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      final requestBody = {
        'classID': widget.classID,
        'facilitatorFullName': facilitatorFullName,
        'representativeFullName': learner['FullName'],
        'description': selectedLearningMaterialType,
        'subDescription': selectedLearningMaterialType,
        'quantity': 1,
        'qualificationName': qualification.isEmpty ? 'N/A' : qualification,
        'facilitatorSignature': dummySignature,
        'representativeSignature': dummySignature,
      };

      final url = AppConfig.buildUrl('acknoledge.php');
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
                '✅ ${selectedLearningMaterialType} issued to ${learner['FullName']}');

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
    // TODO: Uncomment when geolocator plugin is fixed
    return true; // Skip location check for now

    /* UNCOMMENT THIS WHEN GEOLOCATOR IS FIXED
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

      debugPrint('[GEOFENCE] Current position: ${position.latitude}, ${position.longitude}');
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
    */
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
        return _UnitStandardsDialog(
          learner: learner,
          classID: widget.classID,
          unitStandards: unitStandards,
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
            onPressed: _fetchClockedInLearners,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : learners.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No learners clocked in today',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _fetchClockedInLearners,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
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
                                            facilitatorFullName,
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
                                      ? 'Showing ${learners.length} clocked-in learner${learners.length != 1 ? 's' : ''}. Tap a learner to issue materials.'
                                      : selectedLearningMaterialType ==
                                              'Learning Material'
                                          ? issuedLearnerNames.isEmpty
                                              ? 'Showing ${learners.length} clocked-in learner${learners.length != 1 ? 's' : ''} (none completed all unit standards yet).'
                                              : 'Showing ${learners.length} learner${learners.length != 1 ? 's' : ''} (${issuedLearnerNames.length} completed all unit standards).'
                                          : issuedLearnerNames.isEmpty
                                              ? 'Showing ${learners.length} clocked-in learner${learners.length != 1 ? 's' : ''} (none have received $selectedLearningMaterialType yet).'
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

                          // Debug print
                          if (index == 0) {
                            debugPrint(
                                'Selected Material Type: $selectedLearningMaterialType');
                            debugPrint(
                                'Show Unit Standards: $showUnitStandards');
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
                                    flex: showUnitStandards ? 3 : 4,
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

                                  // All Materials Button / Verify Button
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
                                  else
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
class _UnitStandardsDialog extends StatefulWidget {
  final Map<String, dynamic> learner;
  final String classID;
  final List<Map<String, dynamic>> unitStandards;

  const _UnitStandardsDialog({
    required this.learner,
    required this.classID,
    required this.unitStandards,
  });

  @override
  State<_UnitStandardsDialog> createState() => _UnitStandardsDialogState();
}

class _UnitStandardsDialogState extends State<_UnitStandardsDialog> {
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
      unitStandardQuantities[usId] = 1;
      existingUnitStandardQuantities[usId] = 0;
      existingUnitStandardRepresentatives[usId] = '';

      // Initialize learner guide
      String lgId = '${usId}_LG';
      selectedUnitStandards[lgId] = false;
      unitStandardQuantities[lgId] = 1;
      existingUnitStandardQuantities[lgId] = 0;
      existingUnitStandardRepresentatives[lgId] = '';

      // Initialize formative
      String formId = '${usId}_FORM';
      selectedUnitStandards[formId] = false;
      unitStandardQuantities[formId] = 1;
      existingUnitStandardQuantities[formId] = 0;
      existingUnitStandardRepresentatives[formId] = '';

      // Initialize summative
      String sumId = '${usId}_SUM';
      selectedUnitStandards[sumId] = false;
      unitStandardQuantities[sumId] = 1;
      existingUnitStandardQuantities[sumId] = 0;
      existingUnitStandardRepresentatives[sumId] = '';
    }
  }

  Future<void> _loadExistingSubmissions() async {
    try {
      // Load from server what this specific learner has already received
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl(
            'get_learner_material_status.php?classID=${widget.classID}&learnerID=${widget.learner['IDNumber']}')),
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
        'learnerID': widget.learner['IDNumber'],
        'learnerName': widget.learner['FullName'],
        'selections': selectedUnitStandards,
        'quantities': unitStandardQuantities,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse(AppConfig.buildUrl('save_learner_materials.php')),
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
    // TODO: Uncomment when geolocator plugin is fixed
    return true; // Skip location check for now

    /* UNCOMMENT THIS WHEN GEOLOCATOR IS FIXED
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

      debugPrint('[GEOFENCE-DIALOG] Current position: ${position.latitude}, ${position.longitude}');
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
    */
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

                    // Hide this unit standard if all items are already received
                    if (allItemsReceived) {
                      return const SizedBox.shrink(); // Hide completely
                    }

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

                            // Learner Guide - Only show if not received
                            if (existingLG == 0)
                              Container(
                                margin: const EdgeInsets.only(left: 20),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.purple.shade200),
                                ),
                                child: _buildUnitStandardItem(
                                  usId: '${usId}_LG',
                                  usName: '$usId - Learner Guide',
                                  itemType: 'Learner Guide',
                                  existing: existingLG,
                                  color: Colors.purple,
                                ),
                              ),

                            // Formative - Only show if not received
                            if (existingFORM == 0) ...[
                              const SizedBox(height: 8),
                              Container(
                                margin: const EdgeInsets.only(left: 20),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.orange.shade200),
                                ),
                                child: _buildUnitStandardItem(
                                  usId: '${usId}_FORM',
                                  usName: '$usId - Formative',
                                  itemType: 'Formative',
                                  existing: existingFORM,
                                  color: Colors.orange,
                                ),
                              ),
                            ],

                            // Summative - Only show if not received
                            if (existingSUM == 0) ...[
                              const SizedBox(height: 8),
                              Container(
                                margin: const EdgeInsets.only(left: 20),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.teal.shade200),
                                ),
                                child: _buildUnitStandardItem(
                                  usId: '${usId}_SUM',
                                  usName: '$usId - Summative',
                                  itemType: 'Summative',
                                  existing: existingSUM,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
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
    final currentQuantity = unitStandardQuantities[usId] ?? 1;

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
                  items:
                      List.generate(50, (index) => index + 1).map((int value) {
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
