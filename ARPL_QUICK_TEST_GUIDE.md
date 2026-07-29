# ARPL Toolkit Quick Test Guide
**Date:** July 10, 2026  
**Device:** Samsung SM_A155F  

---

## 📱 Before Testing

✅ APK installed: `build/app/outputs/flutter-apk/app-release.apk` (45.8MB)  
✅ Device connected and app running  
✅ Network connectivity available

---

## 🧪 Test Scenario 1: Bricklayer Toolkit (OFO 641201)

### Step 1: Open Bricklayer Toolkit
1. Open RLMSS app on device
2. Navigate to **ARPL > Bricklayer Toolkit**
3. Select a learner enrolled in a Bricklayer class
4. Verify page loads without errors

### Step 2: Check Cover Page
- [ ] Trade should show: **"Bricklayer"**
- [ ] OFO should show: **"641201"**
- [ ] Learner info displays correctly

### Step 3: Verify Appendix D (Practical Skills Assessment)
1. Go to **Appendix D** tab
2. Should show **22 Bricklaying Criteria:**

✅ Safety  
✅ Hand, power and workshop tools  
✅ Measuring equipment  
✅ Plans and drawings  
✅ Identification of brick and mortar  
✅ Sanitary ware  
✅ Transportation, handling and storage of materials  
✅ Access equipment  
✅ Scaffolding  
✅ Arches  
✅ Below ground drainage system  
✅ Damp proof courses  
✅ Building works  
✅ Cavity wall construction  
✅ Solid wall construction  
✅ Walls and piers  
✅ Installation of components  
✅ Jointing and pointing  
✅ Bonding patterns  
✅ Brick types and quality  
✅ Health and safety  
✅ Environmental awareness  

**Expected:** All 22 items visible as cards (even if empty)  
**NOT Expected:** "No data" message  
**NOT Expected:** Electrician criteria (Circuits, Cables, etc.)

### Step 4: Test Appendix D Editing
1. Click **Edit** button (pencil icon) in AppBar
2. "EDIT MODE" badge should appear
3. Each criterion should show 3 buttons: **Yes | No | Not Applicable**
4. Click on one (e.g., "Yes" for Safety)
5. Button should turn green (selected)
6. Try another criterion
7. Click **Cancel** button (X icon)
8. Changes should NOT be saved
9. Click **Edit** again
10. Previous selection should be gone

### Step 5: Verify Appendix E (Workplace Experience Evaluation)
1. Go to **Appendix E** tab
2. Should show **15 Bricklaying Activities:**

✅ Activity 1-15 related to bricklaying workplace activities  
(Exact names should match those in database)

**Expected:** All 15 activities visible as cards  
**NOT Expected:** "No data" message  
**NOT Expected:** Electrician activities  

### Step 6: Test Appendix E Editing
1. Click **Edit** button
2. Each activity should have:
   - 5 rating buttons (1 2 3 4 5)
   - Comments text field
3. Click rating "3" on Activity 1
   - Button turns green (selected)
4. Type a comment: "Good performance"
5. Go to Activity 2
6. Repeat with different rating
7. Click **Cancel**
8. Changes NOT saved
9. Verify Activity 1 no longer shows rating 3 selected

### Step 7: Verify Appendix F (Practical Assessment)
1. Go to **Appendix F** tab
2. Should show **Workplace Observations** section
3. Should list same 15 bricklaying activities
4. If any Appendix E data was saved, should display here
5. Should NOT show electrician tasks

---

## 🧪 Test Scenario 2: ARPL Assessor Review

### Step 1: Navigate to Assessor Review
1. Open RLMSS app
2. Go to **Assessor > ARPL Assessor Review**

### Step 2: Test with Bricklayer Learner
1. Click learner dropdown
2. Select a learner from **Bricklayer class** (OFO 641201)
3. Wait for data to load

### Step 3: Verify OFO
- [ ] **Top of page should display:** "OFO: 641201"
- [ ] **NOT:** "OFO: 671101"

### Step 4: Verify Appendix B Activities
1. Go to **Appendix B** tab
2. Should show activities specific to **Bricklaying**
3. Should have ratings 1-5 scale
4. NOT electrician activities

### Step 5: Verify Appendix E Activities
1. Go to **Appendix E** tab
2. Should show **15 Bricklaying Workplace Activities**
3. Each should have 1-5 rating scale
4. NOT electrician activities

### Step 6: Test with Electrician Learner
1. Click learner dropdown again
2. Select learner from **Electrician class** (OFO 671101)
3. Wait for data to load
4. Verify OFO changes to **"OFO: 671101"**
5. Verify activities change to **Electrician-specific**

---

## 🐛 Troubleshooting

### Issue: "No Practical skills assessment data saved yet" appears

**Expected:** Should NOT appear - should always show 22 criteria cards

**Possible Causes:**
- [ ] Database query failing - check database connection
- [ ] Wrong OFO number - check learner's class OFO
- [ ] Table missing - verify `arpl_appendix_d_bricklayer` exists

**Fix:**
- Restart app
- Select different learner
- Check database logs
- Rebuild and reinstall APK

---

### Issue: OFO shows 671101 instead of 641201

**Expected:** OFO should match learner's class

**Possible Causes:**
- [ ] Class doesn't have OFO assigned
- [ ] `get_class_trade_info.php` not working
- [ ] Database missing trade_id in class table

**Fix:**
- [ ] Verify class has OFO assigned in `class` table
- [ ] Test `get_class_trade_info.php` endpoint directly
- [ ] Check PHP error logs

---

### Issue: Electrician activities show for Bricklayer learner

**Expected:** Bricklayer learner should see only bricklaying activities

**Possible Causes:**
- [ ] OFO not being fetched (defaults to 671101)
- [ ] API returning wrong table
- [ ] Database filtering by OFO not working

**Fix:**
- [ ] Confirm OFO is 641201
- [ ] Check API response includes correct OFO
- [ ] Verify database has bricklaying activity tables
- [ ] Check logs for `[ARPL DEBUG]` messages

---

### Issue: Edit button not appearing or not working

**Expected:** Pencil icon appears in top-right, clicking toggles edit mode

**Possible Causes:**
- [ ] UI not rendering correctly
- [ ] App cache corrupted
- [ ] Build error in AppBar

**Fix:**
- [ ] Clear app cache: `adb shell pm clear com.example.rlmss`
- [ ] Restart device
- [ ] Reinstall APK: `adb install -r app-release.apk`

---

## ✅ Success Criteria

When all tests pass:

- [x] Bricklayer Toolkit shows OFO 641201
- [x] Appendix D shows 22 bricklaying criteria
- [x] Appendix E shows 15 bricklaying activities
- [x] Appendix F shows corresponding workplace observations
- [x] Edit mode works for all appendices
- [x] Assessor Review shows correct OFO for each learner
- [x] Assessor Review shows trade-specific activities
- [x] Data can be saved and persists after reload
- [x] No crashes or error messages
- [x] Performance is acceptable (loads in <3 seconds)

---

## 📊 Data Expected in Database

### For Bricklayer (OFO 641201):
```
arpl_appendix_d_bricklayer:
  - 22 criteria with activity_1 through activity_22
  
arplappxe_bricklaying_activities:
  - 15 activities with ofo_number = '641201'
  
arplappxe_bricklaying_activity_ratings:
  - Ratings linked to bricklaying activities
  
arpl_appendix_f_bricklayer:
  - Practical assessment evaluation
```

### Verify with query:
```sql
SELECT COUNT(*) as criteria_count FROM arpl_appendix_d_bricklayer;
-- Expected: 1 record

SELECT COUNT(*) as activity_count FROM arplappxe_bricklaying_activities;
-- Expected: 15 records

SELECT COUNT(*) as activity_count FROM arplappxe_bricklaying_activities WHERE ofo_number = '641201';
-- Expected: 15 records
```

---

## 📞 Report Issues

If you encounter any issues:

1. **Take screenshot** of error/unexpected behavior
2. **Check device logs:**
   ```
   adb logcat | grep ARPL
   ```
3. **Document:**
   - What you were doing
   - What you expected to see
   - What actually happened
   - Device/OFO number involved
   - Log output

4. **Report with:** Screenshots + logs + steps to reproduce

---

**Testing Started:** [Your date/time]  
**Testing Completed:** [Your date/time]  
**Tester Name:** ________________  
**Result:** [ ] PASS [ ] FAIL  

