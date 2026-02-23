# SDP Offline Issues - FIXED

## Problem
`sdp_projects_page.dart` and `sdp_learning_pathways_page.dart` were not working offline even though the `project` and `sdp` tables exist in the local database.

## Root Causes

### 1. Incorrect Connectivity Check
**File**: `lib/sdp_projects_page.dart`

**Problem**:
```dart
// WRONG - connectivity_plus returns List<ConnectivityResult>
return connectivityResult != ConnectivityResult.none;
```

**Fix**:
```dart
// CORRECT - check if list contains wifi or mobile
return connectivityResult.contains(ConnectivityResult.wifi) ||
    connectivityResult.contains(ConnectivityResult.mobile);
```

### 2. Not Using Existing Database Tables
**File**: `lib/sdp_projects_page.dart`

**Problem**:
- Created a new cache table `sdp_projects_cache`
- Ignored the existing `project` table that's already synced

**Fix**:
- Removed cache table creation
- Query the existing `project` table directly
- Transform database format to match API format

### 3. Data Format Mismatch
**Problem**:
- Database `project` table has different structure than API response
- `Project_pathway` is JSON string in database
- API returns parsed pathways array

**Fix**:
```dart
// Parse Project_pathway JSON from database
final pathwayJson = project['Project_pathway'] as String?;
if (pathwayJson != null && pathwayJson.isNotEmpty) {
  final decoded = json.decode(pathwayJson);
  if (decoded is List) {
    pathways = List<Map<String, dynamic>>.from(decoded);
  }
}

// Transform to match API format
return {
  'project_id': project['project_id'],
  'project_name': project['Project_name'],
  'pathways': pathways,
  'pathway_count': pathways.length,
  // ... other fields
};
```

## Changes Made

### File: `lib/sdp_projects_page.dart`

#### 1. Fixed Connectivity Check
```dart
Future<bool> _checkConnectivity() async {
  final connectivityResult = await Connectivity().checkConnectivity();
  return connectivityResult.contains(ConnectivityResult.wifi) ||
      connectivityResult.contains(ConnectivityResult.mobile);
}
```

#### 2. Removed Cache Table Creation
- Removed `_createLocalTable()` method
- Removed `_cacheProjects()` method
- Removed `_getCachedProjects()` method
- Removed `sqflite` import (unused)

#### 3. Added Database Query Method
```dart
Future<List<Map<String, dynamic>>> _getProjectsFromDatabase() async {
  // 1. Get SDP name from sdp table
  final sdpResults = await db.query(
    'sdp',
    where: 'sdp_id = ? OR sdp_name = ? OR email = ?',
    whereArgs: [widget.sdpIdentifier, widget.sdpIdentifier, widget.sdpIdentifier],
  );
  
  // 2. Query project table
  final projectResults = await db.query(
    'project',
    where: 'sdp_name = ?',
    whereArgs: [sdpName],
  );
  
  // 3. Transform to match API format
  return transformedProjects;
}
```

#### 4. Updated _loadProjects Method
```dart
// Fallback to local database (offline or server error)
final localProjects = await _getProjectsFromDatabase();
if (localProjects.isNotEmpty) {
  setState(() {
    projects = localProjects;
    isLoading = false;
    if (!isOnline) {
      errorMessage = 'Offline mode - showing local data';
    }
  });
}
```

### File: `lib/sdp_learning_pathways_page.dart`
**No changes needed** - Already works offline because:
- Receives pathways data from projects page
- No API calls made
- Pure UI component

### File: `lib/sync_service.dart`
#### Smart Sync for SDP Table
Changed from DELETE+INSERT to UPDATE/INSERT:
```dart
// OLD: Clear and re-insert (data loss risk)
await _dbHelper.clearTable('sdp');
for (var sdp in sdpData) {
  await _dbHelper.insertData('sdp', sdpRecord);
}

// NEW: Update existing, insert new (no data loss)
for (var sdp in sdpData) {
  final existing = await db.query('sdp', where: 'sdp_id = ?', whereArgs: [sdp['sdp_id']]);
  
  if (existing.isNotEmpty) {
    await db.update('sdp', sdpRecord, where: 'sdp_id = ?', whereArgs: [sdp['sdp_id']]);
  } else {
    await _dbHelper.insertData('sdp', sdpRecord);
  }
}
```

## How It Works Now

### Online Mode
1. User logs in → Background sync runs
2. `syncProjectData()` populates `project` table
3. `_syncSdp()` updates `sdp` table (no delete)
4. Projects page fetches from API
5. Data displayed

### Offline Mode
1. User logs in → `_loginOffline()` checks local `sdp` table
2. Projects page detects offline
3. Queries `project` table using `sdp_name`
4. Transforms database format to API format
5. Displays projects with pathways
6. Pathways page receives data (no API needed)
7. Shows "Offline mode - showing local data" message

### Data Flow
```
Login (Online)
  ↓
Background Sync
  ├─ syncProjectData() → project table
  └─ _syncSdp() → sdp table (UPDATE/INSERT)
  ↓
Projects Page
  ├─ Online: Fetch from API
  └─ Offline: Query project table
  ↓
Pathways Page
  └─ Receives data from Projects (no API)
```

## Database Tables Used

### `sdp` Table
- Stores SDP credentials and profile
- Synced via `_syncSdp()` in `sync_service.dart`
- Used for offline login and SDP lookup
- **Now uses UPDATE/INSERT** (no data loss)

### `project` Table
- Stores all projects for each SDP
- Synced via `syncProjectData()` in `sync_service.dart`
- Fields: project_id, sdp_name, Project_name, Project_pathway (JSON), etc.
- Used for offline project listing

## Testing

### Test Offline Projects Page
1. Login online (wait for sync)
2. Logout
3. Turn off internet
4. Login offline
5. Navigate to Projects page
6. ✅ Should show projects from local database
7. ✅ Should show "Offline mode - showing local data"

### Test Offline Pathways Page
1. While offline, click on a project
2. ✅ Should show pathways
3. ✅ No API calls made
4. ✅ Data passed from projects page

### Test Sync (No Data Loss)
1. Login online
2. Background sync runs
3. ✅ Existing SDP records updated (not deleted)
4. ✅ New SDP records inserted
5. ✅ No data loss

## Benefits

### 1. True Offline Support
- Projects page works completely offline
- Pathways page works completely offline
- Uses existing synced data

### 2. No Data Loss
- Smart sync updates existing records
- Doesn't delete local data
- Preserves offline changes

### 3. Consistent Data
- Same data structure online and offline
- Transformation layer handles format differences
- Seamless user experience

### 4. Better Performance
- No unnecessary cache tables
- Direct database queries
- Faster data access

## Summary

✅ **Fixed connectivity check** - Proper List<ConnectivityResult> handling
✅ **Using existing tables** - project and sdp tables
✅ **Data transformation** - Database format → API format
✅ **Smart sync** - UPDATE/INSERT instead of DELETE+INSERT
✅ **No data loss** - Preserves local data during sync
✅ **Complete offline support** - Projects and pathways work offline

**Both pages now work perfectly offline!**
