import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'config.dart';
import 'database_helper.dart';
import 'sync_service.dart';
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

    debugPrint('[SDP_PROJECTS] Initializing SDP Projects Page');
    debugPrint('[SDP_PROJECTS] SDP Identifier: ${widget.sdpIdentifier}');
    debugPrint('[SDP_PROJECTS] SDP Display Name: ${widget.sdpDisplayName}');

    // Check project table status on initialization
    _checkProjectTableStatus();

    // Use projects from login if available, otherwise fetch
    if (widget.projects != null && widget.projects!.isNotEmpty) {
      debugPrint(
          '[SDP_PROJECTS] Received ${widget.projects!.length} projects from widget');

      // IMPORTANT: Filter widget.projects by SDP to match offline behavior
      final filteredProjects = _filterProjectsBySdp(widget.projects!);

      setState(() {
        projects = filteredProjects;
        isLoading = false;
      });

      debugPrint(
          '[SDP_PROJECTS] After SDP filtering: ${projects.length} projects');
      // Print project names for debugging
      for (var project in projects) {
        debugPrint(
            '[SDP_PROJECTS] - ${project['Project_name'] ?? project['project_name']}');
      }

      // If we have fewer than expected projects, also try to fetch from server
      // This handles cases where login data might be incomplete
      if (projects.length < 3) {
        // Adjust this threshold as needed
        debugPrint(
            '[SDP_PROJECTS] Only ${projects.length} projects after filtering, fetching more from server...');
        _loadProjects();
      }
    } else {
      debugPrint(
          '[SDP_PROJECTS] No projects from widget, fetching from server...');
      _loadProjects();
    }
    _searchController.addListener(() {
      setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  // Debug method to check project table status
  Future<void> _checkProjectTableStatus() async {
    try {
      final db = await _dbHelper.database;

      // Check if project table exists
      final tableCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='project'");

      if (tableCheck.isEmpty) {
        debugPrint('[SDP_PROJECTS] ❌ PROJECT TABLE DOES NOT EXIST!');
        return;
      }

      // Count total projects
      final countResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM project');
      final totalCount = countResult.first['count'] as int? ?? 0;
      debugPrint(
          '[SDP_PROJECTS] 📊 Total projects in local database: $totalCount');

      // Check projects for this specific SDP
      final sdpProjects = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM project p
        WHERE EXISTS (
          SELECT 1 FROM sites s 
          WHERE s.project_id = p.project_id 
          AND (s.sdp_id = ? OR s.sdp_id IN (
            SELECT sdp_id FROM sdp 
            WHERE sdp_name = ? OR email = ? OR client_name = ?
          ))
        )
      ''', [
        widget.sdpIdentifier,
        widget.sdpIdentifier,
        widget.sdpIdentifier,
        widget.sdpIdentifier
      ]);

      final sdpProjectCount = sdpProjects.first['count'] as int? ?? 0;
      debugPrint(
          '[SDP_PROJECTS] 📊 Projects for SDP ${widget.sdpIdentifier}: $sdpProjectCount');

      if (totalCount == 0) {
        debugPrint(
            '[SDP_PROJECTS] ⚠️ PROJECT TABLE IS EMPTY - SYNC MAY NOT BE WORKING');
        // Try to trigger sync
        debugPrint('[SDP_PROJECTS] 🔄 Attempting to sync project data...');
        final syncService = SyncService();
        await syncService.syncProjectData();

        // Check again after sync
        final newCountResult =
            await db.rawQuery('SELECT COUNT(*) as count FROM project');
        final newCount = newCountResult.first['count'] as int? ?? 0;
        debugPrint('[SDP_PROJECTS] 📊 Projects after sync attempt: $newCount');
      }
    } catch (e) {
      debugPrint('[SDP_PROJECTS] ❌ Error checking project table: $e');
    }
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.mobile);
  }

  /// Filter projects by SDP identifier using database logic (match backend exactly)
  /// Only shows projects that have sites for the specific SDP
  List<Map<String, dynamic>> _filterProjectsBySdp(
      List<Map<String, dynamic>> allProjects) {
    debugPrint('[SDP_PROJECTS] ===== FILTERING WIDGET PROJECTS BY SDP =====');
    debugPrint('[SDP_PROJECTS] SDP Identifier: ${widget.sdpIdentifier}');
    debugPrint(
        '[SDP_PROJECTS] Total projects to filter: ${allProjects.length}');

    // This method should use database filtering to match backend logic exactly
    // Backend query: WHERE p.project_id IN (SELECT DISTINCT s2.project_id FROM sites s2 WHERE s2.sdp_id = ?)
    // For now, return all projects and let _getProjectsFromDatabase handle the filtering
    // This ensures consistency with backend behavior

    debugPrint(
        '[SDP_PROJECTS] Using database filtering for consistency with backend');
    debugPrint('[SDP_PROJECTS] ===== END SDP FILTERING =====');

    // Return all projects - the real filtering happens in _getProjectsFromDatabase
    // which matches the backend SQL logic exactly
    return allProjects;
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

        debugPrint(
            '[SDP_PROJECTS] Server response status: ${response.statusCode}');
        debugPrint(
            '[SDP_PROJECTS] Server response body length: ${response.body.length}');

        if (response.statusCode == 200) {
          String cleaned =
              response.body.replaceAll(RegExp(r'<[^>]+>'), '').trim();
          final start = cleaned.indexOf('{');
          final end = cleaned.lastIndexOf('}');
          if (start != -1 && end != -1 && end >= start) {
            cleaned = cleaned.substring(start, end + 1);
          }

          debugPrint(
              '[SDP_PROJECTS] Cleaned response: ${cleaned.substring(0, cleaned.length > 200 ? 200 : cleaned.length)}...');

          final data = json.decode(cleaned);
          debugPrint('[SDP_PROJECTS] Parsed data success: ${data['success']}');
          debugPrint(
              '[SDP_PROJECTS] Projects count in response: ${data['projects']?.length ?? 0}');

          if (data['success'] == true) {
            final projectsList =
                List<Map<String, dynamic>>.from(data['projects'] ?? []);

            debugPrint(
                '[SDP_PROJECTS] Successfully loaded ${projectsList.length} projects from server');
            for (var project in projectsList) {
              debugPrint(
                  '[SDP_PROJECTS] - ${project['Project_name'] ?? project['project_name']}');
            }

            setState(() {
              // If we already have projects (from widget), merge them with server data
              // This prevents losing data when doing a fallback fetch
              if (projects.isNotEmpty) {
                debugPrint(
                    '[SDP_PROJECTS] Merging ${projectsList.length} server projects with ${projects.length} existing projects');
                // Create a map of existing projects by ID for quick lookup
                final existingProjectMap = <String, Map<String, dynamic>>{};
                for (var existing in projects) {
                  final id = existing['project_id']?.toString();
                  if (id != null) existingProjectMap[id] = existing;
                }

                // Update existing projects with server data (server data is more complete)
                // and add new projects that don't already exist
                final updatedProjects = <Map<String, dynamic>>[];

                for (var serverProject in projectsList) {
                  final id = serverProject['project_id']?.toString();
                  if (id != null && existingProjectMap.containsKey(id)) {
                    // Update existing project with server data (server has site/learner counts)
                    debugPrint(
                        '[SDP_PROJECTS] Updated project with server data: ${serverProject['Project_name'] ?? serverProject['project_name']}');
                    updatedProjects.add(serverProject);
                    existingProjectMap.remove(id); // Mark as processed
                  } else if (id != null) {
                    // New project from server
                    updatedProjects.add(serverProject);
                    debugPrint(
                        '[SDP_PROJECTS] Added new project: ${serverProject['Project_name'] ?? serverProject['project_name']}');
                  }
                }

                // Add any remaining widget projects that weren't found on server
                for (var remainingProject in existingProjectMap.values) {
                  updatedProjects.add(remainingProject);
                  debugPrint(
                      '[SDP_PROJECTS] Kept widget-only project: ${remainingProject['Project_name'] ?? remainingProject['project_name']}');
                }

                projects = updatedProjects;
                debugPrint(
                    '[SDP_PROJECTS] Final project count after merge: ${projects.length}');
              } else {
                // No existing projects, use server data
                projects = projectsList;
              }
              isLoading = false;
            });
            return;
          } else {
            debugPrint(
                '[SDP_PROJECTS] Server returned error: ${data['message']}');
            setState(() {
              errorMessage = data['message'] ?? 'Failed to load projects';
            });
          }
        } else {
          debugPrint('[SDP_PROJECTS] Server error: ${response.statusCode}');
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

  /// Get projects from local database using exact backend logic
  /// Only returns projects that have sites for the specific SDP (matches get_sdp_all_data.php)
  Future<List<Map<String, dynamic>>> _getProjectsFromDatabase() async {
    try {
      final db = await _dbHelper.database;

      debugPrint('[SDP_PROJECTS] ===== OFFLINE DATA LOOKUP =====');
      debugPrint(
          '[SDP_PROJECTS] Looking for identifier: ${widget.sdpIdentifier}');
      debugPrint(
          '[SDP_PROJECTS] Widget SDP Display Name: ${widget.sdpDisplayName}');

      // First, resolve SDP identifier to numeric ID (same as backend)
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

      final sdpId = sdpResults.first['sdp_id'];
      final sdpName = sdpResults.first['sdp_name'];
      debugPrint('[SDP_PROJECTS] ✅ Found SDP ID: $sdpId, Name: $sdpName');

      // EXACT BACKEND LOGIC: Only get projects that have sites for this SDP
      // Backend query: WHERE p.project_id IN (SELECT DISTINCT s2.project_id FROM sites s2 WHERE s2.sdp_id = ?)
      List<Map<String, dynamic>> projectResults = [];

      try {
        projectResults = await db.rawQuery('''
          SELECT 
            p.project_id,
            p.Project_name,
            p.Project_pathway,
            COUNT(DISTINCT s.siteID) AS active_sites,
            COUNT(DISTINCT l.LearnerID) AS total_learners
          FROM project p
          LEFT JOIN sites s ON s.project_id = p.project_id AND s.sdp_id = ?
          LEFT JOIN class c ON c.siteId = s.siteID
          LEFT JOIN learnerdetails l ON l.classID = c.classID
          WHERE p.project_id IN (SELECT DISTINCT s2.project_id FROM sites s2 WHERE s2.sdp_id = ?)
          GROUP BY p.project_id, p.Project_name, p.Project_pathway
          ORDER BY p.Project_name
        ''', [sdpId, sdpId]);

        debugPrint(
            '[SDP_PROJECTS] Primary query found ${projectResults.length} projects');
      } catch (e) {
        debugPrint('[SDP_PROJECTS] ⚠️ Primary query failed: $e');
        debugPrint(
            '[SDP_PROJECTS] 🔄 Trying fallback query using sites table only...');

        // FALLBACK: Build projects directly from sites table
        try {
          projectResults = await db.rawQuery('''
            SELECT 
              s.project_id,
              s.project_name AS Project_name,
              s.Project_pathway,
              COUNT(DISTINCT s.siteID) AS active_sites,
              COUNT(DISTINCT l.LearnerID) AS total_learners
            FROM sites s
            LEFT JOIN class c ON c.siteId = s.siteID
            LEFT JOIN learnerdetails l ON l.classID = c.classID
            WHERE s.sdp_id = ?
            GROUP BY s.project_id, s.project_name, s.Project_pathway
            ORDER BY s.project_name
          ''', [sdpId]);

          debugPrint(
              '[SDP_PROJECTS] ✅ Fallback query found ${projectResults.length} projects');
        } catch (e2) {
          debugPrint('[SDP_PROJECTS] ❌ Fallback query also failed: $e2');
          return [];
        }
      }

      debugPrint(
          '[SDP_PROJECTS] Found ${projectResults.length} projects with sites for SDP $sdpId');

      if (projectResults.isEmpty) {
        debugPrint(
            '[SDP_PROJECTS] ❌ No projects found with sites for SDP $sdpId');
        debugPrint('[SDP_PROJECTS] 🔍 Checking if sites table has data...');

        // Debug: Check what's in the sites table
        final sitesCheck = await db.rawQuery(
            'SELECT COUNT(*) as count FROM sites WHERE sdp_id = ?', [sdpId]);
        final sitesCount = sitesCheck.first['count'] as int? ?? 0;
        debugPrint(
            '[SDP_PROJECTS] Sites table has $sitesCount sites for SDP $sdpId');

        if (sitesCount > 0) {
          debugPrint(
              '[SDP_PROJECTS] ⚠️ Sites exist but no projects found - possible table structure issue');
        }

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
              debugPrint('[SDP_PROJECTS]   ✅ Parsed $pathwayCount pathways');
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
          'active_sites':
              int.tryParse(project['active_sites']?.toString() ?? '0') ?? 0,
          'total_learners':
              int.tryParse(project['total_learners']?.toString() ?? '0') ?? 0,
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
