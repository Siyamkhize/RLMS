# Clock-In Page Validation Checks Documentation

## Overview

Before allowing a learner to clock in, the `clock_in_page.dart` implements a comprehensive three-stage validation system to ensure data completeness and compliance. This document details how profile, bank details, and document validation works.

---

## Validation Flow Sequence

When a learner attempts to clock in, the following validation sequence is executed:

```
User clicks "Clock In" button
    ↓
1. Profile Completeness Check
    ↓ (if complete)
2. Bank Details Completeness Check
    ↓ (if complete)
3. Document Completeness Check
    ↓ (if complete)
4. Show Clocking Days Popup
    ↓
5. Fingerprint Verification
    ↓
6. Geofencing Check
    ↓
7. Clock-In Allowed
```

**If any validation fails, the clock-in process is blocked until the issue is resolved.**

---

## 1. Profile Completeness Check

### Method: `_ensureLearnerProfileComplete(String learnerId)`

### Purpose
Ensures all required profile fields are filled before allowing clock-in.

### Required Profile Fields (19 fields)

| Field Label | Database Key(s) | Description |
|------------|----------------|-------------|
| Name | `Name` | Learner's first name |
| Surname | `Surname` | Learner's last name |
| ID Number | `IDNumber` | South African ID number |
| Race | `Race` | Demographic information |
| Language | `Language` | Primary language |
| Disability | `Disability` | Disability status |
| Cellphone Number | `CellphoneNumber`, `PhoneNumber` | Contact number (accepts either field) |
| Address Line 1 | `AddressLine1` | Street address |
| Address Line 2 | `AddressLine2` | Suburb/Area |
| Address Line 3 | `AddressLine3` | City |
| Postal Code | `PostalCode` | Postal code |
| Next of Kin Name | `KinName` | Emergency contact name |
| Next of Kin Relation | `KinRelation` | Relationship to learner |
| School Name | `SchoolName` | Last school attended |
| School Completion | `SchoolCompletion` | Completion status |
| School Location | `SchoolLocation` | School location |
| School Grade | `SchoolGrade` | Highest grade completed |
| Profile Image | `profile_image` | Learner photo |
| Learner Signature | `signature` | Digital signature |

### Validation Logic

```dart
final List<_RequiredProfileRule> _requiredProfileRules = const [
  _RequiredProfileRule(label: 'Name', keys: ['Name']),
  _RequiredProfileRule(label: 'Surname', keys: ['Surname']),
  _RequiredProfileRule(label: 'ID Number', keys: ['IDNumber']),
  // ... (19 rules total)
];
```

### How It Works

1. **Fetch Learner Data**
   - First tries to fetch from server (if online)
   - Falls back to local database (if offline)
   - Returns null if learner not found

2. **Check Missing Fields**
   - Iterates through all 19 required profile rules
   - For each rule, checks if ANY of the specified keys have valid values
   - A field is considered "missing" if:
     - Value is null
     - Value is empty string
     - Value is "null" (string)
     - Value is "n/a", "na", or "-"

3. **Show Dialog if Incomplete**
   ```
   ┌─────────────────────────────────────┐
   │  Complete Learner Profile           │
   ├─────────────────────────────────────┤
   │  This learner profile is incomplete.│
   │  Please fill in missing fields and  │
   │  press Update Data before clock-in. │
   │                                     │
   │  Missing fields:                    │
   │  - Name                             │
   │  - ID Number                        │
   │  - Profile Image                    │
   │                                     │
   │  [Cancel]  [Open Profile]           │
   └─────────────────────────────────────┘
   ```

4. **Navigate to Profile Page**
   - Opens `LearnerDetailsPage` in "missing profile only" mode
   - Highlights missing fields for easy completion
   - User must fill in all missing fields and click "Update Data"

5. **Re-validate After Update**
   - Fetches learner data again
   - Checks if all fields are now complete
   - If still incomplete, shows warning and blocks clock-in
   - If complete, proceeds to bank details check

### Code Example

```dart
Future<bool> _ensureLearnerProfileComplete(String learnerId) async {
  final learner = await _getLearnerForValidation(learnerId);
  if (learner == null) {
    // Show error: Could not load learner profile
    return false;
  }

  final missingFieldLabels = _getMissingRequiredProfileFieldLabels(learner);
  if (missingFieldLabels.isEmpty) {
    return true; // All fields complete
  }

  // Show dialog with missing fields
  final shouldOpenProfile = await showDialog<bool>(...);
  
  if (shouldOpenProfile != true) {
    return false; // User cancelled
  }

  // Open profile page for editing
  await Navigator.push(context, MaterialPageRoute(...));

  // Re-validate after editing
  final refreshedLearner = await _getLearnerForValidation(learnerId);
  final refreshedMissing = _getMissingRequiredProfileFieldLabels(refreshedLearner ?? {});

  if (refreshedMissing.isNotEmpty) {
    // Still incomplete - show warning
    return false;
  }

  return true; // All fields now complete
}
```

### Field Validation Helper

```dart
bool isMissingValue(dynamic value) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized.isEmpty ||
         normalized == 'null' ||
         normalized == 'n/a' ||
         normalized == 'na' ||
         normalized == '-';
}
```

---

## 2. Bank Details Completeness Check

### Method: `_ensureLearnerBankDetailsComplete(String learnerId, Map<String, dynamic>? learnerProfile)`

### Purpose
Ensures all required banking information is captured for stipend payments.

### Required Bank Fields (4 fields)

| Field Label | Database Key | Description |
|------------|-------------|-------------|
| Bank Name | `BankName` | Name of the bank |
| Account Type | `bankType` | Savings, Cheque, etc. |
| Account Number | `BankAccount` | Bank account number |
| Branch Code | `BankCode` | Bank branch code |

### Validation Logic

```dart
final List<_RequiredProfileRule> _requiredBankRules = const [
  _RequiredProfileRule(label: 'Bank Name', keys: ['BankName']),
  _RequiredProfileRule(label: 'Account Type', keys: ['bankType']),
  _RequiredProfileRule(label: 'Account Number', keys: ['BankAccount']),
  _RequiredProfileRule(label: 'Branch Code', keys: ['BankCode']),
];
```

### How It Works

1. **Fetch Bank Details (Multi-Source)**
   - **Priority 1**: Check online database via `check_bank_details.php` endpoint
   - **Priority 2**: Check local database if online fails
   - **Priority 3**: Use learner profile data if available
   - Merges all available data sources

2. **Online Bank Check**
   ```dart
   Future<Map<String, dynamic>?> _checkOnlineBankDetails(String learnerId) async {
     final url = Uri.parse(AppConfig.checkBankDetailsUrl);
     final response = await http.post(
       url,
       headers: {'Content-Type': 'application/json'},
       body: json.encode({'learner_id': learnerId}),
     );
     // Returns bank details if found on server
   }
   ```

3. **Check Missing Fields**
   - Validates all 4 required bank fields
   - Uses same `isMissingValue()` logic as profile check

4. **Show Snackbar if Incomplete**
   ```
   ┌─────────────────────────────────────────┐
   │ ⚠️ Missing bank details: Bank Name,    │
   │    Account Number                       │
   └─────────────────────────────────────────┘
   ```

5. **Show Bank Capture Dialog**
   - Opens dialog with form to capture missing bank details
   - Pre-fills any existing data
   - Provides dropdown for bank selection
   - Validates account number format

6. **Save Bank Details**
   - Saves to local database immediately
   - Attempts to sync to server if online
   - Marks as synced if server save succeeds

### Crash Prevention Features

The bank details check includes multiple crash prevention mechanisms:

```dart
// CRASH FIX: Immediate return if widget not mounted
if (!mounted) {
  print('[BANK_CAPTURE] Widget not mounted - returning true to prevent blocking');
  return true;
}

// CRASH FIX: Wrap dialog call in try-catch
try {
  final saved = await _showBankDetailsCaptureDialog(learnerId, bankData);
} catch (e) {
  print('[BANK_CAPTURE] Dialog error (ignored): $e');
}

// CRASH FIX: Always return true to prevent any blocking or crashes
return true;
```

**Important**: The bank details check is designed to be **non-blocking**. Even if there are errors or the widget is unmounted, it returns `true` to allow the clock-in process to continue. This prevents crashes while still encouraging users to complete bank details.

### Bank Capture Dialog

```
┌─────────────────────────────────────┐
│  Complete Bank Details              │
├─────────────────────────────────────┤
│  Bank Name: [Dropdown ▼]            │
│  Account Type: [Dropdown ▼]         │
│  Account Number: [________]          │
│  Branch Code: [________]             │
│                                     │
│  [Cancel]  [Save]                   │
└─────────────────────────────────────┘
```

### Supported Banks

```dart
final List<String> _banks = const [
  'ABSA Bank',
  'Capitec Bank',
  'First National Bank',
  'Nedbank',
  'Standard Bank',
  'Investec Bank',
  'Discovery Bank',
  'TymeBank',
  'African Bank',
  // ... more banks
];
```

---

## 3. Document Completeness Check

### Method: `_ensureLearnerDocumentsComplete(String learnerId)`

### Purpose
Ensures all required documents are scanned and uploaded before clock-in.

### Required Documents (5 documents)

```dart
final List<String> _requiredDocuments = const [
  'ID Document',
  'Qualifications',
  'Bank Confirmation Letter',
  'Proof of Residence',
  'CV',
];
```

### How It Works

1. **Check Missing Documents**
   - Queries local database for learner's documents
   - Compares against required documents list
   - Checks server for documents if online
   - Returns list of missing documents

2. **Show Dialog if Incomplete**
   ```
   ┌─────────────────────────────────────┐
   │  Missing Required Documents         │
   ├─────────────────────────────────────┤
   │  This learner has missing required  │
   │  documents. Scan all missing        │
   │  document(s) before clock-in.       │
   │                                     │
   │  - ID Document                      │
   │  - Bank Confirmation Letter         │
   │  - CV                               │
   │                                     │
   │  [Cancel] [Sync Documents]          │
   │           [Scan Next Document]      │
   └─────────────────────────────────────┘
   ```

3. **User Actions**
   - **Cancel**: Blocks clock-in, returns to learner list
   - **Sync Documents**: Checks server for documents that may have been uploaded elsewhere
   - **Scan Next Document**: Opens document scanner to capture missing document

4. **Document Selection**
   - Shows list of missing documents
   - User selects which document to scan
   - Opens document scanner (flutter_doc_scanner plugin)

5. **Document Scanning Process**
   ```
   User selects document type
       ↓
   Opens camera scanner
       ↓
   User scans document
       ↓
   Scanner processes and crops
       ↓
   Saves to local storage
       ↓
   Uploads to server (if online)
       ↓
   Marks as synced
       ↓
   Re-checks missing documents
       ↓
   Repeats until all documents scanned
   ```

6. **Document Sync**
   - Checks if document already exists on server
   - Uploads unsynced documents
   - Marks as synced in local database
   - Shows progress for each document

### Document Validation Loop

The document check uses a **while loop** to ensure all documents are captured:

```dart
Future<bool> _ensureLearnerDocumentsComplete(String learnerId) async {
  while (true) {
    final missingDocs = await _getMissingRequiredDocuments(learnerId);
    
    if (missingDocs.isEmpty) {
      await _syncLearnerDocumentsForLearner(learnerId);
      return true; // All documents complete
    }

    // Show dialog and handle user action
    final action = await showDialog<String>(...);
    
    if (action == 'sync') {
      await _syncLearnerDocumentsForLearner(learnerId);
      continue; // Re-check after sync
    }

    if (action != 'scan') {
      return false; // User cancelled
    }

    // Scan document
    final selectedDoc = await _pickMissingDocument(missingDocs);
    final scanned = await _scanAndSaveDocument(learnerId, selectedDoc);
    
    if (!scanned) {
      return false; // Scan failed
    }

    // Show remaining documents
    final stillMissing = await _getMissingRequiredDocuments(learnerId);
    if (stillMissing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved $selectedDoc. Remaining: ${stillMissing.join(', ')}'),
        ),
      );
    }
    // Loop continues until all documents scanned
  }
}
```

### Document Storage

**Local Storage:**
- Documents saved to app's document directory
- Path stored in local database
- Marked as unsynced (synced=0)

**Server Upload:**
- Uploads to `upload_learner_document.php` endpoint
- Includes learner ID and document type
- Marks as synced (synced=1) on success

### Document Normalization

Documents are normalized to handle variations in naming:

```dart
String normalizeRequiredDoc(String doc) {
  return doc
      .toLowerCase()
      .replaceAll(' ', '')
      .replaceAll('_', '')
      .replaceAll('-', '');
}

// Examples:
// "ID Document" → "iddocument"
// "Bank Confirmation Letter" → "bankconfirmationletter"
// "Proof of Residence" → "proofofresidence"
```

---

## Validation Execution in Clock-In Flow

### Location in Code

The validation checks are called in the `_verifyAndClockIn()` method:

```dart
Future<void> _verifyAndClockIn(String learnerId) async {
  // ... initial checks ...

  // VALIDATION STAGE 1: Profile Completeness
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Checking learner profile...'),
      duration: Duration(seconds: 1),
    ),
  );

  final profileIsComplete = await _ensureLearnerProfileComplete(learnerId);
  if (!profileIsComplete) {
    return; // BLOCKED - Profile incomplete
  }

  // VALIDATION STAGE 2: Bank Details Completeness
  print('[CLOCK_IN] SIMPLIFIED: Checking bank details completeness...');
  try {
    if (!mounted) {
      print('[CLOCK_IN] SIMPLIFIED: Widget not mounted - skipping bank check');
      return;
    }

    final strictBankOk = await _ensureLearnerBankDetailsComplete(
      learnerId,
      await _getLearnerForValidation(learnerId),
    );
    print('[CLOCK_IN] SIMPLIFIED: Bank details check result: $strictBankOk');
    
    // CRASH FIX: Don't block flow based on bank check result
    print('[CLOCK_IN] SIMPLIFIED: Bank details check completed - continuing flow');
  } catch (e) {
    print('[CLOCK_IN] SIMPLIFIED: ERROR in bank details check (ignored): $e');
    // Continue with flow - don't let bank details check block clock-in
  }

  // VALIDATION STAGE 3: Document Completeness
  print('[CLOCK_IN] Checking document completeness...');
  try {
    final documentsComplete = await _ensureLearnerDocumentsComplete(learnerId);
    print('[CLOCK_IN] Documents check result: $documentsComplete');

    if (!documentsComplete) {
      print('[CLOCK_IN] Documents incomplete - returning');
      return; // BLOCKED - Documents incomplete
    }
  } catch (e) {
    print('[CLOCK_IN] ERROR in documents check: $e');
    return; // BLOCKED - Error checking documents
  }

  // VALIDATION STAGE 4: Show Clocking Days Popup
  print('[CLOCK_IN] Showing clocking days popup...');
  try {
    await _showClockingDaysPopup(learnerId, 'in');
    print('[CLOCK_IN] Clocking days popup completed');
  } catch (e) {
    print('[CLOCK_IN] ERROR in clocking days popup: $e');
    return;
  }

  // All validations passed - proceed with fingerprint verification
  // ... fingerprint and geofencing checks ...
}
```

---

## Error Handling and User Experience

### Profile Check
- **Error**: "Could not load learner profile. Please try again."
- **Incomplete**: Shows dialog with list of missing fields
- **User Action**: Opens profile page for editing
- **Re-validation**: Checks again after editing
- **Still Incomplete**: Shows warning with remaining fields

### Bank Details Check
- **Error**: Silently handled, returns true to prevent blocking
- **Incomplete**: Shows snackbar with missing fields
- **User Action**: Opens bank capture dialog
- **Crash Prevention**: Multiple mounted checks and try-catch blocks
- **Non-Blocking**: Always returns true to allow clock-in to continue

### Document Check
- **Error**: Returns false, blocks clock-in
- **Incomplete**: Shows dialog with list of missing documents
- **User Actions**: 
  - Cancel: Blocks clock-in
  - Sync: Checks server for documents
  - Scan: Opens document scanner
- **Loop**: Continues until all documents scanned
- **Progress**: Shows remaining documents after each scan

---

## Data Sources Priority

### Profile Data
1. **Server** (if online) - Most up-to-date
2. **Local Database** (if offline) - Cached data
3. **Null** - Learner not found

### Bank Details Data
1. **Online Database** via `check_bank_details.php` - Most reliable
2. **Local Database** - Cached bank details
3. **Learner Profile** - Embedded bank fields
4. **Empty Map** - No data found

### Document Data
1. **Server** (if online) - Authoritative source
2. **Local Database** - Cached documents
3. **Empty List** - No documents found

---

## Configuration

### API Endpoints

```dart
// Profile data
final profileUrl = '${AppConfig.learnerDetailsUrl}?LearnerID=$learnerId';

// Bank details check
final bankUrl = AppConfig.checkBankDetailsUrl; // mobile/check_bank_details.php

// Document upload
final uploadUrl = AppConfig.buildUrl('upload_learner_document.php');

// Document sync
final syncUrl = AppConfig.buildUrl('sync_learner_documents.php');
```

### File Size Limits

```dart
final int _maxFileSize = 5 * 1024 * 1024; // 5MB
final int _minFileSize = 10 * 1024;       // 10KB
```

---

## Testing Scenarios

### Test 1: Complete Profile
1. Learner has all 19 profile fields filled
2. Click "Clock In"
3. ✅ Profile check passes immediately
4. Proceeds to bank details check

### Test 2: Incomplete Profile
1. Learner missing Name, ID Number, Profile Image
2. Click "Clock In"
3. ❌ Shows dialog: "Missing fields: Name, ID Number, Profile Image"
4. Click "Open Profile"
5. Fill in missing fields
6. Click "Update Data"
7. Returns to clock-in page
8. ✅ Profile check passes
9. Proceeds to bank details check

### Test 3: Complete Bank Details
1. Learner has all 4 bank fields filled
2. Profile check passes
3. ✅ Bank details check passes immediately
4. Proceeds to document check

### Test 4: Incomplete Bank Details
1. Learner missing Bank Name and Account Number
2. Profile check passes
3. ⚠️ Shows snackbar: "Missing bank details: Bank Name, Account Number"
4. Shows bank capture dialog
5. User fills in missing fields
6. Click "Save"
7. ✅ Bank details saved
8. Proceeds to document check (non-blocking)

### Test 5: Complete Documents
1. Learner has all 5 required documents
2. Profile and bank checks pass
3. ✅ Document check passes immediately
4. Shows clocking days popup
5. Proceeds to fingerprint verification

### Test 6: Incomplete Documents
1. Learner missing ID Document, CV
2. Profile and bank checks pass
3. ❌ Shows dialog: "Missing: ID Document, CV"
4. Click "Scan Next Document"
5. Select "ID Document"
6. Scan document with camera
7. ✅ ID Document saved
8. Shows: "Saved ID Document. Remaining: CV"
9. Click "Scan Next Document"
10. Select "CV"
11. Scan document
12. ✅ CV saved
13. ✅ All documents complete
14. Proceeds to clocking days popup

### Test 7: Sync Documents
1. Learner missing documents locally
2. Documents exist on server
3. Click "Sync Documents"
4. ✅ Documents downloaded from server
5. ✅ All documents complete
6. Proceeds to clocking days popup

---

## Benefits of Validation System

1. **Data Completeness**: Ensures all required information is captured
2. **Compliance**: Meets regulatory requirements for learner records
3. **Payment Processing**: Bank details required for stipend payments
4. **Audit Trail**: Documents provide proof of enrollment and qualifications
5. **User Guidance**: Clear feedback on what's missing
6. **Flexible**: Allows completion at clock-in time
7. **Non-Blocking**: Bank details check doesn't prevent clock-in
8. **Crash Prevention**: Multiple safety checks prevent app crashes
9. **Offline Support**: Works with local data when offline
10. **Progressive**: Can complete one section at a time

---

## Summary

The clock-in validation system ensures data completeness through three comprehensive checks:

1. **Profile Check** (19 fields) - BLOCKING
   - Validates all personal and demographic information
   - Opens profile page for editing if incomplete
   - Re-validates after editing

2. **Bank Details Check** (4 fields) - NON-BLOCKING
   - Validates banking information for payments
   - Shows capture dialog if incomplete
   - Crash-safe with multiple safety checks
   - Allows clock-in to continue even if incomplete

3. **Document Check** (5 documents) - BLOCKING
   - Validates required document uploads
   - Opens document scanner if incomplete
   - Loops until all documents captured
   - Syncs with server when online

All checks work offline with local data and sync when connectivity is available. The system provides clear user feedback and guidance throughout the validation process.
