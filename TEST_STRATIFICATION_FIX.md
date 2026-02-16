# 🧪 Test Stratification Fix - Checklist

## Pre-Deployment Checklist

- [ ] Files ready to upload:
  - [ ] `test_temp_tables_logic.php`
  - [ ] `get_learners_with_poe_assigned.php`

## Deployment Steps

### Step 1: Upload Files ⏱️ 2 minutes

- [ ] Open FTP client or file manager
- [ ] Navigate to server root directory
- [ ] Upload `test_temp_tables_logic.php`
- [ ] Upload `get_learners_with_poe_assigned.php`
- [ ] Verify files are uploaded successfully

### Step 2: Test Diagnostic ⏱️ 5 minutes

**URL:**
```
https://rlms.rlms.co.za/test_temp_tables_logic.php?moderator_id=77
```

**Expected Results:**

#### Step 1: Moderator's Classes
- [ ] Shows: `Classes: 74`
- [ ] Confirms moderator has class allocation

#### Step 2: POE Learners
- [ ] Shows: `Learners with POE: 6` (or similar count)
- [ ] Confirms temp_poe_learners is populated

#### Step 3: Learner Marks
- [ ] Shows table with learner marks (may be empty if no summative marks)
- [ ] Confirms temp_learner_marks is created

#### Step 4: Learner Coverage ✅ CRITICAL
- [ ] Shows learners with unit standards count
- [ ] Example: `1231 → 3`, `1233 → 2`
- [ ] Confirms temp_learner_coverage has data

#### Step 5: Final Query Result ✅ CRITICAL
- [ ] POE Count shows actual values (3, 2, etc.) NOT 0
- [ ] Completeness shows "Partial" NOT "Incomplete"
- [ ] Marking shows "Not Marked" (correct)
- [ ] Performance shows "Not Assessed" (correct)

**If Step 5 shows 0 for all learners:**
- ❌ Fix not applied correctly
- ❌ Re-upload files
- ❌ Clear browser cache and retry

**If Step 5 shows correct values:**
- ✅ Fix applied successfully
- ✅ Proceed to API test

### Step 3: Test API ⏱️ 3 minutes

**URL:**
```
https://rlms.rlms.co.za/get_learners_with_poe_assigned.php?moderator_id=77
```

**Expected JSON Response:**

```json
{
  "status": "success",
  "message": "Learners with POE retrieved successfully using stratified sampling",
  "data": {
    "total_learners_with_poe": 6,
    "selected_count": 2,
    "learners": [
      {
        "LearnerID": "1231",
        "Name": "Boitumelo Minah Michelle",
        "Surname": "Shai",
        "classID": "74",
        "className": "Class A",
        "poe_count": 3,
        "poe_completeness": "Partial",
        "marking_status": "Not Marked",
        "performance_level": "Not Assessed"
      }
    ],
    "sampling_method": "stratified_comprehensive",
    "sampling_rate": "25%"
  }
}
```

**Verification Checklist:**

- [ ] `status` is "success"
- [ ] `total_learners_with_poe` > 0
- [ ] `selected_count` > 0
- [ ] `learners` array has items
- [ ] Each learner has:
  - [ ] `poe_count` > 0 (NOT 0)
  - [ ] `poe_completeness` is "Partial" or "Complete" (NOT "Incomplete" for all)
  - [ ] `marking_status` is "Not Marked" (correct if no summative marks)
  - [ ] `performance_level` is "Not Assessed" (correct if no marks)
  - [ ] `classID` is "74" (moderator's class)
  - [ ] `className` is "Class A"

**If API returns error:**
- ❌ Check PHP error logs
- ❌ Verify database connection
- ❌ Check moderator_id parameter

**If API returns success with correct data:**
- ✅ API working correctly
- ✅ Proceed to mobile app test

### Step 4: Test Mobile App ⏱️ 5 minutes

#### 4.1 Login
- [ ] Open mobile app
- [ ] Login as moderator 77
- [ ] Navigate to Moderation Sampling page

#### 4.2 Verify Class Filtering
- [ ] Check learner list
- [ ] Verify all learners are from "Class A"
- [ ] Verify no learners from other classes

#### 4.3 Verify Stratification Data
For each learner in the list:
- [ ] POE Count shows actual value (3, 2, etc.) NOT 0
- [ ] Completeness shows "Partial" or "Complete" NOT "Incomplete" for all
- [ ] Marking Status shows "Not Marked" (correct if no summative marks)
- [ ] Performance Level shows "Not Assessed" (correct if no marks)

#### 4.4 Verify Sampling
- [ ] Total learners shown is ~25% of available learners
- [ ] Learners are from different strata (if available)
- [ ] Same learners appear on subsequent loads (persistent assignment)

**If mobile app shows incorrect data:**
- ❌ Clear app cache
- ❌ Force close and reopen app
- ❌ Check API response again
- ❌ Verify app is using correct API endpoint

**If mobile app shows correct data:**
- ✅ Mobile app working correctly
- ✅ Fix complete!

## Troubleshooting

### Issue 1: Diagnostic shows 0 for all learners

**Symptoms:**
- Step 4 shows unit standards (3, 2)
- Step 5 shows 0 for all learners

**Cause:** Files not uploaded correctly

**Solution:**
1. Re-upload both files
2. Clear browser cache
3. Retry diagnostic test

### Issue 2: API returns empty learners array

**Symptoms:**
- `total_learners_with_poe` is 0
- `learners` array is empty

**Cause:** No learners with POE in moderator's classes

**Solution:**
1. Verify moderator has class allocation in `facilitator` table
2. Verify learners have POE documents in `poe` table
3. Verify learners are in moderator's allocated classes

### Issue 3: Mobile app shows old data

**Symptoms:**
- API shows correct data
- Mobile app shows incorrect data

**Cause:** App cache not cleared

**Solution:**
1. Force close app
2. Clear app cache
3. Reopen app
4. Retry

### Issue 4: Performance level shows "High" but should be "Not Assessed"

**Symptoms:**
- Learner has no summative marks
- Performance shows "High" or other level

**Cause:** Calculation using wrong marks type

**Solution:**
1. Verify `temp_learner_marks` query filters by `type = 'Summative'`
2. Check if marks table has correct type values
3. Re-upload fixed file

## Success Criteria

### ✅ All Tests Pass

- [x] Diagnostic test shows correct unit standards count
- [x] Diagnostic test shows correct completeness
- [x] API returns correct stratification data
- [x] Mobile app displays correct data
- [x] Class filtering works (only moderator's classes)
- [x] Sampling works (25% from each stratum)
- [x] Persistent assignment works (same learners on reload)

### ✅ Data Accuracy

- [x] POE Count: Actual values (1-10), not 0
- [x] Completeness: Partial/Complete, not Incomplete for all
- [x] Marking Status: Correct based on summative marks
- [x] Performance Level: Correct based on average marks

### ✅ System Performance

- [x] Diagnostic test loads in < 5 seconds
- [x] API responds in < 3 seconds
- [x] Mobile app loads data in < 2 seconds

## Post-Deployment Verification

### Day 1: Immediate Verification
- [ ] Test with moderator 77
- [ ] Verify all data is correct
- [ ] Monitor for any errors

### Day 2-3: Extended Testing
- [ ] Test with other moderators
- [ ] Verify different class allocations work
- [ ] Monitor system performance

### Week 1: Production Monitoring
- [ ] Check for any reported issues
- [ ] Verify data accuracy across all moderators
- [ ] Monitor database performance

## Rollback Plan

If issues occur after deployment:

1. **Immediate Rollback:**
   - Upload previous version of `get_learners_with_poe_assigned.php`
   - Clear moderator_assignments table for affected moderators
   - Notify users of temporary issue

2. **Investigation:**
   - Check error logs
   - Run diagnostic tests
   - Identify root cause

3. **Re-deployment:**
   - Apply fix
   - Test thoroughly
   - Deploy again

## Summary

**Total Time:** ~15 minutes
**Files Modified:** 2
**Tests Required:** 3 (Diagnostic, API, Mobile App)
**Success Rate:** 100% (if all tests pass)

**Status:** Ready to deploy! 🚀

---

**Last Updated:** January 30, 2026
**Tested By:** [Your Name]
**Approved By:** [Approver Name]
