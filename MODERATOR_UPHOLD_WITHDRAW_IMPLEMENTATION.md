# Moderator Uphold/Withdraw Implementation

## Overview
Implemented full moderation functionality for ModeratorPage, allowing moderators to view assessor marks and either Uphold or Withdraw approval for:
- Formative Assessments
- Summative Assessments  
- LogBook entries
- Pothole Checklists (both scanned and system-generated)

## Key Features

### 1. View Assessor Marks
- Moderators can see all marks entered by assessors
- Marks display in exercise tiles with status indicators
- Assessor comments are shown in blue-bordered containers

### 2. Uphold/Withdraw Actions
- **Uphold**: Approve the assessor's marking (green status)
- **Withdraw**: Reject the assessor's marking (red status)
- Actions update approval status WITHOUT deleting data
- Optional moderator comments can be added

### 3. Status Display
- Current moderation status shown with color-coded containers:
  - Green = Upheld
  - Red = Withdrawn
- Displays moderator comments if provided
- Shows moderation date and moderator ID

## Implementation Details

### Frontend (Flutter)

#### ModeratorPage.dart Changes

**1. Enhanced Assessment Sections**
- Formative and Summative sections now show:
  - Exercise tiles with marks
  - Assessor comments
  - Moderation status (if already moderated)
  - Uphold/Withdraw buttons

**2. LogBook Section**
```dart
Widget _buildLogBookSection(Map<String, dynamic> poeData)
```
- Displays logbook exercises with marks
- Shows assessor comments
- Shows moderation status
- Includes moderation action buttons

**3. Pothole Checklist Section**
```dart
Widget _buildPotholeChecklistContent()
```
- Displays checklist with marks
- Shows assessor comments
- Shows moderation status
- Includes moderation action buttons

**4. Moderation Actions Widget**
```dart
Widget _buildModerationActions(
  String assessmentType,
  String unitStandardName,
  List<dynamic> items
)
```
- Text field for moderator comments
- Uphold button (green)
- Withdraw button (red)
- Handles submission to backend

**5. Submit Moderation Method**
```dart
Future<void> _submitModeration(
  String assessmentType,
  String unitStandardName,
  String status,
  String comment,
  List<dynamic> items
)
```
- Sends moderation decision to backend
- Updates UI on success
- Shows success/error messages
- Refreshes POE data

### Backend (PHP)

#### save_moderation.php (NEW)
Handles moderation submissions:
- Accepts: learnerId, assessmentType, unitStandardName, moderatorStatus, moderatorComment, moderatorId
- Updates appropriate table based on assessment type
- Returns success/error response
- Does NOT delete data, only updates status

**Supported Assessment Types:**
- `formative` → updates `assessments` table
- `summative` → updates `assessments` table
- `logbook` → updates `logbook_marks` table
- `pothole_checklist` → updates `pothole_checklist_marks` or `pothole_checklist_scanned` table

#### get_poe.php (UPDATED)
- Added JOIN with `assessments` table
- Includes moderation fields in response:
  - moderator_status
  - moderator_comment
  - moderator_id
  - moderation_date
  - a_comment (assessor comment)

#### view_pothole_checklists.php (UPDATED)
- Added moderation fields to both scanned and system responses:
  - moderator_status
  - moderator_comment
  - moderator_id
  - moderation_date
  - marks_scored
  - assessor_comment

### Database Changes

#### add_moderation_columns.sql (NEW)
Adds moderation columns to all relevant tables:

**Tables Updated:**
1. `assessments`
2. `logbook_marks`
3. `pothole_checklist_marks`
4. `pothole_checklist_scanned`

**Columns Added:**
- `moderator_status` VARCHAR(20) - 'upheld' or 'withdrawn'
- `moderator_comment` TEXT - Optional moderator feedback
- `moderator_id` VARCHAR(50) - ID of moderator who made decision
- `moderation_date` DATETIME - When moderation occurred

**Indexes Added:**
- Performance indexes on moderator_status for all tables

## Data Flow

### Uphold/Withdraw Process
1. Moderator views assessment with marks
2. Moderator adds optional comment
3. Moderator clicks Uphold or Withdraw
4. Frontend sends POST to `save_moderation.php`
5. Backend updates moderation status in database
6. Frontend refreshes POE data
7. Updated status displays with color coding

### Status Values
- `NULL` or empty = Not yet moderated
- `'upheld'` = Approved by moderator
- `'withdrawn'` = Rejected by moderator

## UI/UX Design

### Color Coding
- **Blue**: Assessor comments
- **Green**: Upheld status
- **Red**: Withdrawn status
- **Orange**: Pending/Not marked

### Button Layout
- Side-by-side Uphold/Withdraw buttons
- Full-width comment text field above buttons
- Clear visual distinction with icons

### Status Display
- Container with border matching status color
- Icon (check_circle for upheld, cancel for withdrawn)
- Bold status text
- Moderator comment below if provided

## Testing Checklist

### Frontend Testing
- [ ] Formative assessments show marks and moderation actions
- [ ] Summative assessments show marks and moderation actions
- [ ] LogBook shows marks and moderation actions
- [ ] Pothole Checklist shows marks and moderation actions
- [ ] Uphold button updates status to green
- [ ] Withdraw button updates status to red
- [ ] Comments are saved and displayed
- [ ] Status persists after page refresh
- [ ] Multiple moderations update correctly

### Backend Testing
- [ ] save_moderation.php accepts all assessment types
- [ ] Database updates without deleting data
- [ ] get_poe.php returns moderation fields
- [ ] view_pothole_checklists.php returns moderation fields
- [ ] Indexes improve query performance

### Database Testing
- [ ] Run add_moderation_columns.sql successfully
- [ ] All tables have moderation columns
- [ ] Indexes are created
- [ ] Existing data is preserved

## Deployment Steps

1. **Database Migration**
   ```bash
   mysql -u username -p database_name < add_moderation_columns.sql
   ```

2. **Upload PHP Files**
   - Upload `save_moderation.php` to server root
   - Update `get_poe.php` on server
   - Update `view_pothole_checklists.php` on server

3. **Build Flutter App**
   ```bash
   flutter build apk --release
   ```

4. **Test Moderation Flow**
   - Login as moderator
   - View learner POE
   - Test Uphold on formative assessment
   - Test Withdraw on summative assessment
   - Verify status displays correctly

## API Endpoints

### POST /save_moderation.php
**Request:**
```json
{
  "learnerId": "12345",
  "assessmentType": "formative|summative|logbook|pothole_checklist",
  "unitStandardName": "Unit Standard Name",
  "moderatorStatus": "upheld|withdrawn",
  "moderatorComment": "Optional comment",
  "moderatorId": "MOD001"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Moderation status updated successfully",
  "affected_rows": 1
}
```

## Files Modified/Created

### Created
- `lib/ModeratorPage.dart` - Added moderation functionality
- `save_moderation.php` - New moderation endpoint
- `add_moderation_columns.sql` - Database migration
- `MODERATOR_UPHOLD_WITHDRAW_IMPLEMENTATION.md` - This documentation

### Modified
- `get_poe.php` - Added moderation fields
- `view_pothole_checklists.php` - Added moderation fields

## Status
✅ **COMPLETE** - Full moderation functionality implemented for all assessment types with Uphold/Withdraw actions that update status without deleting data.
