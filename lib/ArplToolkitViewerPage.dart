import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'models/arpl_toolkit_data.dart';

class ArplToolkitViewerPage extends StatefulWidget {
  final int learnerID;
  final int classID;
  final String ofoNumber;

  const ArplToolkitViewerPage({
    Key? key,
    required this.learnerID,
    required this.classID,
    this.ofoNumber = '671101',
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

  // Appendix B controllers (for each activity rating)
  final Map<int, int> _appendixBRatings = {};
  final Map<int, TextEditingController> _appendixBComments = {};

  // Appendix D controllers (for yes/no responses)
  final Map<String, String> _appendixDResponses = {};

  // Appendix E controllers
  final Map<int, int> _appendixERatings = {};
  final Map<int, TextEditingController> _appendixEComments = {};

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
  }

  Future<void> _saveAllChanges() async {
    if (_toolkitData == null) return;

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

      // Send all data to server
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/save_arpl_toolkit_edits.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'learnerID': widget.learnerID,
          'classID': widget.classID,
          'ofoNumber': widget.ofoNumber,
          'appendixB': appendixBData,
          'appendixD': appendixDData,
          'appendixE': appendixEData,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
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

          // Reload data
          await _loadToolkitData();
        } else {
          throw Exception(data['message'] ?? 'Save failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
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
                  Tab(text: 'Appx F'),
                  Tab(text: 'Appx G'),
                  Tab(text: 'Appx H'),
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
        _buildAppendixF(),
        _buildAppendixG(),
        _buildAppendixH(),
        _buildAppendixI(),
        _buildAppendixJ(),
      ],
    );
  }

  Widget _buildCoverPage() {
    final learner = _toolkitData!.learner;
    final classInfo = _toolkitData!.classInfo;

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
              'Electrician (OFO ${widget.ofoNumber})',
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
    final appendixH = _toolkitData!.appendixH;
    final items = appendixH.items;
    final recommendations = appendixH.recommendations;
    final gapStandards = appendixH.gapStandards;
    final tradeName = _getTradeName(widget.ofoNumber);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appendix H: ACCESS RECOMMENDATION',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF006341),
            ),
          ),
          const SizedBox(height: 16),
          _buildTradeTitleBanner(tradeName),
          const SizedBox(height: 16),

          // Show Assessment Items
          if (items.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assessment Components',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006341),
                      ),
                    ),
                    const Divider(height: 24),
                    ...items.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text('$index. ${item.assessmentType}'),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Show Recommendations
          if (recommendations.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No access recommendation saved yet.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            )
          else ...[
            ...recommendations.map((rec) {
              final isReady = rec.status.toLowerCase().contains('ready') ||
                  rec.status.toLowerCase().contains('recommended');

              return Card(
                color: isReady ? const Color(0xFFE8F5E9) : Colors.amber[50],
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isReady ? Icons.check_circle : Icons.warning_amber,
                            color: isReady
                                ? const Color(0xFF006341)
                                : Colors.orange[700],
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rec.status,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isReady
                                    ? const Color(0xFF006341)
                                    : Colors.orange[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (rec.remarks.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Remarks:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rec.remarks,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF006341),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Assessment Component: ${_getAssessmentTypeName(rec.acrId, items)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        'Date: ${rec.updatedAt.isNotEmpty ? rec.updatedAt : rec.createdAt}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),

            // Show final decision based on all recommendations
            _buildFinalDecision(recommendations),
          ],

          // Show Gap Standards if any
          if (gapStandards.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.amber[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber,
                            color: Colors.orange[700], size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Gap Closure Required',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The following unit standards require completion:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ...gapStandards.map((gs) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            '• ${gs.unitStandardId}: ${gs.unitStandardName ?? "N/A"}',
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
                  _InfoRow('Trade Title', 'Plumber'),
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
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Candidate Signature',
                        hintText: 'Type full name',
                        border: OutlineInputBorder(),
                      ),
                    ),
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
                  _InfoRow('Qualification', 'Plumber'),
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

  /// Get trade name from OFO number
  String _getTradeName(String ofoNumber) {
    const tradeMappings = {
      '671101': 'Electrician',
      '671102': 'Plumber',
      '671103': 'Bricklayer',
      '671104': 'Carpenter',
      '671105': 'Welder',
    };
    return tradeMappings[ofoNumber] ?? 'Trade Specialist';
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
  // APPENDIX F: ASSESSMENT EVALUATION AGREEMENT
  // ══════════════════════════════════════════════════════════
  // APPENDIX F: ASSESSMENT EVALUATION AGREEMENT
  // ══════════════════════════════════════════════════════════
  Widget _buildAppendixF() {
    final tradeName = _getTradeName(widget.ofoNumber);

    // Electrician tasks for workplace observation (13 exact names)
    const workplaceActivities = [
      'Wire ways and wiring',
      'Installing wiring and connecting electrical equipment',
      'Electrical supply systems and components',
      'Installing, wiring and connecting electrical equipment and control systems',
      'Installing, wiring and connecting electrical equipment and control systems',
      'Carrying out commissioning tests',
      'Batteries',
      'Work with electrical and fluid power components',
      'DC motors',
      'AC motors',
      'Transformers',
      'Faultfinding techniques for electrical circuits',
      'Carrying out commissioning tests',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Title
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

          // Subtitle
          const Center(
            child: Text(
              'ASSESSMENT EVALUATION AGREEMENT (knowledge, practical skills and verifiable workplace)',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // Trade Title Banner
          _buildTradeTitleBanner(tradeName),
          const SizedBox(height: 24),

          // Knowledge Section
          _buildKnowledgeSection(),
          const SizedBox(height: 24),

          // Practical Section
          _buildPracticalSection(),
          const SizedBox(height: 24),

          // Workplace Observation Section
          _buildWorkplaceObservation(workplaceActivities),
          const SizedBox(height: 24),

          // Observation Evaluation and Sign-Off Section
          _buildObservationEvaluationAndSignOff(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // HELPER METHODS FOR APPENDIX F SECTIONS
  // ══════════════════════════════════════════════════════════

  /// Build Knowledge Section - 8 empty questions with text fields
  Widget _buildKnowledgeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KNOWLEDGE SECTION (8 Questions)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006341),
              ),
            ),
            const SizedBox(height: 16),
            _buildBorderedTable(
              columnWidths: {0: 50, 1: 250, 2: 80, 3: 80},
              headerRow: [
                _HeaderCell('No'),
                _HeaderCell('Questions'),
                _HeaderCell('Candidate Score'),
                _HeaderCell('Percentage (%)'),
              ],
              dataRows: List.generate(
                8,
                (index) => [
                  _PlainCell((index + 1).toString()),
                  _InputCell(''),
                  _InputCell(''),
                  _InputCell(''),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Practical Section - 13 empty tasks with text fields
  Widget _buildPracticalSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PRACTICAL SECTION (13 Tasks)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006341),
              ),
            ),
            const SizedBox(height: 16),
            _buildBorderedTable(
              columnWidths: {0: 50, 1: 250, 2: 80, 3: 80},
              headerRow: [
                _HeaderCell('No'),
                _HeaderCell('Tasks'),
                _HeaderCell('Score'),
                _HeaderCell('Percentage (%)'),
              ],
              dataRows: List.generate(
                13,
                (index) => [
                  _PlainCell((index + 1).toString()),
                  _InputCell(''),
                  _InputCell(''),
                  _InputCell(''),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSignatureDateRow('Assessor'),
          ],
        ),
      ),
    );
  }

  /// Build Workplace Observation Section - 13 activities with horizontal scrolling
  Widget _buildWorkplaceObservation(List<String> activities) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WORKPLACE OBSERVATION (13 Electrical Activities)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006341),
              ),
            ),
            const SizedBox(height: 16),
            _buildBorderedTable(
              columnWidths: {0: 50, 1: 220, 2: 120, 3: 120, 4: 120},
              headerRow: [
                _HeaderCell('No'),
                _HeaderCell('Tasks Observed'),
                _HeaderCell('Technical\nKnowledge'),
                _HeaderCell('Interpretation'),
                _HeaderCell('Team Work'),
              ],
              dataRows: List.generate(
                activities.length,
                (index) => [
                  _PlainCell((index + 1).toString()),
                  _PlainCell(activities[index]),
                  _InputCell(''),
                  _InputCell(''),
                  _InputCell(''),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Observation Evaluation and Sign-Off Section
  Widget _buildObservationEvaluationAndSignOff() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OBSERVATION EVALUATION AND SIGN-OFF',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006341),
              ),
            ),
            const Divider(height: 24),

            // Scoring Guide
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scoring Guide:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Fair: 1', style: TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        child: Text('Good: 2', style: TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        child: Text('Excellent: 3',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            // Assessor Signature Section
            _buildSignatureDateRow('Assessor'),
            const SizedBox(height: 20),

            // Candidate Signature Section
            _buildSignatureDateRow('Candidate'),
            const SizedBox(height: 20),

            // Witness Signature Section
            _buildSignatureDateRow('Witness'),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // HELPER METHODS FOR APPENDIX F - REMOVED OLD STATIC METHODS
  // (Now using Widget classes defined at end of file)
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
  Widget _buildSignatureDateRow(String role) {
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
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'ARPL Candidate Signature',
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
                  _InfoRow('Qualification Title', 'Plumber'),
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
                  _InfoRow('Trade', 'Plumber (${widget.ofoNumber})'),
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
                    const Text('Candidate:',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Candidate Signature',
                        hintText: 'Type full name',
                        border: OutlineInputBorder(),
                      ),
                    ),
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

  const _InputCell(this.hintText);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: TextField(
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
