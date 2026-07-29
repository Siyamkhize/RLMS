import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:signature/signature.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'PotholeChecklistPage.dart';
import 'database_helper.dart';
import 'config.dart';
import 'utils/scanner_pdf_resolver.dart';
import 'ArplClassDetailsPage.dart';
import 'ArplAssessorMarkingPage.dart';
import 'ArplHierarchicalNavigatorPage.dart';
import 'ArplToolkitRouter.dart';
import 'arpl_assessor_clocking_page.dart';

class ArplAssessorPage extends StatefulWidget {
  final String facilitator_id;

  const ArplAssessorPage({super.key, required this.facilitator_id});

  @override
  _ArplAssessorPageState createState() => _ArplAssessorPageState();
}

class _ArplAssessorPageState extends State<ArplAssessorPage> {
  late Future<List<dynamic>> _classes;
  int _selectedIndex = 0;
  String? _pathwayType; // Store 'ARPL' or other pathway types
  String? _ofoNumber; // Store OFO code for ARPL assessor

  @override
  void initState() {
    super.initState();
    print('[ArplAssessorPage] ===== INITIALIZATION =====');
    print('[ArplAssessorPage] Facilitator ID: ${widget.facilitator_id}');
    print('[ArplAssessorPage] Starting fetchClasses...');
    _classes = fetchClasses(widget.facilitator_id);
  }

  Future<String> _getFacilitatorName() async {
    try {
      final db = await DatabaseHelper().database;
      final result = await db.query(
        'facilitator',
        where: 'facilitator_id = ?',
        whereArgs: [widget.facilitator_id],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final firstName = result.first['firstName'] ?? '';
        final lastName = result.first['lastName'] ?? '';
        return '$firstName $lastName'.trim();
      }
      return 'Assessor';
    } catch (e) {
      print('[ArplAssessorPage] Error fetching facilitator name: $e');
      return 'Assessor';
    }
  }

  Future<List<dynamic>> fetchClasses(String facilitatorId) async {
    try {
      final url = AppConfig.buildUrl('get_classes.php', queryParams: {
        'facilitator_id': facilitatorId,
      });

      print('[ArplAssessorPage] Fetching classes from: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is Map && data['status'] == 'error') {
          throw Exception('Server error: ${data['message']}');
        }

        if (data is List) {
          // Detect pathway type from the first class (if available)
          if (data.isNotEmpty) {
            setState(() {
              // Check both possible keys: Project_pathway (from mobile/get_classes.php)
              // and learning_pathway (from root get_classes.php)
              String pathway =
                  (data[0]['Project_pathway'] ?? data[0]['learning_pathway'])
                          ?.toString()
                          .toUpperCase() ??
                      '';

              print(
                  '[ArplAssessorPage] DEBUG: Raw pathway from data: "${data[0]['Project_pathway']}"');
              print('[ArplAssessorPage] DEBUG: Uppercased pathway: "$pathway"');

              // Try to parse OFO code from Project_pathway JSON
              try {
                String rawPathway =
                    data[0]['Project_pathway']?.toString() ?? '';
                if (rawPathway.isNotEmpty && rawPathway.startsWith('[')) {
                  // Parse as JSON array
                  List<dynamic> pathwayList = jsonDecode(rawPathway);
                  if (pathwayList.isNotEmpty &&
                      pathwayList[0]['ofo_code'] != null) {
                    _ofoNumber = pathwayList[0]['ofo_code'].toString();
                    print('[ArplAssessorPage] Extracted OFO Code: $_ofoNumber');
                  }
                }
              } catch (e) {
                print('[ArplAssessorPage] Could not parse OFO code: $e');
              }

              // Check for ARPL detection in multiple formats:
              // 1. Full JSON format: [{"type":"ARPL",...}]
              // 2. Trade names (these are ARPL trades): ELECTRICIAN, BRICKLAYING, BRICKLAYER, PLUMBING, PLUMBER, ELECTRICITY
              // Note: pathway is already uppercased, so we check against uppercase keywords
              bool isARPL = pathway.contains('ARPL') ||
                  pathway.contains('ELECTRICIAN') ||
                  pathway.contains('BRICKLAYING') ||
                  pathway.contains('BRICKLAYER') ||
                  pathway.contains('PLUMBING') ||
                  pathway.contains('PLUMBER') ||
                  pathway.contains('ELECTRICITY');

              print('[ArplAssessorPage] DEBUG: isARPL check result: $isARPL');
              print(
                  '[ArplAssessorPage] DEBUG: Contains ARPL? ${pathway.contains('ARPL')}');
              print(
                  '[ArplAssessorPage] DEBUG: Contains BRICKLAYER? ${pathway.contains('BRICKLAYER')}');

              if (isARPL) {
                _pathwayType = 'ARPL';
              } else {
                _pathwayType = pathway;
              }

              print(
                  '[ArplAssessorPage] Detected Pathway: $_pathwayType (from data: $pathway, isARPL: $isARPL)');
            });
          }
          return data;
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception(
            'Failed to load classes. Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('[AssessorPage] Error fetching classes: $e');
      throw Exception('Failed to load classes. Error: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildContent() {
    // Branching logic for ARPL pathway
    if (_pathwayType == 'ARPL') {
      switch (_selectedIndex) {
        case 0:
          return _buildClassesContent();
        case 10:
          return _buildARPLDashboard();
        case 11:
          return AssessmentPreparationPage(
              facilitatorId: widget.facilitator_id, isARPL: true);
        case 12:
          return AssessmentPlanPage(facilitatorId: widget.facilitator_id);
        case 13:
          return AssessorReportPage(
              facilitatorId: widget.facilitator_id, isARPL: true);
        case 14:
          return AssessmentReviewPage(
              facilitatorId: widget.facilitator_id, isARPL: true);
        case 20:
          return ARPLAssessorReviewPage(facilitatorId: widget.facilitator_id);
        case 21:
          return ARPLAppendixHPage(
              facilitatorId: widget.facilitator_id, ofoNumber: _ofoNumber);
        case 22:
          return ARPLEvidenceChecklistPage(
              facilitatorId: widget.facilitator_id);
        case 23:
          return RemedialsPage(facilitatorId: widget.facilitator_id);
        case 24:
          return ViewCompleteToolkitPage(facilitatorId: widget.facilitator_id);
        case 25:
          return FutureBuilder(
            future: _getFacilitatorName(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return ArplAssessorClockingPage(
                  facilitatorId: widget.facilitator_id,
                  facilitatorName: snapshot.data as String,
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          );
        default:
          return _buildARPLDashboard();
      }
    }

    // Default Assessor view
    switch (_selectedIndex) {
      case 0:
        return _buildClassesContent();
      case 1:
        return AssessmentPreparationPage(facilitatorId: widget.facilitator_id);
      case 2:
        return AssessmentPlanPage(facilitatorId: widget.facilitator_id);
      case 3:
        return AssessorReportPage(facilitatorId: widget.facilitator_id);
      case 4:
        return _buildAssessorFeedback(facilitatorId: widget.facilitator_id);
      case 5:
        return AssessmentReviewPage(facilitatorId: widget.facilitator_id);
      case 6:
        return AppealFormPage(facilitatorId: widget.facilitator_id);
      case 7:
        return NonComplianceAndFeedbackPage(
            facilitatorId: widget.facilitator_id, learnerId: 'LEARNER_ID');
      case 8:
        return PotholeChecklistClassListPage(
            facilitatorId: widget.facilitator_id);
      default:
        return _buildClassesContent();
    }
  }

  Widget _buildARPLDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ARPL Assessor Dashboard',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo),
          ),
          const SizedBox(height: 8),
          const Text('Recognition of Prior Learning Management'),
          const SizedBox(height: 24),
          _buildDashboardCard(
            title: 'Assigned Classes',
            icon: Icons.class_,
            color: Colors.blue,
            onTap: () => _onItemTapped(0),
          ),
          _buildDashboardCard(
            title: 'Evidence Verification',
            icon: Icons.checklist,
            color: Colors.indigo,
            onTap: () => _onItemTapped(22),
          ),
          _buildDashboardCard(
            title: 'Assessment Preparation',
            icon: Icons.assignment_outlined,
            color: Colors.orange,
            onTap: () => _onItemTapped(11),
          ),
          _buildDashboardCard(
            title: 'Portfolio Review (PoE)',
            icon: Icons.folder_shared,
            color: Colors.teal,
            onTap: () => _onItemTapped(14),
          ),
          _buildDashboardCard(
            title: 'Assessor Review (D,E,F)',
            icon: Icons.fact_check,
            color: Colors.green,
            onTap: () => _onItemTapped(20),
          ),
          _buildDashboardCard(
            title: 'Access Recommendation (H)',
            icon: Icons.recommend,
            color: Colors.purple,
            onTap: () => _onItemTapped(21),
          ),
          _buildDashboardCard(
            title: 'Portfolio Report',
            icon: Icons.picture_as_pdf,
            color: Colors.redAccent,
            onTap: () => _onItemTapped(13),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildClassesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Facilitator ID: ${widget.facilitator_id}',
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
                        String numberOfLearners =
                            classData['numberOfLearners'].toString();
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
                                    builder: (context) =>
                                        ArplClassDetailsPage(classId: classId),
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
    print('[ArplAssessorPage] ===== BUILD METHOD =====');
    print('[ArplAssessorPage] _pathwayType: "$_pathwayType"');
    print(
        '[ArplAssessorPage] Will show ${_pathwayType == 'ARPL' ? 'ARPL' : 'DEFAULT'} dashboard');
    print(
        '[ArplAssessorPage] Will use ${_pathwayType == 'ARPL' ? '_buildARPLDrawerItems' : '_buildDefaultDrawerItems'}');
    print('[ArplAssessorPage] ===========================');

    return Scaffold(
      appBar: AppBar(
          title: Text(_pathwayType == 'ARPL'
              ? 'ARPL Dashboard'
              : 'Assessor Dashboard')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: _pathwayType == 'ARPL'
              ? _buildARPLDrawerItems(context)
              : _buildDefaultDrawerItems(context),
        ),
      ),
      body: _buildContent(),
    );
  }

  List<Widget> _buildARPLDrawerItems(BuildContext context) {
    return [
      const DrawerHeader(
        decoration: BoxDecoration(color: Colors.indigo),
        child: Text('ARPL Assessor',
            style: TextStyle(color: Colors.white, fontSize: 24)),
      ),
      ListTile(
        title: const Text('ARPL Dashboard'),
        selected: _selectedIndex == 10,
        leading: const Icon(Icons.dashboard),
        onTap: () {
          _onItemTapped(10);
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text('Assigned Classes'),
        selected: _selectedIndex == 0,
        leading: const Icon(Icons.class_),
        onTap: () {
          _onItemTapped(0);
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text('Candidate Preparation'),
        selected: _selectedIndex == 11,
        leading: const Icon(Icons.people_outline),
        onTap: () {
          _onItemTapped(11);
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text('Evidence Collection'),
        selected: _selectedIndex == 13,
        leading: const Icon(Icons.assignment_turned_in),
        onTap: () {
          _onItemTapped(13);
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text('Portfolio Review'),
        selected: _selectedIndex == 14,
        leading: const Icon(Icons.rate_review),
        onTap: () {
          _onItemTapped(14);
          Navigator.pop(context);
        },
      ),
      const Divider(),
      ListTile(
        title: const Text('Assessor Review (D,E,F)'),
        selected: _selectedIndex == 20,
        leading: const Icon(Icons.fact_check),
        onTap: () {
          _onItemTapped(20);
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text('Access Recommendation (H)'),
        selected: _selectedIndex == 21,
        leading: const Icon(Icons.recommend),
        onTap: () {
          _onItemTapped(21);
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text('Evidence Checklist'),
        selected: _selectedIndex == 22,
        leading: const Icon(Icons.checklist),
        onTap: () {
          _onItemTapped(22);
          Navigator.pop(context);
        },
      ),
      const Divider(),
      ListTile(
        title: const Text('Remedials'),
        selected: _selectedIndex == 23,
        leading: const Icon(Icons.medical_services),
        onTap: () {
          _onItemTapped(23);
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text('Clock In/Out'),
        selected: _selectedIndex == 25,
        leading: const Icon(Icons.access_time),
        onTap: () {
          Navigator.of(context).pop();
          _onItemTapped(25);
        },
      ),
      ListTile(
        title: const Text('View Complete Toolkit'),
        selected: _selectedIndex == 24,
        leading: const Icon(Icons.description),
        onTap: () {
          _onItemTapped(24);
          Navigator.pop(context);
        },
      ),
    ];
  }

  List<Widget> _buildDefaultDrawerItems(BuildContext context) {
    return [
      const DrawerHeader(
        decoration: BoxDecoration(color: Colors.blue),
        child: Text('Assessor Menu',
            style: TextStyle(color: Colors.white, fontSize: 24)),
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
        title: const Text('Assessment Preparation'),
        selected: _selectedIndex == 1,
        onTap: () {
          _onItemTapped(1);
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text('Assessment Plan'),
        selected: _selectedIndex == 2,
        onTap: () {
          _onItemTapped(2);
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text('Assessor Report'),
        selected: _selectedIndex == 3,
        onTap: () {
          _onItemTapped(3);
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text('Assessor Feedback'),
        selected: _selectedIndex == 4,
        onTap: () {
          _onItemTapped(4);
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text('Assessment Review'),
        selected: _selectedIndex == 5,
        onTap: () {
          _onItemTapped(5);
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text('Appeal Form'),
        selected: _selectedIndex == 6,
        onTap: () {
          _onItemTapped(6);
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text('Non-Compliance & Feedback'),
        selected: _selectedIndex == 7,
        onTap: () {
          _onItemTapped(7);
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text('Pothole Checklist'),
        selected: _selectedIndex == 8,
        onTap: () {
          _onItemTapped(8);
          Navigator.pop(context);
        },
      ),
    ];
  }
}

class AssessmentPreparationPage extends StatefulWidget {
  final String facilitatorId;
  final String? learnerId;
  final bool isARPL;

  const AssessmentPreparationPage({
    super.key,
    required this.facilitatorId,
    this.learnerId,
    this.isARPL = false,
  });

  @override
  _AssessmentPreparationPageState createState() =>
      _AssessmentPreparationPageState();
}

class _AssessmentPreparationPageState extends State<AssessmentPreparationPage> {
  late Future<List<dynamic>> _unitStandards;
  String? _selectedLearnerId;
  List<dynamic> _learners = [];
  bool _isLoadingLearners = true;

  final SignatureController _learnerSig = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);
  final SignatureController _assessorSig = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);

  @override
  void initState() {
    super.initState();
    _selectedLearnerId = widget.learnerId;
    _fetchLearners();
    if (_selectedLearnerId != null) {
      _unitStandards =
          fetchUnitStandards(widget.facilitatorId, _selectedLearnerId);
    } else {
      _unitStandards = Future.value([]);
    }
  }

  Future<void> _fetchLearners() async {
    try {
      final db = await DatabaseHelper().database;
      final facilitatorClasses = await db.query(
        'facilitator',
        columns: ['classID'],
        where: 'facilitator_id = ?',
        whereArgs: [widget.facilitatorId],
      );

      Set<String> classIds = {};
      for (var row in facilitatorClasses) {
        String ids = row['classID']?.toString() ?? '';
        if (ids.isNotEmpty) {
          classIds.addAll(ids.split(',').map((e) => e.trim()));
        }
      }

      if (classIds.isNotEmpty) {
        final learnersList = await db.query(
          'learnerdetails',
          where: 'classID IN (${classIds.map((_) => '?').join(',')})',
          whereArgs: classIds.toList(),
        );

        setState(() {
          _learners = learnersList;
          _isLoadingLearners = false;
        });
      } else {
        setState(() => _isLoadingLearners = false);
      }
    } catch (e) {
      print('Error fetching learners: $e');
      setState(() => _isLoadingLearners = false);
    }
  }

  Future<List<dynamic>> fetchUnitStandards(
      String facilitatorId, String? learnerId) async {
    if (learnerId == null) return [];
    try {
      String url =
          '${AppConfig.baseUrl}/get_assessment_preparation.php?facilitator_id=$facilitatorId&learner_id=$learnerId';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return data['data'];
        } else {
          throw Exception('Failed to load unit standards: ${data['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching unit standards: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLearner = _selectedLearnerId == null
        ? null
        : _learners.isEmpty
            ? null
            : _learners
                    .any((l) => l['LearnerID'].toString() == _selectedLearnerId)
                ? _learners.firstWhere(
                    (l) => l['LearnerID'].toString() == _selectedLearnerId)
                : null;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isARPL ? 'ARPL Preparation' : 'Assessment Preparation'),
        backgroundColor: widget.isARPL ? Colors.indigo : Colors.blue,
      ),
      body: _isLoadingLearners
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Candidate',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedLearnerId,
                    hint: const Text(
                        'Choose a learner to see their unit standards'),
                    isExpanded: true,
                    items: _learners.map((learner) {
                      return DropdownMenuItem<String>(
                        value: learner['LearnerID'].toString(),
                        child: Text('${learner['Name']} ${learner['Surname']}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLearnerId = value;
                        _unitStandards = fetchUnitStandards(
                            widget.facilitatorId, _selectedLearnerId);
                      });
                    },
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedLearnerId != null) ...[
                    if (selectedLearner != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.indigo.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Candidate: ${selectedLearner['Name']} ${selectedLearner['Surname']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo),
                        ),
                      ),
                    Expanded(
                      child: FutureBuilder<List<dynamic>>(
                        future: _unitStandards,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Center(
                                child: Text('Error: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.red)));
                          } else if (!snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return const Center(
                                child: Text(
                                    'No unit standards found for this PoE.',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey)));
                          } else {
                            List<dynamic> unitStandards = snapshot.data!;
                            return ListView.builder(
                              itemCount: unitStandards.length,
                              itemBuilder: (context, index) {
                                var unitStandard = unitStandards[index];
                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: widget.isARPL
                                          ? Colors.indigo
                                          : Colors.blue,
                                      foregroundColor: Colors.white,
                                      child: Text(
                                          unitStandard['unitstandard_id']
                                              .toString()),
                                    ),
                                    title: Text(
                                        unitStandard['unitstandard_name'] ??
                                            'Unknown Unit Standard',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    trailing: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                UnitStandardDetailPage(
                                              unitStandardId: unitStandard[
                                                      'unitstandard_id']
                                                  .toString(),
                                              facilitatorId:
                                                  widget.facilitatorId,
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: widget.isARPL
                                            ? Colors.indigo
                                            : Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Open'),
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ],
                  if (_selectedLearnerId != null) ...[
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }
}

class UnitStandardDetailPage extends StatefulWidget {
  final String unitStandardId;
  final String facilitatorId;

  const UnitStandardDetailPage({
    super.key,
    required this.unitStandardId,
    required this.facilitatorId,
  });

  @override
  _UnitStandardDetailPageState createState() => _UnitStandardDetailPageState();
}

class _UnitStandardDetailPageState extends State<UnitStandardDetailPage> {
  final _formKey = GlobalKey<FormState>();

  final List<Map<String, String>> _prepRows = [
    {
      'step':
          'Explain to the candidate why you are meeting and the purpose of the assessment.',
      'doc': 'NQF Framework Assessment process',
    },
    {
      'step': 'Discuss the assessment plan in detail.',
      'doc': 'Assessment strategy',
    },
    {
      'step':
          'Explain assessment process, show assessment instruments to candidate and describe assessment conditions.',
      'doc': 'Assessment instruments',
    },
    {
      'step': 'Identify the role-players during assessment.',
      'doc': 'Assessors\nModerator',
    },
    {
      'step': 'Describe the evidence required to be declared competent.',
      'doc': 'Examples of evidence',
    },
    {
      'step': 'Explain how evidence will be judged.',
      'doc': '',
    },
    {
      'step':
          'Explain to the candidate how to prepare:  Give candidate summative task description.',
      'doc': 'Summative task description',
    },
    {
      'step':
          'Confirm with the candidate what he/she should bring to the assessment.',
      'doc': 'Detailed briefing on exact requirements to be given to candidate',
    },
    {
      'step':
          'Ensure that candidate understands the procedures of all assessment practices.',
      'doc': 'Appeals procedure\nModeration procedure\nAssessment policy',
    },
    {
      'step':
          'Ask the candidate if he/she foresees any problems or identify any special needs.',
      'doc': 'List needs',
    },
    {
      'step':
          'Check with candidate that he/she clearly understands the assessment procedure.',
      'doc': '',
    },
  ];

  late List<bool> _agreeList;
  late List<TextEditingController> _actionControllers;
  String _responseMessage = '';
  bool _isSubmitting = false;

  final SignatureController _learnerSig = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);
  final SignatureController _assessorSig = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);

  @override
  void initState() {
    super.initState();
    _agreeList = List.filled(_prepRows.length, false);
    _actionControllers =
        List.generate(_prepRows.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (var controller in _actionControllers) {
      controller.dispose();
    }
    _learnerSig.dispose();
    _assessorSig.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _responseMessage = '';
        _isSubmitting = true;
      });

      try {
        final prepTable = List.generate(
            _prepRows.length,
            (index) => {
                  'step': _prepRows[index]['step'],
                  'doc': _prepRows[index]['doc'],
                  'agree': _agreeList[index],
                  'action': _actionControllers[index].text,
                });

        final payload = {
          'unitstandard_id': widget.unitStandardId,
          'facilitator_id': widget.facilitatorId,
          'prep_table': prepTable,
        };

        print("Sending payload: ${jsonEncode(payload)}");
        final response = await http.post(
          Uri.parse(
              'https://rlms.rlms.co.za/mobile/save_assessment_preparation.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        print("Raw response: ${response.statusCode} - ${response.body}");
        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          setState(() {
            _responseMessage = data['status'] == 'success'
                ? 'Form saved successfully!'
                : 'Failed to save form: ${data['message']}';
            _isSubmitting = false;
          });
          if (data['status'] == 'success') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Form saved successfully!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${data['message']}')),
            );
          }
        } else {
          setState(() {
            _responseMessage =
                'Server error: ${response.statusCode} - ${response.body}';
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: ${response.statusCode}')),
          );
        }
      } catch (e) {
        setState(() {
          _responseMessage = 'Error saving form: $e';
          _isSubmitting = false;
        });
        print("Exception: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildPrepTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('How to prepare the candidate')),
          DataColumn(label: Text('Document Requirements')),
          DataColumn(label: Text('Agree (tick)')),
          DataColumn(label: Text('Action Required')),
        ],
        rows: List.generate(_prepRows.length, (index) {
          return DataRow(
            cells: [
              DataCell(Text(_prepRows[index]['step']!)),
              DataCell(Text(_prepRows[index]['doc']!.replaceAll('\\n', '\n'))),
              DataCell(Checkbox(
                value: _agreeList[index],
                onChanged: (val) {
                  setState(() {
                    _agreeList[index] = val ?? false;
                  });
                },
              )),
              DataCell(
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: _actionControllers[index],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Action Required',
                    ),
                    maxLines: 2,
                    validator: (v) => null, // Not required
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Unit Standard: ${widget.unitStandardId}'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                      child: const Icon(Icons.assessment, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Assessment Preparation',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Facilitator ID: ${widget.facilitatorId}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildPrepTable(),
                  ),
                ),
                const SizedBox(height: 24),
                DualSignaturePad(
                  title: 'Preparation Signatures',
                  learnerController: _learnerSig,
                  assessorController: _assessorSig,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _saveForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save'),
                ),
                const SizedBox(height: 16),
                Text(
                  _responseMessage,
                  style: TextStyle(
                    color: _responseMessage.contains('success')
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AssessmentPlanPage extends StatefulWidget {
  final String facilitatorId;

  const AssessmentPlanPage({super.key, required this.facilitatorId});

  @override
  _AssessmentPlanPageState createState() => _AssessmentPlanPageState();
}

class _AssessmentPlanPageState extends State<AssessmentPlanPage> {
  late Future<List<dynamic>> _unitStandards;

  @override
  void initState() {
    super.initState();
    _unitStandards = fetchUnitStandards(widget.facilitatorId);
  }

  Future<List<dynamic>> fetchUnitStandards(String facilitatorId) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://rlms.rlms.co.za/mobile/get_assessment_preparation.php?facilitator_id=$facilitatorId'),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return data['data'];
        } else {
          throw Exception('Failed to load unit standards: ${data['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching unit standards: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Plan'),
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
                  child: const Icon(Icons.calendar_today, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Assessment Plan',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Facilitator ID: ${widget.facilitatorId}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FutureBuilder<List<dynamic>>(
                    future: _unitStandards,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text(
                            'No unit standards found for this assessment plan.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        );
                      } else {
                        List<dynamic> unitStandards = snapshot.data!;
                        return ListView.builder(
                          itemCount: unitStandards.length,
                          itemBuilder: (context, index) {
                            var unitStandard = unitStandards[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  child: Text(unitStandard['unitstandard_id']
                                      .toString()),
                                ),
                                title: Text(
                                  unitStandard['unitstandard_name'] ??
                                      'Unknown Unit Standard',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AssessmentPlanDetailPage(
                                          unitStandardId:
                                              unitStandard['unitstandard_id']
                                                  .toString(),
                                          facilitatorId: widget.facilitatorId,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                  ),
                                  child: const Text('Open'),
                                ),
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

class AssessmentPlanDetailPage extends StatefulWidget {
  final String unitStandardId;
  final String facilitatorId;

  const AssessmentPlanDetailPage({
    super.key,
    required this.unitStandardId,
    required this.facilitatorId,
  });

  @override
  _AssessmentPlanDetailPageState createState() =>
      _AssessmentPlanDetailPageState();
}

class _AssessmentPlanDetailPageState extends State<AssessmentPlanDetailPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _assessmentDate;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  String? _languageMedium;
  String? _assessmentMethod;
  String _responseMessage = '';
  bool _isSubmitting = false;

  final List<String> _languages = [
    'English',
    'Afrikaans',
    'Zulu',
    'Xhosa',
    'Sesotho',
    'Setswana',
    'Xitsonga',
    'Tshivenda',
    'IsiNdebele',
    'Siswati'
  ];
  final List<String> _methods = [
    'Observation(Simulation)',
    'Oral(Knowledge test)',
    'Written(Knowledge test)'
  ];

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
        _responseMessage = '';
      });

      try {
        final payload = {
          'facilitator_id': widget.facilitatorId,
          'unitstandard_id': widget.unitStandardId,
          'assessment_date': _assessmentDate?.toIso8601String().split('T')[0],
          'start_date': _startDate?.toIso8601String().split('T')[0],
          'end_date': _endDate?.toIso8601String().split('T')[0],
          'venue': _venueController.text,
          'contact_person': _contactPersonController.text,
          'language_medium': _languageMedium,
          'assessment_method': _assessmentMethod,
        };

        print("Sending payload: ${jsonEncode(payload)}");
        final response = await http.post(
          Uri.parse('https://rlms.rlms.co.za/mobile/save_assessment_plan.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        print("Raw response: ${response.statusCode} - ${response.body}");
        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          setState(() {
            _responseMessage = data['status'] == 'success'
                ? 'Assessment plan saved successfully!'
                : 'Failed to save: ${data['message']}';
            _isSubmitting = false;
          });
          if (data['status'] == 'success') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Assessment plan saved successfully!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${data['message']}')),
            );
          }
        } else {
          setState(() {
            _responseMessage =
                'Server error: ${response.statusCode} - ${response.body}';
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: ${response.statusCode}')),
          );
        }
      } catch (e) {
        setState(() {
          _responseMessage = 'Error saving form: $e';
          _isSubmitting = false;
        });
        print("Exception: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, String field) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (field == 'assessment') {
          _assessmentDate = picked;
        } else if (field == 'start') {
          _startDate = picked;
        } else if (field == 'end') {
          _endDate = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _venueController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Plan'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                      child:
                          const Icon(Icons.calendar_today, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Assessment Plan',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildDateField('Date of Assessment', _assessmentDate,
                            'assessment'),
                        const SizedBox(height: 16),
                        _buildTimeRangeField(),
                        const SizedBox(height: 16),
                        _buildTextField('Venue', _venueController),
                        const SizedBox(height: 16),
                        _buildTextField(
                            'Contact Person', _contactPersonController),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                            'Language Medium', _languageMedium, _languages,
                            (val) {
                          setState(() => _languageMedium = val);
                        }),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                            'Method of Assessment', _assessmentMethod, _methods,
                            (val) {
                          setState(() => _assessmentMethod = val);
                        }),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 12),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Submit'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _responseMessage,
                  style: TextStyle(
                    color: _responseMessage.contains('success')
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? date, String field) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: () => _selectDate(context, field),
          child: Text(
            date != null
                ? '${date.day}/${date.month}/${date.year}'
                : 'Select Date',
            style: const TextStyle(color: Colors.blue),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Assessment Time',
            style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                const Text('Start:'),
                TextButton(
                  onPressed: () => _selectDate(context, 'start'),
                  child: Text(
                    _startDate != null
                        ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                        : 'Select Date',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const Text('End:'),
                TextButton(
                  onPressed: () => _selectDate(context, 'end'),
                  child: Text(
                    _endDate != null
                        ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                        : 'Select Date',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) => value!.isEmpty ? 'This field is required' : null,
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> options,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'This field is required' : null,
    );
  }
}

class AssessorReportPage extends StatefulWidget {
  final String facilitatorId;
  final bool isARPL;

  const AssessorReportPage({
    super.key,
    required this.facilitatorId,
    this.isARPL = false,
  });

  @override
  _AssessorReportPageState createState() => _AssessorReportPageState();
}

class _AssessorReportPageState extends State<AssessorReportPage> {
  String _statusMessage = '';
  bool _isGenerating = false;
  String? _pdfPath;
  String? _selectedLearnerId;
  List<dynamic> _learners = [];
  bool _isLoadingLearners = true;

  @override
  void initState() {
    super.initState();
    _fetchLearners();
  }

  Future<void> _fetchLearners() async {
    try {
      final db = await DatabaseHelper().database;
      final facilitatorClasses = await db.query(
        'facilitator',
        columns: ['classID'],
        where: 'facilitator_id = ?',
        whereArgs: [widget.facilitatorId],
      );

      Set<String> classIds = {};
      for (var row in facilitatorClasses) {
        String ids = row['classID']?.toString() ?? '';
        if (ids.isNotEmpty) {
          classIds.addAll(ids.split(',').map((e) => e.trim()));
        }
      }

      if (classIds.isNotEmpty) {
        final learnersList = await db.query(
          'learnerdetails',
          where: 'classID IN (${classIds.map((_) => '?').join(',')})',
          whereArgs: classIds.toList(),
        );

        setState(() {
          _learners = learnersList;
          _isLoadingLearners = false;
        });
      } else {
        setState(() => _isLoadingLearners = false);
      }
    } catch (e) {
      print('Error fetching learners: $e');
      setState(() => _isLoadingLearners = false);
    }
  }

  Future<void> _generateAndDownloadReport() async {
    if (widget.isARPL && _selectedLearnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a candidate first')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _statusMessage = 'Generating report...';
      _pdfPath = null;
    });

    try {
      String url =
          '${AppConfig.baseUrl}/generate_assessor_report.php?facilitator_id=${widget.facilitatorId}';
      if (_selectedLearnerId != null) {
        url += '&learner_id=$_selectedLearnerId';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (response.body.startsWith('No data found')) {
          setState(() {
            _statusMessage = 'No data found for this selection.';
            _isGenerating = false;
          });
          return;
        }

        if (response.headers['content-type']?.contains('application/pdf') ==
            true) {
          final dir = await getTemporaryDirectory();
          final fileName = _selectedLearnerId != null
              ? 'ARPL_Report_${_selectedLearnerId}_${DateTime.now().millisecondsSinceEpoch}.pdf'
              : 'Facilitator_${widget.facilitatorId}_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';

          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);

          setState(() {
            _statusMessage = 'Report generated successfully!';
            _isGenerating = false;
            _pdfPath = file.path;
          });
        } else {
          setState(() {
            _statusMessage = 'Unexpected response: ${response.body}';
            _isGenerating = false;
          });
        }
      } else {
        setState(() {
          _statusMessage =
              'Failed to generate report. Server error: ${response.statusCode}';
          _isGenerating = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error generating report: $e';
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isARPL ? 'ARPL Portfolio Report' : 'Assessor Report'),
        backgroundColor: widget.isARPL ? Colors.indigo : Colors.blue,
      ),
      body: _isLoadingLearners
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Candidate',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedLearnerId,
                    hint: const Text('Choose a learner'),
                    isExpanded: true,
                    items: _learners.map((learner) {
                      return DropdownMenuItem<String>(
                        value: learner['LearnerID'].toString(),
                        child: Text('${learner['Name']} ${learner['Surname']}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLearnerId = value;
                        _pdfPath = null;
                        _statusMessage = '';
                      });
                    },
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 16),
                  if (!widget.isARPL)
                    Text('Facilitator ID: ${widget.facilitatorId}'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isGenerating ? null : _generateAndDownloadReport,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: Text(_isGenerating
                          ? 'Generating...'
                          : 'Generate Portfolio Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            widget.isARPL ? Colors.indigo : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _statusMessage.contains('successfully')
                            ? Colors.green
                            : Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_pdfPath != null)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!)),
                        child: PDFView(
                          filePath: _pdfPath!,
                          enableSwipe: true,
                          swipeHorizontal: true,
                          autoSpacing: true,
                          pageFling: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class ClassDetailsPage extends StatefulWidget {
  final String classId;

  const ClassDetailsPage({super.key, required this.classId});

  @override
  _ClassDetailsPageState createState() => _ClassDetailsPageState();
}

class _ClassDetailsPageState extends State<ClassDetailsPage> {
  late Future<List<dynamic>> _learners;

  @override
  void initState() {
    super.initState();
    _learners = fetchLearnersWithPOE(widget.classId);
  }

  Future<List<dynamic>> fetchLearnersWithPOE(String classId) async {
    try {
      final url = AppConfig.buildUrl('get_learners.php', queryParams: {
        'classID': classId,
        '_': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      print('[ClassDetailsPage] Fetching learners from: $url');
      final response = await http.get(Uri.parse(url));

      print('[ClassDetailsPage] Response Status: ${response.statusCode}');
      print('[ClassDetailsPage] Response Headers: ${response.headers}');
      print('[ClassDetailsPage] Response Body Length: ${response.body.length}');
      print(
          '[ClassDetailsPage] Response Body (get_learners): ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }
        if (!response.body.trim().startsWith('[') &&
            !response.body.trim().startsWith('{')) {
          throw Exception(
              'Invalid JSON response: ${response.body.substring(0, response.body.length < 50 ? response.body.length : 50)}');
        }

        List<dynamic> learners = jsonDecode(response.body);

        // Fetch POE data for each learner
        for (var learner in learners) {
          String learnerId = learner['LearnerID'].toString();
          final poeUrl = AppConfig.buildUrl('get_poe.php', queryParams: {
            'learnerId': learnerId,
          });

          print('[ClassDetailsPage] Fetching POE from: $poeUrl');
          final poeResponse = await http.get(Uri.parse(poeUrl));

          print(
              'POE Response Status for learner $learnerId: ${poeResponse.statusCode}');
          print(
              'POE Response Body for learner $learnerId: ${poeResponse.body}');

          if (poeResponse.statusCode == 200) {
            if (poeResponse.body.isEmpty) {
              learner['poeData'] = {'pathways': {}};
              print('Empty POE response for learner $learnerId');
            } else {
              try {
                Map<String, dynamic> poeData = jsonDecode(poeResponse.body);
                learner['poeData'] = poeData;
                print('POE Data for learner $learnerId: $poeData');
              } catch (e) {
                learner['poeData'] = {'pathways': {}};
                print('Failed to parse POE JSON for learner $learnerId: $e');
              }
            }
          } else {
            learner['poeData'] = {'pathways': {}};
            print(
                'Failed to fetch POE for learner $learnerId, status: ${poeResponse.statusCode}');
          }
        }

        return learners;
      } else {
        throw Exception(
            'Failed to load learners. Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching learners: $e');
      throw Exception('Failed to load learners. Error: $e');
    }
  }

  Color _getRowColor(dynamic learner) {
    var poeData = learner['poeData']?['pathways'] ?? {};
    String learnerId = learner['LearnerID'].toString();

    if (poeData.isEmpty) {
      print('No POE data for learner $learnerId, color: white');
      return Colors.white;
    }

    bool hasFile = false;
    bool allMarksScored = true;

    // Iterate through pathways, qualifications, and unit standards
    for (var pathwayEntry in poeData.entries) {
      var qualifications = pathwayEntry.value['qualifications'] ?? {};
      for (var qualEntry in qualifications.entries) {
        var unitStandards = qualEntry.value['unitstandards'] ?? {};
        for (var unitStandardEntry in unitStandards.entries) {
          var assessments = unitStandardEntry.value;

          // Check summative assessments
          for (var assessment in assessments['summative'] ?? []) {
            print(
                'Checking summative assessment for learner $learnerId, exercise: ${assessment['exercise']}, '
                'filePath: ${assessment['filePath']}, marks_scored: ${assessment['marks_scored']}');
            if (assessment['filePath'] != null &&
                assessment['filePath'].isNotEmpty) {
              hasFile = true;
              print(
                  'Found file for learner $learnerId in summative, setting hasFile to true');
            }
            var marksScored = assessment['marks_scored'];
            if (marksScored == null ||
                (marksScored is num && marksScored <= 0)) {
              allMarksScored = false;
              print(
                  'Missing or zero marks for summative exercise ${assessment['exercise']} in learner $learnerId, '
                  'setting allMarksScored to false');
            }
          }

          // Check formative assessments
          for (var assessment in assessments['formative'] ?? []) {
            print(
                'Checking formative assessment for learner $learnerId, exercise: ${assessment['exercise']}, '
                'filePath: ${assessment['filePath']}, marks_scored: ${assessment['marks_scored']}');
            if (assessment['filePath'] != null &&
                assessment['filePath'].isNotEmpty) {
              hasFile = true;
              print(
                  'Found file for learner $learnerId in formative, setting hasFile to true');
            }
            var marksScored = assessment['marks_scored'];
            if (marksScored == null ||
                (marksScored is num && marksScored <= 0)) {
              allMarksScored = false;
              print(
                  'Missing or zero marks for formative exercise ${assessment['exercise']} in learner $learnerId, '
                  'setting allMarksScored to false');
            }
          }
        }
      }
    }

    if (allMarksScored && hasFile) {
      print(
          'All exercises for learner $learnerId have marks and at least one file, color: green');
      return Colors.green;
    }
    if (hasFile) {
      print('Learner $learnerId has file but not all marks, color: amber');
      return Colors.amber;
    }
    print('Learner $learnerId has no file or all marks, color: white');
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Class Details - ${widget.classId}')),
      body: Column(
        children: [
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
                          String learnerId =
                              learnerData['LearnerID'].toString();
                          String firstName = learnerData['Name'] ?? 'Unknown';
                          String lastName = learnerData['Surname'] ?? 'Unknown';
                          String idNumber =
                              learnerData['IDNumber'] ?? 'Unknown';
                          Color rowColor = _getRowColor(learnerData);

                          return DataRow(
                            color: WidgetStateColor.resolveWith(
                                (states) => rowColor),
                            cells: [
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
                                        builder: (context) =>
                                            ArplHierarchicalNavigatorPage(
                                          classId: widget.classId,
                                          learnerId: learnerId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Action'),
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
          ),
        ],
      ),
    );
  }
}

class AssessorMarkingPage extends StatelessWidget {
  final String learnerId;
  final String? learnerFirstName;
  final String? learnerLastName;
  final String? learnerIdNumber;
  final String? facilitatorId; // used to auto-populate assessor
  final String? classId; // used to auto-populate venue

  const AssessorMarkingPage({
    super.key,
    required this.learnerId,
    this.learnerFirstName,
    this.learnerLastName,
    this.learnerIdNumber,
    this.facilitatorId,
    this.classId,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ARPL Assessment Marking'),
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

class PotholeChecklistTab extends StatefulWidget {
  final String learnerId;
  final String? learnerFirstName;
  final String? learnerLastName;
  final String? learnerIdNumber;
  final String? facilitatorId;
  final String? classId;

  const PotholeChecklistTab({
    super.key,
    required this.learnerId,
    this.learnerFirstName,
    this.learnerLastName,
    this.learnerIdNumber,
    this.facilitatorId,
    this.classId,
  });

  @override
  State<PotholeChecklistTab> createState() => _PotholeChecklistTabState();
}

class _PotholeChecklistTabState extends State<PotholeChecklistTab> {
  final TextEditingController _learnerNameController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _assessorNameController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  DateTime _date = DateTime.now();

  // Checklist structure: description, yes/no, notes
  late final List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    // Auto-populate from provided info
    final learnerFullName = [widget.learnerFirstName, widget.learnerLastName]
        .where((e) => (e ?? '').trim().isNotEmpty)
        .join(' ');
    _learnerNameController.text = learnerFullName;
    _idNumberController.text = widget.learnerIdNumber ?? '';

    // Try to auto-populate assessor and venue using existing helpers if available in this file
    // If facilitatorId/classId not provided, leave blank for now
    if (widget.facilitatorId != null) {
      _populateAssessor(widget.facilitatorId!);
    }
    if (widget.classId != null) {
      _populateVenue(widget.classId!);
    }

    _items = [
      {
        'section': 'PRE – OPERATIONAL SAFETY',
        'entries': [
          {'label': 'Wears appropriate PPE', 'value': null, 'notes': ''},
        ],
      },
      {
        'section': 'PREPARATION',
        'entries': [
          {
            'label':
                'Cleans the pothole of all loose material, debris and water',
            'value': null,
            'notes': ''
          },
          {
            'label':
                'Setting out done correctly (marking, straightness, corners)',
            'value': null,
            'notes': ''
          },
        ],
      },
      {
        'section': 'MATERIAL PREPARATION',
        'entries': [
          {'label': 'Crusher material', 'value': null, 'notes': ''},
          {'label': 'Cold asphalt', 'value': null, 'notes': ''},
        ],
      },
      {
        'section': 'APPLICATION AND COMPACTION',
        'entries': [
          {
            'label': 'Filled the hole with crusher material',
            'value': null,
            'notes': ''
          },
          {
            'label': 'Applied tack coat (bonding liquid)',
            'value': null,
            'notes': ''
          },
          {'label': 'Filled asphalt in the hole', 'value': null, 'notes': ''},
          {
            'label': 'All the corners sealed and squared',
            'value': null,
            'notes': ''
          },
          {
            'label': 'Compacted each layer thoroughly using the compactor',
            'value': null,
            'notes': ''
          },
          {
            'label': 'Added 10 mm excess material for final compaction',
            'value': null,
            'notes': ''
          },
          {
            'label':
                'Final compacted surface is flush with surrounding road surfaces',
            'value': null,
            'notes': ''
          },
        ],
      },
      {
        'section': 'POST – OPERATION',
        'entries': [
          {'label': 'Housekeeping', 'value': null, 'notes': ''},
        ],
      },
    ];
  }

  Future<void> _populateAssessor(String facilitatorId) async {
    try {
      final response = await http.get(Uri.parse(
          'https://rlms.rlms.co.za/mobile/fetch_facilitator_details.php?facilitator_id=$facilitatorId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String first = data['firstName']?.toString() ?? '';
        final String last = data['lastName']?.toString() ?? '';
        setState(() {
          _assessorNameController.text =
              [first, last].where((e) => e.trim().isNotEmpty).join(' ');
        });
      }
    } catch (_) {}
  }

  Future<void> _populateVenue(String classId) async {
    try {
      final response = await http.get(Uri.parse(
          'https://rlms.rlms.co.za/mobile/fetch_class_name.php?class_id=$classId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String name = data['className']?.toString() ?? '';
        setState(() {
          _venueController.text = name;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _learnerNameController.dispose();
    _idNumberController.dispose();
    _assessorNameController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LEARNER',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _learnerNameController,
                  decoration: const InputDecoration(
                    labelText: 'Name & Surname',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _idNumberController,
                  decoration: const InputDecoration(
                    labelText: 'ID Number',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_date.toIso8601String().split('T').first),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Signature (placeholder)',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _venueController,
            decoration: const InputDecoration(
              labelText: 'Venue',
              border: OutlineInputBorder(),
            ),
            readOnly: true,
          ),
          const SizedBox(height: 16),
          const Text(
            'POTHOLE PATCHING CHECKLIST',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._items.map((section) => _buildSection(section)),
          const SizedBox(height: 16),
          const Text(
            'ASSESSOR',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _assessorNameController,
                  decoration: const InputDecoration(
                    labelText: 'Name and Surname',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Assessor Reg. Number (optional)',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_date.toIso8601String().split('T').first),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Signature (placeholder)',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {
                // Placeholder: In future, collect and submit to backend
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Checklist captured (not saved).')),
                );
              },
              child: const Text('Save'),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSection(Map<String, dynamic> section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          section['section'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...List<Widget>.from((section['entries'] as List).map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(entry['label'] as String),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Radio<bool?>(
                        value: true,
                        groupValue: entry['value'] as bool?,
                        onChanged: (v) => setState(() => entry['value'] = v),
                      ),
                      const Text('YES'),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Radio<bool?>(
                        value: false,
                        groupValue: entry['value'] as bool?,
                        onChanged: (v) => setState(() => entry['value'] = v),
                      ),
                      const Text('NO'),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: entry['notes'] as String? ?? '',
                    onChanged: (t) => entry['notes'] = t,
                    decoration: const InputDecoration(
                      labelText: 'Notes & observations by assessor',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          );
        })),
      ],
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
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _poeData = fetchPOE(widget.learnerId);
    });
  }

  Future<Map<String, dynamic>> fetchPOE(String learnerId) async {
    try {
      final url = AppConfig.buildUrl('get_poe.php', queryParams: {
        'learnerId': learnerId,
      });

      print('[POETab] Fetching POE from: $url');
      final response = await http.get(Uri.parse(url));

      print('[POETab] POE Response Status: ${response.statusCode}');
      print('[POETab] POE Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to load POE data. Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('[POETab] Error fetching POE: $e');
      throw Exception('Failed to load POE data. Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _poeData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Expanded(
                  child: Center(child: CircularProgressIndicator()));
            } else if (snapshot.hasError) {
              return Expanded(
                  child: Center(child: Text('Error: ${snapshot.error}')));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Expanded(
                  child: Center(child: Text('No POE data found.')));
            }

            Map<String, dynamic> poeData = snapshot.data!;
            Map<String, dynamic> pathways = poeData['pathways'] ?? {};

            return Expanded(
              child: ListView(
                children: [
                  // arl: Button to open ARPL Hierarchical Navigator from POE Tab
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final url = AppConfig.buildUrl(
                            'arpl_hierarchical_navigator.php');
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Could not open the ARPL page')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.assessment),
                      label: const Text('Open ARPL Hierarchical Navigator'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        textStyle: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Refresh button at the top of the list
                  ListTile(
                    leading: const Icon(Icons.refresh, color: Colors.blue),
                    title: const Text('Refresh POE Data'),
                    onTap: _refreshData,
                  ),
                  const Divider(),
                  // Build pathway/qualification/unit standard structure
                  ...pathways.entries.map((entry) {
                    return ExpansionTile(
                      title: Text(entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      children: _buildQualificationTiles(entry.value),
                    );
                  }),

                  // Separate LogBook Section
                  _buildLogBookSection(poeData),

                  // Separate Pothole Checklist Section
                  _buildPotholeChecklistMainSection(),
                ],
              ),
            );
          },
        ),
        if (_responseMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _responseMessage,
              style: TextStyle(
                color: _responseMessage.contains('success')
                    ? Colors.green
                    : Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
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
    Map<String, dynamic> unitStandards =
        qualificationData['unitstandards'] ?? {};

    return unitStandards.entries.map((entry) {
      return ExpansionTile(
        title: Text(entry.key),
        children: _buildAssessmentTypeTiles(entry.value),
      );
    }).toList();
  }

  List<Widget> _buildAssessmentTypeTiles(
      Map<String, dynamic> unitStandardData) {
    List<dynamic> summative = unitStandardData['summative'] ?? [];
    List<dynamic> formative = unitStandardData['formative'] ?? [];
    List<dynamic> formativeRemedial =
        unitStandardData['formativeremedial'] ?? [];
    List<dynamic> summativeRemedial =
        unitStandardData['summativeremedial'] ?? [];

    // Defensive: some backends place remedial items inside the main buckets
    // (e.g. type == SummativeRemedial but stored under 'summative').
    // Split them out here so the UI always shows Remedial sections when present.
    bool _isRemedial(dynamic ex, String kind) {
      final t = (ex is Map ? (ex['type'] ?? ex['assessment_type']) : null)
          ?.toString()
          .toLowerCase()
          .replaceAll(RegExp(r'[\s_-]'), '');
      if (t != null && t.contains('${kind}remedial')) return true;

      final e = (ex is Map ? (ex['exercise'] ?? ex['exercise_name']) : null)
          ?.toString()
          .toLowerCase();
      if (e == null) return false;
      return e.startsWith('${kind.toLowerCase()}remedial');
    }

    if (formative.isNotEmpty) {
      final moved =
          formative.where((ex) => _isRemedial(ex, 'formative')).toList();
      if (moved.isNotEmpty) {
        formative =
            formative.where((ex) => !_isRemedial(ex, 'formative')).toList();
        formativeRemedial = [...formativeRemedial, ...moved];
      }
    }
    if (summative.isNotEmpty) {
      final moved =
          summative.where((ex) => _isRemedial(ex, 'summative')).toList();
      if (moved.isNotEmpty) {
        summative =
            summative.where((ex) => !_isRemedial(ex, 'summative')).toList();
        summativeRemedial = [...summativeRemedial, ...moved];
      }
    }
    // Note: logbook is now handled separately

    List<Widget> assessmentTiles = [];

    // Formative Assessments
    if (formative.isNotEmpty) {
      TextEditingController commentController = TextEditingController();
      String existingComment = formative.first['a_comment'] ?? '';
      commentController.text = existingComment;

      // Check if any marks have been submitted
      bool hasMarks = formative.any((exercise) =>
          exercise['marks_scored'] != null &&
          exercise['marks_scored'].toString().isNotEmpty &&
          exercise['marks_scored'].toString() != '0');

      assessmentTiles.add(
        ExpansionTile(
          title: const Text('Formative'),
          children: [
            ..._buildExerciseTiles(formative),
            if (!hasMarks)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Submit marks first before adding comments',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextFormField(
                controller: commentController,
                decoration: InputDecoration(
                  labelText: 'Comments',
                  border: const OutlineInputBorder(),
                  hintText: 'Enter your comments for formative assessments',
                  helperText: existingComment.isNotEmpty
                      ? 'Editing existing comment'
                      : (hasMarks ? null : 'Marks required before commenting'),
                ),
                maxLines: 3,
                enabled: hasMarks,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton(
                onPressed: hasMarks
                    ? () => saveComment('formative', commentController.text,
                        existingComment.isNotEmpty)
                    : null,
                child: Text(existingComment.isEmpty
                    ? 'Submit Comment'
                    : 'Update Comment'),
              ),
            ),
          ],
        ),
      );
    }

    // Formative Remedial Assessments
    if (formativeRemedial.isNotEmpty) {
      TextEditingController commentController = TextEditingController();
      String existingComment = formativeRemedial.first['a_comment'] ?? '';
      commentController.text = existingComment;

      // Check if any marks have been submitted
      bool hasMarks = formativeRemedial.any((exercise) =>
          exercise['marks_scored'] != null &&
          exercise['marks_scored'].toString().isNotEmpty &&
          exercise['marks_scored'].toString() != '0');

      assessmentTiles.add(
        ExpansionTile(
          title: Row(
            children: [
              const Text('Formative Remedial'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'REMEDIAL',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          children: [
            ..._buildExerciseTiles(formativeRemedial),
            if (!hasMarks)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Submit marks first before adding comments',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextFormField(
                controller: commentController,
                decoration: InputDecoration(
                  labelText: 'Comments',
                  border: const OutlineInputBorder(),
                  hintText:
                      'Enter your comments for formative remedial assessments',
                  helperText: existingComment.isNotEmpty
                      ? 'Editing existing comment'
                      : (hasMarks ? null : 'Marks required before commenting'),
                ),
                maxLines: 3,
                enabled: hasMarks,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton(
                onPressed: hasMarks
                    ? () => saveComment('formativeremedial',
                        commentController.text, existingComment.isNotEmpty)
                    : null,
                child: Text(existingComment.isEmpty
                    ? 'Submit Comment'
                    : 'Update Comment'),
              ),
            ),
          ],
        ),
      );
    }

    // Summative Assessments
    if (summative.isNotEmpty) {
      TextEditingController commentController = TextEditingController();
      String existingComment = summative.first['a_comment'] ?? '';
      commentController.text = existingComment;

      // Check if any marks have been submitted
      bool hasMarks = summative.any((exercise) =>
          exercise['marks_scored'] != null &&
          exercise['marks_scored'].toString().isNotEmpty &&
          exercise['marks_scored'].toString() != '0');

      assessmentTiles.add(
        ExpansionTile(
          title: const Text('Summative'),
          children: [
            ..._buildExerciseTiles(summative),
            if (!hasMarks)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Submit marks first before adding comments',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextFormField(
                controller: commentController,
                decoration: InputDecoration(
                  labelText: 'Comments',
                  border: const OutlineInputBorder(),
                  hintText: 'Enter your comments for summative assessments',
                  helperText: existingComment.isNotEmpty
                      ? 'Editing existing comment'
                      : (hasMarks ? null : 'Marks required before commenting'),
                ),
                maxLines: 3,
                enabled: hasMarks,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton(
                onPressed: hasMarks
                    ? () => saveComment('summative', commentController.text,
                        existingComment.isNotEmpty)
                    : null,
                child: Text(existingComment.isEmpty
                    ? 'Submit Comment'
                    : 'Update Comment'),
              ),
            ),
          ],
        ),
      );
    }

    // Summative Remedial Assessments
    if (summativeRemedial.isNotEmpty) {
      TextEditingController commentController = TextEditingController();
      String existingComment = summativeRemedial.first['a_comment'] ?? '';
      commentController.text = existingComment;

      // Check if any marks have been submitted
      bool hasMarks = summativeRemedial.any((exercise) =>
          exercise['marks_scored'] != null &&
          exercise['marks_scored'].toString().isNotEmpty &&
          exercise['marks_scored'].toString() != '0');

      assessmentTiles.add(
        ExpansionTile(
          title: Row(
            children: [
              const Text('Summative Remedial'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'REMEDIAL',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          children: [
            ..._buildExerciseTiles(summativeRemedial),
            if (!hasMarks)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Submit marks first before adding comments',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextFormField(
                controller: commentController,
                decoration: InputDecoration(
                  labelText: 'Comments',
                  border: const OutlineInputBorder(),
                  hintText:
                      'Enter your comments for summative remedial assessments',
                  helperText: existingComment.isNotEmpty
                      ? 'Editing existing comment'
                      : (hasMarks ? null : 'Marks required before commenting'),
                ),
                maxLines: 3,
                enabled: hasMarks,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton(
                onPressed: hasMarks
                    ? () => saveComment('summativeremedial',
                        commentController.text, existingComment.isNotEmpty)
                    : null,
                child: Text(existingComment.isEmpty
                    ? 'Submit Comment'
                    : 'Update Comment'),
              ),
            ),
          ],
        ),
      );
    }

    return assessmentTiles;
  }

  // New method to build separate LogBook section
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
          TextEditingController commentController = TextEditingController();
          String existingComment = logbookItems.first['a_comment'] ?? '';
          commentController.text = existingComment;

          // Check if any marks have been submitted
          bool hasMarks = logbookItems.any((exercise) =>
              exercise['marks_scored'] != null &&
              exercise['marks_scored'].toString().isNotEmpty &&
              exercise['marks_scored'].toString() != '0');

          return ExpansionTile(
            title: Text(item['unitStandardName']),
            children: [
              ..._buildExerciseTiles(logbookItems),
              if (!hasMarks)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Submit marks first before adding comments',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextFormField(
                  controller: commentController,
                  decoration: InputDecoration(
                    labelText: 'Comments',
                    border: const OutlineInputBorder(),
                    hintText: 'Enter your comments for logbook assessments',
                    helperText: existingComment.isNotEmpty
                        ? 'Editing existing comment'
                        : (hasMarks
                            ? null
                            : 'Marks required before commenting'),
                  ),
                  maxLines: 3,
                  enabled: hasMarks,
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton(
                  onPressed: hasMarks
                      ? () => saveComment('logbook', commentController.text,
                          existingComment.isNotEmpty)
                      : null,
                  child: Text(existingComment.isEmpty
                      ? 'Submit Comment'
                      : 'Update Comment'),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // New method to build separate Pothole Checklist section
  Widget _buildPotholeChecklistMainSection() {
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
          _buildPotholeChecklistSection(),
        ],
      ),
    );
  }

  Widget _buildPotholeChecklistSection() {
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

        if (!hasChecklist) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No pothole checklist found for this learner.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        return Column(
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
              subtitle: const Text('Tap to view and mark'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () =>
                  _viewPotholeChecklist(checklistType!, checklistData?['data']),
            ),
            const Divider(),
            _buildPotholeChecklistMarkingSection(checklistData),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _checkPotholeChecklistStatus() async {
    try {
      final assessmentDate = DateTime.now().toIso8601String().split('T').first;

      print(
          'DEBUG Pothole: Checking for learner ${widget.learnerId}, date $assessmentDate');

      // PRIORITY 1: Check server first using unified endpoint (checks both scanned and system)
      try {
        final url =
            '${AppConfig.baseUrl}/view_pothole_checklists.php?learner_id=${widget.learnerId}';
        print('DEBUG Pothole: Checking server at $url');

        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

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
          } else {
            print(
                'DEBUG Pothole: No checklist on server - ${data['message'] ?? 'Unknown error'}');
          }
        } else {
          print('DEBUG Pothole: Server returned status ${response.statusCode}');
        }
      } catch (e) {
        print('DEBUG Pothole: Error checking server: $e');
      }

      // PRIORITY 2: Fallback to local database for scanned document
      print('DEBUG Pothole: Checking local database as fallback');
      final scannedDoc = await DatabaseHelper().getScannedPotholeChecklist(
        learnerId: widget.learnerId,
        assessorId: '', // Empty to check any assessor
        assessmentDate: '', // Empty to check any date
      );

      if (scannedDoc != null) {
        print(
            'DEBUG Pothole: Found scanned document in local DB at ${scannedDoc['document_path']}');
        return {
          'exists': true,
          'type': 'scanned',
          'data': scannedDoc,
        };
      }

      print('DEBUG Pothole: No checklist found anywhere');
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
    print('DEBUG: data keys: ${data?.keys}');
    print('DEBUG: Full data: $data');

    // The data is already the inner data object from the server response
    if (type == 'scanned' && data?['document_path'] != null) {
      print('DEBUG: Navigating to scanned PDF view page');
      print('DEBUG: document_path=${data!['document_path']}');

      // Navigate to scanned document view page with marking
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PotholeChecklistScannedViewPage(
            documentPath: data['document_path'],
            learnerId: widget.learnerId,
            assessorId: data['assessor_id'] ?? '',
            assessmentDate: data['assessment_date'] ??
                DateTime.now().toIso8601String().split('T').first,
          ),
        ),
      );
    } else if (type == 'system' && data != null) {
      print('DEBUG: Navigating to system checklist view page');
      print(
          'DEBUG: checklist_items count: ${(data['checklist_items'] as Map?)?.length ?? 0}');

      // Navigate to full page view for system-generated checklist
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PotholeChecklistViewPage(
            checklistData: data,
            learnerId: widget.learnerId,
          ),
        ),
      );
    } else {
      print('DEBUG: No action taken - type=$type, has data=${data != null}');
      print(
          'DEBUG: Expected document_path or checklist_items but got: ${data?.keys}');
    }
  }

  Widget _buildChecklistView(Map<String, dynamic>? checklistData) {
    if (checklistData == null) {
      return const Text('No data available');
    }

    final items =
        checklistData['checklist_items'] as Map<String, dynamic>? ?? {};

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                      if (item['notes'] != null && item['notes'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 28, top: 4),
                          child: Text('Notes: ${item['notes']}',
                              style: const TextStyle(
                                  fontSize: 12, fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
                );
              }),
              const Divider(),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildPotholeChecklistMarkingSection(Map<String, dynamic>? data) {
    // TODO: Add marking functionality here
    // This will allow assessors to mark the pothole checklist
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Marking',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Marks',
              border: OutlineInputBorder(),
              hintText: 'Enter marks (e.g., 80)',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Comments',
              border: OutlineInputBorder(),
              hintText: 'Enter your assessment comments',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement save marks functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Marking functionality coming soon')),
              );
            },
            child: const Text('Submit Marks'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExerciseTiles(List<dynamic> exercises) {
    // Keys must be unique among siblings. Some POE items arrive without stable IDs,
    // so we include the index as a fallback to avoid duplicate-key crashes.
    return exercises.asMap().entries.map((entry) {
      final idx = entry.key;
      final exercise = entry.value as dynamic;

      final primaryId = exercise['id'] ??
          exercise['assessment_id'] ??
          exercise['filePath'] ??
          exercise['file_url'] ??
          exercise['fileUrl'];

      final exerciseIdentity = [
        // Always include idx because backend can legitimately return duplicated
        // rows (same question text/filePath) which would otherwise collide.
        'idx:$idx',
        primaryId ?? '',
        exercise['exercise_name'] ?? exercise['exercise'] ?? '',
        exercise['specific_outcome'] ?? '',
      ].join('|');

      return ExerciseTile(
        key: ValueKey(exerciseIdentity),
        exercise: exercise,
        learnerId: widget.learnerId,
        onSubmitMarks: submitMarks,
        onResponseMessage: (message) {
          setState(() {
            _responseMessage = message;
          });
        },
      );
    }).toList();
  }

  void saveComment(String assessmentType, String comment, bool isUpdate) async {
    if (comment.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment cannot be empty')),
      );
      return;
    }

    try {
      final url = AppConfig.buildUrl('save_comment.php');

      print('[POETab] Saving comment to: $url');
      print('[POETab] Assessment type: $assessmentType, isUpdate: $isUpdate');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learnerId': widget.learnerId,
          'assessmentType': assessmentType,
          'comment': comment,
          'isUpdate': isUpdate,
        }),
      );

      print('[POETab] Response status: ${response.statusCode}');
      print('[POETab] Response body: ${response.body}');

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          setState(() {
            _responseMessage = isUpdate
                ? 'Comment updated successfully!'
                : 'Comment saved successfully!';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_responseMessage)),
          );

          // Refresh the POE data to show updated comment
          setState(() {
            _poeData = fetchPOE(widget.learnerId);
          });
        } else if (responseData['status'] == 'error') {
          // Check if it's a duplicate that can be updated
          if (responseData['can_update'] == true && !isUpdate) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Comment Already Exists'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(responseData['message']),
                    const SizedBox(height: 8),
                    const Text('Existing comment:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(responseData['existing_comment'] ?? 'N/A'),
                    const SizedBox(height: 8),
                    const Text('New comment:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(comment),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Retry with update flag
                      saveComment(assessmentType, comment, true);
                    },
                    child: const Text('Update Comment'),
                  ),
                ],
              ),
            );
          } else {
            // Show more helpful error message
            String errorMessage = responseData['message'];
            String errorTitle = 'Error';

            // Check if it's the "no marks" error
            if (errorMessage.contains('No marks records found')) {
              errorTitle = 'Marks Required';
              errorMessage =
                  'Please submit marks for this assessment type before adding comments.\n\n'
                  'Comments are linked to marks records. You need to:\n'
                  '1. Submit marks for at least one exercise\n'
                  '2. Then you can add comments';
            }

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(errorTitle),
                content: Text(errorMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      } else {
        setState(() {
          _responseMessage = 'Server error: ${response.statusCode}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_responseMessage)),
        );
      }
    } catch (e) {
      print('[POETab] Error saving comment: $e');
      setState(() {
        _responseMessage = 'Error saving comment: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_responseMessage)),
      );
    }
  }

  Future<void> submitMarks({
    required String learnerId,
    required Map<String, dynamic> exercise,
    required String marksScored,
    required String specificOutcome,
  }) async {
    try {
      int scoredMarks = int.tryParse(marksScored) ?? 0;

      // Parse specific_outcome if it's a string
      dynamic specificOutcomeArray = specificOutcome;
      try {
        specificOutcomeArray = jsonDecode(specificOutcome);
      } catch (e) {
        print('Error parsing specificOutcome: $e');
      }

      // Check if this exercise already has marks (for update vs insert)
      bool hasExistingMarks = exercise['marks_scored'] != null &&
          exercise['marks_scored'].toString().isNotEmpty;

      // Normalize assessment type so backend duplicate-check uses consistent values.
      // Backend expects: formative, summative, logbook, formativeremedial, summativeremedial
      String rawType = (exercise['type'] ?? '').toString();
      String normalizedType = rawType.trim().toLowerCase();
      normalizedType = normalizedType.replaceAll(' ', '');
      normalizedType = normalizedType.replaceAll('_', '');
      normalizedType = normalizedType.replaceAll('-', '');

      if (normalizedType == 'formative') {
        normalizedType = 'formative';
      } else if (normalizedType == 'summative') {
        normalizedType = 'summative';
      } else if (normalizedType == 'logbook') {
        normalizedType = 'logbook';
      } else if (normalizedType == 'formativeremedial') {
        normalizedType = 'formativeremedial';
      } else if (normalizedType == 'summativeremedial') {
        normalizedType = 'summativeremedial';
      } else {
        // Fallback: try to infer from keys we already use in POE
        final exerciseName =
            (exercise['exercise'] ?? '').toString().toLowerCase();
        if (exerciseName.contains('summative') &&
            exerciseName.contains('remedial')) {
          normalizedType = 'summativeremedial';
        } else if (exerciseName.contains('formative') &&
            exerciseName.contains('remedial')) {
          normalizedType = 'formativeremedial';
        } else if (exerciseName.contains('summative')) {
          normalizedType = 'summative';
        } else if (exerciseName.contains('logbook')) {
          normalizedType = 'logbook';
        } else {
          normalizedType = 'formative';
        }
      }

      final exerciseForPayload = Map<String, dynamic>.from(exercise);
      exerciseForPayload['type'] = normalizedType;

      // Truncate exercise name to 255 characters to avoid database length errors
      if (exerciseForPayload['exercise'] != null) {
        String name = exerciseForPayload['exercise'].toString();
        if (name.length > 255) {
          exerciseForPayload['exercise'] = name.substring(0, 252) + '...';
        }
      } else if (exerciseForPayload['exercise_name'] != null) {
        String name = exerciseForPayload['exercise_name'].toString();
        if (name.length > 255) {
          exerciseForPayload['exercise_name'] = name.substring(0, 252) + '...';
        }
      }

      final payload = {
        'learnerId': learnerId,
        'exercise': exerciseForPayload,
        'marksScored': scoredMarks,
        'assessmentType': normalizedType,
        'specific_outcome': specificOutcomeArray,
        'isUpdate': hasExistingMarks, // Tell backend this is an update
      };
      print(
          "Submitting payload (isUpdate: $hasExistingMarks): ${jsonEncode(payload)}");

      final saveMarksUrl = AppConfig.buildUrl('save_marks.php');
      print('[POETab] Saving marks to: $saveMarksUrl');

      final response = await http
          .post(
            Uri.parse(saveMarksUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      print('[POETab] save_marks.php status: ${response.statusCode}');
      print('[POETab] save_marks.php body: ${response.body}');

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);

        String successMessage = 'Marks saved successfully!';
        if (responseData['action'] == 'update') {
          successMessage = 'Marks updated successfully!';
        } else if (responseData['action'] == 'insert') {
          successMessage = 'Marks saved successfully!';
        }

        if (responseData['status'] == 'success') {
          // Update the local exercise data immediately
          exercise['marks_scored'] = int.tryParse(marksScored) ?? 0;
          if (responseData['filePath'] != null) {
            exercise['filePath'] = responseData['filePath'];
          }

          // Refresh the entire POE data to ensure UI consistency
          _refreshData();

          setState(() {
            _responseMessage = successMessage;
          });
        } else {
          setState(() {
            _responseMessage =
                'Failed to save marks: ${responseData['message']}';
          });
        }

        if (responseData['status'] == 'error') {
          // Check if it's a duplicate that can be updated
          if (responseData['can_update'] == true) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Marks Already Exist'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(responseData['message']),
                    const SizedBox(height: 8),
                    Text('Existing marks: ${responseData['existing_marks']}'),
                    Text('New marks: $marksScored'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      // Retry with update flag
                      final updatePayload = Map<String, dynamic>.from(payload);
                      updatePayload['isUpdate'] = true;

                      final updateResponse = await http
                          .post(
                            Uri.parse(saveMarksUrl),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode(updatePayload),
                          )
                          .timeout(const Duration(seconds: 15));
                      print(
                          '[POETab] save_marks.php(update) status: ${updateResponse.statusCode}');
                      print(
                          '[POETab] save_marks.php(update) body: ${updateResponse.body}');

                      if (updateResponse.statusCode == 200) {
                        var updateData = jsonDecode(updateResponse.body);
                        if (updateData['status'] == 'success') {
                          // Update the local exercise data immediately
                          exercise['marks_scored'] =
                              int.tryParse(marksScored) ?? 0;

                          // Refresh the entire POE data to ensure UI consistency
                          _refreshData();

                          setState(() {
                            _responseMessage = 'Marks updated successfully!';
                          });
                        } else {
                          setState(() {
                            _responseMessage =
                                'Failed to update marks: ${updateData['message']}';
                          });
                        }
                      }
                    },
                    child: const Text('Update Marks'),
                  ),
                ],
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
        }
      } else {
        setState(() {
          _responseMessage =
              'Server error: ${response.statusCode} - ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _responseMessage = 'Error submitting marks: $e';
      });
    }
  }
}

class ExerciseTile extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final String learnerId;
  final Future<void> Function({
    required String learnerId,
    required Map<String, dynamic> exercise,
    required String marksScored,
    required String specificOutcome,
  }) onSubmitMarks;
  final void Function(String) onResponseMessage;

  const ExerciseTile({
    super.key,
    required this.exercise,
    required this.learnerId,
    required this.onSubmitMarks,
    required this.onResponseMessage,
  });

  @override
  _ExerciseTileState createState() => _ExerciseTileState();
}

class _ExerciseTileState extends State<ExerciseTile> {
  late String marksScored;
  late TextEditingController controller;
  bool isSaving = false;

  String _displayExerciseName(String raw) {
    var s = raw.trim();
    final re = RegExp(
      r'^(FormativeRemedial|SummativeRemedial)\s*[-–—]\s*\d+\s*[-–—]\s*',
      caseSensitive: false,
    );
    s = s.replaceFirst(re, '');
    return s.isEmpty ? raw : s;
  }

  @override
  void initState() {
    super.initState();
    marksScored = widget.exercise['marks_scored']?.toString() ?? '';
    controller = TextEditingController(text: marksScored);
  }

  @override
  void didUpdateWidget(ExerciseTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    String newMarksScored = widget.exercise['marks_scored']?.toString() ?? '';
    if (newMarksScored != marksScored && !isSaving) {
      setState(() {
        marksScored = newMarksScored;
        controller.text = marksScored;
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String filePath = (widget.exercise['filePath'] ?? '').toString();
    final String fileUrl = (widget.exercise['fileUrl'] ?? '').toString();
    final bool isManualMark = filePath.contains('MANUALLY_MARKED');
    final bool hasFile =
        (filePath.isNotEmpty || fileUrl.isNotEmpty) && !isManualMark;

    String maxMarks = widget.exercise['marks']?.toString() ?? '0';
    int maxAllowedMarks = int.tryParse(maxMarks) ?? 0;
    String specificOutcome =
        widget.exercise['specific_outcome']?.toString() ?? 'N/A';
    final String rawExerciseName =
        (widget.exercise['exercise'] ?? 'N/A').toString();
    final String displayExerciseName = _displayExerciseName(rawExerciseName);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayExerciseName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text('Max Marks: $maxMarks | SO: $specificOutcome',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                if (hasFile)
                  IconButton(
                    icon:
                        const Icon(Icons.picture_as_pdf, color: Colors.purple),
                    onPressed: () async {
                      if (filePath.isNotEmpty) {
                        final serveUrl =
                            await AppConfig.buildServeFileUrl(filePath);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PdfViewerScreen(pdfUrl: serveUrl),
                          ),
                        );
                      }
                    },
                    tooltip: 'View File',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scored Marks',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter marks',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixText: '/ $maxMarks',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            int? enteredMarks = int.tryParse(value);
                            if (enteredMarks != null &&
                                enteredMarks > maxAllowedMarks) {
                              controller.text = maxAllowedMarks.toString();
                              controller.selection = TextSelection.fromPosition(
                                  TextPosition(offset: controller.text.length));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                String enteredMarks = controller.text.trim();
                                if (enteredMarks.isNotEmpty) {
                                  setState(() => isSaving = true);
                                  await widget.onSubmitMarks(
                                    learnerId: widget.learnerId,
                                    exercise: widget.exercise,
                                    marksScored: enteredMarks,
                                    specificOutcome: specificOutcome,
                                  );
                                  setState(() {
                                    marksScored = enteredMarks;
                                    isSaving = false;
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Please enter a mark')),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(marksScored.isEmpty ? 'Save' : 'Update'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isManualMark)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text('Manually marked - No scanned document',
                        style:
                            TextStyle(color: Colors.orange[700], fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;

  const PdfViewerScreen({super.key, required this.pdfUrl});

  @override
  _PdfViewerScreenState createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      // Create a unique filename based on the URL
      final fileName = 'pdf_${widget.pdfUrl.hashCode.toString()}.pdf';
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');

      // Check if file already exists locally
      if (await file.exists()) {
        print('[PDF] Loading existing file found locally: ${file.path}');
        setState(() {
          _localPath = file.path;
          _isLoading = false;
        });
        return;
      }

      // If file doesn't exist, try to download it
      print('[PDF] Downloading PDF from: ${widget.pdfUrl}');
      final response = await http.get(Uri.parse(widget.pdfUrl));
      print('[PDF] Response status code: ${response.statusCode}');
      print('[PDF] Response headers: ${response.headers}');
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        print(
            '[PDF] PDF saved to: ${file.path}, size: ${response.bodyBytes.length} bytes');
        setState(() {
          _localPath = file.path;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              'Failed to download PDF (status ${response.statusCode}): ${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[PDF ERROR] Exception: $e');
      setState(() {
        _error = 'Error loading PDF: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Viewer')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _error != null
                ? Text(_error!)
                : _localPath != null
                    ? PDFView(
                        filePath: _localPath!,
                        onError: (error) {
                          setState(() {
                            _error = 'Error loading PDF: $error';
                          });
                        },
                        onPageError: (page, error) {
                          setState(() {
                            _error = 'Error on page $page: $error';
                          });
                        },
                      )
                    : const Text('No PDF available'),
      ),
    );
  }
}

Widget _buildAssessorFeedback({required String facilitatorId}) {
  Future<List<dynamic>> fetchClasses(String facilitatorId) async {
    try {
      final url = AppConfig.buildUrl('get_classes.php', queryParams: {
        'facilitator_id': facilitatorId,
      });

      print('[AssessorFeedback] Fetching classes from: $url');

      final response = await http.get(Uri.parse(url));

      print('[AssessorFeedback] Response Status: ${response.statusCode}');
      print('[AssessorFeedback] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if response is an error object
        if (data is Map && data['status'] == 'error') {
          throw Exception('Server error: ${data['message']}');
        }

        // Return the data (should be a list)
        if (data is List) {
          return data;
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception(
            'Failed to load classes. Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('[AssessorFeedback] Error fetching classes: $e');
      throw Exception('Failed to load classes. Error: $e');
    }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'Facilitator ID: $facilitatorId',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<dynamic>>(
          future: fetchClasses(facilitatorId),
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
                      String numberOfLearners =
                          classData['numberOfLearners'].toString();
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
                                  builder: (context) =>
                                      ClassInfoPage(classId: classId),
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

class ClassInfoPage extends StatelessWidget {
  final String classId;

  const ClassInfoPage({super.key, required this.classId});

  // Function to fetch learners from the PHP backend
  Future<List<dynamic>> fetchLearners(String classId) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://rlms.rlms.co.za/mobile/get_f_learners.php?classID=$classId'),
      );

      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to load learners. Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load learners. Error: $e');
    }
  }

  // Helper function to get row color (you can modify this as per your logic)
  Color _getRowColor(dynamic learnerData) {
    return learnerData['LearnerID'].hashCode.isEven
        ? Colors.grey[200]!
        : Colors.white;
  }

  // Function to handle report generation
  Future<void> _generateAndViewReport(
      BuildContext context, String learnerId) async {
    final url = Uri.parse(
        'https://rlms.rlms.co.za/mobile/assessor_feedback.php?learner_id=$learnerId');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Class Details: $classId')),
      body: FutureBuilder<List<dynamic>>(
        future: fetchLearners(classId),
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
                  String learnerId =
                      learnerData['LearnerID']?.toString() ?? 'N/A';
                  String firstName =
                      learnerData['Name']?.toString() ?? 'Unknown';
                  String lastName =
                      learnerData['Surname']?.toString() ?? 'Unknown';
                  String idNumber =
                      learnerData['IDNumber']?.toString() ?? 'Unknown';
                  Color rowColor = _getRowColor(learnerData);

                  return DataRow(
                    color: WidgetStateColor.resolveWith((states) => rowColor),
                    cells: [
                      DataCell(Text(learnerId)),
                      DataCell(Text(firstName)),
                      DataCell(Text(lastName)),
                      DataCell(Text(idNumber)),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf),
                            tooltip: 'Assessor Feedback PDF',
                            onPressed: () =>
                                _generateAndViewReport(context, learnerId),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PotholeChecklistPage(
                                    learnerId: learnerId,
                                    learnerFirstName: firstName,
                                    learnerLastName: lastName,
                                    learnerIdNumber: idNumber,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Checklist'),
                          ),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            );
          }
        },
      ),
    );
  }
}

class AssessmentReviewPage extends StatefulWidget {
  final String facilitatorId;
  final bool isARPL;

  const AssessmentReviewPage({
    super.key,
    required this.facilitatorId,
    this.isARPL = false,
  });

  @override
  _AssessmentReviewPageState createState() => _AssessmentReviewPageState();
}

class _AssessmentReviewPageState extends State<AssessmentReviewPage> {
  late Future<List<dynamic>> _unitStandards;
  String? _selectedLearnerId;
  List<dynamic> _learners = [];
  bool _isLoadingLearners = true;

  @override
  void initState() {
    super.initState();
    _fetchLearners();
    _unitStandards = Future.value([]);
  }

  Future<void> _fetchLearners() async {
    try {
      final db = await DatabaseHelper().database;
      final facilitatorClasses = await db.query(
        'facilitator',
        columns: ['classID'],
        where: 'facilitator_id = ?',
        whereArgs: [widget.facilitatorId],
      );

      Set<String> classIds = {};
      for (var row in facilitatorClasses) {
        String ids = row['classID']?.toString() ?? '';
        if (ids.isNotEmpty) {
          classIds.addAll(ids.split(',').map((e) => e.trim()));
        }
      }

      if (classIds.isNotEmpty) {
        final learnersList = await db.query(
          'learnerdetails',
          where: 'classID IN (${classIds.map((_) => '?').join(',')})',
          whereArgs: classIds.toList(),
        );

        setState(() {
          _learners = learnersList;
          _isLoadingLearners = false;
        });
      } else {
        setState(() => _isLoadingLearners = false);
      }
    } catch (e) {
      print('Error fetching learners: $e');
      setState(() => _isLoadingLearners = false);
    }
  }

  Future<List<dynamic>> fetchUnitStandards(
      String facilitatorId, String? learnerId) async {
    if (learnerId == null) return [];
    try {
      String url =
          '${AppConfig.baseUrl}/get_assessment_preparation.php?facilitator_id=$facilitatorId&learner_id=$learnerId';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return data['data'];
        } else {
          throw Exception('Failed to load unit standards: ${data['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching unit standards: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLearner = _selectedLearnerId == null
        ? null
        : _learners.isEmpty
            ? null
            : _learners
                    .any((l) => l['LearnerID'].toString() == _selectedLearnerId)
                ? _learners.firstWhere(
                    (l) => l['LearnerID'].toString() == _selectedLearnerId)
                : null;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isARPL ? 'ARPL Portfolio Review' : 'Assessment Review'),
        backgroundColor: widget.isARPL ? Colors.indigo : Colors.blue,
      ),
      body: _isLoadingLearners
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Candidate',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedLearnerId,
                    hint: const Text(
                        'Choose a learner to see their unit standards'),
                    isExpanded: true,
                    items: _learners.map((learner) {
                      return DropdownMenuItem<String>(
                        value: learner['LearnerID'].toString(),
                        child: Text('${learner['Name']} ${learner['Surname']}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLearnerId = value;
                        _unitStandards = fetchUnitStandards(
                            widget.facilitatorId, _selectedLearnerId);
                      });
                    },
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedLearnerId != null) ...[
                    if (selectedLearner != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.indigo.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Candidate: ${selectedLearner['Name']} ${selectedLearner['Surname']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo),
                        ),
                      ),
                    Expanded(
                      child: FutureBuilder<List<dynamic>>(
                        future: _unitStandards,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Center(
                                child: Text('Error: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.red)));
                          } else if (!snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return const Center(
                                child: Text(
                                    'No unit standards found for this PoE.',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey)));
                          } else {
                            List<dynamic> unitStandards = snapshot.data!;
                            return ListView.builder(
                              itemCount: unitStandards.length,
                              itemBuilder: (context, index) {
                                var unitStandard = unitStandards[index];
                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: widget.isARPL
                                          ? Colors.indigo
                                          : Colors.blue,
                                      foregroundColor: Colors.white,
                                      child: Text(
                                          unitStandard['unitstandard_id']
                                              .toString()),
                                    ),
                                    title: Text(
                                        unitStandard['unitstandard_name'] ??
                                            'Unknown Unit Standard',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    trailing: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AssessmentReviewDetailPage(
                                              unitStandardId: unitStandard[
                                                      'unitstandard_id']
                                                  .toString(),
                                              facilitatorId:
                                                  widget.facilitatorId,
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: widget.isARPL
                                            ? Colors.indigo
                                            : Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Open'),
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ],
                  if (_selectedLearnerId != null) ...[
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }
}

class AssessmentReviewDetailPage extends StatefulWidget {
  final String unitStandardId;
  final String facilitatorId;

  const AssessmentReviewDetailPage({
    super.key,
    required this.unitStandardId,
    required this.facilitatorId,
  });

  @override
  _AssessmentReviewDetailPageState createState() =>
      _AssessmentReviewDetailPageState();
}

class _AssessmentReviewDetailPageState
    extends State<AssessmentReviewDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _learnerNameController = TextEditingController();
  final TextEditingController _assessorNameController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  DateTime? _reviewDate;
  String _responseMessage = '';
  bool _isSubmitting = false;
  bool _showForm = false;
  String? _selectedLearnerId;

  final SignatureController _learnerSig = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);
  final SignatureController _assessorSig = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);

  // Review dimensions with assessor and learner agreements, and action text
  final List<Map<String, dynamic>> _reviewDimensions = [
    {
      'description':
          'The principles/criteria for good assessment were achieved.',
      'assessorAgree': false,
      'assessorDisagree': false,
      'learnerAgree': false,
      'learnerDisagree': false,
      'action': TextEditingController(),
    },
    {
      'description': 'The assessment related to the registered unit standard.',
      'assessorAgree': false,
      'assessorDisagree': false,
      'learnerAgree': false,
      'learnerDisagree': false,
      'action': TextEditingController(),
    },
    {
      'description': 'The assessment was practicable.',
      'assessorAgree': false,
      'assessorDisagree': false,
      'learnerAgree': false,
      'learnerDisagree': false,
      'action': TextEditingController(),
    },
    {
      'description':
          'It was time efficient and cost-effective and did not interfere with my normal responsibilities.',
      'assessorAgree': false,
      'assessorDisagree': false,
      'learnerAgree': false,
      'learnerDisagree': false,
      'action': TextEditingController(),
    },
    {
      'description':
          'The assessment instruments were fair, clear and understandable.',
      'assessorAgree': false,
      'assessorDisagree': false,
      'learnerAgree': false,
      'learnerDisagree': false,
      'action': TextEditingController(),
    },
    {
      'description':
          'The assessment judgements were made against set requirements.',
      'assessorAgree': false,
      'assessorDisagree': false,
      'learnerAgree': false,
      'learnerDisagree': false,
      'action': TextEditingController(),
    },
    {
      'description': 'The venue and equipment were functional.',
      'assessorAgree': false,
      'assessorDisagree': false,
      'learnerAgree': false,
      'learnerDisagree': false,
      'action': TextEditingController(),
    },
    {
      'description':
          'Special needs were identified and assessment plan was adjusted.',
      'assessorAgree': false,
      'assessorDisagree': false,
      'learnerAgree': false,
      'learnerDisagree': false,
      'action': TextEditingController(),
    },
    {
      'description': 'Feedback was constructive against the evidence required.',
      'assessorAgree': false,
      'assessorDisagree': false,
      'learnerAgree': false,
      'learnerDisagree': false,
      'action': TextEditingController(),
    },
    {
      'description': 'An opportunity to appeals was given.',
      'assessorAgree': false,
      'assessorDisagree': false,
      'learnerAgree': false,
      'learnerDisagree': false,
      'action': TextEditingController(),
    },
    {
      'description': 'The evidence was recorded.',
      'assessorAgree': false,
      'assessorDisagree': false,
      'learnerAgree': false,
      'learnerDisagree': false,
      'action': TextEditingController(),
    },
  ];

  @override
  void dispose() {
    _learnerNameController.dispose();
    _assessorNameController.dispose();
    _venueController.dispose();
    _learnerSig.dispose();
    _assessorSig.dispose();
    for (var dimension in _reviewDimensions) {
      dimension['action'].dispose();
    }
    super.dispose();
  }

  Future<String> _fetchClassId(String facilitatorId) async {
    final response = await http.get(
      Uri.parse(
          'https://rlms.rlms.co.za/mobile/fetch_class_id.php?facilitator_id=$facilitatorId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      if (data.isNotEmpty && data['classID'] != null) {
        return data['classID'].toString();
      } else {
        throw Exception('No class found for facilitator ID: $facilitatorId');
      }
    } else {
      throw Exception('Failed to load class ID: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> fetchLearners(String classId) async {
    final response = await http.get(
      Uri.parse(
          'https://rlms.rlms.co.za/mobile/fetch_learners_by_class.php?class_id=$classId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load learners: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> _fetchLearnersForFacilitator() async {
    String classId = await _fetchClassId(widget.facilitatorId);
    return fetchLearners(classId);
  }

  Future<Map<String, dynamic>> _fetchFacilitatorDetails(
      String facilitatorId) async {
    final response = await http.get(
      Uri.parse(
          'https://rlms.rlms.co.za/mobile/fetch_facilitator_details.php?facilitator_id=$facilitatorId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        return data;
      } else {
        throw Exception('No facilitator found for ID: $facilitatorId');
      }
    } else {
      throw Exception(
          'Failed to load facilitator details: ${response.statusCode}');
    }
  }

  Future<String> _fetchClassName(String classId) async {
    final response = await http.get(
      Uri.parse(
          'https://rlms.rlms.co.za/mobile/fetch_class_name.php?class_id=$classId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      if (data.isNotEmpty && data['className'] != null) {
        return data['className'].toString();
      } else {
        throw Exception('No class found for class ID: $classId');
      }
    } else {
      throw Exception('Failed to load class name: ${response.statusCode}');
    }
  }

  void _selectLearner(BuildContext context, String learnerId, String firstName,
      String lastName) async {
    setState(() {
      _selectedLearnerId = learnerId;
      _learnerNameController.text = '$firstName $lastName';
      _showForm = true;
    });

    try {
      // Fetch facilitator details
      var facilitatorDetails =
          await _fetchFacilitatorDetails(widget.facilitatorId);
      String facilitatorFirstName = facilitatorDetails['firstName'];
      String facilitatorLastName = facilitatorDetails['lastName'];
      String classId = facilitatorDetails['classID'];

      // Fetch class name
      String className = await _fetchClassName(classId);

      // Update the form fields
      setState(() {
        _assessorNameController.text =
            '$facilitatorFirstName $facilitatorLastName';
        _venueController.text = className;
      });
    } catch (e) {
      setState(() {
        _responseMessage = 'Error fetching facilitator or class details: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _reviewDate = picked;
      });
    }
  }

  Future<void> _saveReview() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _responseMessage = '';
        _isSubmitting = true;
      });

      try {
        final payload = {
          'unitstandard_id': widget.unitStandardId,
          'facilitator_id': widget.facilitatorId,
          'learner_id': _selectedLearnerId,
          'learner_name': _learnerNameController.text,
          'assessor_name': _assessorNameController.text,
          'venue': _venueController.text,
          'review_date': _reviewDate?.toIso8601String().split('T')[0],
          'review_dimensions': _reviewDimensions
              .map((dim) => {
                    'description': dim['description'],
                    'assessor_agree': dim['assessorAgree'] ?? false,
                    'assessor_disagree': dim['assessorDisagree'] ?? false,
                    'learner_agree': dim['learnerAgree'] ?? false,
                    'learner_disagree': dim['learnerDisagree'] ?? false,
                    'action': dim['action'].text,
                  })
              .toList(),
        };

        print("Sending payload: ${jsonEncode(payload)}");
        final response = await http.post(
          Uri.parse(
              'https://rlms.rlms.co.za/mobile/save_assessment_review.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        print("Raw response: ${response.statusCode} - ${response.body}");
        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          setState(() {
            _responseMessage = data['status'] == 'success'
                ? 'Review saved successfully!'
                : 'Failed to save review: ' + data['message'];
            _isSubmitting = false;
          });
          if (data['status'] == 'success') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Review saved successfully!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ' + data['message'])),
            );
          }
        } else {
          setState(() {
            _responseMessage =
                'Server error: ${response.statusCode} - ${response.body}';
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: ${response.statusCode}')),
          );
        }
      } catch (e) {
        setState(() {
          _responseMessage = 'Error saving review: $e';
          _isSubmitting = false;
        });
        print("Exception: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Unit Standard: ${widget.unitStandardId}'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _showForm ? _buildForm(context) : _buildLearnerList(context),
      ),
    );
  }

  Widget _buildLearnerList(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchLearnersForFacilitator(),
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
                String learnerId =
                    learnerData['LearnerID']?.toString() ?? 'N/A';
                String firstName = learnerData['Name']?.toString() ?? 'Unknown';
                String lastName =
                    learnerData['Surname']?.toString() ?? 'Unknown';
                String idNumber = learnerData['IDNumber']?.toString() ?? 'N/A';

                return DataRow(
                  cells: [
                    DataCell(Text(learnerId)),
                    DataCell(Text(firstName)),
                    DataCell(Text(lastName)),
                    DataCell(Text(idNumber)),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _selectLearner(
                            context, learnerId, firstName, lastName),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        }
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
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
                child: const Icon(Icons.reviews, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                'Assessment Review',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Facilitator ID: ${widget.facilitatorId}',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildTextField(
                          'Name of Learner', _learnerNameController),
                      const SizedBox(height: 16),
                      _buildTextField(
                          'Name of Assessor', _assessorNameController),
                      const SizedBox(height: 16),
                      _buildTextField('Venue', _venueController),
                      const SizedBox(height: 16),
                      _buildDateField('Date of Review', _reviewDate),
                      const SizedBox(height: 16),
                      const Text('Unit Standard',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(widget.unitStandardId),
                      const SizedBox(height: 16),
                      _buildReviewTable(),
                      const SizedBox(height: 24),
                      DualSignaturePad(
                        title: 'Review Signatures',
                        learnerController: _learnerSig,
                        assessorController: _assessorSig,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _saveReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Save Review'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _responseMessage,
            style: TextStyle(
              color: _responseMessage.contains('success')
                  ? Colors.green
                  : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) => value!.isEmpty ? '$label is required' : null,
    );
  }

  Widget _buildDateField(String label, DateTime? date) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: () => _selectDate(context),
          child: Text(
            date != null
                ? '${date.day}/${date.month}/${date.year}'
                : 'Select Date',
            style: const TextStyle(color: Colors.blue),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        dataRowHeight: 150,
        columns: const [
          DataColumn(label: Text('Review Dimension')),
          DataColumn(
            label: SizedBox(
              width: 120,
              child: Text('Assessor'),
            ),
          ),
          DataColumn(
            label: VerticalDivider(thickness: 1, color: Colors.grey),
          ),
          DataColumn(
            label: SizedBox(
              width: 120,
              child: Text('Learner/Candidate'),
            ),
          ),
          DataColumn(
            label: VerticalDivider(thickness: 1, color: Colors.grey),
          ),
          DataColumn(
            label: SizedBox(
              width: 200,
              child: Text('Action'),
            ),
          ),
        ],
        rows: _reviewDimensions.map((dim) {
          return DataRow(cells: [
            DataCell(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: SizedBox(
                  width: 300,
                  child: Text(
                    dim['description'] ?? '',
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
            ),
            DataCell(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: SizedBox(
                  width: 120,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: dim['assessorAgree'] ?? false,
                            onChanged: (value) {
                              setState(() {
                                dim['assessorAgree'] = value ?? false;
                                if (value == true) {
                                  dim['assessorDisagree'] = false;
                                }
                              });
                            },
                          ),
                          const Text(' Agree'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: dim['assessorDisagree'] ?? false,
                            onChanged: (value) {
                              setState(() {
                                dim['assessorDisagree'] = value ?? false;
                                if (value == true) dim['assessorAgree'] = false;
                              });
                            },
                          ),
                          const Text('Disagree'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const DataCell(
              SizedBox(
                height: 150,
                child: VerticalDivider(thickness: 1, color: Colors.grey),
              ),
            ),
            DataCell(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: SizedBox(
                  width: 120,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: dim['learnerAgree'] ?? false,
                            onChanged: (value) {
                              setState(() {
                                dim['learnerAgree'] = value ?? false;
                                if (value == true) {
                                  dim['learnerDisagree'] = false;
                                }
                              });
                            },
                          ),
                          const Text(' Agree'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: dim['learnerDisagree'] ?? false,
                            onChanged: (value) {
                              setState(() {
                                dim['learnerDisagree'] = value ?? false;
                                if (value == true) dim['learnerAgree'] = false;
                              });
                            },
                          ),
                          const Text('Disagree'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const DataCell(
              SizedBox(
                height: 150,
                child: VerticalDivider(thickness: 1, color: Colors.grey),
              ),
            ),
            DataCell(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: SizedBox(
                  width: 200,
                  child: TextFormField(
                    controller: dim['action'],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Action',
                    ),
                    maxLines: 4,
                    textAlignVertical: TextAlignVertical.center,
                  ),
                ),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}

class AppealFormPage extends StatefulWidget {
  final String facilitatorId;

  const AppealFormPage({super.key, required this.facilitatorId});

  @override
  _AppealFormPageState createState() => _AppealFormPageState();
}

class _AppealFormPageState extends State<AppealFormPage> {
  late Future<List<dynamic>> _unitStandards;

  @override
  void initState() {
    super.initState();
    _unitStandards = fetchUnitStandards(widget.facilitatorId);
  }

  Future<List<dynamic>> fetchUnitStandards(String facilitatorId) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://rlms.rlms.co.za/mobile/get_assessment_preparation.php?facilitator_id=$facilitatorId'),
      );
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['status'] == 'success') return data['data'];
        throw Exception('Failed to load unit standards: ${data['message']}');
      }
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching unit standards: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Appeal Form'), backgroundColor: Colors.blue),
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
                    gradient:
                        LinearGradient(colors: [Colors.blue, Colors.indigo]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.approval, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text('Appeal Form',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Facilitator ID: ${widget.facilitatorId}',
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FutureBuilder<List<dynamic>>(
                    future: _unitStandards,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                            child: Text('Error: ${snapshot.error}',
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                            child: Text('No unit standards found.',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey)));
                      }
                      List<dynamic> unitStandards = snapshot.data!;
                      return ListView.builder(
                        itemCount: unitStandards.length,
                        itemBuilder: (context, index) {
                          var unitStandard = unitStandards[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                              leading: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  child: Text(unitStandard['unitstandard_id']
                                      .toString())),
                              title: Text(
                                  unitStandard['unitstandard_name'] ??
                                      'Unknown Unit Standard',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AppealFormDetailPage(
                                              unitStandardId: unitStandard[
                                                      'unitstandard_id']
                                                  .toString(),
                                              facilitatorId:
                                                  widget.facilitatorId),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8)),
                                child: const Text('Open'),
                              ),
                            ),
                          );
                        },
                      );
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

class AppealFormDetailPage extends StatefulWidget {
  final String unitStandardId;
  final String facilitatorId;

  const AppealFormDetailPage(
      {super.key, required this.unitStandardId, required this.facilitatorId});

  @override
  _AppealFormDetailPageState createState() => _AppealFormDetailPageState();
}

class _AppealFormDetailPageState extends State<AppealFormDetailPage> {
  final _formKey = GlobalKey<FormState>();
  // Section A: Detail of Appeal
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _nqfLevelController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _creditsController = TextEditingController();
  DateTime? _assessmentDate;
  // Section B: Candidate Details
  final TextEditingController _candidateSurnameController =
      TextEditingController();
  final TextEditingController _candidateNameController =
      TextEditingController();
  final TextEditingController _candidateIdNumberController =
      TextEditingController();
  final TextEditingController _reasonDisagreementController =
      TextEditingController();
  final SignatureController _candidateSignatureController =
      SignatureController(penStrokeWidth: 5, penColor: Colors.black);
  DateTime? _candidateDate;
  // Section C: Assessor Details
  final TextEditingController _assessorSurnameController =
      TextEditingController();
  final TextEditingController _assessorNameController = TextEditingController();
  final TextEditingController _assessorRegNumberController =
      TextEditingController();
  final TextEditingController _reasonDecisionController =
      TextEditingController();
  final SignatureController _assessorSignatureController =
      SignatureController(penStrokeWidth: 5, penColor: Colors.black);
  DateTime? _assessorDate;

  String _responseMessage = '';
  bool _isSubmitting = false;
  Uint8List? _candidateSignature;
  Uint8List? _assessorSignature;

  @override
  void dispose() {
    _titleController.dispose();
    _nqfLevelController.dispose();
    _numberController.dispose();
    _creditsController.dispose();
    _candidateSurnameController.dispose();
    _candidateNameController.dispose();
    _candidateIdNumberController.dispose();
    _reasonDisagreementController.dispose();
    _candidateSignatureController.dispose();
    _assessorSurnameController.dispose();
    _assessorNameController.dispose();
    _assessorRegNumberController.dispose();
    _reasonDecisionController.dispose();
    _assessorSignatureController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, String field) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (field == 'assessment') {
          _assessmentDate = picked;
        } else if (field == 'candidate')
          _candidateDate = picked;
        else if (field == 'assessor') _assessorDate = picked;
      });
    }
  }

  Future<void> _generatePDF() async {
    final pdf = pw.Document();

    if (_candidateSignatureController.isNotEmpty) {
      _candidateSignature = await _candidateSignatureController.toPngBytes();
    }
    if (_assessorSignatureController.isNotEmpty) {
      _assessorSignature = await _assessorSignatureController.toPngBytes();
    }

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('A. Detail of Appeal',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Title: ${_titleController.text}'),
            pw.Text('NQF Level: ${_nqfLevelController.text}'),
            pw.Text('Number: ${_numberController.text}'),
            pw.Text('Credits: ${_creditsController.text}'),
            pw.Text(
                'Assessment Date: ${_assessmentDate?.toIso8601String().split('T')[0] ?? ''}'),
            pw.SizedBox(height: 20),
            pw.Text('B. Candidate Details',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Surname: ${_candidateSurnameController.text}'),
            pw.Text('Name: ${_candidateNameController.text}'),
            pw.Text('ID Number: ${_candidateIdNumberController.text}'),
            pw.Text(
                'Reason for Disagreement: ${_reasonDisagreementController.text}'),
            pw.Text('Signature:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            _candidateSignature != null
                ? pw.Image(pw.MemoryImage(_candidateSignature!),
                    width: 100, height: 50)
                : pw.Text('No signature provided'),
            pw.Text(
                'Date: ${_candidateDate?.toIso8601String().split('T')[0] ?? ''}'),
            pw.SizedBox(height: 20),
            pw.Text('C. Assessor Details',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Surname: ${_assessorSurnameController.text}'),
            pw.Text('Name: ${_assessorNameController.text}'),
            pw.Text('Reg Number: ${_assessorRegNumberController.text}'),
            pw.Text('Reason for Decision: ${_reasonDecisionController.text}'),
            pw.Text('Signature:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            _assessorSignature != null
                ? pw.Image(pw.MemoryImage(_assessorSignature!),
                    width: 100, height: 50)
                : pw.Text('No signature provided'),
            pw.Text(
                'Date: ${_assessorDate?.toIso8601String().split('T')[0] ?? ''}'),
          ],
        ),
      ),
    );

    final directory = await getTemporaryDirectory();
    final file =
        File('${directory.path}/appeal_form_${widget.unitStandardId}.pdf');
    await file.writeAsBytes(await pdf.save());

    setState(() {
      _responseMessage = 'PDF generated successfully!';
    });

    OpenFile.open(file.path);
  }

  Future<void> _saveAppeal() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _responseMessage = '';
        _isSubmitting = true;
      });

      try {
        final payload = {
          'unitstandard_id': widget.unitStandardId,
          'facilitator_id': widget.facilitatorId,
          'appeal_details': {
            'title': _titleController.text,
            'nqf_level': _nqfLevelController.text,
            'number': _numberController.text,
            'credits': _creditsController.text,
            'assessment_date':
                _assessmentDate?.toIso8601String().split('T')[0] ?? '',
          },
          'candidate_details': {
            'surname': _candidateSurnameController.text,
            'name': _candidateNameController.text,
            'id_number': _candidateIdNumberController.text,
            'reason_disagreement': _reasonDisagreementController.text,
            'signature': _candidateSignatureController.isNotEmpty
                ? base64Encode(
                    await _candidateSignatureController.toPngBytes() ??
                        Uint8List(0))
                : '',
            'date': _candidateDate?.toIso8601String().split('T')[0] ?? '',
          },
          'assessor_details': {
            'surname': _assessorSurnameController.text,
            'name': _assessorNameController.text,
            'reg_number': _assessorRegNumberController.text,
            'reason_decision': _reasonDecisionController.text,
            'signature': _assessorSignatureController.isNotEmpty
                ? base64Encode(
                    await _assessorSignatureController.toPngBytes() ??
                        Uint8List(0))
                : '',
            'date': _assessorDate?.toIso8601String().split('T')[0] ?? '',
          },
        };

        final response = await http.post(
          Uri.parse('https://rlms.rlms.co.za/mobile/save_appeal_form.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        print('Raw server response: ${response.body}'); // Debug raw response

        if (response.statusCode == 200) {
          try {
            var data = jsonDecode(response.body);
            setState(() {
              _responseMessage = data['status'] == 'success'
                  ? 'Appeal saved successfully!'
                  : 'Failed to save appeal: ${data['message']}';
              _isSubmitting = false;
            });
            if (data['status'] == 'success') {
              await _generatePDF();
            }
          } catch (e) {
            setState(() {
              _responseMessage =
                  'Failed to parse server response: $e\nRaw response: ${response.body}';
              _isSubmitting = false;
            });
          }
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(_responseMessage)));
        } else {
          setState(() {
            _responseMessage =
                'Server error: ${response.statusCode} - ${response.body}';
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(_responseMessage)));
        }
      } catch (e) {
        setState(() {
          _responseMessage = 'Error saving appeal: $e';
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_responseMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Appeal Form - Unit Standard: ${widget.unitStandardId}'),
          backgroundColor: Colors.blue),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('A. Detail of Appeal'),
                _buildTextField('Title Of Unit Standard', _titleController),
                _buildTextField('NQF Level', _nqfLevelController),
                _buildTextField('Number', _numberController),
                _buildTextField('Credits', _creditsController),
                _buildDateField(
                    'Date Of Assessment', _assessmentDate, 'assessment'),
                _buildSectionHeader('B. Candidate Details'),
                _buildTextField('Surname', _candidateSurnameController),
                _buildTextField('Name', _candidateNameController),
                _buildTextField(
                    'Identity Number', _candidateIdNumberController),
                _buildTextField(
                    'Reason For Disagreement Of The Assessment Outcome',
                    _reasonDisagreementController,
                    maxLines: 3),
                _buildSignatureField(
                    'Candidate\'s Signature', _candidateSignatureController),
                _buildDateField('Date', _candidateDate, 'candidate'),
                _buildSectionHeader('C. Assessor Details'),
                _buildTextField('Surname', _assessorSurnameController),
                _buildTextField('Name', _assessorNameController),
                _buildTextField(
                    'Registration Number', _assessorRegNumberController),
                _buildTextField('Reason For Decision Made On The Outcome',
                    _reasonDecisionController,
                    maxLines: 3),
                _buildSignatureField(
                    'Assessor\'s Signature', _assessorSignatureController),
                _buildDateField('Date', _assessorDate, 'assessor'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _saveAppeal,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12)),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save & Generate PDF'),
                ),
                const SizedBox(height: 16),
                Text(_responseMessage,
                    style: TextStyle(
                        color: _responseMessage.contains('success')
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(title,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        maxLines: maxLines,
        validator: (value) => value!.isEmpty ? '$label is required' : null,
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? date, String field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: () => _selectDate(context, field),
            child: Text(
                date != null
                    ? '${date.day}/${date.month}/${date.year}'
                    : 'Select Date',
                style: const TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureField(String label, SignatureController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Signature(
            controller: controller,
            height: 100,
            backgroundColor: Colors.grey[200]!,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () => controller.clear(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white),
                child: const Text('Clear'),
              ),
              ElevatedButton(
                onPressed: () => setState(() {}),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white),
                child: const Text('Refresh'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NonComplianceAndFeedbackPage extends StatefulWidget {
  final String facilitatorId;
  final String learnerId;

  const NonComplianceAndFeedbackPage({
    super.key,
    required this.facilitatorId,
    required this.learnerId,
  });

  @override
  _NonComplianceAndFeedbackPageState createState() =>
      _NonComplianceAndFeedbackPageState();
}

class _NonComplianceAndFeedbackPageState
    extends State<NonComplianceAndFeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _candidateNameController =
      TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _unitStandardController = TextEditingController();
  final TextEditingController _attemptController = TextEditingController();
  final TextEditingController _specificOutcomeController =
      TextEditingController();
  final TextEditingController _actionController = TextEditingController();
  final TextEditingController _usTitleController = TextEditingController();
  final TextEditingController _assessmentDateController =
      TextEditingController();
  final TextEditingController _assessmentTimeController =
      TextEditingController();
  final TextEditingController _numberOfAttemptsController =
      TextEditingController();
  final TextEditingController _assessorFeedbackController =
      TextEditingController();

  final SignatureController _candidateSignatureController =
      SignatureController(penStrokeWidth: 5, penColor: Colors.black);
  String _responseMessage = '';
  bool _isSubmitting = false;
  Uint8List? _candidateSignature;

  @override
  void dispose() {
    _candidateNameController.dispose();
    _idNumberController.dispose();
    _unitStandardController.dispose();
    _attemptController.dispose();
    _specificOutcomeController.dispose();
    _actionController.dispose();
    _usTitleController.dispose();
    _assessmentDateController.dispose();
    _assessmentTimeController.dispose();
    _numberOfAttemptsController.dispose();
    _assessorFeedbackController.dispose();
    _candidateSignatureController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _assessmentDateController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _assessmentTimeController.text =
            "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00";
      });
    }
  }

  Future<void> _generatePDF() async {
    final pdf = pw.Document();

    if (_candidateSignatureController.isNotEmpty) {
      _candidateSignature = await _candidateSignatureController.toPngBytes();
    }

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('NON-COMPLIANCE & ACTION PLAN',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Candidate: ${_candidateNameController.text}'),
            pw.Text('I.D No.: ${_idNumberController.text}'),
            pw.Text('U.S: ${_unitStandardController.text}'),
            pw.Text('For Attempt: ${_attemptController.text}'),
            pw.SizedBox(height: 10),
            pw.Text('Signature:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            _candidateSignature != null
                ? pw.Image(pw.MemoryImage(_candidateSignature!),
                    width: 100, height: 50)
                : pw.Text('No signature provided'),
            pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}'),
            pw.SizedBox(height: 20),
            pw.Text('LEARNING DEVELOPMENT',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Specific Outcome No.: ${_specificOutcomeController.text}'),
            pw.SizedBox(height: 10),
            pw.Text('Action to be taken:'),
            pw.Text(_actionController.text),
            pw.SizedBox(height: 30),
            pw.Text('ASSESSMENT FEEDBACK',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('U.S TITLE: ${_usTitleController.text}'),
            pw.Text('LEARNER NAME: ${_candidateNameController.text}'),
            pw.Text('I.D NUMBER: ${_idNumberController.text}'),
            pw.Text('ASSESSMENT DATE: ${_assessmentDateController.text}'),
            pw.Text('ASSESSMENT TIME: ${_assessmentTimeController.text}'),
            pw.Text('NUMBER OF ATTEMPTS: ${_numberOfAttemptsController.text}'),
            pw.SizedBox(height: 10),
            pw.Text('ASSESSOR FEEDBACK:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(_assessorFeedbackController.text),
          ],
        ),
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File(
        '${directory.path}/non_compliance_feedback_${widget.learnerId}.pdf');
    await file.writeAsBytes(await pdf.save());

    setState(() {
      _responseMessage = 'PDF generated successfully!';
    });

    OpenFile.open(file.path);
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _responseMessage = 'Please fill all required fields correctly';
        _isSubmitting = false;
      });
      return;
    }

    try {
      int.parse(_attemptController.text); // Validate integer
      int.parse(_numberOfAttemptsController.text); // Validate integer
    } catch (e) {
      setState(() {
        _responseMessage =
            'Error: Attempt and Number of Attempts must be integers';
        _isSubmitting = false;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _responseMessage = '';
    });

    try {
      if (_candidateSignatureController.isNotEmpty) {
        _candidateSignature = await _candidateSignatureController.toPngBytes();
      }

      final payload = {
        'facilitator_id': widget.facilitatorId,
        'learner_id': widget.learnerId,
        'candidate_name': _candidateNameController.text,
        'id_number': _idNumberController.text,
        'unit_standard': _unitStandardController.text,
        'attempt': int.parse(_attemptController.text),
        'specific_outcome': _specificOutcomeController.text,
        'action': _actionController.text,
        'us_title': _usTitleController.text,
        'assessment_date': _assessmentDateController.text,
        'assessment_time': _assessmentTimeController.text,
        'number_of_attempts': int.parse(_numberOfAttemptsController.text),
        'assessor_feedback': _assessorFeedbackController.text,
        'signature': _candidateSignature != null
            ? base64Encode(_candidateSignature!)
            : '',
      };

      print("Sending payload: ${jsonEncode(payload)}");
      final response = await http.post(
        Uri.parse(
            'https://rlms.rlms.co.za/mobile/save_non_compliance_feedback.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print("Raw response body: ${response.body}");
      print("Response status code: ${response.statusCode}");

      if (response.statusCode == 200) {
        try {
          var data = jsonDecode(response.body);
          setState(() {
            _responseMessage = data['status'] == 'success'
                ? 'Form saved successfully!'
                : 'Failed to save: ${data['message']}';
            _isSubmitting = false;
          });
          if (data['status'] == 'success') {
            await _generatePDF();
          }
        } catch (e) {
          setState(() {
            _responseMessage =
                'Error decoding response: $e\nResponse: ${response.body.isNotEmpty ? response.body.substring(0, response.body.length < 100 ? response.body.length : 100) : "Empty response"}';
            _isSubmitting = false;
          });
        }
      } else {
        setState(() {
          _responseMessage =
              'Server error: ${response.statusCode}\nResponse: ${response.body.isNotEmpty ? response.body.substring(0, response.body.length < 100 ? response.body.length : 100) : "Empty response"}';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _responseMessage = 'Error: $e';
        _isSubmitting = false;
      });
    }
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (label == 'Candidate' ||
              label == 'I.D No.' ||
              label == 'U.S' ||
              label == 'For Attempt' ||
              label == 'U.S TITLE' ||
              label == 'ASSESSMENT DATE' ||
              label == 'NUMBER OF ATTEMPTS') {
            if (value == null || value.isEmpty) {
              return '$label is required';
            }
          }
          if (label == 'For Attempt' || label == 'NUMBER OF ATTEMPTS') {
            try {
              int.parse(value!);
            } catch (e) {
              return '$label must be a number';
            }
          }
          if (label == 'ASSESSMENT DATE') {
            if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value!)) {
              return 'Date must be in YYYY-MM-DD format';
            }
          }
          if (label == 'ASSESSMENT TIME' && value != null && value.isNotEmpty) {
            if (!RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(value)) {
              return 'Time must be in HH:MM:SS format';
            }
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Non-Compliance & Feedback'),
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
                    gradient:
                        LinearGradient(colors: [Colors.blue, Colors.indigo]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.feedback, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Non-Compliance & Feedback',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Facilitator ID: ${widget.facilitatorId}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NON-COMPLIANCE & ACTION PLAN',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                              'Candidate', _candidateNameController),
                          _buildTextField('I.D No.', _idNumberController),
                          _buildTextField('U.S', _unitStandardController),
                          _buildTextField('For Attempt', _attemptController),
                          const SizedBox(height: 10),
                          const Text('Signature',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Signature(
                            controller: _candidateSignatureController,
                            height: 100,
                            backgroundColor: Colors.grey[200]!,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                onPressed: () =>
                                    _candidateSignatureController.clear(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Clear Signature'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text('LEARNING DEVELOPMENT',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          _buildTextField('Specific Outcome No.',
                              _specificOutcomeController),
                          _buildTextField(
                              'Action to be taken', _actionController,
                              maxLines: 5),
                          const SizedBox(height: 20),
                          const Text('ASSESSMENT FEEDBACK',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          _buildTextField('U.S TITLE', _usTitleController),
                          TextFormField(
                            controller: _assessmentDateController,
                            decoration: const InputDecoration(
                              labelText: 'ASSESSMENT DATE',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: _selectDate,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Assessment Date is required';
                              }
                              if (!RegExp(r'^\d{4}-\d{2}-\d{2}$')
                                  .hasMatch(value)) {
                                return 'Date must be in YYYY-MM-DD format';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _assessmentTimeController,
                            decoration: const InputDecoration(
                              labelText: 'ASSESSMENT TIME',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.access_time),
                            ),
                            readOnly: true,
                            onTap: _selectTime,
                            validator: (value) {
                              if (value != null &&
                                  value.isNotEmpty &&
                                  !RegExp(r'^\d{2}:\d{2}:\d{2}$')
                                      .hasMatch(value)) {
                                return 'Time must be in HH:MM:SS format';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildTextField('NUMBER OF ATTEMPTS',
                              _numberOfAttemptsController),
                          _buildTextField(
                              'ASSESSOR FEEDBACK', _assessorFeedbackController,
                              maxLines: 5),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _saveForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 12),
                            ),
                            child: _isSubmitting
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('Save & Generate PDF'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _responseMessage,
              style: TextStyle(
                color: _responseMessage.contains('success')
                    ? Colors.green
                    : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PotholeChecklistClassListPage extends StatefulWidget {
  final String facilitatorId;

  const PotholeChecklistClassListPage({
    super.key,
    required this.facilitatorId,
  });

  @override
  State<PotholeChecklistClassListPage> createState() =>
      _PotholeChecklistClassListPageState();
}

class PotholeChecklistLearnerListPage extends StatefulWidget {
  final String facilitatorId;
  final String classId;
  final String className;

  const PotholeChecklistLearnerListPage({
    super.key,
    required this.facilitatorId,
    required this.classId,
    required this.className,
  });

  @override
  State<PotholeChecklistLearnerListPage> createState() =>
      _PotholeChecklistLearnerListPageState();
}

class _PotholeChecklistClassListPageState
    extends State<PotholeChecklistClassListPage> {
  Future<List<dynamic>> _fetchClasses(String facilitatorId) async {
    final url = AppConfig.buildUrl('get_classes.php', queryParams: {
      'facilitator_id': facilitatorId,
    });

    print('[PotholeChecklistClassList] Fetching classes from: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
    );

    print(
        '[PotholeChecklistClassList] Response Status: ${response.statusCode}');
    print('[PotholeChecklistClassList] Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Check if response is an error object
      if (data is Map && data['status'] == 'error') {
        throw Exception('Server error: ${data['message']}');
      }

      // Return the data (should be a list)
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
        title: const Text('Pothole Checklist - Select Class'),
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
                final className =
                    classData['className']?.toString() ?? 'Unknown Class';
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
                            builder: (context) =>
                                PotholeChecklistLearnerListPage(
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

class _PotholeChecklistLearnerListPageState
    extends State<PotholeChecklistLearnerListPage> {
  Future<List<dynamic>> fetchLearners(String classId) async {
    // Use the same endpoint as AssessorPage - get_learners.php with classID parameter
    final url = AppConfig.buildUrl('get_learners.php', queryParams: {
      'classID': classId,
    });

    print('[PotholeChecklistLearnerList] Fetching learners from: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
    );

    print(
        '[PotholeChecklistLearnerList] Response Status: ${response.statusCode}');
    print('[PotholeChecklistLearnerList] Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Check if response is an error object
      if (data is Map && data['status'] == 'error') {
        throw Exception('Server error: ${data['message']}');
      }

      // Return the data (should be a list)
      if (data is List) {
        return data;
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      throw Exception('Failed to load learners: ${response.statusCode}');
    }
  }

  /// Handle checklist action based on status
  Future<void> _handleChecklistAction(
    BuildContext context,
    String learnerId,
    String firstName,
    String lastName,
    String idNumber,
    bool checklistExists,
    String? checklistType,
    Map<String, dynamic>? checklistData,
  ) async {
    if (checklistExists) {
      // View existing checklist
      if (checklistType == 'scanned') {
        // View scanned document
        final documentPath =
            checklistData?['data']?['document_path'] as String?;
        if (documentPath != null) {
          await _viewScannedDocument(context, documentPath);
        } else {
          _showError(context, 'Document path not found');
        }
      } else if (checklistType == 'system') {
        // View system checklist
        await _viewSystemChecklist(
            context, learnerId, firstName, lastName, idNumber);
      }
    } else {
      // No checklist exists - show creation options
      await _showChecklistCreationDialog(
          context, learnerId, firstName, lastName, idNumber);
    }
  }

  /// View scanned document
  Future<void> _viewScannedDocument(
      BuildContext context, String documentPath) async {
    try {
      final file = File(documentPath);
      if (await file.exists()) {
        await OpenFile.open(documentPath);
      } else {
        _showError(context, 'Document file not found');
      }
    } catch (e) {
      _showError(context, 'Error opening document: $e');
    }
  }

  /// View system checklist
  Future<void> _viewSystemChecklist(
    BuildContext context,
    String learnerId,
    String firstName,
    String lastName,
    String idNumber,
  ) async {
    // Navigate to the checklist page to view
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PotholeChecklistPage(
          learnerId: learnerId,
          learnerFirstName: firstName,
          learnerLastName: lastName,
          learnerIdNumber: idNumber,
          facilitatorId: widget.facilitatorId,
          classId: widget.classId,
        ),
      ),
    );
  }

  /// Show checklist creation dialog
  Future<void> _showChecklistCreationDialog(
    BuildContext context,
    String learnerId,
    String firstName,
    String lastName,
    String idNumber,
  ) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Create Checklist for $firstName $lastName'),
        content: const Text('How would you like to create the checklist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _scanChecklistDocument(context, learnerId, firstName, lastName);
            },
            icon: const Icon(Icons.document_scanner),
            label: const Text('Scan Document'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _openChecklistForm(
                  context, learnerId, firstName, lastName, idNumber);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Fill Form'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Scan checklist document using document scanner
  Future<void> _scanChecklistDocument(
    BuildContext context,
    String learnerId,
    String firstName,
    String lastName,
  ) async {
    try {
      final docScanner = FlutterDocScanner();

      // Open document scanner
      final scannedDoc = await docScanner.getScanDocuments(page: 10);

      if (scannedDoc != null) {
        // Prepare permanent storage location BEFORE processing
        final appDir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'pothole_checklist_${learnerId}_$timestamp.pdf';
        final permanentPath = '${appDir.path}/$fileName';

        String? pdfUri;
        if (scannedDoc is Map) {
          pdfUri = scannedDoc['pdfUri']?.toString();
        } else if (scannedDoc is String) {
          pdfUri = scannedDoc;
        } else if (scannedDoc is List && scannedDoc.isNotEmpty) {
          pdfUri = scannedDoc.first.toString();
        }

        final sourceFile = await resolveFlutterDocScannerPdfFile(pdfUri);

        if (sourceFile != null && await isReadablePdfFile(sourceFile)) {
          try {
            Uint8List? bytes;
            try {
              bytes = sourceFile.readAsBytesSync();
            } catch (e) {
              bytes = await sourceFile.readAsBytes();
            }

            if (bytes.isNotEmpty) {
              // Write to permanent location synchronously
              final permanentFile = File(permanentPath);
              permanentFile.writeAsBytesSync(bytes);

              // Verify file was saved
              if (permanentFile.existsSync()) {
                // Save to database
                final assessmentDate =
                    DateTime.now().toIso8601String().split('T').first;
                final dbHelper = DatabaseHelper();
                await dbHelper.saveScannedPotholeChecklist(
                  learnerId: learnerId,
                  assessorId: widget.facilitatorId ?? '',
                  documentPath: permanentPath,
                  assessmentDate: assessmentDate,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Checklist scanned for $firstName $lastName'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );

                  // Sync to server if online (in background)
                  _syncScannedDocument(
                      permanentPath, learnerId, assessmentDate);

                  // Refresh the page to update button
                  setState(() {});
                }
              } else {
                _showError(context, 'Failed to save scanned document');
              }
            } else {
              _showError(context, 'Could not read scanned file');
            }
          } catch (e) {
            _showError(context, 'Error processing scan: $e');
          }
        } else {
          _showError(context, 'No valid PDF from scanner');
        }
      } else {
        // User cancelled
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scanning cancelled'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _showError(context, 'Error scanning document: $e');
    }
  }

  /// Sync scanned document to server
  Future<void> _syncScannedDocument(
      String documentPath, String learnerId, String assessmentDate) async {
    try {
      print('[SYNC] Starting sync for learner: $learnerId');
      print('[SYNC] Document path: $documentPath');
      print('[SYNC] Assessment date: $assessmentDate');

      final file = File(documentPath);
      if (!await file.exists()) {
        print('[SYNC] ERROR: File does not exist at path');
        return;
      }

      print('[SYNC] File exists, size: ${await file.length()} bytes');

      final url = '${AppConfig.baseUrl}/upload_scanned_pothole_checklist.php';
      print('[SYNC] Uploading to: $url');

      final request = http.MultipartRequest('POST', Uri.parse(url));

      request.fields['learner_id'] = learnerId;
      request.fields['assessor_id'] = widget.facilitatorId ?? '';
      request.fields['assessment_date'] = assessmentDate;

      print('[SYNC] Adding file to request...');
      request.files.add(await http.MultipartFile.fromPath(
        'document',
        documentPath,
      ));

      print('[SYNC] Sending request...');
      final response =
          await request.send().timeout(const Duration(seconds: 30));

      print('[SYNC] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        print('[SYNC] Response body: $responseBody');
        print('[SYNC] ✅ Document synced successfully');
      } else {
        final responseBody = await response.stream.bytesToString();
        print('[SYNC] ❌ Upload failed with status ${response.statusCode}');
        print('[SYNC] Response: $responseBody');
      }
    } catch (e) {
      print('[SYNC] ❌ Error syncing document: $e');
    }
  }

  /// Open checklist form
  void _openChecklistForm(
    BuildContext context,
    String learnerId,
    String firstName,
    String lastName,
    String idNumber,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PotholeChecklistPage(
          learnerId: learnerId,
          learnerFirstName: firstName,
          learnerLastName: lastName,
          learnerIdNumber: idNumber,
          facilitatorId: widget.facilitatorId,
          classId: widget.classId,
        ),
      ),
    );
  }

  /// Show error message
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Check if pothole checklist exists for a learner
  Future<Map<String, dynamic>> _checkPotholeChecklistStatus(
      String learnerId) async {
    try {
      final assessmentDate = DateTime.now().toIso8601String().split('T').first;

      // Check local database for scanned document
      final dbHelper = DatabaseHelper();
      final scannedDoc = await dbHelper.getScannedPotholeChecklist(
        learnerId: learnerId,
        assessorId: widget.facilitatorId ?? '',
        assessmentDate: assessmentDate,
      );

      if (scannedDoc != null) {
        return {
          'exists': true,
          'type': 'scanned',
          'data': scannedDoc,
        };
      }

      // Check server for system-generated checklist
      try {
        final response = await http
            .get(Uri.parse(
                '${AppConfig.baseUrl}/view_pothole_checklists.php?learner_id=$learnerId&assessor_id=${widget.facilitatorId}&assessment_date=$assessmentDate'))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success' && data['data'] != null) {
            return {
              'exists': true,
              'type': 'system',
              'data': data['data'],
            };
          }
        }
      } catch (e) {
        // Offline or server error - just return no checklist
        print('Server check failed: $e');
      }

      return {
        'exists': false,
        'type': 'none',
        'data': null,
      };
    } catch (e) {
      print('Error checking checklist status: $e');
      return {
        'exists': false,
        'type': 'none',
        'data': null,
      };
    }
  }

  Future<void> _uploadPotholeEvidence(
    BuildContext context,
    String learnerId,
    String firstName,
    String lastName,
  ) async {
    final ImagePicker imagePicker = ImagePicker();

    try {
      // Pick multiple images
      final List<XFile> images = await imagePicker.pickMultiImage();

      if (images.isEmpty) {
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Prepare multipart request
      // Add cache-busting parameter to ensure we hit the updated script
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/upload_pothole_evidence.php?v=2'),
      );

      // Add form fields
      request.fields['learnerID'] = learnerId;
      request.fields['assessorID'] = widget.facilitatorId;
      request.fields['assessmentDate'] =
          DateTime.now().toIso8601String().split('T').first;

      // Add image files - each with array notation
      for (int i = 0; i < images.length; i++) {
        var file = await http.MultipartFile.fromPath(
          'images[]',
          images[i].path,
          filename: images[i].name,
        );
        request.files.add(file);
        print('Added file ${i + 1}: ${images[i].name}');
      }

      // Send request
      print('Sending ${images.length} images for learner $learnerId');
      print('Request fields: ${request.fields}');
      print('Request files count: ${request.files.length}');

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      print('Response status: ${response.statusCode}');
      print('Response data: $responseData');

      // Check for non-200 status
      if (response.statusCode != 200) {
        throw Exception(
            'Server returned status ${response.statusCode}: $responseData');
      }

      // Try to parse JSON response
      dynamic jsonResponse;
      try {
        jsonResponse = jsonDecode(responseData);
      } catch (e) {
        print('Failed to parse JSON response: $e');
        throw Exception('Invalid server response: $responseData');
      }

      // Close loading dialog
      Navigator.of(context).pop();

      if (jsonResponse['status'] == 'success') {
        // Show detailed success message with debug info
        String successMsg =
            '${jsonResponse['success_count']} image(s) uploaded for $firstName $lastName';

        // Add debug info if available
        if (jsonResponse['uploaded_files'] != null) {
          print('Uploaded files: ${jsonResponse['uploaded_files']}');
        }
        if (jsonResponse['errors'] != null &&
            (jsonResponse['errors'] as List).isNotEmpty) {
          print('Partial errors: ${jsonResponse['errors']}');
          successMsg += '\n(Some files had errors - check console)';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // Show detailed error message
        String errorMsg = jsonResponse['message'] ?? 'Upload failed';
        if (jsonResponse['errors'] != null &&
            jsonResponse['errors'].isNotEmpty) {
          errorMsg += '\n${(jsonResponse['errors'] as List).join('\n')}';
        }
        if (jsonResponse['debug'] != null) {
          print('Debug info: ${jsonResponse['debug']}');
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Upload error: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading images: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
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
                    DataColumn(label: Text('Evidence')),
                  ],
                  rows: learners.map<DataRow>((learnerData) {
                    String learnerId =
                        learnerData['LearnerID']?.toString() ?? 'N/A';
                    String firstName =
                        learnerData['Name']?.toString() ?? 'Unknown';
                    String lastName =
                        learnerData['Surname']?.toString() ?? 'Unknown';
                    String idNumber =
                        learnerData['IDNumber']?.toString() ?? 'N/A';

                    return DataRow(
                      cells: [
                        DataCell(Text(learnerId)),
                        DataCell(Text(firstName)),
                        DataCell(Text(lastName)),
                        DataCell(Text(idNumber)),
                        DataCell(
                          FutureBuilder<Map<String, dynamic>>(
                            future: _checkPotholeChecklistStatus(learnerId),
                            builder: (context, snapshot) {
                              // Default state while loading
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const ElevatedButton(
                                  onPressed: null,
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              }

                              // Determine button properties based on checklist status
                              final checklistExists =
                                  snapshot.data?['exists'] == true;
                              final checklistType = snapshot.data?['type'];

                              String buttonLabel;
                              Color buttonColor;
                              IconData buttonIcon;

                              if (checklistExists) {
                                if (checklistType == 'scanned') {
                                  buttonLabel = 'View Scanned';
                                  buttonColor = Colors.blue;
                                  buttonIcon = Icons.picture_as_pdf;
                                } else {
                                  buttonLabel = 'View Checklist';
                                  buttonColor = Colors.blue;
                                  buttonIcon = Icons.visibility;
                                }
                              } else {
                                buttonLabel = 'Open Checklist';
                                buttonColor = Colors.orange;
                                buttonIcon = Icons.folder_open;
                              }

                              return ElevatedButton.icon(
                                onPressed: () async {
                                  await _handleChecklistAction(
                                    context,
                                    learnerId,
                                    firstName,
                                    lastName,
                                    idNumber,
                                    checklistExists,
                                    checklistType,
                                    snapshot.data,
                                  );
                                },
                                icon: Icon(buttonIcon, size: 16),
                                label: Text(buttonLabel),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: buttonColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              );
                            },
                          ),
                        ),
                        DataCell(
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _uploadPotholeEvidence(
                                context,
                                learnerId,
                                firstName,
                                lastName,
                              );
                            },
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Upload'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
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

// Pothole Checklist View Page for Marking
class PotholeChecklistViewPage extends StatefulWidget {
  final Map<String, dynamic> checklistData;
  final String learnerId;

  const PotholeChecklistViewPage({
    super.key,
    required this.checklistData,
    required this.learnerId,
  });

  @override
  State<PotholeChecklistViewPage> createState() =>
      _PotholeChecklistViewPageState();
}

class _PotholeChecklistViewPageState extends State<PotholeChecklistViewPage> {
  final TextEditingController _marksController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;

  // LogBook unit standards
  List<Map<String, dynamic>> _logbookUnitStandards = [];
  final Map<String, TextEditingController> _logbookMarksControllers = {};
  bool _isLoadingLogbook = false;

  // Pothole evidence images
  List<Map<String, dynamic>> _potholeImages = [];
  bool _isLoadingImages = false;

  @override
  void initState() {
    super.initState();
    _loadExistingMarks();
    _loadLogbookUnitStandards();
    _loadPotholeImages();
  }

  Future<void> _loadPotholeImages() async {
    setState(() => _isLoadingImages = true);

    try {
      final url =
          '${AppConfig.baseUrl}/get_pothole_images.php?learner_id=${widget.learnerId}';
      print('DEBUG Images: Loading from $url');

      final response = await http.get(Uri.parse(url));

      print('DEBUG Images: Response status ${response.statusCode}');
      print('DEBUG Images: Response body ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _potholeImages =
                List<Map<String, dynamic>>.from(data['data'] ?? []);
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

  Future<void> _loadExistingMarks() async {
    setState(() => _isLoading = true);

    try {
      final assessmentDate = widget.checklistData['assessment_date'] ??
          DateTime.now().toIso8601String().split('T').first;
      final assessorId = widget.checklistData['assessor_id'] ?? '';

      final response = await http.get(Uri.parse(
          '${AppConfig.baseUrl}/get_pothole_checklist_marks.php?learner_id=${widget.learnerId}&assessor_id=$assessorId&assessment_date=$assessmentDate'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          setState(() {
            _marksController.text = data['data']['marks'].toString();
            _commentsController.text = data['data']['comments'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading marks: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLogbookUnitStandards() async {
    setState(() => _isLoadingLogbook = true);

    try {
      final response = await http.get(Uri.parse(
          '${AppConfig.baseUrl}/get_logbook_unit_standards.php?learner_id=${widget.learnerId}'));

      print('DEBUG LogBook: Response status ${response.statusCode}');
      print('DEBUG LogBook: Response body ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _logbookUnitStandards =
                List<Map<String, dynamic>>.from(data['data']);

            // Create controllers for each unit standard
            for (var us in _logbookUnitStandards) {
              _logbookMarksControllers[us['unit_standard_id']] =
                  TextEditingController();
            }
          });

          print(
              'DEBUG LogBook: Loaded ${_logbookUnitStandards.length} unit standards');
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
      final assessmentDate = widget.checklistData['assessment_date'] ??
          DateTime.now().toIso8601String().split('T').first;
      final assessorId = widget.checklistData['assessor_id'] ?? '';

      final response = await http.get(Uri.parse(
          '${AppConfig.baseUrl}/get_logbook_marks.php?learner_id=${widget.learnerId}&assessor_id=$assessorId&assessment_date=$assessmentDate'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final marks = data['data'] as Map<String, dynamic>;

          setState(() {
            marks.forEach((unitStandardId, mark) {
              if (_logbookMarksControllers.containsKey(unitStandardId)) {
                _logbookMarksControllers[unitStandardId]!.text =
                    mark.toString();
              }
            });
          });
        }
      }
    } catch (e) {
      print('Error loading logbook marks: $e');
    }
  }

  Future<void> _saveLogbookMarks() async {
    // Validate all marks
    Map<String, int> marksToSave = {};

    for (var us in _logbookUnitStandards) {
      final unitStandardId = us['unit_standard_id'];
      final controller = _logbookMarksControllers[unitStandardId];
      final markText = controller?.text.trim() ?? '';

      if (markText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter mark for ${us['unit_standard_name']}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final mark = int.tryParse(markText);
      if (mark == null || mark < 0 || mark > 50) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Mark for ${us['unit_standard_name']} must be between 0 and 50'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      marksToSave[unitStandardId] = mark;
    }

    setState(() => _isSaving = true);

    try {
      final assessmentDate = widget.checklistData['assessment_date'] ??
          DateTime.now().toIso8601String().split('T').first;
      final assessorId = widget.checklistData['assessor_id'] ?? '';

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/save_logbook_marks.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learner_id': widget.learnerId,
          'assessor_id': assessorId,
          'assessment_date': assessmentDate,
          'marks': marksToSave,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('LogBook marks saved successfully!'),
                backgroundColor: Colors.green),
          );
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error saving LogBook marks: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveMarks() async {
    if (_marksController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter marks'), backgroundColor: Colors.red),
      );
      return;
    }

    final marks = int.tryParse(_marksController.text.trim());
    if (marks == null || marks < 0 || marks > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Marks must be between 0 and 100'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final assessmentDate = widget.checklistData['assessment_date'] ??
          DateTime.now().toIso8601String().split('T').first;
      final assessorId = widget.checklistData['assessor_id'] ?? '';

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/save_pothole_checklist_marks.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learner_id': widget.learnerId,
          'assessor_id': assessorId,
          'assessment_date': assessmentDate,
          'marks': marks,
          'comments': _commentsController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Marks saved successfully!'),
                backgroundColor: Colors.green),
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
        SnackBar(
            content: Text('Error saving marks: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG ViewPage: checklistData keys: ${widget.checklistData.keys}');
    print(
        'DEBUG ViewPage: learner_name: ${widget.checklistData['learner_name']}');
    print(
        'DEBUG ViewPage: checklist_items type: ${widget.checklistData['checklist_items'].runtimeType}');
    print(
        'DEBUG ViewPage: checklist_items: ${widget.checklistData['checklist_items']}');

    final items =
        widget.checklistData['checklist_items'] as Map<String, dynamic>? ?? {};
    print('DEBUG ViewPage: items count: ${items.length}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pothole Checklist - Marking'),
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
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Learner',
                              widget.checklistData['learner_name'] ?? 'N/A'),
                          _buildInfoRow(
                              'ID Number',
                              widget.checklistData['learner_id_number'] ??
                                  'N/A'),
                          _buildInfoRow('Assessor',
                              widget.checklistData['assessor_name'] ?? 'N/A'),
                          _buildInfoRow(
                              'Venue', widget.checklistData['venue'] ?? 'N/A'),
                          _buildInfoRow('Date',
                              widget.checklistData['assessment_date'] ?? 'N/A'),
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
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue),
                          ),
                          const SizedBox(height: 16),
                          ...items.entries.map((section) {
                            return _buildSection(
                                section.key, section.value as List);
                          }),
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
                                Icon(Icons.book,
                                    color: Colors.orange.shade700, size: 24),
                                const SizedBox(width: 12),
                                const Text(
                                  'LogBook Unit Standards',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ..._logbookUnitStandards.map((us) {
                              final controller = _logbookMarksControllers[
                                  us['unit_standard_id']];
                              final specificOutcomes =
                                  us['specific_outcomes'] as List<dynamic>? ??
                                      [];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        us['unit_standard_name'] ?? 'N/A',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),

                                      // Specific Outcomes
                                      if (specificOutcomes.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.blue.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                              ...specificOutcomes
                                                  .map((outcome) {
                                                final outcomeText =
                                                    outcome['outcome_text']
                                                            ?.toString() ??
                                                        '';
                                                if (outcomeText.isEmpty) {
                                                  return const SizedBox
                                                      .shrink();
                                                }

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 6),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text('• ',
                                                          style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                      Expanded(
                                                        child: Text(
                                                          outcomeText,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 13,
                                                                  height: 1.3),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.star,
                                              color: Colors.orange.shade700,
                                              size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              controller: controller,
                                              decoration: const InputDecoration(
                                                labelText: 'Mark (0-50)',
                                                border: OutlineInputBorder(),
                                                hintText:
                                                    'Enter mark out of 50',
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 16),
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveLogbookMarks,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(_isSaving
                                    ? 'Saving...'
                                    : 'Save LogBook Marks'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
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
                            const Row(
                              children: [
                                Icon(Icons.image,
                                    color: Colors.purple, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Pothole Evidence Images',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1,
                              ),
                              itemCount: _potholeImages.length,
                              itemBuilder: (context, index) {
                                final image = _potholeImages[index];
                                return FutureBuilder<String>(
                                  future: AppConfig.buildServeFileUrl(
                                      image['file_path']),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    if (snapshot.hasError) {
                                      return const Center(
                                        child:
                                            Icon(Icons.broken_image, size: 40),
                                      );
                                    }
                                    final imageUrl = snapshot.data!;
                                    debugPrint(
                                        '[POE_IMAGE] Loading evidence image from: $imageUrl');

                                    return GestureDetector(
                                      onTap: () {
                                        // Show full image with zoom capability
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(
                                            backgroundColor: Colors.black,
                                            child: SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.9,
                                              height: MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  0.8,
                                              child: Column(
                                                children: [
                                                  // Header with close button
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          'Image ${index + 1}',
                                                          style: const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                        IconButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context),
                                                          icon: const Icon(
                                                              Icons.close,
                                                              color:
                                                                  Colors.white),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  // Zoomable image
                                                  Expanded(
                                                    child: InteractiveViewer(
                                                      panEnabled: true,
                                                      boundaryMargin:
                                                          const EdgeInsets.all(
                                                              20),
                                                      minScale: 0.5,
                                                      maxScale: 4.0,
                                                      child: Center(
                                                        child:
                                                            CachedNetworkImage(
                                                          imageUrl: imageUrl,
                                                          fit: BoxFit.contain,
                                                          placeholder:
                                                              (context, url) =>
                                                                  const Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                                    color: Colors
                                                                        .white),
                                                          ),
                                                          errorWidget: (context,
                                                              error,
                                                              stackTrace) {
                                                            return const Center(
                                                              child: Icon(
                                                                  Icons
                                                                      .broken_image,
                                                                  size: 50,
                                                                  color: Colors
                                                                      .white),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Description
                                                  if (image['description'] !=
                                                          null &&
                                                      image['description']
                                                          .toString()
                                                          .isNotEmpty)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              12.0),
                                                      child: Text(
                                                        image['description'] ??
                                                            '',
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.white),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                  // Instructions
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: const Text(
                                                      'Pinch to zoom • Drag to pan • Tap close to exit',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.grey),
                                                      textAlign:
                                                          TextAlign.center,
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
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return const Center(
                                                    child: Icon(
                                                        Icons.broken_image,
                                                        size: 50,
                                                        color: Colors.grey),
                                                  );
                                                },
                                                loadingBuilder: (context, child,
                                                    loadingProgress) {
                                                  if (loadingProgress == null) {
                                                    return child;
                                                  }
                                                  return const Center(
                                                      child:
                                                          CircularProgressIndicator());
                                                },
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(4.0),
                                              child: Text(
                                                'Image ${index + 1}',
                                                style: const TextStyle(
                                                    fontSize: 10),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
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
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue),
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
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            item['value'] == true
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: item['value'] == true
                                ? Colors.green
                                : Colors.red,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item['value'] == true ? 'YES' : 'NO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: item['value'] == true
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (item['notes'] != null &&
                          item['notes'].toString().isNotEmpty) ...[
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
                              const Icon(Icons.note,
                                  size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item['notes'].toString(),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic),
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
    _marksController.dispose();
    _commentsController.dispose();
    super.dispose();
  }
}

// Pothole Checklist Scanned Document View Page for Marking
class PotholeChecklistScannedViewPage extends StatefulWidget {
  final String documentPath;
  final String learnerId;
  final String assessorId;
  final String assessmentDate;

  const PotholeChecklistScannedViewPage({
    super.key,
    required this.documentPath,
    required this.learnerId,
    required this.assessorId,
    required this.assessmentDate,
  });

  @override
  State<PotholeChecklistScannedViewPage> createState() =>
      _PotholeChecklistScannedViewPageState();
}

class _PotholeChecklistScannedViewPageState
    extends State<PotholeChecklistScannedViewPage> {
  bool _isSaving = false;

  // Pothole evidence images
  List<Map<String, dynamic>> _potholeImages = [];
  bool _isLoadingImages = false;

  // LogBook unit standards
  List<Map<String, dynamic>> _logbookUnitStandards = [];
  final Map<String, TextEditingController> _logbookMarksControllers = {};
  bool _isLoadingLogbook = false;

  @override
  void initState() {
    super.initState();
    _loadPotholeImages();
    _loadLogbookUnitStandards();
  }

  Future<void> _loadPotholeImages() async {
    setState(() => _isLoadingImages = true);

    try {
      final response = await http.get(Uri.parse(
          '${AppConfig.baseUrl}/get_pothole_images.php?learner_id=${widget.learnerId}'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _potholeImages =
                List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
          print(
              'DEBUG Images: Loaded ${_potholeImages.length} images for scanned view');
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
          '${AppConfig.baseUrl}/get_logbook_unit_standards.php?learner_id=${widget.learnerId}'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          setState(() {
            _logbookUnitStandards =
                List<Map<String, dynamic>>.from(data['data']);

            // Create controllers for each unit standard
            for (var us in _logbookUnitStandards) {
              _logbookMarksControllers[us['unit_standard_id']] =
                  TextEditingController();
            }
          });

          // Load existing marks
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
      final response = await http.get(Uri.parse(
          '${AppConfig.baseUrl}/get_logbook_marks.php?learner_id=${widget.learnerId}&assessor_id=${widget.assessorId}&assessment_date=${widget.assessmentDate}'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final marks = data['data'] as Map<String, dynamic>;
          setState(() {
            marks.forEach((unitStandardId, mark) {
              if (_logbookMarksControllers.containsKey(unitStandardId)) {
                _logbookMarksControllers[unitStandardId]!.text =
                    mark.toString();
              }
            });
          });
        }
      }
    } catch (e) {
      print('Error loading logbook marks: $e');
    }
  }

  Future<void> _saveLogbookMarks() async {
    // Validate all marks
    Map<String, int> marksToSave = {};

    for (var us in _logbookUnitStandards) {
      final unitStandardId = us['unit_standard_id'];
      final controller = _logbookMarksControllers[unitStandardId];
      final markText = controller?.text.trim() ?? '';

      if (markText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter mark for ${us['unit_standard_name']}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final mark = int.tryParse(markText);
      if (mark == null || mark < 0 || mark > 50) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Mark for ${us['unit_standard_name']} must be between 0 and 50'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      marksToSave[unitStandardId] = mark;
    }

    setState(() => _isSaving = true);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/save_logbook_marks.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learner_id': widget.learnerId,
          'assessor_id': widget.assessorId,
          'assessment_date': widget.assessmentDate,
          'marks': marksToSave,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('LogBook marks saved successfully'),
                backgroundColor: Colors.green),
          );
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error saving marks: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _openDocument() async {
    try {
      // Convert relative server path to full URL
      String documentUrl = widget.documentPath;

      // If path starts with ../, convert to full URL
      if (documentUrl.startsWith('../')) {
        // Remove ../ and construct full URL
        documentUrl = documentUrl.replaceFirst('../', '');
        // Use base domain without /mobile path for documents in root uploads folder
        final baseDomain = AppConfig.baseUrl.replaceAll('/mobile', '');
        documentUrl = '$baseDomain/$documentUrl';
      } else if (!documentUrl.startsWith('http')) {
        // If it's a relative path without ../, add base URL
        documentUrl = '${AppConfig.baseUrl}/$documentUrl';
      }

      print('DEBUG: Opening document from URL: $documentUrl');

      // Download the PDF to local storage
      final response = await http.get(Uri.parse(documentUrl));

      if (response.statusCode == 200) {
        // Get temporary directory
        final dir = await getTemporaryDirectory();
        final fileName = widget.documentPath.split('/').last;
        final file = File('${dir.path}/$fileName');

        // Write PDF to local file
        await file.writeAsBytes(response.bodyBytes);

        print('DEBUG: PDF downloaded to: ${file.path}');

        // Open the local file
        final result = await OpenFile.open(file.path);
        print('DEBUG: OpenFile result: ${result.message}');

        if (result.type != ResultType.done) {
          throw Exception(result.message);
        }
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Error opening document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error opening document: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanned Checklist - Marking'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: (_isLoadingImages || _isLoadingLogbook)
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Document Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scanned Document',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Icon(
                              Icons.picture_as_pdf,
                              size: 80,
                              color: Colors.red.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _openDocument,
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open PDF Document'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'File: ${widget.documentPath.split('/').last}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
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
                            const Row(
                              children: [
                                Icon(Icons.image,
                                    color: Colors.purple, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Pothole Evidence Images',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1,
                              ),
                              itemCount: _potholeImages.length,
                              itemBuilder: (context, index) {
                                final image = _potholeImages[index];
                                return FutureBuilder<String>(
                                  future: AppConfig.buildServeFileUrl(
                                      image['file_path']),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    if (snapshot.hasError) {
                                      return const Center(
                                        child:
                                            Icon(Icons.broken_image, size: 40),
                                      );
                                    }
                                    final imageUrl = snapshot.data!;
                                    debugPrint(
                                        '[POE_IMAGE] Loading evidence image from: $imageUrl');

                                    return GestureDetector(
                                      onTap: () {
                                        // Show full image with zoom capability
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(
                                            backgroundColor: Colors.black,
                                            child: SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.9,
                                              height: MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  0.8,
                                              child: Column(
                                                children: [
                                                  // Header with close button
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          'Image ${index + 1}',
                                                          style: const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                        IconButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context),
                                                          icon: const Icon(
                                                              Icons.close,
                                                              color:
                                                                  Colors.white),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  // Zoomable image
                                                  Expanded(
                                                    child: InteractiveViewer(
                                                      panEnabled: true,
                                                      boundaryMargin:
                                                          const EdgeInsets.all(
                                                              20),
                                                      minScale: 0.5,
                                                      maxScale: 4.0,
                                                      child: Center(
                                                        child:
                                                            CachedNetworkImage(
                                                          imageUrl: imageUrl,
                                                          fit: BoxFit.contain,
                                                          placeholder:
                                                              (context, url) =>
                                                                  const Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                                    color: Colors
                                                                        .white),
                                                          ),
                                                          errorWidget: (context,
                                                              error,
                                                              stackTrace) {
                                                            return const Center(
                                                              child: Icon(
                                                                  Icons
                                                                      .broken_image,
                                                                  size: 50,
                                                                  color: Colors
                                                                      .white),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Description
                                                  if (image['description'] !=
                                                          null &&
                                                      image['description']
                                                          .toString()
                                                          .isNotEmpty)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              12.0),
                                                      child: Text(
                                                        image['description'] ??
                                                            '',
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.white),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                  // Instructions
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: const Text(
                                                      'Pinch to zoom • Drag to pan • Tap close to exit',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.grey),
                                                      textAlign:
                                                          TextAlign.center,
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
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return const Center(
                                                    child: Icon(
                                                        Icons.broken_image,
                                                        size: 50,
                                                        color: Colors.grey),
                                                  );
                                                },
                                                loadingBuilder: (context, child,
                                                    loadingProgress) {
                                                  if (loadingProgress == null) {
                                                    return child;
                                                  }
                                                  return const Center(
                                                      child:
                                                          CircularProgressIndicator());
                                                },
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(4.0),
                                              child: Text(
                                                'Image ${index + 1}',
                                                style: const TextStyle(
                                                    fontSize: 10),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
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
                                Icon(Icons.book,
                                    color: Colors.orange.shade700, size: 24),
                                const SizedBox(width: 12),
                                const Text(
                                  'LogBook Unit Standards',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ..._logbookUnitStandards.map((us) {
                              final controller = _logbookMarksControllers[
                                  us['unit_standard_id']];
                              final specificOutcomes =
                                  us['specific_outcomes'] as List<dynamic>? ??
                                      [];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        us['unit_standard_name'] ?? 'N/A',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),

                                      // Specific Outcomes
                                      if (specificOutcomes.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.blue.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                              ...specificOutcomes
                                                  .map((outcome) {
                                                final outcomeText =
                                                    outcome['outcome_text']
                                                            ?.toString() ??
                                                        '';
                                                if (outcomeText.isEmpty) {
                                                  return const SizedBox
                                                      .shrink();
                                                }

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 6),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text('• ',
                                                          style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                      Expanded(
                                                        child: Text(
                                                          outcomeText,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 13,
                                                                  height: 1.3),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.star,
                                              color: Colors.orange.shade700,
                                              size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              controller: controller,
                                              decoration: const InputDecoration(
                                                labelText: 'Mark (0-50)',
                                                border: OutlineInputBorder(),
                                                hintText:
                                                    'Enter mark out of 50',
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 16),
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveLogbookMarks,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(_isSaving
                                    ? 'Saving...'
                                    : 'Save LogBook Marks'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _logbookMarksControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }
}

class ARPLEvidenceChecklistPage extends StatefulWidget {
  final String facilitatorId;

  const ARPLEvidenceChecklistPage({super.key, required this.facilitatorId});

  @override
  _ARPLEvidenceChecklistPageState createState() =>
      _ARPLEvidenceChecklistPageState();
}

class _ARPLEvidenceChecklistPageState extends State<ARPLEvidenceChecklistPage> {
  String? _selectedLearnerId;
  List<dynamic> _learners = [];
  bool _isLoading = true;

  // Traceability Data
  String? _projectId;
  String? _siteId;
  String? _classId;

  // Checklist State
  final Map<String, bool> _checklistState = {};

  final SignatureController _learnerSig = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);
  final SignatureController _assessorSig = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);

  final Map<String, List<String>> _checklistData = {
    'Foundational Evidence': [
      'Certified Copy of Identity Document',
      'Service Letters from Employers (Plumbing Experience)',
      'Previous Qualifications / Certificates',
      'Curriculum Vitae (CV)',
    ],
    'Hot & Cold Water Systems': [
      'Installation of Geysers (Electric/Solar)',
      'Pipe Work: Copper, PEX, and Multilayer',
      'Pressure Testing Reports',
      'Installation of Valves and Controls',
    ],
    'Drainage & Sanitation': [
      'Above-ground Drainage (Stack pipes, Vents)',
      'Below-ground Drainage (Trenches, Gully, Manholes)',
      'Sanitaryware Installation (Toilets, Basins, Baths)',
      'Waste Water Management',
    ],
    'Safety & Tools': [
      'Risk Assessment / Site Safety Report',
      'Tool Maintenance Log',
      'PPE Compliance Photos',
    ],
  };

  @override
  void initState() {
    super.initState();
    _fetchLearners();
  }

  Future<void> _fetchLearners() async {
    try {
      final db = await DatabaseHelper().database;
      final facilitatorClasses = await db.query(
        'facilitator',
        columns: ['classID'],
        where: 'facilitator_id = ?',
        whereArgs: [widget.facilitatorId],
      );

      Set<String> classIds = {};
      for (var row in facilitatorClasses) {
        String ids = row['classID']?.toString() ?? '';
        if (ids.isNotEmpty) {
          classIds.addAll(ids.split(',').map((e) => e.trim()));
        }
      }

      if (classIds.isNotEmpty) {
        final learnersList = await db.query(
          'learnerdetails',
          where: 'classID IN (${classIds.map((_) => '?').join(',')})',
          whereArgs: classIds.toList(),
        );

        setState(() {
          _learners = learnersList;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching learners: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTraceabilityData(String learnerId) async {
    try {
      final trace = await DatabaseHelper().getLearnerTraceability(learnerId);
      setState(() {
        _classId = trace['classID'];
        _siteId = trace['siteID'];
        _projectId = trace['project_id'];
      });
    } catch (e) {
      print('[ARPL] Error fetching traceability data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLearner = _selectedLearnerId == null
        ? null
        : _learners.any((l) => l['LearnerID'].toString() == _selectedLearnerId)
            ? _learners.firstWhere(
                (l) => l['LearnerID'].toString() == _selectedLearnerId)
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ARPL Evidence Checklist'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedLearner != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.indigo.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Verifying Evidence for:',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.indigo)),
                          Text(
                            '${selectedLearner['Name']} ${selectedLearner['Surname']}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo),
                          ),
                          Text('ID: ${selectedLearner['IDNumber']}',
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  const Text(
                    'Select Candidate',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedLearnerId,
                    hint: const Text('Select a learner'),
                    isExpanded: true,
                    items: _learners.map((learner) {
                      return DropdownMenuItem<String>(
                        value: learner['LearnerID'].toString(),
                        child: Text(
                            '${learner['Name']} ${learner['Surname']} (${learner['IDNumber']})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLearnerId = value;
                        // Reset form or load data
                        if (value != null) {
                          _fetchTraceabilityData(value);
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  if (_selectedLearnerId != null) ...[
                    const SizedBox(height: 24),
                    ..._checklistData.entries.map((section) =>
                        _buildChecklistSection(section.key, section.value)),
                    const SizedBox(height: 24),
                    DualSignaturePad(
                      title: 'Evidence Verification Signatures',
                      learnerController: _learnerSig,
                      assessorController: _assessorSig,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Evidence Verification Saved')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Finalize Evidence Verification'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildChecklistSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.indigo),
          ),
        ),
        Card(
          elevation: 2,
          child: Column(
            children: items
                .map((item) => CheckboxListTile(
                      title: Text(item, style: const TextStyle(fontSize: 14)),
                      value: _checklistState[item] ?? false,
                      onChanged: (bool? value) {
                        setState(() {
                          _checklistState[item] = value ?? false;
                        });
                      },
                      activeColor: Colors.indigo,
                      controlAffinity: ListTileControlAffinity.leading,
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class DualSignaturePad extends StatelessWidget {
  final String title;
  final SignatureController learnerController;
  final SignatureController assessorController;

  const DualSignaturePad({
    super.key,
    required this.title,
    required this.learnerController,
    required this.assessorController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.indigo)),
          const SizedBox(height: 12),
          _buildPad('Learner Signature', learnerController),
          const SizedBox(height: 16),
          _buildPad('Assessor Signature', assessorController),
        ],
      ),
    );
  }

  Widget _buildPad(String label, SignatureController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700])),
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.red, size: 20),
                onPressed: () => controller.clear(),
                tooltip: 'Clear signature',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Signature(
                controller: controller,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text('Sign above',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class ARPLAssessorReviewPage extends StatefulWidget {
  final String facilitatorId;

  const ARPLAssessorReviewPage({super.key, required this.facilitatorId});

  @override
  _ARPLAssessorReviewPageState createState() => _ARPLAssessorReviewPageState();
}

class _ARPLAssessorReviewPageState extends State<ARPLAssessorReviewPage> {
  String? _selectedLearnerId;
  List<dynamic> _learners = [];
  bool _isLoading = true;

  // Loaded Activities from API
  List<dynamic> _appendixBActivities = [];
  Map<int, dynamic> _activityRatings = {};
  String? _ofoNumber;

  // Appendix D State
  final List<String> _appendixDItems = [
    'Health, Safety and Environmental Protection',
    'Organize and Use Plumbing Tools and Equipment',
    'Install and Maintain Hot Water Systems',
    'Install and Maintain Cold Water Systems',
    'Install and Maintain Above-ground Drainage',
    'Install and Maintain Below-ground Drainage',
    'Install and Maintain Sanitaryware',
    'Maintain and Repair Plumbing Systems',
    'Install and Maintain Rainwater Harvesting',
    'Install and Maintain Solar Water Heating',
  ];
  Map<int, String> _appendixDValues = {}; // 'Yes' or 'No'

  // Appendix E State - Electrician Activities with 1-5 Rating
  List<dynamic> _appendixEActivities = [];
  Map<int, int> _appendixERatings = {}; // 1-5 ratings by index
  Map<int, String> _appendixEComments = {}; // Comments by index
  bool _appendixELoaded = false;

  // Evaluation Criteria State
  final List<String> _evaluationCriteria = [
    'Portfolio of Evidence (PoE) completeness and authenticity.',
    'Successful completion of all practical workshop tasks.',
    'Knowledge of South African National Standards (SANS 10252/10254).',
    'Demonstrated ability to interpret technical plumbing drawings.',
    'Compliance with Health and Safety regulations on site.',
    'Ability to perform maintenance and repairs on existing systems.',
  ];
  Map<int, bool> _evaluationChecks = {};
  bool _assessorConfirmed = false;

  // Appendix H State - Access Recommendation
  List<dynamic> _appendixHItems = []; // 4 assessment items from API
  Map<int, String?> _appendixHStatuses = {}; // Status for each ACRID
  Map<int, String> _appendixHRemarks = {}; // Remarks for each ACRID
  List<dynamic> _unitStandards = []; // Unit standards for qualification 91761
  Set<int> _selectedUnitStandards = {}; // Selected unit standard IDs
  bool _appendixHLoaded = false;
  bool _showUnitStandardsSelection = false;
  // Appendix F State
  final TextEditingController _strengthsController = TextEditingController();
  final TextEditingController _improvementsController = TextEditingController();
  final TextEditingController _actionPlanController = TextEditingController();
  final TextEditingController _assessorCommentsController =
      TextEditingController();

  // Signature Controllers
  final SignatureController _learnerSigD = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);
  final SignatureController _assessorSigD = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);
  final SignatureController _learnerSigE = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);
  final SignatureController _assessorSigE = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);
  final SignatureController _learnerSigF = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);
  final SignatureController _assessorSigF = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);

  // Traceability Data
  String? _projectId;
  String? _siteId;
  String? _classId;

  @override
  void initState() {
    super.initState();
    _fetchLearners();
    // Note: _appendixEActivities initialization removed - now loaded from API
    for (int i = 0; i < _appendixDItems.length; i++) {
      _appendixDValues[i] = '';
    }
    for (int i = 0; i < _evaluationCriteria.length; i++) {
      _evaluationChecks[i] = false;
    }
  }

  @override
  void dispose() {
    // Note: _appendixEControllers removed - using comments map now
    _strengthsController.dispose();
    _improvementsController.dispose();
    _actionPlanController.dispose();
    _assessorCommentsController.dispose();
    _learnerSigD.dispose();
    _assessorSigD.dispose();
    _learnerSigE.dispose();
    _assessorSigE.dispose();
    _learnerSigF.dispose();
    _assessorSigF.dispose();
    super.dispose();
  }

  Future<void> _fetchTraceabilityData(String learnerId) async {
    try {
      final trace = await DatabaseHelper().getLearnerTraceability(learnerId);

      String? classId = trace['classID'];
      String? siteId = trace['siteID'];
      String? projectId = trace['project_id'];

      if (classId == null || classId.isEmpty) {
        for (final learner in _learners) {
          if (learner['LearnerID'].toString() == learnerId) {
            classId = learner['classID']?.toString();
            break;
          }
        }
        if (classId != null && classId.isNotEmpty) {
          final db = await DatabaseHelper().database;
          final classResults = await db.rawQuery('''
            SELECT c.siteID, s.project_id
            FROM class c
            LEFT JOIN sites s ON c.siteID = s.siteID
            WHERE c.classID = ?
          ''', [classId]);
          if (classResults.isNotEmpty) {
            siteId ??= classResults.first['siteID']?.toString();
            projectId ??= classResults.first['project_id']?.toString();
          }
        }
      }

      // FIX: Fetch OFO for this class
      String? ofoNumber;
      if (classId != null && classId.isNotEmpty) {
        print('[ARPL] Fetching OFO for classID: $classId');
        ofoNumber = await _fetchOfoFromClassData(classId);
        print('[ARPL] Fetched OFO: $ofoNumber');
      }

      setState(() {
        _classId = classId;
        _siteId = siteId;
        _projectId = projectId;
        _ofoNumber = ofoNumber; // Set OFO number
      });
      print(
          '[ARPL] Traceability data: Class=$_classId, Site=$_siteId, Project=$_projectId, OFO=$_ofoNumber');

      _loadExistingARPLData(learnerId);

      // Load activities now that we have OFO
      if (ofoNumber != null && ofoNumber.isNotEmpty) {
        _loadActivitiesFromAPI(learnerId);
      }
    } catch (e) {
      print('[ARPL] Error fetching traceability data: $e');
    }
  }

  Future<void> _loadExistingARPLData(String learnerId) async {
    try {
      final url = '${AppConfig.getArplDataUrl}?learner_id=$learnerId';
      print('[ARPL] Loading existing data from: $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        try {
          // Check if response body is empty
          if (response.body.isEmpty) {
            print('[ARPL] Empty response body from API');
            return;
          }

          print(
              '[ARPL] API Response: ${response.body.substring(0, min(200, response.body.length))}...');
          final res = jsonDecode(response.body);

          if (res['success'] == true && res['data'] != null) {
            final data = res['data'];
            setState(() {
              // Reset state before loading
              for (int i = 0; i < _appendixDItems.length; i++) {
                _appendixDValues[i] = '';
              }
              // Note: Appendix E reset removed - handled by _loadAppendixEData()
              for (int i = 0; i < _evaluationCriteria.length; i++) {
                _evaluationChecks[i] = false;
              }
              _strengthsController.clear();
              _improvementsController.clear();
              _actionPlanController.clear();
              _assessorCommentsController.clear();
              _assessorConfirmed = false;

              // Load Appendix D
              if (data['appendix_d'] != null) {
                try {
                  final d = data['appendix_d'];
                  final Map<String, dynamic> responses =
                      jsonDecode(d['responses_json'] ?? '{}');
                  responses.forEach((key, value) {
                    _appendixDValues[int.parse(key)] = value.toString();
                  });
                  _assessorCommentsController.text =
                      d['assessor_comments'] ?? '';
                } catch (e) {
                  print('[ARPL] Error loading Appendix D: $e');
                }
              }

              // Note: Appendix E loading removed - handled by _loadAppendixEData()

              // Load Appendix F
              if (data['appendix_f'] != null) {
                try {
                  final f = data['appendix_f'];
                  _strengthsController.text = f['strengths'] ?? '';
                  _improvementsController.text = f['improvements'] ?? '';
                  _actionPlanController.text = f['action_plan'] ?? '';
                } catch (e) {
                  print('[ARPL] Error loading Appendix F: $e');
                }
              }

              // Load Criteria
              if (data['criteria'] != null) {
                try {
                  final c = data['criteria'];
                  final Map<String, dynamic> checks =
                      jsonDecode(c['criteria_json'] ?? '{}');
                  checks.forEach((key, value) {
                    _evaluationChecks[int.parse(key)] = value as bool;
                  });
                  _assessorConfirmed = (c['assessor_confirmation'] == 1);
                } catch (e) {
                  print('[ARPL] Error loading Criteria: $e');
                }
              }
            });
          } else {
            print('[ARPL] API returned success=false or no data');
          }
        } catch (e) {
          print('[ARPL] Error parsing response JSON: $e');
          print(
              '[ARPL] Response body: ${response.body.substring(0, min(500, response.body.length))}');
        }
      } else {
        print('[ARPL] HTTP Error: ${response.statusCode}');
        print('[ARPL] Response: ${response.body}');
      }
    } catch (e) {
      print('[ARPL] Error loading existing data: $e');
    }
  }

  /// jsonEncode cannot serialize Map<int, T>; keys must be strings.
  String _encodeIntKeyedMap<V>(Map<int, V> map) {
    return jsonEncode(map.map((key, value) => MapEntry(key.toString(), value)));
  }

  Map<String, dynamic> _arplBasePayload() {
    if (_classId == null ||
        _classId!.isEmpty ||
        _siteId == null ||
        _siteId!.isEmpty ||
        _projectId == null ||
        _projectId!.isEmpty) {
      throw Exception(
          'Missing class/site/project data. Reselect the candidate and try again.');
    }
    return {
      'learner_id': int.parse(_selectedLearnerId!),
      'assessor_id': int.parse(widget.facilitatorId),
      'class_id': int.parse(_classId!),
      'project_id': int.parse(_projectId!),
      'site_id': int.parse(_siteId!),
    };
  }

  Future<Map<String, dynamic>> _buildArplPayload() async {
    if (_selectedLearnerId == null) {
      throw Exception('No candidate selected.');
    }
    if (_classId == null ||
        _siteId == null ||
        _projectId == null ||
        _classId!.isEmpty ||
        _siteId!.isEmpty ||
        _projectId!.isEmpty) {
      await _fetchTraceabilityData(_selectedLearnerId!);
    }
    return _arplBasePayload();
  }

  void _showArplSaveResult(Map<String, dynamic> res, String fallback) {
    final ok = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message'] ?? fallback),
        backgroundColor: ok ? null : Colors.red.shade700,
      ),
    );
  }

  Future<void> _saveAppendixB() async {
    if (_selectedLearnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a learner first')),
      );
      return;
    }

    if (_appendixBActivities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No activities loaded')),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      // Build ratings array
      final ratings = <Map<String, dynamic>>[];

      for (int i = 0; i < _appendixBActivities.length; i++) {
        final activity = _appendixBActivities[i];
        final rating = _appendixDValues[i]; // Appendix B uses same storage as D

        if (rating != null && rating.isNotEmpty) {
          final ratingValue = int.tryParse(rating);
          if (ratingValue != null && ratingValue >= 1 && ratingValue <= 5) {
            ratings.add({
              'activity_id': activity['activity_id'] ?? (i + 1),
              'activity_name': activity['activity_name'] ?? 'Unknown Activity',
              'rating': ratingValue,
              'comments': '', // No comments in Appendix B UI currently
            });
          }
        }
      }

      if (ratings.isEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please rate at least one activity')),
        );
        return;
      }

      final payload = {
        'learnerID': _selectedLearnerId,
        'assessor_id': widget.facilitatorId,
        'ofo_number': _ofoNumber,
        'ratings': ratings,
      };

      final response = await http.post(
        Uri.parse(AppConfig.saveArplAppendixBUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      Navigator.pop(context); // Hide loader

      final res = jsonDecode(response.body);

      if (res['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Appendix B saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to save Appendix B'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _saveAppendixD() async {
    if (_selectedLearnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a learner first')),
      );
      return;
    }

    if (_appendixBActivities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No activities loaded')),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      // Build activities object (key: activity number, value: 'yes' or 'no')
      final activities = <String, String>{};

      for (int i = 0; i < _appendixBActivities.length; i++) {
        final activity = _appendixBActivities[i];
        final activityId = activity['activity_id'] ?? (i + 1);
        final response = _appendixDValues[i]?.toLowerCase() ?? 'no';

        // Appendix D expects 'yes' or 'no' strings
        activities[activityId.toString()] = response;
      }

      if (activities.isEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please respond to at least one activity')),
        );
        return;
      }

      final payload = {
        'learnerID': int.parse(_selectedLearnerId!),
        'assessor_id': int.parse(widget.facilitatorId),
        'ofo_number': _ofoNumber ?? '', // Empty if not set - don't default
        'activities': activities,
      };

      final response = await http.post(
        Uri.parse(AppConfig.saveArplAppendixDUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      Navigator.pop(context); // Hide loader

      final res = jsonDecode(response.body);

      if (res['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Appendix D saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to save Appendix D'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _saveAppendixF() async {
    if (_selectedLearnerId == null) return;

    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator()));

      final learnerSig = await _learnerSigF.toPngBytes();
      final assessorSig = await _assessorSigF.toPngBytes();

      final payload = {
        ...(await _buildArplPayload()),
        'strengths': _strengthsController.text,
        'improvements': _improvementsController.text,
        'action_plan': _actionPlanController.text,
        'learner_signature':
            learnerSig != null ? base64Encode(learnerSig) : null,
        'assessor_signature':
            assessorSig != null ? base64Encode(assessorSig) : null,
      };

      final response = await http.post(
        Uri.parse(AppConfig.saveArplAppendixFUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      Navigator.pop(context);
      final res = jsonDecode(response.body);
      _showArplSaveResult(res, 'Feedback Saved');
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _saveCriteria() async {
    if (_selectedLearnerId == null) return;

    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator()));

      final payload = {
        ...(await _buildArplPayload()),
        'criteria_json': _encodeIntKeyedMap(_evaluationChecks),
        'is_recommended': _assessorConfirmed ? 1 : 0,
        'assessor_confirmation': _assessorConfirmed ? 1 : 0,
      };

      final response = await http.post(
        Uri.parse(AppConfig.saveArplCriteriaUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      Navigator.pop(context);
      final res = jsonDecode(response.body);
      _showArplSaveResult(res, 'Criteria Saved');
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _fetchLearners() async {
    try {
      final db = await DatabaseHelper().database;
      // Get classes for this facilitator to find their learners
      final facilitatorClasses = await db.query(
        'facilitator',
        columns: ['classID'],
        where: 'facilitator_id = ?',
        whereArgs: [widget.facilitatorId],
      );

      Set<String> classIds = {};
      for (var row in facilitatorClasses) {
        String ids = row['classID']?.toString() ?? '';
        if (ids.isNotEmpty) {
          classIds.addAll(ids.split(',').map((e) => e.trim()));
        }
      }

      if (classIds.isNotEmpty) {
        final learnersList = await db.query(
          'learnerdetails',
          where: 'classID IN (${classIds.map((_) => '?').join(',')})',
          whereArgs: classIds.toList(),
        );

        setState(() {
          _learners = learnersList;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching learners: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Load Appendix B activities from API based on learner's OFO
  Future<void> _loadActivitiesFromAPI(String learnerId) async {
    try {
      final url = AppConfig.buildUrl('get_arpl_competency_data.php',
          queryParams: {'learnerID': learnerId});
      print('[ARPL] Loading activities from: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[ARPL DEBUG] Full response: $data');

        if (data['status'] == 'success') {
          // First try to get OFO from API
          var ofoValue = data['ofo_number'];
          print(
              '[ARPL DEBUG] Raw OFO value from API: $ofoValue (type: ${ofoValue.runtimeType})');

          String? finalOfoNumber;
          if (ofoValue != null && ofoValue.toString().isNotEmpty) {
            finalOfoNumber = ofoValue.toString();
          } else if (_classId != null && _classId!.isNotEmpty) {
            // If API didn't return OFO, fetch from class data
            print('[ARPL] API missing OFO, fetching from class $_classId');
            finalOfoNumber = await _fetchOfoFromClassData(_classId!);
          }

          // Final fallback - if still no OFO, throw error instead of defaulting
          if (finalOfoNumber == null || finalOfoNumber.isEmpty) {
            print(
                '[ARPL] ERROR: No OFO found for learner. Cannot determine trade.');
            throw Exception(
                'Could not determine trade for learner. ClassID: $_classId');
          }

          setState(() {
            _appendixBActivities = data['appxb_activities'] ?? [];
            _ofoNumber = finalOfoNumber;
            print('[ARPL DEBUG] Final _ofoNumber: $_ofoNumber');

            // Map ratings by activity_id for quick lookup
            if (data['appxb_ratings'] != null) {
              _activityRatings.clear();
              for (var rating in data['appxb_ratings']) {
                _activityRatings[rating['activity_id']] = rating;
              }
            }

            print(
                '[ARPL] Loaded ${_appendixBActivities.length} activities for OFO $_ofoNumber');

            // Also load Appendix E data
            _loadAppendixEData();
          });
        } else {
          print('[ARPL] API Error: ${data['message']}');
        }
      } else {
        print('[ARPL] HTTP Error: ${response.statusCode}');
        print('[ARPL] Response body: ${response.body}');
      }
    } catch (e) {
      print('[ARPL] Error loading activities: $e');
      print('[ARPL] Stack trace: ${e.toString()}');
    }
  }

  /// Fetch OFO for a given class
  Future<String?> _fetchOfoFromClassData(String classId) async {
    try {
      print('[ARPL] Fetching OFO for classID: $classId');

      final response = await http.post(
        Uri.parse(
          '${AppConfig.baseUrl}/get_class_trade_info.php',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'classID': int.parse(classId),
        }),
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success' && data['ofo_number'] != null) {
            final ofo = data['ofo_number'].toString();
            final tradeName = data['trade_name'] ?? 'Unknown';
            print('[ARPL] Class OFO retrieved: $ofo for trade: $tradeName');
            return ofo;
          } else {
            print('[ARPL] API returned no OFO: ${data['message']}');
            return null;
          }
        } catch (e) {
          print('[ARPL] Error parsing OFO response: $e');
          return null;
        }
      } else {
        print('[ARPL] Failed to fetch OFO: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[ARPL] Exception fetching OFO: $e');
      return null;
    }
  }

  // Load Appendix E electrician activities and ratings
  Future<void> _loadAppendixEData() async {
    try {
      if (_selectedLearnerId == null || _ofoNumber == null) {
        print('[ARPL-E] Cannot load: missing learnerID or OFO');
        return;
      }

      print(
          '[ARPL-E] Loading data for learner: $_selectedLearnerId, OFO: $_ofoNumber');

      final response = await http.post(
        Uri.parse(AppConfig.getArplAppendixEUrl),
        body: {
          'learnerID': _selectedLearnerId!,
          'ofo_number': _ofoNumber ?? '', // Don't default to 671101
          'facilitator_id': '1', // TODO: Get from user session
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[ARPL-E] Response: $data');

        if (data['status'] == 'success') {
          setState(() {
            // Get activities from database
            _appendixEActivities = data['activities'] ?? [];

            // Get existing ratings map (activity_id => rating data)
            // Handle both List (empty array) and Map types
            var ratingsData = data['existing_ratings'];
            Map<String, dynamic> existingRatings = (ratingsData is Map)
                ? Map<String, dynamic>.from(ratingsData)
                : {};

            _appendixELoaded = true;
            _appendixERatings.clear();
            _appendixEComments.clear();

            // Map existing ratings to activities by index
            for (int i = 0; i < _appendixEActivities.length; i++) {
              final activity = _appendixEActivities[i];
              final activityId = activity['activity_id']?.toString();

              if (activityId != null &&
                  existingRatings.containsKey(activityId)) {
                final ratingData = existingRatings[activityId];
                _appendixERatings[i] = int.tryParse(
                        ratingData['competency_scale_id']?.toString() ?? '0') ??
                    0;
                _appendixEComments[i] =
                    ratingData['comments']?.toString() ?? '';
              }
            }

            print(
                '[ARPL-E] Loaded ${_appendixEActivities.length} activities from database');
            print('[ARPL-E] Found ${existingRatings.length} existing ratings');
          });
        } else {
          print('[ARPL-E] Error: ${data['message']}');
        }
      } else {
        print('[ARPL-E] HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('[ARPL-E] Error loading data: $e');
    }
  }

  // Save Appendix E ratings
  Future<void> _saveAppendixE() async {
    try {
      if (_selectedLearnerId == null || _ofoNumber == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing learner or OFO data')),
        );
        return;
      }

      // Build ratings array matching API format
      List<Map<String, dynamic>> ratingsArray = [];
      for (int i = 0; i < _appendixEActivities.length; i++) {
        final activity = _appendixEActivities[i];
        final rating = _appendixERatings[i] ?? 0;

        // Only include ratings that have been set (1-5)
        if (rating >= 1 && rating <= 5) {
          ratingsArray.add({
            'activity_id': activity['activity_id'],
            'activity_name': activity['activity_name'],
            'competency_scale_id': rating,
            'comments': _appendixEComments[i] ?? '',
          });
        }
      }

      if (ratingsArray.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please rate at least one activity')),
        );
        return;
      }

      final payload = {
        'learnerID': int.parse(_selectedLearnerId!),
        'facilitator_id': int.parse(widget.facilitatorId),
        'ofo_number': _ofoNumber,
        'ratings': ratingsArray,
      };

      print('[ARPL-E] Saving with payload: $payload');

      final response = await http.post(
        Uri.parse(AppConfig.saveArplAppendixEUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('[ARPL-E] Response status: ${response.statusCode}');
      print('[ARPL-E] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('[ARPL-E] Save response: $result');

        if (result['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          print('[ARPL-E] Saved ${result['saved_count']} ratings successfully');

          // Reload to show updated data
          _loadAppendixEData();
        } else {
          throw Exception(result['message'] ?? 'Save failed');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('[ARPL-E] Error saving: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final selectedLearner = _selectedLearnerId == null
          ? null
          : (_learners.isNotEmpty &&
                  _learners.any(
                      (l) => l['LearnerID'].toString() == _selectedLearnerId))
              ? _learners.firstWhere(
                  (l) => l['LearnerID'].toString() == _selectedLearnerId)
              : null;

      return Scaffold(
        appBar: AppBar(
          title: const Text('ARPL Assessor Review'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Fixed Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selectedLearner != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.indigo.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Reviewing Candidate:',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.indigo)),
                                Text(
                                  '${selectedLearner['Name']} ${selectedLearner['Surname']}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo),
                                ),
                                Text('ID: ${selectedLearner['IDNumber']}',
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        const Text(
                          'Select Candidate',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedLearnerId,
                          hint: const Text('Select a learner'),
                          isExpanded: true,
                          items: _learners.map((learner) {
                            return DropdownMenuItem<String>(
                              value: learner['LearnerID'].toString(),
                              child: Text(
                                  '${learner['Name']} ${learner['Surname']} (${learner['IDNumber']})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedLearnerId = value;
                              if (value != null) {
                                _fetchTraceabilityData(value);
                                _loadActivitiesFromAPI(value);
                                _loadAppendixHItems();
                              }
                            });
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedLearnerId != null)
                    Expanded(
                      child: DefaultTabController(
                        length: 6,
                        child: Column(
                          children: [
                            const TabBar(
                              labelColor: Colors.indigo,
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: Colors.indigo,
                              isScrollable: true,
                              tabs: [
                                Tab(text: 'Eval Criteria'),
                                Tab(text: 'Appx B (Activities)'),
                                Tab(text: 'Appx D (Self-Eval)'),
                                Tab(text: 'Appx E (Interview)'),
                                Tab(text: 'Appx F (Feedback)'),
                                Tab(text: 'Appx H (Access Rec)'),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildEvaluationCriteria(),
                                  _buildAppendixB(),
                                  _buildAppendixD(),
                                  _buildAppendixE(),
                                  _buildAppendixF(),
                                  _buildAppendixH(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      );
    } catch (e, stackTrace) {
      print('[ARPL BUILD ERROR] Error building ARPL page: $e');
      print('[ARPL BUILD STACK] $stackTrace');

      return Scaffold(
        appBar: AppBar(
          title: const Text('ARPL Assessor Review'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error Loading Page',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Error: ${e.toString()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildEvaluationCriteria() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Section 5: Evaluation Criteria',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The candidate must demonstrate competency in the following core areas to be recommended for EISA:',
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ..._evaluationCriteria.asMap().entries.map((entry) {
            int index = entry.key;
            String criteria = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: CheckboxListTile(
                value: _evaluationChecks[index],
                onChanged: (val) {
                  setState(() {
                    _evaluationChecks[index] = val!;
                  });
                },
                title: Text(
                  criteria,
                  style: const TextStyle(fontSize: 14),
                ),
                activeColor: Colors.green,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            );
          }).toList(),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Assessor Confirmation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: CheckboxListTile(
              title: const Text(
                'I confirm that I have evaluated the candidate against the above criteria and recommend them for final assessment.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              value: _assessorConfirmed,
              onChanged: (val) {
                setState(() {
                  _assessorConfirmed = val!;
                });
              },
              activeColor: Colors.green,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveCriteria,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Save Criteria',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCriteriaItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildAppendixB() {
    // Use loaded activities from API, fallback to empty if not loaded
    final activities =
        _appendixBActivities.isNotEmpty ? _appendixBActivities : [];

    if (activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Activities not loaded',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'OFO: $_ofoNumber',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appendix B: Electrician Activities Assessment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'OFO: $_ofoNumber',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rate each activity on a scale of 1-5 (1=Low, 5=High)',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...activities.asMap().entries.map((entry) {
              int index = entry.key;
              var activity = entry.value;
              String activityName =
                  activity['activity_name'] ?? 'Unknown Activity';
              // Fix: Convert activity_number to int, handling both string and int types
              int activityNumber = 0;
              try {
                var rawNumber = activity['activity_number'];
                if (rawNumber is int) {
                  activityNumber = rawNumber;
                } else if (rawNumber is String) {
                  activityNumber = int.parse(rawNumber);
                } else {
                  activityNumber = index + 1;
                }
              } catch (e) {
                print('[ARPL] Error parsing activity_number in appendixB: $e');
                activityNumber = index + 1;
              }

              int currentRating = _appendixDValues[index]?.isNotEmpty ?? false
                  ? int.tryParse(_appendixDValues[index]!) ?? 0
                  : 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$activityNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            activityName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Candidate Competence (1=Low, 5=High)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(5, (i) {
                        final level = i + 1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _appendixDValues[index] = level.toString();
                              });
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: currentRating == level
                                      ? _getLevelColorAppxD(level)
                                      : Colors.grey.shade300,
                                  width: currentRating == level ? 3 : 2,
                                ),
                                color: currentRating == level
                                    ? _getLevelColorAppxD(level)
                                        .withValues(alpha: 0.2)
                                    : Colors.transparent,
                              ),
                              child: Center(
                                child: Text(
                                  level.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: currentRating == level
                                        ? _getLevelColorAppxD(level)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveAppendixB,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Appendix B',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAppendixD() {
    // Use loaded activities from API, fallback to empty if not loaded
    final activities =
        _appendixBActivities.isNotEmpty ? _appendixBActivities : [];

    if (activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Activities not loaded',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'OFO: $_ofoNumber',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appendix D: Self-Evaluation Assessment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'OFO: $_ofoNumber',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tick (Yes) or leave blank (No) for each activity',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...activities.asMap().entries.map((entry) {
              int index = entry.key;
              var activity = entry.value;
              String activityName =
                  activity['activity_name'] ?? 'Unknown Activity';
              // Fix: Convert activity_number to int, handling both string and int types
              int activityNumber = 0;
              try {
                var rawNumber = activity['activity_number'];
                if (rawNumber is int) {
                  activityNumber = rawNumber;
                } else if (rawNumber is String) {
                  activityNumber = int.parse(rawNumber);
                } else {
                  activityNumber = index + 1;
                }
              } catch (e) {
                print('[ARPL] Error parsing activity_number in appendixD: $e');
                activityNumber = index + 1;
              }

              // For Appendix D, we store 'yes' or 'no' (not 1-5 scale)
              bool isChecked = _appendixDValues[index]?.toLowerCase() == 'yes';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isChecked ? Colors.indigo : Colors.grey.shade300,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isChecked
                      ? Colors.indigo.withOpacity(0.08)
                      : Colors.transparent,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _appendixDValues[index] = isChecked ? 'no' : 'yes';
                        });
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 12, top: 2),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isChecked
                                ? Colors.indigo
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          color: isChecked ? Colors.indigo : Colors.transparent,
                        ),
                        child: isChecked
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ),
                    // Activity number and name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.indigo,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$activityNumber',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  activityName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status indicator
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        isChecked ? '✓' : '○',
                        style: TextStyle(
                          fontSize: 18,
                          color:
                              isChecked ? Colors.green : Colors.grey.shade400,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveAppendixD,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Appendix D',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Color _getLevelColorAppxD(int level) {
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

  String _getRatingLevelAppxD(int level) {
    switch (level) {
      case 1:
        return 'Fundamental';
      case 2:
        return 'Novice';
      case 3:
        return 'Advanced';
      case 4:
        return 'Advanced+';
      case 5:
        return 'Expert';
      default:
        return '';
    }
  }

  /// Get trade name from OFO number
  /// Maps OFO codes to their corresponding trade names
  String _getTradeName(String? ofoNumber) {
    switch (ofoNumber) {
      case '671101':
        return 'Electrician';
      case '642601':
        return 'Plumber';
      case '641201':
        return 'Bricklayer';
      default:
        return 'Unknown Trade';
    }
  }

  Widget _buildAppendixE() {
    print('[ARPL-E BUILD] _buildAppendixE() called');
    print(
        '[ARPL-E BUILD] _appendixEActivities.isEmpty: ${_appendixEActivities.isEmpty}');
    print(
        '[ARPL-E BUILD] _appendixEActivities.length: ${_appendixEActivities.length}');
    print('[ARPL-E BUILD] _selectedLearnerId: $_selectedLearnerId');
    print('[ARPL-E BUILD] _ofoNumber: $_ofoNumber');
    print('[ARPL-E BUILD] _appendixELoaded: $_appendixELoaded');

    // Load activities if not loaded yet and we have required data
    if (_appendixEActivities.isEmpty &&
        _selectedLearnerId != null &&
        _ofoNumber != null &&
        !_appendixELoaded) {
      print('[ARPL-E BUILD] Triggering _loadAppendixEData() from tab build');
      // Load data when tab is displayed
      Future.microtask(() => _loadAppendixEData());
    } else if (_appendixEActivities.isEmpty) {
      print('[ARPL-E BUILD] NOT loading because:');
      print('[ARPL-E BUILD]   - isEmpty: ${_appendixEActivities.isEmpty}');
      print('[ARPL-E BUILD]   - learnerId null: ${_selectedLearnerId == null}');
      print('[ARPL-E BUILD]   - ofo null: ${_ofoNumber == null}');
      print('[ARPL-E BUILD]   - already loaded: $_appendixELoaded');
    }

    // Show loading or no data
    if (_appendixEActivities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Activities not loaded',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'OFO: $_ofoNumber',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'Learner: $_selectedLearnerId',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appendix E: Electrician Activities Assessment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'OFO: $_ofoNumber',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rate each activity on a scale of 1-5 (1=Low, 5=High)',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ..._appendixEActivities.asMap().entries.map((entry) {
              int index = entry.key;
              var activity = entry.value;
              String activityName =
                  activity['activity_name'] ?? 'Unknown Activity';
              int activityNumber = activity['activity_id'] ?? (index + 1);
              int currentRating = _appendixERatings[index] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$activityNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            activityName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Candidate Competence (1=Low, 5=High)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(5, (i) {
                        final level = i + 1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _appendixERatings[index] = level;
                              });
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: currentRating == level
                                      ? _getLevelColorAppxD(level)
                                      : Colors.grey.shade300,
                                  width: currentRating == level ? 3 : 2,
                                ),
                                color: currentRating == level
                                    ? _getLevelColorAppxD(level)
                                        .withOpacity(0.2)
                                    : Colors.transparent,
                              ),
                              child: Center(
                                child: Text(
                                  '$level',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: currentRating == level
                                        ? _getLevelColorAppxD(level)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) {
                        _appendixEComments[index] = value;
                      },
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Comments (optional)',
                        fillColor: Colors.grey[50],
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveAppendixE,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Appendix E',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAppendixF() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appendix F: Feedback to Candidate',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo),
          ),
          const SizedBox(height: 16),
          _buildFeedbackSection(
            'Areas of Strength',
            'Highlight what the candidate did well...',
            Icons.thumb_up_alt_outlined,
            Colors.green,
            _strengthsController,
          ),
          _buildFeedbackSection(
            'Areas for Improvement',
            'Note technical gaps or safety concerns...',
            Icons.trending_up_outlined,
            Colors.orange,
            _improvementsController,
          ),
          _buildFeedbackSection(
            'Action Plan / Recommended Training',
            'Describe next steps for the candidate...',
            Icons.assignment_outlined,
            Colors.blue,
            _actionPlanController,
          ),
          const SizedBox(height: 16),
          DualSignaturePad(
            title: 'Feedback Signatures',
            learnerController: _learnerSigF,
            assessorController: _assessorSigF,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveAppendixF,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Submit Feedback',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(String title, String hint, IconData icon,
      Color color, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14, color: color),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppendixH() {
    // Show loading indicator while data is being fetched
    if (!_appendixHLoaded && _appendixHItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading assessment items...'),
          ],
        ),
      );
    }

    // Show error message if no items loaded
    if (_appendixHLoaded && _appendixHItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('No assessment items found'),
            const SizedBox(height: 8),
            Text('Learner ID: $_selectedLearnerId'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAppendixHItems,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appendix H: Access Recommendation',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete the access recommendation for the learner',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Assessment Items Section
            ..._appendixHItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final acrid = int.parse(item['ACRID'].toString());
              final assessmentType = item['AssessmentType'];

              // Determine possible statuses based on ACRID
              List<String> possibleStatuses = [];
              if (acrid <= 3) {
                possibleStatuses = ['Ready', 'Not Yet Ready'];
              } else if (acrid == 4) {
                possibleStatuses = [
                  'Recommended for trade test',
                  'Recommended for gap closure'
                ];
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${acrid}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              assessmentType,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _appendixHStatuses[acrid],
                        hint: const Text('Select Status'),
                        isExpanded: true,
                        items: possibleStatuses.map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _appendixHStatuses[acrid] = value;
                            // Check if we need to show unit standards selection
                            if (acrid == 4 &&
                                value == 'Recommended for gap closure') {
                              _showUnitStandardsSelection = true;
                              if (_unitStandards.isEmpty) {
                                _loadUnitStandards();
                              }
                            } else if (acrid == 4) {
                              _showUnitStandardsSelection = false;
                            }
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        maxLines: 2,
                        onChanged: (value) {
                          _appendixHRemarks[acrid] = value;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Remarks (optional)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            // Unit Standards Selection (shown only for gap closure)
            if (_showUnitStandardsSelection) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.school, color: Colors.orange),
                        SizedBox(width: 12),
                        Text(
                          'Select Unit Standards for Gap Closure',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select one or more unit standards that the learner needs to attend:',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    ..._unitStandards.map((us) {
                      final id = int.parse(us['id'].toString());
                      return CheckboxListTile(
                        title: Text(
                          us['unit_standard_name'],
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${us['Module_Code']} - ${us['module_type']} (${us['credits']} credits)',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: _selectedUnitStandards.contains(id),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedUnitStandards.add(id);
                            } else {
                              _selectedUnitStandards.remove(id);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveAppendixH,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Access Recommendation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Load Appendix H items from API
  Future<void> _loadAppendixHItems() async {
    if (_selectedLearnerId == null) {
      print('[APPX H] No learner selected, cannot load items');
      return;
    }

    print('[APPX H] Starting to load items for learner: $_selectedLearnerId');

    try {
      final url =
          '${AppConfig.baseUrl}/get_appxh_acr_items.php?learner_id=$_selectedLearnerId';
      print('[APPX H] Loading items from: $url');

      final response = await http.get(Uri.parse(url));
      print('[APPX H] Response status: ${response.statusCode}');
      print('[APPX H] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _appendixHItems = data['assessment_items'];
            _appendixHLoaded = true;

            // Pre-populate existing statuses and remarks
            for (var item in _appendixHItems) {
              final acrid = int.parse(item['ACRID'].toString());
              if (item['Status'] != null) {
                _appendixHStatuses[acrid] = item['Status'];
              }
              if (item['Remarks'] != null) {
                _appendixHRemarks[acrid] = item['Remarks'];
              }
            }
          });
          print('[APPX H] Loaded ${_appendixHItems.length} items successfully');
        } else {
          print('[APPX H] API returned success=false: ${data['message']}');
          setState(() {
            _appendixHLoaded = true; // Mark as loaded even on API error
          });
        }
      } else {
        print('[APPX H] HTTP error: ${response.statusCode}');
        setState(() {
          _appendixHLoaded = true; // Mark as loaded even on HTTP error
        });
      }
    } catch (e, stackTrace) {
      print('[APPX H] Error loading items: $e');
      print('[APPX H] Stack trace: $stackTrace');
      setState(() {
        _appendixHLoaded = true; // Mark as loaded even on exception
      });
    }
  }

  // Load Unit Standards for qualification 91761
  Future<void> _loadUnitStandards() async {
    try {
      final url =
          '${AppConfig.baseUrl}/get_unit_standards_for_qualification.php?qualification_id=91761';
      print('[APPX H] Loading unit standards from: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _unitStandards = data['unit_standards'];
          });
          print('[APPX H] Loaded ${_unitStandards.length} unit standards');
        }
      }
    } catch (e) {
      print('[APPX H] Error loading unit standards: $e');
    }
  }

  // Save Appendix H recommendation
  Future<void> _saveAppendixH() async {
    if (_selectedLearnerId == null) return;

    // Validate all 4 items have statuses
    for (var item in _appendixHItems) {
      final acrid = int.parse(item['ACRID'].toString());
      if (_appendixHStatuses[acrid] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select status for ${item['AssessmentType']}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // If gap closure, validate unit standards selection
    if (_showUnitStandardsSelection && _selectedUnitStandards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please select at least one unit standard for gap closure'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Build recommendations array
      final recommendations = _appendixHItems.map((item) {
        final acrid = int.parse(item['ACRID'].toString());
        return {
          'acrid': acrid,
          'status': _appendixHStatuses[acrid],
          'remarks': _appendixHRemarks[acrid] ?? '',
        };
      }).toList();

      final requestBody = {
        'learner_id': int.parse(_selectedLearnerId!),
        'ofo_code': _ofoNumber ?? '',
        'trade': _getTradeName(_ofoNumber),
        'recommendations': recommendations,
      };

      print('[APPX H] Saving recommendations: ${json.encode(requestBody)}');

      final url = '${AppConfig.baseUrl}/save_appxh_recommendation.php';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('[APPX H] Save response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          // If gap closure, save unit standards
          if (_showUnitStandardsSelection &&
              _selectedUnitStandards.isNotEmpty) {
            await _saveGapAnalysisUnitStandards(data['recommendation_id']);
          }

          if (mounted) {
            // Show success dialog with option to view complete toolkit
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 32),
                      SizedBox(width: 12),
                      Text('Recommendation Saved'),
                    ],
                  ),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Access recommendation saved successfully!'),
                      SizedBox(height: 16),
                      Text(
                        'Would you like to view the complete ARPL toolkit with all saved assessments?',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                      },
                      child: const Text('Later'),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.description),
                      label: const Text('View Complete Toolkit'),
                      onPressed: () {
                        // Debug logging
                        print('[APPX H] View Toolkit button tapped');
                        print(
                            '[APPX H] _selectedLearnerId: $_selectedLearnerId');
                        print('[APPX H] _classId: $_classId');

                        Navigator.pop(context); // Close dialog

                        // Validate required data
                        if (_selectedLearnerId == null || _classId == null) {
                          print('[APPX H] ERROR: Missing data');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Missing learner or class information. Please reselect the learner.'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 4),
                            ),
                          );
                          return;
                        }

                        // Navigate to ARPL Toolkit Viewer
                        try {
                          final int learnerId = int.parse(_selectedLearnerId!);
                          final int classId = int.parse(_classId!);

                          print(
                              '[APPX H] Navigating with learnerID: $learnerId, classID: $classId');

                          if (_ofoNumber == null || _ofoNumber!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Error: OFO number not set. Cannot proceed.')),
                            );
                          } else if (_ofoNumber != null &&
                              _ofoNumber!.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ArplToolkitRouter(
                                  learnerID: learnerId,
                                  classID: classId,
                                  ofoNumber: _ofoNumber!,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Error: OFO code not loaded. Please try again.')),
                            );
                          }
                        } catch (e) {
                          print('[APPX H] ERROR: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error opening toolkit: $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006341),
                      ),
                    ),
                  ],
                );
              },
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${data['message']}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      print('[APPX H] Error saving: $e');
      print('[APPX H] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Save gap analysis unit standards
  Future<void> _saveGapAnalysisUnitStandards(int recommendationId) async {
    try {
      final selectedUS = _unitStandards.where((us) {
        final id = int.parse(us['id'].toString());
        return _selectedUnitStandards.contains(id);
      }).toList();

      final requestBody = {
        'learner_id': int.parse(_selectedLearnerId!),
        'recommendation_id': recommendationId,
        'ofo_code': _ofoNumber ?? '',
        'trade': _getTradeName(_ofoNumber),
        'unit_standards': selectedUS,
      };

      print('[APPX H] Saving gap analysis: ${json.encode(requestBody)}');

      final url = '${AppConfig.baseUrl}/save_gap_analysis_unit_standards.php';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('[APPX H] Gap analysis response: ${response.body}');
    } catch (e) {
      print('[APPX H] Error saving gap analysis: $e');
    }
  }
}

class ARPLAppendixHPage extends StatefulWidget {
  final String facilitatorId;
  final String? ofoNumber;

  const ARPLAppendixHPage({
    super.key,
    required this.facilitatorId,
    this.ofoNumber,
  });

  @override
  _ARPLAppendixHPageState createState() => _ARPLAppendixHPageState();
}

class _ARPLAppendixHPageState extends State<ARPLAppendixHPage> {
  String? _selectedLearnerId;
  List<dynamic> _learners = [];
  bool _isLoading = true;
  bool _isRecommended = false;
  String? _ofoNumber;

  final SignatureController _learnerSig = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);
  final SignatureController _assessorSig = SignatureController(
      penColor: Colors.black, exportBackgroundColor: Colors.white);

  @override
  void initState() {
    super.initState();
    _ofoNumber = widget.ofoNumber;
    _fetchLearners();
  }

  Future<void> _fetchLearners() async {
    try {
      final db = await DatabaseHelper().database;
      final facilitatorClasses = await db.query(
        'facilitator',
        columns: ['classID'],
        where: 'facilitator_id = ?',
        whereArgs: [widget.facilitatorId],
      );

      Set<String> classIds = {};
      for (var row in facilitatorClasses) {
        String ids = row['classID']?.toString() ?? '';
        if (ids.isNotEmpty) {
          classIds.addAll(ids.split(',').map((e) => e.trim()));
        }
      }

      if (classIds.isNotEmpty) {
        final learnersList = await db.query(
          'learnerdetails',
          where: 'classID IN (${classIds.map((_) => '?').join(',')})',
          whereArgs: classIds.toList(),
        );

        setState(() {
          _learners = learnersList;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching learners: $e');
      setState(() => _isLoading = false);
    }
  }

  // Traceability Data
  String? _projectId;
  String? _siteId;
  String? _classId;

  final TextEditingController _rationaleController = TextEditingController();

  @override
  void dispose() {
    _learnerSig.dispose();
    _assessorSig.dispose();
    _rationaleController.dispose();
    super.dispose();
  }

  Future<void> _fetchTraceabilityData(String learnerId) async {
    try {
      final trace = await DatabaseHelper().getLearnerTraceability(learnerId);
      String? classId = trace['classID'];
      String? siteId = trace['siteID'];
      String? projectId = trace['project_id'];

      if (classId == null || classId.isEmpty) {
        for (final learner in _learners) {
          if (learner['LearnerID'].toString() == learnerId) {
            classId = learner['classID']?.toString();
            break;
          }
        }
      }

      setState(() {
        _classId = classId;
        _siteId = siteId;
        _projectId = projectId;
      });
    } catch (e) {
      print('[ARPL] Error fetching traceability data: $e');
    }
  }

  Future<void> _saveRecommendation() async {
    if (_selectedLearnerId == null) return;

    try {
      if (_classId == null ||
          _siteId == null ||
          _projectId == null ||
          _classId!.isEmpty ||
          _siteId!.isEmpty ||
          _projectId!.isEmpty) {
        await _fetchTraceabilityData(_selectedLearnerId!);
      }
      if (_classId == null ||
          _siteId == null ||
          _projectId == null ||
          _classId!.isEmpty ||
          _siteId!.isEmpty ||
          _projectId!.isEmpty) {
        throw Exception(
            'Missing class/site/project data. Reselect the candidate and try again.');
      }

      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator()));

      // Note: Appendix H currently shares the criteria table's is_recommended field
      final payload = {
        'learner_id': int.parse(_selectedLearnerId!),
        'assessor_id': int.parse(widget.facilitatorId),
        'class_id': int.parse(_classId!),
        'project_id': int.parse(_projectId!),
        'site_id': int.parse(_siteId!),
        'criteria_json': jsonEncode({}), // Empty or existing criteria
        'is_recommended': _isRecommended ? 1 : 0,
        'assessor_confirmation': _isRecommended ? 1 : 0,
        // rationale is currently not in the DB schema, but we can add it to criteria_json if needed
      };

      final response = await http.post(
        Uri.parse(AppConfig.saveArplCriteriaUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      Navigator.pop(context);
      final res = jsonDecode(response.body);

      // Show success dialog with option to view complete toolkit
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text('Recommendation Saved'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(res['message'] ??
                    'Appendix H recommendation saved successfully!'),
                const SizedBox(height: 16),
                const Text(
                  'Would you like to view the complete ARPL toolkit with all saved assessments?',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                },
                child: const Text('Later'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.description),
                label: const Text('View Complete Toolkit'),
                onPressed: () {
                  // Debug logging
                  print('[APPX H] View Toolkit button tapped');
                  print('[APPX H] _selectedLearnerId: $_selectedLearnerId');
                  print('[APPX H] _classId: $_classId');

                  Navigator.pop(context); // Close dialog

                  // Validate required data
                  if (_selectedLearnerId == null || _classId == null) {
                    print('[APPX H] ERROR: Missing data');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Missing learner or class information. Please reselect the learner.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 4),
                      ),
                    );
                    return;
                  }

                  // Navigate to ARPL Toolkit Viewer
                  try {
                    final int learnerId = int.parse(_selectedLearnerId!);
                    final int classId = int.parse(_classId!);

                    print(
                        '[APPX H] Navigating with learnerID: $learnerId, classID: $classId, OFO: $_ofoNumber');

                    if (_ofoNumber == null || _ofoNumber!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Error: OFO code not loaded. Please try again.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArplToolkitRouter(
                          learnerID: learnerId,
                          classID: classId,
                          ofoNumber: _ofoNumber!,
                        ),
                      ),
                    );
                  } catch (e) {
                    print('[APPX H] ERROR: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error opening toolkit: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006341),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLearner = _selectedLearnerId == null
        ? null
        : _learners.any((l) => l['LearnerID'].toString() == _selectedLearnerId)
            ? _learners.firstWhere(
                (l) => l['LearnerID'].toString() == _selectedLearnerId)
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appendix H: Recommendation'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedLearner != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.indigo.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recommending Candidate:',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.indigo)),
                          Text(
                            '${selectedLearner['Name']} ${selectedLearner['Surname']}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo),
                          ),
                          Text('ID: ${selectedLearner['IDNumber']}',
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  const Text(
                    'Select Candidate',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedLearnerId,
                    hint: const Text('Select a learner'),
                    isExpanded: true,
                    items: _learners.map((learner) {
                      return DropdownMenuItem<String>(
                        value: learner['LearnerID'].toString(),
                        child: Text(
                            '${learner['Name']} ${learner['Surname']} (${learner['IDNumber']})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLearnerId = value;
                        if (value != null) {
                          _fetchTraceabilityData(value);
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  if (_selectedLearnerId != null) ...[
                    const SizedBox(height: 24),
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Access Recommendation for External Integrated Summative Assessment (EISA)',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                                'Does the candidate meet the requirements for access to EISA?'),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              title: Text(_isRecommended
                                  ? 'YES - Recommended'
                                  : 'NO - Not Recommended'),
                              value: _isRecommended,
                              onChanged: (value) =>
                                  setState(() => _isRecommended = value),
                              activeColor: Colors.green,
                              inactiveThumbColor: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _rationaleController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Rationale / Supporting Evidence',
                                hintText:
                                    'Provide reasons for your recommendation...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            DualSignaturePad(
                                title: 'Recommendation Signatures',
                                learnerController: _learnerSig,
                                assessorController: _assessorSig),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _saveRecommendation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text(
                                    'Submit Recommendation (Appendix H)'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// REMEDIALS PAGE
// ══════════════════════════════════════════════════════════
class RemedialsPage extends StatefulWidget {
  final String facilitatorId;

  const RemedialsPage({super.key, required this.facilitatorId});

  @override
  _RemedialsPageState createState() => _RemedialsPageState();
}

class _RemedialsPageState extends State<RemedialsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remedials'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Remedials',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage remedial assessment programs for candidates',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            // Coming Soon Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Colors.indigo.withOpacity(0.1),
                      Colors.blue.withOpacity(0.1)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.indigo.withOpacity(0.2),
                      ),
                      child: const Icon(
                        Icons.construction,
                        size: 48,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Remedials Coming Soon',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The remedial assessment management system is currently under development. This feature will allow assessors to manage remedial programs for candidates who need additional support.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Expected: Q3 2026',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Information Cards
            _buildInfoCard(
              title: 'What are Remedials?',
              description:
                  'Remedial assessments provide candidates with an opportunity to demonstrate competence after initial assessment attempts.',
              icon: Icons.info,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'Coming Features',
              description:
                  'Create remedial programs, track progress, and manage remedial assessments for your candidates.',
              icon: Icons.star,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.indigo),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// VIEW COMPLETE TOOLKIT PAGE
// ══════════════════════════════════════════════════════════
class ViewCompleteToolkitPage extends StatefulWidget {
  final String facilitatorId;

  const ViewCompleteToolkitPage({super.key, required this.facilitatorId});

  @override
  _ViewCompleteToolkitPageState createState() =>
      _ViewCompleteToolkitPageState();
}

class _ViewCompleteToolkitPageState extends State<ViewCompleteToolkitPage> {
  String? _selectedLearnerId;
  List<dynamic> _learners = [];
  bool _isLoadingLearners = true;
  String? _selectedClassId;
  String? _selectedOfoNumber;

  @override
  void initState() {
    super.initState();
    _fetchLearners();
  }

  Future<void> _fetchLearners() async {
    try {
      final db = await DatabaseHelper().database;
      final facilitatorClasses = await db.query(
        'facilitator',
        columns: ['classID'],
        where: 'facilitator_id = ?',
        whereArgs: [widget.facilitatorId],
      );

      Set<String> classIds = {};
      for (var row in facilitatorClasses) {
        String ids = row['classID']?.toString() ?? '';
        if (ids.isNotEmpty) {
          classIds.addAll(ids.split(',').map((e) => e.trim()));
        }
      }

      if (classIds.isNotEmpty) {
        final learnersList = await db.query(
          'learnerdetails',
          where: 'classID IN (${classIds.map((_) => '?').join(',')})',
          whereArgs: classIds.toList(),
        );

        setState(() {
          _learners = learnersList;
          _isLoadingLearners = false;
        });
      } else {
        setState(() => _isLoadingLearners = false);
      }
    } catch (e) {
      print('Error fetching learners: $e');
      setState(() => _isLoadingLearners = false);
    }
  }

  Future<String?> _fetchOfoForClass(String classId) async {
    try {
      print('[TOOLKIT_DEBUG] Fetching OFO for classID: $classId');

      // Call dedicated API endpoint for class trade info
      final response = await http.post(
        Uri.parse(
          '${AppConfig.baseUrl}/get_class_trade_info.php',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'classID': int.parse(classId)}),
      );

      print('[TOOLKIT_DEBUG] API Response Code: ${response.statusCode}');
      print('[TOOLKIT_DEBUG] API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success' && data['ofo_number'] != null) {
            final ofo = data['ofo_number'].toString();
            final tradeName = data['trade_name'] ?? 'Unknown';
            print(
                '[TOOLKIT_DEBUG] API returned OFO: $ofo for trade: $tradeName');
            return ofo;
          } else {
            print(
                '[TOOLKIT_DEBUG] API error response: ${data['message'] ?? 'Unknown error'}, throwing exception');
            throw Exception('Failed to get OFO number from API');
          }
        } catch (e) {
          print('[TOOLKIT_DEBUG] JSON decode error: $e, returning null');
          return null;
        }
      } else {
        print(
            '[TOOLKIT_DEBUG] API error: ${response.statusCode}, body: ${response.body}, returning null');
        return null;
      }
    } catch (e) {
      print('[TOOLKIT_DEBUG] Exception fetching OFO: $e, returning null');
      return null;
    }
  }

  void _openToolkit() {
    print('[TOOLKIT_DEBUG] === _openToolkit called ===');
    print('[TOOLKIT_DEBUG] _selectedLearnerId: $_selectedLearnerId');
    print('[TOOLKIT_DEBUG] _selectedClassId: $_selectedClassId');
    print('[TOOLKIT_DEBUG] _selectedOfoNumber: $_selectedOfoNumber');
    print('[TOOLKIT_DEBUG] _learners.length: ${_learners.length}');

    // Ensure all required fields are set
    if (_selectedLearnerId == null || _selectedLearnerId!.isEmpty) {
      print('[TOOLKIT_DEBUG] ERROR: _selectedLearnerId is null or empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a candidate to continue'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    print(
        '[TOOLKIT_DEBUG] _selectedClassId check: $_selectedClassId (isEmpty: ${_selectedClassId?.isEmpty ?? 'null'})');
    if (_selectedClassId == null || _selectedClassId!.isEmpty) {
      print('[TOOLKIT_DEBUG] ERROR: _selectedClassId is null or empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Class not found for this candidate'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // OFO number must be set - error if empty
    final ofoNumber =
        (_selectedOfoNumber == null || _selectedOfoNumber!.isEmpty)
            ? (throw Exception('OFO number not set. Cannot load ARPL toolkit'))
            : _selectedOfoNumber!;
    print('[TOOLKIT_DEBUG] Using OFO number: $ofoNumber');

    // Find the learner by IDNumber to get LearnerID
    print(
        '[TOOLKIT_DEBUG] Searching for learner with IDNumber: $_selectedLearnerId');

    final learner = _learners.firstWhere(
      (l) {
        final idNum = l['IDNumber']?.toString() ?? '';
        return idNum == _selectedLearnerId;
      },
      orElse: () => <String, dynamic>{},
    );

    print(
        '[TOOLKIT_DEBUG] Learner search result: ${learner.isEmpty ? 'NOT FOUND' : 'FOUND'}');

    if (learner.isEmpty) {
      print('[TOOLKIT_DEBUG] ERROR: learner is empty after search');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Candidate record not found'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    print(
        '[TOOLKIT_DEBUG] Found learner: ${learner['Name']} ${learner['Surname']}');
    print('[TOOLKIT_DEBUG] Learner LearnerID: ${learner['LearnerID']}');
    print('[TOOLKIT_DEBUG] Learner IDNumber: ${learner['IDNumber']}');
    print('[TOOLKIT_DEBUG] Learner classID: ${learner['classID']}');

    int learnerId = int.tryParse(learner['LearnerID']?.toString() ?? '0') ?? 0;
    int classId = int.tryParse(_selectedClassId ?? '0') ?? 0;

    print('[TOOLKIT_DEBUG] Parsed learnerId: $learnerId, classId: $classId');

    if (learnerId == 0) {
      print('[TOOLKIT_DEBUG] ERROR: learnerId is 0, cannot proceed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid candidate ID'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (classId == 0) {
      print('[TOOLKIT_DEBUG] ERROR: classId is 0, cannot proceed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid class ID'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    print('[TOOLKIT_DEBUG] All checks passed, navigating to toolkit');
    print(
        '[TOOLKIT_DEBUG] Final parameters: learnerId=$learnerId, classId=$classId, ofoNumber=$ofoNumber');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArplToolkitRouter(
          learnerID: learnerId,
          classID: classId,
          ofoNumber: ofoNumber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedLearner = _selectedLearnerId == null
        ? null
        : _learners.isEmpty
            ? null
            : _learners
                    .any((l) => l['LearnerID'].toString() == _selectedLearnerId)
                ? _learners.firstWhere(
                    (l) => l['LearnerID'].toString() == _selectedLearnerId)
                : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('View Complete Toolkit'),
        backgroundColor: Colors.indigo,
      ),
      body: _isLoadingLearners
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Candidate to View Toolkit',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Candidate:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _selectedLearnerId,
                    hint: const Text('Choose a candidate'),
                    isExpanded: true,
                    items: _learners.map((learner) {
                      final idNumber = learner['IDNumber'] ?? 'Unknown';
                      return DropdownMenuItem<String>(
                        value: learner['IDNumber'].toString(),
                        child: Text(
                            '${learner['Name']} ${learner['Surname']} ($idNumber)'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      print('[TOOLKIT_DEBUG] Dropdown onChanged: value=$value');
                      if (value != null) {
                        // Find learner BEFORE setState
                        final learner = _learners.firstWhere(
                          (l) => l['IDNumber'].toString() == value,
                          orElse: () => <String, dynamic>{},
                        );

                        print(
                            '[TOOLKIT_DEBUG] Found learner in dropdown: ${learner.isNotEmpty}');
                        if (learner.isNotEmpty) {
                          print(
                              '[TOOLKIT_DEBUG] Learner Name: ${learner['Name']} ${learner['Surname']}');
                          print(
                              '[TOOLKIT_DEBUG] Learner classID: ${learner['classID']}');
                          print(
                              '[TOOLKIT_DEBUG] Learner LearnerID: ${learner['LearnerID']}');
                        }

                        if (learner.isNotEmpty) {
                          final classId = learner['classID']?.toString() ?? '';

                          // Fetch OFO from API based on classID
                          _fetchOfoForClass(classId).then((ofo) {
                            setState(() {
                              _selectedLearnerId = value;
                              print(
                                  '[TOOLKIT_DEBUG] Set _selectedLearnerId=$value');
                              _selectedClassId = classId;
                              print(
                                  '[TOOLKIT_DEBUG] Set _selectedClassId=$classId');
                              _selectedOfoNumber =
                                  ofo; // ← FIX: Actually assign the OFO value
                              print(
                                  '[TOOLKIT_DEBUG] Set _selectedOfoNumber=$ofo (actual from class)');
                              if (ofo == null || ofo.isEmpty) {
                                print(
                                    '[TOOLKIT_DEBUG] WARNING: OFO is empty for this class!');
                              }
                            });
                          });
                        } else {
                          print(
                              '[TOOLKIT_DEBUG] ERROR: Learner not found for value=$value');
                          setState(() {
                            _selectedLearnerId = null;
                            _selectedClassId = null;
                            _selectedOfoNumber = null;
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_selectedLearnerId != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.indigo.withOpacity(0.3)),
                      ),
                      child: _learners.isNotEmpty
                          ? (() {
                              final selectedLearner = _learners.firstWhere(
                                (l) =>
                                    l['IDNumber'].toString() ==
                                    _selectedLearnerId,
                                orElse: () => <String, dynamic>{},
                              );
                              if (selectedLearner == null ||
                                  selectedLearner.isEmpty) {
                                return const Text(
                                  'Learner data not found',
                                  style: TextStyle(color: Colors.red),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Candidate: ${selectedLearner['Name'] ?? ''} ${selectedLearner['Surname'] ?? ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'ID Number: ${selectedLearner['IDNumber'] ?? ''}',
                                    style:
                                        const TextStyle(color: Colors.indigo),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Class: ${selectedLearner['classID'] ?? ''}',
                                    style:
                                        const TextStyle(color: Colors.indigo),
                                  ),
                                ],
                              );
                            })()
                          : const Text(
                              'No learner data available',
                              style: TextStyle(color: Colors.red),
                            ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'OFO Number:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _selectedOfoNumber ?? 'Not Set',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _openToolkit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Open Complete Toolkit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ] else if (_selectedLearnerId == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          _learners.isEmpty
                              ? 'No candidates available in your classes'
                              : 'Select a candidate to continue',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
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
