import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_helper.dart';
import 'config.dart';
import 'utils/fingerprint_error_handler.dart';

class PPESizesPage extends StatefulWidget {
  final int learnerID;
  final String? learnerName;

  const PPESizesPage({
    super.key,
    required this.learnerID,
    this.learnerName,
  });

  @override
  State<PPESizesPage> createState() => _PPESizesPageState();
}

class _PPESizesPageState extends State<PPESizesPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;
  bool _isSaving = false;

  String? _contiSuitsSize;
  String? _safetyBootsSize;

  // Available sizes - Conti-suits: 26-66, Safety boots: 3-14
  final List<String> _contiSuitsSizes = List.generate(
    41, // 66 - 26 + 1 = 41 items
    (index) => (26 + index).toString(),
  );

  final List<String> _safetyBootsSizes = List.generate(
    12, // 14 - 3 + 1 = 12 items
    (index) => (3 + index).toString(),
  );

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Try to load from local database first
      final localData = await _loadFromLocalDatabase();

      if (localData != null) {
        setState(() {
          _contiSuitsSize = localData['conti_suits_size'];
          _safetyBootsSize = localData['safety_boots_size'];
        });
      }

      // If online, also check server for latest data
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.first != ConnectivityResult.none) {
        await _loadFromServer();
      }
    } catch (e) {
      debugPrint('[PPE] Error loading existing data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _loadFromLocalDatabase() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'poe_sizes',
        where: 'learner_id = ?',
        whereArgs: [widget.learnerID],
        orderBy: 'created_at DESC',
        limit: 1,
      );

      if (result.isNotEmpty) {
        debugPrint('[PPE] Loaded from local database: ${result.first}');
        return result.first;
      }
    } catch (e) {
      debugPrint('[PPE] Error loading from local database: $e');
    }
    return null;
  }

  Future<void> _loadFromServer() async {
    try {
      final url = Uri.parse(
          '${AppConfig.baseUrl}/ppe_sizes.php?learner_id=${widget.learnerID}');
      debugPrint('[PPE] Fetching from server: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['status'] == 'success' && result['data'] != null) {
          final serverData = result['data'];

          setState(() {
            _contiSuitsSize = serverData['conti_suits_size'];
            _safetyBootsSize = serverData['safety_boots_size'];
          });

          // Save to local database
          await _saveToLocalDatabase(serverData);

          debugPrint('[PPE] Loaded from server: $serverData');
        }
      }
    } catch (e) {
      debugPrint('[PPE] Error loading from server: $e');
    }
  }

  Future<void> _saveToLocalDatabase(Map<String, dynamic> data) async {
    try {
      final db = await _dbHelper.database;

      // Create table if doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS poe_sizes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          learner_id INTEGER NOT NULL,
          conti_suits_size TEXT,
          safety_boots_size TEXT,
          created_at TEXT,
          updated_at TEXT,
          synced INTEGER DEFAULT 0
        )
      ''');

      await db.insert(
        'poe_sizes',
        {
          'learner_id': widget.learnerID,
          'conti_suits_size': data['conti_suits_size'],
          'safety_boots_size': data['safety_boots_size'],
          'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'synced': 1, // Mark as synced if from server
        },
      );

      debugPrint('[PPE] Saved to local database');
    } catch (e) {
      debugPrint('[PPE] Error saving to local database: $e');
    }
  }

  Future<void> _savePPESizes() async {
    // Validate at least one size is selected
    if (_contiSuitsSize == null && _safetyBootsSize == null) {
      FingerprintErrorHandler.showError(
        context,
        'Please select at least one PPE size (Conti-Suits or Safety Boots)',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Prepare data
      final ppeData = {
        'learner_id': widget.learnerID,
        'conti_suits_size': _contiSuitsSize,
        'safety_boots_size': _safetyBootsSize,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Save to local database first
      await _saveToLocalDatabaseNew(ppeData);

      // Try to sync to server if online
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult.first != ConnectivityResult.none;

      bool synced = false;
      if (isOnline) {
        synced = await _syncToServer(ppeData);
      }

      if (synced) {
        // Update local record as synced
        final db = await _dbHelper.database;
        await db.update(
          'poe_sizes',
          {'synced': 1},
          where: 'learner_id = ?',
          whereArgs: [widget.learnerID],
        );

        FingerprintErrorHandler.showSuccess(
          context,
          'PPE sizes saved and synced to server!',
        );
      } else {
        FingerprintErrorHandler.showInfo(
          context,
          'PPE sizes saved locally (will sync when online)',
        );
      }

      // Return to previous screen
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    } catch (e) {
      debugPrint('[PPE] Error saving PPE sizes: $e');
      FingerprintErrorHandler.showError(context, 'Failed to save PPE sizes');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _saveToLocalDatabaseNew(Map<String, dynamic> data) async {
    try {
      final db = await _dbHelper.database;

      // Create table if doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS poe_sizes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          learner_id INTEGER NOT NULL,
          conti_suits_size TEXT,
          safety_boots_size TEXT,
          created_at TEXT,
          updated_at TEXT,
          synced INTEGER DEFAULT 0
        )
      ''');

      // Delete old record for this learner (keep only latest)
      await db.delete(
        'poe_sizes',
        where: 'learner_id = ?',
        whereArgs: [widget.learnerID],
      );

      // Insert new record
      await db.insert(
        'poe_sizes',
        {
          'learner_id': data['learner_id'],
          'conti_suits_size': data['conti_suits_size'],
          'safety_boots_size': data['safety_boots_size'],
          'created_at': data['created_at'],
          'updated_at': DateTime.now().toIso8601String(),
          'synced': 0, // Not synced yet
        },
      );

      debugPrint('[PPE] Saved to local database');
    } catch (e) {
      debugPrint('[PPE] Error saving to local database: $e');
      rethrow;
    }
  }

  Future<bool> _syncToServer(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/ppe_sizes.php');
      debugPrint('[PPE] Syncing to server: $url');
      debugPrint('[PPE] Data: $data');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint(
          '[PPE] Server response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'success') {
          debugPrint('[PPE] Successfully synced to server');
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('[PPE] Error syncing to server: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'PPE Sizes - ${widget.learnerName ?? "Learner ${widget.learnerID}"}'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personal Protective Equipment Sizes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please select the appropriate PPE sizes for this learner',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // Conti-Suits Size
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.checkroom, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Conti-Suits Size',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _contiSuitsSize,
                            decoration: InputDecoration(
                              hintText: 'Select Conti-Suits size (26-66)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            items: _contiSuitsSizes.map((size) {
                              return DropdownMenuItem<String>(
                                value: size,
                                child: Text('Size $size'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _contiSuitsSize = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Safety Boots Size
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.work_outline, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                'Safety Boots Size',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _safetyBootsSize,
                            decoration: InputDecoration(
                              hintText: 'Select Safety Boots size (3-14)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            items: _safetyBootsSizes.map((size) {
                              return DropdownMenuItem<String>(
                                value: size,
                                child: Text('Size $size'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _safetyBootsSize = value;
                              });
                            },
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
                      onPressed: _isSaving ? null : _savePPESizes,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save PPE Sizes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info Card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Select at least one PPE size. Data will be saved locally and synced to server when online.',
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
