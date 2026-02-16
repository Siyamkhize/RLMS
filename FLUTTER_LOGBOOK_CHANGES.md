  # Flutter Changes for LogBook Unit Standards

## Files Created:
✅ `create_logbook_marks_table.sql`
✅ `get_logbook_unit_standards.php`
✅ `save_logbook_marks.php`
✅ `get_logbook_marks.php`

## Flutter Changes Needed in `lib/AssessorPage.dart`

### In `_PotholeChecklistViewPageState` class:

Add these new state variables after the existing ones (around line 5930):

```dart
// Add these new variables
List<Map<String, dynamic>> _logbookUnitStandards = [];
Map<String, TextEditingController> _logbookMarksControllers = {};
bool _isLoadingLogbook = false;
```

Update `initState` method (around line 5940):

```dart
@override
void initState() {
  super.initState();
  _loadExistingMarks();
  _loadLogbookUnitStandards(); // ADD THIS LINE
}
```

Add these new methods after `_loadExistingMarks()` method:

```dart
Future<void> _loadLogbookUnitStandards() async {
  setState(() => _isLoadingLogbook = true);
  
  try {
    final response = await http.get(Uri.parse(
      '${AppConfig.baseUrl}/get_logbook_unit_standards.php?learner_id=${widget.learnerId}'
    ));
    
    print('DEBUG LogBook: Response status ${response.statusCode}');
    print('DEBUG LogBook: Response body ${response.body}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          _logbookUnitStandards = List<Map<String, dynamic>>.from(data['data']);
          
          // Create controllers for each unit standard
          for (var us in _logbookUnitStandards) {
            _logbookMarksControllers[us['unit_standard_id']] = TextEditingController();
          }
        });
        
        print('DEBUG LogBook: Loaded ${_logbookUnitStandards.length} unit standards');
        
        // Load existing marks
        await _loadLogbookMarks();
      }
    }
  } catch (e) {
    print('Error loading logbook unit standards: $e');
  } finally {
    setState(() => _isLoadingLogbook = false);
  }
}

Future<void> _loadLogbookMarks() async {
  try {
    final assessmentDate = widget.checklistData['assessment_date'] ?? DateTime.now().toIso8601String().split('T').first;
    final assessorId = widget.checklistData['assessor_id'] ?? '';
    
    final response = await http.get(Uri.parse(
      '${AppConfig.baseUrl}/get_logbook_marks.php?learner_id=${widget.learnerId}&assessor_id=$assessorId&assessment_date=$assessmentDate'
    ));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        final marks = data['data'] as Map<String, dynamic>;
        
        setState(() {
          marks.forEach((unitStandardId, mark) {
            if (_logbookMarksControllers.containsKey(unitStandardId)) {
              _logbookMarksControllers[unitStandardId]!.text = mark.toString();
            }
          });
        });
        
        print('DEBUG LogBook: Loaded marks for ${marks.length} unit standards');
      }
    }
  } catch (e) {
    print('Error loading logbook marks: $e');
  }
}

Future<void> _saveLogbookMarks() async {
  // Validate and collect all marks
  List<Map<String, dynamic>> unitStandardsMarks = [];
  
  for (var us in _logbookUnitStandards) {
    final controller = _logbookMarksControllers[us['unit_standard_id']];
    if (controller != null && controller.text.isNotEmpty) {
      final marks = int.tryParse(controller.text);
      if (marks == null || marks < 0 || marks > 50) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marks for ${us['unit_standard_name']} must be between 0 and 50'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      unitStandardsMarks.add({
        'unit_standard_id': us['unit_standard_id'],
        'marks': marks
      });
    }
  }
  
  if (unitStandardsMarks.isEmpty) {
    return; // No marks to save
  }
  
  try {
    final assessmentDate = widget.checklistData['assessment_date'] ?? DateTime.now().toIso8601String().split('T').first;
    final assessorId = widget.checklistData['assessor_id'] ?? '';
    
    print('DEBUG LogBook: Saving marks for ${unitStandardsMarks.length} unit standards');
    
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/save_logbook_marks.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'learner_id': widget.learnerId,
        'assessor_id': assessorId,
        'assessment_date': assessmentDate,
        'unit_standards_marks': unitStandardsMarks
      }),
    );
    
    print('DEBUG LogBook: Save response ${response.statusCode}');
    print('DEBUG LogBook: Save body ${response.body}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('LogBook marks saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(data['message']);
      }
    }
  } catch (e) {
    print('Error saving logbook marks: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error saving logbook marks: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Widget _buildLogbookSection() {
  if (_logbookUnitStandards.isEmpty) {
    return const SizedBox.shrink();
  }
  
  return Card(
    elevation: 4,
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.book, color: Colors.orange.shade700, size: 24),
              const SizedBox(width: 8),
              const Text(
                'LogBook - Unit Standards (Practical)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Mark each unit standard out of 50',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          ..._logbookUnitStandards.map((us) => _buildUnitStandardCard(us)).toList(),
        ],
      ),
    ),
  );
}

Widget _buildUnitStandardCard(Map<String, dynamic> unitStandard) {
  final controller = _logbookMarksControllers[unitStandard['unit_standard_id']];
  final specificOutcomes = List<String>.from(unitStandard['specific_outcomes'] ?? []);
  
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.orange.shade200, width: 2),
      borderRadius: BorderRadius.circular(8),
      color: Colors.orange.shade50,
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unit Standard Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  unitStandard['unit_standard_number'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  unitStandard['unit_standard_name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Specific Outcomes
          if (specificOutcomes.isNotEmpty) ...[
            const Text(
              'Specific Outcomes:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            ...specificOutcomes.map((outcome) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      outcome,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )).toList(),
            const SizedBox(height: 12),
          ],
          
          // Marks Input
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Marks (0-50)',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(Icons.grade, color: Colors.orange.shade700),
                    hintText: 'Enter marks',
                    suffixText: '/ 50',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

Update the `_saveMarks()` method to also save logbook marks (around line 5980):

```dart
Future<void> _saveMarks() async {
  // ... existing validation code ...
  
  setState(() => _isSaving = true);

  try {
    // ... existing save checklist marks code ...
    
    // ALSO SAVE LOGBOOK MARKS - ADD THIS
    await _saveLogbookMarks();
    
    // ... rest of existing code ...
  } catch (e) {
    // ... existing error handling ...
  } finally {
    setState(() => _isSaving = false);
  }
}
```

Update `dispose()` method to dispose logbook controllers:

```dart
@override
void dispose() {
  _marksController.dispose();
  _commentsController.dispose();
  // ADD THESE LINES
  for (var controller in _logbookMarksControllers.values) {
    controller.dispose();
  }
  super.dispose();
}
```

In the `build()` method, add the LogBook section after the checklist items card (around line 6090):

```dart
// ... existing checklist items code ...

const SizedBox(height: 16),

// ADD THIS - LogBook Section
_buildLogbookSection(),

const SizedBox(height: 16),

// Marking Section (existing code)
Card(
  elevation: 4,
  color: Colors.green.shade50,
  // ... rest of marking section ...
```

## Summary of Changes:

1. ✅ Added 3 new state variables
2. ✅ Updated `initState()` to load logbook data
3. ✅ Added 3 new methods for loading/saving logbook data
4. ✅ Added 2 new widget builders for UI
5. ✅ Updated `_saveMarks()` to save logbook marks
6. ✅ Updated `dispose()` to clean up controllers
7. ✅ Added LogBook section to UI

## Testing:

1. Upload PHP files to server
2. Run SQL to create table
3. Update Flutter code
4. Test with a learner who has Practical+Summative assessments
5. Should see LogBook section with unit standards
6. Enter marks and save

The implementation is complete!
