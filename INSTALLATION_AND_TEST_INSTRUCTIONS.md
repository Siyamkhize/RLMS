# Installation and Testing Instructions - Bricklayer Appendix D Fix
## July 10, 2026

### ✅ What Was Fixed

**Problem:** Bricklayer toolkit was crashing with:
```
Error: type 'List<dynamic>' is not a subtype of type 'Map<dynamic, dynamic>'
```

**Root Cause:** Appendix D was being returned from the API as an empty array `[]` instead of an object `{}`

**Solution Applied:** 
- Updated `mobile/get_bricklayer_toolkit_data.php` to properly initialize and populate appendixD as an object
- Now uses `(object)[]` initialization and `->` operator for property assignment (matching electrician pattern)
- APK has been rebuilt (45.9 MB)

---

### 📱 Installation Steps

#### Step 1: Get the APK
The APK is located at:
```
c:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk
```

#### Step 2: Install on Device
**Option A - Using USB Cable (Recommended):**
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**Option B - Transfer Manually:**
1. Copy APK to a location accessible on your device
2. Open file manager on Android device
3. Navigate to the APK file
4. Tap to install
5. Confirm installation

#### Step 3: Verify Installation
1. Open the app
2. You should see no crashes on startup

---

### 🧪 Testing Steps

#### Phase 1: Navigation Test
1. **Open RLMSS App**
2. **Login** with your credentials
3. **Select a Bricklaying class** (from the class list)
4. **Select a learner** from that class
5. **Navigate to ARPL Toolkit**
   - Should see "ARPL Toolkit - Bricklayer" form
   - Tabs should load: Cover, Appendix A, B, C, D, E, F, G, H, I, J

#### Phase 2: Appendix D Data Load Test

1. **Click the "Appendix D" tab**
   - Expected: Form should load with 22 practical skills questions
   - If error: Screen will show error message

2. **Check for Debug Logs** (connect device with ADB)
   ```bash
   adb logcat | grep -i "BRICKLAYER\|ArplToolkitData"
   ```
   
   **Expected Success Pattern:**
   ```
   [BRICKLAYER_TRACE] appendixD type: _LinkedHashMap
   [ArplToolkitData.fromJson] Parsing appendixD...
   [ArplToolkitData.fromJson] ✓ AppendixD parsed
   [BRICKLAYER_TRACE] ✅ ArplToolkitData parsed successfully
   ```
   
   **Failure Pattern (would indicate problem):**
   ```
   [ArplToolkitData.fromJson] Error: type 'List<dynamic>' is not a subtype of type 'Map<dynamic, dynamic>'
   ```

3. **Verify Appendix D Display**
   - Title: "Appendix D: PRACTICAL SKILLS ASSESSMENT"
   - Items should include:
     - Safety and health procedures
     - Hand and power tools
     - Measuring and marking equipment
     - Reading and interpreting architectural drawings
     - Selection and identification of materials
     - Mortar mix design and preparation
     - (and 16 more bricklaying-specific items)
   - Response options: Yes, No, Not Applicable

#### Phase 3: Data Persistence Test

1. **Select a response** for one activity (e.g., click "Yes" for activity 1)
2. **Save the form** (if save button is available)
3. **Navigate away** from Appendix D
4. **Come back to Appendix D**
   - Previous selections should still be visible

#### Phase 4: Appendix E & F Verification

1. **Click "Appendix E" tab**
   - Should show workplace experience activities
   - If data was saved, previous ratings should display

2. **Click "Appendix F" tab**
   - Should show practical assessment section
   - Workplace observations should load

---

### 🐛 Troubleshooting

#### Issue: Still Getting Type Mismatch Error

**Possible Causes:**
1. Old APK still installed
2. Data cache not cleared
3. Device needs restart

**Solutions:**
```bash
# Uninstall old version
adb uninstall com.example.rlmss

# Clear app data and cache
adb shell pm clear com.example.rlmss

# Reinstall APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Restart device
adb reboot
```

#### Issue: Appendix D Tab Shows "Coming Soon"

**Possible Causes:**
1. No data exists for this learner in database
2. Bricklayer-specific database table not created

**Check Database:**
```sql
-- Verify table exists
SHOW TABLES LIKE 'arpl_appendix_d_bricklayer';

-- Check for data
SELECT * FROM arpl_appendix_d_bricklayer WHERE learnerID = 70;

-- If no table, create it
CREATE TABLE IF NOT EXISTS arpl_appendix_d_bricklayer (
    id INT PRIMARY KEY AUTO_INCREMENT,
    learnerID INT NOT NULL,
    activity_1 VARCHAR(50),
    activity_2 VARCHAR(50),
    -- ... activity_3 through activity_21 ...
    activity_22 VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (learnerID) REFERENCES learnerdetails(LearnerID)
);
```

#### Issue: Appendix E Shows Empty

**Possible Causes:**
1. Workplace activities not loaded from database
2. OFO number mismatch (should be 641201 for bricklayer)

**Check Database:**
```sql
-- Verify activities exist
SELECT * FROM arplappxe_bricklaying_activities 
WHERE ofo_number = '641201' 
LIMIT 5;

-- If empty, activities need to be populated
SELECT COUNT(*) FROM arplappxe_bricklaying_activities;
```

---

### 📋 Expected Behavior After Fix

| Component | Before | After |
|-----------|--------|-------|
| Appendix D Load | ❌ Crash with type error | ✅ Loads 22 questions |
| Data Type | ❌ Array `[]` | ✅ Object `{}` |
| Dart Parsing | ❌ Fails | ✅ Succeeds |
| Debug Logs | ❌ FATAL ERROR | ✅ ✓ AppendixD parsed |
| UI Display | ❌ Error screen | ✅ Questions visible |

---

### 📊 Log Verification Checklist

Run this command and verify the output:

```bash
adb logcat -s BRICKLAYER_TRACE,ArplToolkitData.fromJson | grep -E "BRICKLAYER_TRACE|ArplToolkitData|AppendixD"
```

**You should see:**
- ✅ `[BRICKLAYER_TRACE] ═══ TYPE CHECKING ═══`
- ✅ `[BRICKLAYER_TRACE] appendixD type: _LinkedHashMap` (or similar object type)
- ✅ `[ArplToolkitData.fromJson] Parsing appendixD...`
- ✅ `[ArplToolkitData.fromJson] ✓ AppendixD parsed`
- ✅ `[BRICKLAYER_TRACE] ✅ ArplToolkitData parsed successfully`

**You should NOT see:**
- ❌ `type 'List<dynamic>' is not a subtype of type 'Map<dynamic, dynamic>'`
- ❌ `═══ FATAL ERROR ═══`
- ❌ `Error parsing data`

---

### 🔧 API Endpoint Information

**Endpoint:** `POST /mobile/get_bricklayer_toolkit_data.php`

**Request Format:**
```json
{
  "learnerID": 70,
  "classID": 783
}
```

**Response Format (Relevant Section):**
```json
{
  "status": "success",
  "appendixD": {
    "activity_1": "Yes",
    "activity_2": "No",
    "activity_3": "Yes",
    ...
    "activity_22": "Not Applicable",
    "saved_at": "2026-07-10 12:45:00"
  },
  "appendixE": [...],
  "appendixF": {...},
  ...
}
```

**Data Type Check:**
```
Before Fix: appendixD type = Array (json_decode returns array)
After Fix:  appendixD type = stdClass Object (json_encode(object))
Dart Type:  Map<String, String>
```

---

### 📞 Support Information

**If the issue persists:**

1. **Collect logs:**
   ```bash
   adb logcat > logcat_output.txt
   # Wait 30 seconds while reproducing the issue
   # Ctrl+C to stop
   ```

2. **Check database directly:**
   ```bash
   mysql -u user -p database_name
   SHOW TABLES LIKE 'arpl_%_bricklayer';
   SELECT COUNT(*) FROM arpl_appendix_d_bricklayer;
   ```

3. **Verify API endpoint directly:**
   - Use Postman or curl to test:
   ```bash
   curl -X POST http://192.168.0.57:8080/assessorReport2/mobile/get_bricklayer_toolkit_data.php \
     -H "Content-Type: application/json" \
     -d '{"learnerID": 70, "classID": 783}'
   ```

---

### ✨ Summary

- **Build Date:** July 10, 2026
- **APK Size:** 45.9 MB  
- **Files Modified:** `mobile/get_bricklayer_toolkit_data.php`
- **Type Fix:** Object initialization pattern
- **Status:** ✅ READY FOR TESTING

---

**Next Steps:** Install the APK and follow the testing steps above. Report any issues with the debug log output.

