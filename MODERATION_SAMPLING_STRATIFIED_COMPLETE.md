# Moderation Sampling with Stratified Method - Complete Implementation

## Summary
Implemented a sophisticated moderation sampling system using **stratified random sampling** methodology to ensure fair and representative selection of learners for moderation across all classes.

## What is Stratified Sampling?

Stratified sampling is a probability sampling technique where the population is divided into homogeneous subgroups (strata) and samples are randomly selected from each stratum proportionally.

### Benefits:
1. **Representative Selection**: Ensures all classes are represented
2. **Fair Distribution**: Each class contributes proportionally
3. **Reduced Bias**: Prevents over-representation of larger classes
4. **Statistical Validity**: More accurate than simple random sampling
5. **Audit Compliance**: Meets moderation standards and requirements

## How It Works

### 1. **Stratification by Class**
- Learners are grouped by their class (stratum)
- Each class becomes an independent sampling unit
- Maintains class diversity in the sample

### 2. **Proportional Selection**
- 25% of learners selected from EACH class
- Minimum of 1 learner per class (if class has learners)
- Random selection within each stratum

### 3. **Assignment Persistence**
- Each moderator gets ONE assignment (permanent)
- Learners can only be assigned to ONE moderator
- Prevents duplicate moderation work

### Example:
```
Class A: 20 learners → 5 selected (25%)
Class B: 8 learners  → 2 selected (25%)
Class C: 12 learners → 3 selected (25%)
Total: 40 learners   → 10 selected (25%)
```

## Files Created/Updated

### 1. **get_learners_with_poe_assigned.php** (Updated with Stratified Sampling)

**Key Features:**
- Stratified random sampling by class
- Persistent moderator assignments
- Detailed strata summary reporting
- Prevents duplicate assignments

**Database Table:**
```sql
CREATE TABLE moderator_assignments (
    id INT(11) AUTO_INCREMENT PRIMARY KEY,
    moderator_id VARCHAR(50) NOT NULL,
    learner_id INT(11) NOT NULL,
    class_id VARCHAR(50) NULL,
    stratum_type VARCHAR(50) NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_learner (learner_id),
    KEY idx_moderator (moderator_id),
    KEY idx_class (class_id)
);
```

**API Response Structure:**
```json
{
  "status": "success",
  "message": "Learners with POE retrieved successfully using stratified sampling",
  "data": {
    "total_learners_with_poe": 100,
    "selected_count": 25,
    "is_existing_assignment": false,
    "sampling_method": "stratified",
    "sampling_rate": "25%",
    "strata_summary": [
      {
        "classID": "C001",
        "className": "Road Construction 2024",
        "siteID": "S01",
        "total_in_stratum": 40,
        "selected_from_stratum": 10,
        "sampling_rate": "25%"
      }
    ],
    "learners": [...]
  }
}
```

### 2. **lib/ModeratorPage.dart** (Updated)

**Added:**
- New menu item: "Moderation Sampling"
- `ModerationSamplingPage` widget with full UI
- Integration with stratified sampling API

## UI Features

### Moderation Sampling Page Includes:

1. **Summary Cards**
   - Total learners available
   - Number selected (25%)
   - Visual indicators

2. **Status Badge**
   - Shows if assignment is new or existing
   - Color-coded for quick identification

3. **Strata Summary Table** (for new assignments)
   - Class ID and name
   - Site information
   - Total learners in class
   - Number selected from class
   - Sampling rate per class

4. **Class Distribution** (for existing assignments)
   - Chips showing learner count per class
   - Quick overview of distribution

5. **Assigned Learners Table**
   - Full learner details
   - Class information
   - POE count
   - "Moderate" button to start moderation

6. **Refresh Button**
   - Reload sampling data
   - Check for updates

## Usage Flow

### For Moderators:

1. **First Time Access:**
   ```
   - Click "Moderation Sampling" in menu
   - System performs stratified sampling
   - 25% selected from each class
   - Assignment is saved permanently
   - View assigned learners
   ```

2. **Subsequent Access:**
   ```
   - Click "Moderation Sampling"
   - System loads existing assignment
   - Shows same learners as before
   - Can start moderation work
   ```

3. **Moderation Work:**
   ```
   - Click "Moderate" button for any learner
   - Opens full moderation interface
   - Review POE, marks, assessments
   - Uphold or withdraw decisions
   ```

## API Endpoints

### GET: get_learners_with_poe_assigned.php

**Parameters:**
- `moderator_id` (required): The moderator's ID

**Response Fields:**
- `total_learners_with_poe`: Total learners with POE available
- `selected_count`: Number of learners assigned to this moderator
- `is_existing_assignment`: Boolean indicating if this is a previous assignment
- `sampling_method`: "stratified"
- `sampling_rate`: "25%"
- `strata_summary`: Array of class-level sampling details
- `learners`: Array of assigned learner objects

## Advantages Over Simple Random Sampling

| Aspect | Simple Random | Stratified |
|--------|---------------|------------|
| Class Representation | Not guaranteed | Guaranteed |
| Small Class Coverage | May be missed | Always included |
| Large Class Dominance | Possible | Prevented |
| Statistical Validity | Lower | Higher |
| Audit Compliance | Questionable | Strong |
| Fairness | Variable | Consistent |

## Testing

### Test Scenarios:

1. **New Moderator Assignment:**
   ```
   - Login as moderator (first time)
   - Navigate to Moderation Sampling
   - Verify 25% selected from each class
   - Check strata summary table
   - Confirm learners are displayed
   ```

2. **Existing Assignment:**
   ```
   - Login as same moderator again
   - Navigate to Moderation Sampling
   - Verify same learners are shown
   - Check "Existing Assignment" badge
   - Confirm no new sampling occurred
   ```

3. **Multiple Moderators:**
   ```
   - Login as Moderator A → gets 25% sample
   - Login as Moderator B → gets different 25% sample
   - Verify no learner overlap
   - Confirm each gets fair distribution
   ```

4. **Edge Cases:**
   ```
   - Class with 1 learner → 1 selected (100%)
   - Class with 3 learners → 1 selected (33%)
   - Empty classes → skipped
   - No POE available → appropriate message
   ```

## Database Queries

### Check Moderator Assignments:
```sql
SELECT 
    ma.moderator_id,
    COUNT(DISTINCT ma.learner_id) as total_assigned,
    COUNT(DISTINCT ma.class_id) as classes_covered
FROM moderator_assignments ma
GROUP BY ma.moderator_id;
```

### View Sampling Distribution:
```sql
SELECT 
    ma.class_id,
    c.className,
    COUNT(ma.learner_id) as assigned_count,
    (SELECT COUNT(*) FROM learnerdetails l 
     INNER JOIN poe p ON l.LearnerID = p.learnerID 
     WHERE l.classID = ma.class_id 
     AND p.filePath IS NOT NULL) as total_with_poe
FROM moderator_assignments ma
LEFT JOIN class c ON ma.class_id = c.classID
WHERE ma.moderator_id = 'MOD001'
GROUP BY ma.class_id, c.className;
```

### Reset Assignments (if needed):
```sql
-- Reset specific moderator
DELETE FROM moderator_assignments WHERE moderator_id = 'MOD001';

-- Reset all assignments
TRUNCATE TABLE moderator_assignments;
```

## Configuration

### Adjust Sampling Rate:
In `get_learners_with_poe_assigned.php`, change the sampling rate:

```php
// Current: 25%
$samplingResult = performStratifiedSampling($strata, 0.25);

// For 30%:
$samplingResult = performStratifiedSampling($strata, 0.30);

// For 20%:
$samplingResult = performStratifiedSampling($strata, 0.20);
```

### Change Stratification Method:
Currently stratified by class. Can be modified to stratify by:
- Site
- Performance level
- Assessment completion status
- Date ranges

## Compliance & Audit

### Audit Trail:
- All assignments are timestamped
- Stratum type is recorded
- Assignment history is preserved
- Can generate reports showing:
  - Who was assigned what
  - When assignments were made
  - Distribution across strata

### Reporting:
```sql
-- Moderation coverage report
SELECT 
    c.className,
    COUNT(DISTINCT l.LearnerID) as total_learners,
    COUNT(DISTINCT ma.learner_id) as moderated_learners,
    ROUND((COUNT(DISTINCT ma.learner_id) / COUNT(DISTINCT l.LearnerID)) * 100, 2) as coverage_percentage
FROM class c
LEFT JOIN learnerdetails l ON c.classID = l.classID
LEFT JOIN moderator_assignments ma ON l.LearnerID = ma.learner_id
GROUP BY c.classID, c.className;
```

## Deployment

1. **Upload PHP File:**
   ```bash
   upload get_learners_with_poe_assigned.php to server
   ```

2. **Database Table:**
   - Table is created automatically on first use
   - Or run the CREATE TABLE statement manually

3. **Rebuild Flutter App:**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk
   ```

4. **Test:**
   - Login as moderator
   - Click Moderation Sampling
   - Verify stratified selection works

## Troubleshooting

### Issue: No learners showing
**Solution:** Check that learners have uploaded POE with valid file paths

### Issue: Same learners for all moderators
**Solution:** Check unique constraint on learner_id in moderator_assignments table

### Issue: Sampling rate not 25%
**Solution:** Small classes may have different rates (minimum 1 learner per class)

### Issue: Assignment not persisting
**Solution:** Check database connection and table creation

## Future Enhancements

1. **Multi-level Stratification:**
   - Stratify by class AND site
   - Stratify by performance level

2. **Dynamic Sampling Rates:**
   - Different rates for different strata
   - Risk-based sampling

3. **Re-assignment:**
   - Allow moderators to request new sample
   - Swap learners between moderators

4. **Analytics Dashboard:**
   - Moderation progress tracking
   - Coverage visualization
   - Performance metrics

---

**Status**: ✅ Complete and Ready for Production
**Sampling Method**: Stratified Random Sampling (25% per class)
**Date**: January 23, 2026
