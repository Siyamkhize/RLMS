# Session 13B - Classes API HTTP 400 Error Fixed ✅

**Date:** July 10, 2026  
**Issue:** HTTP 400 error when loading classes  
**Error:** `Failed to load resource: the server responded with a status of 400 (Bad Request)`  
**Status:** 🎉 **FIXED**

---

## Root Cause Found

The `get_arpl_classes.php` API was trying to JOIN with the `site` table which doesn't exist in your database:

```sql
SELECT c.* FROM class c
LEFT JOIN site s ON c.siteID = s.siteID  ← ERROR: table 'site' doesn't exist
```

This caused a query preparation error that returned HTTP 400.

---

## Solution Applied

Removed the `LEFT JOIN site` clause and only query the `class` table:

**OLD:**
```php
$sql_classes = "
    SELECT c.classID, c.className, c.numberOfLearners, c.siteID, s.siteName
    FROM class c
    LEFT JOIN site s ON c.siteID = s.siteID  ← REMOVED
    WHERE c.trade_id = ?
";
```

**NEW:**
```php
$sql_classes = "
    SELECT c.classID, c.className, c.numberOfLearners, c.siteID, c.trade_id
    FROM class c
    WHERE c.trade_id = ?
    ORDER BY c.className ASC
";
```

Also updated `classes.php` UI to not display siteName since we don't fetch it.

---

## Test Result ✅

```
Status: HTTP 200 ✅
Response: {
  "status": "success",
  "trade_name": "Bricklayer",
  "ofo_code": "641201",
  "trade_id": 4,
  "classes": [
    {
      "classID": 783,
      "className": "Bricklaying",
      "numberOfLearners": 10,
      "siteID": 828,
      "trade_id": 4
    }
  ],
  "count": 1
}

✅ Found 1 class: Bricklaying (10 learners)
```

---

## Files Fixed

- ✅ `c:\projects\rlmss\web\api\get_arpl_classes.php` - Removed non-existent JOIN
- ✅ `c:\projects\rlmss\web\classes.php` - Updated UI to not show siteName
- ✅ Deployed to xampp

---

## Test Now

1. **Clear cache:** Ctrl+Shift+Delete
2. **Hard refresh:** Ctrl+Shift+F5
3. **Navigate:** Index → Select "Bricklayer" → Click "Next"
4. **Classes page:** Should now load classes without error
5. **Should see:** "Bricklaying" class with "10 learners"
6. **Click class:** Select the class
7. **Click Continue:** Should proceed to learners page

---

## Next Steps

1. ✅ Classes API now returns data
2. ✅ Classes page displays
3. Next: Learners page will work (uses classID)

---

**Status: Ready to test the complete workflow** 🎉
