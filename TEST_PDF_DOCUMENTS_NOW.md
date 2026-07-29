# Test ARPL PDF Document Display - Quick Guide

## Session 17 Fixes Applied ✓

**What was fixed:**
- Assessment paper file path resolution (Appendix L, N)
- Access Recommendation database queries (Appendix H, I, K)
- Helper function for robust file lookup

**What you should test:**

---

## Quick Test (2 minutes)

### Step 1: Generate PDF
1. Open: `http://localhost:8080/web/index.php`
2. Select: Electrician (or any trade)
3. Select: Any class
4. Select: Learner 16389 (or any learner)
5. Click: "Generate ARPL ▶"
6. Wait for PDF to load

### Step 2: Check Documents

**Appendix L: Theory Assessment Papers**
- ✓ Should show: "Total Theory Papers Uploaded: 1"
- ✓ Should list: "Basic Electrical Safety"
- ✓ Should show: PDF embedded in page
- ✗ If blank: File path not resolving (see troubleshooting)

**Appendix N: Practical Assessment Scripts**
- ✓ Should show: "Total Practical Scripts Uploaded: 1"  
- ✓ Should list: "Electrical Practical Paper 1"
- ✓ Should show: PDF embedded in page
- ✗ If blank: File path not resolving (see troubleshooting)

**Appendix H: Assessment Evaluation Agreement**
- ✓ Should show: Form with learner details
- ✓ Should show: Signature blocks
- ✗ If blank: Database query issue

---

## Detailed Verification

### Verify File Paths Working
Browser Console (F12) → Should NOT show errors like:
- "File not found"
- "Path resolution failed"
- "Cannot read file"

### Verify Assessment Papers Exist
Check files in: `C:\xampp\htdocs\assessorReport2\mobile\ARPL_POE\`
- `All_Questions_Basic_Electrical_Safety_Electrician_theory.pdf` ✓ (131 KB)
- `All_Questions_Electrical_Practical_Paper_1_Electrician_practical.pdf` ✓ (54 KB)

### Verify Database Connection
PDF should display learner details from database:
- ✓ Learner name shown
- ✓ Trade shown
- ✓ Assessment date shown

---

## Common Issues & Solutions

### Issue: Documents Show "Not Available"
**Cause**: File path resolution failed

**Fix**:
1. Verify files exist: `C:\xampp\htdocs\assessorReport2\mobile\ARPL_POE\`
2. Clear browser cache: Ctrl+F5
3. Restart Apache in XAMPP
4. Check PHP error logs

### Issue: PDF Appears Blank
**Cause**: File too large or encoding issue

**Fix**:
1. Check file size < 10 MB (it is: 131 + 54 = 185 KB total)
2. Try different browser
3. Check if PDF is valid: Open directly in file explorer

### Issue: Appendix H Shows Empty Form
**Cause**: Database query failed or learner data missing

**Fix**:
1. Verify learner record exists: `SELECT * FROM learnerdetails WHERE LearnerID = ?`
2. Check trade name mapping: `SELECT * FROM class WHERE classID = ?`
3. Verify facilitator data (optional): May show "Assessor" if not in session

### Issue: Access Recommendation (Appendix I) is Blank
**Cause**: No record in `arplelectrician_access_recommendation` table

**Expected behavior**: Shows "Not recorded yet"

**To add data**: 
```sql
INSERT INTO arplelectrician_access_recommendation 
(LearnerID, ACRID, Trade, OFOCode, Status, Remarks)
VALUES (16389, 1, 'Electrician', '671101', 'Ready', 'Assessment completed');
```

---

## Success Indicators ✓

All of these should be true:
- [ ] PDF generates without redirect to index.php
- [ ] Assessment papers show (Appendix L)
- [ ] Practical scripts show (Appendix N)
- [ ] Learner details are populated (Appendix A, H)
- [ ] All content renders without errors
- [ ] Table of Contents matches page numbers
- [ ] Can scroll through all 20+ pages

---

## If Everything Works

Great! The fixes are complete. You should be able to:
- Generate ARPL PDFs without issues
- See all assessment documents embedded
- View learner information throughout
- Access all appendices with proper data

---

## If Something Doesn't Work

1. **Check production deployment**:
   - File: `C:\xampp\htdocs\web\web\web\arpl_pdf.php`
   - Should be 192 KB
   - Should be from today

2. **Check browser cache**:
   - Force refresh: Ctrl+F5
   - Or clear cache entirely

3. **Check PHP errors**:
   - Open browser console: F12
   - Check for PHP warnings/errors
   - Look in XAMPP error logs

4. **Verify database files exist**:
   - `C:\xampp\htdocs\assessorReport2\mobile\ARPL_POE\*.pdf`
   - Should have at least 2 files for learner 16389

---

## Next Steps After Testing

If all works:
1. Test with different learners
2. Test with different trades
3. Test PDF print functionality
4. Test PDF export

If any issues:
1. Note exact behavior
2. Check error messages
3. Verify file paths
4. Check database records

---

**Test Started**: Use this guide to verify the fixes
**Expected Time**: 2-5 minutes
**Success Rate**: Should work if files exist and database connected
