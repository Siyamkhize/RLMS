# ARPL Web Module - Quick Test Guide

**Last Updated:** July 10, 2026  
**Status:** ✅ Ready to Test

---

## One-Minute Test

### Step 1: Prepare
```
Close ALL browser windows
Clear browser cache (Ctrl+Shift+Delete)
Wait 5 seconds
Open new browser
```

### Step 2: Test
```
Go to: http://localhost:8080/web/web/web/index.php
```

### Expected: You Should See
- ✅ ARPL Portfolio Generator title
- ✅ 4 trade cards (Electrician, Bricklayer, Plumber, Welder)
- ✅ Each card shows OFO code
- ✅ "Continue to Classes" button (disabled until you select)

### Step 3: Select a Trade
```
Click on "Electrician" card
```

### Expected:
- ✅ Card highlights in blue
- ✅ "Continue to Classes" button becomes enabled

### Step 4: Click Continue
```
Click "Continue to Classes →" button
```

### Expected:
- ✅ Page loads classes.php
- ✅ Shows "Trade: Electrician"
- ✅ Shows message: "✓ Trade verified. Ready to select learners."
- ✅ "Continue to Learners" button is enabled
- ✅ NO JSON errors in browser console (F12)

### Step 5: Continue
```
Click "Continue to Learners →" button
```

### Expected:
- ✅ Page loads learners.php
- ✅ Workflow continues successfully

---

## If Something Goes Wrong

### Error: "SyntaxError: Unexpected token '<'"
**Solution:**
1. Clear cache again more thoroughly
2. Close browser completely
3. Restart browser
4. Try again

### Error: Trades don't load
**Solution:**
1. Check database connection
2. Visit: `http://localhost:8080/web/web/web/api/diagnose_connection.php`
3. Look for: `"conn_connected": true`

### Error: Only 1 trade shows or trade is missing
**Solution:**
1. Database might have trades disabled
2. Check: `SELECT * FROM arpl_trades;`
3. Verify `is_active = 1` for each trade

---

## What's New (Fixed)

✅ **Trades now load from database** (not hardcoded)  
✅ **All 4 trades available:** Electrician, Bricklayer, Plumber, Welder  
✅ **No more JSON errors** like "Unexpected token '<'"  
✅ **Plumbing now works** (uses OFO 642601, not 671102)  
✅ **API returns valid JSON** always  
✅ **Empty classes handled gracefully** (continues to learners anyway)

---

## Quick Reference

| Trade | OFO Code | Status |
|-------|----------|--------|
| Electrician | 671101 | ✅ Working |
| Bricklayer | 641201 | ✅ Working |
| Plumber | 642601 | ✅ Working (NOT 671102!) |
| Welder | 651302 | ✅ Working |

---

## Test Results Format

If testing, please record:
```
Date: ___________
Time: ___________
Browser: ___________
Steps Completed: [1/2/3/4/5]
Trades Visible: [Y/N]
Number of Trades: _____
Errors: [Y/N]
Error Messages: ___________
Final Status: [PASS/FAIL]
```

---

## Files Modified

- ✅ `web/api/get_arpl_trades.php` - Now queries database
- ✅ `web/api/get_arpl_classes.php` - Now validates trade only
- ✅ `web/index.php` - Now loads trades dynamically
- ✅ `web/classes.php` - Now handles empty classes
- ✅ `C:\xampp\htdocs\web\web\web\connection.php` - Fixed connection

---

## Success Criteria

✅ You completed the full workflow: Index → Classes → Learners  
✅ No console errors (F12 → Console tab shows clean)  
✅ All trades load correctly  
✅ UI is responsive  
✅ JSON responses appear in Network tab  

**All green?** 🎉 ARPL web module is working!
