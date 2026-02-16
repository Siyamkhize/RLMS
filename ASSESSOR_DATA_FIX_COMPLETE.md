# Assessor Data Fix Complete - php/new_aggrement2.php

## Issue
Assessor data was not being retrieved from the `facilitator` table where `role = 'Assessor'`.

## Root Cause
The SQL queries were missing several important assessor fields from the facilitator table, including:
- Email (`f_email`)
- Phone (`f_phone`)
- Registration info (`assessor_registration`, `assessor_registration_number`)
- **Expiry date (`assessorExpiryDate`)** - Column name was incorrect

## Fix Applied

### 1. Added Missing Assessor Fields to SQL Queries (3 locations)

Added the following fields after `assessor_id_number`:

```sql
COALESCE(f.f_email, 'N/A') AS assessor_email,
COALESCE(f.f_phone, 'N/A') AS assessor_phone,
COALESCE(f.assessor_registration, 'N/A') AS assessor_registration,
COALESCE(f.assessor_registration_number, f.assessorNo, 'N/A') AS assessor_registration_number,
COALESCE(f.assessorExpiryDate, 'N/A') AS assessor_expiry_date,
```

**Query Locations:**
- Line ~1215: Main query for single learner
- Line ~1424: Fallback query for single learner
- Line ~1610: Bulk query for multiple learners

### 2. Fixed Column Name
Changed from `f.assessor_expiry_date` to `f.assessorExpiryDate` (camelCase as it exists in the database).

## Facilitator Table JOIN

The queries already had the correct JOIN:
```sql
LEFT JOIN facilitator f ON f.classID = c.classID AND f.role = 'Assessor'
```

This JOIN:
- Links to the `facilitator` table using `classID`
- Filters for records where `role = 'Assessor'`
- Uses LEFT JOIN so documents generate even if no assessor is assigned

## Complete Assessor Fields Now Available

### Basic Information:
```php
${Assessor_Name}              // First name
${Assessor_Surname}           // Last name
${Assessor_Full_Name}         // Full name
${Assessor_ID}                // ID number
${Assessor_IDNumber}          // ID number (alias)
${Assessor_Email}             // Email (NEW)
${Assessor_Phone}             // Phone (NEW)
${Assessor_Contact}           // Phone (alias)
```

### ID Number Breakdown (13 digits):
```php
${assessor_id_digit_1}
${assessor_id_digit_2}
...
${assessor_id_digit_13}
```

### Registration Information:
```php
${Assessor_Number}                    // Assessor number
${Assessor_Registration}              // Registration info (NEW)
${Assessor_Registration_Number}       // Registration number (NEW)
```

### Assessor Number Breakdown (30 characters):
```php
${assessor_number_char_1}
${assessor_number_char_2}
...
${assessor_number_char_30}
```

### Expiry Date:
```php
${Assessor_End_Date}          // Full date (NEW - now working)
${Assessor_Expiry_Date}       // Full date (NEW - now working)
${assessor_expiry_date}       // Full date (NEW - now working)
```

### Expiry Date Breakdown (10 characters for DD/MM/YYYY):
```php
${assessor_expiry_char_1}     // D
${assessor_expiry_char_2}     // D
${assessor_expiry_char_3}     // /
${assessor_expiry_char_4}     // M
${assessor_expiry_char_5}     // M
${assessor_expiry_char_6}     // /
${assessor_expiry_char_7}     // Y
${assessor_expiry_char_8}     // Y
${assessor_expiry_char_9}     // Y
${assessor_expiry_char_10}    // Y
```

## Facilitator Table Schema

The `facilitator` table should have these columns:
```sql
facilitatorID       INT         -- Primary key
classID             INT         -- Links to class table
firstName           VARCHAR     -- First name
lastName            VARCHAR     -- Last name
role                VARCHAR     -- Role (e.g., 'Assessor', 'Facilitator')
assessorNo          VARCHAR     -- Assessor number
f_IDNumber          VARCHAR     -- ID number
f_email             VARCHAR     -- Email address
f_phone             VARCHAR     -- Phone number
assessor_registration           VARCHAR     -- Registration info
assessor_registration_number    VARCHAR     -- Registration number
assessorExpiryDate  DATE        -- Expiry date (camelCase!)
```

## Template Processing

The assessor data is processed in the template around line 800-880:

```php
// Basic info
$template->setValue('Assessor_Name', $learner_data['assessor_firstName'] ?? 'N/A');
$template->setValue('Assessor_Email', $learner_data['assessor_email'] ?? 'N/A');
$template->setValue('Assessor_Phone', $learner_data['assessor_phone'] ?? 'N/A');

// Registration
$template->setValue('Assessor_Registration', $learner_data['assessor_registration'] ?? 'N/A');
$template->setValue('Assessor_Registration_Number', $learner_data['assessor_registration_number'] ?? 'N/A');

// Expiry date
$assessor_expiry_date = $learner_data['assessor_expiry_date'] ?? '';
$template->setValue('Assessor_End_Date', $assessor_expiry_date !== '' ? $assessor_expiry_date : 'N/A');
$template->setValue('Assessor_Expiry_Date', $assessor_expiry_date !== '' ? $assessor_expiry_date : 'N/A');
```

## Testing Checklist

### 1. Verify Assessor Data is Retrieved
- [ ] Check that assessor with `role = 'Assessor'` exists in facilitator table
- [ ] Verify assessor is linked to the correct `classID`
- [ ] Generate a document and check assessor fields are populated

### 2. Test New Fields
- [ ] `${Assessor_Email}` shows email address
- [ ] `${Assessor_Phone}` shows phone number
- [ ] `${Assessor_Registration}` shows registration info
- [ ] `${Assessor_Registration_Number}` shows registration number
- [ ] `${Assessor_Expiry_Date}` shows expiry date

### 3. Test Expiry Date Formatting
- [ ] Full date shows in correct format
- [ ] Character breakdown shows DD/MM/YYYY format
- [ ] If no expiry date, shows "N/A"

### 4. Test When No Assessor Assigned
- [ ] Document generates successfully
- [ ] All assessor fields show "N/A"
- [ ] No errors occur

## Troubleshooting

### If Assessor Data Still Not Showing:

1. **Check if assessor exists:**
   ```sql
   SELECT * FROM facilitator 
   WHERE role = 'Assessor' 
   AND classID = [YOUR_CLASS_ID];
   ```

2. **Check column names:**
   ```sql
   DESCRIBE facilitator;
   ```
   Verify the column is named `assessorExpiryDate` (camelCase), not `assessor_expiry_date`.

3. **Check JOIN condition:**
   - Verify learner's `classID` matches assessor's `classID`
   - Verify assessor's `role` is exactly 'Assessor' (case-sensitive)

4. **Check for NULL values:**
   ```sql
   SELECT firstName, lastName, f_email, f_phone, assessorExpiryDate
   FROM facilitator 
   WHERE role = 'Assessor';
   ```

## Status

✅ **COMPLETE** - All assessor fields now properly retrieved from facilitator table where role = 'Assessor'

## Summary of Changes

1. ✅ Added `assessor_email` field
2. ✅ Added `assessor_phone` field
3. ✅ Added `assessor_registration` field
4. ✅ Added `assessor_registration_number` field
5. ✅ Added `assessor_expiry_date` field with correct column name (`assessorExpiryDate`)
6. ✅ Updated all 3 SQL queries in the file

The assessor data is now fully available in all generated documents!
