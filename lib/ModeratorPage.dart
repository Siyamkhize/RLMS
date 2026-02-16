import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'DetailsPage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

class ModeratorPage extends StatefulWidget {
  final String facilitator_id;

  const ModeratorPage({Key? key, required this.facilitator_id}) : super(key: key);

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

  Future<List<dynamic>> fetchClasses(String facilitator_id) async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl('get_classes.php?facilitator_id=$facilitator_id')),
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
      case 4:
        return ModerationSamplingPage(facilitatorId: widget.facilitator_id);
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
                                    builder: (context) => ClassDetailsPage(classId: classId, moderatorId: widget.facilitator_id),
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
              },
            ),
            ListTile(
              title: const Text('Pothole Checklist'),
              selected: _selectedIndex == 3,
              onTap: () {
                _onItemTapped(3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Moderation Sampling'),
              selected: _selectedIndex == 4,
              onTap: () {
                _onItemTapped(4);
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
  final String moderatorId;

  const ClassDetailsPage({required this.classId, required this.moderatorId, Key? key}) : super(key: key);

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
                                  moderatorId: widget.moderatorId,
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
  final String moderatorId;

  const ModeratorMarkingPage({
    Key? key,
    required this.learnerId,
    this.learnerFirstName,
    this.learnerLastName,
    this.learnerIdNumber,
    required this.moderatorId,
  }) : super(key: key);

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
            ModeratorPOETab(learnerId: learnerId, moderatorId: moderatorId),
          ],
        ),
      ),
    );
  }
}

// Learner Information Tab
class LearnerInformationTab extends StatelessWidget {
  final String learnerId;

  const LearnerInformationTab({Key? key, required this.learnerId}) : super(key: key);

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
  final String moderatorId;

  const ModeratorPOETab({Key? key, required this.learnerId, required this.moderatorId}) : super(key: key);

  @override
  _ModeratorPOETabState createState() => _ModeratorPOETabState();
}

class _ModeratorPOETabState extends State<ModeratorPOETab> {
  late Future<Map<String, dynamic>> _poeData;
  final TextEditingController _potholeCommentController = TextEditingController();
  
  // Pothole evidence images
  List<Map<String, dynamic>> _potholeImages = [];
  bool _isLoadingImages = false;

  @override
  void initState() {
    super.initState();
    _poeData = fetchPOE(widget.learnerId);
    _loadPotholeImages();
  }
  
  Future<void> _loadPotholeImages() async {
    setState(() => _isLoadingImages = true);
    
    try {
      final url = '${AppConfig.baseUrl}/get_pothole_images.php?learner_id=${widget.learnerId}';
      print('DEBUG Images: Loading from $url');
      
      final response = await http.get(Uri.parse(url));
      
      print('DEBUG Images: Response status ${response.statusCode}');
      print('DEBUG Images: Response body ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _potholeImages = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
          print('DEBUG Images: Loaded ${_potholeImages.length} images');
        } else {
          print('DEBUG Images: API returned error - ${data['message']}');
        }
      }
    } catch (e) {
      print('Error loading pothole images: $e');
    } finally {
      setState(() => _isLoadingImages = false);
    }
  }

  @override
  void dispose() {
    _potholeCommentController.dispose();
    super.dispose();
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
            }).toList(),
            
            // LogBook Section
            _buildLogBookSection(poeData),
            
            // Pothole Checklist Section
            _buildPotholeChecklistSection(),
            
            // Pothole Evidence Images Section
            _buildPotholeImagesSection(),
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
    Map<String, dynamic> unitStandards = qualificationData['unitstandards'] ?? {};

    return unitStandards.entries.map((usEntry) {
      return ExpansionTile(
        title: Text(usEntry.key),
        children: _buildAssessmentTypeTiles(usEntry.value),
      );
    }).toList();
  }

  List<Widget> _buildAssessmentTypeTiles(Map<String, dynamic> unitStandardData) {
    List<dynamic> summative = unitStandardData['summative'] ?? [];
    List<dynamic> formative = unitStandardData['formative'] ?? [];

    List<Widget> assessmentTiles = [];

    // Formative Assessments
    if (formative.isNotEmpty) {
      TextEditingController moderatorCommentController = TextEditingController();
      String existingModeratorComment = formative.first['moderator_comment'] ?? '';
      String existingAssessorComment = formative.first['a_comment'] ?? '';
      moderatorCommentController.text = existingModeratorComment;
      
      assessmentTiles.add(
        ExpansionTile(
          title: const Text('Formative'),
          children: [
            ..._buildExerciseTiles(formative, assessmentType: 'formative'),
            // Display assessor comments if available
            if (existingAssessorComment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.comment, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Assessor Comments:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(existingAssessorComment),
                    ],
                  ),
                ),
              ),
            // Moderator comment section at the end of all questions
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Divider(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.comment, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Moderator Comment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: moderatorCommentController,
                    decoration: InputDecoration(
                      labelText: 'Comment',
                      border: const OutlineInputBorder(),
                      hintText: 'Enter your moderation comments for all formative questions',
                      helperText: existingModeratorComment.isNotEmpty 
                          ? 'Editing existing comment' 
                          : null,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _updateCommentForAllExercises(
                          'formative',
                          formative,
                          moderatorCommentController.text,
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Update Comment for All Formative Questions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Summative Assessments
    if (summative.isNotEmpty) {
      TextEditingController moderatorCommentController = TextEditingController();
      String existingModeratorComment = summative.first['moderator_comment'] ?? '';
      String existingAssessorComment = summative.first['a_comment'] ?? '';
      moderatorCommentController.text = existingModeratorComment;
      
      assessmentTiles.add(
        ExpansionTile(
          title: const Text('Summative'),
          children: [
            ..._buildExerciseTiles(summative, assessmentType: 'summative'),
            // Display assessor comments if available
            if (existingAssessorComment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.comment, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Assessor Comments:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(existingAssessorComment),
                    ],
                  ),
                ),
              ),
            // Moderator comment section at the end of all questions
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Divider(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.comment, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Moderator Comment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: moderatorCommentController,
                    decoration: InputDecoration(
                      labelText: 'Comment',
                      border: const OutlineInputBorder(),
                      hintText: 'Enter your moderation comments for all summative questions',
                      helperText: existingModeratorComment.isNotEmpty 
                          ? 'Editing existing comment' 
                          : null,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _updateCommentForAllExercises(
                          'summative',
                          summative,
                          moderatorCommentController.text,
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Update Comment for All Summative Questions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return assessmentTiles;
  }

  // Build LogBook section with actual data
  Widget _buildLogBookSection(Map<String, dynamic> poeData) {
    // Collect all logbook items from all pathways/qualifications/unit standards
    List<Map<String, dynamic>> allLogbookItems = [];
    Map<String, dynamic> pathways = poeData['pathways'] ?? {};

    pathways.forEach((pathwayName, pathwayData) {
      Map<String, dynamic> qualifications = pathwayData['qualifications'] ?? {};
      qualifications.forEach((qualName, qualData) {
        Map<String, dynamic> unitStandards = qualData['unitstandards'] ?? {};
        unitStandards.forEach((unitName, unitData) {
          List<dynamic> logbook = unitData['logbook'] ?? [];
          if (logbook.isNotEmpty) {
            allLogbookItems.add({
              'unitStandardName': unitName,
              'logbookItems': logbook,
            });
          }
        });
      });
    });
    
    // Also add logbook marks from the logbook_marks array (includes pothole checklist)
    List<dynamic> logbookMarks = poeData['logbook_marks'] ?? [];
    for (var mark in logbookMarks) {
      String unitStandardId = mark['unit_standard_id'] ?? '';
      String unitStandardName = mark['unit_standard_name'] ?? 'Unit Standard $unitStandardId';
      
      // Check if this is pothole checklist (unit standards 13958 or 14555)
      bool isPotholeChecklist = unitStandardId == '13958' || unitStandardId == '14555';
      
      allLogbookItems.add({
        'unitStandardName': unitStandardName,
        'unitStandardId': unitStandardId,
        'isPotholeChecklist': isPotholeChecklist,
        'logbookItems': [
          {
            'id': unitStandardId,
            'exercise_name': isPotholeChecklist ? 'Pothole Checklist' : unitStandardName,
            'marks_scored': mark['marks'],
            'total_marks': isPotholeChecklist ? 50 : 100,
            'moderator_status': mark['moderator_status'] ?? '',
            'moderator_comment': mark['moderator_comment'] ?? '',
            'a_comment': mark['a_comment'] ?? '',
            'assessment_date': mark['assessment_date'] ?? '',
          }
        ],
      });
    }

    if (allLogbookItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4,
      child: ExpansionTile(
        title: const Text(
          'LogBook',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: const Icon(Icons.book, color: Colors.blue),
        children: allLogbookItems.map((item) {
          List<dynamic> logbookItems = item['logbookItems'];
          TextEditingController moderatorCommentController = TextEditingController();
          String existingModeratorComment = logbookItems.isNotEmpty 
              ? (logbookItems.first['moderator_comment'] ?? '') 
              : '';
          String existingAssessorComment = logbookItems.isNotEmpty 
              ? (logbookItems.first['a_comment'] ?? '') 
              : '';
          moderatorCommentController.text = existingModeratorComment;
          
          return ExpansionTile(
            title: Text(item['unitStandardName']),
            children: [
              ..._buildExerciseTiles(logbookItems, assessmentType: 'logbook'),
              // Display assessor comments if available
              if (existingAssessorComment.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.comment, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Assessor Comments:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(existingAssessorComment),
                      ],
                    ),
                  ),
                ),
              // Moderator comment section at the end
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Divider(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Moderator Comment',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: moderatorCommentController,
                      decoration: InputDecoration(
                        labelText: 'Comment',
                        border: const OutlineInputBorder(),
                        hintText: 'Enter your moderation comments for logbook',
                        helperText: existingModeratorComment.isNotEmpty 
                            ? 'Editing existing comment' 
                            : null,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Moderation Decision',
                              border: OutlineInputBorder(),
                            ),
                            value: existingModeratorComment.isNotEmpty && logbookItems.first['moderator_status'] != null 
                                ? logbookItems.first['moderator_status'] 
                                : null,
                            items: const [
                              DropdownMenuItem(value: 'upheld', child: Text('Uphold')),
                              DropdownMenuItem(value: 'withdrawn', child: Text('Withdraw')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                _submitModeration(
                                  'logbook',
                                  item['unitStandardName'],
                                  value,
                                  moderatorCommentController.text,
                                  logbookItems,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // Build Pothole Checklist section with actual data
  Widget _buildPotholeChecklistSection() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4,
      child: ExpansionTile(
        title: const Text(
          'Pothole Checklist',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: const Icon(Icons.construction, color: Colors.orange),
        children: [
          _buildPotholeChecklistContent(),
        ],
      ),
    );
  }

  Widget _buildPotholeChecklistContent() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _checkPotholeChecklistStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }

        final checklistData = snapshot.data;
        final bool hasChecklist = checklistData?['exists'] == true;
        final String? checklistType = checklistData?['type'];
        final data = checklistData?['data'];

        if (!hasChecklist) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No pothole checklist found for this learner.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        // Get unit standards array (new format)
        List<dynamic> unitStandards = data?['unit_standards'] ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(
                checklistType == 'scanned'
                    ? Icons.picture_as_pdf
                    : Icons.checklist,
                color: Colors.blue,
              ),
              title: Text(
                checklistType == 'scanned'
                    ? 'Scanned Document'
                    : 'System Generated Form',
              ),
              subtitle: unitStandards.isNotEmpty 
                  ? Text('${unitStandards.length} Unit Standard(s) marked')
                  : const Text('Tap to view'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _viewPotholeChecklist(checklistType!, data),
            ),
            
            // Display each unit standard separately with individual moderation
            if (unitStandards.isNotEmpty)
              ...unitStandards.map((us) {
                String unitId = us['unit_standard_id'] ?? '';
                int marks = us['marks'] ?? 0;
                String moderatorStatus = us['moderator_status'] ?? '';
                String moderatorComment = us['moderator_comment'] ?? '';
                String assessorComment = us['assessor_comment'] ?? '';
                String recordId = us['id']?.toString() ?? '';
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Unit Standard Header
                          Row(
                            children: [
                              const Icon(Icons.assignment, color: Colors.blue, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Unit Standard: $unitId',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // Marks
                          Text(
                            'Marks: $marks / 50',
                            style: const TextStyle(fontSize: 14),
                          ),
                          
                          // Assessor Comment
                          if (assessorComment.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                border: Border.all(color: Colors.blue),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.comment, color: Colors.blue, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'Assessor Comment:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(assessorComment, style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                          
                          // Individual Moderation Decision for this Unit Standard
                          const SizedBox(height: 12),
                          const Text(
                            'Moderation Decision',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Show dropdown only if not yet moderated
                          if (moderatorStatus.isEmpty)
                            DropdownButtonFormField<String>(
                              value: null, // No initial value
                              hint: const Text('-- Select Decision --'),
                              decoration: const InputDecoration(
                                labelText: 'Moderation Decision',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'upheld', child: Text('Uphold')),
                                DropdownMenuItem(value: 'withdrawn', child: Text('Withdraw')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  _submitPotholeUnitStandardModeration(
                                    unitId,
                                    recordId,
                                    value,
                                    _potholeCommentController.text,
                                  );
                                }
                              },
                            )
                          else
                            // Already moderated - show status badge
                            Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: moderatorStatus.toLowerCase() == 'upheld' 
                                    ? Colors.green.shade50 
                                    : Colors.red.shade50,
                                border: Border.all(
                                  color: moderatorStatus.toLowerCase() == 'upheld' 
                                      ? Colors.green 
                                      : Colors.red,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    moderatorStatus.toLowerCase() == 'upheld' 
                                        ? Icons.check_circle 
                                        : Icons.cancel,
                                    color: moderatorStatus.toLowerCase() == 'upheld' 
                                        ? Colors.green 
                                        : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Status: ${moderatorStatus.toUpperCase()}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: moderatorStatus.toLowerCase() == 'upheld' 
                                            ? Colors.green 
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            
            // Shared Moderator Comment Field (after all unit standards)
            if (unitStandards.isNotEmpty)
              _buildSharedPotholeCommentField(unitStandards),
          ],
        );
      },
    );
  }

  // Build Pothole Evidence Images section
  Widget _buildPotholeImagesSection() {
    if (_isLoadingImages) {
      return Card(
        margin: const EdgeInsets.all(8.0),
        elevation: 4,
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    
    if (_potholeImages.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no images
    }
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.image, color: Colors.purple, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Pothole Evidence Images',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: _potholeImages.length,
              itemBuilder: (context, index) {
                final image = _potholeImages[index];
                // Use correct domain for images
                final imageUrl = 'https://rlms.rlms.co.za/mobile/${image['file_path']}';
                
                return GestureDetector(
                  onTap: () {
                    // Show full image with zoom capability
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        backgroundColor: Colors.black,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.9,
                          height: MediaQuery.of(context).size.height * 0.8,
                          child: Column(
                            children: [
                              // Header with close button
                              Container(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Image ${index + 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    IconButton(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.close, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              // Zoomable image
                              Expanded(
                                child: InteractiveViewer(
                                  panEnabled: true,
                                  boundaryMargin: const EdgeInsets.all(20),
                                  minScale: 0.5,
                                  maxScale: 4.0,
                                  child: Center(
                                    child: Image.network(
                                      imageUrl, 
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(
                                          child: CircularProgressIndicator(color: Colors.white),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Center(
                                          child: Icon(Icons.broken_image, size: 50, color: Colors.white),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              // Description if available
                              if (image['description'] != null && image['description'].toString().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12.0),
                                  color: Colors.black87,
                                  child: Text(
                                    image['description'],
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 2,
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                            );
                          },
                        ),
                        // Overlay with image number
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4.0),
                            color: Colors.black54,
                            child: Text(
                              'Image ${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
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

  Future<Map<String, dynamic>> _checkPotholeChecklistStatus() async {
    try {
      print('DEBUG Pothole: Checking for learner ${widget.learnerId}');

      // Check server using unified endpoint
      try {
        final url = '${AppConfig.baseUrl}/view_pothole_checklists.php?learner_id=${widget.learnerId}';
        print('DEBUG Pothole: Checking server at $url');
        
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        
        print('DEBUG Pothole: Response status ${response.statusCode}');
        print('DEBUG Pothole: Response body ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success' && data['data'] != null) {
            final type = data['data']['type'] ?? 'system';
            print('DEBUG Pothole: Found checklist on server, type=$type');
            return {
              'exists': true,
              'type': type,
              'data': data['data'],
            };
          }
        }
      } catch (e) {
        print('DEBUG Pothole: Error checking server: $e');
      }

      print('DEBUG Pothole: No checklist found');
      return {
        'exists': false,
        'type': 'none',
        'data': null,
      };
    } catch (e) {
      print('DEBUG Pothole: Error in _checkPotholeChecklistStatus: $e');
      return {
        'exists': false,
        'type': 'none',
        'data': null,
      };
    }
  }

  void _viewPotholeChecklist(String type, Map<String, dynamic>? data) {
    print('DEBUG: _viewPotholeChecklist called with type=$type');
    
    if (type == 'scanned' && data?['document_path'] != null) {
      print('DEBUG: Opening scanned PDF');
      
      String documentPath = data!['document_path'];
      
      // Convert relative server path to full URL
      String fullUrl = documentPath;
      
      // If path starts with ../, convert to full URL
      if (documentPath.startsWith('../')) {
        // Remove ../ and construct full URL
        documentPath = documentPath.replaceFirst('../', '');
        // Use base domain without /mobile path for documents in root uploads folder
        final baseDomain = AppConfig.baseUrl.replaceAll('/mobile', '');
        fullUrl = '$baseDomain/$documentPath';
      } else if (!documentPath.startsWith('http')) {
        // If it's a relative path without ../, add base URL
        fullUrl = '${AppConfig.baseUrl}/$documentPath';
      }
      
      print('DEBUG: Full PDF URL: $fullUrl');
      
      // Navigate to PDF viewer page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PotholeChecklistPDFViewer(
            pdfUrl: fullUrl,
            documentPath: data['document_path'],
            learnerId: data['learner_id'] ?? widget.learnerId,
            assessmentDate: data['assessment_date'] ?? 'N/A',
          ),
        ),
      );
    } else if (type == 'system' && data != null) {
      print('DEBUG: Opening system checklist');
      
      // Show dialog with checklist data
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('System Pothole Checklist'),
          content: SingleChildScrollView(
            child: _buildChecklistView(data),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildChecklistView(Map<String, dynamic>? checklistData) {
    if (checklistData == null) {
      return const Text('No data available');
    }

    final items = checklistData['checklist_items'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Learner: ${checklistData['learner_name'] ?? 'N/A'}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('Venue: ${checklistData['venue'] ?? 'N/A'}'),
        Text('Date: ${checklistData['assessment_date'] ?? 'N/A'}'),
        const SizedBox(height: 16),
        ...items.entries.map((section) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(section.key,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ...(section.value as List).map((item) {
                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        item['value'] == true
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: item['value'] == true
                            ? Colors.green
                            : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item['label'] ?? '')),
                    ],
                  ),
                );
              }).toList(),
              const Divider(),
            ],
          );
        }).toList(),
      ],
    );
  }

  // Build moderation action buttons with comment section
  Widget _buildModerationActions(String assessmentType, String unitStandardName, List<dynamic> items) {
    TextEditingController commentController = TextEditingController();
    String currentStatus = items.first['moderator_status'] ?? '';
    String currentComment = items.first['moderator_comment'] ?? '';
    
    commentController.text = currentComment;
    String selectedStatus = currentStatus.isEmpty ? 'none' : currentStatus;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const Text(
            'Moderator Comments',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: commentController,
            decoration: InputDecoration(
              labelText: 'Moderator Comments',
              border: const OutlineInputBorder(),
              hintText: 'Enter your moderation comments for this ${assessmentType.toLowerCase()}',
              helperText: currentComment.isNotEmpty 
                  ? 'Editing existing comment' 
                  : null,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          const Text(
            'Moderation Decision',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Select Decision',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('-- Select Decision --')),
                      DropdownMenuItem(value: 'upheld', child: Text('Uphold')),
                      DropdownMenuItem(value: 'withdrawn', child: Text('Withdraw')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedStatus = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: selectedStatus == 'none' ? null : () {
                      _submitModeration(
                        assessmentType,
                        unitStandardName,
                        selectedStatus,
                        commentController.text,
                        items,
                      );
                    },
                    icon: Icon(selectedStatus == 'upheld' ? Icons.check_circle : Icons.save),
                    label: const Text('Submit Moderation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedStatus == 'upheld' 
                          ? Colors.green 
                          : selectedStatus == 'withdrawn'
                              ? Colors.red
                              : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Submit moderation decision
  Future<void> _submitModeration(
    String assessmentType,
    String unitStandardName,
    String status,
    String comment,
    List<dynamic> items,
  ) async {
    try {
      final url = '${AppConfig.baseUrl}/save_moderation.php';
      
      print('[Moderation] Submitting moderation');
      print('[Moderation] URL: $url');
      print('[Moderation] Type: $assessmentType, Status: $status');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learnerId': widget.learnerId,
          'assessmentType': assessmentType,
          'unitStandardName': unitStandardName,
          'moderatorStatus': status,
          'moderatorComment': comment,
          'moderatorId': widget.moderatorId,
        }),
      );

      print('[Moderation] Response status: ${response.statusCode}');
      print('[Moderation] Response body: ${response.body}');

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Moderation ${status == 'upheld' ? 'upheld' : 'withdrawn'} successfully!'),
              backgroundColor: status == 'upheld' ? Colors.green : Colors.red,
            ),
          );
          
          // Refresh the POE data
          setState(() {
            _poeData = fetchPOE(widget.learnerId);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${responseData['message'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('[Moderation] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting moderation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Submit moderation for a specific pothole unit standard
  Future<void> _submitPotholeUnitStandardModeration(
    String unitStandardId,
    String recordId,
    String status,
    String comment,
  ) async {
    try {
      final url = '${AppConfig.baseUrl}/moderate_marks.php';
      
      print('[Pothole Moderation] Submitting moderation for unit standard $unitStandardId');
      print('[Pothole Moderation] URL: $url');
      print('[Pothole Moderation] Record ID: $recordId, Status: $status, Comment: $comment');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'assessmentType': 'logbook',
          'exerciseId': recordId,
          'learnerId': widget.learnerId,
          'moderatorStatus': status == 'upheld' ? 'Upheld' : 'Withdrawn',
          'moderatorComment': comment,
          'moderatorId': widget.moderatorId,
        }),
      );

      print('[Pothole Moderation] Response status: ${response.statusCode}');
      print('[Pothole Moderation] Response body: ${response.body}');

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unit Standard $unitStandardId ${status == 'upheld' ? 'upheld' : 'withdrawn'} successfully!'),
              backgroundColor: status == 'upheld' ? Colors.green : Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // DON'T refresh the entire POE data - this causes navigation issues
          // The UI will update when the user navigates away and comes back
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${responseData['message'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('[Pothole Moderation] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting moderation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Widget> _buildExerciseTiles(List<dynamic> exercises, {String assessmentType = 'general'}) {
    return exercises.map((exercise) {
      String moderatorStatus = exercise['moderator_status'] ?? '';
      // Normalize status for display (capitalize first letter)
      String displayStatus = moderatorStatus.isNotEmpty 
          ? moderatorStatus[0].toUpperCase() + moderatorStatus.substring(1).toLowerCase()
          : '';
      
      String marksScored = exercise['marks_scored']?.toString() ?? 'Not marked';
      String totalMarks = exercise['total_marks']?.toString() ?? '';
      String fileUrl = exercise['fileUrl'] ?? exercise['file_url'] ?? '';
      
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: ExpansionTile(
          leading: Icon(
            displayStatus == 'Upheld' 
                ? Icons.check_circle 
                : displayStatus == 'Withdrawn'
                    ? Icons.cancel
                    : Icons.assignment,
            color: displayStatus == 'Upheld'
                ? Colors.green
                : displayStatus == 'Withdrawn'
                    ? Colors.red
                    : Colors.blue,
          ),
          title: Text(exercise['exercise_name'] ?? exercise['exercise'] ?? 'Exercise'),
          subtitle: Text(
            'Marks: $marksScored${totalMarks.isNotEmpty ? "/$totalMarks" : ""}'
            '${displayStatus.isNotEmpty ? " • Status: $displayStatus" : ""}',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display marks details
                  Row(
                    children: [
                      const Icon(Icons.grade, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Marks Scored: $marksScored${totalMarks.isNotEmpty ? " out of $totalMarks" : ""}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // View Answer button
                  if (exercise['fileUrl'] != null && exercise['fileUrl'].toString().isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          String fileUrl = exercise['fileUrl'];
                          if (fileUrl.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ModeratorPdfViewerScreen(pdfUrl: fileUrl),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('View Learner Answer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Per-exercise moderation decision (without comment)
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Moderation Decision',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Always show dropdown - allows updating moderation status
                  // If already moderated, show current status as selected value
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Decision for this question',
                          border: const OutlineInputBorder(),
                          // Show current status in helper text if already moderated
                          helperText: moderatorStatus.isNotEmpty 
                              ? 'Current: ${displayStatus} (you can change it)' 
                              : null,
                          helperStyle: TextStyle(
                            color: displayStatus == 'Upheld' ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        value: moderatorStatus.isNotEmpty ? moderatorStatus.toLowerCase() : null,
                        items: const [
                          DropdownMenuItem(value: 'upheld', child: Text('Uphold')),
                          DropdownMenuItem(value: 'withdrawn', child: Text('Withdraw')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            // Show confirmation if changing existing status
                            if (moderatorStatus.isNotEmpty && value != moderatorStatus.toLowerCase()) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Change'),
                                  content: Text(
                                    'Change moderation status from ${displayStatus} to ${value == 'upheld' ? 'Uphold' : 'Withdraw'}?'
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _submitExerciseModeration(
                                          exercise,
                                          value,
                                          '', // No comment per exercise
                                          assessmentType,
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: value == 'upheld' ? Colors.green : Colors.red,
                                      ),
                                      child: const Text('Confirm'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              // First time moderation - no confirmation needed
                              _submitExerciseModeration(
                                exercise,
                                value,
                                '', // No comment per exercise
                                assessmentType,
                              );
                            }
                          }
                        },
                      ),
                      // Show status badge below dropdown if already moderated
                      if (moderatorStatus.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: displayStatus == 'Upheld' 
                                ? Colors.green.shade50 
                                : Colors.red.shade50,
                            border: Border.all(
                              color: displayStatus == 'Upheld' 
                                  ? Colors.green 
                                  : Colors.red,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                displayStatus == 'Upheld' 
                                    ? Icons.check_circle 
                                    : Icons.cancel,
                                color: displayStatus == 'Upheld' 
                                    ? Colors.green 
                                    : Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Currently: ${displayStatus.toUpperCase()}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: displayStatus == 'Upheld' 
                                      ? Colors.green 
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
  
  // Submit per-exercise moderation
  Future<void> _submitExerciseModeration(
    Map<String, dynamic> exercise,
    String action,
    String comment,
    String assessmentType,
  ) async {
    try {
      // Use different endpoints based on assessment type
      // Formative/Summative use save_moderation_status.php (marks table)
      // Logbook uses moderate_marks.php (logbook_marks table)
      final String endpoint = (assessmentType == 'formative' || assessmentType == 'summative') 
          ? 'save_moderation_status.php'  // For formative/summative
          : 'moderate_marks.php';          // For logbook/pothole
      
      final url = AppConfig.buildUrl(endpoint);
      
      // Build request body based on endpoint
      Map<String, dynamic> requestBody;
      if (endpoint == 'save_moderation_status.php') {
        // Formative/Summative endpoint - match PHP expectations exactly
        // PHP expects: learnerId, exerciseId (the exercise question text), moderation_status, assessment_type
        
        // Debug: Print ALL exercise data to understand structure
        print('[DEBUG] ========== EXERCISE DATA DUMP ==========');
        print('[DEBUG] Full exercise map: $exercise');
        print('[DEBUG] Available keys: ${exercise.keys.toList()}');
        exercise.forEach((key, value) {
          print('[DEBUG]   $key: $value (${value.runtimeType})');
        });
        print('[DEBUG] ==========================================');
        
        // Try multiple field names to extract exercise name
        // IMPORTANT: The database and API use 'exercise' as the field name
        String exerciseName = exercise['exercise']?.toString() ??  // PRIMARY: This is the actual field name from get_poe.php
                             exercise['exercise_name']?.toString() ?? 
                             exercise['question']?.toString() ?? 
                             exercise['title']?.toString() ?? 
                             exercise['name']?.toString() ?? 
                             exercise['exercise_text']?.toString() ?? 
                             exercise['question_text']?.toString() ?? 
                             '';
        
        print('[DEBUG] Exercise name extracted (before cleanup): "$exerciseName"');
        
        // Remove "Exercise " prefix if it exists to get the actual question text
        if (exerciseName.startsWith('Exercise ')) {
          exerciseName = exerciseName.substring(9); // Remove "Exercise " prefix
        }
        
        print('[DEBUG] Exercise name after cleanup: "$exerciseName"');
        
        // If exerciseName is STILL empty, this is a critical error
        if (exerciseName.isEmpty) {
          print('[DEBUG] ERROR: Exercise name is empty after all attempts!');
          print('[DEBUG] This will cause "missing required fields" error on backend');
          
          // Last resort: use ID if available
          if (exercise['id'] != null) {
            exerciseName = 'Exercise ${exercise['id']}';
            print('[DEBUG] Using last resort exercise name: "$exerciseName"');
          } else {
            print('[DEBUG] CRITICAL: No ID available either!');
            throw Exception('Cannot determine exercise name from exercise data');
          }
        }
        
        // Determine the database type value (capitalize first letter)
        String dbAssessmentType = assessmentType == 'formative' 
            ? 'Formative' 
            : assessmentType == 'summative' 
                ? 'Summative' 
                : '';
        
        requestBody = {
          'learnerId': widget.learnerId,
          'exercise': exerciseName,  // Use 'exercise' to match database column name
          'moderation_status': action,  // 'Upheld' or 'Withdrawn'
          'moderator_comment': comment,  // Moderator's comment (snake_case to match PHP)
          'moderator_id': widget.moderatorId,  // Moderator ID (snake_case to match PHP)
          'assessment_type': dbAssessmentType,  // CRITICAL: Include assessment type to prevent cross-contamination
        };
        
        // Debug: Print request body
        print('[DEBUG] Request body: $requestBody');
      } else {
        // Logbook/Pothole endpoint
        requestBody = {
          'assessmentType': assessmentType,
          'exerciseId': exercise['id']?.toString() ?? exercise['exercise_id']?.toString() ?? '',
          'learnerId': widget.learnerId,
          'moderatorStatus': action,
          'moderatorComment': comment,
          'moderatorId': widget.moderatorId,
        };
      }
      
      print('[DEBUG] Sending POST request to: $url');
      print('[DEBUG] Request headers: Content-Type: application/json');
      print('[DEBUG] Request body: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('[DEBUG] Request timed out after 30 seconds');
          throw Exception('Request timed out - server not responding');
        },
      );

      print('[DEBUG] Response status code: ${response.statusCode}');
      print('[DEBUG] Response body: ${response.body}');

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        print('[DEBUG] Parsed response data: $responseData');
        
        // Handle both 'success' and 'warning' as successful operations
        if (responseData['status'] == 'success' || responseData['status'] == 'warning') {
          // Update the local exercise data without refreshing the entire page
          setState(() {
            exercise['moderator_status'] = action.toLowerCase(); // Store as lowercase to match PHP
            exercise['approval_status'] = action == 'upheld' ? 'Approved' : 'Disapproved';
          });
          
          // Show appropriate message based on status
          String message = responseData['status'] == 'warning' 
              ? 'Status already set to ${action == 'upheld' ? 'upheld' : 'withdrawn'}'
              : 'Exercise ${action == 'upheld' ? 'upheld' : 'withdrawn'} successfully!';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: action == 'upheld' ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${responseData['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit moderation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Build shared comment field for pothole checklist
  Widget _buildSharedPotholeCommentField(List<dynamic> unitStandards) {
    // Get existing comment from first unit standard (they should all have the same comment)
    String existingComment = unitStandards.isNotEmpty 
        ? (unitStandards.first['moderator_comment'] ?? '') 
        : '';
    
    // Initialize controller with existing comment if not already set
    if (_potholeCommentController.text.isEmpty && existingComment.isNotEmpty) {
      _potholeCommentController.text = existingComment;
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.comment, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Shared Moderator Comment',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'This comment will be applied to all unit standards in the pothole checklist.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _potholeCommentController,
            decoration: InputDecoration(
              labelText: 'Moderator Comment',
              border: const OutlineInputBorder(),
              hintText: 'Enter your moderation comments for the pothole checklist',
              helperText: existingComment.isNotEmpty 
                  ? 'Editing existing comment' 
                  : null,
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _updatePotholeCommentForAll(unitStandards);
              },
              icon: const Icon(Icons.save),
              label: const Text('Update Comment for All Unit Standards'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Update comment for all pothole unit standards
  Future<void> _updatePotholeCommentForAll(List<dynamic> unitStandards) async {
    String comment = _potholeCommentController.text;
    
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a comment before updating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      int successCount = 0;
      int failCount = 0;
      
      for (var us in unitStandards) {
        String recordId = us['id']?.toString() ?? '';
        String unitStandardId = us['unit_standard_id'] ?? '';
        
        if (recordId.isEmpty) continue;
        
        final url = AppConfig.buildUrl('moderate_marks.php');
        
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'assessmentType': 'logbook',
            'exerciseId': recordId,
            'learnerId': widget.learnerId,
            'moderatorStatus': us['moderator_status'] ?? 'upheld',  // Keep existing status or default to upheld
            'moderatorComment': comment,
            'moderatorId': widget.moderatorId,
          }),
        );

        if (response.statusCode == 200) {
          var responseData = jsonDecode(response.body);
          if (responseData['status'] == 'success') {
            successCount++;
          } else {
            failCount++;
          }
        } else {
          failCount++;
        }
      }
      
      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comment updated for $successCount unit standard(s)'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the POE data
        setState(() {
          _poeData = fetchPOE(widget.learnerId);
        });
      }
      
      if (failCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update $failCount unit standard(s)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('[Pothole Comment Update] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating comments: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Update comment for all formative/summative exercises
  Future<void> _updateCommentForAllExercises(
    String assessmentType,
    List<dynamic> exercises,
    String comment,
  ) async {
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a comment before updating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      int successCount = 0;
      int failCount = 0;
      
      for (var exercise in exercises) {
        String exerciseName = exercise['exercise_name']?.toString() ?? 
                             exercise['exercise']?.toString() ?? 
                             '';
        // Remove "Exercise " prefix if it exists
        if (exerciseName.startsWith('Exercise ')) {
          exerciseName = exerciseName.substring(9);
        }
        
        if (exerciseName.isEmpty) continue;
        
        final url = AppConfig.buildUrl('save_moderation_status.php');
        
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'learnerId': widget.learnerId,
            'exerciseId': exerciseName,
            'moderation_status': exercise['moderator_status'] ?? 'upheld',  // Keep existing status or default to upheld
            'moderator_comment': comment,
            'moderator_id': widget.moderatorId,
          }),
        );

        if (response.statusCode == 200) {
          var responseData = jsonDecode(response.body);
          if (responseData['status'] == 'success') {
            successCount++;
          } else {
            failCount++;
          }
        } else {
          failCount++;
        }
      }
      
      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comment updated for $successCount ${assessmentType} question(s)'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the POE data
        setState(() {
          _poeData = fetchPOE(widget.learnerId);
        });
      }
      
      if (failCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update $failCount ${assessmentType} question(s)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('[Comment Update] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating comments: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Other pages remain the same...
class ModerationFeedbackPage extends StatefulWidget {
  final String facilitatorId;

  const ModerationFeedbackPage({Key? key, required this.facilitatorId}) : super(key: key);

  @override
  _ModerationFeedbackPageState createState() => _ModerationFeedbackPageState();
}

class _ModerationFeedbackPageState extends State<ModerationFeedbackPage> {
  late Future<List<dynamic>> _classList;

  @override
  void initState() {
    super.initState();
    _classList = fetchClassList(widget.facilitatorId);
  }

  Future<List<dynamic>> fetchClassList(String facilitatorId) async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl('get_classes_by_facilitator.php?facilitator_id=$facilitatorId')),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return data['data'];
        } else {
          throw Exception('Failed to load class list: ${data['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching class list: $e');
    }
  }

  Future<void> _generateAndDownloadReport(String classId) async {
    try {
      if (classId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid Class ID')),
        );
        return;
      }

      final response = await http.get(
        Uri.parse(AppConfig.buildUrl('generate_moderation_report.php', queryParams: {'class_id': classId.toString()})),
      );

      print('Request URL: ${AppConfig.buildUrl("generate_moderation_report.php", queryParams: {"class_id": classId.toString()})}');
      print('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (response.headers['content-type']?.contains('application/pdf') == true) {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/Class_${classId}_Feedback_Report.pdf');
          await file.writeAsBytes(response.bodyBytes);

          // Open the PDF
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfViewerPage(pdfPath: file.path),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unexpected response: ${response.body}')),
          );
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Unknown error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $errorMessage')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.indigo],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.class_, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Moderation Feedback',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select a class to generate feedback report',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FutureBuilder<List<dynamic>>(
                    future: _classList,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text(
                            'No classes available.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        );
                      } else {
                        List<dynamic> classList = snapshot.data!;
                        return ListView.builder(
                          itemCount: classList.length,
                          itemBuilder: (context, index) {
                            var classData = classList[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  child: Text(classData['classID']?.toString() ?? 'N/A'),
                                ),
                                title: Text(
                                  classData['className'] ?? 'Unknown Class',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(classData['classDescription'] ?? 'No description'),
                                trailing: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                onTap: () {
                                  _generateAndDownloadReport(classData['classID']?.toString() ?? '');
                                },
                              ),
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModerationReportPage extends StatefulWidget {
  final String facilitatorId;

  const ModerationReportPage({Key? key, required this.facilitatorId}) : super(key: key);

  @override
  _ModerationReportPageState createState() => _ModerationReportPageState();
}

class _ModerationReportPageState extends State<ModerationReportPage> {
  List<dynamic> classes = [];
  List<dynamic> learners = [];
  bool showLearnersTable = false;

  Future<List<dynamic>> fetchModerationReport() async {
    final response = await http.get(
      Uri.parse(AppConfig.buildUrl('get_classes.php?facilitator_id=${widget.facilitatorId}')),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load moderation report');
    }
  }

  Future<List<dynamic>> fetchLearners(String classID) async {
    final response = await http.get(
      Uri.parse(AppConfig.buildUrl('get_learners.php?classID=$classID')),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load learners');
    }
  }

  Future<void> _generateAndViewReport(String learnerId) async {
    final url = Uri.parse(AppConfig.buildUrl('moderationReport.php?learner_id=$learnerId'));

    try {
      print('Attempting to launch URL: $url');
      bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      print('launchUrl result: $launched');
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to launch $url')),
        );
      }
    } catch (e) {
      print('Error launching URL: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching URL: $e')),
      );
    }
  }

  void _onActionPressed(String classID) async {
    try {
      final learnersData = await fetchLearners(classID);
      setState(() {
        learners = learnersData;
        showLearnersTable = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching learners: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.deepOrange],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assessment, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                'Moderation Report',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a class to view learners, then select a learner to generate their report',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: fetchModerationReport(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No data found'));
                } else {
                  classes = snapshot.data!;
                  return Column(
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 4,
                          child: SingleChildScrollView(
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
                                  String projectId = classData['project_id']?.toString() ?? 'N/A';
                                  String classId = classData['classID']?.toString() ?? 'N/A';
                                  String className = classData['className']?.toString() ?? 'Unknown';
                                  String numberOfLearners = classData['numberOfLearners']?.toString() ?? 'N/A';
                                  String siteId = classData['siteID']?.toString() ?? 'N/A';

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(projectId)),
                                      DataCell(Text(classId)),
                                      DataCell(Text(className)),
                                      DataCell(Text(numberOfLearners)),
                                      DataCell(Text(siteId)),
                                      DataCell(
                                        ElevatedButton(
                                          onPressed: () => _onActionPressed(classId),
                                          child: const Text('View Learners'),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (showLearnersTable) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Learners - Click to generate report',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Card(
                            elevation: 4,
                            child: SingleChildScrollView(
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
                                    String learnerId = learnerData['LearnerID']?.toString() ?? 'N/A';
                                    String firstName = learnerData['Name']?.toString() ?? 'Unknown';
                                    String lastName = learnerData['Surname']?.toString() ?? 'Unknown';
                                    String idNumber = learnerData['IDNumber']?.toString() ?? 'Unknown';

                                    return DataRow(
                                      cells: [
                                        DataCell(Text(learnerId)),
                                        DataCell(Text(firstName)),
                                        DataCell(Text(lastName)),
                                        DataCell(Text(idNumber)),
                                        DataCell(
                                          ElevatedButton.icon(
                                            onPressed: () => _generateAndViewReport(learnerId),
                                            icon: const Icon(Icons.picture_as_pdf, size: 16),
                                            label: const Text('Generate'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ModeratorPotholeChecklistPage extends StatelessWidget {
  final String facilitatorId;

  const ModeratorPotholeChecklistPage({Key? key, required this.facilitatorId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Moderator Pothole Checklist Page'));
  }
}

// Moderation Sampling Page with Stratified Sampling
class ModerationSamplingPage extends StatefulWidget {
  final String facilitatorId;

  const ModerationSamplingPage({Key? key, required this.facilitatorId}) : super(key: key);

  @override
  _ModerationSamplingPageState createState() => _ModerationSamplingPageState();
}

class _ModerationSamplingPageState extends State<ModerationSamplingPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _samplingData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSamplingData();
  }

  Future<void> _loadSamplingData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Add cache-busting timestamp to ensure fresh data
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl('get_learners_with_poe_assigned.php?moderator_id=${widget.facilitatorId}&_t=$timestamp')),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      print('Sampling Response Status: ${response.statusCode}');
      print('Sampling Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _samplingData = data['data'];
            _isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load sampling data');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple, Colors.deepPurple],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.science, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Moderation Sampling',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Stratified random sampling for quality assurance',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_errorMessage',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSamplingData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_samplingData != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Card
                      Card(
                        elevation: 4,
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sampling Summary',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              _buildSummaryRow('Sampling Method', _samplingData!['sampling_method'] ?? 'N/A'),
                              _buildSummaryRow('Total Learners with POE', _samplingData!['total_learners_with_poe'].toString()),
                              _buildSummaryRow('Selected for Moderation', _samplingData!['selected_count'].toString()),
                              if (_samplingData!['sampling_rate'] != null)
                                _buildSummaryRow('Sampling Rate', _samplingData!['sampling_rate']),
                              if (_samplingData!['total_strata'] != null)
                                _buildSummaryRow('Total Strata', _samplingData!['total_strata'].toString()),
                              if (_samplingData!['is_existing_assignment'] == true)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'This is your existing assignment',
                                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // Stratification dimensions info
                              if (_samplingData!['stratification_dimensions'] != null) ...[
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text(
                                  'Stratification Dimensions:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                ...(_samplingData!['stratification_dimensions'] as List).map((dimension) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check, size: 16, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            dimension.toString(),
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Strata Summary (if available)
                      if (_samplingData!['strata_summary'] != null) ...[
                        const Text(
                          'Strata Breakdown',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Each row represents a unique combination of stratification dimensions',
                          style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 16,
                              headingRowColor: MaterialStateProperty.all(Colors.blue.shade100),
                              columns: const [
                                DataColumn(label: Text('Class', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Site', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('POE Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Marking', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Performance', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Selected', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: (_samplingData!['strata_summary'] as List).map<DataRow>((stratum) {
                                return DataRow(cells: [
                                  DataCell(Text(stratum['class'] ?? 'N/A')),
                                  DataCell(Text(stratum['site'] ?? 'N/A')),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getCompletenessColor(stratum['poe_completeness']),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        stratum['poe_completeness'] ?? 'N/A',
                                        style: const TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getMarkingColor(stratum['marking_status']),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        stratum['marking_status'] ?? 'N/A',
                                        style: const TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getPerformanceColor(stratum['performance_level']),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        stratum['performance_level'] ?? 'N/A',
                                        style: const TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(stratum['total_in_stratum'].toString())),
                                  DataCell(
                                    Text(
                                      stratum['selected_from_stratum'].toString(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                  ),
                                  DataCell(Text(stratum['sampling_rate'] ?? 'N/A')),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Learners List
                      const Text(
                        'Selected Learners',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 2,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 12,
                            headingRowColor: MaterialStateProperty.all(Colors.purple.shade50),
                            columns: const [
                              DataColumn(label: Text('Learner ID', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Surname', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Class ID', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Class Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Site', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('POE Status', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Marking', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Performance', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Unit Stds', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: (_samplingData!['learners'] as List).map<DataRow>((learner) {
                              return DataRow(cells: [
                                DataCell(Text(learner['LearnerID'].toString())),
                                DataCell(Text(learner['Name'] ?? 'N/A')),
                                DataCell(Text(learner['Surname'] ?? 'N/A')),
                                DataCell(Text(learner['classID']?.toString() ?? 'N/A')),
                                DataCell(Text(learner['className'] ?? 'N/A')),
                                DataCell(Text(learner['siteName'] ?? learner['siteID'] ?? 'N/A')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _getCompletenessColor(learner['poe_completeness']),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      learner['poe_completeness'] ?? 'Unknown',
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _getMarkingColor(learner['marking_status']),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      learner['marking_status'] ?? 'Unknown',
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _getPerformanceColor(learner['performance_level']),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      learner['performance_level'] ?? 'Unknown',
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    learner['unit_standards_count']?.toString() ?? '0',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataCell(
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ModeratorMarkingPage(
                                            learnerId: learner['LearnerID'].toString(),
                                            learnerFirstName: learner['Name'],
                                            learnerLastName: learner['Surname'],
                                            learnerIdNumber: learner['IDNumber'],
                                            moderatorId: widget.facilitatorId,
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    child: const Text('Moderate', style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ]);
                            }).toList(),
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

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Color _getPerformanceColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'high':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.red;
      case 'not assessed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getCompletenessColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'complete':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'incomplete':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getMarkingColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'marked':
        return Colors.blue;
      case 'unmarked':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}


// PDF Viewer for Scanned Pothole Checklist
class PotholeChecklistPDFViewer extends StatefulWidget {
  final String pdfUrl;
  final String documentPath;
  final String learnerId;
  final String assessmentDate;

  const PotholeChecklistPDFViewer({
    Key? key,
    required this.pdfUrl,
    required this.documentPath,
    required this.learnerId,
    required this.assessmentDate,
  }) : super(key: key);

  @override
  _PotholeChecklistPDFViewerState createState() => _PotholeChecklistPDFViewerState();
}

class _PotholeChecklistPDFViewerState extends State<PotholeChecklistPDFViewer> {
  String? localPath;
  bool isLoading = true;
  String? errorMessage;
  int? totalPages;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    _downloadAndOpenPDF();
  }

  Future<void> _downloadAndOpenPDF() async {
    try {
      print('DEBUG PDF: Downloading from ${widget.pdfUrl}');
      
      final response = await http.get(Uri.parse(widget.pdfUrl));
      
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/temp_pothole_checklist.pdf');
        
        await file.writeAsBytes(bytes);
        
        setState(() {
          localPath = file.path;
          isLoading = false;
        });
        
        print('DEBUG PDF: Downloaded to ${file.path}');
      } else {
        setState(() {
          errorMessage = 'Failed to download PDF: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      print('DEBUG PDF: Error downloading: $e');
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _openWithExternalApp() async {
    if (localPath != null) {
      final Uri fileUri = Uri.file(localPath!);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open PDF with external app')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pothole Checklist'),
        actions: [
          if (localPath != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open in external app',
              onPressed: _openWithExternalApp,
            ),
        ],
      ),
      body: Column(
        children: [
          // Document Info Card
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text(
                        'Scanned Document',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Learner ID: ${widget.learnerId}'),
                  Text('Assessment Date: ${widget.assessmentDate}'),
                  if (totalPages != null)
                    Text('Pages: $totalPages'),
                  if (currentPage > 0)
                    Text('Current Page: ${currentPage + 1}'),
                ],
              ),
            ),
          ),
          
          // PDF Viewer
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading PDF...'),
                      ],
                    ),
                  )
                : errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    isLoading = true;
                                    errorMessage = null;
                                  });
                                  _downloadAndOpenPDF();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : localPath != null
                        ? PDFView(
                            filePath: localPath!,
                            enableSwipe: true,
                            swipeHorizontal: false,
                            autoSpacing: true,
                            pageFling: true,
                            pageSnap: true,
                            onRender: (pages) {
                              setState(() {
                                totalPages = pages;
                              });
                            },
                            onPageChanged: (page, total) {
                              setState(() {
                                currentPage = page ?? 0;
                              });
                            },
                            onError: (error) {
                              print('DEBUG PDF: Error rendering: $error');
                              setState(() {
                                errorMessage = 'Error rendering PDF: $error';
                              });
                            },
                          )
                        : const Center(
                            child: Text('No PDF available'),
                          ),
          ),
        ],
      ),
    );
  }
}


// PDF Viewer for Learner Answers
class ModeratorPdfViewerScreen extends StatefulWidget {
  final String pdfUrl;

  const ModeratorPdfViewerScreen({Key? key, required this.pdfUrl}) : super(key: key);

  @override
  _ModeratorPdfViewerScreenState createState() => _ModeratorPdfViewerScreenState();
}

class _ModeratorPdfViewerScreenState extends State<ModeratorPdfViewerScreen> {
  String? _localPath;
  bool _isLoading = true;
  String? _error;
  int? _totalPages;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _downloadAndSavePdf();
  }

  Future<void> _downloadAndSavePdf() async {
    try {
      print('[PDF Viewer] Downloading from: ${widget.pdfUrl}');
      
      final response = await http.get(Uri.parse(widget.pdfUrl));
      
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final fileName = widget.pdfUrl.split('/').last;
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        
        setState(() {
          _localPath = file.path;
          _isLoading = false;
        });
        
        print('[PDF Viewer] Downloaded to: ${file.path}');
      } else {
        setState(() {
          _error = 'Failed to download PDF: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[PDF Viewer] Error: $e');
      setState(() {
        _error = 'Error downloading PDF: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openWithExternalApp() async {
    if (_localPath != null) {
      final Uri fileUri = Uri.file(_localPath!);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open PDF with external app')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learner Answer'),
        actions: [
          if (_localPath != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open in external app',
              onPressed: _openWithExternalApp,
            ),
        ],
      ),
      body: Column(
        children: [
          // Document Info Card
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Learner Submitted Answer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_totalPages != null)
                    Text('Total Pages: $_totalPages'),
                  if (_currentPage > 0)
                    Text('Current Page: ${_currentPage + 1}'),
                ],
              ),
            ),
          ),
          
          // PDF Viewer
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading PDF...'),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isLoading = true;
                                    _error = null;
                                  });
                                  _downloadAndSavePdf();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _localPath != null
                        ? PDFView(
                            filePath: _localPath!,
                            enableSwipe: true,
                            swipeHorizontal: false,
                            autoSpacing: true,
                            pageFling: true,
                            pageSnap: true,
                            onRender: (pages) {
                              setState(() {
                                _totalPages = pages;
                              });
                            },
                            onPageChanged: (page, total) {
                              setState(() {
                                _currentPage = page ?? 0;
                              });
                            },
                            onError: (error) {
                              print('[PDF Viewer] Error rendering: $error');
                              setState(() {
                                _error = 'Error rendering PDF: $error';
                              });
                            },
                          )
                        : const Center(child: Text('No PDF available')),
          ),
        ],
      ),
    );
  }
}


// PDF Viewer Page for Reports
class PdfViewerPage extends StatefulWidget {
  final String pdfPath;

  const PdfViewerPage({Key? key, required this.pdfPath}) : super(key: key);

  @override
  _PdfViewerPageState createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  int? totalPages;
  int currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Viewer'),
        actions: [
          if (totalPages != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Page ${currentPage + 1} of $totalPages',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      body: PDFView(
        filePath: widget.pdfPath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onRender: (pages) {
          setState(() {
            totalPages = pages;
          });
        },
        onPageChanged: (page, total) {
          setState(() {
            currentPage = page ?? 0;
          });
        },
        onError: (error) {
          print('PDF Error: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading PDF: $error')),
          );
        },
      ),
    );
  }
}

