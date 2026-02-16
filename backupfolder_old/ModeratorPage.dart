import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// Assuming this is where you navigate for class details
import 'package:url_launcher/url_launcher.dart'; // For opening URLs
import 'package:shared_preferences/shared_preferences.dart';

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
              },
            ),
          ],
        ),
      ),
      body: _buildContent(),
    );
  }
}
class ModerationFeedbackPage extends StatefulWidget {
  final String facilitatorId;

  const ModerationFeedbackPage({super.key, required this.facilitatorId});

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
          return data['data']; // Return the list of classes
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
      print('Response Headers: ${response.headers}');
      print('Response Body (first 100 chars): ${response.body.substring(0, response.body.length < 100 ? response.body.length : 100)}');

      if (response.statusCode == 200) {
        if (response.headers['content-type']?.contains('application/pdf') == true) {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/Class_${classId}_Report.pdf');
          await file.writeAsBytes(response.bodyBytes);

          // Open the PDF in a new screen
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
      appBar: AppBar(
        title: const Text('Class List'),
        backgroundColor: Colors.blue,
      ),
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
                  'Class List',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Moderator ID: ${widget.facilitatorId}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
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

class PdfViewerPage extends StatelessWidget {
  final String pdfPath;

  const PdfViewerPage({super.key, required this.pdfPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Report'),
      ),
      body: PDFView(
        filePath: pdfPath,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: true,
        pageFling: true,
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading PDF: $error')),
          );
        },
        onPageError: (page, error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error on page $page: $error')),
          );
        },
      ),
    );
  }
}
class ModerationReportPage extends StatefulWidget {
  final String facilitatorId;

  const ModerationReportPage({super.key, required this.facilitatorId});

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
    // Alternative for emulator: final url = Uri.parse('http://10.0.2.2/New/Lito/mobile/moderationReport.php?learner_id=$learnerId');

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

  Color _getRowColor(dynamic learnerData) {
    // Add your logic to determine row color based on learnerData
    return Colors.white; // Default color
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: FutureBuilder<List<dynamic>>(
        future: fetchModerationReport(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No data found'));
          } else {
            classes = snapshot.data!;
            return Column(
              children: [
                SingleChildScrollView(
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
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _onActionPressed(classId),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (showLearnersTable)
                  SingleChildScrollView(
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
                          Color rowColor = _getRowColor(learnerData);

                          return DataRow(
                            color: WidgetStateColor.resolveWith((states) => rowColor),
                            cells: [
                              DataCell(Text(learnerId)),
                              DataCell(Text(firstName)),
                              DataCell(Text(lastName)),
                              DataCell(Text(idNumber)),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _generateAndViewReport(learnerId),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            );
          }
        },
      ),
    );
  }
}
class ClassDetailsPage extends StatefulWidget {
  final String classId;

  const ClassDetailsPage({required this.classId, super.key});

  @override
  _ClassDetailsPageState createState() => _ClassDetailsPageState();
}

class _ClassDetailsPageState extends State<ClassDetailsPage> {
  late Future<List<dynamic>> _learners;
  List<dynamic> _allLearners = [];
  List<dynamic> _selectedLearners = [];
  bool _isSelectionMade = false;

  @override
  void initState() {
    super.initState();
    _learners = fetchLearners(widget.classId);
    _loadSelectionState(); // Load previous selection
  }

  Future<void> _loadSelectionState() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedLearnerIds = prefs.getStringList('selectedLearners_${widget.classId}');

    if (selectedLearnerIds != null && selectedLearnerIds.isNotEmpty) {
      setState(() {
        _isSelectionMade = true;
        _selectedLearners = _allLearners
            .where((learner) => selectedLearnerIds.contains(learner['LearnerID'].toString()))
            .toList();
      });
    }
  }

  Future<void> _saveSelectionState() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedLearnerIds = _selectedLearners.map((learner) => learner['LearnerID'].toString()).toList();
    await prefs.setStringList('selectedLearners_${widget.classId}', selectedLearnerIds);
  }

  Future<List<dynamic>> fetchLearners(String classId) async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl('get_learners.php?classID=$classId')),
      );

      print('Response Body (get_learners): ${response.body}');

      if (response.statusCode == 200) {
        List<dynamic> learners = jsonDecode(response.body);
        setState(() {
          _allLearners = learners;
          if (!_isSelectionMade) {
            _selectedLearners = learners; // Initially show all learners
          }
        });
        // After fetching learners, filter them if a selection was previously made
        if (_isSelectionMade) {
          final prefs = await SharedPreferences.getInstance();
          final selectedLearnerIds = prefs.getStringList('selectedLearners_${widget.classId}');
          if (selectedLearnerIds != null) {
            _selectedLearners = _allLearners
                .where((learner) => selectedLearnerIds.contains(learner['LearnerID'].toString()))
                .toList();
          }
        }
        return learners;
      } else {
        throw Exception('Failed to load learners. Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load learners. Error: $e');
    }
  }

  void _selectRandomLearners() {
    setState(() {
      int totalLearners = _allLearners.length;
      int selectionCount = (totalLearners * 0.3).ceil(); // 30% of learners
      List<dynamic> tempList = List.from(_allLearners);
      tempList.shuffle();
      _selectedLearners = tempList.take(selectionCount).toList();
      _isSelectionMade = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected $selectionCount learners for marking.')),
      );
    });
    _saveSelectionState(); // Save the selection
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Class Details - ${widget.classId}')),
      body: Column(
        children: [
          if (!_isSelectionMade) // Show button only before selection
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: _allLearners.isEmpty ? null : _selectRandomLearners,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Select 30% of Learners for Marking'),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _learners,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No learners found.'));
                } else {
                  List<dynamic> learners = _isSelectionMade ? _selectedLearners : _allLearners;

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
                                      builder: (context) => AssessorMarkingPage(learnerId: learnerId),
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
          ),
        ],
      ),
    );
  }
}

// AssessorMarkingPage and other classes remain unchanged
class AssessorMarkingPage extends StatelessWidget {
  final String learnerId;

  const AssessorMarkingPage({super.key, required this.learnerId});

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
              Tab(text: 'POE'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            LearnerInformationTab(learnerId: learnerId),
            POETab(learnerId: learnerId),
          ],
        ),
      ),
    );
  }
}

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
class POETab extends StatefulWidget {
  final String learnerId;

  const POETab({super.key, required this.learnerId});

  @override
  _POETabState createState() => _POETabState();
}
class _POETabState extends State<POETab> {
  late Future<Map<String, dynamic>> _poeData;
  String _responseMessage = '';

  @override
  void initState() {
    super.initState();
    _poeData = fetchPOE(widget.learnerId);
  }

  Future<Map<String, dynamic>> fetchPOE(String learnerId) async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl('get_m_poe.php?learnerId=$learnerId')),
      );

      print('Response Body (get_m_poe): ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load POE data. Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load POE data. Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POE Details')),
      body: Column(
        children: [
          FutureBuilder<Map<String, dynamic>>(
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
              Map<String, dynamic> logbook = poeData['logbook'] ?? {};

              return Expanded(
                child: ListView(
                  children: [
                    ...pathways.entries.map((entry) {
                      return ExpansionTile(
                        title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                        children: _buildQualificationTiles(entry.value),
                      );
                    }),
                    if (logbook.isNotEmpty)
                      ExpansionTile(
                        title: const Text('Logbook', style: TextStyle(fontWeight: FontWeight.bold)),
                        children: _buildLogbookTiles(logbook),
                      ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _responseMessage,
              style: TextStyle(
                color: _responseMessage.contains('success') ? Colors.green : Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQualificationTiles(Map<String, dynamic> pathwayData) {
    Map<String, dynamic> qualifications = pathwayData['qualifications'] ?? {};

    return qualifications.entries.map((entry) {
      return ExpansionTile(
        title: Text(entry.key),
        children: _buildUnitStandardTiles(entry.value),
      );
    }).toList();
  }

  List<Widget> _buildUnitStandardTiles(Map<String, dynamic> qualificationData) {
    Map<String, dynamic> unitStandards = qualificationData['unitstandards'] ?? {};

    return unitStandards.entries.map((entry) {
      return ExpansionTile(
        title: Text(entry.key),
        children: _buildAssessmentTypeTiles(entry.value),
      );
    }).toList();
  }

  List<Widget> _buildAssessmentTypeTiles(Map<String, dynamic> unitStandardData) {
    List<dynamic> summative = unitStandardData['summative'] ?? [];
    List<dynamic> formative = unitStandardData['formative'] ?? [];

    List<Widget> assessmentTiles = [];

    if (summative.isNotEmpty) {
      String existingModeratorComment = summative.first['comment'] ?? '';
      bool hasExistingComment = existingModeratorComment.isNotEmpty;

      TextEditingController moderatorCommentController = TextEditingController(text: existingModeratorComment);

      assessmentTiles.add(
        ExpansionTile(
          title: const Text('Formative'),
          children: [
            ..._buildExerciseTiles(summative, 'formative'),
            if (!hasExistingComment)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextFormField(
                  controller: moderatorCommentController,
                  decoration: const InputDecoration(
                    labelText: 'Moderator Comments',
                    border: OutlineInputBorder(),
                    hintText: 'Enter your comments for summative assessments',
                  ),
                  maxLines: 3,
                ),
              ),
            if (!hasExistingComment)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton(
                  onPressed: () => saveModeratorComment('summative', moderatorCommentController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit Moderator Comment'),
                ),
              ),
            if (hasExistingComment)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Moderator Comments: $existingModeratorComment',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
      );
    }

    if (formative.isNotEmpty) {
      String existingModeratorComment = formative.first['comment'] ?? '';
      bool hasExistingComment = existingModeratorComment.isNotEmpty;

      TextEditingController moderatorCommentController = TextEditingController(text: existingModeratorComment);

      assessmentTiles.add(
        ExpansionTile(
          title: const Text('Summative'),
          children: [
            ..._buildExerciseTiles(formative, 'summative'),
            if (!hasExistingComment)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextFormField(
                  controller: moderatorCommentController,
                  decoration: const InputDecoration(
                    labelText: 'Moderator Comments',
                    border: OutlineInputBorder(),
                    hintText: 'Enter your comments for formative assessments',
                  ),
                  maxLines: 3,
                ),
              ),
            if (!hasExistingComment)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton(
                  onPressed: () => saveModeratorComment('formative', moderatorCommentController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit Moderator Comment'),
                ),
              ),
            if (hasExistingComment)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Moderator Comments: $existingModeratorComment',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
      );
    }

    return assessmentTiles;
  }

  List<Widget> _buildLogbookTiles(Map<String, dynamic> logbookData) {
    return logbookData.entries.map<Widget>((entry) {
      String unitStandardName = entry.key;
      List<dynamic> exercises = entry.value;

      return ExpansionTile(
        title: Text(unitStandardName),
        children: _buildExerciseTiles(exercises, 'logbook'),
      );
    }).toList();
  }

  List<Widget> _buildExerciseTiles(List<dynamic> exercises, String assessmentType) {
    return exercises.map<Widget>((exercise) {
      return ExerciseTile(
        key: ValueKey(exercise['exercise_id'] ?? exercise['exercise']),
        exercise: exercise,
        learnerId: widget.learnerId,
        assessmentType: assessmentType,
        onLaunch: launchFile,
        onResponseMessage: (message) {
          setState(() {
            _responseMessage = message;
          });
        },
        onSaveApprovalStatus: (status) {
          final exerciseId = exercise['exercise_id']?.toString() ?? exercise['exercise']?.toString() ?? '';
          print('Exercise data being sent for approval: $exercise');
          saveApprovalStatus(exerciseId, status);
        },
      );
    }).toList();
  }

  Future<void> saveModeratorComment(String assessmentType, String comment) async {
    if (comment.trim().isEmpty) {
      setState(() {
        _responseMessage = 'Comment cannot be empty';
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(AppConfig.buildUrl('m_comment.php')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learnerId': widget.learnerId,
          'assessmentType': assessmentType,
          'm_comment': comment,
        }),
      );

      print("Raw response (save_comment): ${response.body}");
      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        setState(() {
          _responseMessage = responseData['status'] == 'success'
              ? 'Moderator comment saved successfully!'
              : 'Failed to save moderator comment: ${responseData['message']}';
        });
        if (responseData['status'] == 'success') {
          _poeData = fetchPOE(widget.learnerId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comment saved successfully!')),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: Text(responseData['message']),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        setState(() {
          _responseMessage = 'Server error: ${response.statusCode}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() {
        _responseMessage = 'Error saving moderator comment: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> saveApprovalStatus(String exerciseId, String approvalStatus) async {
    if (exerciseId.isEmpty) {
      setState(() {
        _responseMessage = 'Exercise ID is missing';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise ID is missing')),
      );
      return;
    }

    try {
      final payload = {
        'learnerId': widget.learnerId,
        'exerciseId': exerciseId,
        'moderation_status': approvalStatus,
      };
      print('Sending payload to save_moderation_status: $payload');

      final response = await http.post(
        Uri.parse(AppConfig.buildUrl('save_moderation_status.php')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print("Raw response (save_approval_status): ${response.body}");
      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        setState(() {
          _responseMessage = responseData['status'] == 'success'
              ? 'Success: Approval status saved!'
              : responseData['message'].contains('No record found')
              ? 'Error: Exercise not found in database.'
              : 'Failed to save approval: ${responseData['message']}';
        });
        if (responseData['status'] == 'success') {
          _poeData = fetchPOE(widget.learnerId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Approval status saved!')),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: Text(
                responseData['message'].contains('No record found')
                    ? 'Exercise "$exerciseId" not found for learner ID ${widget.learnerId}. Verify or contact support.'
                    : responseData['message'],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        setState(() {
          _responseMessage = 'Server error: ${response.statusCode}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() {
        _responseMessage = 'Error saving approval status: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> launchFile(String url) async {
    if (url.isEmpty) {
      setState(() {
        _responseMessage = 'File URL is empty';
      });
      return;
    }

    final fileExtension = url.split('.').last.toLowerCase();
    if (fileExtension == 'pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FileViewerScreen(fileUrl: url, isPdf: true),
        ),
      );
    } else if (fileExtension == 'jpg' || fileExtension == 'jpeg' || fileExtension == 'png') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FileViewerScreen(fileUrl: url, isPdf: false),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unsupported file type')),
      );
    }
  }
}
class ExerciseTile extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final String learnerId;
  final String assessmentType;
  final Function(String) onLaunch;
  final Function(String) onResponseMessage;
  final Function(String) onSaveApprovalStatus;

  const ExerciseTile({
    super.key,
    required this.exercise,
    required this.learnerId,
    required this.assessmentType,
    required this.onLaunch,
    required this.onResponseMessage,
    required this.onSaveApprovalStatus,
  });

  @override
  _ExerciseTileState createState() => _ExerciseTileState();
}

class _ExerciseTileState extends State<ExerciseTile> {
  String? _selectedApprovalStatus;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedApprovalStatus = null; // Initialize as null for dropdown
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exercise['filePath'] == null || widget.exercise['filePath'].isEmpty) {
      return const SizedBox.shrink();
    }

    String maxMarks = widget.exercise['marks']?.toString() ?? '0';
    String marksScored = widget.exercise['marks_scored']?.toString() ?? 'Not Scored';
    String specificOutcome = widget.exercise['specific_outcome']?.toString() ?? 'N/A';
    String specificOutcomeLabel = 'SO: $specificOutcome';
    String displayTitle = 'Exercise: ${widget.exercise['exercise'] ?? 'N/A'}';
    String? currentApprovalStatus = widget.exercise['approval_status']?.toString();
    bool hasApprovalStatus = currentApprovalStatus != null && currentApprovalStatus.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text('$displayTitle ($specificOutcomeLabel)'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Marks: $marksScored/$maxMarks'),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: hasApprovalStatus
                    ? Text('Approval Status: $currentApprovalStatus')
                    : DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Approval Status',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedApprovalStatus,
                  items: ['Uphold', 'Withdraw'].map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                    setState(() {
                      _selectedApprovalStatus = value;
                    });
                  },
                  hint: const Text('Select approval status'),
                ),
              ),
            ],
          ),
          trailing: ElevatedButton(
            onPressed: () {
              String fileUrl = widget.exercise['fileUrl'] ?? widget.exercise['filePath'];
              if (fileUrl.isNotEmpty) {
                widget.onLaunch(fileUrl);
              } else {
                widget.onResponseMessage('File URL is missing or invalid');
              }
            },
            child: const Text('View File'),
          ),
        ),
        if (!hasApprovalStatus)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton(
              onPressed: _isSubmitting || _selectedApprovalStatus == null
                  ? null
                  : () async {
                setState(() {
                  _isSubmitting = true;
                });
                await widget.onSaveApprovalStatus(_selectedApprovalStatus!);
                setState(() {
                  _isSubmitting = false;
                  _selectedApprovalStatus = null; // Reset dropdown
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text('Submit Approval Status'),
            ),
          ),
      ],
    );
  }
}

class FileViewerScreen extends StatefulWidget {
  final String fileUrl;
  final bool isPdf;

  const FileViewerScreen({super.key, required this.fileUrl, required this.isPdf});

  @override
  _FileViewerScreenState createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  File? _tempFile;

  @override
  void dispose() {
    if (_tempFile != null) {
      _tempFile!.delete();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPdf ? 'PDF Viewer' : 'Image Viewer'),
      ),
      body: Center(
        child: widget.isPdf
            ? FutureBuilder<File>(
          future: _loadPdfFromNetwork(widget.fileUrl),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error loading PDF: ${snapshot.error}');
            } else if (!snapshot.hasData) {
              return const Text('No PDF data available');
            }
            _tempFile = snapshot.data;
            return PDFView(
              filePath: snapshot.data!.path,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageSnap: true,
              pageFling: true,
            );
          },
        )
            : Image.network(
          widget.fileUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const CircularProgressIndicator();
          },
          errorBuilder: (context, error, stackTrace) {
            return const Text('Error loading image');
          },
        ),
      ),
    );
  }

  Future<File> _loadPdfFromNetwork(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load PDF: ${response.statusCode}');
    }
    final bytes = response.bodyBytes;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/temp.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}