# ARPL Hierarchy - Final Version Ready for Upload
**Date: July 23, 2026**

---

## ✅ Changes Made

### Fixed: Database Connection
**Before (Local Configuration):**
```php
// LOCAL CONFIGURATION
$host = '192.168.0.57';
$protocol = 'http';
$port = 80;
$baseUrl = "$protocol://$host:$port/mobile/";
```

**After (Production Ready):**
```php
// Get base URL from connection configuration
// This will be set properly on the production server
$baseUrl = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http") . "://" . $_SERVER['HTTP_HOST'] . "/mobile/";
```

**Benefits:**
- ✅ Uses standard `include('connection.php')` at top of file
- ✅ Automatically detects HTTPS vs HTTP
- ✅ Works on production server without modification
- ✅ Base URL dynamically generated from server settings

---

## 📋 File Ready for Upload

**File:** `mobile/get_arpl_hierarchy.php`

**Status:** ✅ Production Ready

**What it does:**
1. Includes `connection.php` for database connection
2. Gets learner → class → trade_id
3. JOINs with `arpl_trades` table to get OFO and trade name
4. Queries `arpl_papers` WHERE `trade_ofo_code = OFO`
5. Groups papers by type (theory/practical)
6. Queries `arpl_questions` and links via `paper_id`
7. Returns hierarchical structure

---

## 🚀 Upload Instructions

### 1. Upload File
```
Source: c:\projects\rlmss\mobile\get_arpl_hierarchy.php
Destination: /public_html/mobile/get_arpl_hierarchy.php
Action: Replace existing file
```

### 2. Verify Connection
The file now uses:
```php
<?php
header("Access-Control-Allow-Origin: *");
// ... headers ...
include_once 'connection.php';  // ✅ Uses standard connection
```

**No additional configuration needed!**

---

## 🧪 Testing

### Test with cURL:
```bash
curl "https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701"
```

### Expected Response:
```json
{
  "pathways": {
    "ARPL": {
      "qualifications": {
        "Bricklaying": {
          "theory_papers": {
            "Theory Paper 1": {
              "paper_id": 1,
              "paper_number": 1,
              "paper_type": "theory",
              "total_marks": 100,
              "questions": [...]
            }
          },
          "practical_papers": {
            "Practical Paper 1": {
              "paper_id": 3,
              "paper_number": 1,
              "paper_type": "practical",
              "total_marks": 100,
              "questions": [...]
            }
          }
        }
      }
    }
  },
  "_debug": [
    "Found learner: {...}",
    "Found class with trade_id: 1",
    "From arpl_trades table - Trade: Bricklaying, OFO: 641201",
    "Final trade selected: Bricklaying (OFO: 641201)",
    "Total papers loaded: 5",
    "Created paper structure with 5 papers",
    "Total questions processed: 50"
  ]
}
```

### Check Debug Logs:
Look for:
- ✅ `"From arpl_trades table - Trade: Bricklaying"`
- ✅ Papers grouped correctly (theory/practical)
- ✅ Questions linked to correct papers

---

## 📊 Database Queries Used

```sql
-- Step 1: Get trade information
SELECT c.*, t.trade_name, t.ofo_number
FROM class c
LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
WHERE c.classID = ?

-- Step 2: Get papers for this trade
SELECT * FROM arpl_papers 
WHERE trade_ofo_code = '641201'  -- Bricklaying OFO
ORDER BY paper_number, paper_type

-- Step 3: Get questions
SELECT * FROM arpl_questions 
ORDER BY paper_id, question_number

-- Step 4: Link questions to papers via paper_id (done in PHP)
```

---

## ✅ Verification Checklist

### After Upload:
- [ ] File uploaded to `/public_html/mobile/get_arpl_hierarchy.php`
- [ ] File permissions set to `644`
- [ ] Test endpoint with cURL (see above)
- [ ] Check response contains correct trade name
- [ ] Verify debug logs show database query results
- [ ] Test on device (login as ARPL Assessor)
- [ ] View Bricklayer class
- [ ] Click on learner
- [ ] Verify ARPL breakdown shows "Bricklaying" not "Electrician"

### Device Testing:
```bash
# Monitor logs during test
adb logcat | findstr ARPL
```

**Expected logs:**
```
[ARPL_TRADE] ✅ Trade name: Bricklaying
ARPL DEBUG DATA: ["From arpl_trades table - Trade: Bricklaying, OFO: 641201"]
```

---

## 🔧 Troubleshooting

### If trade still shows wrong:
1. Check `arpl_trades` table has correct data:
   ```sql
   SELECT * FROM arpl_trades;
   ```

2. Check `class` table has correct `trade_id`:
   ```sql
   SELECT classID, className, trade_id FROM class WHERE classID = 797;
   ```

3. Clear PHP opcache:
   ```php
   opcache_reset();
   ```
   Or restart PHP-FPM

4. Check PHP error logs:
   ```bash
   tail -f /var/log/php_errors.log
   ```

### If no papers show:
1. Check `arpl_papers` table has data:
   ```sql
   SELECT * FROM arpl_papers WHERE trade_ofo_code = '641201';
   ```

2. Check OFO code matches between tables:
   ```sql
   SELECT t.ofo_number, COUNT(p.id) as paper_count
   FROM arpl_trades t
   LEFT JOIN arpl_papers p ON t.ofo_number = p.trade_ofo_code
   GROUP BY t.ofo_number;
   ```

---

## 📝 Final Status

**Code Changes:** ✅ Complete
**Database Connection:** ✅ Uses connection.php
**Logic:** ✅ Correct (trade → papers → questions)
**Production Ready:** ✅ Yes

**Next Step:** Upload to server and test! 🚀

---

**File Version:** Final
**Last Modified:** July 23, 2026
**Ready for Production:** ✅ YES
