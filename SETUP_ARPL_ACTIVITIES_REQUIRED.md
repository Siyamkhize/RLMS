# ⚠️ CRITICAL: Setup ARPL Activities Database Tables

## Problem

The Appendix B and D tabs show "Activities not loaded" because the required database tables haven't been created yet:
- `arpl_competency_scale` 
- `arplappxb_electrician_activities`
- `arplappxb_activity_ratings`

## Solution

You need to run the SQL setup script in your database. There are two ways:

---

## Option 1: Using phpMyAdmin (Easiest)

1. **Open phpMyAdmin**
   - Go to: `http://localhost/phpmyadmin` (or your server URL)
   - Log in with your database credentials

2. **Import SQL File**
   - Click on your database (e.g., `rlmss`)
   - Click **"Import"** tab
   - Click **"Choose File"**
   - Select: `c:\projects\rlmss\setup_arpl_data.sql`
   - Click **"Go"** button

3. **Verify Success**
   - You should see 3 tables created:
     - ✅ `arpl_competency_scale` (5 records)
     - ✅ `arplappxb_electrician_activities` (22 records)
     - ✅ `arplappxb_activity_ratings` (0 records initially)

---

## Option 2: Using MySQL Command Line

```bash
mysql -u root -p your_database_name < "c:\projects\rlmss\setup_arpl_data.sql"
```

Or if using socket connection:

```bash
mysql -u root -p --socket=/var/run/mysqld/mysqld.sock your_database_name < setup_arpl_data.sql
```

---

## Option 3: Using MySQL Workbench

1. Open MySQL Workbench
2. Connect to your database
3. Go to **File** → **Open SQL Script**
4. Select `setup_arpl_data.sql`
5. Click the ⚡ **Execute** button (or Ctrl+Shift+Enter)

---

## What Gets Created

### Table 1: `arpl_competency_scale` (5 records)
```
Score | Proficiency Level | Description
------+-------------------+-------------------------------------------
1     | Fundamental       | Knowledge is minimal
2     | Novice            | Limited experience
3     | Advanced          | Intermediate experience
4     | Advanced Auth.    | Applied authority
5     | Expert            | Recognized authority
```

### Table 2: `arplappxb_electrician_activities` (22 records)
```
Activity #1 - Health, Safety, Quality and Assessment of Units
Activity #2 - Knowledge and practical skills
Activity #3 - Safety, Quality and Regulations
... (through Activity #22)
```

### Table 3: `arplappxb_activity_ratings` (initially empty)
Stores learner ratings for each activity:
- learnerID
- activity_id
- rating_score (1-5)
- assessor_id
- comments
- rating_date

---

## After Setup

1. **Rebuild & reinstall APK**:
   ```bash
   flutter clean
   flutter build apk --release
   adb install -r build\app\outputs\flutter-apk\app-release.apk
   ```

2. **Test in app**:
   - Navigate to ARPL Assessor Review
   - Select learner
   - Click "Appx B (Activities)" tab
   - Should now show all 22 activities with rating buttons ✅

---

## Verification Query

After running the SQL, verify in phpMyAdmin or MySQL:

```sql
-- Check competency scale
SELECT COUNT(*) FROM arpl_competency_scale;
-- Should return: 5

-- Check activities
SELECT COUNT(*) FROM arplappxb_electrician_activities;
-- Should return: 22

-- List all activities
SELECT activity_number, activity_name FROM arplappxb_electrician_activities ORDER BY activity_number;
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Table already exists" error | This is fine - `INSERT IGNORE` skips duplicates |
| Foreign key error | Make sure `learnerdetails` table exists |
| Permission denied | Check your MySQL user has CREATE/INSERT permissions |
| SQL syntax error | Verify you copied the entire setup_arpl_data.sql file |

---

## File Locations

- **SQL Setup Script**: `c:\projects\rlmss\setup_arpl_data.sql`
- **PHP API**: `c:\projects\rlmss\mobile\get_arpl_competency_data.php`
- **Flutter Code**: `c:\projects\rlmss\lib\ArplAssessorPage.dart`

---

## Next Steps

After database setup:
1. ✅ Run setup_arpl_data.sql
2. ✅ Verify tables created (5 competency scales + 22 activities)
3. ✅ Rebuild APK
4. ✅ Reinstall on device
5. ✅ Test in ARPL Assessor Review → Appx B tab

**Then activities should load and show all 22 activities with rating buttons!**
