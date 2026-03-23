import 'dart:io'; // For checking connectivity
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart'; // For document scanning
import 'package:permission_handler/permission_handler.dart'; // For camera permission
import 'class_details_page.dart'; // Import the class details page
import 'database_helper.dart'; // Import your DatabaseHelper class
import 'sdp_learners_page.dart';
import 'learner_list_page.dart'; // Import LearnerListPage for class navigation
import 'LearnerDetailsPage.dart'; // Import for View button
import 'finance_register_history.dart'; // Import for Attendance button
import 'learner_induction_page.dart'; // Import for Induction button

import 'config.dart'; // Import AppConfig
import 'dart:async'; // For Timer

// ADMIN PAGE WITH STRICT PROJECT FILTERING
// This implementation ensures learner searches are restricted to the current project context
// to prevent document upload confusion when same person is enrolled in multiple projects

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
  Map<String, dynamic>? _searchedLearner; // Store the searched learner result

  // Simple search result cache (caches individual search results)
  final Map<String, Map<String, dynamic>> _searchCache = {};
  final Map<String, DateTime> _searchCacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(hours: 24);

  // Document upload related variables
  final List<String> requiredDocuments = [
    'ID Document',
    'Qualifications',
    'Bank Confirmation Letter',
    'Proof of Residence',
    'CV',
    'Business form',
    'Learner agreement'
  ];
  final int _maxFileSize = 5 * 1024 * 1024; // 5MB
  final int _minFileSize = 10 * 1024; // 10KB
  bool _isScanning = false;

  // Server endpoints for document upload
  String get _uploadUrl => AppConfig.buildUrl('upload_learner_document.php');
  String get _checkDocsUrl => AppConfig.buildUrl('check_learner_documents.php');

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
    _searchCache.clear();
    _searchCacheTimestamps.clear();
    super.dispose();
  }

  // Smart search functionality with STRICT PROJECT FILTERING
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
      _fetchSearchSuggestions(query);
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
      // Offline: build suggestions from local DB (same strict filters)
      if (!_isOnline) {
        await _fetchSearchSuggestionsOffline(query);
        return;
      }

      // Get SDP identifier
      String sdpIdentifier = widget.sdp.trim();
      if (sdpIdentifier.isEmpty) {
        final resolved = _resolveSdpIdentifier();
        if (resolved != null && resolved.isNotEmpty) {
          sdpIdentifier = resolved;
        }
      }

      // Build query params with STRICT PROJECT filtering
      final queryParams = <String, String>{
        'q': query,
        'limit': '8',
      };

      if (sdpIdentifier.isNotEmpty) {
        queryParams['sdp_id'] = sdpIdentifier;
      }

      // STRICT PROJECT FILTERING - only search within current project context
      if (widget.projectId != null && widget.projectId!.isNotEmpty) {
        queryParams['project_id'] = widget.projectId!;
        debugPrint(
            '[ADMIN] STRICT FILTER: Searching only in project_id: ${widget.projectId}');
      }
      if (widget.pathwayId != null && widget.pathwayId!.isNotEmpty) {
        queryParams['pathway_id'] = widget.pathwayId!;
        debugPrint(
            '[ADMIN] STRICT FILTER: Searching only in pathway_id: ${widget.pathwayId}');
      }
      if (widget.qualificationId != null &&
          widget.qualificationId!.isNotEmpty) {
        queryParams['qualification_id'] = widget.qualificationId!;
        debugPrint(
            '[ADMIN] STRICT FILTER: Searching only in qualification_id: ${widget.qualificationId}');
      }

      // DEBUG: Print all search parameters
      debugPrint('[ADMIN] 🔍 SEARCH DEBUG - All parameters:');
      debugPrint('[ADMIN] SDP Identifier: $sdpIdentifier');
      debugPrint('[ADMIN] Query params: $queryParams');
      debugPrint(
          '[ADMIN] Expected learner data: SDP=41, Project=87, Pathway="Short Skills Programme", Qualification=24173');

      // Use SDP-specific autocomplete endpoint with fallback mechanism
      final url = AppConfig.buildUrl('search_learner_autocomplete_sdp.php',
          queryParams: queryParams);

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
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _fetchSearchSuggestionsOffline(String query) async {
    if (!mounted || query.length < 2) return;

    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;

    final sdpId = await _resolveOfflineSdpId(dbHelper);
    final projectIdStr = widget.projectId?.trim() ?? '';
    final projectIdInt = int.tryParse(projectIdStr) ?? 0;

    // Match server strict behavior: require SDP + Project for the admin search.
    if (sdpId <= 0 || projectIdInt <= 0) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final term = '${query.trim()}%';

    final whereExtras = <String>[];
    final extraArgs = <Object>[];

    if (widget.pathwayId != null && widget.pathwayId!.trim().isNotEmpty) {
      whereExtras.add('LOWER(TRIM(s.Project_pathway)) = LOWER(TRIM(?))');
      extraArgs.add(widget.pathwayId!.trim());
    }

    if (widget.qualificationId != null &&
        widget.qualificationId!.trim().isNotEmpty) {
      // Match the same behavior as offline site filtering: include sites
      // with the qualification_id, plus sites where qualification_id is null/empty.
      whereExtras.add(
          '(TRIM(s.qualification_id) = TRIM(?) OR s.qualification_id IS NULL OR s.qualification_id = "")');
      extraArgs.add(widget.qualificationId!.trim());
    }

    final whereExtrasSql =
        whereExtras.isNotEmpty ? ' AND ${whereExtras.join(' AND ')}' : '';

    final sql = '''
      SELECT
        l.LearnerID,
        l.IDNumber,
        l.Name,
        l.Surname,
        l.classID,
        c.className AS class_name,
        s.siteName AS site_name,
        s.siteID AS site_id,
        s.project_id,
        pr.Project_name AS project_name
      FROM learnerdetails l
      INNER JOIN class c ON l.classID = c.classID
      INNER JOIN sites s ON c.siteID = s.siteID
      LEFT JOIN project pr ON s.project_id = pr.project_id
      WHERE s.sdp_id = ?
        AND s.project_id = ?$whereExtrasSql
        AND (
          l.IDNumber LIKE ?
          OR l.Name LIKE ?
          OR l.Surname LIKE ?
        )
      ORDER BY
        CASE
          WHEN l.IDNumber LIKE ? THEN 1
          WHEN l.Surname LIKE ? THEN 2
          ELSE 3
        END,
        l.Surname, l.Name
      LIMIT 8
    ''';

    // Args map 1:1 to the SQL placeholders
    final args = <Object>[
      sdpId,
      projectIdInt,
      ...extraArgs,
      term,
      term,
      term,
      term,
      term,
    ];

    final results = await db.rawQuery(sql, args);

    setState(() {
      _searchSuggestions = results.map((row) {
        final idNumber = row['IDNumber']?.toString() ?? '';
        final classId = row['classID']?.toString() ?? '';

        return <String, dynamic>{
          'learner_id': row['LearnerID']?.toString() ?? '',
          'id_number': idNumber,
          'name': row['Name']?.toString() ?? '',
          'surname': row['Surname']?.toString() ?? '',
          'class_id': classId,
          'class_name': row['class_name']?.toString() ?? '',
          'site_name': row['site_name']?.toString() ?? '',
          'site_id': row['site_id']?.toString() ?? '',
          'project_id': row['project_id']?.toString() ?? '',
          'project_name': row['project_name']?.toString() ?? '',
          'display_text': '${row['site_name']?.toString() ?? ''} ($idNumber)',
          'search_value': idNumber,
        };
      }).toList();

      _showSuggestions =
          _searchSuggestions.isNotEmpty && _searchFocusNode.hasFocus;
    });
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
      await _fetchOnlineData();
    } else {
      // Fetch data offline (from local database)
      await _loadSitesFromLocalDatabase();
    }

    // If no data was loaded and we have widget.data, use it as final fallback
    if (_siteData.isEmpty && widget.data.isNotEmpty) {
      debugPrint(
          '[ADMIN] 🔄 No data loaded, using widget.data as final fallback (${widget.data.length} items)');
      setState(() {
        _siteData = List<Map<String, dynamic>>.from(widget.data);
        _isLoading = false;
      });
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

      final uri = Uri.parse(
          AppConfig.buildUrl('get_sdp_all_data.php', queryParams: queryParams));
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
              '[ADMIN] Parsed JSON - success: ${jsonData['success']}, sites count: ${jsonData['sites']?.length ?? 0}');

          if (jsonData['success'] == true && jsonData['sites'] != null) {
            final sites = List<Map<String, dynamic>>.from(jsonData['sites']);
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
                '[ADMIN] API returned success=false or no sites: ${jsonData['message'] ?? 'Unknown error'}');
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
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Note: offline search relies on already-cached tables.
  // No schema changes or extra sync operations are done here.

  Future<void> _loadSitesFromLocalDatabase() async {
    try {
      final dbHelper = DatabaseHelper();

      // Fetch sites where sdp_id matches the passed sdp (even if widget.sdp is name/email)
      final int sdpId = await _resolveOfflineSdpId(dbHelper);

      debugPrint('[ADMIN] ===== OFFLINE SITES LOOKUP =====');
      debugPrint('[ADMIN] SDP ID resolved: $sdpId');
      debugPrint('[ADMIN] Project ID: ${widget.projectId}');
      debugPrint('[ADMIN] Pathway ID: ${widget.pathwayId}');
      debugPrint('[ADMIN] Qualification ID: ${widget.qualificationId}');

      if (sdpId == 0) {
        debugPrint('[ADMIN] ❌ Invalid SDP ID, cannot load sites');
        // Try to use widget.data as fallback if available
        if (widget.data.isNotEmpty) {
          debugPrint(
              '[ADMIN] 🔄 Using widget.data as fallback (${widget.data.length} items)');
          setState(() {
            _siteData = List<Map<String, dynamic>>.from(widget.data);
            _isLoading = false;
          });
          return;
        }
        setState(() {
          _siteData = [];
          _isLoading = false;
        });
        return;
      }

      // Check what's in the sites table
      final db = await dbHelper.database;
      final allSites = await db.query('sites');
      debugPrint('[ADMIN] Total sites in database: ${allSites.length}');

      if (allSites.isNotEmpty) {
        // Show sites grouped by sdp_id
        final sitesGrouped = <int, int>{};
        for (var site in allSites) {
          final siteSDPId =
              int.tryParse(site['sdp_id']?.toString() ?? '0') ?? 0;
          sitesGrouped[siteSDPId] = (sitesGrouped[siteSDPId] ?? 0) + 1;
        }
        debugPrint('[ADMIN] Sites by SDP:');
        sitesGrouped.forEach((id, count) {
          debugPrint('  - SDP ID $id: $count sites');
        });
      }

      // Now pass the sdpId to your database method
      List<Map<String, dynamic>> offlineSites;

      final where = <String>['sdp_id = ?'];
      final args = <Object>[sdpId];

      if (widget.projectId != null && widget.projectId!.isNotEmpty) {
        where.add('project_id = ?');
        args.add(int.tryParse(widget.projectId!) ?? 0);
        debugPrint('[ADMIN] Filtering by project_id: ${widget.projectId}');
      }

      // NOTE: widget.pathwayId is passed as pathway NAME (see sdp_learning_pathways_page.dart)
      if (widget.pathwayId != null && widget.pathwayId!.isNotEmpty) {
        where.add('LOWER(TRIM(Project_pathway)) = LOWER(TRIM(?))');
        args.add(widget.pathwayId!);
        debugPrint('[ADMIN] Filtering by pathway: ${widget.pathwayId}');
      }
      if (widget.qualificationId != null &&
          widget.qualificationId!.isNotEmpty) {
        // Only filter by qualification if the site has a qualification_id set
        // Sites with null qualification_id should still be shown
        where.add(
            '(TRIM(qualification_id) = TRIM(?) OR qualification_id IS NULL OR qualification_id = "")');
        args.add(widget.qualificationId!);
        debugPrint(
            '[ADMIN] Filtering by qualification_id: ${widget.qualificationId} (including null)');
      }

      debugPrint(
          '[ADMIN] Query: SELECT * FROM sites WHERE ${where.join(' AND ')}');
      debugPrint('[ADMIN] Args: $args');

      offlineSites = await db.query(
        'sites',
        where: where.join(' AND '),
        whereArgs: args,
      );

      debugPrint('[ADMIN] Found ${offlineSites.length} sites matching filters');

      if (offlineSites.isEmpty) {
        debugPrint('[ADMIN] ❌ No sites found with current filters');
        debugPrint('[ADMIN] Trying without qualification filter...');

        // Try without qualification filter
        final whereNoQual = <String>['sdp_id = ?'];
        final argsNoQual = <Object>[sdpId];
        if (widget.projectId != null && widget.projectId!.isNotEmpty) {
          whereNoQual.add('project_id = ?');
          argsNoQual.add(int.tryParse(widget.projectId!) ?? 0);
        }

        offlineSites = await db.query(
          'sites',
          where: whereNoQual.join(' AND '),
          whereArgs: argsNoQual,
        );

        debugPrint(
            '[ADMIN] Without qualification filter: ${offlineSites.length} sites');

        // If still no sites found, try with just SDP ID
        if (offlineSites.isEmpty) {
          debugPrint('[ADMIN] Trying with just SDP ID...');
          offlineSites = await db.query(
            'sites',
            where: 'sdp_id = ?',
            whereArgs: [sdpId],
          );
          debugPrint('[ADMIN] With just SDP ID: ${offlineSites.length} sites');
        }

        // If still no sites, try to use widget.data as fallback
        if (offlineSites.isEmpty && widget.data.isNotEmpty) {
          debugPrint(
              '[ADMIN] 🔄 No sites in database, using widget.data as fallback (${widget.data.length} items)');
          setState(() {
            _siteData = List<Map<String, dynamic>>.from(widget.data);
            _isLoading = false;
          });
          return;
        }

        if (offlineSites.isNotEmpty) {
          debugPrint('[ADMIN] Available qualification IDs in these sites:');
          for (var site in offlineSites) {
            debugPrint(
                '  - Site: ${site['siteName']}, Qual ID: ${site['qualification_id']}');
          }
        }
      }

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

      debugPrint('[ADMIN] ✅ Returning ${normalized.length} normalized sites');
      debugPrint('[ADMIN] ===== END OFFLINE SITES LOOKUP =====');

      setState(() {
        _siteData = normalized;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[ADMIN] ❌ Error loading offline sites: $e');

      // Try to use widget.data as fallback if available
      if (widget.data.isNotEmpty) {
        debugPrint(
            '[ADMIN] 🔄 Error loading from database, using widget.data as fallback (${widget.data.length} items)');
        setState(() {
          _siteData = List<Map<String, dynamic>>.from(widget.data);
          _isLoading = false;
        });
        return;
      }

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
        // Store the learner result to display in UI
        // Convert all fields to strings to avoid type mismatch errors
        setState(() {
          _searchedLearner = {
            'learner_id': learner!['learner_id']?.toString() ?? '',
            'name': learner['name']?.toString() ?? '',
            'surname': learner['surname']?.toString() ?? '',
            'id_number': learner['id_number']?.toString() ?? '',
            'class_id': learner['class_id']?.toString() ?? '',
            'class_name': learner['class_name']?.toString() ?? '',
            'site_id': learner['site_id']?.toString() ?? '',
            'site_name': learner['site_name']?.toString() ?? '',
          };
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found: ${learner['surname']} ${learner['name']}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _searchedLearner = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No learner found with ID number: $idNumber'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _searchedLearner = null;
      });

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
    // Check cache first
    // Include project context in cache key so results from other projects
    // can't be reused for the same ID number.
    final cacheKey = <String>[
      idNumber.trim().toLowerCase(),
      widget.projectId?.trim().toLowerCase() ?? '',
      widget.sdp.trim().toLowerCase(),
      widget.pathwayId?.trim().toLowerCase() ?? '',
      widget.qualificationId?.trim().toLowerCase() ?? '',
    ].join('|');
    if (_searchCache.containsKey(cacheKey)) {
      final cacheTime = _searchCacheTimestamps[cacheKey];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime) < _cacheExpiry) {
        print('[ADMIN] ✅ Cache HIT for ID: $idNumber');
        return _searchCache[cacheKey];
      } else {
        // Cache expired
        _searchCache.remove(cacheKey);
        _searchCacheTimestamps.remove(cacheKey);
        print('[ADMIN] ⏰ Cache EXPIRED for ID: $idNumber');
      }
    }

    print('[ADMIN] ❌ Cache MISS for ID: $idNumber');

    // Try local database first (faster!) - PROJECT-FILTERED SEARCH
    print('[ADMIN] 🔍 Searching local database first (PROJECT-FILTERED)...');
    final localResult = await _searchLearnerOffline(idNumber);
    if (localResult != null) {
      print('[ADMIN] ✅ Found in local database!');
      // Cache the local result
      _searchCache[cacheKey] = localResult;
      _searchCacheTimestamps[cacheKey] = DateTime.now();
      print(
          '[ADMIN] 💾 Cached local result for ID: $idNumber (expires in 24 hours)');
      return localResult;
    }

    // Not found locally, try server with PROJECT FILTERING
    print(
        '[ADMIN] ⚠️ Not found locally, searching server with PROJECT FILTERING...');

    try {
      // Get SDP identifier
      String sdpIdentifier = widget.sdp.trim();
      if (sdpIdentifier.isEmpty) {
        final resolved = _resolveSdpIdentifier();
        if (resolved != null && resolved.isNotEmpty) {
          sdpIdentifier = resolved;
        }
      }

      // Build query parameters with STRICT PROJECT filtering
      final queryParams = <String, String>{
        'id_number': idNumber, // Reverted back to 'id_number'
        'page': '1',
        'limit': '50',
      };

      if (sdpIdentifier.isNotEmpty) {
        queryParams['sdp_id'] = sdpIdentifier;
      }

      // STRICT PROJECT FILTERING - only search within current project context
      if (widget.projectId != null && widget.projectId!.isNotEmpty) {
        queryParams['project_id'] = widget.projectId!;
        debugPrint(
            '[ADMIN] STRICT FILTER: Searching only in project_id: ${widget.projectId}');
      }
      if (widget.pathwayId != null && widget.pathwayId!.isNotEmpty) {
        queryParams['pathway_id'] = widget.pathwayId!;
        debugPrint(
            '[ADMIN] STRICT FILTER: Searching only in pathway_id: ${widget.pathwayId}');
      }
      if (widget.qualificationId != null &&
          widget.qualificationId!.isNotEmpty) {
        queryParams['qualification_id'] = widget.qualificationId!;
        debugPrint(
            '[ADMIN] STRICT FILTER: Searching only in qualification_id: ${widget.qualificationId}');
      }

      // Use project-filtered search endpoint for STRICT project filtering
      final uri =
          Uri.parse(AppConfig.buildUrl('search_learner_global.php')).replace(
        queryParameters: queryParams,
      );

      print('[ADMIN] Searching learner online (PROJECT-FILTERED): $uri');

      final response = await http.get(uri).timeout(
        const Duration(seconds: 5), // Reduced timeout from 10s to 5s
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      print('[ADMIN] 📡 Server response status: ${response.statusCode}');
      print('[ADMIN] 📡 Server response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('[ADMIN] 📦 Parsed JSON: $jsonData');
        print('[ADMIN] 📦 Success: ${jsonData['success']}');
        print('[ADMIN] 📦 Learners: ${jsonData['learners']}');

        // Check if we got the "Search parameter is required" error and log it
        if (jsonData['success'] == false &&
            jsonData['message']
                    ?.toString()
                    .contains('Search parameter is required') ==
                true) {
          print(
              '[ADMIN] ⚠️ Server expects different parameter name. Error: ${jsonData['message']}');
        }

        if (jsonData['success'] == true && jsonData['learners'] != null) {
          final learners = jsonData['learners'] as List;
          print('[ADMIN] 📦 Learners count: ${learners.length}');

          if (learners.isNotEmpty) {
            final learnerData = learners[0] as Map<String, dynamic>;
            print(
                '[ADMIN] ✅ Found learner: ${learnerData['surname']}, ${learnerData['name']}');

            // Convert all fields to strings to avoid type mismatch errors
            final normalizedData = {
              'learner_id': learnerData['learner_id']?.toString() ?? '',
              'name': learnerData['name']?.toString() ?? '',
              'surname': learnerData['surname']?.toString() ?? '',
              'id_number': learnerData['id_number']?.toString() ?? '',
              'class_id': learnerData['class_id']?.toString() ?? '',
              'class_name': learnerData['class_name']?.toString() ?? '',
              'site_id': learnerData['site_id']?.toString() ?? '',
              'site_name': learnerData['site_name']?.toString() ?? '',
            };

            // Cache the normalized result
            _searchCache[cacheKey] = normalizedData;
            _searchCacheTimestamps[cacheKey] = DateTime.now();
            print(
                '[ADMIN] 💾 Cached server result for ID: $idNumber (expires in 24 hours)');

            // Return the normalized learner data
            return normalizedData;
          } else {
            print('[ADMIN] ⚠️ Server returned empty learners array');
          }
        } else {
          print(
              '[ADMIN] ⚠️ Server returned success=false or no learners field');
        }
      } else {
        print('[ADMIN] ❌ Server returned status code: ${response.statusCode}');
      }

      print('[ADMIN] ❌ No learner found on server');
      return null;
    } catch (e) {
      print('[ADMIN] Error searching online: $e');
      return null;
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

      // DEBUG: Print offline search parameters
      debugPrint('[ADMIN] 🔍 OFFLINE SEARCH DEBUG:');
      debugPrint('[ADMIN] ID Number: $idNumber');
      debugPrint('[ADMIN] SDP Identifier: $sdpIdentifier');
      debugPrint('[ADMIN] Project ID: ${widget.projectId}');
      debugPrint('[ADMIN] Pathway ID: ${widget.pathwayId}');
      debugPrint('[ADMIN] Qualification ID: ${widget.qualificationId}');

      // STRICT PROJECT FILTERING for offline search
      final db = await dbHelper.database;

      // Build WHERE clause with project filtering
      final where = <String>['l.IDNumber = ?'];
      final args = <Object>[idNumber];

      // Strictly require SDP + Project filters (same behavior as server strict endpoints)
      final sdpId = await _resolveOfflineSdpId(dbHelper);
      if (sdpId <= 0) {
        debugPrint(
            '[ADMIN] OFFLINE STRICT FILTER: sdp_id could not be resolved');
        return null;
      }
      where.add('s.sdp_id = ?');
      args.add(sdpId);

      final projectIdStr = widget.projectId?.trim() ?? '';
      final projectIdInt = int.tryParse(projectIdStr) ?? 0;
      if (projectIdInt <= 0) {
        debugPrint(
            '[ADMIN] OFFLINE STRICT FILTER: project_id is missing/invalid');
        return null;
      }
      where.add('s.project_id = ?');
      args.add(projectIdInt);

      // Keep offline learner search aligned with the same contextual filters
      // used to load sites online/offline in AdminPage.
      if (widget.pathwayId != null && widget.pathwayId!.trim().isNotEmpty) {
        where.add('LOWER(TRIM(s.Project_pathway)) = LOWER(TRIM(?))');
        args.add(widget.pathwayId!.trim());
      }

      if (widget.qualificationId != null &&
          widget.qualificationId!.trim().isNotEmpty) {
        where.add(
            '(TRIM(s.qualification_id) = TRIM(?) OR s.qualification_id IS NULL OR s.qualification_id = "")');
        args.add(widget.qualificationId!.trim());
      }

      // Query with JOIN to get class + site (for sdp_id/project_id filtering)
      final query = '''
        SELECT
          l.*,
          c.ClassName,
          c.classID,
          s.project_id
        FROM learnerdetails l
        LEFT JOIN class c ON l.classID = c.classID
        LEFT JOIN sites s ON c.siteID = s.siteID
        WHERE ${where.join(' AND ')}
        LIMIT 1
      ''';

      debugPrint('[ADMIN] OFFLINE QUERY: $query');
      debugPrint('[ADMIN] OFFLINE ARGS: $args');

      final results = await db.rawQuery(query, args);

      if (results.isNotEmpty) {
        final learner = results.first;
        debugPrint(
            '[ADMIN] OFFLINE FOUND: ${learner['Name']} ${learner['Surname']} in project ${learner['project_id']}');

        return {
          'learner_id': learner['LearnerID']?.toString() ?? '',
          'name': learner['Name']?.toString() ?? '',
          'surname': learner['Surname']?.toString() ?? '',
          'id_number': learner['IDNumber']?.toString() ?? '',
          'class_id': learner['classID']?.toString() ?? '',
          'class_name': learner['ClassName']?.toString() ?? '',
        };
      }

      debugPrint(
          '[ADMIN] OFFLINE: No learner found with ID $idNumber in current project context');
      return null;
    } catch (e) {
      print('[ADMIN] Error searching offline: $e');
      return null;
    }
  }

  // Helper methods for document upload
  Future<List<String>> _fetchServerDocuments(String learnerId) async {
    try {
      print('Fetching server documents for learner: $learnerId');
      print('Request URL: $_checkDocsUrl');
      print('Request body: {"learner_id": "$learnerId"}');

      final response = await http.post(
        Uri.parse(_checkDocsUrl),
        body: {'learner_id': learnerId},
      ).timeout(const Duration(seconds: 10));

      print('Server response status: ${response.statusCode}');
      print('Server response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final jsonResponse = jsonDecode(response.body);
          print('Parsed JSON response: $jsonResponse');

          if (jsonResponse['success'] == true) {
            final documents = List<String>.from(jsonResponse['documents']);
            print('Successfully fetched server documents: $documents');
            return documents;
          } else {
            print('Server returned error: ${jsonResponse['message']}');
            throw Exception(jsonResponse['message']);
          }
        } catch (e) {
          print('Error parsing JSON response: $e');
          print('Raw response: ${response.body}');
          return [];
        }
      } else {
        print('Server error: ${response.statusCode}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching server documents: $e');
      return [];
    }
  }

  Future<List<String>> getExistingDocuments(String learnerId) async {
    try {
      final dbHelper = DatabaseHelper();
      List<String> existingDocs = [];

      // Check local database
      final localDocs = await dbHelper.fetchLearnerDocuments(learnerId);
      existingDocs =
          localDocs.map((doc) => doc['documentName'] as String).toList();
      print('Local documents for $learnerId: $existingDocs');

      // Check server if online
      if (await _checkConnectivity()) {
        final serverDocs = await _fetchServerDocuments(learnerId);
        print('Server documents for $learnerId: $serverDocs');
        for (var doc in serverDocs) {
          if (!existingDocs.contains(doc)) {
            existingDocs.add(doc);
          }
        }
      } else {
        print('No internet connection, skipping server check for $learnerId');
      }

      print('Combined existing documents for $learnerId: $existingDocs');
      return existingDocs;
    } catch (e) {
      print('Error getting existing documents: $e');
      return [];
    }
  }

  Future<bool> canUploadDocuments(String learnerId) async {
    try {
      final existingDocs = await getExistingDocuments(learnerId);
      // Check if there are any documents that can still be uploaded
      return requiredDocuments.any((doc) => !existingDocs.contains(doc));
    } catch (e) {
      print('Error checking if documents can be uploaded: $e');
      return false;
    }
  }

  Future<void> uploadDocument(
      String learnerId, String documentName, String filePath) async {
    try {
      final dbHelper = DatabaseHelper();
      final document = {
        'learner_id': learnerId,
        'documentName': documentName,
        'learner_document': filePath,
        'status': 'Pending',
        'upload_date': DateTime.now().toIso8601String(),
        'synced': 0,
      };
      await dbHelper.insertLearnerDocument(document);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$documentName uploaded locally')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload $documentName: $e')),
      );
      rethrow;
    }
  }

  Future<void> _syncDocument(Map<String, dynamic> document) async {
    try {
      final filePath = document['learner_document'] as String;
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Document file not found: $filePath');
      }

      var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['learner_id'] = document['learner_id'].toString();
      request.fields['documentName'] = document['documentName'];
      request.fields['status'] = document['status'];
      request.fields['upload_date'] = document['upload_date'];
      request.fields['synced'] = '1';
      if (document['rejection_reason'] != null) {
        request.fields['rejection_reason'] = document['rejection_reason'];
      }

      request.files.add(await http.MultipartFile.fromPath(
        'learner_document',
        filePath,
        filename: filePath.split('/').last,
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print('Sync response status: ${response.statusCode}');
      print('Sync response body: $responseBody');

      if (response.statusCode == 200) {
        try {
          final jsonResponse = jsonDecode(responseBody);
          if (jsonResponse['success'] == true) {
            final dbHelper = DatabaseHelper();
            await dbHelper.updateLearnerDocumentSynced(
                document['document_id'], 1);
            print(
                'Document synced: ${document['documentName']} for learner ${document['learner_id']}');
          } else {
            throw Exception(
                jsonResponse['message'] ?? 'Failed to sync document');
          }
        } catch (e) {
          throw Exception('Invalid JSON response: $responseBody');
        }
      } else {
        throw Exception('Server error: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      print('Error syncing document: $e');
      rethrow;
    }
  }

  Future<void> syncUnsyncedDocuments() async {
    if (!await _checkConnectivity()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection, cannot sync')),
      );
      return;
    }

    try {
      final dbHelper = DatabaseHelper();
      final unsyncedDocs = await dbHelper.fetchUnsyncedLearnerDocuments();
      print('Found ${unsyncedDocs.length} unsynced documents');

      for (var doc in unsyncedDocs) {
        await _syncDocument(doc);
      }

      if (unsyncedDocs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Synced ${unsyncedDocs.length} documents to server')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No documents to sync')),
        );
      }

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error syncing documents: $e')),
      );
    }
  }

  void showDocumentUploadModal(BuildContext context, String learnerId) {
    String? selectedDocument;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return FutureBuilder<List<String>>(
              future: getExistingDocuments(learnerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AlertDialog(
                    title: Text('Loading...'),
                    content: Center(child: CircularProgressIndicator()),
                  );
                }

                final existingDocs = snapshot.data ?? [];
                final availableDocs = requiredDocuments
                    .where((doc) => !existingDocs.contains(doc))
                    .toList();

                if (availableDocs.isEmpty) {
                  return AlertDialog(
                    title: const Text('All Documents Uploaded'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'All required documents have already been uploaded for this learner.'),
                        const SizedBox(height: 8),
                        Text('Existing documents: ${existingDocs.join(', ')}'),
                        const SizedBox(height: 8),
                        Text(
                            'Required documents: ${requiredDocuments.join(', ')}'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  );
                }

                return AlertDialog(
                  title: const Text('Upload Document'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Available documents to upload: ${availableDocs.length}/${requiredDocuments.length}'),
                      const SizedBox(height: 8),
                      if (existingDocs.isNotEmpty)
                        Text('Already uploaded: ${existingDocs.join(', ')}'),
                      const SizedBox(height: 16),
                      DropdownButton<String>(
                        hint: const Text('Select Document Type'),
                        value: selectedDocument,
                        isExpanded: true,
                        items: availableDocs.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedDocument = newValue;
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: selectedDocument == null || _isScanning
                          ? null
                          : () async {
                              setState(() => _isScanning = true);
                              try {
                                final status =
                                    await Permission.camera.request();
                                if (!status.isGranted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Camera permission denied. Please enable it in settings.',
                                      ),
                                    ),
                                  );
                                  await openAppSettings();
                                  setState(() => _isScanning = false);
                                  return;
                                }

                                final scanner = FlutterDocScanner();
                                // Allow unlimited pages (999) for CV and learner agreements
                                final scanResult =
                                    await scanner.getScanDocuments(
                                  page: 999, // Unlimited pages
                                );
                                if (scanResult is! Map ||
                                    !scanResult.containsKey('pdfUri') ||
                                    scanResult['pdfUri'] == null) {
                                  throw 'Invalid scan result';
                                }

                                final pdfPath = (scanResult['pdfUri'] as String)
                                    .replaceFirst('file:///', '');
                                final file = File(pdfPath);

                                if (!await file.exists() ||
                                    !pdfPath.endsWith('.pdf')) {
                                  throw 'Invalid or missing PDF file';
                                }

                                final fileSize = await file.length();
                                if (fileSize > _maxFileSize) {
                                  throw 'File size exceeds 5MB limit';
                                }
                                if (fileSize < _minFileSize) {
                                  throw 'The scanned page may not be clear. Ensure text is sharp and entire page is captured.';
                                }

                                await uploadDocument(
                                    learnerId, selectedDocument!, pdfPath);
                                // Close the dialog
                                Navigator.pop(context);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '$selectedDocument uploaded successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Error scanning document: $e')),
                                );
                              } finally {
                                setState(() => _isScanning = false);
                              }
                            },
                      child: const Text('Scan and Upload'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
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
                              final projectName =
                                  suggestion['project_name'] ?? '';

                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.person, size: 20),
                                title: Text(
                                  '$surname $name ($idNumber)',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  'Project: $projectName${className.isNotEmpty ? ' • Class: $className' : ''}${siteName.isNotEmpty ? ' • Site: $siteName' : ''}',
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

              // Display searched learner result with action buttons
              if (_searchedLearner != null)
                Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Search Result',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _searchedLearner = null;
                                  _searchController.clear();
                                });
                              },
                              tooltip: 'Clear result',
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person,
                                size: 40, color: Colors.blue),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_searchedLearner!['surname'] ?? ''} ${_searchedLearner!['name'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${_searchedLearner!['id_number'] ?? 'N/A'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (_searchedLearner!['class_name'] != null &&
                                      _searchedLearner!['class_name']
                                          .toString()
                                          .isNotEmpty)
                                    Text(
                                      'Class: ${_searchedLearner!['class_name']}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LearnerDetailsPage(
                                      learnerID: _searchedLearner!['learner_id']
                                              ?.toString() ??
                                          'N/A',
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.visibility),
                              label: const Text('View'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Show document upload modal for scanning/uploading
                                showDocumentUploadModal(
                                  context,
                                  _searchedLearner!['learner_id']?.toString() ??
                                      'N/A',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Documents'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                final learnerName =
                                    '${_searchedLearner!['surname'] ?? ''} ${_searchedLearner!['name'] ?? ''}'
                                        .trim();
                                final classId =
                                    _searchedLearner!['class_id']?.toString() ??
                                        '';
                                final className =
                                    _searchedLearner!['class_name']
                                            ?.toString() ??
                                        'Class $classId';

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FinanceRegisterHistory(
                                      learnerId: _searchedLearner!['learner_id']
                                              ?.toString() ??
                                          'N/A',
                                      learnerName: learnerName,
                                      classId: classId,
                                      className: className,
                                      financeId: classId,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.calendar_today),
                              label: const Text('Attendance'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LearnerInductionPage(
                                      learnerID: _searchedLearner!['learner_id']
                                              ?.toString() ??
                                          '',
                                      learnerName:
                                          '${_searchedLearner!['surname'] ?? ''} ${_searchedLearner!['name'] ?? ''}'
                                              .trim(),
                                      classID: _searchedLearner!['class_id']
                                              ?.toString() ??
                                          '',
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.access_time),
                              label: const Text('Induction'),
                            ),
                            ElevatedButton.icon(
                              onPressed: syncUnsyncedDocuments,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.sync),
                              label: const Text('Sync Docs'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _openSdpLearners,
                    icon: const Icon(Icons.people_alt),
                    label: const Text('View All Learners'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : syncUnsyncedDocuments,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Sync Documents'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
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
                            DataCell(
                                Text(item['siteName']?.toString() ?? 'N/A')),
                            DataCell(Text((item['project_name'] ??
                                    item['project_id'] ??
                                    'N/A')
                                .toString())),
                            DataCell(Text((item['sdp_name'] ??
                                    item['sdp_client_name'] ??
                                    item['sdp_id'] ??
                                    'N/A')
                                .toString())),
                            DataCell(
                              Tooltip(
                                message: pathways,
                                child: Text(
                                  pathways.length > 30
                                      ? '${pathways.substring(0, 30)}...'
                                      : pathways,
                                  style: const TextStyle(fontSize: 12),
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
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            DataCell(Text(
                                item['beneficiaries']?.toString() ?? 'N/A')),
                            DataCell(
                                Text(item['classes']?.toString() ?? 'N/A')),
                            DataCell(
                                Text(item['coordinates']?.toString() ?? 'N/A')),
                            DataCell(Text(
                                (item['province'] ?? item['Province'] ?? 'N/A')
                                    .toString())),
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
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}
