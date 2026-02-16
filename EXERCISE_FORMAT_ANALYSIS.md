# Exercise Format Analysis

## Actual Format Discovered

The test results show the exercise column has this format:

### POE Table
```
"All Questions - 9964 - Apply health and safety to a work area"
"All Formative Questions - 9964 - Apply health and safety to a work area"
"All Summative Questions - 9964 - Apply health and safety to a work area"
"Define a safe site"
"What are safety hazards?"
```

### Marks Table
```
"Define a safe site"
"What are safety hazards?"
"Common sources of incidents on a roadworks site."
```

## Problem

The current extraction logic:
```sql
SUBSTRING_INDEX(SUBSTRING_INDEX(m.exercise, '\t', 1), ' ', 1)
```

This extracts the FIRST word before tab or space:
- "All Questions - 9964..." → "All" ❌
- "Define a safe site" → "Define" ❌

The unit standard ID "9964" is in the MIDDLE of the string, not at the beginning!

## Solution

We need to EXTRACT the 4-5 digit number from ANYWHERE in the string, not just the beginning.

### Option 1: Use REGEXP_SUBSTR (MySQL 8.0+)
```sql
REGEXP_SUBSTR(m.exercise, '[0-9]{4,5}')
```

### Option 2: Use REGEXP_REPLACE (MySQL 8.0+)
```sql
REGEXP_REPLACE(m.exercise, '.*?([0-9]{4,5}).*', '$1')
```

### Option 3: Manual extraction (Compatible with older MySQL/MariaDB)
Since the format is "All Questions - 9964 - Description", we can:
1. Find the position of the first 4-5 digit number
2. Extract it

But this is complex in SQL.

## Recommended Solution

Use REGEXP_SUBSTR if available, otherwise we need to change the WHERE clause to just check if the exercise contains a 4-5 digit number, then extract it in the application layer.

### Updated Query (MySQL 8.0+)
```sql
SELECT 
    m.learnerID,
    CAST(REGEXP_SUBSTR(m.exercise, '[0-9]{4,5}') AS UNSIGNED) as unit_standard_id,
    SUM(m.marks_scored) as unit_standard_total
FROM marks m
WHERE m.exercise REGEXP '[0-9]{4,5}'
AND m.type = 'Summative'
GROUP BY m.learnerID, unit_standard_id
```

### Updated Query (MariaDB/MySQL 5.7)
For older versions, we need a different approach. We can use a combination of LOCATE and SUBSTRING:

```sql
SELECT 
    m.learnerID,
    CAST(
        SUBSTRING(
            m.exercise,
            LOCATE(
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(m.exercise, ' - ', 2),
                    ' - ',
                    -1
                ),
                m.exercise
            ),
            5
        ) AS UNSIGNED
    ) as unit_standard_id
FROM marks m
WHERE m.exercise REGEXP '[0-9]{4,5}'
```

## Testing Required

We need to check the MySQL/MariaDB version on the server to determine which approach to use.

```sql
SELECT VERSION();
```

If version >= 8.0: Use REGEXP_SUBSTR
If version < 8.0: Use alternative extraction method
