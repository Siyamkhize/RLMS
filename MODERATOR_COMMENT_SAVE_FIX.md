# Moderator Comment Save Fix

## Problem
The moderator comment was not being saved when clicking "Uphold" or "Withdraw" for formative/summative assessments. The approval status was saving correctly, but the comment field remained empty.

## Root Cause
1. The `marks` table didn't have columns for storing moderation data (moderator_comment, moderator_status, moderator_id, moderation_date)
2. The PHP endpoint `save_moderation_status.php` was only updating the `approval_status` field
3. The Flutter app was not sending the moderator comment to the PHP endpoint

## Solution Applied

### 1. Database Schema Update
Created `add_moderation_columns_to_marks.sql` to add moderation columns to the marks table:
- `moderator_status` VARCHAR(20) - stores 'upheld' or 'withdrawn'
- `moderator_comment` TEXT - stores the moderator's comment
- `moderator_id` VARCHAR(50) - stores the moderator's ID
- `moderation_date` DATETIME - stores when moderation was performed

**Action Required:** Run this SQL file on your database:
```bash
mysql -u your_user -p your_database < add_moderation_columns_to_marks.sql
```

### 2. PHP Backend Update (save_moderation_status.php)

**BEFORE:**
```php
$learnerId = $data['learnerId'];
$exerciseId = $data['exerciseId'];
$moderationStatus = $data['moderation_status'];

$sqlUpdate = "UPDATE marks SET approval_status = ? WHERE learnerID = ? AND exercise = ?";
$stmtUpdate->bind_param("sss", $approvalStatus, $learnerId, $exerciseId);
```

**AFTER:**
```php
$learnerId = $data['learnerId'];
$exerciseId = $data['exerciseId'];
$moderationStatus = $data['moderation_status'];
$moderatorComment = isset($data['moderatorComment']) ? $data['moderatorComment'] : '';
$moderatorId = isset($data['moderatorId']) ? $data['moderatorId'] : '';

$sqlUpdate = "UPDATE marks SET approval_status = ?, moderator_status = ?, moderator_comment = ?, moderator_id = ?, moderation_date = NOW() WHERE learnerID = ? AND exercise = ?";
$moderatorStatusValue = strtolower($moderationStatus); // 'uphold' or 'withdrawn'
$stmtUpdate->bind_param("ssssss", $approvalStatus, $moderatorStatusValue, $moderatorComment, $moderatorId, $learnerId, $exerciseId);
```

### 3. Flutter Frontend Update (lib/ModeratorPage.dart)

**BEFORE:**
```dart
requestBody = {
  'learnerId': widget.learnerId,
  'exerciseId': exerciseName,
  'moderation_status': action,
};
```

**AFTER:**
```dart
requestBody = {
  'learnerId': widget.learnerId,
  'exerciseId': exerciseName,
  'moderation_status': action,
  'moderatorComment': comment,  // Now sending the comment
  'moderatorId': widget.moderatorId,  // Now sending the moderator ID
};
```

## How It Works Now

1. **Moderator enters comment**: The moderator types their comment in the TextFormField
2. **Moderator selects decision**: When they select "Uphold" or "Withdraw" from the dropdown
3. **Flutter sends data**: The app sends learnerId, exerciseId (question text), moderation_status, moderatorComment, and moderatorId
4. **PHP saves data**: The PHP updates the marks table with:
   - `approval_status` = 'Approved' (for Uphold) or 'Disapproved' (for Withdrawn)
   - `moderator_status` = 'uphold' or 'withdrawn'
   - `moderator_comment` = the moderator's comment text
   - `moderator_id` = the moderator's ID
   - `moderation_date` = current timestamp

## Database Fields Explained

- **approval_status**: Used by the system for workflow ('Approved' or 'Disapproved')
- **moderator_status**: Human-readable status ('upheld' or 'withdrawn')
- **moderator_comment**: The moderator's detailed comment
- **moderator_id**: Who performed the moderation
- **moderation_date**: When the moderation was performed

## Testing

1. Navigate to Moderator Dashboard
2. Select a class and learner
3. Expand a unit standard with formative or summative assessments
4. Enter a comment in the "Moderator Comment" field
5. Select "Uphold" or "Withdraw" from the dropdown
6. Verify success message appears
7. Check database: `SELECT * FROM marks WHERE learnerID = 'xxx' AND exercise = 'yyy'`
8. Verify all moderation fields are populated

## Files Modified

1. `add_moderation_columns_to_marks.sql` - NEW: Database schema update
2. `save_moderation_status.php` - UPDATED: Now saves moderator comment and related fields
3. `lib/ModeratorPage.dart` - UPDATED: Now sends moderator comment to PHP

## Important Notes

- The system uses TWO different tables:
  - `marks` table: For formative/summative individual exercises (used by save_moderation_status.php)
  - `assessments` table: For unit standard level moderation (used by save_moderation.php)
- This fix addresses the `marks` table (individual exercise moderation)
- The comment is captured at the unit standard level but applied to individual exercises
- Each exercise under a unit standard gets the same comment when moderated together
