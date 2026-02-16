# Moderator Uphold/Withdraw Flutter Fix

## Problem
When clicking "Uphold" or "Withdraw" in the moderator interface, the system was showing an error: "no records found to update for markId:" because the parameters sent from Flutter didn't match what the PHP endpoint expected. Additionally, the moderator comment was not being saved.

## Root Cause
1. The Flutter app was sending incorrect parameters to `save_moderation_status.php`:
   - Sending `markId` (which was always empty)
   - Sending `exercise` instead of `exerciseId`
   - The PHP endpoint was expecting different parameter names
2. The Flutter was sending `moderatorComment` (camelCase) but PHP expected `moderator_comment` (snake_case)

## Solution Applied

### PHP Endpoint Expectations (save_moderation_status.php)
The working PHP code expects these parameters:
```php
$learnerId = $data['learnerId'];
$exerciseId = $data['exerciseId'];  // This is the exercise question text
$moderationStatus = $data['moderation_status'];  // 'Uphold' or 'Withdrawn'
$moderatorComment = $data['moderator_comment'];  // Moderator's comment
$moderatorId = $data['moderator_id'];  // Moderator ID
```

The PHP logic:
- Uses `learnerID` + `exercise` (question text) to identify the record in the marks table
- If status is "Uphold": Updates `marks.approval_status = 'Approved'`, `moderator_status = 'uphold'`, `moderator_comment`, `moderator_id`, and `moderation_date`
- If status is "Withdrawn": Deletes records from both `marks` and `poe` tables, and deletes the associated file

### Flutter Changes (lib/ModeratorPage.dart)

**BEFORE:**
```dart
requestBody = {
  'markId': exercise['id']?.toString() ?? '',  // Always empty!
  'learnerId': widget.learnerId,
  'exercise': exerciseName,  // Wrong parameter name
  'moderation_status': action,
  'moderatorComment': comment,  // Wrong case
  'moderatorId': widget.moderatorId,  // Wrong case
};
```

**AFTER:**
```dart
requestBody = {
  'learnerId': widget.learnerId,
  'exerciseId': exerciseName,  // Correct parameter name - contains the exercise question text
  'moderation_status': action,  // 'Uphold' or 'Withdrawn'
  'moderator_comment': comment,  // Correct snake_case
  'moderator_id': widget.moderatorId,  // Correct snake_case
};
```

## Key Points

1. **No markId needed**: The PHP identifies records using `learnerID` + `exercise` (question text), not a numeric ID
2. **exerciseId contains question text**: Despite the name "exerciseId", it actually contains the exercise question text (e.g., "Define a safe site")
3. **Individual record updates**: Each mark record is individually upheld or withdrawn based on the learner ID and exercise question text
4. **Removed unused markId**: The `markId` parameter was never populated and is not needed by the PHP
5. **Parameter naming**: PHP expects snake_case (`moderator_comment`, `moderator_id`) not camelCase

## Database Updates
The PHP now updates these fields in the marks table:
- `approval_status` - 'Approved' for Uphold, 'Disapproved' for Withdrawn
- `moderator_status` - 'uphold' or 'withdrawn'
- `moderator_comment` - The moderator's comment text
- `moderator_id` - The ID of the moderator
- `moderation_date` - Timestamp of when moderation was performed

## Testing
Test by:
1. Navigate to Moderator Dashboard
2. Select a class and learner
3. Expand a unit standard with formative or summative assessments
4. Enter a comment in the moderator comment field
5. Click "Uphold" or "Withdraw" on an individual exercise
6. Verify the success message appears
7. Check that the moderation status AND comment are saved correctly in the database

## Files Modified
- `lib/ModeratorPage.dart` - Updated `_submitExerciseModeration` function (lines ~1610-1635)
- `save_moderation_status.php` - Already updated to accept and save moderator comments

## Database Impact
- **Uphold**: Updates `marks.approval_status = 'Approved'`, `moderator_status = 'uphold'`, `moderator_comment`, `moderator_id`, `moderation_date` WHERE `learnerID = ? AND exercise = ?`
- **Withdrawn**: Deletes from `marks` and `poe` tables, and deletes the associated file
