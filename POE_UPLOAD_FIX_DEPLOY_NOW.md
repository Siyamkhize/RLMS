# POE Upload 500 Error - Deploy Fix NOW

## The Problem
The server is returning a 500 error because either:
1. The `poe_documents` table doesn't exist in the database
2. The PHP script has a syntax error
3. The database connection is failing

## What You Need to Do on the Server

### Step 1: Check if Table Exists

```bash
# SSH into the server
ssh user@rlms.rlms.co.za

# Check if table exists
mysql -u root -p -e "USE rlmss; SHOW TABLES LIKE 'poe_documents';"
```

**If table doesn't exist, create it:**

```bash
# Upload the SQL file to the server first, then:
mysql -u root -p rlmss < /path/to/create_poe_documents_table.sql
```

### Step 2: Upload the Fixed PHP Files

Upload these files to the server at `/path/to/mobile/`:

1. `upload_poe_document_safe.php` - The fixed upload script
2. `check_poe_table.php` - To verify table structure

```bash
# On the server, backup the old file
cd /path/to/mobile/
cp upload_poe_document.php upload_poe_document_OLD.php

# Replace with the safe version
cp upload_poe_document_safe.php upload_poe_document.php

# Set permissions
chmod 644 upload_poe_document.php
chmod 777 uploads/poe_documents/temp
```

### Step 3: Test the Table

```bash
# Access this URL in a browser or with curl:
curl https://rlms.rlms.co.za/mobile/check_poe_table.php
```

**Expected response if table is OK:**
```json
{
  "success": true,
  "message": "Table structure is correct",
  "columns": ["id", "learner_id", "learner_name", ...],
  "test_insert": "passed"
}
```

**If table doesn't exist:**
```json
{
  "success": false,
  "error": "Table poe_documents does not exist",
  "solution": "Run create_poe_documents_table.sql"
}
```

### Step 4: Check the Logs

After trying to upload from the app:

```bash
# On the server
tail -50 /path/to/mobile/poe_upload_safe.log
```

This will show exactly where the error is happening.

### Step 5: Check Apache Error Log

```bash
# On the server
sudo tail -50 /var/log/apache2/error.log
```

Look for errors around the time of the upload (10:32:58).

## Quick Commands Summary

```bash
# 1. Check if table exists
mysql -u root -p -e "USE rlmss; SHOW TABLES LIKE 'poe_documents';"

# 2. If table doesn't exist, create it
mysql -u root -p rlmss < create_poe_documents_table.sql

# 3. Backup and replace upload script
cd /path/to/mobile/
cp upload_poe_document.php upload_poe_document_OLD.php
# (Upload upload_poe_document_safe.php via FTP/SCP)
cp upload_poe_document_safe.php upload_poe_document.php

# 4. Set permissions
chmod 644 upload_poe_document.php
mkdir -p uploads/poe_documents/temp
chmod 777 uploads/poe_documents/temp

# 5. Test table structure
curl https://rlms.rlms.co.za/mobile/check_poe_table.php

# 6. Try upload from app, then check logs
tail -50 poe_upload_safe.log
tail -50 /var/log/apache2/error.log
```

## Most Likely Issue

Based on the 500 error, the most likely cause is:

**The `poe_documents` table doesn't exist in the database.**

To fix:
```bash
mysql -u root -p rlmss < create_poe_documents_table.sql
```

## Files to Upload to Server

1. **create_poe_documents_table.sql** - Creates the table
2. **upload_poe_document_safe.php** - Fixed upload script with logging
3. **check_poe_table.php** - Validates table structure

## After Deployment

1. Access `check_poe_table.php` to verify table exists
2. Try uploading from the app
3. Check `poe_upload_safe.log` for detailed error messages
4. If still failing, send me the log contents

## Alternative: Use FTP/cPanel

If you have cPanel or FTP access:

1. **Upload SQL file** to server
2. **Run SQL** via phpMyAdmin:
   - Open phpMyAdmin
   - Select `rlmss` database
   - Click "Import"
   - Upload `create_poe_documents_table.sql`
   - Click "Go"

3. **Upload PHP files** via FTP:
   - Upload `upload_poe_document_safe.php`
   - Rename it to `upload_poe_document.php`
   - Upload `check_poe_table.php`

4. **Set folder permissions**:
   - Create folder: `uploads/poe_documents/temp`
   - Set permissions to 777

5. **Test** by accessing:
   - `https://rlms.rlms.co.za/mobile/check_poe_table.php`

## What the Safe Script Does

The `upload_poe_document_safe.php` script:
- Checks if table exists before attempting upload
- Logs every step to `poe_upload_safe.log`
- Returns clear JSON error messages (not HTML 500 errors)
- Validates chunk uploads before processing
- Catches and logs all errors

## Expected Log Output

**Success:**
```
2025-12-23 10:35:00 === Upload started ===
2025-12-23 10:35:00 Including connection.php
2025-12-23 10:35:00 Database connected
2025-12-23 10:35:00 Table exists
2025-12-23 10:35:00 Upload directory ready
2025-12-23 10:35:00 Is chunked: yes
2025-12-23 10:35:00 Chunk 0 of 4, ID: 1766478778505
2025-12-23 10:35:00 Chunk file valid, size: 2097152
2025-12-23 10:35:00 Chunk saved
```

**Failure (table missing):**
```
2025-12-23 10:35:00 === Upload started ===
2025-12-23 10:35:00 Including connection.php
2025-12-23 10:35:00 Database connected
2025-12-23 10:35:00 ERROR: Table poe_documents does not exist
```

This tells you exactly what's wrong!
