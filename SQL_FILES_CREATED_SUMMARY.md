# SQL FILES CREATED - COMPETENCY & ASSESSMENT TABLES

**Created:** July 13, 2026

---

## FILES AVAILABLE FOR DEPLOYMENT

### 1. **create_arpl_complete_tables.sql** ✓ CREATED

This is the MAIN SQL file containing all 14 tables in one file:

**Location:** `c:\projects\rlmss\create_arpl_complete_tables.sql`

**Contains:**

#### COMPETENCY TABLES (7 tables)
1. `arpl_competency_scale` - Rating scale 1-4 with descriptions
2. `arplappxb_electrician_activities` - Electrician activities (OFO 671101)
3. `arplappxb_bricklaying_activities` - Bricklayer activities (OFO 641201)
4. `arplappxb_plumbing_activities` - Plumbing activities (OFO 642601)
5. `arplappxe_electrician_activity_ratings` - Electrician competency ratings
6. `arplappxe_bricklaying_activity_ratings` - Bricklayer competency ratings
7. `arplappxb_activity_ratings` - Plumbing competency ratings

#### ASSESSMENT FORM TABLES (7 tables)
8. `arpl_appendix_c` - Self Evaluation
9. `arpl_appendix_d` - Practical Skills Assessment
10. `arpl_appendix_g` - Assessment Agreement
11. `arpl_appendix_i` - Generic Access Recommendation
12. `arplelectrician_access_recommendation` - Electrician Access Recommendation
13. `arplbricklayer_access_recommendation` - Bricklayer Access Recommendation
14. `arplplumber_access_recommendation` - Plumber Access Recommendation

**File Size:** ~15 KB  
**Lines:** ~600  
**Execution Time:** <5 seconds  

---

## HOW TO USE

### Run on Your Online Server

```bash
mysql -u [username] -p [database_name] < create_arpl_complete_tables.sql
```

### Or in phpMyAdmin

1. Go to **Import**
2. Select `create_arpl_complete_tables.sql`
3. Click **Import**
4. All 14 tables created automatically with:
   - Proper relationships
   - Foreign key constraints
   - Indexes for performance
   - Default competency scale data

### Verify Success

```sql
-- Should return 14 tables
SHOW TABLES LIKE 'arpl%';
SHOW TABLES LIKE 'arplappxb%';
SHOW TABLES LIKE 'arplappxe%';
```

---

## TABLE STRUCTURE SUMMARY

### COMPETENCY TABLES

#### 1. arpl_competency_scale
```
Columns: id, level, rating_name, rating_description, rating_score, created_at
Pre-populated: 4 rows (levels 1-4)
```

#### 2-4. Activity Tables (Electrician, Bricklayer, Plumbing)
```
Columns: id, activity_id, activity_number, activity_title, activity_description, hours_required, trade_ofo_code, created_at, updated_at
Status: Empty (ready for data)
```

#### 5-7. Activity Rating Tables (Electrician, Bricklayer, Plumbing)
```
Columns: id, learnerID, activity_id, competency_level, rating, comments, assessor_id, assessment_date, created_at, updated_at
Status: Empty (ready for assessor ratings)
Foreign Keys: learnerID → learnerdetails, activity_id → activities table, competency_level → arpl_competency_scale
```

### ASSESSMENT FORM TABLES

#### 8. arpl_appendix_c (Self Evaluation)
```
Columns: id, learnerID, trade_ofo_code, practical_knowledge, theoretical_knowledge, years_work_experience, self_assessment_rating, status, submitted_at, created_at, updated_at
Purpose: Learner self-evaluation before formal assessment
```

#### 9. arpl_appendix_d (Practical Skills)
```
Columns: id, learnerID, trade_ofo_code, assessor_id, assessment_date, skill_category, skill_demonstration, marks_awarded, marks_total, evidence_description, photos_evidence, assessor_comments, status, created_at, updated_at
Purpose: Assessor records practical skill demonstrations
```

#### 10. arpl_appendix_g (Assessment Agreement)
```
Columns: id, learnerID, trade_ofo_code, assessment_start_date, assessment_end_date, assessor_id, learner_signature, theory_assessment, practical_assessment, portfolio_assessment, terms_accepted, status, created_at, updated_at
Purpose: Formal agreement between learner and assessor
```

#### 11. arpl_appendix_i (Generic Recommendation)
```
Columns: id, learnerID, trade_ofo_code, assessment_completed_date, recommendation_status, recommendation_reason, competency_areas_achieved, additional_training_required, conditional_recommendation, reviewer_id, status, created_at, updated_at
Purpose: Generic access recommendation independent of trade
```

#### 12-14. Trade-Specific Recommendations (Electrician, Bricklayer, Plumber)
```
Electrician: electrical_safety_competent, circuit_testing_competent, installation_competent, fault_finding_competent, cable_termination_competent
Bricklayer: masonry_competent, mortar_preparation_competent, brick_laying_competent, wall_construction_competent, safety_compliance_competent
Plumber: pipe_installation_competent, joint_making_competent, drainage_competent, water_supply_competent, safety_regulations_competent

All have: recommendation_status, recommendation_reason, reviewer_id, status, created_at, updated_at
```

---

## KEY FEATURES

✓ **All OFO codes correct:**
- Electrician: 671101
- Bricklayer: 641201
- Plumber: 642601

✓ **Foreign key relationships:**
- learnerID → learnerdetails
- assessor_id → users
- reviewer_id → users
- activity_id → activity tables
- competency_level → arpl_competency_scale

✓ **Unique constraints:**
- One activity rating per learner per activity
- One self-evaluation per learner per trade
- One assessment agreement per learner per trade

✓ **Indexes for performance:**
- learnerID (quick learner lookups)
- trade_ofo_code (trade filtering)
- status (workflow filtering)
- assessor_id (assessor queries)
- activity_id (activity lookups)

✓ **Workflow tracking:**
- Status fields: 'draft', 'submitted', 'reviewed', 'approved'
- Timestamp fields: created_at, updated_at, assessment_date, submitted_at, reviewed_at

✓ **Competency scale pre-populated:**
- Level 1: Not Yet Competent (Score: 0)
- Level 2: Developing Competence (Score: 1)
- Level 3: Competent (Score: 2)
- Level 4: Highly Competent (Score: 3)

---

## RELATED DOCUMENTATION

Also created for your reference:

1. **ARPL_COMPETENCY_ASSESSMENT_TABLES_REFERENCE.md**
   - Detailed field descriptions for all 14 tables
   - Relationships and data flow diagrams
   - Sample queries for verification
   - Data population instructions

2. **ARPL_DEPLOYMENT_CHECKLIST.md**
   - Step-by-step deployment procedure
   - Database verification checklist
   - Post-deployment testing guide

3. **ARPL_SQL_FILES_FOR_UPLOAD.txt**
   - List of all SQL files in execution order

---

## DEPLOYMENT STEPS

### Step 1: Copy SQL File
```
Source: c:\projects\rlmss\create_arpl_complete_tables.sql
Destination: Your online server SQL directory
```

### Step 2: Execute on Online Database
```bash
mysql -h your-server.com -u db-user -p db-name < create_arpl_complete_tables.sql
```

### Step 3: Verify Creation
```sql
SHOW TABLES LIKE 'arpl%';          -- Should show 14 tables
SELECT COUNT(*) FROM arpl_competency_scale;  -- Should show 4
```

### Step 4: Populate Activity Data
Once tables are created, populate:
- `arplappxb_electrician_activities` with electrician activities
- `arplappxb_bricklaying_activities` with bricklayer activities
- `arplappxb_plumbing_activities` with plumbing activities

---

## EXECUTION ORDER FOR DEPLOYMENT

When uploading to online server, execute SQL files in this order:

1. `create_arpl_theory_papers.sql` (existing - theory paper structures)
2. `create_arpl_separate_tables.sql` (existing - unified POE)
3. `create_arpl_poe_unified_table.sql` (existing - main POE table)
4. `create_arpl_appendix_d_table.sql` (existing - practical skills)
5. `create_arpl_appendix_f_tables.sql` (existing - criteria assessment)
6. `create_bricklayer_appendix_tables.sql` (existing - bricklayer forms)
7. `create_bricklayer_gap_closure_tables.sql` (existing - gap analysis)
8. `create_plumber_access_recommendation.sql` (existing - plumber recommendation)
9. **`create_arpl_complete_tables.sql`** ← NEW FILE (competency & assessment forms)
10. `insert_questions_electrician_theory.sql` (existing - questions)
11. `insert_questions_electrician_practical.sql` (existing - questions)
12. `insert_questions_bricklayer_theory.sql` (existing - questions)
13. `insert_questions_bricklayer_practical.sql` (existing - questions)

---

## READY FOR PRODUCTION

✅ SQL file: `create_arpl_complete_tables.sql`  
✅ Documentation: `ARPL_COMPETENCY_ASSESSMENT_TABLES_REFERENCE.md`  
✅ Deployment Guide: `ARPL_DEPLOYMENT_CHECKLIST.md`  

All 14 tables defined, relationships established, indexes created.

**Ready to deploy to your online server.**
