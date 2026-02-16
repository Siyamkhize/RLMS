# POE Offline Functionality - Testing Guide

## Quick Test Scenarios

### Test 0: Initial Setup (REQUIRED FIRST)
**Objective**: Cache learner data for offline use

**Steps**:
1. Ensure device has internet connection
2. Open the app and navigate to a learner's POE tab
3. Wait for pathway data to load
4. Verify POE exercises are displayed

**Expected Result**:
- Pathway data loads successfully
- Data is cached in `learner_pathways_cache` table
- Console shows: `[OFFLINE_CACHE] Saved learner pathway data for offline access`

**Note**: This step MUST be done once per learner before offline functionality works.

---

### Test 1: Offline POE Scanning
**Objective**: Verify POE documents can be scanned and saved offline

**Prerequisites**: Complete Test 0 first (cache learner data while online)

**Steps**:
1. Turn off WiFi/Mobile data on the device
2. Open the app and navigate to a learner's POE tab
3. Verify pathway data loads from cache (not "No offline data" error)
4. Scan a Formative/Summative/LogBook document
5. Observe the orange "📱 Saved offline" notification
6. Check that the orange banner appears showing "X POE record(s) pending sync"
7. Verify the exercise is marked as completed (green checkmark)

**Expected Result**:
- Cached pathway data loads successfully
- Document saves successfully offline
- Orange notification appears
- Sync banner shows pending count
- Exercise marked as completed locally

---

### Test 2: Automatic Sync on Connectivity
**Objective**: Verify automatic sync when internet is restored

**Steps**:
1. Complete Test 1 (have offline POE records)
2. Turn on WiFi/Mobile data
3. Navigate away from POE tab and back
4. Observe automatic sync process

**Expected Result**:
- Green notification: "✅ Synced X POE record(s) to server"
- Orange banner disappears
- Records marked as synced in database

---

### Test 3: Manual Sync
**Objective**: Verify manual sync button works

**Steps**:
1. Have offline POE records (from Test 1)
2. Turn on internet
3. Click "Sync Now" button in orange banner
4. Observe sync progress indicator
5. Wait for completion

**Expected Result**:
- Progress indicator appears
- Green success notification shows
- Banner disappears after successful sync
- All records uploaded to server

---

### Test 4: Multiple Offline Scans
**Objective**: Verify multiple documents can be saved offline

**Steps**:
1. Turn off internet
2. Scan 3-5 different POE documents (mix of Formative/Summative/LogBook)
3. Check orange banner count increases
4. Turn on internet
5. Trigger sync (automatic or manual)

**Expected Result**:
- All documents saved locally
- Banner shows correct count (e.g., "5 POE record(s) pending sync")
- All documents sync successfully
- Success notification shows correct count

---

### Test 5: Offline with App Restart
**Objective**: Verify offline data persists across app restarts

**Steps**:
1. Turn off internet
2. Scan 2-3 POE documents
3. Note the pending sync count
4. Close the app completely
5. Reopen the app
6. Navigate to POE tab

**Expected Result**:
- Orange banner still shows pending sync count
- Documents still accessible
- Sync works when internet restored

---

### Test 6: Partial Sync Failure
**Objective**: Verify handling of partial sync failures

**Steps**:
1. Have 3+ offline POE records
2. Turn on internet with poor connectivity
3. Trigger sync
4. Observe some succeed, some fail

**Expected Result**:
- Successfully synced records marked as synced
- Failed records remain in queue
- Orange notification shows failed count
- Can retry sync later

---

### Test 7: Scan All Formative Offline
**Objective**: Verify "Scan All Formative" works offline

**Steps**:
1. Turn off internet
2. Click "Scan All Formative Answers" button
3. Scan document
4. Observe all formative questions marked

**Expected Result**:
- All formative questions marked as completed
- Orange banner shows multiple pending syncs
- All records saved locally

---

### Test 8: File Persistence
**Objective**: Verify scanned files are stored persistently

**Steps**:
1. Scan POE document offline
2. Check file location: `/data/data/com.example.rlmss/app_flutter/POE/`
3. Verify file naming: `{type}_{learnerID}_{exercise}_{timestamp}.pdf`
4. Restart app
5. Verify file still exists

**Expected Result**:
- File saved in correct directory
- File name follows convention
- File persists after app restart
- File accessible for sync

---

## Database Verification

### Check Unsynced Records
```sql
SELECT * FROM poe WHERE synced = 0;
```

### Check Synced Records
```sql
SELECT * FROM poe WHERE synced = 1;
```

### Check Specific Learner
```sql
SELECT * FROM poe WHERE learnerID = '123' ORDER BY submitted_at DESC;
```

---

## Common Issues & Solutions

### Issue: Sync button doesn't appear
**Solution**: Ensure there are unsynced records and internet is available

### Issue: "No offline data found" error when offline
**Solution**: 
- Learner data must be loaded once while online first
- Open POE tab while online to cache data
- Check console for: `[OFFLINE_CACHE] Saved learner pathway data`
- Verify `learner_pathways_cache` table has entry for learnerID

### Issue: Documents not syncing
**Solution**: 
- Check internet connectivity
- Verify server is accessible
- Check file paths are valid
- Review console logs for errors

### Issue: Orange banner shows wrong count
**Solution**: 
- Close and reopen POE tab
- Check database for actual unsynced count
- Verify `_updateUnsyncedCount()` is called

### Issue: Files not found during sync
**Solution**:
- Verify files exist in POE directory
- Check file permissions
- Ensure files weren't deleted

---

## Performance Testing

### Test Large Batch Sync
1. Create 20+ offline POE records
2. Sync all at once
3. Monitor:
   - Sync duration
   - Memory usage
   - UI responsiveness
   - Success rate

### Test Concurrent Operations
1. Start sync process
2. Try to scan new document
3. Verify no conflicts or crashes

---

## Edge Cases

### Test: No Internet During Sync
1. Start sync with internet
2. Turn off internet mid-sync
3. Verify graceful handling

### Test: Duplicate Scans
1. Scan same exercise twice offline
2. Verify only one record created
3. Check sync behavior

### Test: Server Rejection
1. Scan document offline
2. Modify server to reject upload
3. Verify error handling
4. Check record remains unsynced

---

## Success Criteria

✅ All POE documents save offline successfully
✅ Sync banner shows accurate pending count
✅ Automatic sync works on connectivity restoration
✅ Manual sync button functions correctly
✅ Files persist across app restarts
✅ Sync handles failures gracefully
✅ UI provides clear feedback
✅ No data loss in any scenario
✅ Performance acceptable with large batches
✅ Database integrity maintained

---

## Logging

Monitor console for these key log messages:

- `[POE_OFFLINE] Document saved to: {path}`
- `[POE_OFFLINE] Saved locally: learnerID={id}, exercise={ex}, type={type}`
- `[POE_SYNC] Found X unsynced POE records`
- `[POE_SYNC] ✅ Synced: {type} - {exercise}`
- `[POE_SYNC] ❌ Upload failed: {error}`
- `[POE_SYNC] Complete: X synced, Y failed`

---

## Rollback Plan

If issues occur:
1. Backup local database
2. Export unsynced POE records
3. Manually upload documents via web interface
4. Update database sync status
5. Restore from backup if needed
