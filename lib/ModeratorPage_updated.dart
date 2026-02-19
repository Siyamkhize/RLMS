import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'config.dart';

class ModeratorPage extends StatefulWidget {
  final String facilitator_id;

  const ModeratorPage({super.key, required this.facilitator_id});

  @override
  _ModeratorPageState createState() => _ModeratorPageState();
}

class _ModeratorPageState extends State<ModeratorPage> {
  late Future<List<dynamic>> _classes;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _classes = fetchClasses(widget.facilitator_id);
  }

  Future<List<dynamic>> fetchClasses(String facilitatorId) async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl('get_classes.php?facilitator_id=$facilitatorId')),
      );

      print('Response Body (get_classes): ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load classes. Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load classes. Error: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildClassesContent();
      case 1:
        return ModerationFeedbackPage(facilitatorId: widget.facilitator_id);
      case 2:
        return ModerationReportPage(facilitatorId: widget.facilitator_id);
      case 3:
        return ModeratorPotholeChecklistPage(facilitatorId: widget.facilitator_id);
      default:
        return _buildClassesContent();
    }
  }

  Widget _buildClassesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Moderator ID: ${widget.facilitator_id}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _classes,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No classes found.'));
              } else {
                List<dynamic> classes = snapshot.data!;

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Project ID')),
                        DataColumn(label: Text('Class ID')),
                        DataColumn(label: Text('Class Name')),
                        DataColumn(label: Text('Learners')),
                        DataColumn(label: Text('Site ID')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: classes.map<DataRow>((classData) {
                        String projectId = classData['project_id'].toString();
                        String classId = classData['classID'].toString();
                        String className = classData['className'] ?? 'Unknown';
                        String numberOfLearners = classData['numberOfLearners'].toString();
                        String siteId = classData['siteID'].toString();

                        return DataRow(cells: [
                          DataCell(Text(projectId)),
                          DataCell(Text(classId)),
                          DataCell(Text(className)),
                          DataCell(Text(numberOfLearners)),
                          DataCell(Text(siteId)),
                          DataCell(
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ClassDetailsPage(classId: classId),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                              child: const Text('View'),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderator Dashboard')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Moderator Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              title: const Text('Classes'),
              selected: _selectedIndex == 0,
              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Moderation Feedback'),
              selected: _selectedIndex == 1,
              onTap: () {
                _onItemTapped(1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Moderation Report'),
              selected: _selectedIndex == 2,
              onTap: () {
                _onItemTapped(2);
                Navigator.pop(context);
              ),
            ),
            ListTile(
              title: const Text('Pothole Checklist'),
              selected: _selectedIndex == 3,
              onTap: () {
                _onItemTapped(3);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: _buildContent(),
    );
  }
}

// Class Details Page with Learner List
class ClassDetailsPage extends StatefulWidget {
  final String classId;

  const ClassDetailsPage({required this.classId, super.key});

  @override
  _ClassDetailsPageState createState() => _ClassDetailsPageState();
}

class _ClassDetailsPageState extends State<ClassDetailsPage> {
  late Future<List<dynamic>> _learners;

  @override
  void initState() {
    super.initState();
    _learners = fetchLearners(widget.classId);
  }

  Future<List<dynamic>> fetchLearners(String classId) async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl('get_learners.php?classID=$classId')),
      );

      print('Response Body (get_learners): ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load learners. Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load learners. Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Class Details - ${widget.classId}')),
      body: FutureBuilder<List<dynamic>>(
        future: _learners,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No learners found.'));
          } else {
            List<dynamic> learners = snapshot.data!;

            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Learner ID')),
                    DataColumn(label: Text('First Name')),
                    DataColumn(label: Text('Last Name')),
                    DataColumn(label: Text('ID Number')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: learners.map<DataRow>((learnerData) {
                    String learnerId = learnerData['LearnerID'].toString();
                    String firstName = learnerData['Name'] ?? 'Unknown';
                    String lastName = learnerData['Surname'] ?? 'Unknown';
                    String idNumber = learnerData['IDNumber'] ?? 'Unknown';

                    return DataRow(cells: [
                      DataCell(Text(learnerId)),
                      DataCell(Text(firstName)),
                      DataCell(Text(lastName)),
                      DataCell(Text(idNumber)),
                      DataCell(
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ModeratorMarkingPage(
                                  learnerId: learnerId,
                                  learnerFirstName: firstName,
                                  learnerLastName: lastName,
                                  learnerIdNumber: idNumber,
                                ),
                              ),
                            );
                          },
                          child: const Text('View Marks'),
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

// Moderator Marking Page - Matches Assessor UI
class ModeratorMarkingPage extends StatelessWidget {
  final String learnerId;
  final String? learnerFirstName;
  final String? learnerLastName;
  final String? learnerIdNumber;

  const ModeratorMarkingPage({
    super.key,
    required this.learnerId,
    this.learnerFirstName,
    this.learnerLastName,
    this.learnerIdNumber,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Assessment Marking'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.black,
            tabs: [
              Tab(text: 'Learner Information'),
              Tab(text: 'POE Details'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            LearnerInformationTab(learnerId: learnerId),
            ModeratorPOETab(learnerId: learnerId),
          ],
        ),
      ),
    );
  }
}

// Learner Information Tab
class LearnerInformationTab extends StatelessWidget {
  final String learnerId;

  const LearnerInformationTab({super.key, required this.learnerId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Learner Information for ID: $learnerId',
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}

// POE Details Tab with Expandable Sections
class ModeratorPOETab extends StatefulWidget {
  final String learnerId;

  const ModeratorPOETab({super.key, required this.learnerId});

  @override
  _ModeratorPOETabState createState() => _ModeratorPOETabState();
}

class _ModeratorPOETabState extends State<ModeratorPOETab> {
  late Future<Map<String, dynamic>> _poeData;

  @override
  void initState() {
    super.initState();
    _poeData = fetchPOE(widget.learnerId);
  }

  Future<Map<String, dynamic>> fetchPOE(String learnerId) async {
    try {
      final url = AppConfig.buildUrl('get_poe.php', queryParams: {
        'learnerId': learnerId,
      });
      
      print('[ModeratorPOETab] Fetching POE from: $url');
      final response = await http.get(Uri.parse(url));

      print('[ModeratorPOETab] POE Response Status: ${response.statusCode}');
      print('[ModeratorPOETab] POE Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load POE data. Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('[ModeratorPOETab] Error fetching POE: $e');
      throw Exception('Failed to load POE data. Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _poeData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No POE data found.'));
        }

        Map<String, dynamic> poeData = snapshot.data!;
        Map<String, dynamic> pathways = poeData['pathways'] ?? {};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Programme Section Header
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Short Skills Programme',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            
            // Build pathway/qualification/unit standard structure
            ...pathways.entries.map((entry) {
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text(entry.key,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: _buildQualificationTiles(entry.value),
                ),
              );
            }),
            
            // LogBook Section
            _buildLogBookSection(poeData),
            
            // Pothole Checklist Section
            _buildPotholeChecklistSection(),
          ],
        );
      },
    );
  }

  List<Widget> _buildQualificationTiles(Map<String, dynamic> pathwayData) {
    Map<String, dynamic> qualifications = pathwayData['qualifications'] ?? {};

    return qualifications.entries.map((qualEntry) {
      return ExpansionTile(
        title: Text(qualEntry.key),
        children: _buildUnitStandardTiles(qualEntry.value),
      );
    }).toList();
  }

  List<Widget> _buildUnitStandardTiles(Map<String, dynamic> qualificationData) {
    Map<String, dynamic> unitStandards = qualificationData['unit_standards'] ?? {};

    return unitStandards.entries.map((usEntry) {
      return ListTile(
        leading: const Icon(Icons.book, color: Colors.blue),
        title: Text(usEntry.key),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening ${usEntry.key}')),
          );
        },
      );
    }).toList();
  }

  Widget _buildLogBookSection(Map<String, dynamic> poeData) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.menu_book, color: Colors.blue),
        ),
        title: const Text(
          'LogBook',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          ListTile(
            title: const Text('View LogBook Entries'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening LogBook')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPotholeChecklistSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.construction, color: Colors.orange),
        ),
        title: const Text(
          'Pothole Checklist',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          ListTile(
            title: const Text('View Pothole Checklist'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening Pothole Checklist')),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Other pages remain the same...
class ModerationFeedbackPage extends StatelessWidget {
  final String facilitatorId;

  const ModerationFeedbackPage({super.key, required this.facilitatorId});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Moderation Feedback Page'));
  }
}

class ModerationReportPage extends StatelessWidget {
  final String facilitatorId;

  const ModerationReportPage({super.key, required this.facilitatorId});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Moderation Report Page'));
  }
}

class ModeratorPotholeChecklistPage extends StatelessWidget {
  final String facilitatorId;

  const ModeratorPotholeChecklistPage({super.key, required this.facilitatorId});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Moderator Pothole Checklist Page'));
  }
}
