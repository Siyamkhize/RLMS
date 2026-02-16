# Implement Offline Clocking - Step-by-Step Guide

## Quick Summary
Your system needs to keep learner data in the local database permanently so clocking works offline, even when IP is blocked or no internet connection.

## What We've Created

### 1. ✅ `lib/persistent_sync_service.dart`
- New service that NEVER clears local data
- Uses UPSERT strategy (INSERT OR REPLACE)
- Maintains offline availability
- Falls back to cached data when offline

### 2. ✅ `lib/database_helper.dart` (Updated)
- Added `upsertLearner()` method
- Added `hasLocalLearnerData()` check
- Added `getLocalLearnerCount()` method
- Added data sanitization helpers

## Implementation Steps

### Step 1: Update Main App to Use Persistent Sync

**File: `lib/main.dart`**

Find this code:
```dart
await syncService.syncLearnerDetails();
```

Replace with:
```dart
// Use persistent sync instead of regular sync
import 'persistent_sync_service.dart';
final persistentSync = PersistentSyncService();
final result = await persistentSync.syncLearnerDetailsPersistent();
print('[MAIN] Persistent sync result: $result');
```

### Step 2: Update Clock-In Page to Check Local Data

**File: `lib/clock_in_page.dart`**

Add to `initState()`:
```dart
@override
void initState() {
  super.initState();
  databaseFactory = databaseFactoryFfi;
  ClockingLogger.instance.initialize();
  
  // NEW: Check local data availability
  _checkLocalDataAvailability();
  
  _initializeData();
  _initializeSensor();
  _setupStreams();
  _setupConnectivityListener();
  _checkInitialConnectivity();
}

// NEW METHOD: Check if local data is available
Future<void> _checkLocalDataAvailability() async {
  try {
    final hasData = await DatabaseHelper().hasLocalLearnerData(widget.classID);
    final count = await DatabaseHelper().getLocalLearnerCount(widget.classID);
    
    if (hasData) {
      print('[CLOCK_IN] ✅ Local data available: $count learners for class ${widget.classID}');
    } else {
      print('[CLOCK_IN] ⚠️ No local data for class ${widget.classID}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No local learner data. Please sync when online.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  } catch (e) {
    print('[CLOCK_IN] Error checking local data: $e');
  }
}
```

### Step 3: Add Manual Sync Button (Optional but Recommended)

**File: `lib/clock_in_page.dart`**

Add a sync button to the AppBar:
```dart
AppBar(
  title: Text('Clock In/Out'),
  actions: [
    // NEW: Manual sync button
    IconButton(
      icon: Icon(_isConnected ? Icons.sync : Icons.sync_disabled),
      onPressed: _isConnected ? _manualSync : null,
      tooltip: 'Sync learner data',
    ),
    // ... existing actions ...
  ],
)

// NEW METHOD: Manual sync
Future<void> _manualSync() async {
  if (!_isConnected) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cannot sync while offline'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  try {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Syncing learner data...'),
        duration: Duration(seconds: 2),
      ),
    );

    final persistentSync = PersistentSyncService();
    final result = await persistentSync.syncLearnerDetailsPersistent(
      classID: widget.classID,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Sync completed'),
          backgroundColor: result['success'] ? Colors.green : Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );

      // Reload learners after sync
      await _loadLearnersFromLocalDatabase();
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

### Step 4: Update Sync Service to Use Persistent Strategy

**File: `lib/sync_service.dart`**

Find the `_syncLearnerDetails()` method and replace the clear logic:

```dart
Future<void> _syncLearnerDetails() async {
  try {
    // ... connectivity check ...

    if (response.statusCode == 200) {
      final List<dynamic> learners = json.decode(response.body);
      
      // OLD CODE - REMOVE THIS:
      // await _dbHelper.clearTable('learnerdetails');
      
      // NEW CODE - USE UPSERT:
      for (var learner in learners) {
        if (learner['IDNumber'] == null || learner['classID'] == null) {
          continue;
        }
        
        // Use upsert instead of insert
        await _dbHelper.upsertLearner(learner);
      }
      
      print("Successfully synchronized ${learners.length} learner records");
    }
  } catch (e) {
    print("Error syncing learner details: $e");
    // Don't rethrow - allow offline operation
  }
}
```

## Testing Checklist

### Test 1: Initial Sync (Online)
- [ ] Connect to internet
- [ ] Open app and login
- [ ] Verify learners sync to local database
- [ ] Check console for "Upserted learner" messages

### Test 2: Offline Clocking
- [ ] Disconnect from internet (airplane mode)
- [ ] Open clock-in page
- [ ] Verify learners still visible
- [ ] Clock in a learner
- [ ] Verify "Saved locally (will sync when online)" message
- [ ] Check local database has record with synced=0

### Test 3: IP Block Scenario
- [ ] Block IP address on server
- [ ] Try to access online features (should fail)
- [ ] Open clock-in page (should work)
- [ ] Clock in learner (should work offline)
- [ ] Verify record saved locally

### Test 4: Sync After Offline
- [ ] Reconnect to internet
- [ ] Wait for auto-sync or trigger manual sync
- [ ] Verify offline records upload to server
- [ ] Check records now have synced=1

### Test 5: Data Persistence
- [ ] Close app completely
- [ ] Reopen app (offline)
- [ ] Verify learners still visible
- [ ] Verify clocking still works

## Troubleshooting

### Issue: "No local learner data"
**Solution**: Run initial sync while online first

### Issue: Learners disappear after restart
**Solution**: Check if old sync code is still clearing data

### Issue: Duplicate learners
**Solution**: UPSERT should prevent this, but check LearnerID is unique

### Issue: Sync fails silently
**Solution**: Check console logs for error messages

## Benefits of This Solution

✅ **Works Offline**: Clock in/out without internet
✅ **IP Block Resistant**: System works even when blocked
✅ **Data Persistence**: Learners stay in local database
✅ **Automatic Sync**: Records upload when connection available
✅ **No Data Loss**: Queue-based sync ensures all records saved
✅ **Faster Performance**: No full reload each time

## Important Notes

⚠️ **First Time Setup**: Must sync online at least once to populate local database

⚠️ **Storage**: More data stored locally (monitor device storage)

⚠️ **Data Freshness**: Local data may be stale if not synced regularly

⚠️ **Conflicts**: Server data always wins in conflicts

## Next Steps

1. ✅ Files created (persistent_sync_service.dart, database_helper.dart updated)
2. ⏳ Update main.dart to use persistent sync
3. ⏳ Update clock_in_page.dart with local data check
4. ⏳ Update sync_service.dart to use upsert
5. ⏳ Test thoroughly offline
6. ⏳ Deploy to production

---

**Status**: Ready to implement
**Time Required**: 30-60 minutes
**Risk Level**: Low (fallback to cached data)
