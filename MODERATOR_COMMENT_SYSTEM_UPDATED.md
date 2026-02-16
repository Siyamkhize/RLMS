# Moderator Comment System Updated

## Summary
Modified the ModeratorPage to match the assessor's commenting pattern. The moderator now comments once per assessment type (Formative/Summative/Logbook) instead of per exercise, and can see the assessor's comments before making moderation decisions.

## Changes Made

### 1. Assessor Comments Display
Added assessor comments display in all three assessment types:
- **Formative**: Shows assessor comments in a blue-bordered box after all exercises
- **Summative**: Shows assessor comments in a blue-bordered box after all exercises  
- **Logbook**: Shows assessor comments in a blue-bordered box after all exercises

The assessor comments are displayed with:
- Blue background (Colors.blue.shade50)
- Blue border
- Comment icon
- "Assessor Comments:" label
- The actual comment text

### 2. Moderator Comment Section
The moderator comment section is placed at the assessment type level (not per exercise):
- Located after all exercises in each assessment type
- Includes a text field for entering/editing comments
- Shows "Editing existing comment" helper text when a comment already exists
- Followed by Uphold/Withdraw action buttons

### 3. Comment Flow
**For each assessment type (Formative/Summative/Logbook):**
1. Display all exercises with marks and learner answers
2. Display assessor comments (if available)
3. Display moderator comment input field
4. Display Uphold/Withdraw buttons

### 4. Code Structure
```dart
// Formative/Summative/Logbook structure:
ExpansionTile(
  title: Text('Assessment Type'),
  children: [
    // 1. All exercise tiles
    ..._buildExerciseTiles(items),
    
    // 2. Assessor comments (if available)
    if (existingAssessorComment.isNotEmpty)
      Container with assessor comment display,
    
    // 3. Divider
    Divider(),
    
    // 4. Moderator comment section
    Column(
      - "Moderator Comment" label
      - TextFormField for comment input
      - Uphold/Withdraw buttons
    ),
  ],
)
```

## Files Modified
- `lib/ModeratorPage.dart`

## Key Features
1. **Single Comment per Assessment Type**: Moderator comments once for all exercises in Formative, once for Summative, and once for Logbook
2. **Assessor Comments Visible**: Moderator can see what the assessor commented before making decisions
3. **Consistent Pattern**: Matches the assessor's commenting workflow
4. **Clear UI**: Assessor comments in blue boxes, moderator comments in separate section
5. **Edit Support**: Can edit existing moderator comments

## Testing Checklist
- [ ] Verify assessor comments display correctly in Formative section
- [ ] Verify assessor comments display correctly in Summative section
- [ ] Verify assessor comments display correctly in Logbook section
- [ ] Test moderator comment submission for Formative
- [ ] Test moderator comment submission for Summative
- [ ] Test moderator comment submission for Logbook
- [ ] Test editing existing moderator comments
- [ ] Verify Uphold/Withdraw actions work with comments
- [ ] Test when no assessor comments exist (should not show blue box)
- [ ] Verify comment persistence after page refresh

## Backend Requirements
The backend (`save_moderation.php`) should:
- Accept `moderatorComment` parameter
- Save comment at assessment type level (not per exercise)
- Link comment to all exercises in that assessment type
- Return success/error status

## User Experience
1. Moderator opens a learner's assessment
2. Expands Formative/Summative/Logbook section
3. Reviews all exercises and marks
4. Reads assessor's comments (if available)
5. Enters their own moderation comment
6. Clicks Uphold or Withdraw
7. Comment is saved for the entire assessment type

## Benefits
- **Efficiency**: Comment once instead of per exercise
- **Context**: See assessor's reasoning before moderating
- **Consistency**: Same pattern as assessor workflow
- **Clarity**: Clear separation between assessor and moderator comments
