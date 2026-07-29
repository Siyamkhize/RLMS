# ARPL LOGIN PATHWAY FIX - FINAL SOLUTION

## ISSUE DISCOVERED

Looking at the login response logs, the `classes` array **does NOT include `Project_pathway`**:

```json
"classes":[{
  "project_id":"100",
  "classID":"797",
  "className":"class A",
  ...
  "trade_id":"4"
}]
```

**MISSING:** `Project_pathway` field!

## ROOT CAUSE

The `mobile/login.php` query at line 220 was:
```php
SELECT s.project_id, c.* 
FROM class c
JOIN sites s ON s.siteID = c.siteID
```

This selected:
- ✅ `s.project_id` from sites table
- ✅ `c.*` (all columns from class table)
- ❌ **MISSING:** `s.Project_pathway` from sites table

## FIX APPLIED

Updated `mobile/login.php` line 220:
```php
SELECT s.project_id, s.Project_pathway, c.* 
FROM class c
JOIN sites s ON s.siteID = c.siteID
```

Now includes:
- ✅ `s.project_id`
- ✅ `s.Project_pathway` ← **ADDED**
- ✅ `c.*`

## WHY THIS MATTERS

The `ArplAssessorPage` makes a separate call to `mobile/get_classes.php` which DOES include `Project_pathway`, but based on the logs:

1. Login succeeds → returns classes WITHOUT Project_pathway
2. Navigation to ArplAssessorPage → **NO LOGS FROM ArplAssessorPage!**
3. This suggests the page isn't loading or is crashing

With `Project_pathway` in the login response, even if ArplAssessorPage crashes, at least the data is available.

## NEXT STEPS

1. **Upload fixed `mobile/login.php` to ONLINE server**
2. **Test login again** and check if `Project_pathway` appears in login response
3. **Check for ArplAssessorPage logs** - if still missing, there's a crash/loading issue
4. **If page loads**, verify pathway detection works

## EXPECTED LOGIN RESPONSE (AFTER FIX)

```json
{
  "success": true,
  "role": "arpl_assessor",
  "facilitator_id": 6,
  "classes": [{
    "project_id": "100",
    "Project_pathway": "[{\"type\":\"ARPL\",\"name\":\"Bricklayer\"}]",
    "classID": "797",
    "className": "class A",
    ...
  }],
  "auth_token": "..."
}
```

## FILES MODIFIED

- ✅ `mobile/login.php` - Added `s.Project_pathway` to SELECT query

## ACTION REQUIRED

Upload fixed `mobile/login.php` to ONLINE server and test again.
