# Pothole Checklist Scanning - Test Script

## Test Environment Setup

### Prerequisites
- [ ] App installed on device
- [ ] Server accessible
- [ ] Database table created
- [ ] PHP files uploaded
- [ ] Upload directory created
- [ ] Test documents ready (physical checklists)

---

## Test Suite 1: Basic Functionality

### Test 1.1: Open Checklist Button Exists
**Steps:**
1. Open app
2. Navigate to Pothole Checklist page
3. Scroll to bottom

**Expected:**
- [ ] "Open Checklist" button visible
- [ ] Button is orange color
- [ ] Button has folder icon

**Status:** ⬜ Pass ⬜ Fail

---

### Test 1.2: No Existing Checklist
**Steps:**
1. Click "Open Checklist" button
2. Wait for dialog

**Expected:**
- [ ] Dialog shows "Create Checklist"
- [ ] Two options visible: "Scan Document" and "Fill Form"
- [ ] Cancel button visible

**Status:** ⬜ Pass ⬜ Fail

---

### Test 1.3: Scan Document (Online)
**Steps:**
1. Ensure internet connected
2. Click "Open Checklist"
3. Click "Scan Document"
4. Take photo of test checklist
5. Confirm scan

**Expected:**
- [ ] Camera opens
- [ ] Can capture document
- [ ] Success message appears
- [ ] Document saved

**Status:** ⬜ Pass ⬜ Fail

**Notes:** _________________

---

### Test 1.4: View Scanned Document
**Steps:**
1. After scanning (Test 1.3)
2. Click "Open Checklist" again
3. Click "View Checklist"

**Expected:**
- [ ] Dialog shows "Checklist Found"
- [ ] Type is "scanned"
- [ ] Document opens in viewer
- [ ] Can view full document

**Status:** ⬜ Pass ⬜ Fail

---

## Test Suite 2: Offline Functionality

### Test 2.1: Scan Document (Offline)
**Steps:**
1. Turn OFF WiFi and mobile data
2. Navigate to Pothole Checklist page
3. Click "Open Checklist"
4. Click "Scan Document"
5. Scan test document

**Expected:**
- [ ] Scanner works without internet
- [ ] Document saved locally
- [ ] Success message appears
- [ ] No error about connection

**Status:** ⬜ Pass ⬜ Fail

---

### Test 2.2: View Offline Scanned Document
**Steps:**
1. Still offline (from Test 2.1)
2. Click "Open Checklist"
3. Click "View Checklist"

**Expected:**
- [ ] Document found in local database
- [ ] Opens without internet
- [ ] Full document visible

**Status:** ⬜ Pass ⬜ Fail

---

### Test 2.3: Auto-Sync When Online
**Steps:**
1. Turn ON WiFi/mobile data
2. Wait 30 seconds
3. Check server uploads folder

**Expected:**
- [ ] Document automatically uploaded
- [ ] File exists in server folder
- [ ] Database record created on server
- [ ] Local record marked as synced

**Status:** ⬜ Pass ⬜ Fail

**Server Check:**
```bash
ls -lh uploads/pothole_checklists/
mysql -u root -p -e "SELECT * FROM rlms.pothole_checklist_scanned_documents ORDER BY created_at DESC LIMIT 1;"
```

---

## Test Suite 3: Form-Based Checklist

### Test 3.1: Fill Form
**Steps:**
1. Click "Open Checklist"
2. Click "Fill Form"
3. Complete all checklist items
4. Sign both signatures
5. Click "Save Checklist"

**Expected:**
- [ ] Form remains on screen
- [ ] Can fill all fields
- [ ] Signatures work
- [ ] Save successful
- [ ] Success message appears

**Status:** ⬜ Pass ⬜ Fail

---

### Test 3.2: View System Checklist
**Steps:**
1. After saving (Test 3.1)
2. Click "Open Checklist"
3. Observe dialog

**Expected:**
- [ ] Dialog shows "Checklist Found"
- [ ] Type is "system"
- [ ] Click "View Checklist" loads form data
- [ ] All fields populated correctly

**Status:** ⬜ Pass ⬜ Fail

---

## Test Suite 4: Edge Cases

### Test 4.1: Multiple Scans Same Learner
**Steps:**
1. Scan document for learner A
2. Scan another document for same learner A
3. Click "Open Checklist"

**Expected:**
- [ ] Shows most recent scan
- [ ] Old scan replaced/updated
- [ ] No duplicate records

**Status:** ⬜ Pass ⬜ Fail

---

### Test 4.2: Different Dates
**Steps:**
1. Scan document for today
2. Change date to tomorrow
3. Click "Open Checklist"

**Expected:**
- [ ] Shows "no checklist" for tomorrow
- [ ] Can create new checklist for tomorrow
- [ ] Today's checklist still accessible

**Status:** ⬜ Pass ⬜ Fail

---

### Test 4.3: Cancel Operations
**Steps:**
1. Click "Open Checklist"
2. Click "Cancel"
3. Try again with "Scan Document"
4. Cancel during scan

**Expected:**
- [ ] Dialog closes properly
- [ ] No errors
- [ ] Can retry
- [ ] Scanner cancels cleanly

**Status:** ⬜ Pass ⬜ Fail

---

### Test 4.4: Large Document
**Steps:**
1. Scan a multi-page document (if possible)
2. Wait for upload

**Expected:**
- [ ] Handles large files
- [ ] Upload completes
- [ ] No timeout errors
- [ ] Document viewable

**Status:** ⬜ Pass ⬜ Fail

---

## Test Suite 5: Error Handling

### Test 5.1: No Camera Permission
**Steps:**
1. Deny camera permission
2. Try to scan document

**Expected:**
- [ ] Clear error message
- [ ] Prompts for permission
- [ ] Doesn't crash

**Status:** ⬜ Pass ⬜ Fail

---

### Test 5.2: Server Unreachable
**Steps:**
1. Block server in firewall (or use wrong URL)
2. Try to scan document
3. Check local storage

**Expected:**
- [ ] Document saved locally
- [ ] No crash
- [ ] User can continue
- [ ] Will sync later

**Status:** ⬜ Pass ⬜ Fail

---

### Test 5.3: Disk Full
**Steps:**
1. Fill device storage (if possible)
2. Try to scan document

**Expected:**
- [ ] Clear error message
- [ ] Doesn't crash
- [ ] Prompts to free space

**Status:** ⬜ Pass ⬜ Fail

---

## Test Suite 6: Performance

### Test 6.1: Scan Speed
**Steps:**
1. Time from clicking "Scan Document" to success message

**Expected:**
- [ ] Scanner opens < 2 seconds
- [ ] Scan completes < 5 seconds
- [ ] Save completes < 3 seconds
- [ ] Total < 10 seconds

**Actual Time:** _______ seconds

**Status:** ⬜ Pass ⬜ Fail

---

### Test 6.2: View Speed
**Steps:**
1. Time from clicking "View Checklist" to document visible

**Expected:**
- [ ] Opens < 2 seconds
- [ ] Smooth scrolling
- [ ] No lag

**Actual Time:** _______ seconds

**Status:** ⬜ Pass ⬜ Fail

---

### Test 6.3: Multiple Documents
**Steps:**
1. Scan 10 different documents
2. Check app performance

**Expected:**
- [ ] No slowdown
- [ ] All documents accessible
- [ ] Database queries fast

**Status:** ⬜ Pass ⬜ Fail

---

## Test Suite 7: Data Integrity

### Test 7.1: Correct Learner Association
**Steps:**
1. Scan document for learner A
2. Check database

**Expected:**
- [ ] Correct learner_id stored
- [ ] Correct assessor_id stored
- [ ] Correct date stored

**Database Check:**
```sql
SELECT learner_id, assessor_id, assessment_date 
FROM pothole_checklist_scanned_documents 
WHERE id = LAST_INSERT_ID();
```

**Status:** ⬜ Pass ⬜ Fail

---

### Test 7.2: File Integrity
**Steps:**
1. Scan document
2. Download from server
3. Compare with original

**Expected:**
- [ ] File not corrupted
- [ ] Readable on computer
- [ ] Same content as scanned

**Status:** ⬜ Pass ⬜ Fail

---

### Test 7.3: Sync Status Accuracy
**Steps:**
1. Scan offline
2. Check local database (synced = 0)
3. Go online and wait
4. Check local database (synced = 1)

**Expected:**
- [ ] Initially synced = 0
- [ ] After sync synced = 1
- [ ] Status accurate

**Status:** ⬜ Pass ⬜ Fail

---

## Test Suite 8: User Experience

### Test 8.1: Clear Instructions
**Steps:**
1. Give device to new user
2. Ask them to scan a checklist
3. Observe

**Expected:**
- [ ] User understands buttons
- [ ] Completes task without help
- [ ] No confusion

**User Feedback:** _________________

**Status:** ⬜ Pass ⬜ Fail

---

### Test 8.2: Error Messages
**Steps:**
1. Trigger various errors
2. Read error messages

**Expected:**
- [ ] Messages in plain language
- [ ] Actionable advice given
- [ ] Not technical jargon

**Status:** ⬜ Pass ⬜ Fail

---

### Test 8.3: Loading Indicators
**Steps:**
1. Click "Open Checklist"
2. Observe during check

**Expected:**
- [ ] Shows "Checking..." text
- [ ] Button disabled during check
- [ ] Clear feedback

**Status:** ⬜ Pass ⬜ Fail

---

## Test Summary

### Overall Results
- Total Tests: 28
- Passed: _____
- Failed: _____
- Skipped: _____

### Critical Issues Found
1. _________________
2. _________________
3. _________________

### Minor Issues Found
1. _________________
2. _________________
3. _________________

### Recommendations
1. _________________
2. _________________
3. _________________

---

## Sign-Off

**Tested By:** _________________
**Date:** _________________
**Environment:** _________________
**App Version:** _________________
**Server Version:** _________________

**Overall Status:** ⬜ Ready for Production ⬜ Needs Fixes ⬜ Major Issues

**Approved By:** _________________
**Date:** _________________

---

## Notes

_Use this space for additional observations, screenshots, or comments_

_________________
_________________
_________________
_________________
_________________
