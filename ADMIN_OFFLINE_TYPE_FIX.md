# Admin Page Offline Type Error Fix

## Issue
When viewing sites offline in admin.dart, a Flutter error occurred:
```
type 'int' is not a subtype of type 'String'
```

The query successfully found 7 sites, but the error occurred when displaying the data in the DataTable.

## Root Cause
Database fields like `beneficiaries`, `classes`, `coordinates`, `province`, `sdp_id`, and `project_id` are stored as integers in SQLite, but the DataCell(Text()) widget expects strings. When these integer values were passed directly to Text(), Flutter threw a type error.

## Fix Applied

### 1. Fixed Type Conversion in admin.dart (lines 986-1004)
Added `.toString()` calls to ensure all values are converted to strings before being passed to DataCell(Text()):

```dart
DataCell(Text(item['siteName']?.toString() ?? 'N/A')),
DataCell(Text((item['project_name'] ?? item['project_id'] ?? 'N/A').toString())),
DataCell(Text((item['sdp_name'] ?? item['sdp_client_name'] ?? item['sdp_id'] ?? 'N/A').toString())),
DataCell(Text(item['beneficiaries']?.toString() ?? 'N/A')),
DataCell(Text(item['classes']?.toString() ?? 'N/A')),
DataCell(Text(item['coordinates']?.toString() ?? 'N/A')),
DataCell(Text((item['province'] ?? item['Province'] ?? 'N/A').toString())),
```

### 2. Enhanced Sites Sync in sync_service.dart
Added missing fields to syncSites() method:
- first_name
- last_name
- cell_phone
- email

These fields exist in the database schema but were not being synced from the server.

## Verification

### Sites Sync Status
✅ Sites sync already uses UPDATE/INSERT pattern (ConflictAlgorithm.replace)
✅ No clearTable() call - preserves local data
✅ All database fields now included in sync

### Database Schema (sites table)
- siteID (INTEGER PRIMARY KEY)
- siteName (VARCHAR)
- beneficiaries (VARCHAR)
- latitude, longitude (VARCHAR)
- sdp_id (INTEGER)
- Province, District, Municipality, Category (VARCHAR)
- project_id (INTEGER)
- Project_pathway (VARCHAR)
- qualification_id (VARCHAR) ✅ Already included in sync
- first_name, last_name, cell_phone, email (VARCHAR) ✅ Now included

## Test Results from Logs
```
[ADMIN] Total sites in database: 99
[ADMIN] Sites by SDP:
  - SDP ID 6: 7 sites
[ADMIN] Filtering by project_id: 79
[ADMIN] Filtering by pathway: Short Skills Programme
[ADMIN] Filtering by qualification_id: 49648 (including null)
[ADMIN] Found 7 sites matching filters
[ADMIN] ✅ Returning 7 normalized sites
```

Query executed successfully and found 7 sites. The type error should now be resolved with proper string conversion.

## Files Modified
1. `lib/admin.dart` - Added .toString() to all DataCell values
2. `lib/sync_service.dart` - Added missing fields to sites sync

## Next Steps
1. Test admin page offline to verify sites display correctly
2. Verify all 7 sites show in the DataTable without type errors
3. Continue with remaining tasks:
   - Apply UPDATE/INSERT pattern to other sync methods (project, class, learners, etc.)
   - Add offline support to learner_list_page.dart
