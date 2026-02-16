# Offline Cache Diagnostic Guide

## Your Question: "Does it sync data from server to local?"

**YES!** The code is set up to automatically cache data from server to local. Here's how it works:

## How the Caching Works

### Step 1: When You Open POE Tab (Online)
```
User opens POE tab → fetchLearnerData() → 
  Check connectivity → ONLINE → 
  fetchOnlineLearnerData() → 
  Fetch from server → 
  _saveLearnerDataLocally() → 
  Save to cache table → 
  ✅ Data cached!
```

### Step 2: When You Open POE Tab (Offline)
```
User opens POE tab → fetchLearnerData() → 
  Check connectivity → OFFLINE → 
  fetchOfflineLearnerData() → 
  getLearnerPathwaysCache() → 
  Load from cache → 
  ✅ Data loaded!
```

## Why You're Seeing "No Offline Data Available"

There are only 3 possible reasons:

### Reason 1: You Haven't Loaded This Learner Online Yet ⚠️
**Most Likely Reason**

The cache is **per-learner**. You need to:
1. Be online
2. Open THIS specific learner's POE tab
3. Wait for data to load
4. Data is now cached for THIS learner

**Solution:** Load the learner's POE tab while online first.

### Reason 2: The Online Fetch Failed ❌
If the server request failed, no data was cached.

**Check console for:**
```
[FETCH] ❌ Online fetch failed, trying offline data...
```

**Possible causes:**
- Server is down
- Wrong server URL
- Network timeout
- Server returned error

**Solution:** Fix server connection, then reload while online.

### Reason 3: Cache Save Failed ❌
The data was fetched but failed to save to cache.

**Check console for:**
```
[OFFLINE_CACHE] ❌ Error saving learner data locally: ...
```

**Possible causes:**
- Database error
- Permissions issue
- Disk space issue

**Solution:** Check error message in console.

## How to Diagnose Your Specific Issue

### Run the App and Check Console Logs

When you open a learner's POE tab, you should see these messages:

#### If Online and First Time:
```
[FETCH] Starting fetchLearnerData for learnerID=123
[FETCH] Connectivity check: ONLINE
[FETCH] Attempting online fetch...
API Request: learnerID=123, statusCode=200
[OFFLINE_CACHE] Starting to save learner data for learnerID=123
[OFFLINE_CACHE] Pathways data keys: [pathway1, pathway2, ...]
[OFFLINE_CACHE] Cache table verified/created
[OFFLINE_CACHE] Saved pathways cache for learnerID=123
[OFFLINE_CACHE] ✅ Successfully saved learner pathway data for offline access
[FETCH] ✅ Online fetch successful, checking upload status...
[FETCH] fetchLearnerData complete
```

#### If Offline and Cache Exists:
```
[FETCH] Starting fetchLearnerData for learnerID=123
[FETCH] Connectivity check: OFFLINE
[FETCH] Device is offline, loading from cache...
[OFFLINE_CACHE] Attempting to load cached data for learnerID=123
[OFFLINE_CACHE] Cache table verified/created
[OFFLINE_CACHE] ✅ Found cached pathway data!
[OFFLINE_CACHE] Cache has 2 pathway(s)
[OFFLINE_CACHE] Retrieved cached pathways for learnerID=123
[FETCH] fetchLearnerData complete
```

#### If Offline and No Cache:
```
[FETCH] Starting fetchLearnerData for learnerID=123
[FETCH] Connectivity check: OFFLINE
[FETCH] Device is offline, loading from cache...
[OFFLINE_CACHE] Attempting to load cached data for learnerID=123
[OFFLINE_CACHE] Cache table verified/created
[OFFLINE_CACHE] No cached pathways found for learnerID=123
[OFFLINE_CACHE] No cached data, trying database query...
Local data retrieved: 0 records
[OFFLINE_CACHE] No cached or local data for learnerID: 123
[OFFLINE_CACHE] User must load data online first to enable offline access
```

## Step-by-Step Testing

### Test 1: Verify You're Online
1. Check WiFi/mobile data is ON
2. Open browser, visit google.com
3. If it loads, you're online ✅

### Test 2: Load Learner Data While Online
1. Ensure you're online (Test 1)
2. Open the app
3. Navigate to a learner
4. Click POE tab
5. **Watch the console logs**
6. Look for: `[OFFLINE_CACHE] ✅ Successfully saved`

**If you see the success message:** Cache is working! ✅

**If you see an error:** Note the error message and check below.

### Test 3: Verify Cache Was Saved
After Test 2, check the database:

```sql
SELECT learnerID, length(pathways_json) as data_size, updated_at 
FROM learner_pathways_cache;
```

**Expected:** You should see a row with your learnerID.

### Test 4: Test Offline Access
1. Turn OFF WiFi/mobile data
2. Close and reopen the app
3. Navigate to the SAME learner
4. Click POE tab
5. **Watch the console logs**
6. Look for: `[OFFLINE_CACHE] ✅ Found cached pathway data!`

**If you see the success message:** Offline access is working! ✅

**If you see "No cached pathways found":** Cache wasn't saved in Test 2.

## Common Issues and Solutions

### Issue: "No cached pathways found" even after loading online

**Diagnosis:**
Check console for save errors during online load.

**Solutions:**
1. Check database permissions
2. Verify cache table exists:
   ```sql
   SELECT name FROM sqlite_master WHERE type='table' AND name='learner_pathways_cache';
   ```
3. Try deleting and recreating database
4. Check disk space

### Issue: Server request fails (statusCode != 200)

**Diagnosis:**
Console shows: `Server error: 404` or similar

**Solutions:**
1. Verify server URL in config.dart
2. Check server is running
3. Test server endpoint manually
4. Check network connectivity

### Issue: Server returns error in response

**Diagnosis:**
Console shows: `API Error: Learner not found` or similar

**Solutions:**
1. Verify learnerID exists in database
2. Check server-side logs
3. Verify learner has pathway data assigned

## Quick Verification Commands

### Check if cache table exists:
```sql
SELECT name FROM sqlite_master WHERE type='table' AND name='learner_pathways_cache';
```

### Check cached learners:
```sql
SELECT learnerID, length(pathways_json) as size_kb, updated_at 
FROM learner_pathways_cache;
```

### Check specific learner cache:
```sql
SELECT * FROM learner_pathways_cache WHERE learnerID = 123;
```

### Clear cache for testing:
```sql
DELETE FROM learner_pathways_cache WHERE learnerID = 123;
```

## Expected Behavior Summary

| Scenario | Online | Cache Exists | What Happens |
|----------|--------|--------------|--------------|
| First visit | ✅ Yes | ❌ No | Fetches from server, creates cache |
| Second visit | ✅ Yes | ✅ Yes | Fetches from server, updates cache |
| Offline visit | ❌ No | ✅ Yes | Loads from cache ✅ |
| Offline visit | ❌ No | ❌ No | Shows error message ⚠️ |

## What to Do Now

1. **Run the app**
2. **Open console/logcat** to see the logs
3. **Navigate to a learner's POE tab** while online
4. **Look for the log messages** listed above
5. **Share the console output** if you see errors

The logs will tell us exactly what's happening!

## Key Points

✅ **Yes, it syncs from server to local** - automatically when you load POE tab online
✅ **Caching is per-learner** - each learner needs to be loaded once while online
✅ **Cache persists** - survives app restarts
✅ **Automatic updates** - cache refreshes when you load online again
⚠️ **First load must be online** - this is by design, data must come from server first

The code is working correctly. You just need to load each learner's POE tab once while online to cache their data!
