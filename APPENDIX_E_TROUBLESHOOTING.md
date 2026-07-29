# Appendix E "Activities Not Loaded" - Troubleshooting Guide

## Issue
When clicking the "Appendix E" tab in ARPL Assessor Page, it shows:
```
Activities not loaded
OFO: 671101
```

## Root Cause Analysis

### Where the Error Appears
- **File:** `lib/ArplAssessorPage.dart`
- **Method:** `_buildAppendixE()`
- **Condition:** When `_appendixEActivities.isEmpty` is true

### API Call Details
1. **Endpoint:** `http://192.168.0.57:8080/assessorReport2/mobile/get_arpl_appendix_e.php`
2. **Method:** POST
3. **Parameters:**
   - `learnerID`: From `_selectedLearnerId`
   - `ofo_number`: From `_ofoNumber` (default: '671101')
   - `facilitator_id`: '1' (hardcoded)

4. **Loading Logic:**
```dart
Future<void> _loadAppendixEData() async {
  final response = await http.post(
    Uri.parse(AppConfig.getArplAppendixEUrl),
    body: {
      'learnerID': _selectedLearnerId!,
      'ofo_number': _ofoNumber ?? '671101',
      'facilitator_id': '1',
    },
  );
  
  if (data['status'] == 'success') {
    _appendixEActivities = data['activities'] ?? [];
    // ... load ratings
  }
}
```

## Possible Causes

### 1. API Returns Error
- API returns `status: 'error'` with empty activities array
- Check console for: `[ARPL-E] Error: <message>`

### 2. API Returns Success But No Activities
- API returns `status: 'success'` but activities array is empty
- Database may not have activities for OFO 671101

### 3. Network/Connection Issue
- HTTP request fails
- Check console for: `[ARPL-E] HTTP Error: <code>`

### 4. Parameters Not Set
- `_selectedLearnerId` is null
- `_ofoNumber` is null
- Check console for: `[ARPL-E] Cannot load: missing learnerID or OFO`

## Debugging Steps

### Step 1: Check Flutter Console Logs
Look for these log messages when you click Appendix E tab:
```
[ARPL-E] Loading data for learner: <ID>, OFO: <number>
[ARPL-E] Response: <JSON>
[ARPL-E] Loaded X activities from database
```

### Step 2: Test API Directly
Open in browser:
```
http://192.168.0.57:8080/assessorReport2/mobile/debug_appendix_e_full.php?learnerID=20310&ofo_number=671101
```

This comprehensive diagnostic tool will:
- ✓ Test database connection
- ✓ Check if tables exist
- ✓ Query activities directly
- ✓ Query existing ratings
- ✓ Test GET request
- ✓ Test POST request
- ✓ Show all OFO numbers in database

### Step 3: Test API with Simple Tool
```
http://192.168.0.57:8080/assessorReport2/mobile/test_arpl_apis.php
```

### Step 4: Check Database Directly
Run this SQL:
```sql
SELECT COUNT(*) as count 
FROM arplappxe_electrician_activities 
WHERE ofo_number = '671101';
```

Should return 13 activities.

## Expected API Response

### Success Response
```json
{
  "status": "success",
  "message": "Activities and ratings retrieved successfully",
  "activities": [
    {
      "activity_id": "1",
      "activity_number": 1,
      "activity_name": "Wire ways and wiring",
      "ofo_number": "671101",
      "created_at": "2026-07-08 08:44:32"
    },
    // ... 12 more activities
  ],
  "existing_ratings": {},
  "total_activities": 13,
  "rated_count": 0
}
```

### Error Response
```json
{
  "status": "error",
  "message": "Valid learnerID is required",
  "activities": [],
  "existing_ratings": []
}
```

## Quick Fixes

### Fix 1: Verify learnerID is being passed
Add debug print in ArplAssessorPage:
```dart
print('[DEBUG] Selected Learner ID: $_selectedLearnerId');
print('[DEBUG] OFO Number: $_ofoNumber');
```

### Fix 2: Add retry button
The current UI shows the error but no way to retry. Add a retry button to the error state.

### Fix 3: Show more detailed error
Instead of just "Activities not loaded", show the actual API error message.

## Testing Checklist

- [ ] Open debug tool: `debug_appendix_e_full.php`
- [ ] Verify 13 activities exist for OFO 671101
- [ ] Test GET request returns success
- [ ] Test POST request returns success
- [ ] Check Flutter console for `[ARPL-E]` logs
- [ ] Verify `_selectedLearnerId` is not null
- [ ] Verify `_ofoNumber` is '671101'
- [ ] Test with different learner IDs

## Files Involved

1. **Backend API:**
   - `/mobile/get_arpl_appendix_e.php` - Main API endpoint
   - `/mobile/debug_appendix_e_full.php` - Comprehensive diagnostic tool
   - `/mobile/test_arpl_apis.php` - Simple testing tool

2. **Flutter App:**
   - `/lib/ArplAssessorPage.dart` - Main page with tabs
   - `/lib/config.dart` - API URL configuration
   - `/lib/ArplAppendixEPage.dart` - Standalone page (not used in assessor page)

3. **Database Tables:**
   - `arplappxe_electrician_activities` - Activity definitions
   - `arplappxe_electrician_activity_ratings` - Learner ratings

## Next Steps

1. **Run the debug tool** to verify database and API are working
2. **Check Flutter console** when clicking Appendix E tab
3. **Compare logs** with expected behavior
4. **Identify the exact failure point**

---
**Created:** July 8, 2026  
**Status:** Investigating  
**Priority:** High
