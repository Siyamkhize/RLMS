import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'config.dart';
import 'database_helper.dart';
import 'services/secure_location_service.dart';
import 'package:http/http.dart' as http;
import 'LearnerDetailsPage.dart';

/// BACKUP CLOCK-IN PAGE
///_
/// This page is used when no fingerprint scanner is available.
/// Flow: Profile Check → Bank Check → Documents Check → ID Verification → Signature → GPS → Clock-In/Out
///
/// Key differences from regular clock-in:
/// - Uses signature instead of fingerprint verification
/// - Requires manual ID number confirmation before signature
/// - All the same mandatory checks (profile, bank, documents)
/// - Same geofencing and GPS verification

class BackupClockInPage extends StatefulWidget {
  final String classID;
  final List<dynamic> learners;

  const BackupClockInPage({
    Key? key,
    required this.classID,
    required this.learners,
  }) : super(key: key);

  @override
  _BackupClockInPageState createState() => _BackupClockInPageState();
}

class _BackupClockInPageState extends State<BackupClockInPage> {
  bool _isLoading = false;
  String? _selectedLearnerId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Signature controller
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  // State tracking
  Map<String, bool> _isClockingIn = {};
  Map<String, bool> _isClockedIn = {}; // Track who is clocked in
  Map<String, bool> _hasCompletedDay =
      {}; // Track who has both clocked in AND out
  String? _currentStep; // tracks current step in flow

  @override
  void initState() {
    super.initState();
    _loadClockingStatus();
    _syncAllSignaturesToServer(); // Sync signatures when page loads (if online)
  }

  /// Load clocking status for all learners
  Future<void> _loadClockingStatus() async {
    try {
      final db = await DatabaseHelper().database;
      final today = DateTime.now().toUtc().add(const Duration(hours: 2));
      final todayStr = DateFormat('yyyy-MM-dd').format(today);

      print('[BACKUP_STATUS] ===== LOADING STATUS =====');
      print('[BACKUP_STATUS] Loading status for date: $todayStr');
      print('[BACKUP_STATUS] Total learners: ${widget.learners.length}');

      for (var learner in widget.learners) {
        final learnerMap = learner as Map<String, dynamic>;
        final learnerId = learnerMap['LearnerID'].toString();
        final learnerName = '${learnerMap['Name']} ${learnerMap['Surname']}';

        // Check if learner has clocked in today but not clocked out
        final result = await db.rawQuery('''
          SELECT clock_in_time, clock_out_time, clock_date, synced
          FROM learner_clocking 
          WHERE LearnerID = ? 
            AND DATE(clock_date) = ?
          ORDER BY clock_in_time DESC
          LIMIT 1
        ''', [learnerId, todayStr]);

        print('[BACKUP_STATUS] --- Learner: $learnerName (ID: $learnerId) ---');
        print('[BACKUP_STATUS]     Records found: ${result.length}');

        if (result.isNotEmpty) {
          final record = result.first;
          final clockInTime = record['clock_in_time'];
          final clockOutTime = record['clock_out_time'];
          final clockDate = record['clock_date'];
          final synced = record['synced'];

          print('[BACKUP_STATUS]     clock_date=$clockDate');
          print('[BACKUP_STATUS]     clock_in=$clockInTime');
          print('[BACKUP_STATUS]     clock_out=$clockOutTime');
          print('[BACKUP_STATUS]     synced=$synced');

          if (mounted) {
            setState(() {
              // Clocked in if there's a clock-in time but no clock-out time (or empty string)
              final hasClockIn =
                  clockInTime != null && clockInTime.toString().isNotEmpty;
              final hasClockOut = clockOutTime != null &&
                  clockOutTime.toString().isNotEmpty &&
                  clockOutTime.toString() != 'null';

              // Check if day is completed (both clock in AND clock out)
              _hasCompletedDay[learnerId] = hasClockIn && hasClockOut;

              // Clocked in only if they have clock-in but NO clock-out
              _isClockedIn[learnerId] = hasClockIn && !hasClockOut;

              final isClockedIn = _isClockedIn[learnerId] ?? false;
              final hasCompleted = _hasCompletedDay[learnerId] ?? false;

              print(
                  '[BACKUP_STATUS]     Status: ${hasCompleted ? "✓✓ COMPLETED DAY" : isClockedIn ? "✓ CLOCKED IN" : "✗ NOT CLOCKED IN"} (hasClockIn=$hasClockIn, hasClockOut=$hasClockOut)');
            });
          }
        } else {
          print('[BACKUP_STATUS]     Status: ✗ NO RECORDS FOR TODAY');
          if (mounted) {
            setState(() {
              _isClockedIn[learnerId] = false;
              _hasCompletedDay[learnerId] = false;
            });
          }
        }
      }
      print('[BACKUP_STATUS] ===== STATUS LOADING COMPLETE =====');
    } catch (e) {
      print('[BACKUP] Error loading clocking status: $e');
      print('[BACKUP] Stack trace: ${StackTrace.current}');
    }
  }

  /// Check if a specific learner is clocked in
  bool _isLearnerClockedIn(String learnerId) {
    return _isClockedIn[learnerId] ?? false;
  }

  /// Check if a specific learner has completed their day (clocked in AND out)
  bool _hasLearnerCompletedDay(String learnerId) {
    return _hasCompletedDay[learnerId] ?? false;
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Filter learners based on search
  List<dynamic> get _filteredLearners {
    if (_searchQuery.isEmpty) {
      return widget.learners;
    }
    return widget.learners.where((learner) {
      final learnerMap = learner as Map<String, dynamic>;
      final name = (learnerMap['Name'] ?? '').toString().toLowerCase();
      final surname = (learnerMap['Surname'] ?? '').toString().toLowerCase();
      final idNumber = (learnerMap['IDNumber'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          surname.contains(query) ||
          idNumber.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Clock-In (Signature Mode)'),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            color: Colors.orange.shade100,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Using backup signature mode - no fingerprint scanner required',
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search learners',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Learner list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLearners.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No learners available'
                              : 'No learners found for "$_searchQuery"',
                          style:
                              const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredLearners.length,
                        itemBuilder: (context, index) {
                          final learner =
                              _filteredLearners[index] as Map<String, dynamic>;
                          final learnerId = learner['LearnerID'].toString();
                          final isProcessing = _isClockingIn[learnerId] == true;
                          final isClockedIn = _isLearnerClockedIn(learnerId);
                          final hasCompletedDay =
                              _hasLearnerCompletedDay(learnerId);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: hasCompletedDay
                                    ? Colors.blue
                                    : isClockedIn
                                        ? Colors.green
                                        : Colors.orange,
                                child: Text(
                                  (learner['Name'] ?? '?')
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                '${learner['Name']} ${learner['Surname']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ID: ${learner['IDNumber']}'),
                                  if (hasCompletedDay)
                                    const Text(
                                      'Already clocked in and out for today',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else if (isClockedIn)
                                    const Text(
                                      'Already clocked in',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: isProcessing
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : hasCompletedDay
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.check_circle,
                                                  color: Colors.blue, size: 20),
                                              SizedBox(width: 6),
                                              Text(
                                                'Completed',
                                                style: TextStyle(
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : isClockedIn
                                          ? IconButton(
                                              icon: const Icon(Icons.logout,
                                                  color: Colors.red),
                                              tooltip: 'Clock Out',
                                              onPressed: () =>
                                                  _startBackupClockOut(
                                                      learnerId),
                                            )
                                          : IconButton(
                                              icon: const Icon(Icons.login,
                                                  color: Colors.green),
                                              tooltip: 'Clock In',
                                              onPressed: () =>
                                                  _startBackupClockIn(
                                                      learnerId),
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

  /// ========== CLOCK-IN FLOW ==========
  Future<void> _startBackupClockIn(String learnerId) async {
    if (_isClockingIn[learnerId] == true) {
      return;
    }

    // Block if learner has already completed their day
    if (_hasLearnerCompletedDay(learnerId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '✓ You have already clocked in and out for today. See you tomorrow!'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isClockingIn[learnerId] = true;
      _currentStep = 'profile_check';
    });

    try {
      // Step 1: Profile completeness
      final profileOk = await _ensureLearnerProfileComplete(learnerId);
      if (!profileOk) {
        setState(() {
          _isClockingIn[learnerId] = false;
          _currentStep = null;
        });
        return;
      }

      // Step 2: Bank details
      setState(() => _currentStep = 'bank_check');
      final bankOk = await _ensureLearnerBankDetailsComplete(learnerId);
      if (!bankOk) {
        setState(() {
          _isClockingIn[learnerId] = false;
          _currentStep = null;
        });
        return;
      }

      // Step 3: Document completeness
      setState(() => _currentStep = 'document_check');
      final docsOk = await _checkDocumentCompleteness(learnerId);
      if (!docsOk) {
        setState(() {
          _isClockingIn[learnerId] = false;
          _currentStep = null;
        });
        return;
      }

      // Step 4: Show clocking days popup
      setState(() => _currentStep = 'clocking_days');
      await _showClockingDaysPopup(learnerId, 'in');

      // Step 5: ID verification
      setState(() => _currentStep = 'id_verification');
      final idVerified = await _verifyLearnerID(learnerId);
      if (!idVerified) {
        setState(() {
          _isClockingIn[learnerId] = false;
          _currentStep = null;
        });
        return;
      }

      // Step 6: Signature capture for clock-in
      setState(() => _currentStep = 'signature');
      final signatureData = await _captureSignature(learnerId);
      if (signatureData == null) {
        setState(() {
          _isClockingIn[learnerId] = false;
          _currentStep = null;
        });
        return;
      }

      // Step 7: GPS and geofence check
      setState(() => _currentStep = 'gps_check');
      final gpsOk = await _verifyGeofenceAndGPS(learnerId);
      if (!gpsOk) {
        setState(() {
          _isClockingIn[learnerId] = false;
          _currentStep = null;
        });
        return;
      }

      // Step 8: Submit clock-in WITH signature
      setState(() => _currentStep = 'submitting');
      await _submitBackupClockIn(learnerId, signatureData);

      // Small delay to ensure database write is complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Refresh clocking status
      await _loadClockingStatus();

      // Force UI rebuild
      if (mounted) {
        setState(() {});
      }

      // Success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Clocked in successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('[BACKUP_CLOCK_IN] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isClockingIn[learnerId] = false;
        _currentStep = null;
      });
    }
  }

  /// ========== CLOCK-OUT FLOW (ONE SIGNATURE per day - captured at clock-out) ==========
  Future<void> _startBackupClockOut(String learnerId) async {
    if (_isClockingIn[learnerId] == true) {
      return;
    }

    setState(() {
      _isClockingIn[learnerId] = true;
      _currentStep = 'clocking_days';
    });

    try {
      // Step 1: Show clocking days popup
      await _showClockingDaysPopup(learnerId, 'out');

      // Step 2: ID verification
      setState(() => _currentStep = 'id_verification');
      final idVerified = await _verifyLearnerID(learnerId);
      if (!idVerified) {
        setState(() {
          _isClockingIn[learnerId] = false;
          _currentStep = null;
        });
        return;
      }

      // Step 3: Signature capture (ONE signature for the day)
      setState(() => _currentStep = 'signature');
      final signatureData = await _captureSignature(learnerId);
      if (signatureData == null) {
        setState(() {
          _isClockingIn[learnerId] = false;
          _currentStep = null;
        });
        return;
      }

      // Step 4: GPS and geofence check
      setState(() => _currentStep = 'gps_check');
      final gpsOk = await _verifyGeofenceAndGPS(learnerId);
      if (!gpsOk) {
        setState(() {
          _isClockingIn[learnerId] = false;
          _currentStep = null;
        });
        return;
      }

      // Step 5: Submit clock-out with signature
      setState(() => _currentStep = 'submitting');
      await _submitBackupClockOut(learnerId, signatureData);

      // Small delay to ensure database write is complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Refresh clocking status
      await _loadClockingStatus();

      // Force UI rebuild
      if (mounted) {
        setState(() {});
      }

      // Success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Clocked out successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('[BACKUP_CLOCK_OUT] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isClockingIn[learnerId] = false;
        _currentStep = null;
      });
    }
  }

  /// ========== HELPER METHODS ==========

  Future<bool> _ensureLearnerProfileComplete(String learnerId) async {
    final learner = await _getLearnerForValidation(learnerId);
    if (learner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load learner profile. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final missingFieldLabels = _getMissingRequiredProfileFieldLabels(learner);
    final missingFieldKeys = _getMissingRequiredProfileFieldKeys(learner);
    if (missingFieldLabels.isEmpty) {
      return true;
    }

    final learnerIdInt = int.tryParse(learnerId);
    if (learnerIdInt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid learner ID for profile completion.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final shouldOpenProfile = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Complete Learner Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This learner profile is incomplete. Please fill in missing fields and press Update Data before clock-in.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Missing fields:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ...missingFieldLabels.map((field) => Text('- $field')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open Profile'),
            ),
          ],
        );
      },
    );

    if (shouldOpenProfile != true) {
      return false;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearnerDetailsPage(
          learnerID: learnerId,
          missingProfileOnlyMode: true,
          missingProfileFields: missingFieldKeys,
        ),
      ),
    );

    if (!mounted) return false;

    final refreshedLearner = await _getLearnerForValidation(learnerId);
    final refreshedMissing =
        _getMissingRequiredProfileFieldLabels(refreshedLearner ?? {});

    if (refreshedMissing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile still incomplete: ${refreshedMissing.join(', ')}. Please update before clock-in.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return false;
    }

    return true;
  }

  Future<bool> _ensureLearnerBankDetailsComplete(String learnerId) async {
    print(
        '[BACKUP] Bank check skipped in backup mode - not required for clock-in');
    // Bank details validation is optional in backup clock-in mode
    // The focus is on attendance tracking, not payment processing
    return true;
  }

  Future<bool> _checkDocumentCompleteness(String learnerId) async {
    print('[BACKUP] Checking documents for learner $learnerId');

    while (true) {
      // Get detailed document statuses (not just missing, but with status info)
      final docStatuses = await _getDetailedDocumentStatuses(learnerId);

      if (docStatuses['allApproved'] == true) {
        return true; // All 3 mandatory docs are approved
      }

      final List<Map<String, dynamic>> problemDocs =
          docStatuses['documents'] ?? [];

      final action = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.block, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Expanded(child: Text('Clock-In Blocked')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.assignment_late,
                            color: Colors.orange, size: 32),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'All 3 required documents must be approved',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Document statuses:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  ...problemDocs.map((doc) {
                    final docName = doc['name'] ?? '';
                    final status = doc['status'] ?? 'Not Uploaded';
                    final reason = doc['reason'];

                    Color iconColor = Colors.orange;
                    IconData icon = Icons.error_outline;
                    if (status == 'Declined') {
                      iconColor = Colors.red;
                      icon = Icons.cancel;
                    } else if (status == 'Not Uploaded') {
                      iconColor = Colors.grey;
                      icon = Icons.upload_file;
                    }

                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(icon, color: iconColor, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      docName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: iconColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Show Re-upload button ONLY for Declined docs
                              if (status == 'Declined')
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop({
                                    'action': 'reupload',
                                    'document': docName,
                                  }),
                                  icon: Icon(Icons.upload, size: 16),
                                  label: Text('Re-upload'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                ),
                            ],
                          ),
                          if (reason != null &&
                              reason.toString().isNotEmpty) ...[
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Reason: $reason',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.block, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You cannot clock in until all documents are approved.',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please contact your administrator for document approval.',
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop({'action': 'ok'}),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (action != null && action['action'] == 'reupload') {
        // Handle re-upload for declined document
        final docName = action['document'];
        await _handleDocumentReupload(learnerId, docName);
        continue; // Check again after re-upload
      }

      // User clicked OK - block clock-in
      return false;
    }
  }

  Future<void> _handleDocumentReupload(String learnerId, String docName) async {
    // Navigate to learner details page for document re-upload
    print('[BACKUP_DOCUMENTS] Re-upload requested for: $docName');

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearnerDetailsPage(
          learnerID: learnerId,
          missingProfileOnlyMode: false,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getDetailedDocumentStatuses(
      String learnerId) async {
    try {
      // Check connectivity
      bool isOnline = false;
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        isOnline = false;
      }

      if (!isOnline) {
        // Offline: assume local docs are approved
        return {'allApproved': true, 'documents': []};
      }

      final response = await http.post(
        Uri.parse(AppConfig.buildUrl('get_document_statuses.php')),
        body: {'learner_id': learnerId},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        return {'allApproved': false, 'documents': []};
      }

      final decoded = json.decode(response.body);
      if (decoded['success'] != true) {
        return {'allApproved': false, 'documents': []};
      }

      final docsMap = decoded['documents'] as Map<String, dynamic>?;
      if (docsMap == null) {
        return {'allApproved': false, 'documents': []};
      }

      // Check each required document
      final List<Map<String, dynamic>> problemDocs = [];

      for (final requiredDoc in _requiredDocuments) {
        final normalizedName = requiredDoc.trim().toLowerCase();

        // Find matching document in response
        Map<String, dynamic>? docInfo;
        for (final entry in docsMap.entries) {
          if (entry.key.trim().toLowerCase() == normalizedName) {
            docInfo = entry.value as Map<String, dynamic>?;
            break;
          }
        }

        if (docInfo == null) {
          // Document not uploaded
          problemDocs.add({
            'name': requiredDoc,
            'status': 'Not Uploaded',
            'reason': null,
          });
        } else {
          final status = docInfo['status']?.toString() ?? 'Pending';
          if (status.toLowerCase() != 'approved') {
            // Document is Pending or Declined
            problemDocs.add({
              'name': requiredDoc,
              'status': status,
              'reason': docInfo['rejection_reason'],
            });
          }
        }
      }

      return {
        'allApproved': problemDocs.isEmpty,
        'documents': problemDocs,
      };
    } catch (e) {
      print('[BACKUP_DOCUMENTS] Error fetching detailed statuses: $e');
      return {'allApproved': false, 'documents': []};
    }
  }

  final List<String> _requiredDocuments = const [
    'ID Document',
    'Qualifications',
    'Proof of Residence',
  ];

  Future<void> _showClockingDaysPopup(String learnerId, String action) async {
    // Placeholder - implement clocking days display
    print(
        '[BACKUP] Showing clocking days for learner $learnerId, action: $action');
    // TODO: Implement actual clocking days popup
  }

  Future<bool> _verifyLearnerID(String learnerId) async {
    Map<String, dynamic>? learner;
    try {
      learner = widget.learners.firstWhere(
        (l) => (l as Map<String, dynamic>)['LearnerID'].toString() == learnerId,
      ) as Map<String, dynamic>;
    } catch (e) {
      learner = null;
    }

    if (learner == null || learner.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Learner not found'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final idNumber = learner['IDNumber']?.toString() ?? '';
    final TextEditingController idController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Verify ID Number'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Learner: ${learner!['Name']} ${learner['Surname']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Please enter the learner\'s ID number to confirm:'),
              const SizedBox(height: 8),
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: 'ID Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (idController.text.trim() == idNumber) {
                  Navigator.of(context).pop(true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ID number does not match!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<String?> _captureSignature(String learnerId) async {
    _signatureController.clear();

    Map<String, dynamic>? learner;
    try {
      learner = widget.learners.firstWhere(
        (l) => (l as Map<String, dynamic>)['LearnerID'].toString() == learnerId,
      ) as Map<String, dynamic>;
    } catch (e) {
      learner = null;
    }

    if (learner == null) {
      return null;
    }

    final signature = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Signature: ${learner!['Name']} ${learner['Surname']}'),
          content: SizedBox(
            width: 300,
            height: 200,
            child: Column(
              children: [
                const Text('Please sign below:'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Signature(
                    controller: _signatureController,
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _signatureController.clear();
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_signatureController.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a signature'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final bytes = await _signatureController.toPngBytes();
                if (bytes != null) {
                  final base64Signature = base64Encode(bytes);
                  Navigator.of(context).pop(base64Signature);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    return signature;
  }

  Future<bool> _verifyGeofenceAndGPS(String learnerId) async {
    print('[BACKUP] Verifying geofence and GPS for learner $learnerId...');

    try {
      // Get secure GPS position
      setState(() => _currentStep = 'gps_check');

      final securePosition = await SecureLocationService.getSecurePosition();

      // Check if position is trusted
      if (!securePosition.isTrusted) {
        _showErrorDialog(
          'Location Not Trusted',
          'Your GPS location could not be verified. Please ensure:\n'
              '• GPS is enabled\n'
              '• You are outdoors with clear sky view\n'
              '• Mock locations are disabled\n'
              '• Battery saver is disabled for RLMSS',
        );
        return false;
      }

      // Verify geofence with server
      final geofenceResult = await SecureLocationService.verifyGeofenceOnServer(
        securePosition: securePosition,
        classID: widget.classID,
        learnerID: learnerId, // Pass actual learner ID
        action: 'clock_in',
        baseUrl: AppConfig.baseUrl,
      );

      if (geofenceResult['success'] != true) {
        final errorMsg =
            geofenceResult['error'] ?? 'Geofence verification failed';
        final distance = geofenceResult['distance'];
        final effectiveRadius = geofenceResult['effective_radius'];

        String detailedError = errorMsg;
        if (distance != null && effectiveRadius != null) {
          detailedError = '$errorMsg\n\n'
              'Distance: ${distance.toStringAsFixed(0)}m\n'
              'Required: Within ${effectiveRadius.toStringAsFixed(0)}m\n'
              'GPS Accuracy: ${securePosition.position.accuracy.toStringAsFixed(0)}m';
        } else {
          detailedError = '$errorMsg\n\n'
              'GPS Accuracy: ${securePosition.position.accuracy.toStringAsFixed(0)}m';
        }

        _showErrorDialog('Outside Geofence', detailedError);
        return false;
      }

      print('[BACKUP] ✅ Geofence and GPS verification passed');
      return true;
    } catch (e) {
      print('[BACKUP] ❌ Geofence/GPS error: $e');
      _showErrorDialog(
        'Location Error',
        'Could not verify your location: $e\n\n'
            'Please ensure GPS is enabled and try again.',
      );
      return false;
    }
  }

  Future<void> _submitBackupClockIn(
      String learnerId, String signatureData) async {
    print('[BACKUP] Submitting clock-in for learner $learnerId WITH SIGNATURE');

    try {
      final now = _getCurrentTimeString();
      final date = _getCurrentDateString();

      // CHECK FOR DUPLICATES - prevent creating duplicate records locally
      final existingRecord =
          await DatabaseHelper().getAttendanceForDay(learnerId, date);
      if (existingRecord != null && existingRecord['clock_in_time'] != null) {
        print(
            '[BACKUP] ⚠️ Clock-in record already exists for today - skipping duplicate insert');
        throw Exception('You have already clocked in today');
      }

      // Save clock-in signature image to local file
      final clockInSignatureFilename =
          await _saveSignatureLocally(learnerId, signatureData, suffix: 'in');
      print(
          '[BACKUP] Clock-in signature saved with filename: $clockInSignatureFilename');

      // Prepare database record WITH clock-in signature
      final dbData = {
        'LearnerID': learnerId,
        'clock_in_time': now,
        'clock_out_time': '', // Empty for clock-in
        'contact_time': '', // Empty for clock-in
        'clock_date': date,
        'signature': clockInSignatureFilename, // Clock-in signature
        'synced': 0, // Mark as not synced (offline first)
      };

      // Try to sync to server if online
      bool synced = false;
      try {
        final response = await http.post(
          Uri.parse(AppConfig.buildUrl('clocking/clockin.php')),
          body: {
            'clock_in': '1',
            'LearnerID': learnerId,
            'clock_in_time': now,
            'clock_date': date,
            'classID': widget.classID,
            'signature': clockInSignatureFilename,
            'method': 'manual',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          synced = decoded['success'] == true;
          if (synced) {
            print('[BACKUP] ✅ Clock-in saved to server');
          }
        }
      } catch (e) {
        print('[BACKUP] ⚠️ Server sync failed (will retry later): $e');
      }

      // Update synced flag
      dbData['synced'] = synced ? 1 : 0;

      // Insert into local database with clock-in signature - NO DUPLICATES
      await DatabaseHelper().insertClocking(dbData);
      print('[BACKUP] ✅ Clock-in saved to local database WITH signature');
    } catch (e) {
      print('[BACKUP] ❌ Error saving clock-in: $e');
      rethrow;
    }
  }

  Future<void> _submitBackupClockOut(
      String learnerId, String signatureData) async {
    print(
        '[BACKUP] Submitting clock-out for learner $learnerId WITH SIGNATURE');

    try {
      final now = _getCurrentTimeString();
      final date = _getCurrentDateString();

      // Save clock-out signature image to local file (TWO per day: clock-in + clock-out)
      final clockOutSignatureFilename =
          await _saveSignatureLocally(learnerId, signatureData, suffix: 'out');
      print(
          '[BACKUP] Clock-out signature saved with filename: $clockOutSignatureFilename');

      // Get existing attendance record (created at clock-in WITH clock-in signature)
      final existingAttendance =
          await DatabaseHelper().getAttendanceForDay(learnerId, date);

      if (existingAttendance == null ||
          existingAttendance['clock_in_time'] == null) {
        throw Exception('No clock-in record found for today');
      }

      final clockInTime = existingAttendance['clock_in_time'].toString();
      final clockingId = existingAttendance['clocking_id'];
      final contactTime = _calculateContactTime(clockInTime, now);
      final clockInSignature =
          existingAttendance['signature']?.toString() ?? '';

      // Try to sync to server first
      bool synced = false;
      try {
        final response = await http.post(
          Uri.parse(AppConfig.buildUrl('clocking/clockout.php')),
          body: {
            'clock_out': '1',
            'LearnerID': learnerId,
            'clock_in_time': clockInTime,
            'clock_out_time': now,
            'contact_time': contactTime,
            'clock_date': date,
            'classID': widget.classID,
            'method': 'signature',
            'signature_in': clockInSignature, // Clock-in signature
            'signature_out': clockOutSignatureFilename, // Clock-out signature
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          synced = decoded['success'] == true;
          if (synced) {
            print('[BACKUP] ✅ Clock-out with signature saved to server');
          }
        }
      } catch (e) {
        print('[BACKUP] ⚠️ Server sync failed (will retry later): $e');
      }

      // Update database record with clock-out time AND clock-out signature ONLY
      // Replace clock-in signature with clock-out signature (keep only the last one)
      final updatedAttendance = {
        'clock_out_time': now,
        'contact_time': contactTime,
        'signature':
            clockOutSignatureFilename, // Store ONLY clock-out signature (replaces clock-in)
        'synced': synced ? 1 : 0,
      };

      await DatabaseHelper().updateClocking(clockingId, updatedAttendance);
      print(
          '[BACKUP] ✅ Clock-out saved to local database with clock-out signature (synced=$synced)');
    } catch (e) {
      print('[BACKUP] ❌ Error saving clock-out: $e');
      rethrow;
    }
  }

  String _getCurrentTimeString() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 2)); // SAST
    return DateFormat('HH:mm:ss').format(now);
  }

  String _getCurrentDateString() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 2)); // SAST
    return DateFormat('yyyy-MM-dd').format(now);
  }

  String _calculateContactTime(String clockInTime, String clockOutTime) {
    try {
      final today = DateTime.now().toUtc().add(const Duration(hours: 2));
      final dateStr = DateFormat('yyyy-MM-dd').format(today);

      final clockIn = DateTime.parse('$dateStr $clockInTime');
      final clockOut = DateTime.parse('$dateStr $clockOutTime');

      final duration = clockOut.difference(clockIn);
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);

      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:00';
    } catch (e) {
      print('[BACKUP] Error calculating contact time: $e');
      return '00:00:00';
    }
  }

  /// ========== PROFILE VALIDATION HELPERS ==========

  Future<Map<String, dynamic>?> _getLearnerForValidation(
      String learnerId) async {
    // Prefer local DB — profile edits are saved locally first
    final localLearner = await DatabaseHelper().getLearnerById(learnerId);
    bool hasUnsyncedChanges =
        localLearner != null && localLearner['synced'] == 0;

    if (localLearner != null) {
      print('[BACKUP] _getLearnerForValidation for learnerId $learnerId');
    }

    // Always return local data if available!
    if (localLearner != null) {
      return localLearner;
    }

    return null;
  }

  List<String> _getMissingRequiredProfileFieldLabels(
      Map<String, dynamic> learner) {
    final missing = <String>[];
    for (final rule in _requiredProfileRules) {
      if (_isRuleMissing(learner, rule.keys)) {
        missing.add(rule.label);
      }
    }
    return missing;
  }

  List<String> _getMissingRequiredProfileFieldKeys(
      Map<String, dynamic> learner) {
    final missingKeys = <String>[];
    for (final rule in _requiredProfileRules) {
      if (!_isRuleMissing(learner, rule.keys)) continue;
      final bestKey = _resolveBestFieldKey(learner, rule.keys);
      missingKeys.add(bestKey);
    }
    return missingKeys;
  }

  bool _isRuleMissing(Map<String, dynamic> learner, List<String> keys) {
    for (final key in keys) {
      final value = learner[key];
      if (!isMissingValue(value)) {
        return false;
      }
    }
    return true;
  }

  String _resolveBestFieldKey(Map<String, dynamic> learner, List<String> keys) {
    for (final key in keys) {
      if (learner.containsKey(key)) {
        return key;
      }
    }
    return keys.first;
  }

  bool isMissingValue(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized.isEmpty ||
        normalized == 'null' ||
        normalized == 'n/a' ||
        normalized == 'na' ||
        normalized == '-' ||
        normalized == 'unknown' ||
        normalized.startsWith('1900-01-01');
  }

  final List<_RequiredProfileRule> _requiredProfileRules = const [
    _RequiredProfileRule(label: 'Title', keys: ['Title']),
    _RequiredProfileRule(label: 'Name', keys: ['Name']),
    _RequiredProfileRule(label: 'Surname', keys: ['Surname']),
    _RequiredProfileRule(label: 'ID Number', keys: ['IDNumber']),
    _RequiredProfileRule(label: 'Race', keys: ['Race']),
    _RequiredProfileRule(label: 'Language', keys: ['Language']),
    _RequiredProfileRule(label: 'Disability', keys: ['Disability']),
    _RequiredProfileRule(
        label: 'Cellphone Number', keys: ['CellphoneNumber', 'PhoneNumber']),
    _RequiredProfileRule(label: 'Email', keys: ['Email']),
    _RequiredProfileRule(label: 'Address Line 1', keys: ['AddressLine1']),
    _RequiredProfileRule(label: 'Address Line 2', keys: ['AddressLine2']),
    _RequiredProfileRule(label: 'Address Line 3', keys: ['AddressLine3']),
    _RequiredProfileRule(label: 'Postal Code', keys: ['PostalCode']),
    _RequiredProfileRule(label: 'Next of Kin Name', keys: ['KinName']),
    _RequiredProfileRule(label: 'Next of Kin Relation', keys: ['KinRelation']),
    _RequiredProfileRule(label: 'Next of Kin Contact', keys: ['KinContact']),
    _RequiredProfileRule(label: 'School Name', keys: ['SchoolName']),
    _RequiredProfileRule(
        label: 'School Completion', keys: ['SchoolCompletion']),
    _RequiredProfileRule(label: 'School Location', keys: ['SchoolLocation']),
    _RequiredProfileRule(label: 'School Grade', keys: ['SchoolGrade']),
    _RequiredProfileRule(label: 'Profile Image', keys: ['profile_image']),
    _RequiredProfileRule(label: 'Learner Signature', keys: ['signature']),
  ];

  /// Sync all signature files from local folder to server
  Future<void> _syncAllSignaturesToServer() async {
    try {
      print('[SIGNATURE_SYNC] Starting signature sync...');

      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final signaturesDir = Directory('${directory.path}/signatures');

      // Check if signatures folder exists
      if (!await signaturesDir.exists()) {
        print('[SIGNATURE_SYNC] No signatures folder found');
        return;
      }

      // List all PNG files in signatures folder
      final signatureFiles = signaturesDir
          .listSync()
          .where((file) => file.path.endsWith('.png'))
          .map((file) => File(file.path))
          .toList();

      print('[SIGNATURE_SYNC] Found ${signatureFiles.length} signature files');

      if (signatureFiles.isEmpty) {
        print('[SIGNATURE_SYNC] No signatures to sync');
        return;
      }

      int successCount = 0;
      int failCount = 0;

      // Sync each signature file
      for (final signatureFile in signatureFiles) {
        try {
          final filename = signatureFile.path.split('/').last;

          // Skip if not valid signature filename format
          if (!filename.startsWith('signature_') ||
              !filename.endsWith('.png')) {
            print('[SIGNATURE_SYNC] Skipping invalid filename: $filename');
            continue;
          }

          // Read file bytes
          final bytes = await signatureFile.readAsBytes();

          // Create multipart request
          final request = http.MultipartRequest(
            'POST',
            Uri.parse(AppConfig.syncSignaturesUrl),
          );

          // Add filename parameter
          request.fields['filename'] = filename;

          // Add file
          request.files.add(http.MultipartFile.fromBytes(
            'signature',
            bytes,
            filename: filename,
          ));

          // Send request
          final response =
              await request.send().timeout(const Duration(seconds: 30));
          final responseBody = await response.stream.bytesToString();

          if (response.statusCode == 200) {
            final decoded = json.decode(responseBody);
            if (decoded['success'] == true) {
              print(
                  '[SIGNATURE_SYNC] ✅ Synced: $filename (${bytes.length} bytes)');
              successCount++;

              // Optionally delete local file after successful sync (commented out for safety)
              // await signatureFile.delete();
              // print('[SIGNATURE_SYNC] Deleted local file: $filename');
            } else {
              print(
                  '[SIGNATURE_SYNC] ❌ Server rejected: $filename - ${decoded['message']}');
              failCount++;
            }
          } else {
            print(
                '[SIGNATURE_SYNC] ❌ HTTP ${response.statusCode} for: $filename');
            failCount++;
          }
        } catch (e) {
          print('[SIGNATURE_SYNC] ❌ Error syncing file: $e');
          failCount++;
        }

        // Small delay between uploads to avoid overwhelming server
        await Future.delayed(const Duration(milliseconds: 500));
      }

      print(
          '[SIGNATURE_SYNC] Complete: $successCount succeeded, $failCount failed');
    } catch (e) {
      print('[SIGNATURE_SYNC] ❌ Fatal error: $e');
    }
  }

  /// Save signature PNG to local device storage (TWO per day: clock-in and clock-out)
  /// Returns ONLY the filename (not full path) for database storage
  Future<String> _saveSignatureLocally(String learnerId, String base64Signature,
      {String suffix = 'out'}) async {
    try {
      // Decode base64 to bytes
      final bytes = base64Decode(base64Signature);

      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();

      // Create signatures folder if it doesn't exist
      final signaturesDir = Directory('${directory.path}/signatures');
      if (!await signaturesDir.exists()) {
        await signaturesDir.create(recursive: true);
        print('[BACKUP] Created signatures directory: ${signaturesDir.path}');
      }

      // Generate unique filename: signature_{ID}_{YYYYMMDD_HHMMSS}_{in/out}.png
      final now = DateTime.now();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(now);
      final filename = 'signature_${learnerId}_${timestamp}_$suffix.png';
      final filePath = '${signaturesDir.path}/$filename';

      // Write PNG file
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      print('[BACKUP] Signature saved: $filePath (${bytes.length} bytes)');

      // Return ONLY the filename (not the full path)
      return filename;
    } catch (e) {
      print('[BACKUP] Error saving signature locally: $e');
      // Return empty string if save fails (graceful degradation)
      return '';
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _RequiredProfileRule {
  final String label;
  final List<String> keys;

  const _RequiredProfileRule({
    required this.label,
    required this.keys,
  });
}
