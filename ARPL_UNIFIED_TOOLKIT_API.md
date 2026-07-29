# ARPL Unified Toolkit API - All Trades

## Overview

All three trade-specific ARPL Toolkit forms (Electrician, Bricklayer, Plumber) now use a single unified API endpoint with consistent data structure. The backend API automatically routes to trade-specific data sources based on the OFO number.

## Single API Endpoint

**Endpoint**: `mobile/get_arpl_toolkit_data.php`

**Used by**:
- ArplToolkitViewerPage (Electrician)
- ArplToolkitBricklayerPage (Bricklayer)
- ArplToolkitPlumberPage (Plumber)

## Trade Routing

The API auto-detects the trade and routes to appropriate tables:

### Request
```json
{
  "learnerID": 72,
  "classID": 783,
  "ofoNumber": "671103",
  "trade": "bricklaying"
}
```

### Trade Detection (in priority order)
1. Use provided `trade` parameter if available
2. Query class's trade via `class.trade_id` → `arpl_trades` table
3. Query learner's qualification OFO number
4. Default to Electrician (OFO 671101)

### Trade → OFO Mapping
- **Electrician**: OFO 671101 → table prefix `electrician`
- **Bricklayer**: OFO 671103 → table prefix `bricklaying`
- **Plumber**: OFO 671102 → table prefix `plumbing`

## Consistent Data Structure

All trades return the same JSON response structure:

```json
{
  "status": "success",
  "learnerID": 72,
  "classID": 783,
  "ofoNumber": "671103",
  "trade": "bricklaying",
  "learner": { /* LearnerDetails */ },
  "facilitator": null,
  "class_info": { /* ClassInfo */ },
  "competency_scale": [ /* Array of competency levels */ ],
  
  "appendixB": [ /* Theory Assessment activities */ ],
  "appendixD": { /* Practical Skills yes/no responses */ },
  "appendixE": [ /* Workplace Experience activities */ ],
  "appendixH": {
    "items": [ /* ACR assessment items */ ],
    "recommendations": [ /* Access recommendations */ ],
    "gap_standards": [ /* Gap analysis standards */ ]
  },
  
  "appendixA": null,
  "appendixC": null,
  "appendixF": null,
  "appendixG": null,
  "appendixI": null,
  "appendixJ": null
}
```

## Database Tables Used by Trade

### Shared Tables (all trades)
- `learnerdetails` - Learner information
- `class` - Class information with trade_id
- `arpl_trades` - Trade definitions (OFO numbers)
- `arpl_competency_scale` - Competency ratings 1-5
- `arplappxb_activity_ratings` - Appendix B ratings (all trades)

### Electrician (671101) - Table Prefix: `electrician`
- `arplappxb_electrician_activities` - Theory activities
- `arplappxe_electrician_activities` - Workplace activities
- `appxh_acrelectrician` - ACR items (4 assessment components)
- `arplelectrician_access_recommendation` - Recommendations
- `arpl_appendix_*_electrician` - Other appendices (A, C, D, F, G, I, J)

### Bricklayer (671103) - Table Prefix: `bricklaying`
- `arplappxb_bricklaying_activities` - Theory activities
- `arplappxe_bricklaying_activities` - Workplace activities
- `appxh_acrbricklaying` - ACR items
- `arplbricklaying_access_recommendation` - Recommendations
- `arpl_appendix_*_bricklayer` - Other appendices

### Plumber (671102) - Table Prefix: `plumbing`
- `arplappxb_plumbing_activities` - Theory activities
- `arplappxe_plumbing_activities` - Workplace activities
- `appxh_acrplumbing` - ACR items
- `arplplumbing_access_recommendation` - Recommendations
- `arpl_appendix_*_plumber` - Other appendices

## UI/Form Structure

All three trade pages use the **same form structure and UI layout**:

1. **Same data parsing** via `ArplToolkitData.fromJson()` model
2. **Same tab layout** - 11 tabs for all appendices
3. **Same field types and validation** - All trades use consistent form controls
4. **Trade-specific content only** - Activities populated from trade-specific tables

The visual consistency ensures users get the same experience regardless of trade, with only the data content varying based on trade-specific activities.

## Benefits of Unified Approach

✅ **Single API** - No need for multiple endpoints  
✅ **Consistent UI** - Same form layout for all trades  
✅ **Maintainability** - One API file to maintain  
✅ **Extensibility** - New trades can be added easily  
✅ **Data Consistency** - Same response format guarantees predictable UI  

## Implementation

**Dart Config** (`lib/config.dart`):
```dart
static String get getArplToolkitDataUrl =>
    '$baseUrl/get_arpl_toolkit_data.php';
static String get getBricklayerToolkitDataUrl =>
    '$baseUrl/get_arpl_toolkit_data.php'; // Unified
static String get getPlumberToolkitDataUrl =>
    '$baseUrl/get_arpl_toolkit_data.php'; // Unified
```

**All pages use same endpoint**:
- `ArplToolkitViewerPage` (Electrician)
- `ArplToolkitBricklayerPage` (Bricklayer)
- `ArplToolkitPlumberPage` (Plumber)

All call: `AppConfig.getArplToolkitDataUrl`
