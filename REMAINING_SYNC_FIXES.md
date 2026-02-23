# Remaining Sync Fixes - UPDATE/INSERT Pattern

## Status Summary

### ✅ Already Fixed (Using UPDATE/INSERT)
1. **sdp** - _syncSdp()
2. **sites** - syncSites()
3. **project** - syncProjectData()
4. **class** - _syncClass()
5. **learnerdetails** - _syncLearnerDetails()
6. **bankdetails** - _syncBankDetails()
7. **users** - _syncUsers()
8. **learningpathway** - _syncLearningpathway()
9. **pathway_selection** - _syncPathwaySelection()

### ⚠️ Still Using DELETE+INSERT (Lower Priority - Reference Data)
These tables contain mostly reference/configuration data that doesn't change frequently:

10. **qualification** (line 1410)
11. **qualification_selection** (line 1445)
12. **qualification_pathway** (line 1481)
13. **qualificationunitstandard** (line 1517)
14. **unitstandard** (line 1553)
15. **unit_standard_selection** (line 1588)
16. **assessments** (line 1623)
17. **poe** (line 1657)

## Why These Are Lower Priority

These tables contain:
- **Qualification definitions** - Rarely change
- **Unit standards** - Static reference data
- **Assessment templates** - Configuration data
- **POE templates** - Reference data

Unlike user data (learners, classes, sites), these don't have:
- User-generated content
- Frequent updates
- Local modifications
- Critical data loss risk

## Learner List Issue

### Problem
```
[LEARNER_LIST] Found 0 learners in local database
```

### Possible Causes

1. **Learners Not Synced Yet**
   - User needs to sync while online first
   - Learners are fetched from server and saved to `learnerdetails` table
   - Then they'll be available offline

2. **Wrong Class ID**
   - Class 111 might not have learners
   - Or learners have different classID in database

3. **Sync Not Completing**
   - Check if `_syncLearnerDetails()` is being called
   - Check if learners are being saved to database

### Solution Steps

1. **While Online:**
   ```
   - Open app
   - Navigate to class 111
   - Wait for sync to complete
   - Verify learners appear
   ```

2. **Then Offline:**
   ```
   - Turn off internet
   - Navigate to class 111
   - Should see learners from local database
   ```

3. **Debug:**
   ```dart
   // Add to fetchLearnersData() in learner_list_page.dart
   print('[DEBUG] Checking all learners in database...');
   final db = await dbHelper.database;
   final allLearners = await db.query('learnerdetails');
   print('[DEBUG] Total learners in DB: ${allLearners.length}');
   print('[DEBUG] Learners for class ${widget.classID}: ${localLearners.length}');
   ```

## How to Fix Remaining Tables (If Needed)

### Pattern to Follow

**Before (DELETE+INSERT):**
```dart
await _dbHelper.clearTable('table_name');
for (var item in items) {
  await _dbHelper.insertData('table_name', item);
}
```

**After (UPDATE/INSERT):**
```dart
// SMART SYNC: Update existing, insert new (no delete)
print('Syncing ${items.length} records using UPDATE/INSERT pattern');

final db = await _dbHelper.database;
for (var item in items) {
  await db.insert(
    'table_name',
    item,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
```

### Example: Fix qualification table

**Location:** lib/sync_service.dart, line ~1410

**Find:**
```dart
await _dbHelper.clearTable('qualification');

for (var qualificationData in qualificationList) {
  await _dbHelper.insertData('qualification', qualificationData);
}
```

**Replace with:**
```dart
// SMART SYNC: Update existing, insert new (no delete)
print('Syncing ${qualificationList.length} qualifications using UPDATE/INSERT pattern');

final db = await _dbHelper.database;
for (var qualificationData in qualificationList) {
  await db.insert(
    'qualification',
    qualificationData,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
```

## Testing Checklist

### For Each Fixed Table:
- [ ] Sync while online
- [ ] Verify data appears
- [ ] Add local-only record
- [ ] Sync again
- [ ] Verify local record still exists
- [ ] Verify server updates applied

### For Learner List:
- [ ] Sync while online
- [ ] Navigate to class with learners
- [ ] Verify learners appear
- [ ] Go offline
- [ ] Navigate to same class
- [ ] Verify learners still appear
- [ ] Check logs for "[LEARNER_LIST] Found X learners"

## Current Sync Flow

```
syncData()
  ├─ _syncUsers() ✅ UPDATE/INSERT
  ├─ _syncFacilitator()
  ├─ _syncSdp() ✅ UPDATE/INSERT
  ├─ syncSites() ✅ UPDATE/INSERT
  ├─ _syncClass() ✅ UPDATE/INSERT
  ├─ _syncLearningpathway() ✅ UPDATE/INSERT
  ├─ _syncPathwaySelection() ✅ UPDATE/INSERT
  ├─ _syncQualification() ⚠️ DELETE+INSERT
  ├─ _syncQualificationSelection() ⚠️ DELETE+INSERT
  ├─ _syncQualificationPathway() ⚠️ DELETE+INSERT
  ├─ _syncQualificationUnitStandard() ⚠️ DELETE+INSERT
  ├─ _syncUnitStandard() ⚠️ DELETE+INSERT
  ├─ _syncUnitStandardSelection() ⚠️ DELETE+INSERT
  ├─ _syncAssessments() ⚠️ DELETE+INSERT
  ├─ _syncPoe() ⚠️ DELETE+INSERT
  ├─ _syncLearnerDetails() ✅ UPDATE/INSERT
  └─ _syncBankDetails() ✅ UPDATE/INSERT
```

## Priority Recommendation

### High Priority (Done ✅)
- Users, SDP, Sites, Project, Class
- Learner Details, Bank Details
- Learning Pathway, Pathway Selection

### Medium Priority (Optional)
- Qualification tables (if users modify qualifications)
- Unit standard tables (if users modify standards)

### Low Priority (Can Skip)
- Assessment templates (rarely change)
- POE templates (static reference)

## Conclusion

**9 out of 17 tables** now use smart sync (UPDATE/INSERT pattern).

The remaining 8 tables are mostly reference data that:
- Don't change frequently
- Don't have user modifications
- Have low risk of data loss

Focus on testing the learner list offline functionality first, as that's the immediate issue.
