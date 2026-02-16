# Fixing "No Offline Data Found" Error

## The Issue
When you go offline and try to access a learner's POE tab, you see:
```
No offline data found for learner ID: 123
[Retry] [Back]
```

## Why This Happens
The learner's pathway data hasn't been cached yet. The app needs to load the data at least once while online to cache it for offline use.

## The Fix (Already Implemented)

### What Was Changed
1. **New cache table** (`learner_pathways_cache`) stores learner data
2. **Automatic caching** when you load POE tab online
3. **Better error message** explains what to do
4. **Table auto-creation** ensures cache table exists

### New Error Message
Instead of just "No offline data found", you now see:
```
No offline data available.

To use offline POE functionality:
1. Connect to internet
2. Open this learner's POE tab
3. Data will be cached automatically

Then you can work offline.
```

## How to Use

### Step-by-Step Instructions

#### 1. First Time Setup (MUST BE ONLINE)
```
✅ Connect to internet
✅ Open app
✅ Navigate to learner
✅ Click POE tab
✅ Wait for data to load
✅ Data is now cached!
```

Console will show:
```
[OFFLINE_CACHE] Cache table verified/created
[OFFLINE_CACHE] Saved pathways cache for learnerID=123
```

#### 2. Offline Usage (NOW WORKS!)
```
✅ Turn off internet
✅ Open app
✅ Navigate to same learner
✅ Click POE tab
✅ Cached data loads!
✅ Scan POE documents offline
```

Console will show:
```
[OFFLINE_CACHE] Cache table verified/created
[OFFLINE_CACHE] Using cached pathway data
```

## Verification Steps

### Check 1: Database Version
The database should be version 4 (upgraded from 3).

**How to check:**
- Look in console for: `[DB] Upgrading database from version 3 to 4`
- Or: `[DB] Created learner_pathways_cache table for offline POE support`

### Check 2: Cache Table Exists
Run SQL query:
```sql
SELECT name FROM sqlite_master 
WHERE type='table' AND name='learner_pathways_cache';
```

Should return: `learner_pathways_cache`

### Check 3: Data is Cached
After loading POE tab online, run:
```sql
SELECT learnerID, 
       length(pathways_json) as size_bytes,
       updated_at 
FROM learner_pathways_cache;
```

Should show your learner's data.

### Check 4: Console Messages
Look for these key messages:

**✅ Good signs:**
```
[OFFLINE_CACHE] Cache table verified/created
[OFFLINE_CACHE] Saved pathways cache for learnerID=123
[OFFLINE_CACHE] Using cached pathway data
```

**⚠️ Warning signs:**
```
[OFFLINE_CACHE] No cached pathways found for learnerID=123
[OFFLINE_CACHE] User must load data online first
```

**❌ Error signs:**
```
Error saving learner pathways cache: ...
Error getting learner pathways cache: ...
```

## Troubleshooting

### Problem: Still seeing old error message
**Solution:** App needs to be recompiled
```bash
flutter clean
flutter pub get
flutter run
```

### Problem: Cache table doesn't exist
**Solution:** Database needs to upgrade

**Option A - Soft reset:**
1. Close app completely
2. Clear app data (Settings > Apps > Your App > Clear Data)
3. Reopen app
4. Database will recreate with version 4

**Option B - Hard reset:**
1. Uninstall app
2. Reinstall app
3. Database will be created fresh with version 4

### Problem: Data not caching
**Check these:**
- Are you actually online when loading POE tab?
- Does console show cache save message?
- Is there an error in console?
- Does cache table exist?

**Debug:**
```dart
// Add this temporarily to your code
final dbHelper = DatabaseHelper();
final cache = await dbHelper.getLearnerPathwaysCache(123);
print('Cache exists: ${cache != null}');
if (cache != null) {
  print('Cache keys: ${cache.keys}');
}
```

### Problem: Cache exists but not loading
**Check:**
- Console for error messages
- JSON decode errors
- Database query errors

**Fix:**
```dart
// Clear cache and reload
final db = await DatabaseHelper().database;
await db.delete('learner_pathways_cache', where: 'learnerID = ?', whereArgs: [123]);
// Then reload POE tab while online
```

## Testing Checklist

- [ ] Database upgraded to version 4
- [ ] Cache table exists
- [ ] Load POE tab while online
- [ ] Console shows cache save message
- [ ] Cache table has data for learner
- [ ] Turn off internet
- [ ] Load POE tab offline
- [ ] Console shows cache load message
- [ ] POE data displays correctly
- [ ] Can scan documents offline
- [ ] Documents save with orange notification
- [ ] Sync banner shows pending count

## Debug Widget (Optional)

Add this to your POE tab to see cache status:

```dart
import 'cache_debug_widget.dart';

// In your POE tab build method:
Column(
  children: [
    CacheDebugWidget(learnerID: widget.learnerID),
    // ... rest of your POE content
  ],
)
```

This will show:
- ✅ Cache exists with size and date
- ⚠️ No cache (need to load online)
- ❌ Cache table missing (need database upgrade)

## Expected Console Output

### First Load (Online)
```
API Request: learnerID=123, statusCode=200
Decoded Response: {pathways: {...}}
[OFFLINE_CACHE] Cache table verified/created
[OFFLINE_CACHE] Saved learner pathway data for offline access
Assigned pathwaysData: {...}
```

### Second Load (Offline)
```
[OFFLINE_CACHE] Cache table verified/created
[OFFLINE_CACHE] Using cached pathway data
```

### No Cache (Offline)
```
[OFFLINE_CACHE] Cache table verified/created
[OFFLINE_CACHE] No cached pathways found for learnerID=123
[OFFLINE_CACHE] No cached or local data for learnerID: 123
[OFFLINE_CACHE] User must load data online first to enable offline access
```

## Summary

✅ **What works now:**
- Automatic caching when online
- Offline POE access after first online load
- Better error messages
- Auto-table creation

⚠️ **What you need to do:**
- Load each learner's POE tab once while online
- This caches their data for offline use

❌ **What won't work:**
- Offline access without prior online load
- This is by design - data must come from server first

## Need More Help?

Check these files:
- `TEST_OFFLINE_POE.md` - Step-by-step testing guide
- `OFFLINE_POE_QUICK_START.md` - Quick reference
- `POE_OFFLINE_FUNCTIONALITY.md` - Technical details
- `POE_OFFLINE_TESTING_GUIDE.md` - Comprehensive testing

Or check console logs for `[OFFLINE_CACHE]` messages to see what's happening.
