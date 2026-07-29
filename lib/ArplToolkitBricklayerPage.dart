import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'models/arpl_toolkit_data.dart';

class ArplToolkitBricklayerPage extends StatefulWidget {
  final int learnerID;
  final int classID;
  final String ofoNumber;

  const ArplToolkitBricklayerPage({
    Key? key,
    required this.learnerID,
    required this.classID,
    this.ofoNumber = '641201',
  }) : super(key: key);

  @override
  _ArplToolkitBricklayerPageState createState() =>
      _ArplToolkitBricklayerPageState();
}

class _ArplToolkitBricklayerPageState extends State<ArplToolkitBricklayerPage>
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

  // Appendix D controllers - for editable text inputs
  final Map<String, TextEditingController> _appendixDInputs = {};

  // Appendix F controllers - Practical section (13 bricklaying tasks)
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

  // Appendix H - Gap Closure Controllers
  final Map<int, String> _appendixHStatus = {};
  final Map<int, TextEditingController> _appendixHRemarks = {};
  bool _showGapClosureSelection = false;
  final Set<String> _selectedGapUnitStandards = {};
  bool _gapStandardsLoading = false;
  List<Map<String, dynamic>> _availableGapUnitStandards = [];

  // Bricklayer-specific practical tasks (13 tasks)
  static const List<String> bricklayerPracticalTasks = [
    'Reading and interpreting architectural drawings and specifications',
    'Setting out brickwork with appropriate measuring and marking tools',
    'Preparing and mixing mortar to required consistency',
    'Building cavity walls and demonstrating knowledge of cavity tie placement',
    'Building solid walls with proper bonding patterns',
    'Constructing arches and openings',
    'Pointing and jointing brickwork to specifications',
    'Building in lintels, wall plates, and other components',
    'Constructing brick piers and chimney stacks',
    'Building curved brickwork and special features',
    'Applying protective treatments and finishes',
    'Health, safety, and environmental compliance in brickwork',
    'Quality control and defect rectification in brickwork'
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
        Uri.parse(AppConfig.getBricklayerToolkitDataUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learnerID': widget.learnerID,
          'classID': widget.classID,
        }),
      );

      print('[BRICKLAYER_TRACE] API Response Status: ${response.statusCode}');
      print(
          '[BRICKLAYER_TRACE] API Response Length: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[BRICKLAYER_TRACE] ═══ RAW API RESPONSE ═══');
        print('[BRICKLAYER_TRACE] ${response.body}');
        print('[BRICKLAYER_TRACE] ═══ END RAW RESPONSE ═══');

        if (data['status'] == 'success') {
          try {
            print('[BRICKLAYER_TRACE] ═══ TYPE CHECKING ═══');
            print(
                '[BRICKLAYER_TRACE] appendixA type: ${data['appendixA'].runtimeType}');
            print(
                '[BRICKLAYER_TRACE] appendixB type: ${data['appendixB'].runtimeType}, is List: ${data['appendixB'] is List}');
            print(
                '[BRICKLAYER_TRACE] appendixC type: ${data['appendixC'].runtimeType}');
            print(
                '[BRICKLAYER_TRACE] appendixD type: ${data['appendixD'].runtimeType}');
            print(
                '[BRICKLAYER_TRACE] appendixE type: ${data['appendixE'].runtimeType}, is List: ${data['appendixE'] is List}');
            print(
                '[BRICKLAYER_TRACE] appendixF type: ${data['appendixF'].runtimeType}');
            print(
                '[BRICKLAYER_TRACE] appendixG type: ${data['appendixG'].runtimeType}');
            print(
                '[BRICKLAYER_TRACE] appendixH type: ${data['appendixH'].runtimeType}');
            if (data['appendixH'] != null) {
              print(
                  '[BRICKLAYER_TRACE] appendixH.items type: ${data['appendixH']['items'].runtimeType}');
              print(
                  '[BRICKLAYER_TRACE] appendixH.recommendations type: ${data['appendixH']['recommendations'].runtimeType}');
              print(
                  '[BRICKLAYER_TRACE] appendixH.gap_standards type: ${data['appendixH']['gap_standards'].runtimeType}');
            }
            print('[BRICKLAYER_TRACE] ═══ END TYPE CHECKING ═══');

            print('[BRICKLAYER_TRACE] Attempting to parse ArplToolkitData...');
            _toolkitData = ArplToolkitData.fromJson(data);
            print('[BRICKLAYER_TRACE] ✅ ArplToolkitData parsed successfully');

            setState(() {
              _isLoading = false;
              _populateControllers();
            });
          } catch (parseError, stackTrace) {
            print('[BRICKLAYER_ERROR] ═══ PARSE ERROR ═══');
            print('[BRICKLAYER_ERROR] Error: $parseError');
            print('[BRICKLAYER_ERROR] Stack Trace:');
            print(stackTrace);
            print('[BRICKLAYER_ERROR] ═══ END PARSE ERROR ═══');

            setState(() {
              _errorMessage =
                  'Error parsing data: $parseError\n\nStack trace:\n$stackTrace';
              _isLoading = false;
            });
          }
        } else {
          print(
              '[BRICKLAYER_ERROR] API returned non-success status: ${data['message']}');
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to load toolkit data';
            _isLoading = false;
          });
        }
      } else {
        print(
            '[BRICKLAYER_ERROR] Server returned status ${response.statusCode}');
        print('[BRICKLAYER_ERROR] Response: ${response.body}');
        setState(() {
          _errorMessage =
              'Server error: ${response.statusCode}\n${response.body}';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('[BRICKLAYER_ERROR] ═══ NETWORK ERROR ═══');
      print('[BRICKLAYER_ERROR] Error: $e');
      print('[BRICKLAYER_ERROR] Stack Trace:');
      print(stackTrace);
      print('[BRICKLAYER_ERROR] ═══ END NETWORK ERROR ═══');

      setState(() {
        _errorMessage = 'Error loading data: $e\n\nStack trace:\n$stackTrace';
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

    // Populate Appendix E controllers - ENSURE ALL ARE INITIALIZED
    for (var rating in _toolkitData!.appendixE) {
      if (rating.hasRating) {
        _appendixERatings[rating.activityId] = rating.competencyScaleId;
        _appendixEComments[rating.activityId] =
            TextEditingController(text: rating.comments);
      } else {
        // IMPORTANT: Always create a controller, even if no rating yet
        _appendixEComments[rating.activityId] = TextEditingController();
      }
    }

    // Populate Appendix F controllers if data exists
    if (_toolkitData!.appendixF != null) {
      final f = _toolkitData!.appendixF!;

      // Populate practical section (13 bricklaying tasks)
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
            'taskName': bricklayerPracticalTasks[i],
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
            'taskObserved': bricklayerPracticalTasks[i],
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
          'trade': 'bricklayer',
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
          // Now save gap closure data if applicable
          await _saveGapClosureData();

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

  Future<void> _saveGapClosureData() async {
    try {
      // Build recommendations array
      List<Map<String, dynamic>> recommendationsData = [];

      // Get existing recommendations and add updated status/remarks
      for (var rec in _toolkitData!.appendixH.recommendations) {
        recommendationsData.add({
          'acrid': rec.acrId,
          'status': _appendixHStatus[rec.acrId] ?? rec.status ?? '',
          'remarks': _appendixHRemarks[rec.acrId]?.text ?? '',
        });
      }

      final response = await http.post(
        Uri.parse(AppConfig.saveBricklayerGapClosureUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learnerID': widget.learnerID,
          'recommendations': recommendationsData,
          'selected_unit_standards': _selectedGapUnitStandards.toList(),
          'ofo_code': '641201',
          'trade': 'bricklayer',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          print('[BRICKLAYER] Gap closure data saved successfully');
        } else {
          print('[BRICKLAYER] Gap closure save error: ${data['message']}');
        }
      } else {
        print('[BRICKLAYER] Gap closure save failed: ${response.statusCode}');
      }
    } catch (e) {
      print('[BRICKLAYER] Gap closure save exception: $e');
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
        appBar: AppBar(title: const Text('ARPL Toolkit - Bricklayer')),
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
        title: const Text('ARPL Toolkit - Bricklayer'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Edit',
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                });
              },
              tooltip: 'Cancel',
            ),
        ],
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
          const Text('Trade: Bricklayer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const Text('OFO Number: 641201',
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
  Widget _buildAppendixD() {
    final appendixD = _toolkitData!.appendixD;
    final tradeName = _getTradeName(widget.ofoNumber);

    // Bricklayer-specific practical criteria
    final practicalCriteria = [
      'Safety',
      'Hand, power and workshop tools',
      'Measuring equipment',
      'Plans and drawings',
      'Identification of brick and mortar',
      'Sanitary ware',
      'Transportation, handling and storage of materials',
      'Access equipment',
      'Scaffolding',
      'Arches',
      'Below ground drainage system',
      'Damp proof courses',
      'Building works',
      'Cavity wall construction',
      'Solid wall construction',
      'Walls and piers',
      'Installation of components',
      'Jointing and pointing',
      'Bonding patterns',
      'Brick types and quality',
      'Health and safety',
      'Environmental awareness',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Appendix D: PRACTICAL SKILLS ASSESSMENT',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006341),
                  ),
                ),
              ),
              if (_isEditing)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '✏️ EDIT MODE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Competency Scale: Yes | No | Not Applicable',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          _buildTradeTitleBanner(tradeName),
          const SizedBox(height: 16),
          // Always show input fields - users can fill them even if no data exists
          ...practicalCriteria.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final criterion = entry.value;
            final activityKey = 'activity_$index';
            final response = _appendixDResponses[activityKey] ??
                (appendixD[activityKey] ?? '');
            return _buildEditablePracticalCriteriaCard(
                activityKey, criterion, response);
          }),
        ],
      ),
    );
  }

  Widget _buildEditablePracticalCriteriaCard(
      String activityKey, String criteria, String currentResponse) {
    final bool hasResponse = currentResponse.isNotEmpty;
    final bool isYes = currentResponse.toLowerCase() == 'yes';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              criteria,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            if (_isEditing) ...[
              Row(
                children: ['Yes', 'No', 'Not Applicable'].map((option) {
                  final isSelected = currentResponse == option;
                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _appendixDResponses[activityKey] = option;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF006341)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          option,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: hasResponse
                      ? (isYes ? Colors.green[50] : Colors.red[50])
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  currentResponse.isEmpty ? 'Not answered' : currentResponse,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: hasResponse
                        ? (isYes ? Colors.green[700] : Colors.red[700])
                        : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditableRatingCard(
    int activityId,
    String activity,
    int currentRating,
    TextEditingController? commentController,
    String appendixType,
  ) {
    // Ensure we have a controller - create one if null
    final finalController = commentController ?? TextEditingController();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activity,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            // Rating selection
            if (_isEditing) ...[
              const Text('Rating:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (index) {
                  final ratingNum = index + 1;
                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (appendixType == 'B') {
                            _appendixBRatings[activityId] = ratingNum;
                          } else if (appendixType == 'E') {
                            _appendixERatings[activityId] = ratingNum;
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: currentRating == ratingNum
                              ? const Color(0xFF006341)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ratingNum.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: currentRating == ratingNum
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: finalController,
                decoration: const InputDecoration(
                  labelText: 'Comments',
                  border: OutlineInputBorder(),
                  hintText: 'Add any comments or observations...',
                ),
                maxLines: 2,
              ),
            ] else ...[
              // View mode - show rating
              Row(
                children: [
                  const Text('Rating: '),
                  ...List.generate(5, (index) {
                    final ratingNum = index + 1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        ratingNum == currentRating ? '✓' : '○',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ratingNum == currentRating
                              ? const Color(0xFF006341)
                              : Colors.grey[400],
                        ),
                      ),
                    );
                  }),
                  Text(
                    '($currentRating/5)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006341),
                    ),
                  ),
                ],
              ),
              if (finalController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  finalController.text,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF006341),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppendixE() {
    final appendixE = _toolkitData!.appendixE;
    final tradeName = _getTradeName(widget.ofoNumber);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Appendix E: WORKPLACE EXPERIENCE EVALUATION',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006341),
                  ),
                ),
              ),
              if (_isEditing)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '✏️ EDIT MODE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Competency Scale: 1=Fundamental | 2=Novice | 3=Intermediate | 4=Advanced | 5=Expert',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          _buildTradeTitleBanner(tradeName),
          const SizedBox(height: 16),
          // Always show activities - users can rate and add comments even if no data exists
          ...appendixE.map((rating) => _buildEditableRatingCard(
                rating.activityId,
                rating.activityName,
                _appendixERatings[rating.activityId] ??
                    rating.competencyScaleId,
                _appendixEComments[rating.activityId],
                'E',
              )),
        ],
      ),
    );
  }

  Widget _buildAppendixF() {
    final tradeName = _getTradeName(widget.ofoNumber);
    final appendixE = _toolkitData?.appendixE ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appendix F: PRACTICAL ASSESSMENT EVALUATION',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF006341),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'ASSESSMENT EVALUATION AGREEMENT (knowledge, practical skills and verifiable workplace)',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildTradeTitleBanner(tradeName),
          const SizedBox(height: 24),

          // ═══ PRACTICAL TASKS SECTION ═══
          const Text(
            'PRACTICAL TASKS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF006341),
            ),
          ),
          const SizedBox(height: 12),
          ..._buildPracticalTasksList(),

          const SizedBox(height: 24),

          // ═══ WORKPLACE OBSERVATIONS SECTION ═══
          const Text(
            'WORKPLACE OBSERVATIONS (detailed)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF006341),
            ),
          ),
          const SizedBox(height: 12),
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
                Text('Task ${i + 1}: ${bricklayerPracticalTasks[i]}',
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
                Text('Observation ${i + 1}: ${bricklayerPracticalTasks[i]}',
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

  Widget _buildAppendixH() {
    if (_toolkitData?.appendixH == null) {
      return _buildPlaceholder('Appendix H - Access Recommendation');
    }

    final appendixH = _toolkitData!.appendixH;
    final items = appendixH.items;
    final recommendations = appendixH.recommendations;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Appendix H: ACCESS RECOMMENDATION FORM',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006341),
                  ),
                ),
              ),
              if (_isEditing)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '✏️ EDIT MODE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Assessment Component Ratings: Not Ready | Recommended | Recommended for Gap Closure',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 24),
          // ACR Items
          ...recommendations.map((rec) {
            final itemName = _getAcrItemName(rec.acrId);
            final currentStatus =
                _appendixHStatus[rec.acrId] ?? rec.status ?? '';
            final isOverallResult = rec.acrId == 4;

            return Column(
              children: [
                _buildAcrItemCard(
                  rec.acrId,
                  itemName,
                  currentStatus,
                  isOverallResult,
                ),
                if (isOverallResult &&
                    currentStatus == 'Recommended for Gap Closure')
                  _buildGapClosureSection(),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAcrItemCard(
      int acrId, String itemName, String currentStatus, bool isOverallResult) {
    final statusOptions = [
      'Not Ready',
      'Recommended',
      'Recommended for Gap Closure'
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    itemName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF006341),
                    ),
                  ),
                ),
                if (isOverallResult)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Overall Result',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isEditing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Status:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: statusOptions.map((option) {
                      final isSelected = currentStatus == option;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _appendixHStatus[acrId] = option;
                            if (isOverallResult &&
                                option != 'Recommended for Gap Closure') {
                              _showGapClosureSelection = false;
                            } else if (isOverallResult &&
                                option == 'Recommended for Gap Closure') {
                              _showGapClosureSelection = true;
                              _loadGapUnitStandards();
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF006341)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            option,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _appendixHRemarks.putIfAbsent(
                        acrId, () => TextEditingController()),
                    decoration: const InputDecoration(
                      labelText: 'Remarks',
                      border: OutlineInputBorder(),
                      hintText: 'Add any remarks or observations...',
                    ),
                    maxLines: 2,
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(currentStatus),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      currentStatus.isEmpty ? 'Not Answered' : currentStatus,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if ((_appendixHRemarks[acrId]?.text ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _appendixHRemarks[acrId]?.text ?? '',
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF006341),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGapClosureSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gap Closure: Select Unit Standards',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_gapStandardsLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (_availableGapUnitStandards.isEmpty)
              const Text('No unit standards available')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Unit Standards (${_availableGapUnitStandards.length}):',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._availableGapUnitStandards.map((standard) {
                    final unitId = standard['unit_standard_id'] ?? '';
                    final unitName = standard['unit_standard_name'] ?? '';
                    final isSelected =
                        _selectedGapUnitStandards.contains(unitId);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: _isEditing
                          ? (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedGapUnitStandards.add(unitId);
                                } else {
                                  _selectedGapUnitStandards.remove(unitId);
                                }
                              });
                            }
                          : null,
                      title: Text(
                        unitName,
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                        unitId,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                  if (_selectedGapUnitStandards.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Selected: ${_selectedGapUnitStandards.length} unit standards',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006341),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadGapUnitStandards() async {
    setState(() {
      _gapStandardsLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(AppConfig.getBricklayerGapUnitStandardsUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learnerID': widget.learnerID,
          'qualification_id': 65409,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _availableGapUnitStandards =
                List<Map<String, dynamic>>.from(data['unit_standards'] ?? []);
            final selected = data['selected_unit_standards'] ?? [];
            _selectedGapUnitStandards.clear();
            _selectedGapUnitStandards.addAll(
              List<String>.from(selected),
            );
            _gapStandardsLoading = false;
          });
        }
      } else {
        setState(() {
          _gapStandardsLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Error loading unit standards: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() {
        _gapStandardsLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading unit standards: $e')),
      );
    }
  }

  String _getAcrItemName(int acrId) {
    switch (acrId) {
      case 1:
        return '1. Foundation Knowledge & Competency';
      case 2:
        return '2. Practical & Workplace Skills';
      case 3:
        return '3. Health, Safety & Environment';
      case 4:
        return '4. Overall Result';
      default:
        return 'Item $acrId';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Not Ready':
        return Colors.red;
      case 'Recommended':
        return Colors.green;
      case 'Recommended for Gap Closure':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

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

  String _getTradeName(String ofoNumber) {
    const tradeMappings = {
      '671101': 'Electrician',
      '642601': 'Plumber',
      '641201': 'Bricklayer',
      '671104': 'Carpenter',
      '671105': 'Welder',
    };
    return tradeMappings[ofoNumber] ?? 'Trade Specialist';
  }

  Widget _buildTradeTitleBanner(String tradeName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF006341),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Trade: $tradeName',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
