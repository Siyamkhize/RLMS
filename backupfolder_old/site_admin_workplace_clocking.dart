import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'config.dart';
import 'services/futronic_service.dart';

class SiteAdminWorkplaceClocking extends StatefulWidget {
  final int workplaceId;
  final String workplaceName;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  const SiteAdminWorkplaceClocking({
    super.key,
    required this.workplaceId,
    required this.workplaceName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  @override
  _SiteAdminWorkplaceClockingState createState() =>
      _SiteAdminWorkplaceClockingState();
}

class _SiteAdminWorkplaceClockingState
    extends State<SiteAdminWorkplaceClocking> {
  final FutronicService _futronicService = FutronicService();
  List<dynamic> learners = [];
  bool isLoading = true;
  bool isSensorConnected = false;
  String statusMessage = '';

  @override
  void initState() {
    super.initState();
    _checkSensor();
    _loadLearners();
  }

  Future<void> _checkSensor() async {
    try {
      final connected = await _futronicService.isFutronicConnected();
      setState(() {
        isSensorConnected = connected;
        statusMessage =
            connected ? 'Fingerprint scanner ready' : 'Scanner not connected';
      });

      if (connected) {
        // Request USB permission if needed
        await _futronicService.requestUsbPermission();
      }
    } catch (e) {
      setState(() {
        isSensorConnected = false;
        statusMessage = 'Scanner error: $e';
      });
    }
  }

  Future<void> _loadLearners() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
            '${AppConfig.getWorkplaceLearnersForClockingUrl}?workplace_id=${widget.workplaceId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            learners = data['data'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading learners: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _clockLearner(
      Map<String, dynamic> learner, bool isClockIn) async {
    if (!isSensorConnected) {
      _showError('Fingerprint scanner not connected');
      return;
    }

    setState(() {
      statusMessage = 'Place finger on scanner...';
    });

    try {
      // Verify fingerprint using Futronic scanner
      final leftTemplate = learner['fingerprint_template_left'];
      final rightTemplate = learner['fingerprint_template_right'];

      if (leftTemplate == null && rightTemplate == null) {
        _showError('No fingerprint enrolled for this learner');
        return;
      }

      final isMatch = await _futronicService.verifyBoth(
        hintFinger: 'Place finger on scanner',
        leftTemplate: leftTemplate,
        rightTemplate: rightTemplate,
      );

      if (!isMatch) {
        _showError('Fingerprint does not match');
        return;
      }

      // Save clocking
      await _saveClocking(learner['LearnerID'], isClockIn);

      setState(() {
        statusMessage =
            isClockIn ? 'Clocked in successfully' : 'Clocked out successfully';
      });

      _loadLearners(); // Refresh list
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _saveClocking(int learnerId, bool isClockIn) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm:ss').format(now);

    final response = await http.post(
      Uri.parse(AppConfig.saveWorkplaceClockingUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'learner_id': learnerId,
        'workplace_id': widget.workplaceId,
        'clock_date': dateStr,
        isClockIn ? 'clock_in_time' : 'clock_out_time': timeStr,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save clocking');
    }

    final data = json.decode(response.body);
    if (!data['success']) {
      throw Exception(data['message'] ?? 'Failed to save clocking');
    }
  }

  void _showError(String message) {
    setState(() {
      statusMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Clock Learners - ${widget.workplaceName}'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.all(16),
            color:
                isSensorConnected ? Colors.green.shade50 : Colors.red.shade50,
            child: Row(
              children: [
                Icon(
                  isSensorConnected ? Icons.check_circle : Icons.error,
                  color: isSensorConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusMessage,
                    style: TextStyle(
                      color: isSensorConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Learners list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : learners.isEmpty
                    ? const Center(child: Text('No learners assigned'))
                    : ListView.builder(
                        itemCount: learners.length,
                        itemBuilder: (context, index) {
                          final learner = learners[index];
                          final hasClockIn = learner['clock_in_time'] != null;
                          final hasClockOut = learner['clock_out_time'] != null;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: hasClockOut
                                    ? Colors.green
                                    : hasClockIn
                                        ? Colors.orange
                                        : Colors.grey,
                                child: Text(
                                  learner['Name'][0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                  '${learner['Name']} ${learner['Surname']}'),
                              subtitle: Text(
                                hasClockOut
                                    ? 'In: ${learner['clock_in_time']} | Out: ${learner['clock_out_time']}'
                                    : hasClockIn
                                        ? 'Clocked in: ${learner['clock_in_time']}'
                                        : 'Not clocked in',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!hasClockIn)
                                    ElevatedButton(
                                      onPressed: () =>
                                          _clockLearner(learner, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                      child: const Text('Clock In'),
                                    ),
                                  if (hasClockIn && !hasClockOut) ...[
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () =>
                                          _clockLearner(learner, false),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Clock Out'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // FutronicService doesn't need disposal
    super.dispose();
  }
}
