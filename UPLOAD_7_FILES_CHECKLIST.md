# Upload 7 Files - Simple Checklist

## FILES TO UPLOAD (Check when done)

All files upload to: `public_html/mobile/`

### File 1: Fix "OFO Not Set"
- [ ] `get_class_trade_info.php`
- Test: https://rlms.rlms.co.za/mobile/get_class_trade_info.php?classID=797
- Expected: JSON with ofo_number

### File 2: Fix "Activities Not Loaded"
- [ ] `get_arpl_competency_data.php`
- Test: https://rlms.rlms.co.za/mobile/get_arpl_competency_data.php?learnerID=11701&ofo_number=641201
- Expected: JSON with activities array

### Files 3-7: Fix 404 Save Errors
- [ ] `save_arpl_appendix_b.php`
- [ ] `save_arpl_appendix_d.php`
- [ ] `save_arpl_appendix_e.php`
- [ ] `save_arpl_appendix_f.php`
- [ ] `save_arpl_criteria.php`
- Test: Visit each URL (should NOT be 404)

---

## QUICK UPLOAD (cPanel)

1. Login to cPanel
2. File Manager
3. Navigate: `public_html/mobile/`
4. Click Upload
5. Drag and drop all 7 files:
   ```
   get_class_trade_info.php
   get_arpl_competency_data.php
   save_arpl_appendix_b.php
   save_arpl_appendix_d.php
   save_arpl_appendix_e.php
   save_arpl_appendix_f.php
   save_arpl_criteria.php
   ```
6. Wait for uploads to complete
7. Verify all 7 files appear in directory

---

## TEST IN APP

### Route 1: Assessor Review (D,E,F)
- [ ] Menu → Assessor Review (D,E,F)
- [ ] Select: Anele Cele
- [ ] Check: OFO shows "641201"
- [ ] Check: Activities load in Appendix B
- [ ] Check: Can save without 404 error

### Route 2: View Complete Toolkit
- [ ] Menu → View Complete Toolkit
- [ ] Select: Anele Cele
- [ ] Check: OFO shows "641201" (NOT "Not Set")
- [ ] Check: Can open toolkit
- [ ] Check: Activities load
- [ ] Check: Can save without 404 error

---

## ALL DONE? ✅

Both routes should now:
- Show correct OFO number
- Load activities from database
- Save successfully without 404 errors

**No app rebuild needed** - server-side only fix!

