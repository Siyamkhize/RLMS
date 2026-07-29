# Device Testing Guide - Trade Detection Fix

**Date:** July 9, 2026  
**APK:** Release version installed on device  
**Test Objective:** Verify that the correct trade-specific form loads when selecting learners from different classes

---

## Pre-Test Setup

### Database Classes Configured
- **ClassID 782:** "lowest" → Electrician (OFO 671101)
- **ClassID 783:** "Bricklaying" → Bricklayer (OFO 671103) ✅ **TEST THIS ONE**

### Expected Routes
- Learner from ClassID 782 → **ArplToolkitViewerPage** (Electrician form)
- Learner from ClassID 783 → **ArplToolkitBricklayerPage** (Bricklayer form)

---

## Test Procedure

### Step 1: Launch App
1. Open the RLMSS app on device
2. Login with assessor credentials
3. Navigate to **Assessor Dashboard**

### Step 2: Test Bricklayer Class (Primary Test)
1. Look for section: **"View Complete Toolkit"** or **"ARPL Toolkit"**
2. Click dropdown to **select a candidate**
3. **Select a learner from the "Bricklaying" class** (ClassID 783)
4. Look for learner name in dropdown
5. Click **"View Complete Toolkit"** or **"Start Assessment"** button

**Expected Behavior:**
- ✅ Page should display "Bricklayer Toolkit" (or similar title indicating bricklayer)
- ✅ Form should show bricklayer-specific activities
- ✅ No electrician activities should appear

### Step 3: Verify Form Content (Bricklayer)
Once the form loads:

1. **Check Section Titles:**
   - Should mention "Bricklayer" or "Bricklaying"
   - NOT "Electrician"

2. **Check Activities Listed:**
   - Look for bricklayer-specific tasks (masonry, brickwork, etc.)
   - NOT electrical tasks (wiring, circuits, etc.)

3. **Check Tables Being Used:**
   - In browser developer tools or server logs, verify:
     - Loading from `arplappxb_bricklayer_activities` ✅
     - NOT from `arplappxb_electrician_activities` ❌

### Step 4: Test Electrician Class (Verification)
1. Go back to candidate selection
2. **Select a learner from the "lowest" class** (ClassID 782)
3. Click **"View Complete Toolkit"** button

**Expected Behavior:**
- ✅ Page should display "Electrician Toolkit" or default form
- ✅ Should show electrician-specific activities
- ✅ Different from bricklayer form

### Step 5: Test Form Submission (Bricklayer)
1. Go back to Bricklayer learner
2. Navigate to Appendix F (Practical Assessment)
3. Fill in some test data:
   - Select a task
   - Enter some ratings
   - Add notes
4. Click **"Save Assessment"**

**Expected Behavior:**
- ✅ Data saves successfully
- ✅ Success message appears
- ✅ Check database: data saved to `arpl_appendix_f_bricklayer` table (NOT `arpl_appendix_f`)

---

## Verification Checklist

| Test | Expected Result | Status |
|------|-----------------|--------|
| Bricklayer learner routes to Bricklayer form | Form title/content shows Bricklayer | ☐ Pass / ☐ Fail |
| Electrician learner routes to Electrician form | Form title/content shows Electrician | ☐ Pass / ☐ Fail |
| Bricklayer activities load correctly | Bricklayer-specific tasks visible | ☐ Pass / ☐ Fail |
| Electrician activities load correctly | Electrician-specific tasks visible | ☐ Pass / ☐ Fail |
| Bricklayer save works | Data persists, success message | ☐ Pass / ☐ Fail |
| Data saves to correct table | `arpl_appendix_f_bricklayer` (not electrician) | ☐ Pass / ☐ Fail |

---

## Database Verification (After Testing)

To verify data was saved correctly, run this query:

```sql
-- Check Bricklayer assessments
SELECT * FROM arpl_appendix_f_bricklayer ORDER BY created_at DESC LIMIT 5;

-- Check Electrician assessments
SELECT * FROM arpl_appendix_f ORDER BY created_at DESC LIMIT 5;

-- Check that class is properly linked to trade
SELECT c.classID, c.className, t.trade_id, t.trade_name, t.ofo_number
FROM class c
LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
WHERE c.classID IN (782, 783);
```

---

## Troubleshooting

### Problem: Still showing Electrician form for Bricklayer learner
**Solution:**
1. Force close app: Settings → Apps → RLMSS → Force Stop
2. Reopen app
3. Try again
4. If still fails, check:
   - Did you click the button for the BRICKLAYING class learner?
   - Is the classID really 783?
   - Check app logs for error messages

### Problem: Activities not loading
**Solution:**
1. Check network connectivity
2. Verify learner is actually from the correct class
3. Check server logs for API errors
4. Try logging out and logging back in

### Problem: Save not working
**Solution:**
1. Check network connection
2. Verify you filled in required fields
3. Check if error message appears (read it carefully)
4. Try clearing app cache: Settings → Apps → RLMSS → Clear Cache

### Problem: Can't find learner from Bricklaying class
**Solution:**
1. Check dropdown is scrollable (learners list may be long)
2. Try searching/filtering in dropdown if available
3. Manually verify a learner is in classID 783:
   ```sql
   SELECT LearnerID, Name, Surname, classID 
   FROM learnerdetails 
   WHERE classID = 783 
   LIMIT 5;
   ```

---

## Quick Tips

1. **Look for visual indicators:**
   - Page titles should change between Electrician and Bricklayer
   - Activity names should be different
   - Form colors might be different

2. **Pay attention to content:**
   - Electrician: Wiring, Circuits, Electrical systems
   - Bricklayer: Masonry, Brickwork, Mortar, Structures

3. **Network matters:**
   - Ensure device has internet connection
   - Slow network might make loading seem broken

4. **Learner selection is critical:**
   - Double-check you selected from BRICKLAYING class
   - Not from "lowest" (Electrician) class

---

## Success Criteria

✅ **Test PASSES if:**
1. Bricklayer learner opens Bricklayer form (not Electrician)
2. Electrician learner opens Electrician form
3. Activities shown match the trade
4. Save operation completes successfully
5. Data appears in correct trade-specific table

❌ **Test FAILS if:**
1. Bricklayer learner opens Electrician form
2. Learner selection doesn't route correctly
3. Wrong activities displayed
4. Save fails or data goes to wrong table

---

## Next Steps After Testing

1. **If test PASSES:**
   - Document results
   - Deployment ready for other assessors
   - Roll out to all devices

2. **If test FAILS:**
   - Document which steps failed
   - Check app logs
   - Check server logs
   - Report errors with exact reproduction steps

---

## Contact Developer

If you encounter issues:
1. Note the exact steps that failed
2. Screenshot any error messages
3. Check both app and server logs
4. Report with device model, OS version, and network status
