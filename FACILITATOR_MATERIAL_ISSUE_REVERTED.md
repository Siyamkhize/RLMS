# Facilitator Material Issue Page - Reverted to Original

## Changes Made
The facilitator material issue page has been reverted back to its original learner-focused implementation as requested by the user.

## Restored Features

### 1. Data Structure
- **Restored**: `List<dynamic> learners` - loads all learners in the class
- **Restored**: Nested controllers `Map<String, Map<String, TextEditingController>>` - per learner per material

### 2. UI Layout
- **Restored**: Individual learner cards showing each learner's details
- **Restored**: Material quantity inputs for each learner individually
- **Restored**: Learner information display (ID, name, qualification)

### 3. App Bar and Titles
- **Restored**: "Issue Materials to Learners" (not "to Facilitator")
- **Restored**: Classes page title "Select Class - Issue Materials to Learners"
- **Restored**: Description "Select a class to issue materials to learners"

### 4. Save Logic
- **Restored**: Creates separate material issuance records for each learner
- **Restored**: `representativeFullName` = learner's name (not facilitator's name)
- **Restored**: Individual submissions per learner per material

### 5. Backend Integration
Still uses the same three backend endpoints:
- `getFacilitatorDetailsForMaterials.php` - Gets learners in the class
- `get_facilitator_checkbox_status.php` - Gets material status
- `save_facilitator_material_issue.php` - Saves material issuances

## Current Workflow
1. Select site → Select class → Material issue page
2. Page loads all learners in the selected class
3. For each learner, show available materials with quantity inputs
4. Save creates individual material issuance records per learner
5. Materials are issued TO each individual learner (not to the facilitator)

## Page Structure
```
Header (Class name, site name, instructions)
├── Learner Card 1
│   ├── Learner details (name, ID, qualification)
│   └── Materials list with quantity inputs
├── Learner Card 2
│   ├── Learner details
│   └── Materials list with quantity inputs
└── ... (for each learner in class)
```

The page is now back to its original implementation where materials are issued to individual learners, with each learner having their own card and material quantity inputs.