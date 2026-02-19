import 'dart:io'; // For checking connectivity
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'class_details_page.dart'; // Import the class details page
import 'database_helper.dart'; // Import your DatabaseHelper class
import 'sdp_learners_page.dart';
import 'learner_list_page.dart'; // Import LearnerListPage for class navigation
import 'config.dart'; // Import AppConfig
import 'dart:async'; // For Timer

class AdminPage extends StatefulWidget {
  final String sdp;
  final List<dynamic> data;
  final String? projectId;
  final String? pathwayId;
  final String? qualificationId;

  const AdminPage({
    super.key,
    required this.sdp,
    required this.data,
    this.projectId,
    this.pathwayId,
    this.qualificationId,
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
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _showSuggestions = false;
  Timer? _debounceTimer;

  Future<int> _resolveOfflineSdpId(DatabaseHelper dbHelper) async {
    final raw = widget.sdp.trim();
    final direct = int.tryParse(raw);
    if (direct != null && direct > 0) return direct;

    // Try resolve via local sdp table (sdp_name / email / reg number)
    final db = await dbHelper.database;
    Future<int> lookup(String candidate) async {
      final rows = await db.query(
        'sdp',
        columns: ['sdp_id'],
        where: 'sdp_name = ? OR email = ? OR Reg_number = ?',
        whereArgs: [candidate, candidate, candidate],
        limit: 1,
      );
      if (rows.isEmpty) return 0;
      return int.tryParse(rows.first['sdp_id']?.toString() ?? '') ?? 0;
    }

    final byRaw = await lookup(raw);
    if (byRaw > 0) return byRaw;

    final resolved = _resolveSdpIdentifier();
    if (resolved != null && resolved.isNotEmpty && resolved != raw) {
      final byResolved = await lookup(resolved);
      if (byResolved > 0) return byResolved;
    }

    return 0;
  }

  @override
  void initState() {
    super.initState();
    _loadData(); // Load data based on connectivity status
    _searchController.addListener(_onSearchTextChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Smart search functionality
  void _onSearchTextChanged() {
    final query = _searchController.text.trim();

    // Cancel previous timer
    _debounceTimer?.cancel();

    if (query.length < 2) {
      setState(() {
        _searchSuggestions.clear();
        _showSuggestions = false;
      });
      return;
    }

    // Debounce search requests - smart search with 300ms delay
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_isOnline) {
        _fetchSearchSuggestions(query);
      }
    });
  }

  void _onSearchFocusChanged() {
    if (!_searchFocusNode.hasFocus) {
      // Delay hiding suggestions to allow for selection
      Timer(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _showSuggestions = false;
          });
        }
      });
    }
  }

  Future<void> _fetchSearchSuggestions(String query) async {
    if (!mounted || query.length < 2) return;

    setState(() {
      _isSearching = true;
    });

    try {
      // Use global search autocomplete endpoint (no SDP filter)
      final url = AppConfig.buildUrl('search_learner_autocomplete_global.php',
          queryParams: {
            'q': query,
            'limit': '8',
          });

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 5),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _searchSuggestions =
                List<Map<String, dynamic>>.from(data['suggestions'] ?? []);
            _showSuggestions =
                _searchSuggestions.isNotEmpty && _searchFocusNode.hasFocus;
          });
        }
      }
    } catch (e) {
      print('[ADMIN] Smart search autocomplete error: $e');
      if (mounted) {
        setState(() {
          _searchSuggestions.clear();
          _showSuggestions = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _selectSearchSuggestion(Map<String, dynamic> suggestion) {
    // Extract learner and class IDs from suggestion
    final learnerId = suggestion['learner_id']?.toString() ?? '';
    final classId = suggestion['class_id']?.toString() ?? '';
    final idNumber = suggestion['id_number']?.toString() ?? '';

    // Use the ID number in the search field
    _searchController.text = idNumber;

    setState(() {
      _showSuggestions = false;
    });

    _searchFocusNode.unfocus();

    // Navigate to class page
    // User can then scan documents and click View to see learner profile
    if (learnerId.isNotEmpty && classId.isNotEmpty) {
      // Navigate directly to the class page
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
    }
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
      final sdpId = widget.sdp.trim().isEmpty
          ? _resolveSdpIdentifier()
          : widget.sdp.trim();
      debugPrint('[ADMIN] Fetching sites for sdpId: $sdpId');

      if (sdpId == null || sdpId.isEmpty) {
        debugPrint(
            '[ADMIN] No sdpId found, using widget.data (${widget.data.length} items)');
        setState(() {
          _siteData = List<Map<String, dynamic>>.from(widget.data);
          _isLoading = false;
        });
        return;
      }

      final queryParams = <String, String>{'sdpId': sdpId};
      if (widget.projectId != null && widget.projectId!.isNotEmpty) {
        queryParams['project_id'] = widget.projectId!;
        debugPrint('[ADMIN] Filtering by project_id: ${widget.projectId}');
      }
      if (widget.pathwayId != null && widget.pathwayId!.isNotEmpty) {
        queryParams['pathway_id'] = widget.pathwayId!;
        debugPrint('[ADMIN] Filtering by pathway_id: ${widget.pathwayId}');
      }
      if (widget.qualificationId != null &&
          widget.qualificationId!.isNotEmpty) {
        queryParams['qualification_id'] = widget.qualificationId!;
        debugPrint(
            '[ADMIN] Filtering by qualification_id: ${widget.qualificationId}');
      }

      final uri = Uri.parse(AppConfig.getSdpSitesUrl).replace(
        queryParameters: queryParams,
      );
      debugPrint('[ADMIN] Requesting URL: $uri');

      final response = await http.get(uri).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timed out'),
          );

      debugPrint('[ADMIN] Response status: ${response.statusCode}');
      debugPrint(
          '[ADMIN] Response body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');

      if (response.statusCode == 200) {
        try {
          // Clean the response body - remove any HTML tags and whitespace
          String cleaned = response.body.trim();

          // Remove any HTML/PHP output before JSON
          cleaned = cleaned.replaceAll(RegExp(r'<[^>]+>'), '').trim();

          // Find JSON boundaries
          final start = cleaned.indexOf('{');
          final end = cleaned.lastIndexOf('}');

          if (start == -1 || end == -1 || end < start) {
            throw Exception('No valid JSON found in response');
          }

          cleaned = cleaned.substring(start, end + 1);

          debugPrint(
              '[ADMIN] Cleaned JSON (first 200 chars): ${cleaned.substring(0, cleaned.length > 200 ? 200 : cleaned.length)}');

          final jsonData = json.decode(cleaned);
          debugPrint(
              '[ADMIN] Parsed JSON - success: ${jsonData['success']}, data count: ${jsonData['data']?.length ?? 0}');

          if (jsonData['success'] == true && jsonData['data'] != null) {
            final sites = List<Map<String, dynamic>>.from(jsonData['data']);
            debugPrint(
                '[ADMIN] Successfully loaded ${sites.length} sites from API');

            // Cache for offline use
            try {
              await DatabaseHelper().saveSdpSitesForOffline(sdpId, sites);
              debugPrint('[ADMIN] Sites cached for offline use');
            } catch (e) {
              debugPrint('[ADMIN] Failed to cache sites for offline: $e');
            }

            if (mounted) {
              setState(() {
                _siteData = sites;
                _isLoading = false;
              });
            }
            return;
          } else {
            debugPrint(
                '[ADMIN] API returned success=false or no data: ${jsonData['message'] ?? 'Unknown error'}');
          }
        } catch (e) {
          debugPrint('[ADMIN] Error parsing JSON response: $e');
          debugPrint('[ADMIN] Raw response: ${response.body}');
        }
      }

      // Fallback to widget.data if API fails or returns no data
      debugPrint(
          '[ADMIN] Falling back to widget.data (${widget.data.length} items)');
      setState(() {
        _siteData = List<Map<String, dynamic>>.from(widget.data);
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('[ADMIN] Error fetching sites: $e');
      debugPrint('[ADMIN] Stack trace: $stackTrace');
      setState(() {
        _siteData = List<Map<String, dynamic>>.from(widget.data);
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sites: $e'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadSitesFromLocalDatabase() async {
    try {
      final dbHelper = DatabaseHelper();

      // Fetch sites where sdp_id matches the passed sdp (even if widget.sdp is name/email)
      final int sdpId = await _resolveOfflineSdpId(dbHelper);
      if (sdpId == 0) {
        setState(() {
          _siteData = [];
          _isLoading = false;
        });
        return;
      }

      // Now pass the sdpId to your database method
      List<Map<String, dynamic>> offlineSites;

      final db = await dbHelper.database;
      final where = <String>['sdp_id = ?'];
      final args = <Object>[sdpId];

      if (widget.projectId != null && widget.projectId!.isNotEmpty) {
        where.add('project_id = ?');
        args.add(int.tryParse(widget.projectId!) ?? 0);
      }

      // NOTE: widget.pathwayId is passed as pathway NAME (see sdp_learning_pathways_page.dart)
      if (widget.pathwayId != null && widget.pathwayId!.isNotEmpty) {
        where.add('LOWER(TRIM(Project_pathway)) = LOWER(TRIM(?))');
        args.add(widget.pathwayId!);
      }
      if (widget.qualificationId != null &&
          widget.qualificationId!.isNotEmpty) {
        where.add('TRIM(qualification_id) = TRIM(?)');
        args.add(widget.qualificationId!);
      }

      offlineSites = await db.query(
        'sites',
        where: where.join(' AND '),
        whereArgs: args,
      );

      // Normalize keys for table (API uses lowercase; DB may use Province, Project_pathway)
      final normalized = offlineSites.map((s) {
        final m = Map<String, dynamic>.from(s);
        if (m['province'] == null && m['Province'] != null) {
          m['province'] = m['Province'];
        }
        if (m['project_pathway'] == null && m['Project_pathway'] != null) {
          m['project_pathway'] = m['Project_pathway'];
        }
        if (m['learningPathway'] == null && m['Project_pathway'] != null) {
          m['learningPathway'] = m['Project_pathway'];
        }
        m['pathways'] = m['pathways'] ??
            (m['Project_pathway'] != null
                ? [m['Project_pathway']]
                : <dynamic>[]);
        m['qualifications'] = m['qualifications'] ?? <dynamic>[];
        return m;
      }).toList();

      setState(() {
        _siteData = normalized;
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

      if (learner != null && learner['learner_id'] != null) {
        // Navigate to class list page so user can scan documents and mark attendance
        final learnerId = learner['learner_id'].toString();
        final classId = learner['class_id']?.toString() ?? '';

        if (learnerId.isNotEmpty && classId.isNotEmpty) {
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
        } else if (learnerId.isNotEmpty) {
          // Fallback: if no class_id, show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Learner found but class information is missing'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          throw Exception('Learner ID is missing');
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
      // Use global search endpoint (no SDP filter) with 5s timeout for faster feedback
      final uri =
          Uri.parse(AppConfig.buildUrl('search_learner_global.php')).replace(
        queryParameters: {
          'id_number': idNumber,
        },
      );

      print('[ADMIN] Searching learner online (global): $uri');

      final response = await http.get(uri).timeout(
        const Duration(seconds: 5), // Reduced timeout from 10s to 5s
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
        actions: [
          if (!_isOnline)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Chip(
                  label: Text('Offline',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade900)),
                  backgroundColor: Colors.orange.shade100,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection:
            Axis.vertical, // Vertical scrolling for the entire page
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_siteData.isNotEmpty &&
                  _siteData.first['project_name'] != null)
                Text(
                  'Project: ${_siteData.first['project_name']}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue),
                ),
              if (_siteData.isNotEmpty && _siteData.first['sdp_name'] != null)
                Text(
                  'SDP: ${_siteData.first['sdp_name']}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey),
                ),
              Text(
                'Sites & Classes (${_siteData.length} sites)',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Search bar for learner by ID number with autocomplete
              Stack(
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              decoration: const InputDecoration(
                                hintText:
                                    'Search learner by ID number or name...',
                                prefixIcon: Icon(Icons.search),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                              onSubmitted: (_) => _searchLearnerById(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchSuggestions.clear();
                                  _showSuggestions = false;
                                });
                              },
                              tooltip: 'Clear search',
                            ),
                          _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
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
                  // Autocomplete suggestions dropdown
                  if (_showSuggestions && _searchSuggestions.isNotEmpty)
                    Positioned(
                      top: 60,
                      left: 0,
                      right: 0,
                      child: Card(
                        elevation: 4,
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchSuggestions.length,
                            itemBuilder: (context, index) {
                              final suggestion = _searchSuggestions[index];
                              final name = suggestion['name'] ?? '';
                              final surname = suggestion['surname'] ?? '';
                              final idNumber = suggestion['id_number'] ?? '';
                              final className = suggestion['class_name'] ?? '';
                              final siteName = suggestion['site_name'] ?? '';

                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.person, size: 20),
                                title: Text(
                                  '$surname $name ($idNumber)',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  'Class: $className${siteName.isNotEmpty ? ' • Site: $siteName' : ''}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () =>
                                    _selectSearchSuggestion(suggestion),
                                hoverColor: Colors.blue.withOpacity(0.1),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
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
                              : (item['learningPathway'] ??
                                      item['project_pathway'] ??
                                      'N/A')
                                  .toString();
                          final qualifications = item['qualification_name']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true
                              ? item['qualification_name'].toString()
                              : (item['qualifications'] is List
                                  ? (item['qualifications'] as List).join(', ')
                                  : (item['qualification_id']?.toString() ??
                                      'N/A'));

                          return DataRow(cells: [
                            DataCell(Text(item['siteName'] ?? 'N/A')),
                            DataCell(Text(item['project_name'] ??
                                item['project_id'] ??
                                'N/A')),
                            DataCell(Text(item['sdp_name'] ??
                                item['sdp_client_name'] ??
                                item['sdp_id'] ??
                                'N/A')),
                            DataCell(
                              Tooltip(
                                message: pathways,
                                child: Text(
                                  pathways.length > 30
                                      ? '${pathways.substring(0, 30)}...'
                                      : pathways,
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            DataCell(
                              Tooltip(
                                message: qualifications,
                                child: Text(
                                  qualifications.length > 30
                                      ? '${qualifications.substring(0, 30)}...'
                                      : qualifications,
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
