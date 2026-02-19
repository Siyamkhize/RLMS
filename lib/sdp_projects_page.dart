import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'sdp_learning_pathways_page.dart';

class SdpProjectsPage extends StatefulWidget {
  final String sdpIdentifier;
  final String? sdpDisplayName;
  final List<Map<String, dynamic>>? projects;

  const SdpProjectsPage({
    super.key,
    required this.sdpIdentifier,
    this.sdpDisplayName,
    this.projects,
  });

  @override
  _SdpProjectsPageState createState() => _SdpProjectsPageState();
}

class _SdpProjectsPageState extends State<SdpProjectsPage> {
  List<Map<String, dynamic>> projects = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Use projects from login if available, otherwise fetch
    if (widget.projects != null && widget.projects!.isNotEmpty) {
      setState(() {
        projects = widget.projects!;
        isLoading = false;
      });
    } else {
      _loadProjects();
    }
  }

  Future<void> _loadProjects() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final url = AppConfig.buildUrl(
        'get_sdp_projects.php',
        queryParams: {'sdp_identifier': widget.sdpIdentifier},
      );

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            projects = List<Map<String, dynamic>>.from(data['projects'] ?? []);
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = data['message'] ?? 'Failed to load projects';
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
        errorMessage = 'Error loading projects: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Projects - ${widget.sdpDisplayName ?? widget.sdpIdentifier}'),
        backgroundColor: Colors.blue,
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
                        onPressed: _loadProjects,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : projects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No projects found',
                              style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProjects,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final project = projects[index];
                          return Card(
                            elevation: 3,
                            margin: EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Icon(Icons.folder, color: Colors.white),
                              ),
                              title: Text(
                                project['Project_name'] ?? 'Unknown Project',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Province: ${project['Province'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'Pathways: ${project['pathway_count'] ?? 0}',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.blue),
                                  ),
                                ],
                              ),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        SdpLearningPathwaysPage(
                                      sdpIdentifier: widget.sdpIdentifier,
                                      projectId:
                                          project['project_id']?.toString() ??
                                              '',
                                      projectName:
                                          project['Project_name'] ?? 'Unknown',
                                      pathways: List<Map<String, dynamic>>.from(
                                          project['pathways'] ?? []),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
