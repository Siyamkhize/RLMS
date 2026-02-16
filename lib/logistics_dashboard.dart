import 'package:flutter/material.dart';
import 'logistics_sites_page.dart';
import 'logistics_materials_page.dart';
import 'logistics_poe_sites_page.dart';
import 'facilitator_issue_sites_page.dart';

class LogisticsDashboard extends StatefulWidget {
  final String logisticsId;
  final String logisticsName;

  const LogisticsDashboard({
    super.key,
    required this.logisticsId,
    required this.logisticsName,
  });

  @override
  State<LogisticsDashboard> createState() => _LogisticsDashboardState();
}

class _LogisticsDashboardState extends State<LogisticsDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Logistics Dashboard - ${widget.logisticsName}'),
        backgroundColor: Colors.blueGrey[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[100]!, Colors.lightBlue[50]!],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card
                Card(
                  elevation: 8,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.grey[50]!],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2,
                              size: 40,
                              color: Colors.blueGrey[600],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome to Logistics',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey[700],
                                    ),
                                  ),
                                  Text(
                                    'Manage materials and Report',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
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
                ),
                const SizedBox(height: 24),
                
                // Main Menu Grid
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85, // Slightly taller cards to prevent overflow
                    children: [
                      // POE Collection Workflow
                      _buildMenuCard(
                        icon: Icons.location_city,
                        title: 'Sites & Classes',
                        subtitle: 'Submit the POE',
                        color: Colors.blueGrey,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LogisticsPOESitesPage(
                                logisticsId: widget.logisticsId,
                                logisticsName: widget.logisticsName,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // Materials Management
                      _buildMenuCard(
                        icon: Icons.inventory,
                        title: 'Materials',
                        subtitle: 'Manage learning materials, PPE, consumables',
                        color: Colors.lightBlue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LogisticsMaterialsPage(
                                logisticsId: widget.logisticsId,
                                logisticsName: widget.logisticsName,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // Issue Materials to Facilitators
                      _buildMenuCard(
                        icon: Icons.person,
                        title: 'Issue to Facilitators',
                        subtitle: 'Issue materials to facilitators',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FacilitatorIssueSitesPage(
                                logisticsId: widget.logisticsId,
                                logisticsName: widget.logisticsName,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // Issue Materials to Learners
                      _buildMenuCard(
                        icon: Icons.group,
                        title: 'Issue to Learners',
                        subtitle: 'Issue materials to learners',
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LogisticsSitesPage(
                                logisticsId: widget.logisticsId,
                                logisticsName: widget.logisticsName,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // Reports
                      _buildMenuCard(
                        icon: Icons.analytics,
                        title: 'Reports',
                        subtitle: 'View issuance reports and history',
                        color: Colors.purple,
                        onTap: () {
                          _showComingSoon();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: const Text('This feature is under development.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}