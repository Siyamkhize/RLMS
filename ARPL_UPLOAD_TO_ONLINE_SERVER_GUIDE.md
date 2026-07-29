# ARPL System - Upload to Online Server Guide

**Date:** July 13, 2026  
**Status:** Complete Identification Done  
**Total Items to Upload:** 58 PHP endpoints + 26 Database tables + 13 SQL files

---

## SUMMARY

The ARPL system requires uploading to your online server:

### 📦 Items to Upload:
- **58 PHP Endpoints** (Mobile API)
- **26 Database Tables** (Schema)
- **13 SQL Setup Files** (Table creation + data insertion)

### 📂 Target Directory:
```
Online Server: /assessorReport2/mobile/
```

---

## PART 1: PHP ENDPOINTS (58 files)

### Location: 
```
Source: c:\projects\rlmss\mobile\
Target: /assessorReport2/mobile/
```

### Breakdown:

**GET Endpoints (16 files)** - Read/Retrieve Data:
```
✓ get_arpl_access_recommendation.php
✓ get_arpl_appeals.php
✓ get_arpl_appendix_d.php
✓ get_arpl_appendix_e.php
✓ get_arpl_appendix_e_ratings.php
✓ get_arpl_appendix_f.php
✓ get_arpl_application.php
✓ get_arpl_assessment_agreement.php
✓ get_arpl_competency_data.php
✓ get_arpl_curriculum.php
✓ get_arpl_data.php
✓ get_arpl_gap_analysis.php
✓ get_arpl_hierarchy.php
✓ get_arpl_statement_of_results.php
✓ get_arpl_toolkit_data.php
✓ get_arpl_upload_status.php
```

**SAVE Endpoints (17 files)** - Write/Create/Update Data:
```
✓ save_arpl_access_recommendation.php
✓ save_arpl_activity_rating.php
✓ save_arpl_appendix_a.php
✓ save_arpl_appendix_b.php
✓ save_arpl_appendix_c.php
✓ save_arpl_appendix_d.php
✓ save_arpl_appendix_e.php
✓ save_arpl_appendix_e_ratings.php
✓ save_arpl_appendix_f.php
✓ save_arpl_appendix_f_assessment.php
✓ save_arpl_appendix_g.php
✓ save_arpl_appendix_i.php
✓ save_arpl_appendix_j.php
✓ save_arpl_application.php
✓ save_arpl_criteria.php
✓ save_arpl_gap_analysis.php
✓ save_arpl_toolkit_edits.php
```

**Other Endpoints (25 files)** - Utilities, Setup, Testing:
```
✓ arpl_get_practical_ratings.php
✓ arpl_hierarchical_navigator.php
✓ arpl_rate_practical.php
✓ arpl_save_metadata.php
✓ arpl_save_practical.php
✓ arpl_save_theory.php
✓ arpl_toolkit_dynamic.php
✓ arpl_toolkit_dynamic_backup_20260708_170236.php
✓ audit_arpl_database.php
✓ check_arpl_data.php
✓ check_arpl_db.php
✓ check_arpl_papers.php
✓ check_arpl_papers_structure.php
✓ check_arpl_tables.php
✓ check_arpl_trades.php
✓ check_learner_16389_arpl.php
✓ verify_arpl_theory_papers.php
✓ execute_arpl_setup.php
✓ fix_check_arpl_tables.php
✓ setup_arpl_electrician_papers.php
✓ setup_arpl_theory_papers.php
✓ test_all_arpl_endpoints.php
✓ test_arpl_apis.php
✓ test_arpl_competency_endpoint.php
✓ test_get_arpl_endpoint.php
```

---

## PART 2: DATABASE TABLES (26 tables)

### Core Tables (4):
```
✓ arpl_poe - Main POE unified table (theory & practical papers)
✓ arpl_papers - Paper definitions and templates
✓ arpl_questions - Assessment questions for each paper
✓ arpl_trades - Trade definitions (Electrician, Bricklayer, Plumber)
```

### Competency Tables (7):
```
✓ arpl_competency_scale - Rating scale (1-4 levels)
✓ arplappxb_electrician_activities - Electrician activities
✓ arplappxb_bricklaying_activities - Bricklaying activities
✓ arplappxb_plumbing_activities - Plumbing activities
✓ arplappxe_electrician_activity_ratings - Electrician ratings
✓ arplappxe_bricklaying_activity_ratings - Bricklaying ratings
✓ arplappxb_activity_ratings - Plumbing ratings
```

### Assessment Form Tables (7):
```
✓ arpl_appendix_c - Self Evaluation
✓ arpl_appendix_d - Practical Skills Assessment
✓ arpl_appendix_g - Assessment Agreement
✓ arpl_appendix_i - Access Recommendation (Generic)
✓ arplelectrician_access_recommendation - Electrician H
✓ arplbricklayer_access_recommendation - Bricklayer H
✓ arplplumber_access_recommendation - Plumber H
```

### Application & Work Experience (4):
```
✓ arpl_applications_v3 - Application forms
✓ arpl_work_experience_v3 - Work experience records
✓ arpl_references_v3 - References provided
✓ arpl_qualifications_v3 - Qualifications submitted
```

### Gap Analysis Tables (4):
```
✓ gap_analysis_submissions - Submissions
✓ gap_analysis_submission_items - Line items
✓ gap_analysis_report - Report templates
✓ arpl_bricklayer_gap_tasks - Gap closure tasks
```

---

## PART 3: SQL FILES (13 files)

Run these files in order on your online server database:

```
1. create_arpl_theory_papers.sql
   - Creates arpl_trades, arpl_papers, arpl_questions

2. create_arpl_separate_tables.sql
   - Creates separate ARPL tables

3. create_arpl_poe_unified_table.sql
   - Creates main arpl_poe unified table

4. create_arpl_appendix_d_table.sql
   - Creates Appendix D table

5. create_arpl_appendix_f_tables.sql
   - Creates Appendix F tables

6. create_bricklayer_appendix_tables.sql
   - Creates Bricklayer-specific tables

7. create_bricklayer_gap_closure_tables.sql
   - Creates gap closure tables

8. create_plumber_access_recommendation.sql
   - Creates Plumber recommendation table

9. insert_questions_electrician_theory.sql
   - Inserts Electrician theory questions

10. insert_questions_electrician_practical.sql
    - Inserts Electrician practical questions

11. insert_questions_bricklayer_theory.sql
    - Inserts Bricklayer theory questions

12. insert_questions_bricklayer_practical.sql
    - Inserts Bricklayer practical questions

13. insert_bricklayer_questions.sql
    - Additional Bricklayer questions
```

---

## UPLOAD PROCEDURES

### Method 1: Using FTP/SFTP

```
1. Connect to online server FTP/SFTP
2. Navigate to: /assessorReport2/mobile/
3. Upload all 58 .php files from: c:\projects\rlmss\mobile\arpl*.php
```

### Method 2: Using Command Line (SCP)

```bash
# Copy all ARPL endpoints to server
scp c:\projects\rlmss\mobile\arpl*.php \
    c:\projects\rlmss\mobile\get_arpl*.php \
    c:\projects\rlmss\mobile\save_arpl*.php \
    c:\projects\rlmss\mobile\check_arpl*.php \
    user@online-server:/path/to/assessorReport2/mobile/
```

### Method 3: SSH Terminal Access

```bash
# On online server:
cd /var/www/html/assessorReport2/mobile/

# Then use WinSCP or FileZilla to upload files
```

---

## DATABASE SETUP PROCEDURE

### On Online Server:

```bash
# 1. Connect to MySQL/MariaDB
mysql -u username -p database_name

# 2. Run SQL files in order (from c:\projects\rlmss\)
source /path/to/create_arpl_theory_papers.sql;
source /path/to/create_arpl_separate_tables.sql;
source /path/to/create_arpl_poe_unified_table.sql;
source /path/to/create_arpl_appendix_d_table.sql;
source /path/to/create_arpl_appendix_f_tables.sql;
source /path/to/create_bricklayer_appendix_tables.sql;
source /path/to/create_bricklayer_gap_closure_tables.sql;
source /path/to/create_plumber_access_recommendation.sql;
source /path/to/insert_questions_electrician_theory.sql;
source /path/to/insert_questions_electrician_practical.sql;
source /path/to/insert_questions_bricklayer_theory.sql;
source /path/to/insert_questions_bricklayer_practical.sql;
source /path/to/insert_bricklayer_questions.sql;

# 3. Verify tables created
SHOW TABLES LIKE 'arpl%';
```

---

## VERIFICATION CHECKLIST

### After uploading PHP endpoints:

- [ ] All 58 .php files copied to `/assessorReport2/mobile/`
- [ ] File permissions set correctly (644 or 755)
- [ ] `.htaccess` file in `/assessorReport2/mobile/` (if exists)
- [ ] Test endpoint: `http://your-server.com/assessorReport2/mobile/get_arpl_data.php`

### After running SQL files:

- [ ] All 26 tables created successfully
- [ ] Tables have correct columns and data types
- [ ] Questions data inserted (check row counts)
- [ ] Trade definitions present (671101, 641201, 642601)
- [ ] Foreign keys created (if applicable)

---

## TESTING

### Test PHP Endpoints:

```bash
# Test GET endpoint
curl http://your-server.com/assessorReport2/mobile/get_arpl_data.php?learnerID=1

# Test SAVE endpoint
curl -X POST http://your-server.com/assessorReport2/mobile/save_arpl_appendix_b.php \
  -d "learnerID=1&data=test"
```

### Test Database:

```sql
-- Check core tables
SELECT COUNT(*) FROM arpl_poe;
SELECT COUNT(*) FROM arpl_questions;
SELECT COUNT(*) FROM arpl_papers;
SELECT DISTINCT trade_ofo_code FROM arpl_papers;

-- Check questions
SELECT COUNT(*) FROM arpl_questions WHERE paper_id = 1;
```

---

## GENERATED FILES

The identification script created these reference files:

```
✓ ARPL_ENDPOINTS_FOR_UPLOAD.txt
✓ ARPL_DATABASE_TABLES_FOR_UPLOAD.txt
✓ ARPL_SQL_FILES_FOR_UPLOAD.txt
✓ identify_arpl_for_upload.php (the identification script)
```

Use these files as a checklist during upload.

---

## TROUBLESHOOTING

### 404 Errors on Endpoints:

1. Check file permissions: `chmod 755 *.php`
2. Verify directory path: `/assessorReport2/mobile/`
3. Check `.htaccess` for rewrite rules
4. Test direct file access: `http://server/assessorReport2/mobile/get_arpl_data.php`

### Database Connection Errors:

1. Update `connection.php` credentials for online server
2. Check database user permissions
3. Verify database name and host
4. Test connection with `mysqli_connect()`

### Missing Tables:

1. Re-run all SQL files in order
2. Check for SQL errors in execution
3. Verify table names with: `SHOW TABLES LIKE 'arpl%';`
4. Check collation and charset match

---

## QUICK REFERENCE

| Item | Count | Status |
|------|-------|--------|
| PHP Endpoints | 58 | Ready for upload |
| Database Tables | 26 | Ready for creation |
| SQL Files | 13 | Ready to execute |
| GET Endpoints | 16 | For reading data |
| SAVE Endpoints | 17 | For writing data |
| Setup/Test Endpoints | 25 | For verification |

---

## NEXT STEPS

1. ✅ Review all 58 endpoints in `ARPL_ENDPOINTS_FOR_UPLOAD.txt`
2. ✅ Review all 26 tables in `ARPL_DATABASE_TABLES_FOR_UPLOAD.txt`
3. ✅ Review all 13 SQL files in `ARPL_SQL_FILES_FOR_UPLOAD.txt`
4. 📤 Upload 58 PHP endpoints to `/assessorReport2/mobile/`
5. 🗄️ Run 13 SQL files on online database (in order)
6. ✔️ Verify all endpoints and tables created
7. 🧪 Test endpoints with sample data
8. 📱 Update mobile app to point to online server

---

**Status:** ✅ COMPLETE - Ready for deployment  
**Generated:** 2026-07-13  
**All files ready in:** `c:\projects\rlmss\`
