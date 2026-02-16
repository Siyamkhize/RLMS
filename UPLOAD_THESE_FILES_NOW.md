# UPLOAD THESE FILES TO SERVER NOW

## Quick Summary
All three tasks are complete. Task 3 requires uploading 2 files to the server.

---

## Files to Upload

Upload these files to: `https://rlms.rlms.co.za/mobile/`

### 1. add_supplemental_learners.php (NEW FILE)
**Purpose**: Adds 29 supplemental learners to reach 402 total

**Location**: Root of project folder
**Destination**: `https://rlms.rlms.co.za/mobile/add_supplemental_learners.php`

### 2. get_learners_with_poe_assigned.php (UPDATED FILE)
**Purpose**: Fixed SQL error when classID 74 is filtered out

**Location**: Root of project folder
**Destination**: `https://rlms.rlms.co.za/mobile/get_learners_with_poe_assigned.php`

---

## Upload Methods

### Option 1: FTP/SFTP
```
Host: rlms.rlms.co.za
Directory: /public_html/mobile/
Files:
  - add_supplemental_learners.php
  - get_learners_with_poe_assigned.php
```

### Option 2: cPanel File Manager
1. Login to cPanel
2. Open File Manager
3. Navigate to `/public_html/mobile/`
4. Upload both files
5. Overwrite existing `get_learners_with_poe_assigned.php`

### Option 3: Command Line (if you have SSH access)
```bash
scp add_supplemental_learners.php user@rlms.rlms.co.za:/path/to/mobile/
scp get_learners_with_poe_assigned.php user@rlms.rlms.co.za:/path/to/mobile/
```

---

## After Upload - Testing

### Test 1: Check Current State (No SQL Error)
```bash
php check_current_assignments.php
```

**Expected Output**:
```
Current assignments: 373
No SQL errors
Shows strata summary
```

### Test 2: Add Supplemental Learners
```bash
php test_supplemental_learners_remote.php
```

**Expected Output**:
```
Previous count: 373
Needed count: 29
Added count: 29
Final count: 402
✓ Target reached exactly!
✓ No learners from classID 74
```

### Test 3: Verify in Flutter App
1. Open ModeratorPage
2. Pull to refresh
3. Check total shows 402 learners
4. Verify no learners from classID 74
5. Confirm existing moderated learners still present

---

## Verification Commands

### Check Total Count
```bash
curl "https://rlms.rlms.co.za/mobile/get_learners_with_poe_assigned.php?moderator_id=77"
```
Look for: `"selected_count": 402`

### Add Supplemental (if needed)
```bash
curl -X POST "https://rlms.rlms.co.za/mobile/add_supplemental_learners.php" \
  -H "Content-Type: application/json" \
  -d '{"moderator_id": 77, "target_count": 402}'
```

---

## What Each File Does

### add_supplemental_learners.php
- Checks current assignment count (373)
- Calculates needed count (402 - 373 = 29)
- Randomly selects 29 learners from available pool
- Excludes classID 74 (testing class)
- Excludes already assigned learners
- Adds them to moderator_assignments table
- Returns detailed response with counts

### get_learners_with_poe_assigned.php (UPDATED)
- Fixed SQL error when classID 74 is filtered out
- Added empty check after filtering in 2 locations
- Prevents empty IN clause: `IN ()`
- Now returns empty array instead of SQL error

---

## Success Indicators

After upload and testing, you should see:

✅ No SQL errors when fetching assignments
✅ Total assignments = 402
✅ No learners from classID 74
✅ Existing 373 assignments untouched
✅ 29 new supplemental learners added
✅ Flutter app displays all 402 learners
✅ Moderation work preserved

---

## If Something Goes Wrong

### Rollback: Remove Supplemental Learners Only
```sql
DELETE FROM moderator_assignments 
WHERE moderator_id = '77' 
AND stratum_type = 'supplemental';
```

### Rollback: Full Reset
```sql
DELETE FROM moderator_assignments 
WHERE moderator_id = '77';
```
Then re-run original sampling.

---

## Quick Reference

**Moderator ID**: 77
**Current Count**: 373
**Target Count**: 402
**Need to Add**: 29
**Excluded Class**: 74 (testing class)

**Server**: https://rlms.rlms.co.za/mobile
**Database**: rlmsrlmsco_ezxcmacd_rlms

---

## Status

- [x] Task 1: Individual exercise moderation fix - DEPLOYED
- [x] Task 2: ClassID and site name display - DEPLOYED
- [ ] Task 3: Add 29 supplemental learners - **UPLOAD FILES NOW**

---

## Next Action

**UPLOAD THESE 2 FILES TO THE SERVER NOW:**
1. `add_supplemental_learners.php`
2. `get_learners_with_poe_assigned.php`

Then run the test scripts to verify everything works!
