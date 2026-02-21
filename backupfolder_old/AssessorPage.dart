import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
import 'PotholeChecklistPage.dart';
import 'database_helper.dart';
import 'config.dart';

class AssessorPage extends StatefulWidget {
  final String facilitator_id;

  const AssessorPage({super.key, required this.facilitator_id});

  @override
  _AssessorPageState createState() => _AssessorPageState();
}

class _AssessorPageState extends State<AssessorPage> {
  late Future<List<dynamic>> _classes;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _classes = fetchClasses(widget.facilitator_id);
  }

  Future<List<dynamic>> fetchClasses(String facilitatorId) async {
    try {
      final url = AppConfig.buildUrl('get_classes.php', queryParams: {
        'facilitator_id': facilitatorId,
      });

      print('[AssessorPage] Fetching classes from: $url');

      final response = await http.get(Uri.parse(url));

      print('[AssessorPage] Response Status: ${response.statusCode}');
      print('[AssessorPage] Response Body: ${response.body}');

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
      case 5: // New case for Assessment Review
        return AssessmentReviewPage(facilitatorId: widget.facilitator_id);
      case 6:
        return AppealFormPage(facilitatorId: widget.facilitator_id); // New case
      case 7:
        return NonComplianceAndFeedbackPage(
            facilitatorId: widget.facilitator_id,
            learnerId:
                'LEARNER_ID'); // Replace 'LEARNER_ID' with actual learner ID
      case 8:
        return PotholeChecklistClassListPage(
          facilitatorId: widget.facilitator_id,
        );
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
                                        ClassDetailsPage(classId: classId),
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
      appBar: AppBar(title: const Text('Assessor Dashboard')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Assessor Menu',
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
              selected: _selectedIndex == 4, // Update the index to 4
              onTap: () {
                _onItemTapped(4); // Update the index to 4
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Assessment Review'), // New menu item
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
                }), // New item
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
          ],
        ),
      ),
      body: _buildContent(),
    );
  }
}

class AssessmentPreparationPage extends StatefulWidget {
  final String facilitatorId;

  const AssessmentPreparationPage({super.key, required this.facilitatorId});

  @override
  _AssessmentPreparationPageState createState() =>
      _AssessmentPreparationPageState();
}

class _AssessmentPreparationPageState extends State<AssessmentPreparationPage> {
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
        title: const Text('Assessment Preparation'),
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
                  child: const Icon(Icons.assessment, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Assessment Preparation',
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
                            'No unit standards found.',
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
                                            UnitStandardDetailPage(
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

  const AssessorReportPage({super.key, required this.facilitatorId});

  @override
  _AssessorReportPageState createState() => _AssessorReportPageState();
}

class _AssessorReportPageState extends State<AssessorReportPage> {
  String _statusMessage = '';
  bool _isGenerating = false;
  String? _pdfPath;

  Future<void> _generateAndDownloadReport() async {
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Generating report...';
      _pdfPath = null; // Reset PDF path
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://rlms.rlms.co.za/mobile/generate_assessor_report.php?facilitator_id=${widget.facilitatorId}'),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print(
          'Response Body (first 100 chars): ${response.body.substring(0, response.body.length < 100 ? response.body.length : 100)}');

      if (response.statusCode == 200) {
        if (response.body.startsWith('No data found')) {
          setState(() {
            _statusMessage =
                'No data found for Facilitator ID: ${widget.facilitatorId}';
            _isGenerating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_statusMessage)),
          );
          return;
        }

        if (response.headers['content-type']?.contains('application/pdf') ==
            true) {
          final dir = await getTemporaryDirectory();
          final file = File(
              '${dir.path}/Facilitator_${widget.facilitatorId}_Learner_Report_${DateTime.now().toString().substring(0, 10)}.pdf');
          await file.writeAsBytes(response.bodyBytes);

          setState(() {
            _statusMessage = 'Report generated successfully!';
            _isGenerating = false;
            _pdfPath = file.path; // Set the PDF path for viewing
          });
        } else {
          setState(() {
            _statusMessage = 'Unexpected response: ${response.body}';
            _isGenerating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_statusMessage)),
          );
        }
      } else {
        setState(() {
          _statusMessage =
              'Failed to generate report. Server error: ${response.statusCode}';
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_statusMessage)),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error generating report: $e';
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_statusMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessor Report'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Facilitator ID: ${widget.facilitatorId}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isGenerating ? null : _generateAndDownloadReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: _isGenerating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Generate Report'),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: TextStyle(
                color: _statusMessage.contains('success')
                    ? Colors.green
                    : Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_pdfPath != null)
              Expanded(
                child: PDFView(
                  filePath: _pdfPath!,
                  enableSwipe: true,
                  swipeHorizontal: true,
                  autoSpacing: true,
                  pageFling: true,
                  onError: (error) {
                    setState(() {
                      _statusMessage = 'Error loading PDF: $error';
                    });
                  },
                  onPageError: (page, error) {
                    setState(() {
                      _statusMessage = 'Error on page $page: $error';
                    });
                  },
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
                                            AssessorMarkingPage(
                                          learnerId: learnerId,
                                          learnerFirstName: firstName,
                                          learnerLastName: lastName,
                                          learnerIdNumber: idNumber,
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
    _poeData = fetchPOE(widget.learnerId);
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

              return Expanded(
                child: ListView(
                  children: [
                    // Build pathway/qualification/unit standard structure
                    ...pathways.entries.map((entry) {
                      return ExpansionTile(
                        title: Text(entry.key,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
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
    return exercises.map((exercise) {
      return ExerciseTile(
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

      final payload = {
        'learnerId': learnerId,
        'exercise': exercise,
        'marksScored': scoredMarks,
        'assessmentType': exercise['type'] ?? 'POE', // Use a valid default
        'specific_outcome': specificOutcomeArray,
        'isUpdate': hasExistingMarks, // Tell backend this is an update
      };
      print(
          "Submitting payload (isUpdate: $hasExistingMarks): ${jsonEncode(payload)}");

      final response = await http.post(
        Uri.parse('https://rlms.rlms.co.za/mobile/save_marks.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);

        String successMessage = 'Marks saved successfully!';
        if (responseData['action'] == 'update') {
          successMessage = 'Marks updated successfully!';
        } else if (responseData['action'] == 'insert') {
          successMessage = 'Marks saved successfully!';
        }

        setState(() {
          _responseMessage = responseData['status'] == 'success'
              ? successMessage
              : 'Failed to save marks: ${responseData['message']}';
          if (responseData['status'] == 'success') {
            exercise['marks_scored'] = marksScored;
            if (responseData['filePath'] != null) {
              exercise['filePath'] = responseData['filePath'];
            }
          }
        });

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

                      final updateResponse = await http.post(
                        Uri.parse(
                            'https://rlms.rlms.co.za/mobile/save_marks.php'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode(updatePayload),
                      );

                      if (updateResponse.statusCode == 200) {
                        var updateData = jsonDecode(updateResponse.body);
                        setState(() {
                          _responseMessage = updateData['status'] == 'success'
                              ? 'Marks updated successfully!'
                              : 'Failed to update marks: ${updateData['message']}';
                          if (updateData['status'] == 'success') {
                            exercise['marks_scored'] = marksScored;
                          }
                        });
                      }
                    },
                    child: const Text('Update Marks'),
                  ),
                ],
              ),
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
  bool showInputField = false;

  @override
  void initState() {
    super.initState();
    marksScored = widget.exercise['marks_scored']?.toString() ?? '';
    controller = TextEditingController(text: marksScored);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exercise['filePath'] == null ||
        widget.exercise['filePath'].isEmpty) {
      return const SizedBox.shrink();
    }

    String maxMarks = widget.exercise['marks']?.toString() ?? '0';
    int maxAllowedMarks = int.tryParse(maxMarks) ?? 0;
    String specificOutcome =
        widget.exercise['specific_outcome']?.toString() ?? 'N/A';
    String specificOutcomeLabel = 'SO: $specificOutcome';
    String displayTitle = marksScored.isNotEmpty
        ? 'Exercise: ${widget.exercise['exercise'] ?? 'N/A'} $marksScored/$maxMarks'
        : 'Exercise: ${widget.exercise['exercise'] ?? 'N/A'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text('$displayTitle ($specificOutcomeLabel)'),
          subtitle: Text('Marks: $maxMarks'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (marksScored.isEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 24),
                  onPressed: () {
                    print('Red X clicked');
                    setState(() {
                      controller.text = '0';
                      showInputField = true;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green, size: 24),
                  onPressed: () {
                    print('Green Tick clicked');
                    setState(() {
                      controller.text = '';
                      showInputField = true;
                    });
                  },
                ),
              ],
              ElevatedButton(
                onPressed: () {
                  String fileUrl = widget.exercise['fileUrl'];
                  if (fileUrl.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PdfViewerScreen(pdfUrl: fileUrl),
                      ),
                    );
                  }
                },
                child: const Text('View File'),
              ),
            ],
          ),
        ),
        if (marksScored.isNotEmpty && !showInputField)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Scored Marks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      showInputField = true;
                    });
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        if (showInputField)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Enter Scored Marks',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    int? enteredMarks = int.tryParse(value);
                    if (enteredMarks != null &&
                        enteredMarks > maxAllowedMarks) {
                      setState(() {
                        controller.text = maxAllowedMarks.toString();
                      });
                    }
                  },
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          String enteredMarks = controller.text;
                          if (enteredMarks.isNotEmpty) {
                            int scoredMarks = int.tryParse(enteredMarks) ?? 0;
                            if (scoredMarks <= maxAllowedMarks) {
                              setState(() {
                                marksScored = enteredMarks;
                                showInputField = false;
                              });
                              await widget.onSubmitMarks(
                                learnerId: widget.learnerId,
                                exercise: widget.exercise,
                                marksScored: enteredMarks,
                                specificOutcome: specificOutcome,
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please enter a valid mark')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: marksScored.isNotEmpty
                              ? Colors.orange
                              : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child:
                            Text(marksScored.isNotEmpty ? 'Update' : 'Submit'),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          controller.text =
                              marksScored; // Reset to original value
                          showInputField = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
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
    _downloadAndSavePdf();
  }

  Future<void> _downloadAndSavePdf() async {
    try {
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/temp.pdf');
        await file.writeAsBytes(response.bodyBytes);
        setState(() {
          _localPath = file.path;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to download PDF';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error downloading PDF: $e';
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

  const AssessmentReviewPage({super.key, required this.facilitatorId});

  @override
  _AssessmentReviewPageState createState() => _AssessmentReviewPageState();
}

class _AssessmentReviewPageState extends State<AssessmentReviewPage> {
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
        title: const Text('Assessment Review'),
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
                            'No unit standards found.',
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
                                            AssessmentReviewDetailPage(
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
      final scannedDoc = await docScanner.getScanDocuments();

      if (scannedDoc != null) {
        // Prepare permanent storage location BEFORE processing
        final appDir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'pothole_checklist_${learnerId}_$timestamp.pdf';
        final permanentPath = '${appDir.path}/$fileName';

        // Extract path from scanner result
        String? scannedPath;
        if (scannedDoc is String) {
          scannedPath = scannedDoc;
        } else if (scannedDoc is List && scannedDoc.isNotEmpty) {
          scannedPath = scannedDoc.first.toString();
        } else if (scannedDoc is Map) {
          scannedPath = scannedDoc['path']?.toString() ??
              scannedDoc['scannedPath']?.toString() ??
              scannedDoc.values.first?.toString();
        }

        if (scannedPath != null && scannedPath.isNotEmpty) {
          // Remove file:// prefix if present
          if (scannedPath.startsWith('file://')) {
            scannedPath = scannedPath.substring(7);
          }

          try {
            // CRITICAL: Read file SYNCHRONOUSLY and IMMEDIATELY
            final sourceFile = File(scannedPath);

            // Use synchronous read to get bytes before file is deleted
            Uint8List? bytes;
            try {
              bytes = sourceFile.readAsBytesSync();
            } catch (e) {
              // If sync fails, try async immediately
              if (await sourceFile.exists()) {
                bytes = await sourceFile.readAsBytes();
              }
            }

            if (bytes != null && bytes.isNotEmpty) {
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
          _showError(context, 'No valid path from scanner');
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
                                                if (outcomeText.isEmpty)
                                                  return const SizedBox
                                                      .shrink();

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
                                // Use correct domain for images
                                final imageUrl =
                                    'https://rlms.rlms.co.za/mobile/${image['file_path']}';

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
                                                    const EdgeInsets.all(8.0),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Image ${index + 1}',
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                    IconButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      icon: const Icon(
                                                          Icons.close,
                                                          color: Colors.white),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Zoomable image
                                              Expanded(
                                                child: InteractiveViewer(
                                                  panEnabled: true,
                                                  boundaryMargin:
                                                      const EdgeInsets.all(20),
                                                  minScale: 0.5,
                                                  maxScale: 4.0,
                                                  child: Center(
                                                    child: Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.contain,
                                                      loadingBuilder: (context,
                                                          child,
                                                          loadingProgress) {
                                                        if (loadingProgress ==
                                                            null) return child;
                                                        return const Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                                  color: Colors
                                                                      .white),
                                                        );
                                                      },
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                        return const Center(
                                                          child: Icon(
                                                              Icons
                                                                  .broken_image,
                                                              size: 50,
                                                              color:
                                                                  Colors.white),
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
                                                  padding: const EdgeInsets.all(
                                                      12.0),
                                                  child: Text(
                                                    image['description'] ?? '',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              // Instructions
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: const Text(
                                                  'Pinch to zoom • Drag to pan • Tap close to exit',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey),
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
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Center(
                                                child: Icon(Icons.broken_image,
                                                    size: 50,
                                                    color: Colors.grey),
                                              );
                                            },
                                            loadingBuilder: (context, child,
                                                loadingProgress) {
                                              if (loadingProgress == null)
                                                return child;
                                              return const Center(
                                                  child:
                                                      CircularProgressIndicator());
                                            },
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Text(
                                            'Image ${index + 1}',
                                            style:
                                                const TextStyle(fontSize: 10),
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
                                // Use correct domain for images
                                final imageUrl =
                                    'https://rlms.rlms.co.za/mobile/${image['file_path']}';

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
                                                    const EdgeInsets.all(8.0),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Image ${index + 1}',
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                    IconButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      icon: const Icon(
                                                          Icons.close,
                                                          color: Colors.white),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Zoomable image
                                              Expanded(
                                                child: InteractiveViewer(
                                                  panEnabled: true,
                                                  boundaryMargin:
                                                      const EdgeInsets.all(20),
                                                  minScale: 0.5,
                                                  maxScale: 4.0,
                                                  child: Center(
                                                    child: Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.contain,
                                                      loadingBuilder: (context,
                                                          child,
                                                          loadingProgress) {
                                                        if (loadingProgress ==
                                                            null) return child;
                                                        return const Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                                  color: Colors
                                                                      .white),
                                                        );
                                                      },
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                        return const Center(
                                                          child: Icon(
                                                              Icons
                                                                  .broken_image,
                                                              size: 50,
                                                              color:
                                                                  Colors.white),
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
                                                  padding: const EdgeInsets.all(
                                                      12.0),
                                                  child: Text(
                                                    image['description'] ?? '',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              // Instructions
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: const Text(
                                                  'Pinch to zoom • Drag to pan • Tap close to exit',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey),
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
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Center(
                                                child: Icon(Icons.broken_image,
                                                    size: 50,
                                                    color: Colors.grey),
                                              );
                                            },
                                            loadingBuilder: (context, child,
                                                loadingProgress) {
                                              if (loadingProgress == null)
                                                return child;
                                              return const Center(
                                                  child:
                                                      CircularProgressIndicator());
                                            },
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Text(
                                            'Image ${index + 1}',
                                            style:
                                                const TextStyle(fontSize: 10),
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
                                                if (outcomeText.isEmpty)
                                                  return const SizedBox
                                                      .shrink();

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
