# Add 29 Supplemental Learners - SQL Solution

## The Problem

The existing 373 assignments don't have `class_id` populated, so the PHP script can't determine which classes to sample from.

## The Solution

Use a simple SQL script that:
1. Finds learners with POE who aren't already assigned
2. Excludes class 74 (testing class)
3. Randomly selects 29 learners
4. Adds them to moderator_assignments

## How to Run

### Step 1: Open phpMyAdmin
1. Go to your hosting control panel
2. Click "phpMyAdmin"
3. Select database: `rlmsrlmsco_ezxcmacd_rlms`

### Step 2: Run the SQL Script
1. Click the "SQL" tab at the top
2. Copy the entire contents of `add_29_supplemental_learners.sql`
3. Paste into the SQL query box
4. Click "Go"

### Step 3: Verify
You should see:
```
Query OK, 29 rows affected
```

Then the verification query will show:
```
total_assignments: 402
```

## What the Script Does

```sql
INSERT INTO moderator_assignments (moderator_id, learner_id, stratum_type, ...)
SELECT 
    '77' as moderator_id,
    l.LearnerID,
    'supplemental' as stratum_type,
    ...
FROM learnerdetails l
INNER JOIN poe p ON l.LearnerID = p.learnerID
LEFT JOIN moderator_assignments ma ON l.LearnerID = ma.learner_id
WHERE p.filePath IS NOT NULL 
AND ma.learner_id IS NULL  -- Not already assigned
AND l.classID != '74'      -- Exclude testing class
ORDER BY RAND()            -- Random selection
LIMIT 29;                  -- Exactly 29 learners
```

## After Running

1. Open your Flutter app
2. Go to ModeratorPage
3. You should now see 402 learners (instead of 373)
4. The 29 new learners will be marked as `stratum_type = 'supplemental'`

## No PHP, No cURL, No Timeouts!

This is a direct database operation - fast and simple!

