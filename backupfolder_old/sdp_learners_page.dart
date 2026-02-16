import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'DetailsPage.dart';
import 'database_helper.dart';
import 'poe_document_scanner.dart';

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

  List<Map<String, dynamic>> _learners = [];
  List<Map<String, dynamic>> _filteredLearners = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOnlineMode = false;

  // Filter values
  String? _selectedSite;
  String? _selectedClass;
  List<String> _availableSites = [];
  List<String> _availableClasses = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadLearners();
  }

  Future<void> _loadLearners() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if online
      final isOnline = await _checkConnectivity();
      _isOnlineMode = isOnline;

      if (isOnline) {
        // Fetch from API
        await _fetchLearnersFromApi();
      } else {
        // Fetch from local database
        await _fetchLearnersFromDatabase();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to load learners: $e';
        _isLoading = false;
      });
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

  Future<void> _fetchLearnersFromApi() async {
    try {
      // Try to parse as integer for sdp_id, otherwise use sdp_name
      final int? sdpId = int.tryParse(widget.sdpIdentifier);

      final Uri uri;
      if (sdpId != null) {
        uri = Uri.parse(
            'https://rlms.rlms.co.za/mobile/get_sdp_learners.php?sdp_id=$sdpId');
      } else {
        uri = Uri.parse(
            'https://rlms.rlms.co.za/mobile/get_sdp_learners.php?sdp_name=${Uri.encodeComponent(widget.sdpIdentifier)}');
      }

      print('Fetching learners from: $uri');

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      print('API Response status: ${response.statusCode}');
      print('API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['status'] == 'success') {
          final List<dynamic> learnersData = jsonData['data'] ?? [];

          setState(() {
            _learners = learnersData
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            _extractFilterOptions();
            _applyFilters();
            _isLoading = false;
          });

          print('Loaded ${_learners.length} learners from API');
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to load learners');
        }
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching from API: $e');
      // Fallback to local database
      await _fetchLearnersFromDatabase();
    }
  }

  Future<void> _fetchLearnersFromDatabase() async {
    try {
      final data = await _dbHelper.getLearnersBySdp(widget.sdpIdentifier);
      setState(() {
        _learners = data;
        _extractFilterOptions();
        _applyFilters();
        _isLoading = false;
      });
      print('Loaded ${_learners.length} learners from local database');
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to load learners: $e';
        _isLoading = false;
      });
    }
  }

  void _extractFilterOptions() {
    final sites = <String>{};

    for (final learner in _learners) {
      final siteName = learner['siteName']?.toString();

      if (siteName != null && siteName.isNotEmpty && siteName != 'N/A') {
        sites.add(siteName);
      }
    }

    _availableSites = sites.toList()..sort();
    _updateAvailableClasses();
  }

  void _updateAvailableClasses() {
    final classes = <String>{};

    for (final learner in _learners) {
      // If a site is selected, only include classes from that site
      if (_selectedSite != null) {
        if (learner['siteName']?.toString() != _selectedSite) {
          continue;
        }
      }

      final className = learner['className']?.toString();
      if (className != null && className.isNotEmpty && className != 'N/A') {
        classes.add(className);
      }
    }

    _availableClasses = classes.toList()..sort();
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_learners);

    // Filter by site
    if (_selectedSite != null) {
      filtered = filtered.where((learner) {
        return learner['siteName']?.toString() == _selectedSite;
      }).toList();
    }

    // Filter by class
    if (_selectedClass != null) {
      filtered = filtered.where((learner) {
        return learner['className']?.toString() == _selectedClass;
      }).toList();
    }

    // Filter by ID number search
    final searchQuery = _searchController.text.trim().toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((learner) {
        final idNumber = learner['IDNumber']?.toString().toLowerCase() ?? '';
        return idNumber.contains(searchQuery);
      }).toList();
    }

    setState(() {
      _filteredLearners = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedSite = null;
      _selectedClass = null;
      _searchController.clear();
      _updateAvailableClasses(); // Reset available classes to show all
      _applyFilters();
    });
  }

  void _scanLearner(Map<String, dynamic> learner) {
    final learnerIdValue = learner['LearnerID'];
    final learnerId = int.tryParse(learnerIdValue.toString());
    final learnerName = '${learner['Name']} ${learner['Surname']}';

    if (learnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to scan learner.')),
      );
      return;
    }

    // Directly open the same camera scanning functionality as POE
    _openCameraScanPage(learnerId, learnerName);
  }

  Future<void> _openCameraScanPage(int learnerId, String learnerName) async {
    try {
      // Get additional context for the upload
      final learnerData = _filteredLearners.firstWhere(
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
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
              onPressed: _loadLearners,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_learners.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No learners were found for ${widget.sdpDisplayName ?? widget.sdpIdentifier}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLearners,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    if (_filteredLearners.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No learners match the current filters.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearFilters,
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Surname')),
            DataColumn(label: Text('ID Number')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Site')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _filteredLearners.map((learner) {
            final className = learner['className']?.toString() ?? 'N/A';
            final classId = learner['classID']?.toString() ?? '--';
            final siteName = learner['siteName']?.toString() ?? 'N/A';

            return DataRow(
              cells: [
                DataCell(Text(learner['Name']?.toString() ?? 'N/A')),
                DataCell(Text(learner['Surname']?.toString() ?? 'N/A')),
                DataCell(Text(learner['IDNumber']?.toString() ?? '--')),
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        className,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Class ID: $classId',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                DataCell(Text(siteName)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => _openLearnerDetails(learner),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blueAccent,
                          side: const BorderSide(color: Colors.blueAccent),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        child: const Text('Details',
                            style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _scanLearner(learner),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        child:
                            const Text('Scan', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (widget.sdpDisplayName?.isNotEmpty ?? false)
        ? widget.sdpDisplayName!
        : widget.sdpIdentifier;

    return Scaffold(
      appBar: AppBar(
        title: Text('All Learners - $displayName'),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Chip(
                  avatar: Icon(
                    _isOnlineMode ? Icons.cloud_done : Icons.cloud_off,
                    size: 16,
                    color: _isOnlineMode ? Colors.green : Colors.orange,
                  ),
                  label: Text(
                    _isOnlineMode ? 'Online' : 'Offline',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh learners',
            icon: const Icon(Icons.refresh),
            onPressed: _loadLearners,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_learners.isNotEmpty && !_isLoading) ...[
              // Search by ID Number
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search by ID Number',
                  hintText: 'Enter ID number...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => _applyFilters(),
              ),
              const SizedBox(height: 12),

              // Filter dropdowns
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedSite,
                    decoration: const InputDecoration(
                      labelText: 'Site',
                      prefixIcon: Icon(Icons.location_on, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
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
                        // Reset class selection when site changes
                        _selectedClass = null;
                        // Update available classes based on selected site
                        _updateAvailableClasses();
                        _applyFilters();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedClass,
                    decoration: InputDecoration(
                      labelText: _selectedSite != null
                          ? 'Class (${_availableClasses.length})'
                          : 'Class',
                      prefixIcon: const Icon(Icons.class_, size: 20),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
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
                        _applyFilters();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Active filter chips
              if (_selectedSite != null ||
                  _selectedClass != null ||
                  _searchController.text.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (_selectedSite != null)
                      Chip(
                        label: Text('Site: $_selectedSite'),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() {
                            _selectedSite = null;
                            _selectedClass =
                                null; // Reset class when site is cleared
                            _updateAvailableClasses(); // Update available classes
                            _applyFilters();
                          });
                        },
                      ),
                    if (_selectedClass != null)
                      Chip(
                        label: Text('Class: $_selectedClass'),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() {
                            _selectedClass = null;
                            _applyFilters();
                          });
                        },
                      ),
                    if (_searchController.text.isNotEmpty)
                      Chip(
                        label: Text('ID: ${_searchController.text}'),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      ),
                  ],
                ),
              const SizedBox(height: 8),

              // Results count and clear filters
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${_filteredLearners.length} of ${_learners.length} learners',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_selectedSite != null ||
                      _selectedClass != null ||
                      _searchController.text.isNotEmpty)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear All'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}
