# ARPL PDF Generator - Quick Test Guide

## ✅ Fix Applied
Parameter validation issue in `generate_pdf.php` has been resolved. The wrapper now:
1. Accepts learnerID + ofo_code (auto-looks up classID from database)
2. Accepts learnerID + classID + ofo_code (validates all 3)
3. Shows debug info if parameters are invalid

## 🧪 How to Test

### Test URL Pattern 1: With Auto-Lookup
```
http://localhost:8080/web/generate_pdf.php?learnerID=16389&ofo_code=671101
```

**Expected Behavior**:
- Page loads with spinner
- JS console shows: "🔷 PDF generation page loaded for learnerID=16389"
- JS console shows: "🔗 Redirecting to: http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=782&learnerID=16389&ofoNumber=671101"
- Page redirects to PDF generator
- PDF loads or displays content

### Test URL Pattern 2: With All Parameters
```
http://localhost:8080/web/generate_pdf.php?learnerID=16389&classID=782&ofo_code=671101
```

**Expected Behavior**: Same as above

### Test URL Pattern 3: Invalid Learner (Should Show Error)
```
http://localhost:8080/web/generate_pdf.php?learnerID=99999&ofo_code=671101
```

**Expected Behavior**:
- Shows: "Invalid parameters. Please start over."
- Shows debug: "Debug: learnerID=0, classID=0, ofo_code=671101"

### Test URL Pattern 4: Missing ofo_code (Should Show Error)
```
http://localhost:8080/web/generate_pdf.php?learnerID=16389
```

**Expected Behavior**:
- Shows: "Invalid parameters. Please start over."
- Shows debug: "Debug: learnerID=16389, classID=782, ofo_code=" (empty)

## 🔍 Debugging Steps (If Still Failing)

### Step 1: Check Browser Console
1. Open browser DevTools: **F12**
2. Go to **Console** tab
3. Look for log messages starting with 🔷, 📄, 📨, 🔗
4. Copy exact redirect URL shown

### Step 2: Test Redirect URL Directly
If redirect URL is shown as:
```
http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=782&learnerID=16389&ofoNumber=671101
```

Try visiting it directly in a new tab. If this works, the issue is in the wrapper logic.

### Step 3: Check Database
```bash
# SSH to server or use terminal
mysql -u root -p database_name
```

```sql
-- Check learner exists
SELECT LearnerID, classID, FirstName, LastName FROM learnerdetails WHERE LearnerID = 16389 LIMIT 1;

-- Check class exists
SELECT classID, class_name FROM class WHERE classID = 782 LIMIT 1;

-- Check enrollment
SELECT * FROM learnerdetails WHERE LearnerID = 16389 AND classID = 782;
```

### Step 4: Test PHP Connection
```bash
php -r "
include 'c:\projects\rlmss\connection.php';
echo 'Connection test: ';
var_dump(\$conn);
"
```

### Step 5: Check File Locations
```bash
# Verify files exist at correct paths
ls -la c:\projects\rlmss\web\generate_pdf.php
ls -la c:\projects\rlmss\web\web\web\generate_arpl_pdf.php
```

## 📋 Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "Invalid parameters" | classID not in URL & not in DB | Add classID to URL or verify learner record exists |
| Blank page after redirect | PDF generator not working | Check `/web/web/web/generate_arpl_pdf.php` is at correct path |
| 404 on redirect URL | Path misconfiguration | Verify URL has 3x `/web/` segments: `/web/web/web/` |
| JS console shows 0s for parameters | GET params not passed | Check URL has all parameters: `?learnerID=...&ofo_code=...` |
| Database lookup returns nothing | Learner doesn't exist | Verify learner ID exists in database |

## 🚀 Next Steps

1. **Test with your actual data** using one of the test URLs above
2. **Check browser console** for error messages
3. **Share console output** if it's still failing
4. **Verify database records** exist for the test learner
5. **Test redirect URL directly** to isolate the issue

## 📞 Support Info

If still not working:
- Check `ARPL_PDF_PARAMETER_VALIDATION_FIX.md` for detailed explanation
- Review browser console logs (F12)
- Verify database has learner & class records
- Contact support with console output and database query results
