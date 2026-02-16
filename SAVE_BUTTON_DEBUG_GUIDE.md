# Save Button Debug Guide

## Issue
The save button in FacilitatorProfile.dart is not responding or providing feedback when pressed.

## Debugging Steps Added

### 1. Enhanced Error Handling
- Added comprehensive try-catch blocks with detailed error messages
- Added loading indicator when save process starts
- Added stack trace logging for debugging

### 2. Debug Logging
Added debug prints to track the save process:
- `[PROFILE] Save button pressed` - Confirms button press
- `[PROFILE] Form validation passed/failed` - Confirms validation status
- `[PROFILE] Updated data: {...}` - Shows data being saved
- `[DB] updateFacilitatorDetails called` - Confirms database method called
- `[DB] Update result: X rows affected` - Shows database update result
- `[PROFILE] Starting online sync` - Confirms sync process starts
- `[PROFILE] Sync attempt X/3` - Shows retry attempts
- `[PROFILE] Server response status/body` - Shows server communication

### 3. User Feedback Improvements
- Loading snackbar when save starts
- Clear error messages if validation fails
- Success message when save completes
- Detailed error messages if save fails

## How to Debug

### Step 1: Check Flutter Console
Run the app and press the save button. Look for these debug messages in the Flutter console:

1. **Button Press**: Should see `[PROFILE] Save button pressed`
2. **Validation**: Should see `[PROFILE] Form validation passed` or validation error
3. **Database**: Should see `[DB] updateFacilitatorDetails called` and update result
4. **Sync**: Should see sync attempt messages and server responses

### Step 2: Check for Common Issues

#### Issue: Button not responding at all
- **Symptom**: No debug messages appear
- **Cause**: Button might not be in editing mode
- **Solution**: Tap edit button first, then save

#### Issue: Validation failing silently
- **Symptom**: See `[PROFILE] Form validation failed` but no visible errors
- **Cause**: Date field might have invalid format
- **Solution**: Check assessor expiry date is properly selected

#### Issue: Database update failing
- **Symptom**: See database error in logs
- **Cause**: Database column might not exist
- **Solution**: Ensure database migration ran (version should be 6)

#### Issue: Server sync failing
- **Symptom**: See sync errors in logs
- **Cause**: Server endpoint issues or network problems
- **Solution**: Check server logs and network connectivity

### Step 3: Test Scenarios

#### Test 1: Basic Save
1. Tap edit button (pencil icon)
2. Modify phone number
3. Select assessor expiry date
4. Tap save button (should show loading, then success)

#### Test 2: Validation Test
1. Tap edit button
2. Clear phone number field
3. Tap save button (should show validation error)

#### Test 3: Date Picker Test
1. Tap edit button
2. Tap assessor expiry date field
3. Select a past date (should show expiry warning)
4. Select future date and save

## Expected Behavior

### Successful Save Flow:
1. Loading snackbar appears
2. Form validates successfully
3. Data saves to local database
4. Data syncs to server (if online)
5. Success snackbar appears
6. Edit mode turns off
7. Form refreshes with saved data

### Error Scenarios:
- **Validation Error**: Red snackbar with specific field errors
- **Database Error**: Red snackbar with database error details
- **Network Error**: Orange snackbar about no internet, but local save succeeds
- **Server Error**: Red snackbar with server error details

## Quick Fixes

### If save button doesn't respond:
1. Ensure you're in edit mode (tap pencil icon first)
2. Check Flutter console for error messages
3. Try restarting the app

### If validation always fails:
1. Check all required fields are filled
2. Ensure assessor expiry date is selected (not manually typed)
3. Check phone number format (SA format: 082 123 4567)

### If database errors occur:
1. Clear app data to trigger database recreation
2. Check database version is 6 in logs
3. Verify assessorExpiryDate column exists

The enhanced debugging should now provide clear visibility into what's happening during the save process.