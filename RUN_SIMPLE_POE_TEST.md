# Run Simple POE Query Test

## Quick Start

Run this command to test the simple query against the live server:

```bash
php test_live_poe_direct.php
```

## What This Does

1. **Connects to live server** (rlms.rlms.co.za database)
2. **Gets moderator 77's classes** (handles comma-separated IDs)
3. **Runs simple query** to get learners with POE
4. **Shows results** - should get ~1571 learners

## Expected Output

```
=== SIMPLE POE QUERY TEST (LIVE SERVER) ===
Server: rlms.rlms.co.za
Moderator ID: 77
Timestamp: 2026-02-05 10:45:00

✅ Database connected

Step 1: Getting moderator's classes...
Found 13 classes: 69, 93, 67, 68, 91, 81, 30, 97, 46, 86, 47

Step 2: Getting learners with POE...
✅ Query completed successfully

=== RESULTS ===

Total learners with POE: 1571

✅ SUCCESS! Got 1571 learners (expected ~1571)

First 10 learners:
  1. Surname, Name (ID: 123, Class: Class Name)
  ...

=== TEST COMPLETE ===
```

## What's Different?

### OLD (Complex Query)
- ❌ Timeout after 60 seconds
- ❌ Complex stratification calculations
- ❌ Temporary tables
- ❌ Sampling logic
- ❌ Multiple nested queries

### NEW (Simple Query)
- ✅ Completes in 2-5 seconds
- ✅ Simple JOIN query
- ✅ No temporary tables
- ✅ No complex calculations
- ✅ Just gets learners with POE

## The Query

```sql
SELECT 
    l.LearnerID,
    l.Name,
    l.Surname,
    l.classID,
    COALESCE(c.className, 'Unknown') as className
FROM poe p
INNER JOIN learnerdetails l ON p.learnerID = l.LearnerID
LEFT JOIN class c ON l.classID = c.classID
WHERE p.filePath IS NOT NULL 
  AND p.filePath != ''
  AND l.classID IN (69, 93, 67, 68, 91, 81, 30, 97, 46, 86, 47)
GROUP BY l.LearnerID, l.Name, l.Surname, l.classID, c.className
ORDER BY l.Surname, l.Name
LIMIT 2000
```

## Next Steps After Testing

If the test is successful:

1. **Upload API file** to server:
   - File: `get_learners_with_poe_simple.php`
   - Location: `/mobile/get_learners_with_poe_simple.php`

2. **Update Flutter app** to use new endpoint:
   - Change URL from: `get_learners_with_poe_assigned.php`
   - To: `get_learners_with_poe_simple.php`

3. **Test in app** - should load quickly without timeout

## Files

- `test_live_poe_direct.php` - Test script (run this first)
- `get_learners_with_poe_simple.php` - API endpoint (upload after test succeeds)
- `connection_online.php` - Live server database connection
