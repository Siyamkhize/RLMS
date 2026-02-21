import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'DetailsPage.dart';
import 'database_helper.dart';
import 'poe_document_scanner.dart';
import 'config.dart';
import 'finance_register_history.dart';

class SdpLearnersPage extends StatefulWidget {
  final String sdpIdentifier;
  final String? sdpDisplayName;

  const SdpLearnersPage({
    super.key,
    required this.sdpIdentifier,
    this.sdpDisplayName,
  });

  @override
  State<SdpLearnersPage> createState() => _SdpLearnersPageState();
}

class _SdpLearnersPageState extends State<SdpLearnersPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _learners = [];
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  final bool _isSyncing = false;
  bool _isSearching = false;
  bool _showSuggestions = false;
  String? _errorMessage;
  bool _isOnlineMode = false;
  Timer? _searchDebounceTimer;

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRecords = 0;
  final int _perPage = 50;
  bool _hasNextPage = false;

  // Filter values
  String? _selectedSite;
  String? _selectedClass;
  List<String> _availableSites = [];
  List<String> _availableClasses = [];
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadLearners(reset: true);
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasNextPage) {
        _loadMoreLearners();
      }
    }
  }

  // Smart search functionality
  void _onSearchChanged() {
    final query = _searchController.text.trim();

    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    if (query.length < 2) {
      setState(() {
        _searchSuggestions.clear();
        _showSuggestions = false;
      });
      return;
    }

    // Debounce search requests - smart search with 300ms delay
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_isOnlineMode) {
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
      final url = AppConfig.buildUrl('search_autocomplete.php', queryParams: {
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
      print('Smart search autocomplete error: $e');
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
    // Extract ID number from suggestion - backend should get (ID) only 9301156789012
    String extractedId = '';

    // Try multiple fields to get the ID number (same logic as test file)
    if (suggestion['id_number'] != null &&
        suggestion['id_number'].toString().isNotEmpty) {
      extractedId = suggestion['id_number'].toString();
    } else if (suggestion['search_value'] != null &&
        suggestion['search_value'].toString().isNotEmpty) {
      extractedId = suggestion['search_value'].toString();
    } else if (suggestion['display_text'] != null) {
      // Extract ID from display text like "Doe John (9301156789012)"
      final displayText = suggestion['display_text'].toString();
      final match = RegExp(r'\((\d+)\)').firstMatch(displayText);
      if (match != null) {
        extractedId = match.group(1) ?? '';
      }
    }

    // Clean the ID number (remove any non-digits)
    extractedId = extractedId.replaceAll(RegExp(r'[^\d]'), '');

    // Use the extracted ID number in the search field
    _searchController.text = extractedId;

    setState(() {
      _showSuggestions = false;
      _searchQuery = extractedId;
    });

    _searchFocusNode.unfocus();
    _loadLearners(reset: true);
  }

  void _performSmartSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      setState(() {
        _searchQuery = query;
        _showSuggestions = false;
      });
      _searchFocusNode.unfocus();
      _loadLearners(reset: true);
    }
  }

  Future<void> _loadLearners({bool reset = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _learners.clear();
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Always try online first - prioritize fresh data
      print('Attempting online data fetch...');
      final isOnline = await _checkConnectivity();
      _isOnlineMode = isOnline;

      if (isOnline) {
        // Online mode - fetch from API and sync to local
        await _fetchLearnersFromApi();
      } else {
        // Offline mode - use local database
        print('No internet connection, using local database...');
        await _fetchLearnersFromDatabase();
      }
    } catch (e) {
      print('Error in _loadLearners: $e');

      // If online fetch failed, try local database as fallback
      if (_isOnlineMode && _learners.isEmpty) {
        print('Online fetch failed, trying local database as fallback...');
        try {
          await _fetchLearnersFromDatabase();
          // Update UI to show we're using cached data
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Using cached data - online sync failed'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } catch (localError) {
          setState(() {
            _errorMessage = 'Unable to load learners: $e';
            _isLoading = false;
            _isLoadingMore = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Unable to load learners: $e';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreLearners() async {
    if (_isLoadingMore || !_hasNextPage) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    try {
      await _fetchLearnersFromApi(append: true);
    } catch (e) {
      setState(() {
        _currentPage--; // Revert page increment on error
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more learners: $e')),
        );
      }
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

  Future<void> _fetchLearnersFromApi({bool append = false}) async {
    try {
      final int? sdpId = int.tryParse(widget.sdpIdentifier);

      final Map<String, String> queryParams = {
        'page': _currentPage.toString(),
        'limit': _perPage.toString(),
      };

      if (sdpId != null) {
        queryParams['sdp_id'] = sdpId.toString();
      } else {
        queryParams['sdp_name'] = widget.sdpIdentifier;
      }

      if (_searchQuery.isNotEmpty) {
        queryParams['search'] = _searchQuery;
      }

      if (_selectedSite != null) {
        queryParams['site'] = _selectedSite!;
      }

      if (_selectedClass != null) {
        queryParams['class'] = _selectedClass!;
      }

      final uri = Uri.parse(
              'https://rlms.rlms.co.za/mobile/get_sdp_learners_paginated.php')
          .replace(queryParameters: queryParams);

      print('Fetching learners from: $uri');

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      print('API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['status'] == 'success') {
          final List<dynamic> learnersData = jsonData['data'] ?? [];
          final pagination = jsonData['pagination'] ?? {};
          final filters = jsonData['filters'] ?? {};

          // Sync learners to local database in background
          if (!append && learnersData.isNotEmpty) {
            _syncLearnersToLocal(learnersData);
          }

          setState(() {
            if (append) {
              _learners.addAll(learnersData
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList());
            } else {
              _learners = learnersData
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
            }

            _totalPages = pagination['total_pages'] ?? 1;
            _totalRecords = pagination['total_records'] ?? 0;
            _hasNextPage = pagination['has_next'] ?? false;

            // Update filter options only on first load or reset
            if (!append) {
              _availableSites =
                  List<String>.from(filters['available_sites'] ?? []);
              _availableClasses =
                  List<String>.from(filters['available_classes'] ?? []);
            }

            _isLoading = false;
            _isLoadingMore = false;
          });

          print(
              'Loaded ${learnersData.length} learners (page $_currentPage of $_totalPages)');
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to load learners');
        }
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching from API: $e');
      if (!append) {
        // Fallback to local database only on initial load
        await _fetchLearnersFromDatabase();
      } else {
        rethrow;
      }
    }
  }

  Future<void> _syncLearnersToLocal(List<dynamic> learnersData) async {
    try {
      print('Starting background sync of ${learnersData.length} learners...');

      // Show a brief sync indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                    'Syncing ${learnersData.length} learners to local storage...'),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // Run sync in background without blocking UI
      Future.microtask(() async {
        int syncedCount = 0;
        int updatedCount = 0;

        for (final learnerData in learnersData) {
          try {
            // Convert to the format expected by local database
            final learnerMap = Map<String, dynamic>.from(learnerData);

            // Add sync metadata
            learnerMap['sdp_identifier'] = widget.sdpIdentifier;
            learnerMap['synced_at'] = DateTime.now().toIso8601String();
            learnerMap['sync_source'] = 'api';

            // Check if learner exists locally
            final existingLearner =
                await _dbHelper.getLearnerById(learnerMap['LearnerID']);

            if (existingLearner == null) {
              // Insert new learner
              await _dbHelper.insertLearner(learnerMap);
              syncedCount++;
            } else {
              // Update existing learner with latest data
              await _dbHelper.updateLearner(learnerMap);
              updatedCount++;
            }
          } catch (e) {
            print('Error syncing learner ${learnerData['LearnerID']}: $e');
            // Continue with next learner even if one fails
          }
        }

        print(
            'Background sync completed: $syncedCount new, $updatedCount updated');

        // Show completion message
        if (mounted && (syncedCount > 0 || updatedCount > 0)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Synced $syncedCount new, updated $updatedCount learners'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (e) {
      print('Error starting background sync: $e');
    }
  }

  Future<void> _fetchLearnersFromDatabase() async {
    try {
      final data = await _dbHelper.getLearnersBySdp(widget.sdpIdentifier);
      setState(() {
        _learners = data;
        _totalRecords = data.length;
        _totalPages = 1;
        _hasNextPage = false;
        _extractFilterOptionsFromLocal();
        _isLoading = false;
        _isLoadingMore = false;
      });
      print('Loaded ${_learners.length} learners from local database');
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to load learners: $e';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _extractFilterOptionsFromLocal() {
    final sites = <String>{};
    final classes = <String>{};

    for (final learner in _learners) {
      final siteName = learner['siteName']?.toString();
      final className = learner['className']?.toString();

      if (siteName != null && siteName.isNotEmpty && siteName != 'N/A') {
        sites.add(siteName);
      }
      if (className != null && className.isNotEmpty && className != 'N/A') {
        classes.add(className);
      }
    }

    _availableSites = sites.toList()..sort();
    _availableClasses = classes.toList()..sort();
  }

  void _applyFilters() {
    final newQuery = _searchController.text.trim();
    if (newQuery != _searchQuery) {
      setState(() {
        _searchQuery = newQuery;
        _showSuggestions = false;
      });
    }
    _loadLearners(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _selectedSite = null;
      _selectedClass = null;
      _searchController.clear();
      _searchQuery = '';
      _searchSuggestions.clear();
      _showSuggestions = false;
    });
    _loadLearners(reset: true);
  }

  void _scanLearner(Map<String, dynamic> learner) {
    final learnerIdValue = learner['LearnerID'];
    final learnerId = int.tryParse(learnerIdValue.toString());
    final learnerName = '${learner['Surname']} ${learner['Name']}';

    if (learnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to scan learner.')),
      );
      return;
    }

    // Directly open the same camera scanning functionality as POE
    _openCameraScanPage(learnerId, learnerName);
  }

  void _markAttendance(Map<String, dynamic> learner) {
    final learnerIdValue = learner['LearnerID'];
    final learnerId = learnerIdValue?.toString() ?? '';
    final learnerName =
        '${learner['Surname'] ?? ''} ${learner['Name'] ?? ''}'.trim();
    final classId = learner['classID']?.toString() ?? '';
    final className = learner['className']?.toString() ?? 'Class $classId';

    if (learnerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to mark attendance - learner ID missing.')),
      );
      return;
    }

    if (classId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to mark attendance - class ID missing.')),
      );
      return;
    }

    // Navigate to FinanceRegisterHistory (same as finance flow)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinanceRegisterHistory(
          learnerId: learnerId,
          learnerName: learnerName,
          classId: classId,
          className: className,
          financeId: classId, // Use classId as financeId for tracking
        ),
      ),
    );
  }

  Future<void> _openCameraScanPage(int learnerId, String learnerName) async {
    try {
      // Get additional context for the upload
      final learnerData = _learners.firstWhere(
        (l) => l['LearnerID'].toString() == learnerId.toString(),
        orElse: () => {},
      );

      final classId = learnerData['classID']?.toString();
      final siteName = learnerData['siteName']?.toString();

      // Navigate to POE Document Scanner
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PoeDocumentScanner(
            learnerId: learnerId,
            learnerName: learnerName,
            classId: classId,
            siteName: siteName,
            uploadedBy: widget.sdpDisplayName ?? widget.sdpIdentifier,
          ),
        ),
      );

      if (mounted && result == true) {
        // Document was uploaded successfully
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('POE document uploaded successfully for $learnerName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening scanner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openLearnerDetails(Map<String, dynamic> learner) {
    final learnerIdValue = learner['LearnerID'];
    final learnerId = int.tryParse(learnerIdValue.toString());

    if (learnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open learner details.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsPage(
          learnerID: learnerId,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _learners.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _learners.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadLearners(reset: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_learners.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No learners found for ${widget.sdpDisplayName ?? widget.sdpIdentifier}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadLearners(reset: true),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _learners.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _learners.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final learner = _learners[index];
              final className = learner['className']?.toString() ?? 'N/A';
              final classId = learner['classID']?.toString() ?? '--';
              final siteName = learner['siteName']?.toString() ?? 'N/A';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: _searchQuery.isNotEmpty ? 2 : 1,
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${learner['Surname']} ${learner['Name']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty && _isOnlineMode)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Match',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: ${learner['IDNumber'] ?? '--'}'),
                      Text('Class: $className (ID: $classId)'),
                      Text('Site: $siteName'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _openLearnerDetails(learner),
                            icon: const Icon(Icons.info_outline),
                            tooltip: 'View Details',
                          ),
                          const Text('View', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _scanLearner(learner),
                            icon: const Icon(Icons.camera_alt),
                            tooltip: 'Scan POE',
                            color: Colors.green,
                          ),
                          const Text('Scan', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _markAttendance(learner),
                            icon: const Icon(Icons.calendar_today),
                            tooltip: 'Mark Attendance',
                            color: Colors.blue,
                          ),
                          const Text('Attend', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (widget.sdpDisplayName?.isNotEmpty ?? false)
        ? widget.sdpDisplayName!
        : widget.sdpIdentifier;

    return Scaffold(
      appBar: AppBar(
        title: Text('SDP Learners - $displayName'),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      avatar: Icon(
                        _isOnlineMode ? Icons.cloud_done : Icons.cloud_off,
                        size: 16,
                        color: _isOnlineMode ? Colors.green : Colors.orange,
                      ),
                      label: Text(
                        _isOnlineMode ? 'Online' : 'Offline',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                    ),
                    if (_isOnlineMode && _searchQuery.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Chip(
                        avatar: const Icon(Icons.auto_awesome,
                            size: 14, color: Colors.blue),
                        label:
                            const Text('Smart', style: TextStyle(fontSize: 10)),
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      ),
                    ],
                    if (_isSyncing) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh learners',
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadLearners(reset: true),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Smart Search with autocomplete
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Smart Search by ID Number or Name',
                            hintText: 'Start typing for suggestions...',
                            prefixIcon: Icon(Icons.search),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (value) => _performSmartSearch(),
                        ),
                      ),
                      if (_isSearching)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_searchController.text.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.search, color: Colors.blue),
                              onPressed: _performSmartSearch,
                              tooltip: 'Search',
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _searchSuggestions.clear();
                                  _showSuggestions = false;
                                });
                                _loadLearners(reset: true);
                              },
                              tooltip: 'Clear',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Smart search suggestions
                if (_showSuggestions && _searchSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _searchSuggestions[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.person,
                              size: 16, color: Colors.grey),
                          title: Text(
                            suggestion['text'] ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                          onTap: () => _selectSearchSuggestion(suggestion),
                          hoverColor: Colors.blue.withValues(alpha: 0.1),
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Filter dropdowns
            if (_isOnlineMode) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSite,
                      decoration: const InputDecoration(
                        labelText: 'Site',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Sites'),
                        ),
                        ..._availableSites.map((site) {
                          return DropdownMenuItem<String>(
                            value: site,
                            child: Text(site, overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSite = value;
                          _selectedClass =
                              null; // Reset class when site changes
                        });
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedClass,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Classes'),
                        ),
                        ..._availableClasses.map((className) {
                          return DropdownMenuItem<String>(
                            value: className,
                            child: Text(className),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedClass = value;
                        });
                        _applyFilters();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Results info and clear filters
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOnlineMode
                            ? 'Showing ${_learners.length} of $_totalRecords learners'
                            : 'Showing ${_learners.length} learners (offline)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        Text(
                          'Smart search: "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_selectedSite != null ||
                    _selectedClass != null ||
                    _searchQuery.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Body
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}
