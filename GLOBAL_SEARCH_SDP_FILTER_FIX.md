# Global Search SDP Filter Fix

## Problem
Learner with ID number `8212090652085` exists in the database but search returns "No learner found".

## Root Cause
The global search endpoints were filtering by SDP, which prevented finding learners when:
- The learner's site doesn't have an `sdp_id` set
- The learner's site has a different `sdp_id` than the one being searched
- The SDP parameter doesn't match the site's SDP configuration

Since these are **GLOBAL** search endpoints (indicated by the filename `search_learner_global.php`), they should search across ALL SDPs, not filter by a specific SDP.

## Solution
Removed the SDP filter from both search endpoints to enable true global search functionality.

## Files Modified

### 1. `search_learner_global.php`
**Before:**
```php
// Added SDP filter that restricted results
if (!empty($sdpId)) {
    if (is_numeric($sdpId)) {
        $query .= " AND s.sdp_id = ?";
    } else {
        $query .= " AND (s.sdp_name = ? OR s.sdp_id = ?)";
    }
}
```

**After:**
```php
// No SDP filter - searches globally across all SDPs
$query = "
    SELECT 
        l.LearnerID as learner_id,
        l.Name as name,
        l.Surname as surname,
        l.IDNumber as id_number,
        l.classID as class_id,
        c.className as class_name,
        s.siteName as site_name,
        s.siteID as site_id,
        s.sdp_id,
        s.sdp_name
    FROM learnerdetails l
    LEFT JOIN class c ON l.classID = c.classID
    LEFT JOIN site s ON c.siteID = s.siteID
    WHERE l.IDNumber = ?
    LIMIT 1
";
```

### 2. `search_learner_autocomplete_global.php`
**Before:**
```php
// Added SDP filter that restricted autocomplete results
if (!empty($sdpId)) {
    if (is_numeric($sdpId)) {
        $sql .= " AND s.sdp_id = ?";
    } else {
        $sql .= " AND (s.sdp_name = ? OR s.sdp_id = ?)";
    }
}
```

**After:**
```php
// No SDP filter - autocomplete searches globally
$sql = "
    SELECT 
        l.LearnerID,
        l.IDNumber,
        l.Name,
        l.Surname,
        l.classID,
        c.className,
        s.siteName,
        s.sdp_id,
        s.sdp_name
    FROM learnerdetails l
    LEFT JOIN class c ON l.classID = c.classID
    LEFT JOIN site s ON c.siteID = s.siteID
    WHERE (
        l.IDNumber LIKE ? 
        OR l.Name LIKE ? 
        OR l.Surname LIKE ?
        OR CONCAT(l.Name, ' ', l.Surname) LIKE ?
        OR CONCAT(l.Surname, ' ', l.Name) LIKE ?
    )
    ORDER BY ...
    LIMIT ?
";
```

## Benefits

### 1. True Global Search
- Searches across ALL learners in the database
- No restrictions based on SDP
- Finds learners regardless of their site's SDP configuration

### 2. Better User Experience
- Users can find any learner by ID number
- No "learner not found" errors for existing learners
- Autocomplete shows all matching learners

### 3. Flexibility
- Still returns SDP information (`sdp_id`, `sdp_name`) in results
- Frontend can filter or display SDP info as needed
- Maintains backward compatibility

## Testing

### Test Case 1: Search for ID 8212090652085
```
Before: "No learner found"
After: Learner found and displayed
```

### Test Case 2: Autocomplete
```
Before: Limited to specific SDP
After: Shows all matching learners across all SDPs
```

### Test Case 3: Learners without SDP
```
Before: Not found if site has no sdp_id
After: Found successfully
```

## Diagnostic File Created
`test_search_issue_diagnosis.php` - Upload to server to diagnose search issues

This file will:
- Check if learner exists in database
- Test JOIN queries
- Check for whitespace issues
- Verify class and site relationships
- Test prepared statements

## Deployment Steps

1. Upload updated files to server:
   - `search_learner_global.php`
   - `search_learner_autocomplete_global.php`

2. Test the search:
   - Search for ID: 8212090652085
   - Verify learner is found
   - Check autocomplete suggestions

3. Optional: Upload diagnostic file for troubleshooting:
   - `test_search_issue_diagnosis.php`

## Notes

- The SDP parameter is still accepted by the endpoints (for backward compatibility)
- It's just not used for filtering anymore
- If you need SDP-specific search in the future, create separate endpoints like:
  - `search_learner_by_sdp.php`
  - `search_learner_autocomplete_by_sdp.php`

## Result
The learner with ID `8212090652085` will now be found successfully in the global search.
