import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'config.dart';
import 'logistics_poe_learners_page.dart';

class LogisticsPOEClassesPage extends StatefulWidget {
  final String logisticsId;
  final String logisticsName;
  final String siteId;
  final String siteName;

  const LogisticsPOEClassesPage({
    super.key,
    required this.logisticsId,
    required this.logisticsName,
    required this.siteId,
    required this.siteName,
  });

  @override
  _LogisticsPOEClassesPageState createState() =>
      _LogisticsPOEClassesPageState();
}

class _LogisticsPOEClassesPageState extends State<LogisticsPOEClassesPage> {
  List<dynamic> classes = [];
  bool isLoading = true;
  String errorMessage = '';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    fetchClasses();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Start new timer for debounced search
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = _searchController.text;
      });
      fetchClasses(); // Fetch with new search query
    });
  }

  Future<void> fetchClasses() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Build URL with search parameter
      String url =
          'get_logistics_classes.php?siteID=${widget.siteId}&account_id=${widget.logisticsId}';
      if (_searchQuery.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(_searchQuery)}';
      }

      final response = await http.get(Uri.parse(AppConfig.buildUrl(url)));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['classes'] != null) {
          setState(() {
            classes = data['classes'];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = data['error'] ?? 'Failed to load classes';
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
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('POE Collection - ${widget.siteName}'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchClasses,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select a class to collect POE from learners',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Search classes by name, facilitator, or learner count...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.orange.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.orange.shade600, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              errorMessage,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: fetchClasses,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : classes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    _searchQuery.isNotEmpty
                                        ? Icons.search_off
                                        : Icons.class_outlined,
                                    size: 64,
                                    color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No classes match your search'
                                      : 'No classes found at this site',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try different keywords',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: fetchClasses,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: classes.length,
                              itemBuilder: (context, index) {
                                final classData = classes[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 4,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: const CircleAvatar(
                                      backgroundColor: Colors.orange,
                                      child: Icon(
                                        Icons.class_,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      classData['className'] ?? 'Unknown Class',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.group,
                                                size: 16,
                                                color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                                '${classData['total_learners'] ?? '0'} learners'),
                                          ],
                                        ),
                                        if (classData['facilitator_name'] !=
                                                null &&
                                            classData['facilitator_name'] !=
                                                'No Facilitator Assigned') ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.person,
                                                  size: 16,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  classData['facilitator_name'],
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.person_off,
                                                  size: 16,
                                                  color: Colors.red[400]),
                                              const SizedBox(width: 4),
                                              Text(
                                                'No Facilitator Assigned',
                                                style: TextStyle(
                                                  color: Colors.red[400],
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.assignment,
                                            color: Colors.orange),
                                        SizedBox(width: 4),
                                        Icon(Icons.arrow_forward_ios),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              LogisticsPOELearnersPage(
                                            logisticsId: widget.logisticsId,
                                            logisticsName: widget.logisticsName,
                                            siteId: widget.siteId,
                                            siteName: widget.siteName,
                                            classId:
                                                classData['classID'].toString(),
                                            className: classData['className'] ??
                                                'Unknown Class',
                                            facilitatorId:
                                                classData['facilitator_id']
                                                        ?.toString() ??
                                                    '',
                                            facilitatorName:
                                                classData['facilitator_name'] ??
                                                    '',
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
