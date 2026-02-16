# Deploy Class Filtering Fix - Quick Guide

## What Was Fixed
The moderation sampling was returning ALL learners with POE instead of only learners from the moderator's allocated classes. The bug was in the main query which didn't use the filtered temp table.

## Files Changed
1. **get_learners_with_poe_assigned.php** - Fixed main query to use temp_poe_learners table

## Deployment Steps

### 1. Upload Fixed File
```bash
# Upload to server
scp get_learners_with_poe_assigned.php user@rlms.rlms.co.za:/path/to/web/root/
```

### 2. Test the Fix
```bash
# Option A: Run test script
php test_class_filtering_fix.php?moderator_id=77

# Option B: Test API directly in browser
https://rlms.rlms.co.za/get_learners_with_poe_assigned.php?moderator_id=77
```

### 3. Verify Results
Check that:
- ✅ All returned learners have classID matching moderator's allocated classes
- ✅ No learners from other classes appear
- ✅ Sampling rate is ~25% of available learners
- ✅ Stratification summary shows correct classes

### 4. Clear Incorrect Assignments (Optional)
If moderators already have incorrect assignments from before the fix:

```sql
-- Clear all assignments to force re-sampling
DELETE FROM moderator_assignments;

-- OR clear specific moderator
DELETE FROM moderator_assignments WHERE moderator_id = '77';
```

### 5. Test in Mobile App
1. Login as moderator 77
2. Go to Moderation page
3. Trigger sampling
4. Verify only learners from Class A appear

## Quick Test Commands

### Test Moderator 77 (has 1 class)
```bash
curl "https://rlms.rlms.co.za/get_learners_with_poe_assigned.php?moderator_id=77"
```

### Verify Data
```bash
php test_moderator_77_data.php
```

### Full Verification
```bash
php test_class_filtering_fix.php?moderator_id=77
```

## Expected Behavior

### Before Fix:
- Moderator 77 would see learners from ALL classes in the database
- Class filtering was completely ignored

### After Fix:
- Moderator 77 sees ONLY learners from Class A (ID: 74)
- ~1 learner selected (25% of 3 available)
- All learners have classID = 74

## Rollback Plan
If issues occur, restore the previous version:
```bash
# Restore backup
cp get_learners_with_poe_assigned.php.backup get_learners_with_poe_assigned.php
```

## Success Criteria
- ✅ Moderators only see learners from their allocated classes
- ✅ No errors in API response
- ✅ Stratified sampling still works correctly
- ✅ Mobile app displays correct learners

## Support
If issues occur:
1. Check PHP error logs
2. Run test_moderator_77_data.php to verify data
3. Check facilitator table for moderator's class assignments
4. Verify temp tables are being created correctly

## Summary
This fix ensures proper scope control for moderators. Each moderator will now only see and moderate learners from the classes they are allocated to in the facilitator table.
