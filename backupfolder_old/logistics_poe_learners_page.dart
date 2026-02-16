import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'config.dart';
import 'poe_submit.dart';

class LogisticsPOELearnersPage extends StatefulWidget {
  final String logisticsId;
  final String logisticsName;
  final String siteId;
  final String siteName;
  final String classId;
  final String className;
  final String facilitatorId;
  final String facilitatorName;

  const LogisticsPOELearnersPage({
    super.key,
    required this.logisticsId,
    required this.logisticsName,
    required this.siteId,
    required this.siteName,
    required this.classId,
    required this.className,
    required this.facilitatorId,
    required this.facilitatorName,
  });

  @override
  _LogisticsPOELearnersPageState createState() => _LogisticsPOELearnersPageState();
}

class _LogisticsPOELearnersPageState extends State<LogisticsPOELearnersPage> {
  List<dynamic> learners = [];
  bool isLoading = true;
  String errorMessage = '';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    fetchLearners();
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
      fetchLearners(); // Fetch with new search query
    });
  }

  Future<void> fetchLearners() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Build URL with search parameter
      String url = 'get_logistics_learners.php?classID=${widget.classId}&account_id=${widget.logisticsId}';
      if (_searchQuery.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(_searchQuery)}';
      }
      
      final response = await http.get(Uri.parse(AppConfig.buildUrl(url)));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['learners'] != null) {
          // Check POE status for each learner
          List<dynamic> learnersWithStatus = [];
          for (var learner in data['learners']) {
            // Check if this learner has already submitted POE
            final poeStatus = await checkPOEStatus(learner['IDNumber']);
            learner['POEStatus'] = poeStatus;
            learnersWithStatus.add(learner);
          }
          
          setState(() {
            learners = learnersWithStatus;
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = data['error'] ?? 'Failed to load learners';
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

  // Check if learner has already submitted POE
  Future<String> checkPOEStatus(String? idNumber) async {
    if (idNumber == null || idNumber.isEmpty) {
      return 'Not Submitted';
    }

    try {
      final response = await http.get(
        Uri.parse(AppConfig.buildUrl('get_poe_collection_status.php?classID=${widget.classId}')),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['learners'] != null) {
          // Find this specific learner in the response
          for (var learner in data['learners']) {
            if (learner['IDNumber'] == idNumber) {
              return learner['POEStatus'] ?? 'Not Submitted';
            }
          }
        }
      }
    } catch (e) {
      print('Error checking POE status for $idNumber: $e');
    }

    return 'Not Submitted';
  }

  // Navigate to POE Submit page
  Future<void> _collectPOE(Map<String, dynamic> learner) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => POESubmitPage(
          learner: learner,
          classId: widget.classId,
          className: widget.className,
          facilitatorName: widget.facilitatorName,
          logisticsId: widget.logisticsId,
          logisticsName: widget.logisticsName,
        ),
      ),
    );
    
    // If POE was successfully submitted, refresh the learners list
    if (result == true) {
      fetchLearners();
    }
  }

  // Get display text for POE status
  String _getPOEStatusText(String? status) {
    switch (status) {
      case 'Ready for Collection':
        return 'Already Submitted';
      case 'Collected':
        return 'POE Collected';
      case 'Not Submitted':
      default:
        return 'Ready for POE Collection';
    }
  }

  // Build action button based on POE status
  Widget _buildPOEActionButton(Map<String, dynamic> learner) {
    final status = learner['POEStatus'];
    
    switch (status) {
      case 'Ready for Collection':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              const Text(
                'Submitted',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
        
      case 'Collected':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.done_all, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              const Text(
                'Collected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
        
      case 'Not Submitted':
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.assignment, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              const Text(
                'Collect POE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('POE Collection - ${widget.className}'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchLearners,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'POE Collection for ${widget.className}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('Site: ${widget.siteName}'),
                  ],
                ),
                if (widget.facilitatorName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('Facilitator: ${widget.facilitatorName}'),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, surname, ID number, phone, email...',
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
                      borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
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
                            const Icon(Icons.error, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              errorMessage,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: fetchLearners,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : learners.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _searchQuery.isNotEmpty ? Icons.search_off : Icons.group_outlined, 
                                  size: 64, 
                                  color: Colors.grey[400]
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty 
                                    ? 'No learners match your search'
                                    : 'No learners found in this class',
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
                            onRefresh: fetchLearners,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: learners.length,
                              itemBuilder: (context, index) {
                                final learner = learners[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 4,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.orange,
                                      child: Text(
                                        (learner['Name']?.substring(0, 1) ?? 'L').toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      learner['FullName'] ?? '${learner['Name']} ${learner['Surname']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        if (learner['IDNumber'] != null) ...[
                                          Row(
                                            children: [
                                              Icon(Icons.badge, size: 16, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text('ID: ${learner['IDNumber']}'),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(
                                              learner['POEStatus'] == 'Ready for Collection' || learner['POEStatus'] == 'Collected'
                                                  ? Icons.check_circle
                                                  : Icons.assignment,
                                              size: 16,
                                              color: learner['POEStatus'] == 'Ready for Collection' || learner['POEStatus'] == 'Collected'
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _getPOEStatusText(learner['POEStatus']),
                                              style: TextStyle(
                                                color: learner['POEStatus'] == 'Ready for Collection' || learner['POEStatus'] == 'Collected'
                                                    ? Colors.green.shade700
                                                    : Colors.orange.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: _buildPOEActionButton(learner),
                                    onTap: learner['POEStatus'] == 'Ready for Collection' || learner['POEStatus'] == 'Collected'
                                        ? null // Disable tap for already submitted POEs
                                        : () => _collectPOE(learner),
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