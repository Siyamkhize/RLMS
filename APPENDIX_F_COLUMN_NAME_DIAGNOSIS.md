# Appendix F "Unknown Column ofoNumber" Diagnosis

## Issue Summary
User reports error "Unknown column ofoNumber in where" when saving Appendix F data.
- **Data IS saving successfully** - Records exist in database with ofoNumber=641201
- **Error message appears** despite successful save

## Database Schema ✅ CORRECT

**Tables:**
- `arpl_appendix_f_knowledge`
- `arpl_appendix_f_practical_tasks`  
- `arpl_appendix_f_workplace_observations`

**Column Name:**  `ofoNumber` (camelCase) ✅

Confirmed by:
1. `create_appendix_f_redesign_tables.sql` (July 15, 2026) - Uses `ofoNumber`
2. Existing data in database shows `ofoNumber` column
3. User's screenshot shows records with `ofoNumber=641201`

## PHP Backend Code ✅ CORRECT

**File:** `mobile/save_appendix_f_data.php`

**DELETE Queries (Lines 96, 153):**
```php
$conn->query("DELETE FROM arpl_appendix_f_knowledge WHERE learnerID = $learnerID AND ofoNumber = '$ofoNumber'");
$conn->query("DELETE FROM arpl_appendix_f_practical_tasks WHERE learnerID = $learnerID AND ofoNumber = '$ofoNumber'");
```
✅ Uses `ofoNumber` (camelCase) - CORRECT

**INSERT Queries:**
```php
INSERT INTO arpl_appendix_f_knowledge 
(learnerID, ofoNumber, question_number, question_text, candidate_score, percentage, assessor_id)
VALUES (?, ?, ?, ?, ?, ?, ?)
```
✅ Uses `ofoNumber` (camelCase) - CORRECT

## GET Endpoint ✅ CORRECT

**File:** `mobile/get_appendix_f_data.php`

**SELECT Queries:**
```php
SELECT ... FROM arpl_appendix_f_knowledge WHERE learnerID = ? AND ofoNumber = ?
SELECT ... FROM arpl_appendix_f_practical_tasks WHERE learnerID = ? AND ofoNumber = ?
```
✅ Uses `ofoNumber` (camelCase) - CORRECT

## Flutter Frontend ✅ CORRECT

**File:** `lib/ArplToolkitViewerPage.dart`

**Endpoint URL:**
```dart
final appendixFUrl = AppConfig.saveAppendixFDataUrl;
// Resolves to: https://rlms.rlms.co.za/mobile/save_appendix_f_data.php
```
✅ Calls correct endpoint

**Payload:**
```dart
{
  'learnerID': 11701,
  'ofoNumber': '641201',  // ✅ Sends ofoNumber (camelCase)
  'assessor_id': 6,
  'knowledge': [...],
  'practical': [...],
  'workplace_observations': [...]
}
```

## ⚠️ POTENTIAL ISSUE: Backup File with WRONG Column Name

**File:** `mobile/save_appendix_f_data - Copy.php` ❌ WRONG

**DELETE Queries (Lines 96, 147):**
```php
$conn->query("DELETE FROM arpl_appendix_f_knowledge WHERE learnerID = $learnerID AND ofo_number = '$ofoNumber'");
// ❌ Uses ofo_number (snake_case) - WRONG!
```

**Status:** This backup file is NOT being called by the Flutter app, but may cause confusion.

## Why Data Saves Successfully Despite Error

**Theory:** The DELETE queries run FIRST before INSERT:

1. DELETE query runs (may fail silently if column name wrong)
2. INSERT queries run (these use prepared statements and correct column names)
3. Data gets inserted ✅
4. BUT if DELETE failed, error might be logged/displayed

## Next Steps to Resolve

### 1. Check Error Logging
After user tries to save again, check server logs:
```bash
tail -f /var/log/php_errors.log
```

### 2. Test DELETE Query Directly
Run on production database:
```sql
DELETE FROM arpl_appendix_f_knowledge WHERE learnerID = 11701 AND ofoNumber = '641201' LIMIT 1;
```

If this fails, the column name in database is WRONG.
If this succeeds, the PHP code has an issue.

### 3. Verify Current Schema
```sql
SHOW COLUMNS FROM arpl_appendix_f_knowledge WHERE Field LIKE '%ofo%';
```

Should return: `ofoNumber` (not `ofo_number`)

### 4. Check if Backup File is Being Served
Possible scenarios:
- Apache/Nginx rewrite rule pointing to wrong file
- `.htaccess` redirect issue
- File caching issue
- Load balancer serving cached version

### 5. Add Explicit Error Handling (DONE)
Modified `save_appendix_f_data.php` to:
- Check DELETE query result
- Log errors explicitly  
- Throw exception if DELETE fails
- Return proper error message to frontend

## Files Modified

1. **mobile/save_appendix_f_data.php** - Added error checking for DELETE queries

## Test Data

- **Learner ID:** 11701 (Anele Cele)
- **OFO Number:** 641201 (Bricklayer)
- **Assessor ID:** 6
- **Class ID:** 797

## Verification Query

Check if data is currently in database:
```sql
SELECT id, learnerID, ofoNumber, question_number, candidate_score, created_at 
FROM arpl_appendix_f_knowledge 
WHERE learnerID = 11701 AND ofoNumber = '641201'
ORDER BY question_number;
```

## Expected Result After Fix

- ✅ No error message displayed
- ✅ Data saves successfully
- ✅ DELETE queries execute without errors
- ✅ INSERT queries execute successfully
- ✅ User sees "Changes saved successfully" message
