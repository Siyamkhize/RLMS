# APPENDIX H - GAP CLOSURE IMPLEMENTATION COMPLETE

**Date:** January 2025  
**Status:** ✅ Backend Complete - Ready for Database Setup and Flutter Integration  
**Task:** Fix Appendix H Gap Closure for All Three Trades

---

## 📋 OVERVIEW

Appendix H is the **Access Recommendation Form** where assessors evaluate learners across 4 assessment components and make recommendations:
- **Not Ready** - Learner is not ready for trade test
- **Recommended** - Learner is ready for trade test  
- **Recommended for Gap Closure** - Learner needs additional training on specific unit standards

When "Recommended for Gap Closure" is selected, the assessor must choose which **unit standards** the learner needs to complete before proceeding to trade test.

---

## 🎯 WHAT WAS COMPLETED

### 1. SQL Table Creation Scripts ✅

Created gap closure tables for all three trades:

#### **Bricklayer (OFO 641201)**
- **File:** `create_bricklayer_gap_closure_tables.sql`
- **Tables:**
  - `arplbricklayer_access_recommendation` - Stores 4 ACR item recommendations
  - `arplbricklayer_gap_unit_standards` - Stores selected unit standards for gap closure
- **Qualification ID:** 65409

#### **Electrician (OFO 671101)**  
- **File:** `create_electrician_gap_closure_tables.sql`
- **Tables:**
  - `arplelectrician_access_recommendation` - Stores 4 ACR item recommendations
  - `arplelectrician_gap_unit_standards` - Stores selected unit standards for gap closure
- **Qualification ID:** 671101

#### **Plumber (OFO 642601)**
- **File:** `create_plumber_gap_closure_tables.sql`  
- **Tables:**
  - `arplplumber_access_recommendation` - Stores 4 ACR item recommendations
  - `arplplumber_gap_unit_standards` - Stores selected unit standards for gap closure
- **Qualification ID:** 642601 or 671201

---

### 2. PHP Backend Endpoints ✅

Created 6 PHP endpoints (2 per trade):

#### **Bricklayer** (Already Existed - Confirmed Working)
- `mobile/get_bricklayer_gap_unit_standards.php` - Fetch available unit standards
- `mobile/save_bricklayer_gap_closure.php` - Save recommendations and selected unit standards

#### **Electrician** (NEW)
- `mobile/get_electrician_gap_unit_standards.php` - Fetch available unit standards for qualification 671101
- `mobile/save_electrician_gap_closure.php` - Save recommendations and selected unit standards

#### **Plumber** (NEW)
- `mobile/get_plumber_gap_unit_standards.php` - Fetch available unit standards for qualification 642601/671201
- `mobile/save_plumber_gap_closure.php` - Save recommendations and selected unit standards

---

### 3. Flutter Configuration ✅

Updated `lib/config.dart` to include new endpoint URLs:

```dart
// Bricklayer Gap Closure Endpoints (Existing)
static String get getBricklayerGapUnitStandardsUrl =>
    '$baseUrl/get_bricklayer_gap_unit_standards.php';
static String get saveBricklayerGapClosureUrl =>
    '$baseUrl/save_bricklayer_gap_closure.php';

// Electrician Gap Closure Endpoints (NEW)
static String get getElectricianGapUnitStandardsUrl =>
    '$baseUrl/get_electrician_gap_unit_standards.php';
static String get saveElectricianGapClosureUrl =>
    '$baseUrl/save_electrician_gap_closure.php';

// Plumber Gap Closure Endpoints (NEW)
static String get getPlumberGapUnitStandardsUrl =>
    '$baseUrl/get_plumber_gap_unit_standards.php';
static String get savePlumberGapClosureUrl =>
    '$baseUrl/save_plumber_gap_closure.php';
```

---

### 4. Database Verification Tool ✅

Created `check_existing_gap_closure_tables.php` to verify:
- Which gap closure tables already exist in the database
- Table structures and column definitions
- Sample data in existing tables
- Unit standards availability for each qualification

**Run this file first** to see what tables exist: `https://rlms.rlms.co.za/check_existing_gap_closure_tables.php`

---

## 📊 DATABASE STRUCTURE

### Access Recommendation Table (per trade)

Each trade has its own access recommendation table with identical structure:

```sql
CREATE TABLE arpl{trade}_access_recommendation (
    RecommendationID INT(10) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    LearnerID INT(11) NOT NULL,
    ACRID TINYINT(3) UNSIGNED NOT NULL,  -- 1-4 (4 assessment components)
    Trade VARCHAR(100),                    -- 'bricklayer', 'electrician', 'plumber'
    OFOCode VARCHAR(20),                   -- '641201', '671101', '642601'
    Status VARCHAR(50) NOT NULL,           -- 'Not Ready', 'Recommended', 'Recommended for Gap Closure'
    Remarks TEXT,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_learner_acr (LearnerID, ACRID)
);
```

### Gap Unit Standards Table (per trade)

Stores which unit standards were selected for gap closure:

```sql
CREATE TABLE arpl{trade}_gap_unit_standards (
    id INT(10) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    learner_id INT(11) NOT NULL,
    recommendation_id INT(10) UNSIGNED,
    unit_standard_id VARCHAR(50) NOT NULL,
    unit_standard_name TEXT,
    qualification_id INT(11) NOT NULL,     -- 65409, 671101, or 642601
    ofo_code VARCHAR(20),
    assigned_date DATE,
    status VARCHAR(50) DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (recommendation_id) REFERENCES arpl{trade}_access_recommendation(RecommendationID)
);
```

---

## 🔄 HOW IT WORKS

### Workflow

1. **Assessor opens Appendix H** for a learner
2. **Rates 4 assessment components:**
   - Component 1: Knowledge Assessment
   - Component 2: Practical Assessment
   - Component 3: Workplace Assessment
   - Component 4: Overall Result (ACRID 4)
3. **If "Recommended for Gap Closure" is selected for Overall Result:**
   - Gap closure section appears
   - Shows all available unit standards for that qualification
   - Assessor selects which unit standards learner needs to complete
4. **On Save:**
   - All 4 recommendations are saved to `arpl{trade}_access_recommendation`
   - If gap closure selected, unit standards are saved to `arpl{trade}_gap_unit_standards`

### Data Flow

```
Flutter App → Backend PHP → Database
     ↓             ↓             ↓
 Load Data    Fetch Unit Stds   unitstandard table
 Display UI   from unitstandard  (qualification_id)
 Select Stds  table                    ↓
     ↓             ↓             Save to gap_unit_standards
 Save Data    Save to access    and access_recommendation
              recommendation
```

---

## ⚙️ SETUP INSTRUCTIONS

### Step 1: Check Existing Tables ✅

Run the verification script to see what already exists:

```
https://rlms.rlms.co.za/check_existing_gap_closure_tables.php
```

This will show:
- ✓ Which tables exist
- ✗ Which tables are missing
- Column structures
- Sample data
- Unit standards availability

---

### Step 2: Create Missing Tables 🔨

Based on verification results, run the required SQL scripts on your database:

#### If Bricklayer tables are missing:
```sql
-- Run: create_bricklayer_gap_closure_tables.sql
```

#### If Electrician tables are missing:
```sql
-- Run: create_electrician_gap_closure_tables.sql
```

#### If Plumber tables are missing:
```sql
-- Run: create_plumber_gap_closure_tables.sql
```

You can run these via:
- phpMyAdmin → SQL tab → paste and execute
- MySQL command line
- Any SQL client tool

---

### Step 3: Upload PHP Endpoints 📤

Upload the **6 PHP files** to your production server `https://rlms.rlms.co.za/mobile/`:

**Bricklayer (if not already uploaded):**
- `mobile/get_bricklayer_gap_unit_standards.php`
- `mobile/save_bricklayer_gap_closure.php`

**Electrician (NEW):**
- `mobile/get_electrician_gap_unit_standards.php`
- `mobile/save_electrician_gap_closure.php`

**Plumber (NEW):**
- `mobile/get_plumber_gap_unit_standards.php`
- `mobile/save_plumber_gap_closure.php`

---

### Step 4: Test Backend Endpoints 🧪

Test each endpoint using Postman or similar tool:

#### **Get Unit Standards (Electrician Example)**

**Endpoint:** `POST https://rlms.rlms.co.za/mobile/get_electrician_gap_unit_standards.php`

**Request Body:**
```json
{
  "learnerID": 11701,
  "qualification_id": 671101
}
```

**Expected Response:**
```json
{
  "status": "success",
  "learnerID": 11701,
  "qualification_id": 671101,
  "trade": "electrician",
  "ofo_code": "671101",
  "unit_standards": [
    {
      "unit_standard_id": "12345",
      "unit_standard_name": "Wire a distribution board",
      "credits": 8,
      "qualification_id": 671101
    },
    ...
  ],
  "selected_unit_standards": [],
  "total_available": 25,
  "total_selected": 0
}
```

#### **Save Gap Closure (Electrician Example)**

**Endpoint:** `POST https://rlms.rlms.co.za/mobile/save_electrician_gap_closure.php`

**Request Body:**
```json
{
  "learnerID": 11701,
  "recommendations": [
    {"acrid": 1, "status": "Recommended", "remarks": "Good knowledge"},
    {"acrid": 2, "status": "Recommended", "remarks": "Good practical skills"},
    {"acrid": 3, "status": "Recommended", "remarks": "Good workplace performance"},
    {"acrid": 4, "status": "Recommended for Gap Closure", "remarks": "Needs additional training"}
  ],
  "selected_unit_standards": ["12345", "12346", "12347"],
  "ofo_code": "671101",
  "trade": "electrician"
}
```

**Expected Response:**
```json
{
  "status": "success",
  "message": "Electrician gap closure recommendations saved successfully",
  "learner_id": 11701,
  "recommendation_id": 123,
  "overall_result_status": "Recommended for Gap Closure",
  "unit_standards_saved": 3,
  "next_action": "gap_closure"
}
```

Repeat for Bricklayer and Plumber endpoints.

---

## 🔧 FLUTTER INTEGRATION (NEXT STEPS)

The Flutter app already has gap closure working for **Bricklayer** (see `ArplToolkitBricklayerPage.dart`).

### What Needs to Be Done:

1. **Create separate trade-specific pages** similar to `ArplToolkitBricklayerPage.dart`:
   - `ArplToolkitElectricianPage.dart`
   - `ArplToolkitPlumberPage.dart`

2. **OR Update ArplToolkitViewerPage.dart** to handle gap closure for all trades dynamically:
   - Detect trade from `widget.ofoNumber`
   - Call appropriate endpoint based on trade
   - Use appropriate qualification ID per trade

3. **Key changes needed in Appendix H section:**

```dart
// Determine which endpoints to use based on OFO code
String getGapUnitStandardsUrl() {
  switch (widget.ofoNumber) {
    case '641201': return AppConfig.getBricklayerGapUnitStandardsUrl;
    case '671101': return AppConfig.getElectricianGapUnitStandardsUrl;
    case '642601': return AppConfig.getPlumberGapUnitStandardsUrl;
    default: return '';
  }
}

String saveGapClosureUrl() {
  switch (widget.ofoNumber) {
    case '641201': return AppConfig.saveBricklayerGapClosureUrl;
    case '671101': return AppConfig.saveElectricianGapClosureUrl;
    case '642601': return AppConfig.savePlumberGapClosureUrl;
    default: return '';
  }
}

int getQualificationId() {
  switch (widget.ofoNumber) {
    case '641201': return 65409;    // Bricklayer
    case '671101': return 671101;   // Electrician
    case '642601': return 642601;   // Plumber
    default: return 0;
  }
}
```

4. **Reference Implementation:**
   - Study `ArplToolkitBricklayerPage.dart` lines 1090-1450
   - Copy `_buildAppendixH()`, `_buildGapClosureSection()`, and `_loadGapUnitStandards()` methods
   - Update to use dynamic endpoints based on trade

---

## 📁 FILES CREATED

### SQL Scripts
- ✅ `create_bricklayer_gap_closure_tables.sql` (already existed)
- ✅ `create_electrician_gap_closure_tables.sql` (NEW)
- ✅ `create_plumber_gap_closure_tables.sql` (NEW)

### PHP Backend
- ✅ `mobile/get_bricklayer_gap_unit_standards.php` (already existed)
- ✅ `mobile/save_bricklayer_gap_closure.php` (already existed)
- ✅ `mobile/get_electrician_gap_unit_standards.php` (NEW)
- ✅ `mobile/save_electrician_gap_closure.php` (NEW)
- ✅ `mobile/get_plumber_gap_unit_standards.php` (NEW)
- ✅ `mobile/save_plumber_gap_closure.php` (NEW)

### Verification Tools
- ✅ `check_existing_gap_closure_tables.php` (NEW)

### Flutter Config
- ✅ `lib/config.dart` (UPDATED with new endpoints)

### Documentation
- ✅ `APPENDIX_H_GAP_CLOSURE_COMPLETE.md` (THIS FILE)

---

## 🎯 NEXT ACTIONS

### For User:

1. **Run verification script:**
   ```
   https://rlms.rlms.co.za/check_existing_gap_closure_tables.php
   ```

2. **Run SQL scripts** for any missing tables via phpMyAdmin

3. **Upload 6 PHP files** to production server `/mobile/` folder

4. **Test endpoints** using Postman or similar tool

5. **Report back** with verification results

### For Flutter Development:

1. Decide approach:
   - Option A: Create separate trade-specific pages
   - Option B: Make ArplToolkitViewerPage handle all trades dynamically

2. Implement gap closure UI for Electrician and Plumber (copy from Bricklayer)

3. Test end-to-end workflow with real learners

4. Build and install new APK

---

## 📞 SUPPORT

If any issues arise:

1. Check `check_existing_gap_closure_tables.php` output first
2. Verify all SQL tables were created successfully
3. Check PHP error logs if endpoints fail
4. Ensure `unitstandard` table has data for all three qualifications
5. Verify qualification IDs: 65409 (Bricklayer), 671101 (Electrician), 642601/671201 (Plumber)

---

**Status:** Backend implementation complete ✅  
**Next:** Database setup and Flutter integration  
**Priority:** High - User requested fix for Appendix H
