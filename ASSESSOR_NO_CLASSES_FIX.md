# Assessor "No Classes Found" Issue - FIXED

## Problem
When logging in as an Assessor, the AssessorPage displayed "No classes found" because the required PHP endpoint `get_classes.php` was missing from the server.

## Root Cause
1. The `get_classes.php` file did not exist in the `php/` directory
2. The AssessorPage.dart was trying to fetch classes from a hardcoded URL that pointed to a non-existent endpoint
3. The URL was also pointing to the wrong domain (`rlms.rlms.co.za` instead of using AppConfig)

## Solution Implemented

### 1. Created `php/get_classes.php`
Created a new PHP endpoint that:
- Accepts `facilitator_id` as a query parameter
- Queries the database to fetch all classes associated with the facilitator
- Joins the `facilitator`, `class`, `sites`, `project`, and `learnerdetails` tables
- Returns class information including:
  - classID
  - className
  - siteID
  - siteName
  - project_id
  - Project_name
  - numberOfLearners (count of learners in each class)

### 2. Updated `lib/AssessorPage.dart`
Updated three instances of the `fetchClasses` function to:
- Use `AppConfig.buildUrl()` instead of hardcoded URLs
- Point to the correct server domain (rlms.rlms.co.za)
- Add better error handling and logging
- Check for error responses from the server
- Validate response format before returning data

The three locations updated:
1. Main `_AssessorPageState.fetchClasses()` - Line ~38
2. `_buildAssessorFeedback.fetchClasses()` - Line ~3172
3. `_PotholeChecklistClassListPageState._fetchClasses()` - Line ~5349

## Database Structure
The solution relies on this database relationship:
```
facilitator (facilitator_id, classID)
    ↓
class (classID, className, siteID)
    ↓
sites (siteID, siteName, project_id)
    ↓
project (project_id, Project_name)
    ↓
learnerdetails (LearnerID, classID)
```

## Testing
To test the fix:
1. Deploy `php/get_classes.php` to the server at `/mobile/get_classes.php`
2. Rebuild the Flutter app
3. Log in as an Assessor with a valid `facilitator_id`
4. The AssessorPage should now display all classes associated with that facilitator

## Next Steps
1. Deploy the PHP file to the production server
2. Test with actual assessor credentials
3. Verify that all classes are displayed correctly
4. Check that the "View" button works for each class

## Files Modified
- `php/get_classes.php` (NEW)
- `lib/AssessorPage.dart` (UPDATED - 3 functions)

## Notes
- The fix assumes that facilitators are linked to classes via the `facilitator.classID` field
- If a facilitator needs to access multiple classes, there should be multiple rows in the facilitator table with the same facilitator_id but different classID values
- The endpoint includes proper CORS headers for cross-origin requests
- Error handling has been improved with detailed logging for debugging
