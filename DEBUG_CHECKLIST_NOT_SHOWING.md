# Debug Guide: Pothole Checklist Not Showing

## Problem
Neither scanned documents nor system-generated checklists are showing in the POE tab.

## Diagnostic Steps

### Step 1: Verify Database Has Data

Run these SQL queries to check if data exists:

```sql
-- Check for scanned documents
SELECT id, learner_id, assessor_id, document_path, assessment_date, uploaded_at 
FROM pothole_checklist_scanned_documents 
ORDER BY uploaded_at DESC 
LIMIT 10;

-- Check for system-generated checklists
SELECT pc.id, pc.learner_id, pc.assessor_id, pc.assessment_date, 
       COUNT(pci.id) as item_count
FROM pothole_checklists pc
LEFT JOIN pothole_checklist_items pci ON pc.id = pci.checklist_id
GROUP BY pc.id
ORDER BY pc.assessment_date DESC
LIMIT 10;
```

**Expected Result:** You should see at least one row in one of these tables.

### Step 2: Test PHP Endpoint Directly

Run the test script:
```bash
php test_view_endpoint_simple.php
```

Or test via browser/curl:
```
https://rlms.rlms.co.za/mobile/php/view_pothole_checklists.php?learner_id=YOUR_LEARNER_ID
```

**Expected Response:**
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "type": "scanned",
    "learner_id": "TEST123",
    "document_path": "/path/to/file.pdf",
    ...
  }
}
```

**If you get an error:**
- Check the error message
- Verify database connection in `php/config.php`
- Check table names match exactly

### Step 3: Check Flutter App Logs

Look for these debug messages in the Flutter console:

```
DEBUG Pothole: Checking for learner XXX, date YYYY-MM-DD
DEBUG Pothole: Checking server at https://...
DEBUG Pothole: Response status 200
DEBUG Pothole: Response body {...}
DEBUG Pothole: Found checklist on server, type=scanned
```

**Common Issues:**

1. **URL Construction Error**
   ```
   DEBUG Pothole: Checking server at https://rlms.rlms.co.za/mobile/php/view_pothole_checklists.php?learner_id=XXX
   ```
   - Verify the URL is correct
   - Check `lib/config.dart` baseUrl setting

2. **404 Error**
   ```
   DEBUG Pothole: Server returned status 404
   ```
   - File path is wrong
   - Check if `php/view_pothole_checklists.php` exists on server

3. **Connection Timeout**
   ```
   DEBUG Pothole: Error checking server: TimeoutException
   ```
   - Server is slow or unreachable
   - Check internet connection
   - Increase timeout in code

4. **No Data Found**
   ```
   DEBUG Pothole: No checklist on server - No checklist found for the specified parameters
   ```
   - Learner ID doesn't match database
   - Check database has data for this learner

### Step 4: Verify URL Path

The Flutter app constructs the URL as:
```dart
'${AppConfig.baseUrl}/php/view_pothole_checklists.php?learner_id=${widget.learnerId}'
```

With current config, this becomes:
```
https://rlms.rlms.co.za/mobile/php/view_pothole_checklists.php?learner_id=XXX
```

**Verify:**
1. File exists at this exact path on server
2. File has correct permissions (readable by web server)
3. PHP file has no syntax errors

### Step 5: Check Data Structure

The endpoint returns:
```json
{
  "status": "success",
  "data": {
    "type": "scanned",  // or "system"
    "learner_id": "...",
    "document_path": "...",  // for scanned
    "checklist_items": {...}  // for system
  }
}
```

The Flutter app expects:
- `data['type']` to be either "scanned" or "system"
- For scanned: `data['document_path']` must exist
- For system: `data['checklist_items']` must exist

## Quick Fixes

### Fix 1: Verify Learner ID Format
Check if the learner ID in the app matches the database:
```dart
print('DEBUG: Looking for learner_id=${widget.learnerId}');
```

### Fix 2: Test with Known Data
Temporarily hardcode a learner ID that you know has data:
```dart
final url = '${AppConfig.baseUrl}/php/view_pothole_checklists.php?learner_id=KNOWN_LEARNER_ID';
```

### Fix 3: Check Server Logs
Look at server error logs:
```bash
tail -f /var/log/apache2/error.log
# or
tail -f /var/log/nginx/error.log
```

### Fix 4: Add More Debug Output
Temporarily add to `php/view_pothole_checklists.php`:
```php
error_log("Checking for learner_id: " . $learner_id);
error_log("Scanned query: " . $scanned_sql);
error_log("Scanned result count: " . $scanned_result->num_rows);
```

## Common Root Causes

1. **Wrong File Path**
   - File is at `php/view_pothole_checklists.php` but URL expects different path
   - Solution: Move file or update URL

2. **Database Connection Failed**
   - Check `php/config.php` credentials
   - Test database connection separately

3. **Table Names Don't Match**
   - Code expects `pothole_checklist_scanned_documents`
   - Database has different table name
   - Solution: Update table names to match

4. **No Data in Database**
   - Tables exist but are empty
   - Solution: Add test data or upload a checklist

5. **CORS Issues**
   - Browser blocks request
   - Solution: Check CORS headers in PHP file

6. **Learner ID Mismatch**
   - App sends "L001" but database has "LEARNER001"
   - Solution: Standardize ID format

## Testing Checklist

- [ ] Database tables exist and have data
- [ ] PHP endpoint accessible via browser
- [ ] PHP endpoint returns valid JSON
- [ ] Flutter app constructs correct URL
- [ ] Flutter app receives 200 response
- [ ] Response contains expected data structure
- [ ] Data type is correctly identified
- [ ] Navigation to view page works

## Next Steps

1. Run Step 1 (database check) first
2. If data exists, run Step 2 (endpoint test)
3. If endpoint works, check Step 3 (Flutter logs)
4. Use debug output to identify exact failure point
5. Apply appropriate fix from Quick Fixes section

## Need More Help?

Share these details:
1. Output from database queries (Step 1)
2. Output from endpoint test (Step 2)
3. Flutter console logs (Step 3)
4. Any error messages from server logs
