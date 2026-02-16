import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'finance_learner_list.dart';
import 'finance_register_history.dart';

class FinanceDashboard extends StatefulWidget {
  final String financeId;
  final String financeName;

  const FinanceDashboard({
    Key? key,
    required this.financeId,
    required this.financeName,
  }) : super(key: key);

  @override
  _FinanceDashboardState createState() => _FinanceDashboardState();
}

class _FinanceDashboardState extends State<FinanceDashboard> {
  List<dynamic> classes = [];
  Map<String, List<dynamic>> classesBySite = {};
  List<dynamic> searchResults = [];
  bool isLoading = true;
  bool isSearching = false;
  String errorMessage = '';
  TextEditingController searchController = TextEditingController();
  bool showSearchResults = false;

  @override
  void initState() {
    super.initState();
    fetchClasses();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchClasses() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      showSearchResults = false;
      searchController.clear();
    });

    try {
      final url = AppConfig.buildUrl('get_finance_classes.php');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is List) {
          // Group classes by site
          Map<String, List<dynamic>> grouped = {};
          for (var classData in data) {
            String siteName = classData['site_name'] ?? 'No Site';
            if (!grouped.containsKey(siteName)) {
              grouped[siteName] = [];
            }
            grouped[siteName]!.add(classData);
          }
          
          setState(() {
            classes = data;
            classesBySite = grouped;
            isLoading = false;
          });
        } else if (data['error'] != null) {
          setState(() {
            errorMessage = data['error'];
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

  Future<void> searchLearnerByID(String idNumber) async {
    if (idNumber.trim().isEmpty) {
      setState(() {
        showSearchResults = false;
        searchResults = [];
      });
      return;
    }

    setState(() {
      isSearching = true;
    });

    try {
      final url = AppConfig.buildUrl('search_learner_by_id.php?id_number=${Uri.encodeComponent(idNumber)}');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        setState(() {
          isSearching = false;
          if (data['success'] == true && data['learners'] != null) {
            searchResults = data['learners'];
            showSearchResults = true;
          } else {
            searchResults = [];
            showSearchResults = true;
          }
        });
      } else {
        setState(() {
          isSearching = false;
          searchResults = [];
          showSearchResults = true;
        });
      }
    } catch (e) {
      setState(() {
        isSearching = false;
        searchResults = [];
        showSearchResults = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Finance - ${widget.financeName}'),
        backgroundColor: Colors.green[700],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search by ID Number',
                prefixIcon: Icon(Icons.search, color: Colors.green[700]),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            showSearchResults = false;
                            searchResults = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.green[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {});
                if (value.length >= 3) {
                  searchLearnerByID(value);
                } else if (value.isEmpty) {
                  setState(() {
                    showSearchResults = false;
                    searchResults = [];
                  });
                }
              },
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
                            Icon(Icons.error_outline, size: 60, color: Colors.red),
                            SizedBox(height: 16),
                            Text(errorMessage, style: TextStyle(color: Colors.red)),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: fetchClasses,
                              child: Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : showSearchResults
                        ? _buildSearchResults()
                        : classesBySite.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.class_, size: 60, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text('No classes found'),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: fetchClasses,
                                child: ListView.builder(
                                  padding: EdgeInsets.all(16),
                                  itemCount: classesBySite.keys.length,
                                  itemBuilder: (context, index) {
                                    final siteName = classesBySite.keys.elementAt(index);
                                    final siteClasses = classesBySite[siteName]!;
                                    return _buildSiteSection(siteName, siteClasses);
                                  },
                                ),
                              ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (isSearching) {
      return Center(child: CircularProgressIndicator());
    }

    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No learner found with ID: ${searchController.text}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  showSearchResults = false;
                  searchController.clear();
                });
              },
              child: Text('Back to Classes'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          color: Colors.green[50],
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.green[700]),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Found ${searchResults.length} learner(s)',
                  style: TextStyle(color: Colors.green[900], fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    showSearchResults = false;
                    searchController.clear();
                  });
                },
                child: Text('Back to Classes'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              final learner = searchResults[index];
              return _buildLearnerSearchCard(learner);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLearnerSearchCard(Map<String, dynamic> learner) {
    final learnerName = '${learner['name'] ?? ''} ${learner['surname'] ?? ''}'.trim();
    final learnerId = learner['learner_id']?.toString() ?? '';
    final idNumber = learner['id_number']?.toString() ?? 'N/A';
    final className = learner['class_name']?.toString() ?? 'Unknown Class';
    final classId = learner['class_id']?.toString() ?? '';
    final registerCount = learner['register_count']?.toString() ?? '0';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FinanceRegisterHistory(
                learnerId: learnerId,
                learnerName: learnerName,
                classId: classId,
                className: className,
                financeId: widget.financeId,
              ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Text(
                      learnerName.isNotEmpty ? learnerName[0].toUpperCase() : 'L',
                      style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          learnerName.isNotEmpty ? learnerName : 'Unknown Learner',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ID: $idNumber',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 18),
                ],
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.class_, size: 18, color: Colors.blue[700]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        className,
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$registerCount Registers',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSiteSection(String siteName, List<dynamic> siteClasses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          margin: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.green[700],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  siteName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${siteClasses.length} ${siteClasses.length == 1 ? 'class' : 'classes'}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...siteClasses.map((classData) => _buildClassCard(classData)).toList(),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classData) {
    final className = classData['class_name'] ?? 'Unknown Class';
    final classId = classData['class_id']?.toString() ?? '';
    final learnerCount = classData['learner_count']?.toString() ?? '0';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FinanceLearnerList(
                classId: classId,
                className: className,
                financeId: widget.financeId,
                financeName: widget.financeName,
              ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.class_, color: Colors.green[700], size: 30),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      className,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$learnerCount learners',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
