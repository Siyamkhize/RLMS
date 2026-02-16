# Assessor Column Name Changes Required

## Changes Requested

### 1. Remove assessor_registration field
Remove this line from all 3 SQL queries:
```sql
COALESCE(f.assessor_registration, 'N/A') AS assessor_registration,
```

### 2. Change email column name
Change from:
```sql
COALESCE(f.f_email, 'N/A') AS assessor_email,
```

To:
```sql
COALESCE(f.email, 'N/A') AS assessor_email,
```

### 3. Change phone column name
Change from:
```sql
COALESCE(f.f_phone, 'N/A') AS assessor_phone,
```

To:
```sql
COALESCE(f.phoneNumber, 'N/A') AS assessor_phone,
```

## Locations to Update

All 3 SQL queries in `php/new_aggrement2.php`:
1. Line ~1211-1213: Main query for single learner
2. Line ~1420-1422: Fallback query for single learner
3. Line ~1606-1608: Bulk query for multiple learners

## Before (Current):
```sql
COALESCE(f.f_IDNumber, 'N/A') AS assessor_id_number,
COALESCE(f.f_email, 'N/A') AS assessor_email,
COALESCE(f.f_phone, 'N/A') AS assessor_phone,
COALESCE(f.assessor_registration, 'N/A') AS assessor_registration,
COALESCE(f.assessor_registration_number, f.assessorNo, 'N/A') AS assessor_registration_number,
COALESCE(f.assessorExpiryDate, 'N/A') AS assessor_expiry_date,
```

## After (Required):
```sql
COALESCE(f.f_IDNumber, 'N/A') AS assessor_id_number,
COALESCE(f.email, 'N/A') AS assessor_email,
COALESCE(f.phoneNumber, 'N/A') AS assessor_phone,
COALESCE(f.assessor_registration_number, f.assessorNo, 'N/A') AS assessor_registration_number,
COALESCE(f.assessorExpiryDate, 'N/A') AS assessor_expiry_date,
```

## Reason for Changes

The facilitator table uses these actual column names:
- `email` (not `f_email`)
- `phoneNumber` (not `f_phone`)
- `assessor_registration` field doesn't exist or isn't needed

## Impact

After these changes:
- `${Assessor_Email}` will pull from `facilitator.email`
- `${Assessor_Phone}` will pull from `facilitator.phoneNumber`
- `${Assessor_Registration}` placeholder will no longer be available (only `${Assessor_Registration_Number}` will work)

## Manual Update Required

Due to file locking or IDE auto-formatting, the PowerShell commands didn't persist. Please manually update the file or use the IDE's find-and-replace feature:

1. Find: `f.f_email` → Replace with: `f.email`
2. Find: `f.f_phone` → Replace with: `f.phoneNumber`
3. Find and delete the entire line: `COALESCE(f.assessor_registration, 'N/A') AS assessor_registration,`

Make sure to update all 3 occurrences in the file!
