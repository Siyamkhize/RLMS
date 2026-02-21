import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'config.dart';
import 'ppe_sizes_page.dart';

class LearnerMaterialSelectionPage extends StatefulWidget {
  final Map<String, dynamic> learner;
  final String classID;

  const LearnerMaterialSelectionPage({
    super.key,
    required this.learner,
    required this.classID,
  });

  @override
  State<LearnerMaterialSelectionPage> createState() =>
      _LearnerMaterialSelectionPageState();
}

class _LearnerMaterialSelectionPageState
    extends State<LearnerMaterialSelectionPage> {
  String selectedMaterialType = 'Select';
  List<Map<String, dynamic>> unitStandards = [];

  // Track selections for each unit standard's sub-categories
  // Key format: "unitStandardId_subcategory" (e.g., "12345_formative")
  Map<String, bool> selections = {};

  // Track quantities for each material
  Map<String, int> quantities = {};

  // Track received materials
  List<Map<String, dynamic>> receivedMaterials = [];
  Map<String, int> materialSummary = {
    'ToolKit': 0,
    'Consumables': 0,
    'PPE': 0,
    'Learning Material': 0,
  };

  bool isLoading = false;
  bool fingerprintVerified = false;

  @override
  void initState() {
    super.initState();
    _loadReceivedMaterials();
    _fetchUnitStandards();
  }

  Future<void> _loadReceivedMaterials() async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl(
            'get_learner_received_materials.php?learnerID=${widget.learner['IDNumber']}')),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            receivedMaterials =
                List<Map<String, dynamic>>.from(data['materials'] ?? []);

            // Update summary
            if (data['summary'] != null) {
              materialSummary['ToolKit'] = data['summary']['ToolKit'] ?? 0;
              materialSummary['Consumables'] =
                  data['summary']['Consumables'] ?? 0;
              materialSummary['PPE'] = data['summary']['PPE'] ?? 0;
              materialSummary['Learning Material'] =
                  data['summary']['Learning Material'] ?? 0;
            }

            // Pre-select materials that were already received
            selections['ToolKit'] = materialSummary['ToolKit']! > 0;
            selections['Consumables'] = materialSummary['Consumables']! > 0;
            selections['PPE'] = materialSummary['PPE']! > 0;
            selections['Learning Material'] =
                materialSummary['Learning Material']! > 0;

            // Set current quantities
            quantities['ToolKit'] = materialSummary['ToolKit']!;
            quantities['Consumables'] = materialSummary['Consumables']!;
            quantities['PPE'] = materialSummary['PPE']!;
            quantities['Learning Material'] =
                materialSummary['Learning Material']!;

            // Pre-select unit standards that were already received
            if (data['unit_standards'] != null) {
              Map<String, dynamic> unitStandardsReceived =
                  data['unit_standards'];
              unitStandardsReceived.forEach((key, value) {
                // key format: "14336_SUM - Unit Standard"
                // We need to match it with our selection keys like "14336_summative"

                // Extract unit standard ID and type from the key
                if (key.contains('_')) {
                  String usId = key.split('_')[0]; // Get "14336"
                  String type = key
                      .split('_')[1]
                      .split(' ')[0]; // Get "SUM", "FORM", "LG"

                  // Map to our selection key format
                  String selectionKey = '';
                  if (type == 'SUM') {
                    selectionKey = '${usId}_summative';
                  } else if (type == 'FORM') {
                    selectionKey = '${usId}_formative';
                  } else if (type == 'LG') {
                    selectionKey = '${usId}_learner_guide';
                  }

                  if (selectionKey.isNotEmpty) {
                    selections[selectionKey] = true;
                    quantities[selectionKey] = value['quantity'] ?? 0;
                  }
                }
              });
            }
          });
        }
      }
    } catch (e) {
      print('Error loading received materials: $e');
    }
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
      print('Error fetching unit standards: $e');
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
            'get_learner_material_status.php?classID=${widget.classID}&learnerID=${widget.learner['IDNumber']}')),
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
          });
        }
      }
    } catch (e) {
      print('Error loading existing submissions: $e');
    }
  }

  Future<void> _verifyFingerprintAndUpdate() async {
    // Step 1: Verify fingerprint first
    setState(() => isLoading = true);

    try {
      // TODO: Implement actual fingerprint verification
      // For now, simulate verification
      await Future.delayed(const Duration(seconds: 1));

      // Show fingerprint dialog
      bool? verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Row(
            children: [
              Icon(Icons.fingerprint, color: Colors.blue, size: 32),
              SizedBox(width: 12),
              Text('Fingerprint Verification'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Please scan your fingerprint...'),
            ],
          ),
        ),
      );

      // Simulate verification result
      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pop(); // Close dialog

      // For testing, assume verified = true
      // In production, check actual fingerprint result
      verified = true;

      if (verified != true) {
        throw Exception('Fingerprint verification failed');
      }

      setState(() => fingerprintVerified = true);

      // Step 2: Update materials after successful verification
      await _submitMaterials();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => isLoading = false);
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
            content: Text('Please select at least one item to update')),
      );
      return;
    }

    try {
      // Debug: Print learner object to verify fields
      debugPrint(
          '[MATERIAL-SAVE] Learner object: ${widget.learner.toString()}');
      debugPrint('[MATERIAL-SAVE] LearnerID: ${widget.learner['LearnerID']}');
      debugPrint('[MATERIAL-SAVE] IDNumber: ${widget.learner['IDNumber']}');

      // Prepare submission data with quantities
      Map<String, dynamic> submissionData = {
        'classID': widget.classID,
        'learnerID':
            widget.learner['LearnerID'], // Send internal LearnerID (e.g., 70)
        'IDNumber':
            widget.learner['IDNumber'], // Also send IDNumber for reference
        'learnerName': widget.learner['FullName'],
        'materialType': selectedMaterialType,
        'selections': selections,
        'quantities': quantities,
        'issuedBy': 'Facilitator', // TODO: Get from logged in user
        'timestamp': DateTime.now().toIso8601String(),
      };

      debugPrint(
          '[MATERIAL-SAVE] Submission data: ${json.encode(submissionData)}');

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
                content: Text('Materials updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );

            // Reload materials to show updated status
            await _loadReceivedMaterials();
          }
        } else {
          throw Exception(result['error'] ?? 'Update failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating materials: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Issue Materials - ${widget.learner['FullName']}'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                // If PPE is selected, navigate to PPE sizes page
                if (newValue == 'PPE') {
                  _navigateToPPESizesPage();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToPPESizesPage() async {
    // Navigate to PPE sizes page
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PPESizesPage(
          learnerID: int.parse(widget.learner['IDNumber'].toString()),
          learnerName: widget.learner['FullName']?.toString(),
        ),
      ),
    );

    // If PPE was issued successfully, go back
    if (result == true) {
      Navigator.pop(context, true);
    } else {
      // Reset selection if user cancelled
      setState(() {
        selectedMaterialType = 'Select';
      });
    }
  }

  Widget _buildUnitStandardsList() {
    // Show simple materials (ToolKit, Consumables, PPE) for non-Learning Material types
    if (selectedMaterialType != 'Learning Material') {
      return _buildSimpleMaterialsList();
    }

    // Show unit standards for Learning Material type
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

  Widget _buildSimpleMaterialsList() {
    List<String> materials = [];

    if (selectedMaterialType == 'Toolkit') {
      materials = ['ToolKit'];
    } else if (selectedMaterialType == 'Consumables') {
      materials = ['Consumables'];
    } else if (selectedMaterialType == 'PPE') {
      materials = ['PPE'];
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Materials',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...materials.map((material) => _buildMaterialTile(material)),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialTile(String materialType) {
    final currentQty = materialSummary[materialType] ?? 0;
    final alreadyReceived = currentQty > 0;

    // Find the received material details
    final receivedMaterial = receivedMaterials.firstWhere(
      (m) => m['description'] == materialType,
      orElse: () => {},
    );

    // Initialize quantity if not set
    if (!quantities.containsKey(materialType)) {
      quantities[materialType] = currentQty;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: alreadyReceived ? Colors.green.shade50 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: selections[materialType] ?? false,
                  onChanged: (bool? value) {
                    setState(() {
                      selections[materialType] = value ?? false;
                      if (!value!) {
                        quantities[materialType] = 0;
                      } else if (quantities[materialType] == 0) {
                        quantities[materialType] = 1;
                      }
                    });
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        materialType,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (alreadyReceived) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Already received: ${receivedMaterial['date_received'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          'Issued by: ${receivedMaterial['issued_by'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          'Current quantity: $currentQty',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        Text(
                          'Not yet received',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  alreadyReceived ? 'Update Quantity:' : 'Add Quantity:',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: quantities[materialType] ?? 0,
                  items: List.generate(21, (i) => i)
                      .map((i) => DropdownMenuItem(
                            value: i,
                            child: Text('$i'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      quantities[materialType] = value!;
                      selections[materialType] = value > 0;
                    });
                  },
                ),
              ],
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
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : _verifyFingerprintAndUpdate,
        icon: const Icon(Icons.fingerprint, color: Colors.white),
        label: const Text(
          'Verify Fingerprint & Update',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.blue,
        ),
      ),
    );
  }
}
