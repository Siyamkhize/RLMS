import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'database_helper.dart';
import 'sdp_learning_pathways_page.dart';
import 'config.dart';

class SdpProjectsPage extends StatefulWidget {
  final String sdpIdentifier;
  final String? sdpDisplayName;

  const SdpProjectsPage({
    super.key,
    required this.sdpIdentifier,
    this.sdpDisplayName,
  });

  @override
  State<SdpProjectsPage> createState() => _SdpProjectsPageState();
}

class _SdpProjectsPageState extends State<SdpProjectsPage> {
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);

    final isConnected = await _checkConnectivity();
    setState(() => _isOnline = isConnected);

    if (_isOnline) {
      await _fetchProjectsOnline();
    } else {
      await _fetchProjectsOffline();
    }
  }

  Future<void> _fetchProjectsOnline() async {
    try {
      final url = AppConfig.buildUrl(
        'get_sdp_projects.php',
        queryParams: {'sdp_identifier': widget.sdpIdentifier},
      );

      debugPrint('[SDP_PROJECTS] Fetching online: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true && jsonData['projects'] != null) {
          final projects =
              List<Map<String, dynamic>>.from(jsonData['projects']);

          if (mounted) {
            setState(() {
              _projects = projects;
              _isLoading = false;
            });
          }
          return;
        }
      }

      // Fallback to offline if online fails
      debugPrint('[SDP_PROJECTS] Online fetch failed, falling back to offline');
      await _fetchProjectsOffline();
    } catch (e) {
      debugPrint('[SDP_PROJECTS] Error fetching online: $e');
      await _fetchProjectsOffline();
    }
  }

  Future<void> _fetchProjectsOffline() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Query projects for this SDP
      final projects = await db.rawQuery('''
        SELECT DISTINCT
          p.project_id,
          p.Project_name,
          p.sdp_name,
          p.client_name,
          p.Financial_year,
          p.Start_date,
          p.End_date,
          p.Province,
          p.n_beneficiaries,
          p.Project_pathway
        FROM project p
        WHERE p.sdp_name = ? OR p.project_id IN (
          SELECT DISTINCT s.project_id 
          FROM sites s 
          WHERE s.sdp_id = ?
        )
        ORDER BY p.Project_name
      ''', [widget.sdpIdentifier, int.tryParse(widget.sdpIdentifier) ?? 0]);

      if (mounted) {
        setState(() {
          _projects = projects;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[SDP_PROJECTS] Error loading offline projects: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading projects: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sdpDisplayName ?? 'Projects'),
        actions: [
          IconButton(
            icon: Icon(_isOnline ? Icons.cloud_done : Icons.cloud_off),
            onPressed: null,
            tooltip: _isOnline ? 'Online' : 'Offline',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? const Center(
                  child: Text(
                    'No projects found',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          project['Project_name'] ?? 'Unknown Project',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text('Client: ${project['client_name'] ?? 'N/A'}'),
                            Text('Province: ${project['Province'] ?? 'N/A'}'),
                            Text(
                                'Beneficiaries: ${project['n_beneficiaries'] ?? 'N/A'}'),
                            Text('Year: ${project['Financial_year'] ?? 'N/A'}'),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SdpLearningPathwaysPage(
                                sdpIdentifier: widget.sdpIdentifier,
                                projectId: project['project_id'].toString(),
                                projectName:
                                    project['Project_name'] ?? 'Project',
                                projectPathwayJson:
                                    project['Project_pathway'] ?? '[]',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
