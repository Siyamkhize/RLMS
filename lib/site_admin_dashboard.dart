import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'site_admin_workplace_clocking.dart';
import 'site_admin_attendance_page.dart';

class SiteAdminDashboard extends StatefulWidget {
  final int accountId;
  final String username;

  const SiteAdminDashboard({
    super.key,
    required this.accountId,
    required this.username,
  });

  @override
  _SiteAdminDashboardState createState() => _SiteAdminDashboardState();
}

class _SiteAdminDashboardState extends State<SiteAdminDashboard> {
  List<dynamic> workplaces = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkplaces();
  }

  Future<void> _loadWorkplaces() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
            '${AppConfig.getSiteAdminWorkplacesUrl}?account_id=${widget.accountId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            workplaces = data['data'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading workplaces: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Site Admin Dashboard'),
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWorkplaces,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.blue.shade50,
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 40, color: Colors.blue),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${widget.username}',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${workplaces.length} Workplace(s) Assigned',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: workplaces.isEmpty
                        ? Center(
                            child: Text('No workplaces assigned'),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: workplaces.length,
                            itemBuilder: (context, index) {
                              final workplace = workplaces[index];
                              final presentToday =
                                  workplace['present_today'] ?? 0;
                              final totalLearners =
                                  workplace['total_learners'] ?? 0;
                              final percentage = totalLearners > 0
                                  ? (presentToday / totalLearners * 100)
                                      .toStringAsFixed(0)
                                  : '0';

                              return Card(
                                margin: EdgeInsets.only(bottom: 16),
                                elevation: 3,
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.location_on,
                                              color: Colors.blue),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              workplace['workplace_name'],
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildStat('Present',
                                                '$presentToday', Colors.green),
                                            _buildStat('Total',
                                                '$totalLearners', Colors.blue),
                                            _buildStat(
                                                'Rate',
                                                '$percentage%',
                                                int.parse(percentage) >= 80
                                                    ? Colors.green
                                                    : Colors.orange),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        SiteAdminWorkplaceClocking(
                                                      workplaceId: workplace[
                                                          'workplace_id'],
                                                      workplaceName: workplace[
                                                          'workplace_name'],
                                                      latitude: double.parse(
                                                          workplace['latitude']
                                                              .toString()),
                                                      longitude: double.parse(
                                                          workplace['longitude']
                                                              .toString()),
                                                      radiusMeters: workplace[
                                                          'radius_meters'],
                                                    ),
                                                  ),
                                                ).then(
                                                    (_) => _loadWorkplaces());
                                              },
                                              icon: Icon(Icons.fingerprint),
                                              label: Text('Clock Learners'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        SiteAdminAttendancePage(
                                                      workplaceId: workplace[
                                                          'workplace_id'],
                                                      workplaceName: workplace[
                                                          'workplace_name'],
                                                    ),
                                                  ),
                                                );
                                              },
                                              icon: Icon(Icons.list_alt),
                                              label: Text('Attendance'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
