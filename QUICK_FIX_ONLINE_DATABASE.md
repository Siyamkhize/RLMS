# QUICK FIX: Online Database Project_Pathway Sync

**Time:** 5 minutes  
**Complexity:** Simple SQL UPDATE  
**Impact:** Fixes ARPL UI completely

---

## THE PROBLEM IN ONE SENTENCE

Online server's `sites` table has incomplete `Project_pathway` data (just trade names like "Bricklaying") instead of full JSON (with "ARPL" type identifier).

---

## THE FIX IN ONE COMMAND

```sql
UPDATE sites s
INNER JOIN project p ON s.project_id = p.project_id
SET s.Project_pathway = p.Project_pathway
WHERE s.project_id IS NOT NULL;
```

---

## DEPLOYMENT (3 Steps)

### Step 1: Connect to Database
```bash
mysql -u [username] -p [database_name]
```

### Step 2: Run the Fix
Copy and paste this SQL:
```sql
UPDATE sites s
INNER JOIN project p ON s.project_id = p.project_id
SET s.Project_pathway = p.Project_pathway
WHERE s.project_id IS NOT NULL;
```

Press Enter. Done! ✅

### Step 3: Verify (Optional but Recommended)
```sql
SELECT COUNT(*) as arpl_sites FROM sites WHERE Project_pathway LIKE '%ARPL%';
```

Should return: > 0

---

## RESULT

| Before | After |
|--------|-------|
| sites.Project_pathway = "Bricklaying" | sites.Project_pathway = `[{"type":"ARPL",...]` |
| App can't detect ARPL | App detects ARPL ✅ |
| Normal assessor menu | ARPL menu shows ✅ |

---

## AFTER THE FIX

1. Clear app cache:
   ```bash
   adb shell pm clear com.example.rlmss
   ```

2. Relogin with ARPL assessor

3. ARPL menu appears ✅

---

## WHAT IT DOES

Updates every site in the `sites` table with the full `Project_pathway` JSON from its linked `project` record, so that ARPL pathway detection works correctly.

---

**That's it! One SQL query fixes everything.**

