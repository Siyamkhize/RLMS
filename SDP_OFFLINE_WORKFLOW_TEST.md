# SDP Offline Workflow Test Guide

## Test Objective
Verify the complete SDP workflow works offline: **SDP Login → Projects Page → Pathways Page → Admin Page (Sites)**

## Prerequisites
1. App must have been logged in online at least once to cache data
2. Database should contain SDP credentials and site data
3. Device should be able to go offline (airplane mode)

## Test Steps

### Step 1: Verify Database Has Required Data
Run the debug script to confirm data is available:
```bash
php debug_offline_login.php
```

**Expected Results:**
- ✅ SDP table has records (including SDP ID 41)
- ✅ Sites table has records 
- ✅ Learner data available
- ✅ All tables populated

### Step 2: Test Offline Login
1. **Turn on airplane mode** (or disconnect WiFi/mobile data)
2. **Open the app**
3. **Enter credentials:**
   - Email: `infor@jcp.co.za` (for SDP ID 41)
   - Password: [correct password]
4. **Tap Login**
5. **When "No Network Connection" dialog appears, tap "Proceed with offline login"**

**Expected Results:**
- ✅ Login succeeds
- ✅ Navigates to SDP Projects Page
- ✅ Shows "Offline" indicator

### Step 3: Test Projects Page (Offline)
**Current Page:** SDP Projects Page

**Expected Results:**
- ✅ Shows list of projects for SDP 41
- ✅ Should see "EPWP ROADWORKS" project (Project ID 87)
- ✅ Shows "Offline" indicator in header
- ✅ Project cards show pathway and site counts

**Action:** Tap on "EPWP ROADWORKS" project

### Step 4: Test Pathways Page (Offline)
**Current Page:** SDP Learning Pathways Page

**Expected Results:**
- ✅ Shows pathways for the selected project
- ✅ Should see "Short Skills Programme" pathway
- ✅ Shows qualifications under each pathway
- ✅ "View Sites" button available for each pathway

**Action:** Tap "View Sites" button for "Short Skills Programme"

### Step 5: Test Admin Page - Sites (Offline)
**Current Page:** Admin Page (Sites view)

**Expected Results:**
- ✅ Shows sites for the selected project/pathway
- ✅ Should see sites like:
  - Region One Tshwane Soshanguve
  - Region Two Tshwane Hammanskraal  
  - Region Three Tshwane Attridgeville Pretora Central
  - Region Four Tshwane Centurion
  - Region Five Tshwane Refilwe
- ✅ Shows "Offline" indicator in header
- ✅ Search functionality works
- ✅ Site cards show proper information

### Step 6: Test Learner Search (Offline)
**Current Page:** Admin Page

**Action:** Search for learner ID: `8407315291087`

**Expected Results:**
- ✅ Search finds learner "Munni Shendell"
- ✅ Shows project association (Project 87)
- ✅ Displays learner details
- ✅ All functionality works offline

## Debug Information

### If Login Fails:
Check logs for:
```
[ADMIN] sdp Query Result: [...]
[ADMIN] Password verification failed for SDP user
[ADMIN] No SDP user found with email: [email]
```

### If Projects Page is Empty:
Check logs for:
```
[SDP_PROJECTS] ❌ No projects found with sites for SDP [id]
[SDP_PROJECTS] Found 0 projects with sites for SDP [id]
```

### If Sites Page is Empty:
Check logs for:
```
[ADMIN] ❌ No sites found with current filters
[ADMIN] Found 0 sites matching filters
```

## Troubleshooting

### Issue: Login Fails Offline
**Cause:** Wrong credentials or SDP not cached
**Solution:** 
1. Verify email: `infor@jcp.co.za` (not `infor@lusisizwe1.co.za`)
2. Check password is correct
3. Ensure first login was done online

### Issue: No Projects Found
**Cause:** Projects not cached or SDP ID mismatch
**Solution:**
1. Login online first to cache projects
2. Check SDP ID resolution in logs
3. Verify sites table has data for SDP 41

### Issue: No Sites Found
**Cause:** Sites not cached or filtering too strict
**Solution:**
1. Check sites table has data for Project 87
2. Review filtering logic in admin.dart
3. Check pathway name matching

## Success Criteria

✅ **Complete Offline Workflow:**
1. SDP Login works offline
2. Projects page loads from local database
3. Pathways page shows cached pathways
4. Admin page displays sites from local database
5. Learner search works offline
6. All pages show "Offline" indicator
7. Navigation between pages works smoothly

## Current Status

Based on previous investigation:
- ✅ Database has all required data (15,044 learners, 144 sites, etc.)
- ✅ SDP 41 credentials are properly stored
- ✅ Offline login infrastructure is implemented
- ✅ Site loading from local database is implemented
- ✅ Search functionality works offline

**The workflow should work completely offline!**

## Next Steps

1. Test the complete workflow as described above
2. If any step fails, check the debug logs
3. Report specific error messages for troubleshooting
4. Verify all components work together seamlessly

---

**This test verifies the complete SDP offline workflow from login to site management.**