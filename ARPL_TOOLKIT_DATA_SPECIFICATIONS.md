# ARPL TOOLKIT DATA SPECIFICATIONS

**Purpose:** Defines exact data structure for each trade's ARPL toolkit, ensuring all trades show consistent, accurate, trade-specific data.

---

## BRICKLAYER TOOLKIT (OFO: 641201)

### Appendix A: Application Form
- 22 fields for learner background and employment history
- Learner fills in specialization, employment history, references

### Appendix B: Knowledge Assessment (Formative)
- Activity ID: N/A (placeholder)
- Activities: 13 bricklaying-specific tasks
- Rating Scale: 1-5 (Not Competent → Fully Competent)
- Fields: activity_name, rating_score, comments, rating_date

### Appendix C: Curriculum Content Summary
- Covers: Bricklaying curriculum overview, modules, learning outcomes

### Appendix D: Criteria for Evaluation
- **22 Criteria Cards:**
  1. Ability to interpret drawings and specifications
  2. Ability to prepare work area
  3. Ability to position work safely
  4. Knowledge of solid brickwork English bond
  5. Ability to lay solid brickwork English bond
  6. Knowledge of solid brickwork Flemish bond
  7. Ability to lay solid brickwork Flemish bond
  8. Knowledge of cavity walls
  9. Ability to build cavity walls
  10. Knowledge of facing bricks
  11. Ability to lay facing bricks
  12. Knowledge of curved brickwork
  13. Ability to build curved brickwork
  14. Knowledge of openings and lintels
  15. Ability to build openings and lintels
  16. Knowledge of chimney construction
  17. Ability to build chimneys
  18. Knowledge of repair and repointing
  19. Ability to repair and repoint brickwork
  20. Knowledge of pointing techniques
  21. Ability to complete pointing and joint finish
  22. Safety and environmental compliance knowledge

- **Each Criterion Has:**
  - Yes/No response field
  - Comments field (optional)
  - Evidence field (optional)
  - Date field (auto-populated)

### Appendix E: Workplace Experience (13 Activities)
Activities: Same as Appendix F practical tasks (see below)

**For Each Activity:**
- Rating: 1-5 scale (dropdown)
- Comments: Text field
- Date: Auto-populated
- Witness Name: Text field
- Signature: Optional

### Appendix F: Practical Assessment (Trade-Specific)

#### Section 1: Trade Banner
```
OFO: 641201
Trade: Bricklayer
```

#### Section 2: Practical Tasks (13 Items)
Each item has: Task Name, Score (0-100), Percentage (0-100%)

1. Interpret drawings and specifications
2. Prepare work area and position
3. Lay solid brickwork in English bond
4. Lay solid brickwork in Flemish bond
5. Build cavity walls
6. Lay facing bricks
7. Build curved brickwork
8. Build openings and form lintels
9. Build chimneys
10. Repair/repoint brickwork
11. Complete pointing and joint finish
12. Mix mortar and maintain consistency
13. Safety and environmental compliance

#### Section 3: Workplace Observations (13 Items)
Same items as practical tasks

**For Each Observation:**
- Technical Knowledge: Text field (e.g., "Good understanding of joint types")
- Interpretation: Text field (e.g., "Correctly interprets specifications")
- Team Work: Text field (e.g., "Works effectively with team")

#### Signature Section
- Assessor Name: Text field
- Assessor Signature: Signature upload (optional)
- Candidate Name: Text field
- Candidate Signature: Signature upload (optional)
- Witness Name: Text field
- Witness Signature: Signature upload (optional)
- Assessment Date: Date picker
- Authorized Date: Date picker

---

## ELECTRICIAN TOOLKIT (OFO: 671101)

### Key Differences from Bricklayer:

| Appendix | Bricklayer | Electrician |
|----------|-----------|------------|
| B (Knowledge) | 13 bricklaying activities | 14 electrical activities |
| D (Criteria) | 22 bricklaying criteria | 22 electrical criteria |
| E (Workplace) | 13 bricklaying activities | 14 electrical activities |
| F (Practical) | 13 practical tasks + 13 observations | 14 practical tasks + 14 observations |

**OFO: 671101** (Fixed value for electrician trade)

### Appendix F Sections:
- Trade Banner: "Electrician (671101)"
- Practical Tasks: 14 electrical-specific tasks
- Workplace Observations: 14 electrical observations
- All fields same structure as Bricklayer

---

## PLUMBER TOOLKIT (OFO: TBD)

**Status:** Placeholder page created
**Data:** Currently shows minimal implementation

### Expected Structure:
Same as Bricklayer/Electrician but with:
- OFO: Plumber-specific code
- Activities: 13-14 plumbing-specific tasks
- Criteria: 22 plumbing-relevant criteria

---

## DATA FLOW ARCHITECTURE

### 1. Data Retrieval
```
User Logs In (OFO stored in session)
       ↓
Select Trade/Learner
       ↓
Fetch ARPL Toolkit Data (via API)
       ↓
PHP API (get_arpl_toolkit_data.php)
       ↓
Query Database:
  - arplappxe_{trade}_activities (Appendix B, E, F practical tasks)
  - arplappxe_{trade}_criteria (Appendix D)
  - arplappxe_{trade}_ratings (if existing data)
  - arplappxe_{trade}_observations (Appendix F workplace observations)
       ↓
Build JSON Response (camelCase keys)
       ↓
Dart Model Parses JSON (AppendixFData.fromJson etc.)
       ↓
UI Renders (one appendix at a time via tabs)
```

### 2. Key JSON Response Format (PHP → Dart)

```json
{
  "ofo_number": "641201",
  "learnerID": 12345,
  "appendixA": { ... },
  "appendixB": [ ... ],
  "appendixC": { ... },
  "appendixD": {
    "criterion_1": "No",
    "criterion_2": "Yes",
    ...
    "criterion_22": "No"
  },
  "appendixE": [ ... ],
  "appendixF": {
    "practicalTasks": [
      {
        "task_number": 1,
        "task_name": "Interpret drawings and specifications",
        "score": 0,
        "percentage": 0
      },
      ...
    ],
    "workplaceObservations": [
      {
        "observation_number": 1,
        "task_observed": "Interpret drawings and specifications",
        "technical_knowledge": "",
        "interpretation": "",
        "team_work": ""
      },
      ...
    ],
    "assessorName": "",
    "candidateName": "",
    "witnessName": "",
    "assessorSignature": null,
    "candidateSignature": null,
    "witnessSignature": null,
    "assessmentDate": null,
    "authorizedDate": null
  }
}
```

### 3. Critical Keys (MUST BE CAMELCASE)

These exact keys must be used in PHP JSON response:

```
practicalTasks (NOT practical_tasks)
workplaceObservations (NOT workplace_observations)
assessorName (NOT assessor_name)
candidateName (NOT candidate_name)
witnessName (NOT witness_name)
assessorSignature (NOT assessor_signature)
candidateSignature (NOT candidate_signature)
witnessSignature (NOT witness_signature)
assessmentDate (NOT assessment_date)
authorizedDate (NOT authorized_date)
```

---

## DATABASE TABLES (Required for Each Trade)

### Table: arplappxe_{ofo}_activities
```sql
CREATE TABLE arplappxe_641201_activities (
  id INT PRIMARY KEY,
  ofo_code VARCHAR(10) DEFAULT '641201',
  activity_number INT,
  activity_name VARCHAR(255),
  description TEXT,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
-- Expected: 13 records for bricklayer
```

### Table: arplappxe_{ofo}_criteria
```sql
CREATE TABLE arplappxe_641201_criteria (
  id INT PRIMARY KEY,
  ofo_code VARCHAR(10) DEFAULT '641201',
  criterion_number INT,
  criterion_text VARCHAR(255),
  created_at TIMESTAMP
);
-- Expected: 22 records for all trades
```

### Table: arplappxe_{ofo}_ratings
```sql
CREATE TABLE arplappxe_641201_ratings (
  id INT,
  learner_id INT,
  activity_id INT,
  rating_score INT (1-5),
  comments TEXT,
  rating_date DATE,
  created_at TIMESTAMP
);
```

### Table: arplappxe_{ofo}_practical_assessments
```sql
CREATE TABLE arplappxe_641201_practical_assessments (
  id INT PRIMARY KEY,
  learner_id INT,
  task_number INT,
  score INT,
  percentage INT,
  technical_knowledge TEXT,
  interpretation TEXT,
  team_work TEXT,
  assessor_name VARCHAR(255),
  witness_name VARCHAR(255),
  assessment_date DATE,
  created_at TIMESTAMP
);
```

---

## REQUIRED DATA FOR TESTING

### Bricklayer (OFO: 641201)
- [ ] At least 13 records in arplappxe_641201_activities
- [ ] 22 records in arplappxe_641201_criteria
- [ ] At least 1 learner assigned to bricklayer class
- [ ] Test learner in class with OFO 641201

### Electrician (OFO: 671101)
- [ ] At least 14 records in arplappxe_671101_activities
- [ ] 22 records in arplappxe_671101_criteria
- [ ] At least 1 learner assigned to electrician class

### Verify:
```sql
-- Check bricklayer activities
SELECT COUNT(*) FROM arplappxe_641201_activities;
-- Result: Should be >= 13

-- Check criteria
SELECT COUNT(*) FROM arplappxe_641201_criteria;
-- Result: Should be 22

-- Check class has correct OFO
SELECT class_id, ofo_code FROM classes WHERE class_name LIKE '%Bricklayer%';
-- Result: OFO should be 641201
```

---

## MIGRATION PATH FOR NEW TRADES

To add a new trade (e.g., Plumber):

1. **Create Database Tables:**
   - Copy arplappxe_641201_* tables
   - Rename to arplappxe_{new_ofo}_*
   - Update ofo_code column to new OFO

2. **Create Flutter Page:**
   - Copy ArplToolkitBricklayerPage.dart
   - Rename to ArplToolkitPlumberPage.dart
   - Update OFO default: `this.ofoNumber = '{new_ofo}'`
   - Update trade name in banner

3. **Update Activity Lists:**
   - Update bricklayerPracticalTasks array with plumber tasks
   - Update trade-specific data

4. **Register Route:**
   - Add to main.dart navigation
   - Add to trade selection logic

---

## VALIDATION CHECKLIST

Before declaring toolkit complete for a trade:

- [ ] Database has all activity records
- [ ] Database has all 22 criteria
- [ ] PHP API returns camelCase JSON keys
- [ ] Dart model parses without errors
- [ ] Appendix B shows all activities
- [ ] Appendix D shows all 22 criteria cards
- [ ] Appendix E shows all activities with rating dropdowns
- [ ] Appendix F shows trade banner
- [ ] Appendix F shows all practical tasks (13+)
- [ ] Appendix F shows all observations (13+)
- [ ] Edit mode works (fields become editable)
- [ ] Save mode works (data persists)
- [ ] Switching trades shows different OFO

---

**Last Updated:** July 10, 2026  
**Status:** Active - Bricklayer & Electrician complete, Plumber in progress
