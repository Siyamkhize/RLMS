# Online Status Check - Merge Fix

## The Problem

When online, the app showed only 6/16 questions as completed, even though all 16 were scanned and saved locally.

### What Was Happening:
1. User scans all 16 questions offline
2. All 16 saved locally with `synced=0`
3. All 16 show as completed ✅
4. User goes online
5. App calls `checkUploadedStatus()` to query server
6. Server returns only 6 questions (the ones that synced)
7. App **replaces** local state with server state
8. Now only 6/16 show as completed ❌
9. The other 10 are lost from UI (even though they're in local database)

## Root Cause

The `checkUploadedStatus()` method was **replacing** the entire `uploadedExercises` map with server response:

```dart
uploadedExercises = decodedResponse.map(...);  // ❌ Replaces everything
```

This lost all locally-saved records that hadn't synced to server yet.

## The Fix

Changed `checkUploadedStatus()` to **merge** server status with local status:

```dart
// Get local status first
final localStatus = await dbHelper.getLocalUploadStatus(...);

// Get server status
final serverStatus = decodedResponse.map(...);

// Merge: local + server
uploadedExercises = Map.from(localStatus);  // Start with local
uploadedExercises.addAll(serverStatus);     // Overlay server
```

### Why This Works:

**Local status includes:**
- ✅ Records synced to server (`synced=1`)
- ✅ Records saved locally, pending sync (`synced=0`)

**Server status includes:**
- ✅ Only records synced to server

**Merged status includes:**
- ✅ Everything from local (all scanned questions)
- ✅ Updated status from server (for synced questions)
- ✅ Best of both worlds!

## How It Works Now

### Scenario 1: All Questions Synced
1. User scans 16 questions offline
2. All 16 saved locally
3. User goes online
4. All 16 sync to server
5. Server returns: 16 questions
6. Local has: 16 questions
7. Merged: 16 questions ✅

### Scenario 2: Partial Sync
1. User scans 16 questions offline
2. All 16 saved locally
3. User goes online
4. Only 6 sync successfully (network issues, timeouts, etc.)
5. Server returns: 6 questions
6. Local has: 16 questions (6 synced + 10 pending)
7. Merged: 16 questions ✅
8. Orange banner shows: "10 POE record(s) pending sync"

### Scenario 3: Server Empty, Local Has Data
1. User scans questions offline
2. All saved locally
3. User goes online but server has no records yet
4. Server returns: empty array
5. Local has: all questions
6. Merged: all questions from local ✅

## Code Changes

### Before:
```dart
if (response.statusCode == 200) {
  final decodedResponse = json.decode(response.body);
  if (decodedResponse is Map<String, dynamic>) {
    setState(() {
      // ❌ Replaces everything with server response
      uploadedExercises = decodedResponse.map(...);
    });
  } else if (decodedResponse is List && decodedResponse.isEmpty) {
    setState(() {
      // ❌ Clears everything if server is empty
      uploadedExercises = {};
    });
  }
}
```

### After:
```dart
if (response.statusCode == 200) {
  final decodedResponse = json.decode(response.body);
  if (decodedResponse is Map<String, dynamic>) {
    // ✅ Get local status first
    final localStatus = await dbHelper.getLocalUploadStatus(...);
    final serverStatus = decodedResponse.map(...);
    
    setState(() {
      // ✅ Merge: local + server
      uploadedExercises = Map.from(localStatus);
      uploadedExercises.addAll(serverStatus);
    });
  } else if (decodedResponse is List && decodedResponse.isEmpty) {
    // ✅ Use local status if server is empty
    final localStatus = await dbHelper.getLocalUploadStatus(...);
    setState(() {
      uploadedExercises = localStatus;
    });
  }
}
```

## Benefits

✅ **No data loss** - Locally-saved questions never disappear from UI
✅ **Accurate counts** - Shows all scanned questions, not just synced ones
✅ **Sync awareness** - Orange banner shows what's pending
✅ **Server priority** - Server status overrides local for synced items
✅ **Offline-first** - Works perfectly without constant server connection

## Console Output

You'll now see:
```
checkUploadedStatus Request: learnerID=123, statusCode=200
Raw response: {"Formative-Q1-123":true,"Formative-Q2-123":true,...}
Merged uploadedExercises: 16 total (6 from server, 16 from local)
```

This shows:
- Server returned 6 questions
- Local has 16 questions
- Merged result: 16 questions (all of them!)

## Testing

### Test 1: Scan Offline, Go Online
1. Go offline
2. Scan all 16 questions
3. All show as completed ✅
4. Go online
5. Wait for sync or click "Sync Now"
6. **Expected:** All 16 still show as completed ✅

### Test 2: Partial Sync
1. Scan 16 questions offline
2. Go online with poor connection
3. Only some questions sync
4. **Expected:** All 16 still show as completed ✅
5. **Expected:** Orange banner shows pending count

### Test 3: Server Has Fewer Records
1. Scan questions locally
2. Server has only some of them
3. **Expected:** All local questions show as completed ✅
4. **Expected:** Server records are included too

## Edge Cases Handled

### Case 1: Server Returns Subset
- **Before:** Only server records shown (data loss)
- **After:** All local + server records shown ✅

### Case 2: Server Returns Empty
- **Before:** All records cleared (data loss)
- **After:** Local records preserved ✅

### Case 3: Server Has More Records
- **Before:** Server records shown
- **After:** Server + local records shown ✅

### Case 4: Duplicate Keys
- **Before:** N/A
- **After:** Server value takes precedence (correct behavior)

## Summary

**The fix ensures that locally-saved questions are never lost when checking server status.**

Instead of **replacing** local state with server state, we now **merge** them:
- Start with local status (all scanned questions)
- Overlay server status (synced questions)
- Result: Complete picture of all questions

This gives users an accurate view of their progress, regardless of sync status! 🎉
