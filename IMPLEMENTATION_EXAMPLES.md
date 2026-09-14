# Query Queue & Lazy Loading - Implementation Examples

## 📚 Table of Contents
1. [Simple Learner List with Pagination](#1-simple-learner-list-with-pagination)
2. [Search with Debouncing](#2-search-with-debouncing)
3. [SDP Learners with Filtering](#3-sdp-learners-with-filtering)
4. [ARPL Toolkit Data Loading](#4-arpl-toolkit-data-loading)
5. [Offline Support](#5-offline-support)

---

## 1. Simple Learner List with Pagination

### Full Working Example

```dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rlmss/utils/lazy_loading_controller.dart';
import 'package:rlmss/widgets/paginated_list_widget.dart';
import 'package:rlmss/services/query_queue_service.dart';
import 'config.dart';

class SimpleLearnerListPage extends StatefulWidget {
  final String classID;

  const SimpleLearnerListPage({Key? key, required this.classID}) : super(key: key);

  @override
  State<SimpleLearnerListPage> createState() => _SimpleLearnerListPageState();
}

class _SimpleLearnerListPageState extends State<SimpleLearnerListPage> {
  late LazyLoadingController<Learner> _controller;

  @override
  void initState() {
    super.initState();
    
    _controller = LazyLoadingController<Learner>(
      fetchPage: _fetchLearnersPage,
      pageSize: 30,
      useQueryQueue: true,
      queuePriority: Priority.normal,
    );
  }

  /// Fetch learners for a specific page
  Future<List<Learner>> _fetchLearnersPage(int page, int pageSize) async {
    final url = AppConfig.buildUrl('get_learners.php', queryParams: {
      'classID': widget.classID,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    });

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer ${await _getAuthToken()}'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      
      // Handle new paginated response format
      final data = json['data'] ?? json; // Backward compatible
      
      return (data as List)
          .map((item) => Learner.fromJson(item))
          .toList();
    } else {
      throw Exception('Failed to load learners: ${response.statusCode}');
    }
  }

  Future<String> _getAuthToken() async {
    // Get token from secure storage
    return 'your_token_here';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learners'),
        actions: [
          // Show queue status (optional debugging)
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              final status = QueryQueueService.instance.status;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Queue: ${status.queueSize} | Active: ${status.activeRequests} | Cached: ${status.cachedResults}',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: PaginatedListWidget<Learner>(
        controller: _controller,
        itemBuilder: (context, learner) => ListTile(
          leading: CircleAvatar(
            child: Text(learner.name?.substring(0, 1) ?? '?'),
          ),
          title: Text('${learner.name} ${learner.surname}'),
          subtitle: Text(learner.idNumber ?? 'No ID'),
          trailing: Icon(
            learner.synced == 1 ? Icons.cloud_done : Icons.cloud_off,
            color: learner.synced == 1 ? Colors.green : Colors.grey,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LearnerDetailsPage(learner: learner),
              ),
            );
          },
        ),
        emptyBuilder: (context) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No learners found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Learner model (simplified)
class Learner {
  final String? learnerID;
  final String? name;
  final String? surname;
  final String? idNumber;
  final int? synced;

  Learner({this.learnerID, this.name, this.surname, this.idNumber, this.synced});

  factory Learner.fromJson(Map<String, dynamic> json) => Learner(
    learnerID: json['LearnerID']?.toString(),
    name: json['Name']?.toString(),
    surname: json['Surname']?.toString(),
    idNumber: json['IDNumber']?.toString(),
    synced: int.tryParse(json['synced']?.toString() ?? '0') ?? 0,
  );
}
```

---

## 2. Search with Debouncing

### Searchable Learner List

```dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rlmss/widgets/paginated_list_widget.dart';
import 'config.dart';

class SearchableLearnerPage extends StatelessWidget {
  const SearchableLearnerPage({Key? key}) : super(key: key);

  Future<List<Learner>> _searchLearners(String query, int page, int pageSize) async {
    if (query.isEmpty) {
      return [];
    }

    final url = AppConfig.buildUrl('search_learner_autocomplete_global.php', queryParams: {
      'q': query,
      'page': page.toString(),
      'limit': pageSize.toString(),
    });

    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 5),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final suggestions = json['suggestions'] ?? json['data'] ?? [];
      
      return (suggestions as List)
          .map((item) => Learner.fromJson(item))
          .toList();
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Learners'),
      ),
      body: SearchablePaginatedList<Learner>(
        searchFetch: _searchLearners,
        itemBuilder: (context, learner) => ListTile(
          leading: CircleAvatar(
            child: Text(learner.name?.substring(0, 1) ?? '?'),
          ),
          title: Text('${learner.name} ${learner.surname}'),
          subtitle: Text(learner.idNumber ?? 'No ID'),
          onTap: () {
            // Navigate to details
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LearnerDetailsPage(learner: learner),
              ),
            );
          },
        ),
        hintText: 'Search by name or ID number...',
        pageSize: 20,
        debounceDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}
```

---

## 3. SDP Learners with Filtering

### Advanced Example with Filters

```dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rlmss/utils/lazy_loading_controller.dart';
import 'package:rlmss/widgets/paginated_list_widget.dart';
import 'config.dart';

class SdpLearnersListPage extends StatefulWidget {
  final String sdpId;

  const SdpLearnersListPage({Key? key, required this.sdpId}) : super(key: key);

  @override
  State<SdpLearnersListPage> createState() => _SdpLearnersListPageState();
}

class _SdpLearnersListPageState extends State<SdpLearnersListPage> {
  late LazyLoadingController<Learner> _controller;
  String? _selectedSite;
  String? _selectedClass;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    _controller = LazyLoadingController<Learner>(
      fetchPage: _fetchSdpLearners,
      pageSize: 30,
      useQueryQueue: true,
      queuePriority: Priority.normal,
    );
  }

  Future<List<Learner>> _fetchSdpLearners(int page, int pageSize) async {
    final queryParams = {
      'sdp_id': widget.sdpId,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    // Add filters if selected
    if (_selectedSite != null) queryParams['siteID'] = _selectedSite!;
    if (_selectedClass != null) queryParams['classID'] = _selectedClass!;

    final url = AppConfig.buildUrl('get_sdp_learners.php', queryParams: queryParams);

    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 10),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final data = json['data'] ?? [];
      
      return (data as List)
          .map((item) => Learner.fromJson(item))
          .toList();
    }

    throw Exception('Failed to load SDP learners');
  }

  void _applyFilters() {
    setState(() {
      _controller.dispose();
      _initializeController();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SDP Learners'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedSite != null || _selectedClass != null)
            _buildActiveFiltersChips(),
          Expanded(
            child: PaginatedListWidget<Learner>(
              controller: _controller,
              itemBuilder: (context, learner) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text('${learner.name} ${learner.surname}'),
                  subtitle: Text('${learner.className ?? "No Class"} • ${learner.siteName ?? "No Site"}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to details
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        children: [
          if (_selectedSite != null)
            Chip(
              label: Text('Site: $_selectedSite'),
              onDeleted: () {
                setState(() {
                  _selectedSite = null;
                  _applyFilters();
                });
              },
            ),
          if (_selectedClass != null)
            Chip(
              label: Text('Class: $_selectedClass'),
              onDeleted: () {
                setState(() {
                  _selectedClass = null;
                  _applyFilters();
                });
              },
            ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    // Show dialog with filter options
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filters'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Site dropdown
            // Class dropdown
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyFilters();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

// Extended Learner model with site/class info
class Learner {
  final String? learnerID;
  final String? name;
  final String? surname;
  final String? idNumber;
  final String? className;
  final String? siteName;

  Learner({
    this.learnerID,
    this.name,
    this.surname,
    this.idNumber,
    this.className,
    this.siteName,
  });

  factory Learner.fromJson(Map<String, dynamic> json) => Learner(
    learnerID: json['LearnerID']?.toString(),
    name: json['Name']?.toString(),
    surname: json['Surname']?.toString(),
    idNumber: json['IDNumber']?.toString(),
    className: json['className']?.toString(),
    siteName: json['siteName']?.toString(),
  );
}
```

---

## 4. ARPL Toolkit Data Loading

### Loading Trade-Specific Data

```dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rlmss/services/query_queue_service.dart';
import 'config.dart';

class ArplToolkitPage extends StatefulWidget {
  final String learnerId;
  final String trade;

  const ArplToolkitPage({
    Key? key,
    required this.learnerId,
    required this.trade,
  }) : super(key: key);

  @override
  State<ArplToolkitPage> createState() => _ArplToolkitPageState();
}

class _ArplToolkitPageState extends State<ArplToolkitPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _toolkitData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadToolkitData();
  }

  Future<void> _loadToolkitData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use query queue for controlled loading
      final data = await QueryQueueService.instance.enqueue(
        () => _fetchToolkitData(),
        priority: Priority.high, // User-facing data
        cacheKey: 'arpl_toolkit_${widget.learnerId}_${widget.trade}',
        cacheFor: const Duration(minutes: 10),
        deduplicateBy: true,
      );

      setState(() {
        _toolkitData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchToolkitData() async {
    final url = AppConfig.buildUrl('get_arpl_toolkit_data.php', queryParams: {
      'learner_id': widget.learnerId,
      'trade': widget.trade,
    });

    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 15),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to load toolkit data');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              ElevatedButton(
                onPressed: _loadToolkitData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.trade} Toolkit'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Display toolkit data
            if (_toolkitData != null) ...[
              _buildToolkitSection('Appendix B', _toolkitData!['appendix_b']),
              _buildToolkitSection('Appendix E', _toolkitData!['appendix_e']),
              _buildToolkitSection('Appendix F', _toolkitData!['appendix_f']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToolkitSection(String title, dynamic data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(title),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(data?.toString() ?? 'No data'),
          ),
        ],
      ),
    );
  }
}
```

---

## 5. Offline Support

### Hybrid Online/Offline with Query Queue

```dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rlmss/utils/lazy_loading_controller.dart';
import 'package:rlmss/widgets/paginated_list_widget.dart';
import 'package:rlmss/services/query_queue_service.dart';
import 'database_helper.dart';
import 'config.dart';

class HybridLearnerListPage extends StatefulWidget {
  final String classID;

  const HybridLearnerListPage({Key? key, required this.classID}) : super(key: key);

  @override
  State<HybridLearnerListPage> createState() => _HybridLearnerListPageState();
}

class _HybridLearnerListPageState extends State<HybridLearnerListPage> {
  late LazyLoadingController<Learner> _controller;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _initializeController();
  }

  void _initializeController() {
    _controller = LazyLoadingController<Learner>(
      fetchPage: _isOnline ? _fetchOnline : _fetchOffline,
      pageSize: 30,
      useQueryQueue: _isOnline, // Only use queue for online
      queuePriority: Priority.normal,
    );
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await http.get(Uri.parse(AppConfig.baseUrl)).timeout(
        const Duration(seconds: 3),
      );
      setState(() {
        _isOnline = result.statusCode == 200;
      });
    } catch (e) {
      setState(() {
        _isOnline = false;
      });
    }
  }

  Future<List<Learner>> _fetchOnline(int page, int pageSize) async {
    final url = AppConfig.buildUrl('get_learners.php', queryParams: {
      'classID': widget.classID,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    });

    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 10),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final data = json['data'] ?? json;
      
      return (data as List)
          .map((item) => Learner.fromJson(item))
          .toList();
    }

    throw Exception('Failed to load learners');
  }

  Future<List<Learner>> _fetchOffline(int page, int pageSize) async {
    final db = await _dbHelper.database;
    final offset = (page - 1) * pageSize;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'learnerdetails',
      where: 'classID = ?',
      whereArgs: [widget.classID],
      limit: pageSize,
      offset: offset,
      orderBy: 'Surname ASC, Name ASC',
    );

    return maps.map((map) => Learner.fromJson(map)).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learners'),
        actions: [
          // Online/Offline indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Chip(
              avatar: Icon(
                _isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: Colors.white,
                size: 16,
              ),
              label: Text(
                _isOnline ? 'Online' : 'Offline',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: _isOnline ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
      body: PaginatedListWidget<Learner>(
        controller: _controller,
        itemBuilder: (context, learner) => ListTile(
          leading: CircleAvatar(
            child: Text(learner.name?.substring(0, 1) ?? '?'),
          ),
          title: Text('${learner.name} ${learner.surname}'),
          subtitle: Text(learner.idNumber ?? 'No ID'),
          trailing: Icon(
            learner.synced == 1 ? Icons.cloud_done : Icons.cloud_off,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _checkConnectivity();
          setState(() {
            _controller.dispose();
            _initializeController();
          });
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
```

---

## 🎯 Quick Migration Checklist

### To Convert ANY Existing List Page:

1. **Add imports:**
```dart
import 'package:rlmss/utils/lazy_loading_controller.dart';
import 'package:rlmss/widgets/paginated_list_widget.dart';
import 'package:rlmss/services/query_queue_service.dart';
```

2. **Create controller in initState:**
```dart
_controller = LazyLoadingController<YourModel>(
  fetchPage: _yourFetchFunction,
  pageSize: 30,
  useQueryQueue: true,
);
```

3. **Replace ListView with PaginatedListWidget:**
```dart
PaginatedListWidget<YourModel>(
  controller: _controller,
  itemBuilder: (context, item) => YourListTile(item),
);
```

4. **Dispose controller:**
```dart
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

5. **Done!** ✅

---

**Last Updated**: 2026-09-14
