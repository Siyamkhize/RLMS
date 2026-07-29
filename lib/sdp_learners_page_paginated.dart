import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'DetailsPage.dart';
import 'database_helper.dart';
import 'poe_document_scanner.dart';

class SdpLearnersPagePaginated extends StatefulWidget {
  final String sdpIdentifier;
  final String? sdpDisplayName;

  const SdpLearnersPagePaginated({
    super.key,
    required this.sdpIdentifier,
    this.sdpDisplayName,
  });

  @override
  State<SdpLearnersPagePaginated> createState() => _SdpLearnersPagePaginatedState();
}

class _SdpLearnersPagePaginatedState extends State<SdpLearnersPagePaginated> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _learners = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  bool _isOnlineMode = false;

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
  
  // Sorting
  bool _sortBySurname = false;

  // Smart search autocomplete
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _showSuggestions = false;
  bool _isSearching = false;
  Timer? _searchDebounceTimer;

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
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasNextPage) {
        _loadMoreLearners();
      }
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
      // Check if online
      final isOnline = await _checkConnectivity();
      _isOnlineMode = isOnline;

      if (isOnline) {
        await _fetchLearnersFromApi();
      } else {
        await _fetchLearnersFromDatabase();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to load learners: $e';
        _isLoading = false;
        _isLoadingMore = false;
      });
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

      final uri = Uri.parse('https://rlms.rlms.co.za/mobile/get_sdp_learners_paginated.php')
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

          setState(() {
            if (append) {
              _learners.addAll(learnersData.map((item) => Map<String, dynamic>.from(item)).toList());
            } else {
              _learners = learnersData.map((item) => Map<String, dynamic>.from(item)).toList();
            }

            // Sort by surname if enabled
            if (_sortBySurname) {
              _sortLearnersBySurname();
            }

            _totalPages = pagination['total_pages'] ?? 1;
            _totalRecords = pagination['total_records'] ?? 0;
            _hasNextPage = pagination['has_next'] ?? false;

            // Update filter options only on first load or reset
            if (!append) {
              _availableSites = List<String>.from(filters['available_sites'] ?? []);
              _availableClasses = List<String>.from(filters['available_classes'] ?? []);
            }

            _isLoading = false;
            _isLoadingMore = false;
          });

          print('Loaded ${learnersData.length} learners (page $_currentPage of $_totalPages)');
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

  Future<void> _fetchLearnersFromDatabase() async {
    try {
      final data = await _dbHelper.getLearnersBySdp(widget.sdpIdentifier);
      setState(() {
        _learners = data;
        
        // Sort by surname if enabled
        if (_sortBySurname) {
          _sortLearnersBySurname();
        }
        
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

  void _sortLearnersBySurname() {
    _learners.sort((a, b) {
      final surnameA = (a['Surname']?.toString() ?? '').toLowerCase();
      final surnameB = (b['Surname']?.toString() ?? '').toLowerCase();
      
      // If surnames are the same, sort by name
      if (surnameA == surnameB) {
        final nameA = (a['Name']?.toString() ?? '').toLowerCase();
        final nameB = (b['Name']?.toString() ?? '').toLowerCase();
        return nameA.compareTo(nameB);
      }
      
      return surnameA.compareTo(surnameB);
    });
  }

  void _toggleSurnameSort() {
    setState(() {
      _sortBySurname = !_sortBySurname;
      if (_sortBySurname) {
        _sortLearnersBySurname();
      } else {
        // Reload to restore original order
        _loadLearners(reset: true);
      }
    });
  }

  // Smart search functionality
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    // Cancel previous timer
    _searchDebounceTimer?.cancel();
    
    if (query.isEmpty) {
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

  Future<void> _fetchSearchSuggestions(String query) async {
    if (query.isEmpty || !_isOnlineMode) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final int? sdpId = int.tryParse(widget.sdpIdentifier);
      
      final Map<String, String> queryParams = {
        'search': query,
        'limit': '8',
      };

      if (sdpId != null) {
        queryParams['sdp_id'] = sdpId.toString();
      } else {
        queryParams['sdp_name'] = widget.sdpIdentifier;
      }

      final uri = Uri.parse('https://rlms.rlms.co.za/mobile/get_sdp_learners_autocomplete.php')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Search timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) {
          setState(() {
            _searchSuggestions = List<Map<String, dynamic>>.from(data['suggestions'] ?? []);
            _showSuggestions = _searchSuggestions.isNotEmpty && _searchFocusNode.hasFocus;
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
    if (suggestion['id_number'] != null && suggestion['id_number'].toString().isNotEmpty) {
      extractedId = suggestion['id_number'].toString();
    } else if (suggestion['search_value'] != null && suggestion['search_value'].toString().isNotEmpty) {
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

  void _applyFilters() {
    _searchQuery = _searchController.text.trim();
    _loadLearners(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _selectedSite = null;
      _selectedClass = null;
      _searchController.clear();
      _searchQuery = '';
    });
    _loadLearners(reset: true);
  }

  void _scanLearner(Map<String, dynamic> learner) {
    final learnerIdValue = learner['LearnerID'];
    final learnerId = int.tryParse(learnerIdValue.toString());
    final name = learner['Name']?.toString() ?? '';
    final surname = learner['Surname']?.toString() ?? '';
    // Use "Surname Name" format consistently
    final learnerName = '$surname $name'.trim();

    if (learnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to scan learner.')),
      );
      return;
    }

    _openCameraScanPage(learnerId, learnerName);
  }

  Future<void> _openCameraScanPage(int learnerId, String learnerName) async {
    try {
      final learnerData = _learners.firstWhere(
        (l) => l['LearnerID'].toString() == learnerId.toString(),
        orElse: () => <String, dynamic>{},
      );
      
      final classId = learnerData['classID']?.toString();
      final siteName = learnerData['siteName']?.toString();
      
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('POE document uploaded successfully for $learnerName'),
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
              final idNumber = learner['IDNumber']?.toString() ?? '--';
              final name = learner['Name']?.toString() ?? '';
              final surname = learner['Surname']?.toString() ?? '';
              
              // Ensure correct format: "Surname Name (ID)" 
              final displayName = learner['displayName']?.toString() ?? '$surname $name ($idNumber)';
              
              final isMatch = _searchQuery.isNotEmpty && (
                idNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                displayName.toLowerCase().contains(_searchQuery.toLowerCase())
              );

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: isMatch ? 3 : 1,
                color: isMatch ? Colors.blue.shade50 : null,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  leading: isMatch ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Text(
                      'Match',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ) : null,
                  title: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isMatch ? Colors.blue.shade800 : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        'ID: $idNumber',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.w500,
                          color: isMatch ? Colors.blue.shade700 : null,
                        ),
                      ),
                      Text(
                        'Class: $className (ID: $classId)',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Site: $siteName',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  onTap: () => _openLearnerDetails(learner),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _openLearnerDetails(learner),
                        icon: const Icon(Icons.info_outline, size: 18),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _scanLearner(learner),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        color: Colors.green,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
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

    return GestureDetector(
      onTap: () {
        // Hide keyboard and suggestions when tapping outside
        _searchFocusNode.unfocus();
        setState(() {
          _showSuggestions = false;
        });
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          'SDP Learners - $displayName',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_isLoading)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Center(
                  child: Chip(
                    avatar: Icon(
                      _isOnlineMode ? Icons.cloud_done : Icons.cloud_off,
                      size: 14,
                      color: _isOnlineMode ? Colors.green : Colors.orange,
                    ),
                    label: Text(
                      _isOnlineMode ? 'Online' : 'Offline',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: _sortBySurname ? 'Disable surname sort' : 'Sort by surname A-Z',
            icon: Icon(
              _sortBySurname ? Icons.sort_by_alpha : Icons.sort_by_alpha_outlined,
              color: _sortBySurname ? Colors.blue : null,
            ),
            onPressed: _toggleSurnameSort,
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
                _loadLearners(reset: true);
              },
            ),
          IconButton(
            tooltip: 'Refresh learners',
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadLearners(reset: true),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search and filters section - fixed height to prevent overflow
            Container(
              constraints: const BoxConstraints(maxHeight: 300), // Prevent overflow
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Search bar
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            decoration: InputDecoration(
                              labelText: 'Smart Search by ID Number or Name',
                              hintText: 'Start typing for suggestions...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isSearching)
                                    const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  if (_searchController.text.isNotEmpty)
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
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.search, color: Colors.blue),
                                    onPressed: _performSmartSearch,
                                    tooltip: 'Search',
                                  ),
                                ],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: (_) => _onSearchChanged(),
                            onSubmitted: (_) => _performSmartSearch(),
                            onTap: () {
                              if (_searchSuggestions.isNotEmpty) {
                                setState(() {
                                  _showSuggestions = true;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // Smart search suggestions
                    if (_showSuggestions && _searchSuggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _searchSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _searchSuggestions[index];
                            final displayText = suggestion['display_text'] ?? '';
                            final className = suggestion['class_name'] ?? '';
                            
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.person_search, size: 18),
                              title: Text(
                                displayText,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: className.isNotEmpty ? Text(
                                'Class: $className',
                                style: const TextStyle(fontSize: 12),
                              ) : null,
                              onTap: () => _selectSearchSuggestion(suggestion),
                              hoverColor: Colors.blue.withValues(alpha: 0.1),
                            );
                          },
                        ),
                      ),

                    // Filter dropdowns
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        children: [
                          // Site filter
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  hint: const Text('Site', style: TextStyle(fontSize: 14)),
                                  value: _selectedSite,
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('All Sites', style: TextStyle(fontSize: 14)),
                                    ),
                                    ..._availableSites.map((site) => DropdownMenuItem<String>(
                                      value: site,
                                      child: Text(site, style: const TextStyle(fontSize: 14)),
                                    )),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedSite = value;
                                    });
                                    _applyFilters();
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Class filter
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  hint: const Text('Class', style: TextStyle(fontSize: 14)),
                                  value: _selectedClass,
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('All Classes', style: TextStyle(fontSize: 14)),
                                    ),
                                    ..._availableClasses.map((className) => DropdownMenuItem<String>(
                                      value: className,
                                      child: Text(className, style: const TextStyle(fontSize: 14)),
                                    )),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedClass = value;
                                    });
                                    _applyFilters();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Results summary
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                      child: Column(
                        children: [
                          // Status indicators row
                          if (_sortBySurname)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sort_by_alpha, size: 14, color: Colors.green.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'A-Z',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                if (_searchQuery.isNotEmpty || _selectedSite != null || _selectedClass != null)
                                  TextButton.icon(
                                    onPressed: _clearFilters,
                                    icon: const Icon(Icons.clear_all, size: 14),
                                    label: const Text('Clear', style: TextStyle(fontSize: 11)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                              ],
                            ),
                          
                          // Search query and results summary
                          if (_searchQuery.isNotEmpty || (!_isLoading && _learners.isNotEmpty))
                            const SizedBox(height: 4),
                          if (_searchQuery.isNotEmpty || (!_isLoading && _learners.isNotEmpty))
                            Row(
                              children: [
                                if (_searchQuery.isNotEmpty) ...[
                                  Flexible(
                                    child: Text(
                                      'Search: "$_searchQuery"',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (!_isLoading && _learners.isNotEmpty) ...[
                                  Text(
                                    'Showing ${_learners.length} of $_totalRecords',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (_currentPage > 1) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '(Page $_currentPage/$_totalPages)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Divider
            if (_learners.isNotEmpty || _isLoading)
              Divider(height: 1, color: Colors.grey.shade300),

            // Body - learners list (takes remaining space)
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      ),
    );
  }
}