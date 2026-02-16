# Moderator Uphold/Withdraw Fix - COMPLETE

## Problem
When clicking "Uphold" or "Withdraw" buttons for individual mark records in the moderator interface, the system was showing error: "no records found to update for markId:" because the `markId` parameter was empty.

## Root Cause
The Flutter app was trying to send a `markId` parameter that didn't exist, and the parameter names didn't match what the PHP backend expected.

## Solution Applied

### PHP Backend (`save_moderation_status.php`)
The working PHP code expects these parameters:
- `learnerId` (required) - The learner's ID
- `exerciseId` (required) - The exercise question text (e.g., "Define a safe site", "What are safety hazards?")
- `moderation_status` (required) - Either "Uphold" or "Withdrawn"

The PHP updates records using: `WHERE learnerID = ? AND exercise = ?`

**Actions:**
- For "Uphold": Sets `approval_status = 'Approved'` in marks table
- For "Withdrawn": DELETES the record from marks and poe tables, and deletes the associated file

### Flutter Frontend (`lib/ModeratorPage.dart`)

**Updated `_submitExerciseModeration` function (lines 1597-1680):**

The request body now correctly sends:
```dart
requestBody = {
  'learnerId': widget.learnerId,
  'exerciseId': exerciseName,  // The actual exercise question text
  'moderation_status': action,  // 'Uphold' or 'Withdrawn'
};
```

**Fixed dropdown values (line 1573):**
Changed from:
```dart
DropdownMenuItem(value: 'Upheld', child: Text('Uphold'))
```
To:
```dart
DropdownMenuItem(value: 'Uphold', child: Text('Uphold'))
```

This ensures the value sent to PHP is 'Uphold' (present tense) not 'Upheld' (past tense).

## Key Changes Made

1. **Removed `markId` parameter** - Not needed by PHP
2. **Changed parameter name** from `exercise` to `exerciseId` to match PHP expectations
3. **Fixed dropdown value** from 'Upheld' to 'Uphold' to match PHP logic
4. **Kept 'Withdrawn'** as it was already correct

## How It Works Now

1. Moderator clicks "Uphold" or "Withdraw" dropdown for an individual exercise
2. Flutter extracts the exercise question text (e.g., "Define a safe site")
3. Flutter sends to `save_moderation_status.php`:
   - `learnerId`: "1277"
   - `exerciseId`: "Define a safe site"
   - `moderation_status`: "Uphold" or "Withdrawn"
4. PHP finds the record using `WHERE learnerID = '1277' AND exercise = 'Define a safe site'`
5. PHP either updates approval_status or deletes the record

## Testing

Test with learner 1277 who has 16 mark records with exercises like:
- "Define a safe site"
- "What are safety hazards?"
- etc.

Each exercise can now be individually upheld or withdrawn.

## Files Modified

1. `lib/ModeratorPage.dart` - Updated `_submitExerciseModeration` function and dropdown values
2. `save_moderation_status.php` - Already had correct implementation from server

## Status
✅ COMPLETE - Ready for testing
