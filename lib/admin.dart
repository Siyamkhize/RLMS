import 'dart:io'; // For checking connectivity
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'class_details_page.dart'; // Import the class details page
import 'database_helper.dart'; // Import your DatabaseHelper class
import 'sdp_learners_page.dart';
import 'learner_list_page.dart'; // Import LearnerListPage for class-based learner management
import 'config.dart'; // Import AppConfig

class AdminPage extends StatefulWidget {
  final String sdp;
  final List<dynamic> data;
  final String? projectId;
  final String? pathwayId;

  const AdminPage({
    super.key,
    required this.sdp,
    required this.data,
    this.projectId,
    this.pathwayId,
  });

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<Map<String, dynamic>> _siteData = [];
  bool _isLoading = true;
  bool _isOnline = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData(); // Load data based on connectivity status
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    bool isConnected = await _checkConnectivity();
    setState(() {
      _isOnline = isConnected;
      _isLoading = true;
    });

    if (_isOnline) {
      // Fetch data online (e.g., from API)
      _fetchOnlineData();
    } else {
      // Fetch data offline (from local database)
      _loadSitesFromLocalDatabase();
    }
  }

  String? _resolveSdpIdentifier() {
    final List<String> candidates = [];

    void addCandidate(dynamic value) {
      if (value == null) return;
      final candidate = value.toString().trim();
      if (candidate.isNotEmpty && !candidates.contains(candidate)) {
        candidates.add(candidate);
      }
    }

    addCandidate(widget.sdp);

    for (final site in _siteData) {
      addCandidate(site['sdp_id']);
      addCandidate(site['sdpId']);
      addCandidate(site['sdp_name']);
      addCandidate(site['sdpName']);
      for (final entry in site.entries) {
        final key = entry.key.toString().toLowerCase();
        if (key.contains('sdp')) {
          addCandidate(entry.value);
        }
      }
    }

    for (final raw in widget.data) {
      if (raw is Map) {
        addCandidate(raw['sdp_id']);
        addCandidate(raw['sdpId']);
        addCandidate(raw['sdp_name']);
        addCandidate(raw['sdpName']);
        for (final entry in raw.entries) {
          final key = entry.key.toString().toLowerCase();
          if (key.contains('sdp')) {
            addCandidate(entry.value);
          }
        }
      }
    }

    return candidates.isNotEmpty ? candidates.first : null;
  }

  Future<void> _fetchOnlineData() async {
    try {
      final sdpId = widget.sdp.trim().isEmpty ? _resolveSdpIdentifier() : widget.sdp.trim();
      if (sdpId == null || sdpId.isEmpty) {
        setState(() {
          _siteData = List<Map<String, dynamic>>.from(widget.data);
          _isLoading = false;
        });
        return;
      }

      final queryParams = <String, String>{'sdpId': sdpId};
      if (widget.projectId != null && widget.projectId!.isNotEmpty) {
        queryParams['project_id'] = widget.projectId!;
      }
      if (widget.pathwayId != null && widget.pathwayId!.isNotEmpty) {
        queryParams['pathway_id'] = widget.pathwayId!;
      }

      final url = AppConfig.buildUrl('get_sdp_sites.php', queryParams: queryParams);
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out'),
      );

      if (response.statusCode == 200) {
        String cleaned = response.body.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        final start = cleaned.indexOf('{');
        final end = cleaned.lastIndexOf('}');
        if (start != -1 && end != -1 && end >= start) {
          cleaned = cleaned.substring(start, end + 1);
        }
        final jsonData = json.decode(cleaned);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          setState(() {
            _siteData = List<Map<String, dynamic>>.from(jsonData['data']);
            _isLoading = false;
          });
          return;
        }
      }

      // Fallback to widget.data if API fails or returns no data
      setState(() {
        _siteData = List<Map<String, dynamic>>.from(widget.data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _siteData = List<Map<String, dynamic>>.from(widget.data);
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sites: $e')),
        );
      }
    }
  }

  Future<void> _loadSitesFromLocalDatabase() async {
    try {
      final dbHelper = DatabaseHelper();

      // Fetch sites where sdp_id matches the passed sdp
      final int sdpId =
          int.tryParse(widget.sdp) ?? 0; // Default to 0 if parsing fails

      // Now pass the sdpId to your database method
      List<Map<String, dynamic>> offlineSites;

      if (widget.projectId != null) {
        // Filter by project
        final db = await dbHelper.database;
        offlineSites = await db.query(
          'sites',
          where: 'sdp_id = ? AND project_id = ?',
          whereArgs: [sdpId, int.tryParse(widget.projectId!) ?? 0],
        );
      } else {
        offlineSites = await dbHelper.getSitesBySdpId(sdpId);
      }

      setState(() {
        _siteData = offlineSites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading offline sites: $e')),
      );
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _searchLearnerById() async {
    final idNumber = _searchController.text.trim();

    if (idNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an ID number'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      Map<String, dynamic>? learner;

      if (_isOnline) {
        // Search online via API
        learner = await _searchLearnerOnline(idNumber);
      } else {
        // Search offline from local database
        learner = await _searchLearnerOffline(idNumber);
      }

      if (learner != null &&
          learner['learner_id'] != null &&
          learner['class_id'] != null) {
        // Navigate to LearnerListPage (class page) where we can scan documents and update profiles
        final classId = learner['class_id'].toString();

        if (classId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LearnerListPage(
                classID: classId,
              ),
            ),
          );
          // Clear search field after successful navigation
          _searchController.clear();
        } else {
          throw Exception('Learner has no class assigned');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No learner found with ID number: $idNumber'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching for learner: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _searchLearnerOnline(String idNumber) async {
    try {
      // Get SDP identifier
      String sdpIdentifier = widget.sdp.trim();
      if (sdpIdentifier.isEmpty) {
        final resolved = _resolveSdpIdentifier();
        if (resolved != null && resolved.isNotEmpty) {
          sdpIdentifier = resolved;
        }
      }

      if (sdpIdentifier.isEmpty) {
        throw Exception('SDP identifier not available');
      }

      // Build URL - use unified "sdpId" key for the SDP identifier
      final url = AppConfig.buildUrl(
        'search_learner_by_id_sdp.php',
        queryParams: {
          'id_number': idNumber,
          'sdpId': sdpIdentifier,
        },
      );

      print('[ADMIN] Searching learner online: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true && jsonData['learner'] != null) {
          return jsonData['learner'] as Map<String, dynamic>;
        }
      }

      return null;
    } catch (e) {
      print('[ADMIN] Error searching online: $e');
      // Fallback to offline search
      return await _searchLearnerOffline(idNumber);
    }
  }

  Future<Map<String, dynamic>?> _searchLearnerOffline(String idNumber) async {
    try {
      final dbHelper = DatabaseHelper();

      // Get SDP identifier
      String sdpIdentifier = widget.sdp.trim();
      if (sdpIdentifier.isEmpty) {
        final resolved = _resolveSdpIdentifier();
        if (resolved != null && resolved.isNotEmpty) {
          sdpIdentifier = resolved;
        }
      }

      if (sdpIdentifier.isEmpty) {
        throw Exception('SDP identifier not available');
      }

      // Get all learners for this SDP
      final learners = await dbHelper.getLearnersBySdp(sdpIdentifier);

      // Find learner by ID number
      for (final learner in learners) {
        final learnerIdNumber = learner['IDNumber']?.toString().trim();
        if (learnerIdNumber != null && learnerIdNumber == idNumber) {
          return {
            'learner_id': learner['LearnerID']?.toString() ?? '',
            'name': learner['Name']?.toString() ?? '',
            'surname': learner['Surname']?.toString() ?? '',
            'id_number': learnerIdNumber,
            'class_id': learner['classID']?.toString() ?? '',
            'class_name': learner['className']?.toString() ?? '',
          };
        }
      }

      return null;
    } catch (e) {
      print('[ADMIN] Error searching offline: $e');
      return null;
    }
  }

  void _openSdpLearners() {
    String identifier = widget.sdp.trim();

    // If widget.sdp is empty, try to resolve from site data
    if (identifier.isEmpty) {
      final resolved = _resolveSdpIdentifier();
      if (resolved != null && resolved.isNotEmpty) {
        identifier = resolved;
        print('[ADMIN] Resolved SDP identifier from site data: $identifier');
      }
    }

    if (identifier.isEmpty) {
      print(
          '[ADMIN] ERROR: No SDP identifier found. widget.sdp="${widget.sdp}", _siteData count=${_siteData.length}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'SDP identifier not available. Please log out and log in again.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    print('[ADMIN] Opening SDP learners with identifier: $identifier');

    final dynamic inferredName = _siteData.isNotEmpty
        ? (_siteData.first['sdp_name'] ??
            _siteData.first['sdpName'] ??
            _siteData.first['client_name'])
        : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SdpLearnersPage(
          sdpIdentifier: identifier,
          sdpDisplayName: inferredName?.toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: SingleChildScrollView(
        scrollDirection:
            Axis.vertical, // Vertical scrolling for the entire page
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_siteData.isNotEmpty && _siteData.first['project_name'] != null)
                Text(
                  'Project: ${_siteData.first['project_name']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue),
                ),
              if (_siteData.isNotEmpty && _siteData.first['sdp_name'] != null)
                Text(
                  'SDP: ${_siteData.first['sdp_name']}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey),
                ),
              Text(
                'Sites & Classes (${_siteData.length} sites)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Search bar for learner by ID number
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search learner by ID number...',
                            prefixIcon: Icon(Icons.search),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: (_) => _searchLearnerById(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: _searchLearnerById,
                              tooltip: 'Search learner',
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _openSdpLearners,
                  icon: const Icon(Icons.people_alt),
                  label: const Text('View All Learners'),
                ),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      scrollDirection:
                          Axis.horizontal, // Horizontal scrolling for the table
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Site Name')),
                          DataColumn(label: Text('Project')),
                          DataColumn(label: Text('SDP')),
                          DataColumn(label: Text('Pathway')),
                          DataColumn(label: Text('Qualification')),
                          DataColumn(label: Text('Beneficiaries')),
                          DataColumn(label: Text('Classes')),
                          DataColumn(label: Text('Coordinates')),
                          DataColumn(label: Text('Province')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: _siteData.map<DataRow>((item) {
                          // Get pathway and qualification info
                          final pathways = item['pathways'] is List 
                              ? (item['pathways'] as List).join(', ')
                              : (item['learningPathway'] ?? item['project_pathway'] ?? 'N/A').toString();
                          final qualifications = item['qualifications'] is List
                              ? (item['qualifications'] as List).join(', ')
                              : 'N/A';
                          
                          return DataRow(cells: [
                            DataCell(Text(item['siteName'] ?? 'N/A')),
                            DataCell(Text(item['project_name'] ?? item['project_id'] ?? 'N/A')),
                            DataCell(Text(item['sdp_name'] ?? item['sdp_client_name'] ?? item['sdp_id'] ?? 'N/A')),
                            DataCell(
                              Tooltip(
                                message: pathways,
                                child: Text(
                                  pathways.length > 30 ? '${pathways.substring(0, 30)}...' : pathways,
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            DataCell(
                              Tooltip(
                                message: qualifications,
                                child: Text(
                                  qualifications.length > 30 ? '${qualifications.substring(0, 30)}...' : qualifications,
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            DataCell(Text(item['beneficiaries'] ?? 'N/A')),
                            DataCell(Text(item['classes'] ?? 'N/A')),
                            DataCell(Text(item['coordinates'] ?? 'N/A')),
                            DataCell(Text(item['province'] ?? 'N/A')),
                            DataCell(
                              ElevatedButton(
                                onPressed: () {
                                  // Pass the siteID to the next page
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ClassDetailsPage(
                                        siteID: item['siteID'].toString(),
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                                child: const Text('Open Class'),
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SettingsPage(),
            ),
          );
        },
        child: const Icon(Icons.settings),
      ),
    );
  }
}

// Example placeholder for SettingsPage
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
              // Navigate to profile page
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              // Navigate to settings page
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            onTap: () {
              // Navigate to notifications page
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context); // Log out and go back to login page
            },
          ),
        ],
      ),
    );
  }
}
