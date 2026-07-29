# ARPL COMPETENCY & ASSESSMENT FORM TABLES REFERENCE

**Document Date:** July 13, 2026  
**Total Tables:** 14 (7 Competency + 7 Assessment Forms)

---

## TABLE OVERVIEW

### Competency Tables (7)

| # | Table Name | Purpose | OFO Code | Key Fields |
|---|---|---|---|---|
| 1 | `arpl_competency_scale` | Rating scale (1-4 levels) | N/A | level, rating_name, rating_score |
| 2 | `arplappxb_electrician_activities` | Electrician activities | 671101 | activity_id, activity_title, hours_required |
| 3 | `arplappxb_bricklaying_activities` | Bricklayer activities | 641201 | activity_id, activity_title, hours_required |
| 4 | `arplappxb_plumbing_activities` | Plumbing activities | 642601 | activity_id, activity_title, hours_required |
| 5 | `arplappxe_electrician_activity_ratings` | Electrician competency ratings | 671101 | learnerID, activity_id, competency_level |
| 6 | `arplappxe_bricklaying_activity_ratings` | Bricklayer competency ratings | 641201 | learnerID, activity_id, competency_level |
| 7 | `arplappxb_activity_ratings` | Plumbing competency ratings | 642601 | learnerID, activity_id, competency_level |

### Assessment Form Tables (7)

| # | Table Name | Appendix | Purpose | Key Fields |
|---|---|---|---|---|
| 8 | `arpl_appendix_c` | C | Self Evaluation | learnerID, practical_knowledge, theoretical_knowledge |
| 9 | `arpl_appendix_d` | D | Practical Skills Assessment | learnerID, skill_category, marks_awarded, evidence |
| 10 | `arpl_appendix_g` | G | Assessment Agreement | learnerID, assessor_id, assessment_dates |
| 11 | `arpl_appendix_i` | I | Generic Access Recommendation | learnerID, recommendation_status, competency_areas |
| 12 | `arplelectrician_access_recommendation` | H | Electrician Access Recommendation | learnerID, trade_ofo_code=671101 |
| 13 | `arplbricklayer_access_recommendation` | H | Bricklayer Access Recommendation | learnerID, trade_ofo_code=641201 |
| 14 | `arplplumber_access_recommendation` | H | Plumber Access Recommendation | learnerID, trade_ofo_code=642601 |

---

## DETAILED TABLE SCHEMAS

### 1. ARPL_COMPETENCY_SCALE

**Purpose:** Defines the 1-4 competency rating scale used across all assessments

**Fields:**
```
id (PK)                  - AUTO_INCREMENT
level (UNIQUE)           - 1, 2, 3, or 4 (CONSTRAINT: 1-4)
rating_name              - "Not Yet Competent", "Developing", "Competent", "Highly Competent"
rating_description       - Text describing each level
rating_score            - Numeric value (0, 1, 2, 3)
created_at              - Timestamp
```

**Sample Data:**
```sql
Level 1: Not Yet Competent        | Score: 0
Level 2: Developing Competence   | Score: 1
Level 3: Competent               | Score: 2
Level 4: Highly Competent        | Score: 3
```

**Foreign Key:** Referenced by all activity rating tables

---

### 2. ARPLAPPXB_ELECTRICIAN_ACTIVITIES

**Purpose:** Stores Electrician (OFO 671101) Appendix B workplace activities

**Fields:**
```
id (PK)                 - AUTO_INCREMENT
activity_id (UNIQUE)    - Activity identifier (e.g., 1, 2, 3...)
activity_number         - String reference (e.g., "E1", "E2")
activity_title          - Activity name (e.g., "Single Phase Installation")
activity_description    - Detailed description
hours_required          - Decimal (8,2) - contact hours needed
trade_ofo_code          - Always "671101" for Electrician
created_at              - Timestamp
updated_at              - Timestamp
```

**Indexes:**
- `idx_trade_ofo` on trade_ofo_code
- `idx_activity_id` on activity_id

---

### 3. ARPLAPPXB_BRICKLAYING_ACTIVITIES

**Purpose:** Stores Bricklayer (OFO 641201) Appendix B workplace activities

**Fields:**
```
id (PK)                 - AUTO_INCREMENT
activity_id (UNIQUE)    - Activity identifier
activity_number         - String reference (e.g., "B1", "B2")
activity_title          - Activity name (e.g., "Cavity Wall Construction")
activity_description    - Detailed description
hours_required          - Decimal (8,2)
trade_ofo_code          - Always "641201" for Bricklayer
created_at              - Timestamp
updated_at              - Timestamp
```

**Indexes:**
- `idx_trade_ofo` on trade_ofo_code
- `idx_activity_id` on activity_id

---

### 4. ARPLAPPXB_PLUMBING_ACTIVITIES

**Purpose:** Stores Plumber (OFO 642601) Appendix B workplace activities

**Fields:**
```
id (PK)                 - AUTO_INCREMENT
activity_id (UNIQUE)    - Activity identifier
activity_number         - String reference (e.g., "P1", "P2")
activity_title          - Activity name (e.g., "Pipe Installation")
activity_description    - Detailed description
hours_required          - Decimal (8,2)
trade_ofo_code          - Always "642601" for Plumber
created_at              - Timestamp
updated_at              - Timestamp
```

**Indexes:**
- `idx_trade_ofo` on trade_ofo_code
- `idx_activity_id` on activity_id

---

### 5. ARPLAPPXE_ELECTRICIAN_ACTIVITY_RATINGS

**Purpose:** Stores Electrician learner competency ratings for each activity

**Fields:**
```
id (PK)                     - AUTO_INCREMENT
learnerID (FK)              - Links to learnerdetails.learnerID
activity_id (FK)            - Links to arplappxb_electrician_activities.activity_id
competency_level (FK)       - Links to arpl_competency_scale.level (1-4)
rating                      - 1-4 rating value
comments                    - Assessor comments
assessor_id (FK)            - Links to users.userID
assessment_date             - When rating was given
created_at                  - Timestamp
updated_at                  - Timestamp
UNIQUE KEY                  - (learnerID, activity_id) - one rating per activity per learner
```

**Foreign Keys:**
- learnerID → learnerdetails(learnerID)
- competency_level → arpl_competency_scale(level)
- activity_id → arplappxb_electrician_activities(activity_id)
- assessor_id → users(userID)

**Indexes:**
- idx_learner on learnerID
- idx_activity on activity_id
- idx_rating on rating

---

### 6. ARPLAPPXE_BRICKLAYING_ACTIVITY_RATINGS

**Purpose:** Stores Bricklayer learner competency ratings for each activity

**Fields:**
```
Same as #5 ELECTRICIAN ratings, but:
activity_id (FK)            - Links to arplappxb_bricklaying_activities.activity_id
UNIQUE KEY                  - (learnerID, activity_id)
```

**Foreign Keys:**
- learnerID → learnerdetails(learnerID)
- competency_level → arpl_competency_scale(level)
- activity_id → arplappxb_bricklaying_activities(activity_id)
- assessor_id → users(userID)

---

### 7. ARPLAPPXB_ACTIVITY_RATINGS

**Purpose:** Stores Plumber learner competency ratings for each activity

**Fields:**
```
Same as #5 ELECTRICIAN ratings, but:
activity_id (FK)            - Links to arplappxb_plumbing_activities.activity_id
UNIQUE KEY                  - (learnerID, activity_id)
```

**Foreign Keys:**
- learnerID → learnerdetails(learnerID)
- competency_level → arpl_competency_scale(level)
- activity_id → arplappxb_plumbing_activities(activity_id)
- assessor_id → users(userID)

---

## ASSESSMENT FORM TABLES

### 8. ARPL_APPENDIX_C (Self Evaluation)

**Purpose:** Learner self-evaluation of practical/theoretical knowledge and work experience

**Fields:**
```
id (PK)                     - AUTO_INCREMENT
learnerID (FK)              - learnerdetails.learnerID
trade_ofo_code              - 671101, 641201, or 642601
UNIQUE KEY                  - (learnerID, trade_ofo_code)

-- Section 1: Practical Knowledge
practical_knowledge         - ENUM: 'yes', 'no', 'partial'
practical_knowledge_evidence - TEXT

-- Section 2: Theoretical Knowledge
theoretical_knowledge       - ENUM: 'yes', 'no', 'partial'
theoretical_knowledge_evidence - TEXT

-- Section 3: Work Experience
years_work_experience       - DECIMAL(5,2)
work_experience_evidence    - TEXT

-- Section 4: Competency Assessment
self_assessment_rating      - INT (1-4)
self_assessment_comments    - TEXT

status                      - ENUM: 'draft', 'submitted', 'reviewed', 'approved'
submitted_at                - TIMESTAMP NULL
created_at                  - TIMESTAMP
updated_at                  - TIMESTAMP
```

**Indexes:**
- idx_learner on learnerID
- idx_ofo on trade_ofo_code

---

### 9. ARPL_APPENDIX_D (Practical Skills Assessment)

**Purpose:** Assessor records practical skill demonstration and evidence

**Fields:**
```
id (PK)                     - AUTO_INCREMENT
learnerID (FK)              - learnerdetails.learnerID
trade_ofo_code              - OFO code

-- Assessor Information
assessor_id (FK)            - users.userID
assessment_date             - When assessment occurred

-- Practical Skills Categories
skill_category              - VARCHAR(100) - name of skill
skill_description           - TEXT
skill_demonstration         - ENUM: 'demonstrated', 'partially_demonstrated', 'not_demonstrated'
marks_awarded               - DECIMAL(5,2)
marks_total                 - DECIMAL(5,2)

-- Evidence
evidence_description        - TEXT
evidence_location           - Where evidence found
photos_evidence             - LONGBLOB for images

assessor_comments           - TEXT

status                      - ENUM: 'pending', 'assessed', 'verified', 'approved'
created_at                  - TIMESTAMP
updated_at                  - TIMESTAMP
```

**Foreign Keys:**
- learnerID → learnerdetails(learnerID)
- assessor_id → users(userID)

**Indexes:**
- idx_learner on learnerID
- idx_ofo on trade_ofo_code
- idx_assessor on assessor_id
- idx_status on status

---

### 10. ARPL_APPENDIX_G (Assessment Agreement)

**Purpose:** Records formal assessment agreement between learner and assessor

**Fields:**
```
id (PK)                     - AUTO_INCREMENT
learnerID (FK)              - learnerdetails.learnerID
trade_ofo_code              - OFO code
UNIQUE KEY                  - (learnerID, trade_ofo_code)

-- Assessment Details
assessment_start_date       - DATE
assessment_end_date         - DATE
assessment_venue            - VARCHAR(255)

-- Assessor Details
assessor_id (FK)            - users.userID
assessor_name               - VARCHAR(255)
assessor_contact            - VARCHAR(100)

-- Learner Acknowledgement
learner_acknowledged_date   - TIMESTAMP NULL
learner_signature           - LONGBLOB
learner_confirmation        - TEXT

-- Assessment Components
theory_assessment           - ENUM: 'yes', 'no'
practical_assessment        - ENUM: 'yes', 'no'
portfolio_assessment        - ENUM: 'yes', 'no'

-- Terms Accepted
terms_accepted              - ENUM: 'yes', 'no'
terms_accepted_date         - TIMESTAMP NULL

status                      - ENUM: 'draft', 'agreed', 'assessment_completed', 'results_released'
created_at                  - TIMESTAMP
updated_at                  - TIMESTAMP
```

**Foreign Keys:**
- learnerID → learnerdetails(learnerID)
- assessor_id → users(userID)

---

### 11. ARPL_APPENDIX_I (Generic Access Recommendation)

**Purpose:** Generic access recommendation independent of trade

**Fields:**
```
id (PK)                     - AUTO_INCREMENT
learnerID (FK)              - learnerdetails.learnerID
trade_ofo_code              - OFO code
UNIQUE KEY                  - (learnerID, trade_ofo_code)

-- Assessment Summary
assessment_completed_date   - TIMESTAMP NULL
assessor_id (FK)            - users.userID

-- Recommendation Decision
recommendation_status       - ENUM: 'recommended', 'not_recommended', 'referred_for_reassessment'
recommendation_reason       - TEXT

-- Competency Results
competency_areas_achieved   - TEXT
competency_areas_not_achieved - TEXT

-- Additional Training/Support
additional_training_required - ENUM: 'yes', 'no'
training_recommendations    - TEXT

-- Conditional Recommendation
conditional_recommendation  - ENUM: 'yes', 'no'
conditions_to_meet          - TEXT
condition_review_date       - DATE

reviewer_id (FK)            - users.userID
reviewed_at                 - TIMESTAMP NULL

status                      - ENUM: 'draft', 'recommended', 'not_recommended', 'final'
created_at                  - TIMESTAMP
updated_at                  - TIMESTAMP
```

**Foreign Keys:**
- learnerID → learnerdetails(learnerID)
- assessor_id → users(userID)
- reviewer_id → users(userID)

**Indexes:**
- idx_learner on learnerID
- idx_ofo on trade_ofo_code
- idx_status on status

---

### 12. ARPLELECTRICIAN_ACCESS_RECOMMENDATION

**Purpose:** Trade-specific (Electrician) access recommendation with electrician-specific competencies

**Fields:**
```
id (PK)                             - AUTO_INCREMENT
learnerID (FK)                      - learnerdetails.learnerID
trade_ofo_code                      - DEFAULT '671101'
UNIQUE KEY                          - (learnerID, trade_ofo_code)

-- Assessment Summary
assessment_completed_date           - TIMESTAMP NULL
assessor_id (FK)                    - users.userID

-- Electrician Specific Competencies
electrical_safety_competent         - ENUM: 'yes', 'no'
circuit_testing_competent           - ENUM: 'yes', 'no'
installation_competent              - ENUM: 'yes', 'no'
fault_finding_competent             - ENUM: 'yes', 'no'
cable_termination_competent         - ENUM: 'yes', 'no'

-- Overall Recommendation
recommendation_status               - ENUM: 'recommended', 'not_recommended', 'referred_for_reassessment'
recommendation_reason               - TEXT

reviewer_id (FK)                    - users.userID
reviewed_at                         - TIMESTAMP NULL

status                              - ENUM: 'draft', 'recommended', 'not_recommended', 'final'
created_at                          - TIMESTAMP
updated_at                          - TIMESTAMP
```

**Foreign Keys:**
- learnerID → learnerdetails(learnerID)
- assessor_id → users(userID)
- reviewer_id → users(userID)

---

### 13. ARPLBRICKLAYER_ACCESS_RECOMMENDATION

**Purpose:** Trade-specific (Bricklayer) access recommendation with bricklayer-specific competencies

**Fields:**
```
id (PK)                             - AUTO_INCREMENT
learnerID (FK)                      - learnerdetails.learnerID
trade_ofo_code                      - DEFAULT '641201'
UNIQUE KEY                          - (learnerID, trade_ofo_code)

-- Assessment Summary
assessment_completed_date           - TIMESTAMP NULL
assessor_id (FK)                    - users.userID

-- Bricklayer Specific Competencies
masonry_competent                   - ENUM: 'yes', 'no'
mortar_preparation_competent        - ENUM: 'yes', 'no'
brick_laying_competent              - ENUM: 'yes', 'no'
wall_construction_competent         - ENUM: 'yes', 'no'
safety_compliance_competent         - ENUM: 'yes', 'no'

-- Overall Recommendation
recommendation_status               - ENUM: 'recommended', 'not_recommended', 'referred_for_reassessment'
recommendation_reason               - TEXT

reviewer_id (FK)                    - users.userID
reviewed_at                         - TIMESTAMP NULL

status                              - ENUM: 'draft', 'recommended', 'not_recommended', 'final'
created_at                          - TIMESTAMP
updated_at                          - TIMESTAMP
```

---

### 14. ARPLPLUMBER_ACCESS_RECOMMENDATION

**Purpose:** Trade-specific (Plumber) access recommendation with plumber-specific competencies

**Fields:**
```
id (PK)                             - AUTO_INCREMENT
learnerID (FK)                      - learnerdetails.learnerID
trade_ofo_code                      - DEFAULT '642601'
UNIQUE KEY                          - (learnerID, trade_ofo_code)

-- Assessment Summary
assessment_completed_date           - TIMESTAMP NULL
assessor_id (FK)                    - users.userID

-- Plumber Specific Competencies
pipe_installation_competent         - ENUM: 'yes', 'no'
joint_making_competent              - ENUM: 'yes', 'no'
drainage_competent                  - ENUM: 'yes', 'no'
water_supply_competent              - ENUM: 'yes', 'no'
safety_regulations_competent        - ENUM: 'yes', 'no'

-- Overall Recommendation
recommendation_status               - ENUM: 'recommended', 'not_recommended', 'referred_for_reassessment'
recommendation_reason               - TEXT

reviewer_id (FK)                    - users.userID
reviewed_at                         - TIMESTAMP NULL

status                              - ENUM: 'draft', 'recommended', 'not_recommended', 'final'
created_at                          - TIMESTAMP
updated_at                          - TIMESTAMP
```

---

## RELATIONSHIPS DIAGRAM

```
arpl_competency_scale (1-4 levels)
    ↓
    ├→ arplappxe_electrician_activity_ratings
    ├→ arplappxe_bricklaying_activity_ratings
    └→ arplappxb_activity_ratings

learnerdetails
    ↓
    ├→ arplappxb_electrician_activities → arplappxe_electrician_activity_ratings
    ├→ arplappxb_bricklaying_activities → arplappxe_bricklaying_activity_ratings
    ├→ arplappxb_plumbing_activities → arplappxb_activity_ratings
    ├→ arpl_appendix_c (Self Evaluation)
    ├→ arpl_appendix_d (Practical Skills)
    ├→ arpl_appendix_g (Assessment Agreement)
    ├→ arpl_appendix_i (Generic Recommendation)
    ├→ arplelectrician_access_recommendation (Electrician H)
    ├→ arplbricklayer_access_recommendation (Bricklayer H)
    └→ arplplumber_access_recommendation (Plumber H)

users (assessor/reviewer)
    ↓
    └→ All tables with assessor_id or reviewer_id FK
```

---

## DATA FLOW

1. **Competency Setup (Initial)**
   - Insert data into `arpl_competency_scale` (4 rows)
   - Insert data into `arplappxb_electrician_activities` (multiple activities)
   - Insert data into `arplappxb_bricklaying_activities` (multiple activities)
   - Insert data into `arplappxb_plumbing_activities` (multiple activities)

2. **Learner Assessment Flow**
   - Learner fills `arpl_appendix_c` (Self Evaluation)
   - Assessor creates `arpl_appendix_g` (Assessment Agreement)
   - Assessor records `arpl_appendix_d` (Practical Skills)
   - Assessor rates activities in `arplappxe_*_activity_ratings`
   - Reviewer creates recommendation in trade-specific table (12, 13, or 14)
   - Final generic recommendation created in `arpl_appendix_i`

3. **Data Retrieval**
   - Query by learnerID to get all assessments
   - Query by trade_ofo_code to filter by trade
   - Join with users for assessor names
   - Join with arpl_competency_scale for rating descriptions

---

## VERIFICATION QUERIES

```sql
-- Count all tables
SELECT 'arpl_competency_scale' as table_name, COUNT(*) as count FROM arpl_competency_scale
UNION ALL
SELECT 'arplappxb_electrician_activities', COUNT(*) FROM arplappxb_electrician_activities
UNION ALL
SELECT 'arplappxb_bricklaying_activities', COUNT(*) FROM arplappxb_bricklaying_activities
UNION ALL
SELECT 'arplappxb_plumbing_activities', COUNT(*) FROM arplappxb_plumbing_activities
UNION ALL
SELECT 'arplappxe_electrician_activity_ratings', COUNT(*) FROM arplappxe_electrician_activity_ratings
UNION ALL
SELECT 'arplappxe_bricklaying_activity_ratings', COUNT(*) FROM arplappxe_bricklaying_activity_ratings
UNION ALL
SELECT 'arplappxb_activity_ratings', COUNT(*) FROM arplappxb_activity_ratings
UNION ALL
SELECT 'arpl_appendix_c', COUNT(*) FROM arpl_appendix_c
UNION ALL
SELECT 'arpl_appendix_d', COUNT(*) FROM arpl_appendix_d
UNION ALL
SELECT 'arpl_appendix_g', COUNT(*) FROM arpl_appendix_g
UNION ALL
SELECT 'arpl_appendix_i', COUNT(*) FROM arpl_appendix_i
UNION ALL
SELECT 'arplelectrician_access_recommendation', COUNT(*) FROM arplelectrician_access_recommendation
UNION ALL
SELECT 'arplbricklayer_access_recommendation', COUNT(*) FROM arplbricklayer_access_recommendation
UNION ALL
SELECT 'arplplumber_access_recommendation', COUNT(*) FROM arplplumber_access_recommendation;
```

---

## DEPLOYMENT CHECKLIST

✓ SQL file created: `create_arpl_complete_tables.sql`  
✓ All 14 tables defined with proper relationships  
✓ Competency scale initialized with 4 levels  
✓ OFO codes correctly assigned (671101, 641201, 642601)  
✓ Foreign keys established  
✓ Indexes created for performance  
✓ Unique constraints on critical relationships  
✓ Status fields for workflow tracking  
✓ Timestamp fields for audit trail  

**Ready to deploy to online server.**
