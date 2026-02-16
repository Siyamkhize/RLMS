# Assessor Comment Update Feature - IMPLEMENTED

## Overview
Assessors can now update their comments after they've been submitted, just like they can update marks. This provides flexibility for assessors to refine their feedback.

## Problem Solved
Previously, once a comment was submitted:
- The comment field was disabled
- The submit button was disabled
- No way to edit or update the comment
- Assessors had to contact administrators to change comments

## Solution Implemented

### 1. Created `save_comment.php` Endpoint
A new PHP endpoint that handles both saving and updating comments.

**Features:**
- Accepts `learnerId`, `assessmentType`, `comment`, and `isUpdate` parameters
- Checks for existing comments before saving
- Supports updating existing comments with `isUpdate: true`
- Returns appropriate error messages with `can_update` flag
- Updates all marks records of the same type for the learner
- Proper error handling and logging

**Database Structure:**
- Comments are stored in the `marks` table
- Column: `a_comment` (text field)
- One comment per assessment type per learner
- Comment applies to all marks of that type

### 2. Updated `lib/AssessorPage.dart`
Modified the POETab widget to support comment editing and updating.

**Changes Made:**

#### Comment Fields (3 sections updated):
- **Formative assessments** - Line ~2244
- **Summative assessments** - Line ~2284
- **Logbook assessments** - Line ~2356

**Before:**
```dart
enabled: existingComment.isEmpty,  // Field disabled if comment exists
```

**After:**
```dart
// Field always enabled
helperText: existingComment.isNotEmpty ? 'Editing existing comment' : null,
```

#### Submit Buttons:
**Before:**
```dart
onPressed: existingComment.isEmpty
    ? () => saveComment('formative', commentController.text)
    : null,  // Button disabled if comment exists
child: const Text('Submit Comment'),
```

**After:**
```dart
onPressed: () => saveComment('formative', commentController.text, existingComment.isNotEmpty),
child: Text(existingComment.isEmpty ? 'Submit Comment' : 'Update Comment'),
```

#### saveComment Function:
**Enhanced with:**
- `isUpdate` parameter to track if updating existing comment
- AppConfig URL usage instead of hardcoded URL
- Dialog showing existing vs new comment when duplicate detected
- "Update Comment" button in dialog to confirm update
- Better error handling and user feedback
- Automatic POE data refresh after successful update
- SnackBar notifications for success/error

### 3. User Experience Flow

#### First Time Submitting Comment:
1. Assessor enters comment in text field
2. Clicks "Submit Comment" button
3. Comment is saved to database
4. Success message shown
5. Button changes to "Update Comment"
6. Helper text shows "Editing existing comment"

#### Updating Existing Comment:
1. Assessor edits the comment text
2. Clicks "Update Comment" button
3. If comment hasn't changed much, direct update
4. If significant change, dialog shows:
   - Existing comment
   - New comment
   - "Cancel" button
   - "Update Comment" button
5. Assessor confirms update
6. Comment is updated in database
7. Success message shown
8. POE data refreshes to show new comment

## Files Created/Modified

### Created:
- `save_comment.php` - Comment save/update endpoint
- `test_save_comment.php` - Test script for endpoint
- `ASSESSOR_COMMENT_UPDATE_FEATURE.md` - This documentation

### Modified:
- `lib/AssessorPage.dart` - Updated POETab widget:
  - 3 comment field sections (formative, summative, logbook)
  - 3 submit button sections
  - 1 saveComment function

## Database Schema

### marks Table:
```sql
CREATE TABLE marks (
    id INT PRIMARY KEY AUTO_INCREMENT,
    learnerID VARCHAR(50),
    exercise VARCHAR(255),
    so TEXT,
    marks_scored INT,
    type VARCHAR(50),  -- 'Formative', 'Summative', 'Logbook'
    a_comment TEXT,    -- Assessor comment (NEW USAGE)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Comment Storage:**
- One comment per assessment type per learner
- Comment is stored in `a_comment` column
- When comment is saved/updated, it updates all marks records of that type
- Example: Formative comment applies to all formative assessments for that learner

## API Endpoint

### save_comment.php

**URL:** `https://rlms.rlms.co.za/mobile/save_comment.php`

**Method:** POST

**Request Body:**
```json
{
  "learnerId": "12345",
  "assessmentType": "formative",
  "comment": "Good progress shown in this assessment.",
  "isUpdate": false
}
```

**Response (Success - New):**
```json
{
  "status": "success",
  "message": "Comment saved successfully",
  "action": "insert",
  "affected_rows": 3
}
```

**Response (Success - Update):**
```json
{
  "status": "success",
  "message": "Comment updated successfully",
  "action": "update",
  "record_id": 123
}
```

**Response (Error - Duplicate):**
```json
{
  "status": "error",
  "message": "Comment already exists for this formative assessment",
  "existing_comment": "Previous comment text",
  "record_id": 123,
  "can_update": true,
  "suggestion": "Use isUpdate: true to update existing comment"
}
```

**Response (Error - No Marks):**
```json
{
  "status": "error",
  "message": "No marks records found for this assessment type. Please submit marks first.",
  "can_update": false
}
```

## Testing

### Test Script
Run the comprehensive test:
```bash
php test_save_comment.php
```

This will:
1. Test saving a new comment
2. Test updating an existing comment
3. Verify comment in database

### Manual Testing in App
1. **Test New Comment:**
   - Log in as Assessor
   - View a learner's POE
   - Enter a comment for formative/summative/logbook
   - Click "Submit Comment"
   - Verify success message
   - Verify button changes to "Update Comment"

2. **Test Update Comment:**
   - Edit the existing comment text
   - Click "Update Comment"
   - Verify dialog shows (if applicable)
   - Confirm update
   - Verify success message
   - Verify comment is updated in UI

3. **Test All Assessment Types:**
   - Test formative comments
   - Test summative comments
   - Test logbook comments

## Deployment Checklist

### Server-Side:
- [ ] Upload `save_comment.php` to `/mobile/` directory
- [ ] Verify file permissions (644 or 755)
- [ ] Test endpoint with curl or Postman
- [ ] Run `test_save_comment.php` script
- [ ] Check server error logs

### App-Side:
- [ ] Rebuild Flutter app: `flutter build apk --release`
- [ ] Install on test device
- [ ] Test comment submission
- [ ] Test comment update
- [ ] Test all three assessment types
- [ ] Verify UI changes (button text, helper text)

## Troubleshooting

### Issue: "No marks records found"
**Cause:** Comments require existing marks records
**Solution:** Submit marks first, then add comments

### Issue: Comment not updating
**Check:**
1. Is `isUpdate: true` being sent?
2. Check server error logs
3. Verify database connection
4. Check marks table has records for that learner/type

**Debug SQL:**
```sql
-- Check marks with comments
SELECT * FROM marks 
WHERE learnerID = 'YOUR_LEARNER_ID' 
AND type = 'Formative' 
AND a_comment IS NOT NULL;

-- Check all marks for learner
SELECT id, learnerID, exercise, type, marks_scored, a_comment 
FROM marks 
WHERE learnerID = 'YOUR_LEARNER_ID';
```

### Issue: Dialog not showing
**Check:**
1. Is `can_update` flag true in response?
2. Is `isUpdate` false on first attempt?
3. Check console logs for errors

## Benefits

### For Assessors:
- ✓ Can correct typos or errors in comments
- ✓ Can add more detail after initial submission
- ✓ Can refine feedback based on learner progress
- ✓ No need to contact administrators for changes

### For System:
- ✓ Consistent with marks update functionality
- ✓ Better user experience
- ✓ Reduced support requests
- ✓ Maintains audit trail (can be enhanced with history)

## Future Enhancements

Potential improvements:
1. **Comment History:** Track all versions of comments with timestamps
2. **Comment Templates:** Pre-defined comment templates for common feedback
3. **Character Counter:** Show remaining characters for comments
4. **Rich Text:** Support formatting (bold, italic, lists)
5. **Attachments:** Allow attaching files to comments

## Notes

- Comments are assessment-type specific (formative, summative, logbook)
- One comment per assessment type per learner
- Comments are stored in the marks table, not a separate table
- The same comment applies to all marks of that type for the learner
- Update functionality matches the marks update pattern
- All URLs now use AppConfig for consistency

## Related Documentation

- `ASSESSOR_NO_CLASSES_FIX.md` - Classes display fix
- `ASSESSOR_LEARNERS_FIX_COMPLETE.md` - Learners display fix
- `EDIT_MARKS_FEATURE.md` - Marks editing feature (similar pattern)
