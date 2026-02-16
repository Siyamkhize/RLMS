# Moderator Status Persistence Fix

## Issue
After moderating formative/summative questions (selecting Uphold or Withdraw), the moderation status was not persisting and displaying when navigating back to view the assessments. The status should display like it does in the pothole checklist with a green box showing "Status: UPHELD" or red box showing "Status: WITHDRAWN".

## Root Cause
The `get_poe.php` file was selecting `moderator_status` from the `assessments` table (`a.moderator_status`) instead of from the `marks` table (`m.moderator_status`). The `save_moderation_status.php` saves the moderation status to the `marks` table, but `get_poe.php` was not retrieving it from there.

## Solution
Updated `get_poe.php` to use `COALESCE(m.moderator_status, a.moderator_status)` which prioritizes the marks table value over the assessments table value. This ensures that the moderation status saved by `save_moderation_status.php` is correctly retrieved and displayed.

## Changes Made

### File: `get_poe.php`

#### 1. Updated SELECT Query to Include Marks Table Moderation Fields

**Before:**
```php
SELECT 
    ...
    a.moderator_status,
    a.moderator_comment,
    a.moderator_id,
    a.moderation_date,
    ...
    m.id as mark_id,
    m.approval_status,
    m.sotype
FROM poe p
LEFT JOIN assessments a ON ...
LEFT JOIN marks m ON ...
```

**After:**
```php
SELECT 
    ...
    COALESCE(m.moderator_status, a.moderator_status) as moderator_status,
    COALESCE(m.moderator_comment, a.moderator_comment) as moderator_comment,
    COALESCE(m.moderator_id, a.moderator_id) as moderator_id,
    COALESCE(m.moderation_date, a.moderation_date) as moderation_date,
    ...
    m.id as mark_id,
    m.approval_status,
    m.sotype,
    m.total_marks
FROM poe p
LEFT JOIN assessments a ON ...
LEFT JOIN marks m ON ...
```

**Benefits:**
- Prioritizes marks table values (where save_moderation_status.php saves data)
- Falls back to assessments table if marks table has no value
- Ensures consistency between save and retrieve operations
- Added `total_marks` for complete display information

#### 2. Added fileUrl Field to Assessment Array

**Before:**
```php
$assessment = [
    ...
    'filePath' => $row['filePath'],
    'marks_scored' => $row['marks_scored'],
    ...
];
```

**After:**
```php
$assessment = [
    ...
    'filePath' => $row['filePath'],
    'fileUrl' => $row['filePath'],  // Add fileUrl for consistency
    'marks_scored' => $row['marks_scored'],
    'total_marks' => $row['total_marks'] ?? '',
    ...
];
```

**Benefits:**
- Ensures Flutter code can access file URL consistently
- Adds total_marks for proper marks display

## How It Works Now

### Data Flow:
1. **Moderator selects Uphold/Withdraw** → `save_moderation_status.php` saves to `marks` table
2. **Flutter updates local state** → Immediate UI update (green/red box appears)
3. **User navigates away and back** → `get_poe.php` retrieves from `marks` table
4. **Status displays correctly** → Green box for "UPHELD", red box for "WITHDRAWN"

### Display Pattern (Matching Pothole Checklist):
```
Unit Standard: [Name]
Marks: [scored] / [total]

Moderation Decision
┌─────────────────────────────────┐
│ ✓ Status: UPHELD                │  (Green background)
└─────────────────────────────────┘

OR

┌─────────────────────────────────┐
│ ✗ Status: WITHDRAWN              │  (Red background)
└─────────────────────────────────┘
```

### Database Tables:
- **marks table**: Stores moderation status for formative/summative (per question)
  - `moderator_status`: 'upheld' or 'withdrawn'
  - `approval_status`: 'Approved' or 'Disapproved'
  - `moderator_comment`: Moderator's comment
  - `moderator_id`: Who moderated
  - `moderation_date`: When moderated

- **assessments table**: Legacy table (fallback)
  - Same fields as marks table
  - Used as fallback if marks table has no data

## Testing Instructions

1. **Test Status Persistence**:
   - Open a learner's formative assessment
   - Select "Uphold" on a question
   - Verify: Green box appears with "Status: UPHELD"
   - Navigate back to learner list
   - Navigate back to the same learner
   - Verify: Green box still shows "Status: UPHELD"

2. **Test Withdraw Status**:
   - Select "Withdraw" on a question
   - Verify: Red box appears with "Status: WITHDRAWN"
   - Navigate away and back
   - Verify: Red box still shows "Status: WITHDRAWN"

3. **Test Multiple Questions**:
   - Moderate several questions with different statuses
   - Navigate away and back
   - Verify: All statuses persist correctly
   - Verify: Each question shows its own status

4. **Test Visual Consistency**:
   - Compare formative/summative display with pothole checklist
   - Verify: Same green box style for "UPHELD"
   - Verify: Same red box style for "WITHDRAWN"
   - Verify: Same layout and positioning

## Files Modified
- `get_poe.php` - Updated query to retrieve moderation status from marks table

## Status
✅ **COMPLETE** - Moderation status now persists and displays correctly like pothole checklist
