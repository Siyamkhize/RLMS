# Class Filtering - Exact Code Change

## The Bug
The main query in `getAvailableLearnersByStrata()` was NOT using the filtered `temp_poe_learners` table, causing it to return ALL learners with POE instead of only those from the moderator's allocated classes.

## Location
**File:** `get_learners_with_poe_assigned.php`  
**Function:** `getAvailableLearnersByStrata()`  
**Line:** ~370

## The Fix

### BEFORE (Buggy Code):
```php
// Main query with optimized joins - LIMIT to 100 learners max
$sql = "SELECT DISTINCT 
            l.LearnerID,
            l.Name,
            l.Surname,
            l.IDNumber,
            l.Email,
            l.PhoneNumber,
            l.classID,
            COALESCE(c.className, 'Unknown Class') as className,
            COALESCE(c.siteID, 'Unknown') as siteID,
            COALESCE(tc.total_unit_standards, 0) as poe_count,
            MAX(p.submitted_at) as last_poe_submission,
            CASE 
                WHEN tm.unit_standard_count > 0 THEN 'Marked' 
                ELSE 'Not Marked' 
            END as marking_status,
            CASE 
                WHEN tm.avg_marks IS NULL THEN 'Not Assessed'
                WHEN tm.avg_marks >= 70 THEN 'High'
                WHEN tm.avg_marks >= 50 THEN 'Medium'
                WHEN tm.avg_marks >= 0 THEN 'Low'
                ELSE 'Not Assessed'
            END as performance_level,
            CASE 
                WHEN COALESCE(tc.total_unit_standards, 0) >= 10 THEN 'Complete'
                WHEN COALESCE(tc.total_unit_standards, 0) >= 1 THEN 'Partial'
                ELSE 'Incomplete'
            END as poe_completeness
        FROM learnerdetails l                          -- ❌ WRONG! Starts from all learners
        INNER JOIN poe p ON l.LearnerID = p.learnerID
        LEFT JOIN class c ON l.classID = c.classID
        LEFT JOIN temp_learner_marks tm ON l.LearnerID = tm.learnerID
        LEFT JOIN temp_learner_coverage tc ON l.LearnerID = tc.learnerID
        WHERE p.filePath IS NOT NULL AND p.filePath != ''
        AND l.LearnerID NOT IN (
            SELECT learner_id FROM moderator_assignments
        )
        GROUP BY l.LearnerID, l.Name, l.Surname, l.IDNumber, l.Email, 
                 l.PhoneNumber, l.classID, c.className, c.siteID, 
                 tm.unit_standard_count, tm.avg_marks, tc.total_unit_standards
        ORDER BY l.classID, l.LearnerID DESC
        LIMIT 100";
```

**Problem:** Query starts from `learnerdetails` table, which contains ALL learners. The filtered `temp_poe_learners` table is never used!

### AFTER (Fixed Code):
```php
// Main query with optimized joins - LIMIT to 100 learners max
// CRITICAL: Use temp_poe_learners to ensure only moderator's class learners are included
$sql = "SELECT DISTINCT 
            l.LearnerID,
            l.Name,
            l.Surname,
            l.IDNumber,
            l.Email,
            l.PhoneNumber,
            l.classID,
            COALESCE(c.className, 'Unknown Class') as className,
            COALESCE(c.siteID, 'Unknown') as siteID,
            COALESCE(tc.total_unit_standards, 0) as poe_count,
            MAX(p.submitted_at) as last_poe_submission,
            CASE 
                WHEN tm.unit_standard_count > 0 THEN 'Marked' 
                ELSE 'Not Marked' 
            END as marking_status,
            CASE 
                WHEN tm.avg_marks IS NULL THEN 'Not Assessed'
                WHEN tm.avg_marks >= 70 THEN 'High'
                WHEN tm.avg_marks >= 50 THEN 'Medium'
                WHEN tm.avg_marks >= 0 THEN 'Low'
                ELSE 'Not Assessed'
            END as performance_level,
            CASE 
                WHEN COALESCE(tc.total_unit_standards, 0) >= 10 THEN 'Complete'
                WHEN COALESCE(tc.total_unit_standards, 0) >= 1 THEN 'Partial'
                ELSE 'Incomplete'
            END as poe_completeness
        FROM temp_poe_learners tpl                     -- ✅ CORRECT! Starts from filtered table
        INNER JOIN learnerdetails l ON tpl.learnerID = l.LearnerID
        INNER JOIN poe p ON l.LearnerID = p.learnerID
        LEFT JOIN class c ON l.classID = c.classID
        LEFT JOIN temp_learner_marks tm ON l.LearnerID = tm.learnerID
        LEFT JOIN temp_learner_coverage tc ON l.LearnerID = tc.learnerID
        WHERE p.filePath IS NOT NULL AND p.filePath != ''
        AND l.LearnerID NOT IN (
            SELECT learner_id FROM moderator_assignments
        )
        GROUP BY l.LearnerID, l.Name, l.Surname, l.IDNumber, l.Email, 
                 l.PhoneNumber, l.classID, c.className, c.siteID, 
                 tm.unit_standard_count, tm.avg_marks, tc.total_unit_standards
        ORDER BY l.classID, l.LearnerID DESC
        LIMIT 100";
```

**Solution:** Query now starts from `temp_poe_learners` which contains ONLY learners from the moderator's allocated classes!

## Additional Change: Cleanup

### BEFORE:
```php
// Cleanup temp tables
$mysqli->query("DROP TEMPORARY TABLE IF EXISTS temp_learner_marks");
$mysqli->query("DROP TEMPORARY TABLE IF EXISTS temp_learner_coverage");
```

### AFTER:
```php
// Cleanup temp tables
$mysqli->query("DROP TEMPORARY TABLE IF EXISTS temp_poe_learners");
$mysqli->query("DROP TEMPORARY TABLE IF EXISTS temp_learner_marks");
$mysqli->query("DROP TEMPORARY TABLE IF EXISTS temp_learner_coverage");
```

Added cleanup for `temp_poe_learners` table.

## Key Changes Summary

1. **Changed FROM clause:** `FROM learnerdetails l` → `FROM temp_poe_learners tpl`
2. **Added JOIN:** `INNER JOIN learnerdetails l ON tpl.learnerID = l.LearnerID`
3. **Added cleanup:** Drop `temp_poe_learners` table after use

## Why This Works

The `temp_poe_learners` table is created earlier in the function with this query:

```php
INSERT INTO temp_poe_learners
SELECT DISTINCT p.learnerID 
FROM poe p
INNER JOIN learnerdetails l ON p.learnerID = l.LearnerID
WHERE p.filePath IS NOT NULL AND p.filePath != ''
AND l.classID IN (?)  -- ✅ Filtered by moderator's classes!
```

By starting the main query from this temp table, we ensure that ONLY learners from the moderator's allocated classes are included in the sampling.

## Impact

### Before:
- Query returned ALL learners with POE (entire database)
- Class filter was completely ignored
- Moderators saw learners they shouldn't have access to

### After:
- Query returns ONLY learners from moderator's allocated classes
- Class filter works correctly
- Proper scope control and security

## Testing

Test with Moderator 77 who has Class A (ID: 74):

```bash
# Should return only learners with classID = 74
curl "https://rlms.rlms.co.za/get_learners_with_poe_assigned.php?moderator_id=77"
```

Verify in response:
```json
{
  "data": {
    "learners": [
      {
        "classID": "74",  // ✅ All should be 74
        "className": "Class A",
        ...
      }
    ]
  }
}
```
