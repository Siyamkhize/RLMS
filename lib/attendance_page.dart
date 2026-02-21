import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_helper.dart';
import 'config.dart';

class AttendancePage extends StatefulWidget {
  final String classID;

  const AttendancePage({
    super.key,
    required this.classID,
  });

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<Map<String, dynamic>> learnerAttendance = [];
  bool isLoading = true;
  bool isSyncing = false;
  DateTime selectedMonth = DateTime.now();
  double totalStipend = 2000.0;
  List<DateTime> holidays = []; // Store holidays for the month

  @override
  void initState() {
    super.initState();
    _loadMonthlyAttendance();
  }

  // Check if a date is a public holiday
  bool _isPublicHoliday(DateTime date) {
    // Add South African public holidays here
    // Format: 'YYYY-MM-DD'
    final dateStr = date.toIso8601String().substring(0, 10);

    // Common fixed holidays
    final fixedHolidays = [
      '${date.year}-01-01', // New Year's Day
      '${date.year}-03-21', // Human Rights Day
      '${date.year}-04-27', // Freedom Day
      '${date.year}-05-01', // Workers' Day
      '${date.year}-06-16', // Youth Day
      '${date.year}-08-09', // National Women's Day
      '${date.year}-09-24', // Heritage Day
      '${date.year}-12-16', // Day of Reconciliation
      '${date.year}-12-25', // Christmas Day
      '${date.year}-12-26', // Day of Goodwill
    ];

    return fixedHolidays.contains(dateStr) ||
        holidays.any((h) =>
            h.year == date.year && h.month == date.month && h.day == date.day);
  }

  int _calculateWorkingDays(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    int workingDays = 0;

    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(year, month, day);
      // Exclude weekends (Saturday = 6, Sunday = 7)
      if (date.weekday != DateTime.saturday &&
          date.weekday != DateTime.sunday) {
        workingDays++;
      }
    }

    return workingDays;
  }

  int _countHolidaysInMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    int holidayCount = 0;

    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(year, month, day);
      // Count holidays that fall on working days (not weekends)
      if (date.weekday != DateTime.saturday &&
          date.weekday != DateTime.sunday &&
          _isPublicHoliday(date)) {
        holidayCount++;
      }
    }

    return holidayCount;
  }

  // Calculate working days between two dates (excluding weekends)
  int _calculateWorkingDaysBetween(DateTime startDate, DateTime endDate) {
    int workingDays = 0;
    DateTime current = startDate;

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        workingDays++;
      }
      current = current.add(const Duration(days: 1));
    }

    return workingDays;
  }

  // Get approved sick note days for a learner in the month
  Future<int> _getApprovedSickNoteDays(
      int learnerId, String firstDayStr, String lastDayStr) async {
    try {
      final db = await DatabaseHelper().database;

      // Get approved sick notes that overlap with the month
      // Note: Using date_from/date_to as per the actual database schema
      final sickNotes = await db.rawQuery('''
        SELECT date_from, date_to 
        FROM sick_note 
        WHERE learner_id = ? 
        AND status = 'APPROVED'
        AND (
          (date_from <= ? AND date_to >= ?) OR
          (date_from >= ? AND date_from <= ?) OR
          (date_to >= ? AND date_to <= ?)
        )
      ''', [
        learnerId,
        lastDayStr,
        firstDayStr,
        firstDayStr,
        lastDayStr,
        firstDayStr,
        lastDayStr
      ]);

      int totalSickDays = 0;
      final monthStart = DateTime.parse(firstDayStr);
      final monthEnd = DateTime.parse(lastDayStr);

      for (final note in sickNotes) {
        final startDate = DateTime.parse(note['date_from'].toString());
        final endDate = DateTime.parse(note['date_to'].toString());

        // Clamp dates to the current month
        final effectiveStart =
            startDate.isBefore(monthStart) ? monthStart : startDate;
        final effectiveEnd = endDate.isAfter(monthEnd) ? monthEnd : endDate;

        // Calculate working days (excluding weekends)
        totalSickDays +=
            _calculateWorkingDaysBetween(effectiveStart, effectiveEnd);
      }

      return totalSickDays;
    } catch (e) {
      print(
          '[ATTENDANCE] Error getting sick note days for learner $learnerId: $e');
      return 0;
    }
  }

  // Sync attendance data from server and return the data
  Future<List<Map<String, dynamic>>?> _syncAttendanceFromServer(
      {bool showMessage = false}) async {
    if (isSyncing) return null;

    setState(() {
      isSyncing = true;
    });

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult is List
          ? (connectivityResult.isEmpty ||
              connectivityResult.first == ConnectivityResult.none)
          : (connectivityResult == ConnectivityResult.none);

      if (isOffline) {
        print('[ATTENDANCE] No internet connection - skipping server sync');
        if (showMessage && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No internet connection'),
                backgroundColor: Colors.orange),
          );
        }
        return null;
      }

      final monthStr =
          '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';

      // Add cache-busting parameter to force fresh data
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse(
          '${AppConfig.getAttendanceUrl}?classID=${widget.classID}&month=$monthStr&_t=$timestamp');

      print('[ATTENDANCE] Syncing from server: $url');

      // Add headers to prevent caching
      final response = await http.get(
        url,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('[ATTENDANCE] Server response: $data');

        if (data['success'] == true) {
          print(
              '[ATTENDANCE] Server sync successful: ${data['data'].length} records');
          if (data['data'].isNotEmpty) {
            print(
                '[ATTENDANCE] First server record from API: ${data['data'][0]}');
          }

          if (showMessage && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Synced ${data['data'].length} records from server'),
                  backgroundColor: Colors.green),
            );
          }

          // Return the server data
          final List<Map<String, dynamic>> serverData = [];
          for (var item in data['data']) {
            serverData.add(Map<String, dynamic>.from(item));
          }
          return serverData;
        } else {
          print('[ATTENDANCE] Server sync failed: ${data['error']}');
          if (showMessage && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Sync failed: ${data['error']}'),
                  backgroundColor: Colors.red),
            );
          }
        }
      } else {
        print('[ATTENDANCE] Server returned status: ${response.statusCode}');
        if (showMessage && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Server error: ${response.statusCode}'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('[ATTENDANCE] Error syncing from server: $e');
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Sync error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSyncing = false;
        });
      }
    }
    return null;
  }

  Future<void> _loadMonthlyAttendance() async {
    setState(() {
      isLoading = true;
    });

    try {
      // ONLY USE SERVER DATA - NO LOCAL DATABASE
      final serverData = await _syncAttendanceFromServer(showMessage: false);

      // Calculate working days and holidays for the month
      final workingDays =
          _calculateWorkingDays(selectedMonth.year, selectedMonth.month);
      final holidaysInMonth =
          _countHolidaysInMonth(selectedMonth.year, selectedMonth.month);
      final expectedDays = workingDays;
      final dailyRate = totalStipend / expectedDays;

      print(
          '[ATTENDANCE] Working days: $workingDays, Holidays: $holidaysInMonth, Daily rate: $dailyRate');
      print(
          '[ATTENDANCE] Server data: ${serverData != null ? serverData.length : 0} records');

      if (serverData != null && serverData.isNotEmpty) {
        // Use server data
        print('[ATTENDANCE] ✅ Using server data: ${serverData.length} records');
        print('[ATTENDANCE] First server record: ${serverData.first}');

        final List<Map<String, dynamic>> mappedData = [];

        for (final record in serverData) {
          // Get values from server
          final totalDaysAttended = (record['total_days_attended'] is int)
              ? record['total_days_attended'] as int
              : int.tryParse(record['total_days_attended'].toString()) ?? 0;

          // Use daily_rate from server
          final serverDailyRate = (record['daily_rate'] != null)
              ? (record['daily_rate'] is double
                  ? record['daily_rate'] as double
                  : double.tryParse(record['daily_rate'].toString()) ??
                      dailyRate)
              : dailyRate;

          // Use amount_due from server
          final totalDue = (record['amount_due'] != null)
              ? (record['amount_due'] is double
                  ? record['amount_due'] as double
                  : double.tryParse(record['amount_due'].toString()) ?? 0.0)
              : serverDailyRate * totalDaysAttended;

          mappedData.add({
            'LearnerID': record['LearnerID'],
            'Name': record['Name'],
            'Surname': record['Surname'],
            'days_clocked': record['days_clocked'] ?? 0,
            'manual_days_clocked': record['manual_days_clocked'] ?? 0,
            'sick_note_days': record['sick_note_days'] ?? 0,
            'days_attended': totalDaysAttended,
            'expected_days': expectedDays,
            'daily_rate': serverDailyRate,
            'total_due': totalDue,
            'holidays': holidaysInMonth,
          });
        }

        print('[ATTENDANCE] ✅ Mapped ${mappedData.length} records from server');
        if (mappedData.isNotEmpty) {
          print('[ATTENDANCE] First mapped record: ${mappedData.first}');
          print(
              '[ATTENDANCE] Days attended: ${mappedData.first['days_attended']}/${mappedData.first['expected_days']}');
        }

        setState(() {
          learnerAttendance = mappedData;
          isLoading = false;
        });

        print(
            '[ATTENDANCE] ✅ Server data loaded successfully with ${mappedData.length} learners');
      } else {
        // No server data
        print('[ATTENDANCE] ❌ No server data available');

        setState(() {
          learnerAttendance = [];
          isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Unable to load attendance data from server'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _loadMonthlyAttendance,
              ),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('[ATTENDANCE] ❌ Error loading attendance: $e');
      print('[ATTENDANCE] Stack trace: $stackTrace');

      setState(() {
        learnerAttendance = [];
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadMonthlyAttendance,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        '[ATTENDANCE BUILD] Building with ${learnerAttendance.length} learners, isLoading: $isLoading');

    final monthName = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ][selectedMonth.month - 1];

    final expectedDays = learnerAttendance.isNotEmpty
        ? learnerAttendance[0]['expected_days'] as int
        : _calculateWorkingDays(selectedMonth.year, selectedMonth.month);

    final holidaysInMonth = learnerAttendance.isNotEmpty
        ? learnerAttendance[0]['holidays'] as int
        : _countHolidaysInMonth(selectedMonth.year, selectedMonth.month);

    final dailyRate = totalStipend / expectedDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Attendance'),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          if (isSyncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.blue),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_download),
              onPressed: () async {
                await _syncAttendanceFromServer(showMessage: true);
                await _loadMonthlyAttendance();
              },
              tooltip: 'Sync from Server',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMonthlyAttendance,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Month and stipend info
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$monthName ${selectedMonth.year}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Class: ${widget.classID}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Expected Days: $expectedDays',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Daily Rate: R ${dailyRate.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Holidays in month: $holidaysInMonth day(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Summary
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSummaryItem(
                  'Learners',
                  learnerAttendance.length.toString(),
                  Colors.blue,
                ),
              ],
            ),
          ),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildHeaderCell('Surname')),
                Expanded(flex: 3, child: _buildHeaderCell('Name')),
                Expanded(flex: 2, child: _buildHeaderCell('Days\nAttended')),
                Expanded(flex: 2, child: _buildHeaderCell('Daily\nRate')),
                Expanded(flex: 2, child: _buildHeaderCell('Total\nDue')),
              ],
            ),
          ),

          // Attendance table
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : learnerAttendance.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inbox,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No learners found for this class',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Class ID: ${widget.classID}',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                // Show debug info
                                final db = await DatabaseHelper().database;
                                final allClasses = await db.rawQuery('''
                                  SELECT DISTINCT classID, COUNT(*) as count 
                                  FROM learnerdetails 
                                  WHERE classID IS NOT NULL 
                                  GROUP BY classID
                                  ORDER BY count DESC
                                ''');

                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Debug Info'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                              'Current Class ID: ${widget.classID}'),
                                          const SizedBox(height: 16),
                                          const Text('Available Classes:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          ...allClasses.map((c) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 4),
                                                child: Text(
                                                    '• ${c['classID']}: ${c['count']} learners'),
                                              )),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.bug_report),
                              label: const Text('Show Debug Info'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: learnerAttendance.length,
                        itemBuilder: (context, index) {
                          final record = learnerAttendance[index];
                          return _buildTableRow(record, index);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> record, int index) {
    final daysAttended = record['days_attended'] as int;
    final daysClocked = record['days_clocked'] as int;
    final sickNoteDays = record['sick_note_days'] as int;
    final manualDaysClocked = record['manual_days_clocked'] ?? 0;
    final expectedDays = record['expected_days'] as int;
    final dailyRate = record['daily_rate'] as double;
    final totalDue = record['total_due'] as double;
    final holidays = record['holidays'] as int;

    final bgColor = index % 2 == 0 ? Colors.white : Colors.grey.shade50;

    // Build breakdown tooltip
    final breakdown =
        'Regular: $daysClocked\nManual: $manualDaysClocked\nSick Notes: $sickNoteDays\nHolidays: $holidays\nTotal: $daysAttended';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _buildTableCell(record['Surname'].toString(), isBold: true),
          ),
          Expanded(
            flex: 3,
            child: _buildTableCell(record['Name'].toString()),
          ),
          Expanded(
            flex: 2,
            child: Tooltip(
              message: breakdown,
              child: _buildTableCell(
                '$daysAttended/$expectedDays',
                color: daysAttended > expectedDays * 0.8
                    ? Colors.green.shade700
                    : daysAttended > expectedDays * 0.5
                        ? Colors.orange.shade700
                        : Colors.red.shade700,
                isBold: true,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildTableCell('R${dailyRate.toStringAsFixed(0)}',
                fontSize: 11),
          ),
          Expanded(
            flex: 2,
            child: _buildTableCell(
              'R${totalDue.toStringAsFixed(0)}',
              color: Colors.green.shade700,
              isBold: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text,
      {Color? color, bool isBold = false, double fontSize = 12}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        color: color ?? Colors.black87,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
