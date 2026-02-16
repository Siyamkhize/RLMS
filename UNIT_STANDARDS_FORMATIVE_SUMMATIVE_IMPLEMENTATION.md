# Unit Standards with Formative and Summative Materials Implementation

## Overview
Enhanced the facilitator material issuance system to support three material types for each unit standard:
1. **Learner Guide** (existing)
2. **Formative** (new)
3. **Summative** (new)

## Key Features

### 1. Enhanced UI Design
- **Unit Standards Section**: New dedicated section showing all available unit standards
- **Material Type Cards**: Each unit standard displays three sub-cards for Learner Guide, Formative, and Summative
- **Individual Quantities**: Each material type has its own quantity input field
- **Status Tracking**: Visual indicators show which materials have been previously submitted
- **Individual Submit Buttons**: Each material type can be submitted independently

### 2. Data Structure
```dart
// Material types configuration
final List<Map<String, String>> materialTypes = [
  {'id': 'learner_guide', 'name': 'Learner Guide'},
  {'id': 'formative', 'name': 'Formative'},
  {'id': 'summative', 'name': 'Summative'},
];

// Tracking structures
Map<String, Map<String, int>> unitStandardQuantities = {};
Map<String, Map<String, bool>> unitStandardSubmissions = {};
```

### 3. Backend Integration
- **Database Format**: Uses existing `material_forms` table
- **Sub-description Format**: "Unit Standard {ID}: {MaterialType}"
  - Example: "Unit Standard 13958: Formative"
- **API Key Format**: "{unitId}_{materialType}"
  - Example: "13958_formative"

### 4. Visual Design Elements

#### Unit Standard Cards
- **Purple theme** for unit standard containers
- **Header section** with unit ID badge and name
- **Material type rows** with status indicators

#### Material Type Rows
- **Status icons**: Green checkmark for submitted, gray circle for pending
- **Quantity input**: Individual quantity control for each type
- **Submit buttons**: Color-coded (orange for new, green for updates)
- **Status text**: Shows previously issued quantities

#### Summary Section
- **Previous Submissions Summary**: Shows total submitted units count
- **Real-time updates**: Reflects changes immediately after submission

## Implementation Files

### Frontend (Flutter)
- `lib/facilitator_material_issuance_page.dart`: Enhanced with unit standards section

### Backend (PHP)
- `get_facilitator_checkbox_status.php`: Updated to handle new material type keys
- `save_facilitator_material_issue_fixed.php`: Existing endpoint handles new format

### Testing
- `test_unit_standards_formative_summative.php`: Comprehensive test file

## Usage Flow

1. **Navigate** to facilitator material issuance page
2. **View** unit standards section with all available standards
3. **Select quantities** for desired material types (Learner Guide, Formative, Summative)
4. **Submit individually** each material type as needed
5. **Track status** with visual indicators showing submitted vs pending items
6. **Update quantities** for previously submitted materials

## Database Schema
Uses existing `material_forms` table with:
- `description`: "Learning Material"
- `sub_description`: "Unit Standard {ID}: {MaterialType}"
- `quantity`: Individual quantity for each material type

## API Response Format
```json
{
  "checkboxStatus": {
    "13958_learner_guide": true,
    "13958_formative": true,
    "13958_summative": false
  },
  "quantities": {
    "13958_learner_guide": 5,
    "13958_formative": 3,
    "13958_summative": 0
  }
}
```

## Benefits
- **Granular Control**: Individual tracking and submission of each material type
- **Clear Organization**: Visual separation of different material types
- **Status Visibility**: Immediate feedback on submission status
- **Flexible Quantities**: Different quantities for different material types
- **Backward Compatible**: Works with existing database structure

## Testing
Run `test_unit_standards_formative_summative.php` to:
- Insert test data for all material types
- Verify API response format
- Check database integration
- Validate UI data flow

The implementation provides a comprehensive solution for managing unit standard materials with the three required types (Learner Guide, Formative, Summative) while maintaining a clean, intuitive user interface.