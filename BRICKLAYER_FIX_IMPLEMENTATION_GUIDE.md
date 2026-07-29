# BRICKLAYER TOOLKIT FIX - IMPLEMENTATION GUIDE

**Status:** Ready to Deploy  
**Components:** Database + PHP API + Dart Models  
**Time to Deploy:** ~15 minutes

---

## ⚡ QUICK START - 4 STEPS

### Step 1: Database Setup (2 minutes)
```bash
# Run the SQL script to create all tables
mysql -h [HOST] -u [USER] -p [DATABASE] < create_bricklayer_appendix_tables.sql

# Verify tables created
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME LIKE 'arplbricklayer%' OR TABLE_NAME LIKE 'arplappxb%' OR TABLE_NAME LIKE 'arplappxc%';
```

**Expected Tables:**
- arplappxb_bricklaying_activities (13 rows)
- arplappxc_bricklaying
- arplbricklayer_access_recommendation
- arplbricklayer_gap_unit_standards
- arplappxb_bricklaying_activity_ratings

### Step 2: Deploy PHP Files (2 minutes)
**Copy new/updated files to `mobile/` directory:**
```
✅ mobile/get_bricklayer_toolkit_data.php (UPDATED)
✅ mobile/save_bricklayer_gap_closure.php (NEW)
✅ mobile/get_bricklayer_gap_unit_standards.php (NEW)
```

**Files already exist:**
- mobile/save_appxh_recommendation.php (for electrician - reference)

### Step 3: Update Dart Models (2 minutes)
**File:** `lib/models/arpl_toolkit_data.dart`

**Change Applied:**
- Added `GapUnitStandard` class for gap closure data

**No action needed** - already updated in this implementation

### Step 4: Rebuild APK (8 minutes)
```bash
cd c:\projects\rlmss

# Clean and build
flutter clean
flutter build apk --release

# Install on device
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 📋 DETAILED STEPS

### Step 1: Database Setup (Detailed)

1. **Connect to MySQL:**
   ```bash
   mysql -h your_host -u your_user -p your_database
   ```

2. **Create all tables:**
   ```bash
   source create_bricklayer_appendix_tables.sql;
   ```

3. **Verify table creation:**
   ```sql
   -- Check Appendix B activities (should have 13 rows)
   SELECT COUNT(*) as theory_activities FROM arplappxb_bricklaying_activities;
   
   -- Check recommendation table exists
   DESCRIBE arplbricklayer_access_recommendation;
   
   -- Check gap standards table exists
   DESCRIBE arplbricklayer_gap_unit_standards;
   
   -- Verify qualification 65409 exists
   SELECT qualification_id, qualification_name FROM occupational_qualification 
   WHERE qualification_id = 65409;
   
   -- Verify unit standards exist for bricklaying
   SELECT COUNT(*) as unit_standards FROM occupational_unit_standards 
   WHERE qualification_id = 65409;
   ```

### Step 2: Deploy PHP Files

1. **Copy updated file:**
   ```bash
   cp mobile/get_bricklayer_toolkit_data.php [SERVER]/mobile/
   ```

2. **Copy new files:**
   ```bash
   cp mobile/save_bricklayer_gap_closure.php [SERVER]/mobile/
   cp mobile/get_bricklayer_gap_unit_standards.php [SERVER]/mobile/
   ```

3. **Verify endpoints accessible:**
   - `http://server/mobile/get_bricklayer_toolkit_data.php` ✅
   - `http://server/mobile/save_bricklayer_gap_closure.php` ✅
   - `http://server/mobile/get_bricklayer_gap_unit_standards.php` ✅

### Step 3: Rebuild Flutter App

```bash
# Navigate to project
cd c:\projects\rlmss

# Clean previous builds
flutter clean

# Get latest dependencies
flutter pub get

# Build release APK
flutter build apk --release

# Expected output:
# ✓ Built build\app\outputs\flutter-apk\app-release.apk (45.8MB)
```

### Step 4: Install & Test

```bash
# Verify device connected
adb devices

# Install APK
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Expected: Success
```

---

## 🧪 TESTING SCENARIOS

### Test 1: Appendix B Shows Correct Data
1. Open RLMSS Mobile App
2. Navigate to ARPL Toolkit → Bricklayer
3. Go to Appendix B
4. **Expected:** 13 theory activities for bricklaying (not electrician)
5. **Sample Activities:**
   - Interpret drawings and specifications
   - Lay solid brickwork in English bond
   - Build cavity walls
   - (etc.)

### Test 2: Appendix C Shows Correct Data
1. Still in Bricklayer toolkit
2. Go to Appendix C
3. **Expected:** Bricklaying curriculum content (not empty)
4. **Fields to check:**
   - Curriculum Overview
   - Module Summary
   - Learning Outcomes
   - Additional Notes

### Test 3: Appendix H Gap Closure
1. Still in Bricklayer toolkit
2. Go to Appendix H
3. For "Overall Result" (item 4), select "Recommended for gap closure"
4. **Expected:** UI shows multi-select checkboxes for unit standards
5. Select 2-3 unit standards
6. Click Save
7. **Expected:** Data saved successfully
8. **Verify in DB:**
   ```sql
   SELECT * FROM arplbricklayer_gap_unit_standards 
   WHERE learner_id = [LEARNER_ID];
   ```

### Test 4: Data Persistence
1. Fill in Appendix B ratings
2. Fill in Appendix H recommendations
3. Select gap closure unit standards
4. Click Save
5. Navigate away from toolkit
6. Navigate back to Bricklayer toolkit
7. **Expected:** All data still shows (not cleared)

---

## ⚠️ TROUBLESHOOTING

### Issue: "Table doesn't exist" error
**Solution:**
```bash
# Re-run SQL script
mysql -h [HOST] -u [USER] -p [DATABASE] < create_bricklayer_appendix_tables.sql

# Verify table exists
SHOW TABLES LIKE 'arplbricklayer%';
```

### Issue: Appendix B still shows electrician data
**Check:**
1. Verify `arplappxb_bricklaying_activities` has 13 rows:
   ```sql
   SELECT COUNT(*) FROM arplappxb_bricklaying_activities WHERE ofo_number = '641201';
   ```
2. Verify PHP updated correctly:
   ```bash
   grep "arplappxb_bricklaying" mobile/get_bricklayer_toolkit_data.php
   ```
3. Clear app cache and rebuild

### Issue: Gap closure unit standards not showing
**Check:**
1. Verify `occupational_qualification` has ID 65409:
   ```sql
   SELECT * FROM occupational_qualification WHERE qualification_id = 65409;
   ```
2. Verify unit standards exist:
   ```sql
   SELECT COUNT(*) FROM occupational_unit_standards WHERE qualification_id = 65409;
   ```
3. Check API response from device logs

---

## 📊 FILE CHECKLIST

### Database
- [x] create_bricklayer_appendix_tables.sql - 5 new tables

### PHP API
- [x] mobile/get_bricklayer_toolkit_data.php - UPDATED (Appendix B, C, H)
- [x] mobile/save_bricklayer_gap_closure.php - NEW
- [x] mobile/get_bricklayer_gap_unit_standards.php - NEW

### Dart Models
- [x] lib/models/arpl_toolkit_data.dart - Added GapUnitStandard class

### Documentation
- [x] BRICKLAYER_APPENDIX_B_C_H_FIX.md - Full technical details
- [x] BRICKLAYER_FIX_IMPLEMENTATION_GUIDE.md - This guide

---

## ✅ PRE-DEPLOYMENT CHECKLIST

- [ ] Database script tested and verified
- [ ] All 5 new tables created successfully
- [ ] Qualification ID 65409 verified in database
- [ ] Unit standards exist for qualification 65409
- [ ] PHP files copied to server
- [ ] PHP endpoints accessible via browser/Postman
- [ ] Flutter app rebuilt successfully
- [ ] APK installed on test device
- [ ] Appendix B shows bricklaying activities
- [ ] Appendix C shows curriculum content
- [ ] Appendix H gap closure works
- [ ] Data persists correctly
- [ ] No app crashes during testing

---

## 🚀 DEPLOYMENT SUMMARY

| Component | Status | Notes |
|-----------|--------|-------|
| Database | ✅ Ready | 5 new tables, SQL script provided |
| PHP API | ✅ Ready | 3 files (1 updated, 2 new) |
| Dart | ✅ Ready | 1 class added (GapUnitStandard) |
| Documentation | ✅ Ready | 2 comprehensive guides |
| Testing | ⏳ Ready | 4 test scenarios defined |

---

**Ready to Deploy!**

Next steps:
1. Execute database script
2. Deploy PHP files
3. Rebuild and install APK
4. Run test scenarios
5. Verify all data shows correctly

---

*End of Implementation Guide*
