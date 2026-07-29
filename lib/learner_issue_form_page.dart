import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'database_helper.dart';
import 'config.dart';

class LearnerIssueFormPage extends StatefulWidget {
  final String classID;

  const LearnerIssueFormPage({super.key, required this.classID});

  @override
  _LearnerIssueFormPageState createState() => _LearnerIssueFormPageState();
}

class _LearnerIssueFormPageState extends State<LearnerIssueFormPage> {
  Uint8List? learnerSignature;
  Uint8List? representativeSignature;
  String learnerFullName = '';
  String representativeName = '';
  String practitionerFullName = '';
  String practitionerID = '';
  String className = '';
  List learners = [];
  List<SignatureController> signatureControllers = [];
  String selectedDescription = 'Select';
  String selectedLearningMaterialType = 'Select';
  int quantity = 0;
  String qualification = '';
  String selectedLearnerID = 'Select';

  // Unit Standards related variables
  List<Map<String, dynamic>> unitStandards = [];
  Map<String, bool> selectedUnitStandards = {};
  Map<String, int> unitStandardQuantities = {};
  Map<String, int> existingUnitStandardQuantities = {};
  Map<String, String> existingUnitStandardRepresentatives = {};

  // Regular materials tracking
  Map<String, int> existingRegularMaterialQuantities = {};
  Map<String, String> existingRegularMaterialRepresentatives = {};

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
    // Fetch unit standards for this class
    _fetchUnitStandards();
    // Debug: Print database info
    _debugDatabaseInfo();
    // Load existing regular material submissions
    _loadExistingRegularMaterialQuantities();
  }

  // Load existing regular material quantities from SERVER (not local database)
  Future<void> _loadExistingRegularMaterialQuantities() async {
    try {
      print(
          '🌐 Loading learner material quantities from SERVER for classID: ${widget.classID}');

      // Query server for all material data (including regular materials) using learner checkbox status
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl(
            'get_learner_checkbox_status.php?classID=${widget.classID}')),
      );

      print('📡 Server Response Status: ${response.statusCode}');
      print('📡 Server Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true) {
          final Map<String, dynamic> regularMaterials =
              data['regularMaterials'] ?? {};

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
          pr.Project_pathway
        FROM class c
        LEFT JOIN sites s ON c.siteID = s.siteID
        LEFT JOIN project pr ON s.project_id = pr.project_id
        WHERE c.classID = ?
      ''';

      final projectResult = await db.rawQuery(projectQuery, [widget.classID]);
      print('Project query result: $projectResult');

      if (projectResult.isNotEmpty) {
        final projectPathway =
            projectResult.first['Project_pathway'] as String?;
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

                  if (unitStandardsList is List) {
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
                      for (var us in unitStandards) {
                        String usId = us['unitstandard_id'].toString();
                        // Initialize unit standard
                        selectedUnitStandards[usId] = false;
                        unitStandardQuantities[usId] = 0;
                        existingUnitStandardQuantities[usId] = 0;
                        existingUnitStandardRepresentatives[usId] = '';

                        // Initialize learner guide for this unit standard
                        String lgId = '${usId}_LG';
                        selectedUnitStandards[lgId] = false;
                        unitStandardQuantities[lgId] = 0;
                        existingUnitStandardQuantities[lgId] = 0;
                        existingUnitStandardRepresentatives[lgId] = '';

                        // Initialize formative for this unit standard
                        String formId = '${usId}_FORM';
                        selectedUnitStandards[formId] = false;
                        unitStandardQuantities[formId] = 0;
                        existingUnitStandardQuantities[formId] = 0;
                        existingUnitStandardRepresentatives[formId] = '';

                        // Initialize summative for this unit standard
                        String sumId = '${usId}_SUM';
                        selectedUnitStandards[sumId] = false;
                        unitStandardQuantities[sumId] = 0;
                        existingUnitStandardQuantities[sumId] = 0;
                        existingUnitStandardRepresentatives[sumId] = '';
                      }
                    });

                    // Load existing quantities from previous submissions
                    await _loadExistingUnitStandardQuantities();

                    print('Unit standards loaded successfully:');
                    for (var us in unitStandards) {
                      print(
                          '  - ID: ${us['unitstandard_id']}, Name: ${us['unit_standard_name']}');
                    }
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

  // Load existing unit standard quantities from SERVER (not local database)
  Future<void> _loadExistingUnitStandardQuantities() async {
    try {
      print(
          '🌐 Loading learner material status from SERVER for classID: ${widget.classID}');

      // Query server for learner checkbox status (same as learner guide approach)
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl(
            'get_learner_checkbox_status.php?classID=${widget.classID}')),
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

            setState(() {
              // Set Unit Standard data
              existingUnitStandardQuantities[usId] = quantityUS;
              existingUnitStandardRepresentatives[usId] = repUS;
              if (isCheckedUS || quantityUS > 0) {
                selectedUnitStandards[usId] = true;
              }

              // Set Learner Guide data
              existingUnitStandardQuantities[lgId] = quantityLG;
              existingUnitStandardRepresentatives[lgId] = repLG;
              if (isCheckedLG || quantityLG > 0) {
                selectedUnitStandards[lgId] = true;
              }

              // Set Formative data
              existingUnitStandardQuantities[formId] = quantityFORM;
              existingUnitStandardRepresentatives[formId] = repFORM;
              if (isCheckedFORM || quantityFORM > 0) {
                selectedUnitStandards[formId] = true;
              }

              // Set Summative data
              existingUnitStandardQuantities[sumId] = quantitySUM;
              existingUnitStandardRepresentatives[sumId] = repSUM;
              if (isCheckedSUM || quantitySUM > 0) {
                selectedUnitStandards[sumId] = true;
              }
            });

            if (quantityUS > 0) {
              print(
                  '✅ Unit Standard $usId: Qty=$quantityUS, Rep=$repUS, Selected=${selectedUnitStandards[usId]}');
            }
            if (quantityLG > 0) {
              print(
                  '✅ Learner Guide $lgId: Qty=$quantityLG, Rep=$repLG, Selected=${selectedUnitStandards[lgId]}');
            }
            if (quantityFORM > 0) {
              print(
                  '✅ Formative $formId: Qty=$quantityFORM, Rep=$repFORM, Selected=${selectedUnitStandards[formId]}');
            }
            if (quantitySUM > 0) {
              print(
                  '✅ Summative $sumId: Qty=$quantitySUM, Rep=$repSUM, Selected=${selectedUnitStandards[sumId]}');
            }
          }

          print(
              '🎯 Learner material status loading from server completed successfully!');
        } else {
          print('❌ Server returned error: ${data['error']}');
        }
      } else {
        print('❌ Server request failed with status: ${response.statusCode}');
        _setNoSubmissionsFound();
      }
    } catch (e) {
      print('💥 Error loading learner material status from server: $e');
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

      if (response.statusCode == 200) {
        print('Internet is available');
        _updateConnectionStatus(ConnectivityResult.wifi);
      } else {
        print('No internet connection');
        _updateConnectionStatus(ConnectivityResult.none);
      }
    } catch (e) {
      print('Error checking connectivity: $e');
      _updateConnectionStatus(ConnectivityResult.none);
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    bool isOnline = result != ConnectivityResult.none;

    if (isOnline) {
      print('Internet available - syncing data...');
      fetchDataOnline();
    } else {
      print('No internet connection.');
      fetchDataOffline();
    }
  }

  // Fetch data online
  Future<void> fetchDataOnline() async {
    try {
      print('[FETCH_ONLINE] Starting fetch for classID: ${widget.classID}');
      final url =
          AppConfig.buildUrl('get_learners.php?classID=${widget.classID}');
      print('[FETCH_ONLINE] URL: $url');

      final response = await http.get(Uri.parse(url));

      print('[FETCH_ONLINE] API Response Status: ${response.statusCode}');
      print('[FETCH_ONLINE] API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        // Check if response is an array or error object
        if (responseData is List) {
          final List<dynamic> data = responseData;
          print('[FETCH_ONLINE] Received ${data.length} learners from API');

          setState(() {
            learners = data.map((learner) {
              signatureControllers.add(SignatureController());
              return {
                'LearnerID': learner['LearnerID'] ?? '',
                'Name': learner['Name'] ?? '',
                'Surname': learner['Surname'] ?? '',
                'IDNumber': learner['IDNumber'] ?? '',
              };
            }).toList();

            if (learners.isNotEmpty) {
              print(
                  '[FETCH_ONLINE] Successfully loaded ${learners.length} learners');
            } else {
              print('[FETCH_ONLINE] ⚠️ API returned empty array');
            }
          });
        } else {
          print(
              '[FETCH_ONLINE] ❌ API returned non-array response: $responseData');
          throw Exception('API returned invalid response format');
        }
      } else {
        throw Exception(
            'Failed to load learners from API - Status: ${response.statusCode}');
      }
    } catch (e) {
      print('[FETCH_ONLINE] ❌ Error fetching online data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data from API: $e')),
      );
      // Fallback to offline
      print('[FETCH_ONLINE] Falling back to offline data...');
      fetchDataOffline();
    }
  }

  // Fetch data offline
  Future<void> fetchDataOffline() async {
    try {
      final offlineData =
          await DatabaseHelper().getLearnerDetailsByClassID(widget.classID);
      print('Offline Data: $offlineData');

      if (offlineData.isNotEmpty) {
        setState(() {
          learners = offlineData.map((learner) {
            signatureControllers.add(SignatureController());
            return {
              'LearnerID': learner['LearnerID'] ?? '',
              'Name': learner['Name'] ?? 'Unknown',
              'Surname': learner['Surname'] ?? '',
              'IDNumber': learner['IDNumber'] ?? '',
            };
          }).toList();

          if (learners.isNotEmpty) {
            print(
                '[FETCH_OFFLINE] Successfully loaded ${learners.length} learners from local database');
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

  Widget buildLearnerDetailsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Learner Selection',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 16),
            // Show message if no learners found
            if (learners.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.people_outline,
                        size: 60, color: Colors.orange.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'No learners found in this class',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ClassID: ${widget.classID}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        // Try to fetch learners again
                        await _checkConnectivity();
                        if (learners.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Still no learners found. Please sync data from the main menu.'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tip: Go to Dashboard → Sync to download learner data',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            // Show learner selection UI only if learners exist
            if (learners.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Full Name',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text(
                                learnerFullName.isEmpty
                                    ? 'Unknown Learner'
                                    : learnerFullName,
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Selection',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            DropdownButton<String>(
                              isExpanded: true,
                              value: selectedLearnerID,
                              onChanged: (String? newValue) {
                                if (newValue == null || newValue == 'Select') {
                                  return;
                                }
                                setState(() {
                                  selectedLearnerID = newValue;
                                  // Find the selected learner and update the name
                                  final selectedLearner = learners.any((learner) =>
                                          learner['LearnerID'].toString() ==
                                          newValue)
                                      ? learners.firstWhere((learner) =>
                                          learner['LearnerID'].toString() ==
                                          newValue)
                                      : null;
                                  if (selectedLearner != null) {
                                    learnerFullName =
                                        '${selectedLearner['Name']} ${selectedLearner['Surname']}';
                                    practitionerID =
                                        selectedLearner['IDNumber'] ?? '';
                                  }
                                });
                              },
                              items: [
                                const DropdownMenuItem(
                                    value: 'Select', child: Text('Select')),
                                ...learners.map((learner) {
                                  return DropdownMenuItem(
                                    value: learner['LearnerID'].toString(),
                                    child: Text(
                                        '${learner['Name']} ${learner['Surname']}'),
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Learner table header
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Table(
                  border: TableBorder.all(color: Colors.blue.shade300),
                  children: [
                    const TableRow(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Name',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('ID Number',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Class Name',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ], // Close if (learners.isNotEmpty)
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
                Icon(Icons.history, color: Colors.blue.shade700, size: 18),
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
            Text(
              'Current total: $existingQuantity units',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (existingRepresentative.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Last by: $existingRepresentative',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
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
            Icon(Icons.new_releases, color: Colors.grey.shade600, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No previous submissions found for $materialType. This will be the first issuance.',
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
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select Unit Standards (${unitStandards.length} available)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Tick the unit standards you want to issue to learner and specify quantities:',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
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
                      SnackBar(
                        content: Text(
                            'Cannot uncheck items with previous submissions ($existing units already issued)'),
                        duration: const Duration(seconds: 3),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return; // Don't change the checkbox state
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
                          : Colors.orange.shade700,
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
                          : Colors.orange.shade600,
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
                      'Previously issued: $existing units',
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
            if (selectedDescription != 'Select' &&
                selectedDescription != 'Learning Material') ...[
              const SizedBox(height: 10),
              _buildRegularMaterialPreviousSubmission(selectedDescription),
            ],
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
            if (!(selectedDescription == 'Learning Material' &&
                selectedLearningMaterialType == 'Unit Standards')) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Quantity',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: quantity,
                      onChanged: (int? newValue) {
                        if (newValue == null) return;
                        setState(() {
                          quantity = newValue;
                        });
                      },
                      items: List.generate(100, (index) => index + 1)
                          .map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(value.toString()),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            const Row(
              children: [
                Text('Qualification',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLearnerSignatureTable() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Learner and Representative Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Table(
              border: TableBorder.all(
                  color: Colors.grey,
                  width: 1,
                  borderRadius: BorderRadius.circular(12)),
              columnWidths: {
                0: const FixedColumnWidth(150),
                1: const FixedColumnWidth(150),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  children: [
                    _buildHeaderCell('Name'),
                    _buildHeaderCell('Signature'),
                  ],
                ),
                buildSignatureTableRow(learnerFullName, learnerSignature,
                    (signature) {
                  setState(() {
                    learnerSignature = signature;
                  });
                }),
                buildRepresentativeTableRow(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow buildSignatureTableRow(
      String name, Uint8List? signature, Function(Uint8List?) onCaptured) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: TableCell(
            child: Text(name,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TableCell(
            child: signature == null
                ? ElevatedButton(
                    onPressed: () => showSignatureDialog(context, onCaptured),
                    child: Text('$name Signature'),
                  )
                : Image.memory(
                    signature,
                    height: 50,
                    width: 100,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ],
    );
  }

  TableRow buildRepresentativeTableRow() {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: TableCell(
            child: TextField(
              onChanged: (value) {
                setState(() {
                  representativeName = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Representative Name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TableCell(
            child: representativeSignature == null
                ? ElevatedButton(
                    onPressed: () => showSignatureDialog(context, (signature) {
                      setState(() {
                        representativeSignature = signature;
                      });
                    }),
                    child: const Text('Representative Signature'),
                  )
                : Image.memory(
                    representativeSignature!,
                    height: 50,
                    width: 100,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ],
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

  // Check which form to submit
  Future<void> checkAndSaveMaterialForm() async {
    // Validate learner selection first
    if (selectedLearnerID == 'Select' || learnerFullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a learner first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show preview dialog before submission
    await _showSubmissionPreview();
  }

  // Show submission preview dialog with unit standards count
  Future<void> _showSubmissionPreview() async {
    // Count selected unit standards for preview
    int selectedUnitStandardsCount = 0;
    int totalQuantity = 0;
    List<String> selectedItems = [];

    if (selectedDescription == 'Learning Material' &&
        selectedLearningMaterialType == 'Unit Standards') {
      for (var us in unitStandards) {
        String usId = us['unitstandard_id'].toString();
        String usName = us['unit_standard_name'] ?? 'Unknown Unit Standard';

        // Check Unit Standard
        bool isSelectedUS = selectedUnitStandards[usId] ?? false;
        int existingUS = existingUnitStandardQuantities[usId] ?? 0;
        int quantityUS = unitStandardQuantities[usId] ?? 0;
        // ⚠️ VALIDATION: Only count if quantity > 0
        if ((isSelectedUS || existingUS > 0) && quantityUS > 0) {
          selectedUnitStandardsCount++;
          totalQuantity += quantityUS;
          selectedItems.add('Unit Standard $usId (Qty: $quantityUS)');
        }

        // Check Learner Guide
        String lgId = '${usId}_LG';
        bool isSelectedLG = selectedUnitStandards[lgId] ?? false;
        int existingLG = existingUnitStandardQuantities[lgId] ?? 0;
        int quantityLG = unitStandardQuantities[lgId] ?? 0;
        // ⚠️ VALIDATION: Only count if quantity > 0
        if ((isSelectedLG || existingLG > 0) && quantityLG > 0) {
          selectedUnitStandardsCount++;
          totalQuantity += quantityLG;
          selectedItems.add('Learner Guide $usId (Qty: $quantityLG)');
        }

        // Check Formative
        String formId = '${usId}_FORM';
        bool isSelectedFORM = selectedUnitStandards[formId] ?? false;
        int existingFORM = existingUnitStandardQuantities[formId] ?? 0;
        int quantityFORM = unitStandardQuantities[formId] ?? 0;
        // ⚠️ VALIDATION: Only count if quantity > 0
        if ((isSelectedFORM || existingFORM > 0) && quantityFORM > 0) {
          selectedUnitStandardsCount++;
          totalQuantity += quantityFORM;
          selectedItems.add('Formative $usId (Qty: $quantityFORM)');
        }

        // Check Summative
        String sumId = '${usId}_SUM';
        bool isSelectedSUM = selectedUnitStandards[sumId] ?? false;
        int existingSUM = existingUnitStandardQuantities[sumId] ?? 0;
        int quantitySUM = unitStandardQuantities[sumId] ?? 0;
        // ⚠️ VALIDATION: Only count if quantity > 0
        if ((isSelectedSUM || existingSUM > 0) && quantitySUM > 0) {
          selectedUnitStandardsCount++;
          totalQuantity += quantitySUM;
          selectedItems.add('Summative $usId (Qty: $quantitySUM)');
        }
      }
    }

    // Show preview dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.preview, color: Colors.orange),
            SizedBox(width: 8),
            Text('Submission Preview'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic details
              _buildPreviewRow('Class ID:', widget.classID),
              _buildPreviewRow('Learner:', learnerFullName),
              _buildPreviewRow('Learner ID:', selectedLearnerID),
              _buildPreviewRow('Representative:', representativeName),
              _buildPreviewRow('Description:', selectedDescription),

              if (selectedDescription == 'Learning Material' &&
                  selectedLearningMaterialType != 'Select')
                _buildPreviewRow(
                    'Material Type:', selectedLearningMaterialType),

              if (selectedDescription == 'Learning Material' &&
                  selectedLearningMaterialType == 'Unit Standards') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.checklist,
                              color: Colors.orange.shade700, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Unit Standards Summary',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selected Items: $selectedUnitStandardsCount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        'Total Quantity: $totalQuantity units',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Note: This includes Unit Standards, Learner Guides, Formative and Summative materials across ${unitStandards.length} unit standards.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (!(selectedDescription == 'Learning Material' &&
                  selectedLearningMaterialType == 'Unit Standards')) ...[
                _buildPreviewRow('Quantity:', quantity.toString()),
              ],

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please review the details above before submitting.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      bool isOnline = await checkInternetConnection();
      if (isOnline) {
        await submitForm();
      } else {
        await saveMaterialFormOffline();
      }
    }
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Function to check internet connection
  Future<bool> checkInternetConnection() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error checking internet connection: $e');
      return false;
    }
  }

  Future<void> submitForm() async {
    // Validate required fields
    if (learnerSignature == null ||
        representativeSignature == null ||
        selectedDescription == 'Select' ||
        representativeName.isEmpty ||
        selectedLearnerID == 'Select') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select a learner, capture both learner and representative signatures, and fill all required fields.",
          ),
        ),
      );
      return;
    }

    // Additional validation for Unit Standards
    if (selectedDescription == 'Learning Material' &&
        selectedLearningMaterialType == 'Unit Standards') {
      // Check if any unit standard is manually selected OR has existing submissions
      bool hasSelectedUnitStandards = false;

      // Check manually selected items
      bool hasManuallySelected =
          selectedUnitStandards.values.any((selected) => selected);

      // Check items with existing submissions (auto-selected)
      bool hasExistingSubmissions =
          existingUnitStandardQuantities.values.any((qty) => qty > 0);

      hasSelectedUnitStandards = hasManuallySelected || hasExistingSubmissions;

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
          int quantityUS = unitStandardQuantities[usId] ?? 0;
          // ⚠️ VALIDATION: Skip if quantity is 0
          if ((isSelectedUS || existingUS > 0) && quantityUS > 0) {
            print('🔄 [LEARNER SUBMISSION] Starting Unit Standard submission:');
            print('   - ID: $usId');
            print('   - Name: $usName');
            print('   - Quantity: $quantityUS');
            print('   - ClassID: ${widget.classID}');
            print('   - Learner: $learnerFullName');
            print('   - LearnerID: $selectedLearnerID');
            print('   - Representative: $representativeName');

            // Create form data for this unit standard
            final formData = {
              'classID': widget.classID,
              'learnerID': selectedLearnerID,
              'learnerFullName': learnerFullName,
              'representativeFullName': representativeName,
              'description': 'Learning Material', // Main category
              'subDescription': usName, // Specific unit standard name
              'quantity': quantityUS,
              'qualificationName': '',
              'learnerSignature': base64Encode(learnerSignature!),
              'representativeSignature': base64Encode(representativeSignature!),
            };

            print(
                '📤 [LEARNER SUBMISSION] Sending data: ${json.encode(formData)}');

            try {
              // Send HTTP request for this unit standard
              final response = await http
                  .post(
                    Uri.parse(AppConfig.buildUrl(
                        'save_logisticLeaner_aknowlagment.php')),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode(formData),
                  )
                  .timeout(const Duration(seconds: 30));

              print(
                  '📥 [LEARNER SUBMISSION] Response Status: ${response.statusCode}');
              print('📥 [LEARNER SUBMISSION] Response Body: ${response.body}');

              final responseBody = json.decode(response.body);
              if (!responseBody['success']) {
                allSuccessful = false;
                failedSubmissions.add(usName);
                print(
                    '❌ [LEARNER SUBMISSION] FAILED for $usName: ${responseBody['message']}');
              } else {
                print('✅ [LEARNER SUBMISSION] SUCCESS for $usName');
              }
            } catch (e) {
              allSuccessful = false;
              failedSubmissions.add(usName);
              print('💥 [LEARNER SUBMISSION] EXCEPTION for $usName: $e');
            }
          }

          // Handle Learner Guide submission
          String lgId = '${usId}_LG';
          bool isSelectedLG = selectedUnitStandards[lgId] ?? false;
          int existingLG = existingUnitStandardQuantities[lgId] ?? 0;
          int quantityLG = unitStandardQuantities[lgId] ?? 0;
          // ⚠️ VALIDATION: Skip if quantity is 0
          if ((isSelectedLG || existingLG > 0) && quantityLG > 0) {
            String lgName = '$usId - Learner Guide';

            final formDataLG = {
              'classID': widget.classID,
              'learnerID': selectedLearnerID,
              'learnerFullName': learnerFullName,
              'representativeFullName': representativeName,
              'description': 'Learning Material',
              'subDescription': lgName,
              'quantity': quantityLG,
              'learnerSignature': base64Encode(learnerSignature!),
              'representativeSignature': base64Encode(representativeSignature!),
            };

            try {
              final response = await http
                  .post(
                    Uri.parse(
                        AppConfig.buildUrl('save_learner_material_issue.php')),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode(formDataLG),
                  )
                  .timeout(const Duration(seconds: 30));

              final responseBody = json.decode(response.body);
              if (!responseBody['success']) {
                allSuccessful = false;
                failedSubmissions.add(lgName);
              }
            } catch (e) {
              allSuccessful = false;
              failedSubmissions.add(lgName);
            }
          }

          // Handle Formative submission
          String formId = '${usId}_FORM';
          bool isSelectedFORM = selectedUnitStandards[formId] ?? false;
          int existingFORM = existingUnitStandardQuantities[formId] ?? 0;
          int quantityFORM = unitStandardQuantities[formId] ?? 0;
          // ⚠️ VALIDATION: Skip if quantity is 0
          if ((isSelectedFORM || existingFORM > 0) && quantityFORM > 0) {
            String formName = '$usId - Formative';

            final formDataFORM = {
              'classID': widget.classID,
              'learnerID': selectedLearnerID,
              'learnerFullName': learnerFullName,
              'representativeFullName': representativeName,
              'description': 'Learning Material',
              'subDescription': formName,
              'quantity': quantityFORM,
              'learnerSignature': base64Encode(learnerSignature!),
              'representativeSignature': base64Encode(representativeSignature!),
            };

            try {
              final response = await http
                  .post(
                    Uri.parse(
                        AppConfig.buildUrl('save_learner_material_issue.php')),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode(formDataFORM),
                  )
                  .timeout(const Duration(seconds: 30));

              final responseBody = json.decode(response.body);
              if (!responseBody['success']) {
                allSuccessful = false;
                failedSubmissions.add(formName);
              }
            } catch (e) {
              allSuccessful = false;
              failedSubmissions.add(formName);
            }
          }

          // Handle Summative submission
          String sumId = '${usId}_SUM';
          bool isSelectedSUM = selectedUnitStandards[sumId] ?? false;
          int existingSUM = existingUnitStandardQuantities[sumId] ?? 0;
          int quantitySUM = unitStandardQuantities[sumId] ?? 0;
          // ⚠️ VALIDATION: Skip if quantity is 0
          if ((isSelectedSUM || existingSUM > 0) && quantitySUM > 0) {
            String sumName = '$usId - Summative';

            final formDataSUM = {
              'classID': widget.classID,
              'learnerID': selectedLearnerID,
              'learnerFullName': learnerFullName,
              'representativeFullName': representativeName,
              'description': 'Learning Material',
              'subDescription': sumName,
              'quantity': quantitySUM,
              'learnerSignature': base64Encode(learnerSignature!),
              'representativeSignature': base64Encode(representativeSignature!),
            };

            try {
              final response = await http
                  .post(
                    Uri.parse(
                        AppConfig.buildUrl('save_learner_material_issue.php')),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode(formDataSUM),
                  )
                  .timeout(const Duration(seconds: 30));

              final responseBody = json.decode(response.body);
              if (!responseBody['success']) {
                allSuccessful = false;
                failedSubmissions.add(sumName);
              }
            } catch (e) {
              allSuccessful = false;
              failedSubmissions.add(sumName);
            }
          }
        }

        if (allSuccessful) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('All unit standards issued to learner successfully!')),
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
          learnerSignature = null;
          representativeSignature = null;
          selectedDescription = 'Select';
          selectedLearningMaterialType = 'Select';
          representativeName = '';
          quantity = 0;
          selectedLearnerID = 'Select';
          learnerFullName = '';
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
            builder: (context) => LearnerIssueFormPage(classID: widget.classID),
          ),
        );
        return;
      }

      // Handle regular single item submission
      String finalDescription = selectedDescription;
      String? finalSubDescription;

      if (selectedDescription == 'Learning Material' &&
          selectedLearningMaterialType != 'Select') {
        finalSubDescription = selectedLearningMaterialType;
      }

      // Log form data for debugging
      final formData = {
        'classID': widget.classID,
        'learnerID': selectedLearnerID,
        'learnerFullName': learnerFullName,
        'representativeFullName': representativeName,
        'description': finalDescription,
        'subDescription': finalSubDescription ?? finalDescription,
        'quantity': quantity,
        'learnerSignature': base64Encode(learnerSignature!),
        'representativeSignature': base64Encode(representativeSignature!),
      };

      print('Form data: ${json.encode(formData)}');

      final response = await http
          .post(
            Uri.parse(AppConfig.buildUrl('save_learner_material_issue.php')),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(formData),
          )
          .timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Material issued to learner successfully!')),
          );

          // Reset form fields
          setState(() {
            learnerSignature = null;
            representativeSignature = null;
            selectedDescription = 'Select';
            selectedLearningMaterialType = 'Select';
            representativeName = '';
            quantity = 0;
            selectedLearnerID = 'Select';
            learnerFullName = '';
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to issue material: ${responseBody['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error submitting form: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting form: $e')),
      );
    }
  }

  Future<void> saveMaterialFormOffline() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Offline functionality not implemented yet')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Materials to Learner'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            buildLearnerDetailsCard(),
            const SizedBox(height: 16),
            _buildClassDetailsCard(),
            const SizedBox(height: 16),
            buildLearnerSignatureTable(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: checkAndSaveMaterialForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Issue Materials to Learner'),
            ),
          ],
        ),
      ),
    );
  }
}
