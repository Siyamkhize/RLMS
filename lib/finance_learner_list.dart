import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'finance_register_history.dart';

class FinanceLearnerList extends StatefulWidget {
  final String classId;
  final String className;
  final String financeId;
  final String financeName;

  const FinanceLearnerList({
    super.key,
    required this.classId,
    required this.className,
    required this.financeId,
    required this.financeName,
  });

  @override
  _FinanceLearnerListState createState() => _FinanceLearnerListState();
}

class _FinanceLearnerListState extends State<FinanceLearnerList> {
  List<dynamic> learners = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchLearners();
  }

  Future<void> fetchLearners() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final url = AppConfig.buildUrl(
          'get_finance_learners.php?classID=${widget.classId}');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is List) {
          setState(() {
            learners = data;
            isLoading = false;
          });
        } else if (data['error'] != null) {
          setState(() {
            errorMessage = data['error'];
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Server error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        backgroundColor: Colors.green[700],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Colors.red),
                      SizedBox(height: 16),
                      Text(errorMessage, style: TextStyle(color: Colors.red)),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchLearners,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : learners.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No learners found in this class'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchLearners,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: learners.length,
                        itemBuilder: (context, index) {
                          final learner = learners[index];
                          return _buildLearnerCard(learner);
                        },
                      ),
                    ),
    );
  }

  Widget _buildLearnerCard(Map<String, dynamic> learner) {
    final learnerName =
        '${learner['name'] ?? ''} ${learner['surname'] ?? ''}'.trim();
    final learnerId = learner['learner_id']?.toString() ?? '';
    final idNumber = learner['id_number']?.toString() ?? 'N/A';
    final registerCount = learner['register_count']?.toString() ?? '0';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Text(
                    learnerName.isNotEmpty ? learnerName[0].toUpperCase() : 'L',
                    style: TextStyle(
                        color: Colors.green[700], fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        learnerName.isNotEmpty
                            ? learnerName
                            : 'Unknown Learner',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ID: $idNumber',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description, size: 18, color: Colors.blue[700]),
                  SizedBox(width: 8),
                  Text(
                    '$registerCount Registers',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FinanceRegisterHistory(
                        learnerId: learnerId,
                        learnerName: learnerName,
                        classId: widget.classId,
                        className: widget.className,
                        financeId: widget.financeId,
                      ),
                    ),
                  ).then((_) => fetchLearners());
                },
                icon: Icon(Icons.calendar_month, size: 20),
                label: Text('Mark Attendance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
