import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';
import 'CameraScanPage.dart';
import 'services/fingerprint_service.dart';
import 'config.dart';

class ArplHierarchicalNavigatorPage extends StatefulWidget {
  final String? classId;
  final String? learnerId;

  const ArplHierarchicalNavigatorPage({
    super.key,
    this.classId,
    this.learnerId,
  });

  @override
  State<ArplHierarchicalNavigatorPage> createState() =>
      _ArplHierarchicalNavigatorPageState();
}

class _ArplHierarchicalNavigatorPageState
    extends State<ArplHierarchicalNavigatorPage> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? arplData;

  // Trade information
  String tradeName = 'ARPL'; // Default fallback
  bool isLoadingTrade = true;

  // Navigation state
  int currentStep = 0;
  String? selectedPathway;
  String? selectedTrade;
  String? selectedSection; // theory or practical
  String? selectedPaper;

  // Upload state
  Map<String, bool> uploadedExercises = {};
  int unsyncedCount = 0;
  bool isSyncing = false;

  final FingerprintService _fingerprintService = FingerprintService();
  final FutronicService _futronicService = FutronicService();

  @override
  void initState() {
    super.initState();
    if (widget.learnerId == null || widget.learnerId!.isEmpty) {
      setState(() {
        errorMessage = 'Learner ID is required';
        isLoading = false;
      });
      return;
    }

    // Fetch trade information if classId is provided
    if (widget.classId != null && widget.classId!.isNotEmpty) {
      _fetchTradeInfo();
    }

    fetchArplData().then((_) {
      print('fetchArplData complete');
    }).catchError((e) {
      print('Error in fetchArplData: $e');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUploadStatus();
    });
  }

  /// Fetch trade information from class
  Future<void> _fetchTradeInfo() async {
    if (widget.classId == null || widget.classId!.isEmpty) {
      setState(() {
        isLoadingTrade = false;
      });
      return;
    }

    try {
      final url = AppConfig.buildUrl('get_class_trade_info.php', queryParams: {
        'classID': widget.classId!,
      });

      debugPrint(
          '[ARPL_TRADE] Fetching trade info for classID: ${widget.classId}');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          setState(() {
            tradeName = data['trade_name'] ?? 'ARPL';
            isLoadingTrade = false;
          });
          debugPrint('[ARPL_TRADE] ✅ Trade name: $tradeName');
        } else {
          debugPrint('[ARPL_TRADE] ❌ Error: ${data['message']}');
          setState(() {
            isLoadingTrade = false;
          });
        }
      } else {
        debugPrint('[ARPL_TRADE] ❌ HTTP error: ${response.statusCode}');
        setState(() {
          isLoadingTrade = false;
        });
      }
    } catch (e) {
      debugPrint('[ARPL_TRADE] ❌ Exception: $e');
      setState(() {
        isLoadingTrade = false;
      });
    }
  }

  Future<void> fetchArplData() async {
    try {
      final url = AppConfig.buildUrl('get_arpl_hierarchy.php', queryParams: {
        'learner_id': widget.learnerId!,
      });

      debugPrint('🔍 ARPL API URL: $url');

      final response = await http.get(Uri.parse(url));

      debugPrint('📡 ARPL Response Status: ${response.statusCode}');
      debugPrint('📦 ARPL Response Body Length: ${response.body.length}');
      debugPrint(
          '📦 ARPL Response First 500 chars: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint('✅ ARPL JSON Decoded Successfully');
        debugPrint('🔑 ARPL Top-level keys: ${jsonData.keys.toList()}');

        if (jsonData['pathways'] != null) {
          debugPrint(
              '📚 Pathways found: ${jsonData['pathways'].keys.toList()}');
        } else {
          debugPrint('❌ No pathways in response!');
        }

        print('ARPL DEBUG DATA: ${jsonData['_debug']}');
        setState(() {
          if (jsonData['error'] != null) {
            errorMessage = jsonData['error'];
            debugPrint('❌ API returned error: $errorMessage');
          } else {
            // Keep _debug for now, we'll print it
            arplData = jsonData;
            debugPrint('✅ arplData set successfully');
          }
          isLoading = false;
        });
        await _refreshUploadStatus();
      } else {
        debugPrint('❌ HTTP Error: ${response.statusCode}');
        setState(() {
          errorMessage = 'Server error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Exception in fetchArplData: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        errorMessage = 'Failed to load data: $e';
        isLoading = false;
      });
    }
  }

  String _uploadKey(String paperTitle, String questionNumber, String exercise) {
    final safePaper = paperTitle.replaceAll(RegExp(r'\s+'), '_');
    final safeQuestion = questionNumber.replaceAll(RegExp(r'\s+'), '_');
    return 'ARPL-$safePaper-$safeQuestion-${widget.learnerId}';
  }

  bool _isPaperUploaded(String paperTitle) {
    // Check if THIS SPECIFIC paper has already been uploaded
    // Uses paper TITLE in the key to distinguish between different papers

    final sectionType =
        selectedSection == 'theory_papers' ? 'theory' : 'practical';

    // Normalize the paper title the same way we do in _checkServerUploadStatus
    final paperTitleNormalized =
        paperTitle.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    // Key format: "ARPL-{paper_title_normalized}-{section_type}"
    final uploadKey = 'ARPL-$paperTitleNormalized-$sectionType';

    final isUploaded = uploadedExercises[uploadKey] == true;
    if (isUploaded) {
      print('Paper FOUND in uploaded: $paperTitle ($sectionType)');
    } else {
      print('Paper NOT in uploaded: $paperTitle ($sectionType)');
    }

    return isUploaded;
  }

  bool _isExerciseUploaded(
      String paperTitle, String questionNumber, String exercise) {
    final uploadKey = _uploadKey(paperTitle, questionNumber, exercise);
    final rawKey = 'ARPL-$exercise-${widget.learnerId}';

    if (uploadedExercises[uploadKey] == true ||
        uploadedExercises[rawKey] == true) {
      return true;
    }

    // Also check the raw exercise key
    if (uploadedExercises[exercise] == true) {
      return true;
    }

    return false;
  }

  Future<void> _refreshUploadStatus() async {
    try {
      final currentUploadedExercises =
          Map<String, bool>.from(uploadedExercises);
      await _updateUnsyncedCount();
      if (await _checkConnectivity()) {
        await _syncOfflineArpl();
        await _checkServerUploadStatus();
      } else {
        await _checkLocalUploadStatus();
      }
      setState(() {
        currentUploadedExercises.forEach((key, value) {
          if (value == true) {
            uploadedExercises[key] = true;
          }
        });
      });
    } catch (e) {
      print('Error refreshing upload status: $e');
    }
  }

  Future<void> _updateUnsyncedCount() async {
    try {
      final DatabaseHelper dbHelper = DatabaseHelper();
      final List<Map<String, dynamic>> unsynced =
          await dbHelper.getUnsyncedPOE(int.parse(widget.learnerId!));
      setState(() {
        unsyncedCount = unsynced.length;
      });
    } catch (e) {
      print('Error updating unsynced count: $e');
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final url = AppConfig.buildUrl('connection.php');
      final response =
          await http.head(Uri.parse(url)).timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  Future<void> _checkServerUploadStatus() async {
    try {
      // Call the new ARPL-specific endpoint that queries the arpl_poe table
      final url =
          AppConfig.buildUrl('get_arpl_upload_status.php', queryParams: {
        'learnerID': widget.learnerId!,
      });

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['uploaded_papers'] != null) {
          setState(() {
            uploadedExercises.clear();

            // Process each uploaded paper from the arpl_poe table
            for (var paper in data['uploaded_papers']) {
              // Create SPECIFIC keys using paper TITLE to distinguish between different papers
              // This prevents marking ALL papers as uploaded
              final paperTitleNormalized = (paper['paper_title'] as String)
                  .toLowerCase()
                  .replaceAll(RegExp(r'\s+'), '');
              final sectionType = paper['section_type'] as String;

              // Key format: "ARPL-{paper_title_normalized}-{section_type}"
              final uploadKey = 'ARPL-$paperTitleNormalized-$sectionType';
              uploadedExercises[uploadKey] = true;

              print(
                  'ARPL paper marked uploaded: ${paper['paper_title']} ($sectionType)');
            }
          });

          print(
              'ARPL upload status loaded: ${uploadedExercises.length} papers');
        }
      }
    } catch (e) {
      print('Error checking ARPL server upload status: $e');
    }
  }

  Future<void> _checkLocalUploadStatus() async {
    try {
      final DatabaseHelper dbHelper = DatabaseHelper();
      final localUploads =
          await dbHelper.getLocalUploadStatus(widget.learnerId!);
      setState(() {
        uploadedExercises = localUploads;
      });
      print('Local uploadedExercises: $uploadedExercises');
    } catch (e) {
      setState(() {
        errorMessage = 'Error checking local upload status: $e';
      });
      print('Error checking local upload status: $e');
    }
  }

  Future<void> _syncOfflineArpl() async {
    if (isSyncing) return;

    setState(() {
      isSyncing = true;
    });

    try {
      final DatabaseHelper dbHelper = DatabaseHelper();
      final List<Map<String, dynamic>> unsyncedPOE =
          await dbHelper.getUnsyncedPOE(int.parse(widget.learnerId!));

      if (unsyncedPOE.isEmpty) {
        setState(() {
          isSyncing = false;
          unsyncedCount = 0;
        });
        return;
      }

      int successCount = 0;
      int failCount = 0;

      for (var poe in unsyncedPOE) {
        final id = poe['poe_id'] ?? poe['id'] as int;
        final type = poe['type'] as String;
        final exercise = poe['exercise'] as String;
        final filePath = poe['filePath'] as String;
        final logbookText = poe['logbook_text'] as String?;

        final file = File(filePath);
        if (!await file.exists()) {
          failCount++;
          continue;
        }

        try {
          final url = Uri.parse(AppConfig.buildUrl(
              type == 'ARPL' ? 'arpl_save_metadata.php' : 'save_metadata.php'));
          var request = http.MultipartRequest('POST', url)
            ..fields['learnerID'] = widget.learnerId.toString()
            ..fields['exercise'] = exercise
            ..fields['type'] = type;

          if (logbookText != null) {
            request.fields['logbook_text'] = logbookText;
          }

          request.files
              .add(await http.MultipartFile.fromPath('files[]', filePath));

          final response = await request.send().timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw Exception('Upload timeout'));

          final responseBody = await response.stream.bytesToString();
          final decoded = json.decode(responseBody);

          if (decoded['status'] == 'success') {
            await dbHelper.markPOEAsSynced(id);
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          failCount++;
        }
      }

      await _updateUnsyncedCount();

      if (successCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Synced $successCount record(s) to server'),
          backgroundColor: Colors.green,
        ));
      }

      if (failCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠️ $failCount record(s) failed to sync'),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      print('Error during sync: $e');
    } finally {
      setState(() {
        isSyncing = false;
      });
    }
  }

  Future<void> _scanAndUploadQuestion({
    required String tradeName,
    required String sectionType,
    required String paperTitle,
    required String questionNumber,
    required String exerciseText,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScanPage(
          type: 'ARPL',
          exercise: exerciseText,
          unitStandard: tradeName,
          learnerID: int.parse(widget.learnerId!),
        ),
      ),
    );

    if (result != null && mounted) {
      final file = result['image'] as File?;
      if (file != null) {
        final dbHelper = DatabaseHelper();

        await dbHelper.saveManualMarkToLocalPoe(
          int.parse(widget.learnerId!),
          'ARPL',
          exerciseText,
          file.path,
          unitStandard: tradeName,
        );

        setState(() {
          // Add both raw key and uploadKey to ensure it's marked as uploaded
          final uploadKey =
              _uploadKey(paperTitle, questionNumber, exerciseText);
          uploadedExercises[uploadKey] = true;
          final rawKey = 'ARPL-$exerciseText-${widget.learnerId}';
          uploadedExercises[rawKey] = true;
        });

        await _refreshUploadStatus();

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Question uploaded successfully!'),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$tradeName Portfolio'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (unsyncedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Stack(
                  children: [
                    const Icon(Icons.cloud_off),
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '$unsyncedCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                )
              : _buildCurrentStep(),
    );
  }

  Widget _buildCurrentStep() {
    switch (currentStep) {
      case 0:
        return _buildPathwaySelector();
      case 1:
        return _buildTradeSelector();
      case 2:
        return _buildSectionSelector();
      case 3:
        return _buildPaperSelector();
      case 4:
        return _buildQuestionList();
      default:
        return _buildPathwaySelector();
    }
  }

  Widget _buildPathwaySelector() {
    final pathways =
        (arplData?['pathways'] as Map<String, dynamic>?)?.keys.toList() ?? [];
    return _buildListSelector(
      title: 'Select Pathway',
      items: pathways,
      onSelected: (pathway) {
        setState(() {
          selectedPathway = pathway;
          currentStep = 1;
        });
      },
      leadingIcon: Icons.school,
    );
  }

  Widget _buildTradeSelector() {
    final pathway =
        arplData?['pathways']?[selectedPathway] as Map<String, dynamic>?;
    final trades =
        (pathway?['qualifications'] as Map<String, dynamic>?)?.keys.toList() ??
            [];
    return _buildListSelector(
      title: 'Select Trade',
      items: trades,
      onSelected: (trade) {
        setState(() {
          selectedTrade = trade;
          currentStep = 2;
        });
      },
      leadingIcon: Icons.work,
      onBack: () {
        setState(() {
          currentStep = 0;
          selectedPathway = null;
        });
      },
    );
  }

  Widget _buildSectionSelector() {
    final pathway =
        arplData?['pathways']?[selectedPathway] as Map<String, dynamic>?;
    final tradeData =
        pathway?['qualifications']?[selectedTrade] as Map<String, dynamic>?;

    final sections = <Map<String, dynamic>>[];

    // Check theory papers
    if (tradeData?['theory_papers'] != null &&
        (tradeData!['theory_papers'] as Map).isNotEmpty) {
      final theoryCount = (tradeData['theory_papers'] as Map).length;
      sections.add({
        'name': 'Theory',
        'key': 'theory_papers',
        'icon': Icons.description,
        'count': theoryCount,
      });
    }

    // Check practical papers
    if (tradeData?['practical_papers'] != null &&
        (tradeData!['practical_papers'] as Map).isNotEmpty) {
      final practicalCount = (tradeData['practical_papers'] as Map).length;
      sections.add({
        'name': 'Practical',
        'key': 'practical_papers',
        'icon': Icons.build,
        'count': practicalCount,
      });
    }

    // If no sections found, show both options but indicate they're empty
    if (sections.isEmpty) {
      sections.addAll([
        {
          'name': 'Theory',
          'key': 'theory_papers',
          'icon': Icons.description,
          'count': 0
        },
        {
          'name': 'Practical',
          'key': 'practical_papers',
          'icon': Icons.build,
          'count': 0
        },
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              currentStep = 1;
              selectedTrade = null;
            });
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Section Type', style: TextStyle(fontSize: 16)),
            Text(
              'Trade: $selectedTrade',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: sections.length,
          itemBuilder: (context, index) {
            final section = sections[index];
            final count = section['count'] as int;
            final isAvailable = count > 0;

            return GestureDetector(
              onTap: isAvailable
                  ? () {
                      print(
                          '✅ Section selected: ${section['name']} (${section['key']})');
                      setState(() {
                        selectedSection = section['key'] as String;
                        currentStep = 3;
                      });
                    }
                  : null,
              child: Card(
                elevation: isAvailable ? 4 : 0,
                color: isAvailable ? Colors.white : Colors.grey.shade200,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        section['icon'] as IconData,
                        size: 48,
                        color: isAvailable
                            ? Colors.deepPurple
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        section['name'] as String,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              isAvailable ? Colors.black : Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? Colors.deepPurple.shade100
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count paper${count == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isAvailable
                                ? Colors.deepPurple.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPaperSelector() {
    final pathway =
        arplData?['pathways']?[selectedPathway] as Map<String, dynamic>?;
    final tradeData =
        pathway?['qualifications']?[selectedTrade] as Map<String, dynamic>?;
    final papersData = tradeData?[selectedSection] as Map<String, dynamic>?;
    final papers = papersData?.keys.toList() ?? [];

    // Debug logging
    print('📚 PAPER SELECTOR DEBUG:');
    print('   Selected Pathway: $selectedPathway');
    print('   Selected Trade: $selectedTrade');
    print('   Selected Section: $selectedSection');
    print('   Papers Available: ${papers.length}');
    print('   Papers List: $papers');

    if (papers.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                currentStep = 2;
                selectedSection = null;
              });
            },
          ),
          title: const Text('No Papers Available'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No papers found for this section',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Trade: $selectedTrade\nSection: $selectedSection',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              currentStep = 2;
              selectedSection = null;
            });
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Paper', style: TextStyle(fontSize: 16)),
            Text(
              '$selectedTrade - ${selectedSection == 'theory_papers' ? 'Theory' : 'Practical'}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Summary card
          Card(
            margin: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.assignment, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Papers',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${papers.length} paper${papers.length == 1 ? '' : 's'} available for upload',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      '${papers.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Papers list
          Expanded(
            child: ListView.builder(
              itemCount: papers.length,
              itemBuilder: (context, index) {
                final paper = papers[index];
                final paperData = papersData![paper] as Map<String, dynamic>?;
                final questionCount =
                    (paperData?['questions'] as List<dynamic>?)?.length ?? 0;
                final isUploaded = _isPaperUploaded(paper);

                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isUploaded
                          ? Colors.green.shade100
                          : Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isUploaded ? Icons.check_circle : Icons.description,
                      color: isUploaded
                          ? Colors.green.shade700
                          : Colors.deepPurple.shade700,
                    ),
                  ),
                  title: Text(
                    paper,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$questionCount question${questionCount == 1 ? '' : 's'}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (isUploaded)
                        Text(
                          '✅ Uploaded',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    print('✅ Paper selected: $paper');
                    setState(() {
                      selectedPaper = paper;
                      currentStep = 4;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionList() {
    final pathway =
        arplData?['pathways']?[selectedPathway] as Map<String, dynamic>?;
    final tradeData =
        pathway?['qualifications']?[selectedTrade] as Map<String, dynamic>?;
    final papersData = tradeData?[selectedSection] as Map<String, dynamic>?;

    // If we're in a specific paper, show that paper's questions
    if (selectedPaper != null) {
      final paperData = papersData?[selectedPaper] as Map<String, dynamic>?;
      final questions = paperData?['questions'] as List<dynamic>? ?? [];

      // Get un-uploaded questions
      final unUploadedQuestions = questions.where((question) {
        final questionNumber = (question['question_number'] ?? '').toString();
        final exerciseText = question['exercise'] ?? '';
        return !_isExerciseUploaded(
            selectedPaper!, questionNumber, exerciseText);
      }).toList();

      return _buildSinglePaperQuestions(
          questions, unUploadedQuestions, selectedPaper!);
    } else {
      // Show all papers with their questions grouped
      return _buildAllPapersWithQuestions(papersData ?? {});
    }
  }

  Widget _buildSinglePaperQuestions(
    List<dynamic> questions,
    List<dynamic> unUploadedQuestions,
    String paperName,
  ) {
    // If the PAPER itself is marked as uploaded, ALL questions should show as uploaded
    final paperUploaded = _isPaperUploaded(paperName);

    // Override unUploadedQuestions if paper is already uploaded
    final actualUnuploadedQuestions = paperUploaded ? [] : unUploadedQuestions;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              currentStep = 3;
              selectedPaper = null;
            });
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload Questions',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              paperName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paper info card
          Card(
            margin: const EdgeInsets.all(16),
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.assignment,
                        color: Colors.amber.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              paperName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Trade: $selectedTrade',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Questions',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '${questions.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Remaining',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '${actualUnuploadedQuestions.length}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: actualUnuploadedQuestions.isEmpty
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      if (actualUnuploadedQuestions.length == questions.length)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const Text(
                              'Not Started',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        )
                      else if (actualUnuploadedQuestions.isEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const Text(
                              'Complete',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'In Progress',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Questions list
          Expanded(
            child: questions.isEmpty
                ? const Center(child: Text('No questions found'))
                : ListView.builder(
                    itemCount: questions.length,
                    itemBuilder: (context, index) =>
                        _buildQuestionCard(questions[index]),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  actualUnuploadedQuestions.isEmpty
                      ? '✅ All questions completed!'
                      : '📤 Upload ${actualUnuploadedQuestions.length} question${actualUnuploadedQuestions.length == 1 ? '' : 's'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: actualUnuploadedQuestions.isEmpty
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: Text(
                    'Scan All Questions (${actualUnuploadedQuestions.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: actualUnuploadedQuestions.isEmpty
                      ? Colors.grey
                      : Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: actualUnuploadedQuestions.isEmpty
                    ? null
                    : () => _scanAllQuestions(actualUnuploadedQuestions),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllPapersWithQuestions(Map<String, dynamic> papersData) {
    // Group questions by paper with header
    final papersWithQuestions = <String, List<dynamic>>{};

    papersData.forEach((paperName, paperData) {
      final questions =
          (paperData as Map<String, dynamic>)['questions'] as List<dynamic>? ??
              [];
      if (questions.isNotEmpty) {
        papersWithQuestions[paperName] = questions;
      }
    });

    if (papersWithQuestions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                currentStep = 2;
                selectedSection = null;
              });
            },
          ),
          title: const Text('No Questions Available'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('No questions found in this section'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              currentStep = 3;
            });
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('All Questions by Paper',
                style: TextStyle(fontSize: 16)),
            Text(
              '$selectedTrade - ${selectedSection == 'theory_papers' ? 'Theory' : 'Practical'}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: papersWithQuestions.length,
        itemBuilder: (context, paperIndex) {
          final paperName = papersWithQuestions.keys.elementAt(paperIndex);
          final questions = papersWithQuestions[paperName]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Paper header
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.deepPurple.shade50,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${paperIndex + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paperName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.deepPurple,
                            ),
                          ),
                          Text(
                            '${questions.length} question${questions.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.assignment_outlined,
                      color: Colors.deepPurple.shade300,
                    ),
                  ],
                ),
              ),
              // Questions under this paper
              ...questions.asMap().entries.map((entry) {
                final questionIndex = entry.key;
                final question = entry.value as Map<String, dynamic>;
                return _buildQuestionCardWithPaper(
                  question,
                  paperName,
                  paperIndex + 1,
                );
              }).toList(),
              const Divider(height: 16, thickness: 2),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuestionCardWithPaper(
    Map<String, dynamic> question,
    String paperName,
    int paperNumber,
  ) {
    final questionNumber = (question['question_number'] ?? '').toString();
    final exerciseText = question['exercise'] ?? '';
    final isUploaded =
        _isExerciseUploaded(paperName, questionNumber, exerciseText);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUploaded ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isUploaded ? Colors.green : Colors.grey,
              size: 24,
            ),
          ],
        ),
        title: Text(
          'Paper $paperNumber • Q$questionNumber',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              exerciseText,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isUploaded ? '✅ Completed' : '⏳ Pending',
                  style: TextStyle(
                    fontSize: 12,
                    color: isUploaded ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Marks: ${question['marks'] ?? 0}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
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

  Future<void> _scanAllQuestions(List<dynamic> questions) async {
    // Check if all selected questions are already completed
    bool allCompleted = true;
    for (var item in questions) {
      final questionNumber = (item['question_number'] ?? '').toString();
      final exerciseText = item['exercise'] ?? '';
      if (!_isExerciseUploaded(selectedPaper!, questionNumber, exerciseText)) {
        allCompleted = false;
        break;
      }
    }

    if (allCompleted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All questions are already completed.')),
        );
      }
      return;
    }

    final imageSource = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: const Text('This will capture answers for all questions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            child: const Text('Open Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (imageSource == null) {
      print('User cancelled image selection');
      return;
    }

    File? document;

    if (imageSource == ImageSource.camera) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScanPage(
            type: 'ARPL',
            exercise: 'All Questions - $selectedPaper',
            learnerID: int.parse(widget.learnerId!),
            unitStandard: selectedTrade!,
            logbookText: null,
            autoUpload: false,
          ),
        ),
      );

      if (result == null || result is! Map) {
        print('Error: No result returned from CameraScanPage');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Camera operation was cancelled or failed')),
          );
        }
        return;
      }

      final file = result['image'] as File?;

      if (file == null || !await file.exists()) {
        print('Error: No valid file returned from CameraScanPage');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid document captured')),
          );
        }
        return;
      }

      if (!file.path.toLowerCase().endsWith('.pdf')) {
        print('Error: Expected PDF file for ARPL, got ${file.path}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Invalid file format. Expected a PDF.')),
          );
        }
        return;
      }
      document = file;
    }

    // First copy the document to the POE directory for persistence
    final appDir = await getApplicationDocumentsDirectory();
    final poeDir = Directory('${appDir.path}/POE');
    if (!poeDir.existsSync()) {
      poeDir.createSync(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safePaperName =
        selectedPaper!.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final targetFileName = 'All_Questions_${safePaperName}_ARPL_$timestamp.pdf';
    final targetFilePath = '${poeDir.path}/$targetFileName';
    final targetFile = File(targetFilePath);

    // Copy the temporary file to POE directory
    await document!.copy(targetFilePath);
    document = targetFile;
    print('Document copied to: $targetFilePath');

    // Show processing dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 15),
                  Text('Uploading document...',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('This may take a moment for large files'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      // Upload the same document for all selected questions
      bool isConnected = await _checkConnectivity();

      print('📊 ARPL UPLOAD DEBUG:');
      print('   Total questions to process: ${questions.length}');
      print('   Is connected: $isConnected');
      print('   Target file path: $targetFilePath');

      final dbHelper = DatabaseHelper();

      if (isConnected) {
        final url = Uri.parse(AppConfig.buildUrl('arpl_save_metadata.php'));

        print('Starting ARPL upload for ${questions.length} questions');

        // Send a single bulk request for all selected questions
        var request = http.MultipartRequest('POST', url)
          ..fields['learnerID'] = widget.learnerId.toString()
          ..fields['ofo_number'] = selectedTrade!
          ..fields['paper_title'] = selectedPaper!
          ..fields['paper_number'] = '1'
          ..fields['section_type'] =
              selectedSection == 'theory_papers' ? 'theory' : 'practical'
          ..fields['question_count'] = questions.length.toString()
          ..fields['type'] = 'ARPL'
          ..fields['exercises'] = json.encode(questions
              .map((item) => item['exercise']?.toString() ?? 'N/A')
              .toList());

        print(
            'Uploading single ARPL document for ${questions.length} questions: ${document.path}, Size: ${await document.length()} bytes');

        request.files.add(await http.MultipartFile.fromPath(
          'files[]',
          document.path,
          filename: targetFileName,
        ));

        try {
          final response = await request.send().timeout(
            const Duration(seconds: 120),
            onTimeout: () {
              throw Exception('Upload timeout after 120 seconds');
            },
          );
          final responseBody = await response.stream.bytesToString();

          // Close processing dialog
          if (mounted) Navigator.of(context).pop();

          final decoded = json.decode(responseBody);

          if (decoded['status'] == 'success') {
            // Save to local database for all exercises
            for (var item in questions) {
              final questionNumber = (item['question_number'] ?? '').toString();
              final exerciseText = item['exercise'] ?? '';
              await dbHelper.saveManualMarkToLocalPoe(
                int.parse(widget.learnerId!),
                'ARPL',
                exerciseText,
                targetFilePath,
                unitStandard: selectedTrade!,
              );
              setState(() {
                final uploadKey =
                    _uploadKey(selectedPaper!, questionNumber, exerciseText);
                uploadedExercises[uploadKey] = true;
                final rawKey = 'ARPL-$exerciseText-${widget.learnerId}';
                uploadedExercises[rawKey] = true;
              });
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Uploaded ${questions.length} items'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            print('❌ Server error for ARPL upload: ${decoded['message']}');
            // Save locally for all exercises
            for (var item in questions) {
              final questionNumber = (item['question_number'] ?? '').toString();
              final exerciseText = item['exercise'] ?? '';
              await dbHelper.saveManualMarkToLocalPoe(
                int.parse(widget.learnerId!),
                'ARPL',
                exerciseText,
                targetFilePath,
                unitStandard: selectedTrade!,
              );
              setState(() {
                final uploadKey =
                    _uploadKey(selectedPaper!, questionNumber, exerciseText);
                uploadedExercises[uploadKey] = true;
                final rawKey = 'ARPL-$exerciseText-${widget.learnerId}';
                uploadedExercises[rawKey] = true;
              });
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Saved locally - will sync later'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        } catch (e) {
          // Close processing dialog if open
          if (mounted) Navigator.of(context).pop();

          print('❌ Upload error: $e');
          // Save locally for all exercises
          for (var item in questions) {
            final questionNumber = (item['question_number'] ?? '').toString();
            final exerciseText = item['exercise'] ?? '';
            await dbHelper.saveManualMarkToLocalPoe(
              int.parse(widget.learnerId!),
              'ARPL',
              exerciseText,
              targetFilePath,
              unitStandard: selectedTrade!,
            );
            setState(() {
              final uploadKey =
                  _uploadKey(selectedPaper!, questionNumber, exerciseText);
              uploadedExercises[uploadKey] = true;
              final rawKey = 'ARPL-$exerciseText-${widget.learnerId}';
              uploadedExercises[rawKey] = true;
            });
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved locally - will sync later'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        // No connection, save locally
        for (var item in questions) {
          final questionNumber = (item['question_number'] ?? '').toString();
          final exerciseText = item['exercise'] ?? '';
          await dbHelper.saveManualMarkToLocalPoe(
            int.parse(widget.learnerId!),
            'ARPL',
            exerciseText,
            targetFilePath,
            unitStandard: selectedTrade!,
          );
          setState(() {
            final uploadKey =
                _uploadKey(selectedPaper!, questionNumber, exerciseText);
            uploadedExercises[uploadKey] = true;
            final rawKey = 'ARPL-$exerciseText-${widget.learnerId}';
            uploadedExercises[rawKey] = true;
          });
        }
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved locally - will sync later'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      await _refreshUploadStatus();
    } catch (e, stackTrace) {
      print('Error in _scanAllQuestions: $e\nStackTrace: $stackTrace');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    }
  }

  Widget _buildQuestionCardWithPaperInfo(
      Map<String, dynamic> question, String paperName, int paperNumber) {
    final questionNumber = (question['question_number'] ?? '').toString();
    final exerciseText = question['exercise'] ?? '';
    final isUploaded =
        _isExerciseUploaded(paperName, questionNumber, exerciseText);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUploaded ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isUploaded ? Colors.green : Colors.grey,
              size: 24,
            ),
          ],
        ),
        title: Text(
          'Paper $paperNumber • Q$questionNumber',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              exerciseText,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isUploaded ? '✅ Completed' : '⏳ Pending',
                  style: TextStyle(
                    fontSize: 12,
                    color: isUploaded ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Marks: ${question['marks'] ?? 0}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
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

  Widget _buildQuestionCard(Map<String, dynamic> question) {
    final questionNumber = (question['question_number'] ?? '').toString();
    final exerciseText = question['exercise'] ?? '';

    // Check if PAPER is uploaded first (overrides individual question status)
    final paperUploaded = _isPaperUploaded(selectedPaper!);

    // Use paper upload status if paper is complete, otherwise check individual question
    final isUploaded = paperUploaded ||
        _isExerciseUploaded(selectedPaper!, questionNumber, exerciseText);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isUploaded ? Colors.green.shade50 : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isUploaded ? Colors.green : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isUploaded ? Icons.check : Icons.radio_button_unchecked,
            color: isUploaded ? Colors.white : Colors.grey,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Text(
              'Q$questionNumber',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isUploaded ? Colors.green.shade700 : Colors.deepPurple,
              ),
            ),
            if (isUploaded) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '✅ Uploaded',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              exerciseText,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isUploaded ? 'Completed' : 'Pending',
                  style: TextStyle(
                    color: isUploaded ? Colors.green : Colors.orange,
                  ),
                ),
                Text(
                  'Marks: ${question['marks'] ?? 0}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListSelector({
    required String title,
    required List<String> items,
    required void Function(String) onSelected,
    required IconData leadingIcon,
    VoidCallback? onBack,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
          ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No items found'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Icon(leadingIcon,
                            color: Colors.deepPurple, size: 32),
                        title: Text(
                          item,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => onSelected(item),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSectionCardSelector({
    required String title,
    required List<Map<String, dynamic>> sections,
    required void Function(String) onSelected,
    VoidCallback? onBack,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
          ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(16),
            childAspectRatio: 1.5,
            children: sections.map((section) {
              return Card(
                elevation: 4,
                margin: const EdgeInsets.all(8),
                child: InkWell(
                  onTap: () => onSelected(section['key']),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        section['icon'],
                        size: 64,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        section['name'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
