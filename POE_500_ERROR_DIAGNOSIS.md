# POE 500 Error - Database/Syntax Diagnosis

You're right - a 500 error usually means:
1. **PHP syntax error** in the code
2. **Database table doesn't exist** or has wrong structure
3. **Database connection failing**
4. **SQL query error** (wrong column names, data type mismatch)

## Step 1: Check if Table Exists

Run this on the server:

```bash
# Upload and run check_poe_table.php
curl https://rlms.rlms.co.za/mobile/check_poe_table.php
```

This will tell you:
- If the `poe_documents` table exists
- If it has all required columns
- If test inserts work

**If table doesn't exist:**
```bash
# On the server
mysql -u root -p rlmss < create_poe_documents_table.sql
```

## Step 2: Check PHP Syntax

```bash
# On the server
cd /path/to/mobile/
php -l upload_poe_document.php
```

If there's a syntax error, it will show the line number.

## Step 3: Check Database Connection

```bash
# On the server
cat > test_db_connection.php << 'EOF'
<?php
header('Content-Type: application/json');
try {
    require_once 'connection.php';
    if (!isset($conn)) {
        throw new Exception('$conn not set');
    }
    $result = $conn->query("SELECT 1");
    if (!$result) {
        throw new Exception('Query failed: ' . $conn->error);
    }
    echo json_encode(['success' => true, 'message' => 'Database connected']);
} catch (Exception $e) {
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}
?>
EOF

curl https://rlms.rlms.co.za/mobile/test_db_connection.php
```

## Step 4: Use Safe Upload Script

The `upload_poe_document_safe.php` has:
- Better error handling
- Detailed logging to `poe_upload_safe.log`
- Database validation before attempting upload
- Clear error messages

**Deploy it:**

```bash
# On the server
cp upload_poe_document.php upload_poe_document_backup.php
cp upload_poe_document_safe.php upload_poe_document.php
chmod 644 upload_poe_document.php
```

**Then check the log after upload:**

```bash
tail -f /path/to/mobile/poe_upload_safe.log
```

## Common Database Issues

### Issue 1: Table Doesn't Exist

**Error:** `Table 'rlmss.poe_documents' doesn't exist`

**Fix:**
```bash
mysql -u root -p rlmss < create_poe_documents_table.sql
```

### Issue 2: Column Name Mismatch

**Error:** `Unknown column 'xyz' in 'field list'`

**Fix:** Check if table has all columns:
```sql
DESCRIBE poe_documents;
```

Compare with the INSERT statement in the PHP file.

### Issue 3: Data Type Mismatch

**Error:** `Incorrect integer value` or `Data too long`

**Fix:** Check the data types:
- `learner_id` should be VARCHAR(50)
- `file_size` should be BIGINT
- `page_count` should be INT

### Issue 4: NULL Constraint Violation

**Error:** `Column 'xyz' cannot be null`

**Fix:** Make sure required fields are being sent:
- `learner_id` (required)
- `learner_name` (required)
- `file_name` (required)
- `file_path` (required)
- `file_size` (required)

## Quick Diagnosis Commands

```bash
# 1. Check if table exists
mysql -u root -p -e "USE rlmss; SHOW TABLES LIKE 'poe_documents';"

# 2. Check table structure
mysql -u root -p -e "USE rlmss; DESCRIBE poe_documents;"

# 3. Check PHP syntax
php -l upload_poe_document.php

# 4. Check connection.php syntax
php -l connection.php

# 5. Test database connection
php -r "require 'connection.php'; echo 'Connected: ' . (isset(\$conn) ? 'yes' : 'no');"

# 6. Check Apache error log
sudo tail -20 /var/log/apache2/error.log
```

## What the Safe Script Does

1. **Validates table exists** before attempting upload
2. **Logs every step** to `poe_upload_safe.log`
3. **Catches SQL errors** and returns them in JSON
4. **Validates chunk uploads** before processing
5. **Returns clear error messages** instead of generic 500

## Testing the Fix

After deploying the safe script:

1. Try uploading from the app
2. Check the log:
   ```bash
   cat /path/to/mobile/poe_upload_safe.log
   ```
3. If it fails, the log will show exactly where and why

## Expected Log Output (Success)

```
2025-12-23 10:30:00 === Upload started ===
2025-12-23 10:30:00 Including connection.php
2025-12-23 10:30:00 Database connected
2025-12-23 10:30:00 Table exists
2025-12-23 10:30:00 Upload directory ready
2025-12-23 10:30:00 Is chunked: yes
2025-12-23 10:30:00 Chunk 0 of 4, ID: 1766478196712
2025-12-23 10:30:00 Chunk file valid, size: 2097152
2025-12-23 10:30:00 Chunk saved: /path/temp/1766478196712_chunk_0
```

## Expected Log Output (Error)

```
2025-12-23 10:30:00 === Upload started ===
2025-12-23 10:30:00 Including connection.php
2025-12-23 10:30:00 Database connected
2025-12-23 10:30:00 ERROR: Table poe_documents does not exist
```

This tells you exactly what's wrong!

## Files to Deploy

1. **check_poe_table.php** - Validates table structure
2. **upload_poe_document_safe.php** - Safe upload with logging
3. **create_poe_documents_table.sql** - Creates table if missing

## Next Steps

1. Run `check_poe_table.php` to see if table is correct
2. If table is missing/wrong, run the SQL file
3. Deploy `upload_poe_document_safe.php`
4. Try upload and check `poe_upload_safe.log`
5. Send me the log output if still failing
