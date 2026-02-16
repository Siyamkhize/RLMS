# POE Offline Functionality - Implementation Summary

## Overview
Enhanced the DetailsPage.dart to support full offline functionality for scanning and uploading POE (Proof of Evidence) documents. Users can now scan and save POE documents offline, which will automatically sync to the server when connectivity is restored.

**IMPORTANT**: Learner pathway data must be loaded at least once while online. The app automatically caches this data for subsequent offline access.

## Key Features Implemented

### 1. **Offline Data Caching**
- Learner pathway data is automatically cached when first loaded online
- Cached data stored in `learner_pathways_cache` table
- Enables full offline POE functionality after initial online load
- Cache automatically updates when online data is refreshed

### 2. **Offline Document Storage**
- All scanned POE documents are automatically saved to the device's persistent storage
- Documents are stored in: `/data/data/com.example.rlmss/app_flutter/POE/`
- File naming convention: `{type}_{learnerID}_{exercise}_{timestamp}.{extension}`
- Supports PDF and image formats

### 3. **Local Database Tracking**
- POE records are saved to the local SQLite database with `synced=0` flag
- Tracks: learnerID, type, exercise, filePath, logbook_text, submitted_at, synced status
- Enables offline-first workflow with automatic sync capability

### 4. **Automatic Sync on Connectivity**
- When internet connection is detected, unsynced POE records automatically sync to server
- Sync happens when:
  - User opens the POE tab
  - User manually triggers sync via "Sync Now" button
  - App detects connectivity restoration

### 5. **Visual Sync Status Indicators**
- **Orange banner** at top of POE tab shows pending sync count
- **"Sync Now" button** for manual sync trigger
- **Progress indicator** during active sync
- **Toast notifications** for sync success/failure
- **Offline save confirmation** with orange snackbar

### 6. **Enhanced User Experience**
- Users can continue working offline without interruption
- All POE scanning features work identically online and offline
- Clear visual feedback for offline operations
- No data loss - all documents persisted locally

## Technical Implementation

### Modified Files

#### 1. **lib/DetailsPage.dart**
- Added `unsyncedCount` and `isSyncing` state variables
- Enhanced `_saveLocally()` method:
  - Always copies documents to persistent app directory
  - Improved file naming with metadata
  - Shows offline save confirmation
  - Marks records with `synced=0` for later sync

- New `_syncOfflinePOE()` method:
  - Fetches unsynced POE records from database
  - Uploads each document to server
  - Marks successfully synced records
  - Handles errors gracefully
  - Updates UI with sync status

- New `_updateUnsyncedCount()` method:
  - Queries database for pending sync count
  - Updates UI state

- Enhanced `_refreshUploadStatus()`:
  - Checks unsynced count on load
  - Triggers automatic sync when online

- Added sync status banner UI:
  - Shows pending sync count
  - Manual "Sync Now" button
  - Progress indicator during sync

#### 2. **lib/database_helper.dart**
- Database version upgraded to 4 with new cache table

- New `learner_pathways_cache` table:
  - Stores learner pathway data as JSON
  - Enables offline POE access
  - Auto-updates when online data refreshed

- New `saveLearnerPathwaysCache(int learnerID, Map pathways)` method:
  - Saves pathway data to cache table
  - Called automatically when data fetched online
  - Uses REPLACE conflict algorithm for updates

- New `getLearnerPathwaysCache(int learnerID)` method:
  - Retrieves cached pathway data
  - Returns null if no cache exists
  - Decodes JSON to Map structure

- New `getUnsyncedPOE(int learnerID)` method:
  - Queries POE records where `synced=0`
  - Returns list of unsynced records with all metadata
  - Orders by submission time

- New `markPOEAsSynced(int id)` method:
  - Updates POE record to set `synced=1`
  - Called after successful server upload

## User Workflow

### First-Time Setup (Online Required):
1. User opens learner's POE tab while online
2. App fetches pathway data from server
3. Data is automatically cached locally
4. User can now work offline

### Offline Scenario:
1. User opens learner's POE tab (cached data loads)
2. User scans POE document (Formative/Summative/LogBook)
3. Document is saved locally with orange "Saved offline" notification
4. Orange banner appears showing "X POE record(s) pending sync"
5. User can continue scanning more documents
6. All documents remain accessible and tracked locally

### Online Scenario:
1. When connectivity is restored, app automatically attempts sync
2. User can also click "Sync Now" button for immediate sync
3. Each document uploads to server sequentially
4. Successfully synced records are marked as `synced=1`
5. Green notification shows "✅ Synced X POE record(s) to server"
6. Orange banner disappears when all records are synced

## Benefits

✅ **No Data Loss** - All POE documents saved locally first
✅ **Offline-First** - Full functionality without internet
✅ **Automatic Sync** - Seamless background synchronization
✅ **User Transparency** - Clear visual indicators of sync status
✅ **Resilient** - Handles network failures gracefully
✅ **Efficient** - Only syncs unsynced records
✅ **Persistent** - Documents stored in app directory survive app restarts

## Testing Recommendations

1. **Offline Scanning**:
   - Turn off internet
   - Scan multiple POE documents
   - Verify orange banner shows correct count
   - Verify documents saved to local storage

2. **Automatic Sync**:
   - Turn on internet
   - Open POE tab
   - Verify automatic sync triggers
   - Check green success notification

3. **Manual Sync**:
   - With pending records, click "Sync Now"
   - Verify progress indicator appears
   - Verify sync completes successfully

4. **Error Handling**:
   - Test with poor connectivity
   - Verify failed syncs remain in queue
   - Verify retry capability

5. **Persistence**:
   - Close and reopen app
   - Verify unsynced records still tracked
   - Verify documents still accessible

## Database Schema

### `learner_pathways_cache` table:
```sql
CREATE TABLE learner_pathways_cache (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  learnerID INTEGER UNIQUE NOT NULL,
  pathways_json TEXT NOT NULL,
  cached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### `poe` table:
```sql
CREATE TABLE poe (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  learnerID TEXT NOT NULL,
  type TEXT NOT NULL,
  exercise TEXT NOT NULL,
  filePath TEXT NOT NULL,
  logbook_text TEXT,
  submitted_at TEXT NOT NULL,
  synced INTEGER DEFAULT 0
);
```

## Future Enhancements (Optional)

- Add retry logic with exponential backoff for failed syncs
- Implement batch upload for multiple documents
- Add sync progress percentage
- Show individual document sync status
- Add option to delete synced local files to save space
- Implement conflict resolution for duplicate uploads
- Add sync history/log viewer
