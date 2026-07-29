# ARPL Appendix Format Analysis

**Purpose**: Determine which appendices have rating scales vs other formats for PDF generation

---

## Appendix Formats Summary

### ✅ **Appendix A: Application Form**
- **Format**: Text fields (Name, ID, Address, Employment History, etc.)
- **Data Type**: Personal information, employment history, references, qualifications
- **Flutter UI**: Text inputs, date pickers, tables
- **PDF Format**: Table-based with prefilled information
- **Needs Circle Format**: ❌ NO (not a rating scale)

### ✅ **Appendix B: Self-Evaluation (Competency Assessment)**
- **Format**: ⭐ **5-LEVEL RATING SCALE** (1-5)
- **Data Type**: Assessor ratings for trade activities
- **Flutter UI**: ✓ ✓ ✓ ✓ ○ Circle indicators
- **PDF Format**: ✅ **APPLY CIRCLE FORMAT** (DONE)
- **Needs Circle Format**: ✅ YES - IMPLEMENTED

### ✅ **Appendix C: Trade Curriculum Content Summary**
- **Format**: Text/Dropdown (Unit Standards, curriculum content)
- **Data Type**: Qualification requirements, unit standards
- **Flutter UI**: Text input, checkboxes
- **PDF Format**: Table/card with unit standards
- **Needs Circle Format**: ❌ NO (not a rating scale)

### ✅ **Appendix D: Practical Skills Assessment Evaluation**
- **Format**: ⭐ **YES/NO/PENDING** (checkbox style)
- **Data Type**: Yes/No responses for 22+ practical criteria
- **Flutter UI**: Radio buttons (Yes/No/Pending), not circles
- **PDF Format**: Table with Yes/No indicators
- **Needs Circle Format**: ❌ NO (already has Yes/No format, don't change)

### ✅ **Appendix E: Practical Skills Assessment**
- **Format**: ⭐ **5-LEVEL RATING SCALE** (1-5)
- **Data Type**: Assessor ratings for practical activities
- **Flutter UI**: ✓ ✓ ✓ ✓ ○ Circle indicators
- **PDF Format**: ✅ **APPLY CIRCLE FORMAT** (should match Appendix B)
- **Needs Circle Format**: ✅ YES - NEEDS IMPLEMENTATION

### ✅ **Appendix F: Assessment Evaluation Agreement**
- **Format**: Knowledge/Practical/Workplace scores + comments
- **Data Type**: Assessment scores (percentage), text feedback
- **Flutter UI**: Text inputs, score fields
- **PDF Format**: Table with scores and text
- **Needs Circle Format**: ❌ NO (not 5-level scale, uses percentages)

### ✅ **Appendix G: Appeals Form**
- **Format**: Text/Dropdown (Appeal reason, moderator info)
- **Data Type**: Appeal details, text responses
- **Flutter UI**: Text inputs, dropdowns
- **PDF Format**: Form fields
- **Needs Circle Format**: ❌ NO (text-based form)

### ✅ **Appendix H: Access Recommendation**
- **Format**: ⭐ **READY/NOT READY** (decision buttons)
- **Data Type**: Recommendation status with rationale
- **Flutter UI**: Status buttons, text comments
- **PDF Format**: Status display + text
- **Needs Circle Format**: ❌ NO (binary ready/not ready, not 5-level)

### ✅ **Appendix I: Statement of Results**
- **Format**: Knowledge/Practical/Workplace results + percentages
- **Data Type**: Final scores, pass/fail status
- **Flutter UI**: Text display, status indicators
- **PDF Format**: Results summary with percentages
- **Needs Circle Format**: ❌ NO (percentage-based, not 1-5 scale)

### ✅ **Appendix J: Pre-Assessment Agreement**
- **Format**: ⭐ **CHECKBOXES** (Acknowledgments, Yes/No)
- **Data Type**: Candidate acknowledgments (checkbox list)
- **Flutter UI**: Checkboxes, text
- **PDF Format**: Checkbox summary
- **Needs Circle Format**: ❌ NO (checkbox-based, not ratings)

---

## Summary: Circle Format Application

### APPLY Circle Format (✓ ○ Scale)
1. **Appendix B** ✅ - DONE (Self-Evaluation)
2. **Appendix E** ⏳ - TODO (Practical Skills Assessment)

### DO NOT Change Format
3. **Appendix A** - Keep table format (personal info)
4. **Appendix C** - Keep text/unit standards format
5. **Appendix D** - Keep Yes/No format (different UI than 5-level)
6. **Appendix F** - Keep percentage scores
7. **Appendix G** - Keep text form format
8. **Appendix H** - Keep ready/not ready status
9. **Appendix I** - Keep results/percentage format
10. **Appendix J** - Keep checkbox format

---

## Trade-Specific Data Requirements

### Electrician (OFO 671101)
- **Activities Table**: `arplappxb_electrician_activities`
- **Ratings Table (Appendix B)**: `arplappxe_electrician_activity_ratings`
- **Ratings Table (Appendix E)**: `arplappxe_electrician_activity_ratings` (same)
- **Number of Activities**: 23
- **Criteria Format**: Practical skills (tools, safety, measurements, etc.)

### Bricklaying (OFO 641201)
- **Activities Table**: `arplappxb_bricklaying_activities`
- **Ratings Table (Appendix B)**: `arplappxe_bricklaying_activity_ratings`
- **Ratings Table (Appendix E)**: `arplappxe_bricklaying_activity_ratings`
- **Number of Activities**: TBD (varies by trade)
- **Criteria Format**: Bricklaying-specific skills

### Plumbing (OFO 642601)
- **Activities Table**: `arplappxb_plumbing_activities`
- **Ratings Table (Appendix B)**: `arplappxb_activity_ratings`
- **Ratings Table (Appendix E)**: `arplappxb_activity_ratings`
- **Number of Activities**: 23
- **Criteria Format**: Plumbing-specific skills

---

## Data Saving Endpoints

### Appendix B (Ratings - Circle Format)
- **Endpoint**: `POST mobile/save_arpl_appendix_b.php`
- **Saves To**: Trade-specific ratings table (e.g., `arplappxe_electrician_activity_ratings`)
- **Data Fields**: activity_id, competency_scale_id (1-5), comments, rating_date
- **Trade-Aware**: ✅ YES (uses OFO code to select table)

### Appendix E (Ratings - Should Be Circle Format)
- **Endpoint**: `POST mobile/save_arpl_appendix_e.php`
- **Saves To**: Same ratings table as Appendix B (trade-specific)
- **Data Fields**: activity_id, competency_scale_id (1-5), comments
- **Trade-Aware**: ✅ YES (uses OFO code to select table)

### Appendix D (Yes/No)
- **Endpoint**: `POST mobile/save_arpl_appendix_d.php`
- **Saves To**: arpl_appendix_d table
- **Data Fields**: activity_id, response (yes/no/pending)
- **Trade-Aware**: ⚠️ CHECK (may need trade-specific routing)

### Appendix A (Personal Info)
- **Endpoint**: `POST mobile/save_arpl_appendix_a.php`
- **Saves To**: arpl_applications_v3 + related tables
- **Data Fields**: id_number, first_name, last_name, employment history
- **Trade-Aware**: ❌ NO (general application form)

---

## PDF Generation Approach

### Current Implementation (Appendix B)
```php
// Trade-aware query pattern
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

// Use OFO code to select correct tables
$appendixBTable = $tradeActivityTables[$ofo_code];
$ratingsTable = $tradeRatingsTables[$ofo_code];
```

### Key Points for All Appendices
1. **ALWAYS use `$ofo_code`** parameter to select correct trade-specific tables
2. **NEVER hardcode table names** - use mapping arrays
3. **Check which tables exist** for each trade
4. **Verify data availability** - some trades may not have all appendices populated

---

## Next Steps

### PRIORITY 1: Appendix E
- Apply same circle format as Appendix B
- Verify it pulls from same ratings tables
- Check if data structure matches (should be identical)

### PRIORITY 2: Verify Remaining Appendices
- Confirm each appendix loads correct data in PDF
- Ensure trade-specific tables are used
- Test with all three trades (Electrician, Bricklaying, Plumbing)

### PRIORITY 3: Data Endpoint Review
- Review each save_arpl_appendix_X.php file
- Verify trade-aware routing
- Check for any mismatches between Flutter save and PDF display

---

## Implementation Checklist

### Appendix B ✅
- [x] Circle format implemented
- [x] Trade-specific tables used
- [x] Query returns correct ratings
- [x] Verified with learner data

### Appendix E ⏳
- [ ] Apply circle format (matching B)
- [ ] Verify ratings table (should be same as B)
- [ ] Test with all trades
- [ ] Confirm data displays correctly

### Appendix D (No changes needed, but verify)
- [ ] Verify Yes/No format displays correctly
- [ ] Check trade-specific data loading
- [ ] Test with learner data

### Other Appendices (Verify only)
- [ ] A, C, F, G, H, I, J - verify they load and display correctly

---

## Database Schema Quick Reference

### Electrician (671101)
```
arplappxb_electrician_activities
├── activity_id (PK)
├── activity_number
├── activity_name
└── ofo_number

arplappxe_electrician_activity_ratings
├── rating_id (PK)
├── activity_id (FK)
├── learnerID
├── competency_scale_id (1-5)
├── comments
├── rating_date
└── ofo_number
```

### Bricklaying (641201)
```
arplappxb_bricklaying_activities
├── activity_id
├── activity_number
├── activity_name
└── ofo_number

arplappxe_bricklaying_activity_ratings
├── rating_id
├── activity_id (FK)
├── learnerID
├── competency_scale_id (1-5)
├── comments
├── rating_date
└── ofo_number
```

### Plumbing (642601)
```
arplappxb_plumbing_activities
├── activity_id
├── activity_number
├── activity_name
└── ofo_number

arplappxb_activity_ratings (NOTE: Different table name!)
├── rating_id
├── activity_id (FK)
├── learnerID
├── competency_scale_id (1-5)
├── comments
├── rating_date
└── ofo_number
```

---

**Analysis Date**: July 11, 2026  
**Status**: Ready for implementation
