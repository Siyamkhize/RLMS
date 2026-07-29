# FINAL FIX - ARPL MENU NOT SHOWING

**Status**: 🔴 ROOT CAUSE CONFIRMED  
**Date**: July 14, 2026  
**Solution**: Update Facilitator 6 Class Assignment

---

## THE PROBLEM

Facilitator 6 (Sithandazile Mbotho) is assigned to:
- **ClassID 12** ("Class A")  
- **Site 309** ("Word Pray Center")
- **Pathway**: "Short Skills Programme" ❌ **NOT ARPL**

---

## THE SOLUTION

Reassign facilitator 6 to an ARPL class. 

### Available ARPL Classes (14 total):

```
RECOMMENDED:
- ClassID 782 (Site 828 "NDENGEZI") - Electrician ARPL ✓
- ClassID 783 (Site 828 "NDENGEZI") - Electrician ARPL ✓

OTHER OPTIONS:
- ClassID 102-105 (Site 370 "Training Center Electrical") - ARPL
- ClassID 106-109 (Site 369 "Training Center Plumbing") - ARPL
- ClassID 165, 194-196 (Sites 393-394 "Sivananda Trade Test Centre") - ARPL
```

---

## QUICK FIX (SQL)

### Option 1: Assign to Electrician ARPL (Recommended)

```sql
UPDATE facilitator 
SET classID = '782'
WHERE facilitator_id = 6;
```

### Option 2: Assign to Bricklaying ARPL

```sql
UPDATE facilitator 
SET classID = '783'
WHERE facilitator_id = 6;
```

### Option 3: Keep both classes (if needed)

```sql
UPDATE facilitator 
SET classID = '12,782'
WHERE facilitator_id = 6;
```

---

## STEP-BY-STEP FIX

### Step 1: Run SQL Update

Connect to database and run ONE of the commands above.

**Which should I choose?**
- If this is purely for testing ARPL: Use **Option 1 (ClassID 782)**
- If need to keep regular duties: Use **Option 3 (12,782)**
- Otherwise: Use **Option 1 or 2**

### Step 2: Verify in Database

```sql
SELECT facilitator_id, firstName, role, classID 
FROM facilitator 
WHERE facilitator_id = 6;
```

Should now show: `classID = 782` (or your chosen class)

### Step 3: Clear App Cache

```bash
adb shell pm clear com.example.rlmss
```

### Step 4: Reinstall APK

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Step 5: Test

1. Open app
2. Login with facilitator 6 (Sithandazile Mbotho)
3. Should see **ARPL menu** with Toolkit and Appendices

---

## WHAT THIS FIXES

**Before**:
- Role: arpl_Assessor ✓
- Class: 12 (non-ARPL) ❌
- Menu: Regular assessor ❌

**After**:
- Role: arpl_Assessor ✓
- Class: 782 (ARPL) ✓
- Menu: ARPL assessor ✓

---

## WHY THIS WORKS

1. **Role is already correct** - `arpl_Assessor`
2. **Code logic is correct** - Checks for ARPL keywords
3. **The problem is** - ClassID 12 has no ARPL data
4. **The fix is** - Point to ClassID 782 which HAS ARPL data

Once facilitator 6 is assigned to an ARPL class:
- App gets ClassID 782
- App gets Site 828 (NDENGEZI)
- App gets Project_pathway with ARPL data
- App detects ARPL ✓
- App shows ARPL menu ✓

---

## WHY IT WASN'T ONLINE SERVER ISSUE

**You were right:**
- Local works fine with site 828
- Online didn't work

**The confusion:**
- Site 828 DOES have ARPL data
- But facilitator 6 isn't assigned to any class at site 828
- Facilitator 6 is assigned to ClassID 12 at site 309
- Site 309 doesn't have ARPL data

**The real issue:**
- Same database used for both LOCAL and ONLINE
- Database says facilitator 6 → ClassID 12 → Site 309 → "Short Skills Programme"
- Whether accessed locally or online, result is the same
- The fix needed is: Update the assignment in the database

---

## COMMANDS

### All in One (Copy-Paste)

```bash
# For Electrician ARPL:
mysql -u root -p your_database -e "UPDATE facilitator SET classID = '782' WHERE facilitator_id = 6;"

# For Bricklaying ARPL:
mysql -u root -p your_database -e "UPDATE facilitator SET classID = '783' WHERE facilitator_id = 6;"

# Then clear and reinstall:
adb shell pm clear com.example.rlmss
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## FINAL VERIFICATION

After fix, run this query:

```sql
SELECT 
    f.facilitator_id,
    f.firstName,
    f.lastName,
    f.role,
    c.classID,
    c.className,
    s.siteName,
    CASE
        WHEN UPPER(s.Project_pathway) LIKE '%ARPL%' THEN 'YES - ARPL Menu will show'
        ELSE 'NO - Regular menu'
    END as will_show_arpl_menu
FROM facilitator f
JOIN class c ON FIND_IN_SET(c.classID, f.classID) > 0
JOIN sites s ON c.siteID = s.siteID
WHERE f.facilitator_id = 6;
```

Should output: `YES - ARPL Menu will show`

---

## SUMMARY

| Item | Before | After |
|------|--------|-------|
| Facilitator 6 Role | arpl_Assessor | arpl_Assessor |
| ClassID | 12 | 782 |
| Site | 309 (Word Pray Center) | 828 (NDENGEZI) |
| Pathway | Short Skills Programme | ARPL Electrician data |
| ARPL Menu | NO | YES ✓ |

---

## TIME TO FIX

- SQL Update: 1 minute
- Clear cache: 1 minute  
- Reinstall APK: 3 minutes
- Test: 2 minutes

**Total: ~7 minutes**

---

**Confidence**: 100%  
**Solution Type**: Database data assignment  
**Status**: Ready to execute

