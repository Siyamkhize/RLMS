import 'package:flutter/material.dart';
import 'admin.dart';

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
    } else {
      setState(() {
        _pathways = [];
        _isLoading = false;
      });
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
                    final qualTypes = pathway['qual_types'] as List? ?? [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(
                            pathway['is_internship'] == true
                                ? Icons.work
                                : Icons.school,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          pathway['pathway_name'] ?? 'Unknown Pathway',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pathway['is_internship'] == true
                                  ? 'Internship Programme'
                                  : 'Training Programme',
                              style: TextStyle(fontSize: 13),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Sites: ${pathway['site_count'] ?? 0}',
                              style: TextStyle(
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
                              if (qual == null) return SizedBox.shrink();

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                                leading: Icon(Icons.verified,
                                    color: Colors.orange, size: 20),
                                title: Text(
                                  qual['name']?.toString() ?? 'Unknown',
                                  style: TextStyle(fontSize: 14),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (qualType['qual_type']
                                            ?.toString()
                                            .isNotEmpty ==
                                        true)
                                      Text('Type: ${qualType['qual_type']}',
                                          style: TextStyle(fontSize: 12)),
                                    if (qual['employment_status']
                                            ?.toString()
                                            .isNotEmpty ==
                                        true)
                                      Text(
                                          'Status: ${qual['employment_status']}',
                                          style: TextStyle(fontSize: 12)),
                                    if (qual['num_participants']
                                            ?.toString()
                                            .isNotEmpty ==
                                        true)
                                      Text(
                                          'Participants: ${qual['num_participants']}',
                                          style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              );
                            }),
                          // View Sites button
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Navigate to AdminPage with sites data
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdminPage(
                                      sdp: widget.sdpIdentifier,
                                      data: List<Map<String, dynamic>>.from(
                                          pathway['sites'] ?? []),
                                      projectId: widget.projectId,
                                      pathwayId:
                                          pathway['pathway_id']?.toString(),
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.location_on),
                              label: Text(
                                  'View ${pathway['site_count'] ?? 0} Sites'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(double.infinity, 45),
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
