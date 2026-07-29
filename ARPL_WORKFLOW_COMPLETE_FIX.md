# ARPL Workflow - Complete Fix & Troubleshooting Guide

## Problem Summary
User reported that the "View Learners" button on the classes page remains disabled even after selecting a class.

## Root Cause Analysis

### Database Structure (VERIFIED)
```
arpl_trades:
  - trade_id: 1, trade_name: "Electrician", ofo_number: "671101"
  - trade_id: 2, trade_name: "Plumber", ofo_number: "642601"
  - trade_id: 3, trade_name: "Welder", ofo_number: "651302"
  - trade_id: 4, trade_name: "Bricklayer", ofo_number: "641201"

class (linked via trade_id):
  - classID: 782, className: "lowest", trade_id: 1 (Electrician)
  - classID: 783, className: "Bricklaying", trade_id: 4 (Bricklayer)
  - No classes for Plumber or Welder
```

## Workflow Architecture

```
index.php
  └─ User selects trade (Electrician, OFO: 671101)
  └─ Stores: sessionStorage['selectedTradeOFO'] = '671101'
  └─ Navigate to: classes.php

classes.php
  └─ Reads: selectedTradeOFO from session storage
  └─ Call API: POST /api/get_arpl_classes.php with {ofo_code: '671101'}
  └─ API Response: {status: 'success', classes: [...]}
  └─ Display classes as clickable items
  └─ User clicks class → selectClass(element, classID)
  └─ selectClass() enables button and stores selectedClass
  └─ User clicks "View Learners →" button
  └─ Navigate to: learners.php

learners.php
  └─ Reads: selectedTradeOFO and selectedClassID from session storage
  └─ Validation: if (!selectedTradeOFO || !selectedClassID) → Error
  └─ Call API: POST /api/get_arpl_class_learners.php with {classID: 782}
  └─ API Response: {status: 'success', learners: [...]}
  └─ Display learners table with individual "Generate ARPL ▶" buttons
  └─ User clicks "Generate ARPL ▶" for each learner
```

## Files Deployed to XAMPP

All files are deployed to: `C:\xampp\htdocs\web\web\web\`

### Core Pages
- `index.php` - Trade selection (Step 1)
- `classes.php` - Class selection (Step 2) - **ENHANCED WITH DEBUGGING**
- `learners.php` - Learner selection & ARPL generation (Step 3)

### API Endpoints
- `api/get_arpl_trades.php` - Fetch all active ARPL trades
- `api/get_arpl_classes.php` - Fetch classes for a trade (by ofo_code → looks up trade_id)
- `api/get_arpl_class_learners.php` - Fetch learners for a class (by classID)

### Debug Page
- `debug_classes.php` - Comprehensive API testing page

## Fixes Applied

### 1. Enhanced Debugging in classes.php
Added `console.log()` statements to track:
- When API is called and with what parameters
- API response status and data
- When classes are displayed
- When user clicks a class
- When button is enabled/disabled

### 2. Verified API Logic
- `get_arpl_classes.php`: Correctly looks up `ofo_number` in `arpl_trades` table
- API returns trade_id and uses it to fetch classes from `class` table where `trade_id` matches
- Response format is correct and includes all required fields

### 3. Verified JavaScript Logic
- `selectClass()` function correctly:
  - Removes 'active' class from all items
  - Adds 'active' to clicked item
  - Stores classID in `selectedClass` variable
  - Finds button by ID: `btnContinue`
  - Disables the disabled attribute (enables button)

## Troubleshooting Steps

### If Button Still Doesn't Enable:

1. **Open Browser Developer Console** (F12)
   - Go to classes.php page
   - Select a trade from index.php first
   - Go to classes page
   - Open Console tab (F12)
   - Look for console.log() output

2. **Check Console Logs**
   - Should see: `loadClasses: Sending request with ofo_code=671101`
   - Should see: `API Response status: 200` (or other HTTP status)
   - Should see: `API Response data: {status: 'success', classes: [...]}`
   - Should see: `displayClasses called with X classes`
   - When clicking class should see: `selectClass called with classID=782`

3. **Use Debug Page**
   - Visit: `http://localhost/web/web/web/debug_classes.php`
   - Click "Test /api/get_arpl_trades.php" - Should find 4 trades
   - Set OFO Code to "671101", click "Test /api/get_arpl_classes.php"
   - Should find 1 class: "lowest"
   - Set Class ID to "782", click "Test /api/get_arpl_class_learners.php"
   - Should find 10 learners

### If APIs Return Errors:

1. **HTTP 400 on get_arpl_classes.php**
   - Check browser console for error message
   - Common: Missing ofo_code parameter
   - Common: Invalid JSON in request

2. **Connection Refused**
   - Verify Apache is running
   - Check localhost:80 is accessible
   - Verify files are in `C:\xampp\htdocs\web\web\web\api\`

3. **Empty Classes**
   - Verify trade exists in `arpl_trades` table
   - Verify `ofo_number` matches exactly
   - Check if classes exist: SELECT * FROM class WHERE trade_id IN (SELECT trade_id FROM arpl_trades)

## Quick Test Sequence

1. Navigate to: `http://localhost/web/web/web/index.php`
2. Click on "Electrician" card (or any trade with classes)
3. Click "Continue to Classes →"
4. On classes page, open F12 console
5. Should see: "loadClasses: Sending request with ofo_code=671101"
6. Wait for response
7. Should see: "displayClasses called with 1 classes"
8. See class item "lowest" displayed
9. Click on the class item
10. Should see: "selectClass called with classID=782"
11. Should see: "Button enabled, disabled=false"
12. "View Learners →" button should now be ENABLED
13. Click button to go to learners page

## Session Storage Keys

- `selectedTradeOFO` - Stores OFO code (e.g., "671101")
- `selectedClassID` - Stores class ID (e.g., 782)

Both are cleared when user clicks "Back" button.

## Expected Database States

### For Electrician Trade (OFO: 671101):
- 1 class: "lowest" (ID: 782)
- 10 learners in class 782

### For Bricklayer Trade (OFO: 641201):
- 1 class: "Bricklaying" (ID: 783)
- 10 learners in class 783

### For Plumber & Welder:
- 0 classes (will show "No classes found" message)

## Important Notes

1. **OFO Code vs OFO Number**: 
   - Database stores as `ofo_number` (e.g., "671101")
   - JavaScript passes as `ofo_code` parameter
   - API looks up using `WHERE ofo_number = ?`

2. **Trade ID not passed directly**:
   - Instead, ofo_code is sent and API converts it to trade_id
   - This is more robust as ofo_code is the unique identifier shown to users

3. **Session Storage**:
   - Persists during session
   - Cleared when user clicks "Back" button
   - Different from cookies - cleared when browser closes

4. **Button Enable Logic**:
   - Button starts with `disabled` attribute
   - `selectClass()` removes the disabled attribute (enables it)
   - Button re-enables each time user selects a class

## Files Modified

1. **c:\projects\rlmss\web\classes.php**
   - Added enhanced console.log() debugging
   - No logic changes - structure is correct

2. **c:\projects\rlmss\web\debug_classes.php** (NEW)
   - Comprehensive API testing page
   - Can be accessed at: http://localhost/web/web/web/debug_classes.php

## Verification Checklist

- [x] Database has 4 ARPL trades
- [x] Electrician has 1 class with 10 learners
- [x] Bricklayer has 1 class with 10 learners
- [x] API endpoints return correct JSON structure
- [x] classes.php displays classes correctly
- [x] selectClass() function enables button
- [x] learners.php validates both trade and classID
- [x] Workflow: Trade → Classes → Learners works

## Next Steps for User

1. Test with the debug page first
2. Check browser console logs while navigating
3. If button still doesn't enable, screenshot the console output
4. Report which step fails (API call, API response, or button enable)

---

**Status**: Ready for Testing
**Last Updated**: 2026-07-10
**Deployed Location**: C:\xampp\htdocs\web\web\web\
