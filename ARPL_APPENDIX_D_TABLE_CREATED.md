# ARPL Appendix D: Practical Skills Assessment Evaluation Checklist

## Status
✅ **COMPLETE** - Database table and API endpoints created

## What Was Created

### 1. Database Table: `arpl_appendix_d`
**File**: `create_arpl_appendix_d_table.sql`

Stores Yes/No responses for the 22 practical skills assessment activities.

#### Table Structure:
- **Primary Key**: `id`
- **Learner Info**: `learnerID`, `assessor_id`, `ofo_number`
- **22 Activity Fields** (each with yes/no/comments):
  1. Health, Safety, Quality and Legislation
  2. Tools, Equipment and Materials
  3. Introduction to the world of work and the electrical trade
  4. Measuring and testing instruments
  5. Fundamentals of electricity
  6. Electronics
  7. Wire ways and wiring
  8. AC motors
  9. DC motors
  10. Alternators and Generators
  11. Control systems
  12. Domestic wiring and testing
  13. Industrial wiring and testing
  14. Lighting
  15. Power factor correction
  16. Maintenance and troubleshooting
  17. Cable terminations and connections
  18. Safety procedures and personal protective equipment
  19. Renewable energy systems
  20. Building Information Modelling (BIM)
  21. Communication and teamwork
  22. Environmental compliance and waste management

#### Field Pattern for Each Activity:
```sql
activity_N_yes TINYINT(1)       -- 1 = Yes, 0 = No
activity_N_no TINYINT(1)        -- 1 = No, 0 = Yes
activity_N_comments TEXT        -- Optional assessor comments
```

#### Overall Assessment Fields:
- `overall_pass` (TINYINT): 1 = Pass, 0 = Fail/Pending
- `overall_comments` (TEXT): Summary feedback
- `assessor_signature_status` (ENUM): pending/signed/verified

#### Unique Constraint:
Only one assessment per learner per assessor per OFO:
```sql
UNIQUE KEY unique_appendix_d (learnerID, assessor_id, ofo_number)
```

---

### 2. Backend API Endpoints

#### Endpoint 1: Save/Update Appendix D Assessment
**File**: `mobile/save_arpl_appendix_d.php`  
**Method**: POST  
**Content-Type**: application/json

**Request Body**:
```json
{
  "learnerID": 11515,
  "assessor_id": 1,
  "ofo_number": "671101",
  "activities": {
    "1": "yes",
    "2": "no",
    "3": "yes",
    ...
    "22": "no"
  },
  "overall_pass": true,
  "overall_comments": "Strong performance in practical assessment",
  "comments": {
    "1": "Excellent understanding of safety procedures",
    "2": "Needs more practice",
    ...
    "22": "Good environmental awareness"
  }
}
```

**Response Success (200)**:
```json
{
  "status": "success",
  "message": "Appendix D assessment created/updated successfully",
  "data": {
    "id": 123,
    "learnerID": 11515,
    "assessor_id": 1,
    "ofo_number": "671101",
    "overall_pass": 1,
    "updated_at": "2026-07-07 17:15:00"
  }
}
```

**Response Error (400)**:
```json
{
  "status": "error",
  "message": "Missing required field: activities",
  "debug": { "file": "...", "line": 123 }
}
```

---

#### Endpoint 2: Get Appendix D Assessment
**File**: `mobile/get_arpl_appendix_d.php`  
**Method**: GET

**Query Parameters**:
- `learnerID` (required): Learner database ID
- `assessor_id` (optional): If provided with ofo_number, returns specific assessment
- `ofo_number` (optional): Used with learnerID/assessor_id

**Examples**:
```
GET /mobile/get_arpl_appendix_d.php?learnerID=11515
GET /mobile/get_arpl_appendix_d.php?learnerID=11515&ofo_number=671101
GET /mobile/get_arpl_appendix_d.php?learnerID=11515&assessor_id=1&ofo_number=671101
```

**Response Success (200)**:
```json
{
  "status": "success",
  "message": "Assessment(s) retrieved successfully",
  "data": {
    "id": 123,
    "learnerID": 11515,
    "assessor_id": 1,
    "ofo_number": "671101",
    "activities": {
      "1": {
        "yes": 1,
        "no": 0,
        "comments": "Excellent understanding",
        "response": "yes"
      },
      "2": {
        "yes": 0,
        "no": 1,
        "comments": "Needs practice",
        "response": "no"
      },
      ...
      "22": {
        "yes": 1,
        "no": 0,
        "comments": "",
        "response": "yes"
      }
    },
    "overall_pass": 1,
    "overall_comments": "Strong performance",
    "assessor_signature_status": "pending",
    "created_at": "2026-07-07 17:10:00",
    "submitted_at": "2026-07-07 17:15:00"
  }
}
```

---

## Setup Instructions

### Step 1: Create the Database Table
Run the SQL script on your database server:
```bash
mysql -h 192.168.0.57 -u root -p < create_arpl_appendix_d_table.sql
```

Or connect to phpMyAdmin and execute the SQL from `create_arpl_appendix_d_table.sql`

### Step 2: Verify Files Are in Place
- ✅ `/mobile/save_arpl_appendix_d.php` - Save endpoint
- ✅ `/mobile/get_arpl_appendix_d.php` - Get endpoint
- ✅ `/create_arpl_appendix_d_table.sql` - Table schema

### Step 3: Flutter Integration (Next Steps)

Update `lib/ArplAssessorPage.dart` to:
1. Load existing Appendix D data when viewing
2. Display Yes/No checkboxes for each activity
3. Save responses via `save_arpl_appendix_d.php`
4. Integrate with the Appendix D tab UI

---

## Data Storage Strategy

### By Activity:
- Each activity stores **2 TINYINT fields** (yes/no flags)
- Only ONE can be 1, the other is 0 (mutual exclusivity enforced in app logic)
- Optional comments per activity

### By Learner:
- One row per learner-assessor-ofo combination
- Prevents duplicate assessments
- Updated timestamps track changes

### Response Format:
Activities are stored as separate fields (not JSON) for:
- Easy SQL queries
- Database indexing capability
- Direct field access
- Simple backup/restore

---

## Example Workflows

### Create New Assessment:
```
POST /mobile/save_arpl_appendix_d.php
{
  "learnerID": 11515,
  "assessor_id": 1,
  "ofo_number": "671101",
  "activities": { "1": "yes", "2": "no", ... },
  "overall_pass": false
}
→ Creates new record with ID 123
```

### Update Existing Assessment:
```
POST /mobile/save_arpl_appendix_d.php (same learnerID, assessor_id, ofo_number)
→ Updates existing record, changes timestamps
```

### Retrieve for Review:
```
GET /mobile/get_arpl_appendix_d.php?learnerID=11515&assessor_id=1&ofo_number=671101
→ Returns complete assessment with all 22 activities and responses
```

### Bulk Statistics:
```sql
SELECT 
  COUNT(CASE WHEN activity_1_yes = 1 THEN 1 END) as total_passed_activity_1,
  COUNT(CASE WHEN activity_1_no = 1 THEN 1 END) as total_failed_activity_1,
  AVG(overall_pass) as pass_rate
FROM arpl_appendix_d 
WHERE ofo_number = '671101';
```

---

## Next Steps

1. ✅ Database table created
2. ✅ Backend API endpoints created
3. ⏳ Update Flutter UI for Appendix D tab to:
   - Show 22 Yes/No checkboxes
   - Integrate with save endpoint
   - Display saved data on load
   - Add overall pass/fail indicator
   - Add comments field per activity

4. ⏳ Add sync logic to sync Appendix D responses with offline database

---

## Database Index Summary

For optimal query performance:
- `idx_appendix_d_learner` - Get all assessments for a learner
- `idx_appendix_d_assessor` - Get all assessments by an assessor
- `idx_appendix_d_ofo` - Get all assessments for an OFO
- `idx_appendix_d_created` - Get recent assessments
- `idx_appendix_d_overall` - Filter by pass/fail status

All indexes created automatically with the table.
