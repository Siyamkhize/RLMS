import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'facilitator_material_issuance_page.dart';

class LogisticsFacilitatorsPage extends StatefulWidget {
  final String logisticsId;
  final String logisticsName;
  final String siteId;
  final String siteName;

  const LogisticsFacilitatorsPage({
    super.key,
    required this.logisticsId,
    required this.logisticsName,
    required this.siteId,
    required this.siteName,
  });

  @override
  _LogisticsFacilitatorsPageState createState() =>
      _LogisticsFacilitatorsPageState();
}

class _LogisticsFacilitatorsPageState extends State<LogisticsFacilitatorsPage> {
  List<dynamic> facilitators = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchFacilitators();
  }

  Future<void> fetchFacilitators() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final url = AppConfig.buildUrl(
          'get_logistics_facilitators.php?siteID=${widget.siteId}&account_id=${widget.logisticsId}');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['facilitators'] != null) {
          setState(() {
            facilitators = data['facilitators'];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = data['error'] ?? 'Failed to load facilitators';
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
        title: Text('Facilitators - ${widget.siteName}'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchFacilitators,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select facilitator to issue materials directly',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
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
                              onPressed: fetchFacilitators,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : facilitators.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_outline,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No facilitators found at this site',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: fetchFacilitators,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: facilitators.length,
                              itemBuilder: (context, index) {
                                final facilitator = facilitators[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 4,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: const CircleAvatar(
                                      backgroundColor: Colors.orange,
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      facilitator['facilitator_name'] ??
                                          'Unknown Facilitator',
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
                                        if (facilitator['class_names'] !=
                                            null) ...[
                                          Row(
                                            children: [
                                              Icon(Icons.class_,
                                                  size: 16,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'Classes: ${facilitator['class_names']}',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (facilitator['total_learners'] !=
                                            null) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.group,
                                                  size: 16,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                  '${facilitator['total_learners']} learners'),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: const Icon(Icons.send,
                                        color: Colors.orange),
                                    onTap: () {
                                      // Navigate directly to material issuance page
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              FacilitatorMaterialIssuancePage(
                                            logisticsId: widget.logisticsId,
                                            logisticsName: widget.logisticsName,
                                            siteId: widget.siteId,
                                            siteName: widget.siteName,
                                            classId: facilitator['class_id']
                                                    ?.toString() ??
                                                '0',
                                            className:
                                                facilitator['class_names'] ??
                                                    'Unknown Class',
                                            facilitatorId:
                                                facilitator['facilitator_id']
                                                        ?.toString() ??
                                                    '0',
                                            facilitatorName: facilitator[
                                                    'facilitator_name'] ??
                                                'Unknown Facilitator',
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
