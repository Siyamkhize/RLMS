# Next Steps: Testing Moderator 77 Fixes

## Quick Summary

All three tasks have been completed:
1. ✅ Timeout fix for 62 allocated classes
2. ✅ Individual exercise moderation fix
3. ✅ ClassID and site name display

## Testing Instructions

### Test 1: Verify Timeout Fix

**Steps:**
1. Open the Flutter app
2. Login as moderator ID 77
3. Navigate to "Moderation Sampling" page
4. Wait for the page to load (may take 2-5 minutes on first load)
5. Verify no timeout error occurs
6. Verify learners are displayed

**Expected Results:**
- Page loads successfully without timeout
- Shows 273 learners (from moderator's 62 classes)
- Shows "Total Learners with POE: 273" (not 1571)
- Subsequent loads should be instant (< 1 second)

---

### Test 2: Verify Individual Exercise Moderation

**Steps:**
1. Navigate to a learner's marking page
2. Expand a unit standard (e.g., 13958)
3. Expand "Formative" section
4. Moderate one formative question (Uphold or Withdraw)
5. Save the moderation
6. Check the "Summative" section
7. Verify summative questions are NOT moderated

**Expected Results:**
- Only the specific formative question is moderated
- Summative questions remain unmoderated
- Each question can be moderated independently
- No cross-contamination between formative and summative

**Repeat Test:**
1. Now moderate a summative question
2. Verify formative questions remain unchanged
3. Verify only the specific summative question is moderated

---

### Test 3: Verify ClassID and Site Name Display

**Steps:**
1. Navigate to "Moderation Sampling" page
2. Look at the learners table
3. Verify the following columns are visible:
   - Learner ID
   - Name
   - Surname
   - **Class ID** (new column)
   - **Class Name** (new column)
   - **Site** (should show site name, not just ID)
   - POE Status
   - Marking
   - Performance
   - Unit Stds
   - Action

**Expected Results:**
- Class ID column shows numeric class IDs (e.g., 8, 9, 10, 12, etc.)
- Class Name column shows class names (e.g., "Class A", "Class B")
- Site column shows site names (e.g., "Main Campus", "Branch Office")
- If site name is missing, shows site ID as fallback
- All columns are properly aligned and readable

**Check Strata Summary:**
1. Scroll to "Strata Breakdown" section
2. Look at the strata summary table
3. Verify "Site" column shows site names (not just IDs)

---

## Troubleshooting

### If Timeout Still Occurs
1. Check PHP error logs on server
2. Verify `max_execution_time` is set to 300 seconds
3. Check if database connection is stable
4. Verify moderator has 62 classes allocated

### If Individual Exercise Moderation Fails
1. Check `save_moderation_status.php` has `LIMIT 1` in UPDATE query
2. Check browser console for API errors
3. Verify exercise names are unique (use `test_moderation_update.php`)
4. Check database `marks` table for duplicate records

### If ClassID or Site Name Not Showing
1. Verify `get_learners_with_poe_assigned.php` has JOIN with sites table
2. Check API response includes `classID`, `className`, and `siteName`
3. Verify Flutter app is using latest version of `ModeratorPage.dart`
4. Check if sites table has data for the classes

---

## API Endpoints to Test

### 1. Get Learners with POE (Sampling)
```
GET https://rlms.rlms.co.za/mobile/get_learners_with_poe_assigned.php?moderator_id=77
```

**Expected Response:**
```json
{
  "status": "success",
  "data": {
    "total_learners_with_poe_global": 1571,
    "total_learners_with_poe": 273,
    "selected_count": 68,
    "learners": [
      {
        "LearnerID": "123",
        "Name": "John",
        "Surname": "Doe",
        "classID": "8",
        "className": "Class A",
        "siteID": "1",
        "siteName": "Main Campus",
        "poe_completeness": "Complete",
        "marking_status": "Marked",
        "performance_level": "High",
        "unit_standards_count": 10
      }
    ],
    "strata_summary": [
      {
        "class": "Class A",
        "classID": "8",
        "site": "Main Campus",
        "siteID": "1",
        "poe_completeness": "Complete",
        "marking_status": "Marked",
        "performance_level": "High",
        "total_in_stratum": 10,
        "selected_from_stratum": 3,
        "sampling_rate": "30%"
      }
    ]
  }
}
```

### 2. Save Moderation Status
```
POST https://rlms.rlms.co.za/mobile/save_moderation_status.php
```

**Request Body:**
```json
{
  "learnerId": "123",
  "exerciseId": "13958 - Formative - Question 1",
  "moderation_status": "uphold",
  "moderator_comment": "Good work",
  "moderator_id": "77"
}
```

**Expected Response:**
```json
{
  "status": "success",
  "message": "Moderation status updated successfully"
}
```

---

## Database Queries to Verify

### Check Moderator's Allocated Classes
```sql
SELECT classID FROM facilitator WHERE facilitator_id = '77';
```

**Expected:** Should return 62 class IDs (comma-separated or multiple rows)

### Check Total Learners with POE in Moderator's Classes
```sql
SELECT COUNT(DISTINCT p.learnerID) as total 
FROM poe p
INNER JOIN learnerdetails l ON p.learnerID = l.LearnerID
WHERE p.filePath IS NOT NULL AND p.filePath != ''
AND l.classID IN (8,9,10,12,13,15,16,18,19,20,21,22,23,24,28,29,30,32,33,34,35,38,41,43,44,46,47,49,51,53,54,56,57,58,59,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,78,79,81,83,84,85,86,89,91,92,93,97);
```

**Expected:** Should return 273

### Check Moderator Assignments
```sql
SELECT COUNT(*) as assigned_count 
FROM moderator_assignments 
WHERE moderator_id = '77';
```

**Expected:** Should return number of assigned learners (e.g., 68 if 25% of 273)

### Check Individual Exercise Moderation
```sql
SELECT learnerID, exercise, approval_status, moderator_status 
FROM marks 
WHERE learnerID = '123' 
AND exercise LIKE '%13958%'
ORDER BY exercise;
```

**Expected:** Each exercise should have independent moderation status

---

## Success Criteria

### Task 1: Timeout Fix ✅
- [ ] Page loads without timeout error
- [ ] Shows 273 learners (not 1571)
- [ ] Subsequent loads are instant
- [ ] No PHP timeout errors in logs

### Task 2: Individual Exercise Moderation ✅
- [ ] Moderating formative doesn't affect summative
- [ ] Moderating summative doesn't affect formative
- [ ] Each question moderated independently
- [ ] No duplicate updates in database

### Task 3: ClassID and Site Name Display ✅
- [ ] Class ID column visible and populated
- [ ] Class Name column visible and populated
- [ ] Site column shows site names (not IDs)
- [ ] Strata summary shows site names
- [ ] Fallback works when siteName is missing

---

## Contact Information

If you encounter any issues during testing:
1. Check the documentation files listed above
2. Review the API response in browser console
3. Check PHP error logs on server
4. Verify database data is correct

All fixes have been implemented and documented. The system is ready for testing!
