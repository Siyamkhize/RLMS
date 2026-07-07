import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'config.dart';
import 'facilitator_issue_form_page.dart';

class FacilitatorIssueClassesPage extends StatefulWidget {
  final String logisticsId;
  final String logisticsName;
  final String siteId;
  final String siteName;

  const FacilitatorIssueClassesPage({
    super.key,
    required this.logisticsId,
    required this.logisticsName,
    required this.siteId,
    required this.siteName,
  });

  @override
  _FacilitatorIssueClassesPageState createState() =>
      _FacilitatorIssueClassesPageState();
}

class _FacilitatorIssueClassesPageState
    extends State<FacilitatorIssueClassesPage> {
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
        title: Text('${widget.siteName} - Classes'),
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
                    Icon(Icons.class_, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select Class - Issue to Facilitator',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a class to issue materials to its facilitator',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search classes by name or facilitator...',
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
                                Icon(Icons.class_outlined,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No classes found at this site',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
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
                                final hasFacilitator =
                                    classData['facilitator_name'] != null &&
                                        classData['facilitator_name'] !=
                                            'No Facilitator Assigned';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 4,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: CircleAvatar(
                                      backgroundColor: hasFacilitator
                                          ? Colors.orange
                                          : Colors.grey,
                                      child: Icon(
                                        hasFacilitator
                                            ? Icons.person
                                            : Icons.person_off,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      classData['className'] ?? 'Unknown Class',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
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
                                              '${classData['total_learners'] ?? '0'} learners',
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                                hasFacilitator
                                                    ? Icons.person
                                                    : Icons.person_off,
                                                size: 16,
                                                color: hasFacilitator
                                                    ? Colors.green[600]
                                                    : Colors.red[400]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                hasFacilitator
                                                    ? 'Facilitator: ${classData['facilitator_name']}'
                                                    : 'No Facilitator Assigned',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: hasFacilitator
                                                      ? Colors.green[600]
                                                      : Colors.red[400],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (!hasFacilitator) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                  color: Colors.red.shade200),
                                            ),
                                            child: Text(
                                              'Cannot issue materials - No facilitator assigned',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red.shade700,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: hasFacilitator
                                        ? const Icon(Icons.arrow_forward_ios)
                                        : Icon(Icons.block,
                                            color: Colors.red[400]),
                                    onTap: hasFacilitator
                                        ? () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    FacilitatorIssueFormPage(
                                                  classID: classData['classID']
                                                      .toString(),
                                                ),
                                              ),
                                            );
                                          }
                                        : () {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Cannot issue materials - No facilitator assigned to this class'),
                                                backgroundColor: Colors.red,
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
