import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'models/arpl_toolkit_data.dart';
import 'services/fingerprint_service.dart';
import 'services/futronic_service.dart' as futronic;
import 'database_helper.dart';
import 'AppendixFRedesigned.dart';

class ArplToolkitViewerPage extends StatefulWidget {
  final int learnerID;
  final int classID;
  final String ofoNumber;

  const ArplToolkitViewerPage({
    Key? key,
    required this.learnerID,
    required this.classID,
    required this.ofoNumber,
  }) : super(key: key);

  @override
  _ArplToolkitViewerPageState createState() => _ArplToolkitViewerPageState();
}

class _ArplToolkitViewerPageState extends State<ArplToolkitViewerPage>
    with SingleTickerProviderStateMixin {
  ArplToolkitData? _toolkitData;
  bool _isLoading = true;
  String? _errorMessage;
  TabController? _tabController;

  // Form controllers for editable fields
  bool _isEditing = false;
  bool _isSaving = false;

  // Cover page controllers (example - expand as needed)
  final TextEditingController _tradeSpecializationController =
      TextEditingController();

  // Appendix A - Employment controllers
  final TextEditingController _currentEmployerController =
      TextEditingController();
  final TextEditingController _positionJobTitleController =
      TextEditingController();
  final TextEditingController _employerAddressController =
      TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _employerTelController = TextEditingController();
  final TextEditingController _employerFaxController = TextEditingController();
  final TextEditingController _employerCellController = TextEditingController();
  final TextEditingController _employerEmailController =
      TextEditingController();

  // Employment History (3 entries)
  final List<TextEditingController> _employmentHistoryCompanyControllers =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _employmentHistoryPositionControllers =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _employmentHistoryPeriodControllers =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _employmentHistoryContactControllers =
      List.generate(3, (_) => TextEditingController());

  // Appendix B controllers (for each activity rating)
  final Map<int, int> _appendixBRatings = {};
  final Map<int, TextEditingController> _appendixBComments = {};

  // Appendix D controllers (for yes/no responses)
  final Map<String, String> _appendixDResponses = {};

  // Appendix E controllers
  final Map<int, int> _appendixERatings = {};
  final Map<int, TextEditingController> _appendixEComments = {};

  // Appendix F - NEW Redesigned (3 sections)
  List<AppendixFKnowledgeQuestion> _knowledgeQuestions = [];
  List<AppendixFPracticalTask> _practicalTasks = [];
  List<AppendixFWorkplaceObservation> _workplaceObservations = [];
  bool _isLoadingAppendixF = false;

  // Fingerprint signature verification
  final FingerprintService _fingerprintService = FingerprintService();
  final futronic.FutronicService _futronicService = futronic.FutronicService();
  bool _isVerifyingFingerprint = false;
  String? _candidateSignature;
  String? _candidateSignatureName;
  final TextEditingController _candidateSignatureController =
      TextEditingController();
  final TextEditingController _candidateDateController = TextEditingController(
    text: DateTime.now().toString().substring(0, 10),
  );

  // Appendix H - Gap Closure State
  final Map<int, String> _appendixHStatus = {}; // ACRID -> Status
  final Map<int, TextEditingController> _appendixHRemarks =
      {}; // ACRID -> Remarks controller
  final Map<int, TextEditingController> _appendixHMarks =
      {}; // ACRID -> Marks/Score controller
  bool _showGapClosureUI = false;
  bool _isLoadingGapStandards = false;
  List<Map<String, dynamic>> _availableUnitStandards = [];
  Set<String> _selectedUnitStandardIds = {};
  String _detectedTrade = ''; // Populated from system OFO number, not hardcoded
  Map<String, dynamic> _tradeConfig = {};

  // Appendix H - Assessor Signature Section
  String? _assessorSignature;
  String? _assessorSignatureName;
  final TextEditingController _assessorSignatureController =
      TextEditingController();
  final TextEditingController _assessorDateController = TextEditingController(
    text: DateTime.now().toString().substring(0, 10),
  );

  @override
  void initState() {
    super.initState();
    // Derive trade from system OFO number passed via widget (not hardcoded)
    _detectedTrade = _detectTradeFromOfo(widget.ofoNumber);
    _tradeConfig = _getTradeConfig(_detectedTrade);
    _tabController = TabController(length: 11, vsync: this);
    _loadToolkitData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _tradeSpecializationController.dispose();

    // Dispose Appendix A controllers
    _currentEmployerController.dispose();
    _positionJobTitleController.dispose();
    _employerAddressController.dispose();
    _referenceController.dispose();
    _employerTelController.dispose();
    _employerFaxController.dispose();
    _employerCellController.dispose();
    _employerEmailController.dispose();
    for (var controller in _employmentHistoryCompanyControllers) {
      controller.dispose();
    }
    for (var controller in _employmentHistoryPositionControllers) {
      controller.dispose();
    }
    for (var controller in _employmentHistoryPeriodControllers) {
      controller.dispose();
    }
    for (var controller in _employmentHistoryContactControllers) {
      controller.dispose();
    }

    _appendixBComments.forEach((key, controller) => controller.dispose());
    _appendixEComments.forEach((key, controller) => controller.dispose());
    _appendixHRemarks.forEach((key, controller) => controller.dispose());
    _appendixHMarks.forEach((key, controller) => controller.dispose());
    _candidateSignatureController.dispose();
    _candidateDateController.dispose();
    _assessorSignatureController.dispose();
    _assessorDateController.dispose();

    // Dispose Appendix F NEW
    for (var q in _knowledgeQuestions) {
      q.dispose();
    }
    for (var t in _practicalTasks) {
      t.dispose();
    }

    // Dispose fingerprint service
    _fingerprintService.dispose();

    super.dispose();
  }

  Future<void> _loadToolkitData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Select correct endpoint based on OFO number
      String endpointUrl;
      if (widget.ofoNumber == '641201') {
        // Bricklayer - uses separate endpoint
        endpointUrl = AppConfig.getBricklayerToolkitDataUrl;
      } else if (widget.ofoNumber == '642601') {
        // Plumber - uses unified endpoint
        endpointUrl = AppConfig.getPlumberToolkitDataUrl;
      } else {
        // Electrician (671101) or default - uses unified endpoint
        endpointUrl = AppConfig.getArplToolkitDataUrl;
      }

      final response = await http.post(
        Uri.parse(endpointUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learnerID': widget.learnerID,
          'classID': widget.classID,
          'ofoNumber': widget.ofoNumber,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[TOOLKIT_VIEWER_DEBUG] Full API Response: ${jsonEncode(data)}');
        print(
            '[TOOLKIT_VIEWER_DEBUG] appendixE type: ${data['appendixE'].runtimeType}');
        print('[TOOLKIT_VIEWER_DEBUG] appendixE value: ${data['appendixE']}');
        if (data['status'] == 'success') {
          try {
            // ✅ Re-derive trade from returned OFO number (system-of-record), not widget or hardcoded
            final returnedOfo = data['ofoNumber']?.toString() ??
                data['ofo_number']?.toString() ??
                widget.ofoNumber;
            final systemTrade = _detectTradeFromOfo(returnedOfo);
            final systemConfig = _getTradeConfig(systemTrade);

            setState(() {
              _detectedTrade = systemTrade;
              _tradeConfig = systemConfig;
              _toolkitData = ArplToolkitData.fromJson(data);
              _isLoading = false;
              _populateControllers();

              // ✨ FIX: Populate Appendix F Workplace Observations from AppendixE
              // AppendixE contains the same 15 workplace activities
              _workplaceObservations.clear();
              print(
                  '🔵 [APPENDIX_F_FIX] Converting ${_toolkitData!.appendixE.length} AppendixE items to Workplace Observations');
              for (var item in _toolkitData!.appendixE) {
                _workplaceObservations.add(AppendixFWorkplaceObservation(
                  activityId: item.activityId,
                  taskObserved: item.activityName,
                  technicalKnowledge: 1, // Default to Fair (1)
                  interpretationOfInstructions: 1, // Default to Fair (1)
                  teamWorkAttitude: 1, // Default to Fair (1)
                ));
              }
              print(
                  '✅ [APPENDIX_F_FIX] Loaded ${_workplaceObservations.length} workplace observations from appendixE');
            });
          } catch (e) {
            print('[TOOLKIT_VIEWER_ERROR] Parsing error: $e');
            setState(() {
              _errorMessage = 'Error parsing data: $e';
              _isLoading = false;
            });
          }
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

  Future<void> _loadAppendixFData() async {
    setState(() {
      _isLoadingAppendixF = true;
    });

    try {
      final response = await http
          .post(
        Uri.parse('${AppConfig.baseUrl}/get_appendix_f_data.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learnerID': widget.learnerID,
          'ofoNumber': widget.ofoNumber,
        }),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print(
              '⚠️ Appendix F load timeout - backend files may not be deployed yet');
          setState(() {
            _isLoadingAppendixF = false;
          });
          throw Exception('Timeout loading Appendix F');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          setState(() {
            // Load knowledge questions
            _knowledgeQuestions.clear();
            if (data['data']['knowledge'] != null) {
              for (var item in data['data']['knowledge']) {
                _knowledgeQuestions.add(AppendixFKnowledgeQuestion(
                  questionNumber: item['question_number'],
                  questionText: item['question_text'],
                  score: item['candidate_score'],
                  percentage: item['percentage'],
                ));
              }
            }

            // Load practical tasks
            _practicalTasks.clear();
            if (data['data']['practical'] != null) {
              for (var item in data['data']['practical']) {
                _practicalTasks.add(AppendixFPracticalTask(
                  taskNumber: item['task_number'],
                  taskName: item['task_name'],
                  score: item['candidate_score'],
                  percentage: item['percentage'],
                ));
              }
            }

            // Load workplace observations
            _workplaceObservations.clear();
            if (data['data']['workplace_observations'] != null) {
              for (var item in data['data']['workplace_observations']) {
                _workplaceObservations.add(AppendixFWorkplaceObservation(
                  activityId: item['activity_id'],
                  taskObserved: item['task_observed'],
                  technicalKnowledge: item['technical_knowledge'] ?? 1,
                  interpretationOfInstructions:
                      item['interpretation_of_instructions'] ?? 1,
                  teamWorkAttitude: item['team_work_attitude'] ?? 1,
                ));
              }
            }

            _isLoadingAppendixF = false;
          });
        } else {
          // API returned error status
          print('⚠️ Appendix F API error: ${data['message']}');
          setState(() {
            _isLoadingAppendixF = false;
          });
        }
      } else {
        // Non-200 response (404, 500, etc.)
        print('⚠️ Appendix F load failed: HTTP ${response.statusCode}');
        setState(() {
          _isLoadingAppendixF = false;
        });
      }
    } catch (e) {
      print('❌ Error loading Appendix F data: $e');
      setState(() {
        _isLoadingAppendixF = false;
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

    // Appendix F is loaded separately via _loadAppendixFData()
  }

  Future<void> _saveAllChanges() async {
    if (_toolkitData == null) return;

    // DEBUG: Log what we're about to send
    print('🔍 [DEBUG] Starting save...');
    print('🔍 [DEBUG] learnerID: ${widget.learnerID}');
    print('🔍 [DEBUG] classID: ${widget.classID}');
    print('🔍 [DEBUG] ofoNumber: ${widget.ofoNumber}');
    print('🔍 [DEBUG] Appendix B ratings count: ${_appendixBRatings.length}');
    print(
        '🔍 [DEBUG] Appendix D responses count: ${_appendixDResponses.length}');
    print('🔍 [DEBUG] Appendix E ratings count: ${_appendixERatings.length}');

    setState(() {
      _isSaving = true;
    });

    try {
      // Save Appendix B ratings
      final appendixBData = _appendixBRatings.entries.map((entry) {
        return {
          'activity_id': entry.key,
          'rating': entry.value,
          'comments': _appendixBComments[entry.key]?.text ?? '',
        };
      }).toList();

      // Save Appendix D responses
      final appendixDData = _appendixDResponses;

      // Save Appendix E ratings
      final appendixEData = _appendixERatings.entries.map((entry) {
        return {
          'activity_id': entry.key,
          'rating': entry.value,
          'comments': _appendixEComments[entry.key]?.text ?? '',
        };
      }).toList();

      // ══════════════════════════════════════════════════════════
      // SAVE B, D, E TO MAIN ENDPOINT (ONLY IF THERE'S DATA)
      // ══════════════════════════════════════════════════════════
      final hasBDEData = appendixBData.isNotEmpty ||
          appendixDData.isNotEmpty ||
          appendixEData.isNotEmpty;

      if (hasBDEData) {
        print('🔍 [DEBUG] Saving B/D/E data...');
        final url = AppConfig.saveArplToolkitEditsUrl;
        final payload = {
          'learnerID': widget.learnerID,
          'classID': widget.classID,
          'ofoNumber': widget.ofoNumber,
          'appendixB': appendixBData,
          'appendixD': appendixDData,
          'appendixE': appendixEData,
        };

        print('🔍 [DEBUG] Posting to URL: $url');
        final payloadStr = jsonEncode(payload);
        print(
            '🔍 [DEBUG] Payload: ${payloadStr.substring(0, min(500, payloadStr.length))}');

        final response1 = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        print('🔍 [DEBUG] Response status: ${response1.statusCode}');
        print(
            '🔍 [DEBUG] Response body: ${response1.body.substring(0, min(500, response1.body.length))}');

        if (response1.statusCode != 200) {
          // Try to parse error message from response
          String errorMsg =
              'Failed to save Appendix B/D/E: ${response1.statusCode}';
          try {
            final errorData = jsonDecode(response1.body);
            if (errorData['message'] != null) {
              errorMsg = errorData['message'];
            }
          } catch (e) {
            // If can't parse, use default message
          }
          throw Exception(errorMsg);
        }
      } else {
        print('🔍 [DEBUG] No B/D/E data to save, skipping...');
      }

      // ══════════════════════════════════════════════════════════
      // APPENDIX F - NEW REDESIGNED SAVE
      // ══════════════════════════════════════════════════════════
      if (_knowledgeQuestions.isNotEmpty ||
          _practicalTasks.isNotEmpty ||
          _workplaceObservations.isNotEmpty) {
        print('🔍 [DEBUG] Saving Appendix F data...');
        print('🔍 [DEBUG] AppConfig.baseUrl: ${AppConfig.baseUrl}');

        final appendixFUrl = AppConfig.saveAppendixFDataUrl;
        print('🔍 [DEBUG] Full Appendix F URL: $appendixFUrl');

        final appendixFData = {
          'learnerID': widget.learnerID,
          'ofoNumber': widget.ofoNumber,
          'assessor_id': 6, // TODO: Get from logged-in user
          'knowledge': _knowledgeQuestions.map((q) => q.toJson()).toList(),
          'practical': _practicalTasks.map((t) => t.toJson()).toList(),
          'workplace_observations':
              _workplaceObservations.map((o) => o.toJson()).toList(),
        };

        print(
            '🔍 [DEBUG] Workplace observations count: ${_workplaceObservations.length}');
        print(
            '🔍 [DEBUG] Knowledge questions count: ${_knowledgeQuestions.length}');
        print('🔍 [DEBUG] Practical tasks count: ${_practicalTasks.length}');

        final payloadJson = jsonEncode(appendixFData);
        print(
            '🔍 [DEBUG] Payload: ${payloadJson.substring(0, min(1000, payloadJson.length))}');

        final responseF = await http.post(
          Uri.parse(appendixFUrl),
          headers: {'Content-Type': 'application/json'},
          body: payloadJson,
        );

        print('🔍 [DEBUG] Appendix F Response status: ${responseF.statusCode}');
        print(
            '🔍 [DEBUG] Appendix F Response body: ${responseF.body.substring(0, min(500, responseF.body.length))}');

        if (responseF.statusCode != 200) {
          // Try to parse the error message from JSON response
          String errorMsg =
              'Failed to save Appendix F: ${responseF.statusCode}';
          try {
            final errorData = jsonDecode(responseF.body);
            if (errorData['message'] != null) {
              errorMsg = '${errorData['message']}';
              if (errorData['debug'] != null) {
                print('🔍 [DEBUG] Server error details: ${errorData['debug']}');
              }
            }
          } catch (e) {
            print('🔍 [DEBUG] Could not parse error response: $e');
          }
          throw Exception(errorMsg);
        }

        final dataF = jsonDecode(responseF.body);
        if (dataF['status'] != 'success') {
          throw Exception(dataF['message'] ?? 'Appendix F save failed');
        }
      }

      setState(() {
        _isSaving = false;
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Changes saved successfully'),
          backgroundColor: Color(0xFF006341),
          duration: Duration(seconds: 2),
        ),
      );

      // Reload data immediately to show what was saved
      await _loadToolkitData();
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ARPL Toolkit'),
        backgroundColor: const Color(0xFF006341),
        actions: [
          if (_toolkitData != null) ...[
            IconButton(
              icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                });
              },
              tooltip: _isEditing ? 'View Mode' : 'Edit Mode',
            ),
            if (_isEditing && !_isSaving)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveAllChanges,
                tooltip: 'Save Changes',
              ),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                ),
              ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadToolkitData,
            tooltip: 'Reload',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _toolkitData != null ? _handlePrint : null,
            tooltip: 'Print',
          ),
        ],
        bottom: _tabController != null
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Cover'),
                  Tab(text: 'Appx A'),
                  Tab(text: 'Appx B'),
                  Tab(text: 'Appx C'),
                  Tab(text: 'Appx D'),
                  Tab(text: 'Appx E'),
                  Tab(text: 'Appx G'),
                  Tab(text: 'Appx H'),
                  Tab(text: 'Appx F'),
                  Tab(text: 'Appx I'),
                  Tab(text: 'Appx J'),
                ],
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006341)),
            ),
            SizedBox(height: 16),
            Text('Loading toolkit data...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadToolkitData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006341),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_toolkitData == null) {
      return const Center(child: Text('No data available'));
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildCoverPage(),
        _buildAppendixA(),
        _buildAppendixB(),
        _buildAppendixC(),
        _buildAppendixD(),
        _buildAppendixE(),
        _buildAppendixG(),
        _buildAppendixH(),
        _buildAppendixF(),
        _buildAppendixI(),
        _buildAppendixJ(),
      ],
    );
  }

  Widget _buildCoverPage() {
    final learner = _toolkitData!.learner;
    final classInfo = _toolkitData!.classInfo;
    final tradeName = _getTradeName(widget.ofoNumber);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DHET Logo placeholder
          Container(
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'DHET LOGO',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'ARPL TOOLKIT',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006341),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '$tradeName (OFO ${widget.ofoNumber})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 32),
          _buildInfoCard('Learner Information', [
            _InfoRow('Name', learner?.fullName ?? 'N/A'),
            _InfoRow('ID Number', learner?.idNumber ?? 'N/A'),
            _InfoRow('Email', learner?.email ?? 'N/A'),
            _InfoRow('Phone', learner?.phoneNumber ?? 'N/A'),
          ]),
          const SizedBox(height: 16),
          _buildInfoCard('Training Information', [
            _InfoRow('Provider', classInfo?.providerName ?? 'N/A'),
            _InfoRow('Accreditation', classInfo?.accreditationN ?? 'N/A'),
            _InfoRow('Project', classInfo?.projectName ?? 'N/A'),
            _InfoRow('Site', classInfo?.siteName ?? 'N/A'),
            _InfoRow('Class', classInfo?.className ?? 'N/A'),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006341),
              ),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildAppendixB() {
    final appendixB = _toolkitData!.appendixB;
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
                  'Appendix B: SELF-EVALUATION',
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
          if (appendixB.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No self-evaluation data saved yet.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ...appendixB.map((rating) => _buildEditableRatingCard(
                  rating.activityId,
                  rating.activityName,
                  _appendixBRatings[rating.activityId] ??
                      rating.competencyScaleId,
                  _appendixBComments[rating.activityId],
                  'B',
                )),
        ],
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
                controller: commentController,
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
              if (commentController != null &&
                  commentController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  commentController.text,
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

  Widget _buildAppendixD() {
    final appendixD = _toolkitData!.appendixD;
    final tradeName = _getTradeName(widget.ofoNumber);

    final practicalCriteria = [
      'Safety',
      'Hand, power and workshop tools',
      'Measuring equipment',
      'Plans and drawings',
      'Identification of pipe and fittings',
      'Sanitary ware',
      'Transportation, handling and storage of materials',
      'Access equipment',
      'Hot water system',
      'Cold water system',
      'Rain water system',
      'Above ground drainage system',
      'Below ground drainage system',
      'SANS Codes and National Building Regulations',
      'Sanitary ware appliances',
      'Trenching and Backfill',
      'Basic building works',
      'Valves and Terminal Fixtures',
      'Hydraulic loading and Air Test',
      'Install and read of water meters',
      'Brazing and soldering',
      'Jointing and installing of piping',
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
          const SizedBox(height: 16),
          _buildTradeTitleBanner(tradeName),
          const SizedBox(height: 16),
          if (appendixD.isEmpty && !_isEditing)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No practical skills assessment data saved yet.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ...practicalCriteria.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final criteria = entry.value;
              final activityKey = 'activity_$index';
              final response = _appendixDResponses[activityKey] ??
                  appendixD[activityKey] ??
                  '';
              return _buildEditablePracticalCriteriaCard(
                  activityKey, criteria, response);
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
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                criteria,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(width: 16),
            if (_isEditing) ...[
              // Edit mode - radio buttons
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _appendixDResponses[activityKey] = 'yes';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            isYes ? const Color(0xFF006341) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '✓ Yes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isYes ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _appendixDResponses[activityKey] = 'no';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: hasResponse && !isYes
                            ? Colors.red
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '✗ No',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasResponse && !isYes
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // View mode
              if (hasResponse)
                Row(
                  children: [
                    Text(
                      isYes ? '✓ Yes' : '✗ No',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isYes ? const Color(0xFF006341) : Colors.red,
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  'Not assessed',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
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
          if (appendixE.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No workplace experience evaluation data saved yet.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
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

  Widget _buildAppendixH() {
    if (_toolkitData?.appendixH == null) {
      return const Center(child: Text('No Appendix H data available'));
    }

    final appendixH = _toolkitData!.appendixH;
    final items = appendixH.items;
    final recommendations = appendixH.recommendations;
    final tradeName = _getTradeName(widget.ofoNumber);
    final learner = _toolkitData!.learner;

    for (var rec in recommendations) {
      if (!_appendixHStatus.containsKey(rec.acrId)) {
        _appendixHStatus[rec.acrId] = rec.status;
      }
      if (!_appendixHRemarks.containsKey(rec.acrId)) {
        _appendixHRemarks[rec.acrId] = TextEditingController(text: rec.remarks);
      }
      if (!_appendixHMarks.containsKey(rec.acrId)) {
        _appendixHMarks[rec.acrId] = TextEditingController(text: '');
      }
    }
    for (var acrId in [1, 2, 3, 4]) {
      if (!_appendixHMarks.containsKey(acrId)) {
        _appendixHMarks[acrId] = TextEditingController(text: '');
      }
    }

    final knowledgeItem = items.firstWhere((e) => e.acrId == 1,
        orElse: () =>
            AcrItem(acrId: 1, assessmentType: 'Knowledge assessment'));
    final practicalItem = items.firstWhere((e) => e.acrId == 2,
        orElse: () => AcrItem(acrId: 2, assessmentType: 'Set up well'));
    final workplaceItem = items.firstWhere((e) => e.acrId == 3,
        orElse: () =>
            AcrItem(acrId: 3, assessmentType: 'Workplace Observation'));
    final overallItem = items.firstWhere((e) => e.acrId == 4,
        orElse: () => AcrItem(acrId: 4, assessmentType: 'Overall Result'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Appendix H: ACCESS RECOMMENDATION FORM',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006341),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          _buildTradeTitleBanner(tradeName),
          const SizedBox(height: 24),

          // Main Assessment Table
          _buildAppendixHMainTable(
            knowledgeItem,
            practicalItem,
            workplaceItem,
            overallItem,
          ),

          // Gap Closure UI (shown when Overall = Recommended for Gap Closure)
          if (_showGapClosureUI) ...[
            const SizedBox(height: 20),
            _buildGapClosureSection(),
          ],

          // Signature Section (Table-style)
          const SizedBox(height: 20),
          _buildAppendixHSignatureTable(),

          // Save Button
          const SizedBox(height: 24),
          _buildSaveAppendixHButton(),
        ],
      ),
    );
  }

  Widget _buildAppendixHMainTable(
    AcrItem knowledgeItem,
    AcrItem practicalItem,
    AcrItem workplaceItem,
    AcrItem overallItem,
  ) {
    final knowledgeStatus = _appendixHStatus[knowledgeItem.acrId] ?? '';
    final practicalStatus = _appendixHStatus[practicalItem.acrId] ?? '';
    final workplaceStatus = _appendixHStatus[workplaceItem.acrId] ?? '';
    final overallStatus = _appendixHStatus[overallItem.acrId] ?? '';

    final knowledgeRemarksCtrl = _appendixHRemarks.putIfAbsent(
      knowledgeItem.acrId,
      () => TextEditingController(),
    );
    final practicalRemarksCtrl = _appendixHRemarks.putIfAbsent(
      practicalItem.acrId,
      () => TextEditingController(),
    );
    final workplaceRemarksCtrl = _appendixHRemarks.putIfAbsent(
      workplaceItem.acrId,
      () => TextEditingController(),
    );
    final overallRemarksCtrl = _appendixHRemarks.putIfAbsent(
      overallItem.acrId,
      () => TextEditingController(),
    );

    final knowledgeMarksCtrl = _appendixHMarks.putIfAbsent(
      knowledgeItem.acrId,
      () => TextEditingController(),
    );
    final practicalMarksCtrl = _appendixHMarks.putIfAbsent(
      practicalItem.acrId,
      () => TextEditingController(),
    );
    final workplaceMarksCtrl = _appendixHMarks.putIfAbsent(
      workplaceItem.acrId,
      () => TextEditingController(),
    );
    final overallMarksCtrl = _appendixHMarks.putIfAbsent(
      overallItem.acrId,
      () => TextEditingController(),
    );

    const labelColor = Color(0xFFD0D0D0);
    const headerColor = Color(0xFFE8E8E8);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400, width: 1),
      ),
      child: Column(
        children: [
          _buildAssessmentBlock(
            number: 1,
            assessmentName: knowledgeItem.assessmentType,
            acrId: knowledgeItem.acrId,
            currentStatus: knowledgeStatus,
            marksCtrl: knowledgeMarksCtrl,
            remarksCtrl: knowledgeRemarksCtrl,
            isOverall: false,
            labelColor: labelColor,
            headerColor: headerColor,
          ),
          _buildAssessmentBlock(
            number: 2,
            assessmentName: practicalItem.assessmentType,
            acrId: practicalItem.acrId,
            currentStatus: practicalStatus,
            marksCtrl: practicalMarksCtrl,
            remarksCtrl: practicalRemarksCtrl,
            isOverall: false,
            labelColor: labelColor,
            headerColor: headerColor,
          ),
          _buildAssessmentBlock(
            number: 3,
            assessmentName: workplaceItem.assessmentType,
            acrId: workplaceItem.acrId,
            currentStatus: workplaceStatus,
            marksCtrl: workplaceMarksCtrl,
            remarksCtrl: workplaceRemarksCtrl,
            isOverall: false,
            labelColor: labelColor,
            headerColor: headerColor,
          ),
          _buildAssessmentBlock(
            number: 4,
            assessmentName: overallItem.assessmentType,
            acrId: overallItem.acrId,
            currentStatus: overallStatus,
            marksCtrl: overallMarksCtrl,
            remarksCtrl: overallRemarksCtrl,
            isOverall: true,
            labelColor: labelColor,
            headerColor: headerColor,
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentBlock({
    required int number,
    required String assessmentName,
    required int acrId,
    required String currentStatus,
    required TextEditingController marksCtrl,
    required TextEditingController remarksCtrl,
    required bool isOverall,
    required Color labelColor,
    required Color headerColor,
  }) {
    return Column(
      children: [
        Row(
          children: [
            _buildBlockLabelCell('No.\nAssessment', color: headerColor),
            _buildHeaderCell('$number\n$assessmentName',
                flex: 5, color: headerColor),
          ],
        ),
        Row(
          children: [
            _buildBlockLabelCell('Results', color: labelColor),
            _buildAssessmentResultCell(
              acrId: acrId,
              currentStatus: currentStatus,
              isOverall: isOverall,
              flex: 5,
            ),
          ],
        ),
        Row(
          children: [
            _buildBlockLabelCell('Marks', color: labelColor),
            _buildMarksCell(marksCtrl, flex: 5),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBlockLabelCell('Remarks', color: labelColor),
            _buildRemarksCell(remarksCtrl, flex: 5),
          ],
        ),
      ],
    );
  }

  Widget _buildBlockLabelCell(String text, {Color color = Colors.white}) {
    return Expanded(
      flex: 2,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.grey.shade400, width: 0.5),
        ),
        constraints: const BoxConstraints(minHeight: 60, minWidth: 80),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildMarksCell(TextEditingController controller, {int flex = 2}) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, width: 0.5),
        ),
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Center(
          child: _isEditing
              ? SizedBox(
                  width: 120,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Enter marks...',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                )
              : Text(
                  controller.text.isEmpty ? '-' : controller.text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF006341),
                  ),
                  textAlign: TextAlign.center,
                ),
        ),
      ),
    );
  }

  Widget spacerCell({Color color = Colors.white}) {
    return Expanded(
      flex: 1,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.grey.shade400, width: 0.5),
        ),
      ),
    );
  }

  Widget _buildExperienceCell(LearnerDetails? learner) {
    final appendixA = _toolkitData?.appendixA;
    final expText = StringBuffer();
    if (appendixA != null) {
      if (appendixA.positionJobTitle != null &&
          appendixA.positionJobTitle!.isNotEmpty) {
        expText.writeln('Current: ${appendixA.positionJobTitle}');
      }
      if (appendixA.currentEmployer != null &&
          appendixA.currentEmployer!.isNotEmpty) {
        expText.writeln('@ ${appendixA.currentEmployer}');
      }
    }
    final display = expText.toString().trim();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        display.isEmpty ? learner?.fullName ?? 'N/A' : display,
        style: const TextStyle(fontSize: 12),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildHeaderCell(String text,
      {int flex = 1, Color color = Colors.white}) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.grey.shade400, width: 0.5),
        ),
        padding: const EdgeInsets.all(10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCell({int flex = 1, required Widget child}) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, width: 0.5),
        ),
        constraints: const BoxConstraints(minHeight: 90),
        child: child,
      ),
    );
  }

  Widget _buildEmptyCell({int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, width: 0.5),
        ),
        constraints: const BoxConstraints(minHeight: 120),
      ),
    );
  }

  Widget _buildRotatedLabelCell(String text, {Color color = Colors.white}) {
    return Expanded(
      flex: 1,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.grey.shade400, width: 0.5),
        ),
        constraints: const BoxConstraints(minHeight: 90, minWidth: 32),
        child: Center(
          child: RotatedBox(
            quarterTurns: 3,
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentResultCell({
    required int acrId,
    required String currentStatus,
    required bool isOverall,
    int flex = 2,
  }) {
    final List<String> options = isOverall
        ? ['Recommended for trade test', 'Recommended for gap closure']
        : ['Ready', 'Not Yet Ready'];

    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, width: 0.5),
        ),
        constraints: const BoxConstraints(minHeight: 90),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: _isEditing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: options.map((opt) {
                  final selected = currentStatus == opt ||
                      (isOverall &&
                          currentStatus == 'Recommended for Gap Closure' &&
                          opt == 'Recommended for gap closure') ||
                      (isOverall &&
                          currentStatus == 'Recommended' &&
                          opt == 'Recommended for trade test');
                  return InkWell(
                    onTap: () {
                      final hasGapClosure =
                          _tradeConfig['hasGapClosure'] == true;
                      setState(() {
                        if (isOverall) {
                          if (opt == 'Recommended for gap closure') {
                            _appendixHStatus[acrId] =
                                'Recommended for Gap Closure';
                            // Only show gap closure UI when the system supports it for this trade
                            if (hasGapClosure) {
                              _showGapClosureUI = true;
                              _loadGapClosureUnitStandards();
                            } else {
                              _showGapClosureUI = true;
                              _availableUnitStandards = [];
                              _selectedUnitStandardIds.clear();
                            }
                          } else {
                            _appendixHStatus[acrId] = 'Recommended';
                            _showGapClosureUI = false;
                            _selectedUnitStandardIds.clear();
                          }
                        } else {
                          _appendixHStatus[acrId] = opt;
                        }
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF006341)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF006341)
                              : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }).toList(),
              )
            : Center(
                child: Text(
                  currentStatus.isEmpty ? '-' : currentStatus,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF006341),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
      ),
    );
  }

  Widget _buildRemarksCell(TextEditingController controller, {int flex = 2}) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, width: 0.5),
        ),
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(6),
        child: _isEditing
            ? TextField(
                controller: controller,
                maxLines: null,
                expands: false,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Remarks...',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(8),
                ),
              )
            : Text(
                controller.text.isEmpty ? '-' : controller.text,
                style: const TextStyle(fontSize: 12),
              ),
      ),
    );
  }

  Widget _buildAppendixHSignatureTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400, width: 1),
      ),
      child: Row(
        children: [
          // ARPL Candidate column
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8E8),
                    border: Border.all(color: Colors.grey.shade400, width: 0.5),
                  ),
                  child: const Text(
                    'Signature of ARPL\nCandidate:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minHeight: 90),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400, width: 0.5),
                  ),
                  child: _buildSignatureBlock(
                    signature: _candidateSignature,
                    signatureName: _candidateSignatureName,
                    signatureController: _candidateSignatureController,
                    isEditing: _isEditing,
                    onVerify: _verifyFingerprintAndFillSignature,
                    isVerifying: _isVerifyingFingerprint,
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8E8),
                    border: Border.all(color: Colors.grey.shade400, width: 0.5),
                  ),
                  child: const Text(
                    'Date:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minHeight: 50),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400, width: 0.5),
                  ),
                  child: Center(
                    child: _isEditing
                        ? TextField(
                            controller: _candidateDateController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.all(8),
                            ),
                          )
                        : Text(
                            _candidateDateController.text,
                            style: const TextStyle(fontSize: 13),
                          ),
                  ),
                ),
              ],
            ),
          ),
          // Assessor column
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8E8),
                    border: Border.all(color: Colors.grey.shade400, width: 0.5),
                  ),
                  child: const Text(
                    'Signature of\nAssessor:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minHeight: 90),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400, width: 0.5),
                  ),
                  child: _buildAssessorSignatureBlock(),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8E8),
                    border: Border.all(color: Colors.grey.shade400, width: 0.5),
                  ),
                  child: const Text(
                    'Date:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minHeight: 50),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400, width: 0.5),
                  ),
                  child: Center(
                    child: _isEditing
                        ? TextField(
                            controller: _assessorDateController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.all(8),
                            ),
                          )
                        : Text(
                            _assessorDateController.text,
                            style: const TextStyle(fontSize: 13),
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

  Widget _buildSignatureBlock({
    String? signature,
    String? signatureName,
    required TextEditingController signatureController,
    required bool isEditing,
    required Future<void> Function() onVerify,
    required bool isVerifying,
  }) {
    if (signature != null) {
      return Column(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
          const SizedBox(height: 4),
          Text(
            signature,
            style: TextStyle(
              fontSize: 10,
              color: Colors.green.shade800,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            signatureName ?? '',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    if (!isEditing) {
      return const Center(
        child: Text(
          'Not signed',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
        ),
      );
    }
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isVerifying ? null : onVerify,
            icon: isVerifying
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.fingerprint, size: 16),
            label: Text(isVerifying ? 'Capturing...' : 'Sign',
                style: const TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006341),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: signatureController,
          style: const TextStyle(fontSize: 11),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: 'Print name',
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(6),
          ),
        ),
      ],
    );
  }

  Widget _buildAssessorSignatureBlock() {
    final facilitator = _toolkitData?.facilitator;
    if (_assessorSignature != null ||
        _assessorSignatureController.text.isNotEmpty) {
      final name = _assessorSignatureName ?? _assessorSignatureController.text;
      return Column(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
          const SizedBox(height: 4),
          if (_assessorSignature != null)
            Text(
              _assessorSignature!,
              style: TextStyle(
                fontSize: 10,
                color: Colors.green.shade800,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    if (!_isEditing) {
      return const Center(
        child: Text(
          'Not signed',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
        ),
      );
    }
    final defaultName = facilitator?.fullName ?? '';
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _assessorSignature = 'Signed';
                _assessorSignatureName =
                    _assessorSignatureController.text.isEmpty
                        ? defaultName
                        : _assessorSignatureController.text;
                if (_assessorSignatureController.text.isEmpty &&
                    defaultName.isNotEmpty) {
                  _assessorSignatureController.text = defaultName;
                }
              });
            },
            icon: const Icon(Icons.draw, size: 16),
            label:
                const Text('Confirm Signature', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006341),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _assessorSignatureController,
          style: const TextStyle(fontSize: 11),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: 'Assessor name',
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(6),
          ),
        ),
      ],
    );
  }

  Widget _buildGapClosureSection() {
    final hasGapClosure = _tradeConfig['hasGapClosure'] == true;
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: Colors.orange.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Gap Closure Plan - ${_tradeConfig['displayName']} (OFO ${_tradeConfig['ofoCode']})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasGapClosure) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.yellow.shade400),
                ),
                child: const Text(
                  '⚠️  Gap closure qualifications are not yet configured for this trade in the system. Please contact the administrator to set up the qualification/unit standards list.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
            ] else ...[
              const Text(
                'Select the qualifications / unit standards the learner needs to complete:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (_isLoadingGapStandards)
                const Center(child: CircularProgressIndicator())
              else if (_availableUnitStandards.isEmpty)
                const Text(
                  'No unit standards / qualifications available for this trade yet.',
                  style:
                      TextStyle(fontStyle: FontStyle.italic, color: Colors.red),
                )
              else
                _buildUnitStandardsList(),
              const SizedBox(height: 16),
              _buildGapClosureSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnitStandardsList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _availableUnitStandards.length,
        itemBuilder: (context, index) {
          final standard = _availableUnitStandards[index];
          final standardId = standard['unit_standard_id'].toString();
          final isSelected = _selectedUnitStandardIds.contains(standardId);

          return Card(
            margin: const EdgeInsets.all(8),
            elevation: isSelected ? 4 : 1,
            color: isSelected ? Colors.blue.shade50 : Colors.white,
            child: CheckboxListTile(
              title: Text(
                standard['unit_standard_name'] ?? 'Unknown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                'ID: $standardId | Credits: ${standard['credits'] ?? 0}',
                style: const TextStyle(fontSize: 12),
              ),
              value: isSelected,
              onChanged: (bool? value) {
                _toggleUnitStandardSelection(standardId);
              },
              activeColor: Colors.blue.shade700,
            ),
          );
        },
      ),
    );
  }

  Widget _buildGapClosureSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Selected Unit Standards:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${_selectedUnitStandardIds.length} / ${_availableUnitStandards.length}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveAppendixHButton() {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _saveAppendixHData,
      icon: _isSaving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.save),
      label: Text(_isSaving ? 'Saving...' : 'Save Appendix H'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF006341),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }

  Future<void> _saveAppendixHData() async {
    final saveEndpoint = _tradeConfig['saveEndpoint'] as String? ?? '';
    final hasGapClosure = _tradeConfig['hasGapClosure'] == true;

    // For trades with no backend gap-closure endpoints we can still save
    // status/remarks locally but must not POST to a missing endpoint.
    if (saveEndpoint.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No save endpoint configured for trade "${_tradeConfig['displayName']}" (OFO ${widget.ofoNumber}). Status/remarks kept on device only.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Prepare recommendations data
      final recommendations = [];
      for (var entry in _appendixHStatus.entries) {
        recommendations.add({
          'acrid': entry.key,
          'status': entry.value,
          'remarks': _appendixHRemarks[entry.key]?.text ?? '',
          'candidate_score': _appendixHMarks[entry.key]?.text ?? '',
        });
      }

      // Call appropriate save endpoint based on trade (derived from system OFO)
      final response = await http
          .post(
            Uri.parse(saveEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'learnerID': widget.learnerID,
              'recommendations': recommendations,
              'selected_unit_standards':
                  hasGapClosure ? _selectedUnitStandardIds.toList() : [],
              'ofo_code': _tradeConfig['ofoCode'],
              'trade': _detectedTrade,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Appendix H saved successfully! '
                  '${_selectedUnitStandardIds.isNotEmpty ? "${_selectedUnitStandardIds.length} unit standards selected." : ""}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
          // Reload toolkit data to refresh
          await _loadToolkitData();
        } else {
          throw Exception(data['message'] ?? 'Failed to save');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving Appendix H: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _getAssessmentTypeName(int acrId, List<AcrItem> items) {
    final item = items.where((i) => i.acrId == acrId).firstOrNull;
    return item?.assessmentType ?? 'Component $acrId';
  }

  Widget _buildFinalDecision(List<AccessRecommendation> recommendations) {
    // Check if all recommendations are "Ready" or "Recommended"
    final allReady = recommendations.every((rec) =>
        rec.status.toLowerCase().contains('ready') ||
        rec.status.toLowerCase().contains('recommended'));

    final anyNotReady = recommendations.any((rec) =>
        rec.status.toLowerCase().contains('not ready') ||
        rec.status.toLowerCase().contains('gap'));

    if (allReady && recommendations.length >= 4) {
      return Card(
        color: const Color(0xFFE8F5E9),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF006341), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'RECOMMENDED FOR TRADE TEST',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'All assessment components have been completed successfully. The candidate is recommended to proceed to trade test.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    } else if (anyNotReady) {
      return Card(
        color: Colors.amber[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pending_actions,
                      color: Colors.orange[700], size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'GAP CLOSURE REQUIRED',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Some competencies require additional work before the candidate can be recommended for trade test.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _handlePrint() {
    // For now, open the PHP version in browser
    // In a full implementation, this would generate a PDF
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Print Toolkit'),
        content: const Text(
            'PDF generation will be implemented in a future update.\n\nFor now, you can view the printable version in your browser.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // APPENDIX A: APPLICATION FORM (EDITABLE)
  // ══════════════════════════════════════════════════════════
  Widget _buildAppendixA() {
    final learner = _toolkitData!.learner;
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
                  'Appendix A: APPLICATION FORM',
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
            'APPLICATION FOR RECOGNITION OF PRIOR LEARNING IN A LISTED TRADE',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildTradeTitleBanner(tradeName),
          const SizedBox(height: 16),

          // Applicant Details Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Applicant Details',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  _InfoRow('Trade Title', _getTradeName(widget.ofoNumber)),
                  _InfoRow('OFO Code', widget.ofoNumber),
                  const SizedBox(height: 12),
                  if (_isEditing)
                    TextField(
                      controller: _tradeSpecializationController,
                      decoration: const InputDecoration(
                        labelText: 'Specialization / Alternative Trade Name',
                        hintText: 'e.g. None or specify specialization',
                        border: OutlineInputBorder(),
                      ),
                    )
                  else
                    _InfoRow(
                        'Specialization',
                        _tradeSpecializationController.text.isEmpty
                            ? 'None'
                            : _tradeSpecializationController.text),
                  const SizedBox(height: 8),
                  _InfoRow('Name of Candidate', learner?.fullName ?? 'N/A'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Address Section (Physical from DB, Postal editable)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Address Details',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  const Text('Physical Address (from profile):',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(learner?.fullAddress ?? 'Not provided'),
                  const SizedBox(height: 16),
                  const Text('Postal Address:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  if (_isEditing) ...[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Postal Address Line 1',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Postal Address Line 2',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Postal Code',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ] else
                    const Text('Not provided yet',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Contact Details Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Details',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  _InfoRow('Tel no', learner?.phoneNumber ?? 'N/A'),
                  const SizedBox(height: 8),
                  if (_isEditing)
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Fax no',
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    )
                  else
                    _InfoRow('Fax no', 'Not provided'),
                  const SizedBox(height: 8),
                  _InfoRow('Cell no', learner?.phoneNumber ?? 'N/A'),
                  _InfoRow('E-mail address', learner?.email ?? 'N/A'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Employment Status Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Employment Status',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  const Text('Currently employed:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  if (_isEditing)
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Yes'),
                            value: true,
                            groupValue: false, // TODO: Add state variable
                            onChanged: (val) {},
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('No'),
                            value: false,
                            groupValue: false,
                            onChanged: (val) {},
                            dense: true,
                          ),
                        ),
                      ],
                    )
                  else
                    const Text('Not specified',
                        style: TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  const Text('Self employed:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  if (_isEditing)
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Yes'),
                            value: true,
                            groupValue: false,
                            onChanged: (val) {},
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('No'),
                            value: false,
                            groupValue: false,
                            onChanged: (val) {},
                            dense: true,
                          ),
                        ),
                      ],
                    )
                  else
                    const Text('Not specified',
                        style: TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Current Employer Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current/Most Recent Employer',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  if (_isEditing) ...[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Current/Most recent Employer',
                        hintText: 'Company name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Position/Job Title',
                        hintText: 'e.g. Plumber / Pipe Fitter',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Employer Address',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Reference (Supervisor/Foreman)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Tel no',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Cell no',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'E-mail address',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ] else
                    const Text('Not provided yet',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Employment History Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Employment History',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  if (_isEditing)
                    const Text(
                        'Provide previous employment details (up to 3 entries):',
                        style: TextStyle(
                            fontSize: 13, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 12),
                  for (int i = 0; i < 3; i++) ...[
                    Text('Entry ${i + 1}:',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    if (_isEditing) ...[
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Company',
                          hintText: 'Company name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Position/Job Title',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Period',
                                hintText: '2018-2022',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Contact (Tel)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      if (i < 2) const Divider(height: 24),
                    ] else
                      const Text('Not provided',
                          style: TextStyle(
                              fontStyle: FontStyle.italic, color: Colors.grey)),
                    if (!_isEditing && i < 2) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Signature Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Declaration',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  if (_isEditing) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Candidate:',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isVerifyingFingerprint
                              ? null
                              : () {
                                  print(
                                      '[APPENDIX_A] Fingerprint button pressed!');
                                  print(
                                      '[APPENDIX_A] widget.learnerID = ${widget.learnerID}');
                                  print(
                                      '[APPENDIX_A] Calling _verifyFingerprintAndFillSignature()');
                                  _verifyFingerprintAndFillSignature();
                                },
                          icon: _isVerifyingFingerprint
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.fingerprint),
                          label: Text(_isVerifyingFingerprint
                              ? 'Verifying...'
                              : 'Verify Fingerprint'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006341),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _candidateSignatureController,
                      decoration: InputDecoration(
                        labelText: 'Candidate Signature',
                        hintText: 'Type full name or verify with fingerprint',
                        border: const OutlineInputBorder(),
                        suffixIcon: _candidateSignatureName != null
                            ? const Icon(Icons.verified, color: Colors.green)
                            : null,
                      ),
                      enabled: !_isVerifyingFingerprint,
                    ),
                    if (_candidateSignatureName != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Verified: $_candidateSignatureName',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_candidateSignature != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Signature Image:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Image.memory(
                              base64Decode(_candidateSignature!
                                  .replaceAll('data:image/png;base64,', '')
                                  .replaceAll('data:image/jpeg;base64,', '')),
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: DateTime.now().toString().substring(0, 10),
                      ),
                    ),
                  ] else
                    const Text('Not signed yet',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // APPENDIX C: TRADE CURRICULUM CONTENT SUMMARY (EDITABLE)
  // ══════════════════════════════════════════════════════════
  Widget _buildAppendixC() {
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
                  'Appendix C: TRADE CURRICULUM CONTENT SUMMARY',
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
          const SizedBox(height: 16),
          _buildTradeTitleBanner(tradeName),
          const SizedBox(height: 16),

          // Trade Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trade Information',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  _InfoRow('Qualification', _getTradeName(widget.ofoNumber)),
                  _InfoRow('OFO Code', widget.ofoNumber),
                  _InfoRow('NQF Level', '4'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Unit Standards (Read-Only - from database)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Unit Standards Covered',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Unit standards for this qualification will be loaded from the database.',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  const Text('Example unit standards:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  _buildUnitStandardRow(
                      '261999', 'Apply first-aid skills in the workplace'),
                  _buildUnitStandardRow('116237',
                      'Install and maintain sanitary ware appliances and systems'),
                  _buildUnitStandardRow(
                      '116238', 'Install and test domestic water systems'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Curriculum Notes (Editable)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Curriculum Overview & Notes',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  if (_isEditing) ...[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Curriculum Overview',
                        hintText:
                            'Brief overview of the trade curriculum covered',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Module Summary',
                        hintText: 'Summary of modules completed',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Additional Notes',
                        hintText: 'Any additional relevant information',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ] else
                    const Text('No curriculum notes added yet',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitStandardRow(String id, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF006341).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              id,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF006341),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // HELPER METHODS
  // ══════════════════════════════════════════════════════════

  /// Single source of truth: OFO -> trade key / display name / qualification id
  static const Map<String, Map<String, dynamic>> _ofoTradeRegistry = {
    '671101': {
      'key': 'electrician',
      'displayName': 'Electrician',
      'qualificationId': 91761,
    },
    '642601': {
      'key': 'plumber',
      'displayName': 'Plumber',
      'qualificationId': 65409,
    },
    '641201': {
      'key': 'bricklayer',
      'displayName': 'Bricklayer',
      'qualificationId': 65409,
    },
    '671104': {
      'key': 'carpenter',
      'displayName': 'Carpenter',
      'qualificationId': 0,
    },
    '671105': {
      'key': 'welder',
      'displayName': 'Welder',
      'qualificationId': 0,
    },
  };

  /// Get human-readable trade display name from OFO number (system data)
  String _getTradeName(String ofoNumber) {
    final entry = _ofoTradeRegistry[ofoNumber];
    return entry?['displayName'] as String? ?? 'Trade Specialist';
  }

  /// ✅ Detect trade key FROM THE GIVEN SYSTEM OFO NUMBER (no hardcoded default)
  /// Never falls back to "bricklayer" silently – unknown trades return empty + use generic config.
  String _detectTradeFromOfo(String ofoNumber) {
    final entry = _ofoTradeRegistry[ofoNumber];
    if (entry != null) {
      final key = entry['key'] as String;
      // Only return concrete key if backend endpoints exist for this trade
      // (otherwise keep as empty so config clearly shows "unknown")
      if (const {'electrician', 'plumber', 'bricklayer'}.contains(key)) {
        return key;
      }
      return key; // carpenter/welder – no gap endpoints, but still correct trade name
    }
    return ''; // unknown OFO – do NOT pretend it is bricklayer
  }

  /// Get trade-specific configuration for gap closure.
  /// When the trade is unknown, returns an explicit "unknown" config that
  /// disables gap closure instead of defaulting to bricklayer.
  Map<String, dynamic> _getTradeConfig(String trade) {
    switch (trade) {
      case 'electrician':
        return {
          'qualificationId': 91761,
          'ofoCode': '671101',
          'getEndpoint': AppConfig.getElectricianGapUnitStandardsUrl,
          'saveEndpoint': AppConfig.saveElectricianGapClosureUrl,
          'displayName': 'Electrician',
          'hasGapClosure': true,
        };
      case 'plumber':
        return {
          'qualificationId': 65409,
          'ofoCode': '642601',
          'getEndpoint': AppConfig.getPlumberGapUnitStandardsUrl,
          'saveEndpoint': AppConfig.savePlumberGapClosureUrl,
          'displayName': 'Plumber',
          'hasGapClosure': true,
        };
      case 'bricklayer':
        return {
          'qualificationId': 65409,
          'ofoCode': '641201',
          'getEndpoint': AppConfig.getBricklayerGapUnitStandardsUrl,
          'saveEndpoint': AppConfig.saveBricklayerGapClosureUrl,
          'displayName': 'Bricklayer',
          'hasGapClosure': true,
        };
      case 'carpenter':
        return {
          'qualificationId': 0,
          'ofoCode': '671104',
          'getEndpoint': '',
          'saveEndpoint': '',
          'displayName': 'Carpenter',
          'hasGapClosure': false,
        };
      case 'welder':
        return {
          'qualificationId': 0,
          'ofoCode': '671105',
          'getEndpoint': '',
          'saveEndpoint': '',
          'displayName': 'Welder',
          'hasGapClosure': false,
        };
      default:
        // Unknown OFO from system – use generic display, no silent bricklayer fallback
        final fallbackName = _getTradeName(widget.ofoNumber);
        return {
          'qualificationId': 0,
          'ofoCode': widget.ofoNumber,
          'getEndpoint': '',
          'saveEndpoint': '',
          'displayName': fallbackName,
          'hasGapClosure': false,
        };
    }
  }

  /// Load unit standards for gap closure (only if trade has a system endpoint)
  Future<void> _loadGapClosureUnitStandards() async {
    // Guard against trades without gap closure backend (no silent bricklayer fallback)
    final hasGapClosure = _tradeConfig['hasGapClosure'] == true;
    final endpoint = _tradeConfig['getEndpoint'] as String? ?? '';
    if (!hasGapClosure || endpoint.isEmpty) {
      setState(() {
        _isLoadingGapStandards = false;
        _availableUnitStandards = [];
      });
      print(
          '⚠️  No gap closure endpoints configured for trade "$_detectedTrade" (OFO: ${widget.ofoNumber})');
      return;
    }

    setState(() {
      _isLoadingGapStandards = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'learnerID': widget.learnerID,
              'qualification_id': _tradeConfig['qualificationId'],
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _availableUnitStandards =
                List<Map<String, dynamic>>.from(data['unit_standards'] ?? []);
            _selectedUnitStandardIds = Set<String>.from(
                (data['selected_unit_standards'] ?? [])
                    .map((e) => e.toString()));
          });
          print(
              '✅ Loaded ${_availableUnitStandards.length} unit standards for $_detectedTrade');
        } else {
          print('❌ Error loading gap standards: ${data['message']}');
        }
      }
    } catch (e) {
      print('❌ Exception loading gap closure unit standards: $e');
    } finally {
      setState(() {
        _isLoadingGapStandards = false;
      });
    }
  }

  /// Toggle unit standard selection
  void _toggleUnitStandardSelection(String unitStandardId) {
    setState(() {
      if (_selectedUnitStandardIds.contains(unitStandardId)) {
        _selectedUnitStandardIds.remove(unitStandardId);
      } else {
        _selectedUnitStandardIds.add(unitStandardId);
      }
    });
  }

  /// Build a consistent trade title banner for all appendices
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

  // ══════════════════════════════════════════════════════════
  // APPENDIX F: ASSESSMENT EVALUATION AGREEMENT - NEW REDESIGN
  // ══════════════════════════════════════════════════════════
  Widget _buildAppendixF() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Center(
            child: Text(
              '9. Appendix F: ASSESSMENT EVALUATION AGREEMENT',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006341),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Knowledge, Practical Skills and Workplace Observation',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // Loading indicator
          if (_isLoadingAppendixF)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Section 1: Knowledge Assessment
            _buildKnowledgeSectionNew(),
            const SizedBox(height: 24),

            // Section 2: Practical Tasks
            _buildPracticalSectionNew(),
            const SizedBox(height: 24),

            // Section 3: Workplace Observation
            _buildWorkplaceObservationNew(),
          ],
        ],
      ),
    );
  }

  // SECTION 1: KNOWLEDGE ASSESSMENT (DYNAMIC)
  Widget _buildKnowledgeSectionNew() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '1. KNOWLEDGE ASSESSMENT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006341),
                  ),
                ),
                if (_isEditing)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        int nextNumber = _knowledgeQuestions.isEmpty
                            ? 1
                            : _knowledgeQuestions.last.questionNumber + 1;
                        _knowledgeQuestions.add(AppendixFKnowledgeQuestion(
                          questionNumber: nextNumber,
                        ));
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Question'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006341),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_knowledgeQuestions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No questions added yet. Tap "Add Question" to start.',
                  style: TextStyle(
                      fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                      const Color(0xFF006341).withOpacity(0.1)),
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columns: const [
                    DataColumn(
                        label: Text('#',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Question',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Score',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Percentage%',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Actions',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _knowledgeQuestions.map((q) {
                    return DataRow(cells: [
                      DataCell(Text(q.questionNumber.toString())),
                      DataCell(
                        SizedBox(
                          width: 300,
                          child: _isEditing
                              ? TextField(
                                  controller: q.questionController,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter question...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(8),
                                  ),
                                  maxLines: 2,
                                )
                              : Text(q.questionController.text.isEmpty
                                  ? '-'
                                  : q.questionController.text),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: _isEditing
                              ? TextField(
                                  controller: q.scoreController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(8),
                                  ),
                                  keyboardType: TextInputType.number,
                                )
                              : Text(q.scoreController.text.isEmpty
                                  ? '-'
                                  : q.scoreController.text),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: _isEditing
                              ? TextField(
                                  controller: q.percentageController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(8),
                                  ),
                                  keyboardType: TextInputType.number,
                                )
                              : Text(q.percentageController.text.isEmpty
                                  ? '-'
                                  : q.percentageController.text),
                        ),
                      ),
                      DataCell(
                        _isEditing
                            ? IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    q.dispose();
                                    _knowledgeQuestions.remove(q);
                                  });
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // SECTION 2: PRACTICAL TASKS (DYNAMIC)
  Widget _buildPracticalSectionNew() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '2. PRACTICAL TASKS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006341),
                  ),
                ),
                if (_isEditing)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        int nextNumber = _practicalTasks.isEmpty
                            ? 1
                            : _practicalTasks.last.taskNumber + 1;
                        _practicalTasks.add(AppendixFPracticalTask(
                          taskNumber: nextNumber,
                        ));
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Task'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006341),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_practicalTasks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No tasks added yet. Tap "Add Task" to start.',
                  style: TextStyle(
                      fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                      const Color(0xFF006341).withOpacity(0.1)),
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columns: const [
                    DataColumn(
                        label: Text('#',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Task Name',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Score',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Percentage%',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Actions',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _practicalTasks.map((t) {
                    return DataRow(cells: [
                      DataCell(Text(t.taskNumber.toString())),
                      DataCell(
                        SizedBox(
                          width: 300,
                          child: _isEditing
                              ? TextField(
                                  controller: t.taskNameController,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter task name...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(8),
                                  ),
                                )
                              : Text(t.taskNameController.text.isEmpty
                                  ? '-'
                                  : t.taskNameController.text),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: _isEditing
                              ? TextField(
                                  controller: t.scoreController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(8),
                                  ),
                                  keyboardType: TextInputType.number,
                                )
                              : Text(t.scoreController.text.isEmpty
                                  ? '-'
                                  : t.scoreController.text),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: _isEditing
                              ? TextField(
                                  controller: t.percentageController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(8),
                                  ),
                                  keyboardType: TextInputType.number,
                                )
                              : Text(t.percentageController.text.isEmpty
                                  ? '-'
                                  : t.percentageController.text),
                        ),
                      ),
                      DataCell(
                        _isEditing
                            ? IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    t.dispose();
                                    _practicalTasks.remove(t);
                                  });
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // SECTION 3: WORKPLACE OBSERVATION (FROM DATABASE WITH DROPDOWNS)
  Widget _buildWorkplaceObservationNew() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '3. WORKPLACE OBSERVATION',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006341),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rate each activity: 1=Fair, 2=Good, 3=Excellent',
              style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_workplaceObservations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No workplace activities available.',
                  style: TextStyle(
                      fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                      const Color(0xFF006341).withOpacity(0.1)),
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(
                        label: Text('Task Observed',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Technical\nKnowledge',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Interpretation of\nInstructions',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Team Work\nAttitude',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _workplaceObservations.map((obs) {
                    return DataRow(cells: [
                      DataCell(
                        SizedBox(
                          width: 250,
                          child: Text(obs.taskObserved),
                        ),
                      ),
                      DataCell(
                        _isEditing
                            ? DropdownButton<int>(
                                value: obs.technicalKnowledge,
                                items: const [
                                  DropdownMenuItem(
                                      value: 1, child: Text('1 - Fair')),
                                  DropdownMenuItem(
                                      value: 2, child: Text('2 - Good')),
                                  DropdownMenuItem(
                                      value: 3, child: Text('3 - Excellent')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    obs.technicalKnowledge = value!;
                                  });
                                },
                              )
                            : Text(_getRatingText(obs.technicalKnowledge)),
                      ),
                      DataCell(
                        _isEditing
                            ? DropdownButton<int>(
                                value: obs.interpretationOfInstructions,
                                items: const [
                                  DropdownMenuItem(
                                      value: 1, child: Text('1 - Fair')),
                                  DropdownMenuItem(
                                      value: 2, child: Text('2 - Good')),
                                  DropdownMenuItem(
                                      value: 3, child: Text('3 - Excellent')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    obs.interpretationOfInstructions = value!;
                                  });
                                },
                              )
                            : Text(_getRatingText(
                                obs.interpretationOfInstructions)),
                      ),
                      DataCell(
                        _isEditing
                            ? DropdownButton<int>(
                                value: obs.teamWorkAttitude,
                                items: const [
                                  DropdownMenuItem(
                                      value: 1, child: Text('1 - Fair')),
                                  DropdownMenuItem(
                                      value: 2, child: Text('2 - Good')),
                                  DropdownMenuItem(
                                      value: 3, child: Text('3 - Excellent')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    obs.teamWorkAttitude = value!;
                                  });
                                },
                              )
                            : Text(_getRatingText(obs.teamWorkAttitude)),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // HELPER METHOD FOR DROPDOWN TEXT
  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return '1 - Fair';
      case 2:
        return '2 - Good';
      case 3:
        return '3 - Excellent';
      default:
        return '-';
    }
  }

  // ══════════════════════════════════════════════════════════
  // HELPER METHODS FOR APPENDIX F - OLD METHODS REMOVED
  // (Using new dynamic section builders above)
  // ══════════════════════════════════════════════════════════

  /// Build a bordered table with custom column widths
  Widget _buildBorderedTable({
    required Map<int, double> columnWidths,
    required List<Widget> headerRow,
    required List<List<Widget>> dataRows,
  }) {
    // Convert double values to FixedColumnWidth for Table widget
    final tableColumnWidths = columnWidths.map(
      (key, value) => MapEntry(key, FixedColumnWidth(value)),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(
          color: Colors.grey[400]!,
          width: 1,
        ),
        columnWidths: tableColumnWidths,
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(
              color: const Color(0xFF006341),
            ),
            children: headerRow,
          ),
          // Data rows
          ...dataRows.map((row) => TableRow(children: row)),
        ],
      ),
    );
  }

  /// Build a signature and date row for sign-off sections
  Widget _buildSignatureDateRow(String role,
      [TextEditingController? dateController]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$role:',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Signature',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[400]!,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_isEditing && dateController != null)
                    TextField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'DD/MM/YYYY',
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 12),
                    )
                  else
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[400]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          dateController?.text ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // APPENDIX G: APPEALS FORM (EDITABLE)
  // ══════════════════════════════════════════════════════════
  Widget _buildAppendixG() {
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
                  'Appendix G: APPEALS FORM',
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
          const SizedBox(height: 16),
          _buildTradeTitleBanner(tradeName),
          const SizedBox(height: 16),

          // Appeal Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appeal Information',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  _InfoRow('ARPL Candidate',
                      _toolkitData!.learner?.fullName ?? 'N/A'),
                  _InfoRow(
                      'Assessor', _toolkitData!.facilitator?.fullName ?? 'N/A'),
                  _InfoRow('Institution',
                      _toolkitData!.classInfo?.providerName ?? 'N/A'),
                  const SizedBox(height: 12),
                  if (_isEditing) ...[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Name of Moderator',
                        hintText: 'Full name of moderator handling the appeal',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else
                    _InfoRow('Moderator', 'Not assigned'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Appeal Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appeal Details',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  if (_isEditing) ...[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Reason for Appeal',
                        hintText: 'State the reason for the appeal clearly...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Appeal Status',
                        border: OutlineInputBorder(),
                      ),
                      value: 'Submitted',
                      items: const [
                        DropdownMenuItem(
                            value: 'Submitted', child: Text('Submitted')),
                        DropdownMenuItem(
                            value: 'Under Review', child: Text('Under Review')),
                        DropdownMenuItem(
                            value: 'Resolved', child: Text('Resolved')),
                      ],
                      onChanged: (val) {},
                    ),
                  ] else
                    const Text('No appeal submitted',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Candidate Signature
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Candidate Declaration',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  if (_isEditing) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Candidate:',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isVerifyingFingerprint
                              ? null
                              : _verifyFingerprintAndFillSignature,
                          icon: _isVerifyingFingerprint
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.fingerprint),
                          label: Text(_isVerifyingFingerprint
                              ? 'Verifying...'
                              : 'Verify Fingerprint'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006341),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _candidateSignatureController,
                      decoration: InputDecoration(
                        labelText: 'ARPL Candidate Signature',
                        hintText: 'Type full name or verify with fingerprint',
                        border: const OutlineInputBorder(),
                        suffixIcon: _candidateSignatureName != null
                            ? const Icon(Icons.verified, color: Colors.green)
                            : null,
                      ),
                      enabled: !_isVerifyingFingerprint,
                    ),
                    if (_candidateSignatureName != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Verified: $_candidateSignatureName',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_candidateSignature != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Signature Image:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Image.memory(
                              base64Decode(_candidateSignature!
                                  .replaceAll('data:image/png;base64,', '')
                                  .replaceAll('data:image/jpeg;base64,', '')),
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Signed at',
                              hintText: 'Place',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                            controller: TextEditingController(
                              text: DateTime.now().toString().substring(0, 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    const Text('Not signed',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Assessor Response
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assessor Findings',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  if (_isEditing) ...[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Assessor Findings',
                        hintText: "Assessor's findings regarding the appeal...",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Assessor Signature',
                        hintText: 'Type full name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Signed at',
                              hintText: 'Place',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                            controller: TextEditingController(
                              text: DateTime.now().toString().substring(0, 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    const Text('Pending assessor response',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Important Notice
          Card(
            color: Colors.amber[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'NB: ARPL candidate must state the reason for the appeal and forward to the moderator. The moderator must call a meeting within 1 week of receiving the appeal.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // APPENDIX I: STATEMENT OF RESULTS (EDITABLE)
  // ══════════════════════════════════════════════════════════
  Widget _buildAppendixI() {
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
                  'Appendix I: STATEMENT OF RESULTS',
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
          const SizedBox(height: 12),
          _buildTradeTitleBanner(tradeName),
          const SizedBox(height: 16),
          Card(
            color: Colors.blue[50],
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                'This Statement of Results indicates that the learner/candidate has complied with the requirements of the knowledge, practical skills and workplace components of the Occupational (Trade) qualification.',
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Provider Type
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Provider Type',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  if (_isEditing)
                    Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Assessment Centre'),
                          value: 'Assessment Centre',
                          groupValue: 'Skills Development Provider',
                          onChanged: (val) {},
                          dense: true,
                        ),
                        RadioListTile<String>(
                          title:
                              const Text('Skills Development Provider (SDP)'),
                          value: 'Skills Development Provider',
                          groupValue: 'Skills Development Provider',
                          onChanged: (val) {},
                          dense: true,
                        ),
                      ],
                    )
                  else
                    const Text('Skills Development Provider (SDP)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Provider Details (Read-Only)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Provider Details',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  _InfoRow('Provider Name',
                      _toolkitData!.classInfo?.providerName ?? 'N/A'),
                  _InfoRow('Accreditation No',
                      _toolkitData!.classInfo?.accreditationN ?? 'N/A'),
                  _InfoRow(
                      'Project', _toolkitData!.classInfo?.projectName ?? 'N/A'),
                  _InfoRow('Site', _toolkitData!.classInfo?.siteName ?? 'N/A'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Candidate Details (Read-Only)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Candidate Details',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Text('Type: ',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF006341),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ARPL Process',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _InfoRow('Full Names', _toolkitData!.learner?.name ?? 'N/A'),
                  _InfoRow('Surname', _toolkitData!.learner?.surname ?? 'N/A'),
                  _InfoRow(
                      'ID Number', _toolkitData!.learner?.idNumber ?? 'N/A'),
                  _InfoRow(
                      'Address', _toolkitData!.learner?.fullAddress ?? 'N/A'),
                  _InfoRow('Tel/Cell No',
                      _toolkitData!.learner?.phoneNumber ?? 'N/A'),
                  _InfoRow('E-mail', _toolkitData!.learner?.email ?? 'N/A'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Trade Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trade Information',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  _InfoRow(
                      'Qualification Title', _getTradeName(widget.ofoNumber)),
                  _InfoRow('OFO Code', widget.ofoNumber),
                  _InfoRow('NQF Level', '4'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Assessment Results (Editable)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assessment Results',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  if (_isEditing) ...[
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Knowledge Assessment Result',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: '', child: Text('-- Select --')),
                        DropdownMenuItem(
                            value: 'Competent', child: Text('Competent')),
                        DropdownMenuItem(
                            value: 'Not Yet Competent',
                            child: Text('Not Yet Competent')),
                      ],
                      onChanged: (val) {},
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Practical Assessment Result',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: '', child: Text('-- Select --')),
                        DropdownMenuItem(
                            value: 'Competent', child: Text('Competent')),
                        DropdownMenuItem(
                            value: 'Not Yet Competent',
                            child: Text('Not Yet Competent')),
                      ],
                      onChanged: (val) {},
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Workplace Assessment Result',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: '', child: Text('-- Select --')),
                        DropdownMenuItem(
                            value: 'Competent', child: Text('Competent')),
                        DropdownMenuItem(
                            value: 'Not Yet Competent',
                            child: Text('Not Yet Competent')),
                      ],
                      onChanged: (val) {},
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Overall Competency Rating (1-5)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('-- Select --')),
                        DropdownMenuItem(
                            value: 1, child: Text('1 - Fundamental Awareness')),
                        DropdownMenuItem(value: 2, child: Text('2 - Novice')),
                        DropdownMenuItem(
                            value: 3, child: Text('3 - Intermediate')),
                        DropdownMenuItem(value: 4, child: Text('4 - Advanced')),
                        DropdownMenuItem(value: 5, child: Text('5 - Expert')),
                      ],
                      onChanged: (val) {},
                    ),
                  ] else
                    const Text('Assessment results not recorded yet',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Assessor Certification
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assessor Certification',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  if (_isEditing) ...[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Assessor Name',
                        hintText: 'Full name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Assessor Registration Number',
                        hintText: 'NAMB registration number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Certification Date',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: DateTime.now().toString().substring(0, 10),
                      ),
                    ),
                  ] else ...[
                    _InfoRow('Assessor',
                        _toolkitData!.facilitator?.fullName ?? 'Not assigned'),
                    _InfoRow('Registration No',
                        _toolkitData!.facilitator?.assessorNo ?? 'N/A'),
                    _InfoRow('Certification Date', 'Not certified yet'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // FINGERPRINT VERIFICATION FOR CANDIDATE SIGNATURE
  // ══════════════════════════════════════════════════════════

  Future<void> _verifyFingerprintAndFillSignature() async {
    setState(() => _isVerifyingFingerprint = true);

    try {
      // Step 1: Get learner's stored fingerprint templates
      print('[FINGERPRINT_SIG] ====== VERIFICATION START ======');
      print('[FINGERPRINT_SIG] widget.learnerID: ${widget.learnerID}');
      print('[FINGERPRINT_SIG] Getting stored templates...');

      final templates =
          await DatabaseHelper().getAllTemplates(widget.learnerID);

      print(
          '[FINGERPRINT_SIG] Templates retrieved: ${templates.keys.length} keys');
      print(
          '[FINGERPRINT_SIG] ZKTeco Left: ${templates['zkteco_left_template']?.isNotEmpty ?? false}');
      print(
          '[FINGERPRINT_SIG] ZKTeco Right: ${templates['zkteco_right_template']?.isNotEmpty ?? false}');
      print(
          '[FINGERPRINT_SIG] Futronic Left: ${templates['futronic_left_template']?.isNotEmpty ?? false}');
      print(
          '[FINGERPRINT_SIG] Futronic Right: ${templates['futronic_right_template']?.isNotEmpty ?? false}');

      // Check both ZKTeco and Futronic templates
      final zkLeftTemplate = templates['zkteco_left_template'];
      final zkRightTemplate = templates['zkteco_right_template'];
      final futLeftTemplate = templates['futronic_left_template'];
      final futRightTemplate = templates['futronic_right_template'];

      if ((zkLeftTemplate == null || zkLeftTemplate.isEmpty) &&
          (zkRightTemplate == null || zkRightTemplate.isEmpty) &&
          (futLeftTemplate == null || futLeftTemplate.isEmpty) &&
          (futRightTemplate == null || futRightTemplate.isEmpty)) {
        _showError(
            'Learner has no fingerprint registered. Please enroll fingerprint first.');
        setState(() => _isVerifyingFingerprint = false);
        return;
      }

      // Step 2: Detect which scanner is available
      // PRIORITY: Check Futronic first if learner has Futronic templates
      print('[FINGERPRINT_SIG] Detecting scanner...');
      String scanner = 'none';

      // Try Futronic first if learner has Futronic templates
      if ((futLeftTemplate != null && futLeftTemplate.isNotEmpty) ||
          (futRightTemplate != null && futRightTemplate.isNotEmpty)) {
        try {
          final isFutConnected = await _futronicService.isFutronicConnected();
          if (isFutConnected) {
            scanner = 'futronic';
            print('[FINGERPRINT_SIG] ✅ Using Futronic scanner (priority)');
          }
        } catch (e) {
          print('[FINGERPRINT_SIG] Futronic check failed: $e');
        }
      }

      // Try ZKTeco as fallback if learner has ZKTeco templates
      if (scanner == 'none' &&
          ((zkLeftTemplate != null && zkLeftTemplate.isNotEmpty) ||
              (zkRightTemplate != null && zkRightTemplate.isNotEmpty))) {
        try {
          final isZkConnected = await _fingerprintService.isSensorConnected();
          if (isZkConnected) {
            scanner = 'zkteco';
            print('[FINGERPRINT_SIG] ✅ Using ZKTeco scanner (fallback)');
          }
        } catch (e) {
          print('[FINGERPRINT_SIG] ZKTeco check failed: $e');
        }
      }

      if (scanner == 'none') {
        _showError(
            'No fingerprint scanner detected or learner has no templates enrolled for available scanner.');
        setState(() => _isVerifyingFingerprint = false);
        return;
      }

      // Step 3: Show scanning dialog
      _showScanningDialog();

      // Step 4: Perform fingerprint verification based on scanner type
      bool matched = false;
      String matchedTemplate = '';

      try {
        if (scanner == 'futronic') {
          print('[FINGERPRINT_SIG] Attempting Futronic verification...');
          final hint = (futLeftTemplate != null && futLeftTemplate.isNotEmpty)
              ? 'left'
              : 'right';
          matched = await _futronicService.verifyBoth(
            hintFinger: hint,
            leftTemplate: futLeftTemplate,
            rightTemplate: futRightTemplate,
          );
          if (matched) {
            matchedTemplate = futLeftTemplate ?? futRightTemplate ?? '';
          }
        } else if (scanner == 'zkteco') {
          print('[FINGERPRINT_SIG] Attempting ZKTeco verification...');
          if (zkLeftTemplate != null && zkLeftTemplate.isNotEmpty) {
            matched = await _fingerprintService.verify('left', zkLeftTemplate);
            if (matched) matchedTemplate = zkLeftTemplate;
          }
          if (!matched &&
              zkRightTemplate != null &&
              zkRightTemplate.isNotEmpty) {
            matched =
                await _fingerprintService.verify('right', zkRightTemplate);
            if (matched) matchedTemplate = zkRightTemplate;
          }
        }
      } catch (e) {
        print('[FINGERPRINT_SIG] Verification error: $e');
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(); // Close scanning dialog
        }

        // Provide user-friendly error messages
        String errorMessage = 'Fingerprint verification failed';
        if (e.toString().contains('USB_OPEN_FAILED') ||
            e.toString().contains('DEVICE_OPEN_FAILED')) {
          errorMessage =
              'Scanner connection failed. Please check USB connection and try again.';
        } else if (e.toString().contains('CAPTURE_FAILED')) {
          errorMessage =
              'Could not capture fingerprint. Please place finger firmly on scanner and try again.';
        } else if (e.toString().contains('TIMEOUT') ||
            e.toString().contains('Timeout')) {
          errorMessage = 'Timeout waiting for fingerprint. Please try again.';
        } else {
          errorMessage = 'Fingerprint verification failed: ${e.toString()}';
        }

        _showError(errorMessage);
        setState(() => _isVerifyingFingerprint = false);
        return;
      }

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(); // Close scanning dialog
      }

      if (!matched) {
        _showError('Fingerprint does not match learner profile');
        setState(() => _isVerifyingFingerprint = false);
        return;
      }

      // Step 5: Fingerprint matched - call backend to get signature
      print(
          '[FINGERPRINT_SIG] Fingerprint matched! Fetching signature from backend...');

      final response = await http
          .post(
            Uri.parse(AppConfig.verifyFingerprintSignatureUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'learnerID': widget.learnerID,
              'scannedTemplate': matchedTemplate,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      print(
          '[FINGERPRINT_SIG] Backend response: ${response.statusCode} - ${data['status']}');

      if (response.statusCode == 200 && data['verified'] == true) {
        // Success - fingerprint matched
        setState(() {
          _candidateSignature = data['signature'];
          _candidateSignatureName = data['learnerName'];
          if (data['signature'] != null) {
            _candidateSignatureController.text =
                'Verified: ${data['learnerName']}';
          }
        });

        _showSuccess('✓ Fingerprint verified: ${data['learnerName']}');

        if (data['signature'] == null) {
          _showInfo('Learner verified but no signature image on file');
        }
      } else {
        // Failed - fingerprint didn't match or error
        _showError(data['message'] ?? 'Fingerprint verification failed');
      }
    } catch (e) {
      print('[FINGERPRINT_SIG] Error: $e');
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(); // Close dialog if still open
      }
      _showError('Error during fingerprint verification: $e');
    } finally {
      setState(() => _isVerifyingFingerprint = false);
    }
  }

  void _showScanningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Place finger on scanner...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Text(
                'Verifying candidate identity',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF006341),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // APPENDIX J: CANDIDATE PRE-ASSESSMENT AGREEMENT (EDITABLE)
  // ══════════════════════════════════════════════════════════
  Widget _buildAppendixJ() {
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
                  'Appendix J: PRE-ASSESSMENT AGREEMENT',
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
          const SizedBox(height: 16),
          _buildTradeTitleBanner(tradeName),
          const SizedBox(height: 16),

          // Agreement Text
          Card(
            color: Colors.blue[50],
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CANDIDATE PRE-ASSESSMENT AGREEMENT',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  Divider(height: 24),
                  Text(
                    'This agreement confirms that the ARPL candidate understands and consents to the assessment process, procedures, and requirements.',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Please read each statement carefully and confirm your understanding by checking the boxes below.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Candidate Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Candidate Information',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  _InfoRow('Name', _toolkitData!.learner?.fullName ?? 'N/A'),
                  _InfoRow(
                      'ID Number', _toolkitData!.learner?.idNumber ?? 'N/A'),
                  _InfoRow('Trade',
                      '${_getTradeName(widget.ofoNumber)} (${widget.ofoNumber})'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Acknowledgments
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Candidate Acknowledgments',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'I, the candidate, acknowledge and confirm the following:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  if (_isEditing) ...[
                    CheckboxListTile(
                      title: const Text('Understanding of ARPL Process'),
                      subtitle: const Text(
                          'I understand the Recognition of Prior Learning (ARPL) process and assessment procedures'),
                      value: false, // TODO: Add state
                      onChanged: (val) {},
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const Divider(),
                    CheckboxListTile(
                      title: const Text('Consent to Assessment'),
                      subtitle: const Text(
                          'I consent to undergo assessment through knowledge tests, practical demonstrations, and workplace evaluations'),
                      value: false,
                      onChanged: (val) {},
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const Divider(),
                    CheckboxListTile(
                      title: const Text('Right to Appeal'),
                      subtitle: const Text(
                          'I understand my rights to appeal any assessment decision I believe to be unfair'),
                      value: false,
                      onChanged: (val) {},
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const Divider(),
                    CheckboxListTile(
                      title: const Text('Accuracy of Information'),
                      subtitle: const Text(
                          'I confirm that all information provided in this application and supporting documents is true and accurate'),
                      value: false,
                      onChanged: (val) {},
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const Divider(),
                    CheckboxListTile(
                      title: const Text('Assessment Criteria'),
                      subtitle: const Text(
                          'I understand the assessment criteria and requirements for the trade qualification'),
                      value: false,
                      onChanged: (val) {},
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const Divider(),
                    CheckboxListTile(
                      title: const Text('Agreement to Terms'),
                      subtitle: const Text(
                          'I agree to comply with all policies, procedures, and code of conduct during the assessment process'),
                      value: false,
                      onChanged: (val) {},
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ] else
                    const Text('Agreement not signed yet',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Signatures
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Signatures',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341)),
                  ),
                  const Divider(height: 24),
                  if (_isEditing) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Candidate:',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isVerifyingFingerprint
                              ? null
                              : _verifyFingerprintAndFillSignature,
                          icon: _isVerifyingFingerprint
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.fingerprint),
                          label: Text(_isVerifyingFingerprint
                              ? 'Verifying...'
                              : 'Verify Fingerprint'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006341),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _candidateSignatureController,
                      decoration: InputDecoration(
                        labelText: 'Candidate Signature',
                        hintText: 'Type full name or verify with fingerprint',
                        border: const OutlineInputBorder(),
                        suffixIcon: _candidateSignatureName != null
                            ? const Icon(Icons.verified, color: Colors.green)
                            : null,
                      ),
                      enabled: !_isVerifyingFingerprint,
                    ),
                    if (_candidateSignatureName != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Verified: $_candidateSignatureName',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_candidateSignature != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Signature Image:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Image.memory(
                              base64Decode(_candidateSignature!
                                  .replaceAll('data:image/png;base64,', '')
                                  .replaceAll('data:image/jpeg;base64,', '')),
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      controller: _candidateDateController,
                    ),
                    const SizedBox(height: 24),
                    const Text('Witness:',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Witness Name',
                        hintText: 'Full name of witness',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Witness Signature',
                        hintText: 'Type full name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else
                    const Text('Not signed yet',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Important Notice
          Card(
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'By signing this agreement, you acknowledge that you have read, understood, and agree to all the terms and conditions of the ARPL assessment process.',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// HELPER STATIC CLASSES FOR APPENDIX F TABLE CELLS
// ══════════════════════════════════════════════════════════

/// Header cell widget for table headers
class _HeaderCell extends StatelessWidget {
  final String text;

  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF006341),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Plain cell widget for displaying text
class _PlainCell extends StatelessWidget {
  final String text;

  const _PlainCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Input cell widget for editable fields
class _InputCell extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;

  const _InputCell(this.hintText, [this.controller]);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}
