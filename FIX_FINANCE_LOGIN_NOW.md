# Fix Finance Login - Complete Solution

## What We Fixed

### Backend (login.php)
✓ Role is normalized to lowercase
✓ Empty classID is returned for finance role
✓ Proper response structure

### Frontend (lib/main.dart)
✓ Role comparison is case-insensitive
✓ Debug logging added
✓ Navigation logic updated

## IMMEDIATE STEPS TO FIX

### Step 1: Verify Database Role
Run this in your database:

```sql
SELECT account_id, username, role, email FROM account_user;
```

**IMPORTANT:** The role MUST be exactly "finance" (lowercase, no spaces).

If it's not, fix it:
```sql
UPDATE account_user 
SET role = 'finance' 
WHERE username = 'your_finance_username';
```

### Step 2: Test Backend (Web Browser)
Open this URL in your browser:
```
https://rlms.rlms.co.za/mobile2025/test_finance_login.html
```

1. Enter your finance username and password
2. Click "Debug Login (Detailed)"
3. Check the output:
   - `is_finance` should be `true`
   - `normalized_role` should be `"finance"`
   - `would_return.role` should be `"finance"`

### Step 3: Upload Updated Files
Make sure these files are on your server:
- `login.php` (updated with role normalization)
- `check_finance_role.php` (diagnostic tool)
- `debug_finance_login.php` (diagnostic tool)
- `test_finance_login.html` (testing interface)

### Step 4: Rebuild Flutter App
```bash
# Clean the build
flutter clean

# Get dependencies
flutter pub get

# Build and install
flutter run
```

### Step 5: Test Login in App
1. Open the app
2. Enter finance credentials
3. Watch the debug console for these messages:

```
[LOGIN] Cleaned login response: {...}
[LOGIN] Parsed JSON data: {...}
[LOGIN] Extracted values:
[LOGIN]   - role: "finance"
[LOGIN]   - role.toLowerCase(): "finance"
[NAVIGATION] Role: "finance", classID: "", facilitator_id: "..."
[NAVIGATION] Navigating to Finance Dashboard
```

## Troubleshooting

### Problem: Still seeing facilitator interface

**Check 1: Database Role**
```sql
SELECT username, role, CHAR_LENGTH(role) as role_length 
FROM account_user 
WHERE username = 'your_username';
```
- Role should be exactly "finance" (7 characters)
- If it's "Finance" or " finance " or anything else, update it

**Check 2: Backend Response**
Use the test HTML page to verify login.php returns:
```json
{
  "success": true,
  "role": "finance",
  "facilitator_id": "123",
  "classID": "",
  "name": "...",
  "email": "..."
}
```

**Check 3: Flutter App**
- Did you rebuild the app after updating main.dart?
- Check debug logs - what role value is being received?
- Is the navigation log showing "Finance Dashboard" or "Facilitator Dashboard"?

### Problem: Login fails with "Invalid credentials"

**Check password in database:**
```sql
SELECT username, password, CHAR_LENGTH(password) as pwd_length 
FROM account_user 
WHERE username = 'your_username';
```

The password might be:
- MD5 hash (32 characters)
- Bcrypt hash (60 characters starting with $2y$)
- Plain text

Test with `debug_finance_login.php` to see which method works.

### Problem: App crashes or shows error

**Check for:**
- Missing fields in response (facilitator_id, classID, etc.)
- JSON parsing errors in logs
- Network connectivity issues

## Manual Database Fix (If Needed)

If the role in database is wrong:

```sql
-- Check current value
SELECT account_id, username, role, 
       HEX(role) as role_hex,
       CHAR_LENGTH(role) as role_length
FROM account_user;

-- Fix the role
UPDATE account_user 
SET role = 'finance' 
WHERE account_id = YOUR_ACCOUNT_ID;

-- Verify the fix
SELECT username, role FROM account_user WHERE account_id = YOUR_ACCOUNT_ID;
```

## Expected Behavior After Fix

1. **Login Screen:**
   - Enter finance credentials
   - Click login

2. **Debug Console Shows:**
   ```
   [LOGIN] Cleaned login response: {"success":true,"role":"finance",...}
   [NAVIGATION] Role: "finance"
   [NAVIGATION] Navigating to Finance Dashboard
   ```

3. **App Shows:**
   - Finance Dashboard with your name
   - List of classes
   - Can click on class to see learners
   - Can scan registers for each learner

## Files Modified

1. **login.php** - Role normalization and response structure
2. **lib/main.dart** - Navigation logic and debug logging
3. **New diagnostic files:**
   - check_finance_role.php
   - debug_finance_login.php
   - test_finance_login.html

## Quick Test Checklist

- [ ] Database role is exactly "finance" (lowercase)
- [ ] test_finance_login.html shows correct response
- [ ] Flutter app rebuilt with `flutter clean && flutter run`
- [ ] Debug logs show "Navigating to Finance Dashboard"
- [ ] Finance Dashboard appears with classes

## Still Not Working?

Run these diagnostics and share the output:

1. **Database check:**
   ```sql
   SELECT * FROM account_user WHERE username = 'your_username';
   ```

2. **Backend test:**
   Open `test_finance_login.html` and click "Debug Login"

3. **Flutter logs:**
   Copy all lines starting with `[LOGIN]` and `[NAVIGATION]`

This will help identify the exact issue.
