# Moderation Sampling - Comprehensive Stratified Implementation

## Overview
The moderation sampling system has been enhanced with **comprehensive stratified random sampling** that ensures representative selection across multiple dimensions.

## Implementation Date
January 29, 2026

## What Was Implemented

### 1. Enhanced Backend (get_learners_with_poe_assigned.php)

#### Multi-Dimensional Stratification
The system now stratifies learners across **5 dimensions**:

1. **Class** - Different classes/cohorts
2. **Site** - Different training sites
3. **POE Completeness** - Upload status
   - Complete: All unit standards uploaded
   - Partial: Some unit standards uploaded
   - Incomplete: No uploads
4. **Marking Status** - Assessment status
   - Marked: Work has been assessed
   - Unmarked: Work not yet assessed
5. **Performance Level** - Academic performance
   - High: Average marks ≥ 70%
   - Medium: Average marks 50-69%
   - Low: Average marks < 50%
   - Not Assessed: No marks available

#### Sampling Algorithm
- **Sampling Rate**: 25% from each stratum
- **Minimum Selection**: At least 1 learner per stratum (if available)
- **Randomization**: Random selection within each stratum
- **Assignment Persistence**: Each moderator gets one permanent assignment

#### Database Enhancements
```sql
-- Enhanced moderator_assignments table
CREATE TABLE IF NOT EXISTS moderator_assignments (
    id INT(11) NOT NULL AUTO_INCREMENT,
    moderator_id VARCHAR(50) NOT NULL,
    learner_id INT(11) NOT NULL,
    class_id VARCHAR(50) NULL,
    stratum_type VARCHAR(50) NULL COMMENT 'Type of stratification used',
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY unique_learner (learner_id),
    KEY idx_moderator (moderator_id),
    KEY idx_class (class_id)
)
```

### 2. Enhanced Flutter UI (lib/ModeratorPage.dart)

#### New Features

**Sampling Summary Card**
- Displays sampling method
- Shows total learners vs selected count
- Lists all stratification dimensions used
- Indicates if assignment is existing or new

**Comprehensive Strata Breakdown Table**
Shows detailed breakdown with columns:
- Class
- Site
- POE Status (color-coded: Green=Complete, Orange=Partial, Red=Incomplete)
- Marking Status (color-coded: Blue=Marked, Grey=Unmarked)
- Performance Level (color-coded: Green=High, Orange=Medium, Red=Low, Grey=Not Assessed)
- Total in Stratum
- Selected from Stratum
- Sampling Rate

**Enhanced Learners List**
Additional columns showing:
- POE Status badge
- Marking Status badge
- Performance Level badge
- Unit Standards Count

#### Color Coding System
```dart
// POE Completeness
Complete → Green
Partial → Orange
Incomplete → Red

// Marking Status
Marked → Blue
Unmarked → Grey

// Performance Level
High (≥70%) → Green
Medium (50-69%) → Orange
Low (<50%) → Red
Not Assessed → Grey
```

## How It Works

### First-Time Assignment
1. Moderator clicks "Moderation Sampling"
2. System queries all learners with POE
3. Calculates stratification dimensions for each learner
4. Groups learners into strata (unique combinations of dimensions)
5. Selects 25% from each stratum
6. Assigns selected learners to moderator
7. Displays comprehensive breakdown

### Subsequent Access
1. Moderator clicks "Moderation Sampling"
2. System retrieves existing assignment
3. Displays same learners with "existing assignment" indicator
4. Shows original stratification breakdown

## API Response Structure

```json
{
  "status": "success",
  "message": "Comprehensive stratified random sampling applied...",
  "data": {
    "total_learners_with_poe": 100,
    "selected_count": 25,
    "sampling_method": "stratified_comprehensive",
    "sampling_rate": "25%",
    "total_strata": 15,
    "is_existing_assignment": false,
    "stratification_dimensions": [
      "Class",
      "Site",
      "POE Completeness (Complete/Partial/Incomplete)",
      "Marking Status (Marked/Unmarked)",
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
      }
    ],
    "learners": [
      {
        "LearnerID": 123,
        "Name": "John",
        "Surname": "Doe",
        "className": "Class A",
        "siteID": "Site 1",
        "poe_completeness": "Complete",
        "marking_status": "Marked",
        "performance_level": "High",
        "unit_standards_count": 2,
        "poe_count": 5,
        "avg_marks": 85.5
      }
    ]
  }
}
```

## Benefits of This Approach

### 1. Representative Sampling
- Ensures all learner types are included
- Prevents bias toward high-performers or complete submissions
- Captures full spectrum of learner experiences

### 2. Quality Assurance
- Moderators see both strong and weak work
- Identifies systemic issues across different dimensions
- Validates assessment standards across all scenarios

### 3. Transparency
- Clear visualization of how sample was generated
- Shows exact composition of each stratum
- Demonstrates fairness and randomness

### 4. Efficiency
- One-time assignment per moderator
- No duplicate work
- Consistent moderation scope

## Testing the Feature

### Test Endpoint Directly
```bash
# Test with moderator ID
curl "http://your-server/get_learners_with_poe_assigned.php?moderator_id=MOD001"
```

### Expected Scenarios

**Scenario 1: First Assignment**
- Response includes `"is_existing_assignment": false`
- Shows comprehensive strata breakdown
- Displays stratification dimensions
- Learners have all metadata fields

**Scenario 2: Existing Assignment**
- Response includes `"is_existing_assignment": true`
- Shows same learners as before
- Green indicator in UI
- Message: "Returning your existing moderation assignment"

**Scenario 3: No Learners Available**
- Response includes `"selected_count": 0`
- Message: "No learners with POE available for assignment"

## Files Modified

### Backend
- `get_learners_with_poe_assigned.php` - Complete rewrite with comprehensive stratification

### Frontend
- `lib/ModeratorPage.dart` - Enhanced ModerationSamplingPage with:
  - Stratification dimensions display
  - Comprehensive strata breakdown table
  - Enhanced learner list with all metadata
  - Color-coded status badges
  - Helper methods for color coding

## Navigation

**Access Path:**
1. Login as Moderator
2. Open drawer menu
3. Click "Moderation Sampling"
4. View comprehensive sampling breakdown
5. Click "Moderate" on any learner to begin moderation

## Key Advantages Over Simple Random Sampling

| Aspect | Simple Random | Comprehensive Stratified |
|--------|--------------|-------------------------|
| Representation | May miss groups | Guarantees all groups |
| Bias | Possible | Minimized |
| Transparency | Limited | Full breakdown shown |
| Quality Assurance | Basic | Comprehensive |
| Fairness | Good | Excellent |

## Future Enhancements (Optional)

1. **Adjustable Sampling Rate** - Allow moderators to change from 25%
2. **Custom Stratification** - Let moderators choose which dimensions to use
3. **Export Functionality** - Download sampling report as PDF
4. **Historical Tracking** - View past sampling assignments
5. **Stratum Weighting** - Give more weight to certain strata

## Troubleshooting

### Issue: No strata summary showing
**Solution**: Check that learners have POE uploaded and marks table has data

### Issue: All learners showing "Not Assessed"
**Solution**: Verify marks table has entries for learners

### Issue: Only one stratum appearing
**Solution**: Check data diversity - may need more varied learner data

### Issue: Sampling rate not exactly 25%
**Solution**: This is expected - minimum 1 per stratum means small strata get >25%

## Summary

The comprehensive stratified sampling implementation ensures:
✅ Fair representation across all learner types
✅ Transparent sampling methodology
✅ Quality assurance across multiple dimensions
✅ Persistent assignments per moderator
✅ Visual breakdown of stratification
✅ Color-coded status indicators
✅ Complete metadata for each learner

The system is production-ready and provides moderators with a scientifically sound, transparent, and comprehensive sampling methodology for quality assurance.
