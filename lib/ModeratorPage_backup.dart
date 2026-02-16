import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'DetailsPage.dart'; // Assuming this is where you navigate for class details
import 'package:url_launcher/url_launcher.dart'; // For opening URLs
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

  const PdfViewerPage({Key? key, required this.pdfPath}) : super(key: key);

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
                            color: MaterialStateColor.resolveWith((states) => rowColor),
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

  const ClassDetailsPage({required this.classId, Key? key}) : super(key: key);

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

                  return ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: learners.length,
                    itemBuilder: (context, index) {
                      var learnerData = learners[index];
                      String learnerId = learnerData['LearnerID'].toString();
                      String firstName = learnerData['Name'] ?? 'Unknown';
                      String lastName = learnerData['Surname'] ?? 'Unknown';
                      String idNumber = learnerData['IDNumber'] ?? 'Unknown';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          title: Text(
                            '$firstName $lastName',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('ID: $learnerId'),
                              Text('ID Number: $idNumber'),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AssessorMarkingPage(learnerId: learnerId),
                              ),
                            );
                          },
                        ),
                      );
                    },
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

class AssessorMarkingPage extends StatefulWidget {
  final String learnerId;

  const AssessorMarkingPage({required this.learnerId, Key? key}) : super(key: key);

  @override
  _AssessorMarkingPageState createState() => _AssessorMarkingPageState();
}

class _AssessorMarkingPageState extends State<AssessorMarkingPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _logbookExpanded = false;
  bool _potholeExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Marking'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(text: 'Learner Information'),
                Tab(text: 'POE Details'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Learner Information Tab
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Short Skills Programme',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  
                  // LogBook Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.book, color: Colors.blue),
                          ),
                          title: const Text(
                            'LogBook',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: Icon(
                            _logbookExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          ),
                          onTap: () {
                            setState(() {
                              _logbookExpanded = !_logbookExpanded;
                            });
                          },
                        ),
                        if (_logbookExpanded)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('LogBook content goes here'),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    // Navigate to logbook marking
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('View LogBook'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Pothole Checklist Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ListTile(
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
                          trailing: Icon(
                            _potholeExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          ),
                          onTap: () {
                            setState(() {
                              _potholeExpanded = !_potholeExpanded;
                            });
                          },
                        ),
                        if (_potholeExpanded)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pothole checklist content goes here'),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    // Navigate to pothole checklist
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('View Checklist'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // POE Details Tab
          const Center(
            child: Text('POE Details content goes here'),
          ),
        ],
      ),
    );
  }
}

// Placeholder for remaining code
class ModeratorPotholeChecklistPage extends StatelessWidget {
  final String facilitatorId;

  const ModeratorPotholeChecklistPage({Key? key, required this.facilitatorId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Moderator Pothole Checklist Page'),
    );
  }.toList(),
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
                    }).toList(),
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
              if (fileUrl != null && fileUrl.isNotEmpty) {
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


// Moderator Pothole Checklist Page
class ModeratorPotholeChecklistPage extends StatefulWidget {
  final String facilitatorId;

  const ModeratorPotholeChecklistPage({super.key, required this.facilitatorId});

  @override
  State<ModeratorPotholeChecklistPage> createState() => _ModeratorPotholeChecklistPageState();
}

class _ModeratorPotholeChecklistPageState extends State<ModeratorPotholeChecklistPage> {
  Future<List<dynamic>> _fetchClasses(String facilitatorId) async {
    final url = AppConfig.buildUrl('get_classes.php', queryParams: {
      'facilitator_id': facilitatorId,
    });
    
    print('[ModeratorPotholeChecklist] Fetching classes from: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
    );

    print('[ModeratorPotholeChecklist] Response Status: ${response.statusCode}');
    print('[ModeratorPotholeChecklist] Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data is Map && data['status'] == 'error') {
        throw Exception('Server error: ${data['message']}');
      }
      
      if (data is List) {
        return data;
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      throw Exception('Failed to load classes: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pothole Checklist - Moderation'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _fetchClasses(widget.facilitatorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No classes found.'));
          } else {
            List<dynamic> classes = snapshot.data!;

            return ListView.builder(
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final classData = classes[index];
                final classId = classData['classID']?.toString() ?? 'N/A';
                final className = classData['className']?.toString() ?? 'Unknown Class';
                final classDate = classData['classDate']?.toString() ?? '';
                final venue = classData['venue']?.toString() ?? '';

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(Icons.class_, color: Colors.blue),
                    title: Text(
                      className,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (classDate.isNotEmpty) Text('Date: $classDate'),
                        if (venue.isNotEmpty) Text('Venue: $venue'),
                        Text('Class ID: $classId'),
                      ],
                    ),
                    trailing: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ModeratorPotholeChecklistLearnerListPage(
                              facilitatorId: widget.facilitatorId,
                              classId: classId,
                              className: className,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Select'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

// Moderator Pothole Checklist Learner List Page
class ModeratorPotholeChecklistLearnerListPage extends StatefulWidget {
  final String facilitatorId;
  final String classId;
  final String className;

  const ModeratorPotholeChecklistLearnerListPage({
    super.key,
    required this.facilitatorId,
    required this.classId,
    required this.className,
  });

  @override
  State<ModeratorPotholeChecklistLearnerListPage> createState() => _ModeratorPotholeChecklistLearnerListPageState();
}

class _ModeratorPotholeChecklistLearnerListPageState extends State<ModeratorPotholeChecklistLearnerListPage> {
  Future<List<dynamic>> fetchLearners(String classId) async {
    final url = AppConfig.buildUrl('get_learners.php', queryParams: {
      'classID': classId,
    });
    
    print('[ModeratorPotholeChecklistLearnerList] Fetching learners from: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
    );

    print('[ModeratorPotholeChecklistLearnerList] Response Status: ${response.statusCode}');
    print('[ModeratorPotholeChecklistLearnerList] Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data is Map && data['status'] == 'error') {
        throw Exception('Server error: ${data['message']}');
      }
      
      if (data is List) {
        return data;
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      throw Exception('Failed to load learners: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> _checkPotholeChecklistMarks(String learnerId) async {
    try {
      final assessmentDate = DateTime.now().toIso8601String().split('T').first;
      
      // Check server for marks
      try {
        final response = await http.get(Uri.parse(
          '${AppConfig.baseUrl}/get_pothole_checklist_marks.php?learner_id=$learnerId&assessment_date=$assessmentDate'
        )).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success' && data['data'] != null) {
            return {
              'hasMarks': true,
              'marks': data['data']['marks'],
              'comments': data['data']['comments'] ?? '',
              'approval_status': data['data']['approval_status'],
              'moderator_comment': data['data']['comment'] ?? '',
            };
          }
        }
      } catch (e) {
        print('Server check failed: $e');
      }
      
      return {
        'hasMarks': false,
      };
    } catch (e) {
      print('Error checking marks: $e');
      return {
        'hasMarks': false,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pothole Checklist - ${widget.className}'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: fetchLearners(widget.classId),
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
                    String idNumber = learnerData['IDNumber']?.toString() ?? 'N/A';

                    return DataRow(
                      cells: [
                        DataCell(Text(learnerId)),
                        DataCell(Text(firstName)),
                        DataCell(Text(lastName)),
                        DataCell(Text(idNumber)),
                        DataCell(
                          FutureBuilder<Map<String, dynamic>>(
                            future: _checkPotholeChecklistMarks(learnerId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return ElevatedButton(
                                  onPressed: null,
                                  child: const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              }

                              final hasMarks = snapshot.data?['hasMarks'] == true;
                              final approvalStatus = snapshot.data?['approval_status'];
                              
                              String buttonLabel;
                              Color buttonColor;
                              IconData buttonIcon;
                              
                              if (hasMarks) {
                                if (approvalStatus != null && approvalStatus.isNotEmpty) {
                                  buttonLabel = 'View ($approvalStatus)';
                                  buttonColor = approvalStatus == 'Approved' ? Colors.green : Colors.red;
                                  buttonIcon = approvalStatus == 'Approved' ? Icons.check_circle : Icons.cancel;
                                } else {
                                  buttonLabel = 'Moderate';
                                  buttonColor = Colors.orange;
                                  buttonIcon = Icons.rate_review;
                                }
                              } else {
                                buttonLabel = 'No Marks';
                                buttonColor = Colors.grey;
                                buttonIcon = Icons.info_outline;
                              }

                              return ElevatedButton.icon(
                                onPressed: hasMarks ? () async {
                                  // Fetch complete checklist data
                                  final assessmentDate = DateTime.now().toIso8601String().split('T').first;
                                  try {
                                    final response = await http.get(Uri.parse(
                                      '${AppConfig.baseUrl}/view_pothole_checklists.php?learner_id=$learnerId&assessment_date=$assessmentDate'
                                    ));
                                    
                                    if (response.statusCode == 200) {
                                      final data = jsonDecode(response.body);
                                      if (data['status'] == 'success' && data['data'] != null) {
                                        // Navigate to full checklist view for moderation
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ModeratorPotholeChecklistViewPage(
                                              checklistData: data['data'],
                                              learnerId: learnerId,
                                              marksData: snapshot.data!,
                                              facilitatorId: widget.facilitatorId,
                                            ),
                                          ),
                                        ).then((_) => setState(() {})); // Refresh on return
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('No checklist data found')),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error loading checklist: $e')),
                                    );
                                  }
                                } : null,
                                icon: Icon(buttonIcon, size: 16),
                                label: Text(buttonLabel),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: buttonColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
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

// Moderator Pothole Checklist View Page - Shows full checklist with marks for moderation
class ModeratorPotholeChecklistViewPage extends StatefulWidget {
  final Map<String, dynamic> checklistData;
  final String learnerId;
  final Map<String, dynamic> marksData;
  final String facilitatorId;

  const ModeratorPotholeChecklistViewPage({
    super.key,
    required this.checklistData,
    required this.learnerId,
    required this.marksData,
    required this.facilitatorId,
  });

  @override
  State<ModeratorPotholeChecklistViewPage> createState() => _ModeratorPotholeChecklistViewPageState();
}

class _ModeratorPotholeChecklistViewPageState extends State<ModeratorPotholeChecklistViewPage> {
  final TextEditingController _moderatorCommentController = TextEditingController();
  String? _selectedDecision; // "Uphold" or "Withdraw"
  bool _isSaving = false;
  bool _isLoading = false;
  
  // LogBook unit standards
  List<Map<String, dynamic>> _logbookUnitStandards = [];
  Map<String, int> _logbookMarks = {};
  bool _isLoadingLogbook = false;
  
  // Pothole evidence images
  List<Map<String, dynamic>> _potholeImages = [];
  bool _isLoadingImages = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill if already moderated
    final approvalStatus = widget.marksData['approval_status'];
    if (approvalStatus == 'Approved') {
      _selectedDecision = 'Uphold';
    } else if (approvalStatus == 'Disapproved') {
      _selectedDecision = 'Withdraw';
    }
    _moderatorCommentController.text = widget.marksData['moderator_comment'] ?? '';
    
    _loadLogbookUnitStandards();
    _loadPotholeImages();
  }
  
  Future<void> _loadPotholeImages() async {
    setState(() => _isLoadingImages = true);
    
    try {
      final url = '${AppConfig.baseUrl}/get_pothole_images.php?learner_id=${widget.learnerId}';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _potholeImages = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
        }
      }
    } catch (e) {
      print('Error loading pothole images: $e');
    } finally {
      setState(() => _isLoadingImages = false);
    }
  }

  Future<void> _loadLogbookUnitStandards() async {
    setState(() => _isLoadingLogbook = true);
    
    try {
      final response = await http.get(Uri.parse(
        '${AppConfig.baseUrl}/get_logbook_unit_standards.php?learner_id=${widget.learnerId}'
      ));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _logbookUnitStandards = List<Map<String, dynamic>>.from(data['data']);
          });
          
          await _loadLogbookMarks();
        }
      }
    } catch (e) {
      print('Error loading logbook unit standards: $e');
    } finally {
      setState(() => _isLoadingLogbook = false);
    }
  }

  Future<void> _loadLogbookMarks() async {
    try {
      final assessmentDate = widget.checklistData['assessment_date'] ?? DateTime.now().toIso8601String().split('T').first;
      final assessorId = widget.checklistData['assessor_id'] ?? '';
      
      final response = await http.get(Uri.parse(
        '${AppConfig.baseUrl}/get_logbook_marks.php?learner_id=${widget.learnerId}&assessor_id=$assessorId&assessment_date=$assessmentDate'
      ));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final marks = data['data'] as Map<String, dynamic>;
          
          setState(() {
            _logbookMarks = marks.map((key, value) => MapEntry(key, value as int));
          });
        }
      }
    } catch (e) {
      print('Error loading logbook marks: $e');
    }
  }

  Future<void> _saveModeration() async {
    if (_selectedDecision == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Uphold or Withdraw'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedDecision == 'Withdraw' && _moderatorCommentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a comment when withdrawing'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final assessmentDate = DateTime.now().toIso8601String().split('T').first;
      
      // Map Uphold/Withdraw to Approved/Disapproved
      final approvalStatus = _selectedDecision == 'Uphold' ? 'Approved' : 'Disapproved';

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/save_pothole_moderation.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learner_id': widget.learnerId,
          'assessment_date': assessmentDate,
          'approval_status': approvalStatus,
          'comment': _moderatorCommentController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Moderation saved: $_selectedDecision'), backgroundColor: Colors.green),
          );
          Navigator.pop(context); // Go back after saving
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving moderation: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.checklistData['checklist_items'] as Map<String, dynamic>? ?? {};
    final marks = widget.marksData['marks'];
    final assessorComments = widget.marksData['comments'] ?? '';
    final hasExistingModeration = widget.marksData['approval_status'] != null && 
                                   widget.marksData['approval_status'].toString().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pothole Checklist - Moderation'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Learner Information',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Learner', widget.checklistData['learner_name'] ?? 'N/A'),
                          _buildInfoRow('ID Number', widget.checklistData['learner_id_number'] ?? 'N/A'),
                          _buildInfoRow('Assessor', widget.checklistData['assessor_name'] ?? 'N/A'),
                          _buildInfoRow('Venue', widget.checklistData['venue'] ?? 'N/A'),
                          _buildInfoRow('Date', widget.checklistData['assessment_date'] ?? 'N/A'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Checklist Items
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assessment Criteria',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          const SizedBox(height: 16),
                          ...items.entries.map((section) {
                            return _buildSection(section.key, section.value as List);
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Pothole Checklist Marks
                  Card(
                    elevation: 4,
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.assessment, color: Colors.green.shade700, size: 24),
                              const SizedBox(width: 12),
                              const Text(
                                'Pothole Checklist Marks',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Marks', '$marks / 100'),
                          if (assessorComments.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow('Assessor Comments', assessorComments),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // LogBook Unit Standards Section  
                  if (_isLoadingLogbook)
                    const Center(child: CircularProgressIndicator())
                  else if (_logbookUnitStandards.isNotEmpty)
                    Card(
                      elevation: 4,
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.book, color: Colors.orange.shade700, size: 24),
                                const SizedBox(width: 12),
                                const Text(
                                  'LogBook Unit Standards',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ..._logbookUnitStandards.map((us) {
                              final unitStandardId = us['unit_standard_id'];
                              final mark = _logbookMarks[unitStandardId] ?? 0;
                              final specificOutcomes = us['specific_outcomes'] as List<dynamic>? ?? [];
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        us['unit_standard_name'] ?? 'N/A',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      
                                      // Specific Outcomes
                                      if (specificOutcomes.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Specific Outcomes:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              ...specificOutcomes.map((outcome) {
                                                final outcomeText = outcome['outcome_text']?.toString() ?? '';
                                                if (outcomeText.isEmpty) return const SizedBox.shrink();
                                                
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 6),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('• ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                                      Expanded(
                                                        child: Text(
                                                          outcomeText,
                                                          style: const TextStyle(fontSize: 13, height: 1.3),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ],
                                          ),
                                        ),
                                      ],
                                      
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.star, color: Colors.orange.shade700, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Mark: $mark / 50',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Pothole Evidence Images Section
                  if (_isLoadingImages)
                    const Center(child: CircularProgressIndicator())
                  else if (_potholeImages.isNotEmpty)
                    Card(
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
                                final imageUrl = 'https://rlms.rlms.co.za/mobile/${image['file_path']}';
                                
                                return GestureDetector(
                                  onTap: () {
                                    // Show full image
                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        backgroundColor: Colors.black,
                                        child: InteractiveViewer(
                                          child: Image.network(imageUrl),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Card(
                                    elevation: 2,
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Center(
                                                child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                              );
                                            },
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return const Center(child: CircularProgressIndicator());
                                            },
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Text(
                                            'Image ${index + 1}',
                                            style: const TextStyle(fontSize: 10),
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
                    ),

                  const SizedBox(height: 16),

                  // Moderation Decision Section
                  Card(
                    elevation: 4,
                    color: hasExistingModeration ? Colors.blue.shade50 : Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                hasExistingModeration ? Icons.check_circle : Icons.rate_review,
                                color: hasExistingModeration ? Colors.blue.shade700 : Colors.orange.shade700,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                hasExistingModeration ? 'Moderation Complete' : 'Moderation Decision',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: hasExistingModeration ? Colors.blue : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (hasExistingModeration) ...[
                            // Show existing moderation
                            _buildInfoRow('Decision', _selectedDecision ?? 'N/A'),
                            if (widget.marksData['moderator_comment'] != null && 
                                widget.marksData['moderator_comment'].toString().isNotEmpty)
                              _buildInfoRow('Moderator Comment', widget.marksData['moderator_comment']),
                          ] else ...[
                            // Moderation form
                            const Text(
                              'Decision',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              value: _selectedDecision,
                              items: ['Uphold', 'Withdraw'].map((decision) {
                                return DropdownMenuItem<String>(
                                  value: decision,
                                  child: Row(
                                    children: [
                                      Icon(
                                        decision == 'Uphold' ? Icons.check_circle : Icons.cancel,
                                        color: decision == 'Uphold' ? Colors.green : Colors.red,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(decision),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: _isSaving ? null : (value) {
                                setState(() {
                                  _selectedDecision = value;
                                });
                              },
                              hint: const Text('Select Uphold or Withdraw'),
                            ),

                            const SizedBox(height: 16),

                            const Text(
                              'Moderator Comment',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _moderatorCommentController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Enter your comments (required when withdrawing)',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              maxLines: 4,
                              enabled: !_isSaving,
                            ),

                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveModeration,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(_isSaving ? 'Saving...' : 'Save Decision'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String sectionName, List items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              sectionName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map<Widget>((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['label'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            item['value'] == true ? Icons.check_circle : Icons.cancel,
                            color: item['value'] == true ? Colors.green : Colors.red,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item['value'] == true ? 'YES' : 'NO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: item['value'] == true ? Colors.green : Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.note, size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item['notes'].toString(),
                                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _moderatorCommentController.dispose();
    super.dispose();
  }
}
