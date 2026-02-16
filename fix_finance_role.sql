-- Check current roles in account_user table
SELECT 
    account_id,
    username,
    email,
    role,
    CHAR_LENGTH(role) as role_length,
    HEX(role) as role_hex,
    account_name
FROM account_user;

-- If you see the role is not exactly 'finance', run this:
-- UPDATE account_user SET role = 'finance' WHERE username = 'YOUR_USERNAME_HERE';

-- After updating, verify:
-- SELECT username, role FROM account_user WHERE username = 'YOUR_USERNAME_HERE';
