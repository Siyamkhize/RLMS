# Moderator Pothole Checklist Implementation

## Overview
This implementation adds pothole checklist moderation functionality to the ModeratorPage. Moderators can now view marks assigned by assessors and either approve or disapprove them with comments.

## Key Features

### 1. **View Marks (Not Edit)**
- Moderators can view the marks that were assigned by assessors
- They cannot modify the marks themselves
- Marks are displayed in a read-only format

### 2. **Approval/Disapproval System**
- Moderators can select either "Approved" or "Disapproved" status
- When disapproving, a comment is required to explain the reason
- The status is saved to the `approval_status` column in the marks table
- Comments are saved to the `comment` column

### 3. **Non-Destructive Updates**
- When a moderator withdraws (disapproves), the record is NOT deleted
- Instead, the `approval_status` column is updated to 'Disapproved'
- The moderator's comment is saved in the `comment` column
- Original marks and assessor comments remain intact

## Database Changes

### Table: `pothole_checklist_marks`

Two new columns have been added:

| Column | Type | Description |
|--------|------|-------------|
| `approval_status` | ENUM('Approved', 'Disapproved') | Moderator's approval decision |
| `comment` | VARCHAR(256) | Moderator's comment (required for disapproval) |

### SQL Migration Script
Run the following script to add the required columns:
```sql
-- File: add_moderation_columns_to_pothole_marks.sql
ALTER TABLE pothole_checklist_marks 
ADD COLUMN approval_status ENUM('Approved', 'Disapproved') NULL DEFAULT NULL
AFTER comments;

ALTER TABLE pothole_checklist_marks 
ADD COLUMN comment VARCHAR(256) NULL DEFAULT NULL
AFTER approval_status;
```

## Files Modified/Created

### Flutter Files (lib/)
1. **lib/ModeratorPage.dart** - Updated with new pages:
   - Added "Pothole Checklist" menu item
   - `ModeratorPotholeChecklistPage` - Class list page
   - `ModeratorPotholeChecklistLearnerListPage` - Learner list with moderation status
   - `ModeratorPotholeChecklistModerationPage` - Moderation form page

### PHP Files (php/)
1. **php/save_pothole_moderation.php** - NEW
   - Handles saving moderation status and comments
   - Updates `approval_status` and `comment` columns
   - Validates that records exist before updating

2. **php/get_pothole_checklist_marks.php** - UPDATED
   - Now returns `approval_status` and `comment` fields
   - Allows moderators to see existing moderation status

### SQL Files
1. **add_moderation_columns_to_pothole_marks.sql** - NEW
   - Migration script to add moderation columns

## User Flow

### For Moderators:

1. **Navigate to Pothole Checklist**
   - Open ModeratorPage
   - Select "Pothole Checklist" from the drawer menu

2. **Select Class**
   - View list of classes
   - Click "Select" button on desired class

3. **View Learners**
   - See list of learners in the class
   - Button states indicate moderation status:
     - **"No Marks"** (Grey) - Assessor hasn't marked yet
     - **"Moderate"** (Orange) - Marks exist, awaiting moderation
     - **"View (Approved)"** (Green) - Already approved
     - **"View (Disapproved)"** (Red) - Already disapproved

4. **Moderate Marks**
   - Click on a learner with marks
   - View:
     - Learner information
     - Assessor's marks (read-only)
     - Assessor's comments (read-only)
   - Select approval status:
     - **Approved** - Accept the marks
     - **Disapproved** - Reject the marks (requires comment)
   - Enter moderator comment (mandatory for disapproval)
   - Click "Save Moderation"

5. **After Moderation**
   - Status is saved to database
   - Record is updated, not deleted
   - Return to learner list
   - Button now shows the moderation status

## API Endpoints

### 1. Get Pothole Checklist Marks
**Endpoint:** `get_pothole_checklist_marks.php`
**Method:** GET
**Parameters:**
- `learner_id` - Learner ID
- `assessor_id` - Assessor ID (optional for moderator view)
- `assessment_date` - Assessment date

**Response:**
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "learner_id": "12345",
    "assessor_id": "67890",
    "assessment_date": "2026-01-19",
    "marks": 85,
    "comments": "Good work",
    "approval_status": "Approved",
    "comment": "Marks are appropriate",
    "created_at": "2026-01-19 10:00:00",
    "updated_at": "2026-01-19 11:00:00"
  }
}
```

### 2. Save Pothole Moderation
**Endpoint:** `save_pothole_moderation.php`
**Method:** POST
**Content-Type:** application/json

**Request Body:**
```json
{
  "learner_id": "12345",
  "assessment_date": "2026-01-19",
  "approval_status": "Approved",
  "comment": "Marks are appropriate"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Moderation saved successfully",
  "affected_rows": 1
}
```

## Deployment Steps

### 1. Database Migration
```bash
# Run the SQL migration script
mysql -u username -p database_name < add_moderation_columns_to_pothole_marks.sql
```

### 2. Deploy PHP Files
```bash
# Copy new PHP file to server
cp php/save_pothole_moderation.php /path/to/server/mobile/

# Update existing PHP file
cp php/get_pothole_checklist_marks.php /path/to/server/mobile/
```

### 3. Build and Deploy Flutter App
```bash
# Build the APK
flutter build apk --release

# Or build for specific environment
flutter build apk --release --dart-define=ENV=production
```

### 4. Test the Implementation
1. Login as a moderator
2. Navigate to Pothole Checklist
3. Select a class with learners who have been marked
4. Verify you can see marks but not edit them
5. Test approval workflow
6. Test disapproval workflow (with comment)
7. Verify status persists after saving

## Validation Rules

### Approval Status
- Must be either "Approved" or "Disapproved"
- Cannot be empty when submitting

### Moderator Comment
- Required when status is "Disapproved"
- Optional when status is "Approved"
- Maximum length: 256 characters

## Error Handling

### Common Errors:
1. **"No marks record found"** - Assessor hasn't marked this learner yet
2. **"Please select approval status"** - Moderator didn't choose Approved/Disapproved
3. **"Please provide a comment for withdrawal"** - Comment required for disapproval
4. **"Invalid approval status"** - Status must be Approved or Disapproved

## Security Considerations

1. **Role-Based Access** - Only moderators can access this functionality
2. **Data Integrity** - Original marks are never deleted, only status is updated
3. **Audit Trail** - `updated_at` timestamp tracks when moderation occurred
4. **Input Validation** - All inputs are validated and sanitized

## Future Enhancements

Potential improvements for future versions:
1. Add moderator ID tracking to know who moderated
2. Add moderation history (track changes over time)
3. Add bulk moderation for multiple learners
4. Add filtering by moderation status
5. Add reports showing moderation statistics
6. Add notifications to assessors when marks are disapproved

## Testing Checklist

- [ ] Database columns added successfully
- [ ] PHP endpoints deployed and accessible
- [ ] Flutter app builds without errors
- [ ] Moderator can view class list
- [ ] Moderator can view learner list
- [ ] Button states correctly reflect moderation status
- [ ] Marks display correctly (read-only)
- [ ] Approval saves successfully
- [ ] Disapproval requires comment
- [ ] Disapproval with comment saves successfully
- [ ] Status persists after page refresh
- [ ] Already moderated records show correct status
- [ ] Error messages display appropriately

## Support

For issues or questions:
1. Check the error logs in PHP files
2. Check Flutter console for client-side errors
3. Verify database columns exist
4. Verify PHP files are deployed correctly
5. Check network connectivity between app and server

## Summary

This implementation provides a complete moderation workflow for pothole checklist marks:
- ✅ View marks assigned by assessors
- ✅ Approve or disapprove marks
- ✅ Add comments (required for disapproval)
- ✅ Non-destructive updates (no deletion)
- ✅ Status tracking in database
- ✅ Visual indicators for moderation status
- ✅ Complete audit trail

The system maintains data integrity while providing moderators with the tools they need to review and validate assessor marks.
