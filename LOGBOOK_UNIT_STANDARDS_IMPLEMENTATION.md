# LogBook Unit Standards in Checklist Marking

## Overview
Add LogBook unit standards with specific outcomes to the pothole checklist marking interface. Each unit standard will have a marks field (out of 50) and display its specific outcomes.

## Requirements
1. Query unit standards where `question_type = 'Practical'` AND `assessment_type = 'Summative'`
2. Display these unit standards at the end of the checklist form
3. Each unit standard has a marks input field (0-50)
4. Show specific outcomes for each unit standard
5. Save marks for each unit standard

## Database Structure

### Query to Get LogBook Unit Standards
```sql
SELECT DISTINCT 
    a.unit_standard_id,
    us.unit_standard_name,
    us.unit_standard_number
FROM assessments a
INNER JOIN unit_standards us ON a.unit_standard_id = us.id
WHERE a.learner_id = ?
  AND a.question_type = 'Practical'
  AND a.assessment_type = 'Summative'
ORDER BY us.unit_standard_number;
```

### Query to Get Specific Outcomes for Each Unit Standard
```sql
SELECT DISTINCT specific_outcome
FROM assessments
WHERE learner_id = ?
  AND unit_standard_id = ?
  AND question_type = 'Practical'
  AND assessment_type = 'Summative'
  AND specific_outcome IS NOT NULL
  AND specific_outcome != ''
ORDER BY specific_outcome;
```

## Implementation Steps

### Step 1: Create PHP Endpoint

**File:** `get_logbook_unit_standards.php`

```php
<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'config.php';

$learner_id = $_GET['learner_id'] ?? '';

if (empty($learner_id)) {
    echo json_encode(['status' => 'error', 'message' => 'Missing learner_id']);
    exit();
}

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    $conn->set_charset("utf8mb4");
    
    // Get unit standards with LogBook (Practical + Summative)
    $sql = "SELECT DISTINCT 
                a.unit_standard_id,
                us.unit_standard_name,
                us.unit_standard_number
            FROM assessments a
            INNER JOIN unit_standards us ON a.unit_standard_id = us.id
            WHERE a.learner_id = ?
              AND a.question_type = 'Practical'
              AND a.assessment_type = 'Summative'
            ORDER BY us.unit_standard_number";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $learner_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $unit_standards = [];
    while ($row = $result->fetch_assoc()) {
        $unit_standard_id = $row['unit_standard_id'];
        
        // Get specific outcomes for this unit standard
        $outcomes_sql = "SELECT DISTINCT specific_outcome
                        FROM assessments
                        WHERE learner_id = ?
                          AND unit_standard_id = ?
                          AND question_type = 'Practical'
                          AND assessment_type = 'Summative'
                          AND specific_outcome IS NOT NULL
                          AND specific_outcome != ''
                        ORDER BY specific_outcome";
        
        $outcomes_stmt = $conn->prepare($outcomes_sql);
        $outcomes_stmt->bind_param("ss", $learner_id, $unit_standard_id);
        $outcomes_stmt->execute();
        $outcomes_result = $outcomes_stmt->get_result();
        
        $specific_outcomes = [];
        while ($outcome = $outcomes_result->fetch_assoc()) {
            $specific_outcomes[] = $outcome['specific_outcome'];
        }
        $outcomes_stmt->close();
        
        $unit_standards[] = [
            'unit_standard_id' => $unit_standard_id,
            'unit_standard_name' => $row['unit_standard_name'],
            'unit_standard_number' => $row['unit_standard_number'],
            'specific_outcomes' => $specific_outcomes,
            'max_marks' => 50
        ];
    }
    
    $stmt->close();
    $conn->close();
    
    echo json_encode([
        'status' => 'success',
        'data' => $unit_standards
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
```

### Step 2: Create Database Table for LogBook Marks

**File:** `create_logbook_marks_table.sql`

```sql
CREATE TABLE IF NOT EXISTS logbook_marks (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    unit_standard_id VARCHAR(50) NOT NULL,
    assessor_id VARCHAR(50) NOT NULL,
    marks INT(11) NOT NULL,
    assessment_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_marking (learner_id, unit_standard_id, assessor_id, assessment_date),
    INDEX idx_learner (learner_id),
    INDEX idx_unit_standard (unit_standard_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### Step 3: Create Save/Get Marks Endpoints

**File:** `save_logbook_marks.php`

```php
<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit();
}

require_once 'config.php';

$input = json_decode(file_get_contents('php://input'), true);

$learner_id = $input['learner_id'] ?? '';
$assessor_id = $input['assessor_id'] ?? '';
$assessment_date = $input['assessment_date'] ?? '';
$unit_standards_marks = $input['unit_standards_marks'] ?? []; // Array of {unit_standard_id, marks}

if (empty($learner_id) || empty($assessor_id) || empty($assessment_date) || empty($unit_standards_marks)) {
    echo json_encode(['status' => 'error', 'message' => 'Missing required fields']);
    exit();
}

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    $conn->set_charset("utf8mb4");
    $conn->begin_transaction();
    
    $sql = "INSERT INTO logbook_marks 
            (learner_id, unit_standard_id, assessor_id, marks, assessment_date)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE marks = VALUES(marks), updated_at = NOW()";
    
    $stmt = $conn->prepare($sql);
    
    foreach ($unit_standards_marks as $item) {
        $unit_standard_id = $item['unit_standard_id'];
        $marks = $item['marks'];
        
        if ($marks < 0 || $marks > 50) {
            throw new Exception("Marks must be between 0 and 50 for unit standard $unit_standard_id");
        }
        
        $stmt->bind_param("sssis", $learner_id, $unit_standard_id, $assessor_id, $marks, $assessment_date);
        $stmt->execute();
    }
    
    $stmt->close();
    $conn->commit();
    $conn->close();
    
    echo json_encode(['status' => 'success', 'message' => 'LogBook marks saved successfully']);
    
} catch (Exception $e) {
    if (isset($conn)) {
        $conn->rollback();
        $conn->close();
    }
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
?>
```

**File:** `get_logbook_marks.php`

```php
<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'config.php';

$learner_id = $_GET['learner_id'] ?? '';
$assessor_id = $_GET['assessor_id'] ?? '';
$assessment_date = $_GET['assessment_date'] ?? '';

if (empty($learner_id)) {
    echo json_encode(['status' => 'error', 'message' => 'Missing learner_id']);
    exit();
}

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    $conn->set_charset("utf8mb4");
    
    $sql = "SELECT unit_standard_id, marks 
            FROM logbook_marks 
            WHERE learner_id = ?";
    
    $params = [$learner_id];
    $types = "s";
    
    if (!empty($assessor_id)) {
        $sql .= " AND assessor_id = ?";
        $params[] = $assessor_id;
        $types .= "s";
    }
    
    if (!empty($assessment_date)) {
        $sql .= " AND assessment_date = ?";
        $params[] = $assessment_date;
        $types .= "s";
    }
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $marks = [];
    while ($row = $result->fetch_assoc()) {
        $marks[$row['unit_standard_id']] = $row['marks'];
    }
    
    $stmt->close();
    $conn->close();
    
    echo json_encode(['status' => 'success', 'data' => $marks]);
    
} catch (Exception $e) {
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
?>
```

### Step 4: Update Flutter Checklist View Pages

Add this section after the checklist items but before the main marking section:

```dart
// In PotholeChecklistViewPage state class

List<Map<String, dynamic>> _logbookUnitStandards = [];
Map<String, TextEditingController> _logbookMarksControllers = {};
bool _isLoadingLogbook = false;

@override
void initState() {
  super.initState();
  _loadExistingMarks();
  _loadLogbookUnitStandards(); // Add this
}

Future<void> _loadLogbookUnitStandards() async {
  setState(() => _isLoadingLogbook = true);
  
  try {
    final response = await http.get(Uri.parse(
      '${AppConfig.baseUrl}/get_logbook_unit_standards.php?learner_id=${widget.learnerId}'
    ));
    
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
      }
    }
  } catch (e) {
    print('Error loading logbook marks: $e');
  }
}

Future<void> _saveLogbookMarks() async {
  // Validate all marks
  List<Map<String, dynamic>> unitStandardsMarks = [];
  
  for (var us in _logbookUnitStandards) {
    final controller = _logbookMarksControllers[us['unit_standard_id']];
    if (controller != null && controller.text.isNotEmpty) {
      final marks = int.tryParse(controller.text);
      if (marks == null || marks < 0 || marks > 50) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marks for ${us['unit_standard_name']} must be between 0 and 50')),
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
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('LogBook marks saved successfully!'), backgroundColor: Colors.green),
        );
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error saving logbook marks: $e'), backgroundColor: Colors.red),
    );
  }
}

// Add this widget in the build method, after checklist items but before main marking section

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
          const Text(
            'LogBook - Unit Standards (Practical)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
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
      border: Border.all(color: Colors.orange.shade200),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unit Standard Header
          Text(
            '${unitStandard['unit_standard_number']} - ${unitStandard['unit_standard_name']}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          
          // Specific Outcomes
          if (specificOutcomes.isNotEmpty) ...[
            const Text(
              'Specific Outcomes:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ...specificOutcomes.map((outcome) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(child: Text(outcome, style: const TextStyle(fontSize: 14))),
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
                    prefixIcon: const Icon(Icons.grade),
                    hintText: 'Enter marks',
                    suffixText: '/ 50',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// Update the _saveMarks method to also save logbook marks
Future<void> _saveMarks() async {
  // ... existing checklist marks saving code ...
  
  // Also save logbook marks
  await _saveLogbookMarks();
  
  // ... rest of the code ...
}

// In the build method, add the logbook section:
// After the checklist items card, before the main marking section:

_buildLogbookSection(),

const SizedBox(height: 16),

// Marking Section (existing code)
```

## Deployment Steps

1. **Create database table:**
   ```bash
   mysql -u username -p database < create_logbook_marks_table.sql
   ```

2. **Upload PHP files to server:**
   - `get_logbook_unit_standards.php`
   - `save_logbook_marks.php`
   - `get_logbook_marks.php`

3. **Update Flutter code** in `lib/AssessorPage.dart`

4. **Test the feature:**
   - Open a checklist for a learner with LogBook unit standards
   - Should see the LogBook section with unit standards
   - Each unit standard shows specific outcomes
   - Enter marks (0-50) for each
   - Save marks

## UI Layout

```
┌─────────────────────────────────────┐
│ Learner Information                 │
│ (existing)                          │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Assessment Criteria                 │
│ (existing checklist items)          │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ LogBook - Unit Standards (Practical)│
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ US123456 - Unit Standard Name   │ │
│ │                                 │ │
│ │ Specific Outcomes:              │ │
│ │ • Outcome 1                     │ │
│ │ • Outcome 2                     │ │
│ │                                 │ │
│ │ Marks: [____] / 50              │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ US789012 - Another Unit Std     │ │
│ │ ...                             │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Marking                             │
│ (existing overall marks)            │
│ [Save Marks Button]                 │
└─────────────────────────────────────┘
```

## Benefits

✅ Assessors can mark LogBook unit standards directly in checklist
✅ Specific outcomes are visible for reference
✅ Each unit standard marked separately (out of 50)
✅ Marks saved to dedicated table
✅ Can retrieve and edit marks later
✅ Clean, organized UI

## Status
📋 **IMPLEMENTATION PLAN READY**

Follow the steps above to implement this feature. The code is complete and ready to use!
