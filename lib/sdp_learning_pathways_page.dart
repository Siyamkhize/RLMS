import 'dart:convert';
import 'package:flutter/material.dart';
import 'admin.dart';

class SdpLearningPathwaysPage extends StatefulWidget {
  final String sdpIdentifier;
  final String projectId;
  final String projectName;
  final String projectPathwayJson;

  const SdpLearningPathwaysPage({
    super.key,
    required this.sdpIdentifier,
    required this.projectId,
    required this.projectName,
    required this.projectPathwayJson,
  });

  @override
  State<SdpLearningPathwaysPage> createState() =>
      _SdpLearningPathwaysPageState();
}

class _SdpLearningPathwaysPageState extends State<SdpLearningPathwaysPage> {
  List<Map<String, dynamic>> _pathways = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _parsePathways();
  }

  void _parsePathways() {
    setState(() => _isLoading = true);

    try {
      if (widget.projectPathwayJson.isEmpty ||
          widget.projectPathwayJson == '[]') {
        setState(() {
          _pathways = [];
          _isLoading = false;
        });
        return;
      }

      final List<dynamic> pathwayList = jsonDecode(widget.projectPathwayJson);

      final List<Map<String, dynamic>> parsedPathways = [];

      for (var pathway in pathwayList) {
        if (pathway is Map) {
          final pathwayId = pathway['id']?.toString() ?? '';
          final pathwayName = pathway['name']?.toString() ?? 'Unknown Pathway';
          final isInternship = pathway['isInternship'] ?? false;

          // Extract qualifications
          final qualTypes = pathway['qual_types'] as List<dynamic>? ?? [];
          final List<Map<String, dynamic>> qualifications = [];

          for (var qualType in qualTypes) {
            if (qualType is Map && qualType['qualification'] != null) {
              final qual = qualType['qualification'] as Map;
              qualifications.add({
                'id': qual['id']?.toString() ?? '',
                'name': qual['name']?.toString() ?? 'Unknown Qualification',
                'employment_status':
                    qual['employment_status']?.toString() ?? '',
                'num_participants': qual['num_participants']?.toString() ?? '',
                'qual_type': qualType['qual_type']?.toString() ?? '',
              });
            }
          }

          parsedPathways.add({
            'id': pathwayId,
            'name': pathwayName,
            'isInternship': isInternship,
            'qualifications': qualifications,
          });
        }
      }

      setState(() {
        _pathways = parsedPathways;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[SDP_PATHWAYS] Error parsing pathways: $e');
      setState(() {
        _pathways = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing pathways: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pathways.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'No learning pathways found',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Navigate directly to sites for this project
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminPage(
                                sdp: widget.sdpIdentifier,
                                data: const [],
                                projectId: widget.projectId,
                              ),
                            ),
                          );
                        },
                        child: const Text('View All Sites'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pathways.length,
                  itemBuilder: (context, index) {
                    final pathway = _pathways[index];
                    final qualifications = pathway['qualifications']
                            as List<Map<String, dynamic>>? ??
                        [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(
                          pathway['name'] ?? 'Unknown Pathway',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          pathway['isInternship'] == true
                              ? 'Internship Programme'
                              : 'Training Programme',
                        ),
                        children: [
                          if (qualifications.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No qualifications available'),
                            )
                          else
                            ...qualifications.map((qual) {
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                                title: Text(qual['name'] ?? 'Unknown'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (qual['qual_type']?.isNotEmpty == true)
                                      Text('Type: ${qual['qual_type']}'),
                                    if (qual['employment_status']?.isNotEmpty ==
                                        true)
                                      Text(
                                          'Status: ${qual['employment_status']}'),
                                    if (qual['num_participants']?.isNotEmpty ==
                                        true)
                                      Text(
                                          'Participants: ${qual['num_participants']}'),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    // Navigate to sites filtered by this project and pathway
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AdminPage(
                                          sdp: widget.sdpIdentifier,
                                          data: const [],
                                          projectId: widget.projectId,
                                          pathwayId: pathway['id']?.toString(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('View Sites'),
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
