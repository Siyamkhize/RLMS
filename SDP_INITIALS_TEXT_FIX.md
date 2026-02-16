# SDP Initials Text Fix - Complete

## Issue
The `sdp_initials` and `sdp_witness_initials` fields in the `sdp` table were being incorrectly treated as **image paths** when they actually contain **text** (e.g., "JD", "AB", "MT").

## Root Cause
In `php/new_aggrement2.php`, the code was attempting to:
1. Find image files using `findSignatureImage()` for these text fields
2. Insert them as images using `setImageValue()` with placeholders like `sdp_initials_image` and `sdp_witness_initials_image`

## Database Schema
From the SQL query in the file, the SDP table fields are:
- `s.sdp_initials` → **TEXT** (e.g., "JD", "AB")
- `s.sdp_witness_initials` → **TEXT** (e.g., "MT", "KL")
- `s.signature_image` → **IMAGE PATH** (e.g., "Uploads/sdp/signature.png")
- `s.sdp_witness_signature` → **IMAGE PATH** (e.g., "Uploads/sdp/witness_sig.png")

## Fix Applied
Modified `php/new_aggrement2.php` to:

### Before (Lines ~900-920):
```php
// Add SDP initials image
log_message("Form - Looking for SDP initials: " . ($learner_data['sdp_initials'] ?? 'null'));
$sdp_initials_path = findSignatureImage(
    $learner_data['sdp_initials'], 
    null, 
    'sdp'
);
if ($sdp_initials_path) {
    $template->setImageValue('sdp_initials_image', [
        'src' => $sdp_initials_path,
        'width' => 100,
        'height' => 50
    ]);
    log_message("SDP initials image added to form: $sdp_initials_path");
} else {
    $template->setValue('sdp_initials_image', 'N/A');
    log_message("No SDP initials found for form");
}

// Add SDP witness initials image
log_message("Form - Looking for SDP witness initials: " . ($learner_data['sdp_witness_initials'] ?? 'null'));
$sdp_witness_initials_path = findSignatureImage(
    $learner_data['sdp_witness_initials'], 
    null, 
    'sdp'
);
if ($sdp_witness_initials_path) {
    $template->setImageValue('sdp_witness_initials_image', [
        'src' => $sdp_witness_initials_path,
        'width' => 100,
        'height' => 50
    ]);
    log_message("SDP witness initials image added to form: $sdp_witness_initials_path");
} else {
    $template->setValue('sdp_witness_initials_image', 'N/A');
    log_message("No SDP witness initials found for form");
}
```

### After (Fixed):
```php
// SDP initials are TEXT, not images - already set above as text placeholder
// No need to process as image
log_message("Form - SDP initials (text): " . ($learner_data['sdp_initials'] ?? 'N/A'));

// SDP witness initials are TEXT, not images - already set above as text placeholder
// No need to process as image
log_message("Form - SDP witness initials (text): " . ($learner_data['sdp_witness_initials'] ?? 'N/A'));
```

## How It Works Now
1. **Text placeholders** (already set earlier in the code around line 700):
   ```php
   $template->setValue('sdp_initials', $learner_data['sdp_initials'] ?? 'N/A');
   $template->setValue('sdp_witness_initials', $learner_data['sdp_witness_initials'] ?? 'N/A');
   ```

2. **Image placeholders** (still processed correctly):
   ```php
   // SDP signature image
   $template->setImageValue('sdp_signature_image', [...]);
   
   // SDP witness signature image
   $template->setImageValue('sdp_witness_signature_image', [...]);
   ```

## Word Template Placeholders
Your Word templates should use:
- `${sdp_initials}` → Will show text like "JD"
- `${sdp_witness_initials}` → Will show text like "AB"
- `${sdp_signature_image}` → Will show the SDP signature image
- `${sdp_witness_signature_image}` → Will show the SDP witness signature image

## Testing
To verify the fix:
1. Generate a learner agreement document
2. Check that `sdp_initials` and `sdp_witness_initials` show as **text** (e.g., "JD", "MT")
3. Check that `sdp_signature_image` and `sdp_witness_signature_image` show as **images**

## Status
✅ **FIXED** - SDP initials are now correctly treated as text fields, not image paths.
