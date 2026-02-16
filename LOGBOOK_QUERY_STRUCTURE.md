.# LogBook Query Structure

## Current Implementation

### Endpoint
```
GET https://tesing.mtltechnical.co.za/mobile/get_poe.php?learnerId={learner_id}
```

### Expected Response Structure

```json
{
  "pathways": {
    "Pathway Name": {
      "qualifications": {
        "Qualification Name": {
          "unitstandards": {
            "Unit Standard Name": {
              "formative": [...],
              "summative": [...],
              "logbook": [
                {
                  "exercise_name": "Exercise 1",
                  "assessment_type": "Summative",
                  "question_type": "Practical",
                  "marks": "100",
                  "marks_scored": "85",
                  "a_comment": "Good work",
                  "type": "logbook",
                  ...
                },
                {
                  "exercise_name": "Exercise 2",
                  "assessment_type": "Formative",
                  "question_type": "Knowledge",
                  "marks": "50",
                  ...
                }
              ]
            }
          }
        }
      }
    }
  }
}
```

## LogBook Filtering Logic

### Current Filter (in Flutter)
```dart
List<dynamic> filteredLogbook = logbook.where((item) {
  String assessmentType = (item['assessment_type'] ?? '').toString().toLowerCase();
  String questionType = (item['question_type'] ?? '').toString().toLowerCase();
  
  return assessmentType == 'summative' && questionType == 'practical';
}).toList();
```

### What Gets Shown
Only logbook items where:
- `assessment_type` = "Summative" (case-insensitive)
- AND
- `question_type` = "Practical" (case-insensitive)

## Recommended PHP Query Structure

If you want to filter on the server side instead of client side, here's the recommended SQL query:

### Option 1: Filter in PHP (Recommended)

**File:** `get_poe.php`

```php
<?php
// ... existing code ...

// When building the logbook array for each unit standard
$logbookQuery = "
    SELECT 
        p.exercise_name,
        a.assessment_type,
        a.question_type,
        p.marks,
        p.marks_scored,
        p.a_comment,
        p.type
    FROM poe p
    INNER JOIN assessments a ON p.assessment_id = a.assessment_id
    WHERE p.learner_id = ?
    AND p.unit_standard_id = ?
    AND p.type = 'logbook'
    AND a.assessment_type = 'Summative'
    AND a.question_type = 'Practical'
    ORDER BY p.exercise_name
";

// This will only return Summative + Practical logbook items
```

### Option 2: Return All, Filter in Flutter (Current)

**File:** `get_poe.php`

```php
<?php
// Return ALL logbook items
$logbookQuery = "
    SELECT 
        p.exercise_name,
        a.assessment_type,
        a.question_type,
        p.marks,
        p.marks_scored,
        p.a_comment,
        p.type
    FROM poe p
    INNER JOIN assessments a ON p.assessment_id = a.assessment_id
    WHERE p.learner_id = ?
    AND p.unit_standard_id = ?
    AND p.type = 'logbook'
    ORDER BY p.exercise_name
";

// Flutter will filter based on assessment_type and question_type
```

## Database Schema

### Tables Involved

**1. poe table:**
```sql
CREATE TABLE poe (
    id INT PRIMARY KEY,
    learner_id VARCHAR(50),
    unit_standard_id INT,
    assessment_id INT,
    exercise_name VARCHAR(255),
    marks INT,
    marks_scored INT,
    a_comment TEXT,
    type VARCHAR(50), -- 'formative', 'summative', 'logbook'
    ...
);
```

**2. assessments table:**
```sql
CREATE TABLE assessments (
    assessment_id INT PRIMARY KEY,
    assessment_type VARCHAR(50), -- 'Formative', 'Summative'
    question_type VARCHAR(50),   -- 'Knowledge', 'Practical'
    ...
);
```

### Join Relationship
```
poe.assessment_id = assessments.assessment_id
```

## Testing the Query

### Test SQL Query
```sql
-- Test query to see what logbook items exist
SELECT 
    us.unitstandard_name,
    p.exercise_name,
    a.assessment_type,
    a.question_type,
    p.marks,
    p.marks_scored,
    p.type
FROM poe p
INNER JOIN assessments a ON p.assessment_id = a.assessment_id
INNER JOIN unit_standards us ON p.unit_standard_id = us.unitstandard_id
WHERE p.learner_id = 'YOUR_LEARNER_ID'
AND p.type = 'logbook'
ORDER BY us.unitstandard_name, p.exercise_name;
```

### Expected Results
```
| unitstandard_name | exercise_name | assessment_type | question_type | marks | marks_scored | type    |
|-------------------|---------------|-----------------|---------------|-------|--------------|---------|
| Unit Standard 1   | Exercise 1    | Summative       | Practical     | 100   | 85           | logbook |
| Unit Standard 1   | Exercise 2    | Formative       | Knowledge     | 50    | 40           | logbook |
| Unit Standard 2   | Exercise 3    | Summative       | Practical     | 100   | 90           | logbook |
```

### Filtered Results (What Shows in LogBook Section)
```
| unitstandard_name | exercise_name | assessment_type | question_type | marks | marks_scored |
|-------------------|---------------|-----------------|---------------|-------|--------------|
| Unit Standard 1   | Exercise 1    | Summative       | Practical     | 100   | 85           |
| Unit Standard 2   | Exercise 3    | Summative       | Practical     | 100   | 90           |
```

## Debugging Steps

### 1. Check Raw Data
Add this to your PHP file to see what's being returned:

```php
// In get_poe.php, before returning the response
error_log("POE Data for learner $learnerId: " . json_encode($poeData));
```

### 2. Check Flutter Console
The current implementation prints debug info:

```
DEBUG LogBook: Unit "Unit Standard 1" has 5 logbook items
  - Item: assessment_type="summative", question_type="practical"
  - Item: assessment_type="formative", question_type="knowledge"
  - Filtered: 1 items match criteria
DEBUG LogBook Summary: Total=5, Filtered=1, Units with matches=1
```

### 3. Test Direct API Call
```bash
curl "https://tesing.mtltechnical.co.za/mobile/get_poe.php?learnerId=YOUR_LEARNER_ID" | jq '.pathways'
```

## Recommendations

### For Better Performance
1. **Filter in PHP** - Reduces data transfer
2. **Add indexes** - On `poe.type`, `assessments.assessment_type`, `assessments.question_type`
3. **Cache results** - If data doesn't change frequently

### For Better Debugging
1. **Add logging** - Log all logbook queries
2. **Return metadata** - Include counts in response
3. **Validate data** - Ensure assessment_type and question_type are set

## Common Issues

### Issue 1: No logbook items showing
**Possible causes:**
- No items have `type = 'logbook'` in poe table
- No items have `assessment_type = 'Summative'`
- No items have `question_type = 'Practical'`
- Field names are different (e.g., `assessmentType` vs `assessment_type`)

**Solution:** Run the test SQL query above

### Issue 2: Wrong items showing
**Possible causes:**
- Case sensitivity issues
- Extra whitespace in data
- Different field names

**Solution:** Check the debug logs in Flutter console

### Issue 3: Section not appearing
**Possible causes:**
- No logbook items at all
- All items filtered out
- PHP endpoint not returning logbook array

**Solution:** Check the raw API response

## Contact Points

If you need to modify the query:
1. **PHP File:** `https://tesing.mtltechnical.co.za/mobile/get_poe.php`
2. **Database:** Check with your database administrator
3. **Flutter Code:** `lib/AssessorPage.dart` line ~2286 (`_buildLogBookSection`)
