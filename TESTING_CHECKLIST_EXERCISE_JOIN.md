# Testing Checklist: Exercise Column Join Fix

## Pre-Upload Verification ✅

- [x] get_learners_with_poe_assigned.php updated with exercise join
- [x] test_temp_tables_logic.php updated with exercise join
- [x] Both MySQL 8.0+ and MySQL 5.7/MariaDB sections updated
- [x] Documentation updated
- [x] Upload script created

## Upload Steps

- [ ] Run `UPLOAD_EXERCISE_JOIN_FIX.bat`
- [ ] Verify files uploaded successfully
- [ ] Check file permissions on server (should be readable)

## Testing Phase 1: Diagnostic Script

### URL
```
http://102.130.118.179/test_temp_tables_logic.php?moderator_id=77
```

### Checklist

#### Step 1: Moderator's Classes
- [ ] Shows Class ID: 74 (Class A)
- [ ] No errors displayed

#### Step 2: POE Learners (temp_poe_learners)
- [ ] Shows count > 0 (e.g., 10-50 learners)
- [ ] No errors displayed

#### Step 3: Learner Marks (temp_learner_marks) ⭐ CRITICAL
**Before fix:**
- [ ] ❌ 0 rows (empty table)

**After fix (expected):**
- [ ] ✅ Multiple rows displayed
- [ ] ✅ Unit Standard Count > 0 (e.g., 3-10)
- [ ] ✅ Avg Marks > 0 (e.g., 45-90)
- [ ] ✅ Performance Level shows: High/Medium/Low
- [ ] ✅ No NULL values in avg_marks column

**Example expected output:**
```
Learner ID | Unit Standard Count | Avg Marks | Performance Level
1234       | 5                   | 75.50     | High
1235       | 3                   | 62.00     | Medium
1236       | 4                   | 45.00     | Low
```

#### Step 4: Learner Coverage (temp_learner_coverage)
- [ ] Shows Total Unit Standards: 1-10
- [ ] POE Completeness: Complete/Partial/Incomplete
- [ ] No errors displayed

#### Step 5: Final Query Result
**Before fix:**
- [ ] ❌ Marking: Not Marked
- [ ] ❌ Performance: Not Assessed
- [ ] ❌ US Count: NULL
- [ ] ❌ Avg Marks: NULL

**After fix (expected):**
- [ ] ✅ POE Count: 1-10
- [ ] ✅ Completeness: Complete/Partial
- [ ] ✅ Marking: Marked
- [ ] ✅ Performance: High/Medium/Low
- [ ] ✅ US Count: > 0
- [ ] ✅ Avg Marks: > 0

## Testing Phase 2: API Endpoint

### URL
```
http://102.130.118.179/get_learners_with_poe_assigned.php?moderator_id=77
```

### Checklist

#### Response Status
- [ ] HTTP Status: 200 OK
- [ ] Content-Type: application/json
- [ ] No PHP errors displayed

#### JSON Structure
- [ ] Has "status": "success"
- [ ] Has "data" object
- [ ] Has "data.learners" array
- [ ] Has "data.strata_summary" array

#### Learner Data
**Before fix:**
```json
{
  "marking_status": "Not Marked",
  "performance_level": "Not Assessed",
  "unit_standards_count": 0
}
```

**After fix (expected):**
- [ ] ✅ marking_status: "Marked"
- [ ] ✅ performance_level: "High", "Medium", or "Low"
- [ ] ✅ unit_standards_count: > 0
- [ ] ✅ poe_count: > 0
- [ ] ✅ poe_completeness: "Complete" or "Partial"

#### Stratification Summary
- [ ] Shows multiple strata
- [ ] Each stratum has:
  - [ ] class
  - [ ] classID
  - [ ] site
  - [ ] poe_completeness
  - [ ] marking_status: "Marked" ✅
  - [ ] performance_level: "High"/"Medium"/"Low" ✅
  - [ ] total_in_stratum
  - [ ] selected_from_stratum
  - [ ] sampling_rate

**Expected strata distribution:**
- [ ] At least one stratum with marking_status: "Marked"
- [ ] At least one stratum with performance_level: "High"
- [ ] At least one stratum with performance_level: "Medium" or "Low"

## Testing Phase 3: Fresh Sampling (Optional)

### Reset Assignments
```sql
DELETE FROM moderator_assignments WHERE moderator_id = '77';
```

### Re-test API
- [ ] Call API again: `get_learners_with_poe_assigned.php?moderator_id=77`
- [ ] Verify new assignments created
- [ ] Verify stratification metadata stored correctly
- [ ] Check is_existing_assignment: false (first call)
- [ ] Call API again
- [ ] Check is_existing_assignment: true (second call)

## Success Criteria

### Must Have (Critical) ✅
1. [ ] temp_learner_marks table has rows (not empty)
2. [ ] Marking Status shows "Marked" (not "Not Marked")
3. [ ] Performance Level shows "High", "Medium", or "Low" (not "Not Assessed")
4. [ ] Unit Standards Count > 0 (not NULL or 0)
5. [ ] Average Marks > 0 (not NULL)

### Should Have (Important) ✅
6. [ ] Stratification summary shows different performance levels
7. [ ] Multiple strata with "Marked" status
8. [ ] POE completeness calculated correctly
9. [ ] Class filtering working (only Class A learners for moderator 77)
10. [ ] No PHP errors or warnings

### Nice to Have (Optional) ✅
11. [ ] Sampling rate approximately 25% per stratum
12. [ ] Balanced distribution across strata
13. [ ] Persistent assignments (same learners on second call)

## Troubleshooting

### If temp_learner_marks is still empty:
1. [ ] Check if assessments table exists
2. [ ] Check if assessments.assessment_type column has "Summative" values
3. [ ] Check if marks.exercise matches assessments.exercise
4. [ ] Run: `SELECT COUNT(*) FROM assessments WHERE assessment_type = 'Summative'`
5. [ ] Run: `SELECT COUNT(*) FROM marks m INNER JOIN assessments a ON m.exercise = a.exercise WHERE a.assessment_type = 'Summative'`

### If still showing "Not Marked":
1. [ ] Verify the join is using `m.exercise = a.exercise` (not assessment_id)
2. [ ] Check for typos in column names
3. [ ] Verify assessments table has data
4. [ ] Check MySQL/MariaDB version compatibility

### If performance levels are wrong:
1. [ ] Check avg_marks values in temp_learner_marks
2. [ ] Verify CASE statement logic (High: 70+, Medium: 50-69, Low: <50)
3. [ ] Check for NULL handling

## Sign-Off

### Tester Information
- [ ] Tester Name: _______________
- [ ] Date: _______________
- [ ] Time: _______________

### Test Results
- [ ] All critical tests passed ✅
- [ ] All important tests passed ✅
- [ ] Issues found: _______________
- [ ] Notes: _______________

### Approval
- [ ] Ready for production ✅
- [ ] Needs fixes ❌
- [ ] Approved by: _______________

## Additional Notes

Use this space to document any issues, observations, or recommendations:

_______________________________________________
_______________________________________________
_______________________________________________
_______________________________________________
_______________________________________________

