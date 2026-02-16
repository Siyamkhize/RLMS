import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class LogisticsMaterialsInventoryPage extends StatefulWidget {
  final String logisticsId;
  final String logisticsName;

  const LogisticsMaterialsInventoryPage({
    super.key,
    required this.logisticsId,
    required this.logisticsName,
  });

  @override
  State<LogisticsMaterialsInventoryPage> createState() =>
      _LogisticsMaterialsInventoryPageState();
}

class _LogisticsMaterialsInventoryPageState
    extends State<LogisticsMaterialsInventoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, List<Map<String, dynamic>>> learnersByMaterialType = {};
  bool isLoading = true;
  String errorMessage = '';

  final List<String> materialTypes = [
    'All',
    'Learning Material',
    'PPE',
    'ToolKit',
    'Consumables',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: materialTypes.length, vsync: this);
    _fetchAllMaterialsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllMaterialsData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Fetch learners for each material type
      for (String materialType in materialTypes) {
        if (materialType == 'All') {
          // For "All", we'll combine all learners
          continue;
        }

        // URL encode the material type
        final encodedType = Uri.encodeComponent(materialType);
        final url = AppConfig.buildUrl(
            'get_learners_by_material_type.php?materialType=$encodedType');

        debugPrint('[MATERIALS-INVENTORY] Fetching: $materialType');
        debugPrint('[MATERIALS-INVENTORY] URL: $url');

        final response = await http.get(Uri.parse(url));

        debugPrint(
            '[MATERIALS-INVENTORY] Response status: ${response.statusCode}');
        debugPrint('[MATERIALS-INVENTORY] Response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            learnersByMaterialType[materialType] =
                List<Map<String, dynamic>>.from(data['learners'] ?? []);
            debugPrint(
                '[MATERIALS-INVENTORY] ✅ $materialType: ${learnersByMaterialType[materialType]!.length} learners');
          } else {
            learnersByMaterialType[materialType] = [];
            debugPrint(
                '[MATERIALS-INVENTORY] ⚠️ $materialType: ${data['error'] ?? 'No learners'}');
          }
        } else {
          learnersByMaterialType[materialType] = [];
          debugPrint(
              '[MATERIALS-INVENTORY] ❌ $materialType: HTTP ${response.statusCode}');
        }
      }

      // Create "All" by combining all learners (unique by LearnerID)
      Map<String, Map<String, dynamic>> allLearnersMap = {};
      learnersByMaterialType.forEach((type, learners) {
        for (var learner in learners) {
          String learnerId = learner['LearnerID'].toString();
          if (!allLearnersMap.containsKey(learnerId)) {
            allLearnersMap[learnerId] = {
              ...learner,
              'materials': <String>[type],
            };
          } else {
            // Add material type to existing learner
            List<String> materials =
                List<String>.from(allLearnersMap[learnerId]!['materials']);
            if (!materials.contains(type)) {
              materials.add(type);
            }
            allLearnersMap[learnerId]!['materials'] = materials;
          }
        }
      });

      learnersByMaterialType['All'] = allLearnersMap.values.toList();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading data: $e';
        isLoading = false;
      });
    }
  }

  Color _getMaterialTypeColor(String materialType) {
    switch (materialType) {
      case 'Learning Material':
        return Colors.blue;
      case 'PPE':
        return Colors.orange;
      case 'ToolKit':
        return Colors.purple;
      case 'Consumables':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getMaterialTypeIcon(String materialType) {
    switch (materialType) {
      case 'Learning Material':
        return Icons.book;
      case 'PPE':
        return Icons.security;
      case 'ToolKit':
        return Icons.build;
      case 'Consumables':
        return Icons.inventory;
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
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No learners received $materialType yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
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
          final issuedDate =
              learner['issued_date'] ?? learner['timestamp'] ?? 'N/A';
          final materials = learner['materials'] as List<String>?;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: _getMaterialTypeColor(materialType),
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.badge, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'ID: $learnerId',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Issued: $issuedDate',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  if (materialType == 'All' && materials != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: materials.map((mat) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getMaterialTypeColor(mat).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getMaterialTypeColor(mat),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getMaterialTypeIcon(mat),
                                size: 12,
                                color: _getMaterialTypeColor(mat),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                mat,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _getMaterialTypeColor(mat),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
              trailing: Icon(
                Icons.check_circle,
                color: Colors.green[600],
                size: 28,
              ),
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
        title: const Text('Materials Inventory'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAllMaterialsData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: materialTypes.map((type) {
            final count = learnersByMaterialType[type]?.length ?? 0;
            return Tab(
              child: Row(
                children: [
                  Icon(_getMaterialTypeIcon(type), size: 18),
                  const SizedBox(width: 8),
                  Text(type),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getMaterialTypeColor(type),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
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
              : TabBarView(
                  controller: _tabController,
                  children: materialTypes
                      .map((type) => _buildLearnersList(type))
                      .toList(),
                ),
    );
  }
}
