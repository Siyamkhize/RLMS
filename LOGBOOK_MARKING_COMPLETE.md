# LogBook Marking Feature - Complete Implementation

## Overview
Added LogBook unit standards marking functionality to the Pothole Checklist marking page in AssessorPage.dart.

## Implementation Details

### 1. PHP Endpoint: `get_logbook_unit_standards.php`
**Purpose**: Fetch unit standards that have LogBook items (Practical assessments)

**Logic** (matches `get_poe.php`):
- Uses CASE statement: `CASE WHEN a.question_type = 'Practical' THEN 'LogBook' ELSE a.assessment_type END`
- Filters for `question_type = 'Practical'`
- Returns only unit standards that have LogBook items
- Same data source as POE tab (learnerdetails → class → sites → project → assessments)

**Returns**:
```json
{
  "status": "success",
  "data": [
    {
      "unit_standard_id": "US123",
      "unit_standard_name": "Unit Standard Name",
      "unit_standard_number": "US123"
    }
  ]
}
```

### 2. PHP Endpoint: `get_logbook_marks.php`
**Purpose**: Retrieve existing LogBook marks for a learner

**Parameters**:
- `learner_id` (required)
- `assessor_id` (optional)
- `assessment_date` (optional)

**Returns**:
```json
{
  "status": "success",
  "data": {
    "US123": 85,
    "US456": 92
  }
}
```

### 3. PHP Endpoint: `save_logbook_marks.php`
**Purpose**: Save LogBook marks for unit standards

**Request Body**:
```json
{
  "learner_id": "123",
  "assessor_id": "456",
  "assessment_date": "2024-01-15",
  "marks": {
    "US123": 85,
    "US456": 92
  }
}
```

**Validation**:
- Marks must be between 0 and 100
- Uses INSERT ... ON DUPLICATE KEY UPDATE for upsert functionality

### 4. Flutter Implementation (AssessorPage.dart)

#### State Variables Added to `_PotholeChecklistViewPageState`:
```dart
List<Map<String, dynamic>> _logbookUnitStandards = [];
Map<String, TextEditingController> _logbookMarksControllers = {};
bool _isLoadingLogbook = false;
```

#### Methods Added:

**`_loadLogbookUnitStandards()`**
- Called in `initState()`
- Fetches unit standards with LogBook items
- Creates text controllers for each unit standard
- Calls `_loadLogbookMarks()` after loading

**`_loadLogbookMarks()`**
- Fetches existing marks from database
- Populates text controllers with saved marks

**`_saveLogbookMarks()`**
- Validates all marks (0-100 range)
- Sends marks to server
- Shows success/error messages

#### UI Section Added:
- Orange card section titled "LogBook Unit Standards"
- Shows after the Pothole Checklist marking section
- Displays each unit standard with:
  - Unit standard name
  - Mark input field (0-100)
- Save button to submit all LogBook marks

## Database Table

Table: `logbook_marks`
```sql
CREATE TABLE IF NOT EXISTS logbook_marks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    unit_standard_id VARCHAR(50) NOT NULL,
    assessor_id VARCHAR(50) NOT NULL,
    marks INT NOT NULL,
    assessment_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_logbook_mark (learner_id, unit_standard_id, assessor_id, assessment_date)
);
```

## How It Works

1. **Assessor opens Pothole Checklist for marking**
   - System loads pothole checklist data
   - Simultaneously loads LogBook unit standards via `get_logbook_unit_standards.php`

2. **LogBook section displays**
   - Shows only unit standards that have Practical assessments
   - Each unit standard has a mark input field
   - Existing marks are pre-populated if available

3. **Assessor enters marks**
   - Marks must be between 0-100
   - Validation happens before submission

4. **Marks are saved**
   - Sent to `save_logbook_marks.php`
   - Stored in `logbook_marks` table
   - Success message displayed

## Key Features

- **Consistent with POE Tab**: Uses same data source and logic as `get_poe.php`
- **Separate Marking**: LogBook marks are independent from Pothole Checklist marks
- **Validation**: Ensures marks are within valid range
- **Persistence**: Marks are saved and can be retrieved later
- **User-Friendly**: Clear UI with orange color scheme to distinguish from other sections

## Testing

To test the implementation:

1. Open Pothole Checklist marking page for a learner
2. Verify LogBook section appears (if learner has Practical assessments)
3. Enter marks for each unit standard
4. Click "Save LogBook Marks"
5. Verify success message
6. Reload page and verify marks are retained

## Files Modified

1. `lib/AssessorPage.dart` - Added LogBook UI and logic to `_PotholeChecklistViewPageState`
2. `get_logbook_unit_standards.php` - Created endpoint to fetch LogBook unit standards
3. `get_logbook_marks.php` - Created endpoint to retrieve marks
4. `save_logbook_marks.php` - Created endpoint to save marks
5. `create_logbook_marks_table.sql` - Database table creation script

## Notes

- LogBook items are assessments where `question_type = 'Practical'`
- In `get_poe.php`, these are transformed to `assessment_type = 'LogBook'`
- The marking page shows unit standards, not individual exercises
- Each unit standard gets one overall mark (0-100)
