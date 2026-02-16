import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'monitoring_service.dart';

class MonitoringDashboardPage extends StatefulWidget {
  final String classID;

  const MonitoringDashboardPage({
    super.key,
    required this.classID,
  });

  @override
  State<MonitoringDashboardPage> createState() =>
      _MonitoringDashboardPageState();
}

class _MonitoringDashboardPageState extends State<MonitoringDashboardPage>
    with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late TabController _tabController;

  List<Map<String, dynamic>> _todayRecords = [];
  List<Map<String, dynamic>> _weeklyStats = [];
  List<Map<String, dynamic>> _availablePeople = [];
  bool _isLoading = true;

  // Statistics
  int _totalLearners = 0;
  int _presentCount = 0;
  int _absentCount = 0;
  int _pendingCount = 0;
  double _attendanceRate = 0.0;

  // Service status
  bool _isServiceRunning = false;
  int _availablePeopleCount = 0;
  int _verifiedTodayCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboardData();
    _updateServiceStatus();

    // Update service status every 30 seconds
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _updateServiceStatus();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateServiceStatus() {
    setState(() {
      _isServiceRunning = MonitoringService().isServiceRunning;
      _availablePeopleCount = MonitoringService().availablePeopleCount;
      _verifiedTodayCount = MonitoringService().verifiedTodayCount;
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.wait([
      _loadTodayRecords(),
      _loadWeeklyStats(),
      _loadAvailablePeople(),
      _calculateStatistics(),
    ]);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadAvailablePeople() async {
    try {
      final people =
          await _dbHelper.getAllClockedInPeopleForClass(widget.classID);
      setState(() {
        _availablePeople = people;
      });
    } catch (e) {
      debugPrint('[MONITORING_DASHBOARD] Error loading available people: $e');
    }
  }

  Future<void> _loadTodayRecords() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final db = await _dbHelper.database;

      final records = await db.query(
        'monitoring_records',
        where: 'monitoring_date = ?',
        whereArgs: [today],
        orderBy: 'created_at DESC',
      );

      setState(() {
        _todayRecords = records;
      });
    } catch (e) {
      print('[MONITORING_DASHBOARD] Error loading today\'s records: $e');
    }
  }

  Future<void> _loadWeeklyStats() async {
    try {
      final db = await _dbHelper.database;
      final today = DateTime.now();
      final weekAgo = today.subtract(Duration(days: 7));

      final records = await db.rawQuery('''
        SELECT 
          monitoring_date,
          COUNT(*) as total_monitored,
          SUM(CASE WHEN final_status = 'PRESENT' THEN 1 ELSE 0 END) as present_count,
          SUM(CASE WHEN final_status = 'ABSENT' THEN 1 ELSE 0 END) as absent_count,
          SUM(CASE WHEN final_status = 'IN_PROGRESS' THEN 1 ELSE 0 END) as pending_count
        FROM monitoring_records 
        WHERE monitoring_date >= ? AND monitoring_date <= ?
        GROUP BY monitoring_date
        ORDER BY monitoring_date DESC
      ''', [
        DateFormat('yyyy-MM-dd').format(weekAgo),
        DateFormat('yyyy-MM-dd').format(today),
      ]);

      setState(() {
        _weeklyStats = records;
      });
    } catch (e) {
      print('[MONITORING_DASHBOARD] Error loading weekly stats: $e');
    }
  }

  Future<void> _calculateStatistics() async {
    try {
      // Get today's clocked in learners
      final clockedInLearners = await _dbHelper.getClockingDataForToday();

      // Calculate stats from today's monitoring records
      int present = 0;
      int absent = 0;
      int pending = 0;

      for (var record in _todayRecords) {
        switch (record['final_status']) {
          case 'PRESENT':
            present++;
            break;
          case 'ABSENT':
            absent++;
            break;
          case 'IN_PROGRESS':
            pending++;
            break;
        }
      }

      final totalMonitored = present + absent + pending;
      final attendanceRate =
          totalMonitored > 0 ? (present / totalMonitored) * 100 : 0.0;

      setState(() {
        _totalLearners = clockedInLearners.length;
        _presentCount = present;
        _absentCount = absent;
        _pendingCount = pending;
        _attendanceRate = attendanceRate;
      });
    } catch (e) {
      print('[MONITORING_DASHBOARD] Error calculating statistics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Monitoring Dashboard'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Service Status Indicator
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isServiceRunning
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isServiceRunning ? Colors.green : Colors.red,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isServiceRunning ? Icons.play_circle : Icons.pause_circle,
                  size: 16,
                  color: _isServiceRunning ? Colors.green : Colors.red,
                ),
                SizedBox(width: 4),
                Text(
                  _isServiceRunning ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isServiceRunning ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.people), text: 'People'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blue[600]),
                  SizedBox(height: 16),
                  Text('Loading monitoring data...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildPeopleTab(),
                _buildAnalyticsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Status Card
          _buildServiceStatusCard(),
          SizedBox(height: 16),

          // Quick Stats
          _buildQuickStatsGrid(),
          SizedBox(height: 16),

          // Today's Progress
          _buildTodayProgressCard(),
          SizedBox(height: 16),

          // Recent Activity
          _buildRecentActivityCard(),
        ],
      ),
    );
  }

  Widget _buildServiceStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: _isServiceRunning
                ? [Colors.green[400]!, Colors.green[600]!]
                : [Colors.orange[400]!, Colors.orange[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isServiceRunning ? Icons.radar : Icons.pause_circle,
                color: Colors.white,
                size: 32,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monitoring Service',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _isServiceRunning ? 'Active & Running' : 'Inactive',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      _buildServiceStat(
                          'Available', _availablePeopleCount.toString()),
                      SizedBox(width: 16),
                      _buildServiceStat(
                          'Verified', _verifiedTodayCount.toString()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildModernStatCard(
          'Total People',
          _totalLearners.toString(),
          Colors.blue,
          Icons.people,
        ),
        _buildModernStatCard(
          'Present Today',
          _presentCount.toString(),
          Colors.green,
          Icons.check_circle,
        ),
        _buildModernStatCard(
          'Absent Today',
          _absentCount.toString(),
          Colors.red,
          Icons.cancel,
        ),
        _buildModernStatCard(
          'Attendance Rate',
          '${_attendanceRate.toStringAsFixed(1)}%',
          Colors.orange,
          Icons.trending_up,
        ),
      ],
    );
  }

  Widget _buildModernStatCard(
      String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayProgressCard() {
    final totalMonitored = _presentCount + _absentCount + _pendingCount;
    final progressValue =
        totalMonitored > 0 ? _presentCount / totalMonitored : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Rate',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progressValue,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressValue >= 0.8
                              ? Colors.green
                              : progressValue >= 0.6
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                        minHeight: 8,
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${(progressValue * 100).toStringAsFixed(1)}% Present',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: progressValue >= 0.8
                              ? Colors.green
                              : progressValue >= 0.6
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 20),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        totalMonitored.toString(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[600],
                        ),
                      ),
                      Text(
                        'Monitored',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    final recentRecords = _todayRecords.take(5).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: Text('View All'),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (recentRecords.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                    SizedBox(height: 8),
                    Text(
                      'No monitoring activity today',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              ...recentRecords
                  .map((record) => _buildActivityItem(record))
                  ,
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> record) {
    final status = record['final_status'];
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'PRESENT':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'ABSENT':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['learner_name'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Status: $status',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (record['verification_time'] != null)
            Text(
              DateFormat('HH:mm')
                  .format(DateTime.parse(record['verification_time'])),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeopleTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Available People Card
          _buildAvailablePeopleCard(),
          SizedBox(height: 16),

          // Today's Records
          _buildTodayRecordsCard(),
        ],
      ),
    );
  }

  Widget _buildAvailablePeopleCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available for Monitoring',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            if (_availablePeople.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline,
                        size: 48, color: Colors.grey[400]),
                    SizedBox(height: 8),
                    Text(
                      'No people clocked in today',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _availablePeople.length,
                itemBuilder: (context, index) {
                  final person = _availablePeople[index];
                  final isVerified = _todayRecords.any((record) =>
                      record['learner_id'] ==
                          (person['person_type'] == 'facilitator'
                              ? 'F${person['person_id']}'
                              : person['person_id'].toString()) &&
                      record['final_status'] == 'PRESENT');

                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isVerified ? Colors.green[50] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            isVerified ? Colors.green[200]! : Colors.grey[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              person['person_type'] == 'facilitator'
                                  ? Colors.purple[400]
                                  : Colors.blue[400],
                          child: Icon(
                            person['person_type'] == 'facilitator'
                                ? Icons.school
                                : Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                person['person_name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${person['person_type'] == 'facilitator' ? 'Facilitator' : 'Learner'} ID: ${person['person_id']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isVerified
                                ? Colors.green[100]
                                : Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isVerified ? 'Verified' : 'Pending',
                            style: TextStyle(
                              color: isVerified
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayRecordsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Monitoring Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            if (_todayRecords.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.assignment, size: 48, color: Colors.grey[400]),
                    SizedBox(height: 8),
                    Text(
                      'No monitoring records for today',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _todayRecords.length,
                itemBuilder: (context, index) {
                  final record = _todayRecords[index];
                  return _buildRecordItem(record);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordItem(Map<String, dynamic> record) {
    final status = record['final_status'];
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'PRESENT':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'ABSENT':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['learner_name'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Status: $status',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (record['verification_time'] != null)
                  Text(
                    'Verified: ${DateFormat('HH:mm').format(DateTime.parse(record['verification_time']))}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Attempts',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                _getAttemptCount(record).toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWeeklyTrendsCard(),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrendsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Monitoring Trends',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 20),
            if (_weeklyStats.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.analytics, size: 48, color: Colors.grey[400]),
                    SizedBox(height: 8),
                    Text(
                      'No data available for the past week',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _weeklyStats.length,
                  itemBuilder: (context, index) {
                    final stat = _weeklyStats[index];
                    final date = DateTime.parse(stat['monitoring_date']);
                    final dayName = DateFormat('EEE').format(date);
                    final presentCount = stat['present_count'] ?? 0;
                    final absentCount = stat['absent_count'] ?? 0;
                    final total = presentCount + absentCount;

                    return Container(
                      width: 80,
                      margin: EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Present bar
                          if (presentCount > 0)
                            Container(
                              height: (presentCount / (total > 0 ? total : 1)) *
                                  150,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green[400]!,
                                    Colors.green[600]!
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          // Absent bar
                          if (absentCount > 0)
                            Container(
                              height:
                                  (absentCount / (total > 0 ? total : 1)) * 150,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.red[400]!, Colors.red[600]!],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.vertical(
                                  bottom: presentCount == 0
                                      ? Radius.circular(4)
                                      : Radius.zero,
                                  top: presentCount == 0
                                      ? Radius.circular(4)
                                      : Radius.zero,
                                ),
                              ),
                            ),
                          SizedBox(height: 12),
                          Text(
                            dayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            DateFormat('MM/dd').format(date),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            total.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (_weeklyStats.isNotEmpty) ...[
              SizedBox(height: 20),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green[400]!, Colors.green[600]!],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Present',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  SizedBox(width: 24),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red[400]!, Colors.red[600]!],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Absent',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _getAttemptCount(Map<String, dynamic> record) {
    int count = 0;
    if (record['attempt_1_time'] != null) count++;
    if (record['attempt_2_time'] != null) count++;
    if (record['attempt_3_time'] != null) count++;
    return count;
  }
}
