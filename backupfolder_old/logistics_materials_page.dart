import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class LogisticsMaterialsPage extends StatefulWidget {
  final String logisticsId;
  final String logisticsName;

  const LogisticsMaterialsPage({
    super.key,
    required this.logisticsId,
    required this.logisticsName,
  });

  @override
  State<LogisticsMaterialsPage> createState() => _LogisticsMaterialsPageState();
}

class _LogisticsMaterialsPageState extends State<LogisticsMaterialsPage> {
  Map<String, List<Map<String, dynamic>>> learnersByMaterialType = {};
  bool isLoading = true;
  String errorMessage = '';
  String selectedMaterialType = 'Learning Material';
  final List<String> materialTypes = [
    'Learning Material',
    'PPE',
    'ToolKit',
    'Consumables',
  ];

  @override
  void initState() {
    super.initState();
    _fetchAllMaterialsData();
  }

  Future<void> _fetchAllMaterialsData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      for (String materialType in materialTypes) {
        final encodedType = Uri.encodeComponent(materialType);
        final url = AppConfig.buildUrl(
            'get_learners_by_material_type.php?materialType=$encodedType');

        debugPrint('[MATERIALS] Fetching data for: $materialType');
        debugPrint('[MATERIALS] URL: $url');

        final response = await http.get(Uri.parse(url));

        debugPrint('[MATERIALS] Response status: ${response.statusCode}');
        debugPrint('[MATERIALS] Response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            learnersByMaterialType[materialType] =
                List<Map<String, dynamic>>.from(data['learners'] ?? []);
            debugPrint(
                '[MATERIALS] ✓ Loaded ${learnersByMaterialType[materialType]!.length} learners for $materialType');
          } else {
            learnersByMaterialType[materialType] = [];
            debugPrint(
                '[MATERIALS] ✗ No learners for $materialType: ${data['message']}');
          }
        } else {
          learnersByMaterialType[materialType] = [];
          debugPrint(
              '[MATERIALS] ✗ HTTP error for $materialType: ${response.statusCode}');
        }
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading data: ';
        isLoading = false;
      });
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Learning Material':
        return Colors.blue[700]!;
      case 'PPE':
        return Colors.orange[700]!;
      case 'Consumable':
      case 'Consumables':
        return Colors.green[700]!;
      case 'ToolKit':
        return Colors.purple[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Learning Material':
        return Icons.book;
      case 'PPE':
        return Icons.security;
      case 'Consumable':
      case 'Consumables':
        return Icons.inventory;
      case 'ToolKit':
        return Icons.build;
      default:
        return Icons.category;
    }
  }

  Widget _buildLearnersList(String materialType) {
    final learners = learnersByMaterialType[materialType] ?? [];

    if (learners.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No learners received $materialType yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAllMaterialsData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: learners.length,
        itemBuilder: (context, index) {
          final learner = learners[index];
          final learnerName =
              '${learner['Name'] ?? ''} ${learner['Surname'] ?? ''}'.trim();
          final learnerId =
              learner['IDNumber'] ?? learner['LearnerID'] ?? 'N/A';
          final issuedDate = learner['issued_date'] ?? 'N/A';
          final materials = learner['materials'] as List<String>?;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: _getCategoryColor(materialType),
                child: Text(
                  learnerName.isNotEmpty
                      ? learnerName.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                learnerName.isNotEmpty ? learnerName : 'Unknown Learner',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('ID: $learnerId | Issued: $issuedDate',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                ],
              ),
              trailing:
                  Icon(Icons.check_circle, color: Colors.green[600], size: 28),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materials Issued to Learners'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green[50],
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.green[800]),
                    const SizedBox(width: 8),
                    Text(
                      'Issued to Learners',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _fetchAllMaterialsData,
                      color: Colors.green[800],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: materialTypes.length,
                    itemBuilder: (context, index) {
                      final type = materialTypes[index];
                      final isSelected = selectedMaterialType == type;
                      final count = learnersByMaterialType[type]?.length ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: count > 0
                              ? CircleAvatar(
                                  backgroundColor: _getCategoryColor(type),
                                  child: Text(
                                    count.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getCategoryIcon(type), size: 16),
                              const SizedBox(width: 4),
                              Text(type),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              selectedMaterialType = type;
                            });
                          },
                          selectedColor: Colors.green[200],
                          checkmarkColor: Colors.green[800],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              errorMessage,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchAllMaterialsData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _buildLearnersList(selectedMaterialType),
          ),
        ],
      ),
    );
  }
}
