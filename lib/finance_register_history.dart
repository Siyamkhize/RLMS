import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'finance_register_scanner.dart';

class FinanceRegisterHistory extends StatefulWidget {
  final String learnerId;
  final String learnerName;
  final String classId;
  final String className;
  final String financeId;

  const FinanceRegisterHistory({
    Key? key,
    required this.learnerId,
    required this.learnerName,
    required this.classId,
    required this.className,
    required this.financeId,
  }) : super(key: key);

  @override
  _FinanceRegisterHistoryState createState() => _FinanceRegisterHistoryState();
}

class _FinanceRegisterHistoryState extends State<FinanceRegisterHistory> {
  List<dynamic> registers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRegisters();
  }

  Future<void> fetchRegisters() async {
    setState(() {
      isLoading = true;
    });

    try {
      final url = AppConfig.buildUrl('get_learner_registers.php?learner_id=${widget.learnerId}');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is List) {
          setState(() {
            registers = data;
            isLoading = false;
          });
        } else {
          setState(() {
            registers = [];
            isLoading = false;
          });
        }
      } else {
        setState(() {
          registers = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching registers: $e');
      setState(() {
        registers = [];
        isLoading = false;
      });
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registers - ${widget.learnerName}'),
        backgroundColor: Colors.green[700],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.green[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green[700]),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'View scanned registers or mark new attendance',
                    style: TextStyle(color: Colors.green[900]),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : registers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_outlined, size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No registers scanned yet',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap the button below to mark attendance',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchRegisters,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: registers.length,
                          itemBuilder: (context, index) {
                            final register = registers[index];
                            return _buildRegisterCard(register);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FinanceRegisterScanner(
                learnerId: widget.learnerId,
                learnerName: widget.learnerName,
                classId: widget.classId,
                className: widget.className,
                financeId: widget.financeId,
              ),
            ),
          ).then((_) => fetchRegisters());
        },
        backgroundColor: Colors.green[700],
        icon: Icon(Icons.add),
        label: Text('Mark Attendance'),
      ),
    );
  }

  Widget _buildRegisterCard(Map<String, dynamic> register) {
    final month = register['register_month']?.toString() ?? '';
    final year = register['register_year']?.toString() ?? '';
    final uploadedAt = register['uploaded_at']?.toString() ?? '';
    final fileName = register['file_name']?.toString() ?? '';
    final monthName = month.isNotEmpty ? _getMonthName(int.parse(month)) : 'Unknown';
    final monthInt = month.isNotEmpty ? int.parse(month) : 0;
    final yearInt = year.isNotEmpty ? int.parse(year) : 0;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (monthInt > 0 && yearInt > 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FinanceRegisterScanner(
                  learnerId: widget.learnerId,
                  learnerName: widget.learnerName,
                  classId: widget.classId,
                  className: widget.className,
                  financeId: widget.financeId,
                  editMode: true,
                  editMonth: monthInt,
                  editYear: yearInt,
                ),
              ),
            ).then((_) => fetchRegisters());
          }
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.description, color: Colors.blue[700], size: 30),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$monthName $year',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Uploaded: ${_formatDate(uploadedAt)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    if (fileName.isNotEmpty)
                      Text(
                        fileName,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(Icons.edit, color: Colors.blue[700], size: 20),
                  SizedBox(height: 8),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    onPressed: () => _confirmDelete(monthName, year, monthInt, yearInt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String monthName, String year, int month, int yearInt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Register'),
        content: Text('Are you sure you want to delete the register for $monthName $year?\n\nThis will also delete all attendance records for this month.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteRegister(month, yearInt);
    }
  }

  Future<void> _deleteRegister(int month, int year) async {
    try {
      final url = AppConfig.buildUrl('delete_learner_register.php');
      final response = await http.post(
        Uri.parse(url),
        body: {
          'learner_id': widget.learnerId,
          'month': month.toString(),
          'year': year.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Register deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          fetchRegisters();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Failed to delete'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
