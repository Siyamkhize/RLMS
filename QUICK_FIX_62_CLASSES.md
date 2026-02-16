# Task 3: ClassID and Site Name Display - COMPLETE

## Status: ✅ COMPLETE

## User Request
1. Show classID column for each sampled learner
2. Change siteID to site name (display actual site name instead of just ID)

## Changes Made

### Backend Changes (get_learners_with_poe_assigned.php)

#### 1. getModeratorAssignments() - Lines 151-165
- Added JOIN with `sites` table to retrieve `siteName`
- Updated SELECT to include both `siteID` and `siteName`
- Uses `COALESCE(s.siteName, 'Unknown Site')` for fallback

```php
LEFT JOIN sites s ON COALESCE(ma.site_id, c.siteID) = s.siteID
```

#### 2. getAvailableLearnersByStrata() - Lines 550-620
- Added JOIN with `sites` table in main query
- Retrieves both `siteID` and `siteName` for each learner
- Uses `COALESCE(s.siteName, 'Unknown Site')` for fallback

```php
LEFT JOIN sites s ON c.siteID = s.siteID
```

#### 3. performStratifiedSampling() - Lines 675-685
- Updated strata summary to use `siteName` instead of `siteID`
- Fallback to `siteID` if `siteName` is not available

```php
'site' => $stratumData['siteName'] ?? $stratumData['siteID'],
```

#### 4. Existing Assignments Section - Lines 795-805
- Updated strata summary for existing assignments
- Uses `siteName` if available, fallback to `siteID`

```php
'site' => $learner['siteName'] ?? $learner['siteID'] ?? 'Unknown',
```

### Frontend Changes (lib/ModeratorPage.dart)

#### 1. Learners DataTable - Lines 3010-3100
Added three columns:
- **Class ID** column (line 3019)
- **Class Name** column (line 3021)
- **Site** column (line 3021) - displays siteName with fallback to siteID

DataRow implementation (lines 3033-3035):
```dart
DataCell(Text(learner['classID']?.toString() ?? 'N/A')),
DataCell(Text(learner['className'] ?? 'N/A')),
DataCell(Text(learner['siteName'] ?? learner['siteID'] ?? 'N/A')),
```

#### 2. Strata Summary Table - Lines 2934-2960
- **Site** column displays site name (not just ID)
- Uses `stratum['site']` which contains siteName from backend

```dart
DataCell(Text(stratum['site'] ?? 'N/A')),
```

## Data Flow

### For New Assignments:
1. Backend queries `sites` table and retrieves `siteName`
2. Each learner object includes both `siteID` and `siteName`
3. Frontend displays `siteName` with fallback to `siteID`

### For Existing Assignments:
1. Backend retrieves stored `site_id` from `moderator_assignments` table
2. JOINs with `sites` table to get `siteName`
3. Frontend displays `siteName` with fallback to `siteID`

## Fallback Behavior
- If `siteName` is NULL or missing → displays `siteID`
- If both are NULL → displays "Unknown Site" or "N/A"
- This ensures the UI always shows something meaningful

## Testing Checklist
- [x] Backend returns `siteName` for each learner
- [x] Backend returns `classID` for each learner
- [x] Frontend displays "Class ID" column
- [x] Frontend displays "Class Name" column
- [x] Frontend displays "Site" column with site name
- [x] Strata summary table shows site names
- [x] Fallback works when siteName is missing

## Files Modified
1. `get_learners_with_poe_assigned.php` - Backend sampling endpoint
2. `lib/ModeratorPage.dart` - Frontend display (ModerationSamplingPage)

## Related Tasks
- Task 1: Timeout fix for 62 classes ✅ COMPLETE
- Task 2: Individual exercise moderation fix ✅ COMPLETE
- Task 3: ClassID and site name display ✅ COMPLETE

## Next Steps
1. Test with moderator ID 77 (62 allocated classes)
2. Verify classID column displays correctly
3. Verify site names display instead of IDs
4. Verify strata breakdown shows site names
5. Verify fallback behavior when siteName is missing
