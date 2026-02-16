import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class FinanceAttendanceCalendar extends StatefulWidget {
  final String learnerId;
  final String learnerName;
  final String classId;
  final String className;
  final String financeId;

  const FinanceAttendanceCalendar({
    Key? key,
    required this.learnerId,
    required this.learnerName,
    required this.classId,
    required this.className,
    required this.financeId,
  }) : super(key: key);

  @override
  _FinanceAttendanceCalendarState createState() => _FinanceAttendanceCalendarState();
}

class _FinanceAttendanceCalendarState extends State<FinanceAttendanceCalendar> {
  Set<DateTime> selectedDates = {};
  Set<DateTime> savedDates = {};
  DateTime? selectedMonth;
  bool isLoading = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default to current month
    selectedMonth = DateTime(2024, DateTime.now().month, 1);
    fetchAttendance();
  }

  Future<void> fetchAttendance() async {
    if (selectedMonth == null) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      final url = AppConfig.buildUrl(
        'get_learner_attendance.php?learner_id=${widget.learnerId}&month=${selectedMonth!.month}&year=${selectedMonth!.year}'
      );
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is List) {
          setState(() {
            savedDates = data.map((item) {
              return DateTime.parse(item['attendance_date']);
            }).toSet();
            selectedDates = Set.from(savedDates);
            isLoading = false;
          });
        } else {
          setState(() {
            savedDates = {};
            selectedDates = {};
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching attendance: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveAttendance() async {
    if (selectedMonth == null) return;
    
    setState(() {
      isSaving = true;
    });

    try {
      final url = AppConfig.buildUrl('save_learner_attendance.php');
      
      // Convert selected dates to list of date strings
      final dates = selectedDates.map((date) => date.toIso8601String().split('T')[0]).toList();
      
      final response = await http.post(
        Uri.parse(url),
        body: {
          'learner_id': widget.learnerId,
          'class_id': widget.classId,
          'finance_id': widget.financeId,
          'month': selectedMonth!.month.toString(),
          'year': selectedMonth!.year.toString(),
          'dates': json.encode(dates),
        },
      );

      setState(() {
        isSaving = false;
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Attendance saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            savedDates = Set.from(selectedDates);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Failed to save attendance'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        isSaving = false;
      });
      
      print('Error saving attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> selectMonth() async {
    final selected = await showMonthYearPicker(context);
    if (selected != null) {
      setState(() {
        selectedMonth = selected;
        selectedDates.clear();
        savedDates.clear();
      });
      fetchAttendance();
    }
  }

  Future<DateTime?> showMonthYearPicker(BuildContext context) async {
    DateTime? selectedDate;
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        int selectedMonthValue = selectedMonth?.month ?? DateTime.now().month;
        int selectedYear = 2024;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select Month'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Year: 2024', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    value: selectedMonthValue,
                    decoration: InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      final monthName = _getMonthName(month);
                      return DropdownMenuItem(
                        value: month,
                        child: Text(monthName),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        selectedMonthValue = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    selectedDate = DateTime(selectedYear, selectedMonthValue, 1);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );

    return selectedDate;
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  int _getFirstWeekdayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday;
  }

  bool _hasChanges() {
    if (selectedDates.length != savedDates.length) return true;
    return !selectedDates.every((date) => savedDates.contains(date));
  }

  @override
  Widget build(BuildContext context) {
    if (selectedMonth == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Attendance - ${widget.learnerName}'),
          backgroundColor: Colors.green[700],
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final daysInMonth = _getDaysInMonth(selectedMonth!);
    final firstWeekday = _getFirstWeekdayOfMonth(selectedMonth!);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance - ${widget.learnerName}'),
        backgroundColor: Colors.green[700],
        actions: [
          if (_hasChanges())
            IconButton(
              icon: Icon(Icons.save),
              onPressed: isSaving ? null : saveAttendance,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: Column(
        children: [
          // Month selector
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.green[50],
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.green[700]),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_getMonthName(selectedMonth!.month)} ${selectedMonth!.year}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[900],
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: selectMonth,
                  icon: Icon(Icons.edit_calendar, size: 18),
                  label: Text('Change Month'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Info banner
          Container(
            padding: EdgeInsets.all(12),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap on dates to mark attendance. Selected: ${selectedDates.length} days',
                    style: TextStyle(color: Colors.blue[900], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          
          // Calendar
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: _buildCalendar(daysInMonth, firstWeekday),
                  ),
          ),
          
          // Save button
          if (_hasChanges())
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : saveAttendance,
                  icon: isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.save),
                  label: Text(isSaving ? 'Saving...' : 'Save Attendance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendar(int daysInMonth, int firstWeekday) {
    return Column(
      children: [
        // Weekday headers
        Row(
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        SizedBox(height: 8),
        
        // Calendar grid
        _buildCalendarGrid(daysInMonth, firstWeekday),
      ],
    );
  }

  Widget _buildCalendarGrid(int daysInMonth, int firstWeekday) {
    List<Widget> weeks = [];
    List<Widget> currentWeek = [];
    
    // Add empty cells for days before the first day of month
    for (int i = 1; i < firstWeekday; i++) {
      currentWeek.add(Expanded(child: SizedBox()));
    }
    
    // Add day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(selectedMonth!.year, selectedMonth!.month, day);
      final isSelected = selectedDates.contains(date);
      final isSaved = savedDates.contains(date);
      
      currentWeek.add(
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  selectedDates.remove(date);
                } else {
                  selectedDates.add(date);
                }
              });
            },
            child: Container(
              margin: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.green[700]
                    : (isSaved ? Colors.green[100] : Colors.grey[100]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.green[900]! : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  day.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      
      // Start new week on Sunday
      if ((firstWeekday + day - 1) % 7 == 0 || day == daysInMonth) {
        // Fill remaining cells in the week
        while (currentWeek.length < 7) {
          currentWeek.add(Expanded(child: SizedBox()));
        }
        
        weeks.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 50,
              child: Row(children: currentWeek),
            ),
          ),
        );
        currentWeek = [];
      }
    }
    
    return Column(children: weeks);
  }
}
