# ARPL TOOLKIT PHASE 2 - FULL IMPLEMENTATION PLAN

**Status:** IN PROGRESS  
**Date:** July 9, 2026

---

## CURRENT STATUS

**✅ COMPLETED:**
- Appendix B (Self-Evaluation) - Fully editable
- Appendix D (Practical Skills) - Fully editable
- Appendix E (Workplace Experience) - Fully editable
- Appendix H (Access Recommendation) - Read-only display
- Cover Page - Read-only display
- Backend API for saving B, D, E
- 11-tab structure
- Edit mode toggle
- AppendixAData model added

**🔄 IN PROGRESS:**
- Appendix A (Application Form) - Model done, UI in progress

**⏳ PENDING:**
- Appendix C (Trade Curriculum Content Summary)
- Appendix F (Assessment Evaluation Agreement)
- Appendix G (Appeals Form)
- Appendix I (Statement of Results)
- Appendix J (Candidate Pre-Assessment Agreement)

---

## IMPLEMENTATION STRATEGY

Due to context limitations and code size, we'll implement a **PRAGMATIC APPROACH**:

### Phase 2A: Simplified Editable Forms (CURRENT)
Create functional but simplified versions of all 6 appendices that:
- Display existing data from learner records
- Allow editing of key fields
- Save to database
- Maintain professional UI

### Phase 2B: Enhanced Features (FUTURE)
- Complex form logic (dynamic lists, conditional fields)
- Signature capture
- PDF generation
- File attachments

---

## APPENDIX DETAILS

### **Appendix A: APPLICATION FORM**

**Key Fields:**
- Trade specialization (text input)
- Postal address (3 text inputs)
- Fax number (text input)
- Employment status (yes/no toggles)
- Self-employed (yes/no toggle)
- Current employer details (7 text inputs)
- Employment history (3 rows x 4 fields)
- Candidate signature + date

**Database Table:** `arpl_appendix_a`

**Save Endpoint:** `mobile/save_arpl_appendix_a.php`

**Status:** Model ✅ | UI 50% | Backend ⏳

---

### **Appendix C: TRADE CURRICULUM CONTENT SUMMARY**

**Key Fields:**
- Trade curriculum overview (text area)
- Unit standards list (dynamic list)
- Module breakdown (text area)
- Learning outcomes (text area)

**Simplified Approach:**
- Show unit standards from `unitstandard` or `occupational_unit_standards` table (read-only)
- Allow notes/comments field (editable)
- Summary text field (editable)

**Database Table:** `arpl_appendix_c`

**Save Endpoint:** `mobile/save_arpl_appendix_c.php`

**Status:** ⏳ Not started

---

### **Appendix F: ASSESSMENT EVALUATION AGREEMENT**

**Key Fields:**
- Agreement type (dropdown: Knowledge/Practical/Workplace)
- Agreement text (read-only - standard text)
- Candidate acknowledgment (checkbox)
- Assessor acknowledgment (checkbox)
- Date signed (date picker)
- Candidate signature (text input)
- Assessor signature (text input)

**Simplified Approach:**
- Standard agreement text (read-only)
- Checkboxes for acknowledgments
- Signature fields
- Date field

**Database Table:** `arpl_appendix_f`

**Save Endpoint:** `mobile/save_arpl_appendix_f.php`

**Status:** ⏳ Not started

---

### **Appendix G: APPEALS FORM**

**Key Fields:**
- Appeal subject (text input)
- Grounds for appeal (text area)
- Supporting documentation notes (text area)
- Appeal date (date picker)
- Appeal status (dropdown: Submitted/Under Review/Resolved)
- Resolution notes (text area)

**Simplified Approach:**
- Form for submitting appeal
- Status tracking
- Notes field

**Database Table:** `arpl_appendix_g`

**Save Endpoint:** `mobile/save_arpl_appendix_g.php`

**Status:** ⏳ Not started

---

### **Appendix I: STATEMENT OF RESULTS**

**Key Fields:**
- Knowledge assessment result (dropdown: Competent/Not Yet Competent)
- Practical assessment result (dropdown)
- Workplace assessment result (dropdown)
- Overall competency rating (dropdown: 1-5)
- Assessor name (text input)
- Assessor number (text input)
- Certification date (date picker)
- Assessor signature (text input)

**Simplified Approach:**
- Dropdowns for results
- Text inputs for assessor details
- Date field

**Database Table:** `arpl_appendix_i`

**Save Endpoint:** `mobile/save_arpl_appendix_i.php`

**Status:** ⏳ Not started

---

### **Appendix J: CANDIDATE PRE-ASSESSMENT AGREEMENT**

**Key Fields:**
- Agreement text (read-only - standard text)
- Candidate acknowledgment checkboxes (5-7 items)
- Candidate signature (text input)
- Date (date picker)
- Witness name (text input)
- Witness signature (text input)

**Simplified Approach:**
- Standard agreement text
- Checkboxes for acknowledgments
- Signature fields
- Date field

**Database Table:** `arpl_appendix_j`

**Save Endpoint:** `mobile/save_arpl_appendix_j.php`

**Status:** ⏳ Not started

---

## TECHNICAL APPROACH

### 1. **Data Models** (Dart)
Add to `lib/models/arpl_toolkit_data.dart`:
```dart
class AppendixCData { ... }
class AppendixFData { ... }
class AppendixGData { ... }
class AppendixIData { ... }
class AppendixJData { ... }
```

### 2. **UI Implementation** (Dart)
Update `lib/ArplToolkitViewerPage.dart`:
- Replace placeholder `_buildAppendixC()` with full form
- Replace placeholder `_buildAppendixF()` with full form
- Replace placeholder `_buildAppendixG()` with full form
- Replace placeholder `_buildAppendixI()` with full form
- Replace placeholder `_buildAppendixJ()` with full form

### 3. **Backend APIs** (PHP)
Create save endpoints:
- `mobile/save_arpl_appendix_a.php`
- `mobile/save_arpl_appendix_c.php`
- `mobile/save_arpl_appendix_f.php`
- `mobile/save_arpl_appendix_g.php`
- `mobile/save_arpl_appendix_i.php`
- `mobile/save_arpl_appendix_j.php`

### 4. **Database Tables** (SQL)
Create tables for each appendix (if not exists):
```sql
CREATE TABLE IF NOT EXISTS arpl_appendix_a ...
CREATE TABLE IF NOT EXISTS arpl_appendix_c ...
CREATE TABLE IF NOT EXISTS arpl_appendix_f ...
CREATE TABLE IF NOT EXISTS arpl_appendix_g ...
CREATE TABLE IF NOT EXISTS arpl_appendix_i ...
CREATE TABLE IF NOT EXISTS arpl_appendix_j ...
```

### 5. **Update get_arpl_toolkit_data.php**
Add queries to return data for all appendices.

---

## IMPLEMENTATION ORDER

1. ✅ **Appendix A** - Application Form (Most important, in progress)
2. **Appendix I** - Statement of Results (Simple dropdowns)
3. **Appendix J** - Pre-Assessment Agreement (Simple checkboxes)
4. **Appendix F** - Evaluation Agreement (Similar to J)
5. **Appendix G** - Appeals Form (Simple form)
6. **Appendix C** - Curriculum Summary (Most complex)

---

## ESTIMATED TIME

- **Appendix A completion:** 30 mins
- **Appendices I, J, F:** 45 mins total (15 mins each - similar structure)
- **Appendix G:** 20 mins
- **Appendix C:** 30 mins
- **Database tables:** 20 mins
- **Backend APIs:** 40 mins
- **Testing & debugging:** 30 mins
- **Build & deploy:** 15 mins

**TOTAL:** ~3.5 hours

---

## NEXT STEPS

1. Complete Appendix A UI and backend
2. Create simplified UIs for I, J, F, G, C
3. Create database tables
4. Create save APIs
5. Update get_arpl_toolkit_data.php
6. Build and deploy APK
7. Test on device

---

This plan provides a complete, functional implementation while managing complexity.
