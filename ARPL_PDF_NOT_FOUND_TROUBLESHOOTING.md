# ARPL PDF Generator - "Not Found" Troubleshooting Guide

## Issue
You're getting a "Not found" error when trying to access:
```
http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=782&LearnerID=16389&ofoNumber=671101
```

---

## 🔧 Solution: Use the Diagnostic Tool

We've created a diagnostic script to help identify the exact issue.

### Step 1: Access the Diagnostic Tool

**URL:**
```
http://localhost:8080/web/web/web/diagnose_arpl_pdf.php?classID=782&learnerID=16389&ofoNumber=671101
```

**Note:** Use lowercase `learnerID` in the diagnostic URL (not `LearnerID`)

### Step 2: Check the Results

The diagnostic tool will show:
- ✅ Session status (are you logged in?)
- ✅ Parameters received (classID, learnerID)
- ✅ Database connection
- ✅ Class exists in database
- ✅ Learner exists in database
- ✅ Learner is enrolled in the class
- ✅ Trade code is valid
- ✅ Generator file exists

### Step 3: Fix Issues

Based on the diagnostic output, follow the appropriate section below:

---

## ❌ Common Issues & Fixes

### Issue 1: "NO SESSION FOUND" (Red)

**Problem:** You are not logged in

**Solution:**
1. Go to login page: `http://localhost:8080/web/index.php`
2. Login as SDP or Facilitator
3. Then try the ARPL PDF generator again

**Example Login:**
- Username: your_username
- Password: your_password
- Role: SDP or Facilitator

---

### Issue 2: "classID NOT PROVIDED" or "learnerID NOT PROVIDED" (Red)

**Problem:** Missing parameters in URL

**Solution:**

Your URL: `?classID=782&LearnerID=16389&ofoNumber=671101`

The parameter name is case-sensitive in some contexts. Use:
- `learnerID` (lowercase L) - preferred
- OR `LearnerID` (capital L) - also supported

**Correct URLs:**
```
http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=782&learnerID=16389&ofoNumber=671101
```

---

### Issue 3: "Class NOT Found" (Red)

**Problem:** classID=782 doesn't exist in the database

**Solution:**

1. **Check if the class exists:**
   ```
   SELECT * FROM class WHERE classID = 782;
   ```

2. **Find a valid class:**
   ```
   SELECT classID, ClassName FROM class LIMIT 10;
   ```

3. **Use a valid classID** in the URL

**Example:**
If class 42 exists and is named "Electrician 2024", use:
```
http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=42&learnerID=16389&ofoNumber=671101
```

---

### Issue 4: "Learner NOT Found" (Red)

**Problem:** learnerID=16389 doesn't exist in the database

**Solution:**

1. **Check if the learner exists:**
   ```
   SELECT * FROM learnerdetails WHERE LearnerID = 16389;
   ```

2. **Find a valid learner:**
   ```
   SELECT LearnerID, Name, Surname FROM learnerdetails LIMIT 10;
   ```

3. **Use a valid learnerID** in the URL

**Example:**
If learner 100 exists and is named "John Smith", use:
```
http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=782&learnerID=100&ofoNumber=671101
```

---

### Issue 5: "Learner IS NOT enrolled in this class" (Yellow Warning)

**Problem:** The learner exists, but is not in the specified class

**Solution:**

1. **Check which class the learner is in:**
   ```
   SELECT classID FROM learnerdetails WHERE LearnerID = 16389;
   ```

2. **Use the correct class** they're enrolled in

**Example:**
If learner 16389 is in class 5, use:
```
http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=5&learnerID=16389&ofoNumber=671101
```

---

### Issue 6: "Unknown Trade Code" (Yellow Warning)

**Problem:** OFO code is not recognized

**Solution:**

Use one of the valid codes:
- `671101` - Electrician ✅
- `641201` - Bricklaying ✅
- `642601` - Plumbing ✅ (default)

**Correct URL:**
```
http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=782&learnerID=16389&ofoNumber=671101
```

---

### Issue 7: "Database Connection Failed" (Red)

**Problem:** Cannot connect to database

**Solution:**

1. **Check if MySQL is running**
   - Windows: Services > MySQL80 should be running
   - Or run: `net start MySQL80`

2. **Check connection.php**
   - File should be at: `c:\projects\rlmss\connection.php`
   - Check hostname, username, password, database name

3. **Verify database exists:**
   ```
   SHOW DATABASES;
   ```

4. **Restart web server:**
   - Stop Apache/PHP server
   - Start it again
   - Try the URL again

---

### Issue 8: "Generator File NOT Found" (Red)

**Problem:** The file doesn't exist in the expected location

**Solution:**

The file should be at:
```
c:\projects\rlmss\web\web\web\generate_arpl_pdf.php
```

**Check:**
1. Does the file exist at that path?
2. If not, check if it's in a different location
3. Contact support to ensure file was deployed correctly

---

## 🧪 Full Testing Workflow

### Step 1: Run Diagnostic
```
http://localhost:8080/web/web/web/diagnose_arpl_pdf.php?classID=782&learnerID=16389&ofoNumber=671101
```

### Step 2: Review Output

Check each section for ✅ (green) or ❌ (red)

### Step 3: Fix Issues

Follow the appropriate fix section above

### Step 4: Generate PDF

Once all checks are green:
```
http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=782&learnerID=16389&ofoNumber=671101
```

### Step 5: Verify Output

You should see:
- 📄 Cover page with ARPL title
- 📄 Contents page
- 📄 Application form
- 📄 Self-evaluation checklist
- 📄 Multiple appendices
- 🖊️ Signature pads
- 🖨️ Print button

---

## 🔍 How to Get Valid classID and learnerID

### Option 1: From Admin Panel
1. Go to Classes page
2. Click on a class
3. Note the classID (usually in URL)
4. Select a learner
5. Note the learnerID

### Option 2: From Database
```sql
-- Find all classes
SELECT classID, ClassName FROM class;

-- Find all learners in a specific class
SELECT LearnerID, Name, Surname, classID FROM learnerdetails WHERE classID = 782;

-- Find a specific learner
SELECT LearnerID, Name, Surname, classID FROM learnerdetails WHERE Name = 'John';
```

### Option 3: From ARPL Dashboard
1. Open ARPL dashboard
2. Select a class
3. Select a learner
4. URLs will show the IDs

---

## ✅ Correct URL Format

### Syntax:
```
http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=XXXX&learnerID=YYYY&ofoNumber=ZZZZ
```

### Examples:

**Electrician:**
```
http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=123&learnerID=456&ofoNumber=671101
```

**Bricklayer:**
```
http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=123&learnerID=456&ofoNumber=641201
```

**Plumber:**
```
http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=123&learnerID=456&ofoNumber=642601
```

---

## 📞 Quick Checklist Before Debugging

- [ ] I'm logged in as SDP or Facilitator
- [ ] I have valid classID (checked in database)
- [ ] I have valid learnerID (checked in database)
- [ ] The learner is enrolled in the specified class (checked)
- [ ] I'm using the correct URL format
- [ ] MySQL database is running
- [ ] Web server is running

---

## 🚀 If Everything is Fixed

Once all diagnostic checks are green, the URL should work:

```
http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=782&learnerID=16389&ofoNumber=671101
```

**Expected Result:**
- Page loads with ARPL PDF form
- Print button appears
- All fields are populated
- Signature pads are ready

---

## 📝 Parameters Reference

| Parameter | Required | Valid Values | Example |
|-----------|----------|--------------|---------|
| `classID` | Yes | Integer > 0 | `782` |
| `learnerID` | Yes | Integer > 0 | `16389` |
| `ofoNumber` | No | 671101, 641201, 642601 | `671101` |

---

## 🔗 Related URLs

- **Diagnostic Tool:** `/web/web/web/diagnose_arpl_pdf.php`
- **Generator:** `/web/web/web/generate_arpl_pdf.php`
- **Login:** `/web/index.php`
- **Classes:** `/web/classes.php`
- **Learners:** `/web/learners.php`

---

## 📞 Still Having Issues?

If the diagnostic tool shows all checks as ✅ but the generator still doesn't work:

1. **Check browser console** (F12 > Console) for JavaScript errors
2. **Check server logs** for PHP errors
3. **Verify file permissions** - file should be readable
4. **Clear browser cache** - Ctrl+Shift+Delete
5. **Restart web server**

---

**Last Updated:** July 11, 2026  
**Version:** 1.0  
**Status:** ✅ Complete

