# POE Endpoint Optimization Guide

## What We Did to Fix the Timeouts

### 1. Increased Timeout Values in Flutter App
- **File**: `lib/DetailsPage.dart`
- **Changes**:
  - Increased `fetchOnlineLearnerData()` timeout from 30s to 60s
  - Increased `checkUploadedStatus()` timeout from 10s to 60s

### 2. Added Timeout Protection to PHP Endpoints
- **Files Updated**:
  - `get_poe.php`
  - `mobile/get_poe.php`
  - `mobile/poe.php`
  - `mobile/poe_files/poe.php`
  - `mobile/get_poe_online.php`
  - `get_poe_online.php`
  - `mobile/poe_files/get_poe.php`
  - `mobile/check_uploads.php`
- **Added Code**:
  ```php
  // Timeout protection
  set_time_limit(60);
  ini_set('max_execution_time', 60);
  ```

### 3. Created Database Index Optimization Script
- **File**: `optimize_database_indexes.sql`
- **Run this SQL once to add indexes for faster queries**:
  ```sql
  -- Indexes to optimize get_poe.php performance
  CREATE INDEX idx_assessment_project ON assessments(project_id, unit_standard_id);
  CREATE INDEX idx_poe_lookup ON poe(learnerID, exercise);
  CREATE INDEX idx_marks_lookup ON marks(learnerID, exercise);
  ```

## How to Apply
1. Upload all modified PHP files to your server
2. Run the SQL script from `optimize_database_indexes.sql` on your database
3. Rebuild and install the Flutter app
