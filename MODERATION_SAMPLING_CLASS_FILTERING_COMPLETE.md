# Moderation Sampling - Class Filtering Implementation

## Overview
Modified the moderation sampling system to filter learners based on the classes allocated to each moderator. Now moderators will only see learners from their assigned classes during sampling, not all learners in the project.

## Changes Made

### 1. Added `getModeratorClasses()` Function
**Location:** `get_learners_with_poe_assigned.php`

```php
function getModeratorClasses($mysqli, $moderatorId)
```

**Purpose:** Retrieves all classes allocated to a specific moderator from the `facilitator` table.

**Returns:** Array of classIDs that the moderator is assigned to.

**Logic:**
- Queries the `facilitator` table where `facilitator_id` matches the moderator
- Returns distinct classIDs
- If no classes found, returns empty array (moderator will see no learners)

### 2. Modified `getAvailableLearnersByStrata()` Function
**Changes:**
- Added `$moderatorId` parameter
- Calls `getModeratorClasses()` to get moderator's allocated classes
- Returns empty array if moderator has no allocated classes
- Filters POE learners by moderator's classes using `IN` clause
- Uses prepared statements with dynamic parameter binding for security

**Key Implementation:**
```php
// Get moderator's allocated classes
$moderatorClasses = getModeratorClasses($mysqli, $moderatorId);

if (empty($moderatorClasses)) {
    return []; // No classes = no learners
}

// Build class filter for SQL
$placeholders = implode(',', array_fill(0, count($moderatorClasses), '?'));
$classFilter = "AND l.classID IN ($placeholders)";
```

### 3. Modified `getModeratorAssignments()` Function
**Changes:**
- Added class filtering to existing assignments retrieval
- Ensures moderators only see their previously assigned learners from their allocated classes
- Uses same class filtering logic as new assignments

**Purpose:** Prevents moderators from seeing learners assigned to them from classes they're no longer allocated to.

### 4. Updated Function Call
**Location:** `getLearnersWithPOEForModerator()`

Changed from:
```php
$strata = getAvailableLearnersByStrata($mysqli);
```

To:
```php
$strata = getAvailableLearnersByStrata($mysqli, $moderatorId);
```

## Database Schema

### Facilitator Table (Existing)
The system uses the existing `facilitator` table to determine class allocations:

```sql
SELECT DISTINCT classID 
FROM facilitator 
WHERE facilitator_id = ?
```

**Key Points:**
- A moderator can be assigned to multiple classes
- Each row in `facilitator` table represents one class assignment
- The `facilitator_id` column stores the moderator's ID

## How It Works

### Scenario 1: New Sampling Assignment
1. Moderator requests sampling via API with their `moderator_id`
2. System queries `facilitator` table to get moderator's allocated classes
3. System filters learners with POE to only include those from moderator's classes
4. Stratified sampling (25%) is performed on the filtered learner pool
5. Selected learners are assigned to the moderator
6. Assignment includes class metadata for future reference

### Scenario 2: Existing Assignment Retrieval
1. Moderator requests their assigned learners
2. System queries `moderator_assignments` table
3. Results are filtered to only include learners from moderator's current allocated classes
4. This ensures moderators don't see old assignments from classes they're no longer assigned to

### Scenario 3: No Classes Allocated
1. Moderator has no entries in `facilitator` table
2. `getModeratorClasses()` returns empty array
3. Sampling returns 0 learners with appropriate message
4. Moderator sees empty list in the app

## Testing

### Test File Created
**File:** `test_moderator_class_filtering.php`

**Usage:**
```
http://your-server/test_moderator_class_filtering.php?moderator_id=YOUR_MODERATOR_ID
```

**Test Steps:**
1. Retrieves moderator's allocated classes
2. Counts learners with POE in those classes
3. Calls the sampling API
4. Verifies all returned learners are from moderator's classes
5. Displays detailed breakdown and validation results

**Expected Output:**
- List of moderator's allocated classes
- Count of learners with POE per class
- API response validation
- Class filtering verification (✅ or ❌)
- Sampling summary with strata breakdown

## Benefits

### 1. **Proper Scope Control**
- Moderators only see learners they're responsible for
- No access to learners from other classes/projects

### 2. **Fair Workload Distribution**
- Each moderator gets 25% sample from their own classes
- No overlap between moderators' assignments

### 3. **Multi-Project Support**
- Moderators can work across multiple classes/sites
- System automatically includes all their allocated classes

### 4. **Security & Privacy**
- Moderators can't access learner data outside their scope
- Follows principle of least privilege

### 5. **Accurate Sampling**
- Stratification still works within moderator's class scope
- Maintains statistical validity of sampling

## API Response

### Success Response (With Classes)
```json
{
  "status": "success",
  "message": "Learners with POE retrieved successfully using stratified sampling",
  "data": {
    "total_learners_with_poe": 50,
    "selected_count": 12,
    "learners": [...],
    "sampling_method": "stratified_comprehensive",
    "strata_summary": [
      {
        "class": "Class A",
        "classID": "123",
        "site": "Site 1",
        "poe_completeness": "Complete",
        "marking_status": "Marked",
        "performance_level": "High",
        "total_in_stratum": 10,
        "selected_from_stratum": 3,
        "sampling_rate": "30%"
      }
    ]
  }
}
```

### Success Response (No Classes)
```json
{
  "status": "success",
  "message": "Learners with POE retrieved successfully using stratified sampling",
  "data": {
    "total_learners_with_poe": 0,
    "selected_count": 0,
    "learners": [],
    "sampling_method": "stratified_comprehensive",
    "message": "No learners with POE available for assignment"
  }
}
```

## Deployment Checklist

- [x] Modified `get_learners_with_poe_assigned.php`
- [x] Added `getModeratorClasses()` function
- [x] Updated `getAvailableLearnersByStrata()` with class filtering
- [x] Updated `getModeratorAssignments()` with class filtering
- [x] Created test file `test_moderator_class_filtering.php`
- [ ] Test with actual moderator IDs from your system
- [ ] Verify moderators see only their class learners
- [ ] Verify sampling still works correctly
- [ ] Deploy to production server

## Notes

### Database Requirements
- Existing `facilitator` table must have moderator assignments
- Moderators must be added to `facilitator` table with their allocated classes
- No schema changes required

### Backward Compatibility
- Existing `moderator_assignments` records remain valid
- Old assignments are filtered by current class allocations
- No data migration needed

### Performance
- Added one additional query per request (get moderator classes)
- Query is fast (indexed on `facilitator_id`)
- Minimal performance impact
- Temp tables still used for efficient sampling

## Troubleshooting

### Issue: Moderator sees no learners
**Possible Causes:**
1. Moderator not added to `facilitator` table
2. No learners with POE in moderator's classes
3. All eligible learners already assigned to other moderators

**Solution:**
- Run test script to diagnose
- Check `facilitator` table for moderator's entries
- Verify learners exist with POE in those classes

### Issue: Moderator sees learners from wrong classes
**Possible Causes:**
1. Incorrect class assignments in `facilitator` table
2. Caching issue (unlikely with current implementation)

**Solution:**
- Verify `facilitator` table data
- Check learner's `classID` in `learnerdetails` table
- Run test script to validate filtering

## Summary

The moderation sampling system now properly respects class allocations. Each moderator will only see and moderate learners from the classes they are assigned to in the `facilitator` table. This ensures proper scope control, fair workload distribution, and maintains the integrity of the stratified sampling approach.

**Key Point:** Moderators must be added to the `facilitator` table with their allocated classes for this to work correctly.
