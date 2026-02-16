# SDP Physical Address and Email Added to new_aggrement2.php

## Summary
Added two new fields from the `sdp` table to the learner agreement document generation:
1. `p_address` (Physical Address) → `sdp_physical_address`
2. `email` → `sdp_email`

## Changes Made

### 1. SQL Queries Updated (3 locations)
Added the following fields to all three SQL queries in the file:

```sql
s.p_address AS sdp_physical_address,
s.email AS sdp_email,
```

**Locations:**
- Line ~1187: Main query for single learner
- Line ~1391: Fallback query for single learner
- Line ~1568: Bulk query for multiple learners

### 2. Template setValue Calls Added (2 locations)
Added the following template placeholders:

```php
$template->setValue('sdp_physical_address', $learner_data['sdp_physical_address'] ?? 'N/A');
$template->setValue('sdp_email', $learner_data['sdp_email'] ?? 'N/A');
```

**Locations:**
- Line ~715: In `generateForms()` function for form generation
- Line ~1855: In main document generation loop

## Word Template Placeholders
Your Word templates can now use these new placeholders:

- `${sdp_physical_address}` → Will show the SDP's physical address
- `${sdp_email}` → Will show the SDP's email address

## Existing SDP Fields (for reference)
The following SDP fields were already available:
- `${sdp_name}` → SDP name
- `${sdp_initials}` → SDP initials (TEXT)
- `${sdp_witness_initials}` → SDP witness initials (TEXT)
- `${sdp_contact_person}` → Contact person name
- `${sdp_contact_number}` → Contact phone number
- `${sdp_city}` → City
- `${sdp_postal_code}` → Postal code
- `${sdp_signature_image}` → SDP signature (IMAGE)
- `${sdp_witness_signature_image}` → SDP witness signature (IMAGE)

## Database Schema
The `sdp` table should have these columns:
- `sdp_name` (TEXT)
- `p_address` (TEXT) - Physical address
- `email` (TEXT) - Email address
- `initials` (TEXT) - Initials
- `witness_initials` (TEXT) - Witness initials
- `signature_image` (TEXT) - Path to signature image
- `witness_signature` (TEXT) - Path to witness signature image
- `contact_person` (TEXT)
- `contact_number` (TEXT)
- `city` (TEXT)
- `postal_code` (TEXT)

## Testing
To verify the changes:
1. Generate a learner agreement document
2. Check that `${sdp_physical_address}` shows the SDP's physical address
3. Check that `${sdp_email}` shows the SDP's email address
4. If the fields are empty in the database, they will show as "N/A"

## Status
✅ **COMPLETE** - SDP physical address and email fields added to document generation.

## Notes
- Both fields default to "N/A" if not present in the database
- The fields are retrieved from the `sdp` table via the JOIN: `LEFT JOIN sdp s ON p.sdp_name = s.sdp_name`
- All three SQL queries in the file have been updated to include these fields
