# ARPL Assessor "Unknown Class" Bug Fix

## Date: July 20, 2026

## Issue
ARPL assessors were seeing "Unknown Class" and "0 learners" in the Learner Clocking tab even when classes existed in the database.

## Root Cause
**Key Name Mismatch Between PHP API and Flutter Code**

The `get_classes.php` API returns data with these keys (from SQL column names):
- `classID` (lowercase 'c')
- `className` (lowercase 'c')
- `numberOfLearners` (camelCase)

But the Flutter code in `arpl_assessor_clocking_page.dart` was looking for:
- `ClassID` (uppercase 'C') 
- `ClassName` (uppercase 'C')
- `learner_count` (snake_case)

## The Fix

### File: `lib/arpl_assessor_clocking_page.dart`
**Lines 293-297**

Changed from:
```dart
final classData = _classes[index];
final className = classData['ClassName'] ?? 'Unknown Class';  // ❌ Wrong key
final classID = classData['ClassID']?.toString() ?? '';       // ❌ Wrong key
final learnerCount = classData['learner_count'] ?? 0;          // ❌ Wrong key
```

Changed to:
```dart
final classData = _classes[index];
final className = classData['className'] ?? 'Unknown Class';  // ✅ Correct key
final classID = classData['classID']?.toString() ?? '';       // ✅ Correct key
final learnerCount = classData['numberOfLearners'] ?? 0;      // ✅ Correct key
```

## Why This Happened
The PHP MySQL query returns column names exactly as they appear in the database schema. The `class` table uses:
- `classID` (not `ClassID`)
- `className` (not `ClassName`)  
- `numberOfLearners` (not `learner_count`)

When the Dart code tried to access `classData['ClassName']`, it returned `null`, which triggered the fallback `'Unknown Class'`.

## Testing
1. Rebuild the APK with this fix
2. Login as ARPL assessor (facilitator_id 6)
3. Go to "Learner Clocking" tab
4. Classes should now display correctly with:
   - Actual class names (not "Unknown Class")
   - Correct class IDs
   - Correct learner counts

## Related Files
- `lib/arpl_assessor_clocking_page.dart` - Fixed key names
- `mobile/get_classes.php` - API endpoint (no changes needed)

## Next Steps
After rebuilding and testing, the learner sync functionality should work correctly because it will now receive valid class IDs to query against.
