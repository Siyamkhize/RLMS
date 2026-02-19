import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'sdp_learning_pathways_page.dart';

enum ProjectSortOption {
  nameAsc,
  nameDesc,
  idAsc,
  idDesc,
  pathwaysDesc,
  sitesDesc,
  learnersDesc,
}

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ProjectSortOption _sortOption = ProjectSortOption.nameAsc;

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
    _searchController.addListener(() {
      setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredProjects {
    if (_searchQuery.isEmpty) return List.from(projects);
    return projects.where((p) {
      final name = (p['project_name'] ?? p['Project_name'] ?? '')
          .toString()
          .toLowerCase();
      final id = (p['project_id'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || id.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _sortedProjects {
    final list = List<Map<String, dynamic>>.from(_filteredProjects);
    switch (_sortOption) {
      case ProjectSortOption.nameAsc:
        list.sort((a, b) =>
            ((a['project_name'] ?? a['Project_name'] ?? '') as String)
                .toLowerCase()
                .compareTo(
                    ((b['project_name'] ?? b['Project_name'] ?? '') as String)
                        .toLowerCase()));
        break;
      case ProjectSortOption.nameDesc:
        list.sort((a, b) =>
            ((b['project_name'] ?? b['Project_name'] ?? '') as String)
                .toLowerCase()
                .compareTo(
                    ((a['project_name'] ?? a['Project_name'] ?? '') as String)
                        .toLowerCase()));
        break;
      case ProjectSortOption.idAsc:
        list.sort((a, b) {
          final idA = int.tryParse((a['project_id'] ?? '0').toString()) ?? 0;
          final idB = int.tryParse((b['project_id'] ?? '0').toString()) ?? 0;
          return idA.compareTo(idB);
        });
        break;
      case ProjectSortOption.idDesc:
        list.sort((a, b) {
          final idA = int.tryParse((a['project_id'] ?? '0').toString()) ?? 0;
          final idB = int.tryParse((b['project_id'] ?? '0').toString()) ?? 0;
          return idB.compareTo(idA);
        });
        break;
      case ProjectSortOption.pathwaysDesc:
        list.sort((a, b) {
          final cA = int.tryParse((a['pathway_count'] ?? 0).toString()) ?? 0;
          final cB = int.tryParse((b['pathway_count'] ?? 0).toString()) ?? 0;
          return cB.compareTo(cA);
        });
        break;
      case ProjectSortOption.sitesDesc:
        list.sort((a, b) {
          final cA = int.tryParse((a['active_sites'] ?? 0).toString()) ?? 0;
          final cB = int.tryParse((b['active_sites'] ?? 0).toString()) ?? 0;
          return cB.compareTo(cA);
        });
        break;
      case ProjectSortOption.learnersDesc:
        list.sort((a, b) {
          final cA = int.tryParse((a['total_learners'] ?? 0).toString()) ?? 0;
          final cB = int.tryParse((b['total_learners'] ?? 0).toString()) ?? 0;
          return cB.compareTo(cA);
        });
        break;
    }
    return list;
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
        String cleaned =
            response.body.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        final start = cleaned.indexOf('{');
        final end = cleaned.lastIndexOf('}');
        if (start != -1 && end != -1 && end >= start) {
          cleaned = cleaned.substring(start, end + 1);
        }

        final data = json.decode(cleaned);
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

  String _sortLabel(ProjectSortOption option) {
    switch (option) {
      case ProjectSortOption.nameAsc:
        return 'Name A–Z';
      case ProjectSortOption.nameDesc:
        return 'Name Z–A';
      case ProjectSortOption.idAsc:
        return 'ID low–high';
      case ProjectSortOption.idDesc:
        return 'ID high–low';
      case ProjectSortOption.pathwaysDesc:
        return 'Pathways (most)';
      case ProjectSortOption.sitesDesc:
        return 'Sites (most)';
      case ProjectSortOption.learnersDesc:
        return 'Learners (most)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Projects'),
        backgroundColor: Colors.blue,
        actions: [
          if (!isLoading && errorMessage.isEmpty && projects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '${_sortedProjects.length} of ${projects.length}',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isLoading && errorMessage.isEmpty && projects.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or ID...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Sort: ', style: TextStyle(fontWeight: FontWeight.w500)),
                  SizedBox(width: 8),
                  ...ProjectSortOption.values.map((opt) {
                    final isSelected = _sortOption == opt;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_sortLabel(opt)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _sortOption = opt);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            SizedBox(height: 8),
          ],
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 60, color: Colors.red),
                            SizedBox(height: 16),
                            Text(errorMessage,
                                style: TextStyle(color: Colors.red)),
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
                                Icon(Icons.folder_open,
                                    size: 60, color: Colors.grey),
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
                              itemCount: _sortedProjects.length,
                              itemBuilder: (context, index) {
                                final project = _sortedProjects[index];
                                return Card(
                                  elevation: 3,
                                  margin: EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue,
                                      child: Icon(Icons.folder,
                                          color: Colors.white),
                                    ),
                                    title: Text(
                                      project['Project_name'] ??
                                          project['project_name'] ??
                                          'Unknown Project',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'ID: ${project['project_id'] ?? 'N/A'}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600]),
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.route,
                                                size: 14, color: Colors.blue),
                                            SizedBox(width: 4),
                                            Text(
                                              '${project['pathway_count'] ?? 0} pathways',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            SizedBox(width: 12),
                                            Icon(Icons.location_on,
                                                size: 14, color: Colors.green),
                                            SizedBox(width: 4),
                                            Text(
                                              '${project['active_sites'] ?? 0} sites',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.people,
                                                size: 14, color: Colors.orange),
                                            SizedBox(width: 4),
                                            Text(
                                              '${project['total_learners'] ?? 0} learners',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing:
                                        Icon(Icons.arrow_forward_ios, size: 16),
                                    onTap: () {
                                      // Parse pathways from Project_pathway JSON string
                                      List<Map<String, dynamic>>
                                          parsedPathways = [];
                                      try {
                                        final pathwayJson = project[
                                                'Project_pathway'] ??
                                            project['Project_pathway_raw'] ??
                                            '[]';
                                        if (pathwayJson is String &&
                                            pathwayJson.isNotEmpty &&
                                            pathwayJson != '[]') {
                                          final decoded =
                                              json.decode(pathwayJson);
                                          if (decoded is List) {
                                            parsedPathways =
                                                List<Map<String, dynamic>>.from(
                                                    decoded);
                                          }
                                        }
                                      } catch (e) {
                                        debugPrint(
                                            '[SDP_PROJECTS] Error parsing pathways: $e');
                                      }

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              SdpLearningPathwaysPage(
                                            sdpIdentifier: widget.sdpIdentifier,
                                            projectId: project['project_id']
                                                    ?.toString() ??
                                                '',
                                            projectName:
                                                project['Project_name'] ??
                                                    project['project_name'] ??
                                                    'Unknown',
                                            pathways: parsedPathways,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
