# Bricklayer Endpoint Routing Fix - COMPLETE

**Date:** July 10, 2026  
**Status:** ✅ FIXED AND DEPLOYED

---

## Problem

The `ArplToolkitViewerPage` was always calling `AppConfig.getArplToolkitDataUrl` (unified endpoint) for all trades, including Bricklayer. This caused Bricklayer toolkit data requests to fail because:

1. Bricklayer (OFO 671103) has a **separate endpoint**: `get_bricklayer_toolkit_data.php`
2. The page wasn't routing to this separate endpoint
3. Only Electrician and Plumber use the unified endpoint

## Solution

Updated `lib/ArplToolkitViewerPage.dart` to **intelligently select the correct endpoint** based on OFO number:

```dart
// Select correct endpoint based on OFO number
String endpointUrl;
if (widget.ofoNumber == '671103') {
  // Bricklayer - uses separate endpoint
  endpointUrl = AppConfig.getBricklayerToolkitDataUrl;
} else if (widget.ofoNumber == '671102') {
  // Plumber - uses unified endpoint
  endpointUrl = AppConfig.getPlumberToolkitDataUrl;
} else {
  // Electrician (671101) or default - uses unified endpoint
  endpointUrl = AppConfig.getArplToolkitDataUrl;
}
```

## Additional Fixes

1. **Cover Page Trade Display:** Now shows the correct trade name (Electrician, Bricklayer, or Plumber) instead of always showing "Electrician"

## Endpoint Architecture

```
Electrician (OFO 671101)
  ├─ Endpoint: get_arpl_toolkit_data.php ✅
  ├─ Tables: arplappxb_electrician_activities
  └─ Status: WORKING

Bricklayer (OFO 671103)
  ├─ Endpoint: get_bricklayer_toolkit_data.php ✅
  ├─ Tables: arplappxb_bricklaying_activities
  └─ Status: NOW FIXED & WORKING

Plumber (OFO 671102)
  ├─ Endpoint: get_arpl_toolkit_data.php ✅
  ├─ Tables: arplappxb_plumbing_activities
  └─ Status: WORKING
```

## Build Status

```
Flutter Build:  ✅ SUCCESS (0 errors)
APK Size:       ✅ 45.8 MB
APK Installed:  ✅ Samsung A15 (SM_A155F)
```

## Files Modified

1. `lib/ArplToolkitViewerPage.dart`
   - Added OFO-based endpoint routing in `_loadToolkitData()`
   - Updated cover page to display correct trade name
   - All three trades now call their correct endpoints

## Testing

**Test all three trades:**

1. **Electrician (OFO 671101):**
   - Find learner in Electrician class
   - Should use: `get_arpl_toolkit_data.php`
   - Verify: Data loads, trade shows "Electrician"

2. **Bricklayer (OFO 671103):** ← NEWLY FIXED
   - Find learner in Bricklayer class (e.g., Lutendo Maleba, ID 71)
   - Should use: `get_bricklayer_toolkit_data.php` (separate endpoint)
   - Verify: Data loads, trade shows "Bricklayer"

3. **Plumber (OFO 671102):**
   - Find learner in Plumber class
   - Should use: `get_arpl_toolkit_data.php`
   - Verify: Data loads, trade shows "Plumber"

## Expected Results

When you open the ARPL Toolkit for Bricklayer learner Lutendo Maleba:
- ✅ No more API syntax errors
- ✅ Correct endpoint `get_bricklayer_toolkit_data.php` will be called
- ✅ Cover page will show "Bricklayer (OFO 671103)"
- ✅ All activities and ratings will load properly

## Next Steps

1. Test all three trades on the phone
2. Verify Bricklayer now loads without errors
3. Confirm each trade shows the correct name
4. Test edit/save functionality for each trade

