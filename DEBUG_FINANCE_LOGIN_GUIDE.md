# Debug Finance Login - Step by Step Guide

## Problem
Finance user can log in but sees facilitator interface instead of finance dashboard.

## Debugging Steps

### Step 1: Check Database Role Value
Open in browser:
```
https://rlms.rlms.co.za/mobile2025/check_finance_role.php
```

This will show:
- All users in `account_user` table
- Their exact role values (raw, trimmed, lowercase)
- Role byte representation (to detect hidden characters)

**Look for:**
- Is the role exactly "finance" or "Finance" or something else?
- Are there any extra spaces or hidden characters?

### Step 2: Test Login via Web
Open in browser:
```
https://rlms.rlms.co.za/mobile2025/test_finance_login.html
```

1. Click "Check account_user Table" to see all users
2. Enter your username and password
3. Click "Test Login" to see what login.php returns
4. Click "Debug Login (Detailed)" to see detailed analysis

**Look for:**
- Does `role` in the response equal "finance"?
- Is `success` true?
- Is `classID` empty string?

### Step 3: Check Flutter App Logs
When you log in via the mobile app, check the debug console for these messages:

```
[LOGIN] Cleaned login response: {...}
[LOGIN] Parsed JSON data: {...}
[LOGIN] Full login response: {...}
[LOGIN] Extracted values:
[LOGIN]   - role: "..."
[LOGIN]   - facilitator_id: "..."
[LOGIN]   - classID: "..."
[LOGIN]   - role.toLowerCase(): "..."
[NAVIGATION] Role: "...", classID: "...", facilitator_id: "..."
[NAVIGATION] Navigating to Finance Dashboard
```

**Look for:**
- What is the exact role value?
- Does it say "Navigating to Finance Dashboard" or "Navigating to Facilitator Dashboard"?

## Common Issues and Solutions

### Issue 1: Role is capitalized ("Finance" instead of "finance")
**Solution:** Already fixed in login.php with `strtolower()`

### Issue 2: Role has extra spaces
**Solution:** Already fixed in login.php with `trim()`

### Issue 3: Role in database is not "finance"
**Solution:** Update the database:
```sql
UPDATE account_user SET role = 'finance' WHERE username = 'your_username';
```

### Issue 4: Flutter app not receiving correct response
**Check:**
- Is the response being cleaned correctly?
- Are there HTML tags or extra content in the response?
- Check the raw response in the logs

### Issue 5: Navigation logic not matching
**Check:**
- Does the role comparison in `_navigateBasedOnRole()` match?
- Is the role being normalized to lowercase in Flutter?

## Quick Fix Commands

### If role in database is wrong:
```sql
-- Check current role
SELECT username, role FROM account_user WHERE username = 'your_username';

-- Fix role to lowercase 'finance'
UPDATE account_user SET role = 'finance' WHERE username = 'your_username';
```

### If you need to rebuild the app:
```bash
flutter clean
flutter pub get
flutter run
```

## Files to Check

1. **login.php** - Lines 180-210 (account_user login section)
2. **lib/main.dart** - Lines 586-650 (_navigateBasedOnRole function)
3. **Database** - account_user table, role column

## Expected Flow

1. User enters credentials
2. login.php checks account_user table
3. Password is verified (MD5, Bcrypt, or plain text)
4. Role is normalized: `strtolower(trim($row['role']))`
5. Response returned:
   ```json
   {
     "success": true,
     "role": "finance",
     "facilitator_id": "123",
     "classID": "",
     "name": "Finance User",
     "email": "finance@example.com"
   }
   ```
6. Flutter receives response
7. Role is normalized: `role.toLowerCase().trim()`
8. Navigation checks: `if (normalizedRole == 'finance')`
9. Navigates to FinanceDashboard

## Next Steps

1. Run `check_finance_role.php` to see the exact role value in database
2. Run `test_finance_login.html` to test the login endpoint
3. Check Flutter debug logs when logging in via app
4. Share the results so we can identify the exact issue
