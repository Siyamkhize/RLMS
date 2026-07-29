# Quick Test Steps - Trade Routing Fix

**On Your Device:**

## Test 1: Bricklayer Form (Primary Test) ✅

1. Open app → Assessor Dashboard
2. Find **ARPL section** → **View Complete Toolkit** button
3. **Select dropdown** → Choose a learner from **"Bricklaying" class**
4. Click button → **Form opens**

**EXPECT:** 
- Form title/header shows "Bricklayer" or bricklaying activities  
- NOT electrician activities
- Form loads successfully

---

## Test 2: Electrician Form (Comparison)

1. Same steps, but select learner from **"lowest" class** (Electrician)
2. Click button → **Form opens**

**EXPECT:**
- Form shows electrician activities
- Different from bricklayer form

---

## Test 3: Save Assessment

1. In Bricklayer form → Fill Appendix F
2. Select a task → Click Save

**EXPECT:**
- Success message appears
- Data saves without error

---

## What's Different?

- **Before:** Always showed electrician form (hardcoded OFO 671101)
- **After:** Shows correct trade form based on class assignment
  - Bricklaying class → Bricklayer form (OFO 671103) ✅
  - Electrician class → Electrician form (OFO 671101) ✅

---

## Issues to Look For

❌ Form still shows Electrician for Bricklayer learner  
→ Force close app + retry

❌ Activities won't load  
→ Check internet connection

❌ Save fails  
→ Take screenshot of error message

---

## Report Results

✅ **All tests pass?** → Fix is complete, ready for deployment

❌ **Any test fails?** → Provide:
1. Which test failed (1, 2, or 3)
2. What you see vs. what you expected
3. Any error messages (screenshot)

---

**APK installed:** Release build (45.9 MB)  
**Build date:** July 9, 2026
