# SDP Sites Type Casting Fix

## Issue Description
The app was crashing with a `DatabaseException` when trying to cache SDP sites for offline use:

```
DatabaseException(java.lang.String cannot be cast to java.lang.Integer) 
sql 'INSERT OR REPLACE INTO sites (siteID, siteName, beneficiaries, classes, project_id, qualification_id, learningPathway, coordinates, category, province, project_name, sdp_name, qualification_name, project_pathway, pathways, pathway_count, qualifications, qualification_count, sdp_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
```

## Root Cause
1. **API Data Source**: Data comes from `get_sdp_all_data.php` endpoint called by `admin.dart`
2. **API Data Conversion**: PHP endpoint uses `array_map('strval', $site_row)` which converts all database values to strings
3. **Field Mismatch**: API response includes fields like `pathway_count`, `qualification_count`, `coordinates` that don't exist in the sites table
4. **Type Mismatch**: Database expects integers for fields like `siteID`, `project_id`, `sdp_id` but receives strings
5. **Direct Insert**: The `saveSdpSitesForOffline()` method was inserting raw API data without proper mapping/conversion

## Data Flow
```
get_sdp_all_data.php → admin.dart → saveSdpSitesForOffline() → sites table
```

The error occurs when `admin.dart` fetches SDP data online and tries to cache it for offline use.

## Solution Applied

### Updated `saveSdpSitesForOffline()` method in `lib/database_helper.dart`:

1. **Field Mapping**: Maps API fields to database schema fields
   - `coordinates` → split into `latitude` and `longitude`
   - `province` → `Province`
   - `category` → `Category`
   - Ignores extra fields like `pathway_count`, `qualification_count`

2. **Type Conversion**: Added `_parseToInt()` helper method to safely convert strings to integers
   - Handles `siteID`, `project_id`, `sdp_id` conversion
   - Returns null for invalid values instead of crashing

3. **Data Sanitization**: Removes null values before database insertion

### Key Changes:
```dart
// Before: Direct insert of raw API data
batch.insert('sites', site, conflictAlgorithm: ConflictAlgorithm.replace);

// After: Mapped and type-converted data
final mappedSite = <String, dynamic>{
  'siteID': _parseToInt(site['siteID']),
  'siteName': site['siteName']?.toString(),
  'beneficiaries': site['beneficiaries']?.toString(),
  'latitude': site['coordinates']?.toString().split(',')[0]?.trim(),
  'longitude': site['coordinates']?.toString().split(',')[1]?.trim(),
  'sdp_id': sdpIdInt ?? _parseToInt(site['sdp_id']),
  'Province': site['province']?.toString(),
  // ... other fields
};
```

## Files Modified
- `lib/database_helper.dart` - Updated `saveSdpSitesForOffline()` method and added `_parseToInt()` helper

## Testing Required
1. Test SDP admin dashboard site loading when online
2. Test offline functionality after sites are cached
3. Verify no crashes when switching between online/offline modes
4. Test with different SDP projects that have various data types

## Impact
- ✅ Fixes crash when caching SDP sites for offline use via `get_sdp_all_data.php`
- ✅ Maintains data integrity with proper type conversion
- ✅ Handles missing or invalid data gracefully
- ✅ Preserves all existing functionality

## Related Issues
This fix addresses the specific type casting issue in SDP sites caching from `get_sdp_all_data.php`. Similar issues might exist in other parts of the codebase where PHP endpoints use `array_map('strval')` and Flutter expects specific data types.