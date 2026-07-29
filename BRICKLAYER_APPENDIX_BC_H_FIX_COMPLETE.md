# Bricklayer ARPL Appendix B, C, and H Fix - COMPLETE

**Date:** July 10, 2026  
**Status:** ✅ IMPLEMENTATION COMPLETE

---

## Overview

Successfully fixed and implemented the following for Bricklayer ARPL Toolkit:

1. **Appendix B** - Shows correct bricklaying theory assessment activities
2. **Appendix C** - Left empty (as requested - unit standards only show in gap closure)
3. **Appendix H** - Complete access recommendation form with gap closure multi-select

---

## Database Changes

### Tables Created

```
✅ arplbricklayer_access_recommendation
   - Stores ACR recommendations for bricklayer (ACRID 1-4)
   - Similar to arplelectrician_access_recommendation
   - Fields: RecommendationID, LearnerID, ACRID, Trade, OFOCode, Status, Remarks

✅ arplbricklayer_gap_unit_standards
   - Stores selected unit standards for gap closure per learner
   - Links to arplbricklayer_access_recommendation via foreign key
   - Fields: id, learner_id, recommendation_id, unit_standard_id, qualification_id (65409)
```

### Existing Tables Used

```
✅ arplappxb_bricklaying_activities - Appendix B theory activities
✅ appxh_acrbricklaying - ACR items (4 assessment components)
✅ unitstandard (qualification_id=65409) - Unit standards for gap closure
✅ arplbricklayer_appendix_*  - Appendix-specific data tables
```

---

## PHP API Endpoints

### Updated Endpoint

**`mobile/get_bricklayer_toolkit_data.php`** (UPDATED)
- Fetches all bricklayer toolkit data including Appendix H recommendations
- Returns gap standards already selected for this learner
- Loads recommendations from `arplbricklayer_access_recommendation` table

### New Endpoints Created

**`mobile/get_bricklayer_gap_unit_standards.php`** (NEW)
- Fetches all unit standards for qualification 65409 (bricklaying)
- Returns list of available unit standards for multi-select
- Returns previously selected unit standards for this learner

**`mobile/save_bricklayer_gap_closure.php`** (NEW)
- Saves ACR recommendations (Status: Not Ready, Recommended, Recommended for Gap Closure)
- Saves selected unit standards when "Recommended for Gap Closure" is chosen
- Stores data with learnerID linking for retrieval

---

## Flutter Implementation

### Files Modified

**`lib/config.dart`** (UPDATED)
- Added URL config for gap closure endpoints:
  - `getBricklayerGapUnitStandardsUrl`
  - `saveBricklayerGapClosureUrl`

**`lib/ArplToolkitBricklayerPage.dart`** (COMPLETELY UPDATED)

#### New State Variables
```dart
// Appendix H - Gap Closure
final Map<int, String> _appendixHStatus = {};
final Map<int, TextEditingController> _appendixHRemarks = {};
bool _gapStandardsLoading = false;
List<Map<String, dynamic>> _availableGapUnitStandards = [];
final Set<String> _selectedGapUnitStandards = {};
```

#### New Methods
- `_buildAppendixH()` - Full Appendix H form with 4 ACR items
- `_buildAcrItemCard()` - Card UI for each ACR recommendation
- `_buildGapClosureSection()` - Multi-select checkboxes for unit standards
- `_loadGapUnitStandards()` - Fetch available unit standards from API
- `_saveGapClosureData()` - Save recommendations and selected unit standards
- `_getAcrItemName()` - Get label for ACR item (1-4)
- `_getStatusColor()` - Get status badge color

#### UI Features
- **Edit Mode**: Dropdown/button selection for status + remarks field
- **View Mode**: Color-coded status badges
- **Gap Closure Section**: Shows only when Overall Result = "Recommended for Gap Closure"
- **Multi-select**: Checkboxes for selecting unit standards from list

---

## Workflow

### User Experience Flow

1. **Appendix H Tab**: Assessor sees 4 ACR items:
   - Foundation Knowledge & Competency
   - Practical & Workplace Skills
   - Health, Safety & Environment
   - **Overall Result** (highlighted in purple)

2. **Editing Assessments**:
   - Assessor selects status for each (Not Ready/Recommended/Recommended for Gap Closure)
   - Can add remarks for each
   - Can only select gap closure status for overall result

3. **Gap Closure Trigger**:
   - When Overall Result = "Recommended for Gap Closure"
   - Golden section appears below showing available unit standards
   - Assessor checks unit standards learner should complete
   - Selected count shown at bottom

4. **Saving**:
   - Click Save FAB
   - Both recommendations and gap unit standards saved
   - Next_action returned: "gap_closure" if applicable

---

## Data Structure

### Appendix H Response Format (from PHP)

```json
{
  "appendixH": {
    "items": [
      {"acrId": 1, "assessmentType": "Foundation Knowledge"},
      ...
    ],
    "recommendations": [
      {
        "recommendationId": 1,
        "learnerId": 20286,
        "acrId": 1,
        "trade": "bricklayer",
        "ofoCode": "641201",
        "status": "Recommended",
        "remarks": "...",
        "createdAt": "...",
        "updatedAt": "..."
      },
      ...
    ],
    "gap_standards": [
      {
        "unit_standard_id": "...",
        "unit_standard_name": "...",
        "assigned_date": "..."
      },
      ...
    ]
  }
}
```

---

## Qualification & OFO Information

- **Bricklayer Trade:** OFO 641201
- **Qualification:** 65409 (Building and Civil Construction)
- **Unit Standards:** Available for multi-select in gap closure
- **Trade Reference:** Bricklaying activities from `arplappxb_bricklaying_activities`

---

## Testing Checklist

- [ ] Load Appendix B - Shows bricklaying theory activities (10 items)
- [ ] Load Appendix C - Shows empty (as intended)
- [ ] Load Appendix H - Shows 4 ACR items with saved recommendations
- [ ] Edit Appendix H - Select status and remarks for each item
- [ ] Select "Recommended for Gap Closure" on Overall Result
- [ ] Golden section appears with unit standards list
- [ ] Multi-select unit standards using checkboxes
- [ ] Save and verify data persisted in database
- [ ] Reload page and verify recommendations/selections retained
- [ ] Test with multiple learners
- [ ] Verify different status selections (Not Ready, Recommended, Gap Closure)

---

## Next Steps

1. **Build APK**: `flutter build apk --release`
2. **Test on Device**: Install and test with real bricklayer learner data
3. **Verify Database**: Check `arplbricklayer_access_recommendation` and `arplbricklayer_gap_unit_standards` tables
4. **Monitor Logs**: Check Flutter console logs and PHP error logs

---

## Files Summary

| File | Status | Changes |
|------|--------|---------|
| `mobile/get_bricklayer_toolkit_data.php` | ✅ Updated | Load recommendations from bricklayer table |
| `mobile/get_bricklayer_gap_unit_standards.php` | ✅ New | Fetch unit standards for qualification 65409 |
| `mobile/save_bricklayer_gap_closure.php` | ✅ New | Save recommendations and gap standards |
| `lib/ArplToolkitBricklayerPage.dart` | ✅ Updated | Complete Appendix H implementation |
| `lib/config.dart` | ✅ Updated | Added endpoint URLs |
| `Database Tables` | ✅ Created | 2 new bricklayer-specific tables |

---

**Implementation Date:** July 10, 2026  
**Ready for:** APK Build and Device Testing
