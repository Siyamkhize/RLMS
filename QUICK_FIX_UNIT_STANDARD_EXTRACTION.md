# Quick Fix: Unit Standard Extraction

## Problem
- POE Count always showing 0
- Marking Status always "Not Marked"
- Performance Level always "Not Assessed"

## Root Cause
The extraction logic was looking for unit standard IDs at the BEGINNING of the exercise string, but they're actually in the MIDDLE:
- "All Questions - **9964** - Apply health..." ✅
- Not: "**9964** - Apply health..." ❌

## Solution
Extract 4-5 digit numbers from ANYWHERE in the string using:
- MySQL 8.0+: `REGEXP_SUBSTR(exercise, '[0-9]{4,5}')`
- MySQL 5.7/MariaDB: Alternative SUBSTRING/LOCATE method

## Files Changed
1. `get_learners_with_poe_assigned.php` - Main API file
2. `test_temp_tables_logic.php` - Test file

## Upload & Test
```bash
# 1. Upload files to server
get_learners_with_poe_assigned.php
test_temp_tables_logic.php
test_unit_standard_extraction_fixed.php
check_server_version.php

# 2. Test
http://your-server.com/test_temp_tables_logic.php?moderator_id=77

# 3. Verify
- POE Count > 0 ✅
- Marking Status = "Marked" (if summative marks exist) ✅
- Performance Level matches average marks ✅
```

## Reset Assignments (if needed)
```sql
DELETE FROM moderator_assignments WHERE moderator_id = '77';
```

Then call the API again to recalculate with correct data.

## Expected Results
- **POE Count**: 1-10 (number of unique unit standards)
- **Marking Status**: "Marked" or "Not Marked"
- **Performance Level**: "High", "Medium", "Low", or "Not Assessed"
- **POE Completeness**: "Complete", "Partial", or "Incomplete"
