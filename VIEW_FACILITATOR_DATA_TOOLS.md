# 📊 Facilitator Data Viewing Tools

I've created comprehensive tools to view ALL facilitator data from the server database. Use these to diagnose sync issues.

---

## 🛠️ Available Tools

### 1. **view_all_facilitators.php** ⭐ RECOMMENDED
**Beautiful web interface with complete data view**

**URL:** `https://your-server.com/php/view_all_facilitators.php`

**Features:**
- ✅ Visual dashboard with summary statistics
- ✅ Expandable rows to see all fields
- ✅ Color-coded NULL vs empty vs actual values
- ✅ Fingerprint template status indicators
- ✅ JSON export with copy button
- ✅ Click any row to see complete details
- ✅ Shows password hashes, email, class assignments
- ✅ Highlights incomplete records

**Best for:** Visual inspection and quick overview

---

### 2. **get_facilitator_raw.php**
**JSON API endpoint for raw data**

**URLs:**
- All facilitators: `https://your-server.com/php/get_facilitator_raw.php`
- Specific ID: `https://your-server.com/php/get_facilitator_raw.php?id=60`

**Response Format:**
```json
{
  "success": true,
  "count": 1,
  "data": {
    "facilitator_id": "60",
    "firstName": "Zamokuhle",
    "lastName": "MLONDO",
    "email": "zamokuhle@mtltechnical.co.za",
    "password": "$2y$10$...",
    ...
  }
}
```

**Best for:** API testing, programmatic access

---

### 3. **dump_facilitator_table.php**
**Plain text database dump**

**URL:** `https://your-server.com/php/dump_facilitator_table.php`

**Features:**
- ✅ Shows table structure (columns, types, keys)
- ✅ Complete field-by-field breakdown
- ✅ NULL/empty string indicators
- ✅ Fingerprint status for each template
- ✅ Includes sync endpoint JSON output
- ✅ Plain text for easy copy/paste

**Best for:** Detailed analysis, sharing with developers

---

### 4. **test_facilitator_sync.php**
**Original sync test page**

**URL:** `https://your-server.com/php/test_facilitator_sync.php`

**Features:**
- ✅ Shows exactly what sync endpoint returns
- ✅ JSON format that mobile app receives
- ✅ Table view with NULL highlighting
- ✅ Detailed first record view

**Best for:** Testing sync endpoint output

---

## 📋 How to Use These Tools

### Step 1: Check Server Has Data
Visit: **view_all_facilitators.php**

**Look for:**
- Total facilitator count > 0
- Facilitator ID 60 exists
- firstName = "Zamokuhle"
- lastName = "MLONDO"
- email = "zamokuhle@mtltechnical.co.za"
- password starts with "$2y$10$"
- Fingerprint templates have data (if enrolled)

**Screenshot or copy the data you see**

---

### Step 2: Verify Specific Facilitator
Visit: **get_facilitator_raw.php?id=60**

**This shows:**
```json
{
  "success": true,
  "count": 1,
  "data": {
    "facilitator_id": "60",
    "firstName": "Zamokuhle",
    "lastName": "MLONDO",
    "role": "Facilitator",
    "email": "zamokuhle@mtltechnical.co.za",
    "classID": "67",
    "password": "$2y$10$NjZP3Z.QSL3Xx7dQo8A4jezcSooOccs.QgNPPnb5VuBe3JH0kaX.2",
    "assessorNo": "",
    "f_signature": "facilitatorSignatures/1755671144_60_signature.png",
    ...
  }
}
```

**Compare this with what you see in local database!**

---

### Step 3: Get Complete Dump
Visit: **dump_facilitator_table.php**

**Save the output** - it shows:
1. Table structure
2. Total records
3. Every field of every record
4. NULL vs empty indicators
5. Fingerprint status
6. Exact JSON that sync returns

---

## 🔍 What to Look For

### ✅ Good Data (Server)
```
firstName: Zamokuhle
lastName: MLONDO
email: zamokuhle@mtltechnical.co.za
password: $2y$10$NjZP3Z.QSL3Xx7dQo8A4je...
```

### ❌ Bad Data (Local - Current Problem)
```
firstName: [EMPTY STRING]
lastName: [EMPTY STRING]
email: zamokuhle@mtltechnical.co.za
password: null (string "null", not NULL)
```

---

## 🎯 Diagnosis Steps

1. **Open view_all_facilitators.php in browser**
   - Verify server has complete data
   - Click on facilitator ID 60 to expand
   - Check all fields have values

2. **Compare with Local Database**
   - Run app and view local facilitator table
   - Compare field-by-field with server

3. **Run Sync with Debug Logs**
   - Trigger facilitator sync in app
   - Check logs show server data (see FACILITATOR_SYNC_DEBUG.md)

4. **Identify Where Data is Lost**
   - If server has data but logs don't → Network/JSON issue
   - If logs have data but DB doesn't → Insert issue
   - If logs show mismatch warning → SQLite corruption

---

## 📤 Share Results

When reporting the issue, include:

1. **Screenshot of view_all_facilitators.php** showing ID 60
2. **Raw JSON from get_facilitator_raw.php?id=60**
3. **Current local database values** (the RowData you showed)
4. **Sync logs** from the app

This will pinpoint exactly where firstName/lastName are being lost!

---

## 🚀 Quick Access URLs

Replace `your-server.com` with your actual server:

- 📊 **Visual Dashboard:** `https://your-server.com/php/view_all_facilitators.php`
- 📄 **JSON All:** `https://your-server.com/php/get_facilitator_raw.php`
- 📄 **JSON ID 60:** `https://your-server.com/php/get_facilitator_raw.php?id=60`
- 📋 **Text Dump:** `https://your-server.com/php/dump_facilitator_table.php`
- 🔄 **Sync Test:** `https://your-server.com/php/test_facilitator_sync.php`
- 🔄 **Sync Endpoint:** `https://your-server.com/php/sync_facilitator.php`

---

All tools are ready to use! Start with **view_all_facilitators.php** - it's the easiest to read! 🎉

