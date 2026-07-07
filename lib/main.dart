import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:workmanager/workmanager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dashboard_page.dart';
import 'sdp_projects_page.dart';
import 'database_helper.dart';
import 'sync_service.dart';
import 'config.dart';
import 'assessorPage.dart';
import 'ModeratorPage.dart';
import 'facilitator_fingerprint_page.dart';
import 'finance_dashboard.dart';
import 'logistics_dashboard.dart';
import 'utils/global_error_handler.dart';
import 'utils/ultimate_scanner_crash_prevention.dart';
import 'services/random_prompt_service.dart';
import 'monitoring_prompt_page.dart';

// Define unique task names for Workmanager
const String syncTask = "com.example.rlmss.syncTask";
const String connectivityCheckTask = "com.example.rlmss.connectivityCheckTask";

// Initialize notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Request notification permission
Future<void> requestNotificationPermission() async {
  if (await Permission.notification.request().isGranted) {
    print("Notification permission granted");
  } else {
    print("Notification permission denied");
    // Optionally, guide user to enable notifications in settings
  }
}

// Request battery optimization exemption
Future<void> requestIgnoreBatteryOptimization() async {
  if (await Permission.ignoreBatteryOptimizations.request().isGranted) {
    print("Battery optimization disabled");
  } else {
    print("Battery optimization permission denied");
    // Optionally, guide user to disable battery optimization in settings
  }
}

// Workmanager callback dispatcher
@pragma('vm:entry-point') // Added to fix Dart entrypoint error
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Initialize notifications in the background
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      if (task == syncTask) {
        // Sync task: Runs when network is available
        final dbHelper = DatabaseHelper();
        final syncService = SyncService();

        final connectivityResult = await Connectivity().checkConnectivity();
        final hasNetwork =
            connectivityResult.contains(ConnectivityResult.wifi) ||
                connectivityResult.contains(ConnectivityResult.mobile);

        if (hasNetwork) {
          print("Background sync: Network available, starting sync...");
          await syncService.syncDataToServer();
          await syncService.syncAllPOERecords();
          await syncService.syncLearnerDetails();
          await syncService.syncMaterialFormsWithServer();
          await syncService.syncAcknowledgmentOfReceiptToServer();
          await syncService.sync_inductionClocking();
          print("Background sync completed successfully.");
          return Future.value(true);
        } else {
          print("Background sync: No network available, skipping sync.");
          return Future.value(false);
        }
      } else if (task == connectivityCheckTask) {
        print("Connectivity check task started at ${DateTime.now()}");
        final connectivityResult = await Connectivity().checkConnectivity();
        print("Connectivity result: $connectivityResult");
        final hasNetwork =
            connectivityResult.contains(ConnectivityResult.wifi) ||
                connectivityResult.contains(ConnectivityResult.mobile);
        print("Has network: $hasNetwork");

        if (!hasNetwork) {
          print("No network detected, attempting to trigger alert...");
          try {
            const AndroidNotificationDetails androidDetails =
                AndroidNotificationDetails(
              'connectivity_channel',
              'Connectivity Alerts',
              channelDescription:
                  'Notifications for network connectivity issues',
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'ticker',
              playSound: false, // Changed from true to false
              enableVibration: true,
              fullScreenIntent: true, // Show notification prominently
            );
            const DarwinNotificationDetails iosDetails =
                DarwinNotificationDetails(
              badgeNumber: 1,
            );
            const NotificationDetails platformDetails = NotificationDetails(
              android: androidDetails,
              iOS: iosDetails,
            );
            await flutterLocalNotificationsPlugin.show(
              0,
              'No Network Connection',
              'Please turn on Wi-Fi or mobile data to enable background syncing',
              platformDetails,
            );
            print("Notification shown successfully");
          } catch (e) {
            print("Notification failed: $e");
          }
        } else {
          print("Network available, no alert needed.");
        }

        // Reschedule the connectivity check task for 2 minutes later
        Workmanager().registerOneOffTask(
          "connectivity-check-${DateTime.now().millisecondsSinceEpoch}",
          connectivityCheckTask,
          initialDelay: const Duration(minutes: 2),
          constraints: Constraints(
            networkType: NetworkType.unmetered,
            requiresBatteryNotLow: false,
            requiresCharging: false,
          ),
        );
        print("Rescheduled connectivity check task for 2 minutes later");
        return Future.value(true);
      }
      return Future.value(false);
    } catch (e) {
      print("Task $task failed: $e");
      return Future.value(false);
    }
  });
}

void main() async {
  // Initialize global error handler FIRST to catch all errors
  GlobalErrorHandler.initialize();

  // Initialize ultimate scanner crash prevention system
  UltimateScannerCrashPrevention().initialize();

  // Ensure bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // DEBUG-ONLY: Allow connecting to hosts with certificate hostname mismatch (development servers)
  if (kDebugMode) {
    HttpOverrides.global = _DevHttpOverrides(allowedHosts: {"192.168.68.105"});
  }

  // Request permissions
  await requestNotificationPermission();
  await requestIgnoreBatteryOptimization();

  final supportsWorkmanager = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  if (supportsWorkmanager) {
    // Initialize Workmanager only on supported platforms.
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // Set to false for production
    );
  }

  // Initialize notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();
  const WindowsInitializationSettings initializationSettingsWindows =
      WindowsInitializationSettings(
    appName: 'rlmss',
    appUserModelId: 'com.example.rlmss',
    guid: 'd49b0314-ee7c-4f34-95b1-3f01f9c4e9c3',
  );
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
    windows: initializationSettingsWindows,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Schedule periodic sync task (every 15 minutes)
  if (supportsWorkmanager) {
    Workmanager().registerPeriodicTask(
      "sync-task-1",
      syncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresCharging: false,
      ),
      initialDelay: const Duration(seconds: 10),
    );

    // Schedule initial connectivity check task (runs after 2 minutes, then reschedules itself)
    Workmanager().registerOneOffTask(
      "connectivity-check-initial",
      connectivityCheckTask,
      initialDelay: const Duration(minutes: 2),
      constraints: Constraints(
        networkType: NetworkType.unmetered,
        requiresBatteryNotLow: false,
        requiresCharging: false,
      ),
    );
  }

  final dbHelper = DatabaseHelper();
  dbHelper.initConnectivityListener();

  // Clean up old clocking records (keep only current day)
  await dbHelper.cleanupOldClockingRecords();

  // Clean up duplicate clocking records
  await dbHelper.cleanupDuplicateClockingRecords();

  runApp(const MyApp());
}

// Debug HTTP overrides to relax certificate hostname checks for specific hosts only.
// This is applied ONLY in debug mode above. Do not enable for release.
class _DevHttpOverrides extends HttpOverrides {
  final Set<String> allowedHosts;
  _DevHttpOverrides({required this.allowedHosts});

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      return allowedHosts.contains(host);
    };
    return client;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'rlmss',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routes: {
        '/login': (context) => const LoginPage(),
      },
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isOffline = false;
  bool _isLoading = false;

  final dbHelper = DatabaseHelper();
  final syncService = SyncService();
  String _connectivityStatus = 'Checking connectivity...';
  String _databaseStatus = 'Checking SQLite connection...';

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _checkDatabase();
    syncService.initSync();
    _initializeRandomPromptService();
  }

  Future<void> _initializeRandomPromptService() async {
    try {
      debugPrint('[MAIN] Initializing random prompt service');
      await RandomPromptService().initialize();
      debugPrint('[MAIN] Random prompt service initialized');
    } catch (e) {
      debugPrint('[MAIN] Error initializing random prompt service: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final List<ConnectivityResult> results =
          await Connectivity().checkConnectivity();
      setState(() {
        _isOffline = !results.contains(ConnectivityResult.wifi) &&
            !results.contains(ConnectivityResult.mobile);
        _connectivityStatus = _getStatusMessage(results);
      });
    } catch (e) {
      setState(() {
        _connectivityStatus = 'Error checking connectivity: $e';
      });
    }
  }

  String _getStatusMessage(List<ConnectivityResult> results) {
    if (results.isEmpty) return 'No Internet Connection';
    if (results.contains(ConnectivityResult.wifi)) {
      return 'Connected via Wi-Fi';
    } else if (results.contains(ConnectivityResult.mobile)) {
      return 'Connected via Mobile Data';
    } else {
      return 'No Internet Connection';
    }
  }

  Future<void> _checkDatabase() async {
    try {
      bool isConnected = await dbHelper.isDatabaseConnected();
      setState(() {
        _databaseStatus = isConnected
            ? 'Connected to SQLite Database'
            : 'Not connected to SQLite Database';
      });
    } catch (e) {
      setState(() {
        _databaseStatus = 'Error checking SQLite connection: $e';
      });
    }
  }

  Future<Map<String, dynamic>?> _attemptLogin(
      String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.loginUrl),
        body: {'email': username, 'password': password},
      ).timeout(const Duration(seconds: 15));

      print("Raw login response: ${response.body}"); // Log raw response

      if (response.statusCode == 200) {
        // Clean response by removing HTML tags and trimming extra characters
        String cleaned =
            response.body.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        // Try to extract JSON object if extra content exists
        final start = cleaned.indexOf('{');
        final end = cleaned.lastIndexOf('}');
        if (start != -1 && end != -1 && end >= start) {
          cleaned = cleaned.substring(start, end + 1);
        }
        debugPrint("[LOGIN] Cleaned login response: $cleaned");
        try {
          final data = json.decode(cleaned) as Map<String, dynamic>;
          debugPrint("[LOGIN] Parsed JSON data: $data");
          return data;
        } catch (e) {
          debugPrint('[LOGIN] JSON parsing error: $e');
          return null;
        }
      }
      print('Login HTTP error: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error during login: $e');
      return null;
    }
  }

  Future<void> _performBackgroundSync() async {
    try {
      print("Initiating background sync");
      await syncService.syncDataToServer();
      await syncService.syncAllPOERecords();
      var result = await syncService.syncLearnerDetails();
      print(result);
      await syncService.syncMaterialFormsWithServer();
      await syncService.syncAcknowledgmentOfReceiptToServer();
      await syncService.sync_inductionClocking();
      print("Background sync completed successfully.");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Background sync completed successfully')),
        );
      }
    } catch (syncError) {
      print("Background sync failed: $syncError");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Background sync failed: $syncError')),
        );
      }
    }
  }

  Future<void> _loginOnline() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String username = _usernameController.text;
      String password = _passwordController.text;

      final data = await _attemptLogin(username, password);
      if (data != null) {
        final success = data['success'] == true;
        if (success) {
          // Debug: Print the entire response
          debugPrint('[LOGIN] Full login response: $data');

          final role = data['role']?.toString() ?? '';
          final classID = data['classID']?.toString() ?? '';
          // Try multiple fields for SDP identifier
          final sdp = data['sdp_id']?.toString() ??
              data['sdp_name']?.toString() ??
              data['sdpId']?.toString() ??
              '';
          final classData = data['data'] ?? [];
          final learners = data['learners'] ?? [];
          final facilitatorId = data['facilitator_id']?.toString() ?? '';
          final classes = data['classes'] ?? [];

          // Debug: Show what we extracted
          debugPrint('[LOGIN] Extracted values:');
          debugPrint('[LOGIN]   - role: "$role"');
          debugPrint('[LOGIN]   - facilitator_id: "$facilitatorId"');
          debugPrint('[LOGIN]   - classID: "$classID"');
          debugPrint('[LOGIN]   - role.toLowerCase(): "${role.toLowerCase()}"');

          // Save facilitator data to local database (if not SDP role)
          if (role != 'sdp' && classID.isNotEmpty) {
            try {
              await dbHelper.saveFacilitatorDetailsOffline(classID, {
                'firstName': data['firstName'] ?? '',
                'lastName': data['lastName'] ?? '',
                'email': username,
                'phoneNumber': data['phoneNumber'] ?? '',
                'f_IDNumber': data['f_IDNumber'] ?? '',
                'assessorNo': data['assessorNo'] ?? '',
                'f_signature': data['f_signature'],
                'f_profile': data['f_profile'],
                'role': role,
                'facilitator_id': facilitatorId.isNotEmpty
                    ? int.tryParse(facilitatorId)
                    : null,
              });
              debugPrint(
                  '[LOGIN] Saved facilitator data to local database for classID: $classID');
            } catch (e) {
              debugPrint('[LOGIN] Error saving facilitator data: $e');
            }
          }

          // Start background sync without awaiting
          _performBackgroundSync();

          // Sync learners to local database if we have a classID
          if (classID.isNotEmpty) {
            try {
              await dbHelper.syncLearnersFromServer(classID);
              print('Successfully synced learners for classID: $classID');
            } catch (e) {
              print('Failed to sync learners for classID $classID: $e');
              // Continue even if sync fails
            }
          }

          // Navigate immediately
          _navigateBasedOnRole(role, classID, sdp, classData, learners,
              facilitatorId, classes, data);
        } else {
          final message =
              (data['message']?.toString().trim().isNotEmpty == true)
                  ? data['message'].toString()
                  : 'Invalid email or password';
          _showError(message);
        }
      } else {
        _showError(
            'Unable to reach server or parse response. Please try again.');
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getSDP() async {
    final db = await dbHelper.database;
    final results = await db.query('sdp');
    return results;
  }

  Future<List<Map<String, dynamic>>> _getAllFacilitators() async {
    final db = await dbHelper.database;
    final results = await db.query('facilitator');
    return results;
  }

  Future<void> _loginOffline() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String username = _usernameController.text;
      String password = _passwordController.text;

      try {
        // Check SDP FIRST before checking facilitators
        Map<String, dynamic>? sdpEntry =
            await dbHelper.getSdp(username, password);

        if (sdpEntry != null) {
          String role = 'sdp';
          String siteID = sdpEntry['siteID']?.toString() ?? '';
          String classID = sdpEntry['classID']?.toString() ?? '';
          // Try multiple fields for SDP identifier
          String sdp = sdpEntry['sdp_id']?.toString() ??
              sdpEntry['sdp_name']?.toString() ??
              sdpEntry['Reg_number']?.toString() ??
              '';
          String facilitatorId = sdpEntry['facilitator_id']?.toString() ?? '';
          List classes = sdpEntry['classes'] ?? [];

          int siteIDInt = int.tryParse(siteID) ?? 0;
          List classData = await dbHelper.getClassData(classID);

          // Try to sync learners from server if we have a classID
          if (classID.isNotEmpty) {
            try {
              await dbHelper.syncLearnersFromServer(classID);
              print('Successfully synced learners for classID: $classID');
            } catch (e) {
              print('Failed to sync learners for classID $classID: $e');
              // Continue with local data even if sync fails
            }
          }

          List learners = await dbHelper.getLearnersForClass(siteIDInt);

          // Create data map with sdp_name for offline login
          Map<String, dynamic> offlineData = {
            'sdp_name': sdpEntry['sdp_name']?.toString() ??
                sdpEntry['client_name']?.toString() ??
                '',
            'sdp_id': sdp,
          };

          _navigateBasedOnRole(role, classID, sdp, classData, learners,
              facilitatorId, classes, offlineData);
        } else {
          // Check facilitator table only if not found in SDP
          Map<String, dynamic>? facilitator =
              await dbHelper.getFacilitator(username, password);

          if (facilitator != null) {
            String role = facilitator['role'];
            if (role == 'Moderator') {
              role = 'Moderator'; // Ensure case consistency with PHP
            }
            String classID = facilitator['classID']?.toString() ?? '';
            String sdp = facilitator['sdp_name'] ?? '';
            List classData = [];
            List learners = [];
            String facilitatorId =
                facilitator['facilitator_id']?.toString() ?? '';
            List classes = facilitator['classes'] ?? [];

            _navigateBasedOnRole(role, classID, sdp, classData, learners,
                facilitatorId, classes, {});
          } else {
            _showError('Invalid email or password');
          }
        }
      } catch (e) {
        _showError('Error during offline login: $e');
        print('Error during offline login: $e');
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_isOffline) {
      // Show alert dialog for no network
      bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Network Connection'),
          content: const Text(
              'No internet connection detected. Would you like to proceed with offline login?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Proceed Offline'),
            ),
          ],
        ),
      );

      if (proceed == true) {
        await _loginOffline();
      }
    } else {
      await _loginOnline();
    }
  }

  void _navigateBasedOnRole(
      String role,
      String classID,
      String sdp,
      List classData,
      List learners,
      String facilitatorId,
      List classes,
      Map<String, dynamic> data) async {
    // Normalize role to lowercase for consistent comparison
    final normalizedRole = role.toLowerCase().trim();

    debugPrint('[NAVIGATION] ===== NAVIGATION DEBUG =====');
    debugPrint('[NAVIGATION] Role: "$normalizedRole"');
    debugPrint('[NAVIGATION] classID: "$classID"');
    debugPrint('[NAVIGATION] sdp: "$sdp"');
    debugPrint('[NAVIGATION] facilitator_id: "$facilitatorId"');
    debugPrint('[NAVIGATION] data keys: ${data.keys.toList()}');
    debugPrint('[NAVIGATION] =============================');

    if (normalizedRole == 'sdp') {
      // SDP users navigate to Projects page with full hierarchical data
      debugPrint('[NAVIGATION] Navigating SDP to Projects Page');
      final projects = data['projects'] ?? [];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SdpProjectsPage(
            sdpIdentifier: sdp,
            sdpDisplayName: data['sdp_name']?.toString(),
            projects: List<Map<String, dynamic>>.from(projects),
          ),
        ),
      );
    } else if (normalizedRole == 'finance') {
      // Finance role - navigate to finance dashboard
      debugPrint('[NAVIGATION] Navigating to Finance Dashboard');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FinanceDashboard(
            financeId: facilitatorId,
            financeName: _usernameController.text.split('@')[0],
          ),
        ),
      );
    } else if (normalizedRole == 'logistics') {
      // Logistics role - navigate to logistics dashboard
      debugPrint('[NAVIGATION] Navigating to Logistics Dashboard');
      // Use account_id for logistics users, fallback to facilitator_id if not available
      final logisticsId = data['account_id']?.toString() ?? facilitatorId;
      final logisticsName = data['account_name']?.toString() ??
          _usernameController.text.split('@')[0];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LogisticsDashboard(
            logisticsId: logisticsId,
            logisticsName: logisticsName,
          ),
        ),
      );
    } else if (normalizedRole == 'assessor') {
      // Use classID to get facilitator (old reliable way)
      await _handleFacilitatorLoginByClassID(
        classID: classID,
        facilitatorId: facilitatorId,
        facilitatorName: 'Assessor',
        onSuccess: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AssessorPage(
                facilitator_id: facilitatorId,
              ),
            ),
          );
        },
      );
    } else if (normalizedRole == 'moderator') {
      // Use classID to get facilitator (old reliable way)
      await _handleFacilitatorLoginByClassID(
        classID: classID,
        facilitatorId: facilitatorId,
        facilitatorName: 'Moderator',
        onSuccess: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ModeratorPage(
                facilitator_id: facilitatorId,
              ),
            ),
          );
        },
      );
    } else {
      // Facilitator role - Use classID (old reliable way)
      debugPrint('[NAVIGATION] Navigating to Facilitator Dashboard');
      await _handleFacilitatorLoginByClassID(
        classID: classID,
        facilitatorId: facilitatorId,
        facilitatorName: 'Facilitator',
        onSuccess: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardPage(
                classID: classID,
                learners: learners,
              ),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RLMS Login'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image.asset(
                "assets/images/logo.png",
                width: MediaQuery.of(context).size.width * 0.5,
                height: MediaQuery.of(context).size.height * 0.2,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Enter email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Enter password' : null,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 15),
                      ),
                      child:
                          const Text('Login', style: TextStyle(fontSize: 16)),
                    ),
              const SizedBox(height: 20),
              Text(
                _connectivityStatus,
                style: TextStyle(
                  color: _isOffline ? Colors.red : Colors.green,
                  fontSize: 12,
                ),
              ),
              Text(
                _databaseStatus,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle facilitator login flow with fingerprint enrollment and daily clock-in
  // Uses classID to get facilitator (OLD RELIABLE WAY)
  Future<void> _handleFacilitatorLoginByClassID({
    required String classID,
    required String facilitatorId,
    required String facilitatorName,
    required VoidCallback onSuccess,
  }) async {
    try {
      // Use classID to get facilitator from database (the old way that works)
      debugPrint('[LOGIN] Getting facilitator by classID: $classID');

      final db = await dbHelper.database;
      final result = await db.query(
        'facilitator',
        where: 'classID = ?',
        whereArgs: [classID],
        limit: 1,
      );

      if (result.isEmpty) {
        debugPrint('[LOGIN] No facilitator found for classID: $classID');
        debugPrint(
            '[LOGIN] Bypassing fingerprint features, proceeding to dashboard');
        // No facilitator in database - bypass fingerprint features
        onSuccess();
        return;
      }

      final facilitator = result.first;
      final facilitatorIdInt = facilitator['facilitator_id'] as int?;

      if (facilitatorIdInt == null) {
        debugPrint(
            '[LOGIN] facilitator_id is null in database for classID: $classID');
        debugPrint(
            '[LOGIN] Bypassing fingerprint features, proceeding to dashboard');
        // No valid ID - bypass fingerprint features
        onSuccess();
        return;
      }

      final firstName = facilitator['firstName']?.toString() ?? '';
      final lastName = facilitator['lastName']?.toString() ?? '';
      final fullName = '$firstName $lastName'.trim();

      debugPrint(
          '[LOGIN] Found facilitator: ID=$facilitatorIdInt, Name=$fullName');

      // Step 0: Sync facilitator data from server (including fingerprints) if online
      if (!_isOffline) {
        try {
          debugPrint('[LOGIN] Syncing facilitator data from server...');
          final syncService = SyncService();
          await syncService.syncFacilitatorData();
          debugPrint('[LOGIN] Facilitator data synced successfully');
        } catch (e) {
          debugPrint('[LOGIN] Failed to sync facilitator data: $e');
          // Continue with local data
        }
      }

      // Step 1: Check if facilitator has fingerprints enrolled (one-time setup)
      final hasFingerprints =
          await dbHelper.facilitatorHasFingerprints(facilitatorIdInt);
      debugPrint(
          '[LOGIN] Facilitator $facilitatorIdInt has fingerprints: $hasFingerprints');

      if (!hasFingerprints) {
        debugPrint(
            '[LOGIN] No fingerprints enrolled for facilitator $facilitatorIdInt');
        // Navigate to fingerprint enrollment (first-time setup)
        final enrolled = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FacilitatorFingerprintPage(
              facilitatorId: facilitatorIdInt,
              facilitatorName: fullName.isNotEmpty ? fullName : facilitatorName,
              isFirstTimeSetup: true,
            ),
          ),
        );

        if (!mounted) return;

        if (enrolled != true) {
          // User didn't complete enrollment, stay on login page
          _showError('Fingerprint enrollment is required to continue');
          return;
        }
      }

      // Step 2: Check if facilitator has clocked in today (daily requirement)
      final clockedInToday =
          await dbHelper.facilitatorClockedInToday(facilitatorIdInt);

      if (!clockedInToday) {
        debugPrint(
            '[LOGIN] Facilitator $facilitatorIdInt has NOT clocked in today');
        // Show message that clock-in is required
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please clock in to start your day'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Navigate to fingerprint page for clock-in (required daily)
        final clockedIn = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FacilitatorFingerprintPage(
              facilitatorId: facilitatorIdInt,
              facilitatorName: fullName.isNotEmpty ? fullName : facilitatorName,
              isFirstTimeSetup: false,
              requireClockIn: true, // Force clock-in mode
            ),
          ),
        );

        if (!mounted) return;

        if (clockedIn != true) {
          // User didn't clock in, stay on login page
          _showError('Clock-in is required to access the dashboard');
          return;
        }
      } else {
        // Already clocked in today, show confirmation
        final clockInTime =
            await dbHelper.getFacilitatorTodayClockIn(facilitatorIdInt);
        debugPrint(
            '[LOGIN] Facilitator $facilitatorIdInt already clocked in at $clockInTime');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Welcome back! Already clocked in at ${clockInTime ?? 'earlier'}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      // Proceed to dashboard
      debugPrint(
          '[LOGIN] Proceeding to dashboard for facilitator $facilitatorIdInt');
      onSuccess();
    } catch (e) {
      debugPrint('[LOGIN] Error in facilitator login flow: $e');
      // If any error occurs, bypass fingerprint and go to dashboard
      debugPrint('[LOGIN] Error occurred, bypassing fingerprint features');
      onSuccess();
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showFacilitatorsList(List<Map<String, dynamic>> facilitators) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Available Facilitators'),
        content: SingleChildScrollView(
          child: Column(
            children: facilitators.map((facilitator) {
              return ListTile(
                title: Text(
                    '${facilitator['firstName']} ${facilitator['lastName']}'),
                subtitle: Text('Password: ${facilitator['password']}'),
              );
            }).toList(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
