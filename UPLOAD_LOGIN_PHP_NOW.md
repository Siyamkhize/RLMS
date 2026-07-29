# 🚨 URGENT: UPLOAD FIXED login.php TO ONLINE SERVER

## THE PROBLEM FOUND

Your login response is **missing the `Project_pathway` field**:

```json
"classes":[{
  "project_id":"100",
  "classID":"797",
  ...
  "trade_id":"4"
}]
```

❌ **NO `Project_pathway` field!**

But the ONLINE database HAS the correct data:
```json
"Project_pathway": "[{\"type\":\"ARPL\",\"name\":\"Bricklayer\"}]"
```

---

## THE FIX

I fixed `mobile/login.php` to include `s.Project_pathway` in the SELECT query.

**Line 220 was:**
```php
SELECT s.project_id, c.* 
FROM class c
JOIN sites s ON s.siteID = c.siteID
```

**Now is:**
```php
SELECT s.project_id, s.Project_pathway, c.* 
FROM class c
JOIN sites s ON s.siteID = c.siteID
```

---

## WHAT YOU NEED TO DO

### 1. Upload This File:
```
c:\projects\rlmss\mobile\login.php
```

### 2. To This Location:
```
https://rlms.rlms.co.za/mobile/login.php
```

### 3. Test Login Again

After uploading, log in as Facilitator 6 and check the login response should now include:

```json
{
  "success": true,
  "role": "arpl_assessor",
  "facilitator_id": 6,
  "classes": [{
    "project_id": "100",
    "Project_pathway": "[{\"type\":\"ARPL\",\"name\":\"Bricklayer\"}]",  ← THIS SHOULD APPEAR!
    "classID": "797",
    ...
  }]
}
```

---

## WHY THIS IS CRITICAL

Without `Project_pathway` in the login response, the ArplAssessorPage might be crashing or not detecting ARPL correctly.

The logs show navigation starts but ArplAssessorPage never logs anything, suggesting a loading issue.

---

## AFTER UPLOADING

Send me the complete logs including:
1. Login response (should now show `Project_pathway`)
2. Navigation logs  
3. **ArplAssessorPage logs** (should appear after navigation)
4. Any error/crash messages

---

**DO THIS NOW:** Upload `mobile/login.php` to ONLINE server and test!
