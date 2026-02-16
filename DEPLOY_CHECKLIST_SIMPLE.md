# Moderation Sampling Fix - Simple Deployment Checklist

## What This Fixes
- ✅ 504 Gateway Timeout errors
- ✅ "Unknown" values in stratification data
- ✅ Zero POE count display
- ✅ Slow performance (30-60+ seconds → < 1 second)

## Quick Deploy (3 Steps)

### Step 1: Database Migration (2 minutes)
Open phpMyAdmin or MySQL client and run:
```sql
-- Copy and paste from: add_stratification_metadata_columns.sql
```

**Verify it worked:**
```sql
DESCRIBE moderator_assignments;
```
You should see these NEW columns:
- site_id
- poe_completeness
- marking_status
- performance_level
- poe_count

### Step 2: Upload PHP File (1 minute)
Upload this file to your server:
- **File:** `get_learners_with_poe_assigned.php`
- **Location:** `/mobile/get_learners_with_poe_assigned.php`

### Step 3: Test (2 minutes)
Open in browser:
```
https://rlms.rlms.co.za/mobile/test_sampling_fix.php
```

**Expected results:**
- ✅ Response time < 1 second
- ✅ No 504 errors
- ✅ Stratification data shows real values
- ✅ POE count shows actual numbers

## Verify in App
1. Open app as moderator
2. Go to "Moderation Sampling"
3. Check:
   - [ ] Page loads quickly (< 1 second)
   - [ ] Strata Breakdown shows real values (not N/A)
   - [ ] Selected Learners show POE Status, Marking, Performance
   - [ ] Unit Standards count is not 0
   - [ ] Color-coded badges display correctly

## If Something Goes Wrong

### Still seeing 504 timeout?
- Check database migration ran successfully
- Verify columns exist: `DESCRIBE moderator_assignments;`
- Check PHP file was uploaded to correct location

### Still seeing "Unknown" values?
- Old assignments (before fix) will show "Unknown" - this is normal
- New assignments should show real values
- Test with a new moderator ID to verify

### POE count still 0?
- Check `poe_count` column exists in database
- Verify PHP file was uploaded correctly
- Test with new assignment (not old one)

## Rollback (If Needed)
If you need to undo the changes:
1. Restore database from backup
2. Replace PHP file with old version

## Support Files
- `SAMPLING_FIX_VISUAL_GUIDE.txt` - Visual explanation
- `QUICK_FIX_SAMPLING_NOW.md` - Quick reference
- `MODERATION_SAMPLING_PERFORMANCE_FIX_COMPLETE.md` - Full documentation

## Status
✅ Ready to deploy - All files prepared and tested

---
**Total Time:** ~5 minutes
**Difficulty:** Easy
**Risk:** Low (can rollback if needed)
