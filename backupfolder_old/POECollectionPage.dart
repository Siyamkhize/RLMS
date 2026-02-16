import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:signature/signature.dart';
import 'dart:typed_data';
import 'config.dart';
import 'database_helper.dart';

class POECollectionPage extends StatefulWidget {
  final String classID;

  const POECollectionPage({
    super.key,
    required this.classID,
  });

  @override
  _POECollectionPageState createState() => _POECollectionPageState();
}

class _POECollectionPageState extends State<POECollectionPage> {
  List<Map<String, dynamic>> learners = [];
  String selectedItem = 'Select'; // Default selected item
  String practitionerFullName = 'Unknown Facilitator';
  String qualification_name = 'No qualification assigned';
  String className = 'N/A';
  String dateAORCreated = DateTime.now().toString().split(' ')[0];
  String selectedDescription = 'POE Submission'; // Fixed to POE Submission
  Uint8List? facilitatorSignature; // For facilitator signature
  Uint8List? representativeSignature; // For representative signature
  String facilitatorFullName = ''; // Facilitator's full name
  String representativeName = ''; // Representative's full name

  // Form field controllers
  TextEditingController studentIdController = TextEditingController();
  TextEditingController studentNameController = TextEditingController();
  TextEditingController classNameController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController dateReceivedController = TextEditingController();
  TextEditingController practitionerNameController = TextEditingController();
  TextEditingController representativeNameController = TextEditingController();
  TextEditingController commentsController = TextEditingController();
  String learnerSignature = ''; // For simplicity, assuming you get signature as a base64
  bool received = false; // Checkbox for "Received" field

  @override
  void initState() {
    super.initState();
    fetchLearners(); // Use new POE collection status API
    _loadExistingPOESubmissions();
  }

  Future<void> _loadExistingPOESubmissions() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final results = await db.query(
        'poe_submissions',
        where: 'class_id = ?',
        whereArgs: [widget.classID],
      );

      // Mark learners who have already submitted POE
      for (var result in results) {
        final learnerId = result['learner_id'] as String;
        final signature = result['signature'] as Uint8List?;

        // Find the learner in the current list and mark as submitted
        final learnerIndex = learners.indexWhere((learner) => learner['IDNumber'] == learnerId);
        if (learnerIndex != -1) {
          learners[learnerIndex]['Signature'] = signature;
          learners[learnerIndex]['POESubmitted'] = true;
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading existing POE submissions: $e');
    }
  }

  Future<void> fetchLearners() async {
    try {
      print('⚡ Fetching learners for classID: ${widget.classID}');

      // Check connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('❌ No internet connection. Attempting local database fetch...');
        await fetchLearnerss(widget.classID);
        return;
      }

      print('🌐 Internet found. Fetching learners from API...');
      final response = await http.get(Uri.parse(
          AppConfig.buildUrl('get_poe_collection_status.php?classID=${widget.classID}')));

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('❌ Failed to load learners from API: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      print('🔍 Decoded API data: $data');
      
      final apiData = data['learners'] as List<dynamic>?;

      if (apiData == null || apiData.isEmpty) {
        print("❌ No learners found in API response.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No learners found.')),
        );
        setState(() => learners = []);
        return;
      }

      // Process learners - the API already provides POE status
      final processedLearners = <Map<String, dynamic>>[];
      
      print('🔍 Processing ${apiData.length} learners from API...');
      
      for (var learner in apiData) {
        final idNumber = learner['IDNumber']?.toString() ?? '';
        final poeStatus = learner['POEStatus'] ?? 'Not Submitted';
        
        print('📋 Learner: ${learner['FullName']} ($idNumber) - POE Status: $poeStatus');
        
        if (idNumber.isNotEmpty) {
          processedLearners.add({
            'FullName': learner['FullName'] ?? '',
            'IDNumber': idNumber,
            'ClassName': learner['ClassName'] ?? '',
            'Received': false,
            'Quantity': '1',
            'Date': DateTime.now().toString().split(' ')[0],
            'Description': 'POE Submission',
            'Signature': null,
            'FacilitatorFullName': learner['FacilitatorFullName'] ?? 'Unknown Facilitator',
            'qualification_name': learner['qualification_name'] ?? 'No qualification assigned',
            'POEStatus': poeStatus, // Use status from API
            'submission_date': learner['submission_date'],
            'collection_date': learner['collection_date'],
          });
        }
      }

      setState(() {
        learners = processedLearners;
        if (learners.isNotEmpty) {
          practitionerFullName = learners.first['FacilitatorFullName'] ?? 'Unknown Facilitator';
          className = learners.first['ClassName'] ?? 'N/A';
          qualification_name = learners.first['qualification_name'] ?? 'No qualification assigned';
          print('✅ Set qualification_name: $qualification_name');
        } else {
          practitionerFullName = 'Unknown Facilitator';
          className = 'N/A';
          qualification_name = 'No qualification assigned';
        }
      });

      // Reload POE submissions after fetching learners
      await _loadExistingPOESubmissions();

      print('✅ Learners fetched: ${learners.length}');
      print('Learners: $learners');
    } catch (e) {
      print('❌ Error fetching learners: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch learners. Please try again later.')),
      );
    }
  }

  Future<void> fetchLearnerss(String classID) async {
    try {
      final dbHelper = DatabaseHelper();
      final result = await dbHelper.getLearnerss(classID, 'Select');

      print('Local DB Result: $result');

      if (result.isEmpty) {
        print("❌ No learners found in local database.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No learners found in local database.')),
        );
        setState(() => learners = []);
        return;
      }

      final submittedIds = await getSubmittedLearners('POE Submission');
      print('Submitted IDs (local): $submittedIds');

      final uniqueLearnersMap = _filterAndFormatLearners(result, submittedIds);

      // Update POE status for each learner based on database records
      for (var learner in uniqueLearnersMap.values) {
        final idNumber = learner['IDNumber'] as String;
        
        if (submittedIds.contains(idNumber)) {
          learner['POEStatus'] = 'Ready for Collection';
          learner['Description'] = 'POE Submission';
        } else {
          learner['POEStatus'] = 'Not Submitted';
          learner['Description'] = 'POE Submission';
        }
      }

      setState(() {
        learners = uniqueLearnersMap.values.toList();
        if (learners.isNotEmpty) {
          practitionerFullName = learners.first['FacilitatorFullName'] ?? 'Unknown Facilitator';
          className = learners.first['ClassName'] ?? 'N/A';
          qualification_name = learners.first['qualification_name'] ?? 'No qualification assigned';
          print('✅ Set qualification_name (local): $qualification_name');
        }
      });

      // Reload POE submissions after fetching learners locally
      await _loadExistingPOESubmissions();

      print('✅ Local learners fetched: ${learners.length}');
      print('Local Learners: $learners');
    } catch (e) {
      print('❌ Error fetching learners from local database: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching learners from local database.')),
      );
      setState(() => learners = []);
    }
  }

  Future<Set<String>> getSubmittedLearners(String description) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // For POE Collection, check for "POE Submission" description
      final submittedLearners = await db.rawQuery(
        'SELECT student_id_number FROM material_receipt_form WHERE description = ?',
        ['POE Submission'],
      );

      return submittedLearners.map((record) => record['student_id_number'] as String).toSet();
    } catch (e) {
      print('❌ Error fetching submitted learners: $e');
      return <String>{};
    }
  }

  Map<String, Map<String, dynamic>> _filterAndFormatLearners(
      List<dynamic> apiData, Set<String> submittedIds) {
    final uniqueLearnersMap = <String, Map<String, dynamic>>{};

    for (var learner in apiData) {
      final idNumber = learner['IDNumber']?.toString() ?? '';
      if (idNumber.isNotEmpty) {
        // Include all learners, but mark their status appropriately
        uniqueLearnersMap[idNumber] = {
          'FullName': learner['FullName'] ?? '',
          'IDNumber': idNumber,
          'ClassName': learner['ClassName'] ?? '',
          'Received': false,
          'Quantity': '1',
          'Date': DateTime.now().toString().split(' ')[0],
          'Description': 'POE Submission', // Always POE Submission for POE Collection
          'Signature': null,
          'FacilitatorFullName': learner['FacilitatorFullName'] ?? '',
          'qualification_name': learner['qualification_name'] ?? '',
          'POEStatus': 'Not Submitted', // Default status
        };
      }
    }

    return uniqueLearnersMap;
  }

  Future<void> sendData() async {
    final url = AppConfig.buildUrl('save_material_receipt.php');
    print('🌐 Sending data to: $url');
    final body = jsonEncode({
      'classID': widget.classID,
      'learners': learners.map((learner) {
        return {
          'Name': learner['FullName'] ?? '',
          'IDNumber': learner['IDNumber'] ?? '',
          'ClassName': learner['ClassName'] ?? '',
          'description': learner['Description'] ?? '',
          'Received': learner['Received'] ? 'Yes' : 'No',
          'Quantity': learner['Quantity'].toString(),
          'Date': learner['Date'] ?? '',
          'Signature': learner['Signature'] != null ? base64Encode(learner['Signature']) : '',
          'Description': learner['Description'] ?? '',
        };
      }).toList(),
      'facilitator_name': practitionerFullName,
    });

    try {
      print('📤 Request body: $body');
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response headers: ${response.headers}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Server returned status ${response.statusCode}: ${response.body}');
      }

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final dbHelper = DatabaseHelper();
        final db = await dbHelper.database;

        for (var learner in learners) {
          if (learner['Received'] == true && learner['Signature'] != null) {
            String studentId = learner['IDNumber'] ?? '';
            String studentName = learner['FullName'] ?? '';
            String className = learner['ClassName'] ?? '';
            String quantityText = learner['Quantity'] ?? '1';
            String description = learner['Description'] ?? '';
            String dateReceived = learner['Date'] ?? '';
            String practitionerName = practitionerFullName;

            final existingRecords = await db.query(
              'material_receipt_form',
              where: 'student_id_number = ? AND description = ?',
              whereArgs: [studentId, description],
            );

            if (existingRecords.isNotEmpty) {
              print("⚠️ $studentName already exists locally with description: '$description'. Skipping...");
              continue;
            }

            String learnerSignaturePath = await saveSignatureAsPng(
              learner['Signature'],
              'learner_signature_$studentId',
            );

            String receivedText = learnerSignaturePath.isNotEmpty ? 'Yes' : 'No';

            Map<String, dynamic> data = {
              'student_id_number': studentId,
              'student_full_name': studentName,
              'class_name': className,
              'received': receivedText,
              'quantity': int.tryParse(quantityText) ?? 1,
              'description': description,
              'date_received': dateReceived,
              'practitioner_full_name': practitionerName,
              'learner_signature': learnerSignaturePath,
              'created_at': DateTime.now().toIso8601String(),
            };

            await db.insert('material_receipt_form', data);
            print("✅ Saved $studentName locally after server submission.");
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'].contains('already exist')
                ? 'Some learners already exist: ${responseData['message']}'
                : 'POE submissions submitted successfully!'),
          ),
        );

        await fetchLearners();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit data: ${responseData['message']}')),
        );
      }
    } catch (e) {
      print('❌ Error submitting form: $e');
      String errorMessage = 'Error submitting form: $e';

      // Provide more specific error messages
      if (e.toString().contains('FormatException')) {
        errorMessage = 'Server returned invalid response. Please check if the server endpoint exists.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('404')) {
        errorMessage = 'Server endpoint not found. Please contact support.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<String> saveSignatureAsPng(Uint8List signatureBytes, String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final signaturesDir = Directory('${appDir.path}/signatures');
      if (!signaturesDir.existsSync()) {
        signaturesDir.createSync(recursive: true);
      }

      final filePath = '${signaturesDir.path}/$fileName.png';
      final file = File(filePath);
      await file.writeAsBytes(signatureBytes);
      return filePath;
    } catch (e) {
      print('Error saving signature: $e');
      return '';
    }
  }

  Future<void> saveMaterialReceiptForm() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      for (var learner in learners) {
        if (learner['Received'] == true && learner['Signature'] != null) {
          String studentId = learner['IDNumber'] ?? '';
          String studentName = learner['FullName'] ?? '';
          String className = learner['ClassName'] ?? '';
          String quantityText = learner['Quantity'] ?? '1';
          String description = learner['Description'] ?? '';
          String dateReceived = learner['Date'] ?? '';
          String practitionerName = practitionerFullName;

          final existingRecords = await db.query(
            'material_receipt_form',
            where: 'student_id_number = ? AND description = ?',
            whereArgs: [studentId, description],
          );

          if (existingRecords.isNotEmpty) {
            print("⚠️ $studentName already exists locally with description: '$description'. Skipping...");
            continue;
          }

          String learnerSignaturePath = await saveSignatureAsPng(
            learner['Signature'],
            'learner_signature_$studentId',
          );

          String receivedText = learnerSignaturePath.isNotEmpty ? 'Yes' : 'No';

          Map<String, dynamic> data = {
            'student_id_number': studentId,
            'student_full_name': studentName,
            'class_name': className,
            'received': receivedText,
            'quantity': int.tryParse(quantityText) ?? 1,
            'description': description,
            'date_received': dateReceived,
            'practitioner_full_name': practitionerName,
            'learner_signature': learnerSignaturePath,
            'created_at': DateTime.now().toIso8601String(),
          };

          await db.insert('material_receipt_form', data);
          print("✅ Saved $studentName locally.");
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('POE submissions saved locally!')),
      );

      await fetchLearners();
    } catch (e) {
      print('❌ Error saving material receipt form: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving form: $e')),
      );
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building POE Collection Table with ${learners.length} learners');
    print('Qualification Name in UI: $qualification_name');
    return Scaffold(
      appBar: AppBar(
        title: const Text('POE Collection'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Qualification
                    _buildQualificationCard(),
                    const SizedBox(height: 8.0),
                    // Row 2: Full Name + Class Name + Date Created
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: buildCard('Full Name', practitionerFullName),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: buildCard('Class Name', className),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: buildCard('Date Created', dateAORCreated),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    // Row 3: Description (fixed) + Representative
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildPOEDescriptionCard(),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: buildCard('Representative', representativeName.isNotEmpty ? representativeName : 'N/A'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    border: TableBorder.all(color: Colors.grey, width: 1, borderRadius: BorderRadius.circular(12)),
                    columnWidths: const {
                      0: FixedColumnWidth(90),  // Name + Status - increased slightly
                      1: FixedColumnWidth(90),  // ID Number
                      2: FixedColumnWidth(80),  // Class Name
                      3: FixedColumnWidth(60),  // Received
                      4: FixedColumnWidth(50),  // Quantity
                      5: FixedColumnWidth(80),  // Date
                      6: FixedColumnWidth(80),  // Description
                      7: FixedColumnWidth(100), // Signature
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        children: [
                          headerCell('Name'),
                          headerCell('ID Number'),
                          headerCell('Class Name'),
                          headerCell('Received'),
                          headerCell('Quantity'),
                          headerCell('Date'),
                          headerCell('Description'),
                          headerCell('Signature'),
                        ],
                      ),
                      ...learners.map((learner) {
                        return TableRow(
                          children: [
                            // Name column with status indicator under ID
                            TableCell(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0), // Reduced padding
                                child: Column(
                                  children: [
                                    Text(
                                      learner['FullName'] ?? '',
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 4),
                                    // Status indicator under the name
                                    _buildStatusIndicator(learner),
                                  ],
                                ),
                              ),
                            ),
                            // ID Number column
                            dataCell(learner['IDNumber'] ?? ''),
                            textFieldCell(
                              initialValue: learner['ClassName'] ?? '',
                              onChanged: (value) => learner['ClassName'] = value,
                            ),
                            checkboxCell(
                              value: learner['Received'] ?? false,
                              learner: learner,
                            ),
                            quantityDropdown(learner),
                            datePickerCell(
                              initialValue: learner['Date'] ?? '',
                              onChanged: (date) => setState(() => learner['Date'] = date),
                            ),
                            textFieldCell(
                              initialValue: learner['Description'] ?? 'POE Submission',
                              onChanged: (value) => learner['Description'] = value,
                            ),
                            // POE-specific signature button that turns into a tick after signing
                            TableCell(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildPOESubmissionButton(learner),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: learners.isEmpty
                  ? null
                  : () async {
                final isOnline = await _checkConnectivity();
                if (isOnline) {
                  await sendData();
                } else {
                  await saveMaterialReceiptForm();
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  // === Helpers copied to mirror LearningMaterialForm structure ===
  Widget headerCell(String title) {
    return Container(
      padding: const EdgeInsets.all(6.0),
      alignment: Alignment.center,
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10), // Reduced font size
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }

  Widget dataCell(String value) {
    return Padding(
      padding: const EdgeInsets.all(4.0), // Reduced padding
      child: Text(
        value,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }

  Widget textFieldCell({
    required String initialValue,
    required Function(String) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(4.0), // Reduced padding
      child: TextField(
        controller: TextEditingController(text: initialValue),
        onChanged: onChanged,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        ),
        style: const TextStyle(fontSize: 10), // Reduced font size
        maxLines: 1,
      ),
    );
  }

  TableCell checkboxCell({required bool value, required Map<String, dynamic> learner}) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(4.0), // Reduced padding
        child: Checkbox(
          value: value,
          onChanged: (v) => setState(() {
            learner['Received'] = v ?? false;
          }),
        ),
      ),
    );
  }

  Widget quantityDropdown(Map<String, dynamic> learner) {
    return Container(
      padding: const EdgeInsets.all(4.0),
      child: DropdownButton<int>(
        value: int.tryParse(learner['Quantity'] ?? '1') ?? 1,
        onChanged: (value) => setState(() {
          learner['Quantity'] = (value ?? 1).toString();
        }),
        isExpanded: true,
        style: const TextStyle(fontSize: 12, color: Colors.black),
        items: List.generate(10, (index) => DropdownMenuItem(
          value: index == 0 ? 1 : index, // default min 1
          child: Text((index == 0 ? 1 : index).toString()),
        )),
      ),
    );
  }

  Widget datePickerCell({
    required String initialValue,
    required Function(String) onChanged,
  }) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: InkWell(
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: initialValue.isNotEmpty
                  ? DateTime.tryParse(initialValue) ?? DateTime.now()
                  : DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (pickedDate != null) {
              onChanged(pickedDate.toIso8601String().split('T').first);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              initialValue.isNotEmpty ? initialValue : DateTime.now().toString().split(' ').first,
              style: const TextStyle(fontSize: 10), // Reduced font size
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(Map<String, dynamic> learner) {
    final poeStatus = learner['POEStatus'] ?? 'Not Submitted';
    
    print('🎯 Building status indicator for ${learner['FullName']} - Status: $poeStatus');
    
    switch (poeStatus) {
      case 'Collected':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Reduced padding
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade300, width: 1),
          ),
          child: Text(
            'DONE', // Shorter text
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 7, // Even smaller font
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        
      case 'Ready for Collection':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Reduced padding
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade300, width: 1),
          ),
          child: Text(
            'READY',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: 7, // Even smaller font
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        
      case 'Not Submitted':
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Reduced padding
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Text(
            'PENDING', // Shorter text
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 7, // Even smaller font
              fontWeight: FontWeight.bold,
            ),
          ),
        );
    }
  }

  Widget buildCard(String label, String value) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualificationCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Qualification',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Qualification: $qualification_name',
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPOEDescriptionCard() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: const Text(
                'POE Submission',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPOESubmissionButton(Map<String, dynamic> learner) {
    final poeStatus = learner['POEStatus'] ?? 'Not Submitted';
    
    print('🎯 Building submission button for ${learner['FullName']} - Status: $poeStatus');
    
    switch (poeStatus) {
      case 'Collected':
        // POE has been collected - show green check (no action allowed)
        return Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.check_circle,
            color: Colors.green.shade700,
            size: 24,
          ),
        );
        
      case 'Ready for Collection':
        // POE has been submitted - show "Already Submitted" (no action allowed)
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Text(
            'Already Submitted',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        
      case 'Not Submitted':
      default:
        // POE not submitted yet - show "Ready for POE Collection" (can submit)
        return SizedBox(
          width: 100,
          child: ElevatedButton(
            onPressed: () => _showPOESubmissionDialog(context, learner),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
            child: const Text(
              'Ready for POE Collection',
              style: TextStyle(fontSize: 9),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
          ),
        );
    }
  }

  Future<void> _showPOECollectionDialog(BuildContext context, Map<String, dynamic> learner) async {
    final controller = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    bool isCollected = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Text('POE Collection - ${learner['FullName']}'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      color: Colors.orange.shade700,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'POE Ready for Collection',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This learner\'s POE has been submitted and is ready for collection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please sign below to confirm POE collection:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey.shade200,
                child: Signature(
                  controller: controller,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => controller.clear(),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            onPressed: () async {
              final signature = await controller.toPngBytes();
              if (signature != null) {
                // Mark POE as collected
                learner['Signature'] = signature;
                learner['Received'] = true;
                learner['Description'] = 'POE Collected';
                learner['POEStatus'] = 'Collected';
                learner['POECollectionDate'] = DateTime.now().toIso8601String();
                isCollected = true;

                // Update the database record from "POE Submission" to "POE Collected"
                await _updatePOEStatusToCollected(learner);
              }
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Collect POE'),
          ),
        ],
      ),
    );

    if (isCollected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('POE collected successfully for ${learner['FullName']}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _updatePOEStatusToCollected(Map<String, dynamic> learner) async {
    try {
      // Just update the local display status - don't change database
      // The database record remains as "POE Submission" but we track collection locally
      print('✅ POE collected locally for ${learner['FullName']} - database status unchanged');
      
      // Optional: You could save collection info to a separate table if needed
      // For now, we just update the local UI state
      
    } catch (e) {
      print('❌ Error updating local POE collection status: $e');
    }
  }

  Future<void> _showPOESubmissionDialog(BuildContext context, Map<String, dynamic> learner) async {
    final controller = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    bool isSubmitted = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Text('POE Submission - ${learner['FullName']}'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment,
                      color: Colors.green.shade700,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ready for POE Submission',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This learner is ready to submit their POE.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please sign below to confirm POE submission:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey.shade200,
                child: Signature(
                  controller: controller,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => controller.clear(),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            onPressed: () async {
              final signature = await controller.toPngBytes();
              if (signature != null) {
                // Mark POE as submitted
                learner['Signature'] = signature;
                learner['Received'] = true;
                learner['Description'] = 'POE Submission';
                learner['POEStatus'] = 'Ready for Collection'; // Update status to submitted
                learner['POESubmissionDate'] = DateTime.now().toIso8601String();
                isSubmitted = true;

                // Save POE submission locally
                await _savePOESubmissionLocally(learner);
              }
              Navigator.pop(context);
              setState(() {}); // Refresh the UI to show new status
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit POE'),
          ),
        ],
      ),
    );

    if (isSubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('POE submitted successfully for ${learner['FullName']}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _savePOESubmissionLocally(Map<String, dynamic> learner) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Save POE submission record to material_receipt_form table
      // This is what the API checks for POE status
      await db.insert('material_receipt_form', {
        'student_id_number': learner['IDNumber'],
        'student_full_name': learner['FullName'],
        'class_name': learner['ClassName'] ?? '',
        'received': 'Yes',
        'quantity': 1,
        'description': 'POE Submission', // This is what the API looks for
        'date_received': DateTime.now().toIso8601String().split('T')[0],
        'practitioner_full_name': practitionerFullName,
        'learner_signature': '', // Could save signature path if needed
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ POE submission saved to material_receipt_form for ${learner['FullName']}');
    } catch (e) {
      print('❌ Error saving POE submission locally: $e');
    }
  }
}