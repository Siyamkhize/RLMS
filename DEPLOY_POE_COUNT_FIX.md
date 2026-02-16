# Deploy POE Count Fix - Step by Step

## Problem Summary
The moderation sampling endpoint was showing `total_learners_with_poe: 273` instead of the actual `1571` learners with POEs in the database.

## Root Cause
When returning existing assignments, the code was setting `total_learners_with_poe` to `count($learners)` (existing assignments) instead of calculating the actual total from the database.

## Files Changed

### 1. Backend: get_learners_with_poe_assigned.php
**Location**: `mobile/get_learners_with_poe_assigned.php`

**Change**: Added calculation of actual total learners with POE when returning existing assignments (around line 733-760)

### 2. Frontend: lib/ModeratorPage.dart
**Location**: `lib/ModeratorPage.dart`

**Change**: Added cache-busting to API call (around line 2738-2747)

## Deployment Steps

### Step 1: Deploy Backend Fix

1. **Upload the updated file to server:**
```bash
# Upload get_learners_with_poe_assigned.php to:
https://rlms.rlms.co.za/mobile/get_learners_with_poe_assigned.php
```

2. **Verify file permissions:**
```bash
chmod 644 get_learners_with_poe_assigned.php
```

3. **Test the endpoint:**
```bash
php test_poe_count_live.php
```

Expected output:
```
✅ PASS: total_learners_with_poe = 1571 (expected ~1571)
✅ PASS: selected_count = 273 (existing assignments)
✅ PASS: Learners array (273) matches selected_count (273)
```

### Step 2: Deploy Frontend Fix

1. **Rebuild the Flutter app:**
```bash
flutter clean
flutter pub get
flutter build apk --release
```

2. **Install on device and test:**
   - Open the app
   - Login as moderator (ID 77)
   - Click "Moderation Sampling"
   - Verify the display shows correct counts

### Step 3: Verify in Mobile App

Check the console logs for:
```
Sampling Response Status: 200
Sampling Response Body: {"status":"success","data":{"total_learners_with_poe":1571,"selected_count":273,...}}
```

## Testing Checklist

- [ ] Backend deployed to server
- [ ] Run `php test_poe_count_live.php` - all tests pass
- [ ] Flutter app rebuilt with cache-busting
- [ ] Test in mobile app - shows correct counts
- [ ] Verify `total_learners_with_poe` shows ~1571
- [ ] Verify `selected_count` shows 273
- [ ] Verify UI displays both numbers correctly

## Expected Behavior After Fix

### API Response:
```json
{
  "status": "success",
  "data": {
    "total_learners_with_poe": 1571,
    "selected_count": 273,
    "learners": [...273 learners...],
    "is_existing_assignment": true,
    "message": "Returning your existing moderation assignment..."
  }
}
```

### Mobile App Display:
```
Total learners with POE: 1571
Your assigned learners: 273
```

## Rollback Plan

If issues occur:

1. **Restore previous backend file:**
```bash
# Keep a backup before deploying
cp get_learners_with_poe_assigned.php get_learners_with_poe_assigned.php.backup
```

2. **Revert Flutter changes:**
```bash
git checkout lib/ModeratorPage.dart
flutter build apk --release
```

## Support Files

- `test_poe_count_live.php` - Test live server
- `test_poe_count_complete.php` - Test local server
- `diagnose_poe_count_issue.php` - Diagnostic tool
- `MODERATION_SAMPLING_COMPLETE_FIX.md` - Technical documentation

## Status
✅ Backend fix ready
✅ Frontend fix ready
✅ Test scripts ready
⏳ Awaiting deployment
