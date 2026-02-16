import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'config.dart';
import 'services/fingerprint_service.dart';
import 'logistics_learner_ppe_selection_page.dart';

class LogisticsPPEIssuancePage extends StatefulWidget {
  final String classID;
  final String? logisticsId;
  final String? logisticsName;
  final String? siteId;
  final String? siteName;
  final String? classId;
  final String? className;
  final String? facilitatorId;
  final String? facilitatorName;

  const LogisticsPPEIssuancePage({
    super.key,
    required this.classID,
    this.logisticsId,
    this.logisticsName,
    this.siteId,
    this.siteName,
    this.classId,
    this.className,
    this.facilitatorId,
    this.facilitatorName,
  });

  @override
  State<LogisticsPPEIssuancePage> createState() =>
      _LogisticsPPEIssuancePageState();
}

class _LogisticsPPEIssuancePageState extends State<LogisticsPPEIssuancePage> {
  List<Map<String, dynamic>> learners = [];
  List<Map<String, dynamic>> allLearners = [];
  List<Map<String, dynamic>> ppeItems = [];
  List<String> issuedLearnerNames = [];
  bool isLoading = true;

  // Selection interface variables
  String qualification = '';
  String facilitatorFullName = 'Unknown Facilitator';
  String selectedPPEType = 'Select';

  // PPE type options
  final List<String> ppeTypes = [
    'Select',
    'Conti-Suit',
    'Safety Boots',
    'Hard Hat',
    'Safety Glasses',
    'Gloves',
    'Ear Protection',
    'Reflective Vest',
  ];

  // Fingerprint services
  final FingerprintService _fingerprintService = FingerprintService();
  final FutronicService _futronicService = FutronicService();
  String activeScanner = 'none';
  bool isVerifying = false;

  @override
  void initState() {
    super.initState();
    _fetchAllLearners();
    _fetchPPEItems();
    _fetchClassInfo();
    _detectScanner();
  }

  Future<void> _detectScanner() async {
    try {
      // Try ZKTeco first
      try {
        debugPrint('[SCANNER] Checking ZKTeco...');
        final isZkConnected = await _fingerprintService.isSensorConnected();
        debugPrint('[SCANNER] ZKTeco result: $isZkConnected');
        if (isZkConnected == true) {
          setState(() => activeScanner = 'zkteco');
          debugPrint('[SCANNER] ✅ ZKTeco scanner detected');
          return;
        }
      } catch (e) {
        debugPrint('[SCANNER] ❌ ZKTeco not available: $e');
      }

      // Try Futronic
      try {
        debugPrint('[SCANNER] Checking Futronic...');
        final isFutronicConnected =
            await _futronicService.isFutronicConnected();
        debugPrint('[SCANNER] Futronic result: $isFutronicConnected');
        if (isFutronicConnected == true) {
          setState(() => activeScanner = 'futronic');
          debugPrint('[SCANNER] ✅ Futronic scanner detected');
          return;
        }
      } catch (e) {
        debugPrint('[SCANNER] ❌ Futronic not available: $e');
      }

      // No scanner found
      setState(() => activeScanner = 'none');
      debugPrint('[SCANNER] ⚠️ No fingerprint scanner detected');
    } catch (e) {
      debugPrint('[SCANNER] ❌ Error detecting scanner: $e');
      setState(() => activeScanner = 'none');
    }
  }

  Future<void> _fetchClassInfo() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Get class and facilitator info
      final query = '''
        SELECT
          c.className,
          f.firstName,
          f.lastName
        FROM class c
        LEFT JOIN facilitator f ON c.classID = f.classID
        WHERE c.classID = ?
      ''';

      final results = await db.rawQuery(query, [widget.classID]);

      if (results.isNotEmpty) {
        setState(() {
          facilitatorFullName =
              '${results.first['firstName'] ?? ''} ${results.first['lastName'] ?? ''}'
                  .trim();
          if (facilitatorFullName.isEmpty) {
            facilitatorFullName = 'Unknown Facilitator';
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching class info: $e');
    }
  }

  Future<void> _fetchAllLearners() async {
    try {
      setState(() => isLoading = true);

      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      debugPrint(
          '[LOGISTICS-PPE] Fetching learners for classID: ${widget.classID}');

      // STEP 1: Try to fetch learners directly from server API
      try {
        debugPrint('[LOGISTICS-PPE] Fetching learners from server API...');

        final response = await http
            .get(
              Uri.parse(
                  '${AppConfig.getLearnersUrl}?classID=${widget.classID}'),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List<dynamic> learnersData = json.decode(response.body);
          debugPrint(
              '[LOGISTICS-PPE] ✅ Received ${learnersData.length} learners from server API');

          // Store all learners from API
          allLearners = learnersData.map((learner) {
            return {
              'LearnerID': learner['LearnerID'],
              'IDNumber': learner['IDNumber'],
              'FullName': '${learner['Name']} ${learner['Surname']}',
              'Name': learner['Name'],
              'Surname': learner['Surname'],
              'ClockInTime': null,
            };
          }).toList();

          debugPrint(
              '[LOGISTICS-PPE] Fetched ${allLearners.length} learners from API');

          // Apply filtering based on selected PPE type
          await _filterLearnersByPPEType();

          setState(() => isLoading = false);
          return; // Success - exit early
        } else {
          debugPrint(
              '[LOGISTICS-PPE] ⚠️ Server API returned status ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('[LOGISTICS-PPE] ⚠️ Failed to fetch from server API: $e');
        debugPrint('[LOGISTICS-PPE] Falling back to local database...');
      }

      // STEP 2: Fallback to local database if API fails
      debugPrint('[LOGISTICS-PPE] Using local database as fallback...');

      // Check if learners exist in local database
      final totalQuery = 'SELECT COUNT(*) as total FROM learnerdetails';
      final totalResult = await db.rawQuery(totalQuery);
      final totalLearners = totalResult.first['total'];
      debugPrint(
          '[LOGISTICS-PPE] Total learners in local database: $totalLearners');

      // NEVER SYNC - Only use existing local data
      if (totalLearners == null || (totalLearners as int) == 0) {
        debugPrint('[LOGISTICS-PPE] ❌ No data in local database');
        debugPrint(
            '[LOGISTICS-PPE] Please sync data from another role first (Facilitator, Admin, or SDP)');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No learner data available. Please sync from another role first.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }

        setState(() => isLoading = false);
        return;
      } else {
        debugPrint(
            '[LOGISTICS-PPE] ✅ Using local data ($totalLearners learners already synced)');
      }

      // Try to convert classID to integer in case there's a type mismatch
      dynamic classIdParam = widget.classID;
      try {
        classIdParam = int.parse(widget.classID);
        debugPrint(
            '[LOGISTICS-PPE] Converted classID to integer: $classIdParam');
      } catch (e) {
        debugPrint(
            '[LOGISTICS-PPE] ClassID is not numeric, using as string: ${widget.classID}');
      }

      // Get all learners for this class
      final query = '''
        SELECT DISTINCT
          ld.LearnerID,
          ld.IDNumber,
          ld.Name,
          ld.Surname,
          ld.classID
        FROM learnerdetails ld
        WHERE ld.classID = ?
        ORDER BY ld.Surname, ld.Name
      ''';

      final results = await db.rawQuery(query, [classIdParam]);

      debugPrint(
          '[LOGISTICS-PPE] Raw query results: ${results.length} rows found');

      // Store all learners
      allLearners = results.map((row) {
        return {
          'LearnerID': row['LearnerID'],
          'IDNumber': row['IDNumber'],
          'FullName': '${row['Name']} ${row['Surname']}',
          'Name': row['Name'],
          'Surname': row['Surname'],
          'ClockInTime': null,
        };
      }).toList();

      debugPrint('[LOGISTICS-PPE] Fetched ${allLearners.length} learners');

      // Apply filtering based on selected PPE type
      await _filterLearnersByPPEType();

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint('[LOGISTICS-PPE] Error fetching learners: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading learners: $e')),
        );
      }
    }
  }

  Future<void> _fetchPPEItems() async {
    // Define PPE items with sizes
    ppeItems = [
      {
        'ppe_type': 'Conti-Suit',
        'sizes': List.generate(41, (index) => (26 + index).toString()),
        'icon': Icons.checkroom,
        'color': Colors.blue,
      },
      {
        'ppe_type': 'Safety Boots',
        'sizes': List.generate(12, (index) => (3 + index).toString()),
        'icon': Icons.work_outline,
        'color': Colors.orange,
      },
      {
        'ppe_type': 'Hard Hat',
        'sizes': ['Small', 'Medium', 'Large', 'X-Large'],
        'icon': Icons.construction,
        'color': Colors.yellow[700],
      },
      {
        'ppe_type': 'Safety Glasses',
        'sizes': ['One Size'],
        'icon': Icons.remove_red_eye,
        'color': Colors.green,
      },
      {
        'ppe_type': 'Gloves',
        'sizes': ['Small', 'Medium', 'Large', 'X-Large'],
        'icon': Icons.back_hand,
        'color': Colors.purple,
      },
      {
        'ppe_type': 'Ear Protection',
        'sizes': ['One Size'],
        'icon': Icons.headset,
        'color': Colors.red,
      },
      {
        'ppe_type': 'Reflective Vest',
        'sizes': ['Small', 'Medium', 'Large', 'X-Large', 'XX-Large'],
        'icon': Icons.visibility,
        'color': Colors.amber,
      },
    ];
  }

  Future<void> _fetchIssuedLearners() async {
    if (selectedPPEType == 'Select') {
      setState(() {
        issuedLearnerNames = [];
      });
      return;
    }

    try {
      debugPrint('[FILTER] Fetching learners who received $selectedPPEType');

      final response = await http
          .get(
            Uri.parse(
                '${AppConfig.baseUrl}/get_logistics_ppe_issued.php?classID=${widget.classID}&ppe_type=$selectedPPEType'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> issuedData = json.decode(response.body);
        debugPrint('[FILTER] Received ${issuedData.length} issued learners');

        setState(() {
          issuedLearnerNames = issuedData
              .map((item) => '${item['Name']} ${item['Surname']}')
              .toList()
              .cast<String>();
        });

        debugPrint('[FILTER] Issued learners: $issuedLearnerNames');
      }
    } catch (e) {
      debugPrint('[FILTER] Error fetching issued learners: $e');
    }
  }

  Future<void> _filterLearnersByPPEType() async {
    await _fetchIssuedLearners();

    setState(() {
      if (selectedPPEType == 'Select') {
        // Show all learners
        learners = List.from(allLearners);
      } else {
        // Filter out learners who already received this PPE type
        learners = allLearners.where((learner) {
          final fullName = learner['FullName'];
          return !issuedLearnerNames.contains(fullName);
        }).toList();
      }
    });

    debugPrint(
        '[FILTER] Filtered learners: ${learners.length} (from ${allLearners.length} total)');
  }

  Future<void> _verifyAndIssuePPE(Map<String, dynamic> learner) async {
    if (selectedPPEType == 'Select') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a PPE type first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (activeScanner == 'none') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fingerprint scanner detected'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isVerifying = true);

    try {
      // Verify fingerprint
      bool verified = false;
      final learnerId = learner['LearnerID'].toString();

      if (activeScanner == 'zkteco') {
        verified = await _fingerprintService.verifyFingerprint(learnerId);
      } else if (activeScanner == 'futronic') {
        verified = await _futronicService.verifyFutronicFingerprint(learnerId);
      }

      if (!verified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fingerprint verification failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Fingerprint verified - navigate to PPE selection page
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LogisticsLearnerPPESelectionPage(
              learner: learner,
              ppeType: selectedPPEType,
              ppeItems: ppeItems,
              logisticsId: widget.logisticsId,
              logisticsName: widget.logisticsName,
              siteId: widget.siteId,
              siteName: widget.siteName,
              classId: widget.classId,
              className: widget.className,
              facilitatorId: widget.facilitatorId,
              facilitatorName: widget.facilitatorName,
            ),
          ),
        );

        if (result == true) {
          // Refresh the list after successful issuance
          await _fetchAllLearners();
        }
      }
    } catch (e) {
      debugPrint('[PPE-VERIFY] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PPE Issuance'),
        backgroundColor: Colors.orange,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header Card
                Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            const Text(
                              'PPE Issuance',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Site: ${widget.siteName ?? "N/A"}'),
                        Text('Class: ${widget.className ?? "N/A"}'),
                        Text('Facilitator: $facilitatorFullName'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              activeScanner == 'zkteco'
                                  ? Icons.fingerprint
                                  : activeScanner == 'futronic'
                                      ? Icons.fingerprint
                                      : Icons.fingerprint_outlined,
                              color: activeScanner != 'none'
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              activeScanner == 'zkteco'
                                  ? 'ZKTeco Scanner Ready'
                                  : activeScanner == 'futronic'
                                      ? 'Futronic Scanner Ready'
                                      : 'No Scanner Detected',
                              style: TextStyle(
                                color: activeScanner != 'none'
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // PPE Type Selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<String>(
                    value: selectedPPEType,
                    decoration: InputDecoration(
                      labelText: 'Select PPE Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: ppeTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      setState(() {
                        selectedPPEType = value!;
                      });
                      await _filterLearnersByPPEType();
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Learners List
                Expanded(
                  child: learners.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                selectedPPEType == 'Select'
                                    ? 'Select a PPE type to view learners'
                                    : 'All learners have received $selectedPPEType',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: learners.length,
                          itemBuilder: (context, index) {
                            final learner = learners[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange[100],
                                  child: Text(
                                    learner['Name'][0].toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.orange[900],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  learner['FullName'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text('ID: ${learner['IDNumber']}'),
                                trailing: ElevatedButton.icon(
                                  onPressed: isVerifying
                                      ? null
                                      : () => _verifyAndIssuePPE(learner),
                                  icon: const Icon(Icons.fingerprint, size: 18),
                                  label: const Text('Issue PPE'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
