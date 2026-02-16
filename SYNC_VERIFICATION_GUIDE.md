# 🔄 Facilitator Sync Verification Guide

## The Goal: Server Data = Local Data

**After syncing, your offline (local) database should have EXACTLY the same data as the server database.**

---

## ✅ What Should Happen

### Server Database (MySQL)
```
facilitator_id: 60
firstName: "Zamokuhle"
lastName: "MLONDO"
email: "zamokuhle@mtltechnical.co.za"
password: "$2y$10$NjZP3Z.QSL3Xx7dQo8A4jezcSooOccs..."
classID: 67
```

### Local Database (SQLite) - After Sync
```
facilitator_id: 60
firstName: "Zamokuhle"          ← SHOULD MATCH SERVER
lastName: "MLONDO"              ← SHOULD MATCH SERVER
email: "zamokuhle@mtltechnical.co.za"
password: "$2y$10$NjZP3Z.QSL3Xx7dQo8A4jezcSooOccs..."
classID: 67
```

**✅ PERFECT - Data is identical!**

---

## ❌ What's Currently Happening (THE PROBLEM)

### Server Database (MySQL)
```
facilitator_id: 60
firstName: "Zamokuhle"
lastName: "MLONDO"
email: "zamokuhle@mtltechnical.co.za"
password: "$2y$10$NjZP3Z.QSL3Xx7dQo8A4jezcSooOccs..."
```

### Local Database (SQLite) - After Sync
```
facilitator_id: 1               ← WRONG! Should be 60
firstName: ""                   ← EMPTY! Should be "Zamokuhle"
lastName: ""                    ← EMPTY! Should be "MLONDO"
email: "zamokuhle@mtltechnical.co.za"  ← Correct
password: "null"                ← WRONG! Should be hash, not string "null"
```

**❌ DATA IS BEING LOST OR CORRUPTED DURING SYNC!**

---

## 🔍 Step-by-Step Verification

### Step 1: Check What Server Has
Visit: `https://your-server.com/php/verify_sync_data.php?id=60`

**This shows:**
- ✅ What's currently on the server
- ✅ What your local database SHOULD have after sync
- ✅ Expected values for every field

**Screenshot or note down the values**

### Step 2: Run Sync in Mobile App
1. Open the app
2. Go to sync/settings page
3. Trigger "Sync Facilitator Data"
4. Wait for sync to complete

### Step 3: Check Local Database
Open your local SQLite database and run:
```sql
SELECT * FROM facilitator WHERE facilitator_id = 60;
```

### Step 4: Compare Values
**Every field should EXACTLY match what verify_sync_data.php showed!**

| Field | Server Has | Local Should Have | Current Problem |
|-------|-----------|------------------|-----------------|
| facilitator_id | 60 | 60 | Shows 1 ❌ |
| firstName | "Zamokuhle" | "Zamokuhle" | Empty "" ❌ |
| lastName | "MLONDO" | "MLONDO" | Empty "" ❌ |
| email | "zamokuhle@..." | "zamokuhle@..." | Correct ✅ |
| password | "$2y$10$..." | "$2y$10$..." | String "null" ❌ |
| classID | 67 | 67 | Shows 67 ✅ |

---

## 🔧 Debugging with Logs

When you run sync, the debug logs will show **exactly** where data is lost:

### 1. Server Response
```
[FAC_SYNC] Server response received, status: 200
[FAC_SYNC] Response body length: 1523 chars
[FAC_SYNC] Received 1 facilitators from server
```
✅ This confirms server sent data

### 2. Data Received from Server
```
[FAC_SYNC] ===== FIRST RECORD FROM SERVER =====
[FAC_SYNC]   facilitator_id: 60
[FAC_SYNC]   firstName: Zamokuhle
[FAC_SYNC]   lastName: MLONDO
[FAC_SYNC]   email: zamokuhle@mtltechnical.co.za
[FAC_SYNC]   password: $2y$10$NjZP3Z.QSL3Xx7dQo8A4je...
```
✅ This confirms app received correct data from server

### 3. Data Being Inserted
```
[FAC_SYNC] Data to insert: 18 fields
[FAC_SYNC]   - facilitator_id: 60
[FAC_SYNC]   - firstName: 'Zamokuhle'
[FAC_SYNC]   - lastName: 'MLONDO'
```
✅ This confirms app is trying to insert correct data

### 4. Database Verification
```
[FAC_SYNC] ✓ VERIFIED in DB: ID=60, firstName='Zamokuhle', lastName='MLONDO'
```
✅ **SUCCESS!** Data was inserted correctly

**OR**

```
[FAC_SYNC] ⚠️ WARNING: firstName mismatch! Expected 'Zamokuhle', got ''
```
❌ **PROBLEM!** Data was lost during database insert

### 5. Final Table State
```
[FAC_SYNC] ===== FINAL TABLE STATE =====
[FAC_SYNC] Total records in table: 1
[FAC_SYNC] Record: ID=60, firstName='Zamokuhle', lastName='MLONDO'
```
✅ This confirms final state matches expectations

---

## 🎯 Tools to Verify

### 1. Server Data Tools
- **verify_sync_data.php** - Shows what local DB should have after sync
- **view_all_facilitators.php** - Visual dashboard of all server data
- **get_facilitator_raw.php?id=60** - JSON API for specific facilitator
- **dump_facilitator_table.php** - Complete text dump

### 2. App Sync Logs
- Enable debug logging in app
- Look for `[FAC_SYNC]` entries
- Check for warnings or mismatches

### 3. Local Database Query
```sql
-- Check what's actually in local database
SELECT 
    facilitator_id,
    firstName,
    lastName,
    email,
    SUBSTR(password, 1, 30) as password_preview,
    classID
FROM facilitator 
WHERE facilitator_id = 60;
```

---

## 📊 Success Criteria

### ✅ Sync is Working When:
1. Server has complete data (check with verify_sync_data.php)
2. App logs show data received from server
3. App logs show data inserted successfully
4. Local database query shows same values as server
5. **No warnings in logs about mismatches**

### ❌ Sync is Broken When:
1. Local database shows empty fields that server has values for
2. Local database shows string "null" instead of NULL
3. facilitator_id doesn't match expected ID
4. App logs show mismatch warnings
5. **Data from server ≠ Data in local database**

---

## 🚀 Quick Test

1. **Before Sync:** Note current local database values
2. **Visit:** `https://your-server.com/php/verify_sync_data.php?id=60`
3. **Copy:** Expected values shown
4. **Run Sync:** In mobile app
5. **Check Logs:** Look for success/warning messages
6. **Query Local:** Run `SELECT * FROM facilitator WHERE facilitator_id = 60`
7. **Compare:** Local values should EXACTLY match verify_sync_data.php

**If they match → Sync is working! ✅**  
**If they don't → Share the logs and comparison! ❌**

---

## 💡 Remember

**The sync is only successful when:**
```
Server Database Data = Local Database Data
```

No transformations, no data loss, no empty fields - **EXACT MATCH!** 🎯

