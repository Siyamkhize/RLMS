# Moderation Sampling - Comprehensive Stratified Sampling COMPLETE

## Overview
Implemented **comprehensive 5-dimensional stratified random sampling** for moderation assignments to ensure fair and representative learner selection.

## Stratification Dimensions

### 1. **Class** (Primary)
- Different classes may have different teaching approaches
- Ensures representation from all classes
- One site can have multiple classes (Class A, Class B, etc.)

### 2. **Site** (Location)
- Multiple classes can exist at one site
- Each site may have unique characteristics
- Ensures geographic/location diversity

### 3. **POE Completeness**
- **Complete**: 3+ POE documents uploaded
- **Partial**: 1-2 POE documents uploaded
- **Incomplete**: 0 POE documents (filtered out - only learners with POE are sampled)

### 4. **Marking Status**
- **Marked**: Learner has assessment marks in the `marks` table
- **Not Marked**: Learner has no marks yet (assessments pending)
- Ensures moderators review both assessed and unassessed work

### 5. **Performance Level**
- **High**: Average marks ≥ 70%
- **Medium**: Average marks 50-69%
- **Low**: Average marks < 50%
- **Not Assessed**: No marks recorded yet
- Based on average of all marks in the `marks` table

## How It Works

### Sampling Process
1. **Query Available Learners**: Gets all learners with POE who haven't been assigned
2. **Calculate Dimensions**: For each learner, determines:
   - Class and Site from `learnerdetails` and `class` tables
   - POE count from `poe` table
   - Marking status from `marks` table (EXISTS check)
   - Performance level from `marks` table (AVG calculation)
3. **Create Strata**: Groups learners by composite key: `Class|Site|POE|Marking|Performance`
4. **Random Selection**: Selects 25% from each stratum (minimum 1 per stratum)
5. **Assignment**: Stores in `moderator_assignments` with `stratum_type = 'comprehensive'`
6. **Persistence**: Once assigned, moderator always gets the same learners

### Database Query
```sql
SELECT DISTINCT 
    l.LearnerID,
    l.Name,
    l.Surname,
    l.classID,
    c.className,
    c.siteID,
    COUNT(DISTINCT p.poe_id) as poe_count,
    -- Marking status
    CASE 
        WHEN EXISTS (SELECT 1 FROM marks m WHERE m.learnerID = l.LearnerID) 
        THEN 'Marked' 
        ELSE 'Not Marked' 
    END as marking_status,
    -- Performance level
    CASE 
        WHEN (SELECT AVG(marks_scored) FROM marks m WHERE m.learnerID = l.LearnerID) >= 70 THEN 'High'
        WHEN (SELECT AVG(marks_scored) FROM marks m WHERE m.learnerID = l.LearnerID) >= 50 THEN 'Medium'
        WHEN (SELECT AVG(marks_scored) FROM marks m WHERE m.learnerID = l.LearnerID) > 0 THEN 'Low'
        ELSE 'Not Assessed'
    END as performance_level,
    -- POE completeness
    CASE 
        WHEN COUNT(DISTINCT p.poe_id) >= 3 THEN 'Complete'
        WHEN COUNT(DISTINCT p.poe_id) >= 1 THEN 'Partial'
        ELSE 'Incomplete'
    END as poe_completeness
FROM learnerdetails l
INNER JOIN poe p ON l.LearnerID = p.learnerID
LEFT JOIN class c ON l.classID = c.classID
WHERE p.filePath IS NOT NULL 
AND l.LearnerID NOT IN (SELECT learner_id FROM moderator_assignments)
GROUP BY l.LearnerID
```

## API Response Structure
```json
{
  "status": "success",
  "data": {
    "total_learners_with_poe": 100,
    "selected_count": 25,
    "sampling_method": "stratified_comprehensive",
    "sampling_rate": "25%",
    "total_strata": 15,
    "stratification_dimensions": [
      "Class",
      "Site",
      "POE Completeness (Complete/Partial/Incomplete)",
      "Marking Status (Marked/Not Marked)",
      "Performance Level (High/Medium/Low/Not Assessed)"
    ],
    "strata_summary": [
      {
        "class": "Class A",
        "classID": "1",
        "site": "Site 1",
        "poe_completeness": "Complete",
        "marking_status": "Marked",
        "performance_level": "High",
        "total_in_stratum": 8,
        "selected_from_stratum": 2,
        "sampling_rate": "25%"
      },
      {
        "class": "Class A",
        "classID": "1",
        "site": "Site 1",
        "poe_completeness": "Partial",
        "marking_status": "Not Marked",
        "performance_level": "Not Assessed",
        "total_in_stratum": 4,
        "selected_from_stratum": 1,
        "sampling_rate": "25%"
      }
    ],
    "learners": [
      {
        "LearnerID": 123,
        "Name": "John",
        "Surname": "Doe",
        "classID": "1",
        "className": "Class A",
        "siteID": "Site 1",
        "poe_count": 3,
        "marking_status": "Marked",
        "performance_level": "High",
        "poe_completeness": "Complete",
        "stratum_class": "1",
        "stratum_site": "Site 1",
        "stratum_completeness": "Complete",
        "stratum_marking": "Marked",
        "stratum_performance": "High"
      }
    ]
  }
}
```

## Benefits of This Approach

### 1. **Fair Representation**
- Every class gets proportional representation
- Sites with multiple classes are properly represented
- Both marked and unmarked learners are included

### 2. **Quality Assurance**
- Moderators review mix of performance levels
- Can identify patterns in high/low performers
- Ensures assessment standards are consistent

### 3. **Comprehensive Coverage**
- Complete POE submissions get reviewed
- Partial submissions also sampled (may need follow-up)
- Mix of assessed and unassessed work

### 4. **Statistical Validity**
- Stratified sampling is more representative than simple random
- 25% rate ensures adequate sample size
- Minimum 1 per stratum prevents empty strata

### 5. **Transparency**
- UI shows exactly how sample was generated
- Strata summary displays all dimensions
- Moderators understand their assignment composition

## Flutter UI Display
The UI (`lib/ModeratorPage.dart`) displays:
- Total learners available
- Selected count (25%)
- Sampling method: "Stratified Comprehensive"
- All 5 stratification dimensions
- Detailed strata summary showing:
  - Class name and ID
  - Site
  - POE completeness status
  - Marking status
  - Performance level
  - Count in stratum
  - Count selected
  - Sampling rate
- Individual learner cards with all metadata

## Testing Instructions
1. Upload `get_learners_with_poe_assigned.php` to server
2. Test endpoint:
   ```
   https://rlms.rlms.co.za/mobile/get_learners_with_poe_assigned.php?moderator_id=TEST001
   ```
3. Expected result: 
   - No errors
   - Returns learners with all 5 dimensions populated
   - Strata summary shows breakdown by all dimensions
   - No "Unknown" values for POE status, marking, or performance
4. In app: 
   - Login as moderator
   - Click "Moderation Sampling"
   - Should display comprehensive stratification details
   - Each learner card shows their stratum classification

## Database Tables Used
- `learnerdetails` - Learner information and class assignment
- `class` - Class names and site associations
- `poe` - POE document uploads (count and completeness)
- `marks` - Assessment marks (marking status and performance)
- `moderator_assignments` - Persistent assignment storage

## Why This Matters
- **One site can have multiple classes**: Site alone isn't enough for stratification
- **Unmarked learners need review**: Moderators should see work before and after marking
- **Performance levels matter**: Need to verify standards across all performance ranges
- **POE completeness varies**: Some learners submit everything, others are partial
- **Fair sampling**: Every combination of characteristics gets represented

## Status
✅ **COMPLETE** - Ready for testing
- 5-dimensional stratification implemented
- All dimensions calculated from actual database data
- No "Unknown" values (except for truly unassessed learners)
- Comprehensive strata summary in API response
- UI ready to display all dimensions
- 25% sampling rate from each stratum
- Persistent assignments per moderator
