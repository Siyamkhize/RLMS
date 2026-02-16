# Edit Marks Feature - Complete Implementation

## Overview
Added the ability to edit/update marks that have already been saved, allowing assessors to correct mistakes or update scores as needed.

## Features Implemented

### 1. Backend Changes (save_marks.php)

#### Enhanced Functionality
- **Dual Operation Support**: Single endpoint handles both INSERT (new) and UPDATE (edit) operations
- **Update Detection**: Uses `isUpdate` flag to determine operation type
- **Comprehensive Error Handling**: Better error messages with context and suggestions
- **Audit Trail**: Tracks old vs new marks in responses

#### Key Backend Logic
```php
// Check if this is an update operation
$isUpdate = isset($data['isUpdate']) && $data['isUpdate'] === true;

if ($result->num_rows > 0) {
    if ($isUpdate) {
        // Update existing marks
        $updateQuery = $conn->prepare("UPDATE marks SET marks_scored = ?, updated_at = NOW() WHERE id = ?");
        // ... update logic
    } else {
        // Return error with option to update
        echo json_encode([
            'status' => 'error',
            'can_update' => true,
            'suggestion' => 'Use isUpdate: true to update existing marks'
        ]);
    }
}
```

### 2. Frontend Changes (lib/AssessorPage.dart)

#### UI Enhancements
- **Edit Button**: Added orange "Edit" button next to existing marks
- **Dynamic Submit Button**: Changes from "Submit" (green) to "Update" (orange) based on context
- **Cancel Functionality**: Added cancel button to revert changes
- **Smart Dialog**: Shows update confirmation dialog for accidental duplicates

#### ExerciseTile Updates
```dart
// Edit button for existing marks
ElevatedButton.icon(
  onPressed: () {
    setState(() {
      showInputField = true;
    });
  },
  icon: const Icon(Icons.edit, size: 16),
  label: const Text('Edit'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orange,
    foregroundColor: Colors.white,
  ),
)

// Dynamic submit button
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: marksScored.isNotEmpty ? Colors.orange : Colors.green,
  ),
  child: Text(marksScored.isNotEmpty ? 'Update' : 'Submit'),
)
```

#### Enhanced submitMarks Function
- **Context Detection**: Automatically detects if marks exist
- **Update Flag**: Sends `isUpdate: true` for existing marks
- **Smart Error Handling**: Shows update dialog for accidental duplicates
- **Better Feedback**: Different success messages for save vs update

## User Experience Flow

### Scenario 1: First Time Marking
1. User sees exercise with no marks
2. Clicks green/red buttons or enters marks directly
3. Clicks "Submit" (green button)
4. System saves new marks
5. Shows "Marks saved successfully!"

### Scenario 2: Editing Existing Marks
1. User sees exercise with existing marks and "Edit" button
2. Clicks "Edit" button
3. Input field appears with current marks
4. User modifies marks
5. Clicks "Update" (orange button)
6. System updates existing marks
7. Shows "Marks updated successfully!"

### Scenario 3: Accidental Duplicate
1. User tries to submit marks that already exist
2. System detects duplicate
3. Shows dialog: "Marks Already Exist"
4. User can choose "Cancel" or "Update Marks"
5. If "Update Marks" → system updates the record

## API Endpoints

### save_marks.php (Enhanced)
**Purpose**: Handle both save and update operations

**Request Format**:
```json
{
  "learnerId": 12345,
  "exercise": {
    "exercise": "Safety Assessment",
    "type": "formative"
  },
  "marksScored": 85,
  "assessmentType": "POE",
  "specific_outcome": ["719", "720"],
  "isUpdate": true
}
```

**Response Format**:
```json
{
  "status": "success",
  "message": "Marks updated successfully",
  "action": "update",
  "record_id": 123,
  "old_marks": "75",
  "new_marks": "85",
  "actual_type": "Formative"
}
```

### update_marks.php (Standalone)
**Purpose**: Dedicated endpoint for updates only (alternative option)

**Features**:
- Update-only operations
- Detailed validation
- Comprehensive error messages
- Audit trail logging

## Database Considerations

### Table Structure
The `marks` table should have these columns:
```sql
- id (primary key)
- learnerID
- exercise
- so (specific outcomes)
- marks_scored
- type
- created_at (timestamp)
- updated_at (timestamp) -- for tracking edits
```

### Update Query
```sql
UPDATE marks 
SET marks_scored = ?, updated_at = NOW() 
WHERE learnerID = ? AND exercise = ? AND type = ? AND so = ?
```

## Security & Validation

### Input Validation
- ✅ Numeric marks validation
- ✅ Maximum marks enforcement
- ✅ Required field validation
- ✅ Assessment type validation

### Business Rules
- ✅ Prevent unauthorized updates
- ✅ Maintain audit trail
- ✅ Preserve assessment context (formative/summative)
- ✅ Validate mark ranges

### Error Handling
- ✅ Clear error messages
- ✅ Contextual suggestions
- ✅ Graceful fallbacks
- ✅ Comprehensive logging

## Testing Scenarios

### Test Case 1: New Mark Entry
```
Input: New exercise, no existing marks
Expected: INSERT operation, success message
```

### Test Case 2: Edit Existing Mark
```
Input: Existing exercise with isUpdate: true
Expected: UPDATE operation, success message with old/new values
```

### Test Case 3: Accidental Duplicate
```
Input: Existing exercise with isUpdate: false
Expected: Error with can_update: true, dialog option
```

### Test Case 4: Invalid Update
```
Input: Non-existent record with isUpdate: true
Expected: Error message suggesting to use save instead
```

## Benefits

### For Assessors
- ✅ **Mistake Correction**: Can fix marking errors easily
- ✅ **Flexible Workflow**: Edit marks without starting over
- ✅ **Clear Feedback**: Know whether saving new or updating existing
- ✅ **Safety Net**: Confirmation dialogs prevent accidental overwrites

### For System
- ✅ **Data Integrity**: Maintains proper audit trails
- ✅ **Conflict Resolution**: Smart handling of duplicate scenarios
- ✅ **Backward Compatibility**: Existing functionality unchanged
- ✅ **Performance**: Single endpoint for both operations

### For Administrators
- ✅ **Audit Trail**: Track all mark changes with timestamps
- ✅ **Error Reduction**: Less data entry errors
- ✅ **User Satisfaction**: Assessors can correct mistakes
- ✅ **System Reliability**: Robust error handling

## Deployment Checklist

1. **Backend**:
   - [ ] Deploy updated `save_marks.php`
   - [ ] Test with sample data
   - [ ] Verify database updates work
   - [ ] Check error logging

2. **Frontend**:
   - [ ] Update Flutter app with new UI
   - [ ] Test edit button functionality
   - [ ] Verify update dialogs work
   - [ ] Test cancel functionality

3. **Database**:
   - [ ] Ensure `updated_at` column exists
   - [ ] Test UPDATE queries
   - [ ] Verify audit trail works
   - [ ] Check performance impact

4. **Testing**:
   - [ ] Test all user scenarios
   - [ ] Verify error handling
   - [ ] Check duplicate detection
   - [ ] Validate mark ranges

The edit marks feature provides a complete solution for mark management, allowing assessors to confidently make corrections while maintaining data integrity and providing clear user feedback.