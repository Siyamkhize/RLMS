# Moderation Sampling - Class-Based Stratification Complete

## Issue Fixed
The comprehensive stratified sampling was failing because the database schema doesn't support the expected columns:
- `poe` table does NOT have `unit_standard_id` column
- `poe` table does NOT have marks-related columns
- `moderator_assignments` table does NOT have `class_id` column

## Solution Implemented
Simplified the stratification to work with the actual database structure:

### Stratification Method: Class-Based
- **Primary Dimension**: Class (classID)
- **Informational**: Site (siteID)
- **Sampling Rate**: 25% from each class

### How It Works
1. **Query Available Learners**: Gets all learners with POE who haven't been assigned yet
2. **Group by Class**: Creates strata based on classID
3. **Random Selection**: Selects 25% from each class (minimum 1 per class)
4. **Assignment**: Stores assignments in `moderator_assignments` table with `stratum_type = 'class-based'`
5. **Persistence**: Once assigned, moderator always gets the same learners

### Database Structure Used
```sql
-- moderator_assignments table
CREATE TABLE moderator_assignments (
    id INT(11) AUTO_INCREMENT PRIMARY KEY,
    moderator_id VARCHAR(50) NOT NULL,
    learner_id INT(11) NOT NULL,
    stratum_type VARCHAR(50) NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_learner (learner_id)
);
```

### API Response Structure
```json
{
  "status": "success",
  "message": "Learners with POE retrieved successfully using stratified sampling",
  "data": {
    "total_learners_with_poe": 100,
    "selected_count": 25,
    "sampling_method": "stratified_class_based",
    "sampling_rate": "25%",
    "total_strata": 5,
    "is_existing_assignment": false,
    "stratification_dimensions": [
      "Class (Primary)",
      "Site (Informational)"
    ],
    "strata_summary": [
      {
        "class": "Class A",
        "classID": "1",
        "site": "Site 1",
        "total_in_stratum": 20,
        "selected_from_stratum": 5,
        "sampling_rate": "25%"
      }
    ],
    "learners": [...]
  }
}
```

## Files Modified
1. **get_learners_with_poe_assigned.php**
   - Simplified `getAvailableLearnersByStrata()` to only query existing columns
   - Updated `performStratifiedSampling()` to use class-based stratification
   - Modified `assignLearnersToModerator()` to use 'class-based' stratum type
   - Updated `getLearnersWithPOEForModerator()` to reflect simplified approach
   - Added comments explaining database constraints

## Testing Instructions
1. Upload `get_learners_with_poe_assigned.php` to server
2. Test endpoint:
   ```
   https://rlms.rlms.co.za/mobile/get_learners_with_poe_assigned.php?moderator_id=TEST001
   ```
3. Expected result: No errors, returns learners grouped by class
4. In app: Login as moderator → Click "Moderation Sampling" → Should load without errors

## Flutter UI
The Flutter UI (`lib/ModeratorPage.dart`) already displays:
- Total learners available
- Selected count
- Sampling method
- Strata summary with class breakdown
- Individual learner cards

The UI will automatically adapt to the simplified stratification data.

## Why This Approach?
- **Works with actual database**: No assumptions about non-existent columns
- **Still provides fair sampling**: 25% from each class ensures representation
- **Maintains core functionality**: Moderators get a representative sample
- **Extensible**: Can add more dimensions when database schema is updated

## Future Enhancements (When Database Supports)
If the database is updated to include:
- `marks` table with `unit_standard_id` and `learner_id`
- Performance/marking status columns

Then we can enhance to multi-dimensional stratification:
- Class + Marking Status
- Class + Performance Level
- Class + POE Completeness

## Status
✅ **COMPLETE** - Ready for testing
- No more column errors
- Simplified to work with actual database structure
- Maintains stratified random sampling principle
- 25% selection rate from each class
