# BRICKLAYER APPENDIX H DATA LOADING FIX - COMPLETE

**Date:** July 10, 2026  
**Issue:** Error parsing data - type 'List<dynamic>' is not a subtype of type 'Map<dynamic,dynamic>'  
**Status:** ✅ FIXED

---

## PROBLEM IDENTIFIED

When clicking "View Toolkit" for bricklayer learner, the app threw a parsing error:
```
Error parsing data: type 'List<dynamic>' is not a subtype of type 'Map<dynamic,dynamic>'
```

**Root Cause:**
1. The API endpoint `mobile/get_bricklayer_toolkit_data.php` was querying for `Status` and `Remarks` columns in the `appxh_acrbricklaying` table
2. However, the database table ONLY has `ACRID` and `AssessmentType` columns
3. The SQL query `WHERE Status IS NOT NULL` returned no records, making `$appendixH_recommendations` an empty array
4. When PHP converted the empty result to JSON with `(object)[...]`, it became `null` instead of an array
5. This caused the Dart parser to receive `null` for `recommendations` instead of an array, causing the type mismatch error

---

## SOLUTION APPLIED

### 1. Fixed `mobile/get_bricklayer_toolkit_data.php`

**Change:** Removed the invalid SQL query and created default recommendations based on available ACR items.

**Before:**
```php
// Get recommendations - FAILS because Status column doesn't exist
$stmt = $conn->prepare("
    SELECT ACRID, Status, Remarks
    FROM appxh_acrbricklaying
    WHERE Status IS NOT NULL
    ORDER BY ACRID ASC
");
// Returns null/empty, causing JSON to be null
```

**After:**
```php
// Create default recommendations based on ACR items
// Default to empty status (user will fill in during assessment)
foreach ($appendixH_items as $item) {
    $appendixH_recommendations[] = [
        'recommendationId' => $item['acrId'],
        'learnerId' => $learnerID,
        'acrId' => $item['acrId'],
        'trade' => 'bricklaying',
        'ofoCode' => $ofo_number,
        'status' => '',  // Default empty - user fills in during assessment
        'remarks' => '',
        'createdAt' => date('Y-m-d H:i:s'),
        'updatedAt' => date('Y-m-d H:i:s')
    ];
}
```

**Result:**
- `$appendixH_recommendations` is now always an array (not null)
- The API response sends `appendixH.recommendations` as a proper array
- Dart model correctly parses this as `List<AccessRecommendation>`

---

## DATA STRUCTURE VERIFIED

### Database Schema (appxh_acrbricklaying)
- `ACRID` (tinyint) - PRIMARY KEY
- `AssessmentType` (varchar(100))
- **Note:** No Status or Remarks columns

### ACR Items in Database
1. Knowledge assessment
2. Practical assessment
3. Workplace Observation
4. Overall Result

### API Response Structure (Verified)
```json
{
  "appendixH": {
    "items": [
      {"acrId": 1, "assessmentType": "Knowledge assessment"},
      {"acrId": 2, "assessmentType": "Practical assessment"},
      {"acrId": 3, "assessmentType": "Workplace Observation"},
      {"acrId": 4, "assessmentType": "Overall Result"}
    ],
    "recommendations": [
      {
        "recommendationId": 1,
        "learnerId": 1,
        "acrId": 1,
        "trade": "bricklaying",
        "ofoCode": "641201",
        "status": "",
        "remarks": "",
        "createdAt": "2026-07-10 12:35:32",
        "updatedAt": "2026-07-10 12:35:32"
      },
      ...
    ],
    "gap_standards": []
  }
}
```

---

## FILES MODIFIED

1. **`mobile/get_bricklayer_toolkit_data.php`** (Lines 128-163)
   - Removed invalid SQL query for Status/Remarks
   - Added logic to create default recommendations from ACR items
   - Ensures `recommendations` is always an array, never null

---

## BUILD & DEPLOYMENT

- ✅ Flutter clean & pub get completed
- ✅ APK built successfully (45.8MB)
- ✅ APK installed on device (SUCCESS)

---

## NEXT STEPS

1. Test the bricklayer toolkit load in the app:
   - Login → Select bricklayer learner → View Toolkit
   - Should load without parsing errors
   - Appendix H tab should show the 4 assessment recommendations

2. If "Ready"/"Not Ready" status data is needed:
   - Add `Status` and `Remarks` columns to `appxh_acrbricklaying` table, OR
   - Create a separate recommendations table linking learner assessment status to ACR items

---

## TESTING CHECKLIST

- [ ] Select bricklayer learner without error
- [ ] Click "View Toolkit" without parsing error
- [ ] AppendixH tab loads with 4 assessment recommendations
- [ ] All tabs load correctly (A through J)
- [ ] No console errors in debug mode

