# Debug: LogBook Section Not Showing

## Possible Causes

### 1. No Practical + Summative Assessments
The learner doesn't have any assessments with `question_type = 'Practical'` AND `assessment_type = 'Summative'`.

### 2. PHP Endpoint Not Uploaded
The `get_logbook_unit_standards.php` file isn't on the server.

### 3. Flutter Code Not Updated
The Flutter code changes haven't been applied yet.

### 4. Endpoint Returning Empty Data
The endpoint is working but returning 0 unit standards.

## Diagnostic Steps

### Step 1: Test PHP Endpoint

Run the test script:
```bash
php test_logbook_endpoint.php
```

Or test in browser:
```
https://rlms.rlms.co.za/mobile/get_logbook_unit_standards.php?learner_id=75
```

**Expected Response (if data exists):**
```json
{
  "status": "success",
  "data": [
    {
      "unit_standard_id": "123",
      "unit_standard_name": "Unit Standard Name",
      "unit_standard_number": "US123456",
      "specific_outcomes": ["Outcome 1", "Outcome 2"],
      "max_marks": 50
    }
  ]
}
```

**If empty:**
```json
{
  "status": "success",
  "data": []
}
```

### Step 2: Check Database

Run this SQL query:
```sql
-- Check for Practical + Summative assessments
SELECT 
    a.learner_id,
    a.unit_standard_id,
    us.unit_standard_name,
    us.unit_standard_number,
    a.question_type,
    a.assessment_type,
    a.specific_outcome
FROM assessments a
LEFT JOIN unit_standards us ON a.unit_standard_id = us.id
WHERE a.learner_id = '75'
  AND a.question_type = 'Practical'
  AND a.assessment_type = 'Summative'
LIMIT 10;
```

**If returns 0 rows:**
- The learner doesn't have LogBook assessments
- Try with a different learner
- Or check if the data uses different values for `question_type` or `assessment_type`

**Check what values exist:**
```sql
SELECT DISTINCT question_type, assessment_type 
FROM assessments 
WHERE learner_id = '75';
```

### Step 3: Check Flutter Logs

Look for these debug messages in Flutter console:
```
DEBUG LogBook: Response status 200
DEBUG LogBook: Response body {...}
DEBUG LogBook: Loaded X unit standards
```

**If you don't see these logs:**
- The Flutter code wasn't updated
- The `_loadLogbookUnitStandards()` method isn't being called

**If you see error:**
```
Error loading logbook unit standards: ...
```
- Check the error message
- Verify endpoint URL is correct

### Step 4: Verify Flutter Code Changes

Check if these were added to `lib/AssessorPage.dart`:

1. **State variables added?**
```dart
List<Map<String, dynamic>> _logbookUnitStandards = [];
Map<String, TextEditingController> _logbookMarksControllers = {};
bool _isLoadingLogbook = false;
```

2. **initState updated?**
```dart
@override
void initState() {
  super.initState();
  _loadExistingMarks();
  _loadLogbookUnitStandards(); // This line added?
}
```

3. **Methods added?**
- `_loadLogbookUnitStandards()`
- `_loadLogbookMarks()`
- `_saveLogbookMarks()`
- `_buildLogbookSection()`
- `_buildUnitStandardCard()`

4. **UI updated?**
```dart
// In build() method, after checklist items:
_buildLogbookSection(),
```

### Step 5: Check Files Uploaded

Verify these files exist on server:
```
https://rlms.rlms.co.za/mobile/get_logbook_unit_standards.php
https://rlms.rlms.co.za/mobile/save_logbook_marks.php
https://rlms.rlms.co.za/mobile/get_logbook_marks.php
```

## Common Issues

### Issue 1: Wrong question_type or assessment_type Values

**Symptom:** Endpoint returns empty array

**Check:**
```sql
SELECT DISTINCT question_type FROM assessments WHERE learner_id = '75';
SELECT DISTINCT assessment_type FROM assessments WHERE learner_id = '75';
```

**Solution:** Update the PHP query to match your actual values. For example, if it's "practical" (lowercase) instead of "Practical":

```php
// In get_logbook_unit_standards.php, change:
AND a.question_type = 'Practical'
// To:
AND a.question_type = 'practical'
```

### Issue 2: unit_standards Table Doesn't Exist

**Symptom:** SQL error about missing table

**Solution:** The query joins with `unit_standards` table. If it doesn't exist, modify the query to not use it:

```php
// Simplified query without unit_standards table:
$sql = "SELECT DISTINCT 
            a.unit_standard_id,
            a.unit_standard_id as unit_standard_name,
            a.unit_standard_id as unit_standard_number
        FROM assessments a
        WHERE a.learner_id = ?
          AND a.question_type = 'Practical'
          AND a.assessment_type = 'Summative'
        ORDER BY a.unit_standard_id";
```

### Issue 3: Flutter Code Not Applied

**Symptom:** No debug logs at all

**Solution:** 
1. Make sure you saved the file after making changes
2. Hot reload or restart the app
3. Check for compilation errors

### Issue 4: Section Hidden Because Empty

**Symptom:** Endpoint works but section doesn't show

**Reason:** The `_buildLogbookSection()` returns `SizedBox.shrink()` if list is empty

**Check:** Add debug print:
```dart
Widget _buildLogbookSection() {
  print('DEBUG: Building logbook section, count: ${_logbookUnitStandards.length}');
  if (_logbookUnitStandards.isEmpty) {
    return const SizedBox.shrink();
  }
  // ...
}
```

## Quick Test

To quickly test if the system works, manually check:

1. **Test endpoint in browser:**
```
https://rlms.rlms.co.za/mobile/get_logbook_unit_standards.php?learner_id=75
```

2. **If it returns data**, the PHP is working
3. **If Flutter doesn't show it**, the Flutter code needs to be updated
4. **If it returns empty**, check the database queries

## Next Steps

1. Run `test_logbook_endpoint.php` to see what the endpoint returns
2. Share the output
3. Check Flutter console for "DEBUG LogBook:" messages
4. Share those logs

This will help identify exactly where the issue is!
