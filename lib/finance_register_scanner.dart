import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'config.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';

class FinanceRegisterScanner extends StatefulWidget {
  final String learnerId;
  final String learnerName;
  final String classId;
  final String className;
  final String financeId;
  final bool editMode;
  final int? editMonth;
  final int? editYear;

  const FinanceRegisterScanner({
    Key? key,
    required this.learnerId,
    required this.learnerName,
    required this.classId,
    required this.className,
    required this.financeId,
    this.editMode = false,
    this.editMonth,
    this.editYear,
  }) : super(key: key);

  @override
  _FinanceRegisterScannerState createState() => _FinanceRegisterScannerState();
}

class _FinanceRegisterScannerState extends State<FinanceRegisterScanner> {
  Set<DateTime> selectedDates = {};
  Set<DateTime> savedDates = {};
  DateTime? selectedMonth;
  bool isLoading = false;
  bool isSaving = false;
  String? scannedDocumentPath;
  bool showScanner = false;

  // South African Public Holidays for 2024
  final Map<DateTime, String> holidays = {
    DateTime(2024, 1, 1): "New Year's Day",
    DateTime(2024, 3, 21): "Human Rights Day",
    DateTime(2024, 3, 29): "Good Friday",
    DateTime(2024, 4, 1): "Family Day",
    DateTime(2024, 4, 27): "Freedom Day",
    DateTime(2024, 5, 1): "Workers' Day",
    DateTime(2024, 6, 16): "Youth Day",
    DateTime(2024, 6, 17): "Youth Day (Observed)",
    DateTime(2024, 8, 9): "National Women's Day",
    DateTime(2024, 9, 24): "Heritage Day",
    DateTime(2024, 12, 16): "Day of Reconciliation",
    DateTime(2024, 12, 25): "Christmas Day",
    DateTime(2024, 12, 26): "Day of Goodwill",
  };

  @override
  void initState() {
    super.initState();
    
    // If in edit mode, set the month directly and load attendance
    if (widget.editMode && widget.editMonth != null && widget.editYear != null) {
      selectedMonth = DateTime(widget.editYear!, widget.editMonth!, 1);
      fetchAttendance();
    } else {
      // Show month picker immediately when page opens
      WidgetsBinding.instance.addPostFrameCallback((_) {
        selectMonth();
      });
    }
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  String? _getHoliday(DateTime date) {
    return holidays[DateTime(date.year, date.month, date.day)];
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
        
        print('Fetched attendance data: $data');
        
        if (data is List) {
          setState(() {
            savedDates = data.map((item) {
              // Parse the date and normalize to midnight
              final dateStr = item['attendance_date'];
              final parsedDate = DateTime.parse(dateStr);
              // Normalize to midnight to ensure proper comparison
              return DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
            }).toSet();
            selectedDates = Set.from(savedDates);
            isLoading = false;
            
            print('Loaded ${savedDates.length} attendance dates');
            print('Selected dates: $selectedDates');
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

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          // Save attendance successful, now upload scanned document if available
          if (scannedDocumentPath != null) {
            await uploadRegister(scannedDocumentPath!);
          }
          
          setState(() {
            isSaving = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                scannedDocumentPath != null 
                  ? 'Attendance and register saved successfully!'
                  : 'Attendance updated successfully!'
              ),
              backgroundColor: Colors.green,
            ),
          );
          
          Navigator.pop(context);
        } else {
          setState(() {
            isSaving = false;
          });
          
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

  Future<void> uploadRegister(String imagePath) async {
    try {
      final url = AppConfig.buildUrl('upload_learner_register.php');
      final request = http.MultipartRequest('POST', Uri.parse(url));

      request.fields['learner_id'] = widget.learnerId;
      request.fields['class_id'] = widget.classId;
      request.fields['finance_id'] = widget.financeId;
      request.fields['register_month'] = selectedMonth!.month.toString();
      request.fields['register_year'] = selectedMonth!.year.toString();

      final file = File(imagePath);
      if (await file.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('register_file', imagePath),
        );
      }

      await request.send();
    } catch (e) {
      print('Error uploading register: $e');
    }
  }

  Future<void> proceedToScanner() async {
    if (selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one attendance day'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final docScanner = FlutterDocScanner();
      final scannedImage = await docScanner.getScanDocuments();

      print('Scanned image result: $scannedImage');
      print('Scanned image type: ${scannedImage.runtimeType}');

      if (scannedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No document scanned')),
        );
        return;
      }

      String? imagePath;
      
      if (scannedImage is String) {
        imagePath = scannedImage;
      } else if (scannedImage is List && scannedImage.isNotEmpty) {
        imagePath = scannedImage.first.toString();
      } else if (scannedImage is Map) {
        imagePath = scannedImage['pdfUri']?.toString() ?? 
                   scannedImage['path']?.toString() ?? 
                   scannedImage['scanned_path']?.toString() ??
                   scannedImage['file_path']?.toString() ??
                   scannedImage['scannedPath']?.toString() ??
                   scannedImage['filePath']?.toString();
        
        if (imagePath == null) {
          for (var value in scannedImage.values) {
            if (value != null && value.toString().contains('/')) {
              imagePath = value.toString();
              break;
            }
          }
        }
      }

      if (imagePath != null && imagePath.startsWith('file://')) {
        imagePath = imagePath.substring(7);
      }

      if (imagePath == null || imagePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get scanned document path'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      setState(() {
        scannedDocumentPath = imagePath;
        showScanner = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document scanned! Click Save to complete.'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      print('Error scanning: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
    } else {
      // User cancelled month selection, go back
      if (selectedMonth == null) {
        Navigator.pop(context);
      }
    }
  }

  Future<DateTime?> showMonthYearPicker(BuildContext context) async {
    DateTime? selectedDate;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        int selectedMonthValue = DateTime.now().month;
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
                  child: Text('Continue'),
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
    return selectedDates.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (selectedMonth == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Mark Attendance - ${widget.learnerName}'),
          backgroundColor: Colors.green[700],
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final daysInMonth = _getDaysInMonth(selectedMonth!);
    final firstWeekday = _getFirstWeekdayOfMonth(selectedMonth!);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Mark Attendance - ${widget.learnerName}'),
        backgroundColor: Colors.green[700],
      ),
      body: Column(
        children: [
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
          
          Container(
            padding: EdgeInsets.all(12),
            color: scannedDocumentPath != null ? Colors.green[50] : Colors.blue[50],
            child: Row(
              children: [
                Icon(
                  scannedDocumentPath != null ? Icons.check_circle : Icons.info_outline,
                  color: scannedDocumentPath != null ? Colors.green[700] : Colors.blue[700],
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scannedDocumentPath != null
                        ? 'Document scanned! Selected: ${selectedDates.length} days. Click Save to complete.'
                        : widget.editMode
                            ? 'Edit mode: Modify attendance days. Weekends are disabled. Selected: ${selectedDates.length} days'
                            : 'Tap on dates to mark attendance. Weekends are disabled. Selected: ${selectedDates.length} days',
                    style: TextStyle(
                      color: scannedDocumentPath != null ? Colors.green[900] : Colors.blue[900],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: _buildCalendar(daysInMonth, firstWeekday),
                  ),
          ),
          
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
                child: widget.editMode
                    ? Column(
                        children: [
                          // In edit mode, show save button directly
                          ElevatedButton.icon(
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
                            label: Text(isSaving ? 'Saving...' : 'Save Attendance Changes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(height: 8),
                          // Optional: Re-scan button
                          OutlinedButton.icon(
                            onPressed: proceedToScanner,
                            icon: Icon(Icons.document_scanner),
                            label: Text('Re-scan Register (Optional)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue[700],
                              padding: EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.blue[700]!),
                            ),
                          ),
                        ],
                      )
                    : scannedDocumentPath == null
                        ? ElevatedButton.icon(
                            onPressed: proceedToScanner,
                            icon: Icon(Icons.document_scanner),
                            label: Text('Continue to Scan Register'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          )
                        : ElevatedButton.icon(
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
                            label: Text(isSaving ? 'Saving...' : 'Save Attendance & Register'),
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
        
        _buildCalendarGrid(daysInMonth, firstWeekday),
      ],
    );
  }

  Widget _buildCalendarGrid(int daysInMonth, int firstWeekday) {
    List<Widget> weeks = [];
    List<Widget> currentWeek = [];
    
    for (int i = 1; i < firstWeekday; i++) {
      currentWeek.add(Expanded(child: SizedBox()));
    }
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(selectedMonth!.year, selectedMonth!.month, day);
      final isSelected = selectedDates.contains(date);
      final isSaved = savedDates.contains(date);
      final isWeekend = _isWeekend(date);
      final holiday = _getHoliday(date);
      
      // Debug: Print first few dates to check comparison
      if (day <= 3) {
        print('Day $day: date=$date, isSelected=$isSelected, isSaved=$isSaved');
      }
      
      currentWeek.add(
        Expanded(
          child: GestureDetector(
            onTap: isWeekend ? null : () {
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
                color: isWeekend
                    ? Colors.grey[300]
                    : (isSelected
                        ? Colors.green[700]
                        : (isSaved ? Colors.green[100] : Colors.grey[100])),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isWeekend
                      ? Colors.grey[400]!
                      : (isSelected ? Colors.green[900]! : Colors.grey[300]!),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day.toString(),
                    style: TextStyle(
                      color: isWeekend
                          ? Colors.grey[600]
                          : (isSelected ? Colors.white : Colors.black87),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  if (holiday != null)
                    Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Text(
                        'Holiday',
                        style: TextStyle(
                          fontSize: 8,
                          color: isWeekend
                              ? Colors.grey[600]
                              : (isSelected ? Colors.white : Colors.red[700]),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      
      if ((firstWeekday + day - 1) % 7 == 0 || day == daysInMonth) {
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
