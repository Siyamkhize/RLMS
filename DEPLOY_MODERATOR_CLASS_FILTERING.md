# Deploy Moderator Class Filtering - Quick Guide

## What Changed?
Moderation sampling now filters learners based on the classes allocated to each moderator. Moderators will only see learners from their assigned classes.

## Files Modified
1. ✅ `get_learners_with_poe_assigned.php` - Added class filtering logic

## Files Created
1. ✅ `test_moderator_class_filtering.php` - Test script
2. ✅ `MODERATION_SAMPLING_CLASS_FILTERING_COMPLETE.md` - Full documentation
3. ✅ `DEPLOY_MODERATOR_CLASS_FILTERING.md` - This file

## Deployment Steps

### Step 1: Upload Modified File
Upload the updated file to your server:
```
get_learners_with_poe_assigned.php
```

### Step 2: Verify Moderator Class Assignments
Ensure moderators are properly assigned to classes in the `facilitator` table:

```sql
-- Check moderator's class assignments
SELECT 
    f.facilitator_id,
    f.classID,
    c.className,
    c.siteID,
    s.siteName
FROM facilitator f
LEFT JOIN class c ON f.classID = c.classID
LEFT JOIN sites s ON c.siteID = s.siteID
WHERE f.facilitator_id = 'YOUR_MODERATOR_ID';
```

**Important:** If a moderator has no entries in the `facilitator` table, they will see NO learners in sampling!

### Step 3: Test with Sample Moderator
Upload the test file and run it:
```
test_moderator_class_filtering.php
```

Access via browser:
```
http://your-server/test_moderator_class_filtering.php?moderator_id=YOUR_MODERATOR_ID
```

**Expected Results:**
- ✅ Shows moderator's allocated classes
- ✅ Shows learner count per class
- ✅ API returns only learners from moderator's classes
- ✅ All validation checks pass

### Step 4: Test in Mobile App
1. Login as a moderator
2. Navigate to ModeratorPage
3. Trigger sampling (if not already assigned)
4. Verify learners shown are only from moderator's classes
5. Check class names in the learner list

### Step 5: Verify Multiple Moderators
Test with different moderators to ensure:
- Each moderator sees only their class learners
- No overlap in assignments
- Sampling works correctly for each

## Quick Test Commands

### Check if moderator has classes
```sql
SELECT COUNT(*) as class_count 
FROM facilitator 
WHERE facilitator_id = 'YOUR_MODERATOR_ID';
```

### Check learners with POE in moderator's classes
```sql
SELECT 
    l.classID,
    c.className,
    COUNT(DISTINCT l.LearnerID) as learner_count
FROM learnerdetails l
INNER JOIN poe p ON l.LearnerID = p.learnerID
LEFT JOIN class c ON l.classID = c.classID
WHERE p.filePath IS NOT NULL 
AND p.filePath != ''
AND l.classID IN (
    SELECT classID 
    FROM facilitator 
    WHERE facilitator_id = 'YOUR_MODERATOR_ID'
)
GROUP BY l.classID, c.className;
```

### Check existing moderator assignments
```sql
SELECT 
    ma.moderator_id,
    ma.learner_id,
    l.Name,
    l.Surname,
    l.classID,
    c.className
FROM moderator_assignments ma
INNER JOIN learnerdetails l ON ma.learner_id = l.LearnerID
LEFT JOIN class c ON l.classID = c.classID
WHERE ma.moderator_id = 'YOUR_MODERATOR_ID'
ORDER BY c.className, l.Surname;
```

## Common Issues & Solutions

### Issue 1: Moderator sees no learners
**Diagnosis:**
```sql
-- Check if moderator has class assignments
SELECT * FROM facilitator WHERE facilitator_id = 'YOUR_MODERATOR_ID';
```

**Solutions:**
- Add moderator to `facilitator` table with their classes
- Ensure learners exist with POE in those classes
- Check if all eligible learners are already assigned to other moderators

### Issue 2: Moderator sees learners from wrong classes
**Diagnosis:**
Run the test script to see which classes are being included

**Solutions:**
- Verify `facilitator` table has correct class assignments
- Check learner's `classID` in `learnerdetails` table
- Clear any cached data (if applicable)

### Issue 3: API returns error
**Diagnosis:**
Check PHP error logs for detailed error messages

**Solutions:**
- Ensure database connection is working
- Verify `facilitator` table exists and has data
- Check PHP version compatibility (prepared statements)

## Rollback Plan

If issues occur, you can rollback by:

1. Restore the previous version of `get_learners_with_poe_assigned.php`
2. The system will revert to showing all learners (no class filtering)
3. No database changes were made, so no data cleanup needed

## Success Criteria

✅ Moderators see only learners from their allocated classes
✅ Sampling still uses stratified approach (25% per stratum)
✅ No errors in API responses
✅ Test script passes all validation checks
✅ Mobile app displays correct learners

## Post-Deployment Monitoring

Monitor for:
- API errors in logs
- Moderators reporting empty learner lists
- Moderators seeing unexpected learners
- Performance issues (should be minimal)

## Support

If issues arise:
1. Run the test script to diagnose
2. Check database for moderator class assignments
3. Review PHP error logs
4. Verify API responses match expected format

## Summary

This deployment adds class-based filtering to moderation sampling. The change is backward compatible and requires no database schema changes. The main requirement is that moderators must be properly assigned to classes in the `facilitator` table.

**Critical:** Ensure all moderators have entries in the `facilitator` table before deploying, or they will see no learners!
