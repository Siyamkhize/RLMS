# NEXT STEPS - Action Plan
**Date: July 23, 2026**

---

## 🎯 PRIORITY 1: Upload ARPL Hierarchy Fix

### Issue
- Frontend AppBar shows correct trade "Bricklayer" ✅
- But breakdown page (cards) shows hardcoded "Electrician" ❌
- Root cause: `get_arpl_hierarchy.php` was defaulting to Electrician

### Fix Applied
- File: `mobile/get_arpl_hierarchy.php`
- Changed query to JOIN `class` with `arpl_trades` table via `trade_id`
- Gets `trade_name` and `ofo_number` directly from database
- Only defaults to Electrician if JOIN returns no results

### ACTION REQUIRED:
1. **Upload `mobile/get_arpl_hierarchy.php` to server**
2. **Test workflow:**
   - Login as ARPL Assessor (user with Bricklayer class)
   - Go to ARPL Portfolio page
   - Click on a learner to view ARPL breakdown
   - **Expected:** Card should show "Bricklayer" not "Electrician"
3. **Check logs:** 
   ```bash
   adb logcat | findstr ARPL
   ```
   Should show: `"From arpl_trades table - Trade: Bricklayer"`

### Database Architecture Note:
```sql
-- class table has trade_id (foreign key)
-- arpl_trades table has: trade_id, trade_name, ofo_number
-- Always JOIN to get dynamic trade info

SELECT 
    c.*,
    t.trade_name,
    t.ofo_number
FROM class c
LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
WHERE c.classID = ?
```

---

## 🎯 PRIORITY 2: Upload Sick Note Feature

### Backend Files Ready:
1. `mobile/get_sick_note_eligible_dates.php` ✅
   - Eligibility gate (first-time learner check)
   - Last 5 working days logic
   - SA public holidays handling
   - Fixed ALL column names: `LearnerID`, `clock_date`, `status = 'Approved'`

2. `mobile/submit_sick_note.php` ✅
   - Server-side validation
   - PDF upload handling
   - Fixed ALL column names

### Frontend Complete:
- `lib/sick_note_page.dart` ✅
- `lib/config.dart` with endpoints ✅

### ACTION REQUIRED:
1. **Upload both PHP files to server:**
   - `mobile/get_sick_note_eligible_dates.php`
   - `mobile/submit_sick_note.php`

2. **Test workflow:**
   - Login as learner with clocking history
   - Navigate to Sick Note page
   - Check eligible dates display
   - Try uploading a PDF sick note
   - Verify validation works (first-time learner rejection, date validation, etc.)

### Database Schema (Confirmed):
```sql
-- learner_clocking table
- LearnerID (PascalCase, not learner_id)
- clock_date (not timestamp)

-- manual_clocking table  
- LearnerID (PascalCase)
- clock_date (not date)
- status ENUM('Pending','Approved','Declined')

-- sick_note table
- note_id, learner_id, document_path
- practice_name, practitioner_name
- date_from, date_to, upload_date
- status ENUM('PENDING','APPROVED','Declined')
- rejection_reason
```

---

## 📋 Testing Checklist

### ARPL Hierarchy Fix:
- [ ] Upload `mobile/get_arpl_hierarchy.php`
- [ ] Clear app cache or rebuild APK
- [ ] Login as ARPL Assessor
- [ ] Navigate to Bricklayer class
- [ ] Click learner → view ARPL breakdown
- [ ] Verify card shows "Bricklayer" not "Electrician"
- [ ] Check logcat for "From arpl_trades table - Trade: Bricklayer"

### Sick Note Feature:
- [ ] Upload `mobile/get_sick_note_eligible_dates.php`
- [ ] Upload `mobile/submit_sick_note.php`
- [ ] Create `uploads/sick_notes/` directory on server (with 755 permissions)
- [ ] Test with first-time learner (should be rejected)
- [ ] Test with existing learner (should see eligible dates)
- [ ] Test uploading PDF sick note
- [ ] Verify record saved to `sick_note` table with status='PENDING'

---

## 🔍 User Logs Reference

**Last logs from user (July 23, 2026 11:53):**
```
[POE_SYNC] Found 0 unsynced POE records for learnerID=11701
[CONFIG] Base URL: https://rlms.rlms.co.za/mobile
[ARPL_TRADE] ✅ Trade name: Bricklayer
Local uploadedExercises: {}
```

**Analysis:**
- ✅ Frontend correctly fetching "Bricklayer" from `get_class_trade_info.php`
- ❌ But breakdown page still showing "Electrician" (needs backend fix upload)

---

## 📝 Critical Database Column Names

**ALWAYS USE PascalCase for ID columns:**
- `learnerdetails.LearnerID` (NOT learner_id)
- `learner_clocking.LearnerID` (NOT learner_id)
- `manual_clocking.LearnerID` (NOT learner_id)
- `class.classID`, `class.trade_id`, `class.siteID`
- `arpl_trades.trade_id`, `arpl_trades.trade_name`, `arpl_trades.ofo_number`

**Date columns:**
- `learner_clocking.clock_date` (NOT timestamp)
- `manual_clocking.clock_date` (NOT date)

**Status columns:**
- `manual_clocking.status` = ENUM('Pending', 'Approved', 'Declined')
- `sick_note.status` = ENUM('PENDING', 'APPROVED', 'Declined')

---

## 🚀 After Successful Upload

**If ARPL hierarchy still shows wrong trade after upload:**
1. Check server PHP error logs
2. Verify `arpl_trades` table has correct data:
   ```sql
   SELECT * FROM arpl_trades;
   ```
3. Verify class has correct `trade_id`:
   ```sql
   SELECT classID, className, trade_id FROM class WHERE classID = 797;
   ```

**If sick note upload fails:**
1. Check server has `uploads/sick_notes/` directory
2. Check directory permissions (755)
3. Check PHP `upload_max_filesize` and `post_max_size` settings
4. Check database connection in `submit_sick_note.php`

---

## ✅ Status: Ready for Upload & Testing

All code changes are complete. Need to:
1. Upload files to server
2. Test on device
3. Confirm fixes work as expected
