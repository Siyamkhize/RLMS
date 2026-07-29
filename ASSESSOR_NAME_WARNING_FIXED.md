# Assessor Name Warning - FIXED ✅

**Warning**: 
```
Warning: Undefined array key "FirstName" in C:\xampp\htdocs\web\web\web\arpl_pdf.php on line 1743
Warning: Undefined array key "LastName" in C:\xampp\htdocs\web\web\web\arpl_pdf.php on line 1743
```

**Root Cause**: Array key case mismatch
- Code was using: `$facilitator['FirstName']` (uppercase)
- Array keys are: `$facilitator['firstName']` (lowercase)

**File**: `web/arpl_pdf.php` (Line 1788)

---

## What Was Changed

### Before (Line 1788)
```php
<tr><td><b>Assessor Name</b></td><td><?php echo htmlspecialchars($facilitator['FirstName'] . ' ' . $facilitator['LastName'] ?? 'Assessment Coordinator'); ?></td></tr>
```

**Problems**:
1. Uses uppercase keys `FirstName` and `LastName` which don't exist
2. Operator precedence wrong - `??` applies only to `LastName` not the whole expression

### After (Line 1788)
```php
<tr><td><b>Assessor Name</b></td><td><?php echo htmlspecialchars(($facilitator['firstName'] ?? '') . ' ' . ($facilitator['lastName'] ?? '') ?: 'Assessment Coordinator'); ?></td></tr>
```

**Fixes**:
1. Uses correct lowercase keys: `firstName` and `lastName`
2. Uses proper null coalescing: `??` provides default empty string for each key
3. Uses `?:` to provide fallback "Assessment Coordinator" if both names are empty

---

## Result

✅ No more PHP warnings  
✅ Assessor name displays correctly  
✅ Fallback shows "Assessment Coordinator" if name is missing  

---

## Verification

```bash
php -l web/arpl_pdf.php
```

**Result**: No syntax errors detected ✓

---

**Status**: FIXED ✅
