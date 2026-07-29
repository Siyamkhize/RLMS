# ARPL ONLINE SERVER DEPLOYMENT CHECKLIST

**Date:** July 13, 2026  
**System:** RLMSS ARPL Module  
**Scope:** Complete ARPL system deployment to online server

---

## DEPLOYMENT OVERVIEW

Deploy **58 PHP endpoints** and **26 database tables** for the Assessment of Prior Learning (ARPL) system.

**Key Facts:**
- Only 2 classes have ARPL enabled: classID 782 (Electrician) and 783 (Bricklayer)
- OFO Codes: 671101 (Electrician), 641201 (Bricklayer), 642601 (Plumber)
- All endpoints in: `/assessorReport2/mobile/`
- Database: Single integration database (no separate ARPL database)

---

## STEP 1: DATABASE SETUP (13 SQL Files - Execute in Order)

Run these SQL files on your online database server in this exact sequence:

### Core Setup (4 files)
1. **create_arpl_theory_papers.sql** - Theory paper structures
2. **create_arpl_separate_tables.sql** - Initial separate tables
3. **create_arpl_poe_unified_table.sql** - Unified POE table (theory + practical)
4. **create_arpl_appendix_d_table.sql** - Practical skills assessment

### Form & Assessment Tables (3 files)
5. **create_arpl_appendix_f_tables.sql** - Criteria assessment
6. **create_bricklayer_appendix_tables.sql** - Bricklayer forms (Appendix C, G, I)
7. **create_bricklayer_gap_closure_tables.sql** - Gap analysis tables

### Trade-Specific Setup (1 file)
8. **create_plumber_access_recommendation.sql** - Plumber access recommendation

### Question Data (4 files)
9. **insert_questions_electrician_theory.sql** - Electrician theory questions (21 Q)
10. **insert_questions_electrician_practical.sql** - Electrician practical questions
11. **insert_questions_bricklayer_theory.sql** - Bricklayer theory questions
12. **insert_questions_bricklayer_practical.sql** - Bricklayer practical questions

**Execution Command:**
```bash
mysql -u [username] -p [database_name] < create_arpl_theory_papers.sql
mysql -u [username] -p [database_name] < create_arpl_separate_tables.sql
# ... continue with remaining files in order
```

---

## STEP 2: DATABASE TABLES CREATED (26 Total)

After SQL files execute, verify these 26 tables exist:

### Core Tables (4)
- ✓ `arpl_poe` - Main POE unified table
- ✓ `arpl_papers` - Paper definitions
- ✓ `arpl_questions` - Assessment questions
- ✓ `arpl_trades` - Trade definitions

### Competency Tables (7)
- ✓ `arpl_competency_scale` - Rating scale (1-4)
- ✓ `arplappxb_electrician_activities` - Electrician activities
- ✓ `arplappxb_bricklaying_activities` - Bricklayer activities
- ✓ `arplappxb_plumbing_activities` - Plumber activities
- ✓ `arplappxe_electrician_activity_ratings` - Electrician ratings
- ✓ `arplappxe_bricklaying_activity_ratings` - Bricklayer ratings
- ✓ `arplappxb_activity_ratings` - Plumbing ratings

### Assessment Form Tables (7)
- ✓ `arpl_appendix_c` - Self Evaluation
- ✓ `arpl_appendix_d` - Practical Skills
- ✓ `arpl_appendix_g` - Assessment Agreement
- ✓ `arpl_appendix_i` - Generic Access Recommendation
- ✓ `arplelectrician_access_recommendation` - Electrician recommendation
- ✓ `arplbricklayer_access_recommendation` - Bricklayer recommendation
- ✓ `arplplumber_access_recommendation` - Plumber recommendation

### Application & Experience Tables (4)
- ✓ `arpl_applications_v3` - Application forms
- ✓ `arpl_work_experience_v3` - Work experience
- ✓ `arpl_references_v3` - References
- ✓ `arpl_qualifications_v3` - Qualifications

### Gap Analysis Tables (4)
- ✓ `gap_analysis_submissions` - Submissions
- ✓ `gap_analysis_submission_items` - Line items
- ✓ `gap_analysis_report` - Reports
- ✓ `arpl_bricklayer_gap_tasks` - Gap tasks

**Verification Command:**
```sql
SHOW TABLES LIKE 'arpl%';
SHOW TABLES LIKE 'gap_%';
```

---

## STEP 3: DEPLOY PHP ENDPOINTS (58 Files)

Upload all PHP files from `c:\projects\rlmss\mobile\` to your online server at `/assessorReport2/mobile/`

### GET ENDPOINTS (16 files) - Read Operations
```
get_arpl_access_recommendation.php
get_arpl_appeals.php
get_arpl_appendix_d.php
get_arpl_appendix_e.php
get_arpl_appendix_e_ratings.php
get_arpl_appendix_f.php
get_arpl_application.php
get_arpl_assessment_agreement.php
get_arpl_competency_data.php
get_arpl_curriculum.php
get_arpl_data.php
get_arpl_gap_analysis.php
get_arpl_hierarchy.php
get_arpl_statement_of_results.php
get_arpl_toolkit_data.php
get_bricklayer_toolkit_data.php
```

### SAVE ENDPOINTS (17 files) - Write Operations
```
save_arpl_access_recommendation.php
save_arpl_activity_rating.php
save_arpl_appendix_a.php
save_arpl_appendix_b.php
save_arpl_appendix_c.php
save_arpl_appendix_d.php
save_arpl_appendix_e.php
save_arpl_appendix_e_ratings.php
save_arpl_appendix_f.php
save_arpl_appendix_f_assessment.php
save_arpl_appendix_g.php
save_arpl_appendix_i.php
save_arpl_appendix_j.php
save_arpl_application.php
save_arpl_criteria.php
save_arpl_gap_analysis.php
save_arpl_toolkit_edits.php
```

### UTILITY ENDPOINTS (8 files) - Testing & Diagnostics
```
check_arpl_data.php
check_arpl_db.php
check_arpl_papers.php
check_arpl_papers_structure.php
check_arpl_tables.php
check_arpl_trades.php
check_learner_16389_arpl.php
verify_arpl_theory_papers.php
```

**Upload Command (example with FTP/SCP):**
```bash
scp -r c:\projects\rlmss\mobile\*.php user@server:/var/www/html/assessorReport2/mobile/
```

---

## STEP 4: VERIFY ENDPOINTS ARE ACCESSIBLE

Test that all endpoints are reachable. Use a test endpoint first:

```bash
curl http://[your-online-server]/assessorReport2/mobile/check_arpl_db.php
curl http://[your-online-server]/assessorReport2/mobile/check_arpl_tables.php
```

Expected response: JSON with status and table count.

---

## STEP 5: CONFIGURATION VERIFICATION

Verify these configurations on online server:

### 1. .htaccess Rules (in `/assessorReport2/mobile/`)
Ensure `.htaccess` file allows PHP execution:
```apache
<FilesMatch "\.php$">
    Allow from all
</FilesMatch>
```

### 2. PHP Configuration
- PHP version: 7.4+ (recommended 8.0+)
- Required extensions: mysqli, json, gd
- Max upload size: 50MB+

### 3. Database Connection
- Update `connection.php` with online database credentials
- Verify credentials work: `mysqli_connect(host, user, pass, db)`

### 4. File Permissions
```bash
chmod 755 /var/www/html/assessorReport2/mobile/
chmod 644 /var/www/html/assessorReport2/mobile/*.php
```

---

## STEP 6: MOBILE APP CONFIGURATION

Mobile app (Flutter) is configured via `lib/config.dart`:

```dart
static const String baseUrl = 'http://[your-online-server]:8080/assessorReport2/';
static const String apiEndpoint = baseUrl + 'mobile/';
```

**Important:** No changes needed if online server URL is properly configured in `connection.php`.

---

## STEP 7: DATA VALIDATION CHECKLIST

After deployment, verify:

- [ ] All 26 tables created successfully
- [ ] All 58 endpoints accessible (test with `check_arpl_tables.php`)
- [ ] Theory questions loaded (21 electrician + bricklayer questions)
- [ ] Practical questions loaded
- [ ] Competency scale has 4 levels
- [ ] Activities loaded for all 3 trades
- [ ] Appendix forms accessible via GET endpoints

**Test Learner Data:**
```bash
curl "http://[server]/assessorReport2/mobile/get_arpl_competency_data.php?learnerID=16389"
```

Expected: Returns OFO code, activities, ratings

---

## STEP 8: CRITICAL OFO CODE VERIFICATION

**Verify these are correct in database:**

| Trade | OFO Code | Status |
|-------|----------|--------|
| Electrician | 671101 | ✓ Correct |
| Bricklayer | 641201 | ✓ Correct |
| Plumber | 642601 | ✓ Correct |

Check in `arpl_trades` table:
```sql
SELECT trade_name, ofo_code FROM arpl_trades;
```

**Expected Output:**
```
Electrician | 671101
Bricklayer  | 641201
Plumber     | 642601
```

---

## TROUBLESHOOTING

### 404 Errors on Endpoints
- Verify `.htaccess` rules in `/assessorReport2/mobile/`
- Check file permissions (755 for directories, 644 for files)
- Verify all PHP files uploaded correctly

### Database Connection Errors
- Test: `mysql -u user -p -h host database_name`
- Verify credentials in `connection.php`
- Ensure online database has same name/structure

### Questions Not Loading
- Run SQL files 9-12 in correct order
- Verify `arpl_questions` table has records: `SELECT COUNT(*) FROM arpl_questions;`
- Check `arpl_papers` table is populated

### Trade/OFO Code Mismatches
- Verify `arpl_trades` table has correct OFO codes
- Check `arpl_poe` table references correct `trade_ofo_code`
- Ensure learners are linked to correct classID (782=Electrician, 783=Bricklayer)

---

## POST-DEPLOYMENT TESTING

### 1. Login and ARPL Access
- Login as Electrician assessor → should see Electrician classes
- Login as Bricklayer assessor → should see Bricklayer classes

### 2. Fill ARPL Form
- Start ARPL assessment
- Save Appendix B activities → verify no 404
- Save Appendix E ratings → verify no 404
- Save Appendix D assessment → verify no 404

### 3. View PDF Report
- Generate ARPL PDF → verify all sections load
- Check Theory Papers section → verify 21 questions display
- Check Practical Scripts section → verify script PDFs load

### 4. Verify Questions Display
- Questions should show: Number, Type, Marks, Difficulty, Full Text
- Script PDFs should display below questions
- No "Questions Not Available" error message

---

## IMPORTANT NOTES

⚠️ **Only 2 Classes with ARPL:**
- classID 782 = Electrician (OFO 671101)
- classID 783 = Bricklayer (OFO 641201)
- Do NOT enable ARPL for other 631 classes

⚠️ **Trade Identification:**
- Learners identified by classID → OFO mapping
- Assessor can see only their facilitator classes

⚠️ **Question Database Linking:**
- Questions in `arpl_questions` table
- Linked to papers via `arpl_papers.paper_id`
- Papers linked to POE via `arpl_poe.paper_title`

⚠️ **All OFO Codes Must Match:**
- arpl_trades table
- arpl_poe records
- arpl_papers records
- Mobile app queries

---

## FILES NOT TO DEPLOY

❌ DO NOT upload:
- `lib/` (Dart files) - compiled into APK only
- `android/` - compiled into APK only
- `backupfolder_old/` - old files
- `.dart` files - frontend only
- Test/debug files (`check_*.php`, `verify_*.php` - optional, use for testing)

✅ DEPLOY ONLY:
- `/mobile/` directory (all 58 .php files)
- SQL setup files (13 files)

---

## DEPLOYMENT SUMMARY

**Total Files to Deploy:**
- 58 PHP endpoints
- 13 SQL setup files
- Database: 26 tables created
- Configuration: 1 connection.php update

**Estimated Deployment Time:**
- Database setup: 5-10 minutes
- File upload: 2-5 minutes
- Verification: 5-10 minutes
- **Total: 15-25 minutes**

---

**Generated:** July 13, 2026  
**Status:** Ready for deployment
