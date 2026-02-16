# Test Offline POE - Step by Step

## Current Situation
You're seeing "No offline data found for learner" when offline because the learner's data hasn't been cached yet.

## Solution Steps

### Step 1: Verify You're Online
1. Connect to WiFi or mobile data
2. Verify internet connection is working

### Step 2: Cache the Learner Data
1. Open the app
2. Navigate to the learner's details
3. Click on the **POE tab**
4. Wait for the data to load (you should see the pathway/qualification/unit standards)
5. Look for this message in console/logs: `[OFFLINE_CACHE] Saved learner pathway data for offline access`

### Step 3: Test Offline Access
1. Turn OFF WiFi/mobile data
2. Close the app completely
3. Reopen the app
4. Navigate to the same learner's POE tab
5. You should now see the cached data load successfully!

## What to Expect

### First Time (Online) ✅
- POE tab loads from server
- Console shows: `[OFFLINE_CACHE] Saved learner pathway data for offline access`
- Data is now cached

### Second Time (Offline) ✅
- POE tab loads from cache
- Console shows: `[OFFLINE_CACHE] Using cached pathway data`
- Full POE functionality available

### If Still Shows Error ❌
Error message will now say:
```
No offline data available.

To use offline POE functionality:
1. Connect to internet
2. Open this learner's POE tab
3. Data will be cached automatically

Then you can work offline.
```

## Troubleshooting

### Check if Cache Table Exists
Run this SQL query on your database:
```sql
SELECT name FROM sqlite_master WHERE type='table' AND name='learner_pathways_cache';
```

Should return: `learner_pathways_cache`

### Check if Data is Cached
```sql
SELECT learnerID, length(pathways_json) as data_size, updated_at 
FROM learner_pathways_cache;
```

Should show entries for learners you've viewed online.

### Force Database Upgrade
If the table doesn't exist:
1. Uninstall the app completely
2. Reinstall
3. Database will be created with version 4

OR

1. Delete the database file manually
2. Restart the app
3. Database will be recreated

### Check Console Logs
Look for these messages:

**When caching (online):**
```
[OFFLINE_CACHE] Cache table verified/created
[OFFLINE_CACHE] Saved pathways cache for learnerID=123
```

**When loading offline:**
```
[OFFLINE_CACHE] Cache table verified/created
[OFFLINE_CACHE] Using cached pathway data
```

**When no cache exists:**
```
[OFFLINE_CACHE] No cached pathways found for learnerID=123
[OFFLINE_CACHE] No cached or local data for learnerID: 123
[OFFLINE_CACHE] User must load data online first to enable offline access
```

## Quick Test Commands

### Check Database Version
```dart
final db = await DatabaseHelper().database;
final version = await db.getVersion();
print('Database version: $version'); // Should be 4
```

### Manually Create Cache Table (if needed)
```dart
final db = await DatabaseHelper().database;
await db.execute('''
  CREATE TABLE IF NOT EXISTS learner_pathways_cache (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    learnerID INTEGER UNIQUE NOT NULL,
    pathways_json TEXT NOT NULL,
    cached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  )
''');
```

### Check Cache for Specific Learner
```dart
final cache = await DatabaseHelper().getLearnerPathwaysCache(123);
print('Cache exists: ${cache != null}');
```

## Expected Behavior Summary

| Scenario | Online | Cache Exists | Result |
|----------|--------|--------------|--------|
| First visit | ✅ Yes | ❌ No | Loads from server, creates cache |
| Second visit | ✅ Yes | ✅ Yes | Loads from server, updates cache |
| Offline visit | ❌ No | ✅ Yes | Loads from cache, works perfectly |
| Offline visit | ❌ No | ❌ No | Shows helpful error message |

## Success Indicators

✅ Console shows cache messages
✅ Database has `learner_pathways_cache` table
✅ Table has entry for your learner
✅ Offline access works after online load
✅ Error message is helpful when no cache exists

## Still Having Issues?

1. Check database version (should be 4)
2. Verify cache table exists
3. Ensure you loaded POE tab while online
4. Check console for error messages
5. Try uninstall/reinstall if database won't upgrade
