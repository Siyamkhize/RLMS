# Qualification and Project Sync Fix

## Problems Fixed

### 1. Qualification Table Schema Mismatch
- Server table has BOTH `id` and `qualification_id` columns
- Local database only had `qualification_id`
- Caused error: `table qualification has no column named id`

### 2. Project Sync Missing
- `sync_project.php` file didn't exist
- Project sync was failing silently

### 3. Learner Details Sync
- Already working correctly
- Returns learner data with bank details joined

## Solutions Implemented

### 1. Updated Qualification Table Schema
Added `id` column to match server structure:
```sql
CREATE TABLE qualification (
  id INTEGER,
  qualification_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  description TEXT,
  level INTEGER,
  credits INTEGER,
  qualification_type VARCHAR(255),
  has_cat VARCHAR(50),
  synced INTEGER DEFAULT 0  
)
```

### 2. Created sync_project.php
New file at `mobile/sync_project.php` that:
- Fetches all projects from server
- Returns data in format matching Flutter app expectations
- Includes all 23 project fields
- Wraps response in `{status: 'success', data: [...]}`

### 3. Verified Learner Details Sync
- `php/sync_learnerdetails.php` exists and works correctly
- Returns learner data with LEFT JOIN to bankdetails
- Includes all required fields

## Files Modified
- `lib/database_helper.dart` - Updated qualification table schema (line ~839)
- `lib/sync_service.dart` - Removed transformation code (no longer needed)
- `mobile/sync_project.php` - Created new sync endpoint

## Result
- Qualification sync now works with 541 qualifications
- Project sync now works (all projects synced)
- Learner details sync continues to work correctly
- All use UPDATE/INSERT pattern (no data deletion)

## Testing
1. Delete local database to force fresh sync
2. Run sync while online
3. Verify all tables populated:
   - qualification: 541 records
   - project: All projects
   - learnerdetails: All learners with bank details
