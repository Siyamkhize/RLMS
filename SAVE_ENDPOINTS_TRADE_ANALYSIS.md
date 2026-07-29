# ARPL Save Endpoints - Trade Support Analysis

## SUMMARY

✅ **4 out of 5 endpoints are TRADE-AGNOSTIC** (work for all trades)  
❌ **1 endpoint is TRADE-SPECIFIC** (hardcoded for Electrician only)

---

## ENDPOINT-BY-ENDPOINT ANALYSIS

### 1. save_arpl_appendix_b.php ✅ TRADE-AGNOSTIC

**Purpose**: Save assessor competency ratings (1-5 scale) for activities

**Table Used**: `arplappxb_activity_ratings` (UNIFIED table)

**Trade Support**: ✅ **ALL TRADES**

**How it works**:
- Accepts `ofo_number` as parameter
- Stores OFO in the record
- Uses ONE unified table for all trades
- Table has `ofo_number` column to distinguish trades

**Request**:
```json
{
  "learnerID": 11701,
  "assessor_id": 6,
  "ofo_number": "641201",  ← Bricklayer
  "ratings": [...]
}
```

**Table Schema**:
```sql
arplappxb_activity_ratings (
  learnerID,
  ofo_number,      ← Stores trade identifier
  activity_id,
  competency_scale_id (1-5 rating),
  assessor_id,
  comments
)
UNIQUE KEY (learnerID, ofo_number, activity_id, assessor_id)
```

**Verdict**: ✅ Fully trade-agnostic

---

### 2. save_arpl_appendix_d.php ✅ TRADE-AGNOSTIC

**Purpose**: Save Yes/No responses for 22 practical skills assessment activities

**Table Used**: `arpl_appendix_d` (UNIFIED table)

**Trade Support**: ✅ **ALL TRADES**

**How it works**:
- Accepts `ofo_number` as parameter
- Stores OFO in the record
- Uses ONE unified table for all trades
- Has 22 activity columns (activity_1, activity_2, ... activity_22)

**Request**:
```json
{
  "learnerID": 11701,
  "assessor_id": 6,
  "ofo_number": "641201",  ← Bricklayer
  "activities": {
    "1": "yes",
    "2": "no",
    ...
  }
}
```

**Table Schema**:
```sql
arpl_appendix_d (
  id,
  learnerID,
  assessor_id,
  ofo_number,      ← Stores trade identifier
  activity_1,      ← "yes", "no", "pending"
  activity_2,
  ...
  activity_22,
  updated_at
)
UNIQUE KEY (learnerID, assessor_id, ofo_number)
```

**Verdict**: ✅ Fully trade-agnostic

---

### 3. save_arpl_appendix_e.php ❌ TRADE-SPECIFIC (ELECTRICIAN ONLY)

**Purpose**: Save activity ratings for Appendix E (interview/observation)

**Table Used**: `arplappxe_electrician_activity_ratings` (TRADE-SPECIFIC table)

**Trade Support**: ❌ **ELECTRICIAN ONLY**

**Problem**: **HARDCODED TABLE NAME**

**How it currently works**:
- Accepts `ofo_number` as parameter
- BUT always saves to `arplappxe_electrician_activity_ratings` table
- Won't work for Bricklayer (641201) or Plumber (671201)

**Code Issue** (Line 55-57):
```php
$stmt = $conn->prepare("
    INSERT INTO arplappxe_electrician_activity_ratings (  ← HARDCODED!
        learnerID,
```

**What it SHOULD do**:
- Dynamically select table based on OFO:
  - 641201 → `arplappxe_bricklaying_activity_ratings`
  - 671101 → `arplappxe_electrician_activity_ratings`
  - 671201 → `arplappxe_plumber_activity_ratings`

**Fix Required**: ⚠️ Make it trade-agnostic like the others

**Verdict**: ❌ Only works for Electrician - NEEDS FIX

---

### 4. save_arpl_appendix_f.php ✅ TRADE-AGNOSTIC

**Purpose**: Save Assessment Evaluation Agreement (acknowledgments & signatures)

**Table Used**: `arpl_appendix_f` (UNIFIED table)

**Trade Support**: ✅ **ALL TRADES**

**How it works**:
- Accepts `ofoNumber` as parameter
- Stores OFO in the record
- Uses ONE unified table for all trades

**Request**:
```json
{
  "learnerID": 11701,
  "ofoNumber": "641201",  ← Bricklayer
  "knowledge_acknowledged": true,
  "practical_acknowledged": true,
  ...
}
```

**Table Schema**:
```sql
arpl_appendix_f (
  id,
  learnerID,
  ofo_number,      ← Stores trade identifier
  knowledge_acknowledged,
  practical_acknowledged,
  workplace_acknowledged,
  assessor_acknowledged,
  candidate_signature,
  assessor_signature,
  agreement_date
)
UNIQUE KEY (learnerID, ofo_number)
```

**Verdict**: ✅ Fully trade-agnostic

---

### 5. save_arpl_criteria.php ✅ TRADE-AGNOSTIC

**Purpose**: Save evaluation criteria (Section 5) with recommendation

**Table Used**: `arpl_evaluation_criteria` (UNIFIED table)

**Trade Support**: ✅ **ALL TRADES**

**How it works**:
- Uses learner_id, class_id, project_id for identification
- Trade is inferred from class/project relationship
- Stores criteria as JSON

**Request**:
```json
{
  "learner_id": 11701,
  "assessor_id": 6,
  "class_id": 797,
  "project_id": 1,
  "site_id": 1,
  "criteria_json": "{...}",
  "is_recommended": 1
}
```

**Table Schema**:
```sql
arpl_evaluation_criteria (
  learner_id,
  assessor_id,
  class_id,        ← Trade inferred from class
  project_id,
  site_id,
  criteria_json,   ← Stores all criteria
  is_recommended,
  assessor_confirmation
)
UNIQUE KEY (learner_id)
```

**Verdict**: ✅ Trade-agnostic (uses class relationship)

---

## SUMMARY TABLE

| Endpoint | Table | Trade Support | Status |
|----------|-------|---------------|--------|
| save_arpl_appendix_b.php | arplappxb_activity_ratings | ✅ All Trades | OK |
| save_arpl_appendix_d.php | arpl_appendix_d | ✅ All Trades | OK |
| save_arpl_appendix_e.php | arplappxe_electrician_activity_ratings | ❌ Electrician Only | NEEDS FIX |
| save_arpl_appendix_f.php | arpl_appendix_f | ✅ All Trades | OK |
| save_arpl_criteria.php | arpl_evaluation_criteria | ✅ All Trades | OK |

---

## DATABASE ARCHITECTURE

### Unified Tables (Trade-Agnostic)

These tables support ALL trades using an `ofo_number` column:

```
✅ arplappxb_activity_ratings
   - Has ofo_number column
   - One table for all trades
   - OFO distinguishes Bricklayer/Electrician/Plumber

✅ arpl_appendix_d
   - Has ofo_number column
   - One table for all trades

✅ arpl_appendix_f
   - Has ofo_number column
   - One table for all trades

✅ arpl_evaluation_criteria
   - Uses class_id relationship
   - One table for all trades
```

### Separate Tables (Trade-Specific)

These tables are SEPARATE per trade:

```
❌ arplappxe_electrician_activity_ratings  ← Electrician
❌ arplappxe_bricklaying_activity_ratings  ← Bricklayer (if exists)
❌ arplappxe_plumber_activity_ratings      ← Plumber (if exists)
```

**Why separate tables?**
- Different activities per trade for Appendix E
- Each trade has unique competency requirements
- Can't use unified table with OFO column

---

## THE PROBLEM WITH APPENDIX E

**Current Code** (save_arpl_appendix_e.php line 55):
```php
$stmt = $conn->prepare("
    INSERT INTO arplappxe_electrician_activity_ratings (  ← HARDCODED!
```

**What happens**:
- Bricklayer (641201) → Saves to Electrician table ❌ WRONG
- Electrician (671101) → Saves to Electrician table ✅ CORRECT
- Plumber (671201) → Saves to Electrician table ❌ WRONG

**Impact**:
- Bricklayer and Plumber assessments are saved to wrong table
- Data gets mixed up
- Reports show wrong activities

---

## FIX REQUIRED FOR APPENDIX E

Make `save_arpl_appendix_e.php` trade-agnostic like the GET endpoint.

**Solution**: Dynamic table selection based on OFO

```php
// Determine table name based on OFO
$table_name = '';
switch ($ofo_number) {
    case '641201': // Bricklayer
        $table_name = 'arplappxe_bricklaying_activity_ratings';
        break;
    case '671101': // Electrician
        $table_name = 'arplappxe_electrician_activity_ratings';
        break;
    case '671201': // Plumber
        $table_name = 'arplappxe_plumber_activity_ratings';
        break;
    default:
        throw new Exception("Unknown OFO number: $ofo_number");
}

// Use dynamic table name in query
$stmt = $conn->prepare("
    INSERT INTO {$table_name} (
        learnerID,
        ofo_number,
        activity_id,
        ...
```

**This matches the pattern used in**:
- `get_arpl_competency_data.php` (already fixed - dynamic table selection)

---

## VERIFICATION CHECKLIST

Before uploading, verify these tables exist on ONLINE server:

### For Bricklayer (641201):
- [ ] `arplappxb_activity_ratings` (has ofo_number column)
- [ ] `arpl_appendix_d` (has ofo_number column)
- [ ] `arplappxe_bricklaying_activity_ratings` ← For Appendix E
- [ ] `arpl_appendix_f` (has ofo_number column)
- [ ] `arpl_evaluation_criteria`

### For Electrician (671101):
- [ ] `arplappxb_activity_ratings` (has ofo_number column)
- [ ] `arpl_appendix_d` (has ofo_number column)
- [ ] `arplappxe_electrician_activity_ratings` ← For Appendix E
- [ ] `arpl_appendix_f` (has ofo_number column)
- [ ] `arpl_evaluation_criteria`

### For Plumber (671201):
- [ ] `arplappxb_activity_ratings` (has ofo_number column)
- [ ] `arpl_appendix_d` (has ofo_number column)
- [ ] `arplappxe_plumber_activity_ratings` ← For Appendix E
- [ ] `arpl_appendix_f` (has ofo_number column)
- [ ] `arpl_evaluation_criteria`

---

## RECOMMENDED ACTIONS

### Immediate (Before Upload):

1. ✅ **Upload 4 working endpoints** (B, D, F, Criteria)
   - These are fully trade-agnostic
   - Will work for all trades immediately

2. ⚠️ **Fix Appendix E endpoint** before upload
   - Add dynamic table selection
   - Test with all 3 trades

3. ✅ **Verify tables exist** on ONLINE server
   - Run table check script
   - Create missing tables if needed

### Testing After Upload:

Test with all 3 trades:
- Bricklayer (641201) - Class 797
- Electrician (671101) - Class ???
- Plumber (671201) - Class ???

For each trade, test:
- Save Appendix B ✅
- Save Appendix D ✅
- Save Appendix E ⚠️ (after fix)
- Save Appendix F ✅
- Save Criteria ✅

---

## CONCLUSION

**Current State**:
- 4 endpoints are trade-agnostic ✅
- 1 endpoint needs fixing (Appendix E) ⚠️

**Next Steps**:
1. Fix `save_arpl_appendix_e.php` to use dynamic table selection
2. Upload all 5 endpoints
3. Test with Bricklayer, Electrician, and Plumber

**No Database Changes Needed**:
- Unified tables already have `ofo_number` column
- Separate Appendix E tables should already exist per trade
- Just need to fix the PHP code to use correct table

