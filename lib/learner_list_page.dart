import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'database_helper.dart';
import 'LearnerDetailsPage.dart';
import 'finance_register_history.dart';
import 'package:intl/intl.dart';

import 'config.dart';

class Learner {
  final String? classID;
  final String? learnerID; // Changed to String? to match database usage
  final String? title;
  final String? name;
  final String? surname;
  final String? idNumber;
  final String? dateOfBirth;
  final String? phoneNumber;
  final String? email;
  final String? age;
  final String? gender;
  final String? race;
  final String? language;
  final String? disability;
  final String? addressLine1;
  final String? addressLine2;
  final String? addressLine3;
  final String? postalCode;
  final String? kinName;
  final String? kinRelation;
  final String? kinContact;
  final String? schoolName;
  final String? schoolCompletion;
  final String? schoolLocation;
  final String? schoolGrade;
  final String? bankName;
  final String? bankType;
  final String? bankAccount;
  final String? bankCode;
  final String? profileImage;
  final String? signature;
  final int? synced;
  final String? zktecoLeftTemplate;
  final String? zktecoRightTemplate;
  final String? futronicLeftTemplate;
  final String? futronicRightTemplate;
  final String? imagePath;
  final String? activityStatus;
  final String? witnessInitials;
  final String? learnerInitials;
  final String? witnessSignature;

  Learner({
    this.classID,
    this.learnerID,
    this.title,
    this.name,
    this.surname,
    this.idNumber,
    this.dateOfBirth,
    this.phoneNumber,
    this.email,
    this.age,
    this.gender,
    this.race,
    this.language,
    this.disability,
    this.addressLine1,
    this.addressLine2,
    this.addressLine3,
    this.postalCode,
    this.kinName,
    this.kinRelation,
    this.kinContact,
    this.schoolName,
    this.schoolCompletion,
    this.schoolLocation,
    this.schoolGrade,
    this.bankName,
    this.bankType,
    this.bankAccount,
    this.bankCode,
    this.profileImage,
    this.signature,
    this.synced,
    this.zktecoLeftTemplate,
    this.zktecoRightTemplate,
    this.futronicLeftTemplate,
    this.futronicRightTemplate,
    this.imagePath,
    this.activityStatus,
    this.witnessInitials,
    this.learnerInitials,
    this.witnessSignature,
  });

  factory Learner.fromJson(Map<String, dynamic> json) {
    // Handle DateOfBirth properly
    String? validDateOfBirth;
    String? rawDateOfBirth = json['DateOfBirth']?.toString();

    if (rawDateOfBirth != null &&
        rawDateOfBirth.isNotEmpty &&
        rawDateOfBirth != 'N/A') {
      // Try to parse the date to ensure it's valid
      try {
        // Try different date formats
        List<String> dateFormats = [
          'yyyy-MM-dd',
          'dd/MM/yyyy',
          'MM/dd/yyyy',
          'yyyy/MM/dd'
        ];
        DateTime? parsedDate;

        for (String format in dateFormats) {
          try {
            parsedDate = DateFormat(format).parse(rawDateOfBirth);
            break;
          } catch (e) {
            continue;
          }
        }

        if (parsedDate != null) {
          validDateOfBirth = DateFormat('yyyy-MM-dd').format(parsedDate);
        } else {
          // If we can't parse the date, use null
          validDateOfBirth = null;
        }
      } catch (e) {
        print('Error parsing date in fromJson: $rawDateOfBirth, error: $e');
        validDateOfBirth = null;
      }
    } else {
      validDateOfBirth = null;
    }

    return Learner(
      classID: json['classID']?.toString(),
      learnerID: json['LearnerID']?.toString(),
      title: json['Title']?.toString(),
      name: json['Name']?.toString(),
      surname: json['Surname']?.toString(),
      idNumber: json['IDNumber']?.toString(),
      dateOfBirth: validDateOfBirth,
      phoneNumber: json['PhoneNumber']?.toString(),
      email: json['Email']?.toString(),
      age: json['Age']?.toString(),
      gender: json['Gender']?.toString(),
      race: json['Race']?.toString(),
      language: json['Language']?.toString(),
      disability: json['Disability']?.toString(),
      addressLine1: json['AddressLine1']?.toString(),
      addressLine2: json['AddressLine2']?.toString(),
      addressLine3: json['AddressLine3']?.toString(),
      postalCode: json['PostalCode']?.toString(),
      kinName: json['KinName']?.toString(),
      kinRelation: json['KinRelation']?.toString(),
      kinContact: json['KinContact']?.toString(),
      schoolName: json['SchoolName']?.toString(),
      schoolCompletion: json['SchoolCompletion']?.toString(),
      schoolLocation: json['SchoolLocation']?.toString(),
      schoolGrade: json['SchoolGrade']?.toString(),
      bankName: json['BankName']?.toString(),
      bankType: json['bankType']?.toString(),
      bankAccount: json['BankAccount']?.toString(),
      bankCode: json['BankCode']?.toString(),
      profileImage: json['profile_image']?.toString(),
      signature: json['signature']?.toString(),
      synced: json['synced'] != null
          ? int.tryParse(json['synced'].toString()) ?? 0
          : 0,
      zktecoLeftTemplate: json['zkteco_left_template']?.toString(),
      zktecoRightTemplate: json['zkteco_right_template']?.toString(),
      futronicLeftTemplate: json['futronic_left_template']?.toString(),
      futronicRightTemplate: json['futronic_right_template']?.toString(),
      imagePath: json['imagePath']?.toString(),
      activityStatus: json['activity_statu']?.toString(),
      witnessInitials: json['witness_initials']?.toString(),
      learnerInitials: json['learner_initials']?.toString(),
      witnessSignature: json['witness_signature']?.toString(),
    );
  }
}

class LearnerListPage extends StatefulWidget {
  final String classID;

  const LearnerListPage({super.key, required this.classID});

  @override
  _LearnerListPageState createState() => _LearnerListPageState();
}

class _LearnerListPageState extends State<LearnerListPage> {
  List<Learner> learners = [];
  List<Learner> _filteredLearners = [];
  final TextEditingController _searchController = TextEditingController();
  final List<String> requiredDocuments = [
    'ID Document',
    'Qualifications',
    'Bank Confirmation Letter',
    'Proof of Residence',
    'CV',
    'Business form',
    'Learner agreement'
  ];
  final int _maxFileSize = 5 * 1024 * 1024; // 5MB
  final int _minFileSize = 10 * 1024; // 10KB
  bool _isScanning = false;

  // Server endpoints
  String get _uploadUrl => AppConfig.buildUrl('upload_learner_document.php');
  String get _checkDocsUrl => AppConfig.buildUrl('check_learner_documents.php');

  // Helper function to clean file paths - extract only filename
  String _cleanFilePath(String? filePath) {
    if (filePath == null || filePath.isEmpty) return '';

    // If it's already just a filename (no path separators), return as is
    if (!filePath.contains('/') && !filePath.contains('\\')) {
      return filePath;
    }

    // Extract filename from path
    final pathParts = filePath.split('/');
    if (pathParts.isEmpty) return '';

    final filename = pathParts.last;
    return filename;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterLearners);
    fetchLearnersData();
    _checkForUnsyncedData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterLearners() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      _filteredLearners = List.from(learners);
    } else {
      _filteredLearners = learners.where((learner) {
        final idNumber = learner.idNumber?.toLowerCase() ?? '';
        return idNumber.contains(query);
      }).toList();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _checkForUnsyncedData() async {
    try {
      final dbHelper = DatabaseHelper();
      final unsyncedLearners =
          await dbHelper.fetchUnsyncedLearners(widget.classID);

      if (unsyncedLearners.isNotEmpty) {
        // Show a notification after a short delay to let the UI load
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'You have ${unsyncedLearners.length} unsynced learners. Tap the sync button to upload them.'),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Sync Now',
                  onPressed: () async {
                    await _syncLocalLearnersToServer();
                    await fetchLearnersData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sync completed')),
                    );
                  },
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      print('Error checking for unsynced data: $e');
    }
  }

  Future<void> refreshDocumentStatus() async {
    setState(() {
      // This will trigger a rebuild of the FutureBuilder widgets
    });
  }

  Future<List<Learner>> fetchLearnersFromServer() async {
    try {
      print('Fetching learners from server for classID: ${widget.classID}');
      final response = await http
          .get(
        Uri.parse(AppConfig.buildUrl('get_learners.php',
            queryParams: {'classID': widget.classID.toString()})),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Server request timed out after 10 seconds');
          throw TimeoutException('Server request timed out');
        },
      );

      print('Server response status: ${response.statusCode}');
      print('Server response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> learnersJson = jsonDecode(response.body);
        print('Parsed server response: $learnersJson'); // Debug log
        print(
            'Number of learners received from server: ${learnersJson.length}'); // Debug log

        if (learnersJson.isNotEmpty) {
          print(
              'First learner data from server: ${learnersJson.first}'); // Debug log
          print(
              'Available fields in first learner: ${learnersJson.first.keys.toList()}'); // Debug log
          print('Sample field values:');
          learnersJson.first.forEach((key, value) {
            print('  $key: $value');
          });
        } else {
          print('No learners found on server for classID: ${widget.classID}');
        }

        // No need to filter since the server now returns only learners for the specific classID
        final learners =
            learnersJson.map((json) => Learner.fromJson(json)).toList();
        print('Converted ${learners.length} learners from JSON');
        return learners;
      } else {
        print('Server returned status code: ${response.statusCode}');
        throw Exception(
            'Failed to load learners from server: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching server data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loading from local database (offline)'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return [];
    }
  }

  Future<void> saveLearnersToLocalDatabase(List<Learner> serverLearners) async {
    try {
      final dbHelper = DatabaseHelper();
      print(
          'Saving ${serverLearners.length} server learners to local database');

      for (var learner in serverLearners) {
        final learnerIdStr = learner.learnerID ?? 'N/A';
        print(
            'Processing learner: ${learner.name} ${learner.surname} with ID: $learnerIdStr');
        print('=== LEARNER DATA ANALYSIS ===');
        print('Title: ${learner.title}');
        print('DateOfBirth: ${learner.dateOfBirth}');
        print('PhoneNumber: ${learner.phoneNumber}');
        print('Email: ${learner.email}');
        print('Race: ${learner.race}');
        print('Language: ${learner.language}');
        print('Disability: ${learner.disability}');
        print('AddressLine1: ${learner.addressLine1}');
        print('AddressLine2: ${learner.addressLine2}');
        print('AddressLine3: ${learner.addressLine3}');
        print('PostalCode: ${learner.postalCode}');
        print('KinName: ${learner.kinName}');
        print('KinRelation: ${learner.kinRelation}');
        print('KinContact: ${learner.kinContact}');
        print('SchoolName: ${learner.schoolName}');
        print('SchoolCompletion: ${learner.schoolCompletion}');
        print('SchoolLocation: ${learner.schoolLocation}');
        print('SchoolGrade: ${learner.schoolGrade}');
        print('BankName: ${learner.bankName}');
        print('bankType: ${learner.bankType}');
        print('BankAccount: ${learner.bankAccount}');
        print('BankCode: ${learner.bankCode}');
        print('=== END LEARNER DATA ANALYSIS ===');

        // First, get existing fingerprint templates for this learner (if any)
        Map<String, String?> existingTemplates = {};
        try {
          if (learnerIdStr != 'N/A') {
            final learnerId = int.tryParse(learnerIdStr);
            if (learnerId != null) {
              existingTemplates = await dbHelper.getAllTemplates(learnerId);
              print(
                  '[SYNC] Preserving templates for learner $learnerId: ${existingTemplates.keys.where((k) => existingTemplates[k]?.isNotEmpty == true).toList()}');
            }
          }
        } catch (e) {
          print('[SYNC] Error getting existing templates: $e');
          // Continue with empty templates if there's an error
        }

        // Prepare learner data map with correct field names and comprehensive data
        final learnerData = {
          'classID': widget.classID, // Manually provided classID
          'LearnerID': learner.learnerID ?? 'N/A',
          'Title': learner.title ?? 'N/A',
          'Name': learner.name ?? 'N/A',
          'Surname': learner.surname ?? 'N/A',
          'IDNumber':
              learner.idNumber?.isEmpty ?? true ? 'N/A' : learner.idNumber,
          'DateOfBirth': learner.dateOfBirth ?? 'N/A',
          'PhoneNumber': learner.phoneNumber ?? 'N/A',
          'Email': learner.email ?? 'N/A',
          'Age': int.tryParse(learner.age ?? '0') ?? 0,
          'Gender':
              learner.gender?.isEmpty ?? true ? 'Unknown' : learner.gender,
          'Race': learner.race ?? '',
          'Language': learner.language ?? '',
          'Disability': learner.disability ?? '',
          'AddressLine1': learner.addressLine1 ?? '',
          'AddressLine2': learner.addressLine2 ?? '',
          'AddressLine3': learner.addressLine3 ?? '',
          'PostalCode': learner.postalCode ?? '',
          'KinName': learner.kinName ?? '',
          'KinRelation': learner.kinRelation ?? '',
          'KinContact': learner.kinContact ?? '',
          'SchoolName': learner.schoolName ?? '',
          'SchoolCompletion': learner.schoolCompletion ?? '',
          'SchoolLocation': learner.schoolLocation ?? '',
          'SchoolGrade': learner.schoolGrade ?? '',
          'profile_image': _cleanFilePath(learner.profileImage),
          'signature': _cleanFilePath(learner.signature),
          'synced': 1, // Mark server learners as synced
          // Preserve existing fingerprint templates, only use server data if we don't have local templates
          'zkteco_left_template':
              existingTemplates['zkteco_left_template']?.isNotEmpty == true
                  ? existingTemplates['zkteco_left_template']!
                  : (learner.zktecoLeftTemplate ?? ''),
          'zkteco_right_template':
              existingTemplates['zkteco_right_template']?.isNotEmpty == true
                  ? existingTemplates['zkteco_right_template']!
                  : (learner.zktecoRightTemplate ?? ''),
          'futronic_left_template':
              existingTemplates['futronic_left_template']?.isNotEmpty == true
                  ? existingTemplates['futronic_left_template']!
                  : (learner.futronicLeftTemplate ?? ''),
          'futronic_right_template':
              existingTemplates['futronic_right_template']?.isNotEmpty == true
                  ? existingTemplates['futronic_right_template']!
                  : (learner.futronicRightTemplate ?? ''),
          'imagePath': _cleanFilePath(learner.imagePath),
          'activity_statu': learner.activityStatus ?? '',
          'witness_initials': learner.witnessInitials ?? '',
          'learner_initials': learner.learnerInitials ?? '',
          'witness_signature': _cleanFilePath(learner.witnessSignature),
        };

        print('Prepared learner data with ${learnerData.keys.length} fields');
        print('All learner data fields: ${learnerData.keys.toList()}');

        // Prepare bank data separately since local database has separate bankdetails table
        Map<String, dynamic>? bankData;
        if ((learner.bankName != null && learner.bankName!.isNotEmpty) ||
            (learner.bankType != null && learner.bankType!.isNotEmpty) ||
            (learner.bankAccount != null && learner.bankAccount!.isNotEmpty) ||
            (learner.bankCode != null && learner.bankCode!.isNotEmpty)) {
          bankData = {
            'BankName': learner.bankName ?? '',
            'bankType': learner.bankType ?? '',
            'BankAccount': learner.bankAccount ?? '',
            'BankCode': learner.bankCode ?? '',
          };
          print('Bank data prepared: $bankData');
        } else {
          print('No bank data to save for this learner');
        }

        print(
            'Saving learner data: ${learnerData['Name']} ${learnerData['Surname']} with LearnerID: ${learnerData['LearnerID']}');

        try {
          // Use insertOrUpdate instead of insert to handle existing learners
          final result =
              await dbHelper.insertOrUpdateLearner(learnerData, bankData);
          print('Insert/Update result for ${learnerData['Name']}: $result');

          // Verify the insertion by checking if learner exists in the class
          final classLearners = await dbHelper.fetchLearners(widget.classID);
          final savedLearner = classLearners
              .where((l) =>
                  l['LearnerID']?.toString() == learnerData['LearnerID'] ||
                  l['IDNumber']?.toString() == learnerData['IDNumber'])
              .firstOrNull;

          if (savedLearner != null) {
            print('Verification successful - learner found in database');
            print('Stored fields: ${savedLearner.keys.toList()}');

            // Check specific fields that were problematic
            final fieldsToCheck = [
              'Title',
              'Race',
              'Language',
              'Disability',
              'AddressLine1',
              'AddressLine2',
              'AddressLine3',
              'PostalCode',
              'KinName',
              'KinRelation',
              'KinContact',
              'SchoolName',
              'SchoolCompletion',
              'SchoolLocation',
              'SchoolGrade'
            ];

            for (String field in fieldsToCheck) {
              final storedValue = savedLearner[field];
              final originalValue = learnerData[field];
              if (storedValue != originalValue) {
                print(
                    'FIELD MISMATCH - $field: stored="$storedValue", original="$originalValue"');
              } else {
                print('Field OK - $field: "$storedValue"');
              }
            }

            // Check bank details if they were supposed to be saved
            if (bankData != null && savedLearner['LearnerID'] != null) {
              try {
                final savedBankDetails = await dbHelper
                    .fetchLearnerBankDetails(savedLearner['LearnerID']);
                if (savedBankDetails != null) {
                  print('Bank details verified: $savedBankDetails');
                } else {
                  print('WARNING: Bank details were not saved properly');
                }
              } catch (bankError) {
                print('Error checking bank details: $bankError');
              }
            }
          } else {
            print(
                'ERROR: Learner not found after insertion - this indicates a database problem');
            print(
                'Looking for LearnerID: ${learnerData['LearnerID']} or IDNumber: ${learnerData['IDNumber']}');
            print(
                'Available learners in class: ${classLearners.map((l) => '${l['LearnerID']}-${l['IDNumber']}').toList()}');
          }
        } catch (insertError) {
          print(
              'Error inserting/updating learner ${learnerData['Name']}: $insertError');
          // Continue with next learner instead of failing completely
          continue;
        }
      }

      print(
          'Successfully processed ${serverLearners.length} learners to local database');

      // Summary of sync results
      print('=== SYNC SUMMARY ===');
      print('Total learners processed: ${serverLearners.length}');
      print(
          'Using sync_onlinedetails.php endpoint which returns all learner fields');
      print('All fields should now be populated correctly from server data');
      print('Bank details are stored in separate bankdetails table');
      print(
          'Fingerprint templates are preserved from local database if they exist');
      print('=== END SYNC SUMMARY ===');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Loaded ${serverLearners.length} learners from server with complete data')),
      );
    } catch (e) {
      print('Error saving learners to local database: $e');
      print('Stack trace: ${StackTrace.current}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving to local database: $e')),
      );
    }
  }

  Future<void> loadLearnersFromLocalDatabase() async {
    try {
      print(
          '[LEARNER_LIST] Loading learners from local database for classID: ${widget.classID}');
      final dbHelper = DatabaseHelper();

      // Debug: Check total learners in database
      final db = await dbHelper.database;
      final allLearners = await db.query('learnerdetails');
      print(
          '[LEARNER_LIST] Total learners in entire database: ${allLearners.length}');

      if (allLearners.isNotEmpty) {
        // Show sample of classIDs in database
        final classIds = allLearners.map((l) => l['classID']).toSet().toList();
        print('[LEARNER_LIST] Available classIDs in database: $classIds');
      }

      final localLearners = await dbHelper.fetchLearners(widget.classID);
      print(
          '[LEARNER_LIST] Found ${localLearners.length} learners for classID: ${widget.classID}');

      if (localLearners.isEmpty && allLearners.isNotEmpty) {
        print(
            '[LEARNER_LIST] ⚠️ WARNING: Database has learners but none for classID ${widget.classID}');
        print(
            '[LEARNER_LIST] This class might not have been synced yet, or classID mismatch');
      }

      final learnersList = localLearners
          .map((learnerMap) => Learner.fromJson(learnerMap))
          .toList();
      setState(() {
        learners = learnersList;
      });
      // Initialize filtered list and apply current search filter
      _filterLearners();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Loaded ${learnersList.length} learners from local database'),
            backgroundColor: learnersList.isEmpty ? Colors.red : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[LEARNER_LIST] Error loading local data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading local data: $e')),
        );
      }
    }
  }

  Future<void> fetchLearnersData() async {
    try {
      final isConnected = await _checkConnectivity();

      if (isConnected) {
        print(
            '[LEARNER_LIST] Online - attempting to sync and fetch from server');
        // First, sync any local unsynced learners to server
        await _syncLocalLearnersToServer();

        // Then fetch from server and merge with local data
        final serverLearners = await fetchLearnersFromServer();
        if (serverLearners.isNotEmpty) {
          print(
              '[LEARNER_LIST] Server returned ${serverLearners.length} learners, merging with local data');
          await _mergeServerAndLocalData(serverLearners);
        } else {
          // Server returned empty (could be error or no data)
          print(
              '[LEARNER_LIST] Server returned empty, loading from local database');
          await loadLearnersFromLocalDatabase();
        }
      } else {
        print('[LEARNER_LIST] Offline - loading from local database');
        await loadLearnersFromLocalDatabase();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline mode - showing cached data'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error in fetchLearnersData: $e');
      // Fallback to local data if server fails
      try {
        print('[LEARNER_LIST] Error occurred, falling back to local database');
        await loadLearnersFromLocalDatabase();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loading from local database'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (localError) {
        print('Error loading local data: $localError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading data: $e')),
          );
        }
      }
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _syncLocalLearnersToServer() async {
    try {
      final dbHelper = DatabaseHelper();
      final unsyncedLearners =
          await dbHelper.fetchUnsyncedLearners(widget.classID);

      if (unsyncedLearners.isNotEmpty) {
        print('Found ${unsyncedLearners.length} unsynced learners to sync');

        for (var learner in unsyncedLearners) {
          try {
            final success = await _syncLearnerToServer(learner);
            if (success) {
              // The LearnerID might have been updated by the server response
              // So we need to get the current LearnerID after sync
              final currentLearner =
                  await dbHelper.fetchLearnerByIDNumber(learner['IDNumber']);
              if (currentLearner != null) {
                await dbHelper.markLearnerAsSynced(currentLearner['LearnerID']);
                print(
                    'Successfully synced learner ${learner['Name']} ${learner['Surname']}');
              } else {
                print('Could not find learner after sync to mark as synced');
              }
            } else {
              print(
                  'Failed to sync learner ${learner['Name']} ${learner['Surname']}');
            }
          } catch (e) {
            print(
                'Error syncing learner ${learner['Name']} ${learner['Surname']}: $e');
          }
        }
      }
    } catch (e) {
      print('Error syncing local learners: $e');
    }
  }

  Future<bool> _syncLearnerToServer(Map<String, dynamic> learnerData) async {
    final url = AppConfig.buildUrl("add_learner.php");
    try {
      // Create a copy of learnerData without the local LearnerID
      Map<String, dynamic> syncData = Map.from(learnerData);

      // Remove the local LearnerID to let server assign the correct one
      syncData.remove('LearnerID');

      // Also remove synced field as it's not needed for server
      syncData.remove('synced');

      // Clean file paths to save only filenames
      syncData['profile_image'] = _cleanFilePath(syncData['profile_image']);
      syncData['signature'] = _cleanFilePath(syncData['signature']);
      syncData['witness_signature'] =
          _cleanFilePath(syncData['witness_signature']);

      print(
          'Preparing sync data without local LearnerID: ${syncData.keys.toList()}');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(syncData),
          )
          .timeout(const Duration(seconds: 10));

      print('Sync request body: ${json.encode(syncData)}');
      print('Sync response status: ${response.statusCode}');
      print('Sync response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            // If server returns a LearnerID, update the local database
            if (responseData['LearnerID'] != null) {
              final serverLearnerID = responseData['LearnerID'];
              final localLearnerID = learnerData['LearnerID'];
              final dbHelper = DatabaseHelper();

              // Update the local LearnerID with the server's LearnerID
              await dbHelper.updateLearnerID(localLearnerID, serverLearnerID);
              print(
                  'Updated local LearnerID $localLearnerID to server LearnerID $serverLearnerID');
            }
            return true;
          } else {
            print(
                'Server returned success: false - ${responseData['message']}');
            return false;
          }
        } catch (e) {
          print('JSON parse error: $e');
          return false;
        }
      } else {
        print('Server error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Network error: $e');
      return false;
    }
  }

  Future<void> _mergeServerAndLocalData(List<Learner> serverLearners) async {
    try {
      final dbHelper = DatabaseHelper();

      // First, save server learners to local database
      await saveLearnersToLocalDatabase(serverLearners);

      // Get local learners after saving server data
      final localLearners = await dbHelper.fetchLearners(widget.classID);

      // Create a map of server learners by IDNumber for easy lookup
      final serverLearnersMap = <String, Learner>{};
      for (var learner in serverLearners) {
        if (learner.idNumber != null && learner.idNumber!.isNotEmpty) {
          serverLearnersMap[learner.idNumber!] = learner;
        }
      }

      // Create a map of local learners by IDNumber
      final localLearnersMap = <String, Map<String, dynamic>>{};
      for (var learner in localLearners) {
        if (learner['IDNumber'] != null &&
            learner['IDNumber'].toString().isNotEmpty) {
          localLearnersMap[learner['IDNumber'].toString()] = learner;
        }
      }

      // Merge data: prefer server data but keep local unsynced data
      List<Learner> mergedLearners = [];

      // Add all server learners
      mergedLearners.addAll(serverLearners);

      // Add local learners that are not on server (unsynced)
      for (var localLearner in localLearners) {
        final idNumber = localLearner['IDNumber']?.toString();
        if (idNumber != null && idNumber.isNotEmpty) {
          final isSynced = localLearner['synced'] == 1;
          final notOnServer = !serverLearnersMap.containsKey(idNumber);

          if (!isSynced || notOnServer) {
            // Convert local learner to Learner object and add to merged list
            final learner = Learner.fromJson(localLearner);
            mergedLearners.add(learner);
            print(
                'Added local learner to merged data: ${learner.name} ${learner.surname}');
          }
        }
      }

      // Update the UI with merged data
      setState(() {
        learners = mergedLearners;
      });
      // Apply current search filter after updating learners
      _filterLearners();

      print(
          'Merged ${serverLearners.length} server learners with ${localLearners.length} local learners = ${mergedLearners.length} total');
    } catch (e) {
      print('Error merging server and local data: $e');
      // Fallback to server data only
      setState(() {
        learners = serverLearners;
      });
    }
  }

  Future<bool> hasAllDocuments(String learnerId) async {
    try {
      final dbHelper = DatabaseHelper();
      List<String> existingDocs = [];

      // Check local database
      final localDocs = await dbHelper.fetchLearnerDocuments(learnerId);
      existingDocs =
          localDocs.map((doc) => doc['documentName'] as String).toList();

      // Check server if online
      if (await _checkConnectivity()) {
        final serverDocs = await _fetchServerDocuments(learnerId);
        // Add server documents to the list for checking, but don't insert them locally
        // unless they have actual document content
        for (var doc in serverDocs) {
          if (!existingDocs.contains(doc)) {
            existingDocs.add(doc);
          }
        }
      }

      print('Existing documents for $learnerId: $existingDocs');
      return requiredDocuments.every((doc) => existingDocs.contains(doc));
    } catch (e) {
      print('Error checking documents: $e');
      return false;
    }
  }

  Future<bool> hasAnyDocuments(String learnerId) async {
    try {
      final dbHelper = DatabaseHelper();
      final localDocs = await dbHelper.fetchLearnerDocuments(learnerId);

      // Check if any documents exist locally
      if (localDocs.isNotEmpty) {
        return true;
      }

      // Check server if online
      if (await _checkConnectivity()) {
        final serverDocs = await _fetchServerDocuments(learnerId);
        return serverDocs.isNotEmpty;
      }

      return false;
    } catch (e) {
      print('Error checking documents: $e');
      return false;
    }
  }

  Future<List<String>> getExistingDocuments(String learnerId) async {
    try {
      final dbHelper = DatabaseHelper();
      List<String> existingDocs = [];

      // Check local database
      final localDocs = await dbHelper.fetchLearnerDocuments(learnerId);
      existingDocs =
          localDocs.map((doc) => doc['documentName'] as String).toList();
      print('Local documents for $learnerId: $existingDocs');

      // Check server if online
      if (await _checkConnectivity()) {
        final serverDocs = await _fetchServerDocuments(learnerId);
        print('Server documents for $learnerId: $serverDocs');
        for (var doc in serverDocs) {
          if (!existingDocs.contains(doc)) {
            existingDocs.add(doc);
          }
        }
      } else {
        print('No internet connection, skipping server check for $learnerId');
      }

      print('Combined existing documents for $learnerId: $existingDocs');
      return existingDocs;
    } catch (e) {
      print('Error getting existing documents: $e');
      return [];
    }
  }

  Future<bool> canUploadDocuments(String learnerId) async {
    try {
      final existingDocs = await getExistingDocuments(learnerId);
      // Check if there are any documents that can still be uploaded
      return requiredDocuments.any((doc) => !existingDocs.contains(doc));
    } catch (e) {
      print('Error checking if documents can be uploaded: $e');
      return false;
    }
  }

  Future<void> testServerConnectivity(String learnerId) async {
    try {
      print('Testing server connectivity for learner: $learnerId');
      final isConnected = await _checkConnectivity();
      print('Internet connectivity: $isConnected');

      if (isConnected) {
        final serverDocs = await _fetchServerDocuments(learnerId);
        print('Test completed. Server documents found: $serverDocs');

        // Test with a known learner ID if available
        if (learners.isNotEmpty) {
          final testLearnerId = learners.first.learnerID ?? 'N/A';
          if (testLearnerId != learnerId) {
            print('Testing with first learner ID: $testLearnerId');
            final testDocs = await _fetchServerDocuments(testLearnerId);
            print(
                'Test with first learner completed. Documents found: $testDocs');
          }
        }
      } else {
        print('No internet connection available for testing');
      }
    } catch (e) {
      print('Error testing server connectivity: $e');
    }
  }

  Future<void> testAllLearnerDocuments() async {
    try {
      print('Testing document checking for all learners...');
      final isConnected = await _checkConnectivity();
      if (!isConnected) {
        print('No internet connection available');
        return;
      }

      for (var learner in learners.take(3)) {
        // Test first 3 learners
        final learnerId = learner.learnerID ?? 'N/A';
        print(
            'Testing learner: $learnerId (${learner.name} ${learner.surname})');

        final existingDocs = await getExistingDocuments(learnerId);
        final canUpload = await canUploadDocuments(learnerId);

        print('  - Existing documents: $existingDocs');
        print('  - Can upload documents: $canUpload');
        print('  - Required documents: $requiredDocuments');
      }
    } catch (e) {
      print('Error testing all learner documents: $e');
    }
  }

  Future<void> testBankDataInsertion() async {
    try {
      print('Testing bank data insertion...');
      final dbHelper = DatabaseHelper();

      // Test data
      final testLearnerData = {
        'classID': widget.classID,
        'Title': 'Mr.',
        'Name': 'Test',
        'Surname': 'BankUser',
        'IDNumber': '1234567890123',
        'DateOfBirth': '1990-01-01',
        'PhoneNumber': '1234567890',
        'Email': 'test@example.com',
        'Age': '33',
        'Gender': 'Male',
        'Race': 'African',
        'Language': 'English',
        'Disability': 'None',
        'AddressLine1': 'Test Address',
        'AddressLine2': '',
        'AddressLine3': '',
        'PostalCode': '1234',
        'KinName': 'Test Kin',
        'KinRelation': 'Parent',
        'KinContact': '0987654321',
        'SchoolName': 'Test School',
        'SchoolCompletion': '2010',
        'SchoolLocation': 'Test Location',
        'SchoolGrade': '12',
        'profile_image': '',
        'signature': '',
        'synced': 0,
        'zkteco_left_template': '',
        'zkteco_right_template': '',
        'futronic_left_template': '',
        'futronic_right_template': '',
        'imagePath': '',
        'activity_statu': '',
        'witness_initials': '',
        'learner_initials': '',
        'witness_signature': '',
      };

      final testBankData = {
        'BankName': 'ABSA',
        'bankType': 'Savings',
        'BankAccount': '1234567890',
        'BankCode': '632005',
      };

      print('Test learner data: $testLearnerData');
      print('Test bank data: $testBankData');

      final learnerId =
          await dbHelper.insertOrUpdateLearner(testLearnerData, testBankData);
      print('Test learner inserted with ID: $learnerId');

      // Verify the insertion
      final insertedLearner = await dbHelper.fetchLearners(widget.classID);
      final lastLearner = insertedLearner.last;
      print('Last inserted learner: $lastLearner');

      if (lastLearner['LearnerID'] != null) {
        final bankDetails =
            await dbHelper.fetchLearnerBankDetails(lastLearner['LearnerID']);
        print('Bank details for test learner: $bankDetails');
      }

      // Show all bank details
      final allBankDetails = await dbHelper.fetchAllBankDetails();
      print('All bank details in database: $allBankDetails');
    } catch (e) {
      print('Error testing bank data insertion: $e');
    }
  }

  Future<List<String>> _fetchServerDocuments(String learnerId) async {
    try {
      print('Fetching server documents for learner: $learnerId');
      print('Request URL: $_checkDocsUrl');
      print('Request body: {"learner_id": "$learnerId"}');

      final response = await http.post(
        Uri.parse(_checkDocsUrl),
        body: {'learner_id': learnerId},
      ).timeout(const Duration(seconds: 10));

      print('Server response status: ${response.statusCode}');
      print('Server response headers: ${response.headers}');
      print('Server response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final jsonResponse = jsonDecode(response.body);
          print('Parsed JSON response: $jsonResponse');

          if (jsonResponse['success'] == true) {
            final documents = List<String>.from(jsonResponse['documents']);
            print('Successfully fetched server documents: $documents');
            return documents;
          } else {
            print('Server returned error: ${jsonResponse['message']}');
            throw Exception(jsonResponse['message']);
          }
        } catch (e) {
          print('Error parsing JSON response: $e');
          print('Raw response: ${response.body}');
          return [];
        }
      } else {
        print('Server error: ${response.statusCode}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching server documents: $e');
      return [];
    }
  }

  Future<void> _syncDocument(Map<String, dynamic> document) async {
    try {
      final filePath = document['learner_document'] as String;
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Document file not found: $filePath');
      }

      var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['learner_id'] = document['learner_id'].toString();
      request.fields['documentName'] = document['documentName'];
      request.fields['status'] = document['status'];
      request.fields['upload_date'] = document['upload_date'];
      request.fields['synced'] = '1';
      if (document['rejection_reason'] != null) {
        request.fields['rejection_reason'] = document['rejection_reason'];
      }

      request.files.add(await http.MultipartFile.fromPath(
        'learner_document',
        filePath,
        filename: filePath.split('/').last,
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print('Sync response status: ${response.statusCode}');
      print('Sync response body: $responseBody');

      if (response.statusCode == 200) {
        try {
          final jsonResponse = jsonDecode(responseBody);
          if (jsonResponse['success'] == true) {
            final dbHelper = DatabaseHelper();
            await dbHelper.updateLearnerDocumentSynced(
                document['document_id'], 1);
            print(
                'Document synced: ${document['documentName']} for learner ${document['learner_id']}');
          } else {
            throw Exception(
                jsonResponse['message'] ?? 'Failed to sync document');
          }
        } catch (e) {
          throw Exception('Invalid JSON response: $responseBody');
        }
      } else {
        throw Exception('Server error: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      print('Error syncing document: $e');
      rethrow;
    }
  }

  Future<void> syncUnsyncedDocuments() async {
    if (!await _checkConnectivity()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection, cannot sync')),
      );
      return;
    }

    try {
      final dbHelper = DatabaseHelper();
      final unsyncedDocs = await dbHelper.fetchUnsyncedLearnerDocuments();
      print('Found ${unsyncedDocs.length} unsynced documents');

      for (var doc in unsyncedDocs) {
        await _syncDocument(doc);
      }

      if (unsyncedDocs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Synced ${unsyncedDocs.length} documents to server')),
        );
      }

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error syncing documents: $e')),
      );
    }
  }

  Future<void> uploadDocument(
      String learnerId, String documentName, String filePath) async {
    try {
      final dbHelper = DatabaseHelper();
      final document = {
        'learner_id': learnerId,
        'documentName': documentName,
        'learner_document': filePath,
        'status': 'Pending',
        'upload_date': DateTime.now().toIso8601String(),
        'synced': 0,
      };
      await dbHelper.insertLearnerDocument(document);

      // Update the UI without a full refresh
      setState(() {
        // No need to reload all learners, just update the document status if needed
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$documentName uploaded locally')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload $documentName: $e')),
      );
      rethrow;
    }
  }

  void showDocumentUploadModal(BuildContext context, String learnerId) {
    String? selectedDocument;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return FutureBuilder<List<String>>(
              future: getExistingDocuments(learnerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AlertDialog(
                    title: Text('Loading...'),
                    content: Center(child: CircularProgressIndicator()),
                  );
                }

                final existingDocs = snapshot.data ?? [];
                final availableDocs = requiredDocuments
                    .where((doc) => !existingDocs.contains(doc))
                    .toList();

                if (availableDocs.isEmpty) {
                  return AlertDialog(
                    title: const Text('All Documents Uploaded'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'All required documents have already been uploaded for this learner.'),
                        const SizedBox(height: 8),
                        Text('Existing documents: ${existingDocs.join(', ')}'),
                        const SizedBox(height: 8),
                        Text(
                            'Required documents: ${requiredDocuments.join(', ')}'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  );
                }

                return AlertDialog(
                  title: const Text('Upload Document'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Available documents to upload: ${availableDocs.length}/${requiredDocuments.length}'),
                      const SizedBox(height: 8),
                      if (existingDocs.isNotEmpty)
                        Text('Already uploaded: ${existingDocs.join(', ')}'),
                      const SizedBox(height: 16),
                      DropdownButton<String>(
                        hint: const Text('Select Document Type'),
                        value: selectedDocument,
                        isExpanded: true,
                        items: availableDocs.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedDocument = newValue;
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: selectedDocument == null || _isScanning
                          ? null
                          : () async {
                              setState(() => _isScanning = true);
                              try {
                                final status =
                                    await Permission.camera.request();
                                if (!status.isGranted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Camera permission denied. Please enable it in settings.',
                                      ),
                                    ),
                                  );
                                  await openAppSettings();
                                  return;
                                }

                                final scanner = FlutterDocScanner();
                                // Allow unlimited pages (999) for CV and learner agreements
                                final scanResult =
                                    await scanner.getScanDocuments(
                                  page: 999, // Unlimited pages
                                );
                                if (scanResult is! Map ||
                                    !scanResult.containsKey('pdfUri') ||
                                    scanResult['pdfUri'] == null) {
                                  throw 'Invalid scan result';
                                }

                                final pdfPath = (scanResult['pdfUri'] as String)
                                    .replaceFirst('file:///', '');
                                final file = File(pdfPath);

                                if (!await file.exists() ||
                                    !pdfPath.endsWith('.pdf')) {
                                  throw 'Invalid or missing PDF file';
                                }

                                final fileSize = await file.length();
                                if (fileSize > _maxFileSize) {
                                  throw 'File size exceeds 5MB limit';
                                }
                                if (fileSize < _minFileSize) {
                                  throw 'The scanned page may not be clear. Ensure text is sharp and entire page is captured.';
                                }

                                await uploadDocument(
                                    learnerId, selectedDocument!, pdfPath);
                                // Avoid full refresh, just close the dialog
                                Navigator.pop(context);
                                // Refresh document status
                                refreshDocumentStatus();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Error scanning document: $e')),
                                );
                              } finally {
                                setState(() => _isScanning = false);
                              }
                            },
                      child: const Text('Scan and Upload'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learner Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await _syncLocalLearnersToServer();
              await fetchLearnersData(); // Refresh the list after sync
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync completed')),
              );
            },
            tooltip: 'Sync Learners',
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: syncUnsyncedDocuments,
            tooltip: 'Sync Documents',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              if (learners.isNotEmpty) {
                testServerConnectivity(learners.first.learnerID ?? 'N/A');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Check console for server test results')),
                );
              }
            },
            tooltip: 'Test Server Connectivity',
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              testAllLearnerDocuments();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Check console for all learners test results')),
              );
            },
            tooltip: 'Test All Learners',
          ),
          IconButton(
            icon: const Icon(Icons.storage),
            onPressed: () async {
              final dbHelper = DatabaseHelper();
              await dbHelper.debugDatabaseStructure();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Check console for database structure debug info')),
              );
            },
            tooltip: 'Debug Database',
          ),
          IconButton(
            icon: const Icon(Icons.account_balance),
            onPressed: () async {
              await testBankDataInsertion();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Check console for bank data insertion test results')),
              );
            },
            tooltip: 'Test Bank Insertion',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Class ID: ${widget.classID}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Search bar for ID number
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search learner by ID number...',
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (_) => _filterLearners(),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterLearners();
                        },
                        tooltip: 'Clear search',
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: learners.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      await _syncLocalLearnersToServer();
                      await fetchLearnersData();
                      refreshDocumentStatus();
                    },
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Learner ID')),
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Surname')),
                            DataColumn(label: Text('ID Number')),
                            DataColumn(label: Text('Age')),
                            DataColumn(label: Text('Gender')),
                            DataColumn(label: Text('Action')),
                          ],
                          rows: (_searchController.text.isNotEmpty
                                  ? _filteredLearners
                                  : learners)
                              .map((learner) {
                            return DataRow(cells: [
                              DataCell(Text(learner.learnerID ?? 'N/A')),
                              DataCell(Text(learner.name ?? '')),
                              DataCell(Text(learner.surname ?? '')),
                              DataCell(Text(learner.idNumber ?? '')),
                              DataCell(Text(learner.age ?? '')),
                              DataCell(Text(learner.gender ?? '')),
                              DataCell(
                                Row(
                                  children: [
                                    FutureBuilder<bool>(
                                      future: hasAnyDocuments(
                                          learner.learnerID ?? 'N/A'),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const CircularProgressIndicator();
                                        }
                                        bool hasDocuments =
                                            snapshot.data ?? false;
                                        return ElevatedButton(
                                          onPressed: hasDocuments
                                              ? () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          LearnerDetailsPage(
                                                        learnerID:
                                                            learner.learnerID ??
                                                                'N/A',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: hasDocuments
                                                ? Colors.blue
                                                : Colors.grey,
                                          ),
                                          child: const Text('View'),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    FutureBuilder<bool>(
                                      future: canUploadDocuments(
                                          learner.learnerID ?? 'N/A'),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const CircularProgressIndicator();
                                        }
                                        bool canUpload = snapshot.data ?? false;
                                        return ElevatedButton(
                                          onPressed: !canUpload || _isScanning
                                              ? null
                                              : () => showDocumentUploadModal(
                                                    context,
                                                    learner.learnerID ?? 'N/A',
                                                  ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: canUpload
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                          child: const Text('Documents'),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        final learnerName =
                                            '${learner.surname ?? ''} ${learner.name ?? ''}'
                                                .trim();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                FinanceRegisterHistory(
                                              learnerId:
                                                  learner.learnerID ?? 'N/A',
                                              learnerName: learnerName,
                                              classId: widget.classID,
                                              className:
                                                  'Class ${widget.classID}',
                                              financeId: widget
                                                  .classID, // Use classID as financeId
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                      ),
                                      child: const Text('Attendance'),
                                    ),
                                  ],
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddLearnerPage(
                classID: widget.classID,
              ),
            ),
          ).then((_) => fetchLearnersData());
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddLearnerPage extends StatefulWidget {
  final String classID;

  const AddLearnerPage({super.key, required this.classID});

  @override
  _AddLearnerPageState createState() => _AddLearnerPageState();
}

class _AddLearnerPageState extends State<AddLearnerPage> {
  // Controllers for form fields
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _dobController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressStreetController = TextEditingController();
  final _addressSuburbController = TextEditingController();
  final _addressCityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _schoolCompletionController = TextEditingController();
  final _schoolLocationController = TextEditingController();
  final _schoolGradeController = TextEditingController();
  final _kinNameController = TextEditingController();
  final _kinRelationController = TextEditingController();
  final _kinContactController = TextEditingController();
  final _bankAccountTypeController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _bankBranchCodeController = TextEditingController();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  bool _isValidSAId = false;

  // Dropdown selections
  String? _selectedTitle;
  String? _selectedGender;
  String? _selectedRace;
  String? _selectedLanguage;
  String? _selectedDisability;
  String? _selectedBank;

  // Helper function to clean file paths - extract only filename
  String _cleanFilePath(String? filePath) {
    if (filePath == null || filePath.isEmpty) return '';

    // If it's already just a filename (no path separators), return as is
    if (!filePath.contains('/') && !filePath.contains('\\')) {
      return filePath;
    }

    // Extract filename from path
    final pathParts = filePath.split('/');
    if (pathParts.isEmpty) return '';

    final filename = pathParts.last;
    return filename;
  }

  // Date picker method
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        _dobController.text = pickedDate.toIso8601String().split('T')[0];
      });
    }
  }

  @override
  void dispose() {
    // Clean up all controllers
    _nameController.dispose();
    _surnameController.dispose();
    _idNumberController.dispose();
    _dobController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _addressStreetController.dispose();
    _addressSuburbController.dispose();
    _addressCityController.dispose();
    _postalCodeController.dispose();
    _schoolNameController.dispose();
    _schoolCompletionController.dispose();
    _schoolLocationController.dispose();
    _schoolGradeController.dispose();
    _kinNameController.dispose();
    _kinRelationController.dispose();
    _kinContactController.dispose();
    _bankAccountTypeController.dispose();
    _bankAccountNumberController.dispose();
    _bankBranchCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Learner'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Class ID (non-editable)
                TextFormField(
                  initialValue: widget.classID,
                  decoration: const InputDecoration(
                    labelText: 'Class ID',
                    border: OutlineInputBorder(),
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 16),

                // Learner Details Section
                const Text(
                  'Learner Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Enter learner's name",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter name'
                      : null,
                ),
                const SizedBox(height: 16),

                // Surname
                TextFormField(
                  controller: _surnameController,
                  decoration: const InputDecoration(
                    labelText: "Enter learner's surname",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter surname'
                      : null,
                ),
                const SizedBox(height: 16),

                // Title Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedTitle,
                  decoration: const InputDecoration(
                    labelText: 'Select Title',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Mr.', child: Text('Mr.')),
                    DropdownMenuItem(value: 'Ms.', child: Text('Ms.')),
                    DropdownMenuItem(value: 'Dr.', child: Text('Dr.')),
                    DropdownMenuItem(value: 'Prof.', child: Text('Prof.')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedTitle = value;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Please select a title' : null,
                ),
                const SizedBox(height: 16),

                // ID Number with validation and auto-population
                TextFormField(
                  controller: _idNumberController,
                  decoration: InputDecoration(
                    labelText: 'Enter ID number',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _isValidSAId ? Colors.grey : Colors.red,
                        width: _isValidSAId ? 1.0 : 2.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _isValidSAId ? Colors.grey : Colors.red,
                        width: _isValidSAId ? 1.0 : 2.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _isValidSAId ? Colors.blue : Colors.red,
                        width: 2.0,
                      ),
                    ),
                    helperText: _isValidSAId
                        ? 'Enter 13-digit South African ID number'
                        : null,
                    errorText:
                        !_isValidSAId && _idNumberController.text.isNotEmpty
                            ? 'Not a valid SA ID number'
                            : null,
                    errorStyle: const TextStyle(color: Colors.red),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 13,
                  onChanged: (value) {
                    _validateAndExtractFromId(value);
                  },
                  validator: _validateIdNumber,
                ),
                const SizedBox(height: 16),

                // Date of Birth (auto-populated from ID)
                TextFormField(
                  controller: _dobController,
                  readOnly: !_isValidSAId,
                  enabled: _isValidSAId,
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    border: const OutlineInputBorder(),
                    helperText: _isValidSAId
                        ? 'Auto-populated from ID number or tap to select'
                        : 'Enter valid SA ID number first',
                    helperStyle: TextStyle(
                      color: _isValidSAId ? Colors.grey[600] : Colors.red,
                    ),
                    disabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey, width: 1.0),
                    ),
                  ),
                  onTap: _isValidSAId ? () => _selectDate(context) : null,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please select date of birth'
                      : null,
                ),
                const SizedBox(height: 16),

                // Contact Number
                TextFormField(
                  controller: _contactNumberController,
                  decoration: const InputDecoration(
                    labelText: "Enter learner's contact number",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter contact number'
                      : null,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Enter learner's email",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // Age (auto-populated from ID)
                TextFormField(
                  controller: _ageController,
                  readOnly: true,
                  enabled: _isValidSAId,
                  decoration: InputDecoration(
                    labelText: "Learner's age",
                    border: const OutlineInputBorder(),
                    helperText: _isValidSAId
                        ? 'Auto-calculated from ID number'
                        : 'Enter valid SA ID number first',
                    helperStyle: TextStyle(
                      color: _isValidSAId ? Colors.grey[600] : Colors.red,
                    ),
                    disabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey, width: 1.0),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid age';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Gender Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Please select a gender' : null,
                ),
                const SizedBox(height: 16),

                // Race Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedRace,
                  decoration: const InputDecoration(
                    labelText: 'Select Race',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'African', child: Text('African')),
                    DropdownMenuItem(value: 'Indian', child: Text('Indian')),
                    DropdownMenuItem(
                        value: 'Coloured', child: Text('Coloured')),
                    DropdownMenuItem(value: 'White', child: Text('White')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRace = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Home Language Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Select Language',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'IsiZulu', child: Text('IsiZulu')),
                    DropdownMenuItem(
                        value: 'IsiXhosa', child: Text('IsiXhosa')),
                    DropdownMenuItem(
                        value: 'Afrikaans', child: Text('Afrikaans')),
                    DropdownMenuItem(value: 'English', child: Text('English')),
                    DropdownMenuItem(
                        value: 'IsiNdebele', child: Text('IsiNdebele')),
                    DropdownMenuItem(value: 'Sepedi', child: Text('Sepedi')),
                    DropdownMenuItem(value: 'Sesotho', child: Text('Sesotho')),
                    DropdownMenuItem(
                        value: 'Setswana', child: Text('Setswana')),
                    DropdownMenuItem(value: 'SiSwati', child: Text('SiSwati')),
                    DropdownMenuItem(
                        value: 'Tshivenda', child: Text('Tshivenda')),
                    DropdownMenuItem(
                        value: 'Xitsonga', child: Text('Xitsonga')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedLanguage = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Residential Address Line 1 (Street)
                TextFormField(
                  controller: _addressStreetController,
                  decoration: const InputDecoration(
                    labelText: 'Enter street name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Residential Address Line 2 (Suburb)
                TextFormField(
                  controller: _addressSuburbController,
                  decoration: const InputDecoration(
                    labelText: 'Enter suburb',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Residential Address Line 3 (City/Town)
                TextFormField(
                  controller: _addressCityController,
                  decoration: const InputDecoration(
                    labelText: 'Enter city or town',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Postal Code
                TextFormField(
                  controller: _postalCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Enter postal code',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Disability Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedDisability,
                  decoration: const InputDecoration(
                    labelText: 'Select Disability',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'None', child: Text('None')),
                    DropdownMenuItem(
                        value: 'Physical', child: Text('Physical')),
                    DropdownMenuItem(value: 'Visual', child: Text('Visual')),
                    DropdownMenuItem(value: 'Hearing', child: Text('Hearing')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedDisability = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // High School Details Section
                const Text(
                  'High School Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // School Name
                TextFormField(
                  controller: _schoolNameController,
                  decoration: const InputDecoration(
                    labelText: 'Enter school name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Year of Completion
                TextFormField(
                  controller: _schoolCompletionController,
                  decoration: const InputDecoration(
                    labelText: 'Enter year of completion',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // School Location
                TextFormField(
                  controller: _schoolLocationController,
                  decoration: const InputDecoration(
                    labelText: 'Enter school location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Grade
                TextFormField(
                  controller: _schoolGradeController,
                  decoration: const InputDecoration(
                    labelText: 'Enter highest grade passed',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Next of Kin Details Section
                const Text(
                  'Next of Kin Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Kin Name
                TextFormField(
                  controller: _kinNameController,
                  decoration: const InputDecoration(
                    labelText: "Enter next of kin's name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Kin Relation
                TextFormField(
                  controller: _kinRelationController,
                  decoration: const InputDecoration(
                    labelText: 'Enter relation',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Kin Contact Number
                TextFormField(
                  controller: _kinContactController,
                  decoration: const InputDecoration(
                    labelText: 'Enter contact number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Bank Details Section
                const Text(
                  'Bank Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Bank Name Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedBank,
                  decoration: const InputDecoration(
                    labelText: 'Select a Bank',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ABSA', child: Text('ABSA')),
                    DropdownMenuItem(value: 'FNB', child: Text('FNB')),
                    DropdownMenuItem(value: 'Nedbank', child: Text('Nedbank')),
                    DropdownMenuItem(
                        value: 'Standard Bank', child: Text('Standard Bank')),
                    DropdownMenuItem(value: 'Capitec', child: Text('Capitec')),
                    DropdownMenuItem(
                        value: 'TymeBank', child: Text('Tyme Bank')),
                    DropdownMenuItem(value: 'Ithala', child: Text('Ithala')),
                    DropdownMenuItem(value: 'Bidvest', child: Text('Bidvest')),
                    DropdownMenuItem(
                        value: 'OldMutual', child: Text('Old Mutual')),
                    DropdownMenuItem(
                        value: 'AfricanBank', child: Text('African Bank')),
                    DropdownMenuItem(
                        value: 'Discovery', child: Text('Discovery')),
                    DropdownMenuItem(
                        value: 'PostBank', child: Text('Post Bank')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedBank = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Type of Account
                TextFormField(
                  controller: _bankAccountTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Enter bank account type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Account Number
                TextFormField(
                  controller: _bankAccountNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Enter account number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Branch Code
                TextFormField(
                  controller: _bankBranchCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Enter branch code',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      // Validate classID
                      if (widget.classID.isEmpty ||
                          int.tryParse(widget.classID) == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid Class ID')),
                        );
                        return;
                      }

                      final learnerData = {
                        'classID':
                            widget.classID, // Use string as per Learner class
                        'Title': _selectedTitle ?? 'N/A',
                        'Name': _nameController.text,
                        'Surname': _surnameController.text,
                        'IDNumber': _idNumberController.text,
                        'DateOfBirth': _dobController.text.isEmpty
                            ? 'N/A'
                            : _dobController.text,
                        'PhoneNumber': _contactNumberController.text.isEmpty
                            ? 'N/A'
                            : _contactNumberController.text,
                        'Email': _emailController.text.isEmpty
                            ? 'N/A'
                            : _emailController.text,
                        'Age': _ageController.text.isEmpty
                            ? '0'
                            : int.tryParse(_ageController.text)?.toString() ??
                                '0',
                        'Gender': _selectedGender ?? 'Unknown',
                        'Race': _selectedRace ?? '',
                        'Language': _selectedLanguage ?? '',
                        'Disability': _selectedDisability ?? '',
                        'AddressLine1': _addressStreetController.text.isEmpty
                            ? ''
                            : _addressStreetController.text,
                        'AddressLine2': _addressSuburbController.text.isEmpty
                            ? ''
                            : _addressSuburbController.text,
                        'AddressLine3': _addressCityController.text.isEmpty
                            ? ''
                            : _addressCityController.text,
                        'PostalCode': _postalCodeController.text.isEmpty
                            ? ''
                            : _postalCodeController.text,
                        'KinName': _kinNameController.text.isEmpty
                            ? ''
                            : _kinNameController.text,
                        'KinRelation': _kinRelationController.text.isEmpty
                            ? ''
                            : _kinRelationController.text,
                        'KinContact': _kinContactController.text.isEmpty
                            ? ''
                            : _kinContactController.text,
                        'SchoolName': _schoolNameController.text.isEmpty
                            ? ''
                            : _schoolNameController.text,
                        'SchoolCompletion':
                            _schoolCompletionController.text.isEmpty
                                ? ''
                                : _schoolCompletionController.text,
                        'SchoolLocation': _schoolLocationController.text.isEmpty
                            ? ''
                            : _schoolLocationController.text,
                        'SchoolGrade': _schoolGradeController.text.isEmpty
                            ? ''
                            : _schoolGradeController.text,
                        'BankName': _selectedBank ?? '',
                        'bankType': _bankAccountTypeController.text.isEmpty
                            ? ''
                            : _bankAccountTypeController.text,
                        'BankAccount': _bankAccountNumberController.text.isEmpty
                            ? ''
                            : _bankAccountNumberController.text,
                        'BankCode': _bankBranchCodeController.text.isEmpty
                            ? ''
                            : _bankBranchCodeController.text,
                        'profile_image': '',
                        'signature': '',
                        'synced': 0,
                        'zkteco_right_template': '',
                        'imagePath': '',
                        'zkteco_left_template': '',
                        'activity_statu': '',
                        'witness_initials': '',
                        'learner_initials': '',
                        'witness_signature': '',
                      };

                      // Remove bank details if BankName is empty
                      if (learnerData['BankName'] == '') {
                        learnerData
                          ..remove('bankType')
                          ..remove('BankAccount')
                          ..remove('BankCode');
                      }

                      print('Request body: ${json.encode(learnerData)}');

                      final success =
                          await _submitLearnerData(context, learnerData);
                      if (success) {
                        Navigator.pop(context, true);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'SAVE LEARNER',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // South African ID validation function
  String? _validateIdNumber(String? value) {
    if (value == null || value.isEmpty) return 'ID number is required';
    if (value.length != 13) return 'SA ID must be exactly 13 digits';
    if (!RegExp(r'^\d{13}$').hasMatch(value)) {
      return 'ID number must contain only digits';
    }

    int year = int.parse(value.substring(0, 2));
    int month = int.parse(value.substring(2, 4));
    int day = int.parse(value.substring(4, 6));
    int fullYear = year <= 21 ? 2000 + year : 1900 + year;

    if (month < 1 || month > 12) return 'Invalid month in ID number';
    if (day < 1 || day > 31) return 'Invalid day in ID number';

    List<int> daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 &&
        (fullYear % 4 == 0 && fullYear % 100 != 0 || fullYear % 400 == 0)) {
      daysInMonth[1] = 29;
    }
    if (day > daysInMonth[month - 1]) return 'Invalid date in ID number';

    // Luhn algorithm check for SA ID
    int sum = 0;
    for (int i = 0; i < 12; i += 2) {
      sum += int.parse(value[i]);
    }

    String evenDigits = '';
    for (int i = 1; i < 12; i += 2) {
      evenDigits += value[i];
    }

    int evenSum = int.parse(evenDigits) * 2;
    String evenSumStr = evenSum.toString();
    for (int i = 0; i < evenSumStr.length; i++) {
      sum += int.parse(evenSumStr[i]);
    }

    int checkDigit = (10 - (sum % 10)) % 10;
    if (checkDigit != int.parse(value[12])) {
      return 'Invalid SA ID number checksum';
    }

    return null;
  }

  // Extract date of birth and age from SA ID number
  void _validateAndExtractFromId(String idNumber) {
    setState(() {
      if (idNumber.length == 13 && _validateIdNumber(idNumber) == null) {
        _isValidSAId = true;
        _extractDateAndAgeFromId(idNumber);
      } else {
        _isValidSAId = false;
        // Clear date and age fields if ID is invalid
        _dobController.clear();
        _ageController.clear();
      }
    });
  }

  void _extractDateAndAgeFromId(String idNumber) {
    if (idNumber.length == 13 && RegExp(r'^\d{13}$').hasMatch(idNumber)) {
      int year = int.parse(idNumber.substring(0, 2));
      int month = int.parse(idNumber.substring(2, 4));
      int day = int.parse(idNumber.substring(4, 6));

      // Determine full year (assuming cutoff at 21 for 2000s)
      int fullYear = year <= 21 ? 2000 + year : 1900 + year;

      // Validate date before setting
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        try {
          DateTime birthDate = DateTime(fullYear, month, day);
          DateTime today = DateTime.now();

          // Calculate age
          int age = today.year - birthDate.year;
          if (today.month < birthDate.month ||
              (today.month == birthDate.month && today.day < birthDate.day)) {
            age--;
          }

          setState(() {
            _dobController.text =
                '${fullYear.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            _ageController.text = age.toString();
          });
        } catch (e) {
          // Invalid date, don't populate
          print('Invalid date extracted from ID: $e');
        }
      }
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<bool> _submitLearnerData(
      BuildContext context, Map<String, dynamic> learnerData) async {
    try {
      bool isConnected = await _checkConnectivity();
      final dbHelper = DatabaseHelper();

      // Separate learner data from bank data
      Map<String, dynamic> learnerOnlyData = Map.from(learnerData);
      Map<String, dynamic>? bankData;

      // Clean file paths to save only filenames
      learnerOnlyData['profile_image'] =
          _cleanFilePath(learnerOnlyData['profile_image']);
      learnerOnlyData['signature'] =
          _cleanFilePath(learnerOnlyData['signature']);
      learnerOnlyData['witness_signature'] =
          _cleanFilePath(learnerOnlyData['witness_signature']);

      // Extract bank data if present
      if (learnerOnlyData.containsKey('BankName') &&
          learnerOnlyData['BankName'] != null &&
          learnerOnlyData['BankName'].toString().isNotEmpty) {
        bankData = {
          'BankName': learnerOnlyData['BankName'],
          'bankType': learnerOnlyData['bankType'] ?? '',
          'BankAccount': learnerOnlyData['BankAccount'] ?? '',
          'BankCode': learnerOnlyData['BankCode'] ?? '',
        };

        // Remove bank fields from learner data
        learnerOnlyData.remove('BankName');
        learnerOnlyData.remove('bankType');
        learnerOnlyData.remove('BankAccount');
        learnerOnlyData.remove('BankCode');
      }

      if (!isConnected) {
        // Offline: Save locally only with temporary ID
        final id =
            await dbHelper.insertOrUpdateLearner(learnerOnlyData, bankData);
        if (id > 0) {
          await dbHelper.syncBankDetails();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Learner saved to local database successfully!${bankData != null ? ' Bank details also saved. Will sync when online.' : ' Will sync when online.'}',
              ),
            ),
          );
          return true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save learner locally')),
          );
          return false;
        }
      } else {
        // Online: Save to server first to get the server LearnerID
        final serverResponse =
            await _sendToBackendAndGetLearnerID(context, learnerData);

        if (serverResponse['success']) {
          // Save locally with the server's LearnerID
          final serverLearnerID = serverResponse['learnerID'];
          learnerOnlyData['LearnerID'] = serverLearnerID;
          learnerOnlyData['synced'] = 1; // Mark as synced since it's on server

          try {
            final localId =
                await dbHelper.insertOrUpdateLearner(learnerOnlyData, bankData);
            print(
                'Saved locally with server LearnerID: $serverLearnerID, local ID: $localId');

            if (bankData != null) {
              await dbHelper.syncBankDetails();
            }
          } catch (localError) {
            print('Error saving locally: $localError');
            // Don't fail the whole operation if local save fails, since server succeeded
          }

          return true;
        } else {
          // Server failed, save locally with temporary ID for later sync
          try {
            final localId =
                await dbHelper.insertOrUpdateLearner(learnerOnlyData, bankData);
            print('Server failed, saved locally with temporary ID: $localId');

            if (bankData != null) {
              await dbHelper.syncBankDetails();
            }
          } catch (localError) {
            print('Error saving locally after server failure: $localError');
          }

          return false;
        }
      }
    } catch (e) {
      print('Submission error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving data: $e')),
      );
      return false;
    }
  }

  Future<bool> _sendToBackend(
      BuildContext context, Map<String, dynamic> learnerData) async {
    final url = AppConfig.buildUrl("add_learner.php");
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(learnerData),
          )
          .timeout(const Duration(seconds: 10));

      print('Request body: ${json.encode(learnerData)}');
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] ?? 'Success')),
          );
          return responseData['success'] == true;
        } catch (e) {
          print('JSON parse error: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Invalid server response: ${response.body}')),
          );
          return false;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Server error: ${response.statusCode} - ${response.body}')),
        );
        return false;
      }
    } catch (e) {
      print('Network error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
      return false;
    }
  }

  Future<Map<String, dynamic>> _sendToBackendAndGetLearnerID(
      BuildContext context, Map<String, dynamic> learnerData) async {
    final url = AppConfig.addLearnerUrl;
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(learnerData),
          )
          .timeout(const Duration(seconds: 10));

      print('Request body: ${json.encode(learnerData)}');
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(responseData['message'] ?? 'Success')),
            );

            // Return success status and server LearnerID
            return {
              'success': true,
              'learnerID':
                  responseData['LearnerID'] ?? responseData['learnerID'],
              'message': responseData['message'] ?? 'Success'
            };
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text(responseData['message'] ?? 'Failed to add learner')),
            );
            return {
              'success': false,
              'message': responseData['message'] ?? 'Failed to add learner'
            };
          }
        } catch (e) {
          print('JSON parse error: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Invalid server response: ${response.body}')),
          );
          return {'success': false, 'message': 'Invalid server response'};
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Server error: ${response.statusCode} - ${response.body}')),
        );
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('Network error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
