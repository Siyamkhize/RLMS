# Quick Fix: Pothole Moderation Per-Unit-Standard

## Problem Summary
1. ✅ **FIXED**: Both checklists not showing after uploading view_pothole_checklists.php
2. ⚠️ **NEEDS DATA**: Empty recordId causing "Missing required fields" error

## What Was Fixed

### Issue 1: Checklists Not Showing
**Cause 1**: File used `require_once 'config.php';` but config.php doesn't exist
**Fix 1**: Changed to `require_once 'connection.php';`

**Cause 2**: SQL query tried to SELECT `unit_standard_name` column which doesn't exist in `logbook_marks` table
**Fix 2**: Removed `unit_standard_name` from SELECT and generate it dynamically instead

**File**: `view_pothole_checklists.php`

## What Needs Attention

### Issue 2: Empty Record ID
**Error in logs**:
```
[Pothole Moderation] Record ID: , Status: upheld
Response: {"status":"error","message":"Missing required fields"}
```

**Cause**: The `id` field from `logbook_marks` table is empty because marks haven't been saved yet.

**Solution**: The assessor must save marks for the pothole checklist BEFORE the moderator can moderate.

## How It Should Work

### Step 1: Assessor Saves Marks
1. Assessor opens pothole checklist for a learner
2. Assessor enters marks for Unit Standard 13958
3. Assessor enters marks for Unit Standard 14555
4. Assessor saves the marks
5. Marks are stored in `logbook_marks` table with an auto-increment `id`

### Step 2: Moderator Moderates
1. Moderator opens the same learner's pothole checklist
2. System fetches marks from `logbook_marks` table
3. Each unit standard shows with its marks and a dropdown
4. Moderator selects "Uphold" or "Withdraw" for EACH unit standard
5. System sends the `id` from logbook_marks as `exerciseId`
6. Moderation is saved

## Files Created/Modified

### Modified:
- ✅ `view_pothole_checklists.php` - Fixed connection issue

### Created:
- 📝 `test_pothole_unit_standards.php` - Test if marks exist
- 📝 `POTHOLE_MODERATION_PER_UNIT_STANDARD_FIX.md` - Detailed documentation
- 📝 `DEPLOY_POTHOLE_MODERATION_FIX.bat` - Deployment helper

## Deployment Steps

### 1. Upload Fixed File
Upload `view_pothole_checklists.php` to:
```
https://rlms.rlms.co.za/mobile/view_pothole_checklists.php
```

### 2. Upload Test File
Upload `test_pothole_unit_standards.php` to:
```
https://rlms.rlms.co.za/mobile/test_pothole_unit_standards.php
```

### 3. Test Checklist Display
Open in browser:
```
https://rlms.rlms.co.za/mobile/view_pothole_checklists.php?learner_id=YOUR_LEARNER_ID
```

Should return JSON with `unit_standards` array.

### 4. Check If Marks Exist
Open in browser:
```
https://rlms.rlms.co.za/mobile/test_pothole_unit_standards.php?learner_id=YOUR_LEARNER_ID
```

This will show:
- ✅ If marks records exist
- ✅ The `id` field value (this is the recordId)
- ✅ Current moderation status

### 5. Test in App

**If marks exist**:
1. Open app as moderator
2. Navigate to learner's pothole checklist
3. Select Uphold or Withdraw for a unit standard
4. Should save successfully

**If no marks exist**:
1. Open app as assessor
2. Navigate to learner's pothole checklist
3. Enter marks for both unit standards
4. Save marks
5. Then moderator can moderate

## Quick Diagnosis

### Checklists not showing?
→ Upload fixed `view_pothole_checklists.php`

### "Missing required fields" error?
→ Run `test_pothole_unit_standards.php` to check if marks exist
→ If no marks: Assessor needs to save marks first
→ If marks exist but id is NULL: Database schema issue

### Moderation not saving?
→ Check if `exerciseId` is being sent (should be the id from logbook_marks)
→ Verify `moderate_marks.php` is receiving the request
→ Check database has moderation columns

## Database Requirements

The `logbook_marks` table must have:
```sql
- id (PRIMARY KEY, AUTO_INCREMENT) ← This is the recordId
- learner_id
- unit_standard_id
- marks
- moderator_status
- moderator_comment
- moderator_id
- moderation_date
```

If moderation columns are missing, run:
```sql
ALTER TABLE logbook_marks 
ADD COLUMN moderator_status VARCHAR(20),
ADD COLUMN moderator_comment TEXT,
ADD COLUMN moderator_id VARCHAR(50),
ADD COLUMN moderation_date DATETIME;
```

## Summary

✅ **Fixed**: view_pothole_checklists.php connection issue
✅ **Created**: Test file to check if marks exist
⚠️ **Action Required**: Verify marks exist in database before testing moderation
📝 **Documentation**: Complete guide in POTHOLE_MODERATION_PER_UNIT_STANDARD_FIX.md

The system is ready, but needs marks data to be saved by assessor first!
