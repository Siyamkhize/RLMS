# 🚨 CRITICAL FINDING: 631 Classes Missing trade_id - ARPL SYSTEM BROKEN

**Date:** July 12, 2026, 16:45 UTC  
**Status:** IMMEDIATE ACTION REQUIRED  
**Severity:** 🔴 **CRITICAL - SYSTEM BLOCKING**

---

## THE PROBLEM

### Database Verification Results
```
Total classes in database: 633
Classes WITH trade_id assigned: 2
Classes WITHOUT trade_id (NULL): 631
Missing: 99.7% of all classes!
```

**Breakdown:**
- trade_id = NULL: 631 classes ❌ (BROKEN)
- trade_id = 1: 1 class
- trade_id = 4 (Bricklayer): 1 class
- trade_id = 5 (Electrician): 0 classes

---

## IMPACT

### 🔴 ARPL System is Currently BROKEN

**When a user tries to access ARPL:**

1. User logs in
2. Clicks "ARPL" button
3. App calls: `GET /mobile/get_arpl_toolkit_data.php?classID=783`
4. PHP tries to find: `class.trade_id` where `classID = 783`
5. **Result: NULL** ❌
6. App gets NULL back
7. Form doesn't load (or loads wrong default)
8. **User cannot complete ARPL assessment**

### 🔴 Why This Breaks Everything

The entire ARPL routing logic depends on `class.trade_id`:

```php
// From get_arpl_toolkit_data.php
$result = $mysqli->query("SELECT trade_id FROM class WHERE classID = $classID");
$row = $result->fetch_assoc();
$trade_id = $row['trade_id']; // ← THIS IS NULL FOR 631/633 CLASSES!

// Then determines which table to query:
if ($trade_id == 4) {
  // Load Bricklayer form
  $query = "SELECT * FROM arpl_appendix_a_bricklayer ...";
} else if ($trade_id == 5) {
  // Load Electrician form
  $query = "SELECT * FROM arpl_appendix_a_electrician ...";
} else {
  // ← THIS BRANCH EXECUTES FOR 631 CLASSES! (Unknown trade)
  // Either shows generic form or blank
}
```

### 🔴 Affected Features

| Feature | Status | Issue |
|---------|--------|-------|
| **ARPL Assessment View** | ❌ BROKEN | No trade_id → can't determine which form to load |
| **Bricklayer ARPL** | ❌ BROKEN | Only 1 bricklayer class has trade_id |
| **Electrician ARPL** | ❌ BROKEN | 0 electrician classes have trade_id |
| **Appendix Loading** | ❌ BROKEN | Tries to load wrong appendix table |
| **Score Calculation** | ❌ BROKEN | Can't route to correct scoring logic |

---

## ROOT CAUSE ANALYSIS

### Why Are 631 Classes Missing trade_id?

**Investigation:**
1. Check how classes are created/synced
2. Check if there's a migration that didn't complete
3. Check if sync from server sets trade_id

**Possible Causes:**
- ✗ Classes were created before `trade_id` column existed
- ✗ Mass import script didn't populate trade_id
- ✗ Sync from server not mapping trade_id correctly
- ✗ New column added but old classes not updated

---

## IMMEDIATE ACTION (CRITICAL - DO THIS NOW)

### Step 1: Determine Class-to-Trade Mapping

We need to figure out which trade each class belongs to. There are several ways:

**Option A: From class name pattern**
```sql
SELECT DISTINCT className FROM class WHERE trade_id IS NULL LIMIT 20;
```

**Option B: From database relationships**
- Is there a `classes_trade` junction table?
- Is trade stored in another table?
- Check learners: Do they have a `trade` field we can use?

**Option C: From server/web application**
- Are classes mapped to trades in the PHP backend?
- Can we query the server to get trade mappings?

### Step 2: Map trade_id Values

Based on ARPL system:
- **trade_id = 4**: Bricklayer (OFO 641201)
- **trade_id = 5**: Electrician (OFO 671101)  
- **trade_id = 3**: Plumbing (OFO 642601)

### Step 3: Update All Classes

Once we have mapping, execute:
```sql
UPDATE class SET trade_id = 4 WHERE className LIKE '%bricklaying%' OR className LIKE '%brick%';
UPDATE class SET trade_id = 5 WHERE className LIKE '%electric%';
UPDATE class SET trade_id = 3 WHERE className LIKE '%plumb%';
```

---

## SOLUTION PATH

### **Immediate (Next 30 minutes)**
1. ✅ Identify a Bricklayer class from the 631
2. ✅ Look at its name/context to understand naming pattern
3. ✅ Check if learners in this class have a `trade` field
4. ✅ Determine trade_id mapping rules

### **Short-term (Next 1 hour)**
1. Create SQL migration script to populate trade_id
2. Test on 5-10 sample classes
3. Verify ARPL forms load after update

### **Execution (30 minutes)**
1. Back up database
2. Run migration script
3. Verify ARPL system works

### **Verification (30 minutes)**
1. Login as Bricklayer
2. View ARPL → should show Bricklayer form (not Electrician)
3. Load each appendix section
4. Submit test assessment
5. Verify score saved to database

---

## NEXT STEPS TO UNBLOCK

**I need you to tell me:**

1. **How were classes created?**
   - Manual entry?
   - Imported from CSV?
   - Synced from server?
   - Spreadsheet?

2. **Is there a way to map class names to trades?**
   - Example class names from the 631?
   - Is the pattern consistent (e.g., "NDB3011 - Bricklaying")?

3. **Do learners have a trade field?**
   ```sql
   SELECT DISTINCT trade_ofo_code FROM learnerdetails LIMIT 10;
   SELECT COUNT(*) FROM learnerdetails WHERE learnerID IN (
     SELECT learnerID FROM learners WHERE classID IN (
       SELECT classID FROM class WHERE trade_id IS NULL
     )
   );
   ```

4. **Can we get trade mappings from the server/web app?**
   - Is there a PHP endpoint that returns class-to-trade mappings?
   - Can we query the web database for trade assignments?

---

## VERIFICATION NEEDED

Once fixed, verify:
```sql
-- Should return 0
SELECT COUNT(*) FROM class WHERE trade_id IS NULL;

-- Should show distribution
SELECT trade_id, COUNT(*) FROM class GROUP BY trade_id;

-- Should show trades for each
SELECT DISTINCT trade_id FROM class;
```

---

## FILES THAT DEPEND ON THIS FIX

1. `mobile/get_arpl_toolkit_data.php` - Requires trade_id
2. `lib/ArplAssessorPage.dart` - Expects trade_id to route form
3. `mobile/save_arpl_appendix_*.php` - Need correct trade routing
4. `mobile/get_class_trade_info.php` - Uses class.trade_id

---

## CRITICAL: THIS IS BLOCKING ARPL

Until this is fixed:
- ❌ Bricklayer users cannot view ARPL
- ❌ Assessors cannot create assessments
- ❌ Portfolio generation fails
- ❌ No ARPL scores recorded

**This needs to be fixed BEFORE ANY OTHER WORK.**

---

**Status:** WAITING FOR MAPPING INFORMATION  
**Priority:** 🔴 **CRITICAL - BLOCKING**  
**Estimated Fix Time:** 1-2 hours once mapping identified
