# 🚀 CRITICAL TESTING GUIDE - ARPL SYSTEM
**Start Testing Now:** July 12, 2026  
**Expected Time:** 1.5 hours  
**Goal:** Verify ARPL system is working correctly for Bricklayers and Electricians

---

## TEST 1: ARPL Form Display - Bricklayer (15 minutes)

### Setup
- Device: Tablet or phone with latest APK
- Connection: WiFi/Mobile data ACTIVE
- Credentials: Bricklayer user account

### Steps

**1. Login as Bricklayer**
```
1.1 Open RLMSS app
1.2 Enter Bricklayer username/password
1.3 Verify login successful
1.4 Note user's classID (should be 783)
```

**2. Navigate to Action Button**
```
2.1 Go to Dashboard/Home page
2.2 Look for "Action" button or menu
2.3 Click on "Action" 
2.4 Wait for menu to load
```

**3. Select ARPL**
```
3.1 Look for "ARPL" option in menu
3.2 Expected: Should show only "Bricklayer" (not "Electrician")
3.3 Click on ARPL/Bricklayer option
3.4 Wait for form to load
```

**4. Verify Bricklayer Form Loads**
```
✓ Form title should mention "Bricklayer"
✓ OFO code should be 641201
✓ Trade name should be "Bricklayer"
✓ NOT "Electrician" or generic text
```

**5. Check Appendices Load**
```
Navigation > Each Appendix:
- [ ] Appendix B: Self-Evaluation (loads?)
- [ ] Appendix C: Curriculum Content (loads?)
- [ ] Appendix D: Practical Skills (loads?)
- [ ] Appendix F: Practical Assessment (loads?)
- [ ] Appendix H: Competency Assessment (loads?)
- [ ] Appendix I: Access Recommendation (loads?)
```

**6. Test Answer Input**
```
6.1 Navigate to Appendix B
6.2 Try to answer 1-2 questions
6.3 Verify answers can be input
6.4 Scroll through form to check for blank sections
```

**7. Screenshot Checklist**
```
Take screenshots of:
- Main menu (showing ARPL option)
- Form title/header
- OFO code display (should be 641201)
- One appendix section
- Any error messages (if any)
```

### Expected Result ✅
- Form displays with "Bricklayer" designation
- All appendices load without errors
- No "Electrician" content visible
- Questions can be answered

### If Failed ❌
**Document:**
- What appeared instead? (blank screen, Electrician form, error)
- Any error messages?
- Screenshot of what you saw
- **Don't proceed to next test, escalate to developer**

---

## TEST 2: ARPL Form Display - Electrician (15 minutes)

### Setup
- Device: Same tablet/phone
- Connection: WiFi/Mobile data ACTIVE
- Credentials: Electrician user account

### Steps

**1. Logout from Bricklayer**
```
1.1 Go to profile/settings
1.2 Click "Logout"
1.3 Confirm logout
1.4 Return to login screen
```

**2. Login as Electrician**
```
2.1 Enter Electrician username/password
2.2 Verify login successful
2.3 Note user's classID (should be 782)
```

**3. Navigate to ARPL**
```
3.1 Go to Dashboard/Home page
3.2 Click "Action" button
3.3 Look for ARPL option
3.4 Expected: Should show only "Electrician" (not "Bricklayer")
3.5 Click on ARPL/Electrician
3.6 Wait for form to load
```

**4. Verify Electrician Form Loads**
```
✓ Form title should mention "Electrician"
✓ OFO code should be 671101
✓ Trade name should be "Electrician"
✓ NOT "Bricklayer" or generic text
```

**5. Check Appendices Load**
```
Navigation > Each Appendix:
- [ ] Appendix B: Self-Evaluation (loads?)
- [ ] Appendix C: Curriculum Content (loads?)
- [ ] Appendix D: Practical Skills (loads?)
- [ ] Appendix F: Practical Assessment (loads?)
- [ ] Appendix H: Competency Assessment (loads?)
- [ ] Appendix I: Access Recommendation (loads?)
```

**6. Compare with Bricklayer Form**
```
6.1 Note any differences in questions/content
6.2 Verify this is NOT the same form as Bricklayer
6.3 Check if Appendix C has different curriculum content
```

**7. Screenshot Checklist**
```
Take screenshots of:
- Form title/header
- OFO code (should be 671101)
- One appendix section
- Any differences from Bricklayer form
```

### Expected Result ✅
- Form displays with "Electrician" designation
- All appendices load without errors
- Different content from Bricklayer form
- Questions can be answered

### If Failed ❌
**Document:**
- What appeared? (blank, Bricklayer form, error)
- Any error messages?
- Screenshot of what you saw
- **Don't proceed to next test, escalate**

---

## TEST 3: ARPL Answer Submission (20 minutes)

### Setup
- Stay logged in as Electrician OR Bricklayer
- Same form from Test 1 or 2
- Open and ready to input answers

### Steps

**1. Answer Some Questions**
```
1.1 Navigate to Appendix B
1.2 Find 3-4 simple questions
1.3 Select answers for each question
1.4 Example: "Yes/No" or "Rate 1-5" questions
1.5 Verify answers are accepted
```

**2. Fill Multiple Appendices**
```
2.1 Go to Appendix C and answer 2 questions
2.2 Go to Appendix D and answer 2 questions
2.3 Go back to Appendix B and verify answers saved
2.4 Verify data persistence across sections
```

**3. Submit Form**
```
3.1 Look for "Submit" or "Complete Assessment" button
3.2 Click Submit
3.3 Wait for success message
3.4 Screenshot any success/error message
```

**4. Verify Submission Saved**
```
4.1 Check if form shows "Submitted" status
4.2 Look for submission timestamp
4.3 Check if score is displayed
4.4 If possible, check database directly:
    SELECT * FROM arpl_assessment_responses 
    WHERE learnerID = [user's ID] 
    LIMIT 5;
```

### Expected Result ✅
- Answers are saved as you input them
- Can navigate between appendices and answers persist
- Submit button works
- Success message appears
- Database contains submission record

### If Failed ❌
**Document:**
- Which step failed?
- Any error messages?
- Can you see submitted data in database?
- Screenshot of error

---

## TEST 4: Offline Form Loading (20 minutes)

### Setup
- Device: Same tablet
- Logged in as Bricklayer or Electrician
- Already viewed ARPL form online (data cached)

### Steps

**1. Go Online First (Baseline)**
```
1.1 Make sure WiFi/data is ON
1.2 Login and open ARPL form
1.3 View Appendix B
1.4 Verify form loads correctly
```

**2. Go Offline**
```
2.1 Turn OFF WiFi/mobile data
2.2 Device should show "Offline" mode
2.3 Wait 5 seconds
```

**3. Try to View Form Again**
```
3.1 Go back to dashboard
3.2 Click Action → ARPL
3.3 Try to view form
```

**4. Check Offline Access**
```
✓ Form loads from local cache?
✓ Appendix B available?
✓ Questions visible?
✓ Can answer questions?
✓ Any error message?
```

**5. Try to Submit**
```
5.1 Try to submit answers
5.2 Expected: Should queue for sync (not submit immediately)
5.3 Should show "Pending sync" or similar message
5.4 Should show warning about offline
```

### Expected Result ✅
- Form loads from local cache
- Can view questions offline
- Can input answers offline
- Submit button either disabled or shows "pending sync" message

### If Failed ❌
**Document:**
- Blank form? Error message? No form at all?
- Can you view any appendices?
- Screenshot of what happened
- Note: This might be expected if offline sync not implemented yet

---

## TEST 5: Learner List Offline (15 minutes)

### Setup
- Device: Tablet
- Fresh start (or cleared data if testing second time)

### Steps

**1. First Launch - Online**
```
1.1 Connect to WiFi/mobile data
1.2 Open app fresh or after clearing local data
1.3 Go to Dashboard
1.4 Navigate to "Learner List"
1.5 Wait for sync (should see loading indicator)
1.6 Verify learners appear
```

**2. Go Offline**
```
2.1 Turn OFF WiFi/mobile data
2.2 Close and reopen app
2.3 Navigate to "Learner List"
```

**3. Check Offline Access**
```
✓ Learner list visible?
✓ Shows "0 learners" or shows actual learners?
✓ How many learners visible?
✓ Can click on a learner?
```

### Expected Result ✅
- Learner list shows offline learners from cache
- Should NOT show "0 learners"
- Should show at least 2-3 learners

### If Failed ❌
**Document:**
- Shows "0 learners" (this is the known issue)
- No learners visible at all
- Any error messages
- Screenshot

---

## 📊 RESULTS SUMMARY

### Test Results

| Test | Bricklayer | Electrician | Offline | Status |
|------|-----------|-------------|---------|--------|
| ARPL Form Display | PASS / FAIL | PASS / FAIL | PASS / FAIL | ⏳ |
| Appendices Load | PASS / FAIL | PASS / FAIL | PASS / FAIL | ⏳ |
| Answer Submission | PASS / FAIL | PASS / FAIL | PENDING / SAVED | ⏳ |
| Learner Offline | N/A | N/A | SHOWS / "0 LEARNERS" | ⏳ |

---

## 🐛 BUG REPORT TEMPLATE

If you find issues, document them:

```
BUG REPORT - ARPL Testing
========================

Test Number: [1, 2, 3, 4, or 5]
Trade: [Bricklayer / Electrician]
Expected: [What should happen]
Actual: [What actually happened]

Steps to Reproduce:
1. [Step 1]
2. [Step 2]
3. [Step 3]

Screenshots:
- [Attach image 1]
- [Attach image 2]

Error Message:
[Copy exact error message if any]

Device Info:
- Model: [Device name]
- Android Version: [e.g., 10, 11, 12]
- App Version: [APK date]

Database Check (if applicable):
SELECT COUNT(*) FROM arpl_assessment_responses WHERE ...
[Query results]
```

---

## ✅ COMPLETION CHECKLIST

After all tests:

- [ ] Test 1 (Bricklayer Form) - PASS/FAIL
- [ ] Test 2 (Electrician Form) - PASS/FAIL
- [ ] Test 3 (Submission) - PASS/FAIL
- [ ] Test 4 (Offline Form) - PASS/FAIL
- [ ] Test 5 (Learner Offline) - PASS/FAIL
- [ ] All screenshots taken
- [ ] Bug reports filed (if any)
- [ ] Results documented

---

**Status:** Ready to Test  
**Last Updated:** July 12, 2026  
**Contact:** [Developer email/Slack]
