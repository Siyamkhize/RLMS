# ARPL PDF Final Appendix Structure

**Updated**: July 12, 2026

## Complete Appendix List (After Gap Closure Integration)

| Page | Appendix | Title | Source |
|------|----------|-------|--------|
| 1 | - | Cover Page | Static HTML |
| 2 | - | Table of Contents | Dynamic list |
| 3 | A | Application Form & Supporting Documents | `learnerdetails`, `learner_documents` |
| 4 | B | Competency Proficiency Scale & Trade Activities | `arplappxb_*_activities` |
| 5 | C | Trade Curriculum Content Summary | Static HTML (trade-specific) |
| **6** | **D** | **Gap Closure Report** | **`gap_analysis_submissions`** ⭐ NEW |
| 7 | E | Practical Skills Assessment Evaluation Checklist | `arpl_appendix_d` |
| 8 | F | Practical Skills Assessment | `arplappxe_*_activity_ratings` |
| 9 | G | Assessment Evaluation Agreement | `arpl_appendix_g` |
| 10 | H | Assessment Evaluation Agreement (DHET) | Static HTML form |
| 11 | I | Appeals Form | Static HTML form |
| 12 | J | POE Checklist (Auto-inserted after TOC) | `arpl_poe_checklist` |
| 13 | K | Access Recommendation | `arpl_appendix_i` |
| 14 | L | Statement of Results | `arpl_appendix_k` |
| 15 | M | Candidate Pre-Assessment Agreement | `arpl_appendix_j` |
| 16 | N | Pre-Assessment Checklist | Static HTML form |
| 17+ | - | Theory Assessment Papers (if available) | `arpl_poe` |
| - | - | Theory Assessment Register | Theory attendance |
| - | - | Practical Assessment Scripts (if available) | `arpl_poe` |
| - | - | Practical Attendance Register | Practical attendance |
| - | - | Workplace Experience Register | Workplace attendance |

---

## Key Features of Gap Closure Report (Appendix D)

### Auto-Population
- Learner Name: From `learnerdetails` table
- ID Number: From learner record
- Trade: From class → trade mapping
- Assessment Date: From Gap Analysis submission
- Assessor Information: From submission record

### Task Assessment Display
- **Task Number**: From `gap_analysis_report.TaskNo`
- **Task Name**: From `gap_analysis_report.TaskName`
- **Assessment Method**: Interview | Practical | Written | Observation
- **Rating**: Bad (red) | Fair (orange) | Good (green)

### Signature Block
- Assessor Signature & Date
- Candidate Signature & Date
- Footer with document reference and version info

---

## Database Tables Used

### Core Tables
```
learnerdetails → (LearnerID, FirstName, LastName, IDNumber, ClassID)
  ↓
classes → (ClassID, TradeID)
  ↓
trades → (TradeID, TradeName)
```

### Gap Analysis Tables
```
gap_analysis_submissions
  ├─ id (PK)
  ├─ learner_id (FK)
  ├─ trade_id (FK)
  ├─ assessor_name
  ├─ assessor_no
  ├─ comments
  ├─ assess_date
  └─ created_at

gap_analysis_submission_items
  ├─ id (PK)
  ├─ submission_id (FK)
  ├─ task_id (FK)
  └─ rating (Bad|Fair|Good)

gap_analysis_report
  ├─ TaskID (PK)
  ├─ TaskNo (display order)
  ├─ TaskName
  ├─ AssessmentMethod
  └─ TradeID (FK)
```

---

## PDF Generation Flow

```
1. Get learnerID, classID, ofo_code from URL parameters
2. Load learner details
3. Load Gap Analysis submission data (NEW)
   └─ If found: Load task ratings
   └─ If not found: Show info message
4. Load other appendix data (B, E, F, G, I, J, K, etc.)
5. Render PDF pages in order:
   - Cover & TOC
   - Appendix A-N (including NEW Appendix D)
   - Assessment papers (Theory, Practical)
   - Attendance registers
```

---

## Deployment Status

| Location | File Size | Status | Last Updated |
|----------|-----------|--------|--------------|
| Dev | `c:\projects\rlmss\web\arpl_pdf.php` | ✅ 194.5 KB | 2026-07-12 10:13 |
| Prod | `C:\xampp\htdocs\web\web\web\arpl_pdf.php` | ✅ 194.5 KB | 2026-07-12 10:13 |

---

## How to Test

### 1. With Gap Analysis Data
```
URL: http://localhost:8080/web/arpl_pdf.php?learnerID=123&classID=456
Expected: PDF displays Gap Closure Report in Appendix D with task ratings
```

### 2. Without Gap Analysis Data
```
URL: http://localhost:8080/web/arpl_pdf.php?learnerID=999&classID=888
Expected: PDF displays info message "No Gap Closure Report data is currently available"
```

### 3. Appendix Verification
- Verify Table of Contents lists all appendices correctly
- Verify Gap Closure Report is on page 6
- Verify assessment papers start after Appendix N

---

## Integration Notes

- ✅ Gap Analysis data loads dynamically (no pre-rendering needed)
- ✅ Handles missing data gracefully with fallback messages
- ✅ All XSS vulnerabilities protected with htmlspecialchars()
- ✅ Appendix numbering consistent throughout (D-N)
- ✅ Backward compatible with existing apprentices without Gap Analysis

---

**Architecture**: Trade-aware multi-appendix PDF generator  
**Language**: PHP with HTML/CSS for PDF rendering  
**Format**: DompDF compatible  
**Last Modified**: July 12, 2026
