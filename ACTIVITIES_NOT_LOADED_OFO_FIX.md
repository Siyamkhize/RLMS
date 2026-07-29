# ACTIVITIES NOT LOADED OFO:NULL FIX

## PROBLEM SUMMARY
User reports: "Activities not loaded OFO:null" for Appendix B, D, and E when opening Complete Toolkit viewer.

## ROOT CAUSE IDENTIFIED

### The Issue
1. **Class 797 has OFO stored in `Project_pathway` JSON**: `641201` (Bricklayer)
2. **BUT `get_class_trade_info.php` was ONLY checking `arpl_trades` table via `class.trade_id` JOIN**
3. **Class 797's `trade_id` does NOT link to correct record in `arpl_trades` table**
4. **Result**: Endpoint returns NULL or default fallback (671101) instead of actual OFO
5. **Flutter app receives wrong/null OFO** → Cannot query activities → Shows "Activities not loaded OFO:null"

### The Flow
```
User selects candidate
    ↓
ViewCompleteToolkitPage dropdown onChange
    ↓
Calls _fetchOfoForClass(classId)
    ↓
HTTP POST to get_class_trade_info.php
    ↓
Endpoint does: class → JOIN arpl_trades ON trade_id
    ↓
Returns NULL (because trade_id not linked correctly)
    ↓
App sets _selectedOfoNumber = null
    ↓
Opens Complete Toolkit with ofoNumber=null
    ↓
Activities query WHERE ofo_number = null (finds nothing)
    ↓
Shows: "Activities not loaded OFO:null"
```

## SOLUTION APPLIED

### Modified File: `mobile/get_class_trade_info.php`

**Change**: Added fallback to read OFO from `Project_pathway` JSON when `arpl_trades` JOIN returns NULL

**Logic Flow**:
1. Try to get OFO from `arpl_trades` table (via `trade_id` JOIN)
2. **NEW**: If NULL, parse `Project_pathway` JSON and extract `ofo_code`
3. If still NULL, use default fallback (671101)

**Code Changes**:
```php
// OLD: Only checked arpl_trades
$ofo = $classData['ofo_number'] ?? '671101';

// NEW: Checks arpl_trades, then Project_pathway, then fallback
$ofo = $classData['ofo_number'] ?? null;
$trade = $classData['trade_name'] ?? null;

// Fallback to Project_pathway JSON
if (empty($ofo) && !empty($classData['Project_pathway'])) {
    try {
        $pathway = json_decode($classData['Project_pathway'], true);
        if ($pathway && is_array($pathway) && isset($pathway[0]['ofo_code'])) {
            $ofo = $pathway[0]['ofo_code'];
            $trade = $pathway[0]['name'] ?? $trade;
        }
    } catch (Exception $e) {
        // JSON decode failed, continue with fallback
    }
}

// Final fallback
if (empty($ofo)) {
    $ofo = '671101';
    $trade = $trade ?? 'Electrician';
}
```

## FILES MODIFIED
- ✅ `mobile/get_class_trade_info.php` - Added Project_pathway fallback

## FILES CREATED (FOR TESTING)
- 📝 `mobile/test_class_797_ofo.php` - Diagnostic to show OFO from all sources
- 📝 `mobile/test_get_class_trade_info_fixed.php` - Test fixed endpoint
- 📝 `mobile/diagnose_arpl_complete_flow.php` - Complete flow diagnostic (ALREADY UPLOADED)

## UPLOAD INSTRUCTIONS

### Step 1: Upload Fixed Endpoint
```bash
# Upload to ONLINE server
FTP/cPanel File Manager:
- Upload: mobile/get_class_trade_info.php
- Destination: /home/rlmsrlmsco/public_html/mobile/
```

### Step 2: Test Fixed Endpoint
```
URL: https://rlms.rlms.co.za/mobile/test_get_class_trade_info_fixed.php

Expected Result:
✅ OFO Number: 641201
✅ Trade Name: Bricklayer
```

### Step 3: Test Complete Flow
```
URL: https://rlms.rlms.co.za/mobile/diagnose_arpl_complete_flow.php

Expected Results:
✅ Test 1: Class has OFO: 641201
✅ Test 3: Activities tables exist
✅ Test 4: Found XX activities for OFO 641201
✅ Test 6: Ratings table has ofo_number column
```

### Step 4: Test in App
1. Open ARPL Assessor app
2. Login as Facilitator 6 (arpl_Assessor role)
3. Go to: View Complete Toolkit
4. Select candidate: Anele Cele
5. Check OFO displays: "641201" (not "Not Set" or null)
6. Click "Open Complete Toolkit"
7. **EXPECTED**: Activities load successfully for all appendices (B, D, E)

## VERIFICATION CHECKLIST

### Before Fix
- [ ] Appendix B shows: "Activities not loaded OFO:null"
- [ ] Appendix D shows: "Activities not loaded OFO:null"
- [ ] Appendix E shows: "Activities not loaded OFO:null"
- [ ] OFO field in Complete Toolkit shows: "Not Set"

### After Fix
- [ ] `test_get_class_trade_info_fixed.php` returns OFO: 641201
- [ ] `diagnose_arpl_complete_flow.php` shows activities found
- [ ] Complete Toolkit dropdown shows OFO: 641201
- [ ] Appendix B loads activities successfully
- [ ] Appendix D loads activities successfully
- [ ] Appendix E loads activities successfully

## REMAINING ISSUES TO ADDRESS

### Issue 1: Save Endpoints Return 404
**Status**: Still needs to be fixed
**Files**: `save_arpl_appendix_b.php`, `save_arpl_appendix_d.php`, `save_arpl_appendix_e.php`
**Next Step**: Verify these files exist on server, upload if missing

### Issue 2: Database Schema - Missing ofo_number Column
**Status**: Needs verification on ONLINE server
**Table**: `arplappxb_activity_ratings`
**Issue**: May be missing `ofo_number` column
**SQL to Check**:
```sql
DESCRIBE arplappxb_activity_ratings;
```
**SQL to Fix** (if column missing):
```sql
ALTER TABLE arplappxb_activity_ratings 
ADD COLUMN ofo_number VARCHAR(20) AFTER learnerID;
```

### Issue 3: Appendix B Save Timeout
**Status**: Fixed locally, needs upload
**File**: `mobile/save_arpl_appendix_b.php`
**Fix**: Optimized from 312 queries to 104 queries using INSERT...ON DUPLICATE KEY UPDATE
**Depends On**: ofo_number column must exist first

## TEST DATA REFERENCE
- **Facilitator**: ID 6, Role: arpl_Assessor
- **Class**: 797, Name: Bricklaying class
- **Learner**: Anele Cele, ID: 9201151070088, LearnerID: 11701
- **OFO**: 641201 (Bricklayer)
- **Trade**: Bricklayer

## TROUBLESHOOTING

### If Activities Still Don't Load After Fix

1. **Check diagnostic output**:
   ```
   https://rlms.rlms.co.za/mobile/diagnose_arpl_complete_flow.php
   ```
   Look for:
   - ✅ Class has OFO in Project_pathway
   - ✅ Activities tables exist (arplappxb_bricklaying_activities, etc.)
   - ✅ Activities exist for OFO 641201

2. **Check if activities table is empty**:
   ```sql
   SELECT COUNT(*) FROM arplappxb_bricklaying_activities WHERE ofo_number = '641201';
   ```
   If 0: Need to populate activities table with Bricklayer activities

3. **Check app logs**:
   - Look for `[TOOLKIT_DEBUG]` messages
   - Verify `_selectedOfoNumber` is being set correctly
   - Check HTTP response from `get_class_trade_info.php`

### If Save Still Returns 404

1. **Verify files exist on server**:
   ```
   https://rlms.rlms.co.za/mobile/save_arpl_appendix_b.php
   https://rlms.rlms.co.za/mobile/save_arpl_appendix_d.php
   https://rlms.rlms.co.za/mobile/save_arpl_appendix_e.php
   ```

2. **Check file permissions**: Should be 644 or 755

3. **Check Apache error logs** for PHP errors

## PRIORITY ORDER

### IMMEDIATE (Blocking all functionality)
1. ✅ Fix `get_class_trade_info.php` - **DONE**
2. ⏳ Upload fixed file to server - **NEXT**
3. ⏳ Test endpoint returns correct OFO - **NEXT**
4. ⏳ Test app loads activities - **NEXT**

### HIGH (Blocking save functionality)
5. ⏳ Verify save endpoints exist on server
6. ⏳ Check database schema for ofo_number column
7. ⏳ Add column if missing
8. ⏳ Upload optimized save endpoints

### MEDIUM (Performance improvement)
9. ⏳ Add UNIQUE KEY constraint to prevent duplicates
10. ⏳ Test complete save flow

## SUCCESS CRITERIA
- [ ] Activities load for all appendices (B, D, E)
- [ ] OFO displays correctly (641201)
- [ ] Can view complete toolkit without errors
- [ ] Can save ratings without 404 errors
- [ ] Save completes within 5 seconds (not 30+ seconds)

## NOTES
- The fix is **server-side only** - no app rebuild required
- Once uploaded, changes take effect immediately
- No user data will be affected by this fix
- Backward compatible with classes that DO have correct trade_id links

---
**Date**: 2026-07-15
**Status**: Fix ready for upload and testing
**Next Action**: User must upload `get_class_trade_info.php` and test
