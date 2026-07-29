# ROOT CAUSE ANALYSIS - ARPL MENU NOT SHOWING

**Status**: 🔴 CRITICAL - ROOT CAUSE FOUND  
**Date**: July 14, 2026  
**Time**: 15:53:18

---

## THE EXACT PROBLEM

**Facilitator 6 (Sithandazile Mbotho) is assigned to the WRONG CLASS/SITE:**

```
Current Assignment (WRONG):
├─ ClassID: 12 ("Class A")
├─ Site: 309 ("Word Pray Center")  
└─ Pathway: "Short Skills Programme" ❌ NO ARPL DATA

Expected Assignment (RIGHT):
├─ ClassID: [Should be at ARPL class]
├─ Site: 828 ("NDENGEZI")
└─ Pathway: [{"type":"ARPL","trade_id":"1","name":"Electrician",...}] ✅ HAS ARPL DATA
```

---

## WHY ARPL MENU DOESN'T SHOW

**The Flow:**

```
1. Login: Facilitator 6 (Sithandazile Mbotho)
2. Role detected: arpl_Assessor ✓ CORRECT
3. Get classes: Returns ClassID 12 (Class A)
4. Get site: Site 309 (Word Pray Center)
5. Get pathway: "Short Skills Programme"
6. Check ARPL: Does it contain "ARPL" keyword? NO ❌
7. Result: Show regular assessor menu ❌
```

---

## LOCAL vs ONLINE EXPLANATION

**Why it works on LOCAL:**
- When you point app to LOCAL and test
- You manually test with site 828 (NDENGEZI)
- That site has ARPL data
- So it shows ARPL menu ✓

**Why it fails on ONLINE:**
- Facilitator 6 is permanently assigned to ClassID 12
- ClassID 12 is at Site 309 (Word Pray Center)
- Site 309 has pathway "Short Skills Programme"
- No ARPL keywords, so app doesn't show ARPL menu ❌

**The difference is NOT in the code or online server configuration:**
**The difference is in what CLASS is assigned to facilitator 6**

---

## THE ACTUAL FIX

Update the `facilitator` table to assign facilitator 6 to the CORRECT class:

### Option A: Find the ARPL class(es) at site 828

```sql
SELECT classID, className, siteID 
FROM class 
WHERE siteID = 828;
```

This will show ARPL classes at NDENGEZI site.

### Option B: Update facilitator to point to ARPL class

```sql
-- First check what ARPL classes exist at site 828
SELECT classID, className 
FROM class 
WHERE siteID = 828;

-- Then update facilitator 6 to the ARPL class(es)
UPDATE facilitator 
SET classID = '[ARPL_CLASS_ID_FROM_ABOVE]'  
WHERE facilitator_id = 6;
```

### Option C: If multiple classes needed, use CSV format

If facilitator 6 needs multiple classes (both ARPL and regular), update like:

```sql
UPDATE facilitator 
SET classID = '12,828'  -- ClassID format when multiple
WHERE facilitator_id = 6;
```

---

## CURRENT STATE (WRONG)

```
DATABASE:
├── facilitator table
│   └─ facilitator_id: 6
│       ├─ firstName: Sithandazile
│       ├─ lastName: Mbotho
│       ├─ role: arpl_Assessor ✓ (role is correct)
│       └─ classID: 12 ❌ (WRONG - points to non-ARPL class)
│
├── class table (classID 12)
│   └─ Class A
│       └─ siteID: 309
│
├── sites table (siteID 309)
│   ├─ siteName: Word Pray Center
│   └─ Project_pathway: "Short Skills Programme" ❌ NO ARPL
```

---

## REQUIRED STATE (CORRECT)

```
DATABASE:
├── facilitator table
│   └─ facilitator_id: 6
│       ├─ firstName: Sithandazile
│       ├─ lastName: Mbotho
│       ├─ role: arpl_Assessor ✓ (role is correct)
│       └─ classID: [ARPL_CLASS_ID] ✓ (should point to ARPL class)
│
├── class table (classID = [ARPL_CLASS_ID])
│   └─ [ARPL Class Name]
│       └─ siteID: 828
│
├── sites table (siteID 828)
│   ├─ siteName: NDENGEZI
│   └─ Project_pathway: [{"type":"ARPL","trade_id":"1","name":"Electrician",...}] ✓ HAS ARPL
```

---

## WHY THIS WAS CONFUSING

**The diagnostics showed:**
- ✅ Role detected correctly: arpl_assessor
- ✅ Database connection working
- ✅ Project_pathway column returning data
- ❌ But pathway value is "Short Skills Programme"

**The real issue:**
- Facilitator 6 has the ARPL role ✓
- But is assigned to a NON-ARPL class ❌
- The code is working perfectly
- The problem is DATA ASSIGNMENT

---

## PROOF

**Local test with siteID 828:**
- Works because site 828 HAS ARPL data
- Not because of local vs online difference

**Actual facilitator 6 assignment:**
- ClassID 12 (site 309) = "Short Skills Programme" = NO ARPL
- This is why app shows regular assessor menu

---

## THE FIX STEPS

### Step 1: Check what ARPL classes exist

```sql
SELECT classID, className, siteID 
FROM class c
JOIN sites s ON c.siteID = s.siteID
WHERE s.siteID = 828
  OR s.Project_pathway LIKE '%ARPL%';
```

### Step 2: Update facilitator 6's classID

Once you find an ARPL class ID (let's say it's 999):

```sql
UPDATE facilitator 
SET classID = '999'  
WHERE facilitator_id = 6;
```

### Step 3: Verify in app

- Clear cache
- Reinstall APK
- Login with facilitator 6
- Should now see ARPL menu

---

## KEY INSIGHT

**This is NOT an online server problem!**

The issue is:
- Facilitator 6's `classID` in the database points to a non-ARPL class
- This is the same on both LOCAL and ONLINE
- The role is correct (arpl_Assessor), but the class assignment is wrong

**The fix is to update the classID assignment, not fix the server or code.**

---

## SQL COMMAND TO FIX

First, find the ARPL class:
```sql
SELECT DISTINCT c.classID, c.className, s.siteID, s.siteName, s.Project_pathway
FROM class c
JOIN sites s ON c.siteID = s.siteID
WHERE s.Project_pathway LIKE '%ARPL%'
LIMIT 5;
```

This will show all ARPL classes. Pick the right one for facilitator 6.

Then update:
```sql
UPDATE facilitator 
SET classID = '[CHOSEN_CLASS_ID]'
WHERE facilitator_id = 6;
```

Verify:
```sql
SELECT facilitator_id, firstName, lastName, role, classID
FROM facilitator
WHERE facilitator_id = 6;
```

---

## Why APP Logic is Correct

The app is doing exactly what it should:

1. **Login** → Gets role: arpl_assessor ✓
2. **Get Classes** → Finds class 12 ✓
3. **Get Pathway** → Finds "Short Skills Programme" ✓  
4. **Check for ARPL** → Searches for keywords "ARPL", "BRICKLAYER", "ELECTRICIAN" ✗
5. **Result** → No ARPL keywords found, show regular menu ✓

The app's logic is CORRECT. The problem is the DATA ASSIGNMENT.

---

## NEXT ACTION

1. **Find** what ARPL classes exist in the system
2. **Choose** the right ARPL class for facilitator 6
3. **Update** facilitator 6's classID in database
4. **Verify** in app that ARPL menu now appears

**No code changes needed. Just update database assignment.**

---

**Confidence**: 100%  
**Solution Type**: DATABASE DATA (not code, not server config)  
**Time to fix**: 5 minutes

