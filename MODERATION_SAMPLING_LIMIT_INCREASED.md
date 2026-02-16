# Moderation Sampling - Simple Query Solution

## Summary

Created a simple, non-complex query solution to get learners with POE for moderator 77, avoiding the timeout issues with the complex stratification query.

## Problem

The complex query in `get_learners_with_poe_assigned.php` was timing out after 60 seconds on the live server when trying to:
- Calculate stratification
- Perform sampling
- Use temporary tables
- Process 1571 learners with complex joins

## Solution

Created `test_live_poe_direct.php` with a simple approach:

1. **Get moderator's classes** - Handles comma-separated class IDs
2. **Simple query** - Just get learners with POE, no complex calculations
3. **Fast execution** - Should complete in seconds instead of timing out

## Files

### Test File (Local Testing)
- `test_live_poe_direct.php` - Complete test script that connects to LIVE server

### API File (For Deployment)
- `get_learners_with_poe_simple.php` - Simple API endpoint ready to upload to server

### Database Connection
- `connection_online.php` - Live server database credentials

## How to Test

Run the test file locally to verify it works:

```bash
php test_live_poe_direct.php
```

Expected output:
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

## Next Steps

1. **Test locally**: Run `php test_live_poe_direct.php`
2. **If successful**: Upload `get_learners_with_poe_simple.php` to server
3. **Update Flutter app**: Point to new endpoint `/mobile/get_learners_with_poe_simple.php`

## Query Details

The simple query:
- Joins `poe` table with `learnerdetails` and `class`
- Filters by moderator's classes
- Only includes learners with POE files
- Groups by learner to avoid duplicates
- Orders by surname, name
- Limits to 2000 results

No temporary tables, no stratification calculations, no sampling logic - just a straightforward query that should execute quickly.

## Changes Made

1. Updated `test_live_poe_direct.php` to use `connection_online.php` for live server testing
2. Kept the simple query approach without complex calculations
3. Ready to test against live database

## Expected Performance

- **Old complex query**: 60+ seconds (timeout)
- **New simple query**: 2-5 seconds (estimated)
