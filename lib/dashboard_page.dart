import 'package:flutter/material.dart';
import 'dart:async';
import 'LearnerListPage.dart';
import 'LearningMaterialFormPage.dart';
import 'database_helper.dart';
import 'FacilitatorProfile.dart';
import 'MaterialForm.dart';
import 'clock_in_page.dart';
import 'contact_less.dart';
import 'services/fingerprint_service.dart';
import 'sync_service.dart' show syncSingleClockIn, syncSingleClockOut;
import 'EnrollmentPage.dart';
import 'facilitator_fingerprint_page.dart';
import 'attendance_page.dart';
import 'monitoring_service.dart';
// import 'random_prompt_service.dart';
// import 'random_biometric_prompt_page.dart';
// import 'package:geolocator/geolocator.dart';  // Temporarily commented out
//import 'contact_less_clock_in_page.dart';

class DashboardPage extends StatefulWidget {
  final String classID;
  final List<dynamic> learners;

  const DashboardPage({
    super.key,
    required this.classID,
    required this.learners,
  });

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<Map<String, dynamic>>? classData;
  List<dynamic> currentLearners = [];

  // Fingerprint services
  late FingerprintService _fingerprintService;

  // 1:N verification state
  bool _isScanning = false;
  StreamSubscription? _enrollSuccessSubscription;

  @override
  void initState() {
    super.initState();

    print(
        "[DASHBOARD] Initializing dashboard with classID: '${widget.classID}'");
    print("[DASHBOARD] Initial learners count: ${widget.learners.length}");
    print("[DASHBOARD] Initial learners data: ${widget.learners}");

    // Check if initial learners have any fingerprint data
    int initialLearnersWithFingerprints = 0;
    for (var learner in widget.learners) {
      final hasAnyFingerprint =
          (learner['zkteco_left_template']?.isNotEmpty == true) ||
              (learner['zkteco_right_template']?.isNotEmpty == true) ||
              (learner['futronic_left_template']?.isNotEmpty == true) ||
              (learner['futronic_right_template']?.isNotEmpty == true);
      if (hasAnyFingerprint) initialLearnersWithFingerprints++;
    }
    print(
        "[DASHBOARD] ⚠️  Initial learners with fingerprints: $initialLearnersWithFingerprints");

    currentLearners = widget.learners;

    // Initialize fingerprint services
    _initializeFingerprintServices();

    // Start monitoring service for random biometric verification
    MonitoringService().startService(context, widget.classID);
    print(
        "[DASHBOARD] ✅ Monitoring service started for class: ${widget.classID}");

    reloadClassData();

    // Reload after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        reloadClassData();
      }
    });
  }

  @override
  void dispose() {
    print(
        '[DASHBOARD] ⚠️  DISPOSING DASHBOARD PAGE - This should only happen during intended logout!');
    print('[DASHBOARD] Stack trace during dispose: ${StackTrace.current}');
    print('[DASHBOARD] Current mounted state: $mounted');
    print('[DASHBOARD] Is scanning: $_isScanning');

    // Stop monitoring service
    MonitoringService().stopService();
    print('[DASHBOARD] ✅ Monitoring service stopped');

    _enrollSuccessSubscription?.cancel();
    super.dispose();
  }

  void _initializeFingerprintServices() {
    _fingerprintService = FingerprintService();

    // Listen for fingerprint scan results (for ZKTeco scanner)
    _enrollSuccessSubscription =
        _fingerprintService.enrollSuccessStream.listen((capturedData) async {
      if (!mounted || !_isScanning) return;

      final scannedTemplate = capturedData['template'] as String?;
      if (scannedTemplate != null) {
        await _performOneToNVerification(scannedTemplate);
      }
    });
  }

  Future<void> reloadClassData({String? overrideClassID}) async {
    try {
      print(
          "[DASHBOARD] Starting to reload class data for classID: ${widget.classID}");
      print("[DASHBOARD] Widget mounted state at start: $mounted");

      print("[DASHBOARD] About to call fetchClassData");
      final data = await fetchClassData(widget.classID);
      print("[DASHBOARD] Raw class data fetched: $data");
      print("[DASHBOARD] Data fetch completed, widget still mounted: $mounted");

      final effectiveClassID = overrideClassID ?? widget.classID;
      print(
          "[DASHBOARD] About to call getLearnersWithClockingData for classID: $effectiveClassID");
      final learnersData =
          await DatabaseHelper().getLearnersWithClockingData(effectiveClassID);
      print("[DASHBOARD] Raw learners data fetched: $learnersData");
      print("[DASHBOARD] Learners data count: ${learnersData.length}");
      print("[DASHBOARD] ClassID being used: ${widget.classID}");

      // Debug why we might have 0 learners
      if (learnersData.isEmpty) {
        print("[DASHBOARD] ⚠️  NO LEARNERS FOUND! Debugging...");

        // Check if there are any learners in the database at all
        final db = await DatabaseHelper().database;
        final totalLearners = await db.query('learnerdetails');
        print(
            "[DASHBOARD] Total learners in database: ${totalLearners.length}");

        if (totalLearners.isNotEmpty) {
          // Show first few learners and their classIDs
          print("[DASHBOARD] First 5 learners in database:");
          for (int i = 0; i < totalLearners.length && i < 5; i++) {
            final learner = totalLearners[i];
            print(
                "[DASHBOARD]   ${learner['LearnerID']} (${learner['Name']} ${learner['Surname']}) - classID: ${learner['classID']}");
          }

          // Check if any learners match our classID
          final matchingClassLearners = await db.query(
            'learnerdetails',
            where: 'classID = ?',
            whereArgs: [widget.classID],
          );
          print(
              "[DASHBOARD] Learners matching classID ${widget.classID}: ${matchingClassLearners.length}");

          if (matchingClassLearners.isEmpty) {
            // Check what classIDs exist
            final distinctClasses = await db.rawQuery(
                'SELECT DISTINCT classID FROM learnerdetails WHERE classID IS NOT NULL');
            print(
                "[DASHBOARD] Available classIDs in database: ${distinctClasses.map((e) => e['classID']).toList()}");
          }
        }
      }

      print(
          "[DASHBOARD] Learners fetch completed, widget still mounted: $mounted");

      // Debug fingerprint data for first few learners
      for (int i = 0; i < learnersData.length && i < 3; i++) {
        final learner = learnersData[i];
        final learnerId = learner['LearnerID'];
        final name = learner['Name'];
        final surname = learner['Surname'];
        final zkLeft = learner['zkteco_left_template']?.toString() ?? '';
        final zkRight = learner['zkteco_right_template']?.toString() ?? '';
        final futLeft = learner['futronic_left_template']?.toString() ?? '';
        final futRight = learner['futronic_right_template']?.toString() ?? '';

        print("[DASHBOARD_DEBUG] Learner $learnerId ($name $surname):");
        print("[DASHBOARD_DEBUG]   ZKTeco Left: ${zkLeft.length} chars");
        print("[DASHBOARD_DEBUG]   ZKTeco Right: ${zkRight.length} chars");
        print("[DASHBOARD_DEBUG]   Futronic Left: ${futLeft.length} chars");
        print("[DASHBOARD_DEBUG]   Futronic Right: ${futRight.length} chars");
      }

      if (data.isEmpty) {
        print("[DASHBOARD] WARNING: Class data is empty!");
      }

      print("[DASHBOARD] Checking mounted state before setState: $mounted");
      if (mounted) {
        print("[DASHBOARD] About to call setState");
        setState(() {
          print("[DASHBOARD] Inside setState");
          classData = Future.value(data);
          currentLearners = learnersData.map((learner) {
            return {
              'LearnerID': learner['LearnerID']?.toString() ?? 'N/A',
              'Name': learner['Name']?.toString() ?? 'N/A',
              'Surname': learner['Surname']?.toString() ?? 'N/A',
              'clock_in_time': learner['clock_in_time']?.toString() ?? '',
              'clock_out_time': learner['clock_out_time']?.toString() ?? '',
              'contact_time': learner['contact_time']?.toString() ?? '',
              // CRITICAL: Preserve fingerprint template data
              'zkteco_left_template':
                  learner['zkteco_left_template']?.toString() ?? '',
              'zkteco_right_template':
                  learner['zkteco_right_template']?.toString() ?? '',
              'futronic_left_template':
                  learner['futronic_left_template']?.toString() ?? '',
              'futronic_right_template':
                  learner['futronic_right_template']?.toString() ?? '',
              'sourceafis_template':
                  learner['sourceafis_template']?.toString() ?? '',
            };
          }).toList();
        });

        print("[DASHBOARD] Final class data set in state: $data");
        print("[DASHBOARD] Final learners count: ${currentLearners.length}");

        // Check if reloaded learners have fingerprint data
        int reloadedLearnersWithFingerprints = 0;
        for (var learner in currentLearners) {
          final hasAnyFingerprint =
              (learner['zkteco_left_template']?.isNotEmpty == true) ||
                  (learner['zkteco_right_template']?.isNotEmpty == true) ||
                  (learner['futronic_left_template']?.isNotEmpty == true) ||
                  (learner['futronic_right_template']?.isNotEmpty == true);
          if (hasAnyFingerprint) reloadedLearnersWithFingerprints++;
        }
        print(
            "[DASHBOARD] ✅ Reloaded learners with fingerprints: $reloadedLearnersWithFingerprints");
      }
    } catch (e) {
      print("[DASHBOARD] ERROR fetching class data or learners: $e");
      print("[DASHBOARD] Error details: ${e.toString()}");
      // Set some default data to prevent "no data found"
      if (mounted) {
        setState(() {
          classData = Future.value({
            'class_name': 'Unknown Class',
            'facilitator_name': 'Unknown',
            'class_max': '0',
            'total_learners': '0',
            'total_attendance': '0',
            'total_absent': '0',
            'site_name': 'Unknown Site',
          });
        });
      }
    }
  }

  Future<Map<String, dynamic>> _loadClassDataWithCorrectClassID(
      String correctClassID) async {
    try {
      print(
          "[DASHBOARD] Loading class data with corrected classID: $correctClassID");

      // Fetch the original class data structure but with correct learners
      final data = await fetchClassData(widget.classID);
      final learnersData =
          await DatabaseHelper().getLearnersWithClockingData(correctClassID);

      // Update the data structure with correct learners and classID
      final correctedData = Map<String, dynamic>.from(data);
      correctedData['classID'] = correctClassID;
      correctedData['learners'] = learnersData.map((learner) {
        return {
          'LearnerID': learner['LearnerID']?.toString() ?? 'N/A',
          'Name': learner['Name']?.toString() ?? 'N/A',
          'Surname': learner['Surname']?.toString() ?? 'N/A',
          'clock_in_time': learner['clock_in_time']?.toString() ?? '',
          'clock_out_time': learner['clock_out_time']?.toString() ?? '',
          'contact_time': learner['contact_time']?.toString() ?? '',
        };
      }).toList();

      print(
          "[DASHBOARD] ✅ Corrected class data loaded with ${learnersData.length} learners");
      return correctedData;
    } catch (e) {
      print("[DASHBOARD] ❌ Error loading corrected class data: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchClassData(String classID) async {
    try {
      print(
          "[DASHBOARD] Attempting to fetch class data for classID: '$classID'");

      final result =
          await DatabaseHelper().fetchClassDetailsAndAttendance(classID);
      print("[DASHBOARD] Successfully fetched class data: $result");

      return result;
    } catch (e) {
      print("[DASHBOARD] Error in fetchClassData: $e");

      // Return default data instead of throwing exception to prevent "no data found"
      return {
        'class_name': 'Class $classID',
        'facilitator_name': 'Unknown Facilitator',
        'class_max': '0',
        'total_learners': currentLearners.length.toString(),
        'total_attendance': '0',
        'total_absent': '0',
        'site_name': 'Unknown Site',
      };
    }
  }

  // 1:N Fingerprint Verification Methods
  Future<void> _startFingerprintClocking() async {
    if (_isScanning) return;

    try {
      // Detect which scanner is available
      final scanner = await _detectScanner();
      if (scanner == 'none') {
        _showErrorDialog('Scanner Not Found',
            'No fingerprint scanner detected. Please connect a Futronic or ZKTeco scanner and try again.');
        return;
      }

      setState(() {
        _isScanning = true;
      });

      _showScanningDialog(scanner);

      if (scanner == 'futronic') {
        await _startFutronicScanning();
      } else if (scanner == 'zkteco') {
        await _startZKTecoScanning();
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      _showErrorDialog('Scan Error', 'Error starting fingerprint scan: $e');
    }
  }

  Future<String> _detectScanner() async {
    // Try ZKTeco first
    try {
      final isZkConnected = await _fingerprintService.isSensorConnected();
      if (isZkConnected) return 'zkteco';
    } catch (_) {}

    // Try Futronic with retry using the correct service
    const maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final isFutronicConnected =
            await FutronicService().isFutronicConnected();
        if (isFutronicConnected) return 'futronic';
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      } catch (_) {}
    }

    return 'none';
  }

  Future<void> _startFutronicScanning() async {
    try {
      // For Futronic, use the same approach as clock_in_page - direct verification
      await _performFutronicOneToNVerification();
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      Navigator.of(context).pop(); // Close scanning dialog
      _showErrorDialog('Futronic Error', 'Futronic scan failed: $e',
          skipPop: true);
    }
  }

  Future<void> _startZKTecoScanning() async {
    try {
      // For ZKTeco, start capture which will trigger enrollSuccessStream
      await _fingerprintService.startEnrollment('scan');
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      Navigator.of(context).pop(); // Close scanning dialog
      _showErrorDialog('ZKTeco Error', 'ZKTeco scan failed: $e', skipPop: true);
    }
  }

  Future<void> _performFutronicOneToNVerification() async {
    setState(() {
      _isScanning = false;
    });
    Navigator.of(context).pop(); // Close scanning dialog

    _showMessage(
        'Scanning completed! Verifying against class learners...', Colors.blue);

    try {
      final dbHelper = DatabaseHelper();
      String? matchedLearnerId;
      String? matchedLearnerName;

      print(
          '[1:N] Starting OPTIMIZED FUTRONIC verification against ${currentLearners.length} learners');
      print(
          '[1:N] ⚠️  DEBUG: currentLearners at verification time: ${currentLearners.length}');
      print(
          '[1:N] ⚠️  DEBUG: First 3 learners: ${currentLearners.take(3).toList()}');

      int learnersWithTemplates = 0;

      // OPTIMIZATION 1: Pre-filter learners with Futronic templates to avoid repeated DB calls
      List<Map<String, dynamic>> candidateLearners = [];

      for (final learner in currentLearners) {
        final learnerId = learner['LearnerID']?.toString();
        if (learnerId == null) continue;

        final learnerIdInt = int.tryParse(learnerId);
        if (learnerIdInt == null) continue;

        // Quick check for Futronic templates from the already loaded learner data
        final futronicLeft = learner['futronic_left_template'];
        final futronicRight = learner['futronic_right_template'];

        if ((futronicLeft != null && futronicLeft.toString().isNotEmpty) ||
            (futronicRight != null && futronicRight.toString().isNotEmpty)) {
          // ULTRA-AGGRESSIVE PRIORITY SCORING for Futronic (same as ZKTeco)
          var priority = 0;

          // PRIORITY 1: Recent activity (most important for speed)
          final clockInTime = learner['clock_in_time']?.toString() ?? '';
          if (clockInTime.isNotEmpty) {
            // Check if clocked in today (highest priority)
            final today = DateTime.now().toIso8601String().substring(0, 10);
            if (clockInTime.contains(today)) {
              priority += 100; // MAXIMUM priority for today's active learners
            } else {
              priority += 50; // High priority for recently active learners
            }
          }

          // PRIORITY 2: Template quality
          if (futronicLeft != null && futronicRight != null) {
            priority += 20; // Both templates available
          } else if (futronicLeft != null || futronicRight != null) {
            priority += 10; // Single template available
          }

          // PRIORITY 3: Template size (better quality)
          if (futronicLeft != null && futronicLeft.toString().length > 200) {
            priority += 5;
          }
          if (futronicRight != null && futronicRight.toString().length > 200) {
            priority += 5;
          }

          candidateLearners.add({
            'learnerId': learnerId,
            'learnerIdInt': learnerIdInt,
            'name': '${learner['Name']} ${learner['Surname']}',
            'learnerData': learner,
            'leftTemplate': futronicLeft?.toString(),
            'rightTemplate': futronicRight?.toString(),
            '_priority': priority,
          });
          learnersWithTemplates++;
        }
      }

      print(
          '[1:N] Pre-filtered to ${candidateLearners.length} learners with Futronic templates');

      // OPTIMIZATION 2: Sort by ultra-aggressive priority score (activity + quality)
      candidateLearners.sort((a, b) {
        // Primary sort: Priority score (activity + template quality)
        final priorityA = a['_priority'] ?? 0;
        final priorityB = b['_priority'] ?? 0;
        if (priorityA != priorityB) {
          return priorityB.compareTo(priorityA); // Higher priority first
        }

        // Secondary sort: Template count
        int scoreA = 0;
        int scoreB = 0;
        if (a['leftTemplate'] != null && a['leftTemplate'].isNotEmpty) {
          scoreA += 1;
        }
        if (a['rightTemplate'] != null && a['rightTemplate'].isNotEmpty) {
          scoreA += 1;
        }
        if (b['leftTemplate'] != null && b['leftTemplate'].isNotEmpty) {
          scoreB += 1;
        }
        if (b['rightTemplate'] != null && b['rightTemplate'].isNotEmpty) {
          scoreB += 1;
        }

        return scoreB.compareTo(scoreA); // Higher scores first
      });

      // OPTIMIZATION 3: ULTRA-AGGRESSIVE - Limit to top 5 candidates for Futronic
      const maxFutronicCandidates =
          5; // ULTRA-FAST: Only check top 5 most likely candidates
      final limitedFutronicCandidates =
          candidateLearners.take(maxFutronicCandidates).toList();
      print(
          '[1:N] ⚡ FUTRONIC ULTRA-FAST: Processing only top ${limitedFutronicCandidates.length}/${candidateLearners.length} candidates');

      for (final candidate in limitedFutronicCandidates) {
        final learnerId = candidate['learnerId'];
        final learnerIdInt = candidate['learnerIdInt'];
        final learnerName = candidate['name'];
        final leftTemplate = candidate['leftTemplate'];
        final rightTemplate = candidate['rightTemplate'];

        print(
            '[1:N] ⚡ LIGHTNING-FAST checking learner: $learnerId ($learnerName)');
        print(
            '[1:N]   Left: ${leftTemplate?.isNotEmpty == true ? "YES (${leftTemplate!.length})" : "NO"}');
        print(
            '[1:N]   Right: ${rightTemplate?.isNotEmpty == true ? "YES (${rightTemplate!.length})" : "NO"}');

        try {
          bool match = false;

          // OPTIMIZATION 4: Smart template selection - use best available combination
          if (leftTemplate != null &&
              leftTemplate.isNotEmpty &&
              rightTemplate != null &&
              rightTemplate.isNotEmpty) {
            // Best case: both templates available
            final hint = 'left'; // Always start with left when both available
            print(
                '[1:N] FAST verifyBoth for learner $learnerId with hint: $hint');

            match = await FutronicService().verifyBoth(
              hintFinger: hint,
              leftTemplate: leftTemplate,
              rightTemplate: rightTemplate,
            );
            print(
                '[1:N] FAST verifyBoth result for learner $learnerId: $match');
          } else if (leftTemplate != null && leftTemplate.isNotEmpty) {
            // Left template only
            print('[1:N] FAST verify (left only) for learner $learnerId');
            match = await FutronicService().verify('left', leftTemplate);
            print(
                '[1:N] FAST verify (left) result for learner $learnerId: $match');
          } else if (rightTemplate != null && rightTemplate.isNotEmpty) {
            // Right template only
            print('[1:N] FAST verify (right only) for learner $learnerId');
            match = await FutronicService().verify('right', rightTemplate);
            print(
                '[1:N] FAST verify (right) result for learner $learnerId: $match');
          }

          if (match) {
            print('[1:N] ✅ FUTRONIC MATCH FOUND! Learner: $learnerId');
            matchedLearnerId = learnerId;
            matchedLearnerName = learnerName;
            break; // OPTIMIZATION 5: Exit immediately on first match
          }
        } catch (e) {
          print(
              '[1:N] Error in FAST Futronic verification for learner $learnerId: $e');
          continue;
        }
      }

      print('[1:N] Futronic verification summary:');
      print('[1:N]   Total learners: ${currentLearners.length}');
      print('[1:N]   Learners with Futronic templates: $learnersWithTemplates');
      print('[1:N]   Match found: ${matchedLearnerId != null}');

      // SECURITY CHECK: Ensure we have templates before allowing any match
      if (learnersWithTemplates == 0) {
        print(
            '[1:N] ⚠️  SECURITY: No learners have Futronic templates in current class');

        // AUTO-FIX: Try to load learners from classID with fingerprints
        print(
            '[1:N] 🔧 Attempting AUTO-FIX: Loading learners from correct classID...');
        final db = await DatabaseHelper().database;
        final classQuery = await db.rawQuery('''
          SELECT DISTINCT classID, COUNT(*) as learner_count
          FROM learnerdetails 
          WHERE (futronic_left_template IS NOT NULL AND futronic_left_template != '') 
             OR (futronic_right_template IS NOT NULL AND futronic_right_template != '')
          GROUP BY classID
          ORDER BY learner_count DESC
          LIMIT 1
        ''');

        if (classQuery.isNotEmpty) {
          final suggestedClassID = classQuery.first['classID']?.toString();
          if (suggestedClassID != null) {
            print(
                '[1:N] 🎯 Found classID $suggestedClassID with ${classQuery.first['learner_count']} Futronic templates');
            final learnersFromCorrectClass = await DatabaseHelper()
                .getLearnersWithClockingData(suggestedClassID);

            if (learnersFromCorrectClass.isNotEmpty) {
              print(
                  '[1:N] ✅ AUTO-FIX SUCCESS: Loaded ${learnersFromCorrectClass.length} learners from correct classID');

              // PERMANENT FIX: Update widget classID and reload all data with correct classID
              print(
                  '[1:N] 🔧 PERMANENT FIX: Switching dashboard to use classID $suggestedClassID permanently');

              // Create a new Future that uses the correct classID
              setState(() {
                // Update the class data future to use the correct classID
                classData = _loadClassDataWithCorrectClassID(suggestedClassID);
              });

              // Reload class data with the correct classID
              await reloadClassData(overrideClassID: suggestedClassID);

              print(
                  '[1:N] ✅ AUTO-FIX COMPLETE: Dashboard now permanently uses correct classID $suggestedClassID');
              return;
            }
          }
        }

        print(
            '[1:N] ❌ AUTO-FIX FAILED: No classID with Futronic templates found');
        _showVerificationFailedDialog(0, 'Futronic - No Templates Available');
        return;
      }

      if (matchedLearnerId != null && matchedLearnerName != null) {
        print(
            '[1:N] ✅ SECURE MATCH: Proceeding with verified learner $matchedLearnerId');
        await _handleMatchedLearner(matchedLearnerId, matchedLearnerName,
            scanningDialogAlreadyClosed: true);
      } else {
        _showVerificationFailedDialog(learnersWithTemplates, 'Futronic');
      }
    } catch (e) {
      print('[1:N] Futronic verification error: $e');
      _showErrorDialog(
          'Verification Error', 'Futronic verification failed: $e');
    }
  }

  Future<void> _performOneToNVerification(String scannedTemplate) async {
    setState(() {
      _isScanning = false;
    });
    Navigator.of(context).pop(); // Close scanning dialog

    _showMessage(
        'Scanning completed! Verifying against class learners...', Colors.blue);

    try {
      // This is for ZKTeco scanner - use template-based matching
      final dbHelper = DatabaseHelper();
      String? matchedLearnerId;
      String? matchedLearnerName;

      print(
          '[1:N] Starting ULTRA-FAST ZKTECO verification against ${currentLearners.length} learners');
      print('[1:N] Scanned template length: ${scannedTemplate.length}');
      print(
          '[1:N] ⚠️  DEBUG: currentLearners at verification time: ${currentLearners.length}');
      print(
          '[1:N] ⚠️  DEBUG: First 3 learners: ${currentLearners.take(3).toList()}');

      int learnersWithTemplates = 0;

      // OPTIMIZATION 1: Template pre-loading and caching (SDK Pattern)
      List<Map<String, dynamic>> candidateLearners = [];
      final startTime = DateTime.now();
      print('[1:N] ⚡ Starting template pre-loading phase...');

      for (final learner in currentLearners) {
        final learnerId = learner['LearnerID']?.toString();
        if (learnerId == null) continue;

        final learnerIdInt = int.tryParse(learnerId);
        if (learnerIdInt == null) continue;

        // Quick check for ZKTeco templates from the already loaded learner data
        final zktecoLeft = learner['zkteco_left_template'];
        final zktecoRight = learner['zkteco_right_template'];

        if ((zktecoLeft != null && zktecoLeft.toString().isNotEmpty) ||
            (zktecoRight != null && zktecoRight.toString().isNotEmpty)) {
          // ULTRA-AGGRESSIVE PRIORITY SCORING for sub-10-second verification
          var priority = 0;

          // PRIORITY 1: Recent activity (most important for speed)
          final clockInTime = learner['clock_in_time']?.toString() ?? '';
          if (clockInTime.isNotEmpty) {
            // Check if clocked in today (highest priority)
            final today = DateTime.now().toIso8601String().substring(0, 10);
            if (clockInTime.contains(today)) {
              priority += 100; // MAXIMUM priority for today's active learners
            } else {
              priority += 50; // High priority for recently active learners
            }
          }

          // PRIORITY 2: Template quality
          if (zktecoLeft != null && zktecoRight != null) {
            priority += 20; // Both templates available
          } else if (zktecoLeft != null || zktecoRight != null) {
            priority += 10; // Single template available
          }

          // PRIORITY 3: Template size (better quality)
          if (zktecoLeft != null && zktecoLeft.toString().length > 200) {
            priority += 5;
          }
          if (zktecoRight != null && zktecoRight.toString().length > 200) {
            priority += 5;
          }

          candidateLearners.add({
            'learnerId': learnerId,
            'learnerIdInt': learnerIdInt,
            'name': '${learner['Name']} ${learner['Surname']}',
            'learnerData': learner,
            'leftTemplate': zktecoLeft?.toString(),
            'rightTemplate': zktecoRight?.toString(),
            '_priority': priority,
          });
          learnersWithTemplates++;
        }
      }

      print(
          '[1:N] Pre-filtered to ${candidateLearners.length} learners with ZKTeco templates');

      // OPTIMIZATION 2: Sort by priority score for fastest verification
      candidateLearners.sort((a, b) {
        // Primary sort: Priority score (activity + template quality)
        final priorityA = a['_priority'] ?? 0;
        final priorityB = b['_priority'] ?? 0;
        if (priorityA != priorityB) {
          return priorityB.compareTo(priorityA); // Higher priority first
        }

        // Secondary sort: Template quality
        int templateScoreA = 0;
        int templateScoreB = 0;
        if (a['leftTemplate'] != null &&
            a['leftTemplate'].isNotEmpty &&
            a['leftTemplate'].length > 100) {
          templateScoreA += 1;
        }
        if (a['rightTemplate'] != null &&
            a['rightTemplate'].isNotEmpty &&
            a['rightTemplate'].length > 100) {
          templateScoreA += 1;
        }
        if (b['leftTemplate'] != null &&
            b['leftTemplate'].isNotEmpty &&
            b['leftTemplate'].length > 100) {
          templateScoreB += 1;
        }
        if (b['rightTemplate'] != null &&
            b['rightTemplate'].isNotEmpty &&
            b['rightTemplate'].length > 100) {
          templateScoreB += 1;
        }

        return templateScoreB.compareTo(templateScoreA);
      });

      // OPTIMIZATION 3: ULTRA-AGGRESSIVE - Drastically limit candidates for sub-10-second verification
      const maxCandidates =
          5; // ULTRA-FAST: Only check top 5 most likely candidates
      final limitedCandidates = candidateLearners.take(maxCandidates).toList();
      final preloadTime = DateTime.now().difference(startTime).inMilliseconds;
      print(
          '[1:N] ⚡ TEMPLATE PRE-LOAD COMPLETE: ${preloadTime}ms for ${limitedCandidates.length}/${candidateLearners.length} candidates');

      // OPTIMIZATION 3: Single-attempt verification with best template selection
      for (final candidate in candidateLearners) {
        final learnerId = candidate['learnerId'];
        final learnerIdInt = candidate['learnerIdInt'];
        final learnerName = candidate['name'];
        final leftTemplate = candidate['leftTemplate'];
        final rightTemplate = candidate['rightTemplate'];

        print('[1:N] FAST checking learner: $learnerId ($learnerName)');

        // Validate template quality
        bool hasValidLeft = leftTemplate != null &&
            leftTemplate.isNotEmpty &&
            leftTemplate.length > 100;
        bool hasValidRight = rightTemplate != null &&
            rightTemplate.isNotEmpty &&
            rightTemplate.length > 100;

        print(
            '[1:N] Template validation - Left: $hasValidLeft, Right: $hasValidRight');

        if (!hasValidLeft && !hasValidRight) {
          print('[1:N] No valid templates found for learner $learnerId');
          continue;
        }

        try {
          bool match = false;

          // OPTIMIZATION 4: Smart template selection - try best template first
          if (hasValidLeft && hasValidRight) {
            // Try left first (typically better quality)
            print('[1:N] FAST ZKTeco verify (left) for learner $learnerId');
            try {
              match = await _fingerprintService.verify('left', leftTemplate!);
              print('[1:N] FAST ZKTeco left verify result: $match');
            } catch (e) {
              print('[1:N] FAST ZKTeco left verify error: $e');
            }

            // If left fails, try right
            if (!match) {
              print('[1:N] FAST ZKTeco verify (right) for learner $learnerId');
              try {
                match =
                    await _fingerprintService.verify('right', rightTemplate!);
                print('[1:N] FAST ZKTeco right verify result: $match');
              } catch (e) {
                print('[1:N] FAST ZKTeco right verify error: $e');
              }
            }
          } else if (hasValidLeft) {
            // Left template only
            print(
                '[1:N] FAST ZKTeco verify (left only) for learner $learnerId');
            try {
              match = await _fingerprintService.verify('left', leftTemplate!);
              print('[1:N] FAST ZKTeco left verify result: $match');
            } catch (e) {
              print('[1:N] FAST ZKTeco left verify error: $e');
            }
          } else if (hasValidRight) {
            // Right template only
            print(
                '[1:N] FAST ZKTeco verify (right only) for learner $learnerId');
            try {
              match = await _fingerprintService.verify('right', rightTemplate!);
              print('[1:N] FAST ZKTeco right verify result: $match');
            } catch (e) {
              print('[1:N] FAST ZKTeco right verify error: $e');
            }
          }

          if (match) {
            print('[1:N] ✅ ZKTECO MATCH FOUND! Learner: $learnerId');
            matchedLearnerId = learnerId;
            matchedLearnerName = learnerName;
            break; // OPTIMIZATION 5: Exit immediately on first match
          }
        } catch (e) {
          print(
              '[1:N] Error in FAST ZKTeco verification for learner $learnerId: $e');
          continue;
        }
      }

      print('[1:N] ZKTeco verification summary:');
      print('[1:N]   Total learners: ${currentLearners.length}');
      print('[1:N]   Learners with ZKTeco templates: $learnersWithTemplates');
      print('[1:N]   Match found: ${matchedLearnerId != null}');

      // SECURITY CHECK: Ensure we have templates before allowing any match
      if (learnersWithTemplates == 0) {
        print(
            '[1:N] ⚠️  SECURITY: No learners have ZKTeco templates in current class');

        // AUTO-FIX: Try to load learners from classID with fingerprints
        print(
            '[1:N] 🔧 Attempting AUTO-FIX: Loading learners from correct classID...');
        final db = await DatabaseHelper().database;
        final classQuery = await db.rawQuery('''
          SELECT DISTINCT classID, COUNT(*) as learner_count
          FROM learnerdetails 
          WHERE (zkteco_left_template IS NOT NULL AND zkteco_left_template != '') 
             OR (zkteco_right_template IS NOT NULL AND zkteco_right_template != '')
          GROUP BY classID
          ORDER BY learner_count DESC
          LIMIT 1
        ''');

        if (classQuery.isNotEmpty) {
          final suggestedClassID = classQuery.first['classID']?.toString();
          if (suggestedClassID != null) {
            print(
                '[1:N] 🎯 Found classID $suggestedClassID with ${classQuery.first['learner_count']} ZKTeco templates');
            final learnersFromCorrectClass = await DatabaseHelper()
                .getLearnersWithClockingData(suggestedClassID);

            if (learnersFromCorrectClass.isNotEmpty) {
              print(
                  '[1:N] ✅ AUTO-FIX SUCCESS: Loaded ${learnersFromCorrectClass.length} learners from correct classID');

              // PERMANENT FIX: Update widget classID and reload all data with correct classID
              print(
                  '[1:N] 🔧 PERMANENT FIX: Switching dashboard to use classID $suggestedClassID permanently');

              // Create a new Future that uses the correct classID
              setState(() {
                // Update the class data future to use the correct classID
                classData = _loadClassDataWithCorrectClassID(suggestedClassID);
              });

              // Reload class data with the correct classID
              await reloadClassData(overrideClassID: suggestedClassID);

              print(
                  '[1:N] ✅ AUTO-FIX COMPLETE: Dashboard now permanently uses correct classID $suggestedClassID');
              return;
            }
          }
        }

        print(
            '[1:N] ❌ AUTO-FIX FAILED: No classID with ZKTeco templates found');
        _showVerificationFailedDialog(0, 'ZKTeco - No Templates Available');
        return;
      }

      if (matchedLearnerId != null && matchedLearnerName != null) {
        print(
            '[1:N] ✅ SECURE MATCH: Proceeding with verified learner $matchedLearnerId');
        await _handleMatchedLearner(matchedLearnerId, matchedLearnerName,
            scanningDialogAlreadyClosed: false);
      } else {
        _showVerificationFailedDialog(learnersWithTemplates, 'ZKTeco');
      }
    } catch (e) {
      print('[1:N] ZKTeco verification error: $e');
      _showErrorDialog('Verification Error', 'ZKTeco verification failed: $e');
    }
  }

  Future<void> _handleMatchedLearner(String learnerId, String learnerName,
      {bool scanningDialogAlreadyClosed = false}) async {
    print(
        '[HANDLE_MATCHED] _handleMatchedLearner called for learner: $learnerId ($learnerName)');

    try {
      print('[HANDLE_MATCHED] Creating DatabaseHelper instance');
      final dbHelper = DatabaseHelper();

      print(
          '[HANDLE_MATCHED] Getting attendance for day: ${_getCurrentDateString()}');
      final existingAttendance = await dbHelper.getAttendanceForDay(
          learnerId, _getCurrentDateString());

      print('[HANDLE_MATCHED] Existing attendance: $existingAttendance');

      if (existingAttendance == null ||
          existingAttendance['clock_in_time'] == null) {
        // Clock In
        print('[HANDLE_MATCHED] Starting clock-in process');
        await _performClockIn(learnerId, learnerName);
        print('[HANDLE_MATCHED] Clock-in process completed');
      } else if (existingAttendance['clock_out_time'] == null ||
          existingAttendance['clock_out_time'].toString().isEmpty) {
        // Clock Out
        print('[HANDLE_MATCHED] Starting clock-out process');
        await _performClockOut(learnerId, learnerName, existingAttendance);
        print('[HANDLE_MATCHED] Clock-out process completed');
      } else {
        print('[HANDLE_MATCHED] Learner already completed clocking for today');
        print(
            '[HANDLE_MATCHED] Scanning dialog already closed: $scanningDialogAlreadyClosed');

        // Only close scanning dialog if it hasn't been closed already
        if (!scanningDialogAlreadyClosed) {
          try {
            print('[HANDLE_MATCHED] Checking if can pop dialog...');
            if (Navigator.of(context).canPop()) {
              print('[HANDLE_MATCHED] Can pop - closing scanning dialog');
              Navigator.of(context).pop(); // Close scanning dialog
              print('[HANDLE_MATCHED] Scanning dialog closed successfully');
            } else {
              print('[HANDLE_MATCHED] Cannot pop - no dialog to close');
            }
          } catch (e) {
            print('[HANDLE_MATCHED] Error closing scanning dialog: $e');
          }
        } else {
          print(
              '[HANDLE_MATCHED] Scanning dialog already closed - skipping pop');
        }

        // Add a longer delay to ensure the scanning dialog is fully closed
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            print(
                '[HANDLE_MATCHED] Showing delayed error dialog - widget still mounted');
            _showErrorDialog('Already Completed',
                '$learnerName has already completed clocking for today.',
                skipPop: true);
            print(
                '[HANDLE_MATCHED] Error dialog shown - should stay on dashboard');
          } else {
            print(
                '[HANDLE_MATCHED] Widget disposed before showing error dialog - this might indicate crash');
          }
        });
      }

      print('[HANDLE_MATCHED] _handleMatchedLearner completed successfully');
    } catch (e, stackTrace) {
      print('[HANDLE_MATCHED] ERROR in _handleMatchedLearner: $e');
      print('[HANDLE_MATCHED] Stack trace: $stackTrace');
      print('[HANDLE_MATCHED] Widget mounted during error: $mounted');

      // Safely close scanning dialog during error
      try {
        if (Navigator.of(context).canPop()) {
          print('[HANDLE_MATCHED] Closing scanning dialog due to error');
          Navigator.of(context).pop();
          print(
              '[HANDLE_MATCHED] Scanning dialog closed successfully during error');
        }
      } catch (navError) {
        print('[HANDLE_MATCHED] Error closing dialog: $navError');
      }

      // Add delay before showing error dialog to prevent navigation conflicts
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          print('[HANDLE_MATCHED] Showing error dialog after delay');
          _showErrorDialog(
              'Processing Error', 'Error handling matched learner: $e',
              skipPop: true);
        } else {
          print(
              '[HANDLE_MATCHED] Widget disposed during error - cannot show error dialog');
        }
      });
    }
  }

  Future<void> _performClockIn(String learnerId, String learnerName) async {
    print(
        '[CLOCK_IN] Starting clock-in for learner: $learnerId ($learnerName)');

    try {
      final now = _getCurrentTimeString();
      final date = _getCurrentDateString();

      print('[CLOCK_IN] Getting current location');
      // Get current location
      final locationData = await _getCurrentLocation();
      print('[CLOCK_IN] Location data: $locationData');

      final attendance = {
        'LearnerID': learnerId,
        'clock_in_time': now,
        'clock_out_time': '',
        'contact_time': '',
        'clock_date': date,
        'classID': widget.classID,
        'synced': 0,
        'user_latitude': locationData['latitude'],
        'user_longitude': locationData['longitude'],
        'user_accuracy': locationData['accuracy'],
      };

      print('[CLOCK_IN] Prepared attendance data: $attendance');

      try {
        // Try to sync to server immediately
        bool synced = false;
        try {
          print('[CLOCK_IN] Starting sync to server');
          synced = await syncSingleClockIn(attendance);
          print('[CLOCK_IN] Sync result: $synced');
        } catch (e) {
          print('[CLOCK_IN] Immediate sync failed: $e');
        }

        // Save to local database
        print('[CLOCK_IN] Saving to local database');
        final dbData = {
          'LearnerID': learnerId,
          'clock_in_time': now,
          'clock_out_time': '',
          'contact_time': '',
          'clock_date': date,
          'synced': synced ? 1 : 0,
          'user_latitude': locationData['latitude'],
          'user_longitude': locationData['longitude'],
          'user_accuracy': locationData['accuracy'],
        };

        print('[CLOCK_IN] Database data: $dbData');
        await DatabaseHelper().insertClocking(dbData);
        print('[CLOCK_IN] Database insert completed');

        final syncStatus = synced ? '(synced)' : '(offline)';
        print('[CLOCK_IN] Showing success dialog');
        _showSuccessDialog(learnerName, 'Clock-In');
        print('[CLOCK_IN] Clock-in process completed successfully');
      } catch (e, stackTrace) {
        print('[CLOCK_IN] ERROR during clock-in operations: $e');
        print('[CLOCK_IN] Stack trace: $stackTrace');

        // Close scanning dialog if still open
        try {
          Navigator.of(context).pop();
        } catch (navError) {
          print('[CLOCK_IN] Error closing dialog: $navError');
        }

        _showErrorDialog('Clock-In Error', 'Error during clock-in: $e');
      }
    } catch (e, stackTrace) {
      print('[CLOCK_IN] ERROR in _performClockIn setup: $e');
      print('[CLOCK_IN] Stack trace: $stackTrace');

      // Close scanning dialog if still open
      try {
        Navigator.of(context).pop();
      } catch (navError) {
        print('[CLOCK_IN] Error closing dialog: $navError');
      }

      _showErrorDialog('Clock-In Error', 'Error during clock-in setup: $e');
    }
  }

  Future<void> _performClockOut(String learnerId, String learnerName,
      Map<String, dynamic> existingAttendance) async {
    final now = _getCurrentTimeString();
    final clockInTime = existingAttendance['clock_in_time'].toString();
    final contactTime = _calculateContactTime(clockInTime, now);

    // Get current location
    final locationData = await _getCurrentLocation();

    final attendance = {
      'LearnerID': learnerId,
      'clock_in_time': clockInTime,
      'clock_out_time': now,
      'contact_time': contactTime,
      'clock_date': _getCurrentDateString(),
      'classID': widget.classID,
      'synced': 0,
      'user_latitude': locationData['latitude'],
      'user_longitude': locationData['longitude'],
      'user_accuracy': locationData['accuracy'],
    };

    try {
      // Try to sync to server immediately
      bool synced = false;
      try {
        synced = await syncSingleClockOut(attendance);
      } catch (e) {
        print('[CLOCK_OUT] Immediate sync failed: $e');
      }

      // Update local database
      final updatedAttendance = {
        'clock_out_time': now,
        'contact_time': contactTime,
        'synced': synced ? 1 : 0,
      };
      await DatabaseHelper()
          .updateClocking(existingAttendance['clocking_id'], updatedAttendance);

      final syncStatus = synced ? '(synced)' : '(offline)';
      _showSuccessDialog(learnerName, 'Clock-Out');
    } catch (e) {
      _showErrorDialog('Clock-Out Error', 'Error during clock-out: $e');
    }
  }

  String _getCurrentTimeString() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  String _getCurrentDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, String>> _getCurrentLocation() async {
    // Temporarily disabled geolocator functionality
    print(
        '[DASHBOARD] Geolocator temporarily disabled - using default coordinates');
    return {
      'latitude': '0.0',
      'longitude': '0.0',
      'accuracy': '10.0',
    };
  }

  String _calculateContactTime(String clockInTime, String clockOutTime) {
    try {
      final now = DateTime.now();
      final dateStr = _getCurrentDateString();

      DateTime clockInDateTime;
      DateTime clockOutDateTime;

      // Parse clock-in time
      if (clockInTime.contains(' ')) {
        clockInDateTime = DateTime.parse(clockInTime);
      } else {
        clockInDateTime = DateTime.parse('$dateStr $clockInTime');
      }

      // Parse clock-out time
      if (clockOutTime.contains(' ')) {
        clockOutDateTime = DateTime.parse(clockOutTime);
      } else {
        clockOutDateTime = DateTime.parse('$dateStr $clockOutTime');
      }

      final duration = clockOutDateTime.difference(clockInDateTime);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final seconds = duration.inSeconds % 60;

      return "${hours}h ${minutes}m ${seconds}s";
    } catch (e) {
      print('[CONTACT_TIME] Error calculating contact time: $e');
      return "0h 0m 0s";
    }
  }

  // Fingerprint Update Methods
  Future<void> _startFingerprintUpdate() async {
    _showLearnerSelectionDialog(isUpdate: true);
  }

  Future<void> _startFingerprintReEnrollment() async {
    _showLearnerSelectionDialog(isUpdate: false);
  }

  Future<void> _forceClassIDFix() async {
    try {
      print('\\n🔧 ===== FORCE CLASSID FIX START =====');

      final db = await DatabaseHelper().database;
      final classQuery = await db.rawQuery('''
        SELECT DISTINCT classID, COUNT(*) as learner_count
        FROM learnerdetails 
        WHERE (futronic_left_template IS NOT NULL AND futronic_left_template != '') 
           OR (futronic_right_template IS NOT NULL AND futronic_right_template != '')
           OR (zkteco_left_template IS NOT NULL AND zkteco_left_template != '')
           OR (zkteco_right_template IS NOT NULL AND zkteco_right_template != '')
        GROUP BY classID
        ORDER BY learner_count DESC
        LIMIT 1
      ''');

      if (classQuery.isNotEmpty) {
        final suggestedClassID = classQuery.first['classID']?.toString();
        if (suggestedClassID != null && suggestedClassID != widget.classID) {
          print(
              '🎯 Found best classID: $suggestedClassID with ${classQuery.first['learner_count']} learners');
          print(
              '🔧 Current classID: ${widget.classID} → Switching to: $suggestedClassID');

          // Apply the permanent fix
          setState(() {
            classData = _loadClassDataWithCorrectClassID(suggestedClassID);
          });

          await reloadClassData(overrideClassID: suggestedClassID);

          _showErrorDialog(
              'ClassID Fixed!',
              'Dashboard switched from classID ${widget.classID} to $suggestedClassID\n\n'
                  'Found ${classQuery.first['learner_count']} learners with fingerprints\n\n'
                  'Fingerprint verification should now work!',
              skipPop: true);

          print('✅ FORCE CLASSID FIX COMPLETE');
        } else {
          _showErrorDialog('No Fix Needed',
              'Current classID ${widget.classID} already has the most learners with fingerprints',
              skipPop: true);
        }
      } else {
        _showErrorDialog('No Fingerprints',
            'No learners found with fingerprint templates in any classID',
            skipPop: true);
      }
    } catch (e) {
      print('❌ Error during force ClassID fix: $e');
      _showErrorDialog('Fix Failed', 'Error during ClassID fix: $e',
          skipPop: true);
    }
  }

  Future<void> _debugFingerprintDatabase() async {
    try {
      print('\n🔍 ===== FINGERPRINT DATABASE DEBUG START =====');

      // Get current learners from classData
      final snapshot = await classData;
      final learners =
          snapshot?['learners'] as List<Map<String, dynamic>>? ?? [];

      print('📊 Total learners in current class: ${learners.length}');

      // Check a few learners in detail
      int learnersWithFingerprints = 0;
      int learnersChecked = 0;

      for (var learner in learners.take(10)) {
        // Check first 10 learners
        final learnerId = learner['LearnerID']?.toString();
        if (learnerId == null) continue;

        learnersChecked++;
        print(
            '\n👤 Checking Learner $learnerId (${learner['Name']} ${learner['Surname']}):');

        // Use the same method as the verification process
        final learnerIdInt = int.tryParse(learnerId);
        if (learnerIdInt == null) continue;

        final storedTemplates =
            await DatabaseHelper().getFingerprints(learnerIdInt);
        final leftTemplate = storedTemplates['left'];
        final rightTemplate = storedTemplates['right'];

        final hasLeft = leftTemplate != null && leftTemplate.isNotEmpty;
        final hasRight = rightTemplate != null && rightTemplate.isNotEmpty;

        // Also do direct database query to see raw data
        final db = await DatabaseHelper().database;
        final rawResult = await db.query(
          'learnerdetails',
          columns: [
            'LearnerID',
            'Name',
            'Surname',
            'zkteco_left_template',
            'zkteco_right_template',
            'futronic_left_template',
            'futronic_right_template'
          ],
          where: 'LearnerID = ?',
          whereArgs: [learnerId],
        );

        if (rawResult.isNotEmpty) {
          final rawRow = rawResult.first;
          print('  📋 RAW DATABASE DATA:');
          print(
              '    zkteco_left_template: ${rawRow['zkteco_left_template']?.toString().length ?? 'NULL'} chars');
          print(
              '    zkteco_right_template: ${rawRow['zkteco_right_template']?.toString().length ?? 'NULL'} chars');
          print(
              '    futronic_left_template: ${rawRow['futronic_left_template']?.toString().length ?? 'NULL'} chars');
          print(
              '    futronic_right_template: ${rawRow['futronic_right_template']?.toString().length ?? 'NULL'} chars');

          // Check if templates contain actual data vs empty strings
          final futronicLeftRaw = rawRow['futronic_left_template']?.toString();
          final futronicRightRaw =
              rawRow['futronic_right_template']?.toString();
          print(
              '    futronic_left_template actual content: ${futronicLeftRaw?.substring(0, futronicLeftRaw.length > 50 ? 50 : futronicLeftRaw.length) ?? 'NULL'}...');
          print(
              '    futronic_right_template actual content: ${futronicRightRaw?.substring(0, futronicRightRaw.length > 50 ? 50 : futronicRightRaw.length) ?? 'NULL'}...');
        }

        if (hasLeft || hasRight) {
          learnersWithFingerprints++;
          print('  ✅ HAS FINGERPRINTS:');
          print('    Left: ${hasLeft ? "${leftTemplate.length} chars" : "❌"}');
          print(
              '    Right: ${hasRight ? "${rightTemplate.length} chars" : "❌"}');
        } else {
          print('  ❌ NO FINGERPRINTS DETECTED');
        }
      }

      // Direct database count of learners with fingerprints
      final db = await DatabaseHelper().database;
      final fingerprintCount = await db.rawQuery('''
        SELECT COUNT(*) as count FROM learnerdetails 
        WHERE (zkteco_left_template IS NOT NULL AND zkteco_left_template != '') 
           OR (zkteco_right_template IS NOT NULL AND zkteco_right_template != '')
           OR (futronic_left_template IS NOT NULL AND futronic_left_template != '')
           OR (futronic_right_template IS NOT NULL AND futronic_right_template != '')
           OR (sourceafis_template IS NOT NULL AND sourceafis_template != '')
      ''');

      final totalFingerprintCount = fingerprintCount.first['count'] as int;
      print('\n📊 DIRECT DATABASE COUNT:');
      print(
          '  Total learners with ANY fingerprint data: $totalFingerprintCount');

      // Show specific breakdown
      final futronicCount = await db.rawQuery('''
        SELECT COUNT(*) as count FROM learnerdetails 
        WHERE (futronic_left_template IS NOT NULL AND futronic_left_template != '') 
           OR (futronic_right_template IS NOT NULL AND futronic_right_template != '')
      ''');

      final zktecoCount = await db.rawQuery('''
        SELECT COUNT(*) as count FROM learnerdetails 
        WHERE (zkteco_left_template IS NOT NULL AND zkteco_left_template != '') 
           OR (zkteco_right_template IS NOT NULL AND zkteco_right_template != '')
      ''');

      print(
          '  Learners with Futronic templates: ${futronicCount.first['count']}');
      print('  Learners with ZKTeco templates: ${zktecoCount.first['count']}');

      print('\n📈 SUMMARY:');
      print('  Learners checked: $learnersChecked');
      print('  Learners with fingerprints: $learnersWithFingerprints');
      print(
          '  Percentage with fingerprints: ${learnersChecked > 0 ? ((learnersWithFingerprints / learnersChecked) * 100).toStringAsFixed(1) : 0}%');

      // Check if we have fingerprints but no learners (ClassID mismatch)
      print(
          '🔍 Debug check: learnersChecked=$learnersChecked, totalFingerprintCount=$totalFingerprintCount');
      if (learnersChecked == 0 && totalFingerprintCount > 0) {
        print('\n🔍 ClassID MISMATCH DETECTED - Finding correct classID...');
        final classQuery = await db.rawQuery('''
          SELECT DISTINCT classID, COUNT(*) as learner_count
          FROM learnerdetails 
          WHERE (futronic_left_template IS NOT NULL AND futronic_left_template != '') 
             OR (futronic_right_template IS NOT NULL AND futronic_right_template != '')
             OR (zkteco_left_template IS NOT NULL AND zkteco_left_template != '')
             OR (zkteco_right_template IS NOT NULL AND zkteco_right_template != '')
          GROUP BY classID
          ORDER BY learner_count DESC
        ''');

        if (classQuery.isNotEmpty) {
          print('📊 ClassIDs with fingerprint templates:');
          for (var row in classQuery) {
            print(
                '   ClassID ${row['classID']}: ${row['learner_count']} learners with fingerprints');
          }

          final suggestedClassID = classQuery.first['classID']?.toString();
          print(
              '\n💡 SOLUTION: Current classID "${widget.classID}" has no learners.');
          print(
              '💡 Suggested classID "$suggestedClassID" which has ${classQuery.first['learner_count']} learners with fingerprints');

          // AUTOMATIC FIX: Load learners from the classID with fingerprints
          if (suggestedClassID != null) {
            print(
                '\n🔧 APPLYING AUTOMATIC FIX: Loading learners from classID with fingerprints...');
            try {
              final learnersFromCorrectClass = await DatabaseHelper()
                  .getLearnersWithClockingData(suggestedClassID);
              if (learnersFromCorrectClass.isNotEmpty) {
                print(
                    '✅ Found ${learnersFromCorrectClass.length} learners in suggested classID');
                // Update currentLearners to use the correct class
                setState(() {
                  currentLearners = learnersFromCorrectClass.map((learner) {
                    return {
                      'LearnerID': learner['LearnerID']?.toString() ?? 'N/A',
                      'Name': learner['Name']?.toString() ?? 'N/A',
                      'Surname': learner['Surname']?.toString() ?? 'N/A',
                      'clock_in_time':
                          learner['clock_in_time']?.toString() ?? '',
                      'clock_out_time':
                          learner['clock_out_time']?.toString() ?? '',
                      'contact_time': learner['contact_time']?.toString() ?? '',
                      // CRITICAL: Preserve fingerprint template data
                      'zkteco_left_template':
                          learner['zkteco_left_template']?.toString() ?? '',
                      'zkteco_right_template':
                          learner['zkteco_right_template']?.toString() ?? '',
                      'futronic_left_template':
                          learner['futronic_left_template']?.toString() ?? '',
                      'futronic_right_template':
                          learner['futronic_right_template']?.toString() ?? '',
                      'sourceafis_template':
                          learner['sourceafis_template']?.toString() ?? '',
                    };
                  }).toList();
                });
                print(
                    '✅ currentLearners updated with ${currentLearners.length} learners from correct classID');
              }
            } catch (e) {
              print('❌ Error loading learners from suggested classID: $e');
            }
          }
        }
      }

      // Check if we need to sync from server
      if (learnersWithFingerprints == 0 || learnersChecked == 0) {
        print(
            '\n⚠️  NO FINGERPRINTS FOUND OR NO LEARNERS - Checking server sync...');
        final classID = snapshot?['classID']?.toString() ?? widget.classID;
        print('📡 Attempting to sync from server for classID: $classID');
        await DatabaseHelper().syncLearnersFromServer(classID);
        print('✅ Server sync completed - reloading class data...');

        // Trigger a data reload
        await reloadClassData();
        print('✅ Class data reloaded - please tap debug again to see results');
      }

      print('🔍 ===== FINGERPRINT DATABASE DEBUG END =====\n');

      // Show dialog with results
      String autoFixMessage = '';
      if (learnersChecked == 0 && totalFingerprintCount > 0) {
        autoFixMessage =
            '\n✅ AUTO-FIX APPLIED: Loaded learners from correct classID';
      }

      _showErrorDialog(
          'Debug Results',
          'Checked $learnersChecked learners\n'
              'Found $learnersWithFingerprints with fingerprints\n'
              'Database total: $totalFingerprintCount\n'
              'Futronic: ${futronicCount.first['count']}, ZKTeco: ${zktecoCount.first['count']}\n'
              'Current classID: ${widget.classID}$autoFixMessage\n'
              '${learnersWithFingerprints == 0 && learnersChecked > 0 ? "\n⚠️ Server sync triggered" : ""}\n'
              'Check console for detailed logs',
          skipPop: true);
    } catch (e) {
      print('❌ Debug error: $e');
      _showErrorDialog('Debug Error', 'Error debugging database: $e',
          skipPop: true);
    }
  }

  void _showLearnerSelectionDialog({required bool isUpdate}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(isUpdate ? Icons.update : Icons.refresh,
                  color: Colors.blue, size: 30),
              const SizedBox(width: 12),
              Text(isUpdate ? 'Update Fingerprints' : 'Re-enroll Fingerprints'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Text(
                  isUpdate
                      ? 'Select a learner to update their fingerprints:'
                      : 'Select a learner to completely re-enroll their fingerprints:',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: currentLearners.length,
                    itemBuilder: (context, index) {
                      final learner = currentLearners[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Text(
                              '${learner['Name']?[0] ?? ''}${learner['Surname']?[0] ?? ''}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title:
                              Text('${learner['Name']} ${learner['Surname']}'),
                          subtitle: Text('ID: ${learner['LearnerID']}'),
                          trailing:
                              const Icon(Icons.fingerprint, color: Colors.blue),
                          onTap: () {
                            Navigator.of(context).pop();
                            _processFingerprintUpdate(learner, isUpdate);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processFingerprintUpdate(
      Map<String, dynamic> learner, bool isUpdate) async {
    final learnerId = learner['LearnerID']?.toString();
    final learnerName = '${learner['Name']} ${learner['Surname']}';

    if (learnerId == null) {
      _showErrorDialog('Error', 'Invalid learner ID');
      return;
    }

    try {
      // Detect scanner
      final scanner = await _detectScanner();
      if (scanner == 'none') {
        _showErrorDialog('Scanner Not Found',
            'No fingerprint scanner detected. Please connect a scanner and try again.');
        return;
      }

      // Show update confirmation dialog
      _showFingerprintUpdateDialog(learner, scanner, isUpdate);
    } catch (e) {
      _showErrorDialog('Scanner Error', 'Error detecting scanner: $e');
    }
  }

  void _showFingerprintUpdateDialog(
      Map<String, dynamic> learner, String scanner, bool isUpdate) {
    final learnerName = '${learner['Name']} ${learner['Surname']}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(isUpdate ? Icons.update : Icons.refresh,
                  color: Colors.orange, size: 30),
              const SizedBox(width: 12),
              Text(isUpdate ? 'Update Fingerprints' : 'Re-enroll Fingerprints'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.person, size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    Text(
                      learnerName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isUpdate
                          ? 'This will update existing fingerprint templates'
                          : 'This will completely replace all fingerprint templates',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scanner: ${scanner.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.cancel, color: Colors.grey),
              label: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _startFingerprintEnrollmentProcess(learner, scanner, isUpdate);
              },
              icon: const Icon(Icons.fingerprint),
              label: Text('Start ${isUpdate ? 'Update' : 'Re-enrollment'}'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startFingerprintEnrollmentProcess(
      Map<String, dynamic> learner, String scanner, bool isUpdate) async {
    final learnerId = learner['LearnerID']?.toString();
    final learnerName = '${learner['Name']} ${learner['Surname']}';

    if (learnerId == null) return;

    try {
      // Navigate to EnrollmentPage for the specific learner
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnrollmentPage(
            learnerId: int.parse(learnerId),
            returnToClockAfterEnroll: false,
          ),
        ),
      );

      if (result == true) {
        // Enrollment was successful
        _showSuccessDialog(learnerName,
            isUpdate ? 'Fingerprint Update' : 'Fingerprint Re-enrollment');
      }
    } catch (e) {
      _showErrorDialog(
          'Enrollment Error', 'Error starting fingerprint enrollment: $e');
    }
  }

  void _showScanningDialog(String scanner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.fingerprint, color: Colors.blue, size: 30),
              SizedBox(width: 12),
              Text('Fingerprint Scanning'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated scanning indicator
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.fingerprint,
                    size: 40,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Place your thumb on the ${scanner.toUpperCase()} scanner',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Scanning against ${currentLearners.length} learners in this class',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isScanning = false;
                });
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String learnerName, String action) {
    print(
        '[SUCCESS_DIALOG] _showSuccessDialog called for $learnerName, action: $action');

    // Don't close any dialogs here - let the calling method handle that
    // The scanning dialog should already be closed by the calling method

    print('[SUCCESS_DIALOG] About to show success dialog immediately');

    // Show dialog immediately without delay - the calling method should handle timing
    if (mounted) {
      print('[SUCCESS_DIALOG] Showing dialog now');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 30),
                SizedBox(width: 12),
                Text('Success!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        action == 'Clock-In' ? Icons.login : Icons.logout,
                        size: 48,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        learnerName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$action successful!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateTime.now().toString().substring(0, 19),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  print('[SUCCESS_DIALOG] OK button pressed');
                  try {
                    print('[SUCCESS_DIALOG] About to pop dialog');
                    Navigator.of(context).pop();
                    print(
                        '[SUCCESS_DIALOG] Dialog popped, checking mounted state: $mounted');

                    // Reload class data to reflect new attendance, but only if widget is still mounted
                    if (mounted) {
                      print(
                          '[SUCCESS_DIALOG] Widget is mounted, scheduling data reload');
                      // Schedule the reload after the dialog is fully dismissed
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted) {
                          print(
                              '[SUCCESS_DIALOG] Starting delayed data reload');
                          setState(() {
                            print(
                                '[SUCCESS_DIALOG] Inside setState, calling reloadClassData');
                            reloadClassData();
                          });
                          print(
                              '[SUCCESS_DIALOG] Delayed reload completed successfully');
                        } else {
                          print(
                              '[SUCCESS_DIALOG] Widget disposed during delayed reload, skipping');
                        }
                      });
                    } else {
                      print(
                          '[SUCCESS_DIALOG] Widget is not mounted, skipping setState');
                    }
                  } catch (e) {
                    print('[SUCCESS_DIALOG] ERROR in OK button handler: $e');
                    print(
                        '[SUCCESS_DIALOG] Stack trace: ${StackTrace.current}');
                  }
                },
                icon: const Icon(Icons.check, color: Colors.green),
                label: const Text('OK', style: TextStyle(color: Colors.green)),
              ),
            ],
          );
        },
      );
    } else {
      print('[SUCCESS_DIALOG] Widget not mounted, skipping dialog');
    }
  }

  void _showErrorDialog(String title, String message, {bool skipPop = false}) {
    print(
        '[ERROR_DIALOG] _showErrorDialog called: $title - $message, skipPop: $skipPop');
    // Close any existing dialogs first, but only if we're not showing a success dialog
    // and only if skipPop is false (to avoid double-popping)
    if (!skipPop) {
      try {
        Navigator.of(context).pop();
      } catch (e) {
        print('[ERROR_DIALOG] Error popping dialog: $e');
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 30),
              const SizedBox(width: 12),
              Text(title),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                print('[ERROR_DIALOG] Close button pressed');
                try {
                  print('[ERROR_DIALOG] About to call Navigator.pop()');
                  print(
                      '[ERROR_DIALOG] Current navigator can pop: ${Navigator.of(dialogContext).canPop()}');
                  Navigator.of(dialogContext).pop();
                  print(
                      '[ERROR_DIALOG] Dialog closed successfully - staying on dashboard');
                  print(
                      '[ERROR_DIALOG] Dashboard widget still mounted: $mounted');
                } catch (e) {
                  print('[ERROR_DIALOG] Error closing dialog: $e');
                  print('[ERROR_DIALOG] Stack trace: ${StackTrace.current}');
                }
              },
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text('Close', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showVerificationFailedDialog(int learnersChecked, String scannerType) {
    // Note: The scanning dialog should already be closed by the calling method
    // Don't pop again as it might close the wrong dialog or the entire page

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_search, color: Colors.orange, size: 30),
              SizedBox(width: 12),
              Text('Not Recognized'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.fingerprint_outlined,
                        size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    Text(
                      'Fingerprint not recognized',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Searched: $learnersChecked learners in this class\nScanner: ${scannerType.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Possible reasons:\n• Learner not enrolled in this class\n• Fingerprint not registered\n• Try different finger position',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                try {
                  Navigator.of(dialogContext).pop();
                } catch (e) {
                  print('[VERIFICATION_DIALOG] Error closing dialog: $e');
                }
              },
              icon: const Icon(Icons.refresh, color: Colors.blue),
              label:
                  const Text('Try Again', style: TextStyle(color: Colors.blue)),
            ),
            TextButton.icon(
              onPressed: () {
                try {
                  Navigator.of(dialogContext).pop();
                } catch (e) {
                  print('[VERIFICATION_DIALOG] Error closing dialog: $e');
                }
              },
              icon: const Icon(Icons.close, color: Colors.grey),
              label: const Text('Close', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {
            showMenu(
              context: context,
              position: const RelativeRect.fromLTRB(100.0, 100.0, 0.0, 0.0),
              items: [
                _buildMenuItem(Icons.dashboard, 'Dashboard', 1),
                _buildMenuItem(Icons.account_circle, 'Profile', 2),
                _buildMenuItem(Icons.list, 'Learner List', 3),
                _buildMenuItem(Icons.monitor, 'Learner Material', 4),
                _buildMenuItem(Icons.monitor, 'Learning Material Form', 5),
                _buildMenuItem(Icons.fingerprint, 'Fingerprint Clock In', 6),
                // _buildMenuItem(Icons.fingerprint, 'Contact Less Clock In', 7),
                _buildMenuItem(Icons.people, 'Attendance', 8),
                // _buildMenuItem(Icons.fingerprint_outlined, 'My Fingerprints', 9),
                // _buildMenuItem(Icons.security, 'Test Random Prompt', 10),
                _buildMenuItem(Icons.logout, 'Logout', 11),
              ],
              elevation: 8.0,
            ).then((value) {
              if (value != null) _handleMenuSelection(context, value);
            });
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.red, size: 20),
            tooltip: 'Debug Fingerprints',
            onPressed: _debugFingerprintDatabase,
          ),
          IconButton(
            icon: const Icon(Icons.settings_backup_restore,
                color: Colors.purple, size: 20),
            tooltip: 'Fix ClassID',
            onPressed: _forceClassIDFix,
          ),
          IconButton(
            icon: const Icon(Icons.fingerprint_outlined,
                color: Colors.blue, size: 20),
            tooltip: 'Update Fingerprints',
            onPressed: _startFingerprintUpdate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange, size: 20),
            tooltip: 'Re-enroll Fingerprints',
            onPressed: _startFingerprintReEnrollment,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: classData,
        builder: (context, snapshot) {
          print(
              "[DASHBOARD] FutureBuilder state - Connection: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, data: ${snapshot.data}");

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            print("[DASHBOARD] FutureBuilder error: ${snapshot.error}");
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData ||
              snapshot.data == null ||
              snapshot.data!.isEmpty) {
            print(
                "[DASHBOARD] FutureBuilder no data - hasData: ${snapshot.hasData}, data: ${snapshot.data}");
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No class data found'),
                  const SizedBox(height: 16),
                  Text('Class ID: ${widget.classID}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      print("[DASHBOARD] Manual reload triggered");
                      if (mounted) {
                        reloadClassData();
                      }
                    },
                    child: const Text('Retry Loading'),
                  ),
                ],
              ),
            );
          }

          final classInfo = snapshot.data!;
          final className = classInfo['class_name'] ?? 'N/A';
          final facilitatorName = classInfo['facilitator_name'] ?? 'N/A';
          final classMax = classInfo['class_max']?.toString() ?? 'N/A';
          final totalLearners =
              classInfo['total_learners']?.toString() ?? 'N/A';
          final attendance = classInfo['total_attendance']?.toString() ?? 'N/A';
          final absent = classInfo['total_absent']?.toString() ?? 'N/A';
          final siteName = classInfo['site_name'] ?? 'N/A';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Site Information
                Text(
                  'Site: $siteName',
                  style: const TextStyle(color: Colors.black, fontSize: 30),
                ),
                const SizedBox(height: 30),
                // Class Information Card
                _buildInfoCard(
                  context,
                  title: 'Class Details',
                  details: [
                    'Class: $className',
                    'Facilitator: $facilitatorName',
                    'Class Max: $classMax',
                    'Total Learners: $totalLearners',
                    'Attendance: $attendance',
                    'Absent: $absent',
                  ],
                ),
                const SizedBox(height: 30),
                // Biometric Section
                _buildBiometricSection(context),
              ],
            ),
          );
        },
      ),
    );
  }

  PopupMenuItem<int> _buildMenuItem(IconData icon, String label, int value) {
    return PopupMenuItem<int>(
      value: value,
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 15),
          Text(label),
        ],
      ),
    );
  }

  void _handleMenuSelection(BuildContext context, int value) {
    switch (value) {
      case 1:
        // Navigate to Dashboard
        Navigator.pushNamed(context, '/dashboard');
        break;
      case 2:
        // Navigate to Profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FacilitatorProfile(
              classID: widget.classID,
            ),
          ),
        );
        break;
      case 3:
        // Navigate to Learner List (Facilitator - with PPE Sizes button)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Learnerlistpage(
              classID: widget.classID,
              learners: [],
            ),
          ),
        );
        break;
      case 4:
        // Navigate to Learner Material
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MaterialForm(
              classID: widget.classID,
            ),
          ),
        );
        break;
      case 5:
        // Navigate to Learning Material Form Page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LearningMaterialFormPage(
              classID: widget.classID,
            ),
          ),
        );
        break;
      case 6:
        // Navigate to ClockInPage
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClockInPage(
              classID: widget.classID,
              learners: currentLearners,
            ),
          ),
        );
        break;
      case 7:
        // Navigate to ContactlessClockInPage
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContactlessClockInPage(
              classID: widget.classID,
              learners: currentLearners,
            ),
          ),
        );
        break;
      case 8:
        // Navigate to Attendance Page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttendancePage(
              classID: widget.classID,
            ),
          ),
        );
        break;
      case 9:
        // Navigate to Facilitator Fingerprint Management
        _navigateToFacilitatorFingerprints();
        break;
      case 11:
        // Perform Logout
        Navigator.pushReplacementNamed(context, '/login');
        break;
      // case 10:
      // // Test Random Prompt
      //   _testRandomPrompt();
      //   break;
      default:
        print('Unknown menu option: $value');
        break;
    }
  }

  // /// Test random prompt functionality
  // void _testRandomPrompt() async {
  //   try {
  //     debugPrint('[DASHBOARD] Testing random prompt...');
  //
  //     // Get random clocked learners
  //     final dbHelper = DatabaseHelper();
  //     final learners = await dbHelper.getRandomClockedLearners(count: 2);
  //
  //     if (learners.isEmpty) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('No clocked learners found for random prompt'),
  //           backgroundColor: Colors.orange,
  //         ),
  //       );
  //       return;
  //     }
  //
  //     // Select first learner for testing
  //     final selectedLearner = learners.first;
  //     final learnerId = selectedLearner['LearnerID'] as int;
  //     final learnerName = '${selectedLearner['firstName']} ${selectedLearner['lastName']}';
  //
  //     debugPrint('[DASHBOARD] Testing prompt for learner: $learnerName (ID: $learnerId)');
  //
  //     // Create monitoring record
  //     final monitoringId = await dbHelper.createRandomPrompt(learnerId, countdownDuration: 180);
  //
  //     // Show the prompt
  //     final result = await RandomPromptService.showRandomPromptDialog(
  //       context,
  //       learnerId,
  //       learnerName,
  //       monitoringId,
  //     );
  //
  //     if (result == true) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Random prompt test completed successfully'),
  //           backgroundColor: Colors.green,
  //         ),
  //       );
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Random prompt test was skipped or failed'),
  //           backgroundColor: Colors.orange,
  //         ),
  //       );
  //     }
  //
  //   } catch (e) {
  //     debugPrint('[DASHBOARD] Error testing random prompt: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Error testing random prompt: $e'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }

  /// Navigate to facilitator fingerprint management page
  void _navigateToFacilitatorFingerprints() async {
    try {
      debugPrint('[DASHBOARD] Navigating to facilitator fingerprints...');
      debugPrint('[DASHBOARD] Current classID: ${widget.classID}');

      // Try to get facilitator_id from database
      final db = await DatabaseHelper().database;

      // First, check if facilitator table exists and has data
      final allFacilitators = await db.query('facilitator');
      debugPrint(
          '[DASHBOARD] Total facilitators in database: ${allFacilitators.length}');

      if (allFacilitators.isNotEmpty) {
        debugPrint('[DASHBOARD] First facilitator: ${allFacilitators.first}');
      }

      final facilitators = await db.query(
        'facilitator',
        where: 'classID = ?',
        whereArgs: [widget.classID],
        limit: 1,
      );

      debugPrint(
          '[DASHBOARD] Facilitators found for classID ${widget.classID}: ${facilitators.length}');

      if (facilitators.isNotEmpty) {
        final facilitator = facilitators.first;
        debugPrint('[DASHBOARD] Facilitator data: $facilitator');

        final facilitatorId = facilitator['facilitator_id'] as int?;
        final fullName =
            '${facilitator['firstName'] ?? ''} ${facilitator['lastName'] ?? ''}'
                .trim();

        debugPrint(
            '[DASHBOARD] Facilitator ID: $facilitatorId, Name: $fullName');

        if (facilitatorId != null) {
          debugPrint('[DASHBOARD] Navigating to FacilitatorFingerprintPage...');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FacilitatorFingerprintPage(
                facilitatorId: facilitatorId,
                facilitatorName: fullName.isNotEmpty ? fullName : 'Facilitator',
                isFirstTimeSetup: false,
                requireClockIn: false,
              ),
            ),
          );
        } else {
          debugPrint('[DASHBOARD] Facilitator ID is null');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Facilitator ID not found. Please contact support.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        debugPrint(
            '[DASHBOARD] No facilitator found for classID: ${widget.classID}');

        // Try to find any facilitator and show helpful message
        if (allFacilitators.isNotEmpty) {
          final availableClassIDs =
              allFacilitators.map((f) => f['classID']).toSet().toList();
          debugPrint('[DASHBOARD] Available classIDs: $availableClassIDs');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'No facilitator found for class ${widget.classID}. Available classes: $availableClassIDs'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No facilitator data found. Please log in again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[DASHBOARD] Error navigating to fingerprints: $e');
      debugPrint('[DASHBOARD] Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildInfoCard(BuildContext context,
      {required String title, required List<String> details}) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ...details.map((detail) => Text(detail)),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricSection(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Biometric Tabs
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTab(context, 'Fingerprint', true),
                const SizedBox(width: 8),
                _buildTab(context, 'Facial', false),
              ],
            ),
            const SizedBox(height: 16),
            // Biometric Options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBiometricOption(
                    context, Icons.fingerprint, 'Fingerprint'),
                const SizedBox(width: 16),
                _buildBiometricOption(context, Icons.face, 'Facial'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, String label, bool isSelected) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey[300],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricOption(
      BuildContext context, IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        if (label == 'Fingerprint') {
          // Start 1:N fingerprint verification
          _startFingerprintClocking();
        } else {
          // Handle Facial recognition (not implemented)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label recognition not implemented')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, width: 2.0),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          children: [
            Icon(icon, size: 80, color: Colors.black),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
