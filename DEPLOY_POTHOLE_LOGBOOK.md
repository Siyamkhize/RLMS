# Deploy Pothole Checklist LogBook Feature

## Files to Upload

### ✅ Already Correct (No Changes Needed)
- `get_logbook_unit_standards.php` - Already correct, no update needed
- `get_logbook_marks.php` - Already correct, no update needed

### 🔄 Updated Files (Upload These)
- `save_logbook_marks.php` - **UPDATED** - Fixed to match Flutter data format

### 📝 New Test Files (Optional)
- `test_pothole_logbook.php` - Test script to verify everything works

### 📱 Flutter Files (Already Updated)
- `lib/potholeChecklistpage.dart` - Already updated with collapsible LogBook section

## Deployment Steps

### Step 1: Upload Updated PHP File

Upload the **updated** `save_logbook_marks.php` to your server:
```
/mobile/save_logbook_marks.php
```

**What changed:**
- Fixed to accept `unit_standards_marks` array format
- Matches the data structure sent by Flutter app

### Step 2: Verify Database Table

Make sure the `logbook_marks` table exists. Run this SQL if needed:

```sql
CREATE TABLE IF NOT EXISTS logbook_marks (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    unit_standard_id VARCHAR(50) NOT NULL,
    assessor_id VARCHAR(50) NOT NULL,
    marks INT(11) NOT NULL,
    assessment_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_marking (learner_id, unit_standard_id, assessor_id, assessment_date),
    INDEX idx_learner (learner_id),
    INDEX idx_unit_standard (unit_standard_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### Step 3: Upload Test File (Optional)

Upload `test_pothole_logbook.php` to test the endpoints:
```
/mobile/test_pothole_logbook.php
```

Then access:
```
https://rlms.rlms.co.za/mobile/test_pothole_logbook.php?learner_id=YOUR_LEARNER_ID
```

### Step 4: Test in Flutter App

1. **Build and run the Flutter app**
2. **Navigate to Pothole Checklist**
3. **Select a learner** who has logbook unit standards
4. **Scroll down** to see the LogBook section
5. **Test the collapsible behavior**
6. **Enter marks and save**

## What to Expect

### API Endpoints

#### 1. Get Unit Standards
```
GET /mobile/get_logbook_unit_standards.php?learner_id=123
```

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "unit_standard_id": "14336",
      "unit_standard_name": "Maintain records on a construction site",
      "unit_standard_number": "14336"
    },
    {
      "unit_standard_id": "9968",
      "unit_standard_name": "Procure materials, tools and equipment",
      "unit_standard_number": "9968"
    }
  ]
}
```

#### 2. Save Marks
```
POST /mobile/save_logbook_marks.php
Content-Type: application/json

{
  "learner_id": "123",
  "assessor_id": "456",
  "assessment_date": "2025-11-07",
  "unit_standards_marks": [
    {"unit_standard_id": "14336", "marks": 85},
    {"unit_standard_id": "9968", "marks": 90}
  ]
}
```

**Response:**
```json
{
  "status": "success",
  "message": "LogBook marks saved successfully"
}
```

#### 3. Get Marks
```
GET /mobile/get_logbook_marks.php?learner_id=123&assessor_id=456&assessment_date=2025-11-07
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "14336": 85,
    "9968": 90
  }
}
```

## UI Behavior

### Collapsed State
```
┌─────────────────────────────────────┐
│ 📖 LogBook                      ▼   │
└─────────────────────────────────────┘
```

### Expanded State
```
┌─────────────────────────────────────┐
│ 📖 LogBook                      ▲   │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ 14336 - Maintain records...  ▼ │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 9968 - Procure materials...   ▼ │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Unit Standard Expanded
```
┌─────────────────────────────────────┐
│ 14336 - Maintain records...      ▲ │
├─────────────────────────────────────┤
│ ⭐ Mark (0-100): [____]             │
└─────────────────────────────────────┘
```

## Testing Checklist

- [ ] Upload updated `save_logbook_marks.php`
- [ ] Verify database table exists
- [ ] Upload test file (optional)
- [ ] Run test file to verify API
- [ ] Build Flutter app
- [ ] Open Pothole Checklist
- [ ] Verify LogBook section appears
- [ ] Test expand/collapse main section
- [ ] Test expand/collapse unit standards
- [ ] Enter marks for unit standards
- [ ] Save checklist
- [ ] Verify marks saved in database
- [ ] Reload checklist
- [ ] Verify marks loaded correctly

## Troubleshooting

### LogBook Section Not Showing

**Check:**
1. Does learner have logbook unit standards?
2. Is API returning data?
3. Check Flutter console for errors

**Test API:**
```
https://rlms.rlms.co.za/mobile/get_logbook_unit_standards.php?learner_id=YOUR_ID
```

### Marks Not Saving

**Check:**
1. Is `save_logbook_marks.php` updated?
2. Does database table exist?
3. Are marks between 0-100?
4. Check Flutter console for errors

**Test manually:**
```bash
curl -X POST https://rlms.rlms.co.za/mobile/save_logbook_marks.php \
  -H "Content-Type: application/json" \
  -d '{
    "learner_id": "123",
    "assessor_id": "456",
    "assessment_date": "2025-11-07",
    "unit_standards_marks": [
      {"unit_standard_id": "14336", "marks": 85},
      {"unit_standard_id": "9968", "marks": 90}
    ]
  }'
```

### Marks Not Loading

**Check:**
```
https://rlms.rlms.co.za/mobile/get_logbook_marks.php?learner_id=123&assessor_id=456&assessment_date=2025-11-07
```

## Summary

### Files Changed
✅ `save_logbook_marks.php` - Updated to match Flutter data format
✅ `lib/potholeChecklistpage.dart` - Added collapsible LogBook section

### Files Already Correct
✅ `get_logbook_unit_standards.php` - No changes needed
✅ `get_logbook_marks.php` - No changes needed

### New Files
✅ `test_pothole_logbook.php` - Test script (optional)

## Status

🎉 **READY TO DEPLOY**

Upload the updated `save_logbook_marks.php` file and test!
