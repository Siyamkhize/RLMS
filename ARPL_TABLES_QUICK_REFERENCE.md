# ARPL TABLES - QUICK REFERENCE GUIDE

**All 14 Tables at a Glance**

---

## COMPETENCY TABLES (7)

| Table | Trade | OFO | Purpose | Key Columns |
|-------|-------|-----|---------|-------------|
| `arpl_competency_scale` | All | N/A | Rating scale 1-4 | level, rating_name, rating_score |
| `arplappxb_electrician_activities` | Electrician | 671101 | Activities list | activity_id, activity_title, hours_required |
| `arplappxb_bricklaying_activities` | Bricklayer | 641201 | Activities list | activity_id, activity_title, hours_required |
| `arplappxb_plumbing_activities` | Plumber | 642601 | Activities list | activity_id, activity_title, hours_required |
| `arplappxe_electrician_activity_ratings` | Electrician | 671101 | Competency ratings | learnerID, activity_id, rating (1-4) |
| `arplappxe_bricklaying_activity_ratings` | Bricklayer | 641201 | Competency ratings | learnerID, activity_id, rating (1-4) |
| `arplappxb_activity_ratings` | Plumber | 642601 | Competency ratings | learnerID, activity_id, rating (1-4) |

---

## ASSESSMENT FORM TABLES (7)

| Table | Appendix | Purpose | Key Columns | Trade Filter |
|-------|----------|---------|-------------|--------------|
| `arpl_appendix_c` | C | Self Evaluation | learnerID, practical_knowledge, theoretical_knowledge, years_work_experience | trade_ofo_code |
| `arpl_appendix_d` | D | Practical Skills | learnerID, skill_category, marks_awarded, evidence | trade_ofo_code |
| `arpl_appendix_g` | G | Assessment Agreement | learnerID, assessor_id, assessment_dates, terms_accepted | trade_ofo_code |
| `arpl_appendix_i` | I | Generic Recommendation | learnerID, recommendation_status, competency_areas | trade_ofo_code |
| `arplelectrician_access_recommendation` | H | Electrician Recommendation | learnerID, OFO=671101, electrical_safety, circuit_testing, installation | OFO 671101 |
| `arplbricklayer_access_recommendation` | H | Bricklayer Recommendation | learnerID, OFO=641201, masonry, brick_laying, wall_construction | OFO 641201 |
| `arplplumber_access_recommendation` | H | Plumber Recommendation | learnerID, OFO=642601, pipe_installation, joint_making, drainage | OFO 642601 |

---

## DETAILED TABLE COLUMNS

### COMPETENCY TABLES

#### 1. arpl_competency_scale
```
✓ id (INT, PK)
✓ level (INT, UNIQUE, 1-4)
✓ rating_name (VARCHAR 100)
✓ rating_description (TEXT)
✓ rating_score (DECIMAL 5,2)
✓ created_at (TIMESTAMP)
```
**Pre-populated:** 4 rows (Level 1-4)

#### 2-4. arplappxb_[electrician/bricklaying/plumbing]_activities
```
✓ id (INT, PK)
✓ activity_id (INT, UNIQUE)
✓ activity_number (VARCHAR 50)
✓ activity_title (VARCHAR 255)
✓ activity_description (TEXT)
✓ hours_required (DECIMAL 8,2)
✓ trade_ofo_code (VARCHAR 50)
✓ created_at (TIMESTAMP)
✓ updated_at (TIMESTAMP)
```
**Status:** Empty (ready for data)  
**Indexes:** trade_ofo_code, activity_id

#### 5-7. arplappxe_[electrician/bricklaying]_activity_ratings + arplappxb_activity_ratings
```
✓ id (INT, PK)
✓ learnerID (INT, FK → learnerdetails)
✓ activity_id (INT, FK → activities)
✓ competency_level (INT, FK → arpl_competency_scale.level)
✓ rating (INT, 1-4)
✓ comments (TEXT)
✓ assessor_id (INT, FK → users)
✓ assessment_date (TIMESTAMP NULL)
✓ created_at (TIMESTAMP)
✓ updated_at (TIMESTAMP)
✓ UNIQUE (learnerID, activity_id)
```
**Status:** Empty (ready for ratings)  
**Indexes:** learnerID, activity_id, rating

---

### ASSESSMENT FORM TABLES

#### 8. arpl_appendix_c (Self Evaluation)
```
✓ id (INT, PK)
✓ learnerID (INT, FK)
✓ trade_ofo_code (VARCHAR 50)
✓ practical_knowledge (ENUM: yes/no/partial)
✓ practical_knowledge_evidence (TEXT)
✓ theoretical_knowledge (ENUM: yes/no/partial)
✓ theoretical_knowledge_evidence (TEXT)
✓ years_work_experience (DECIMAL 5,2)
✓ work_experience_evidence (TEXT)
✓ self_assessment_rating (INT)
✓ self_assessment_comments (TEXT)
✓ status (ENUM: draft/submitted/reviewed/approved)
✓ submitted_at (TIMESTAMP NULL)
✓ created_at (TIMESTAMP)
✓ updated_at (TIMESTAMP)
✓ UNIQUE (learnerID, trade_ofo_code)
```

#### 9. arpl_appendix_d (Practical Skills Assessment)
```
✓ id (INT, PK)
✓ learnerID (INT, FK)
✓ trade_ofo_code (VARCHAR 50)
✓ assessor_id (INT, FK)
✓ assessment_date (TIMESTAMP NULL)
✓ skill_category (VARCHAR 100)
✓ skill_description (TEXT)
✓ skill_demonstration (ENUM: demonstrated/partially_demonstrated/not_demonstrated)
✓ marks_awarded (DECIMAL 5,2)
✓ marks_total (DECIMAL 5,2)
✓ evidence_description (TEXT)
✓ evidence_location (VARCHAR 255)
✓ photos_evidence (LONGBLOB)
✓ assessor_comments (TEXT)
✓ status (ENUM: pending/assessed/verified/approved)
✓ created_at (TIMESTAMP)
✓ updated_at (TIMESTAMP)
```

#### 10. arpl_appendix_g (Assessment Agreement)
```
✓ id (INT, PK)
✓ learnerID (INT, FK)
✓ trade_ofo_code (VARCHAR 50)
✓ assessment_start_date (DATE)
✓ assessment_end_date (DATE)
✓ assessment_venue (VARCHAR 255)
✓ assessor_id (INT, FK)
✓ assessor_name (VARCHAR 255)
✓ assessor_contact (VARCHAR 100)
✓ learner_acknowledged_date (TIMESTAMP NULL)
✓ learner_signature (LONGBLOB)
✓ learner_confirmation (TEXT)
✓ theory_assessment (ENUM: yes/no)
✓ practical_assessment (ENUM: yes/no)
✓ portfolio_assessment (ENUM: yes/no)
✓ terms_accepted (ENUM: yes/no)
✓ terms_accepted_date (TIMESTAMP NULL)
✓ status (ENUM: draft/agreed/assessment_completed/results_released)
✓ created_at (TIMESTAMP)
✓ updated_at (TIMESTAMP)
✓ UNIQUE (learnerID, trade_ofo_code)
```

#### 11. arpl_appendix_i (Generic Access Recommendation)
```
✓ id (INT, PK)
✓ learnerID (INT, FK)
✓ trade_ofo_code (VARCHAR 50)
✓ assessment_completed_date (TIMESTAMP NULL)
✓ assessor_id (INT, FK)
✓ recommendation_status (ENUM: recommended/not_recommended/referred_for_reassessment)
✓ recommendation_reason (TEXT)
✓ competency_areas_achieved (TEXT)
✓ competency_areas_not_achieved (TEXT)
✓ additional_training_required (ENUM: yes/no)
✓ training_recommendations (TEXT)
✓ conditional_recommendation (ENUM: yes/no)
✓ conditions_to_meet (TEXT)
✓ condition_review_date (DATE)
✓ reviewer_id (INT, FK)
✓ reviewed_at (TIMESTAMP NULL)
✓ status (ENUM: draft/recommended/not_recommended/final)
✓ created_at (TIMESTAMP)
✓ updated_at (TIMESTAMP)
✓ UNIQUE (learnerID, trade_ofo_code)
```

#### 12. arplelectrician_access_recommendation
```
✓ id (INT, PK)
✓ learnerID (INT, FK)
✓ trade_ofo_code (VARCHAR 50, DEFAULT '671101')
✓ assessment_completed_date (TIMESTAMP NULL)
✓ assessor_id (INT, FK)
✓ electrical_safety_competent (ENUM: yes/no)
✓ circuit_testing_competent (ENUM: yes/no)
✓ installation_competent (ENUM: yes/no)
✓ fault_finding_competent (ENUM: yes/no)
✓ cable_termination_competent (ENUM: yes/no)
✓ recommendation_status (ENUM: recommended/not_recommended/referred_for_reassessment)
✓ recommendation_reason (TEXT)
✓ reviewer_id (INT, FK)
✓ reviewed_at (TIMESTAMP NULL)
✓ status (ENUM: draft/recommended/not_recommended/final)
✓ created_at (TIMESTAMP)
✓ updated_at (TIMESTAMP)
✓ UNIQUE (learnerID, trade_ofo_code)
```

#### 13. arplbricklayer_access_recommendation
```
✓ id (INT, PK)
✓ learnerID (INT, FK)
✓ trade_ofo_code (VARCHAR 50, DEFAULT '641201')
✓ assessment_completed_date (TIMESTAMP NULL)
✓ assessor_id (INT, FK)
✓ masonry_competent (ENUM: yes/no)
✓ mortar_preparation_competent (ENUM: yes/no)
✓ brick_laying_competent (ENUM: yes/no)
✓ wall_construction_competent (ENUM: yes/no)
✓ safety_compliance_competent (ENUM: yes/no)
✓ recommendation_status (ENUM: recommended/not_recommended/referred_for_reassessment)
✓ recommendation_reason (TEXT)
✓ reviewer_id (INT, FK)
✓ reviewed_at (TIMESTAMP NULL)
✓ status (ENUM: draft/recommended/not_recommended/final)
✓ created_at (TIMESTAMP)
✓ updated_at (TIMESTAMP)
✓ UNIQUE (learnerID, trade_ofo_code)
```

#### 14. arplplumber_access_recommendation
```
✓ id (INT, PK)
✓ learnerID (INT, FK)
✓ trade_ofo_code (VARCHAR 50, DEFAULT '642601')
✓ assessment_completed_date (TIMESTAMP NULL)
✓ assessor_id (INT, FK)
✓ pipe_installation_competent (ENUM: yes/no)
✓ joint_making_competent (ENUM: yes/no)
✓ drainage_competent (ENUM: yes/no)
✓ water_supply_competent (ENUM: yes/no)
✓ safety_regulations_competent (ENUM: yes/no)
✓ recommendation_status (ENUM: recommended/not_recommended/referred_for_reassessment)
✓ recommendation_reason (TEXT)
✓ reviewer_id (INT, FK)
✓ reviewed_at (TIMESTAMP NULL)
✓ status (ENUM: draft/recommended/not_recommended/final)
✓ created_at (TIMESTAMP)
✓ updated_at (TIMESTAMP)
✓ UNIQUE (learnerID, trade_ofo_code)
```

---

## FOREIGN KEY RELATIONSHIPS

### From learnerdetails (learnerID)
- arplappxe_electrician_activity_ratings.learnerID
- arplappxe_bricklaying_activity_ratings.learnerID
- arplappxb_activity_ratings.learnerID
- arpl_appendix_c.learnerID
- arpl_appendix_d.learnerID
- arpl_appendix_g.learnerID
- arpl_appendix_i.learnerID
- arplelectrician_access_recommendation.learnerID
- arplbricklayer_access_recommendation.learnerID
- arplplumber_access_recommendation.learnerID

### From users (userID)
- arplappxe_electrician_activity_ratings.assessor_id
- arplappxe_bricklaying_activity_ratings.assessor_id
- arplappxb_activity_ratings.assessor_id
- arpl_appendix_d.assessor_id
- arpl_appendix_g.assessor_id
- arpl_appendix_i.assessor_id / reviewer_id
- arplelectrician_access_recommendation.assessor_id / reviewer_id
- arplbricklayer_access_recommendation.assessor_id / reviewer_id
- arplplumber_access_recommendation.assessor_id / reviewer_id

### From arpl_competency_scale (level)
- arplappxe_electrician_activity_ratings.competency_level
- arplappxe_bricklaying_activity_ratings.competency_level
- arplappxb_activity_ratings.competency_level

### Between activities & ratings
- arplappxb_electrician_activities.activity_id → arplappxe_electrician_activity_ratings.activity_id
- arplappxb_bricklaying_activities.activity_id → arplappxe_bricklaying_activity_ratings.activity_id
- arplappxb_plumbing_activities.activity_id → arplappxb_activity_ratings.activity_id

---

## INDEXES

All tables have indexes on:
- **learnerID** - Fast learner lookups
- **trade_ofo_code** - Trade-specific filtering
- **status** - Workflow state queries
- **assessor_id** - Assessor-specific queries
- **activity_id** - Activity lookups

---

## UNIQUE CONSTRAINTS

- `(learnerID, activity_id)` - One rating per activity per learner
- `(learnerID, trade_ofo_code)` - One form per learner per trade
- `activity_id` - Unique activity identifiers

---

## STATUS WORKFLOW VALUES

**Activity Ratings:**
- pending_rating → rated → reviewed

**Self Evaluation (Appendix C):**
- draft → submitted → reviewed → approved

**Practical Skills (Appendix D):**
- pending → assessed → verified → approved

**Assessment Agreement (Appendix G):**
- draft → agreed → assessment_completed → results_released

**Recommendations (Appendix I & Trade-Specific):**
- draft → recommended / not_recommended / final

---

## SQL FILE LOCATION

**File:** `c:\projects\rlmss\create_arpl_complete_tables.sql`

**To deploy:**
```bash
mysql -u user -p database < create_arpl_complete_tables.sql
```

**Execute as step 9 in deployment sequence** (after existing ARPL tables, before question data)
