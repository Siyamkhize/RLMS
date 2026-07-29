import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'PotholeChecklistPage.dart';
import 'database_helper.dart';
import 'utils/scanner_pdf_resolver.dart';

// arl: ARPL Assessor Marking Page
class ArplAssessorMarkingPage extends StatelessWidget {
  final String learnerId;
  final String? learnerFirstName;
  final String? learnerLastName;
  final String? learnerIdNumber;
  final String? facilitatorId; // used to auto-populate assessor
  final String? classId; // used to auto-populate venue

  const ArplAssessorMarkingPage({
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
            ArplLearnerInformationTab(learnerId: learnerId),
            ArplPOETab(learnerId: learnerId),
          ],
        ),
      ),
    );
  }
}

// arl: ARPL Learner Information Tab
class ArplLearnerInformationTab extends StatelessWidget {
  final String learnerId;

  const ArplLearnerInformationTab({super.key, required this.learnerId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'ARPL Learner Information for ID: $learnerId',
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}

// arl: ARPL Pothole Checklist Tab
class ArplPotholeChecklistTab extends StatefulWidget {
  final String learnerId;
  final String? learnerFirstName;
  final String? learnerLastName;
  final String? learnerIdNumber;
  final String? facilitatorId;
  final String? classId;

  const ArplPotholeChecklistTab({
    super.key,
    required this.learnerId,
    this.learnerFirstName,
    this.learnerLastName,
    this.learnerIdNumber,
    this.facilitatorId,
    this.classId,
  });

  @override
  State<ArplPotholeChecklistTab> createState() =>
      _ArplPotholeChecklistTabState();
}

class _ArplPotholeChecklistTabState extends State<ArplPotholeChecklistTab> {
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

// arl: ARPL POE Tab
class ArplPOETab extends StatefulWidget {
  final String learnerId;

  const ArplPOETab({super.key, required this.learnerId});

  @override
  _ArplPOETabState createState() => _ArplPOETabState();
}

class _ArplPOETabState extends State<ArplPOETab> {
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

      print('[ArplPOETab] Fetching POE from: $url');
      final response = await http.get(Uri.parse(url));

      print('[ArplPOETab] POE Response Status: ${response.statusCode}');
      print('[ArplPOETab] POE Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to load POE data. Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('[ArplPOETab] Error fetching POE: $e');
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
                        child: Text('Submit marks first before adding comments',
                            style: TextStyle(color: Colors.orange)),
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
                    ? () {
                        // Placeholder: In future, submit to backend
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Comment captured (not saved).')),
                        );
                      }
                    : null,
                child: const Text('Save Comment'),
              ),
            ),
          ],
        ),
      );
    }

    // Formative Remedial Assessments
    if (formativeRemedial.isNotEmpty) {
      assessmentTiles.add(
        ExpansionTile(
          title: const Text('Formative Remedial'),
          children: [
            ..._buildExerciseTiles(formativeRemedial),
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
                        child: Text('Submit marks first before adding comments',
                            style: TextStyle(color: Colors.orange)),
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
                    ? () {
                        // Placeholder: In future, submit to backend
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Comment captured (not saved).')),
                        );
                      }
                    : null,
                child: const Text('Save Comment'),
              ),
            ),
          ],
        ),
      );
    }

    // Summative Remedial Assessments
    if (summativeRemedial.isNotEmpty) {
      assessmentTiles.add(
        ExpansionTile(
          title: const Text('Summative Remedial'),
          children: [
            ..._buildExerciseTiles(summativeRemedial),
          ],
        ),
      );
    }

    return assessmentTiles;
  }

  List<Widget> _buildExerciseTiles(List<dynamic> exercises) {
    return exercises.map((exercise) {
      final exerciseName = exercise['exercise'] ??
          exercise['exercise_name'] ??
          'Unknown Exercise';
      final marksScored = exercise['marks_scored'];
      final filePath = exercise['filePath'];
      final aComment = exercise['a_comment'] ?? '';
      final comment = exercise['comment'] ?? '';
      final approvalStatus = exercise['approval_status'] ?? '';
      final moderatorStatus = exercise['moderator_status'] ?? '';

      return ExpansionTile(
        title: Text(exerciseName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (marksScored != null &&
                marksScored.toString().isNotEmpty &&
                marksScored.toString() != '0')
              Text('Marks: $marksScored'),
            if (filePath != null && filePath.toString().isNotEmpty)
              const Text('POE File Attached'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (filePath != null && filePath.toString().isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.file_present),
                    title: Text('View File'),
                    onTap: () async {
                      // Placeholder: In future, view file
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('File view not implemented yet.')),
                      );
                    },
                  ),
                const SizedBox(height: 8),
                Text('Marks: $marksScored',
                    style: const TextStyle(fontSize: 16)),
                if (aComment.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Assessor Comment: $aComment',
                        style: const TextStyle(color: Colors.grey)),
                  ),
                if (comment.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Comment: $comment',
                        style: const TextStyle(color: Colors.grey)),
                  ),
                if (approvalStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Approval Status: $approvalStatus',
                        style: const TextStyle(color: Colors.grey)),
                  ),
                if (moderatorStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Moderator Status: $moderatorStatus',
                        style: const TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildLogBookSection(Map<String, dynamic> poeData) {
    // Placeholder: Logbook section implementation
    return const ExpansionTile(
      title: Text('Logbook'),
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Logbook section coming soon!'),
        ),
      ],
    );
  }

  Widget _buildPotholeChecklistMainSection() {
    return const ExpansionTile(
      title: Text('Pothole Checklist'),
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Pothole checklist section coming soon!'),
        ),
      ],
    );
  }
}
