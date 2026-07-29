import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class FacilitatorMaterialIssuePage extends StatefulWidget {
  final String logisticsId;
  final String logisticsName;
  final String siteId;
  final String siteName;
  final String classId;
  final String className;
  final String facilitatorId;
  final String facilitatorName;

  const FacilitatorMaterialIssuePage({
    super.key,
    required this.logisticsId,
    required this.logisticsName,
    required this.siteId,
    required this.siteName,
    required this.classId,
    required this.className,
    required this.facilitatorId,
    required this.facilitatorName,
  });

  @override
  _FacilitatorMaterialIssuePageState createState() =>
      _FacilitatorMaterialIssuePageState();
}

class _FacilitatorMaterialIssuePageState
    extends State<FacilitatorMaterialIssuePage> {
  List<Map<String, dynamic>> learners = [];
  List<Map<String, dynamic>> availableMaterials = [];
  List<Map<String, dynamic>> selectedMaterials = [];
  Map<String, List<Map<String, dynamic>>> learnerMaterials = {};

  bool isLoadingLearners = true;
  bool isLoadingMaterials = true;
  bool isSaving = false;
  String errorMessage = '';
  DateTime selectedDate = DateTime.now();
  String? selectedUnitStandard;
  String selectedIssueType = 'Learning Materials';
  String? selectedLearnerId;
  String? selectedLearnerName;

  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<String> issueTypes = [
    'Learning Materials',
    'PPE (Personal Protective Equipment)',
    'Consumables',
    'Tools & Equipment',
    'Safety Materials',
    'Assessment Materials'
  ];

  final List<Map<String, String>> unitStandards = [
    {'id': '13958', 'name': 'Pothole Repair and Road Maintenance'},
    {'id': '14555', 'name': 'Road Construction and Safety'},
    {'id': '15001', 'name': 'Construction Site Safety'},
    {'id': '15002', 'name': 'Equipment Operation'},
    {'id': '15003', 'name': 'Quality Control'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLearners();
    _loadAvailableMaterials();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadLearners() async {
    try {
      setState(() {
        isLoadingLearners = true;
        errorMessage = '';
      });

      final response = await http.get(
        Uri.parse(AppConfig.buildUrl(
            'get_logistics_learners.php?classID=${widget.classId}&siteID=${widget.siteId}&account_id=${widget.logisticsId}')),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            learners = List<Map<String, dynamic>>.from(data['learners'] ?? []);
            isLoadingLearners = false;
          });
        } else {
          setState(() {
            errorMessage = data['error'] ?? 'Failed to load learners';
            isLoadingLearners = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Server error: ${response.statusCode}';
          isLoadingLearners = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: $e';
        isLoadingLearners = false;
      });
    }
  }

  Future<void> _loadAvailableMaterials() async {
    try {
      setState(() {
        isLoadingMaterials = true;
      });

      final response = await http.get(
        Uri.parse(AppConfig.buildUrl('get_material_inventory.php')),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            availableMaterials =
                List<Map<String, dynamic>>.from(data['materials'] ?? []);
            isLoadingMaterials = false;
          });
        } else {
          setState(() {
            errorMessage = data['error'] ?? 'Failed to load materials';
            isLoadingMaterials = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Server error: ${response.statusCode}';
          isLoadingMaterials = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: $e';
        isLoadingMaterials = false;
      });
    }
  }

  void _addMaterialToLearner(Map<String, dynamic> material) {
    if (selectedLearnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a learner first')),
      );
      return;
    }

    setState(() {
      if (!learnerMaterials.containsKey(selectedLearnerId)) {
        learnerMaterials[selectedLearnerId!] = [];
      }

      learnerMaterials[selectedLearnerId!]!.add({
        'material_id': material['inventory_id'],
        'material_name': material['material_name'],
        'material_code': material['material_code'],
        'available_stock': material['current_stock'],
        'quantity_issued': 1,
        'unit_of_measure': material['unit_of_measure'] ?? 'pieces',
      });
    });
  }

  void _removeMaterialFromLearner(String learnerId, int materialIndex) {
    setState(() {
      learnerMaterials[learnerId]?.removeAt(materialIndex);
      if (learnerMaterials[learnerId]?.isEmpty == true) {
        learnerMaterials.remove(learnerId);
      }
    });
  }

  void _updateMaterialQuantity(
      String learnerId, int materialIndex, int quantity) {
    setState(() {
      if (learnerMaterials[learnerId] != null &&
          materialIndex < learnerMaterials[learnerId]!.length) {
        learnerMaterials[learnerId]![materialIndex]['quantity_issued'] =
            quantity;
      }
    });
  }

  Future<void> _submitMaterialIssue() async {
    if (!_formKey.currentState!.validate() || learnerMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please assign materials to learners and fill all required fields')),
      );
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = '';
    });

    try {
      // Prepare data for each learner
      List<Map<String, dynamic>> issuanceRecords = [];

      learnerMaterials.forEach((learnerId, materials) {
        final learner = learners
                .any((l) => l['learnerID'].toString() == learnerId)
            ? learners.firstWhere((l) => l['learnerID'].toString() == learnerId)
            : null;

        if (learner == null) return;

        issuanceRecords.add({
          'classID': widget.classId,
          'siteID': widget.siteId,
          'learner_id': learnerId,
          'learner_name': learner['learnerName'],
          'facilitator_id': widget.facilitatorId,
          'facilitator_name': widget.facilitatorName,
          'issue_date': selectedDate.toIso8601String().split('T')[0],
          'issue_type': selectedIssueType,
          'unit_standard': selectedUnitStandard,
          'notes': _notesController.text,
          'issued_by': widget.logisticsName,
          'materials': materials,
        });
      });

      final response = await http.post(
        Uri.parse(AppConfig.buildUrl('save_facilitator_material_issue.php')),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'issuance_records': issuanceRecords,
          'batch_id': DateTime.now().millisecondsSinceEpoch.toString(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Materials issued successfully to ${learnerMaterials.length} learner(s)'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          setState(() {
            errorMessage = data['error'] ?? 'Failed to issue materials';
          });
        }
      } else {
        setState(() {
          errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Widget _buildLearnerSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue[800]),
                const SizedBox(width: 8),
                const Text(
                  'Select Learner',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedLearnerId,
              decoration: const InputDecoration(
                labelText: 'Choose Learner',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_search),
              ),
              items: learners.map((learner) {
                return DropdownMenuItem<String>(
                  value: learner['learnerID'].toString(),
                  child: Text(
                    '${learner['learnerName']} (ID: ${learner['learnerID']})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedLearnerId = value;
                  selectedLearnerName = learners.any(
                          (l) => l['learnerID'].toString() == value.toString())
                      ? learners.firstWhere((l) =>
                          l['learnerID'].toString() ==
                          value.toString())['learnerName']
                      : '';
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a learner';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory, color: Colors.green[800]),
                const SizedBox(width: 8),
                const Text(
                  'Available Materials',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isLoadingMaterials
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: availableMaterials.length,
                      itemBuilder: (context, index) {
                        final material = availableMaterials[index];
                        final stock = material['current_stock'] ?? 0;
                        final isOutOfStock = stock <= 0;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                isOutOfStock ? Colors.red : Colors.green,
                            child: const Icon(
                              Icons.inventory_2,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            material['material_name'] ?? 'Unknown Material',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isOutOfStock ? Colors.grey : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            'Code: ${material['material_code']} | Stock: $stock ${material['unit_of_measure']}',
                            style: TextStyle(
                              color:
                                  isOutOfStock ? Colors.red : Colors.grey[600],
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle),
                            color: isOutOfStock ? Colors.grey : Colors.blue,
                            onPressed: isOutOfStock
                                ? null
                                : () => _addMaterialToLearner(material),
                          ),
                          enabled: !isOutOfStock,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnerMaterialsList() {
    if (learnerMaterials.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.assignment_outlined,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No materials assigned yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a learner and add materials to get started',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: learnerMaterials.entries.map((entry) {
        final learnerId = entry.key;
        final materials = entry.value;
        final learner = learners
                .any((l) => l['learnerID'].toString() == learnerId)
            ? learners.firstWhere((l) => l['learnerID'].toString() == learnerId)
            : {'learnerName': 'Unknown'};

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange,
              child: Text(
                learner['learnerName'][0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              learner['learnerName'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${materials.length} material(s) assigned'),
            children: [
              ...materials.asMap().entries.map((materialEntry) {
                final materialIndex = materialEntry.key;
                final material = materialEntry.value;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              material['material_name'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Code: ${material['material_code']}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            const Text('Qty: '),
                            SizedBox(
                              width: 60,
                              child: TextFormField(
                                initialValue:
                                    material['quantity_issued'].toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                                onChanged: (value) {
                                  final quantity = int.tryParse(value) ?? 1;
                                  _updateMaterialQuantity(
                                      learnerId, materialIndex, quantity);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeMaterialFromLearner(
                            learnerId, materialIndex),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Materials to Learners'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadLearners();
              _loadAvailableMaterials();
            },
          ),
        ],
      ),
      body: isLoadingLearners
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // Header Information
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.blue[50],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[800]),
                            const SizedBox(width: 8),
                            const Text(
                              'Issue Details',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Site: ${widget.siteName}'),
                        Text('Class: ${widget.className}'),
                        Text('Facilitator: ${widget.facilitatorName}'),
                        Text('Total Learners: ${learners.length}'),
                      ],
                    ),
                  ),

                  // Error Message
                  if (errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.red[100],
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Issue Configuration
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.settings,
                                          color: Colors.purple[800]),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Issue Configuration',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Date Selection
                                  Row(
                                    children: [
                                      const Text('Issue Date: ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      TextButton.icon(
                                        icon: const Icon(Icons.calendar_today),
                                        label: Text(
                                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                        ),
                                        onPressed: () async {
                                          final date = await showDatePicker(
                                            context: context,
                                            initialDate: selectedDate,
                                            firstDate: DateTime.now().subtract(
                                                const Duration(days: 30)),
                                            lastDate: DateTime.now()
                                                .add(const Duration(days: 30)),
                                          );
                                          if (date != null) {
                                            setState(() {
                                              selectedDate = date;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Issue Type
                                  DropdownButtonFormField<String>(
                                    value: selectedIssueType,
                                    decoration: const InputDecoration(
                                      labelText: 'Issue Type',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.category),
                                    ),
                                    items: issueTypes.map((type) {
                                      return DropdownMenuItem<String>(
                                        value: type,
                                        child: Text(type),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedIssueType = value!;
                                      });
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  // Unit Standard
                                  DropdownButtonFormField<String>(
                                    value: selectedUnitStandard,
                                    decoration: const InputDecoration(
                                      labelText: 'Unit Standard (Optional)',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.school),
                                    ),
                                    items: unitStandards.map((us) {
                                      return DropdownMenuItem<String>(
                                        value: us['id'],
                                        child:
                                            Text('${us['id']} - ${us['name']}'),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedUnitStandard = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Learner Selector
                          _buildLearnerSelector(),

                          const SizedBox(height: 16),

                          // Material Selector
                          _buildMaterialSelector(),

                          const SizedBox(height: 16),

                          // Assigned Materials
                          Row(
                            children: [
                              Icon(Icons.assignment, color: Colors.orange[800]),
                              const SizedBox(width: 8),
                              const Text(
                                'Materials Assigned to Learners',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          _buildLearnerMaterialsList(),

                          const SizedBox(height: 16),

                          // Notes
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Notes (Optional)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.note),
                            ),
                            maxLines: 3,
                          ),

                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: isSaving ? null : _submitMaterialIssue,
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(
                                isSaving
                                    ? 'Issuing Materials...'
                                    : 'Issue Materials to ${learnerMaterials.length} Learner(s)',
                                style: const TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[800],
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
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
}
