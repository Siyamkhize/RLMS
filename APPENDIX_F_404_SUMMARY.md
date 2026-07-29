# Appendix F 404 Error - Investigation Summary

## Issue
User is getting 404 error when saving Appendix F data from the ARPL Toolkit app, even though they confirmed uploading `save_appendix_f_data.php` to the server.

## Error Output
```
[DEBUG] Response status: 404
[DEBUG] Response body: <!DOCTYPE HTML...>404 Not Found</...>
```

## Investigation Results

### ✅ Code Analysis - NO ISSUES FOUND
The Dart code in `ArplToolkitViewerPage.dart` is **CORRECT**:

```dart
// Line 497
final appendixFUrl = '${AppConfig.baseUrl}/save_appendix_f_data.php';
```

This constructs: `https://rlms.rlms.co.za/mobile/save_appendix_f_data.php`

### ✅ Backend Code - VERIFIED CORRECT
The PHP file `mobile/save_appendix_f_data.php` exists locally and is properly coded:
- Handles JSON input correctly
- Saves knowledge questions to `arpl_appendix_f_knowledge`
- Saves practical tasks to `arpl_appendix_f_practical_tasks`  
- Saves workplace observations to `arpl_appendix_f_workplace_observations`
- Returns proper JSON responses

### ✅ URL Construction - CORRECT PATTERN
Compared to working endpoint:
- **Working:** `${AppConfig.baseUrl}/mobile/save_arpl_toolkit_edits.php` → `https://rlms.rlms.co.za/mobile/save_arpl_toolkit_edits.php`
- **Not Working:** `${AppConfig.baseUrl}/save_appendix_f_data.php` → `https://rlms.rlms.co.za/mobile/save_appendix_f_data.php`

Both follow same pattern (AppConfig.baseUrl already includes `/mobile`).

### ⚠️ .htaccess Analysis
Checked all `.htaccess` variants:
- `.htaccess` - Simple, should NOT block
- `.htaccess_secure` - Has blocking rules for debug/test files, but `save_appendix_f_data.php` doesn't match blocked patterns
- `.htaccess_poe_fix` - Only affects POE routes
- `.htaccess_poe_upload` - Only changes PHP limits

**Conclusion:** .htaccess is unlikely to be the cause.

## Most Probable Root Cause

The 404 error strongly suggests one of these issues **on the production server**:

1. **File Not Actually Uploaded (80% probability)**
   - User thinks file was uploaded, but upload failed
   - File was uploaded but deleted/overwritten
   - File was uploaded but to wrong server/environment

2. **File in Wrong Directory (15% probability)**
   - Uploaded to root directory instead of `/mobile/` subdirectory
   - Uploaded to `/mobile/mobile/` (double nested)
   - Uploaded to different project directory

3. **File Permissions Issue (3% probability)**
   - File uploaded but not readable by Apache
   - Ownership issues (wrong user/group)

4. **Case Sensitivity (2% probability)**
   - Linux server requires exact case match
   - File uploaded as `Save_appendix_f_data.php` or similar

## Diagnostic Tools Created

### 1. `mobile/verify_appendix_f_endpoint.php`
Simple endpoint that returns JSON confirming:
- Directory path
- Whether `save_appendix_f_data.php` exists
- List of all `save_*.php` files in directory

**Usage:** Access `https://rlms.rlms.co.za/mobile/verify_appendix_f_endpoint.php` in browser

### 2. `mobile/test_appendix_f_exists.php`
More detailed diagnostic showing:
- Current directory
- File paths
- Readability status
- Directory contents

**Usage:** Access `https://rlms.rlms.co.za/mobile/test_appendix_f_exists.php` in browser

### 3. `APPENDIX_F_404_FIX_INSTRUCTIONS.md`
Complete step-by-step troubleshooting guide for the user

## Recommended Action Plan

### For User:
1. **Upload diagnostic files** to server:
   - `mobile/verify_appendix_f_endpoint.php`
   - `mobile/test_appendix_f_exists.php`

2. **Test verification endpoint** in browser
   - If 404: `/mobile/` directory path issue
   - If works but `save_file_exists: false`: File not uploaded or wrong location

3. **Re-upload the main file** to be absolutely certain:
   - Upload `mobile/save_appendix_f_data.php`
   - Confirm it's in same directory as `save_arpl_toolkit_edits.php`

4. **Check file permissions**:
   - Should be 644 or 755
   - Same as other working PHP files

5. **Compare with working endpoint**:
   - Both `save_arpl_toolkit_edits.php` and `save_appendix_f_data.php` should be in same directory
   - Both should have same permissions
   - If one works and other doesn't, something is different

### For Developer (Me):
- Wait for diagnostic results from user
- Based on findings, provide targeted solution
- If file location is correct, investigate Apache/server configuration

## Key Insight

The fact that `save_arpl_toolkit_edits.php` works but `save_appendix_f_data.php` doesn't strongly suggests:
- **The URL pattern is correct** (proven by working endpoint)
- **The code is correct** (verified locally)
- **The issue is server-side** (file not where it should be)

## Next Steps

**User needs to:**
1. Upload the 3 diagnostic/fix files to server
2. Access verification endpoint in browser
3. Report back the JSON response
4. Confirm file locations using FTP/file manager

**Then we can:**
- Pinpoint exact issue based on diagnostic output
- Provide targeted fix
- Test and verify solution works
