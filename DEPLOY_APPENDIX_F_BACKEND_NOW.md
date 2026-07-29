# 🚀 DEPLOY APPENDIX F BACKEND - STEP BY STEP

**Current Status:** APK installed and working ✅  
**Problem:** Workplace Observation section is empty  
**Solution:** Deploy backend files to server

---

## 📋 WHAT YOU NEED TO UPLOAD

### Step 1: Create Database Tables
**File:** `create_appendix_f_redesign_tables.sql`  
**Action:** Execute in phpMyAdmin

### Step 2: Upload PHP Files
**Files to upload to `/mobile/` folder:**
1. `mobile/get_appendix_f_data.php`
2. `mobile/save_appendix_f_data.php`
3. `mobile/check_bricklaying_activities.php` (diagnostic - optional)

---

## 🔧 DEPLOYMENT STEPS

### STEP 1: Verify Activities Table Exists

Before anything else, check if the activities table has data:

1. **Upload** `mobile/check_bricklaying_activities.php` to your server
2. **Visit:** `https://rlms.rlms.co.za/mobile/check_bricklaying_activities.php`

**Expected Output:**
```json
{
  "status": "success",
  "message": "Table exists with activities",
  "total_activities": 20,
  "sample_activities": [
    {
      "id": 1,
      "activityName": "Reinforced Concrete Construction",
      "created_at": "2024-..."
    },
    ...
  ]
}
```

**If table doesn't exist or is empty:**
You need to create it first. The activities should already exist from previous ARPL work, but if not, you'll need to populate it.

---

### STEP 2: Create Appendix F Tables

1. **Open phpMyAdmin** on `rlms.rlms.co.za`
2. **Select database:** `rlms`
3. **Click:** "SQL" tab
4. **Copy contents** of `create_appendix_f_redesign_tables.sql`
5. **Paste** into SQL window
6. **Click:** "Go" button

**Expected Result:**
- 3 tables created successfully:
  - `arpl_appendix_f_knowledge`
  - `arpl_appendix_f_practical_tasks`
  - `arpl_appendix_f_workplace_observations`

**Verification Query:**
```sql
SHOW TABLES LIKE 'arpl_appendix_f%';
```

Should show 3 tables.

---

### STEP 3: Upload PHP Files

Using FileZilla, cPanel File Manager, or your preferred FTP tool:

**Upload these files to `/mobile/` folder:**

1. **get_appendix_f_data.php**
   - Local: `c:\projects\rlmss\mobile\get_appendix_f_data.php`
   - Server: `/mobile/get_appendix_f_data.php`

2. **save_appendix_f_data.php**
   - Local: `c:\projects\rlmss\mobile\save_appendix_f_data.php`
   - Server: `/mobile/save_appendix_f_data.php`

---

### STEP 4: Test Backend

Test the GET endpoint with curl or browser:

**URL:** `https://rlms.rlms.co.za/mobile/get_appendix_f_data.php`

**Test with POST data:**
```json
{
  "learnerID": 11701,
  "ofoNumber": "641201"
}
```

**Expected Response:**
```json
{
  "status": "success",
  "data": {
    "knowledge": [],
    "practical": [],
    "workplace_observations": [
      {
        "activity_id": 1,
        "task_observed": "Reinforced Concrete Construction",
        "technical_knowledge": 1,
        "interpretation_of_instructions": 1,
        "team_work_attitude": 1,
        "has_rating": false
      },
      ...
    ]
  }
}
```

The `workplace_observations` array should have activities from `arplappxe_bricklaying_activities`.

---

## 🧪 TEST IN THE APP

After deploying backend:

1. **Open app** on device
2. **Login** as Facilitator ID 6
3. **Navigate:** Menu → View Complete Toolkit
4. **Select:** Anele Cele (ID 11701, Class 797)
5. **Click:** "Appx F" tab
6. **Wait** 2-3 seconds for data to load

### ✅ Expected Results:

**Knowledge Section:**
- Empty (ready to add)
- "Add Question" button visible in edit mode

**Practical Section:**
- Empty (ready to add)
- "Add Task" button visible in edit mode

**Workplace Observation Section:**
- Shows ~20 activities from database
- Each activity has 3 dropdown fields:
  - Technical Knowledge (1=Fair, 2=Good, 3=Excellent)
  - Interpretation of Instructions (1=Fair, 2=Good, 3=Excellent)
  - Team Work Attitude (1=Fair, 2=Good, 3=Excellent)
- Dropdowns work in edit mode
- Shows selected values in view mode

---

## 🐛 TROUBLESHOOTING

### Problem: Workplace Observation still empty

**Check 1: Activities table**
```sql
SELECT COUNT(*) FROM arplappxe_bricklaying_activities;
```
Should return > 0

**Check 2: PHP file uploaded correctly**
Visit: `https://rlms.rlms.co.za/mobile/get_appendix_f_data.php`
Should NOT show 404 error

**Check 3: Check PHP errors**
Look in server error logs or add to top of PHP file:
```php
ini_set('display_errors', 1);
error_reporting(E_ALL);
```

### Problem: Dropdowns not showing

Make sure you're in **Edit Mode** (toggle switch at top of page)

### Problem: Save not working

Check `save_appendix_f_data.php` is uploaded correctly.

---

## 📁 FILE LOCATIONS

**Local Files (Your Computer):**
- `c:\projects\rlmss\create_appendix_f_redesign_tables.sql`
- `c:\projects\rlmss\mobile\get_appendix_f_data.php`
- `c:\projects\rlmss\mobile\save_appendix_f_data.php`
- `c:\projects\rlmss\mobile\check_bricklaying_activities.php`

**Server Locations:**
- SQL: Execute in phpMyAdmin
- PHP: `/mobile/` folder on `rlms.rlms.co.za`

---

## ✨ AFTER DEPLOYMENT

Once deployed, you should be able to:

1. **Add knowledge questions** dynamically
2. **Add practical tasks** dynamically
3. **Rate workplace activities** using dropdowns
4. **Save all data** and have it persist
5. **View saved data** when reopening

---

## 🎯 QUICK CHECKLIST

- [ ] Verified `arplappxe_bricklaying_activities` has data
- [ ] Executed `create_appendix_f_redesign_tables.sql` in phpMyAdmin
- [ ] Uploaded `get_appendix_f_data.php` to `/mobile/`
- [ ] Uploaded `save_appendix_f_data.php` to `/mobile/`
- [ ] Tested GET endpoint returns activities
- [ ] Tested in app - Workplace Observation shows activities
- [ ] Tested Add Question/Task buttons work
- [ ] Tested dropdowns work in Workplace Observation
- [ ] Tested Save button saves data
- [ ] Tested data persists after closing and reopening

---

**Need Help?** Let me know which step you're stuck on!
