# Learner Duplicate Prevention - Implementation Complete

## Overview
Implemented project-specific duplicate learner prevention. Learners can now exist in multiple projects, but duplicates within the same project are prevented with user confirmation.

## Changes Made

### 1. Database Helper (`lib/database_helper.dart`)

#### Modified `insertOrUpdateLearner()` Method
- Now checks for duplicates by **IDNumber + project_id** (not just IDNumber)
- Gets project_id from classID via: `class` → `sites` (JOIN on siteID) → `project_id`
- Allows same learner in different projects
- Prevents duplicates within same project
- Logs: "Updated existing learner with ID: X (same project)" vs "Inserted new learner with ID: X"

#### Added `checkLearnerExistsInProject()` Method
```dart
Future<Map<String, dynamic>?> checkLearnerExistsInProject(
    String idNumber, String classID)
```
- Returns existing learner data if found in same project
- Returns null if learner doesn't exist in project
- Includes className, siteName, project_id in result
- Used by UI to show confirmation dialog

### 2. Standalone Add Learner Page (`lib/AddLearnerPage.dart`)

#### Updated `_submitLearnerData()` Method
- Checks for duplicate before insertion using `checkLearnerExistsInProject()`
- Shows confirmation dialog if learner exists in same project:
  - Title: "Learner Already Exists"
  - Shows: ID Number, Class Name, Site Name
  - Options: "Cancel" or "Update" (orange button)
- If user cancels: Returns false, no changes made
- If user confirms: Updates existing learner
- Success messages differentiate between "added" and "updated"

### 3. Embedded Add Learner Page (`lib/learner_list_page.dart`)

#### Updated `_submitLearnerData()` Method
- Same duplicate check logic as standalone page
- Shows same confirmation dialog
- Handles both online and offline scenarios
- Success messages:
  - Online: "Learner added/updated successfully"
  - Offline: "Learner saved/updated in local database! Will sync when online."

### 4. Backend PHP (`php/add_learner.php`)

#### Updated Duplicate Check Logic
- Gets project_id from classID via SQL JOIN:
  ```sql
  SELECT s.project_id 
  FROM class c 
  JOIN sites s ON c.siteID = s.siteID 
  WHERE c.classID = ?
  ```
- Checks for duplicate by IDNumber + project_id:
  ```sql
  SELECT ld.LearnerID 
  FROM learnerdetails ld
  JOIN class c ON ld.classID = c.classID
  JOIN sites s ON c.siteID = s.siteID
  WHERE ld.IDNumber = ? AND s.project_id = ?
  ```
- Fallback to old behavior if project_id not found
- Updates existing learner if found in same project
- Inserts new learner if not found in project

## Database Schema

### Relationships
```
learnerdetails.classID → class.classID
class.siteID → sites.siteID
sites.project_id → project identifier
```

### Key Fields
- `learnerdetails.IDNumber` - Learner's ID number (can duplicate across projects)
- `learnerdetails.classID` - Links to class table
- `class.siteID` - Links to sites table
- `sites.project_id` - Project identifier (used for duplicate checking)

## User Experience

### Scenario 1: New Learner
1. User fills in learner form with ID Number
2. System checks if learner exists in current project
3. Learner doesn't exist → Inserts as new learner
4. Success message: "Learner added successfully"

### Scenario 2: Duplicate in Same Project
1. User fills in learner form with existing ID Number
2. System detects learner exists in same project
3. Shows dialog:
   ```
   Learner Already Exists
   
   A learner with ID Number 1234567890123 already exists in this project.
   
   Class: Class A
   Site: Site Name
   
   Do you want to update the existing learner data?
   
   [Cancel]  [Update]
   ```
4. If Cancel → No changes made
5. If Update → Updates existing learner data
6. Success message: "Learner updated successfully"

### Scenario 3: Duplicate in Different Project
1. User fills in learner form with ID Number from another project
2. System checks current project only
3. Learner doesn't exist in current project → Inserts as new learner
4. Success message: "Learner added successfully"
5. Result: Same person now exists in multiple projects (allowed)

## Offline Support

### Offline Behavior
- Duplicate check works offline using local database
- Same confirmation dialog shown
- Changes queued for sync when online
- Success message: "Learner saved/updated in local database! Will sync when online."

### Sync Behavior
- When syncing, backend also checks project-specific duplicates
- Server-side logic matches client-side logic
- Prevents duplicate creation during sync

## Testing Checklist

- [x] Add new learner (not in any project) → Inserts successfully
- [x] Add learner with existing ID in same project → Shows confirmation dialog
- [x] Cancel confirmation dialog → No changes made
- [x] Confirm update → Updates existing learner
- [x] Add learner with existing ID in different project → Inserts as new
- [x] Offline: Add new learner → Saves locally
- [x] Offline: Update existing learner → Updates locally
- [x] Sync after offline changes → Syncs correctly without duplicates

## Benefits

1. **Prevents Accidental Duplicates**: Users can't accidentally create duplicate learners in same project
2. **Allows Cross-Project Learners**: Same person can be in multiple projects (common requirement)
3. **User Confirmation**: Users explicitly choose to update existing data
4. **Data Integrity**: Maintains clean data across online and offline scenarios
5. **Clear Feedback**: Users know if they're adding new or updating existing

## Technical Notes

- Uses SQL JOINs for efficient project_id lookup
- Minimal performance impact (single JOIN query)
- Fallback logic if project_id not found (backwards compatible)
- Works with existing database schema (no schema changes needed)
- Consistent behavior across Flutter app and PHP backend

## Files Modified

1. `lib/database_helper.dart` - Core duplicate checking logic
2. `lib/AddLearnerPage.dart` - Standalone add learner page
3. `lib/learner_list_page.dart` - Embedded add learner page
4. `php/add_learner.php` - Backend duplicate checking

## Status: ✅ COMPLETE

All duplicate prevention logic implemented and tested. Ready for production use.
