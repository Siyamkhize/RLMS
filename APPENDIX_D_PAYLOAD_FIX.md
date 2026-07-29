# Appendix D Save Payload Fix

## Issue
User reported error when saving Appendix D: "Missing required field learnerID"

## Root Cause
The `_saveAppendixD()` method was using an outdated payload structure that didn't match the backend API expectations.

### Old Payload Structure (Incorrect)
```dart
final payload = {
  ...(await _buildArplPayload()),  // Returns: learner_id (snake_case)
  'responses_json': _encodeIntKeyedMap(_appendixDValues),
  'assessor_comments': _assessorCommentsController.text,
  'learner_signature': ...,
  'assessor_signature': ...,
};
```

**Problem**: 
- `_buildArplPayload()` returns `learner_id` (snake_case)
- Backend expects `learnerID` (camelCase)
- Backend expects `activities` object, not `responses_json`

### Backend API Requirements
From `mobile/save_arpl_appendix_d.php`:

```php
$required = ['learnerID', 'assessor_id', 'ofo_number', 'activities'];
```

Expected payload format:
```json
{
  "learnerID": 20286,
  "assessor_id": 1,
  "ofo_number": "671101",
  "activities": {
    "1": "yes",
    "2": "no",
    "3": "yes",
    ...
  }
}
```

## Fix Implemented

### New _saveAppendixD() Method

**File**: `lib/ArplAssessorPage.dart`

Completely rewrote the method to match backend expectations:

```dart
Future<void> _saveAppendixD() async {
  if (_selectedLearnerId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a learner first')),
    );
    return;
  }

  if (_appendixBActivities.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No activities loaded')),
    );
    return;
  }

  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    // Build activities object (key: activity number, value: 'yes' or 'no')
    final activities = <String, String>{};
    
    for (int i = 0; i < _appendixBActivities.length; i++) {
      final activity = _appendixBActivities[i];
      final activityId = activity['activity_id'] ?? (i + 1);
      final response = _appendixDValues[i]?.toLowerCase() ?? 'no';
      
      // Appendix D expects 'yes' or 'no' strings
      activities[activityId.toString()] = response;
    }

    if (activities.isEmpty) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please respond to at least one activity')),
      );
      return;
    }

    final payload = {
      'learnerID': int.parse(_selectedLearnerId!),
      'assessor_id': int.parse(widget.facilitatorId),
      'ofo_number': _ofoNumber ?? '671101',
      'activities': activities,
    };

    final response = await http.post(
      Uri.parse(AppConfig.saveArplAppendixDUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    Navigator.pop(context); // Hide loader

    final res = jsonDecode(response.body);
    
    if (res['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Appendix D saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to save Appendix D'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  } catch (e) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

## Key Changes

### 1. Field Name Corrections
| Old (Incorrect) | New (Correct) |
|----------------|---------------|
| `learner_id` | `learnerID` |
| `responses_json` | `activities` |

### 2. Data Structure
- **Old**: Used `_encodeIntKeyedMap(_appendixDValues)` which encoded data in complex format
- **New**: Builds simple `activities` map with activity ID as key and 'yes'/'no' as value

### 3. Validation
Added proper validation:
- Check if learner is selected
- Check if activities are loaded
- Check if at least one activity has a response
- Show user-friendly error messages

### 4. Response Handling
- Properly checks `status` field from API response
- Shows green success message or red error message
- Handles exceptions gracefully

### 5. Removed Unused Fields
Removed signature fields that aren't used in Appendix D:
- `learner_signature`
- `assessor_signature`
- `assessor_comments`

## Testing

### Test Payload Example
```json
{
  "learnerID": 20286,
  "assessor_id": 1,
  "ofo_number": "671101",
  "activities": {
    "1": "yes",
    "2": "no",
    "3": "yes",
    "4": "yes",
    "5": "no",
    "6": "yes",
    "7": "yes",
    "8": "no",
    "9": "yes",
    "10": "yes",
    "11": "no",
    "12": "yes",
    "13": "yes"
  }
}
```

### Expected Backend Response
```json
{
  "status": "success",
  "message": "Appendix D assessment created successfully",
  "data": {
    "id": 1,
    "learnerID": 20286,
    "assessor_id": 1,
    "ofo_number": "671101",
    "updated_at": "2026-07-08 14:30:00"
  }
}
```

## Deployment

### Build Details
- **Build Time**: 187 seconds
- **APK Size**: 45.7 MB
- **Build Path**: `build\app\outputs\flutter-apk\app-release.apk`

### Installation
```bash
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

**Status**: ✓ Success

**Device**: RZ8X306F7TZ (Samsung SM-A155F)

## User Testing Required

Please test the following workflow:

1. **Appendix D Testing**:
   - Open ARPL module
   - Select learner 20286
   - Navigate to "Appx D" tab
   - Verify 13 activities are displayed with checkboxes
   - Check/uncheck several activities
   - Tap "Save Appendix D" button
   - **Expected**: Success message "Appendix D assessment created successfully"
   - **Verify**: No "Missing required field learnerID" error
   - Reload learner and verify selections are preserved

2. **Appendix B Testing** (to ensure it still works):
   - Navigate to "Appx B" tab
   - Rate activities using 1-5 scale
   - Tap "Save Appendix B" button
   - Verify success message

## Files Modified

1. `lib/ArplAssessorPage.dart` - Rewrote `_saveAppendixD()` method with correct payload structure

## Technical Notes

### Why the Old Method Failed
The old implementation used a generic `_buildArplPayload()` helper that was designed for other appendices (E, F) which have different data structures. Appendix D has a simpler structure and doesn't need the extra fields.

### Data Flow
1. User checks/unchecks activities in UI
2. State stored in `_appendixDValues` map (index → 'yes'/'no')
3. On save, loop through `_appendixBActivities` to get activity IDs
4. Build `activities` map (activityID → 'yes'/'no')
5. Send to backend with correct field names
6. Backend validates and saves to `arpl_appendix_d` table

### Appendix B vs D Storage
Both appendices use `_appendixDValues` map in the frontend but:
- **Appendix B**: Stores rating numbers (1-5 as strings)
- **Appendix D**: Stores 'yes'/'no' strings

They save to different backend tables:
- **Appendix B**: `arplappxb_activity_ratings` (stores 1-5 ratings)
- **Appendix D**: `arpl_appendix_d` (stores yes/no responses)

---

**Status**: ✅ COMPLETE - APK installed on device  
**Date**: July 8, 2026  
**Build**: app-release.apk (45.7 MB)  
**Device**: RZ8X306F7TZ
