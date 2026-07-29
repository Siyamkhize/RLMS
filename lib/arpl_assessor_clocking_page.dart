import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart'; // Added for ConflictAlgorithm
import 'database_helper.dart';
import 'config.dart';
import 'clock_in_page.dart';
import 'facilitator_fingerprint_page.dart';

/// ARPL Assessor Clocking Page
/// Allows ARPL Assessors to:
/// 1. Clock themselves in/out using fingerprint scanner (same as facilitators)
/// 2. Clock learners in/out (navigates to ClockInPage with fingerprint scanning)
class ArplAssessorClockingPage extends StatefulWidget {
  final String facilitatorId; // Actually the assessor ID but uses same field
  final String facilitatorName;

  const ArplAssessorClockingPage({
    Key? key,
    required this.facilitatorId,
    required this.facilitatorName,
  }) : super(key: key);

  @override
  _ArplAssessorClockingPageState createState() =>
      _ArplAssessorClockingPageState();
}

class _ArplAssessorClockingPageState extends State<ArplAssessorClockingPage> {
  bool _isLoading = false;
  String? _assessorClockStatus; // 'in' or 'out' or null
  DateTime? _assessorClockInTime;
  List<dynamic> _classes = [];
  int _selectedTabIndex = 0;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadAssessorClockStatus();
    _loadClasses();
  }

  Future<void> _loadAssessorClockStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await _dbHelper.database;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Check local database for assessor clock status
      final result = await db.query(
        'facilitator_clocking',
        where: 'facilitator_id = ? AND clock_date = ?',
        whereArgs: [widget.facilitatorId, today],
        orderBy: 'clock_in_time DESC',
        limit: 1,
      );

      if (result.isNotEmpty) {
        final record = result.first;
        final clockOutTime = record['clock_out_time'];

        setState(() {
          if (clockOutTime == null || clockOutTime.toString().isEmpty) {
            _assessorClockStatus = 'in';
            _assessorClockInTime =
                DateTime.parse(record['clock_in_time'].toString());
          } else {
            _assessorClockStatus = 'out';
          }
        });
      }
    } catch (e) {
      print('[ARPL_CLOCKING] Error loading clock status: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadClasses() async {
    try {
      final url = AppConfig.buildUrl('get_classes.php', queryParams: {
        'facilitator_id': widget.facilitatorId,
      });

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          setState(() {
            _classes = data;
          });
        }
      }
    } catch (e) {
      print('[ARPL_CLOCKING] Error loading classes: $e');
    }
  }

  /// Navigate to facilitator fingerprint page for ASSESSOR clock in/out
  /// This uses the same fingerprint scanning system as facilitators
  Future<void> _navigateToFingerprintClocking() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilitatorFingerprintPage(
          facilitatorId: int.parse(widget.facilitatorId),
          facilitatorName: widget.facilitatorName,
          isFirstTimeSetup: false,
          requireClockIn: true,
          nextRoute: null, // Don't auto-navigate after clocking
        ),
      ),
    );

    // Refresh clock status after returning
    if (result == true) {
      await _loadAssessorClockStatus();
    }
  }

  Widget _buildAssessorClockingCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.fingerprint,
              size: 64,
              color: Color(0xFF006341),
            ),
            const SizedBox(height: 16),
            const Text(
              'Assessor Clock In/Out',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Assessor ID: ${widget.facilitatorId}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.facilitatorName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 24),
            if (_assessorClockStatus == 'in' && _assessorClockInTime != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Currently Clocked In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Since: ${DateFormat('HH:mm').format(_assessorClockInTime!)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            if (_assessorClockStatus == 'out' || _assessorClockStatus == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Not Clocked In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _navigateToFingerprintClocking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006341),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.fingerprint, size: 28),
                label: Text(
                  _assessorClockStatus == 'in'
                      ? 'Scan Fingerprint to Clock Out'
                      : 'Scan Fingerprint to Clock In',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnerClockingSection() {
    if (_classes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.class_, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No classes assigned',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You need to be assigned to a class to clock learners in/out',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _classes.length,
      itemBuilder: (context, index) {
        final classData = _classes[index];
        final className = classData['className'] ?? 'Unknown Class';
        final classID = classData['classID']?.toString() ?? '';
        final learnerCount = classData['numberOfLearners'] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF006341),
              child: Text(
                learnerCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              className,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Class ID: $classID • $learnerCount learners'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _navigateToLearnerClocking(classID, className);
            },
          ),
        );
      },
    );
  }

  /// Navigate to ClockInPage for learner fingerprint clocking
  /// This uses the same system that facilitators use for learners
  Future<void> _navigateToLearnerClocking(
      String classID, String className) async {
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Loading learners...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      final db = await _dbHelper.database;

      // CRITICAL FIX: Check if learners exist locally for this class
      final existingLearners = await db.query(
        'learnerdetails',
        where: 'ClassID = ?',
        whereArgs: [classID],
      );

      print(
          '[ARPL_CLOCKING] Found ${existingLearners.length} learners locally for class $classID');

      List<Map<String, dynamic>> learners = existingLearners;

      // If no learners found locally, try to sync from server
      if (learners.isEmpty) {
        print(
            '[ARPL_CLOCKING] No learners found locally - attempting to sync from server...');

        try {
          final url = '${AppConfig.baseUrl}/get_learners.php?classID=$classID';
          final response = await http.get(Uri.parse(url)).timeout(
                const Duration(seconds: 30),
              );

          if (response.statusCode == 200) {
            final dynamic responseData = jsonDecode(response.body);

            // Handle both List and Map responses
            List<dynamic> serverLearners = [];
            if (responseData is List) {
              serverLearners = responseData;
            } else if (responseData is Map) {
              // If response is a map, check for common data keys
              if (responseData.containsKey('data')) {
                serverLearners = responseData['data'] as List<dynamic>;
              } else if (responseData.containsKey('learners')) {
                serverLearners = responseData['learners'] as List<dynamic>;
              } else {
                throw Exception(
                    'Unexpected response format: Map without data or learners key');
              }
            } else {
              throw Exception(
                  'Unexpected response type: ${responseData.runtimeType}');
            }

            print(
                '[ARPL_CLOCKING] Received ${serverLearners.length} learners from server');

            // Insert learners into local database
            for (var learner in serverLearners) {
              try {
                await db.insert(
                  'learnerdetails',
                  learner as Map<String, dynamic>,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              } catch (e) {
                print('[ARPL_CLOCKING] Error inserting learner: $e');
              }
            }

            // Re-query learners for this class
            learners = await db.query(
              'learnerdetails',
              where: 'ClassID = ?',
              whereArgs: [classID],
            );

            print(
                '[ARPL_CLOCKING] After sync: ${learners.length} learners found for class $classID');
          } else {
            throw Exception('Server returned status ${response.statusCode}');
          }
        } catch (syncError) {
          print(
              '[ARPL_CLOCKING] Error syncing learners from server: $syncError');

          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Unable to load learners. Please check your internet connection and try again.\n\nError: $syncError'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      }

      if (!mounted) return;

      // Clear loading indicator
      ScaffoldMessenger.of(context).clearSnackBars();

      if (learners.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('No learners found for class $className (ID: $classID)'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Navigate to the standard ClockInPage (same as facilitators use)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClockInPage(
            classID: classID,
            learners: learners,
          ),
        ),
      );
    } catch (e) {
      print('[ARPL_CLOCKING] Error fetching learners: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading learners: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ARPL Assessor Clocking'),
          backgroundColor: const Color(0xFF006341),
          foregroundColor: Colors.white,
          bottom: TabBar(
            onTap: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
            tabs: const [
              Tab(
                icon: Icon(Icons.fingerprint),
                text: 'My Clock In/Out',
              ),
              Tab(
                icon: Icon(Icons.people),
                text: 'Learner Clocking',
              ),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 0: Assessor self clocking with fingerprint
            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildAssessorClockingCard(),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Color(0xFF006341)),
                                SizedBox(width: 8),
                                Text(
                                  'Instructions',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '1. Tap the fingerprint button to scan your fingerprint\n'
                              '2. Place your enrolled finger on the scanner\n'
                              '3. The system will clock you in or out automatically\n'
                              '4. Your attendance is tracked for reporting\n'
                              '5. Data syncs automatically when online',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Tab 1: Learner clocking with fingerprint
            _buildLearnerClockingSection(),
          ],
        ),
      ),
    );
  }
}
