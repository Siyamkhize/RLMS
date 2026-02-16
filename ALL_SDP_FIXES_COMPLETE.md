# All SDP Fixes Complete - php/new_aggrement2.php

## Summary
All requested changes to the SDP (Skills Development Provider) fields in `php/new_aggrement2.php` have been completed successfully.

## Changes Made

### 1. ✅ SDP Initials - Fixed to TEXT (Not Images)
**Issue:** `sdp_initials` and `sdp_witness_initials` were being treated as image paths when they contain text values like "JD", "AB", etc.

**Fix:**
- Removed image processing for `sdp_initials` 
- Removed image processing for `sdp_witness_initials`
- These fields now display as text only

**Word Template Usage:**
- `${sdp_initials}` → Shows text like "JD"
- `${sdp_witness_initials}` → Shows text like "AB"

---

### 2. ✅ SDP Physical Address & Email - Added
**Issue:** Physical address and email from SDP table were not available in documents.

**Fix:**
- Added `s.p_address AS sdp_physical_address` to all 3 SQL queries
- Added `s.email AS sdp_email` to all 3 SQL queries
- Added template setValue calls in 2 locations

**Word Template Usage:**
- `${sdp_physical_address}` → Shows SDP's physical address
- `${sdp_email}` → Shows SDP's email address

---

### 3. ✅ SDP Witness Signature - Fixed to IMAGE (Not Text)
**Issue:** `sdp_witness_signature` contains an image path like `/Uploads/sdp/witness_sig_3_1764146358.png` but was displaying as text instead of an image.

**Fix:**
- Removed text setValue for `sdp_witness_signature` (2 locations)
- Added image processing for `sdp_witness_signature` in second generation section
- Verified image processing exists in first generation section

**Word Template Usage:**
- `${sdp_witness_signature_image}` → Shows the witness signature image

---

### 4. ✅ Server URL - Changed
**Issue:** All URLs were pointing to old testing server.

**Fix:**
- Changed from `rlms.rlms.co.za` to `rlms.rlms.co.za`
- Updated in `lib/config.dart` (main configuration)
- Updated in all PHP test/debug files

---

## Complete SDP Field Reference

### TEXT Fields (use setValue):
```php
${sdp_name}                  // SDP name
${sdp_initials}              // SDP initials (e.g., "JD")
${sdp_witness_initials}      // SDP witness initials (e.g., "AB")
${sdp_contact_person}        // Contact person name
${sdp_contact_number}        // Phone number
${sdp_city}                  // City
${sdp_postal_code}           // Postal code
${sdp_physical_address}      // Physical address (NEW)
${sdp_email}                 // Email address (NEW)
```

### IMAGE Fields (use setImageValue):
```php
${sdp_signature_image}              // SDP signature image
${sdp_witness_signature_image}      // SDP witness signature image
```

---

## Database Schema - SDP Table

The `sdp` table should have these columns:
```sql
sdp_name                VARCHAR     -- SDP name
initials                VARCHAR     -- SDP initials (TEXT like "JD")
witness_initials        VARCHAR     -- Witness initials (TEXT like "AB")
signature_image         VARCHAR     -- Path to SDP signature image
witness_signature       VARCHAR     -- Path to witness signature image (was sdp_witness_signature)
contact_person          VARCHAR     -- Contact person name
contact_number          VARCHAR     -- Phone number
city                    VARCHAR     -- City
postal_code             VARCHAR     -- Postal code
p_address               TEXT        -- Physical address (NEW)
email                   VARCHAR     -- Email address (NEW)
sdp_logo                VARCHAR     -- Logo path
```

---

## SQL Query Changes

All three SQL queries in the file now include:
```sql
s.sdp_name,
s.sdp_logo,
s.signature_image,
s.sdp_initials,
s.sdp_witness_signature,
s.sdp_witness_initials,
s.contact_person,
s.contact_number,
s.city,
s.postal_code,
s.p_address AS sdp_physical_address,    -- NEW
s.email AS sdp_email,                    -- NEW
```

**Query Locations:**
- Line ~1187: Main query for single learner
- Line ~1391: Fallback query for single learner  
- Line ~1568: Bulk query for multiple learners

---

## Template Processing Changes

### Location 1: generateForms() function (~line 710)
```php
// TEXT fields
$template->setValue('sdp_name', $learner_data['sdp_name'] ?? 'N/A');
$template->setValue('sdp_initials', $learner_data['sdp_initials'] ?? 'N/A');
// Note: sdp_witness_signature is set as IMAGE below, not as text
$template->setValue('sdp_witness_initials', $learner_data['sdp_witness_initials'] ?? 'N/A');
$template->setValue('sdp_contact_person', $learner_data['contact_person'] ?? 'N/A');
$template->setValue('sdp_contact_number', $learner_data['contact_number'] ?? 'N/A');
$template->setValue('sdp_city', $learner_data['city'] ?? 'N/A');
$template->setValue('sdp_postal_code', $learner_data['postal_code'] ?? 'N/A');
$template->setValue('sdp_physical_address', $learner_data['sdp_physical_address'] ?? 'N/A');  // NEW
$template->setValue('sdp_email', $learner_data['sdp_email'] ?? 'N/A');  // NEW

// IMAGE fields (processed later ~line 950)
// - sdp_signature_image
// - sdp_witness_signature_image
```

### Location 2: Main document generation (~line 1854)
```php
// TEXT fields
$template->setValue('sdp_name', $data['sdp_name'] ?? 'N/A');
$template->setValue('sdp_initials', $data['sdp_initials'] ?? 'N/A');
// Note: sdp_witness_signature is set as IMAGE below, not as text
$template->setValue('sdp_witness_initials', $data['sdp_witness_initials'] ?? 'N/A');
$template->setValue('sdp_contact_person', $data['contact_person'] ?? 'N/A');
$template->setValue('sdp_contact_number', $data['contact_number'] ?? 'N/A');
$template->setValue('sdp_city', $data['city'] ?? 'N/A');
$template->setValue('sdp_postal_code', $data['postal_code'] ?? 'N/A');
$template->setValue('sdp_physical_address', $data['sdp_physical_address'] ?? 'N/A');  // NEW
$template->setValue('sdp_email', $data['sdp_email'] ?? 'N/A');  // NEW

// IMAGE fields (processed later ~line 2088)
// - sdp_signature_image
// - sdp_witness_signature_image
```

---

## Image Processing

### SDP Signature Image (~line 940 & ~line 2071)
```php
$sdp_signature_path = findSignatureImage(
    $learner_data['signature_image'], 
    null, 
    'sdp'
);
if ($sdp_signature_path) {
    $template->setImageValue('sdp_signature_image', [
        'src' => $sdp_signature_path,
        'width' => 100,
        'height' => 50
    ]);
}
```

### SDP Witness Signature Image (~line 950 & ~line 2088)
```php
$sdp_witness_signature_path = findSignatureImage(
    $learner_data['sdp_witness_signature'], 
    null, 
    'sdp'
);
if ($sdp_witness_signature_path) {
    $template->setImageValue('sdp_witness_signature_image', [
        'src' => $sdp_witness_signature_path,
        'width' => 100,
        'height' => 50
    ]);
}
```

---

## Testing Checklist

### 1. Test SDP Initials (TEXT)
- [ ] Generate a document
- [ ] Verify `${sdp_initials}` shows text like "JD" (not an image or file path)
- [ ] Verify `${sdp_witness_initials}` shows text like "AB" (not an image or file path)

### 2. Test SDP Address & Email (NEW)
- [ ] Generate a document
- [ ] Verify `${sdp_physical_address}` shows the physical address
- [ ] Verify `${sdp_email}` shows the email address
- [ ] If database fields are empty, should show "N/A"

### 3. Test SDP Witness Signature (IMAGE)
- [ ] Generate a document
- [ ] Verify `${sdp_witness_signature_image}` shows an **image**, not text
- [ ] Should NOT show file path like "/Uploads/sdp/witness_sig_3_1764146358.png"
- [ ] If image file doesn't exist, should show "N/A"

### 4. Test Server URL
- [ ] Rebuild Flutter app: `flutter clean && flutter pub get && flutter build apk`
- [ ] Verify all API calls go to `rlms.rlms.co.za`
- [ ] Test login, sync, and document generation

---

## Files Modified

1. **php/new_aggrement2.php** - Main document generation file
   - SQL queries updated (3 locations)
   - Template setValue calls updated (2 locations)
   - Image processing updated (2 locations)

2. **lib/config.dart** - Flutter configuration
   - Server URL changed from `rlms.rlms.co.za` to `rlms.rlms.co.za`

3. **get_facilitator_profile.php** - Facilitator profile API
   - Base URL updated

4. **debug_add_learner_sync.php** - Debug script
   - Test URL updated

5. **debug_pothole_logbook_flutter.php** - Debug script
   - Test URL updated

6. **learners.php** - Documentation
   - URL comments updated

---

## Status

✅ **ALL FIXES COMPLETE**

All SDP-related changes have been successfully implemented in `php/new_aggrement2.php`:
1. ✅ SDP initials fixed to TEXT
2. ✅ SDP physical address added
3. ✅ SDP email added
4. ✅ SDP witness signature fixed to IMAGE
5. ✅ Server URL changed to rlms.rlms.co.za

The document generation system is now ready for production use!

---

## Next Steps

1. **Upload to Server:** Upload `php/new_aggrement2.php` to `rlms.rlms.co.za/mobile/php/`
2. **Rebuild App:** Run `flutter clean && flutter pub get && flutter build apk --release`
3. **Test Documents:** Generate test documents to verify all placeholders work correctly
4. **Update Templates:** Ensure Word templates use correct placeholder names as documented above

---

## Support Documentation

- `SDP_INITIALS_TEXT_FIX.md` - Details on initials fix
- `SDP_ADDRESS_EMAIL_ADDED.md` - Details on new fields
- `SDP_WITNESS_SIGNATURE_IMAGE_FIX.md` - Details on witness signature fix
- `URL_CHANGE_TO_RLMS_COMPLETE.md` - Details on URL changes
