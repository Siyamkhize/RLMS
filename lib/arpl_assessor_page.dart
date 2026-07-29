import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class ARPLAssessorPage extends StatefulWidget {
  final String learnerID;

  const ARPLAssessorPage({super.key, required this.learnerID});

  @override
  State<ARPLAssessorPage> createState() => _ARPLAssessorPageState();
}

class _ARPLAssessorPageState extends State<ARPLAssessorPage> {
  String _currentSection = 'pathway';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ARPL Assessor'),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder(
        future: _fetchHierarchyData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return _buildHierarchyUI();
          }
        },
      ),
    );
  }

  Future<void> _fetchHierarchyData() async {
    // This will be implemented later to fetch data from server
  }

  Widget _buildHierarchyUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBreadcrumb(),
          const SizedBox(height: 20),
          _buildPathwaySection(),
          const SizedBox(height: 16),
          _buildTradeSection(),
          const SizedBox(height: 16),
          _buildPaperSection(),
          const SizedBox(height: 16),
          _buildQuestionsSection(),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.deepPurple[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _breadcrumbItem('Pathway', _currentSection == 'pathway'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ),
          _breadcrumbItem('Trade', _currentSection == 'trade'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ),
          _breadcrumbItem('Paper', _currentSection == 'paper'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ),
          _breadcrumbItem('Questions', _currentSection == 'questions'),
        ],
      ),
    );
  }

  Widget _breadcrumbItem(String text, bool isActive) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.deepPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[700],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPathwaySection() {
    return _buildHierarchyCard(
      title: '🎓 Learning Pathway',
      subtitle: 'Accelerated Rapid Pathways Learning - Project ID: 97',
      badge: 'ARPL',
      isActive: _currentSection == 'pathway',
      onTap: () {
        setState(() {
          _currentSection = 'pathway';
        });
      },
      expandedContent: _currentSection == 'pathway'
          ? _buildPathwayContent()
          : null,
    );
  }

  Widget _buildPathwayContent() {
    return Column(
      children: [
        const SizedBox(height: 16),
        _buildInfoGrid([
          {'label': 'Pathway Name', 'value': 'ARPL'},
          {'label': 'Full Name', 'value': 'Accelerated Rapid Pathways Learning'},
          {'label': 'Project ID', 'value': '97'},
          {'label': 'Structure Type', 'value': 'Trade-Based'},
        ]),
        const SizedBox(height: 16),
        const Text(
          'ARPL is a specialized framework designed for rapid skills development. Instead of traditional qualification-based pathways, ARPL organizes training around specific trades, allowing for faster implementation and competency-based progression.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTradeSection() {
    return _buildHierarchyCard(
      title: '⚡ Trade',
      subtitle: 'Electrician - OFO Code: 671101',
      badge: 'ELECTRICIAN',
      isActive: _currentSection == 'trade',
      onTap: () {
        setState(() {
          _currentSection = 'trade';
        });
      },
      expandedContent: _currentSection == 'trade' ? _buildTradeContent() : null,
    );
  }

  Widget _buildTradeContent() {
    return Column(
      children: [
        const SizedBox(height: 16),
        _buildInfoGrid([
          {'label': 'Trade Name', 'value': 'Electrician'},
          {'label': 'Trade ID', 'value': '1'},
          {'label': 'OFO Code', 'value': '671101'},
          {'label': 'Framework', 'value': 'NLQF Level 3'},
        ]),
        const SizedBox(height: 16),
        const Text(
          'The Electrician trade encompasses skills required for electrical installation, maintenance, and repair work. Covers theoretical knowledge, practical competencies, safety procedures, and industry-standard regulations.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildPaperSection() {
    return _buildHierarchyCard(
      title: '📄 Assessment Paper',
      subtitle: 'Electrical Theory Paper 1 - Paper ID: 11',
      badge: 'PAPER 11',
      isActive: _currentSection == 'paper',
      onTap: () {
        setState(() {
          _currentSection = 'paper';
        });
      },
      expandedContent: _currentSection == 'paper' ? _buildPaperContent() : null,
    );
  }

  Widget _buildPaperContent() {
    return Column(
      children: [
        const SizedBox(height: 16),
        _buildInfoGrid([
          {'label': 'Paper Title', 'value': 'Electrical Theory Paper 1'},
          {'label': 'Paper ID', 'value': '11'},
          {'label': 'Paper Type', 'value': 'Theory'},
          {'label': 'Duration', 'value': '120 Minutes'},
          {'label': 'Total Marks', 'value': '100'},
          {'label': 'Pass Score', 'value': '60 (60%)'},
        ]),
        const SizedBox(height: 16),
        _buildStats([
          {'label': 'Questions', 'value': '21'},
          {'label': 'Total Marks', 'value': '100'},
          {'label': 'Easy', 'value': '13'},
          {'label': 'Medium', 'value': '8'},
        ]),
      ],
    );
  }

  Widget _buildQuestionsSection() {
    return _buildHierarchyCard(
      title: '❓ Questions & Learner Data',
      subtitle: '21 Questions × 3 Learners = 63 Data Rows',
      badge: '63 ROWS',
      isActive: _currentSection == 'questions',
      onTap: () {
        setState(() {
          _currentSection = 'questions';
        });
      },
      expandedContent:
          _currentSection == 'questions' ? _buildQuestionsContent() : null,
    );
  }

  Widget _buildQuestionsContent() {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          'Combined view: All learner-question relationships from Class 782 with Paper 11 questions',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _buildStats([
          {'label': 'Total Rows', 'value': '63'},
          {'label': 'Learners', 'value': '3'},
          {'label': 'Questions', 'value': '21'},
        ]),
        const SizedBox(height: 16),
        // Placeholder for questions table
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Questions table will be implemented here with data from server',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildHierarchyCard({
    required String title,
    required String subtitle,
    required String badge,
    required bool isActive,
    required VoidCallback onTap,
    Widget? expandedContent,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: isActive ? Colors.deepPurple : Colors.grey,
                      width: 5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expandedContent != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: expandedContent,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(List<Map<String, String>> items) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: Colors.deepPurple, width: 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['value']!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildStats(List<Map<String, String>> items) {
    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: EdgeInsets.only(
                  right: item == items.last ? 0 : 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      item['value']!,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
