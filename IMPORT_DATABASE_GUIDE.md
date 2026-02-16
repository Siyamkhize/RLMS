# Import Database to XAMPP - Guide

## Database Information
- **Database Name:** rlmsrlmsco_ezxcmacd_rlms
- **Target:** XAMPP MySQL (localhost)

---

## Method 1: Using phpMyAdmin (Recommended - Easy)

### Step 1: Start XAMPP
1. Open XAMPP Control Panel
2. Start **Apache** and **MySQL** services
3. Wait for both to show green "Running" status

### Step 2: Open phpMyAdmin
1. Open your browser
2. Go to: `http://localhost/phpmyadmin`
3. You should see the phpMyAdmin interface

### Step 3: Create Database
1. Click on **"Databases"** tab at the top
2. In "Create database" section:
   - Database name: `rlmsrlmsco_ezxcmacd_rlms`
   - Collation: `utf8mb4_general_ci` (recommended)
3. Click **"Create"** button

### Step 4: Import Database File
1. Click on the database name `rlmsrlmsco_ezxcmacd_rlms` in the left sidebar
2. Click on **"Import"** tab at the top
3. Click **"Choose File"** button
4. Select your database file (`.sql` file)
5. Scroll down and click **"Go"** button
6. Wait for import to complete (may take a few minutes for large databases)

### Step 5: Verify Import
1. Check the left sidebar - you should see all tables listed
2. Click on a few tables to verify data is there
3. Look for success message: "Import has been successfully finished"

---

## Method 2: Using Command Line (Faster for Large Databases)

### Step 1: Locate MySQL Binary
XAMPP MySQL is usually at:
```
C:\xampp\mysql\bin\mysql.exe
```

### Step 2: Open Command Prompt
1. Press `Win + R`
2. Type `cmd` and press Enter

### Step 3: Navigate to Database File Location
```cmd
cd C:\path\to\your\database\file
```

### Step 4: Create Database
```cmd
"C:\xampp\mysql\bin\mysql.exe" -u root -p -e "CREATE DATABASE IF NOT EXISTS rlmsrlmsco_ezxcmacd_rlms CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
```

Press Enter (default XAMPP has no password, just press Enter again)

### Step 5: Import Database
```cmd
"C:\xampp\mysql\bin\mysql.exe" -u root -p rlmsrlmsco_ezxcmacd_rlms < your_database_file.sql
```

Replace `your_database_file.sql` with your actual filename.

---

## Method 3: Using Batch Script (Automated)

I'll create a batch script for you below.

---

## Troubleshooting

### Issue 1: "MySQL said: #1227 - Access denied"
**Solution:** You need SUPER privilege. Use phpMyAdmin method instead.

### Issue 2: "Maximum execution time exceeded"
**Solution:** 
1. Go to `C:\xampp\php\php.ini`
2. Find: `max_execution_time = 30`
3. Change to: `max_execution_time = 300`
4. Restart Apache in XAMPP

### Issue 3: "Allowed memory size exhausted"
**Solution:**
1. Go to `C:\xampp\php\php.ini`
2. Find: `memory_limit = 128M`
3. Change to: `memory_limit = 512M`
4. Restart Apache in XAMPP

### Issue 4: "MySQL server has gone away"
**Solution:**
1. Go to `C:\xampp\mysql\bin\my.ini`
2. Find: `max_allowed_packet = 1M`
3. Change to: `max_allowed_packet = 64M`
4. Restart MySQL in XAMPP

### Issue 5: Import is very slow
**Solution:** Use command line method (Method 2) - it's much faster!

---

## After Import - Update Connection Files

Once imported, update your PHP connection files:

### File: connection.php
```php
<?php
$servername = "localhost";
$username = "root";
$password = "";  // Default XAMPP has no password
$dbname = "rlmsrlmsco_ezxcmacd_rlms";

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
?>
```

---

## Quick Checklist

- [ ] XAMPP Apache and MySQL are running
- [ ] Database created: `rlmsrlmsco_ezxcmacd_rlms`
- [ ] Database file imported successfully
- [ ] Tables are visible in phpMyAdmin
- [ ] Connection file updated with correct database name
- [ ] Test connection by accessing: `http://localhost/your_project/test_db_connection.php`

---

## Need Help?

If you encounter any issues:
1. Check XAMPP error logs: `C:\xampp\mysql\data\mysql_error.log`
2. Check PHP error logs: `C:\xampp\apache\logs\error.log`
3. Make sure your `.sql` file is not corrupted
4. Try importing a small portion first to test

---

## Database File Location

Where is your database file? Common locations:
- Downloads folder: `C:\Users\Administrator\Downloads\`
- Desktop: `C:\Users\Administrator\Desktop\`
- Project folder: Current directory

Once you locate it, use one of the methods above to import!
