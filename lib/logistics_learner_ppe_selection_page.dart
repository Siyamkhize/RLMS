import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'config.dart';

class LogisticsLearnerPPESelectionPage extends StatefulWidget {
  final Map<String, dynamic> learner;
  final String ppeType;
  final List<Map<String, dynamic>> ppeItems;
  final String? logisticsId;
  final String? logisticsName;
  final String? siteId;
  final String? siteName;
  final String? classId;
  final String? className;
  final String? facilitatorId;
  final String? facilitatorName;

  const LogisticsLearnerPPESelectionPage({
    super.key,
    required this.learner,
    required this.ppeType,
    required this.ppeItems,
    this.logisticsId,
    this.logisticsName,
    this.siteId,
    this.siteName,
    this.classId,
    this.className,
    this.facilitatorId,
    this.facilitatorName,
  });

  @override
  State<LogisticsLearnerPPESelectionPage> createState() =>
      _LogisticsLearnerPPESelectionPageState();
}

class _LogisticsLearnerPPESelectionPageState
    extends State<LogisticsLearnerPPESelectionPage> {
  String? selectedSize;
  int quantity = 1;
  bool isSaving = false;

  List<String> availableSizes = [];
  IconData ppeIcon = Icons.category;
  Color ppeColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadPPEInfo();
  }

  void _loadPPEInfo() {
    // Find the PPE item info
    final ppeItem = widget.ppeItems.firstWhere(
      (item) => item['ppe_type'] == widget.ppeType,
      orElse: () => <String, dynamic>{
        'sizes': ['One Size'],
        'icon': Icons.category,
        'color': Colors.blue,
      },
    );

    setState(() {
      availableSizes = List<String>.from(ppeItem['sizes'] ?? ['One Size']);
      ppeIcon = ppeItem['icon'] ?? Icons.category;
      ppeColor = ppeItem['color'] ?? Colors.blue;

      // Auto-select if only one size
      if (availableSizes.length == 1) {
        selectedSize = availableSizes.first;
      }
    });
  }

  Future<void> _savePPEIssuance() async {
    if (selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a size'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantity must be at least 1'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Get internal learner_id (this is the LearnerID from learnerdetails)
      final internalLearnerId = widget.learner['LearnerID'] as int;

      debugPrint('[PPE-SAVE] Internal LearnerID: $internalLearnerId');
      debugPrint('[PPE-SAVE] PPE Type: ${widget.ppeType}');
      debugPrint('[PPE-SAVE] Size: $selectedSize');

      // Save to poe_sizes table (using internal LearnerID)
      final poeCheck = await db.query(
        'poe_sizes',
        where: 'learner_id = ?',
        whereArgs: [internalLearnerId],
      );

      if (poeCheck.isNotEmpty) {
        // Update existing record
        final existing = poeCheck.first;
        String? contiSuitsSize = existing['conti_suits_size'] as String?;
        String? safetyBootsSize = existing['safety_boots_size'] as String?;

        // Update the appropriate field based on PPE type
        if (widget.ppeType.toLowerCase().contains('conti') ||
            widget.ppeType.toLowerCase().contains('suit')) {
          contiSuitsSize = selectedSize;
        } else if (widget.ppeType.toLowerCase().contains('boot') ||
            widget.ppeType.toLowerCase().contains('safety')) {
          safetyBootsSize = selectedSize;
        }

        await db.update(
          'poe_sizes',
          {
            'conti_suits_size': contiSuitsSize,
            'safety_boots_size': safetyBootsSize,
            'updated_at': DateTime.now().toIso8601String(),
            'synced': 0,
          },
          where: 'learner_id = ?',
          whereArgs: [internalLearnerId],
        );
        debugPrint(
            '[PPE-SAVE] ✓ Updated poe_sizes for learner_id: $internalLearnerId');
      } else {
        // Insert new record
        String? contiSuitsSize;
        String? safetyBootsSize;

        if (widget.ppeType.toLowerCase().contains('conti') ||
            widget.ppeType.toLowerCase().contains('suit')) {
          contiSuitsSize = selectedSize;
        } else if (widget.ppeType.toLowerCase().contains('boot') ||
            widget.ppeType.toLowerCase().contains('safety')) {
          safetyBootsSize = selectedSize;
        }

        await db.insert('poe_sizes', {
          'learner_id': internalLearnerId,
          'conti_suits_size': contiSuitsSize,
          'safety_boots_size': safetyBootsSize,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'synced': 0,
        });
        debugPrint(
            '[PPE-SAVE] ✓ Inserted to poe_sizes for learner_id: $internalLearnerId');
      }

      // Prepare data for server sync
      final issuanceData = {
        'LearnerID': widget.learner['LearnerID'],
        'learner_name': widget.learner['FullName'],
        'ppe_type': widget.ppeType,
        'size': selectedSize,
        'quantity': quantity,
        'logistics_id': widget.logisticsId ?? '',
        'logistics_name': widget.logisticsName ?? 'Logistics',
        'site_id': widget.siteId ?? '',
        'site_name': widget.siteName ?? '',
        'class_id': widget.classId ?? '',
        'class_name': widget.className ?? '',
        'facilitator_id': widget.facilitatorId ?? '',
        'facilitator_name': widget.facilitatorName ?? '',
        'issued_date': DateTime.now().toIso8601String(),
      };

      debugPrint('[PPE-SAVE] Saved to local poe_sizes table');

      // Try to sync to server
      bool synced = false;
      try {
        synced = await _syncToServer(issuanceData);
      } catch (e) {
        debugPrint('[PPE-SAVE] Sync to server failed: $e');
      }

      if (synced) {
        // Update local record as synced
        await db.update(
          'poe_sizes',
          {'synced': 1},
          where: 'learner_id = ?',
          whereArgs: [internalLearnerId],
        );
        debugPrint('[PPE-SAVE] ✓ Marked as synced in poe_sizes');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              synced
                  ? 'PPE issued and synced successfully!'
                  : 'PPE issued locally (will sync when online)',
            ),
            backgroundColor: synced ? Colors.green : Colors.orange,
          ),
        );

        // Return to previous screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('[PPE-SAVE] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving PPE issuance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<bool> _syncToServer(Map<String, dynamic> data) async {
    try {
      final url =
          Uri.parse('${AppConfig.baseUrl}/save_logistics_ppe_issuance.php');
      debugPrint('[PPE-SYNC] Syncing to server: $url');
      debugPrint('[PPE-SYNC] Data: $data');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint(
          '[PPE-SYNC] Server response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'success') {
          debugPrint('[PPE-SYNC] Successfully synced to server');
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('[PPE-SYNC] Error syncing to server: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Issue ${widget.ppeType}'),
        backgroundColor: ppeColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Learner Info Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          radius: 30,
                          child: Text(
                            widget.learner['Name'][0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.learner['FullName'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${widget.learner['IDNumber']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.verified_user,
                          color: Colors.green,
                          size: 32,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // PPE Type Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(ppeIcon, color: ppeColor, size: 32),
                        const SizedBox(width: 12),
                        Text(
                          widget.ppeType,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Size Selection
                    const Text(
                      'Select Size',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedSize,
                      decoration: InputDecoration(
                        hintText: 'Select size',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: availableSizes.map((size) {
                        return DropdownMenuItem<String>(
                          value: size,
                          child: Text('Size $size'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedSize = value;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Quantity Selection
                    const Text(
                      'Quantity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: quantity > 1
                              ? () {
                                  setState(() {
                                    quantity--;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          iconSize: 32,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            quantity.toString(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: quantity < 10
                              ? () {
                                  setState(() {
                                    quantity++;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                          iconSize: 32,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Issue Details Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Issue Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Site', widget.siteName ?? 'N/A'),
                    _buildDetailRow('Class', widget.className ?? 'N/A'),
                    _buildDetailRow(
                        'Facilitator', widget.facilitatorName ?? 'N/A'),
                    _buildDetailRow(
                        'Issued By', widget.logisticsName ?? 'Logistics'),
                    _buildDetailRow(
                      'Date',
                      DateTime.now().toString().split(' ')[0],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _savePPEIssuance,
                icon: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(isSaving ? 'Issuing...' : 'Issue PPE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
