# Finance Login Navigation Fix

## Problem
User was able to log in successfully with finance credentials, but was being redirected to the facilitator interface instead of the finance dashboard.

## Root Cause
1. The `role` field from the `account_user` table might have been capitalized or had whitespace
2. The navigation logic in Flutter was doing exact string comparison (`role == 'finance'`)
3. If the role didn't match exactly, it would fall through to the `else` block and treat the user as a facilitator

## Solution Applied

### 1. Backend Fix (login.php)
- Normalized the role to lowercase using `strtolower(trim($row['role'] ?? 'Account'))`
- Added explicit `classID: ''` (empty string) in the finance response to prevent facilitator flow
- Ensured `facilitator_id` is cast to string for consistency

```php
// Normalize role to lowercase for consistent comparison
$role = strtolower(trim($row['role'] ?? 'Account'));

if ($role === 'finance') {
    echo json_encode([
        'success' => true,
        'role' => 'finance',
        'facilitator_id' => (string)$row['account_id'],
        'classID' => '', // Empty classID to prevent facilitator flow
        'name' => $row['account_name'] ?? '',
        'email' => $row['email'] ?? $row['username']
    ]);
}
```

### 2. Frontend Fix (lib/main.dart)
- Added role normalization in `_navigateBasedOnRole()` function
- Changed all role comparisons to use lowercase normalized role
- Added debug logging to track navigation decisions

```dart
void _navigateBasedOnRole(String role, ...) async {
    // Normalize role to lowercase for consistent comparison
    final normalizedRole = role.toLowerCase().trim();
    
    debugPrint('[NAVIGATION] Role: "$normalizedRole", classID: "$classID", facilitator_id: "$facilitator_id"');
    
    if (normalizedRole == 'sdp') {
        // ...
    } else if (normalizedRole == 'finance') {
        debugPrint('[NAVIGATION] Navigating to Finance Dashboard');
        Navigator.push(...);
    } else if (normalizedRole == 'assessor') {
        // ...
    } else if (normalizedRole == 'moderator') {
        // ...
    } else {
        // Facilitator role
        debugPrint('[NAVIGATION] Navigating to Facilitator Dashboard');
        // ...
    }
}
```

## Testing
1. Log in with finance credentials
2. Check the debug logs for: `[NAVIGATION] Role: "finance", classID: "", facilitator_id: "..."`
3. Verify navigation goes to Finance Dashboard (not facilitator interface)
4. Verify the dashboard shows classes and learners correctly

## Files Modified
- `login.php` - Normalized role and added empty classID
- `lib/main.dart` - Added role normalization and debug logging

## Expected Behavior
- Finance users should now be correctly routed to the Finance Dashboard
- The role comparison is now case-insensitive
- Debug logs will help identify any future navigation issues
