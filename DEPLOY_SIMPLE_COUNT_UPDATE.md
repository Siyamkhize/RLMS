# Deploy Simple Count Update - Quick Checklist

## What Was Done

Updated `get_learners_with_poe_assigned.php` to include simple count query that returns accurate total of 1571 learners with POE.

## Files to Upload to Server

1. **get_learners_with_poe_assigned.php** (MODIFIED - main endpoint)

## Testing Before Deploy

### Local Test (Recommended)

```bash
php test_main_endpoint_with_count.php
```

**Expected Result:**
```
✅ total_learners_with_poe_global field EXISTS
   Value: 1571

Key Response Fields:
  - total_learners_with_poe_global: 1571 (ALL learners with POE)
  - total_learners_with_poe: 273 (In moderator's classes)
  - selected_count: 273 (Assigned to moderator)
```

## Deployment Steps

### Option 1: Upload via FTP/File Manager

1. Navigate to your server's mobile directory
2. Backup existing file:
   - Rename `get_learners_with_poe_assigned.php` to `get_learners_with_poe_assigned.php.backup`
3. Upload new `get_learners_with_poe_assigned.php`
4. Test the endpoint

### Option 2: Direct Edit on Server

1. Open `get_learners_with_poe_assigned.php` in cPanel File Manager
2. Find the function `getLearnersWithPOEForModerator()`
3. Add the simple count query at the beginning (after `createModeratorAssignmentsTable()`)
4. Update all three return statements to include `total_learners_with_poe_global`
5. Save the file

## Testing After Deploy

### Test via Browser

```
https://rlms.rlms.co.za/mobile/get_learners_with_poe_assigned.php?moderator_id=77
```

**Check Response:**
```json
{
  "status": "success",
  "data": {
    "total_learners_with_poe_global": 1571,  // ← Should be 1571
    "total_learners_with_poe": 273,
    "selected_count": 273,
    "learners": [...]
  }
}
```

### Test via Command Line (on server)

```bash
php test_main_endpoint_with_count.php
```

## Verification Checklist

- [ ] File uploaded successfully
- [ ] No PHP syntax errors
- [ ] Endpoint returns JSON response
- [ ] `total_learners_with_poe_global` field exists
- [ ] Value is 1571 (or current accurate total)
- [ ] Existing fields still work (`total_learners_with_poe`, `selected_count`)
- [ ] Learners array is populated
- [ ] No timeout errors

## Rollback Plan

If issues occur:

1. Rename backup file back to original:
   - `get_learners_with_poe_assigned.php.backup` → `get_learners_with_poe_assigned.php`
2. Or restore from your local copy

## What Changed

### Before:
```json
{
  "total_learners_with_poe": 273,
  "selected_count": 273
}
```

### After:
```json
{
  "total_learners_with_poe_global": 1571,  // NEW: Accurate total
  "total_learners_with_poe": 273,          // Moderator's classes
  "selected_count": 273                     // Assigned learners
}
```

## Performance Impact

- **Minimal**: Simple COUNT query adds ~5-10ms
- **No Timeout Risk**: Query is very fast
- **No Breaking Changes**: All existing fields remain

## Support

If you encounter issues:

1. Check PHP error logs
2. Verify database connection
3. Test with `test_simple_count.php` first
4. Compare with `get_learners_with_poe_simple_api.php` (working example)

## Success Criteria

✅ Endpoint returns `total_learners_with_poe_global: 1571`  
✅ No timeout errors  
✅ Response time < 10 seconds  
✅ All existing functionality works  

---

**Status**: Ready to deploy  
**Risk Level**: Low (only adds new field, doesn't modify existing logic)  
**Estimated Deploy Time**: 5 minutes
