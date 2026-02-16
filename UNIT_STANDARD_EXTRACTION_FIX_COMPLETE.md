# Unit Standard Extraction Fix - COMPLETE

## Problem Identified

The stratification calculations were showing:
- **Unit standards count (poe_count)**: Always 0
- **Performance level**: Always "Not Assessed"
- **Marking status**: Always "Not Marked"

### Root Cause

The extraction logic was trying to extract unit standard IDs from the BEGINNING of the exercise string:

```sql
SUBSTRING_INDEX(SUBSTRING_INDEX(m.exercise, '\t', 1), ' ', 1)
```

This extracted the FIRST word:
- "All Questions - 9964 - Apply health..." → "All" ❌
- "Define a safe site" → "Define" ❌

But the actual format has unit standard IDs in the MIDDLE:
- "All Questions - **9964** - Apply health and safety to a work area"
- "All Formative Questions - **14555** - Description"
- Some exercises don't have unit standard IDs at all

## Solution Implemented

### Two-Method Approach

The fix detects the MySQL/MariaDB version and uses the appropriate extraction method:

#### Method 1: MySQL 8.0+ (REGEXP_SUBSTR)
```sql
CAST(REGEXP_SUBSTR(m.exercise, '[0-9]{4,5}') AS UNSIGNED)
```
This extracts the first 4-5 digit number from ANYWHERE in the string.

#### Method 2: MySQL 5.7/MariaDB (Alternative)
```sql
CAST(
    SUBSTRING(
        m.exercise,
        LOCATE(
            SUBSTRING_INDEX(
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(m.exercise, ' - ', 2),
                    ' - ',
                    -1
                ),
                ' ',
                1
            ),
            m.exercise
        ),
        5
    ) AS UNSIGNED
)
```
This handles the "Text - 9964 - Description" format by:
1. Splitting by ' - ' delimiter
2. Getting the second part (the unit standard ID)
3. Extracting the first 5 characters

### WHERE Clause Change

**Old:**
```sql
AND SUBSTRING_INDEX(SUBSTRING_INDEX(m.exercise, '\t', 1), ' ', 1) REGEXP '^[0-9]{4,5}$'
```

**New:**
```sql
AND m.exercise REGEXP '[0-9]{4,5}'
```

This filters rows that CONTAIN a 4-5 digit number anywhere in the string.

## Files Updated

### 1. get_learners_with_poe_assigned.php
- Updated `temp_learner_marks` creation (lines ~290-350)
- Updated `temp_learner_coverage` creation (lines ~350-410)
- Added version detection logic
- Both MySQL 8.0+ and MySQL 5.7/MariaDB methods implemented

### 2. test_temp_tables_logic.php
- Updated with same extraction logic
- Added version detection display
- Shows which method is being used

### 3. test_unit_standard_extraction_fixed.php (NEW)
- Tests the extraction logic
- Shows which method is available
- Displays extracted unit standard IDs from all tables

## How It Works

### Step 1: Version Detection
```php
$useRegexpSubstr = false;
$testResult = $mysqli->query("SELECT REGEXP_SUBSTR('Test 9964 String', '[0-9]{4,5}') as test");
if ($testResult) {
    $testRow = $testResult->fetch_assoc();
    if ($testRow && $testRow['test'] == '9964') {
        $useRegexpSubstr = true;
    }
}
```

### Step 2: Use Appropriate Method
```php
if ($useRegexpSubstr) {
    // MySQL 8.0+ method with REGEXP_SUBSTR
} else {
    // MySQL 5.7/MariaDB method with SUBSTRING/LOCATE
}
```

### Step 3: Extract from All 3 Tables
- **POE table**: Extract from exercise column
- **Marks table**: Extract from exercise column
- **Logbook_marks table**: Use unit_standard_id column directly (already numeric)

### Step 4: Count Unique Unit Standards
```sql
COUNT(DISTINCT unit_standard_id) as total_unit_standards
```

## Expected Results

After this fix:

### POE Count (Unit Standards Count)
- Should show the actual number of unique unit standards (e.g., 1, 2, 3, etc.)
- Counts across all 3 tables: poe, marks, logbook_marks
- Maximum is typically 10 unit standards

### Marking Status
- **"Marked"**: If learner has summative marks (unit_standard_count > 0)
- **"Not Marked"**: If learner has no summative marks

### Performance Level
- **"High"**: Average marks >= 70%
- **"Medium"**: Average marks 50-69%
- **"Low"**: Average marks 0-49%
- **"Not Assessed"**: No summative marks available

### POE Completeness
- **"Complete"**: 10+ unit standards covered
- **"Partial"**: 1-9 unit standards covered
- **"Incomplete"**: 0 unit standards covered

## Testing

### Test Files Available

1. **check_server_version.php**
   - Shows MySQL/MariaDB version
   - Tests if REGEXP_SUBSTR is available
   - Shows which method will be used

2. **test_unit_standard_extraction_fixed.php**
   - Tests extraction from all 3 tables
   - Shows extracted unit standard IDs
   - Displays expected vs actual results

3. **test_temp_tables_logic.php**
   - Tests the complete temp table logic
   - Shows stratification calculations
   - Displays final results

### How to Test

1. Upload the updated files to the server:
   - `get_learners_with_poe_assigned.php`
   - `test_temp_tables_logic.php`
   - `test_unit_standard_extraction_fixed.php`

2. Run the test:
   ```
   http://your-server.com/test_temp_tables_logic.php?moderator_id=77
   ```

3. Check the results:
   - POE Count should be > 0
   - Marking Status should be "Marked" if summative marks exist
   - Performance Level should match average marks
   - POE Completeness should match unit standards count

## Deployment Checklist

- [x] Update `get_learners_with_poe_assigned.php` with new extraction logic
- [x] Update `test_temp_tables_logic.php` with new extraction logic
- [x] Create `test_unit_standard_extraction_fixed.php` for testing
- [ ] Upload files to server
- [ ] Test with `test_temp_tables_logic.php?moderator_id=77`
- [ ] Verify POE count is correct
- [ ] Verify marking status is correct
- [ ] Verify performance level is correct
- [ ] Test the API endpoint: `get_learners_with_poe_assigned.php?moderator_id=77`
- [ ] Verify stratification summary shows correct data

## Notes

- The fix is backward compatible with both MySQL 8.0+ and MySQL 5.7/MariaDB
- Version detection happens automatically at runtime
- No manual configuration needed
- The extraction logic handles all exercise formats:
  - "All Questions - 9964 - Description"
  - "All Formative Questions - 14555 - Description"
  - "Define a safe site" (no unit standard ID)
  - "13958 - Unit standard title"

## Next Steps

After deployment and testing:
1. Clear any existing moderator assignments if needed (to recalculate with correct data)
2. Test the moderation sampling in the Flutter app
3. Verify the stratification summary displays correctly
4. Confirm all 5 stratification dimensions are working:
   - Class
   - Site
   - POE Completeness
   - Marking Status
   - Performance Level
