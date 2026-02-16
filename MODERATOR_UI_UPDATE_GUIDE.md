# Moderator Page UI Update Guide

## Overview
This guide explains how to update the ModeratorPage to match the AssessorPage UI as shown in the uploaded image.

## Changes Required

### 1. Update the ModeratorMarkingPage Class

The current `ModeratorPage.dart` has a complex implementation. We need to simplify the `ModeratorMarkingPage` (or `AssessorMarkingPage` if that's what it's called in the file) to match the clean UI from AssessorPage.

### Key UI Elements from the Image:

1. **AppBar**: "Assessment Marking" title
2. **Two Tabs**: 
   - "Learner Information"
   - "POE Details"
3. **POE Details Tab Content**:
   - Section header: "Short Skills Programme"
   - Expandable card: "LogBook" with book icon (blue background)
   - Expandable card: "Pothole Checklist" with construction icon (orange background)

### Implementation Steps:

#### Step 1: Replace the ModeratorMarkingPage class

Replace the existing `ModeratorMarkingPage` or `AssessorMarkingPage` class in `lib/ModeratorPage.dart` with:

```dart
// Moderator Marking Page - Matches Assessor UI
class ModeratorMarkingPage extends StatelessWidget {
  final String learnerId;
  final String? learnerFirstName;
  final String? learnerLastName;
  final String? learnerIdNumber;

  const ModeratorMarkingPage({
    Key? key,
    required this.learnerId,
    this.learnerFirstName,
    this.learnerLastName,
    this.learnerIdNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Assessment Marking'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.black,
            tabs: [
              Tab(text: 'Learner Information'),
              Tab(text: 'POE Details'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            LearnerInformationTab(learnerId: learnerId),
            ModeratorPOETab(learnerId: learnerId),
          ],
        ),
      ),
    );
  }
}
```

#### Step 2: Add the LearnerInformationTab class

```dart
// Learner Information Tab
class LearnerInformationTab extends StatelessWidget {
  final String learnerId;

  const LearnerInformationTab({Key? key, required this.learnerId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Learner Information for ID: $learnerId',
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}
```

#### Step 3: Add the ModeratorPOETab class

```dart
// POE Details Tab with Expandable Sections
class ModeratorPOETab extends StatefulWidget {
  final String learnerId;

  const ModeratorPOETab({Key? key, required this.learnerId}) : super(key: key);

  @override
  _ModeratorPOETabState createState() => _ModeratorPOETabState();
}

class _ModeratorPOETabState extends State<ModeratorPOETab> {
  late Future<Map<String, dynamic>> _poeData;

  @override
  void initState() {
    super.initState();
    _poeData = fetchPOE(widget.learnerId);
  }

  Future<Map<String, dynamic>> fetchPOE(String learnerId) async {
    try {
      final url = AppConfig.buildUrl('get_poe.php', queryParams: {
        'learnerId': learnerId,
      });
      
      print('[ModeratorPOETab] Fetching POE from: $url');
      final response = await http.get(Uri.parse(url));

      print('[ModeratorPOETab] POE Response Status: ${response.statusCode}');
      print('[ModeratorPOETab] POE Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load POE data. Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('[ModeratorPOETab] Error fetching POE: $e');
      throw Exception('Failed to load POE data. Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _poeData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No POE data found.'));
        }

        Map<String, dynamic> poeData = snapshot.data!;
        Map<String, dynamic> pathways = poeData['pathways'] ?? {};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Programme Section Header
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Short Skills Programme',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            
            // Build pathway/qualification/unit standard structure
            ...pathways.entries.map((entry) {
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text(entry.key,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: _buildQualificationTiles(entry.value),
                ),
              );
            }).toList(),
            
            // LogBook Section
            _buildLogBookSection(poeData),
            
            // Pothole Checklist Section
            _buildPotholeChecklistSection(),
          ],
        );
      },
    );
  }

  List<Widget> _buildQualificationTiles(Map<String, dynamic> pathwayData) {
    Map<String, dynamic> qualifications = pathwayData['qualifications'] ?? {};

    return qualifications.entries.map((qualEntry) {
      return ExpansionTile(
        title: Text(qualEntry.key),
        children: _buildUnitStandardTiles(qualEntry.value),
      );
    }).toList();
  }

  List<Widget> _buildUnitStandardTiles(Map<String, dynamic> qualificationData) {
    Map<String, dynamic> unitStandards = qualificationData['unit_standards'] ?? {};

    return unitStandards.entries.map((usEntry) {
      return ListTile(
        leading: const Icon(Icons.book, color: Colors.blue),
        title: Text(usEntry.key),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening ${usEntry.key}')),
          );
        },
      );
    }).toList();
  }

  Widget _buildLogBookSection(Map<String, dynamic> poeData) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.menu_book, color: Colors.blue),
        ),
        title: const Text(
          'LogBook',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          ListTile(
            title: const Text('View LogBook Entries'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening LogBook')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPotholeChecklistSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.construction, color: Colors.orange),
        ),
        title: const Text(
          'Pothole Checklist',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          ListTile(
            title: const Text('View Pothole Checklist'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening Pothole Checklist')),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

### Step 4: Update ClassDetailsPage Navigation

In the `ClassDetailsPage` class, update the navigation to pass the learner details:

```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModeratorMarkingPage(
          learnerId: learnerId,
          learnerFirstName: firstName,
          learnerLastName: lastName,
          learnerIdNumber: idNumber,
        ),
      ),
    );
  },
  child: const Text('View Marks'),
),
```

## Visual Result

After implementing these changes, the Moderator page will have:

1. Clean tabbed interface matching the Assessor page
2. "Learner Information" tab (placeholder for now)
3. "POE Details" tab with:
   - "Short Skills Programme" header
   - Expandable "LogBook" card with blue icon
   - Expandable "Pothole Checklist" card with orange icon
   - Any qualification/unit standard data from the API

## Testing

1. Build the app: `flutter build apk`
2. Navigate to Moderator Dashboard
3. Select a class
4. Select a learner
5. Verify the "Assessment Marking" page matches the Assessor UI

## Files Modified

- `lib/ModeratorPage.dart` - Main changes to UI structure

## Backup

A complete updated version has been created in `lib/ModeratorPage_updated.dart` for reference.
