import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'config.dart';
import 'database_helper.dart';
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
  final DatabaseHelper _dbHelper = DatabaseHelper();
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
      debugPrint(
          '[SDP_PROJECTS] Loaded ${projects.length} projects from widget');
    } else {
      _loadProjects();
    }
    _searchController.addListener(() {
      setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.mobile);
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
      final isOnline = await _checkConnectivity();

      if (isOnline) {
        // Try to fetch from server
        final url = AppConfig.buildUrl(
          'get_sdp_all_data.php',
          queryParams: {'sdp_identifier': widget.sdpIdentifier},
        );

        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

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
            final projectsList =
                List<Map<String, dynamic>>.from(data['projects'] ?? []);

            setState(() {
              projects = projectsList;
              isLoading = false;
            });
            return;
          } else {
            setState(() {
              errorMessage = data['message'] ?? 'Failed to load projects';
            });
          }
        } else {
          setState(() {
            errorMessage = 'Server error: ${response.statusCode}';
          });
        }
      }

      // Fallback to local database (offline or server error)
      final localProjects = await _getProjectsFromDatabase();
      if (localProjects.isNotEmpty) {
        setState(() {
          projects = localProjects;
          isLoading = false;
          errorMessage = ''; // Clear error message - data found!
        });

        // Show info message if offline
        if (!isOnline && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline mode - showing local data'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          errorMessage = isOnline
              ? 'Failed to load projects from server'
              : 'No local data available. Please connect to internet and sync.';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[SDP_PROJECTS] Error loading projects: $e');
      // Try to load from local database on error
      final localProjects = await _getProjectsFromDatabase();
      if (localProjects.isNotEmpty) {
        setState(() {
          projects = localProjects;
          isLoading = false;
          errorMessage = ''; // Clear error message - data found!
        });

        // Show info message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Using local data (offline)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          errorMessage = 'Error loading projects: $e';
          isLoading = false;
        });
      }
    }
  }

  /// Get projects from local database (project table)
  Future<List<Map<String, dynamic>>> _getProjectsFromDatabase() async {
    try {
      final db = await _dbHelper.database;

      debugPrint('[SDP_PROJECTS] ===== OFFLINE DATA LOOKUP =====');
      debugPrint(
          '[SDP_PROJECTS] Looking for identifier: ${widget.sdpIdentifier}');

      // First, check what's in the sdp table
      final allSdps = await db.query('sdp');
      debugPrint('[SDP_PROJECTS] Total SDPs in database: ${allSdps.length}');
      if (allSdps.isNotEmpty) {
        debugPrint('[SDP_PROJECTS] Available SDPs:');
        for (var sdp in allSdps) {
          debugPrint(
              '  - ID: ${sdp['sdp_id']}, Name: ${sdp['sdp_name']}, Email: ${sdp['email']}');
        }
      }

      // Get sdp_name from sdp table using sdpIdentifier
      final sdpResults = await db.query(
        'sdp',
        columns: ['sdp_id', 'sdp_name', 'client_name'],
        where: 'sdp_id = ? OR sdp_name = ? OR email = ? OR client_name = ?',
        whereArgs: [
          widget.sdpIdentifier,
          widget.sdpIdentifier,
          widget.sdpIdentifier,
          widget.sdpIdentifier
        ],
        limit: 1,
      );

      if (sdpResults.isEmpty) {
        debugPrint(
            '[SDP_PROJECTS] ❌ No SDP found for identifier: ${widget.sdpIdentifier}');
        return [];
      }

      final sdpName = sdpResults.first['sdp_name'];
      final clientName = sdpResults.first['client_name'];

      debugPrint('[SDP_PROJECTS] ✅ Found SDP: $sdpName (client: $clientName)');

      // Check what's in the project table
      final allProjects = await db.query('project');
      debugPrint(
          '[SDP_PROJECTS] Total projects in database: ${allProjects.length}');
      if (allProjects.isNotEmpty) {
        debugPrint('[SDP_PROJECTS] Available projects:');
        final uniqueSdpNames = allProjects.map((p) => p['sdp_name']).toSet();
        for (var name in uniqueSdpNames) {
          final count = allProjects.where((p) => p['sdp_name'] == name).length;
          debugPrint('  - SDP: $name ($count projects)');
        }
      }

      // Query project table for this SDP (try both sdp_name and client_name)
      final projectResults = await db.query(
        'project',
        where: 'sdp_name = ? OR client_name = ?',
        whereArgs: [sdpName, clientName],
      );

      debugPrint(
          '[SDP_PROJECTS] Found ${projectResults.length} projects for this SDP');

      if (projectResults.isEmpty) {
        debugPrint(
            '[SDP_PROJECTS] ❌ No projects found for sdp_name: $sdpName or client_name: $clientName');
        return [];
      }

      // Transform database format to match API format
      final transformedProjects = projectResults.map((project) {
        debugPrint(
            '[SDP_PROJECTS] Processing project: ${project['Project_name']}');

        // Parse Project_pathway JSON if it exists
        List<Map<String, dynamic>> pathways = [];
        int pathwayCount = 0;

        try {
          final pathwayJson = project['Project_pathway'] as String?;
          if (pathwayJson != null &&
              pathwayJson.isNotEmpty &&
              pathwayJson != 'null') {
            debugPrint(
                '[SDP_PROJECTS]   Pathway JSON: ${pathwayJson.substring(0, pathwayJson.length > 100 ? 100 : pathwayJson.length)}...');
            final decoded = json.decode(pathwayJson);
            if (decoded is List) {
              pathways = List<Map<String, dynamic>>.from(decoded);
              pathwayCount = pathways.length;
              debugPrint('[SDP_PROJECTS]   ✅ Parsed ${pathwayCount} pathways');
            }
          } else {
            debugPrint('[SDP_PROJECTS]   ⚠️ No pathway data');
          }
        } catch (e) {
          debugPrint('[SDP_PROJECTS]   ❌ Error parsing pathway JSON: $e');
        }

        return {
          'project_id': project['project_id'],
          'project_name': project['Project_name'],
          'Project_name': project['Project_name'],
          'Project_pathway': project['Project_pathway'],
          'active_sites': 0, // Will be calculated if needed
          'total_learners': 0, // Will be calculated if needed
          'pathways': pathways,
          'pathway_count': pathwayCount,
          'qualifications': [],
          'qualification_count': 0,
        };
      }).toList();

      debugPrint(
          '[SDP_PROJECTS] ✅ Returning ${transformedProjects.length} transformed projects');
      debugPrint('[SDP_PROJECTS] ===== END OFFLINE DATA LOOKUP =====');

      return transformedProjects;
    } catch (e) {
      debugPrint('[SDP_PROJECTS] ❌ Error loading projects from database: $e');
      debugPrint('[SDP_PROJECTS] Stack trace: ${StackTrace.current}');
      return [];
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
        title: const Text('Projects'),
        backgroundColor: Colors.blue,
        actions: [
          if (!isLoading && errorMessage.isEmpty && projects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '${_sortedProjects.length} of ${projects.length}',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
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
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Sort: ',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
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
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 60, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(errorMessage,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadProjects,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : projects.isEmpty
                        ? const Center(
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
                              padding: const EdgeInsets.all(16),
                              itemCount: _sortedProjects.length,
                              itemBuilder: (context, index) {
                                final project = _sortedProjects[index];
                                return Card(
                                  elevation: 3,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Colors.blue,
                                      child: Icon(Icons.folder,
                                          color: Colors.white),
                                    ),
                                    title: Text(
                                      project['Project_name'] ??
                                          project['project_name'] ??
                                          'Unknown Project',
                                      style: const TextStyle(
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
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.route,
                                                size: 14, color: Colors.blue),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${project['pathway_count'] ?? 0} pathways',
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                            const SizedBox(width: 12),
                                            const Icon(Icons.location_on,
                                                size: 14, color: Colors.green),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${project['active_sites'] ?? 0} sites',
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.people,
                                                size: 14, color: Colors.orange),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${project['total_learners'] ?? 0} learners',
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16),
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
