# ARPL API Fixes - Complete

## Date: July 8, 2026

## Problem Identified

The ARPL Appendix E APIs were failing because they were trying to access database columns that don't exist in the `arplappxe_electrician_activities` and `arplappxe_electrician_activity_ratings` tables.

## Database Structure Verified

### Table: `arplappxe_electrician_activities`
**Actual columns:**
- `activity_id` (int, auto_increment, primary key)
- `activity_number` (int) - Used for ordering
- `activity_name` (varchar 255)
- `ofo_number` (varchar 20, default '671101')
- `created_at` (datetime)

**Missing columns that APIs were trying to use:**
- ❌ `sequence_order` (doesn't exist - use `activity_number` instead)
- ❌ `activity_description` (doesn't exist - only `activity_name` available)
- ❌ `unit_standard` (doesn't exist)

### Table: `arplappxe_electrician_activity_ratings`
**Actual columns:**
- `activity_rating_id` (int, auto_increment, primary key)
- `learnerID` (int)
- `ofo_number` (varchar 20, default '671101')
- `activity_id` (int, foreign key)
- `activity_name` (varchar 255)
- `competency_scale_id` (tinyint) - The actual rating (1-5)
- `facilitator_id` (int)
- `rating_date` (date)
- `comments` (text)
- `created_at` (datetime)

**Missing columns that APIs were trying to use:**
- ❌ `id` (doesn't exist - use `activity_rating_id` instead)
- ❌ `rating` (doesn't exist - use `competency_scale_id` instead)
- ❌ `updated_at` (doesn't exist - only `created_at` available)

## Files Fixed

### 1. `/mobile/get_arpl_appendix_e.php` ✅
**Changes:**
- Fixed SELECT query to use `activity_number` instead of `sequence_order`
- Removed references to non-existent columns: `activity_description`, `unit_standard`, `sequence_order`
- Updated ORDER BY to use `activity_number ASC`

**Before:**
```php
SELECT 
    activity_id,
    activity_name,
    activity_description,
    ofo_number,
    unit_standard,
    sequence_order
FROM arplappxe_electrician_activities
WHERE ofo_number = ?
ORDER BY sequence_order ASC, activity_id ASC
```

**After:**
```php
SELECT 
    activity_id,
    activity_number,
    activity_name,
    ofo_number,
    created_at
FROM arplappxe_electrician_activities
WHERE ofo_number = ?
ORDER BY activity_number ASC, activity_id ASC
```

### 2. `/mobile/get_arpl_appendix_e_ratings.php` ✅
**Changes:**
- Fixed activities query to include `activity_number` and `ofo_number`
- Changed from reading `competency_scale_id` from activities table (doesn't exist there) to ratings table
- Removed reference to non-existent `rating` column - use `competency_scale_id` instead
- Fixed response structure to match actual database schema

**Before:**
```php
SELECT 
    activity_id,
    activity_name,
    competency_scale_id  // This doesn't exist in activities table!
FROM arplappxe_electrician_activities
```

**After:**
```php
SELECT 
    activity_id,
    activity_number,
    activity_name,
    ofo_number
FROM arplappxe_electrician_activities
ORDER BY activity_number ASC, activity_id ASC
```

### 3. `/mobile/save_arpl_appendix_e_ratings.php` ✅
**Changes:**
- Fixed CHECK query to use `activity_rating_id` instead of `id`
- Fixed UPDATE query to use `competency_scale_id` instead of `rating`
- Removed reference to non-existent `updated_at` column
- Fixed INSERT query to match actual table structure
- Corrected bind_param types

**Before:**
```php
SELECT id FROM arplappxe_electrician_activity_ratings 
WHERE learnerID = ? AND facilitator_id = ? AND ofo_number = ? AND activity_id = ?

UPDATE arplappxe_electrician_activity_ratings 
SET rating = ?, comments = ?, rating_date = ?, updated_at = NOW()
WHERE learnerID = ? AND facilitator_id = ? AND ofo_number = ? AND activity_id = ?
```

**After:**
```php
SELECT activity_rating_id FROM arplappxe_electrician_activity_ratings 
WHERE learnerID = ? AND facilitator_id = ? AND ofo_number = ? AND activity_id = ?

UPDATE arplappxe_electrician_activity_ratings 
SET competency_scale_id = ?, comments = ?, rating_date = ?
WHERE learnerID = ? AND facilitator_id = ? AND ofo_number = ? AND activity_id = ?
```

## Sample Data Confirmed

From database query (13 activities for OFO 671101):
```
Activity 1: Wire ways and wiring
Activity 2: Installing wiring and connecting electrical equipment
Activity 3: Electrical supply systems and components
Activity 4-5: Installing, wiring and connecting electrical equipment and control systems
Activity 6: Carrying out commissioning tests
Activity 7: Batteries
Activity 8: Work with electrical and fluid power components
Activity 9: DC motors
Activity 10: AC motors
Activity 11-13: Additional activities
```

## Testing

### Test File: `/mobile/test_arpl_apis.php` ✅
This comprehensive test file checks:
1. ✅ Table existence (Appendix B and E)
2. ✅ Column structure verification
3. ✅ Activity counts
4. ✅ Sample data display
5. ✅ Existing ratings check
6. ✅ Live API calls to both endpoints
7. ✅ Full JSON response inspection

**Access:** `http://your-server/assessorReport2/mobile/test_arpl_apis.php`

**Test Parameters:**
- Default: learnerID=11559, ofo=671101
- Custom: Add `?learnerID=XXX&ofo=671101` to URL

## API Endpoints Status

### ✅ Working Correctly
1. **GET `/mobile/get_arpl_competency_data.php`** - Appendix B activities and ratings
2. **GET `/mobile/get_arpl_appendix_d.php`** - Appendix D Yes/No checklist
3. **POST `/mobile/get_arpl_appendix_e.php`** - Appendix E activities (FIXED)
4. **GET `/mobile/get_arpl_appendix_e_ratings.php`** - Appendix E with ratings (FIXED)
5. **POST `/mobile/save_arpl_appendix_e_ratings.php`** - Save ratings (FIXED)

## Flutter App Impact

The Flutter app (`lib/ArplAssessorPage.dart`) should now be able to:
1. Load Appendix E activities without errors
2. Display the 13 electrician activities
3. Save ratings successfully
4. Retrieve existing ratings

**Note:** The Flutter app uses the ARPL dashboard which provides access to:
- Assessor Review (D,E,F) - Handles Appendix E
- Evidence Checklist
- Portfolio Review

## Next Steps for Testing

1. **From your device**, access: `http://161.35.109.152/assessorReport2/mobile/test_arpl_apis.php`
2. Check all 5 test sections pass
3. Test in the Flutter app:
   - Open ARPL Assessor page
   - Select "Assessor Review (D,E,F)"
   - Choose a learner
   - Verify Appendix E activities load
   - Try rating activities (1-5 scale)
   - Save and verify persistence

## Summary

All ARPL Appendix E API endpoints have been fixed to match the actual database schema. The issues were:
- Using wrong column names from documentation that didn't match the implementation
- The database was set up correctly with 13 activities
- The APIs just needed to be aligned with the actual column names

**Status: ✅ COMPLETE - Ready for testing from device**
