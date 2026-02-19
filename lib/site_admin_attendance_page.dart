import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'config.dart';

class SiteAdminAttendancePage extends StatefulWidget {
  final int workplaceId;
  final String workplaceName;

  const SiteAdminAttendancePage({
    super.key,
    required this.workplaceId,
    required this.workplaceName,
  });

  @override
  _SiteAdminAttendancePageState createState() =>
      _SiteAdminAttendancePageState();
}

class _SiteAdminAttendancePageState extends State<SiteAdminAttendancePage> {
  DateTime selectedDate = DateTime.now();
  List<dynamic> attendance = [];
  Map<String, dynamic> summary = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => isLoading = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final response = await http.get(
        Uri.parse(
            '${AppConfig.getWorkplaceAttendanceUrl}?workplace_id=${widget.workplaceId}&date=$dateStr'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            attendance = data['data'];
            summary = data['summary'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading attendance: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      _loadAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance - ${widget.workplaceName}'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          // Date picker
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(selectedDate),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _selectDate,
                  icon: Icon(Icons.calendar_today),
                  label: Text('Change Date'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),

          // Summary
          if (summary.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryCard(
                      'Present', summary['present'].toString(), Colors.green),
                  _buildSummaryCard(
                      'Absent', summary['absent'].toString(), Colors.red),
                  _buildSummaryCard(
                      'Total', summary['total'].toString(), Colors.blue),
                ],
              ),
            ),

          // Attendance list
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : attendance.isEmpty
                    ? Center(child: Text('No learners assigned'))
                    : ListView.builder(
                        itemCount: attendance.length,
                        itemBuilder: (context, index) {
                          final record = attendance[index];
                          final isPresent = record['status'] == 'Present';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  isPresent ? Colors.green : Colors.red,
                              child: Icon(
                                isPresent ? Icons.check : Icons.close,
                                color: Colors.white,
                              ),
                            ),
                            title:
                                Text('${record['Name']} ${record['Surname']}'),
                            subtitle: Text(
                              isPresent
                                  ? 'In: ${record['clock_in_time'] ?? 'N/A'} | Out: ${record['clock_out_time'] ?? 'N/A'}'
                                  : 'Absent',
                            ),
                            trailing: Chip(
                              label: Text(record['status']),
                              backgroundColor: isPresent
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
