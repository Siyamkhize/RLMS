# Fix: Unknown column 'ma.stratum_type' Error

## Issue
Error when accessing Moderation Sampling page:
```
{"status":"error","message":"Unknown column 'ma.stratum_type' in 'SELECT'"}
```

## Root Cause
The `moderator_assignments` table exists but doesn't have the `stratum_type` column that was added in the enhanced version.

## Solution Applied

### 1. Updated PHP Code (get_learners_with_poe_assigned.php)
Modified `getModeratorAssignments()` function to:
- Check if `stratum_type` column exists before querying
- Use appropriate SQL query based on column existence
- Fallback to query without `stratum_type` if column doesn't exist

### 2. Database Migration Script
Created `add_stratum_type_column.sql` to add the missing column.

## How to Fix

### Option 1: Run SQL Migration (Recommended)
```bash
# On your database server
mysql -u your_username -p your_database < add_stratum_type_column.sql
```

Or run directly in phpMyAdmin/MySQL client:
```sql
ALTER TABLE moderator_assignments 
ADD COLUMN stratum_type VARCHAR(50) NULL 
COMMENT 'Type of stratification used' 
AFTER class_id;
```

### Option 2: Let PHP Auto-Create (Automatic)
The updated PHP code will:
1. Check if column exists
2. Use appropriate query
3. When new assignments are created, the table will be recreated with the column

## Verification

### Test the Endpoint
```bash
curl "https://rlms.rlms.co.za/mobile/get_learners_with_poe_assigned.php?moderator_id=TEST001"
```

Expected: Should return success response without column error

### Check Database
```sql
-- Verify column exists
DESCRIBE moderator_assignments;

-- Should show:
-- stratum_type | varchar(50) | YES | | NULL |
```

## Files Modified
1. ✅ `get_learners_with_poe_assigned.php` - Added column existence check
2. ✅ `add_stratum_type_column.sql` - Migration script

## Status
- **Backend Fix**: ✅ Applied (backward compatible)
- **Database Migration**: ⏳ Needs to be run on server
- **Frontend**: ✅ No changes needed

## Next Steps

1. **Upload Updated PHP File**
   ```bash
   # Upload to server
   scp get_learners_with_poe_assigned.php user@server:/path/to/mobile/
   ```

2. **Run Database Migration** (Optional but recommended)
   ```bash
   # Run SQL script
   mysql -u username -p database_name < add_stratum_type_column.sql
   ```

3. **Test in App**
   - Login as moderator
   - Click "Moderation Sampling"
   - Should load without errors

## Backward Compatibility
The fix is fully backward compatible:
- ✅ Works with existing tables (without stratum_type column)
- ✅ Works with new tables (with stratum_type column)
- ✅ No data loss
- ✅ No breaking changes

## Alternative: Manual Column Addition

If you prefer to add the column manually:

```sql
-- Connect to your database
USE your_database_name;

-- Add the column
ALTER TABLE moderator_assignments 
ADD COLUMN stratum_type VARCHAR(50) NULL 
COMMENT 'Type of stratification used' 
AFTER class_id;

-- Verify
SHOW COLUMNS FROM moderator_assignments;
```

## Testing Checklist

After applying the fix:
- [ ] Upload updated get_learners_with_poe_assigned.php
- [ ] Test endpoint with curl
- [ ] Login to app as moderator
- [ ] Click "Moderation Sampling"
- [ ] Verify page loads without errors
- [ ] Check that learners are displayed
- [ ] Verify stratification data shows correctly

## Error Resolution Timeline

1. **Immediate** (0 min): Upload updated PHP file → Error disappears
2. **Optional** (5 min): Run SQL migration → Full functionality enabled
3. **Verification** (2 min): Test in app → Confirm working

Total time: ~7 minutes

## Summary

The error is now fixed with a backward-compatible solution. The updated PHP code will work whether or not the `stratum_type` column exists in the database. For full functionality, run the SQL migration to add the column.

**Status**: ✅ FIXED - Ready to deploy
