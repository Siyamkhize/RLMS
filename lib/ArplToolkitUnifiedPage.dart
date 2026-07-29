import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'models/arpl_toolkit_data.dart';

/// Unified ARPL Toolkit Page for ALL trades (Electrician, Bricklayer, Plumber)
/// Uses the same UI/UX structure for all trades
/// Data is fetched from trade-specific endpoints but rendered with unified UI

class ArplToolkitUnifiedPage extends StatefulWidget {
  final int learnerID;
  final int classID;
  final String ofoNumber;

  const ArplToolkitUnifiedPage({
    Key? key,
    required this.learnerID,
    required this.classID,
    required this.ofoNumber,
  }) : super(key: key);

  @override
  _ArplToolkitUnifiedPageState createState() => _ArplToolkitUnifiedPageState();
}

class _ArplToolkitUnifiedPageState extends State<ArplToolkitUnifiedPage>
    with SingleTickerProviderStateMixin {
  ArplToolkitData? _toolkitData;
  bool _isLoading = true;
  String? _errorMessage;
  TabController? _tabController;
  bool _isEditing = false;
  bool _isSaving = false;

  // Form controllers for editable fields
  final TextEditingController _tradeSpecializationController =
      TextEditingController();

  // Appendix B controllers
  final Map<int, int> _appendixBRatings = {};
  final Map<int, TextEditingController> _appendixBComments = {};

  // Appendix D controllers
  final Map<String, String> _appendixDResponses = {};

  // Appendix E controllers
  final Map<int, int> _appendixERatings = {};
  final Map<int, TextEditingController> _appendixEComments = {};

  // Appendix F controllers - Practical section
  final List<TextEditingController> _practicalTasks =
      List.generate(13, (_) => TextEditingController());
  final List<TextEditingController> _practicalScores =
      List.generate(13, (_) => TextEditingController());
  final List<TextEditingController> _practicalPercentages =
      List.generate(13, (_) => TextEditingController());

  // Appendix F controllers - Workplace observation
  final List<TextEditingController> _workplaceObservationTechKnowledge =
      List.generate(13, (_) => TextEditingController());
  final List<TextEditingController> _workplaceObservationInterpretation =
      List.generate(13, (_) => TextEditingController());
  final List<TextEditingController> _workplaceObservationTeamWork =
      List.generate(13, (_) => TextEditingController());

  // Appendix F controllers - Sign-off
  final TextEditingController _assessorSignatureDate = TextEditingController();
  final TextEditingController _candidateSignatureDate = TextEditingController();
  final TextEditingController _witnessSignatureDate = TextEditingController();

  String _getTradeName() {
    switch (widget.ofoNumber) {
      case '671101':
        return 'Electrician';
      case '642601':
        return 'Plumber';
      case '641201':
        return 'Bricklayer';
      default:
        return 'Unknown';
    }
  }

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
      // Determine which endpoint to call based on trade
      String endpointUrl;
      switch (widget.ofoNumber) {
        case '671101':
          endpointUrl = AppConfig.getArplToolkitDataUrl; // Electrician
          break;
        case '642601':
          endpointUrl = AppConfig.getPlumberToolkitDataUrl; // Plumber
          break;
        case '641201':
          endpointUrl = AppConfig.getBricklayerToolkitDataUrl; // Bricklayer
          break;
        default:
          endpointUrl = AppConfig.getArplToolkitDataUrl;
      }

      print('[TOOLKIT_DEBUG] Loading data from: $endpointUrl');
      print(
          '[TOOLKIT_DEBUG] Trade: ${_getTradeName()}, OFO: ${widget.ofoNumber}');

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
        print('[TOOLKIT_DEBUG] API Response status: ${data['status']}');

        if (data['status'] == 'success') {
          try {
            setState(() {
              _toolkitData = ArplToolkitData.fromJson(data);
              _isLoading = false;
              _populateControllers();
            });
            print('[TOOLKIT_DEBUG] Data loaded successfully');
          } catch (parseError) {
            print('[TOOLKIT_ERROR] Parse error: $parseError');
            setState(() {
              _errorMessage = 'Error parsing data: $parseError';
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

  void _populateControllers() {
    if (_toolkitData == null) return;

    // Populate Appendix B
    for (var rating in _toolkitData!.appendixB) {
      if (rating.hasRating) {
        _appendixBRatings[rating.activityId] = rating.competencyScaleId;
        _appendixBComments[rating.activityId] =
            TextEditingController(text: rating.comments);
      } else {
        _appendixBComments[rating.activityId] = TextEditingController();
      }
    }

    // Populate Appendix D
    _appendixDResponses.addAll(_toolkitData!.appendixD);

    // Populate Appendix E
    for (var rating in _toolkitData!.appendixE) {
      if (rating.hasRating) {
        _appendixERatings[rating.activityId] = rating.competencyScaleId;
        _appendixEComments[rating.activityId] =
            TextEditingController(text: rating.comments);
      } else {
        _appendixEComments[rating.activityId] = TextEditingController();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ARPL Toolkit - ${_getTradeName()}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        bottom: _isLoading
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Cover'),
                  Tab(text: 'App. A'),
                  Tab(text: 'App. B'),
                  Tab(text: 'App. C'),
                  Tab(text: 'App. D'),
                  Tab(text: 'App. E'),
                  Tab(text: 'App. F'),
                  Tab(text: 'App. G'),
                  Tab(text: 'App. H'),
                  Tab(text: 'App. I'),
                  Tab(text: 'App. J'),
                ],
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Error',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadToolkitData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 0: Cover Page
                    _buildCoverPage(),
                    // Tab 1: Appendix A
                    _buildAppendixAPage(),
                    // Tab 2: Appendix B (Theory)
                    _buildAppendixBPage(),
                    // Tab 3: Appendix C (Curriculum)
                    _buildAppendixCPage(),
                    // Tab 4: Appendix D (Practical Yes/No)
                    _buildAppendixDPage(),
                    // Tab 5: Appendix E (Workplace Experience)
                    _buildAppendixEPage(),
                    // Tab 6: Appendix F (Practical Assessment)
                    _buildAppendixFPage(),
                    // Tab 7: Appendix G (Appeals)
                    _buildAppendixGPage(),
                    // Tab 8: Appendix H (Access Recommendation)
                    _buildAppendixHPage(),
                    // Tab 9: Appendix I (Statement of Results)
                    _buildAppendixIPage(),
                    // Tab 10: Appendix J (Pre-Assessment Agreement)
                    _buildAppendixJPage(),
                  ],
                ),
    );
  }

  Widget _buildCoverPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ARPL Assessment Toolkit - ${_getTradeName()}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text('Trade: ${_getTradeName()}'),
                  Text('OFO Number: ${widget.ofoNumber}'),
                  if (_toolkitData?.learner != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Learner: ${_toolkitData!.learner!.fullName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('ID: ${_toolkitData!.learner!.idNumber}'),
                  ],
                  if (_toolkitData?.classInfo != null) ...[
                    const SizedBox(height: 12),
                    Text('Class: ${_toolkitData!.classInfo!.className}'),
                    Text('Site: ${_toolkitData!.classInfo!.siteName}'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppendixAPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        _toolkitData?.appendixA != null
            ? 'Appendix A data available'
            : 'No Appendix A data',
      ),
    );
  }

  Widget _buildAppendixBPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Theory Assessment - ${_toolkitData?.appendixB.length ?? 0} activities',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (_toolkitData?.appendixB.isNotEmpty ?? false)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _toolkitData!.appendixB.length,
              itemBuilder: (context, index) {
                final activity = _toolkitData!.appendixB[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.activityName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Rating: ${activity.competencyScaleId}/5'),
                        if (activity.comments.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Comments: ${activity.comments}'),
                        ],
                      ],
                    ),
                  ),
                );
              },
            )
          else
            const Text('No Appendix B activities found'),
        ],
      ),
    );
  }

  Widget _buildAppendixCPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        _toolkitData?.appendixC != null
            ? 'Appendix C data available'
            : 'No Appendix C data',
      ),
    );
  }

  Widget _buildAppendixDPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Practical Skills Assessment',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (_appendixDResponses.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _appendixDResponses.length,
              itemBuilder: (context, index) {
                final entries = _appendixDResponses.entries.toList();
                final key = entries[index].key;
                final value = entries[index].value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(key)),
                        Text(
                          value,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            const Text('No Appendix D responses found'),
        ],
      ),
    );
  }

  Widget _buildAppendixEPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Workplace Experience - ${_toolkitData?.appendixE.length ?? 0} activities',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (_toolkitData?.appendixE.isNotEmpty ?? false)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _toolkitData!.appendixE.length,
              itemBuilder: (context, index) {
                final activity = _toolkitData!.appendixE[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.activityName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Rating: ${activity.competencyScaleId}/5'),
                        if (activity.comments.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Comments: ${activity.comments}'),
                        ],
                      ],
                    ),
                  ),
                );
              },
            )
          else
            const Text('No Appendix E activities found'),
        ],
      ),
    );
  }

  Widget _buildAppendixFPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        _toolkitData?.appendixF != null
            ? 'Appendix F - Practical Assessment available'
            : 'No Appendix F data',
      ),
    );
  }

  Widget _buildAppendixGPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        _toolkitData?.appendixG != null
            ? 'Appendix G - Appeals data available'
            : 'No Appendix G data',
      ),
    );
  }

  Widget _buildAppendixHPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Access Recommendation',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (_toolkitData?.appendixH.items.isNotEmpty ?? false)
            Text('ACR Items: ${_toolkitData!.appendixH.items.length}')
          else
            const Text('No ACR items found'),
        ],
      ),
    );
  }

  Widget _buildAppendixIPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        _toolkitData?.appendixI != null
            ? 'Appendix I - Statement of Results data available'
            : 'No Appendix I data',
      ),
    );
  }

  Widget _buildAppendixJPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        _toolkitData?.appendixJ != null
            ? 'Appendix J - Pre-Assessment Agreement data available'
            : 'No Appendix J data',
      ),
    );
  }
}
