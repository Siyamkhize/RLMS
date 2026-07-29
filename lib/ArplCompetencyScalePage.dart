import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class ArplCompetencyScalePage extends StatefulWidget {
  final int learnerID;
  final String learnerName;
  final int ofoNumber;
  final String tradeName;

  const ArplCompetencyScalePage({
    super.key,
    required this.learnerID,
    required this.learnerName,
    required this.ofoNumber,
    required this.tradeName,
  });

  @override
  State<ArplCompetencyScalePage> createState() =>
      _ArplCompetencyScalePageState();
}

class _ArplCompetencyScalePageState extends State<ArplCompetencyScalePage>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  String? errorMessage;

  late List<Map<String, dynamic>> competencyScale = [];
  late List<Map<String, dynamic>> activities = [];
  late List<Map<String, dynamic>> appxbActivities = [];
  late Map<int, Map<String, dynamic>> activityRatings = {};
  late Map<int, int> appxbRatings = {}; // activity_id -> rating

  int totalActivities = 0;
  int ratedActivities = 0;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchCompetencyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchCompetencyData() async {
    try {
      final url =
          AppConfig.buildUrl('get_arpl_competency_data.php', queryParams: {
        'learnerID': widget.learnerID.toString(),
        'ofo_number': widget.ofoNumber.toString(),
      });

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          setState(() {
            competencyScale =
                List<Map<String, dynamic>>.from(data['competency_scale']);
            activities = List<Map<String, dynamic>>.from(data['activities']);
            appxbActivities = List<Map<String, dynamic>>.from(
                data['appxb_activities'] ?? data['activities']);
            totalActivities = data['total_activities'];
            ratedActivities = data['rated_activities'];

            // Convert activity ratings to a map by activity_id for easy lookup
            activityRatings = {};
            for (var rating in data['activity_ratings']) {
              activityRatings[rating['activity_id']] = rating;
            }

            // Initialize appxb ratings map
            appxbRatings = {};
            for (var rating in data['appxb_ratings'] ?? []) {
              appxbRatings[rating['activity_id']] = rating['rating_score'];
            }

            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'Failed to load competency data';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Server error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  void _saveRating(int activityId, int rating) async {
    try {
      final url = AppConfig.buildUrl('save_arpl_activity_rating.php');

      final response = await http.post(
        Uri.parse(url),
        body: {
          'learnerID': widget.learnerID.toString(),
          'activity_id': activityId.toString(),
          'rating_score': rating.toString(),
          'assessor_id': '0',
          'comments': '',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            appxbRatings[activityId] = rating;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Rating saved successfully'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${data['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ARPL Competency Scale'),
            Text(
              'OFO ${widget.ofoNumber} - ${widget.tradeName} • ${widget.learnerName}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Competency Scale'),
            Tab(text: 'Appx B'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Competency Scale
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildProgressCard(),
                          _buildCompetencyScaleReference(),
                          const Divider(height: 24),
                          _buildActivitiesTable(),
                        ],
                      ),
                    ),
                    // Tab 2: Appendix B Activities
                    SingleChildScrollView(
                      child: _buildAppxBActivities(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildProgressCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Assessment Progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ratedActivities == totalActivities
                        ? Colors.green
                        : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$ratedActivities/$totalActivities',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value:
                    totalActivities > 0 ? ratedActivities / totalActivities : 0,
                minHeight: 8,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ratedActivities == totalActivities
                      ? Colors.green
                      : Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${((ratedActivities / totalActivities) * 100).toStringAsFixed(1)}% Complete',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetencyScaleReference() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Competency Scale (Appendix B)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              columns: const [
                DataColumn(label: Text('Level')),
                DataColumn(label: Text('Proficiency')),
                DataColumn(label: Text('Description')),
              ],
              rows: competencyScale.map((scale) {
                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.hovered)) {
                        return Colors.grey.shade100;
                      }
                      return (scale['score'] as int) % 2 == 0
                          ? Colors.grey.shade50
                          : Colors.white;
                    },
                  ),
                  cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getLevelColor(scale['score']),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          scale['score'].toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Text(
                          scale['proficiency_level'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 250,
                        child: Text(
                          scale['description'],
                          softWrap: true,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesTable() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Competency Ratings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              columns: const [
                DataColumn(label: Text('No')),
                DataColumn(label: Text('Activity')),
                DataColumn(label: Text('Rating')),
                DataColumn(label: Text('Proficiency Level')),
                DataColumn(label: Text('Date')),
              ],
              rows: activities.map((activity) {
                final rating = activityRatings[activity['activity_id']];
                final hasRating = rating != null;

                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                      if (hasRating) {
                        return Colors.green.shade50;
                      }
                      return Colors.grey.shade50;
                    },
                  ),
                  cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          activity['activity_number'].toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: Text(
                          activity['activity_name'],
                          softWrap: true,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      hasRating
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getLevelColor(rating['rating_score']),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                rating['rating_score'].toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '-',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                    ),
                    DataCell(
                      hasRating
                          ? SizedBox(
                              width: 150,
                              child: Text(
                                rating['proficiency_level'] ?? 'N/A',
                                softWrap: true,
                                style: const TextStyle(fontSize: 12),
                              ),
                            )
                          : const Text('-', style: TextStyle(fontSize: 12)),
                    ),
                    DataCell(
                      hasRating
                          ? Text(
                              _formatDate(rating['rating_date']),
                              style: const TextStyle(fontSize: 10),
                            )
                          : const Text('-', style: TextStyle(fontSize: 10)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppxBActivities() {
    if (appxbActivities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No Appendix B activities loaded',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Total activities: ${appxbActivities.length}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Rated activities: $ratedActivities',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appendix B: Electrician Activities (${appxbActivities.length} activities)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: appxbActivities.length,
            itemBuilder: (context, index) {
              final activity = appxbActivities[index];
              final rating = appxbRatings[activity['activity_id']] ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              activity['activity_number'].toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              activity['activity_name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Candidate Competence (1=Low, 5=High)',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (i) {
                          final level = i + 1;
                          return GestureDetector(
                            onTap: () =>
                                _saveRating(activity['activity_id'], level),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: rating == level
                                      ? _getLevelColor(level)
                                      : Colors.grey.shade300,
                                  width: rating == level ? 3 : 1,
                                ),
                                color: rating == level
                                    ? _getLevelColor(level)
                                        .withValues(alpha: 0.2)
                                    : Colors.transparent,
                              ),
                              child: Center(
                                child: Text(
                                  level.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: rating == level
                                        ? _getLevelColor(level)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 1:
        return Colors.red.shade600;
      case 2:
        return Colors.orange.shade600;
      case 3:
        return Colors.yellow.shade700;
      case 4:
        return Colors.lightGreen.shade600;
      case 5:
        return Colors.green.shade600;
      default:
        return Colors.grey.shade400;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
