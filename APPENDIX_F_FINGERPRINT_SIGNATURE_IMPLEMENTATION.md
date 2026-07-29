# Appendix F: Fingerprint-Verified Candidate Signature

## Feature Overview

Add fingerprint verification to automatically fill candidate signature in Appendix J (Agreement/Signatures section).

### User Flow:

1. Assessor navigates to Appendix J (Signatures tab)
2. Assessor clicks on "Candidate Signature" field
3. System prompts: "Scan learner's fingerprint to verify identity"
4. Learner scans fingerprint
5. System verifies fingerprint matches learner's stored template
6. If match ✅:
   - Retrieve learner's signature from `learnerdetails.signature`
   - Auto-fill the candidate signature field
   - Show success message: "✓ Learner verified: [Name]"
7. If no match ❌:
   - Show error: "Fingerprint does not match learner profile"
   - Do not fill signature

## Database Schema

### learnerdetails table:
```sql
signature               LONGTEXT        -- Base64 encoded signature image
futronic_left_template  LONGBLOB        -- Fingerprint template data
Name                    VARCHAR(255)
Surname                 VARCHAR(255)
LearnerID               INT
```

## Implementation Components

### 1. Backend API Endpoint

**File:** `mobile/verify_fingerprint_and_get_signature.php`

**Purpose:** Verify fingerprint template and return signature if matched

**Request:**
```json
{
  "learnerID": 11701,
  "scannedTemplate": "base64_encoded_fingerprint_template"
}
```

**Response (Success):**
```json
{
  "status": "success",
  "verified": true,
  "learnerName": "Anele Cele",
  "signature": "data:image/png;base64,iVBORw0KG..."
}
```

**Response (No Match):**
```json
{
  "status": "error",
  "verified": false,
  "message": "Fingerprint does not match learner profile"
}
```

### 2. Frontend Implementation

**File:** `lib/ArplToolkitViewerPage.dart`

**Changes Needed:**

1. Add fingerprint scanner button next to Candidate Signature field
2. Implement fingerprint capture and verification
3. Auto-fill signature on successful verification
4. Show appropriate success/error messages

### 3. Fingerprint Matching Logic

**Algorithm:**
- Use existing Futronic SDK fingerprint matching
- Compare scanned template with `learnerdetails.futronic_left_template`
- Matching threshold: Same as used in clock-in system
- Return match score and verification result

## Security Considerations

1. ✅ Fingerprint template never leaves server (compare server-side)
2. ✅ Only return signature if fingerprint verified
3. ✅ Log all verification attempts for audit trail
4. ✅ Rate limit verification attempts (prevent brute force)
5. ✅ Require assessor to be logged in

## Files to Create/Modify

### New Files:
1. `mobile/verify_fingerprint_and_get_signature.php` - Backend API
2. `lib/services/fingerprint_signature_service.dart` - Flutter service

### Modified Files:
1. `lib/ArplToolkitViewerPage.dart` - Add fingerprint verification UI
2. `lib/config.dart` - Add new API endpoint URL

## Testing Requirements

1. Test with learner who has fingerprint registered ✓
2. Test with learner without fingerprint registered ✗
3. Test with wrong fingerprint scan ✗
4. Test offline behavior (should fail gracefully)
5. Test with learner who has no signature stored ⚠️

## Error Handling

| Scenario | Behavior |
|----------|----------|
| No fingerprint template stored | Show: "Learner has no fingerprint registered" |
| Fingerprint doesn't match | Show: "Fingerprint verification failed" |
| No signature stored | Show: "Learner has no signature on file" + Allow manual entry |
| Network error | Show: "Cannot verify offline" + Allow manual entry |
| Scanner unavailable | Show: "Fingerprint scanner not available" + Allow manual entry |

## Future Enhancements

1. Support for right-hand fingerprint as backup
2. Multiple fingerprint attempts (3 tries)
3. Fallback to PIN/password if fingerprint fails
4. Timestamp of when signature was auto-filled
5. Store which assessor triggered the verification

## UI/UX Design

### Before Verification:
```
┌─────────────────────────────────────┐
│ Candidate Signature                 │
│                                     │
│ [Empty signature field]              │
│                                     │
│ [🔍 Verify with Fingerprint] Button │
└─────────────────────────────────────┘
```

### During Verification:
```
┌─────────────────────────────────────┐
│ 🔄 Scanning fingerprint...          │
│                                     │
│ Please place finger on scanner      │
└─────────────────────────────────────┘
```

### After Successful Verification:
```
┌─────────────────────────────────────┐
│ ✅ Verified: Anele Cele             │
│                                     │
│ [Signature image displayed]          │
│                                     │
│ Date: 2026-07-20                    │
└─────────────────────────────────────┘
```

## Configuration

Add to `lib/config.dart`:
```dart
static String get verifyFingerprintSignatureUrl =>
    '$baseUrl/verify_fingerprint_and_get_signature.php';
```

## Next Steps

1. ✅ Create backend verification endpoint
2. ✅ Add fingerprint scanner integration to Flutter
3. ✅ Implement UI changes in ArplToolkitViewerPage
4. ✅ Test with real fingerprint data
5. ✅ Deploy and verify on production
