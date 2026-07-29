# Gap Analysis Database Schema & Queries

**Date**: July 12, 2026

---

## Database Schema Diagram

```
┌─────────────────────────────────┐
│    learnerdetails (existing)    │
├─────────────────────────────────┤
│ LearnerID (PK)                  │
│ FirstName                       │
│ LastName                        │
│ IDNumber                        │
│ ClassID (FK to classes)         │
└──────────────┬──────────────────┘
               │
               ├─→ classes → trades (TradeID)
               │
               └─→ gap_analysis_submissions
                  │
                  ├── learner_id (FK)
                  ├── trade_id (FK)
                  └── assessor_name
                      assessor_no
                      comments
                      assess_date
                      status
                      │
                      └─→ gap_analysis_submission_items
                         ├── submission_id (FK) ⟵ ON DELETE CASCADE
                         ├── task_id (FK)
                         └── rating (Bad|Fair|Good)
                             comments
                             │
                             └─→ gap_analysis_report
                                ├── TaskID (PK)
                                ├── TaskNo
                                ├── TaskName
                                ├── AssessmentMethod
                                └── TradeID (filters by trade)
```

---

## Table Relationships

### Primary Key & Foreign Key Structure

```
gap_analysis_report
├─ PK: id
├─ UK: TaskID
├─ FK: TradeID → trades.TradeID
└─ Usage: Master task definitions per trade

gap_analysis_submissions
├─ PK: id
├─ FK: learner_id → learnerdetails.LearnerID
├─ FK: trade_id → trades.TradeID
├─ UK: (learner_id, trade_id, assess_date)
└─ Usage: One submission per learner-trade-date

gap_analysis_submission_items
├─ PK: id
├─ FK: submission_id → gap_analysis_submissions.id [CASCADE DELETE]
├─ FK: task_id (references gap_analysis_report.TaskID)
├─ UK: (submission_id, task_id)
└─ Usage: Multiple items per submission (one per task)
```

---

## SQL Query Examples

### 1. Get Latest Gap Analysis for a Learner

```sql
SELECT 
    gas.id,
    gas.learner_id,
    ld.FirstName,
    ld.LastName,
    ld.IDNumber,
    gas.assessor_name,
    gas.assessor_no,
    gas.assess_date,
    gas.comments,
    gas.status
FROM gap_analysis_submissions gas
JOIN learnerdetails ld ON gas.learner_id = ld.LearnerID
WHERE gas.learner_id = 123
ORDER BY gas.created_at DESC
LIMIT 1;
```

### 2. Get Task Ratings for a Submission

```sql
SELECT 
    gasi.id,
    gar.TaskNo,
    gar.TaskName,
    gar.AssessmentMethod,
    gasi.rating,
    gasi.comments
FROM gap_analysis_submission_items gasi
JOIN gap_analysis_report gar ON gasi.task_id = gar.TaskID
WHERE gasi.submission_id = 1
ORDER BY gar.TaskNo ASC;
```

### 3. Get All Tasks for a Trade

```sql
SELECT 
    TaskID,
    TaskNo,
    TaskName,
    AssessmentMethod,
    Description
FROM gap_analysis_report
WHERE TradeID = 1
ORDER BY TaskNo ASC;
```

**Result for TradeID=1 (Electrician)**:
```
TaskID | TaskNo | TaskName                              | AssessmentMethod
-------|--------|---------------------------------------|------------------
1      | 1      | Safety Awareness and Compliance       | Interview
2      | 2      | Electrical Circuit Analysis           | Practical
3      | 3      | Cable Installation and Termination    | Practical
4      | 4      | Switchgear and Protection Devices     | Practical
5      | 5      | Wiring Systems and Distribution       | Interview
6      | 6      | Testing and Commissioning             | Practical
7      | 7      | Compliance with SANS Codes            | Written
8      | 8      | Problem-Solving and Diagnostics       | Practical
```

### 4. Get Rating Distribution for a Submission

```sql
SELECT 
    gasi.rating,
    COUNT(*) as count
FROM gap_analysis_submission_items gasi
WHERE gasi.submission_id = 1
GROUP BY gasi.rating;
```

**Sample Result**:
```
rating | count
-------|-------
Good   | 4
Fair   | 3
Bad    | 1
```

### 5. Get Summary of All Submissions by Learner

```sql
SELECT 
    gas.id as submission_id,
    ld.LearnerID,
    ld.FirstName,
    ld.LastName,
    t.TradeName,
    gas.assessor_name,
    gas.assess_date,
    gas.status,
    COUNT(gasi.id) as total_tasks,
    SUM(CASE WHEN gasi.rating = 'Good' THEN 1 ELSE 0 END) as good_count,
    SUM(CASE WHEN gasi.rating = 'Fair' THEN 1 ELSE 0 END) as fair_count,
    SUM(CASE WHEN gasi.rating = 'Bad' THEN 1 ELSE 0 END) as bad_count
FROM gap_analysis_submissions gas
JOIN learnerdetails ld ON gas.learner_id = ld.LearnerID
JOIN trades t ON gas.trade_id = t.TradeID
LEFT JOIN gap_analysis_submission_items gasi ON gas.id = gasi.submission_id
GROUP BY gas.id
ORDER BY gas.assess_date DESC;
```

### 6. Get Learners with No Gap Analysis (for missing data report)

```sql
SELECT 
    ld.LearnerID,
    ld.FirstName,
    ld.LastName,
    c.ClassName,
    t.TradeName
FROM learnerdetails ld
JOIN classes c ON ld.ClassID = c.ClassID
JOIN trades t ON c.TradeID = t.TradeID
WHERE ld.LearnerID NOT IN (
    SELECT DISTINCT learner_id 
    FROM gap_analysis_submissions
)
ORDER BY ld.Surname, ld.FirstName;
```

---

## Data Insertion Queries

### Insert a New Gap Analysis Submission

```sql
-- Step 1: Insert submission record
INSERT INTO gap_analysis_submissions 
(learner_id, trade_id, assessor_name, assessor_no, comments, assess_date, status)
VALUES 
(123, 1, 'John Assessment', 'ASSESS001', 'Good progress overall', '2026-07-12', 'Completed');

-- Get the inserted submission ID (use mysqli_insert_id() in PHP)
-- For manual SQL: last_insert_id() returns the ID

-- Step 2: Insert task ratings
INSERT INTO gap_analysis_submission_items 
(submission_id, task_id, rating, comments) 
VALUES 
(1, 1, 'Good', 'Excellent safety awareness'),
(1, 2, 'Fair', 'Needs practical reinforcement'),
(1, 3, 'Good', 'Competent cable installation'),
(1, 4, 'Fair', 'Theory adequate, practical needs work'),
(1, 5, 'Good', 'Strong wiring knowledge'),
(1, 6, 'Good', 'Testing procedures understood'),
(1, 7, 'Fair', 'Some gaps in SANS standards'),
(1, 8, 'Good', 'Problem-solving demonstrated');
```

### Update an Existing Submission

```sql
UPDATE gap_analysis_submissions
SET 
    assessor_name = 'Jane Assessor',
    comments = 'Updated assessment',
    status = 'Reviewed'
WHERE id = 1;
```

### Update Task Ratings

```sql
UPDATE gap_analysis_submission_items
SET 
    rating = 'Good',
    comments = 'Revised - shows competency'
WHERE submission_id = 1 AND task_id = 2;
```

---

## Data Retrieval for PDF Generation

### Query Used in arpl_pdf.php

**Get Latest Submission Data**:
```php
$st = $conn->prepare("
    SELECT gas.* 
    FROM gap_analysis_submissions gas
    WHERE gas.learner_id = ? 
    ORDER BY gas.created_at DESC 
    LIMIT 1
");
```

**Get Task Ratings for Submission**:
```php
$st2 = $conn->prepare("
    SELECT gasi.*, gar.TaskNo, gar.TaskName, gar.AssessmentMethod
    FROM gap_analysis_submission_items gasi
    LEFT JOIN gap_analysis_report gar ON gasi.task_id = gar.TaskID
    WHERE gasi.submission_id = ?
    ORDER BY gar.TaskNo ASC
");
```

---

## Sample Data Records

### gap_analysis_report Sample (TradeID=1, Electrician)

| id | TaskID | TaskNo | TaskName | AssessmentMethod | TradeID | created_at |
|----|--------|--------|----------|------------------|---------|-----------|
| 1 | 1 | 1 | Safety Awareness and Compliance | Interview | 1 | 2026-07-12 |
| 2 | 2 | 2 | Electrical Circuit Analysis | Practical | 1 | 2026-07-12 |
| 3 | 3 | 3 | Cable Installation and Termination | Practical | 1 | 2026-07-12 |
| 4 | 4 | 4 | Switchgear and Protection Devices | Practical | 1 | 2026-07-12 |
| 5 | 5 | 5 | Wiring Systems and Distribution | Interview | 1 | 2026-07-12 |
| 6 | 6 | 6 | Testing and Commissioning | Practical | 1 | 2026-07-12 |
| 7 | 7 | 7 | Compliance with SANS Codes | Written | 1 | 2026-07-12 |
| 8 | 8 | 8 | Problem-Solving and Diagnostics | Practical | 1 | 2026-07-12 |

### gap_analysis_submissions Sample

| id | learner_id | trade_id | assessor_name | assessor_no | assess_date | status | created_at |
|----|-----------|----------|---------------|------------|------------|--------|-----------|
| 1 | 123 | 1 | John Assessment | ASSESS001 | 2026-07-12 | Completed | 2026-07-12 |

### gap_analysis_submission_items Sample

| id | submission_id | task_id | rating | comments | created_at |
|----|--------------|---------|--------|----------|-----------|
| 1 | 1 | 1 | Good | Excellent safety awareness | 2026-07-12 |
| 2 | 1 | 2 | Fair | Needs practical reinforcement | 2026-07-12 |
| 3 | 1 | 3 | Good | Competent cable installation | 2026-07-12 |
| ... | ... | ... | ... | ... | ... |

---

## Index Performance

### Index Usage

| Index Name | Table | Columns | Purpose |
|------------|-------|---------|---------|
| PRIMARY KEY | All | id | Row identification |
| idx_learner_id | gap_analysis_submissions | learner_id | Quick learner lookup |
| idx_trade_id | gap_analysis_submissions | trade_id | Filter by trade |
| idx_created_at | gap_analysis_submissions | created_at | Order by date |
| idx_submission_id | gap_analysis_submission_items | submission_id | Get items for submission |
| idx_task_id | gap_analysis_submission_items | task_id | Cross-reference tasks |
| idx_trade_id | gap_analysis_report | TradeID | Filter by trade |

### Query Optimization

**Fast Queries** (use indexes):
- Get learner's latest submission: ~0.001s (idx_learner_id + idx_created_at)
- Get tasks for trade: ~0.001s (idx_trade_id)
- Get ratings for submission: ~0.001s (idx_submission_id)

**Avoid Full Table Scans**:
- Always filter by learner_id or trade_id
- Use date ranges when querying by date
- Use LIMIT to avoid large result sets

---

## Storage Estimates

### Space Usage

Based on sample data (24 tasks, 0 submissions):

| Table | Rows | Avg Size | Total Size |
|-------|------|----------|-----------|
| gap_analysis_report | 24 | ~200 bytes | ~5 KB |
| gap_analysis_submissions | 0 | ~500 bytes | 0 KB |
| gap_analysis_submission_items | 0 | ~100 bytes | 0 KB |
| **TOTAL** | **24** | | **~5 KB** |

### Growth Projections

Assuming 100 learners, 2 submissions each:
- `gap_analysis_submissions`: 200 records × 500 bytes = 100 KB
- `gap_analysis_submission_items`: 1,600 records (200 × 8 tasks) × 100 bytes = 160 KB
- **Total**: ~265 KB (minimal storage impact)

---

## Maintenance Queries

### Verify Data Integrity

```sql
-- Check for orphaned submission items (shouldn't exist if FK works)
SELECT gasi.* 
FROM gap_analysis_submission_items gasi
LEFT JOIN gap_analysis_submissions gas ON gasi.submission_id = gas.id
WHERE gas.id IS NULL;

-- Check for task references that don't exist
SELECT gasi.* 
FROM gap_analysis_submission_items gasi
LEFT JOIN gap_analysis_report gar ON gasi.task_id = gar.TaskID
WHERE gar.TaskID IS NULL;
```

### Cleanup Queries

```sql
-- Delete old submissions (keep last 2 years)
DELETE FROM gap_analysis_submissions
WHERE created_at < DATE_SUB(NOW(), INTERVAL 2 YEAR);

-- Archive submissions to history table (optional)
-- First create gap_analysis_submissions_archive with same structure
INSERT INTO gap_analysis_submissions_archive
SELECT * FROM gap_analysis_submissions
WHERE created_at < DATE_SUB(NOW(), INTERVAL 2 YEAR);
```

---

## Backup & Restore

### Backup Single Tables

```bash
# Backup only gap analysis tables
mysqldump -u user -p database gap_analysis_report \
    gap_analysis_submissions gap_analysis_submission_items \
    > gap_analysis_backup_$(date +%Y%m%d).sql
```

### Restore from Backup

```bash
mysql -u user -p database < gap_analysis_backup_20260712.sql
```

---

## Related Tables & References

### External References

- **learnerdetails**: Source for learner information
  - Link via: learner_id → LearnerID
  
- **classes**: Class information
  - Link via: learnerdetails.ClassID → classes.ClassID

- **trades**: Trade definitions
  - Link via: gap_analysis_submissions.trade_id → trades.TradeID

---

**Schema Version**: 1.0  
**Last Updated**: July 12, 2026  
**Status**: ✅ READY FOR USE
