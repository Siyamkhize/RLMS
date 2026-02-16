import 'package:flutter/material.dart';
import 'dart:convert'; // For JSON decoding
import 'package:http/http.dart' as http;
import 'learner_list_page.dart'; // Import your LearnerListPage
import 'fingerprint_induction.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io'; // For checking network status
import 'database_helper.dart'; // Import your DatabaseHelper
import 'config.dart';
import 'package:intl/intl.dart'; // For date formatting

class ClassDetailsPage extends StatefulWidget {
  final String siteID;

  const ClassDetailsPage({super.key, required this.siteID});

  @override
  _ClassDetailsPageState createState() => _ClassDetailsPageState();
}

class _ClassDetailsPageState extends State<ClassDetailsPage> {
  List<Map<String, dynamic>> classData = []; // Make sure it's a List<Map<String, dynamic>>
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchClassData();
  }

  // Function to check connectivity status
  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  // Function to fetch class information from online or offline source
  Future<void> fetchClassData() async {
    bool isOnline = await _checkConnectivity();
    if (isOnline) {
      try {
        final response = await http.post(
          Uri.parse(AppConfig.buildUrl('class.php')),
          body: {
            'siteID': widget.siteID
          }, // Send the siteID in the request body
        );

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          if (jsonResponse['success'] == true) {
            List<Map<String, dynamic>> serverClassData = List<Map<String, dynamic>>.from(jsonResponse['classDetails']);
            
            // Calculate attendance data for each class from server
            List<Map<String, dynamic>> enrichedClassData = [];
            for (var classItem in serverClassData) {
              try {
                String classID = classItem['classID'].toString();
                
                // Get total learners for this class from local database
                final db = await DatabaseHelper().database;
                final learnerCount = await db.query(
                  'learnerdetails',
                  where: 'classID = ?',
                  whereArgs: [classID],
                );
                
                // Get today's date
                final today = DateTime.now();
                final todayString = DateFormat('yyyy-MM-dd').format(today);
                
                // Get learners who clocked in today
                final clockedInLearners = await db.rawQuery('''
                  SELECT DISTINCT lc.LearnerID 
                  FROM learner_clocking lc
                  JOIN learnerdetails ld ON lc.LearnerID = ld.LearnerID
                  WHERE ld.classID = ? AND lc.clock_date = ? AND lc.clock_in_time IS NOT NULL
                ''', [classID, todayString]);
                
                // Get learners who clocked out today
                final clockedOutLearners = await db.rawQuery('''
                  SELECT DISTINCT lc.LearnerID 
                  FROM learner_clocking lc
                  JOIN learnerdetails ld ON lc.LearnerID = ld.LearnerID
                  WHERE ld.classID = ? AND lc.clock_date = ? AND lc.clock_out_time IS NOT NULL
                ''', [classID, todayString]);
                
                // Calculate attendance statistics
                int totalLearners = learnerCount.length;
                int learnersClockedIn = clockedInLearners.length;
                int learnersClockedOut = clockedOutLearners.length;
                int learnersAbsent = totalLearners - learnersClockedIn;
                
                // Create enriched class data with attendance statistics
                Map<String, dynamic> enrichedClass = Map<String, dynamic>.from(classItem);
                enrichedClass['totalLearners'] = totalLearners;
                enrichedClass['learnersClockedIn'] = learnersClockedIn;
                enrichedClass['learnersClockedOut'] = learnersClockedOut;
                enrichedClass['learnersAbsent'] = learnersAbsent;
                
                enrichedClassData.add(enrichedClass);
              } catch (e) {
                print('Error processing class ${classItem['classID']}: $e');
                // Add the original class data without attendance calculations
                enrichedClassData.add(classItem);
              }
            }
            
            setState(() {
              classData = enrichedClassData;
              isLoading = false;
            });
            _saveClassDataLocally(enrichedClassData); // Save data locally for offline use
          } else {
            // Show error message from the API response
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(jsonResponse['message'])),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load class data')),
          );
        }
      } catch (e) {
        // Show error message if an exception occurs
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } else {
      // Load data from local storage if offline
      await _loadClassDataLocally();
    }
  }

  // Function to save class data locally
  Future<void> _saveClassDataLocally(List<Map<String, dynamic>> classData) async {
    try {
      final db = await DatabaseHelper().database;
      // Add the class data to the database
      for (var item in classData) {
        // Map the server data to match the local database schema
        Map<String, dynamic> mappedData = {
          'classID': item['classID'],
          'className': item['className'],
          'numberOfLearners': item['learnerCount'] ?? 0, // Map learnerCount to numberOfLearners
          'siteID': item['siteID'],
          'phase_id': item['phase_id'] ?? 0,
          'phase_name': item['phase_name'] ?? '',
          'pathway_id': item['pathway_id'] ?? '',
          'qualification_id': item['qualification_id'] ?? '',
        };
        
        await db.insert(
          'class', // Use lowercase 'class' to match the actual table name
          mappedData,
          conflictAlgorithm: ConflictAlgorithm.replace, // Replace if exists
        );
      }
      print('Class data saved locally successfully');
    } catch (e) {
      // Only log the error to console, don't show snackbar
      print('Error saving class data locally: $e');
      // Don't rethrow the exception to prevent it from showing as a snackbar
    }
  }

  // Function to load class data from local storage based on siteID
  Future<void> _loadClassDataLocally() async {
    try {
      final db = await DatabaseHelper().database; // Use the singleton instance

      // Query all class data from the local database where siteID matches
      final List<Map<String, dynamic>> result = await db.query(
        'class', // Use lowercase 'class' to match the actual table name
        where: 'siteID = ?', // Filter data by siteID
        whereArgs: [widget.siteID], // Use the passed siteID
      );

      // Calculate attendance data for each class
      List<Map<String, dynamic>> enrichedClassData = [];
      for (var classItem in result) {
        try {
          String classID = classItem['classID'].toString();
          
          // Get total learners for this class
          final learnerCount = await db.query(
            'learnerdetails',
            where: 'classID = ?',
            whereArgs: [classID],
          );
          
          // Get today's date
          final today = DateTime.now();
          final todayString = DateFormat('yyyy-MM-dd').format(today);
          
          // Get learners who clocked in today
          final clockedInLearners = await db.rawQuery('''
            SELECT DISTINCT lc.LearnerID 
            FROM learner_clocking lc
            JOIN learnerdetails ld ON lc.LearnerID = ld.LearnerID
            WHERE ld.classID = ? AND lc.clock_date = ? AND lc.clock_in_time IS NOT NULL
          ''', [classID, todayString]);
          
          // Get learners who clocked out today
          final clockedOutLearners = await db.rawQuery('''
            SELECT DISTINCT lc.LearnerID 
            FROM learner_clocking lc
            JOIN learnerdetails ld ON lc.LearnerID = ld.LearnerID
            WHERE ld.classID = ? AND lc.clock_date = ? AND lc.clock_out_time IS NOT NULL
          ''', [classID, todayString]);
          
          // Calculate attendance statistics
          int totalLearners = learnerCount.length;
          int learnersClockedIn = clockedInLearners.length;
          int learnersClockedOut = clockedOutLearners.length;
          int learnersAbsent = totalLearners - learnersClockedIn;
          
          // Create enriched class data with attendance statistics
          Map<String, dynamic> enrichedClass = Map<String, dynamic>.from(classItem);
          enrichedClass['totalLearners'] = totalLearners;
          enrichedClass['learnersClockedIn'] = learnersClockedIn;
          enrichedClass['learnersClockedOut'] = learnersClockedOut;
          enrichedClass['learnersAbsent'] = learnersAbsent;
          
          enrichedClassData.add(enrichedClass);
        } catch (e) {
          print('Error processing class ${classItem['classID']}: $e');
          // Add the original class data without attendance calculations
          enrichedClassData.add(classItem);
        }
      }

      setState(() {
        classData = enrichedClassData;
        isLoading = false;
      });
    } catch (e) {
      // Only log the error to console, don't show snackbar
      print('Error loading class data locally: $e');
      setState(() {
        classData = [];
        isLoading = false;
      });
    }
  }

  // Function to navigate to LearnerListPage with classID
  void navigateToLearnerList(String classID) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LearnerListPage(classID: classID), // Pass classID to LearnerListPage
      ),
    );
  }

  // Function to navigate to InductionPage with classID
  void navigateToInductionClocking(String classID) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            InductionPage(classID: classID), // Pass classID to InductionPage
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Information'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator()) // Show loading spinner while fetching data
          : classData.isEmpty
          ? const Center(child: Text('No class data available'))
          : SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Class Name')),
            DataColumn(label: Text('Learner Count')),
            DataColumn(label: Text('Learners Clocked In')),
            DataColumn(label: Text('Learners Clocked Out')),
            DataColumn(label: Text('Learners Absent')),
            DataColumn(label: Text('Action')), // Column for View Learners button
            DataColumn(label: Text('Induction')), // Column for Induction Clocking button
          ],
          rows: classData.map<DataRow>((item) {
            return DataRow(cells: [
              DataCell(Text(item['className'] ?? 'N/A')), // Show 'N/A' if no className
              DataCell(Text(item['totalLearners']?.toString() ?? 'N/A')), // Use calculated total learners
              DataCell(Text(item['learnersClockedIn']?.toString() ?? 'N/A')), // Use calculated learners clocked in
              DataCell(Text(item['learnersClockedOut']?.toString() ?? 'N/A')), // Use calculated learners clocked out
              DataCell(Text(item['learnersAbsent']?.toString() ?? 'N/A')), // Use calculated learners absent
              DataCell(
                ElevatedButton(
                  onPressed: () =>
                      navigateToLearnerList(item['classID'].toString()),
                  child: const Text('View Learners'),
                ),
              ),
              DataCell(
                ElevatedButton(
                  onPressed: () =>
                      navigateToInductionClocking(item['classID'].toString()),
                  child: const Text('Induction Clocking'),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}