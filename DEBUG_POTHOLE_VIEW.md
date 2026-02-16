# Debug Guide: Pothole Checklist Not Showing

## Problem
Filled pothole checklists are not displaying in view mode when reopening the form.

## Debugging Steps

### Step 1: Check if Data Exists in Database

Run this SQL query in phpMyAdmin or MySQL:

```sql
SELECT * FROM pothole_checklists 
WHERE learner_id = 'YOUR_LEARNER_ID' 
ORDER BY created_at DESC 
LIMIT 5;
```

**Expected Result:**
- Should show rows with the learner's data
- Check the `assessment_date` column format (should be YYYY-MM-DD)
- Check the `checklist_items` column (should be JSON)

**If NO rows found:**
- The save endpoint isn't working
- Check if `save_pothole_checklist.php` exists on server
- Check PHP error logs

### Step 2: Test the View Endpoint Directly

#### Option A: Browser Test
Open this URL (replace with your values):
```
http://your-server.com/php/view_pothole_checklists.php?learner_id=L123&assessor_id=A456&assessment_date=2025-11-05
```

#### Option B: Use Test Script
1. Edit `test_view_checklist.php` with your test values
2. Run: `php test_view_checklist.php`
3. OR open in browser: `http://localhost/test_view_checklist.php`

**Expected Response (Success):**
```json
{
  "status": "success",
  "data": {
    "learner_name": "John Doe",
    "checklist_items": { ... }
  }
}
```

**Expected Response (Not Found):**
```json
{
  "status": "error",
  "message": "No checklist found for the specified parameters"
}
```

### Step 3: Check Flutter App Logs

After rebuilding the app with debug logging:

1. Open Flutter console/terminal
2. Open a learner's pothole checklist
3. Look for DEBUG messages:

```
DEBUG: Loading checklist from: http://...
DEBUG: Response status: 200
DEBUG: Response body: {"status":"success",...}
DEBUG: Parsed data status: success
DEBUG: Checklist found! Loading data...
DEBUG: Loading 5 sections
DEBUG: Checklist loaded successfully in view mode
```

**Common Issues:**

#### Issue 1: "Cannot load checklist - missing learner_id or facilitator_id"
- The learner or facilitator ID is not being passed to the page
- Check how you're navigating to PotholeChecklistPage

#### Issue 2: HTTP error - status code: 404
- The PHP file doesn't exist on server
- Check file path: `php/view_pothole_checklists.php`

#### Issue 3: HTTP error - status code: 500
- PHP error in the endpoint
- Check PHP error logs on server

#### Issue 4: "No checklist found"
- Data doesn't exist in database for this learner/assessor/date
- Check the date being used (today's date by default)
- Verify learner_id and assessor_id match exactly

### Step 4: Verify Date Format

The app uses today's date by default. If the checklist was filled on a different date:

**Check what date is being used:**
```dart
print('DEBUG: Using date: ${_date.toIso8601String().split('T').first}');
```

**Check database:**
```sql
SELECT learner_id, assessor_id, assessment_date 
FROM pothole_checklists 
WHERE learner_id = 'YOUR_LEARNER_ID';
```

Dates must match EXACTLY (YYYY-MM-DD format).

### Step 5: Check Network Connectivity

If testing on a real device:
- Ensure device can reach your server
- Check if `AppConfig.baseUrl` is correct
- Try accessing the URL directly from device browser

### Step 6: Verify Table Structure

Run this SQL to check your table structure:

```sql
DESCRIBE pothole_checklists;
```

**Required columns:**
- id
- learner_id
- learner_name
- learner_id_number
- assessor_id
- assessor_name
- assessor_reg_number
- venue
- assessment_date
- learner_signature
- assessor_signature
- checklist_items (TEXT or JSON type)
- created_at
- updated_at

If missing columns, run: `create_pothole_checklist_table.sql`

## Quick Fixes

### Fix 1: Clear and Rebuild
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### Fix 2: Check PHP File Permissions
```bash
chmod 644 php/view_pothole_checklists.php
```

### Fix 3: Test with Known Data

Create a test record directly in database:

```sql
INSERT INTO pothole_checklists 
(learner_id, learner_name, assessor_id, assessor_name, venue, assessment_date, checklist_items)
VALUES 
('TEST123', 'Test Learner', 'ASSESS001', 'Test Assessor', 'Test Venue', '2025-11-05', 
'[{"section":"PRE – OPERATIONAL SAFETY","label":"Wears appropriate PPE","value":true,"notes":"Test"}]');
```

Then try to view it with:
```
http://your-server.com/php/view_pothole_checklists.php?learner_id=TEST123&assessor_id=ASSESS001&assessment_date=2025-11-05
```

## Still Not Working?

Share the following information:

1. **Database query result** (Step 1)
2. **Endpoint test result** (Step 2)
3. **Flutter console logs** (Step 3)
4. **PHP error logs** from server

This will help identify the exact issue!
