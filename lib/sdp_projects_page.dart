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
  final String sdpId;
  final String sdpName;

  const SdpProjectsPage({
    Key? key,
    required this.sdpId,
    required this.sdpName,
  }) : super(key: key);

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
    _loadProjects();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
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
      final name = (p['project_name'] ?? p['Project_name'] ?? '').toString().toLowerCase();
      final id = (p['project_id'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || id.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _sortedProjects {
    final list = List<Map<String, dynamic>>.from(_filteredProjects);
    switch (_sortOption) {
      case ProjectSortOption.nameAsc:
        list.sort((a, b) => ((a['project_name'] ?? a['Project_name'] ?? '') as String)
            .toLowerCase()
            .compareTo(((b['project_name'] ?? b['Project_name'] ?? '') as String).toLowerCase()));
        break;
      case ProjectSortOption.nameDesc:
        list.sort((a, b) => ((b['project_name'] ?? b['Project_name'] ?? '') as String)
            .toLowerCase()
            .compareTo(((a['project_name'] ?? a['Project_name'] ?? '') as String).toLowerCase()));
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
        queryParams: {'sdpId': widget.sdpId},
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
      case ProjectSortOption.nameAsc: return 'Name A–Z';
      case ProjectSortOption.nameDesc: return 'Name Z–A';
      case ProjectSortOption.idAsc: return 'ID low–high';
      case ProjectSortOption.idDesc: return 'ID high–low';
      case ProjectSortOption.pathwaysDesc: return 'Pathways (most)';
      case ProjectSortOption.sitesDesc: return 'Sites (most)';
      case ProjectSortOption.learnersDesc: return 'Learners (most)';
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
              child: Text(
                widget.sdpName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or ID...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text('Sort: ', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ProjectSortOption.values.map((option) {
                          final selected = _sortOption == option;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(_sortLabel(option), style: TextStyle(fontSize: 12)),
                              selected: selected,
                              onSelected: (_) => setState(() => _sortOption = option),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                    ? _buildErrorState()
                    : projects.isEmpty
                        ? _buildEmptyState()
                        : _sortedProjects.isEmpty
                            ? _buildNoSearchResults()
                            : RefreshIndicator(
                                onRefresh: _loadProjects,
                                child: ListView.builder(
                                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  itemCount: _sortedProjects.length,
                                  itemBuilder: (context, index) {
                                    return _buildProjectCard(_sortedProjects[index]);
                                  },
                                ),
                              ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
            SizedBox(height: 16),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[700], fontSize: 15),
            ),
            SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadProjects,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No projects found',
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No projects match "$_searchQuery"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _searchController.clear(),
            icon: Icon(Icons.clear),
            label: Text('Clear search'),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final projectId = project['project_id']?.toString() ?? '';
    final projectName =
        project['project_name']?.toString() ??
        project['Project_name']?.toString() ??
        'Unknown Project';
    final pathwayCount = int.tryParse((project['pathway_count'] ?? 0).toString()) ?? 0;
    final activeSites = int.tryParse((project['active_sites'] ?? 0).toString()) ?? 0;
    final totalLearners = int.tryParse((project['total_learners'] ?? 0).toString()) ?? 0;

    final projectPathwayJson =
        project['Project_pathway_raw']?.toString() ??
        project['Project_pathway']?.toString() ??
        json.encode(project['pathways'] ?? []);

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SdpLearningPathwaysPage(
                sdpIdentifier: widget.sdpId,
                projectId: projectId,
                projectName: projectName,
                projectPathwayJson: projectPathwayJson,
              ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.folder_rounded, size: 28, color: Colors.blue[700]),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      projectName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (projectId.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          'ID: $projectId',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _statChip(Icons.route, '$pathwayCount pathways'),
                        if (activeSites > 0) _statChip(Icons.place, '$activeSites sites'),
                        if (totalLearners > 0) _statChip(Icons.people, '$totalLearners learners'),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }


  Widget _statChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }
}
