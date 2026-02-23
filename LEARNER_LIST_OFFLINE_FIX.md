# Learner List Page Offline Support Fix

## Issue
The learner_list_page.dart was not loading learners from the local database when offline. The logs showed:
```
Found 0 unsynced learners for class 111
Fetching learners from server for classID: 111
```

This indicated the app was trying to fetch from the server even when offline, and not falling back to local data.

## Root Causes

### 1. Duplicate _checkConnectivity() Methods
There were TWO `_checkConnectivity()` methods in the file:
- Line 708: Used `Connectivity().checkConnectivity()` - only checks if device has network connection (WiFi/mobile), not actual internet access
- Line 2548: Used `InternetAddress.lookup('google.com')` - actually verifies internet connectivity

The first method could return true even when there's no internet access (e.g., connected to WiFi but no internet).

### 2. No Timeout on Server Requests
The `fetchLearnersFromServer()` method had no timeout, so it could hang indefinitely when the server is unreachable.

### 3. Poor Offline Feedback
When loading from local database, there was minimal user feedback about offline mode.

## Fixes Applied

### 1. Removed Duplicate _checkConnectivity() Method
Removed the first (less reliable) connectivity check method. Now only uses the DNS lookup method which actually verifies internet access.

### 2. Added Timeout to Server Requests
```dart
final response = await http
    .get(Uri.parse(...))
    .timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        print('Server request timed out after 10 seconds');
        throw TimeoutException('Server request timed out');
      },
    );
```

### 3. Enhanced Offline Feedback
Added clear user feedback when operating in offline mode:
- Orange SnackBar when loading from local database
- Debug logs with `[LEARNER_LIST]` prefix for easier tracking
- Shows count of learners loaded from local database

### 4. Improved Error Handling
```dart
Future<void> fetchLearnersData() async {
  try {
    final isConnected = await _checkConnectivity();

    if (isConnected) {
      print('[LEARNER_LIST] Online - attempting to sync and fetch from server');
      // Sync and fetch from server
      final serverLearners = await fetchLearnersFromServer();
      if (serverLearners.isNotEmpty) {
        await _mergeServerAndLocalData(serverLearners);
      } else {
        // Server returned empty (error or no data)
        print('[LEARNER_LIST] Server returned empty, loading from local database');
        await loadLearnersFromLocalDatabase();
      }
    } else {
      print('[LEARNER_LIST] Offline - loading from local database');
      await loadLearnersFromLocalDatabase();
      // Show offline indicator
    }
  } catch (e) {
    // Always fallback to local data on error
    await loadLearnersFromLocalDatabase();
  }
}
```

### 5. Added Missing Import
Added `import 'dart:async';` for `TimeoutException`.

## How It Works Now

### Online Mode
1. Check internet connectivity (DNS lookup)
2. Sync unsynced local learners to server
3. Fetch learners from server
4. Merge server data with local data
5. Display merged data

### Offline Mode
1. Detect no internet connection
2. Load learners from local database
3. Show orange SnackBar: "Offline mode - showing cached data"
4. Display local data

### Error/Timeout Mode
1. Attempt server connection
2. Timeout after 10 seconds
3. Fallback to local database
4. Show orange SnackBar: "Loading from local database (offline)"
5. Display local data

## Testing

### Test Offline Mode
1. Turn off WiFi/mobile data
2. Open a class in learner list page
3. Should see: "Offline mode - showing cached data" (orange)
4. Should display learners from local database

### Test Timeout Mode
1. Connect to WiFi with no internet
2. Open a class in learner list page
3. Should timeout after 10 seconds
4. Should see: "Loading from local database (offline)" (orange)
5. Should display learners from local database

### Test Online Mode
1. Connect to internet
2. Open a class in learner list page
3. Should fetch from server
4. Should merge with local data
5. Should display all learners

## Debug Logs
Look for these log messages:
- `[LEARNER_LIST] Online - attempting to sync and fetch from server`
- `[LEARNER_LIST] Offline - loading from local database`
- `[LEARNER_LIST] Server returned empty, loading from local database`
- `[LEARNER_LIST] Found X learners in local database`
- `[LEARNER_LIST] Error occurred, falling back to local database`

## Files Modified
- `lib/learner_list_page.dart`
  - Added timeout to server requests
  - Removed duplicate _checkConnectivity() method
  - Enhanced offline feedback
  - Improved error handling
  - Added debug logging

## Related Tasks
This fix addresses the offline support requirement from the context transfer summary. The learner list page now properly loads from local database when offline, matching the behavior of other pages like admin.dart and sdp_projects_page.dart.
