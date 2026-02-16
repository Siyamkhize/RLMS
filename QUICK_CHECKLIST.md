# Quick Checklist - Getting Offline POE to Work

## ✅ Step-by-Step Checklist

### Step 1: Verify Setup
- [ ] App is installed and running
- [ ] You can see the POE tab
- [ ] Console/logcat is visible (to see debug messages)

### Step 2: Go Online
- [ ] Turn ON WiFi or mobile data
- [ ] Verify internet works (open browser, visit google.com)
- [ ] App can reach server (check config.dart for server URL)

### Step 3: Load Learner Data (CRITICAL!)
- [ ] Open the app
- [ ] Navigate to a learner (any learner)
- [ ] Click on the **POE tab**
- [ ] Wait for pathway data to load (you should see unit standards, formative, summative)
- [ ] Check console for: `[OFFLINE_CACHE] ✅ Successfully saved learner pathway data`

**If you see the success message:** ✅ Cache is working! Continue to Step 4.

**If you see an error or no message:** ❌ Something went wrong. Check console for errors.

### Step 4: Test Offline Access
- [ ] Turn OFF WiFi and mobile data
- [ ] Close the app completely
- [ ] Reopen the app
- [ ] Navigate to the SAME learner you loaded in Step 3
- [ ] Click on the POE tab
- [ ] Check console for: `[OFFLINE_CACHE] ✅ Found cached pathway data!`

**If you see the success message:** 🎉 Offline POE is working!

**If you see "No cached pathways found":** The cache wasn't saved in Step 3.

### Step 5: Scan POE Offline
- [ ] Still offline from Step 4
- [ ] Try to scan a POE document (Formative/Summative/LogBook)
- [ ] You should see orange notification: "📱 Saved offline"
- [ ] Orange banner should appear showing pending sync count

### Step 6: Sync When Back Online
- [ ] Turn WiFi/mobile data back ON
- [ ] Open the POE tab
- [ ] Click "Sync Now" button or wait for automatic sync
- [ ] You should see green notification: "✅ Synced X POE record(s)"

## 🔍 What to Look For in Console

### When Loading Online (Step 3):
```
[FETCH] Connectivity check: ONLINE
[FETCH] Attempting online fetch...
[OFFLINE_CACHE] Starting to save learner data
[OFFLINE_CACHE] ✅ Successfully saved learner pathway data
```

### When Loading Offline (Step 4):
```
[FETCH] Connectivity check: OFFLINE
[OFFLINE_CACHE] Attempting to load cached data
[OFFLINE_CACHE] ✅ Found cached pathway data!
```

### When Scanning Offline (Step 5):
```
[POE_OFFLINE] Document saved to: /path/to/file
[POE_OFFLINE] Saved locally: learnerID=123, exercise=Q1, type=Formative
```

### When Syncing (Step 6):
```
[POE_SYNC] Found X unsynced POE records
[POE_SYNC] ✅ Synced: Formative - Q1
[POE_SYNC] Complete: X synced, 0 failed
```

## ❌ Common Mistakes

### Mistake 1: Testing with Different Learner
❌ Load Learner A online, then test offline with Learner B
✅ Load Learner A online, then test offline with Learner A

**Why:** Cache is per-learner. Each learner needs to be loaded online once.

### Mistake 2: Not Waiting for Data to Load
❌ Open POE tab, immediately go offline
✅ Open POE tab, wait for data to fully load, THEN go offline

**Why:** Cache is saved AFTER data loads from server.

### Mistake 3: Expecting Offline to Work Without Online First
❌ Never load online, expect offline to work
✅ Load online first, then offline works

**Why:** Data must come from server first. Can't cache what doesn't exist.

## 🐛 Troubleshooting

### Problem: No success message in Step 3

**Check:**
1. Are you actually online? (Test with browser)
2. Is server URL correct? (Check config.dart)
3. Does server respond? (Check server logs)
4. Any errors in console? (Read the error message)

**Solution:** Fix the issue preventing online fetch, then retry Step 3.

### Problem: "No cached pathways found" in Step 4

**Check:**
1. Did you see success message in Step 3?
2. Are you testing with the SAME learner?
3. Did you wait for data to load in Step 3?

**Solution:** Repeat Step 3, ensure you see success message.

### Problem: Can't scan offline in Step 5

**Check:**
1. Did Step 4 work? (Cache must load first)
2. Are you trying to scan the first exercise in sequence?
3. Any errors in console?

**Solution:** Ensure cache loaded successfully in Step 4.

## 📊 Success Criteria

You know it's working when:

✅ Step 3: See `[OFFLINE_CACHE] ✅ Successfully saved`
✅ Step 4: See `[OFFLINE_CACHE] ✅ Found cached pathway data!`
✅ Step 5: Can scan POE documents offline
✅ Step 6: Documents sync when back online

## 🎯 Bottom Line

**The offline POE functionality DOES sync from server to local.**

It happens automatically in Step 3 when you load the POE tab while online.

If you're seeing "No offline data available", it means you haven't completed Step 3 for that specific learner yet.

**Just load the learner's POE tab once while online, and offline access will work!**
