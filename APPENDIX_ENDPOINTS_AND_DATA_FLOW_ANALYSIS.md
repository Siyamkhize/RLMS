# ARPL Appendix Endpoints & Data Flow Analysis

**Date**: July 11, 2026  
**Objective**: Document data flow from Flutter app save endpoints → Database → PDF rendering for ALL appendices

---

## Overview: Data Flow Architecture

```
Flutter App (ArplToolkitViewerPage.dart)
    ↓
    ↓ POST request with JSON data
    ↓
save_arpl_appendix_X.php (Mobile endpoint)
    ↓
    ↓ INSERT/UPDATE to specific table
    ↓
Database Tables (trade-specific or generic)
    ↓
    ↓ SELECT query from PDF renderer
    ↓
arpl_pdf.php (Web endpoint)
    ↓
    ↓ Renders PDF with retrieved data
    ↓
User views PDF in browser
```

---

## Appendix A: Application Form

### Format
- Text fields + tables
- Personal information, employment history, references

### Data Flow
**Save Endpoint**: `mobile/save_arpl_appendix_a.php`

**Save to Database**: 
- `arpl_applications_v3` - Main application table
- `arpl_v3_applicant_details` - Applicant personal info
- `arpl_v3_employment_history` - Employment details
- `arpl_v3_references` - References list
- `arpl_v3_qualifications` - Educational qualifications

**Trade Awareness**: ❌ NO (generic application form)

**Query in PDF** (lines 130-150):
```php
// Appendix A: Loads learner details, employment, references, qualifications
// Single queries for each section
$st = $conn->prepare("SELECT * FROM arpl_v3_employment_history WHERE learnerID = ? ORDER BY start_date DESC");
$st = $conn->prepare("SELECT * FROM arpl_v3_references WHERE learnerID = ?");
$st = $conn->prepare("SELECT * FROM arpl_v3_qualifications WHERE learnerID = ?");
```

**Rendering** (lines 600-700):
- Displays as tables with prefilled data
- Shows employment history, references, qualifications

**Issue Check**:
- [?] Verify all v3 tables are populated correctly
- [?] Confirm data displays in PDF without errors

---

## Appendix B: Self-Evaluation (Competency Assessment)

### Format
- **5-level rating scale** (✓ ○ ○ ○ ○)
- Circle format with proficiency levels

### Data Flow
**Save Endpoint**: `mobile/save_arpl_appendix_b.php`

**Request Structure**:
```json
{
  "learnerID": 20286,
  "assessor_id": 1,
  "ofo_number": "671101",
  "ratings": [
    {
      "activity_id": 1,
      "activity_name": "Activity name",
      "rating": 4,
      "comments": "Assessment feedback"
    }
  ]
}
```

**Save to Database**: Trade-specific ratings tables
- Electrician (671101): `arplappxe_electrician_activity_ratings`
- Bricklaying (641201): `arplappxe_bricklaying_activity_ratings`
- Plumbing (642601): `arplappxb_activity_ratings`

**Trade Awareness**: ✅ YES (uses OFO code to select correct table)

**Query in PDF** (lines 231-249):
```php
// Trade-specific table selection
$tradeActivityTables = [
    '671101' => 'arplappxb_electrician_activities',
    '641201' => 'arplappxb_bricklaying_activities',
    '642601' => 'arplappxb_plumbing_activities',
];

$tradeRatingsTables = [
    '671101' => 'arplappxe_electrician_activity_ratings',
    '641201' => 'arplappxe_bricklaying_activity_ratings',
    '642601' => 'arplappxb_activity_ratings',
];

// LEFT JOIN to get ratings with activities
$appendixBSQL = "SELECT 
    act.activity_id, act.activity_number, act.activity_name,
    COALESCE(rat.competency_scale_id, NULL) as rating,
    COALESCE(rat.comments, '') as assessor_comments,
    COALESCE(rat.rating_date, NULL) as rating_date
FROM $activityTable act
LEFT JOIN $ratingsTable rat ON (...)
ORDER BY act.activity_number ASC";
```

**Rendering** (lines 645-770):
- Card format with circles
- Proficiency level mapping
- Color-coded status badges
- Assessor comments display
- Progress summary

**Status**: ✅ WORKING CORRECTLY (Verified with learner 20286)

---

## Appendix C: Trade Curriculum Content Summary

### Format
- Text/dropdown fields
- Curriculum overview, module summary, learning outcomes, notes

### Data Flow
**Save Endpoint**: `mobile/save_arpl_appendix_c.php`

**Request Structure**:
```json
{
  "learnerID": 20286,
  "ofoNumber": "671101",
  "curriculum_overview": "...",
  "module_summary": "...",
  "learning_outcomes": "...",
  "additional_notes": "..."
}
```

**Save to Database**: 
- `arpl_appendix_c` - Single table (generic)

**Trade Awareness**: ✅ YES (saves ofo_number field)

**Fields Saved**:
- learnerID
- ofo_number
- curriculum_overview
- module_summary
- learning_outcomes
- additional_notes
- created_at / updated_at

**Query in PDF** (line 251):
```php
$appendixC = null;
$st = $conn->query("SELECT * FROM arpl_appendix_c WHERE learner_id = $learnerID LIMIT 1");
// ⚠️ ISSUE: Using direct query, not parameterized (SQL injection risk)
// ⚠️ ISSUE: Column name is "learner_id" - need to verify this matches the table
```

**Rendering** (lines 883-915):
- Displays text content from database
- Shows curriculum overview, modules, outcomes, notes

**Issues Found**:
- ❌ Query uses `$learnerID` directly in string (SQL injection risk)
- ❌ Column name mismatch: saves as `learnerID` but query looks for `learner_id`
- ⚠️ No trade-specific filtering (might show wrong trade data if multiple trades for same learner)

---

## Appendix D: Practical Skills Assessment Evaluation Checklist

### Format
- Yes/No/Pending responses
- 22-item checklist

### Data Flow
**Save Endpoint**: `mobile/save_arpl_appendix_d.php`

**Request Structure**:
```json
{
  "learnerID": 11515,
  "assessor_id": 1,
  "ofo_number": "671101",
  "activities": {
    "1": "yes",
    "2": "no",
    "22": "yes"
  }
}
```

**Save to Database**:
- `arpl_appendix_d` - Single table (generic)

**Trade Awareness**: ✅ YES (saves ofo_number field)

**Fields Saved**:
- learnerID
- assessor_id
- ofo_number
- activity_responses (JSON or individual fields)
- created_at / updated_at

**Query in PDF** (line 260):
```php
$appendixDPapers = [];
$st = $conn->query("SELECT * FROM arpl_appendix_d WHERE learner_id = $learnerID ORDER BY paper_date DESC");
// ⚠️ ISSUE: Same as Appendix C
// ⚠️ ISSUE: Column name mismatch
// ⚠️ ISSUE: No trade filtering
```

**Rendering** (lines 919-946):
- Displays as table/checklist
- Shows yes/no responses for each item

**Issues Found**:
- ❌ Same SQL injection risk as Appendix C
- ❌ Same column name mismatch (`learnerID` vs `learner_id`)
- ⚠️ No trade-specific filtering

---

## Appendix E: Practical Skills Assessment (Ratings)

### Format
- **5-level rating scale** (✓ ○ ○ ○ ○)
- Circle format with proficiency levels

### Data Flow
**Save Endpoint**: `mobile/save_arpl_appendix_e.php`

**Request Structure**: Same as Appendix B (same table structure)

**Save to Database**: Same trade-specific ratings tables as Appendix B
- Electrician (671101): `arplappxe_electrician_activity_ratings`
- Bricklaying (641201): `arplappxe_bricklaying_activity_ratings`
- Plumbing (642601): `arplappxb_activity_ratings`

**Trade Awareness**: ✅ YES (uses OFO code to select correct table)

**Query in PDF** (lines 268-304):
```php
// Identical to Appendix B (trade-aware, parameterized)
// Loads activities with ratings via LEFT JOIN
```

**Rendering** (lines 948-1050):
- Identical to Appendix B (circle format)
- Card layout with proficiency levels
- Status badges and progress summary

**Status**: ✅ WORKING CORRECTLY (Verified with learner 20286)

---

## Appendix F: Assessment Evaluation Agreement

### Format
- Knowledge/Practical/Workplace scores
- Comments text field

### Data Flow
**Save Endpoint**: `mobile/save_arpl_appendix_f.php` + `mobile/save_arpl_appendix_f_assessment.php`

**Request Structure**:
```json
{
  "learnerID": 20286,
  "ofo_number": "671101",
  "knowledge_score": 75,
  "practical_score": 80,
  "workplace_score": 70,
  "comments": "..."
}
```

**Save to Database**:
- `arpl_appendix_f` - Main assessment table
- `arpl_appendix_f_assessment` - Detailed scores (if separate)

**Trade Awareness**: ✅ YES (saves ofo_number)

**Query in PDF**: (TBD - need to check if this section exists in PDF)

**Status**: ⚠️ NEEDS VERIFICATION (not visible in sample output)

---

## Appendix G: Assessment Evaluation Agreement

### Format
- Text/dropdown fields
- Moderator information, decision, rationale

### Data Flow
**Save Endpoint**: `mobile/save_arpl_appendix_g.php`

**Save to Database**:
- `arpl_appendix_g` - Single table

**Trade Awareness**: Check endpoint

**Query in PDF** (line 317):
```php
$appendixG = null;
$st = $conn->query("SELECT * FROM arpl_appendix_g WHERE learner_id = $learnerID LIMIT 1");
// ⚠️ Same issues as C & D (SQL injection, column name mismatch, no trade filtering)
```

**Issues Found**:
- ❌ SQL injection risk
- ❌ Column name mismatch
- ⚠️ No trade filtering

---

## Appendix H: Appeals Form

### Format
- Text fields + dropdowns
- Appeal reason, moderator info, decision

### Data Flow
**Save Endpoint**: `mobile/save_arpl_appendix_i.php` (likely, need to check if separate)

**Save to Database**: (TBD - check schema)

**Query in PDF**: (Check if implemented)

**Status**: ⚠️ NEEDS VERIFICATION

---

## Appendix I: Access Recommendation

### Format
- Ready/Not Ready status with rationale

### Data Flow
**Save Endpoint**: `mobile/save_arpl_appendix_i.php`

**Save to Database**:
- `arpl_appendix_i` - Recommendation table

**Query in PDF** (line 324):
```php
$appendixI = null;
$st = $conn->query("SELECT * FROM arpl_appendix_i WHERE learner_id = $learnerID LIMIT 1");
// ⚠️ Same issues as C & D & G
```

**Issues Found**:
- ❌ SQL injection risk
- ❌ Column name mismatch
- ⚠️ Possibly no trade filtering

---

## Appendix J: Pre-Assessment Agreement

### Format
- Checkboxes (acknowledgments)
- Yes/No confirmations

### Data Flow
**Save Endpoint**: `mobile/save_arpl_appendix_j.php`

**Save to Database**:
- `arpl_appendix_j` - Agreement table

**Query in PDF**: (Check if implemented)

**Status**: ⚠️ NEEDS VERIFICATION

---

## Appendix K: Statement of Results

### Format
- Final scores, pass/fail status, results

### Data Flow
**Save Endpoint**: (TBD - might be auto-generated from other sections)

**Save to Database**: (TBD)

**Query in PDF**: (Check if implemented)

**Status**: ⚠️ NEEDS VERIFICATION

---

## CRITICAL ISSUES SUMMARY

### 🔴 HIGH PRIORITY

#### Issue #1: SQL Injection Vulnerabilities in Multiple Appendices
**Files Affected**: `arpl_pdf.php` lines 251, 260, 317, 324
**Appendices**: C, D, G, I
**Problem**: Direct variable substitution in queries instead of parameterized statements
**Example**:
```php
// ❌ WRONG
$st = $conn->query("SELECT * FROM arpl_appendix_c WHERE learner_id = $learnerID LIMIT 1");

// ✅ CORRECT
$st = $conn->prepare("SELECT * FROM arpl_appendix_c WHERE learnerID = ?");
$st->bind_param("i", $learnerID);
$st->execute();
```

#### Issue #2: Column Name Mismatches
**Affected Appendices**: C, D, G, I
**Problem**: Endpoints save to `learnerID` column, but PDF queries look for `learner_id` column
**Result**: Data not found, empty sections in PDF

#### Issue #3: Missing Trade-Specific Filtering
**Affected Appendices**: C, D, F, G, H, I, J, K (potentially)
**Problem**: Queries don't include `ofo_number` filter
**Result**: If a learner has multiple trades, wrong trade data might display

### 🟡 MEDIUM PRIORITY

#### Issue #4: Missing Appendix Implementations
**Appendices**: F, H, K (possibly)
**Problem**: Save endpoints exist but PDF queries/rendering not found
**Action**: Verify if these are implemented or not

#### Issue #5: Inconsistent Table Naming
**Pattern**: Most use `arpl_appendix_X`, but activity ratings use trade-specific naming
**Action**: Document why and ensure queries handle correctly

---

## Recommendations

### Immediate Actions (Today)

1. **Fix SQL Injection Issues**
   - Convert lines 251, 260, 317, 324 in `arpl_pdf.php` to parameterized queries
   - Example:
   ```php
   $st = $conn->prepare("SELECT * FROM arpl_appendix_c WHERE learnerID = ? AND ofo_number = ?");
   $st->bind_param("is", $learnerID, $ofo_code);
   $st->execute();
   ```

2. **Verify Column Names**
   - Check actual schema for each table (learnerID vs learner_id)
   - Update queries to match actual column names

3. **Add Trade Filtering**
   - Include `ofo_number` in WHERE clause for all appendices where applicable
   - Ensures multi-trade learners show correct data

4. **Verify All Appendices Load**
   - Test PDF with complete learner data
   - Ensure all 12 sections display without errors

### Future Enhancements

1. Create utility function for parameterized queries
2. Document trade-specific vs generic tables
3. Add data validation before PDF generation
4. Implement error logging for debugging

---

## Trade-Specific Table Reference

### Tables That Are Trade-Specific (Different Names)

#### Activity & Rating Tables
```
Electrician (671101):
├── arplappxb_electrician_activities
├── arplappxe_electrician_activity_ratings

Bricklaying (641201):
├── arplappxb_bricklaying_activities
├── arplappxe_bricklaying_activity_ratings

Plumbing (642601):
├── arplappxb_plumbing_activities
├── arplappxb_activity_ratings (NOTE: Different pattern!)
```

### Tables That Are Generic (Same Name for All Trades)

```
Generic Tables (all trades):
├── arpl_appendix_c (curriculum)
├── arpl_appendix_d (practical skills checklist)
├── arpl_appendix_f (assessment evaluation)
├── arpl_appendix_g (assessment agreement)
├── arpl_appendix_i (access recommendation)
├── arpl_appendix_j (pre-assessment agreement)
├── arpl_applications_v3 (main application)
├── arpl_v3_employment_history
├── arpl_v3_references
├── arpl_v3_qualifications
```

---

## Data Verification Checklist

### Before Production Deployment

- [ ] All parameterized queries implemented
- [ ] Column names verified against actual schema
- [ ] Trade filtering added to all applicable appendices
- [ ] All 12 appendices display without errors
- [ ] Tested with multiple learners (rated and unrated)
- [ ] Tested with all 3 trades
- [ ] Error logging implemented
- [ ] SQL injection vulnerabilities eliminated
- [ ] Performance acceptable (< 2 seconds PDF generation)

---

## Test Learners

| Learner ID | Trade | Class | Status | Rating Count |
|-----------|-------|-------|--------|--------------|
| 20286 | Electrician (671101) | 782 | Rated | 14/23 |
| 16389 | Electrician (671101) | 782 | Unrated | 0/23 |

---

## Summary of Findings

✅ **Appendix B**: Fully implemented with circles, trade-aware queries, parameterized SQL  
✅ **Appendix E**: Fully implemented with circles, trade-aware queries, parameterized SQL  
⚠️ **Appendix A**: Implemented but needs verification of all linked tables  
⚠️ **Appendix C**: Implemented but has SQL injection risk, column name mismatch, no trade filter  
⚠️ **Appendix D**: Implemented but has SQL injection risk, column name mismatch, no trade filter  
⚠️ **Appendix F**: Partially implemented, needs verification  
⚠️ **Appendix G**: Implemented but has SQL injection risk, column name mismatch, no trade filter  
⚠️ **Appendix H**: Status unclear, needs verification  
⚠️ **Appendix I**: Implemented but has SQL injection risk, column name mismatch, no trade filter  
⚠️ **Appendix J**: Status unclear, needs verification  
⚠️ **Appendix K**: Status unclear, needs verification  

---

**Analysis Date**: July 11, 2026  
**Status**: READY FOR REMEDIATION  
**Next Step**: Fix SQL injection issues and column name mismatches

