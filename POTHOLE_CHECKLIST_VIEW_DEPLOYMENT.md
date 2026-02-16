# Pothole Checklist View Feature - Deployment Guide

## Overview
This update adds the ability to view previously filled pothole checklist forms, with read-only display and edit capabilities.

## What's New
- View existing filled forms in read-only mode
- Edit button to modify existing checklists
- Visual indicator when viewing vs editing
- Backend PHP endpoints for saving and retrieving checklists

## Files Created/Modified

### New Files
1. **create_pothole_checklist_table.sql** - Database table for system-generated checklists
2. **php/save_pothole_checklist.php** - Endpoint to save checklist form data
3. **php/get_pothole_checklist.php** - Endpoint to retrieve checklist data
4. **test_pothole_checklist.php** - Test script for the endpoints

### Modified Files
1. **lib/potholeChecklistpage.dart** - Added view mode functionality

## Deployment Steps

### Step 1: Create Database Table
Run the SQL script to create the pothole_checklists table:

```bash
mysql -u your_username -p your_database < create_pothole_checklist_table.sql
```

Or execute in phpMyAdmin/MySQL Workbench:
```sql
-- Copy and paste contents of create_pothole_checklist_table.sql
```

### Step 2: Upload PHP Files
Upload these files to your server:
- `php/save_pothole_checklist.php`
- `php/get_pothole_checklist.php`

Make sure they're in the same directory as your other PHP files and have access to `config.php`.

### Step 3: Test the Endpoints

#### Option A: Using the test script
```bash
php test_pothole_checklist.php
```

#### Option B: Manual testing with curl

**Test Save:**
```bash
curl -X POST http://your-server.com/php/save_pothole_checklist.php \
  -H "Content-Type: application/json" \
  -d '{
    "learner_id": "TEST123",
    "learner_name": "John Doe",
    "learner_id_number": "9001015800080",
    "assessor_id": "ASSESS001",
    "assessor_name": "Jane Smith",
    "venue": "Test Center",
    "assessment_date": "2025-11-05",
    "checklist_items": [
      {
        "section": "PRE – OPERATIONAL SAFETY",
        "label": "Wears appropriate PPE",
        "value": true,
        "notes": "All good"
      }
    ]
  }'
```

**Test Retrieve:**
```bash
curl "http://your-server.com/php/get_pothole_checklist.php?learner_id=TEST123&assessor_id=ASSESS001&assessment_date=2025-11-05"
```

### Step 4: Deploy Flutter App
Rebuild and deploy your Flutter app with the updated `potholeChecklistpage.dart`.

```bash
flutter clean
flutter pub get
flutter build apk --release
```

## How It Works

### User Flow

1. **Opening a Checklist:**
   - When user opens the pothole checklist page, the app automatically checks if a filled form exists
   - If found, it loads the data in **view mode** (read-only)

2. **View Mode:**
   - All form fields are read-only
   - Radio buttons are disabled
   - Signature pads are disabled with grey background
   - Blue banner shows "Viewing existing checklist"
   - Blue "Edit Checklist" button is displayed

3. **Edit Mode:**
   - Click "Edit Checklist" to enable editing
   - All fields become editable
   - Green "Save Checklist" button appears
   - Save updates the existing record

### Database Structure

**Table: pothole_checklists**
- `id` - Auto-increment primary key
- `learner_id` - Learner identifier
- `learner_name` - Full name
- `learner_id_number` - ID number
- `assessor_id` - Assessor/facilitator identifier
- `assessor_name` - Assessor full name
- `venue` - Assessment venue
- `assessment_date` - Date of assessment
- `checklist_items` - JSON array of checklist items
- `learner_signature` - Signature data
- `assessor_signature` - Signature data
- `created_at` - Creation timestamp
- `updated_at` - Last update timestamp

**Unique Constraint:** (learner_id, assessor_id, assessment_date)
- Prevents duplicate checklists for the same learner/assessor/date combination
- Updates existing record if you save again

## API Endpoints

### POST /php/save_pothole_checklist.php
Saves or updates a pothole checklist.

**Request Body:**
```json
{
  "learner_id": "string",
  "learner_name": "string",
  "learner_id_number": "string",
  "assessor_id": "string",
  "assessor_name": "string",
  "assessor_reg_number": "string",
  "venue": "string",
  "assessment_date": "YYYY-MM-DD",
  "learner_signature": "string",
  "assessor_signature": "string",
  "checklist_items": [
    {
      "section": "string",
      "label": "string",
      "value": boolean,
      "notes": "string"
    }
  ]
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Pothole checklist saved successfully",
  "checklist_id": 123
}
```

### GET /php/get_pothole_checklist.php
Retrieves a pothole checklist.

**Query Parameters:**
- `learner_id` - Required
- `assessor_id` - Required
- `assessment_date` - Required (YYYY-MM-DD format)

**Response:**
```json
{
  "status": "success",
  "data": {
    "id": 123,
    "learner_id": "string",
    "learner_name": "string",
    "venue": "string",
    "assessment_date": "YYYY-MM-DD",
    "checklist_items": {
      "PRE – OPERATIONAL SAFETY": [
        {
          "label": "Wears appropriate PPE",
          "value": true,
          "notes": "All good"
        }
      ]
    }
  }
}
```

## Troubleshooting

### Checklist Not Loading
1. Check browser/app console for errors
2. Verify PHP endpoints are accessible
3. Check database table exists
4. Verify config.php database credentials

### Data Not Saving
1. Check PHP error logs
2. Verify database permissions
3. Test with curl/Postman
4. Check JSON format in request

### View Mode Not Working
1. Ensure `_loadExistingChecklist()` is called in initState
2. Check that `_items` is initialized before loading data
3. Verify `_isViewMode` flag is being set correctly

## Testing Checklist

- [ ] Database table created successfully
- [ ] PHP files uploaded to server
- [ ] Test script runs without errors
- [ ] Can save a new checklist via form
- [ ] Can view existing checklist (read-only)
- [ ] Can edit existing checklist
- [ ] Can update existing checklist
- [ ] Scanned documents still work
- [ ] Offline functionality still works

## Support

If you encounter issues:
1. Check the test_pothole_checklist.php output
2. Review PHP error logs
3. Check Flutter console for errors
4. Verify all files are uploaded correctly
