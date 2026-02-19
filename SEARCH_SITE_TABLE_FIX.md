# Search Site Table Fix

## Problem
Search returns error: `Table 'rlmsrlmsco_ezxcmacd_rlms.site' doesn't exist`

## Root Cause
The search endpoints were trying to JOIN with a `site` table that doesn't exist in your database. This caused the entire query to fail.

## Solution
Updated both search endpoints to:
1. Check if the `site` table exists before using it
2. Use a fallback query without site data if the table doesn't exist
3. Handle missing site fields gracefully in results

## Files Modified

### 1. `search_learner_global.php`
Added table existence check and conditional query:

```php
// Check if site table exists
$tableCheck = $conn->query("SHOW TABLES LIKE 'site'");
$siteTableExists = ($tableCheck && $tableCheck->num_rows > 0);

if ($siteTableExists) {
    // Query WITH site table
    $query = "... LEFT JOIN site s ON c.siteID = s.siteID ...";
} else {
    // Query WITHOUT site table
    $query = "... (no site join) ...";
}
```

### 2. `search_learner_autocomplete_global.php`
Same approach - checks for site table and uses appropriate query.

### 3. Files Created for Diagnosis

#### `check_database_tables.php`
Diagnostic script to:
- List all tables in your database
- Find site-related tables
- Check class and learnerdetails table structure
- Search for the specific learner (8212090652085)

**Usage:** Upload to server and access via browser

#### `search_learner_global_no_site.php`
Simplified search endpoint that never uses the site table. Can be used as a backup.

## How It Works

### With Site Table
Returns full data including:
- learner_id, name, surname, id_number
- class_id, class_name
- site_id, site_name, sdp_id, sdp_name

### Without Site Table
Returns limited data:
- learner_id, name, surname, id_number
- class_id, class_name

## Testing Steps

1. **First, diagnose your database:**
   - Upload `check_database_tables.php` to server
   - Access via browser: `https://yourserver.com/check_database_tables.php`
   - Check output to see:
     - What tables exist
     - If site table exists (and under what name)
     - If learner 8212090652085 exists

2. **Test the fixed search:**
   - Upload updated `search_learner_global.php`
   - Upload updated `search_learner_autocomplete_global.php`
   - Test search for ID: 8212090652085
   - Should now work regardless of site table existence

3. **Alternative test:**
   - Upload `search_learner_global_no_site.php`
   - Test directly: `https://yourserver.com/search_learner_global_no_site.php?id_number=8212090652085`

## Possible Database Scenarios

### Scenario 1: Site table doesn't exist
- Search will work without site data
- Results won't include site_name, sdp_id, sdp_name

### Scenario 2: Site table has different name
- Check `check_database_tables.php` output
- Table might be named: `Site`, `SITE`, `sites`, `Sites`, etc.
- May need to update query to use correct table name

### Scenario 3: Site table exists but has different columns
- Check table structure in diagnostic output
- May need to adjust column names in query

## Next Steps

1. Run `check_database_tables.php` to see your actual database structure
2. Share the output so we can see:
   - What tables exist
   - What the site table is actually called (if it exists)
   - If the learner exists in the database
3. We can then adjust the queries to match your exact database schema

## Deployment

Upload these files to your server:
1. `search_learner_global.php` (updated - handles missing site table)
2. `search_learner_autocomplete_global.php` (updated - handles missing site table)
3. `check_database_tables.php` (diagnostic tool)
4. `search_learner_global_no_site.php` (backup/alternative)

## Expected Result
The search for learner ID `8212090652085` should now work, returning the learner's information even if the site table doesn't exist.
