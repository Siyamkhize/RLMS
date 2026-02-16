# Pothole Checklist Marking Feature

## Overview
Added pothole checklist viewing and marking functionality to the AssessorPage marking section.

## What Was Added

### New Section in Marking UI
The marking interface now displays sections in this order:
1. **Formative** - Formative unit standards
2. **Summative** - Summative unit standards  
3. **LogBook** - Logbook unit standards
4. **Pothole Checklist** - NEW! View and mark pothole checklists

## Features

### 1. Automatic Detection
- Automatically checks if a pothole checklist exists for the learner
- Detects both scanned documents and system-generated forms
- Shows appropriate icon based on checklist type:
  - 📄 PDF icon for scanned documents
  - ✓ Checklist icon for system-generated forms

### 2. View Functionality

#### For Scanned Documents:
- Opens the PDF document directly
- Uses device's default PDF viewer

#### For System-Generated Forms:
- Displays checklist in a dialog
- Shows all sections with YES/NO responses
- Displays assessor notes for each item
- Color-coded indicators (green for YES, red for NO)

### 3. Marking Functionality
- Marks input field (0-100)
- Comments text area for assessor feedback
- Submit button to save marks
- (Note: Backend save functionality needs to be implemented)

## User Flow

1. **Assessor opens marking page** for a learner
2. **Navigates through unit standards** (Formative → Summative → LogBook)
3. **Expands "Pothole Checklist" section**
4. **System checks** if checklist exists:
   - If NO checklist: Shows "No pothole checklist found"
   - If checklist exists: Shows type and "View" button
5. **Assessor taps to view** the checklist
6. **Assessor enters marks and comments**
7. **Submits marks** (saves to database)

## Technical Implementation

### Methods Added

#### `_buildPotholeChecklistSection()`
- Main widget for the pothole checklist section
- Uses FutureBuilder to check checklist status
- Displays appropriate UI based on checklist availability

#### `_checkPotholeChecklistStatus()`
- Checks local database for scanned documents
- Checks server for system-generated checklists
- Returns checklist type and data

#### `_viewPotholeChecklist()`
- Opens scanned PDFs using OpenFile
- Shows system checklists in a dialog

#### `_buildChecklistView()`
- Renders system-generated checklist data
- Displays sections, items, responses, and notes

#### `_buildPotholeChecklistMarkingSection()`
- Provides marking interface
- Marks input field
- Comments text area
- Submit button

## Database Requirements

### Existing Tables Used:
1. **pothole_checklist_scanned_documents** - For scanned PDFs
2. **pothole_checklists** - For system-generated forms

### New Table Needed (for marks):
```sql
CREATE TABLE IF NOT EXISTS pothole_checklist_marks (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    assessor_id VARCHAR(50) NOT NULL,
    assessment_date DATE NOT NULL,
    marks INT(3) NOT NULL,
    comments TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_mark (learner_id, assessor_id, assessment_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## API Endpoints Needed

### Save Marks Endpoint
**File:** `php/save_pothole_checklist_marks.php`

**Request:**
```json
{
  "learner_id": "L123",
  "assessor_id": "A456",
  "assessment_date": "2025-11-05",
  "marks": 85,
  "comments": "Good work on all sections"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Marks saved successfully"
}
```

### Get Marks Endpoint
**File:** `php/get_pothole_checklist_marks.php`

**Query Parameters:**
- `learner_id`
- `assessor_id`
- `assessment_date`

**Response:**
```json
{
  "status": "success",
  "data": {
    "marks": 85,
    "comments": "Good work on all sections",
    "created_at": "2025-11-05 10:30:00"
  }
}
```

## Next Steps

### 1. Create Database Table
Run the SQL above to create the `pothole_checklist_marks` table.

### 2. Create PHP Endpoints
- Create `save_pothole_checklist_marks.php`
- Create `get_pothole_checklist_marks.php`

### 3. Implement Save Functionality
Update `_buildPotholeChecklistMarkingSection()` to:
- Load existing marks if available
- Save marks to database via API
- Show success/error messages

### 4. Add Marks Display
Show existing marks when viewing the checklist:
- Display marks badge
- Show previous comments
- Allow re-marking if needed

## Testing Checklist

- [ ] Pothole Checklist section appears in marking UI
- [ ] Section shows "No checklist found" when none exists
- [ ] Scanned documents can be viewed
- [ ] System-generated forms display correctly
- [ ] All checklist items show with correct YES/NO status
- [ ] Notes display for each item
- [ ] Marks input accepts numbers
- [ ] Comments field accepts text
- [ ] Submit button triggers (currently shows placeholder message)

## UI Screenshots Description

### Collapsed State
```
▶ Pothole Checklist 🔧
```

### Expanded State (No Checklist)
```
▼ Pothole Checklist 🔧
  No pothole checklist found for this learner.
```

### Expanded State (With Checklist)
```
▼ Pothole Checklist 🔧
  📄 Scanned Document
  Tap to view and mark →
  
  Marking
  ┌─────────────────┐
  │ Marks: [    ]   │
  ├─────────────────┤
  │ Comments:       │
  │ [            ]  │
  │ [            ]  │
  └─────────────────┘
  [Submit Marks]
```

## Benefits

1. **Centralized Marking** - All assessments in one place
2. **Flexible Input** - Supports both scanned and digital forms
3. **Easy Review** - Quick view of checklist before marking
4. **Consistent UI** - Matches existing formative/summative/logbook pattern
5. **Offline Support** - Works with locally stored scanned documents

## Future Enhancements

1. **Detailed Marking** - Mark individual checklist items
2. **Rubric Integration** - Predefined marking criteria
3. **Photo Evidence** - View photos attached to checklist
4. **Comparison View** - Compare multiple attempts
5. **Export Marks** - Generate marking reports
