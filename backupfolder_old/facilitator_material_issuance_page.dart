import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class FacilitatorMaterialIssuancePage extends StatefulWidget {
  final String logisticsId;
  final String logisticsName;
  final String siteId;
  final String siteName;
  final String classId;
  final String className;
  final String facilitatorId;
  final String facilitatorName;

  const FacilitatorMaterialIssuancePage({
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
  _FacilitatorMaterialIssuancePageState createState() => _FacilitatorMaterialIssuancePageState();
}

class _FacilitatorMaterialIssuancePageState extends State<FacilitatorMaterialIssuancePage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  
  List<Map<String, dynamic>> availableMaterials = [];
  List<Map<String, dynamic>> filteredMaterials = [];
  List<Map<String, dynamic>> selectedMaterials = [];
  bool isLoadingMaterials = true;
  bool isSaving = false;
  String errorMessage = '';
  DateTime selectedDate = DateTime.now();
  String? selectedUnitStandard;
  String selectedCategory = 'All';
  String searchQuery = '';

  final List<Map<String, String>> unitStandards = [
    {'id': '13958', 'name': 'Pothole Repair and Road Maintenance'},
    {'id': '14555', 'name': 'Road Construction and Safety'},
    {'id': '15001', 'name': 'Construction Site Safety'},
    {'id': '15002', 'name': 'Equipment Operation'},
    {'id': '15003', 'name': 'Quality Control'},
  ];

  final List<String> categories = ['All', 'Learning Material', 'PPE', 'Consumable', 'Tools', 'Equipment'];

  @override
  void initState() {
    super.initState();
    _loadAvailableMaterials();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text;
      _filterMaterials();
    });
  }

  void _filterMaterials() {
    setState(() {
      filteredMaterials = availableMaterials.where((material) {
        final matchesCategory = selectedCategory == 'All' || 
                               (material['category']?.toString().toLowerCase() ?? '') == selectedCategory.toLowerCase();
        
        final matchesSearch = searchQuery.isEmpty ||
                             (material['material_name']?.toString().toLowerCase() ?? '').contains(searchQuery.toLowerCase()) ||
                             (material['material_code']?.toString().toLowerCase() ?? '').contains(searchQuery.toLowerCase()) ||
                             (material['description']?.toString().toLowerCase() ?? '').contains(searchQuery.toLowerCase());
        
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  Future<void> _loadAvailableMaterials() async {
    try {
      setState(() {
        isLoadingMaterials = true;
        errorMessage = '';
      });

      final response = await http.get(
        Uri.parse(AppConfig.buildUrl('get_material_inventory.php')),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            availableMaterials = List<Map<String, dynamic>>.from(data['materials'] ?? []);
            _filterMaterials();
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

  void _addMaterial(Map<String, dynamic> material) {
    setState(() {
      selectedMaterials.add({
        'material_id': material['inventory_id'],
        'material_name': material['material_name'],
        'material_code': material['material_code'],
        'available_stock': material['current_stock'],
        'quantity_requested': 1,
        'unit_of_measure': material['unit_of_measure'] ?? 'pieces',
        'category': material['category'] ?? 'Unknown',
      });
    });
  }

  void _removeMaterial(int index) {
    setState(() {
      selectedMaterials.removeAt(index);
    });
  }

  void _updateQuantity(int index, int quantity) {
    setState(() {
      selectedMaterials[index]['quantity_requested'] = quantity;
    });
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'learning material':
        return Colors.blue[700]!;
      case 'ppe':
        return Colors.orange[700]!;
      case 'consumable':
        return Colors.green[700]!;
      case 'tools':
        return Colors.purple[700]!;
      case 'equipment':
        return Colors.red[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'learning material':
        return Icons.book;
      case 'ppe':
        return Icons.security;
      case 'consumable':
        return Icons.build;
      case 'tools':
        return Icons.construction;
      case 'equipment':
        return Icons.precision_manufacturing;
      default:
        return Icons.inventory;
    }
  }

  Future<void> _submitIssuance() async {
    if (!_formKey.currentState!.validate() || selectedMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select materials and fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = '';
    });

    try {
      final issuanceData = {
        'classID': widget.classId,
        'siteID': widget.siteId,
        'facilitator_id': widget.facilitatorId,
        'facilitator_name': widget.facilitatorName,
        'recipient_name': widget.facilitatorName,
        'recipient_type': 'facilitator',
        'issue_date': selectedDate.toIso8601String().split('T')[0],
        'purpose': 'Facilitator Material Issuance',
        'notes': _notesController.text,
        'issued_by': widget.logisticsName,
        'received_by': widget.facilitatorName,
        'unit_standard': selectedUnitStandard,
        'materials': selectedMaterials,
        'class_name': widget.className,
        'site_name': widget.siteName,
      };

      final response = await http.post(
        Uri.parse(AppConfig.buildUrl('save_material_issuance.php')),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(issuanceData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Materials successfully issued to ${widget.facilitatorName}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.pop(context, true);
        } else {
          setState(() {
            errorMessage = data['error'] ?? 'Failed to save issuance';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Materials to Facilitator'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: isLoadingMaterials
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // Header Information Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue[800]),
                                const SizedBox(width: 8),
                                Text(
                                  'Issuance Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            _buildInfoRow(Icons.location_on, 'Site', widget.siteName),
                            _buildInfoRow(Icons.class_, 'Class', widget.className),
                            _buildInfoRow(Icons.person, 'Facilitator', widget.facilitatorName),
                            _buildInfoRow(Icons.person_outline, 'Issued By', widget.logisticsName),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Error Message
                  if (errorMessage.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red[800]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage,
                              style: TextStyle(color: Colors.red[800]),
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
                          // Date and Unit Standard Selection
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Issue Configuration',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Date Selection
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, color: Colors.grey[600]),
                                      const SizedBox(width: 8),
                                      const Text('Issue Date: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                      TextButton.icon(
                                        onPressed: () async {
                                          final date = await showDatePicker(
                                            context: context,
                                            initialDate: selectedDate,
                                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                            lastDate: DateTime.now().add(const Duration(days: 30)),
                                          );
                                          if (date != null) {
                                            setState(() {
                                              selectedDate = date;
                                            });
                                          }
                                        },
                                        icon: const Icon(Icons.edit_calendar),
                                        label: Text(
                                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Unit Standard Selection
                                  DropdownButtonFormField<String>(
                                    value: selectedUnitStandard,
                                    decoration: InputDecoration(
                                      labelText: 'Unit Standard (Optional)',
                                      prefixIcon: const Icon(Icons.school),
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('Select Unit Standard (Optional)'),
                                      ),
                                      ...unitStandards.map((us) {
                                        return DropdownMenuItem<String>(
                                          value: us['id'],
                                          child: Text('${us['id']} - ${us['name']}'),
                                        );
                                      }),
                                    ],
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

                          // Material Selection Section
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.inventory, color: Colors.blue[800]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Available Materials',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.refresh),
                                        onPressed: _loadAvailableMaterials,
                                        tooltip: 'Refresh Materials',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Search and Filter
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: TextField(
                                          controller: _searchController,
                                          decoration: InputDecoration(
                                            hintText: 'Search materials...',
                                            prefixIcon: const Icon(Icons.search),
                                            suffixIcon: searchQuery.isNotEmpty
                                                ? IconButton(
                                                    icon: const Icon(Icons.clear),
                                                    onPressed: () {
                                                      _searchController.clear();
                                                    },
                                                  )
                                                : null,
                                            border: const OutlineInputBorder(),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: selectedCategory,
                                          decoration: const InputDecoration(
                                            labelText: 'Category',
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          items: categories.map((category) {
                                            return DropdownMenuItem<String>(
                                              value: category,
                                              child: Text(category),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              selectedCategory = value!;
                                              _filterMaterials();
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Available Materials List
                                  Container(
                                    height: 300,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: filteredMaterials.isEmpty
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                                                const SizedBox(height: 8),
                                                Text(
                                                  searchQuery.isNotEmpty || selectedCategory != 'All'
                                                      ? 'No materials match your filters'
                                                      : 'No materials available',
                                                  style: TextStyle(color: Colors.grey[600]),
                                                ),
                                              ],
                                            ),
                                          )
                                        : ListView.builder(
                                            itemCount: filteredMaterials.length,
                                            itemBuilder: (context, index) {
                                              final material = filteredMaterials[index];
                                              final isSelected = selectedMaterials.any(
                                                (selected) => selected['material_id'] == material['inventory_id']
                                              );
                                              final stockQuantity = int.tryParse(material['current_stock']?.toString() ?? '0') ?? 0;
                                              final category = material['category']?.toString() ?? 'Unknown';
                                              
                                              return Card(
                                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                child: ListTile(
                                                  leading: CircleAvatar(
                                                    backgroundColor: _getCategoryColor(category),
                                                    child: Icon(
                                                      _getCategoryIcon(category),
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  ),
                                                  title: Text(
                                                    material['material_name'] ?? 'Unknown Material',
                                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                                  ),
                                                  subtitle: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('Code: ${material['material_code'] ?? 'N/A'}'),
                                                      Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: _getCategoryColor(category),
                                                              borderRadius: BorderRadius.circular(10),
                                                            ),
                                                            child: Text(
                                                              category,
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            'Stock: $stockQuantity ${material['unit_of_measure'] ?? 'pieces'}',
                                                            style: TextStyle(
                                                              color: stockQuantity > 0 ? Colors.green[700] : Colors.red[700],
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  trailing: isSelected
                                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                                      : IconButton(
                                                          icon: const Icon(Icons.add_circle_outline),
                                                          onPressed: stockQuantity > 0 ? () => _addMaterial(material) : null,
                                                          color: Colors.blue[800],
                                                        ),
                                                  enabled: !isSelected && stockQuantity > 0,
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Selected Materials Section
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.shopping_cart, color: Colors.green[800]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Selected Materials (${selectedMaterials.length})',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  if (selectedMaterials.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(32),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey[400]),
                                            const SizedBox(height: 8),
                                            Text(
                                              'No materials selected',
                                              style: TextStyle(color: Colors.grey[600]),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Add materials from the list above',
                                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    ...selectedMaterials.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final material = entry.value;
                                      final category = material['category']?.toString() ?? 'Unknown';
                                      
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        color: Colors.green[50],
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: _getCategoryColor(category),
                                                    radius: 16,
                                                    child: Icon(
                                                      _getCategoryIcon(category),
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          material['material_name'],
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        Text(
                                                          'Code: ${material['material_code']}',
                                                          style: TextStyle(
                                                            color: Colors.grey[600],
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                                    onPressed: () => _removeMaterial(index),
                                                    tooltip: 'Remove Material',
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Text(
                                                    'Available: ${material['available_stock']} ${material['unit_of_measure']}',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  const Text('Quantity: '),
                                                  SizedBox(
                                                    width: 80,
                                                    child: TextFormField(
                                                      initialValue: material['quantity_requested'].toString(),
                                                      keyboardType: TextInputType.number,
                                                      decoration: const InputDecoration(
                                                        border: OutlineInputBorder(),
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        isDense: true,
                                                      ),
                                                      validator: (value) {
                                                        if (value == null || value.isEmpty) {
                                                          return 'Required';
                                                        }
                                                        final quantity = int.tryParse(value);
                                                        if (quantity == null || quantity <= 0) {
                                                          return 'Invalid';
                                                        }
                                                        if (quantity > material['available_stock']) {
                                                          return 'Exceeds stock';
                                                        }
                                                        return null;
                                                      },
                                                      onChanged: (value) {
                                                        final quantity = int.tryParse(value) ?? 0;
                                                        _updateQuantity(index, quantity);
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(material['unit_of_measure']),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Notes Section
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.note_add, color: Colors.grey[700]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Additional Notes',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _notesController,
                                    decoration: const InputDecoration(
                                      labelText: 'Notes (Optional)',
                                      hintText: 'Add any additional notes about this material issuance...',
                                      border: OutlineInputBorder(),
                                      alignLabelWithHint: true,
                                    ),
                                    maxLines: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isSaving || selectedMaterials.isEmpty ? null : _submitIssuance,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[800],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              child: isSaving
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Processing...'),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.send),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Issue Materials to ${widget.facilitatorName}',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}