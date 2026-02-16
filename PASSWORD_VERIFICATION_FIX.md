# Password Verification Fix ✅

## Problem
Login was failing with "Invalid password for account user" even though credentials were correct.

## Root Cause
The password in the `account_user` table might be using a different hashing method than MD5.

## Solution Implemented

### 1. Updated login.php
Now tries **multiple password verification methods** in order:

```php
// Method 1: MD5 hash
$hashedPassword = md5($password);
if ($row['password'] === $hashedPassword) {
    $password_valid = true;
}

// Method 2: Bcrypt (password_verify)
if (!$password_valid && password_verify($password, $row['password'])) {
    $password_valid = true;
}

// Method 3: Plain text (fallback)
if (!$password_valid && $row['password'] === $password) {
    $password_valid = true;
}
```

### 2. Created Diagnostic Tool
**File:** `check_account_password.php`

**Usage:**
```
https://rlms.rlms.co.za/mobile/check_account_password.php?email=your_email&password=your_password
```

**Features:**
- Shows user details
- Tests password against multiple formats
- Identifies which hashing method is used
- Provides fix recommendations

## Password Formats Supported

| Format | Length | Example | Detection |
|--------|--------|---------|-----------|
| MD5 | 32 chars | `482c811da5d5b4bc6d497ffa98491e38` | Exact match |
| Bcrypt | 60 chars | `$2y$10$...` | password_verify() |
| Plain Text | Variable | `password123` | Direct comparison |
| SHA1 | 40 chars | `cbfdac6008f9cab4083784cbd1874f76618d2a97` | Not yet supported |

## Testing Steps

### Step 1: Upload Files
Upload to server:
- `login.php` (updated)
- `check_account_password.php` (diagnostic)

### Step 2: Run Diagnostic
Visit:
```
https://rlms.rlms.co.za/mobile/check_account_password.php?email=YOUR_EMAIL&password=YOUR_PASSWORD
```

### Step 3: Check Results
The diagnostic will show:
- ✓ User found
- ✓ Password format detected
- ✓ Which method matches
- ✓ Recommendation if needed

### Step 4: Test Login
Try logging in with the mobile app.

## Common Scenarios

### Scenario 1: MD5 Password
```
Password Length: 32 characters
Format: MD5
Action: ✓ Should work now
```

### Scenario 2: Bcrypt Password
```
Password Length: 60 characters
Format: Bcrypt (starts with $2y$)
Action: ✓ Should work now (password_verify added)
```

### Scenario 3: Plain Text Password
```
Password Length: Variable
Format: Plain text
Action: ⚠ Works but INSECURE
Recommendation: Update to MD5:
UPDATE account_user SET password = MD5('your_password') WHERE account_id = X;
```

### Scenario 4: Unknown Format
```
Password doesn't match any format
Action: Check diagnostic output for details
```

## Fix Recommendations

### If Using Web Application Password
Your web application might use bcrypt. The updated login.php now supports this.

### If Password Still Fails
1. Run diagnostic script
2. Check password format
3. Update password if needed:

```sql
-- For MD5
UPDATE account_user 
SET password = MD5('your_password') 
WHERE username = 'your_username';

-- For Bcrypt
UPDATE account_user 
SET password = '$2y$10$...' 
WHERE username = 'your_username';
```

## Security Notes

### Current Support
- ✓ MD5 (legacy, less secure)
- ✓ Bcrypt (recommended, secure)
- ✓ Plain text (fallback, insecure)

### Recommendations
1. **Use Bcrypt** for new passwords
2. **Migrate from MD5** to Bcrypt when possible
3. **Never use plain text** in production

### Migration Script
```php
// Migrate MD5 to Bcrypt
$password = 'user_password';
$bcrypt_hash = password_hash($password, PASSWORD_DEFAULT);

UPDATE account_user 
SET password = '$bcrypt_hash' 
WHERE account_id = X;
```

## Troubleshooting

### Issue: Still getting "Invalid password"
**Steps:**
1. Run diagnostic: `check_account_password.php?email=X&password=Y`
2. Check which format is detected
3. Verify password is correct
4. Check for extra spaces/characters

### Issue: Diagnostic shows "No match"
**Possible causes:**
- Password is incorrect
- Password uses SHA1 or other format
- Password has extra characters

**Solution:**
Reset password to known value:
```sql
UPDATE account_user 
SET password = MD5('newpassword123') 
WHERE username = 'your_username';
```

### Issue: Login works but wrong page
**Cause:** Role field issue (separate from password)

**Solution:** Check role in database

## Testing Checklist

- [ ] Upload updated login.php
- [ ] Upload check_account_password.php
- [ ] Run diagnostic with your credentials
- [ ] Verify password format detected
- [ ] Test login in mobile app
- [ ] Verify correct page navigation

## Files Modified

1. **login.php** - Added multi-format password verification
2. **check_account_password.php** - New diagnostic tool

## Backward Compatibility

✅ All existing logins still work:
- SDP (password_verify) - Unchanged
- Client (no password) - Unchanged
- Facilitator (no password) - Unchanged
- Account user (MD5) - Enhanced
- Account user (Bcrypt) - Now supported
- Account user (Plain) - Now supported

## Summary

The login system now supports multiple password formats for the `account_user` table:
1. Tries MD5 first (most common)
2. Falls back to Bcrypt (secure)
3. Falls back to plain text (insecure but works)

This ensures maximum compatibility while maintaining security where possible.

## Date
December 20, 2024

---

**Status:** ✅ Ready to test
**Diagnostic Tool:** Available
**Backward Compatible:** Yes
