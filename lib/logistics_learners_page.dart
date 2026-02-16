import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'config.dart';
import 'poe_submit.dart';
import 'logistics_LearningMaterialFormPage.dart';

class LogisticsLearnersPage extends StatefulWidget {
  final String logisticsId;
  final String logisticsName;
  final String siteId;
  final String siteName;
  final String classId;
  final String className;
  final String facilitatorId;
  final String facilitatorName;
  final String? issuanceType; // 'learner' when used for material issuance

  const LogisticsLearnersPage({
    super.key,
    required this.logisticsId,
    required this.logisticsName,
    required this.siteId,
    required this.siteName,
    required this.classId,
    required this.className,
    required this.facilitatorId,
    required this.facilitatorName,
    this.issuanceType,
  });

  @override
  _LogisticsLearnersPageState createState() => _LogisticsLearnersPageState();
}

class _LogisticsLearnersPageState extends State<LogisticsLearnersPage> {
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
          setState(() {
            learners = data['learners'];
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

  // Navigate to Material Form page (only for Issue to Learners workflow)
  Future<void> _navigateToMaterialForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogisticsLearningMaterialFormPage(
          classID: widget.classId,
          logisticsId: widget.logisticsId,
          logisticsName: widget.logisticsName,
          siteId: widget.siteId,
          siteName: widget.siteName,
          classId: widget.classId,
          className: widget.className,
          facilitatorId: widget.facilitatorId,
          facilitatorName: widget.facilitatorName,
        ),
      ),
    );
    
    // Refresh learners list when returning from material form
    if (result == true) {
      fetchLearners();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.issuanceType == 'learner' 
            ? 'Issue Materials - ${widget.className}' 
            : widget.className),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          // Only show material form button for Issue to Learners workflow
          if (widget.issuanceType == 'learner')
            IconButton(
              icon: const Icon(Icons.assignment),
              tooltip: 'Material Form',
              onPressed: _navigateToMaterialForm,
            ),
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
                    Icon(Icons.group, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Learners in ${widget.className}',
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
                    Expanded(child: Text('Site: ${widget.siteName}')),
                  ],
                ),
                if (widget.facilitatorName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(child: Text('Facilitator: ${widget.facilitatorName}')),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                // Workflow description
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.issuanceType == 'learner' ? Colors.green.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.issuanceType == 'learner' ? Colors.green.shade300 : Colors.blue.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.issuanceType == 'learner' ? Icons.inventory : Icons.assignment,
                        color: widget.issuanceType == 'learner' ? Colors.green.shade700 : Colors.blue.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.issuanceType == 'learner' 
                              ? 'Tap on a learner to issue materials or use the Material Form button above'
                              : 'Tap on a learner to collect their POE',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.issuanceType == 'learner' ? Colors.green.shade700 : Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                ? Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 64, color: Colors.red),
                            SizedBox(height: 16),
                            Text(
                              errorMessage,
                              style: TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: fetchLearners,
                              child: Text('Retry'),
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
                                  padding: EdgeInsets.all(16),
                                  itemCount: learners.length,
                                  itemBuilder: (context, index) {
                                    final learner = learners[index];
                                return Card(
                                  margin: EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.all(16),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.orange,
                                      child: Text(
                                        '${learner['Name']?.toString().substring(0, 1) ?? 'L'}${learner['Surname']?.toString().substring(0, 1) ?? ''}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      learner['FullName'] ?? '${learner['Name'] ?? ''} ${learner['Surname'] ?? ''}'.trim(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.badge, size: 16, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text('ID: ${learner['IDNumber'] ?? 'N/A'}'),
                                          ],
                                        ),
                                        if (learner['Phone'] != null && learner['Phone'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(learner['Phone'].toString()),
                                            ],
                                          ),
                                        ],
                                        if (learner['Email'] != null && learner['Email'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.email, size: 16, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  learner['Email'].toString(),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              size: 12,
                                              color: learner['status'] == 'Active' 
                                                ? Colors.green 
                                                : Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              learner['status'] ?? 'Unknown',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(widget.issuanceType == 'learner' ? Icons.inventory : Icons.assignment),
                                        Text(
                                          widget.issuanceType == 'learner' ? 'Materials' : 'POE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange[600],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: widget.issuanceType == 'learner' 
                                        ? () => _navigateToMaterialForm()
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