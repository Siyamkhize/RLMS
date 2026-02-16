# ✅ Cleanup Instructions - Keep Induction Records

## ⚠️ IMPORTANT CHANGE

**DO NOT delete `induction_clocking` records - keep them permanently!**

Only clean up `learner_clocking` table (delete synced and old records).

## 🧹 How to Clean Up 211 Old Records

### Option 1: Run SQL Script (Recommended)

1. Open phpMyAdmin
2. Select your database
3. Click "SQL" tab
4. Open `CLEANUP_LEARNER_CLOCKING_ONLY.sql`
5. Copy and paste the SQL commands
6. Click "Go"

The script will:
- ✅ Delete synced `learner_clocking` records (synced=1)
- ✅ Delete old `learner_clocking` records (date < today)
- ✅ KEEP `induction_clocking` records (NOT deleted)
- ✅ Show before/after counts

### Option 2: Run Manual SQL

Open phpMyAdmin and run:

```sql
-- Delete synced learner_clocking records
DELETE FROM learner_clocking WHERE synced = 1;

-- Delete old learner_clocking records
DELETE FROM learner_clocking WHERE clock_date < CURDATE();

-- Check what's left
SELECT COUNT(*) FROM learner_clocking;
SELECT COUNT(*) FROM induction_clocking;
```

### Option 3: Wait for App to Start

Once the app builds and runs:
- Cleanup runs automatically on startup
- Deletes synced `learner_clocking` records
- Deletes old `learner_clocking` records
- **KEEPS `induction_clocking` records** (NOT deleted)

## 📊 What Gets Deleted vs. Kept

### ❌ DELETED (learner_clocking only):
- Records with `synced=1` (already on server)
- Records with `clock_date < today` (old records)

### ✅ KEPT:
- Current day `learner_clocking` records with `synced=0`
- **ALL `induction_clocking` records** (never deleted)

## 🎯 Updated Code

The cleanup function in `lib/database_helper.dart` has been updated to:
- Only delete from `learner_clocking` table
- **NOT touch `induction_clocking` table**
- Keep induction records permanently

---

**Status: Cleanup updated - induction_clocking records will NOT be deleted!**
