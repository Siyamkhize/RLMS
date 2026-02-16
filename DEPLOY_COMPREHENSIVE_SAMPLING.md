# Deploy Comprehensive Stratified Sampling

## Quick Deployment Guide

### Files to Deploy

#### Backend (PHP)
```bash
# Upload to server
get_learners_with_poe_assigned.php
```

#### Frontend (Flutter)
```bash
# Already updated in project
lib/ModeratorPage.dart
```

### Deployment Steps

#### Step 1: Backup Current Files
```bash
# On server
cp get_learners_with_poe_assigned.php get_learners_with_poe_assigned.php.backup
```

#### Step 2: Upload New PHP File
```bash
# Upload get_learners_with_poe_assigned.php to server
# Ensure it's in the same directory as other PHP endpoints
```

#### Step 3: Verify Database Table
The endpoint will auto-create the table, but you can verify:
```sql
-- Check if table exists
SHOW TABLES LIKE 'moderator_assignments';

-- View table structure
DESCRIBE moderator_assignments;

-- Check existing assignments
SELECT * FROM moderator_assignments LIMIT 10;
```

#### Step 4: Test Backend Endpoint
```bash
# Test with curl
curl "http://your-server.com/get_learners_with_poe_assigned.php?moderator_id=TEST001"

# Or use the test script
php test_comprehensive_sampling.php
```

Expected response should include:
- `"sampling_method": "stratified_comprehensive"`
- `"stratification_dimensions"` array
- `"strata_summary"` with all 5 dimensions
- Learners with complete metadata

#### Step 5: Build Flutter App
```bash
# Clean build
flutter clean
flutter pub get

# Build APK
flutter build apk --release

# Or build for your target platform
flutter build ios --release  # For iOS
```

#### Step 6: Test in App
1. Login as moderator
2. Open drawer menu
3. Click "Moderation Sampling"
4. Verify:
   - ✓ Sampling summary shows
   - ✓ Stratification dimensions listed
   - ✓ Strata breakdown table displays
   - ✓ Color-coded badges appear
   - ✓ All learner metadata visible
   - ✓ "Moderate" button works

### Verification Checklist

#### Backend Verification
- [ ] PHP file uploaded successfully
- [ ] Endpoint responds to requests
- [ ] JSON structure is correct
- [ ] Database table created/updated
- [ ] Stratification logic working
- [ ] 25% sampling rate applied
- [ ] All 5 dimensions included

#### Frontend Verification
- [ ] App builds without errors
- [ ] Moderation Sampling menu item visible
- [ ] Page loads without crashes
- [ ] Summary card displays correctly
- [ ] Strata breakdown table shows
- [ ] Learner list displays
- [ ] Color coding works
- [ ] Navigation to marking page works

### Rollback Plan

If issues occur:

#### Backend Rollback
```bash
# Restore backup
cp get_learners_with_poe_assigned.php.backup get_learners_with_poe_assigned.php
```

#### Frontend Rollback
```bash
# Revert to previous commit
git checkout HEAD~1 lib/ModeratorPage.dart

# Rebuild
flutter clean
flutter build apk --release
```

### Common Issues & Solutions

#### Issue 1: "No learners with POE available"
**Cause**: No learners have uploaded POE
**Solution**: Ensure learners have POE records in database

#### Issue 2: Strata summary not showing
**Cause**: Missing marks data
**Solution**: Verify marks table has entries

#### Issue 3: All learners show "Not Assessed"
**Cause**: No marks in database
**Solution**: This is expected if no assessments done yet

#### Issue 4: Build errors in Flutter
**Cause**: Syntax errors or missing dependencies
**Solution**: 
```bash
flutter clean
flutter pub get
flutter analyze
```

### Testing Different Scenarios

#### Test 1: First-Time Assignment
```bash
# Use a new moderator ID
curl "http://your-server.com/get_learners_with_poe_assigned.php?moderator_id=NEW_MOD_001"
```
Expected: `"is_existing_assignment": false`

#### Test 2: Existing Assignment
```bash
# Use same moderator ID again
curl "http://your-server.com/get_learners_with_poe_assigned.php?moderator_id=NEW_MOD_001"
```
Expected: `"is_existing_assignment": true`, same learners

#### Test 3: Multiple Moderators
```bash
# Test with different moderators
curl "http://your-server.com/get_learners_with_poe_assigned.php?moderator_id=MOD_A"
curl "http://your-server.com/get_learners_with_poe_assigned.php?moderator_id=MOD_B"
```
Expected: Different learners for each moderator, no overlap

### Performance Considerations

#### Database Optimization
```sql
-- Add indexes for better performance
CREATE INDEX idx_poe_learner ON poe(learnerID);
CREATE INDEX idx_marks_learner ON marks(learner_id);
CREATE INDEX idx_class_id ON learnerdetails(classID);
```

#### Caching (Optional)
Consider caching the sampling results if:
- Large number of learners (>1000)
- Frequent page refreshes
- Server load is high

### Monitoring

#### Check Assignment Distribution
```sql
-- See how many learners each moderator has
SELECT 
    moderator_id,
    COUNT(*) as learner_count,
    MIN(assigned_at) as first_assignment,
    MAX(assigned_at) as last_assignment
FROM moderator_assignments
GROUP BY moderator_id
ORDER BY learner_count DESC;
```

#### Check Stratum Distribution
```sql
-- See distribution across classes
SELECT 
    class_id,
    COUNT(*) as assigned_count
FROM moderator_assignments
WHERE class_id IS NOT NULL
GROUP BY class_id
ORDER BY assigned_count DESC;
```

### Success Criteria

Deployment is successful when:
1. ✅ Backend endpoint returns comprehensive stratification data
2. ✅ Flutter app displays all 5 stratification dimensions
3. ✅ Strata breakdown table shows correctly
4. ✅ Color-coded badges display properly
5. ✅ Moderators can navigate to marking page
6. ✅ Assignments persist across sessions
7. ✅ No duplicate learner assignments
8. ✅ 25% sampling rate maintained per stratum

### Post-Deployment

#### User Training
1. Show moderators the new sampling page
2. Explain the stratification dimensions
3. Demonstrate color coding system
4. Explain why they see specific learners

#### Documentation
- Share MODERATION_SAMPLING_COMPREHENSIVE_COMPLETE.md with team
- Update user manual with new screenshots
- Create video tutorial (optional)

### Support

If issues persist:
1. Check server error logs
2. Review Flutter console output
3. Test endpoint directly with curl
4. Verify database connectivity
5. Check PHP error reporting settings

### Completion

Once deployed and verified:
- [ ] Mark deployment as complete
- [ ] Update changelog
- [ ] Notify stakeholders
- [ ] Archive backup files
- [ ] Document any customizations made

---

**Deployment Date**: _____________
**Deployed By**: _____________
**Verified By**: _____________
**Status**: _____________
