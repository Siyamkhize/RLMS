# Appendix E Save Endpoint - Trade-Agnostic Fix Complete

## ISSUE

`save_arpl_appendix_e.php` was hardcoded to always save to the Electrician table, regardless of the learner's trade.

## ROOT CAUSE

**Before Fix** (Line 55):
```php
$stmt = $conn->prepare("
    INSERT INTO arplappxe_electrician_activity_ratings (  ← HARDCODED!
```

**Impact**:
- Bricklayer (641201) data → Saved to Electrician table ❌
- Electrician (671101) data → Saved to Electrician table ✅
- Plumber (671201) data → Saved to Electrician table ❌

## FIX APPLIED ✅

Added dynamic table selection based on OFO number:

```php
// Determine table name based on OFO (trade-agnostic)
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
        throw new Exception("Unsupported OFO number: $ofo_number");
}

// Verify table exists
$checkTable = $conn->query("SHOW TABLES LIKE '$table_name'");
if ($checkTable->num_rows === 0) {
    throw new Exception("Table '$table_name' does not exist for OFO $ofo_number");
}

// Use dynamic table name
$stmt = $conn->prepare("
    INSERT INTO `$table_name` (
        learnerID,
        ofo_number,
        ...
```

## RESULT

**After Fix**:
- Bricklayer (641201) → `arplappxe_bricklaying_activity_ratings` ✅
- Electrician (671101) → `arplappxe_electrician_activity_ratings` ✅
- Plumber (671201) → `arplappxe_plumber_activity_ratings` ✅

## TRADE SUPPORT SUMMARY

| Endpoint | Trade Support | Status |
|----------|---------------|--------|
| save_arpl_appendix_b.php | ✅ All Trades | OK |
| save_arpl_appendix_d.php | ✅ All Trades | OK |
| save_arpl_appendix_e.php | ✅ All Trades | **FIXED!** |
| save_arpl_appendix_f.php | ✅ All Trades | OK |
| save_arpl_criteria.php | ✅ All Trades | OK |

## UPLOAD STATUS

All 5 save endpoints are now ready for upload:

1. ✅ `save_arpl_appendix_b.php` - Ready (was already trade-agnostic)
2. ✅ `save_arpl_appendix_d.php` - Ready (was already trade-agnostic)
3. ✅ `save_arpl_appendix_e.php` - **FIXED** (now trade-agnostic)
4. ✅ `save_arpl_appendix_f.php` - Ready (was already trade-agnostic)
5. ✅ `save_arpl_criteria.php` - Ready (was already trade-agnostic)

## TABLE REQUIREMENTS

Before upload, verify these tables exist on ONLINE server:

### Appendix E Tables (Trade-Specific):
```sql
-- Bricklayer
arplappxe_bricklaying_activity_ratings

-- Electrician  
arplappxe_electrician_activity_ratings

-- Plumber
arplappxe_plumber_activity_ratings
```

### Unified Tables (All Trades):
```sql
arplappxb_activity_ratings      -- Appendix B
arpl_appendix_d                  -- Appendix D
arpl_appendix_f                  -- Appendix F
arpl_evaluation_criteria         -- Criteria
```

## TEST AFTER UPLOAD

Test each endpoint with all 3 trades:

### Bricklayer (OFO: 641201, Class: 797)
```bash
# Test Appendix E save
curl -X POST https://rlms.rlms.co.za/mobile/save_arpl_appendix_e.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID":11701,"ofo_number":"641201","facilitator_id":6,"ratings":[...]}'
```

**Expected**: Saves to `arplappxe_bricklaying_activity_ratings`

### Electrician (OFO: 671101)
```bash
curl -X POST https://rlms.rlms.co.za/mobile/save_arpl_appendix_e.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID":12345,"ofo_number":"671101","facilitator_id":6,"ratings":[...]}'
```

**Expected**: Saves to `arplappxe_electrician_activity_ratings`

### Plumber (OFO: 671201)
```bash
curl -X POST https://rlms.rlms.co.za/mobile/save_arpl_appendix_e.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID":12346,"ofo_number":"671201","facilitator_id":6,"ratings":[...]}'
```

**Expected**: Saves to `arplappxe_plumber_activity_ratings`

## ERROR HANDLING

The endpoint now provides clear error messages:

**If table doesn't exist**:
```json
{
  "status": "error",
  "message": "Table 'arplappxe_bricklaying_activity_ratings' does not exist for OFO 641201",
  "rolled_back": true
}
```

**If unsupported OFO**:
```json
{
  "status": "error",
  "message": "Unsupported OFO number: 999999. Cannot determine Appendix E table.",
  "rolled_back": true
}
```

## MATCHES PATTERN FROM

This fix follows the same pattern as:
- ✅ `get_arpl_competency_data.php` (dynamic table selection for GET)
- ✅ Now `save_arpl_appendix_e.php` (dynamic table selection for SAVE)

## FILES MODIFIED

1. `mobile/save_arpl_appendix_e.php` - Added trade-agnostic table selection
2. `SAVE_ENDPOINTS_TRADE_ANALYSIS.md` - Documentation
3. `APPENDIX_E_FIX_COMPLETE.md` - This file

---

**Status**: ✅ Fix complete, ready for upload  
**Date**: 2026-07-15  
**Impact**: All ARPL save endpoints now support all trades

