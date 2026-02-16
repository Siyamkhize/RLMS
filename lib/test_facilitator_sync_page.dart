import 'package:flutter/material.dart';
import 'force_facilitator_sync.dart';
import 'database_helper.dart';

class TestFacilitatorSyncPage extends StatefulWidget {
  const TestFacilitatorSyncPage({Key? key}) : super(key: key);

  @override
  State<TestFacilitatorSyncPage> createState() => _TestFacilitatorSyncPageState();
}

class _TestFacilitatorSyncPageState extends State<TestFacilitatorSyncPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _localFacilitators = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    setState(() => _loading = true);
    try {
      final db = await _dbHelper.database;
      final facilitators = await db.query('facilitator');
      setState(() {
        _localFacilitators = facilitators;
        _loading = false;
      });
    } catch (e) {
      print('Error loading facilitators: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _forceSync() async {
    await ForceFacilitatorSync.showSyncDialog(context);
    // Reload data after sync
    await _loadLocalData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Facilitator Sync'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Sync button at top
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.deepPurple.shade50,
                  child: Column(
                    children: [
                      Text(
                        'Local Database Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Facilitators in local DB: ${_localFacilitators.length}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _forceSync,
                        icon: const Icon(Icons.sync),
                        label: const Text('FORCE SYNC NOW'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _loadLocalData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh View'),
                      ),
                    ],
                  ),
                ),

                // List of facilitators
                Expanded(
                  child: _localFacilitators.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 64,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No facilitators in local database',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Click "FORCE SYNC NOW" to download data',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _localFacilitators.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final facilitator = _localFacilitators[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.deepPurple,
                                  child: Text(
                                    facilitator['facilitator_id'].toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '${facilitator['firstName'] ?? ''} ${facilitator['lastName'] ?? ''}'.trim().isEmpty
                                      ? '(No name)'
                                      : '${facilitator['firstName'] ?? ''} ${facilitator['lastName'] ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  facilitator['email']?.toString() ?? '(No email)',
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildDetailRow('ID', facilitator['facilitator_id']),
                                        _buildDetailRow('First Name', facilitator['firstName']),
                                        _buildDetailRow('Last Name', facilitator['lastName']),
                                        _buildDetailRow('Email', facilitator['email']),
                                        _buildDetailRow('Role', facilitator['role']),
                                        _buildDetailRow('Class ID', facilitator['classID']),
                                        _buildDetailRow('Phone', facilitator['phoneNumber']),
                                        _buildDetailRow('Assessor No', facilitator['assessorNo']),
                                        _buildDetailRow('Password', 
                                          facilitator['password']?.toString().isNotEmpty == true 
                                              ? '${facilitator['password'].toString().substring(0, 20)}...' 
                                              : null),
                                        const Divider(),
                                        const Text(
                                          'Fingerprint Templates:',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        _buildTemplateStatus('ZKTeco Left', facilitator['zkteco_left_template']),
                                        _buildTemplateStatus('ZKTeco Right', facilitator['zkteco_right_template']),
                                        _buildTemplateStatus('Futronic Left', facilitator['futronic_left_template']),
                                        _buildTemplateStatus('Futronic Right', facilitator['futronic_right_template']),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    final valueStr = value?.toString() ?? '';
    final isEmpty = valueStr.isEmpty || valueStr == 'null';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              isEmpty ? '(empty)' : valueStr,
              style: TextStyle(
                color: isEmpty ? Colors.red : Colors.black,
                fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateStatus(String label, dynamic template) {
    final hasTemplate = template?.toString().isNotEmpty == true;
    final length = template?.toString().length ?? 0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            hasTemplate ? Icons.check_circle : Icons.cancel,
            color: hasTemplate ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ${hasTemplate ? "$length chars" : "Not enrolled"}',
            style: TextStyle(
              color: hasTemplate ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

