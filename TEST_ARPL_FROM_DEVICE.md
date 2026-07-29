# Test ARPL APIs from Your Device

## Quick Test URL

Open this URL on your device browser:

```
http://161.35.109.152/assessorReport2/mobile/test_arpl_apis.php
```

## What This Tests

This page will run 5 comprehensive tests:

### ✅ Test 1: Appendix B API
- Checks if `arplappxb_electrician_activities` table exists
- Shows activity count (should be 22 activities)
- Displays sample activities

### ✅ Test 2: Appendix E API
- Checks if `arplappxe_electrician_activities` table exists
- Shows actual table columns
- Displays activity count for OFO 671101 (should be 13 activities)
- Shows sample activities

### ✅ Test 3: Existing Ratings Check
- Checks both Appendix B and E ratings tables
- Shows how many ratings exist for test learner (11559)

### ✅ Test 4: Live Appendix B API Call
- Makes actual GET request to competency data endpoint
- Shows HTTP status and full JSON response
- Displays total activities and rated count

### ✅ Test 5: Live Appendix E API Call
- Makes actual POST request to Appendix E endpoint
- Shows HTTP status and full JSON response
- Displays total activities and rated count

## Custom Testing

Test with different learner IDs or OFO codes:

```
http://161.35.109.152/assessorReport2/mobile/test_arpl_apis.php?learnerID=11515&ofo=671101
```

## Expected Results

All tests should show:
- ✓ Green success boxes for table checks
- ✓ Activity counts displayed
- ✓ HTTP Status: 200
- ✓ API status: "success"
- ✓ Sample data visible

## What Was Fixed

1. **Fixed `/mobile/get_arpl_appendix_e.php`**
   - Changed `sequence_order` → `activity_number`
   - Removed non-existent columns

2. **Fixed `/mobile/get_arpl_appendix_e_ratings.php`**
   - Fixed column names to match database
   - Corrected activity query structure

3. **Fixed `/mobile/save_arpl_appendix_e_ratings.php`**
   - Changed `id` → `activity_rating_id`
   - Changed `rating` → `competency_scale_id`
   - Removed `updated_at` column reference

## Database Confirmed

**Appendix E Activities (13 total):**
1. Wire ways and wiring
2. Installing wiring and connecting electrical equipment
3. Electrical supply systems and components
4-5. Installing, wiring and connecting electrical equipment and control systems
6. Carrying out commissioning tests
7. Batteries
8. Work with electrical and fluid power components
9. DC motors
10. AC motors
11-13. Additional electrician activities

## Next: Test in Flutter App

After confirming the test page works:

1. Open Flutter app
2. Go to **ARPL Assessor Dashboard**
3. Select **"Assessor Review (D,E,F)"**
4. Choose a learner
5. Verify Appendix E activities load (should see all 13 activities)
6. Rate activities using 1-5 scale
7. Save and verify ratings persist

## Troubleshooting

If test page shows errors:
- Check internet connection
- Verify URL is correct
- Try from different browser
- Check if server is accessible

## Support Files

- Full documentation: `ARPL_API_FIXES_COMPLETE.md`
- Debug script: `debug_arpl_appendix_e.php`
- API endpoints in `/mobile/get_arpl_*.php`

---
**Status: Ready for Testing** ✅
**Date: July 8, 2026**
