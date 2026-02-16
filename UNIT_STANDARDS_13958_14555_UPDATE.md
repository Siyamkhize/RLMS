# Unit Standards Update for Pothole Checklist

## Change Request
Update the unit standards displayed in the pothole checklist marking section to show only:
- **13958** with its specific outcomes
- **14555** with its specific outcomes

## Files Modified

### 1. get_logbook_unit_standards.php

**Changes:**
- Updated filter to only return unit standards 13958 and 14555
- Updated comments to reflect the correct unit standards

**Before:**
```php
// For pothole checklist, we want specific unit standards: 14336 and 9968
...
if ($check_row['count'] > 0) {
```

**After:**
```php
// For pothole checklist, we want specific unit standards: 13958 and 14555
...
if ($check_row['count'] > 0 && ($unitStandardId == '13958' || $unitStandardId == '14555')) {
```

## How It Works

The endpoint now:
1. Gets the learner's project pathway
2. Extracts all unit standards from the pathway
3. **Filters to only include 13958 and 14555**
4. Checks if they have Summative Practical assessments (LogBook type)
5. Fetches specific outcomes for each unit standard
6. Returns the filtered list

## Testing

### Test the endpoint directly:
```
https://rlms.rlms.co.za/mobile/get_logbook_unit_standards.php?learner_id=75
```

### Use the test page:
```
https://rlms.rlms.co.za/mobile/test_unit_standards_13958_14555.php?learner_id=75
```

### Expected Response:
```json
{
  "status": "success",
  "data": [
    {
      "unit_standard_id": "13958",
      "unit_standard_name": "Unit Standard Name",
      "unit_standard_number": "13958",
      "specific_outcomes": [
        {
          "outcome_id": "xxxxx",
          "outcome_text": "Outcome description..."
        }
      ]
    },
    {
      "unit_standard_id": "14555",
      "unit_standard_name": "Unit Standard Name",
      "unit_standard_number": "14555",
      "specific_outcomes": [
        {
          "outcome_id": "xxxxx",
          "outcome_text": "Outcome description..."
        }
      ]
    }
  ]
}
```

## Prerequisites

For the unit standards to appear, they must:
1. ✅ Exist in the learner's Project_pathway JSON
2. ✅ Have entries in the `assessments` table with:
   - `unit_standard_id` = '13958' or '14555'
   - `assessment_type` = 'Summative'
   - `question_type` = 'Practical'
3. ✅ Have specific outcomes defined in the `outcomes` table

## Deployment

1. **Upload the updated file:**
   - Upload `get_logbook_unit_standards.php` to `rlms.rlms.co.za/mobile/`

2. **Test the endpoint:**
   - Access the test page to verify unit standards are returned

3. **No app rebuild needed:**
   - The Flutter app already calls this endpoint
   - Changes take effect immediately

## Troubleshooting

If unit standards don't appear:

1. **Check if they exist in the project pathway:**
   ```sql
   SELECT pr.Project_pathway 
   FROM learnerdetails ld 
   INNER JOIN class c ON ld.classID = c.classID 
   INNER JOIN sites s ON c.siteID = s.siteID 
   INNER JOIN project pr ON s.project_id = pr.project_id
   WHERE ld.LearnerID = 75;
   ```

2. **Check if assessments exist:**
   ```sql
   SELECT * FROM assessments 
   WHERE unit_standard_id IN ('13958', '14555')
   AND assessment_type = 'Summative'
   AND question_type = 'Practical';
   ```

3. **Check if outcomes exist:**
   ```sql
   SELECT * FROM outcomes 
   WHERE outcome_id IN (
     SELECT JSON_UNQUOTE(JSON_EXTRACT(specific_outcome, '$[0]'))
     FROM assessments 
     WHERE unit_standard_id IN ('13958', '14555')
   );
   ```

## Notes

- The filter is applied at the PHP level, so only 13958 and 14555 will be returned
- Other unit standards in the project pathway will be ignored
- Each unit standard will show its specific outcomes with marks out of 50
- The Flutter app displays these automatically in the marking section
