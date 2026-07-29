import 'package:flutter/material.dart';
import 'admin.dart';
import 'sdp_unallocated_learners_page.dart';

class SdpLearningPathwaysPage extends StatefulWidget {
  final String sdpIdentifier;
  final String projectId;
  final String projectName;
  final List<Map<String, dynamic>>? pathways;

  const SdpLearningPathwaysPage({
    super.key,
    required this.sdpIdentifier,
    required this.projectId,
    required this.projectName,
    this.pathways,
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
    // Use pathways from login if available
    if (widget.pathways != null && widget.pathways!.isNotEmpty) {
      setState(() {
        _pathways = widget.pathways!;
        _isLoading = false;
      });
      debugPrint(
          '[SDP_PATHWAYS] Loaded ${_pathways.length} pathways from widget');
    } else {
      setState(() {
        _pathways = [];
        _isLoading = false;
      });
      debugPrint('[SDP_PATHWAYS] No pathways provided');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: [
          // Unallocated Learners button - more visible
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                debugPrint('[SDP_PATHWAYS] Navigating to Unallocated Learners');
                debugPrint('  - sdpIdentifier: ${widget.sdpIdentifier}');
                debugPrint('  - projectId: ${widget.projectId}');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UnallocatedLearnersPage(
                      sdpIdentifier: widget.sdpIdentifier,
                      projectId: widget.projectId,
                      projectName: widget.projectName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.person_off, size: 18),
              label: const Text('Unallocated'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
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
                    final qualTypes = pathway['qual_types'] as List? ?? [];

                    // Extract pathway name from 'name' field
                    final pathwayName = pathway['name']?.toString() ??
                        pathway['pathway_name']?.toString() ??
                        'Unknown Pathway';
                    final isInternship = pathway['isInternship'] == true ||
                        pathway['is_internship'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(
                            isInternship ? Icons.work : Icons.school,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          pathwayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isInternship
                                  ? 'Internship Programme'
                                  : 'Training Programme',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Qualifications: ${qualTypes.length}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        children: [
                          // Display qualifications
                          if (qualTypes.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No qualifications available'),
                            )
                          else
                            ...qualTypes.map((qualType) {
                              final qual = qualType['qualification'] as Map?;
                              if (qual == null) return const SizedBox.shrink();

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                                leading: const Icon(Icons.verified,
                                    color: Colors.orange, size: 20),
                                title: Text(
                                  qual['name']?.toString() ?? 'Unknown',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (qualType['qual_type']
                                            ?.toString()
                                            .isNotEmpty ==
                                        true)
                                      Text('Type: ${qualType['qual_type']}',
                                          style: const TextStyle(fontSize: 12)),
                                    if (qual['employment_status']
                                            ?.toString()
                                            .isNotEmpty ==
                                        true)
                                      Text(
                                          'Status: ${qual['employment_status']}',
                                          style: const TextStyle(fontSize: 12)),
                                    if (qual['num_participants']
                                            ?.toString()
                                            .isNotEmpty ==
                                        true)
                                      Text(
                                          'Participants: ${qual['num_participants']}',
                                          style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              );
                            }),
                          // View Sites button
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Get first qualification ID if available
                                String? qualificationId;
                                if (qualTypes.isNotEmpty) {
                                  final firstQual =
                                      qualTypes[0]['qualification'] as Map?;
                                  qualificationId =
                                      firstQual?['id']?.toString();
                                }

                                debugPrint(
                                    '[SDP_PATHWAYS] Navigating to AdminPage:');
                                debugPrint(
                                    '  - sdpIdentifier: ${widget.sdpIdentifier}');
                                debugPrint(
                                    '  - projectId: ${widget.projectId}');
                                debugPrint('  - pathwayName: $pathwayName');
                                debugPrint(
                                    '  - qualificationId: $qualificationId');

                                // Navigate to AdminPage - it will fetch sites from API
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdminPage(
                                      sdp: widget.sdpIdentifier,
                                      data: const [], // Empty - let admin fetch from API
                                      projectId: widget.projectId,
                                      pathwayId:
                                          pathwayName, // Pass pathway NAME
                                      qualificationId: qualificationId,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.location_on),
                              label: const Text('View Sites'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 45),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
