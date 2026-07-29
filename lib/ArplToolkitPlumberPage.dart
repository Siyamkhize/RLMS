import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'models/arpl_toolkit_data.dart';

class ArplToolkitPlumberPage extends StatefulWidget {
  final int learnerID;
  final int classID;
  final String ofoNumber;

  const ArplToolkitPlumberPage({
    Key? key,
    required this.learnerID,
    required this.classID,
    required this.ofoNumber,
  }) : super(key: key);

  @override
  _ArplToolkitPlumberPageState createState() => _ArplToolkitPlumberPageState();
}

class _ArplToolkitPlumberPageState extends State<ArplToolkitPlumberPage>
    with SingleTickerProviderStateMixin {
  ArplToolkitData? _toolkitData;
  bool _isLoading = true;
  String? _errorMessage;
  TabController? _tabController;

  // Form controllers for editable fields
  bool _isEditing = false;
  bool _isSaving = false;

  // Cover page controllers
  final TextEditingController _tradeSpecializationController =
      TextEditingController();

  // Appendix B controllers (for each activity rating)
  final Map<int, int> _appendixBRatings = {};
  final Map<int, TextEditingController> _appendixBComments = {};

  // Appendix D controllers (for yes/no responses)
  final Map<String, String> _appendixDResponses = {};

  // Appendix E controllers
  final Map<int, int> _appendixERatings = {};
  final Map<int, TextEditingController> _appendixEComments = {};

  // Appendix F controllers - Practical section (13 plumbing tasks)
  final List<TextEditingController> _practicalTasks =
      List.generate(13, (_) => TextEditingController());
  final List<TextEditingController> _practicalScores =
      List.generate(13, (_) => TextEditingController());
  final List<TextEditingController> _practicalPercentages =
      List.generate(13, (_) => TextEditingController());

  // Appendix F controllers - Workplace observation (13 activities)
  final List<TextEditingController> _workplaceObservationTechKnowledge =
      List.generate(13, (_) => TextEditingController());
  final List<TextEditingController> _workplaceObservationInterpretation =
      List.generate(13, (_) => TextEditingController());
  final List<TextEditingController> _workplaceObservationTeamWork =
      List.generate(13, (_) => TextEditingController());

  // Appendix F controllers - Sign-off (assessor, candidate, witness)
  final TextEditingController _assessorSignatureDate = TextEditingController();
  final TextEditingController _candidateSignatureDate = TextEditingController();
  final TextEditingController _witnessSignatureDate = TextEditingController();

  // Plumber-specific practical tasks (13 tasks)
  static const List<String> plumberPracticalTasks = [
    'Reading and interpreting plumbing plans, drawings and specifications',
    'Selecting and using appropriate plumbing tools and equipment safely',
    'Preparing and assembling copper pipe components and systems',
    'Preparing and assembling plastic (PVC/HDPE) pipe components and systems',
    'Identifying and managing different water supply systems (cold water, hot water)',
    'Installing and testing sanitation systems (waste and drainage)',
    'Identifying and using appropriate fittings, valves and controls',
    'Installing and testing central heating systems',
    'Identifying and resolving common plumbing defects and failures',
    'Complying with plumbing codes, regulations and environmental requirements',
    'Health, safety and environmental compliance in plumbing work',
    'Quality control and testing in plumbing installations',
    'Customer communication and project completion procedures'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 11, vsync: this);
    _loadToolkitData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _tradeSpecializationController.dispose();
    _appendixBComments.forEach((key, controller) => controller.dispose());
    _appendixEComments.forEach((key, controller) => controller.dispose());

    _practicalTasks.forEach((c) => c.dispose());
    _practicalScores.forEach((c) => c.dispose());
    _practicalPercentages.forEach((c) => c.dispose());

    _workplaceObservationTechKnowledge.forEach((c) => c.dispose());
    _workplaceObservationInterpretation.forEach((c) => c.dispose());
    _workplaceObservationTeamWork.forEach((c) => c.dispose());

    _assessorSignatureDate.dispose();
    _candidateSignatureDate.dispose();
    _witnessSignatureDate.dispose();

    super.dispose();
  }

  Future<void> _loadToolkitData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse(AppConfig.getArplToolkitDataUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learnerID': widget.learnerID,
          'classID': widget.classID,
          'ofoNumber': widget.ofoNumber,
          'trade': 'plumber', // Specify plumber trade
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _toolkitData = ArplToolkitData.fromJson(data);
            _isLoading = false;
            _populateControllers();
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to load toolkit data';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  void _populateControllers() {
    if (_toolkitData == null) return;

    // Populate Appendix B controllers
    for (var rating in _toolkitData!.appendixB) {
      if (rating.hasRating) {
        _appendixBRatings[rating.activityId] = rating.competencyScaleId;
        _appendixBComments[rating.activityId] =
            TextEditingController(text: rating.comments);
      } else {
        _appendixBComments[rating.activityId] = TextEditingController();
      }
    }

    // Populate Appendix D responses
    _appendixDResponses.addAll(_toolkitData!.appendixD);

    // Populate Appendix E controllers
    for (var rating in _toolkitData!.appendixE) {
      if (rating.hasRating) {
        _appendixERatings[rating.activityId] = rating.competencyScaleId;
        _appendixEComments[rating.activityId] =
            TextEditingController(text: rating.comments);
      } else {
        _appendixEComments[rating.activityId] = TextEditingController();
      }
    }

    // Populate Appendix F controllers if data exists
    if (_toolkitData!.appendixF != null) {
      final f = _toolkitData!.appendixF!;

      // Populate practical section (13 plumbing tasks)
      for (int i = 0;
          i < _practicalTasks.length && i < f.practicalTasks.length;
          i++) {
        _practicalTasks[i].text = f.practicalTasks[i].taskName ?? '';
        _practicalScores[i].text = (f.practicalTasks[i].score ?? '').toString();
        _practicalPercentages[i].text =
            (f.practicalTasks[i].percentage ?? '').toString();
      }

      // Populate workplace observations (13 activities)
      for (int i = 0;
          i < _workplaceObservationTechKnowledge.length &&
              i < f.workplaceObservations.length;
          i++) {
        _workplaceObservationTechKnowledge[i].text =
            f.workplaceObservations[i].technicalKnowledge ?? '';
        _workplaceObservationInterpretation[i].text =
            f.workplaceObservations[i].interpretation ?? '';
        _workplaceObservationTeamWork[i].text =
            f.workplaceObservations[i].teamWork ?? '';
      }
    }
  }

  Future<void> _saveToolkitData() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Build practical tasks array
      List<Map<String, dynamic>> practicalTasksData = [];
      for (int i = 0; i < _practicalTasks.length; i++) {
        if (_practicalTasks[i].text.isNotEmpty) {
          practicalTasksData.add({
            'taskNumber': i + 1,
            'taskName': plumberPracticalTasks[i],
            'score': int.tryParse(_practicalScores[i].text) ?? 0,
            'percentage': double.tryParse(_practicalPercentages[i].text) ?? 0.0,
          });
        }
      }

      // Build workplace observations array
      List<Map<String, dynamic>> workplaceObservationsData = [];
      for (int i = 0; i < _workplaceObservationTechKnowledge.length; i++) {
        if (_workplaceObservationTechKnowledge[i].text.isNotEmpty ||
            _workplaceObservationInterpretation[i].text.isNotEmpty ||
            _workplaceObservationTeamWork[i].text.isNotEmpty) {
          workplaceObservationsData.add({
            'observationNumber': i + 1,
            'taskObserved': plumberPracticalTasks[i],
            'technicalKnowledge': _workplaceObservationTechKnowledge[i].text,
            'interpretation': _workplaceObservationInterpretation[i].text,
            'teamWork': _workplaceObservationTeamWork[i].text,
          });
        }
      }

      final learnerName = _toolkitData?.learner?.name ?? 'Assessor';
      final learnerSurname = _toolkitData?.learner?.surname ?? 'Candidate';

      final response = await http.post(
        Uri.parse(AppConfig.getArplSaveToolkitDataUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learnerID': widget.learnerID,
          'ofoNumber': widget.ofoNumber,
          'trade': 'plumber',
          'assessorName': learnerName,
          'candidateName': learnerSurname,
          'witnessName': 'Witness',
          'assessmentDate': DateTime.now().toIso8601String().split('T')[0],
          'authorizedDate': DateTime.now().toIso8601String().split('T')[0],
          'practicalTasks': practicalTasksData,
          'workplaceObservations': workplaceObservationsData,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Toolkit data saved successfully!')),
          );
          setState(() {
            _isEditing = false;
            _isSaving = false;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${data['message']}')),
          );
          setState(() {
            _isSaving = false;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
        setState(() {
          _isSaving = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving data: $e')),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ARPL Toolkit - Plumber')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text('Error: $_errorMessage'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadToolkitData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_toolkitData == null) {
      return const Scaffold(
        body: Center(child: Text('No data available')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ARPL Toolkit - Plumber'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Cover'),
            Tab(text: 'Appendix A'),
            Tab(text: 'Appendix B'),
            Tab(text: 'Appendix C'),
            Tab(text: 'Appendix D'),
            Tab(text: 'Appendix E'),
            Tab(text: 'Appendix F'),
            Tab(text: 'Appendix G'),
            Tab(text: 'Appendix H'),
            Tab(text: 'Appendix I'),
            Tab(text: 'Appendix J'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCoverPage(),
          _buildAppendixA(),
          _buildAppendixB(),
          _buildAppendixC(),
          _buildAppendixD(),
          _buildAppendixE(),
          _buildAppendixF(),
          _buildAppendixG(),
          _buildAppendixH(),
          _buildAppendixI(),
          _buildAppendixJ(),
        ],
      ),
      floatingActionButton: _isEditing
          ? FloatingActionButton(
              onPressed: _isSaving ? null : _saveToolkitData,
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.save),
            )
          : null,
    );
  }

  Widget _buildCoverPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ARPL Toolkit Assessment Form',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Trade: Plumber',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Text('OFO Number: ${widget.ofoNumber}',
              style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 24),
          if (_toolkitData?.learner != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Learner Information',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                    'Name: ${_toolkitData?.learner?.name} ${_toolkitData?.learner?.surname}'),
                Text('ID: ${_toolkitData?.learner?.idNumber}'),
                Text('DOB: ${_toolkitData?.learner?.dateOfBirth}'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAppendixA() =>
      _buildPlaceholder('Appendix A - Application Form');
  Widget _buildAppendixB() =>
      _buildPlaceholder('Appendix B - Theory Assessment');
  Widget _buildAppendixC() =>
      _buildPlaceholder('Appendix C - Trade Curriculum');
  Widget _buildAppendixD() =>
      _buildPlaceholder('Appendix D - Practical Skills');
  Widget _buildAppendixE() =>
      _buildPlaceholder('Appendix E - Workplace Experience');

  Widget _buildAppendixF() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Appendix F - Practical Assessment Evaluation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Text('Practical Tasks (13 Plumbing Tasks)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._buildPracticalTasksList(),
          const SizedBox(height: 32),
          const Text('Workplace Observations',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._buildWorkplaceObservationsList(),
        ],
      ),
    );
  }

  List<Widget> _buildPracticalTasksList() {
    List<Widget> widgets = [];
    for (int i = 0; i < 13; i++) {
      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Task ${i + 1}: ${plumberPracticalTasks[i]}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _practicalScores[i],
                        decoration: const InputDecoration(
                          labelText: 'Score',
                          hintText: '0-100',
                          border: OutlineInputBorder(),
                        ),
                        enabled: _isEditing,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _practicalPercentages[i],
                        decoration: const InputDecoration(
                          labelText: 'Percentage',
                          hintText: '0-100%',
                          border: OutlineInputBorder(),
                        ),
                        enabled: _isEditing,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildWorkplaceObservationsList() {
    List<Widget> widgets = [];
    for (int i = 0; i < 13; i++) {
      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Observation ${i + 1}: ${plumberPracticalTasks[i]}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _workplaceObservationTechKnowledge[i],
                  decoration: const InputDecoration(
                    labelText: 'Technical Knowledge',
                    border: OutlineInputBorder(),
                  ),
                  enabled: _isEditing,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _workplaceObservationInterpretation[i],
                  decoration: const InputDecoration(
                    labelText: 'Interpretation',
                    border: OutlineInputBorder(),
                  ),
                  enabled: _isEditing,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _workplaceObservationTeamWork[i],
                  decoration: const InputDecoration(
                    labelText: 'Team Work',
                    border: OutlineInputBorder(),
                  ),
                  enabled: _isEditing,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildAppendixG() => _buildPlaceholder('Appendix G - Appeals Form');
  Widget _buildAppendixH() =>
      _buildPlaceholder('Appendix H - Access Recommendation');
  Widget _buildAppendixI() =>
      _buildPlaceholder('Appendix I - Statement of Results');
  Widget _buildAppendixJ() =>
      _buildPlaceholder('Appendix J - Pre-Assessment Agreement');

  Widget _buildPlaceholder(String title) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.file_present, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Detailed implementation coming soon',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
