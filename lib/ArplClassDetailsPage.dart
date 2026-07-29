import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'ArplAssessorMarkingPage.dart';
import 'ArplHierarchicalNavigatorPage.dart';

// arl: ARPL Class Details Page
class ArplClassDetailsPage extends StatefulWidget {
  final String classId;

  const ArplClassDetailsPage({super.key, required this.classId});

  @override
  _ArplClassDetailsPageState createState() => _ArplClassDetailsPageState();
}

class _ArplClassDetailsPageState extends State<ArplClassDetailsPage> {
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

      print('[ArplClassDetailsPage] Fetching learners from: $url');
      final response = await http.get(Uri.parse(url));

      print('[ArplClassDetailsPage] Response Status: ${response.statusCode}');
      print('[ArplClassDetailsPage] Response Headers: ${response.headers}');
      print(
          '[ArplClassDetailsPage] Response Body Length: ${response.body.length}');
      print(
          '[ArplClassDetailsPage] Response Body (get_learners): ${response.body}');

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

          print('[ArplClassDetailsPage] Fetching POE from: $poeUrl');
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
      appBar: AppBar(title: Text('ARPL Class Details - ${widget.classId}')),
      body: Column(
        children: [
          // Button removed as per user request
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
                                            ArplHierarchicalNavigatorPage(
                                          classId: widget.classId,
                                          learnerId: learnerId,
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
