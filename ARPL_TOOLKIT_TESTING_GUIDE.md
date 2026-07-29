# ARPL Toolkit Testing Guide - July 10, 2026

## Build Status
- ✅ Build: SUCCESSFUL (45.8 MB)
- ✅ APK Installation: SUCCESSFUL
- ✅ Date: July 10, 2026

## Implementation Summary

### Hardcoded Appendix F Activities (13 per trade)

All three trades now have hardcoded workplace observation activities in `_buildAppendixF()` method:

#### Bricklayer (OFO 671103)
1. Safety practices and hazard identification
2. Measuring and marking out brickwork
3. Brick selection and storage
4. Mortar preparation and consistency
5. Building walls with correct bond patterns
6. Installing lintels and openings
7. Building curved and decorative brickwork
8. Applying mortar joints and pointing
9. Building columns and piers
10. Constructing arches and angles
11. Installing damp proof courses
12. Cleaning and finishing brickwork surfaces
13. Quality inspection and fault correction

#### Plumber (OFO 671102)
1. Safety practices and hazard identification
2. Pipe selection and material identification
3. Measuring and marking pipe routes
4. Pipe joining and connection methods
5. Water supply system installation
6. Drainage system installation
7. Hot water system installation
8. Cold water system installation
9. Rainwater system installation
10. Sanitary appliance installation
11. Testing and commissioning systems
12. Leakage detection and repair
13. Cleaning and maintenance of pipework

#### Electrician (OFO 671101)
1. Safety practices and hazard identification
2. Electrical cable selection and storage
3. Measuring and marking installation routes
4. Installing wiring systems and conduits
5. Connecting and terminating cables
6. Installing switching and control devices
7. Installing lighting fixtures and systems
8. Installing power distribution systems
9. Testing electrical installations
10. Fault diagnosis and rectification
11. Earthing and bonding installation
12. Documentation and labeling
13. Compliance with SANS and electrical regulations

### API Configuration

#### Endpoint Routing (lib/config.dart)
```
Electrician (671101)      → get_arpl_toolkit_data.php         (unified endpoint)
Bricklayer (671103)       → get_bricklayer_toolkit_data.php   (separate endpoint)
Plumber (671102)          → get_arpl_toolkit_data.php         (unified endpoint)
```

#### File Locations
- **Main UI:** `lib/ArplToolkitViewerPage.dart`
- **Unified API:** `mobile/get_arpl_toolkit_data.php`
- **Bricklayer API:** `mobile/get_bricklayer_toolkit_data.php`
- **Router:** `lib/ArplToolkitRouter.dart`
- **Config:** `lib/config.dart`

### Security Improvements Applied

1. ✅ **get_arpl_toolkit_data.php**
   - Line 254: Using `$conn->real_escape_string()` for table names
   - Line 271: Using `$conn->real_escape_string()` for ratings table
   - Prepared statements with `bind_param('i', $learnerID)` for SQL injection prevention

2. ✅ **get_bricklayer_toolkit_data.php**
   - Rewritten with proper prepared statements
   - `bind_param('i', $learnerID)` for learner lookup
   - `bind_param('i', $classID)` for class lookup
   - No direct SQL injection vulnerabilities

## Testing Checklist

### Test 1: Bricklayer Trade (OFO 671103)
**Prerequisites:**
- Logged in as assessor
- Have a bricklayer learner (OFO 671103) in the system

**Steps:**
1. Go to Assessor Page → Select a Bricklayer learner
2. Scan or enter bricklayer learner ID
3. Navigate to ARPL Toolkit
4. Check Appendix F (Workplace Observations)
5. Verify 13 bricklayer-specific activities are displayed

**Expected Results:**
- ✓ Appendix F shows 13 bricklayer activities
- ✓ No API errors
- ✓ Can select activities and add ratings
- ✓ Edit/Save functionality works

---

### Test 2: Plumber Trade (OFO 671102)
**Prerequisites:**
- Logged in as assessor
- Have a plumber learner (OFO 671102) in the system

**Steps:**
1. Go to Assessor Page → Select a Plumber learner
2. Scan or enter plumber learner ID
3. Navigate to ARPL Toolkit
4. Check Appendix F (Workplace Observations)
5. Verify 13 plumber-specific activities are displayed

**Expected Results:**
- ✓ Appendix F shows 13 plumber activities
- ✓ No API errors
- ✓ Can select activities and add ratings
- ✓ Edit/Save functionality works

---

### Test 3: Electrician Trade (OFO 671101)
**Prerequisites:**
- Logged in as assessor
- Have an electrician learner (OFO 671101) in the system

**Steps:**
1. Go to Assessor Page → Select an Electrician learner
2. Scan or enter electrician learner ID
3. Navigate to ARPL Toolkit
4. Check Appendix F (Workplace Observations)
5. Verify 13 electrician-specific activities are displayed

**Expected Results:**
- ✓ Appendix F shows 13 electrician activities
- ✓ No API errors
- ✓ Can select activities and add ratings
- ✓ Edit/Save functionality works

---

### Test 4: Cross-Trade Verification
**Steps:**
1. Test switching between different trade learners
2. Verify activities change correctly per trade
3. Verify edit/save works for all trades
4. Check that saved data persists when navigating away and back

**Expected Results:**
- ✓ Activities change when switching trades
- ✓ No data corruption
- ✓ All three trades function identically except for activities

---

### Test 5: Error Handling
**Steps:**
1. Test with invalid learner ID
2. Test with invalid class ID
3. Test with network disconnect
4. Check error messages are appropriate

**Expected Results:**
- ✓ Graceful error handling
- ✓ User-friendly error messages
- ✓ No crashes or blank screens

---

## Debug Information

### If Appendix F is Blank:
1. Check Flutter logs: `flutter logs` or `adb logcat | grep flutter`
2. Look for `[TOOLKIT_DEBUG]` messages to trace API calls
3. Verify `_buildAppendixF()` is being called
4. Check trade name detection in `_getTradeName(ofoNumber)`

### If Activities Don't Match Trade:
1. Verify OFO number is correct in debug logs
2. Check if/else conditions in `_buildAppendixF()` for trade selection
3. Confirm hardcoded lists match expected trade OFO numbers

### Common Issues & Solutions:

| Issue | Cause | Solution |
|-------|-------|----------|
| Blank Appendix F | No activities loaded | Verify trade OFO number matches 671101/671102/671103 |
| Wrong activities | Trade mismatch | Check `_getTradeName()` mapping and OFO routing |
| API errors in console | Network/server issue | Verify server is running, check firewall |
| Activities not saving | Save endpoint issue | Check `save_arpl_appendix_f_assessment.php` |

---

## Database Verification Commands

If activities need to be loaded from database later:

```sql
-- Check bricklayer activities table
SELECT COUNT(*) as activity_count FROM arplappxe_bricklaying_activities;

-- Check electrician activities table
SELECT COUNT(*) as activity_count FROM arplappxe_electrician_activities;

-- Check plumber activities table
SELECT COUNT(*) as activity_count FROM arplappxe_plumbing_activities;

-- Check activity ratings table (shared)
SELECT COUNT(*) as rating_count FROM arplappxb_activity_ratings;
```

---

## Next Steps if Database Activities Are Needed

1. Verify the database tables exist and contain data
2. Update `_buildAppendixF()` to fetch from API instead of hardcoded
3. Modify API endpoints to return activity data
4. Test with real database data
5. Remove hardcoded activities

---

## Files Modified in This Session

1. `lib/ArplToolkitViewerPage.dart` - Added hardcoded activities
2. `mobile/get_arpl_toolkit_data.php` - Fixed SQL injection vulnerabilities
3. `mobile/get_bricklayer_toolkit_data.php` - Rewritten with prepared statements
4. `lib/config.dart` - Configured trade-specific endpoint routing

---

**Session End:** Build successful, APK installed, ready for testing on device.
