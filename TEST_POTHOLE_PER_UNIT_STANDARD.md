# Test Guide: Pothole Per-Unit-Standard Moderation

## Pre-Test Setup

### Requirements
- Flutter app with updated `ModeratorPage.dart`
- Backend server with `moderate_marks.php` endpoint
- Database with `logbook_marks` table containing moderation columns
- Test learner with pothole checklist data for both unit standards (13958 and 14555)

### Test Data Setup

```sql
-- Verify test learner has pothole marks
SELECT 
    learner_id,
    unit_standard_id,
    marks,
    moderator_status,
    moderator_comment
FROM logbook_marks
WHERE learner_id = 'TEST_LEARNER_ID'
AND unit_standard_id IN ('13958', '14555');
```

## Test Cases

### Test Case 1: View Pothole Checklist Section

**Steps:**
1. Login as moderator
2. Navigate to Moderator Dashboard
3. Select a class
4. Select a learner with pothole checklist
5. Scroll to "Pothole Checklist" section

**Expected Results:**
- ✅ Pothole Checklist section is visible
- ✅ "View Checklist" button is present
- ✅ Two unit standard cards are displayed (13958 and 14555)
- ✅ Each card shows:
  - Unit standard ID
  - Marks (X / 50)
  - Assessor comment (if available)
  - Moderation Decision dropdown
- ✅ Shared moderator comment field is at the bottom
- ✅ "Save Comment" button is visible

---

### Test Case 2: Uphold Unit Standard 13958

**Steps:**
1. Navigate to pothole checklist section
2. Find Unit Standard 13958 card
3. Click on "Moderation Decision" dropdown
4. Select "Uphold"

**Expected Results:**
- ✅ Dropdown closes automatically
- ✅ Green snackbar appears: "Unit Standard 13958 upheld successfully!"
- ✅ Status indicator appears below dropdown
- ✅ Status shows: "✅ Current Status: UPHELD" in green
- ✅ Page refreshes with updated data

**Database Verification:**
```sql
SELECT moderator_status, moderation_date
FROM logbook_marks
WHERE learner_id = 'TEST_LEARNER_ID'
AND unit_standard_id = '13958';
-- Should show: moderator_status = 'Upheld'
```

---

### Test Case 3: Withdraw Unit Standard 14555

**Steps:**
1. Navigate to pothole checklist section
2. Find Unit Standard 14555 card
3. Click on "Moderation Decision" dropdown
4. Select "Withdraw"

**Expected Results:**
- ✅ Dropdown closes automatically
- ✅ Red snackbar appears: "Unit Standard 14555 withdrawn successfully!"
- ✅ Status indicator appears below dropdown
- ✅ Status shows: "❌ Current Status: WITHDRAWN" in red
- ✅ Page refreshes with updated data

**Database Verification:**
```sql
SELECT moderator_status, moderation_date
FROM logbook_marks
WHERE learner_id = 'TEST_LEARNER_ID'
AND unit_standard_id = '14555';
-- Should show: moderator_status = 'Withdrawn'
```

---

### Test Case 4: Add Shared Moderator Comment

**Steps:**
1. Navigate to pothole checklist section
2. Scroll to "Moderator Comment (Shared for all Unit Standards)" section
3. Click in the text field
4. Type: "Test comment for both unit standards"
5. Click "Save Comment" button

**Expected Results:**
- ✅ Text field accepts input
- ✅ Green snackbar appears: "Moderator comment saved successfully!"
- ✅ Page refreshes with updated data
- ✅ Comment persists in the text field

**Database Verification:**
```sql
SELECT unit_standard_id, moderator_comment
FROM logbook_marks
WHERE learner_id = 'TEST_LEARNER_ID'
AND unit_standard_id IN ('13958', '14555');
-- Both records should have: moderator_comment = 'Test comment for both unit standards'
```

---

### Test Case 5: Edit Existing Comment

**Steps:**
1. Navigate to pothole checklist section (with existing comment)
2. Scroll to shared comment field
3. Modify the existing text
4. Click "Save Comment" button

**Expected Results:**
- ✅ Existing comment is pre-filled in text field
- ✅ Helper text shows: "Editing existing comment"
- ✅ Can modify the text
- ✅ Green snackbar appears after save
- ✅ Updated comment persists

**Database Verification:**
```sql
SELECT unit_standard_id, moderator_comment
FROM logbook_marks
WHERE learner_id = 'TEST_LEARNER_ID'
AND unit_standard_id IN ('13958', '14555');
-- Both records should have the updated comment
```

---

### Test Case 6: Change Moderation Decision

**Steps:**
1. Navigate to pothole checklist section (with existing moderation)
2. Find Unit Standard 13958 (currently Upheld)
3. Click dropdown and select "Withdraw"

**Expected Results:**
- ✅ Dropdown shows current status as selected
- ✅ Can change to different status
- ✅ Red snackbar appears: "Unit Standard 13958 withdrawn successfully!"
- ✅ Status indicator updates to red "WITHDRAWN"
- ✅ Page refreshes with updated data

**Database Verification:**
```sql
SELECT moderator_status, moderation_date
FROM logbook_marks
WHERE learner_id = 'TEST_LEARNER_ID'
AND unit_standard_id = '13958';
-- Should show: moderator_status = 'Withdrawn' (changed from 'Upheld')
```

---

### Test Case 7: Mixed Decisions (One Upheld, One Withdrawn)

**Steps:**
1. Navigate to pothole checklist section
2. Set Unit Standard 13958 to "Uphold"
3. Set Unit Standard 14555 to "Withdraw"
4. Add comment: "US 13958 acceptable, US 14555 needs reassessment"
5. Save comment

**Expected Results:**
- ✅ Unit Standard 13958 shows green "UPHELD" status
- ✅ Unit Standard 14555 shows red "WITHDRAWN" status
- ✅ Both have the same comment
- ✅ Each maintains its own moderation status

**Database Verification:**
```sql
SELECT 
    unit_standard_id,
    moderator_status,
    moderator_comment
FROM logbook_marks
WHERE learner_id = 'TEST_LEARNER_ID'
AND unit_standard_id IN ('13958', '14555')
ORDER BY unit_standard_id;

-- Expected:
-- 13958 | Upheld    | US 13958 acceptable, US 14555 needs reassessment
-- 14555 | Withdrawn | US 13958 acceptable, US 14555 needs reassessment
```

---

### Test Case 8: View Checklist Button

**Steps:**
1. Navigate to pothole checklist section
2. Click "View Checklist" button

**Expected Results:**
- ✅ If scanned PDF: Opens PDF viewer with the document
- ✅ If system form: Opens dialog with checklist items
- ✅ Can close viewer/dialog and return to moderation page

---

### Test Case 9: Assessor Comments Display

**Steps:**
1. Navigate to pothole checklist section
2. Check each unit standard card

**Expected Results:**
- ✅ If assessor added comments, they appear in blue box
- ✅ Blue box has comment icon
- ✅ Label says "Assessor Comment:"
- ✅ Comment text is readable
- ✅ If no assessor comment, blue box doesn't appear

---

### Test Case 10: Network Error Handling

**Steps:**
1. Turn off network/WiFi
2. Try to select moderation decision
3. Try to save comment

**Expected Results:**
- ✅ Red snackbar appears with error message
- ✅ Error message is descriptive
- ✅ App doesn't crash
- ✅ Can retry after network is restored

---

### Test Case 11: Multiple Moderators

**Steps:**
1. Moderator A: Uphold both unit standards, add comment
2. Moderator B: View the same learner's pothole checklist

**Expected Results:**
- ✅ Moderator B sees Moderator A's decisions
- ✅ Moderator B sees Moderator A's comment
- ✅ Moderator B can change decisions
- ✅ Latest moderator's ID is recorded

**Database Verification:**
```sql
SELECT 
    unit_standard_id,
    moderator_status,
    moderator_id,
    moderation_date
FROM logbook_marks
WHERE learner_id = 'TEST_LEARNER_ID'
AND unit_standard_id IN ('13958', '14555')
ORDER BY moderation_date DESC;
-- Should show latest moderator's changes
```

---

### Test Case 12: Empty Comment Save

**Steps:**
1. Navigate to pothole checklist section
2. Leave comment field empty
3. Click "Save Comment" button

**Expected Results:**
- ✅ Button is clickable
- ✅ Empty comment is saved (clears existing comment)
- ✅ Green snackbar appears
- ✅ Page refreshes

---

## Performance Tests

### Test Case 13: Large Comment Text

**Steps:**
1. Enter 500+ characters in comment field
2. Save comment

**Expected Results:**
- ✅ Text field accepts long text
- ✅ Text field scrolls if needed
- ✅ Comment saves successfully
- ✅ Full comment is stored in database

---

### Test Case 14: Rapid Clicking

**Steps:**
1. Quickly click dropdown multiple times
2. Quickly click "Save Comment" multiple times

**Expected Results:**
- ✅ Only one request is sent
- ✅ No duplicate updates
- ✅ No app crashes
- ✅ Proper feedback shown

---

## Regression Tests

### Test Case 15: Formative/Summative Still Works

**Steps:**
1. Navigate to formative or summative section
2. Test moderation functionality

**Expected Results:**
- ✅ Formative/summative moderation unchanged
- ✅ Per-exercise moderation still works
- ✅ Shared comment for formative/summative still works

---

### Test Case 16: Logbook Still Works

**Steps:**
1. Navigate to logbook section
2. Test moderation functionality

**Expected Results:**
- ✅ Logbook moderation unchanged
- ✅ Moderation decisions save correctly
- ✅ Comments save correctly

---

## Test Summary Checklist

After completing all tests, verify:

- [ ] All 16 test cases passed
- [ ] No syntax errors in code
- [ ] No runtime errors
- [ ] Database updates correctly
- [ ] UI displays correctly
- [ ] Network errors handled gracefully
- [ ] Performance is acceptable
- [ ] No regression in other features

## Bug Report Template

If issues found, use this template:

```
**Test Case:** [Number and Name]
**Steps to Reproduce:**
1. 
2. 
3. 

**Expected Result:**
[What should happen]

**Actual Result:**
[What actually happened]

**Screenshots:**
[If applicable]

**Error Messages:**
[Console logs, snackbar messages]

**Database State:**
[SQL query results]

**Device Info:**
- Device: 
- Android Version: 
- App Version: 
```

## Success Criteria

✅ All test cases pass
✅ No critical bugs found
✅ Database updates correctly
✅ UI is user-friendly
✅ Performance is acceptable
✅ Ready for production deployment
