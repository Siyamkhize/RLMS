# Learner Edit Implementation

## Overview
This implementation adds the ability to edit learner information from the LearnerDetailsPage in the Flutter app, with LearnerID and classID protected from editing.

## Files Modified/Created

### 1. Flutter App - `lib/LearnerDetailsPage.dart`
**Changes Made:**
- Modified `_buildDataList()` method to make all fields editable except LearnerID and classID
- Added visual indicators for read-only fields:
  - Lock icon (🔒) next to field name
  - Grey background on the card
  - Grey background in the text field
  - Grey text color
- Fields are set as `readOnly: true` and `enabled: false` for LearnerID and classID

**How It Works:**
- All learner data is displayed in TextFormField widgets with controllers
- Users can edit any field except LearnerID and classID
- The existing "Update Learner Data" button saves changes
- The `_updateLearnerInformation()` method sends updates to the server

### 2. PHP Backend - `update_learner.php`
**New File Created**

**Features:**
- Accepts JSON POST requests with LearnerID and data to update
- Separates learner data from bank data automatically
- Updates `learnerdetails` table for learner information
- Updates or inserts into `bankdetails` table for bank information
- Uses database transactions for data integrity
- Protects LearnerID, classID, and synced fields from being updated

**Request Format:**
```json
{
  "LearnerID": "123",
  "data": {
    "Name": "John",
    "PhoneNumber": "0123456789",
    "Email": "john@example.com",
    "BankName": "FNB",
    "BankAccount": "1234567890"
  }
}
```

**Response Format:**
```json
{
  "success": true,
  "message": "Learner information updated successfully",
  "updated_fields": ["Name", "PhoneNumber", "Email", "BankName", "BankAccount"]
}
```

**Error Handling:**
- Validates required fields (LearnerID, data)
- Uses transactions to ensure data consistency
- Returns appropriate HTTP status codes
- Logs errors for debugging

### 3. Test File - `test_update_learner.php`
**New File Created**

**Test Cases:**
1. Update learner personal information
2. Update bank details only
3. Update both learner and bank information
4. Try to update protected fields (should be ignored)
5. Error case - Missing LearnerID
6. Error case - Empty data

**How to Use:**
1. Update the LearnerID in the test file to match an existing learner
2. Access via browser: `http://localhost/test_update_learner.php`
3. Review the test results

## Security Features

### Protected Fields
The following fields CANNOT be updated via the API (system-managed fields):

**Identity & Classification:**
- `LearnerID` - Primary identifier
- `classID` - Class assignment

**System Status:**
- `synced` - Sync status flag

**Biometric & Signature Data:**
- `signature` - Learner signature image
- `witness_signature` - Witness signature image
- `learner_initials` - Learner initials
- `witness_initials` - Witness initials
- `zkteco_left_template` - ZKTeco left fingerprint template
- `zkteco_right_template` - ZKTeco right fingerprint template
- `futronic_left_template` - Futronic left fingerprint template
- `futronic_right_template` - Futronic right fingerprint template
- `sourceafis_template` - SourceAFIS fingerprint template

**Media & Activity:**
- `profile_image` - Profile image path
- `imagePath` - Additional image path
- `activity_statu` - Activity status

These fields are filtered out in the PHP backend even if sent in the request, and are displayed as read-only in the Flutter app with lock icons and "System" labels.

### Visual Indicators in App
Read-only fields are clearly marked with:
- Lock icon
- Grey background
- Disabled input state

## Database Tables

### learnerdetails
Contains all learner personal information:
- Personal details (Name, Surname, IDNumber, etc.)
- Contact information (PhoneNumber, Email)
- Address information (AddressLine1, AddressLine2, etc.)
- School information (SchoolName, SchoolCompletion, etc.)
- Next of kin information (KinName, KinRelation, KinContact)
- Signatures and images

### bankdetails
Contains bank information:
- BankName
- bankType
- BankAccount
- BankCode
- LearnerID (foreign key)

## Usage Flow

1. **User Opens Learner Details:**
   - App fetches learner data from server or local database
   - All fields are displayed in editable TextFormFields
   - LearnerID and classID are shown as read-only with lock icons

2. **User Edits Information:**
   - User can modify any field except LearnerID and classID
   - Changes are stored in the TextEditingController for each field

3. **User Clicks "Update Learner Data":**
   - App calls `_updateLearnerInformation()` method
   - Method compares current values with original values
   - Only changed fields are sent to the server
   - Request is sent to `update_learner.php`

4. **Server Processes Update:**
   - Validates request data
   - Separates learner data from bank data
   - Filters out protected fields
   - Updates database tables in a transaction
   - Returns success/error response

5. **App Shows Result:**
   - Success: Shows green snackbar, refreshes data
   - Error: Shows red snackbar with error message

## Deployment Checklist

- [ ] Upload `update_learner.php` to server
- [ ] Ensure `connection.php` is configured correctly
- [ ] Test with `test_update_learner.php`
- [ ] Verify database permissions for UPDATE operations
- [ ] Test offline functionality (local database updates)
- [ ] Verify that LearnerID and classID cannot be changed
- [ ] Test with various field combinations
- [ ] Test bank details update (existing and new records)

## API Endpoint

**URL:** `http://your-server.com/update_learner.php`

**Method:** POST

**Content-Type:** application/json

**Request Body:**
```json
{
  "LearnerID": "string (required)",
  "data": {
    "field_name": "field_value",
    ...
  }
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Learner information updated successfully",
  "updated_fields": ["field1", "field2", ...]
}
```

**Error Response (400/500):**
```json
{
  "success": false,
  "message": "Error description"
}
```

## Notes

- The implementation maintains backward compatibility with existing code
- Offline updates are saved locally and synced when online
- Bank details are automatically created if they don't exist
- All updates use database transactions for data integrity
- Protected fields are silently ignored if included in update request
