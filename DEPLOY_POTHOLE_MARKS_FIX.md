# Deploy Pothole Marks Moderator Fix

## Quick Deployment Guide

### Issue Fixed
Pothole checklist marks were not displaying in the moderator page because they are stored in `logbook_marks` table, but the system was looking in the wrong tables.

### Files Changed
1. `php/view_pothole_checklists.php` - Now fetches marks from logbook_marks table
2. `save_moderation.php` - Now updates logbook_marks table for pothole moderation
3. `add_moderation_columns_to_logbook_marks.sql` - SQL script to add required columns
4. `test_pothole_marks_moderator.php` - Test script to verify the fix

### Deployment Steps

#### Step 1: Backup Database
```bash
mysqldump -u username -p database_name > backup_before_pothole_fix.sql
```

#### Step 2: Add Required Database Columns
Run the SQL script to add moderation columns to logbook_marks table:

```bash
mysql -u username -p database_name < add_moderation_columns_to_logbook_marks.sql
```

Or manually execute:
```sql
ALTER TABLE logbook_marks 
ADD COLUMN IF NOT EXISTS moderator_status VARCHAR(50) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderator_comment TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderator_id VARCHAR(50) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderation_date TIMESTAMP NULL DEFAULT NULL,
ADD COLUMN IF NOT EXISTS assessor_comment TEXT DEFAULT NULL;
```

#### Step 3: Deploy PHP Files
Upload the updated PHP files to your server:
```bash
# Upload to server
scp php/view_pothole_checklists.php user@server:/path/to/php/
scp save_moderation.php user@server:/path/to/
scp test_pothole_marks_moderator.php user@server:/path/to/
```

Or if using FTP/file manager:
- Upload `php/view_pothole_checklists.php`
- Upload `save_moderation.php`
- Upload `test_pothole_marks_moderator.php`

#### Step 4: Test the Fix

**Test 1: Check Database**
```sql
-- Verify columns exist
SHOW COLUMNS FROM logbook_marks LIKE 'moderator%';

-- Check for pothole marks
SELECT * FROM logbook_marks 
WHERE unit_standard_id LIKE '%pothole%' 
LIMIT 5;
```

**Test 2: Test Endpoint**
```bash
# Replace LEARNER_ID with actual learner ID
curl "https://your-domain.com/php/view_pothole_checklists.php?learner_id=LEARNER_ID"
```

Expected response should include:
```json
{
  "status": "success",
  "data": {
    "marks_scored": 85,
    "moderator_status": "",
    "moderator_comment": "",
    "assessor_comment": "Good work"
  }
}
```

**Test 3: Run Test Script**
```
https://your-domain.com/test_pothole_marks_moderator.php?learner_id=LEARNER_ID
```

This will show:
- Pothole marks in logbook_marks table
- Endpoint response
- Status of all pothole-related tables

#### Step 5: Test in Flutter App

1. **Login as Moderator**
   - Use moderator credentials

2. **Navigate to Learner**
   - Select a class
   - Select a learner who has pothole checklist marks

3. **View Pothole Checklist**
   - Expand "Pothole Checklist" section
   - Verify marks are displayed
   - Check if moderator comment section appears

4. **Test Moderation**
   - Add a comment in the moderator comment field
   - Click "Uphold" or "Withdraw"
   - Verify success message appears
   - Refresh the page
   - Verify moderation is saved

### Verification Checklist

- [ ] Database columns added successfully
- [ ] PHP files deployed to server
- [ ] Test endpoint returns marks correctly
- [ ] Moderator page displays pothole marks
- [ ] Moderator can add comments
- [ ] Uphold/Withdraw buttons work
- [ ] Moderation is saved to database
- [ ] Existing moderator comments load correctly
- [ ] No console errors in Flutter app
- [ ] No PHP errors in server logs

### Troubleshooting

#### Issue: Marks not displaying
**Check:**
1. Verify marks exist in logbook_marks table:
   ```sql
   SELECT * FROM logbook_marks 
   WHERE learner_id = 'LEARNER_ID' 
   AND unit_standard_id LIKE '%pothole%';
   ```

2. Check unit_standard_id contains "pothole":
   ```sql
   SELECT DISTINCT unit_standard_id 
   FROM logbook_marks 
   WHERE unit_standard_id LIKE '%pothole%';
   ```

3. Test the endpoint directly:
   ```
   /php/view_pothole_checklists.php?learner_id=LEARNER_ID
   ```

#### Issue: Moderation not saving
**Check:**
1. Verify columns exist:
   ```sql
   SHOW COLUMNS FROM logbook_marks LIKE 'moderator%';
   ```

2. Check PHP error logs:
   ```bash
   tail -f /var/log/php_errors.log
   ```

3. Test moderation endpoint:
   ```bash
   curl -X POST https://your-domain.com/save_moderation.php \
     -H "Content-Type: application/json" \
     -d '{
       "learnerId": "LEARNER_ID",
       "assessmentType": "pothole_checklist",
       "unitStandardName": "Pothole Checklist",
       "moderatorStatus": "upheld",
       "moderatorComment": "Test comment",
       "moderatorId": "MOD123"
     }'
   ```

#### Issue: Wrong marks displayed
**Check:**
1. Multiple pothole entries:
   ```sql
   SELECT * FROM logbook_marks 
   WHERE learner_id = 'LEARNER_ID' 
   AND unit_standard_id LIKE '%pothole%'
   ORDER BY assessment_date DESC;
   ```

2. The system returns the most recent entry. If you need a specific date, add date filtering.

### Rollback Plan

If issues occur:

1. **Restore Database**
   ```bash
   mysql -u username -p database_name < backup_before_pothole_fix.sql
   ```

2. **Restore PHP Files**
   - Replace with backup versions
   - Or revert using version control

3. **Clear Cache**
   ```bash
   # Clear PHP opcache if enabled
   service php-fpm reload
   ```

### Performance Notes

- Added indexes for faster lookups:
  - `idx_learner_unit_standard` on (learner_id, unit_standard_id)
  - `idx_moderator` on (moderator_id, moderation_date)

- Query uses `LIKE '%pothole%'` which may be slow on large tables
- Consider adding a dedicated column if performance is an issue

### Support

If you encounter issues:
1. Check `test_pothole_marks_moderator.php` output
2. Review PHP error logs
3. Check Flutter console for errors
4. Verify database columns exist
5. Test with different learner IDs

## Summary

This fix ensures pothole checklist marks stored in the `logbook_marks` table are correctly fetched and displayed in the moderator page. Moderators can now view marks, add comments, and uphold/withdraw pothole assessments.

**Key Changes:**
- ✅ Fetch marks from logbook_marks table
- ✅ Display marks in moderator view
- ✅ Save moderation to logbook_marks table
- ✅ Support for moderator comments
- ✅ Uphold/Withdraw functionality

**No Flutter Changes Required** - The app already handles the data correctly!
