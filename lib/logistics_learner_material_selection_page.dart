import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'config.dart';

class LogisticsLearnerMaterialSelectionPage extends StatefulWidget {
  final Map<String, dynamic> learner;
  final String classID;

  const LogisticsLearnerMaterialSelectionPage({
    super.key,
    required this.learner,
    required this.classID,
  });

  @override
  State<LogisticsLearnerMaterialSelectionPage> createState() =>
      _LogisticsLearnerMaterialSelectionPageState();
}

class _LogisticsLearnerMaterialSelectionPageState
    extends State<LogisticsLearnerMaterialSelectionPage> {
  String selectedMaterialType = 'Select';
  List<Map<String, dynamic>> unitStandards = [];

  // Track selections for each unit standard's sub-categories
  // Key format: "unitStandardId_subcategory" (e.g., "12345_formative")
  Map<String, bool> selections = {};

  // Track quantities for each material
  Map<String, int> quantities = {};

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUnitStandards();
  }

  Future<void> _fetchUnitStandards() async {
    try {
      setState(() => isLoading = true);

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
                              'qualification_id':
                                  us['qualification_id']?.toString() ?? '',
                              'level': us['level']?.toString() ?? '',
                              'credits': us['credits']?.toString() ?? '',
                              'description':
                                  us['description']?.toString() ?? '',
                            })
                        .toList();

                    // Initialize all selections to false
                    for (var us in unitStandards) {
                      String usId = us['unitstandard_id'].toString();
                      selections['${usId}_formative'] = false;
                      selections['${usId}_summative'] = false;
                      selections['${usId}_learner_guide'] = false;
                    }
                  });

                  // Load existing submissions for this learner
                  await _loadExistingSubmissions();
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LOGISTICS] Error fetching unit standards: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading unit standards: $e')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadExistingSubmissions() async {
    try {
      // Load from server what this specific learner has already received
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl(
            'get_logistics_learner_material_status.php?classID=${widget.classID}&learnerID=${widget.learner['IDNumber']}')),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['materials'] != null) {
          setState(() {
            Map<String, dynamic> materials = data['materials'];
            materials.forEach((key, value) {
              if (value == true || value == 1) {
                selections[key] = true;
              }
            });

            // Load quantities if available
            if (data['quantities'] != null) {
              Map<String, dynamic> qtys = data['quantities'];
              qtys.forEach((key, value) {
                quantities[key] =
                    value is int ? value : int.tryParse(value.toString()) ?? 0;
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[LOGISTICS] Error loading existing submissions: $e');
    }
  }

  Future<void> _submitMaterials() async {
    if (selectedMaterialType == 'Select') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a material type')),
      );
      return;
    }

    // Check if at least one item is selected
    bool hasSelection = selections.values.any((selected) => selected);
    if (!hasSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one item to issue')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Build quantities map - default to 1 for all selected items
      Map<String, int> quantities = {};
      selections.forEach((key, isSelected) {
        if (isSelected) {
          quantities[key] = 1; // Default quantity is 1
        }
      });

      // Prepare submission data
      Map<String, dynamic> submissionData = {
        'classID': widget.classID,
        'learnerID':
            widget.learner['LearnerID'], // Internal LearnerID (e.g., 70)
        'IDNumber': widget
            .learner['IDNumber'], // Actual ID Number (e.g., "9807010472081")
        'learnerName': widget.learner['FullName'],
        'materialType': selectedMaterialType,
        'selections': selections,
        'quantities': quantities, // Add quantities map
        'timestamp': DateTime.now().toIso8601String(),
        'issuedBy': 'Logistics', // Mark as issued by logistics
      };

      debugPrint(
          '[LOGISTICS-SAVE] Learner data: LearnerID=${widget.learner['LearnerID']}, IDNumber=${widget.learner['IDNumber']}');

      debugPrint(
          '[LOGISTICS] Submitting materials: ${json.encode(submissionData)}');

      final response = await http.post(
        Uri.parse(AppConfig.buildUrl('save_logistics_learner_materials.php')),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(submissionData),
      );

      debugPrint('[LOGISTICS] Response status: ${response.statusCode}');
      debugPrint('[LOGISTICS] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Materials issued successfully by Logistics!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            Navigator.pop(context, true); // Return true to indicate success
          }
        } else {
          throw Exception(result['error'] ?? 'Submission failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[LOGISTICS] Error submitting materials: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Issue Materials - ${widget.learner['FullName']}'),
        centerTitle: true,
        backgroundColor: Colors.orange, // Different color for logistics
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLogisticsBanner(),
                  const SizedBox(height: 12),
                  _buildLearnerInfoCard(),
                  const SizedBox(height: 20),
                  _buildMaterialTypeSelection(),
                  const SizedBox(height: 20),
                  if (selectedMaterialType != 'Select')
                    _buildUnitStandardsList(),
                  const SizedBox(height: 20),
                  if (selectedMaterialType != 'Select') _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildLogisticsBanner() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.local_shipping, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Logistics Material Issuance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnerInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 40, color: Colors.blue),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.learner['FullName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${widget.learner['IDNumber'] ?? 'N/A'}',
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
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialTypeSelection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Material Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedMaterialType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                'Select',
                'Learning Material',
                'PPE',
                'Toolkit',
                'Consumables'
              ].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedMaterialType = newValue ?? 'Select';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitStandardsList() {
    if (unitStandards.isEmpty) {
      return Card(
        color: Colors.orange.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No unit standards found for this class',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unit Standards (${unitStandards.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select what the learner has received:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: unitStandards.length,
              itemBuilder: (context, index) {
                final us = unitStandards[index];
                final usId = us['unitstandard_id'].toString();
                final usName = us['unit_standard_name'] ?? 'Unknown';

                // Check if any items are already issued for this unit standard
                final formativeKey = '${usId}_formative';
                final summativeKey = '${usId}_summative';
                final learnerGuideKey = '${usId}_learner_guide';

                final hasFormative = selections[formativeKey] == true;
                final hasSummative = selections[summativeKey] == true;
                final hasLearnerGuide = selections[learnerGuideKey] == true;

                final hasAnyIssued =
                    hasFormative || hasSummative || hasLearnerGuide;

                // Count how many items are issued
                int issuedCount = 0;
                if (hasFormative) issuedCount++;
                if (hasSummative) issuedCount++;
                if (hasLearnerGuide) issuedCount++;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color:
                      hasAnyIssued ? Colors.green.shade50 : Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Unit Standard: $usId',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    usName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasAnyIssued)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$issuedCount/3 issued',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildCheckboxRow(
                            usId, 'Formative', 'formative', hasFormative),
                        _buildCheckboxRow(
                            usId, 'Summative', 'summative', hasSummative),
                        _buildCheckboxRow(usId, 'Learner Guide',
                            'learner_guide', hasLearnerGuide),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxRow(
      String usId, String label, String key, bool alreadyIssued) {
    final selectionKey = '${usId}_$key';
    final isSelected = selections[selectionKey] ?? false;
    final quantity = quantities[selectionKey] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: alreadyIssued ? Colors.grey.shade200 : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: CheckboxListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: alreadyIssued ? Colors.grey.shade700 : Colors.black,
                  fontWeight:
                      alreadyIssued ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            if (alreadyIssued && quantity > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Qty: $quantity',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            selections[selectionKey] = value ?? false;
          });
        },
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _submitMaterials,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.orange,
        ),
        child: const Text(
          'Submit Materials (Logistics)',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }
}
