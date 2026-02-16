# Import Your Database - Step by Step Guide

## Your Database File
**Location:** `C:\Users\Administrator\.android\studio\newApp\rlmss\rlmsrlmsco_ezxcmacd_rlms (1).sql`

**Database Name:** `rlmsrlmsco_ezxcmacd_rlms`

---

## ⚡ Method 1: Automated Script (Easiest - 2 minutes)

### Step 1: Start XAMPP
1. Open **XAMPP Control Panel**
2. Click **Start** next to MySQL
3. Wait for green "Running" status

### Step 2: Run Import Script
1. Double-click: **`IMPORT_MY_DATABASE.bat`**
2. Wait for import to complete (2-5 minutes)
3. Look for "SUCCESS!" message

### Step 3: Done! ✅
Your database is now imported and ready to use!

---

## 🖱️ Method 2: Using phpMyAdmin (Manual - 3 minutes)

### Step 1: Start XAMPP (30 seconds)
1. Open **XAMPP Control Panel**
2. Click **Start** next to Apache
3. Click **Start** next to MySQL
4. Wait for both to show green "Running"

### Step 2: Open phpMyAdmin (10 seconds)
1. Open your browser
2. Go to: `http://localhost/phpmyadmin`

### Step 3: Create Database (20 seconds)
1. Click **"Databases"** tab at the top
2. In "Create database" field, type: `rlmsrlmsco_ezxcmacd_rlms`
3. Click **"Create"** button

### Step 4: Import File (2-5 minutes)
1. Click on **`rlmsrlmsco_ezxcmacd_rlms`** in left sidebar
2. Click **"Import"** tab at the top
3. Click **"Choose File"** button
4. Navigate to: `C:\Users\Administrator\.android\studio\newApp\rlmss\`
5. Select: `rlmsrlmsco_ezxcmacd_rlms (1).sql`
6. Scroll down and click **"Go"** button
7. Wait for import (progress bar will show)

### Step 5: Verify (10 seconds)
1. Look for green message: "Import has been successfully finished"
2. Check left sidebar - you should see many tables
3. Click on a table to verify data

---

## 🔧 After Import - Update Connection File

### Edit: `connection.php`

```php
<?php
$servername = "localhost";
$username = "root";
$password = "";  // XAMPP default has no password
$dbname = "rlmsrlmsco_ezxcmacd_rlms";

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

echo "Connected successfully to database: " . $dbname;
?>
```

---

## ✅ Test Your Connection

### Create: `test_connection.php`

```php
<?php
include('connection.php');

// Show database name
echo "<h2>Database Connection Test</h2>";
echo "<p>Connected to: <strong>" . $dbname . "</strong></p>";

// Count tables
$result = $conn->query("SHOW TABLES");
$table_count = $result->num_rows;
echo "<p>Total tables: <strong>" . $table_count . "</strong></p>";

// List first 10 tables
echo "<h3>Sample Tables:</h3>";
echo "<ul>";
$count = 0;
while ($row = $result->fetch_array() && $count < 10) {
    echo "<li>" . $row[0] . "</li>";
    $count++;
}
echo "</ul>";

$conn->close();
?>
```

### Test It:
1. Save file in your project folder
2. Open: `http://localhost/your_project/test_connection.php`
3. You should see database name and table count

---

## 🚨 Troubleshooting

### Issue 1: "File not found"
**Check:**
- File exists at: `C:\Users\Administrator\.android\studio\newApp\rlmss\rlmsrlmsco_ezxcmacd_rlms (1).sql`
- File name is exactly: `rlmsrlmsco_ezxcmacd_rlms (1).sql` (note the space and "(1)")

### Issue 2: "MySQL is not running"
**Fix:**
1. Open XAMPP Control Panel
2. Click "Start" next to MySQL
3. If it fails, click "Config" → "my.ini"
4. Check for port conflicts (default port: 3306)

### Issue 3: "Maximum execution time exceeded"
**Fix in phpMyAdmin:**
1. Click "Import" tab
2. Check "Partial import" checkbox
3. Set to 2,000 queries at a time
4. Click "Go" multiple times until complete

**Fix in php.ini:**
1. Edit: `C:\xampp\php\php.ini`
2. Find: `max_execution_time = 30`
3. Change to: `max_execution_time = 300`
4. Restart Apache in XAMPP

### Issue 4: "File too large"
**Fix:**
1. Edit: `C:\xampp\php\php.ini`
2. Find: `upload_max_filesize = 2M`
3. Change to: `upload_max_filesize = 128M`
4. Find: `post_max_size = 8M`
5. Change to: `post_max_size = 128M`
6. Restart Apache in XAMPP

### Issue 5: "MySQL server has gone away"
**Fix:**
1. Edit: `C:\xampp\mysql\bin\my.ini`
2. Find: `max_allowed_packet = 1M`
3. Change to: `max_allowed_packet = 64M`
4. Restart MySQL in XAMPP

---

## 📊 Expected Results

After successful import, you should have:

- **Database:** rlmsrlmsco_ezxcmacd_rlms
- **Tables:** 50+ tables (varies by database)
- **Data:** All learner, class, marks, POE data

### Common Tables:
- learnerdetails
- class
- marks
- assessments
- poe
- facilitator
- logbook_marks
- And many more...

---

## 🎯 Quick Commands

### Check if database exists:
```cmd
"C:\xampp\mysql\bin\mysql.exe" -u root -e "SHOW DATABASES LIKE 'rlmsrlmsco_ezxcmacd_rlms';"
```

### Count tables:
```cmd
"C:\xampp\mysql\bin\mysql.exe" -u root -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='rlmsrlmsco_ezxcmacd_rlms';"
```

### List all tables:
```cmd
"C:\xampp\mysql\bin\mysql.exe" -u root rlmsrlmsco_ezxcmacd_rlms -e "SHOW TABLES;"
```

---

## 📝 Summary

**Your database file:**
```
C:\Users\Administrator\.android\studio\newApp\rlmss\rlmsrlmsco_ezxcmacd_rlms (1).sql
```

**Import methods:**
1. ⚡ Run `IMPORT_MY_DATABASE.bat` (automated)
2. 🖱️ Use phpMyAdmin (manual)

**After import:**
1. Update `connection.php`
2. Test with `test_connection.php`
3. Start using your application!

**Total time:** 2-5 minutes

---

## ✅ Ready to Import?

Choose your method:
- **Easy:** Double-click `IMPORT_MY_DATABASE.bat`
- **Manual:** Follow phpMyAdmin steps above

Your database will be ready in minutes! 🎉
