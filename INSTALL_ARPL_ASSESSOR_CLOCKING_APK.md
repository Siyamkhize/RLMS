# Install ARPL Assessor Fingerprint Clocking APK

## APK Details
- **File**: `C:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk`
- **Size**: 45.9 MB
- **Build Date**: July 16, 2026
- **Version**: Latest with ARPL Assessor fingerprint clocking

## Installation Methods

### Method 1: USB Cable Installation (Recommended)

1. **Connect Device**:
   - Connect the Android device to PC via USB cable
   - Enable USB Debugging on the device:
     - Go to Settings → About Phone
     - Tap "Build Number" 7 times to enable Developer Options
     - Go to Settings → Developer Options
     - Enable "USB Debugging"
   - Accept the "Allow USB Debugging" prompt on the device

2. **Restart ADB Server** (if needed):
   ```powershell
   adb kill-server
   adb start-server
   adb devices
   ```
   - Should show your device ID

3. **Install APK**:
   ```powershell
   cd C:\projects\rlmss
   adb install -r build\app\outputs\flutter-apk\app-release.apk
   ```
   - The `-r` flag reinstalls the app (keeps data)

### Method 2: Copy APK to Device

1. **Copy APK File**:
   - Copy `C:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk` to your device
   - Options:
     - USB cable → Copy to Downloads folder
     - Upload to Google Drive → Download on device
     - Email to yourself → Download attachment
     - Use file sharing app (e.g., ShareIt, Google Files)

2. **Install on Device**:
   - Open File Manager on the device
   - Navigate to where you copied the APK
   - Tap the APK file
   - Tap "Install"
   - If prompted, allow "Install from Unknown Sources" for that app
   - Wait for installation to complete
   - Tap "Open" to launch

### Method 3: Transfer via Cloud Storage

1. **Upload APK**:
   - Upload `app-release.apk` to Google Drive, Dropbox, or OneDrive

2. **Download on Device**:
   - Open cloud storage app on device
   - Download the APK file

3. **Install**:
   - Open Downloads in File Manager
   - Tap the APK file
   - Install as described above

## What's New in This Build

### ARPL Assessor Fingerprint Clocking
✅ **Assessor Self-Clocking**:
- Scan fingerprint to clock in
- Scan fingerprint to clock out
- Uses same system as facilitators
- Supports ZKTeco and Futronic scanners
- Signature fallback if no scanner

✅ **Learner Clocking**:
- Learners use fingerprint to clock in/out
- Real-time status updates
- Offline support with auto-sync

✅ **Mandatory Clock-In**:
- Prompt appears after login for assessors
- Must clock in before accessing dashboard
- Can skip or clock in immediately

### Database Fixes
✅ Fixed table names: `facilitator_clocking` (not `facilitator_attendance`)
✅ Fixed column names: `clock_in_time`, `clock_out_time`, `clock_date`
✅ Fixed learner table: `learnerdetails` (not `learners`)

## Testing Checklist

After installation, test the following:

### 1. Login
- ⬜ Login as ARPL Assessor (Facilitator ID: 6)
- ⬜ Mandatory clock-in prompt should appear
- ⬜ "Skip" button closes dialog
- ⬜ "Clock In Now" button opens fingerprint page

### 2. Fingerprint Enrollment (First Time)
- ⬜ Fingerprint page opens
- ⬜ Scanner detection dialog asks about scanner availability
- ⬜ If scanner available, initializes correctly
- ⬜ Enrollment instructions display
- ⬜ Can enroll left thumb fingerprint
- ⬜ Can enroll right thumb fingerprint
- ⬜ Enrollment saves to database

### 3. Assessor Clock In
- ⬜ From dashboard, tap "Clock In/Out" menu
- ⬜ Shows two tabs: "My Clock In/Out" and "Learner Clocking"
- ⬜ On "My Clock In/Out" tab, shows current status
- ⬜ Tap "Scan Fingerprint to Clock In" button
- ⬜ Fingerprint scanner page opens
- ⬜ Scanner prompts to place finger
- ⬜ Scan enrolled fingerprint
- ⬜ Verifies fingerprint
- ⬜ Clocks in successfully
- ⬜ Shows success message
- ⬜ Returns to clocking page
- ⬜ Status shows "Currently Clocked In"

### 4. Assessor Clock Out
- ⬜ Tap "Scan Fingerprint to Clock Out" button
- ⬜ Scanner page opens
- ⬜ Scan enrolled fingerprint
- ⬜ Verifies fingerprint
- ⬜ Clocks out successfully
- ⬜ Shows success message
- ⬜ Status shows "Not Clocked In"

### 5. Learner Clocking
- ⬜ Tap "Learner Clocking" tab
- ⬜ Shows list of assigned classes
- ⬜ Tap a class
- ⬜ Opens ClockInPage with learners
- ⬜ Tap a learner
- ⬜ Learner scans their fingerprint
- ⬜ System clocks learner in/out
- ⬜ Shows visual feedback
- ⬜ Updates learner list

### 6. Offline Mode
- ⬜ Turn off WiFi and mobile data
- ⬜ Clock in with fingerprint
- ⬜ Data saves locally
- ⬜ Turn on connectivity
- ⬜ Data syncs to server automatically

### 7. Database Verification
Check that data is saved correctly:

**Query for assessor clocking**:
```sql
SELECT * FROM facilitator_clocking 
WHERE facilitator_id = 6 
ORDER BY clock_date DESC, clock_in_time DESC 
LIMIT 5;
```

Expected columns:
- `clocking_id`
- `facilitator_id` = 6
- `clock_date` = today's date (YYYY-MM-DD)
- `clock_in_time` = timestamp
- `clock_out_time` = timestamp or NULL
- `contact_time`, `user_latitude`, `user_longitude`, `user_accuracy`

## Troubleshooting

### Issue: "App not installed"
**Solution**: 
- Uninstall the old version first
- Settings → Apps → RLMSS → Uninstall
- Then install the new APK

### Issue: "Install from Unknown Sources blocked"
**Solution**:
- Settings → Security
- Enable "Unknown Sources" or "Install Unknown Apps"
- Allow for the app you're using to install (e.g., Chrome, File Manager)

### Issue: Scanner not detected
**Solution**:
- Check USB connection to scanner
- Check scanner power
- Try unplugging and replugging scanner
- Tap "Refresh Scanner Connection" button
- If still not working, use signature fallback

### Issue: Fingerprint verification fails
**Solution**:
- Clean the scanner surface
- Clean your finger
- Place finger firmly on scanner
- Try the other enrolled finger
- Re-enroll fingerprint if persistent issues

### Issue: Clock status not updating
**Solution**:
- Pull down to refresh the page
- Check if clocking was saved to database
- Check internet connection for sync
- Restart the app

## Test Credentials
- **Facilitator ID**: 6
- **Role**: `arpl_Assessor`
- **Name**: [From database]
- **ClassID**: 797
- **OFO Code**: 641201 (Bricklayer)
- **Test Learner**: Anele Cele, ID: 9201151070088, LearnerID: 11701

## Support Files
- Build documentation: `ARPL_ASSESSOR_FINGERPRINT_CLOCKING_COMPLETE.md`
- Table fixes: `ARPL_ASSESSOR_CLOCKING_TABLE_NAMES_FIXED.md`

## Notes
- This build includes fingerprint scanning for ARPL Assessors
- Assessors use the same clocking system as facilitators
- Learners use fingerprint scanning via ClockInPage
- All clocking operations require biometric verification (or signature)
- Data syncs automatically when online
- Offline support fully functional
