# SDP Witness Signature Image Fix - Complete

## Issue
The `sdp_witness_signature` field in the SDP table contains an image path (e.g., `/Uploads/sdp/witness_sig_3_1764146358.png`), but it was being displayed as **text** in the Word document instead of being rendered as an **image**.

## Root Cause
The code was setting `sdp_witness_signature` as **text** using `setValue()`, which was overriding the image processing that happens later in the code.

```php
// WRONG - This was setting it as text
$template->setValue('sdp_witness_signature', $learner_data['sdp_witness_signature'] ?? 'N/A');
```

## Fix Applied

### 1. Removed Text setValue Calls (2 locations)
**Before:**
```php
$template->setValue('sdp_witness_signature', $learner_data['sdp_witness_signature'] ?? 'N/A');
```

**After:**
```php
// Note: sdp_witness_signature is set as IMAGE below, not as text
// (removed the setValue call)
```

**Locations:**
- Line ~710: In `generateForms()` function
- Line ~1854: In main document generation loop

### 2. Added Missing Image Processing (1 location)
Added the SDP witness signature image processing in the second document generation section:

```php
// Add SDP witness signature image
log_message("Looking for SDP witness signature: " . ($data['sdp_witness_signature'] ?? 'null'));
$sdp_witness_signature_path = findSignatureImage(
    $data['sdp_witness_signature'], 
    null, 
    'sdp'
);
if ($sdp_witness_signature_path) {
    $template->setImageValue('sdp_witness_signature_image', [
        'src' => $sdp_witness_signature_path,
        'width' => 100,
        'height' => 50
    ]);
    log_message("SDP witness signature image added: $sdp_witness_signature_path");
} else {
    $template->setValue('sdp_witness_signature_image', 'N/A');
    log_message("No SDP witness signature found");
}
```

**Location:** Line ~2088 (after SDP signature image processing)

## How It Works Now

### Database Value:
```
sdp_witness_signature = "/Uploads/sdp/witness_sig_3_1764146358.png"
```

### Processing Flow:
1. **SQL Query** retrieves `s.sdp_witness_signature` from the SDP table
2. **findSignatureImage()** function searches for the image file in multiple possible locations:
   - `Uploads/sdp/witness_sig_3_1764146358.png`
   - `../Uploads/sdp/witness_sig_3_1764146358.png`
   - `mobile/Uploads/sdp/witness_sig_3_1764146358.png`
   - And other variations...
3. **setImageValue()** inserts the image into the Word document at the placeholder
4. If image not found, sets placeholder to "N/A"

### Word Template Placeholders:
- `${sdp_witness_signature_image}` → Will show the SDP witness signature **image**
- `${sdp_signature_image}` → Will show the SDP signature **image**

## Related Fields (for reference)

### SDP Fields - TEXT:
- `${sdp_name}` → SDP name (text)
- `${sdp_initials}` → SDP initials (text like "JD")
- `${sdp_witness_initials}` → SDP witness initials (text like "AB")
- `${sdp_contact_person}` → Contact person (text)
- `${sdp_contact_number}` → Phone number (text)
- `${sdp_city}` → City (text)
- `${sdp_postal_code}` → Postal code (text)
- `${sdp_physical_address}` → Physical address (text)
- `${sdp_email}` → Email (text)

### SDP Fields - IMAGES:
- `${sdp_signature_image}` → SDP signature (image)
- `${sdp_witness_signature_image}` → SDP witness signature (image)

## File Path Handling
The `findSignatureImage()` function handles various path formats:
- Absolute paths: `/Uploads/sdp/file.png`
- Relative paths: `Uploads/sdp/file.png`
- URL paths: `rlms.rlms.co.za/mobile/Uploads/sdp/file.png`
- With/without leading slashes
- With/without `mobile/` prefix

## Testing
To verify the fix:
1. Generate a learner agreement document
2. Check that `${sdp_witness_signature_image}` shows the **image**, not the file path text
3. Check that `${sdp_signature_image}` shows the **image**
4. If the image file doesn't exist, the placeholder will show "N/A"

## Status
✅ **COMPLETE** - SDP witness signature now displays as an image instead of text.

## Summary of Changes
1. ✅ Removed text setValue for `sdp_witness_signature` (2 locations)
2. ✅ Added image processing for `sdp_witness_signature` in second generation section (1 location)
3. ✅ Image processing already existed in first generation section (verified)

The document will now correctly display the SDP witness signature as an image!
