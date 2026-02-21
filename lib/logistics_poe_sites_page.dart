import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'config.dart';
import 'logistics_poe_classes_page.dart';

class LogisticsPOESitesPage extends StatefulWidget {
  final String logisticsId;
  final String logisticsName;

  const LogisticsPOESitesPage({
    super.key,
    required this.logisticsId,
    required this.logisticsName,
  });

  @override
  _LogisticsPOESitesPageState createState() => _LogisticsPOESitesPageState();
}

class _LogisticsPOESitesPageState extends State<LogisticsPOESitesPage> {
  List<dynamic> sites = [];
  bool isLoading = true;
  String errorMessage = '';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    fetchSites();
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
      fetchSites(); // Fetch with new search query
    });
  }

  Future<void> fetchSites() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Build URL with search parameter
      String url = 'get_logistics_sites.php?account_id=${widget.logisticsId}';
      if (_searchQuery.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(_searchQuery)}';
      }

      final response = await http.get(Uri.parse(AppConfig.buildUrl(url)));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['sites'] != null) {
          setState(() {
            sites = data['sites'];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = data['error'] ?? 'Failed to load sites';
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
        title: const Text('POE Collection - Select Site'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchSites,
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
                        'Select a site to collect POE from learners',
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
                        'Search sites by name, province, category, or pathway...',
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
                              onPressed: fetchSites,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : sites.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    _searchQuery.isNotEmpty
                                        ? Icons.search_off
                                        : Icons.location_off,
                                    size: 64,
                                    color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No sites match your search'
                                      : 'No sites found',
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
                            onRefresh: fetchSites,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: sites.length,
                              itemBuilder: (context, index) {
                                final site = sites[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 4,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: const CircleAvatar(
                                      backgroundColor: Colors.orange,
                                      child: Icon(
                                        Icons.location_city,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      site['siteName'] ?? 'Unknown Site',
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
                                        if (site['province'] != null) ...[
                                          Row(
                                            children: [
                                              Icon(Icons.map,
                                                  size: 16,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(site['province']),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.class_,
                                                size: 16,
                                                color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                                '${site['total_classes'] ?? '0'} classes'),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.group,
                                                size: 16,
                                                color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                                '${site['total_learners'] ?? '0'} learners'),
                                          ],
                                        ),
                                        if (site['total_facilitators'] !=
                                                null &&
                                            site['total_facilitators'] > 0) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.person,
                                                  size: 16,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                  '${site['total_facilitators']} facilitators'),
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
                                              LogisticsPOEClassesPage(
                                            logisticsId: widget.logisticsId,
                                            logisticsName: widget.logisticsName,
                                            siteId: site['siteID'].toString(),
                                            siteName: site['siteName'] ??
                                                'Unknown Site',
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
