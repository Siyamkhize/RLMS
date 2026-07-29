import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'database_helper.dart';
import 'config.dart';

class MaterialForm extends StatefulWidget {
  final String classID;

  const MaterialForm({super.key, required this.classID});

  @override
  _MaterialFormState createState() => _MaterialFormState();
}

class _MaterialFormState extends State<MaterialForm> {
  Uint8List? facilitatorSignature;
  Uint8List? representativeSignature;
  String facilitatorFullName = '';
  String representativeName = '';
  String practitionerFullName = '';
  String practitionerID = '';
  String className = '';
  String qualification_name = '';
  List learners = [];
  List<SignatureController> signatureControllers = [];
  String selectedDescription = 'Select';
  String selectedLearningMaterialType = 'Select';
  int quantity = 0;
  String qualification = '';

  // Unit Standards related variables
  List<Map<String, dynamic>> unitStandards = [];
  Map<String, bool> selectedUnitStandards = {};
  Map<String, int> unitStandardQuantities = {};
  Map<String, int> existingUnitStandardQuantities = {};
  Map<String, String> existingUnitStandardRepresentatives = {};

  // Regular materials tracking
  Map<String, int> existingRegularMaterialQuantities = {};
  Map<String, String> existingRegularMaterialRepresentatives = {};

  // Unit Standard sub-options (Formative, Summative, Learner Guide)
  Map<String, Map<String, bool>> unitStandardSubOptions = {};
  Map<String, Map<String, int>> unitStandardSubQuantities = {};

  // Sanitize name function to transform names like "Siya Mkhize" to "siya_mkhize"
  String sanitizeName(String name) {
    if (name.isEmpty) return 'default'; // Handle empty names
    return name
        .toLowerCase() // Convert to lowercase
        .replaceAll(' ', '_') // Replace spaces with underscores
        .replaceAll(RegExp(r'[^a-z0-9_]'), ''); // Remove special characters
  }

  @override
  void initState() {
    super.initState();
    // Listen for connectivity changes
    _checkConnectivity();
    // Fetch unit standards and other info for this class
    _loadAllInitialData();
    // Load existing regular material submissions
    _loadExistingRegularMaterialQuantities();
  }

  Future<void> _loadAllInitialData() async {
    try {
      await Future.wait([
        _fetchUnitStandards(),
        _fetchPractitionerAndClassInfo(),
      ]);
    } catch (e) {
      print('Error loading initial data: $e');
    }
  }

  Future<void> _fetchPractitionerAndClassInfo() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // 1. Try to get facilitator info for this class
      final facilitatorQuery = '''
        SELECT 
          f.firstName,
          f.lastName,
          c.className,
          c.qualification_id as class_qual_id,
          s.qualification_id as site_qual_id
        FROM class c
        LEFT JOIN facilitator f ON c.classID = f.classID
        LEFT JOIN sites s ON c.siteID = s.siteID
        WHERE c.classID = ?
      ''';

      final results = await db.rawQuery(facilitatorQuery, [widget.classID]);

      if (results.isNotEmpty) {
        final row = results.first;
        setState(() {
          practitionerFullName =
              '${row['firstName'] ?? ''} ${row['lastName'] ?? ''}'.trim();
          if (practitionerFullName.isEmpty) {
            practitionerFullName = 'Unknown Facilitator';
          }
          className = row['className']?.toString() ?? 'Unknown Class';

          // Try to get qualification name
          String? qualId = row['class_qual_id']?.toString() ??
              row['site_qual_id']?.toString();
          if (qualId != null && qualId.isNotEmpty) {
            _fetchQualificationName(qualId);
          }
        });
      }
    } catch (e) {
      print('Error fetching practitioner info: $e');
    }
  }

  Future<void> _fetchQualificationName(String qualId) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final qualQuery =
          'SELECT name FROM qualification WHERE qualification_id = ?';
      final qualResults = await db.rawQuery(qualQuery, [qualId]);

      if (qualResults.isNotEmpty) {
        setState(() {
          qualification_name = qualResults.first['name']?.toString() ?? '';
          qualification = qualification_name;
        });
      }
    } catch (e) {
      print('Error fetching qualification name: $e');
    }
  }

  // Load existing regular material quantities from SERVER (not local database)
  Future<void> _loadExistingRegularMaterialQuantities() async {
    try {
      print(
          '🌐 Loading regular material quantities from SERVER for classID: ${widget.classID}');

      // Query server for all material data (including regular materials)
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl(
            'get_checkbox_status.php?classID=${widget.classID}')),
      );

      print('📡 Server Response Status: ${response.statusCode}');
      print('📡 Server Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true) {
          // Robustly handle regularMaterials (could be Map or empty List from PHP)
          Map<String, dynamic> regularMaterials = {};
          if (data['regularMaterials'] is Map) {
            regularMaterials = data['regularMaterials'] as Map<String, dynamic>;
          }

          print(
              '✅ Server returned ${regularMaterials.length} regular material types');

          // List of regular material types to check
          List<String> regularMaterialTypes = [
            'ToolKit',
            'PPE',
            'Consumables',
            'Learner Guide',
            'Stationary (Files, Pens)'
          ];

          // Apply server data to regular materials
          for (String materialType in regularMaterialTypes) {
            if (regularMaterials.containsKey(materialType)) {
              final materialData = regularMaterials[materialType];
              final int quantity = materialData['quantity']?.toInt() ?? 0;
              final String representative =
                  materialData['representative']?.toString() ?? '';

              setState(() {
                existingRegularMaterialQuantities[materialType] = quantity;
                existingRegularMaterialRepresentatives[materialType] =
                    representative;
              });

              if (quantity > 0) {
                print(
                    '✅ Regular Material $materialType: Qty=$quantity, Rep=$representative');
              }
            } else {
              // No submissions found for this material type
              setState(() {
                existingRegularMaterialQuantities[materialType] = 0;
                existingRegularMaterialRepresentatives[materialType] = '';
              });
            }
          }

          print(
              '🎯 Regular material loading from server completed successfully!');
        } else {
          print('❌ Server returned error: ${data['error']}');
          _setNoRegularMaterialSubmissionsFound();
        }
      } else {
        print('❌ Server request failed with status: ${response.statusCode}');
        _setNoRegularMaterialSubmissionsFound();
      }
    } catch (e) {
      print('💥 Error loading regular material quantities from server: $e');
      _setNoRegularMaterialSubmissionsFound();
    }
  }

  // Fallback method when server is unavailable for regular materials
  void _setNoRegularMaterialSubmissionsFound() {
    List<String> regularMaterialTypes = [
      'ToolKit',
      'PPE',
      'Consumables',
      'Learner Guide',
      'Stationary (Files, Pens)'
    ];

    setState(() {
      for (String materialType in regularMaterialTypes) {
        existingRegularMaterialQuantities[materialType] = 0;
        existingRegularMaterialRepresentatives[materialType] = '';
      }
    });
    print(
        'ℹ️ Set all regular materials to no previous submissions (no server data available)');
  }

  // Debug method to help troubleshoot database relationships
  Future<void> _debugDatabaseInfo() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      print('\\n=== DEBUG DATABASE INFO FOR CLASS ${widget.classID} ===');

      // 1. Check class table
      final classInfo = await db
          .query('class', where: 'classID = ?', whereArgs: [widget.classID]);
      print('1. Class table data: $classInfo');

      if (classInfo.isNotEmpty) {
        String? siteID = classInfo.first['siteID']?.toString();
        print('   Found siteID: $siteID');

        // 2. Check sites table
        if (siteID != null) {
          final siteInfo =
              await db.query('sites', where: 'siteID = ?', whereArgs: [siteID]);
          print('2. Sites table data: $siteInfo');

          if (siteInfo.isNotEmpty) {
            String? projectId = siteInfo.first['project_id']?.toString();
            print('   Found project_id: $projectId');

            // 3. Check project table and extract unit standards JSON
            if (projectId != null) {
              final projectQuery = '''
                SELECT 
                  project_id,
                  Project_name,
                  Project_pathway
                FROM project 
                WHERE project_id = ?
              ''';

              final projectInfo = await db.rawQuery(projectQuery, [projectId]);
              print('3. Project JSON extraction: $projectInfo');

              if (projectInfo.isNotEmpty) {
                String? projectPathway =
                    projectInfo.first['Project_pathway'] as String?;
                print('4. Project pathway JSON: $projectPathway');

                if (projectPathway != null && projectPathway.isNotEmpty) {
                  try {
                    List<dynamic> pathwayList = jsonDecode(projectPathway);
                    if (pathwayList.isNotEmpty) {
                      var firstPathway = pathwayList[0];
                      if (firstPathway['qual_types'] != null &&
                          firstPathway['qual_types'].isNotEmpty) {
                        var qualification =
                            firstPathway['qual_types'][0]['qualification'];
                        if (qualification != null &&
                            qualification['unitStandards'] != null) {
                          List<dynamic> unitStandardsList =
                              qualification['unitStandards'];
                          print(
                              '5. Parsed unit standards count: ${unitStandardsList.length}');
                          print('6. Sample unit standards:');
                          for (int i = 0;
                              i < unitStandardsList.length && i < 3;
                              i++) {
                            print('   - ${unitStandardsList[i]}');
                          }
                        }
                      }
                    }
                  } catch (e) {
                    print('5. Error parsing JSON: $e');
                  }
                }
              }
            }
          }
        }
      }

      print('=== END DEBUG INFO ===\\n');
    } catch (e) {
      print('Debug error: $e');
    }
  }

  // Fetch unit standards for the class
  Future<void> _fetchUnitStandards() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      print('\\n=== FETCHING UNIT STANDARDS DEBUG ===');
      print('ClassID: ${widget.classID}');

      // First, let's check what project data we have
      final projectQuery = '''
        SELECT 
          c.classID,
          c.className,
          s.siteID,
          s.project_id,
          pr.Project_pathway,
          s.qualification_id as site_qual_id
        FROM class c
        LEFT JOIN sites s ON c.siteID = s.siteID
        LEFT JOIN project pr ON s.project_id = pr.project_id
        WHERE c.classID = ?
      ''';

      final List<Map<String, dynamic>> projectResults =
          await db.rawQuery(projectQuery, [widget.classID]);
      print('Project query result: $projectResults');

      if (projectResults.isNotEmpty) {
        final firstRow = projectResults.first;
        final String? projectPathway = firstRow['Project_pathway'];
        final String? siteQualId = firstRow['site_qual_id']?.toString();
        print('Raw Project_pathway: $projectPathway');

        if (projectPathway != null && projectPathway.isNotEmpty) {
          try {
            // Parse the JSON to extract unit standards
            final pathwayJson = jsonDecode(projectPathway);
            print('Parsed pathway JSON: $pathwayJson');

            // Navigate through the JSON structure
            if (pathwayJson is List && pathwayJson.isNotEmpty) {
              final firstPathway = pathwayJson[0];
              print('First pathway: $firstPathway');

              if (firstPathway['qual_types'] != null &&
                  firstPathway['qual_types'] is List &&
                  firstPathway['qual_types'].isNotEmpty) {
                final qualification =
                    firstPathway['qual_types'][0]['qualification'];
                print('Qualification: $qualification');

                if (qualification != null &&
                    qualification['unitStandards'] != null) {
                  final unitStandardsList = qualification['unitStandards'];
                  print('Unit standards list: $unitStandardsList');

                  if (unitStandardsList is List &&
                      unitStandardsList.isNotEmpty) {
                    setState(() {
                      unitStandards = unitStandardsList
                          .map((us) => {
                                'unitstandard_id': us['id']?.toString() ?? '',
                                'unit_standard_name': us['name']?.toString() ??
                                    'Unknown Unit Standard',
                                'qualification_id':
                                    us['qualification_id']?.toString() ?? '',
                                'level': us['level']?.toString() ?? '',
                                'credits': us['credits']?.toString() ?? '',
                                'description':
                                    us['description']?.toString() ?? '',
                              })
                          .toList();

                      // Initialize selection and quantity maps
                      _initializeSelectionMaps();
                    });

                    // Load existing quantities from previous submissions
                    await _loadExistingUnitStandardQuantities();

                    print('Unit standards loaded successfully from JSON');
                    print('=== UNIT STANDARDS FETCH COMPLETE ===\\n');
                    return;
                  }
                }
              }
            }
          } catch (e) {
            print('Error parsing project pathway JSON: $e');
          }
        }

        // Fallback: If JSON is missing or empty, try the unitstandard table
        print(
            'Fallback: Trying unitstandard table for qualification_id: $siteQualId');
        if (siteQualId != null && siteQualId.isNotEmpty) {
          final usQuery = '''
            SELECT unitstandard_id, unit_standard_name, level, credits
            FROM unitstandard 
            WHERE qualification_id = ?
          ''';
          final List<Map<String, dynamic>> usResults =
              await db.rawQuery(usQuery, [siteQualId]);

          if (usResults.isNotEmpty) {
            print('Found ${usResults.length} unit standards in table');
            setState(() {
              unitStandards = usResults
                  .map((row) => {
                        'unitstandard_id':
                            row['unitstandard_id']?.toString() ?? '',
                        'unit_standard_name':
                            row['unit_standard_name']?.toString() ??
                                'Unknown Unit Standard',
                        'level': row['level']?.toString() ?? '',
                        'credits': row['credits']?.toString() ?? '',
                      })
                  .toList();

              _initializeSelectionMaps();
            });

            // Load existing quantities from previous submissions
            await _loadExistingUnitStandardQuantities();
            print('=== UNIT STANDARDS FETCH COMPLETE (FALLBACK) ===\\n');
            return;
          }
        }
      }

      // If we get here, no unit standards were found
      print('No unit standards found for classID: ${widget.classID}');
      setState(() {
        unitStandards = [];
      });
      print('=== UNIT STANDARDS FETCH COMPLETE (EMPTY) ===\\n');
    } catch (e) {
      print('Error fetching unit standards: $e');
      setState(() {
        unitStandards = [];
      });
    }
  }

  // Helper to initialize maps
  void _initializeSelectionMaps() {
    for (var us in unitStandards) {
      String usId = us['unitstandard_id'].toString();
      // Initialize unit standard
      selectedUnitStandards[usId] = false;
      unitStandardQuantities[usId] = 0;
      existingUnitStandardQuantities[usId] = 0;
      existingUnitStandardRepresentatives[usId] = '';

      // Initialize sub-options
      for (String type in ['LG', 'FORM', 'SUM']) {
        String subId = '${usId}_$type';
        selectedUnitStandards[subId] = false;
        unitStandardQuantities[subId] = 0;
        existingUnitStandardQuantities[subId] = 0;
        existingUnitStandardRepresentatives[subId] = '';
      }
    }
  }

  // Load existing unit standard quantities from SERVER (not local database)
  Future<void> _loadExistingUnitStandardQuantities() async {
    try {
      print(
          '🌐 Loading checkbox status from SERVER for classID: ${widget.classID}');

      // Query server for checkbox status instead of local database
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl(
            'get_checkbox_status.php?classID=${widget.classID}')),
      );

      print('📡 Server Response Status: ${response.statusCode}');
      print('📡 Server Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true) {
          final Map<String, dynamic> checkboxStatus =
              data['checkboxStatus'] ?? {};
          final Map<String, dynamic> quantities = data['quantities'] ?? {};
          final Map<String, dynamic> representatives =
              data['representatives'] ?? {};

          print('✅ Server returned ${checkboxStatus.length} checkbox statuses');

          // DEBUG: Print the raw API data
          print('🔍 DEBUG - Raw API Response:');
          print('   checkboxStatus: $checkboxStatus');
          print('   quantities: $quantities');
          print('   representatives: $representatives');

          // Apply server data to unit standards
          for (var us in unitStandards) {
            String usId = us['unitstandard_id'].toString();
            String lgId = '${usId}_LG';
            String formId = '${usId}_FORM';
            String sumId = '${usId}_SUM';

            // Unit Standard checkbox and quantity
            bool isCheckedUS = checkboxStatus[usId] == true;
            int quantityUS = quantities[usId]?.toInt() ?? 0;
            String repUS = representatives[usId]?.toString() ?? '';

            // Learner Guide checkbox and quantity
            bool isCheckedLG = checkboxStatus[lgId] == true;
            int quantityLG = quantities[lgId]?.toInt() ?? 0;
            String repLG = representatives[lgId]?.toString() ?? '';

            // Formative checkbox and quantity
            bool isCheckedFORM = checkboxStatus[formId] == true;
            int quantityFORM = quantities[formId]?.toInt() ?? 0;
            String repFORM = representatives[formId]?.toString() ?? '';

            // Summative checkbox and quantity
            bool isCheckedSUM = checkboxStatus[sumId] == true;
            int quantitySUM = quantities[sumId]?.toInt() ?? 0;
            String repSUM = representatives[sumId]?.toString() ?? '';

            // DEBUG: Print processing for each unit standard
            print('🔍 DEBUG - Processing Unit Standard $usId:');
            print('   API quantities[$usId] = ${quantities[usId]}');
            print('   API quantities[$lgId] = ${quantities[lgId]}');
            print('   API quantities[$formId] = ${quantities[formId]}');
            print('   API quantities[$sumId] = ${quantities[sumId]}');
            print('   Converted quantityUS = $quantityUS');
            print('   Converted quantityLG = $quantityLG');
            print('   Converted quantityFORM = $quantityFORM');
            print('   Converted quantitySUM = $quantitySUM');

            setState(() {
              // Set Unit Standard data
              existingUnitStandardQuantities[usId] = quantityUS;
              existingUnitStandardRepresentatives[usId] = repUS;
              if (isCheckedUS) {
                selectedUnitStandards[usId] = true;
              }

              // Set Learner Guide data
              existingUnitStandardQuantities[lgId] = quantityLG;
              existingUnitStandardRepresentatives[lgId] = repLG;
              if (isCheckedLG) {
                selectedUnitStandards[lgId] = true;
              }

              // Set Formative data
              existingUnitStandardQuantities[formId] = quantityFORM;
              existingUnitStandardRepresentatives[formId] = repFORM;
              if (isCheckedFORM) {
                selectedUnitStandards[formId] = true;
              }

              // Set Summative data
              existingUnitStandardQuantities[sumId] = quantitySUM;
              existingUnitStandardRepresentatives[sumId] = repSUM;
              if (isCheckedSUM) {
                selectedUnitStandards[sumId] = true;
              }
            });

            // DEBUG: Print final stored values
            print('🔍 DEBUG - Stored values for $usId:');
            print(
                '   existingUnitStandardQuantities[$usId] = ${existingUnitStandardQuantities[usId]}');
            print(
                '   existingUnitStandardQuantities[$lgId] = ${existingUnitStandardQuantities[lgId]}');
            print(
                '   existingUnitStandardQuantities[$formId] = ${existingUnitStandardQuantities[formId]}');
            print(
                '   existingUnitStandardQuantities[$sumId] = ${existingUnitStandardQuantities[sumId]}');

            if (quantityUS > 0) {
              print('✅ Unit Standard $usId: Qty=$quantityUS, Rep=$repUS');
            }
            if (quantityLG > 0) {
              print('✅ Learner Guide $lgId: Qty=$quantityLG, Rep=$repLG');
            }
            if (quantityFORM > 0) {
              print('✅ Formative $formId: Qty=$quantityFORM, Rep=$repFORM');
            }
            if (quantitySUM > 0) {
              print('✅ Summative $sumId: Qty=$quantitySUM, Rep=$repSUM');
            }
          }

          print('🎯 Checkbox loading from server completed successfully!');
        } else {
          print('❌ Server returned error: ${data['error']}');
        }
      } else {
        print('❌ Server request failed with status: ${response.statusCode}');
        // Fallback to show no previous submissions
        _setNoSubmissionsFound();
      }
    } catch (e) {
      print('💥 Error loading checkbox status from server: $e');
      // Fallback to show no previous submissions
      _setNoSubmissionsFound();
    }
  }

  // Fallback method when server is unavailable
  void _setNoSubmissionsFound() {
    setState(() {
      for (var us in unitStandards) {
        String usId = us['unitstandard_id'].toString();
        String lgId = '${usId}_LG';
        String formId = '${usId}_FORM';
        String sumId = '${usId}_SUM';

        existingUnitStandardQuantities[usId] = 0;
        existingUnitStandardRepresentatives[usId] = '';
        selectedUnitStandards[usId] = false;

        existingUnitStandardQuantities[lgId] = 0;
        existingUnitStandardRepresentatives[lgId] = '';
        selectedUnitStandards[lgId] = false;

        existingUnitStandardQuantities[formId] = 0;
        existingUnitStandardRepresentatives[formId] = '';
        selectedUnitStandards[formId] = false;

        existingUnitStandardQuantities[sumId] = 0;
        existingUnitStandardRepresentatives[sumId] = '';
        selectedUnitStandards[sumId] = false;
      }
    });
    print('ℹ️ Set all checkboxes to unchecked (no server data available)');
  }

  // Function to check the connectivity state by pinging Google
  Future<void> _checkConnectivity() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));

      // If the request is successful (status code 200), the internet is available
      if (response.statusCode == 200) {
        print('Internet is available');
        _updateConnectionStatus(
            ConnectivityResult.wifi); // or .mobile depending on the network
      } else {
        print('No internet connection');
        _updateConnectionStatus(ConnectivityResult.none);
      }
    } catch (e) {
      print('Error checking connectivity: $e');
      _updateConnectionStatus(
          ConnectivityResult.none); // If there is an error, assume no internet
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    bool isOnline = result != ConnectivityResult.none;

    if (isOnline) {
      print('Internet available - syncing data...');
      fetchDataOnline(); // Fetch data when online
    } else {
      print('No internet connection.');
      // Optionally, you can call a method to handle offline data
      fetchDataOffline();
    }
  }

  // Fetch data online
  Future<void> fetchDataOnline() async {
    try {
      final response = await http.get(Uri.parse(AppConfig.buildUrl(
          'getFacilitatordetails.php?classID=${widget.classID}')));

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        setState(() {
          learners = data.map((learner) {
            signatureControllers.add(SignatureController());
            return {
              'ClassName': learner['className'] ?? '',
              'qualification_name': learner['qualification_name'] ?? '',
              'FacilitatorFullName': learner['FacilitatorFullName'] ?? '',
            };
          }).toList();

          if (learners.isNotEmpty) {
            // Use the first learner's details for the practitioner and class info
            practitionerFullName = learners[0]['FacilitatorFullName'] ?? '';
            practitionerID = data[0]['IDNumber'] ?? '';
            className = learners[0]['ClassName'] ?? '';
            qualification_name = learners[0]['qualification_name'] ?? '';
          }
        });
      } else {
        throw Exception('Failed to load learners from API');
      }
    } catch (e) {
      print('Error fetching online data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data from API: $e')),
      );
    }
  }

  // Fetch data offline
  Future<void> fetchDataOffline() async {
    try {
      final offlineData =
          await DatabaseHelper().getLearnerDetailsByClassID(widget.classID);
      print(
          'Offline Data: $offlineData'); // Log the returned data for debugging

      if (offlineData.isNotEmpty) {
        setState(() {
          learners = offlineData.map((learner) {
            signatureControllers.add(SignatureController());
            return {
              'ClassName': learner['ClassName'] ?? 'Unknown',
              'qualification_name': learner['qualification_name'] ?? 'Unknown',
              'FacilitatorFullName':
                  learner['FacilitatorFullName'] ?? 'Unknown',
            };
          }).toList();

          if (learners.isNotEmpty) {
            practitionerFullName = learners[0]['FacilitatorFullName'] ?? '';
            className = learners[0]['ClassName'] ?? '';
            qualification_name = learners[0]['qualification_name'] ?? '';
          }
        });
      } else {
        print('No offline data available for classID: ${widget.classID}');
        throw 'No data available offline';
      }
    } catch (e) {
      print('Error fetching offline data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading offline data: $e')),
      );
    }
  }

  Widget buildPractitionerDetailsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          children: [
            buildCard('Full Name', practitionerFullName),
            buildCard('Class Name', className),
            buildCard('Date Created', DateTime.now().toString().split(' ')[0]),
          ],
        ),
      ),
    );
  }

  Widget buildCard(String label, String value) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(value, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildRegularMaterialPreviousSubmission(String materialType) {
    int existingQuantity = existingRegularMaterialQuantities[materialType] ?? 0;
    String existingRepresentative =
        existingRegularMaterialRepresentatives[materialType] ?? '';

    if (existingQuantity > 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Colors.blue.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Previous Submissions Found',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Current total: $existingQuantity units',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (existingRepresentative.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    color: Colors.blue.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Last by: $existingRepresentative',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle,
                    color: Colors.green.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Adding $quantity more units. New total will be: ${existingQuantity + quantity}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'You can issue $materialType multiple times. Each submission adds to the total.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(
              Icons.new_releases,
              color: Colors.grey.shade600,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No previous submissions found for $materialType. This will be the first submission.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPreviousSubmissionsSummary() {
    int totalPreviouslySubmitted = existingUnitStandardQuantities.values
        .fold(0, (sum, quantity) => sum + quantity);
    int countPreviouslySubmitted = existingUnitStandardQuantities.values
        .where((quantity) => quantity > 0)
        .length;

    if (totalPreviouslySubmitted == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.grey.shade600,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'No previous submissions found for this class',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                color: Colors.blue.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Previous Submissions Summary',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$countPreviouslySubmitted unit standards already submitted',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total: $totalPreviouslySubmitted units',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitStandardsSelection() {
    if (unitStandards.isEmpty) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.orange.shade700,
                size: 48,
              ),
              const SizedBox(height: 10),
              Text(
                'No Unit Standards Found',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'No unit standards are available for this qualification. Please ensure the qualification has associated unit standards in the system.',
                style: TextStyle(
                  color: Colors.orange.shade600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select Unit Standards (${unitStandards.length} available)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Tick the unit standards you want to submit and specify quantities:',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            // Previous submissions summary
            _buildPreviousSubmissionsSummary(),
            const SizedBox(height: 15),
            SizedBox(
              height: 300, // Fixed height for scrollable list
              child: ListView.builder(
                itemCount: unitStandards.length,
                itemBuilder: (context, index) {
                  final us = unitStandards[index];
                  final usId = us['unitstandard_id'].toString();
                  final usName =
                      us['unit_standard_name'] ?? 'Unknown Unit Standard';

                  // Check existing quantities for unit standard and its sub-options
                  final existingUS = existingUnitStandardQuantities[usId] ?? 0;
                  final existingLG =
                      existingUnitStandardQuantities['${usId}_LG'] ?? 0;
                  final existingFORM =
                      existingUnitStandardQuantities['${usId}_FORM'] ?? 0;
                  final existingSUM =
                      existingUnitStandardQuantities['${usId}_SUM'] ?? 0;

                  // DEBUG: Print UI values
                  print('🔍 UI DEBUG - Unit Standard $usId:');
                  print(
                      '   existingUnitStandardQuantities[$usId] = ${existingUnitStandardQuantities[usId]}');
                  print('   existingUS = $existingUS');
                  print(
                      '   existingUnitStandardQuantities[${usId}_LG] = ${existingUnitStandardQuantities['${usId}_LG']}');
                  print('   existingLG = $existingLG');
                  print(
                      '   existingUnitStandardQuantities[${usId}_FORM] = ${existingUnitStandardQuantities['${usId}_FORM']}');
                  print('   existingFORM = $existingFORM');
                  print(
                      '   existingUnitStandardQuantities[${usId}_SUM] = ${existingUnitStandardQuantities['${usId}_SUM']}');
                  print('   existingSUM = $existingSUM');

                  final isSelectedUS = selectedUnitStandards[usId] ?? false;
                  final isSelectedLG =
                      selectedUnitStandards['${usId}_LG'] ?? false;
                  final isSelectedFORM =
                      selectedUnitStandards['${usId}_FORM'] ?? false;
                  final isSelectedSUM =
                      selectedUnitStandards['${usId}_SUM'] ?? false;

                  final currentQuantityUS = unitStandardQuantities[usId] ?? 1;
                  final currentQuantityLG =
                      unitStandardQuantities['${usId}_LG'] ?? 1;
                  final currentQuantityFORM =
                      unitStandardQuantities['${usId}_FORM'] ?? 1;
                  final currentQuantitySUM =
                      unitStandardQuantities['${usId}_SUM'] ?? 1;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Unit Standard Section
                          _buildUnitStandardItem(
                            usId: usId,
                            usName: usName,
                            itemType: 'Unit Standard',
                            existing: existingUS,
                            isSelected: isSelectedUS,
                            currentQuantity: currentQuantityUS,
                            representativeName:
                                existingUnitStandardRepresentatives[usId] ?? '',
                          ),

                          const SizedBox(height: 8),

                          // Learner Guide Section
                          Container(
                            margin: const EdgeInsets.only(left: 20),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: _buildUnitStandardItem(
                              usId: '${usId}_LG',
                              usName: '$usId - Learner Guide',
                              itemType: 'Learner Guide',
                              existing: existingLG,
                              isSelected: isSelectedLG,
                              currentQuantity: currentQuantityLG,
                              representativeName:
                                  existingUnitStandardRepresentatives[
                                          '${usId}_LG'] ??
                                      '',
                              isSubOption: true,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Formative Section
                          Container(
                            margin: const EdgeInsets.only(left: 20),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: _buildUnitStandardItem(
                              usId: '${usId}_FORM',
                              usName: '$usId - Formative',
                              itemType: 'Formative',
                              existing: existingFORM,
                              isSelected: isSelectedFORM,
                              currentQuantity: currentQuantityFORM,
                              representativeName:
                                  existingUnitStandardRepresentatives[
                                          '${usId}_FORM'] ??
                                      '',
                              isSubOption: true,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Summative Section
                          Container(
                            margin: const EdgeInsets.only(left: 20),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: _buildUnitStandardItem(
                              usId: '${usId}_SUM',
                              usName: '$usId - Summative',
                              itemType: 'Summative',
                              existing: existingSUM,
                              isSelected: isSelectedSUM,
                              currentQuantity: currentQuantitySUM,
                              representativeName:
                                  existingUnitStandardRepresentatives[
                                          '${usId}_SUM'] ??
                                      '',
                              isSubOption: true,
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
      ),
    );
  }

  Widget _buildUnitStandardItem({
    required String usId,
    required String usName,
    required String itemType,
    required int existing,
    required bool isSelected,
    required int currentQuantity,
    required String representativeName,
    bool isSubOption = false,
  }) {
    // Determine if checkbox should be checked (either manually selected or has existing submissions)
    bool isChecked = isSelected || existing > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with checkbox and name
        Row(
          children: [
            Checkbox(
              value: isChecked,
              onChanged: (bool? value) {
                setState(() {
                  // If unchecking and there are existing submissions, keep it checked
                  if (value == false && existing > 0) {
                    // Show a message that items with previous submissions cannot be unchecked
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Cannot uncheck items with previous submissions'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
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
                      color: isSubOption
                          ? (itemType == 'Learner Guide'
                              ? Colors.purple.shade700
                              : itemType == 'Formative'
                                  ? Colors.orange.shade700
                                  : Colors.teal.shade700)
                          : Colors.green.shade700,
                    ),
                  ),
                  Text(
                    itemType,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSubOption
                          ? (itemType == 'Learner Guide'
                              ? Colors.purple.shade600
                              : itemType == 'Formative'
                                  ? Colors.orange.shade600
                                  : Colors.teal.shade600)
                          : Colors.green.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Previous submission info (if any)
        if (existing > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: Colors.blue.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Previously submitted: $existing units',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (representativeName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: Colors.blue.shade600,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'By: $representativeName',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],

        // Quantity selection (ONLY show if manually selected by user)
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
                child: TextFormField(
                  initialValue: currentQuantity.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      unitStandardQuantities[usId] = int.tryParse(value) ?? 0;
                    });
                  },
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

  Widget _buildClassDetailsCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Description',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedDescription,
                    onChanged: (String? newValue) {
                      if (newValue == null) return;
                      setState(() {
                        selectedDescription = newValue;
                        // Reset learning material type when description changes
                        if (newValue != 'Learning Material') {
                          selectedLearningMaterialType = 'Select';
                        }
                      });
                    },
                    items: [
                      'Select',
                      'ToolKit',
                      'Learning Material',
                      'Consumables',
                      'PPE'
                    ].map((String value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            // Show previous submission info for regular materials (not Learning Material)
            if (selectedDescription != 'Select' &&
                selectedDescription != 'Learning Material') ...[
              const SizedBox(height: 10),
              _buildRegularMaterialPreviousSubmission(selectedDescription),
            ],
            // Show Learning Material sub-options when Learning Material is selected
            if (selectedDescription == 'Learning Material') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Learning Material Type',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedLearningMaterialType,
                      onChanged: (String? newValue) {
                        if (newValue == null) return;
                        setState(() {
                          selectedLearningMaterialType = newValue;
                        });
                      },
                      items: [
                        'Select',
                        'Unit Standards',
                        'Stationary (Files, Pens, Exam Pad)'
                      ].map((String value) {
                        return DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              // Show previous submission info for Learning Material sub-types (except Unit Standards)
              if (selectedLearningMaterialType != 'Select' &&
                  selectedLearningMaterialType != 'Unit Standards') ...[
                const SizedBox(height: 10),
                _buildRegularMaterialPreviousSubmission(
                    selectedLearningMaterialType),
              ],
              // Show Unit Standards selection when Unit Standards is selected
              if (selectedLearningMaterialType == 'Unit Standards') ...[
                const SizedBox(height: 10),
                _buildUnitStandardsSelection(),
              ],
            ],
            // Hide quantity dropdown when Unit Standards is selected (each unit standard has its own quantity)
            if (!(selectedDescription == 'Learning Material' &&
                selectedLearningMaterialType == 'Unit Standards')) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Quantity',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: quantity.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          quantity = int.tryParse(value) ?? 0;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Qualification',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    qualification_name,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Check which form to submit
  Future<void> checkAndSaveMaterialForm() async {
    bool isOnline = await checkInternetConnection();

    if (isOnline) {
      // If online, submit the form to the server
      await submitForm();
    } else {
      // If offline, save the form locally
      await saveMaterialFormOffline();
    }
  }

  // Function to check internet connection
  Future<bool> checkInternetConnection() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));
      if (response.statusCode == 200) {
        // Internet is available
        return true;
      } else {
        // Server is reachable, but the status code is not 200
        return false;
      }
    } catch (e) {
      // If an error occurs during the HTTP request, assume no connection
      print('Error checking internet connection: $e');
      return false;
    }
  }

  Future<void> submitForm() async {
    // Validate required fields
    if (facilitatorSignature == null ||
        representativeSignature == null ||
        selectedDescription == 'Select' ||
        representativeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please capture both facilitator and representative signatures and fill all required fields.",
          ),
        ),
      );
      return;
    }

    // Ensure we have a facilitator name and qualification name
    if (practitionerFullName.isEmpty ||
        practitionerFullName == 'Loading...' ||
        practitionerFullName == 'Unknown Facilitator') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Facilitator name is missing. Please wait for data to load or check your connection."),
        ),
      );
      return;
    }

    if (qualification_name.isEmpty) {
      // Try to use 'qualification' as fallback
      if (qualification.isNotEmpty) {
        qualification_name = qualification;
      } else {
        qualification_name = 'Unknown Qualification';
      }
    }

    // Additional validation for Learning Material
    if (selectedDescription == 'Learning Material' &&
        selectedLearningMaterialType == 'Select') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a Learning Material type."),
        ),
      );
      return;
    }

    // Additional validation for Unit Standards
    if (selectedDescription == 'Learning Material' &&
        selectedLearningMaterialType == 'Unit Standards') {
      bool hasSelectedUnitStandards =
          selectedUnitStandards.values.any((selected) => selected);
      if (!hasSelectedUnitStandards) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select at least one unit standard."),
          ),
        );
        return;
      }
    }

    // Validate quantity
    if (quantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid quantity.")),
      );
      return;
    }

    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("No internet connection. Please try again later.")),
      );
      return;
    }

    try {
      // Handle Unit Standards submission (multiple submissions)
      if (selectedDescription == 'Learning Material' &&
          selectedLearningMaterialType == 'Unit Standards') {
        bool allSuccessful = true;
        List<String> failedSubmissions = [];

        for (var us in unitStandards) {
          String usId = us['unitstandard_id'].toString();
          String usName = us['unit_standard_name'] ?? 'Unknown Unit Standard';

          // Handle Unit Standard submission
          bool isSelectedUS = selectedUnitStandards[usId] ?? false;
          int existingUS = existingUnitStandardQuantities[usId] ?? 0;
          // Submit if manually selected OR if it has existing submissions (auto-checked)
          if (isSelectedUS || existingUS > 0) {
            int quantity = unitStandardQuantities[usId] ?? 1;

            print('🔄 [SUBMISSION] Starting Unit Standard submission:');
            print('   - ID: $usId');
            print('   - Name: $usName');
            print('   - Quantity: $quantity');
            print('   - ClassID: ${widget.classID}');
            print('   - Facilitator: $practitionerFullName');
            print('   - Representative: $representativeName');
            print('   - Qualification: $qualification_name');

            // Create form data for this unit standard
            final formData = {
              'classID': widget.classID,
              'facilitatorFullName': practitionerFullName,
              'representativeFullName': representativeName,
              'description': 'Learning Material', // Main category
              'subDescription': usName, // Specific unit standard name
              'quantity': quantity,
              'qualificationName': qualification_name,
              'facilitatorSignature': base64Encode(facilitatorSignature!),
              'representativeSignature': base64Encode(representativeSignature!),
            };

            print('📤 [SUBMISSION] Sending data: ${json.encode(formData)}');

            try {
              // Send HTTP request for this unit standard
              final response = await http
                  .post(
                    Uri.parse(AppConfig.buildUrl('acknoledge.php')),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode(formData),
                  )
                  .timeout(const Duration(seconds: 30));

              print('📥 [SUBMISSION] Response Status: ${response.statusCode}');
              print('📥 [SUBMISSION] Response Body: ${response.body}');

              final responseBody = json.decode(response.body);
              if (!responseBody['success']) {
                allSuccessful = false;
                failedSubmissions.add(usName);
                print(
                    '❌ [SUBMISSION] FAILED for $usName: ${responseBody['message']}');
              } else {
                print('✅ [SUBMISSION] SUCCESS for $usName');
              }
            } catch (e) {
              allSuccessful = false;
              failedSubmissions.add(usName);
              print('💥 [SUBMISSION] EXCEPTION for $usName: $e');
            }
          }

          // Handle Learner Guide submission
          String lgId = '${usId}_LG';
          bool isSelectedLG = selectedUnitStandards[lgId] ?? false;
          int existingLG = existingUnitStandardQuantities[lgId] ?? 0;
          // Submit if manually selected OR if it has existing submissions (auto-checked)
          if (isSelectedLG || existingLG > 0) {
            int quantityLG = unitStandardQuantities[lgId] ?? 1;
            String lgName = '$usId - Learner Guide';

            print('🔄 [SUBMISSION] Starting Learner Guide submission:');
            print('   - ID: $lgId');
            print('   - Name: $lgName');
            print('   - Quantity: $quantityLG');
            print('   - ClassID: ${widget.classID}');
            print('   - Facilitator: $practitionerFullName');
            print('   - Representative: $representativeName');
            print('   - Qualification: $qualification_name');

            // Create form data for this learner guide
            final formDataLG = {
              'classID': widget.classID,
              'facilitatorFullName': practitionerFullName,
              'representativeFullName': representativeName,
              'description': 'Learning Material', // Main category
              'subDescription': lgName, // Specific learner guide name
              'quantity': quantityLG,
              'qualificationName': qualification_name,
              'facilitatorSignature': base64Encode(facilitatorSignature!),
              'representativeSignature': base64Encode(representativeSignature!),
            };

            print(
                '📤 [SUBMISSION] Sending LG data: ${json.encode(formDataLG)}');

            try {
              // Send HTTP request for this learner guide
              final response = await http
                  .post(
                    Uri.parse(AppConfig.buildUrl('acknoledge.php')),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode(formDataLG),
                  )
                  .timeout(const Duration(seconds: 30));

              print(
                  '📥 [SUBMISSION] LG Response Status: ${response.statusCode}');
              print('📥 [SUBMISSION] LG Response Body: ${response.body}');

              final responseBody = json.decode(response.body);
              if (!responseBody['success']) {
                allSuccessful = false;
                failedSubmissions.add(lgName);
                print(
                    '❌ [SUBMISSION] FAILED for $lgName: ${responseBody['message']}');
              } else {
                print('✅ [SUBMISSION] SUCCESS for $lgName');
              }
            } catch (e) {
              allSuccessful = false;
              failedSubmissions.add(lgName);
              print('💥 [SUBMISSION] EXCEPTION for $lgName: $e');
            }
          }

          // Handle Formative submission
          String formId = '${usId}_FORM';
          bool isSelectedFORM = selectedUnitStandards[formId] ?? false;
          int existingFORM = existingUnitStandardQuantities[formId] ?? 0;
          // Submit if manually selected OR if it has existing submissions (auto-checked)
          if (isSelectedFORM || existingFORM > 0) {
            int quantityFORM = unitStandardQuantities[formId] ?? 1;
            String formName = '$usId - Formative';

            print('🔄 [SUBMISSION] Starting Formative submission:');
            print('   - ID: $formId');
            print('   - Name: $formName');
            print('   - Quantity: $quantityFORM');
            print('   - ClassID: ${widget.classID}');
            print('   - Facilitator: $practitionerFullName');
            print('   - Representative: $representativeName');
            print('   - Qualification: $qualification_name');

            // Create form data for this formative
            final formDataFORM = {
              'classID': widget.classID,
              'facilitatorFullName': practitionerFullName,
              'representativeFullName': representativeName,
              'description': 'Learning Material', // Main category
              'subDescription': formName, // Specific formative name
              'quantity': quantityFORM,
              'qualificationName': qualification_name,
              'facilitatorSignature': base64Encode(facilitatorSignature!),
              'representativeSignature': base64Encode(representativeSignature!),
            };

            print(
                '📤 [SUBMISSION] Sending FORM data: ${json.encode(formDataFORM)}');

            try {
              // Send HTTP request for this formative
              final response = await http
                  .post(
                    Uri.parse(AppConfig.buildUrl('acknoledge.php')),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode(formDataFORM),
                  )
                  .timeout(const Duration(seconds: 30));

              print(
                  '📥 [SUBMISSION] FORM Response Status: ${response.statusCode}');
              print('📥 [SUBMISSION] FORM Response Body: ${response.body}');

              final responseBody = json.decode(response.body);
              if (!responseBody['success']) {
                allSuccessful = false;
                failedSubmissions.add(formName);
                print(
                    '❌ [SUBMISSION] FAILED for $formName: ${responseBody['message']}');
              } else {
                print('✅ [SUBMISSION] SUCCESS for $formName');
              }
            } catch (e) {
              allSuccessful = false;
              failedSubmissions.add(formName);
              print('💥 [SUBMISSION] EXCEPTION for $formName: $e');
            }
          }

          // Handle Summative submission
          String sumId = '${usId}_SUM';
          bool isSelectedSUM = selectedUnitStandards[sumId] ?? false;
          int existingSUM = existingUnitStandardQuantities[sumId] ?? 0;
          // Submit if manually selected OR if it has existing submissions (auto-checked)
          if (isSelectedSUM || existingSUM > 0) {
            int quantitySUM = unitStandardQuantities[sumId] ?? 1;
            String sumName = '$usId - Summative';

            print('🔄 [SUBMISSION] Starting Summative submission:');
            print('   - ID: $sumId');
            print('   - Name: $sumName');
            print('   - Quantity: $quantitySUM');
            print('   - ClassID: ${widget.classID}');
            print('   - Facilitator: $practitionerFullName');
            print('   - Representative: $representativeName');
            print('   - Qualification: $qualification_name');

            // Create form data for this summative
            final formDataSUM = {
              'classID': widget.classID,
              'facilitatorFullName': practitionerFullName,
              'representativeFullName': representativeName,
              'description': 'Learning Material', // Main category
              'subDescription': sumName, // Specific summative name
              'quantity': quantitySUM,
              'qualificationName': qualification_name,
              'facilitatorSignature': base64Encode(facilitatorSignature!),
              'representativeSignature': base64Encode(representativeSignature!),
            };

            print(
                '📤 [SUBMISSION] Sending SUM data: ${json.encode(formDataSUM)}');

            try {
              // Send HTTP request for this summative
              final response = await http
                  .post(
                    Uri.parse(AppConfig.buildUrl('acknoledge.php')),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode(formDataSUM),
                  )
                  .timeout(const Duration(seconds: 30));

              print(
                  '📥 [SUBMISSION] SUM Response Status: ${response.statusCode}');
              print('📥 [SUBMISSION] SUM Response Body: ${response.body}');

              final responseBody = json.decode(response.body);
              if (!responseBody['success']) {
                allSuccessful = false;
                failedSubmissions.add(sumName);
                print(
                    '❌ [SUBMISSION] FAILED for $sumName: ${responseBody['message']}');
              } else {
                print('✅ [SUBMISSION] SUCCESS for $sumName');
              }
            } catch (e) {
              allSuccessful = false;
              failedSubmissions.add(sumName);
              print('💥 [SUBMISSION] EXCEPTION for $sumName: $e');
            }
          }
        }

        print('📊 [SUBMISSION] Final Results:');
        print('   - All Successful: $allSuccessful');
        print('   - Failed Count: ${failedSubmissions.length}');
        print('   - Failed Items: $failedSubmissions');

        if (allSuccessful) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('All unit standards submitted successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Some submissions failed: ${failedSubmissions.join(', ')}')),
          );
        }

        // Reset form fields
        setState(() {
          facilitatorSignature = null;
          representativeSignature = null;
          selectedDescription = 'Select';
          selectedLearningMaterialType = 'Select';
          representativeName = '';
          quantity = 0;
          // Reset unit standards selections
          for (String usId in selectedUnitStandards.keys) {
            selectedUnitStandards[usId] = false;
            unitStandardQuantities[usId] = 0;
          }
        });

        // Refresh the page to update existing quantities
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MaterialForm(classID: widget.classID),
          ),
        );
        return;
      }

      // Handle regular single item submission
      // Determine the final description and sub-description
      String finalDescription = selectedDescription;
      String? finalSubDescription;

      if (selectedDescription == 'Learning Material' &&
          selectedLearningMaterialType != 'Select') {
        finalSubDescription = selectedLearningMaterialType;
      }

      // Log form data for debugging
      final formData = {
        'classID': widget.classID,
        'facilitatorFullName': practitionerFullName,
        'representativeFullName': representativeName,
        'description': finalDescription,
        'subDescription': finalSubDescription,
        'quantity': quantity,
        'qualificationName': qualification_name,
        'facilitatorSignature': base64Encode(facilitatorSignature!),
        'representativeSignature': base64Encode(representativeSignature!),
      };
      print('Form Data: $formData');
      print('Facilitator Signature Length: ${facilitatorSignature!.length}');
      print(
          'Representative Signature Length: ${representativeSignature!.length}');

      // Send HTTP request
      final response = await http
          .post(
            Uri.parse(AppConfig.buildUrl('acknoledge.php')),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(formData),
          )
          .timeout(const Duration(seconds: 30));

      // Log response details
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      // Parse response
      try {
        final responseBody = json.decode(response.body);
        print('Decoded Response: $responseBody');

        if (responseBody['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Form submitted successfully!')),
          );

          // Reset form fields
          setState(() {
            facilitatorSignature = null;
            representativeSignature = null;
            selectedDescription = 'Select';
            selectedLearningMaterialType = 'Select';
            representativeName = '';
            quantity = 0;
          });

          // Navigate to the same page
          print('Navigating to MaterialForm with classID: ${widget.classID}');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MaterialForm(classID: widget.classID),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Failed to submit form: ${responseBody['message']}')),
          );

          // Navigate to the same page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MaterialForm(classID: widget.classID),
            ),
          );
        }
      } catch (e) {
        print('JSON Decode Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid server response: $e')),
        );
      }
    } catch (e, stackTrace) {
      print('Error: $e');
      print('StackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  // Save form offline (simplified version)
  Future<void> saveMaterialFormOffline() async {
    // Implementation for offline saving would go here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offline saving not implemented yet')),
    );
  }

  Widget buildFacilitatorSignatureTable() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_ind, color: Colors.blue.shade700),
                const SizedBox(width: 10),
                Text(
                  'Facilitator & Representative Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(thickness: 1.5),
            ),

            // Facilitator Section
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Facilitator Name',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        practitionerFullName.isEmpty
                            ? 'Loading...'
                            : practitionerFullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 1,
                  child: _buildSignatureBox(
                    label: 'Facilitator Sign',
                    signature: facilitatorSignature,
                    onTap: () => showSignatureDialog(context, (signature) {
                      setState(() => facilitatorSignature = signature);
                    }),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // Representative Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Representative Details',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        onChanged: (value) {
                          setState(() {
                            representativeName = value;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Enter Representative Name',
                          hintText: 'Full Name',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon:
                              const Icon(Icons.person_outline, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 22.0),
                    child: _buildSignatureBox(
                      label: 'Rep. Sign',
                      signature: representativeSignature,
                      onTap: () => showSignatureDialog(context, (signature) {
                        setState(() => representativeSignature = signature);
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureBox({
    required String label,
    Uint8List? signature,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.blue.shade200),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: signature == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit, color: Colors.blue.shade400, size: 18),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  signature,
                  fit: BoxFit.contain,
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  void showSignatureDialog(
      BuildContext context, Function(Uint8List?) onSignatureCaptured) {
    final SignatureController controller = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Capture Signature'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.grey.shade200,
                  child: Signature(
                    controller: controller,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    controller.clear();
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final signatureBytes = await controller.toPngBytes();
                if (signatureBytes != null) {
                  onSignatureCaptured(signatureBytes);
                }
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Form'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            buildPractitionerDetailsCard(),
            const SizedBox(height: 16),
            _buildClassDetailsCard(),
            const SizedBox(height: 16),
            buildFacilitatorSignatureTable(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: checkAndSaveMaterialForm,
              child: const Text('Submit Form'),
            ),
          ],
        ),
      ),
    );
  }
}
