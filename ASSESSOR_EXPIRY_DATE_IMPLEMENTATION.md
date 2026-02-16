# Assessor Certificate Expiry Date Implementation

## Overview
Added a new field for assessor certificate expiry date to the FacilitatorProfile page and updated the local database to support this field.

## Changes Made

### 1. FacilitatorProfile.dart Updates
- **Added new controller**: `_assessorExpiryController` for the expiry date field
- **Added validation method**: `_validateAssessorExpiryDate()` with the following features:
  - Validates DD/MM/YYYY format
  - Checks for valid date ranges (2020-2050)
  - Warns if certificate has expired
  - Provides helpful error messages
- **Added UI field**: New date picker field for "Assessor Certificate Expiry Date" with:
  - Calendar icon and dropdown indicator
  - Native date picker dialog
  - Automatic date formatting (DD/MM/YYYY)
  - Real-time expiry warnings via snackbar
  - Read-only input (prevents manual typing errors)
- **Updated data handling**: 
  - Included expiry date in save operations
  - Added to API sync calls
  - Proper controller disposal
- **New methods added**:
  - `_buildDatePickerField()`: Creates the date picker input field
  - `_selectDate()`: Handles date selection and validation with user feedback

### 2. Database Updates (database_helper.dart)
- **Updated database version**: Incremented from 5 to 6
- **Added migration**: New migration for version 6 to add `assessorExpiryDate` column
- **Updated table creation**: Added `assessorExpiryDate TEXT` to facilitator table schema
- **Updated methods**: Modified `updateFacilitatorDetails()` to handle the new field

### 3. Server-Side Files Updated
- **add_assessor_expiry_column.sql**: SQL script to add the column to server database
- **get_facilitator_profile.php**: Updated to retrieve assessorExpiryDate field
- **save_facilitator.php**: Updated to save assessorExpiryDate field in both INSERT and UPDATE operations
- **save_facilitator_profile.php**: No changes needed (handles profile images only)

## Field Specifications

### Assessor Certificate Expiry Date
- **Input Method**: Date picker (tap to select date)
- **Format**: DD/MM/YYYY (e.g., 15/12/2025)
- **Date Range**: 2020 to 2050
- **Validation**: 
  - Required field
  - Must be valid date
  - Shows error if certificate has expired
  - Shows warning snackbar if expiring within 30 days
- **Database**: Stored as TEXT in `assessorExpiryDate` column
- **UI**: Positioned after Assessor Number field with calendar icon and dropdown indicator

## Database Migration
The app will automatically migrate existing databases from version 5 to 6, adding the new column. For server databases, run the provided SQL script:

```sql
ALTER TABLE facilitator ADD COLUMN assessorExpiryDate VARCHAR(10) DEFAULT NULL;
```

## Usage
1. Facilitators can now enter their assessor certificate expiry date
2. The system validates the date format and warns about expired certificates
3. Data is saved locally and synced to the server
4. The field appears in the "Contact Information" section of the profile

## Testing
- All Dart files compile without errors
- Database migration is properly implemented
- Validation works for various date formats and edge cases
- UI integrates seamlessly with existing profile fields

## Files Modified
- `lib/FacilitatorProfile.dart` - Added UI field and validation
- `lib/database_helper.dart` - Added database column and migration
- `get_facilitator_profile.php` - Updated to include assessorExpiryDate in SELECT query and response
- `save_facilitator.php` - Updated to handle assessorExpiryDate in both INSERT and UPDATE operations
- `add_assessor_expiry_column.sql` - SQL migration script for server database