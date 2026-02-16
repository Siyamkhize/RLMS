# Offline POE - Quick Start Guide

## Problem Solved
The "No offline data found for learner" error when offline has been fixed by implementing automatic data caching.

## How It Works

### Automatic Caching
When you open a learner's POE tab while **online**, the app now:
1. Fetches pathway data from the server
2. **Automatically saves it to local cache** (`learner_pathways_cache` table)
3. Uses this cache when offline

### Offline Access
When you open a learner's POE tab while **offline**, the app:
1. Loads pathway data from local cache
2. Allows full POE scanning functionality
3. Saves scanned documents locally
4. Syncs to server when connectivity returns

## User Instructions

### First Time (Online Required)
1. Connect to internet
2. Open the learner's POE tab
3. Wait for data to load
4. ✅ Data is now cached for offline use

### Subsequent Access (Works Offline)
1. Open the learner's POE tab (works offline now!)
2. Scan POE documents as normal
3. Documents save locally with orange notification
4. Sync automatically when back online

## Technical Changes

### New Database Table
```sql
CREATE TABLE learner_pathways_cache (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  learnerID INTEGER UNIQUE NOT NULL,
  pathways_json TEXT NOT NULL,
  cached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### New Methods
- `saveLearnerPathwaysCache()` - Saves pathway data to cache
- `getLearnerPathwaysCache()` - Retrieves cached pathway data
- `_saveLearnerDataLocally()` - Called automatically when online

### Modified Methods
- `fetchOnlineLearnerData()` - Now caches data after successful fetch
- `fetchOfflineLearnerData()` - Now checks cache first before complex query

## Console Messages

### When Caching Data (Online)
```
[OFFLINE_CACHE] Saved learner pathway data for offline access
```

### When Using Cache (Offline)
```
[OFFLINE_CACHE] Using cached pathway data
```

### When No Cache Exists
```
[OFFLINE_CACHE] No cached data, trying database query...
```

## Benefits

✅ **No more "No offline data" errors** after first online load
✅ **Faster offline loading** - cache is simpler than complex query
✅ **Automatic caching** - no user action required
✅ **Per-learner caching** - each learner cached independently
✅ **Auto-updates** - cache refreshes when online data fetched

## Migration Notes

### For Existing Users
- Database will auto-upgrade from version 3 to version 4
- New `learner_pathways_cache` table created automatically
- Existing POE data unaffected
- Users need to open each learner's POE tab once while online to build cache

### For New Installations
- Cache table created on first run
- Works immediately after first online load per learner

## Troubleshooting

### Still seeing "No offline data" error?
1. Ensure you've opened the POE tab while online at least once
2. Check console for cache messages
3. Verify database version is 4: `SELECT * FROM sqlite_master WHERE type='table' AND name='learner_pathways_cache'`

### Cache not updating?
- Cache updates automatically each time you load POE tab while online
- No manual refresh needed

### Want to clear cache?
```sql
DELETE FROM learner_pathways_cache WHERE learnerID = ?;
```

## Summary

The offline POE functionality now works seamlessly:
1. **First visit (online)**: Data cached automatically
2. **Subsequent visits (offline)**: Cache used, full functionality available
3. **Sync (online)**: Offline scans upload automatically

No user action required beyond the initial online load!
