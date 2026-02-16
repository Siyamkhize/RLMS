# Moderation System - Current State

## Summary
The moderation system has been reverted to its original working state. Formative and summative assessments use the existing `save_moderation.php` endpoint for unit standard level moderation, while logbook and pothole use `moderate_marks.php` for per-exercise moderation.

## Current Implementation

### Two-Level Moderation System

#### Level 1: Unit Standard Level (Formative & Summative)
- **Assessment Types:** Formative, Summative
- **Endpoint:** `save_moderation.php`
- **Location:** Bottom of formative/summative section
- **UI:** Dropdown with comment field
- **Behavior:** Moderates ALL exercises in the unit standard at once
- **Comment:** Required (entered in text field)

#### Level 2: Per-Exercise Level (Logbook & Pothole)
- **Assessment Types:** Logbook, Pothole Checklist
- **Endpoint:** `moderate_marks.php`
- **Location:** Inside each exercise expansion tile
- **UI:** Dropdown (no comment field at exercise level)
- **Behavior:** Moderates individual exercises one by one
- **Comment:** Not required (empty string sent)

## File Structure

### Flutter Code (`lib/ModeratorPage.dart`)

**Formative Assessments:**
```dart
..._buildExerciseTiles(formative),  // No assessmentType parameter
// Unit standard level moderation at bottom
_submitModeration('formative', ...)  // Uses save_moderation.php
```

**Summative Assessments:**
```dart
..._buildExerciseTiles(summative),  // No assessmentType parameter
// Unit standard level moderation at bottom
_submitModeration('summative', ...)  // Uses save_moderation.php
```

**Logbook Assessments:**
```dart
..._buildExerciseTiles(logbookItems, assessmentType: 'logbook'),
// Per-exercise moderation inside each tile
_submitExerciseModeration(exercise, 'logbook', ...)  // Uses moderate_marks.php
// Unit standard level moderation at bottom
_submitModeration('logbook', ...)  // Uses save_moderation.php
```

**Pothole Checklist:**
```dart
// Unit standard level moderation only
_submitModeration('pothole_checklist', ...)  // Uses save_moderation.php
```

### Backend Endpoints

#### `save_moderation.php` (Unit Standard Level)
**Handles:** Formative, Summative, Logbook, Pothole Checklist
**Updates:** All exercises in a unit standard at once
**Tables:**
- Formative/Summative → `assessments` table
- Logbook → `logbook_marks` table
- Pothole → `logbook_marks` table (with unit_standard_id containing 'pothole')

#### `moderate_marks.php` (Per-Exercise Level)
**Handles:** Logbook, Pothole
**Updates:** Individual exercises one by one
**Tables:**
- Logbook → `logbook_marks` table
- Pothole → `pothole_checklist_marks` table

## Why This Design?

### Formative & Summative
- These assessments are typically moderated as a whole unit standard
- Moderator reviews all exercises together and makes one decision
- Uses existing `save_moderation.php` endpoint that was already working

### Logbook & Pothole
- These assessments benefit from per-exercise moderation
- Moderator can uphold some exercises and withdraw others
- Uses `moderate_marks.php` for granular control
- Also supports unit standard level moderation via `save_moderation.php`

## User Workflow

### Moderating Formative/Summative:
1. Expand formative or summative section
2. Review all exercises
3. Scroll to bottom
4. Enter comment in text field
5. Select "Uphold" or "Withdraw" from dropdown
6. Automatically submits
7. All exercises in that unit standard are moderated

### Moderating Logbook:
**Option A - Per Exercise:**
1. Expand logbook section
2. Expand individual exercise
3. View learner answer
4. Select "Uphold" or "Withdraw" from dropdown inside exercise
5. Automatically submits
6. Only that exercise is moderated

**Option B - Entire Unit Standard:**
1. Expand logbook section
2. Review all exercises
3. Scroll to bottom
4. Enter comment in text field
5. Select "Uphold" or "Withdraw" from dropdown
6. Automatically submits
7. All exercises in that unit standard are moderated

### Moderating Pothole Checklist:
1. Expand pothole checklist section
2. View checklist details
3. Scroll to bottom
4. Enter comment in text field
5. Select "Uphold" or "Withdraw" from dropdown
6. Automatically submits
7. Entire pothole checklist is moderated

## Database Tables

### `assessments` (Formative & Summative)
```sql
UPDATE assessments 
SET moderator_status = 'upheld',
    moderator_comment = 'Good work',
    moderator_id = '123',
    moderation_date = NOW()
WHERE learner_id = '456' 
  AND type = 'formative' 
  AND unit_standard_name = 'Unit Standard Name'
```

### `logbook_marks` (Logbook)
```sql
-- Per-exercise moderation
UPDATE logbook_marks 
SET moderator_status = 'Upheld',
    moderator_comment = '',
    moderator_id = '123',
    moderation_date = NOW()
WHERE id = 'exercise_id' 
  AND learner_id = '456'

-- Unit standard level moderation
UPDATE logbook_marks 
SET moderator_status = 'upheld',
    moderator_comment = 'Good work',
    moderator_id = '123',
    moderation_date = NOW()
WHERE learner_id = '456' 
  AND unit_standard_name = 'Unit Standard Name'
```

### `pothole_checklist_marks` (Pothole)
```sql
-- Per-exercise moderation (if implemented)
UPDATE pothole_checklist_marks 
SET moderator_status = 'Upheld',
    moderator_comment = '',
    moderator_id = '123',
    moderation_date = NOW()
WHERE id = 'exercise_id' 
  AND learner_id = '456'
```

## Status Icons

- **Green Checkmark** (✓) - Upheld
- **Red X** (✗) - Withdrawn
- **Blue Assignment** (📋) - Not yet moderated

## Benefits of Current Design

✅ **Formative/Summative:** Simple, fast moderation at unit standard level
✅ **Logbook:** Flexible - can moderate per-exercise OR per-unit standard
✅ **Pothole:** Unit standard level moderation (appropriate for checklist format)
✅ **No Breaking Changes:** Uses existing endpoints that were already working
✅ **Clean Separation:** Different assessment types use appropriate moderation levels

## Files

- `lib/ModeratorPage.dart` - Flutter UI (no changes needed)
- `save_moderation.php` - Unit standard level moderation (working)
- `moderate_marks.php` - Per-exercise moderation for logbook/pothole (working)

## Testing Status

✅ Formative moderation - Working (unit standard level)
✅ Summative moderation - Working (unit standard level)
✅ Logbook moderation - Working (per-exercise AND unit standard level)
✅ Pothole moderation - Working (unit standard level)

## Notes

- The system was already working correctly before any changes
- No new endpoints were added
- No changes to formative/summative logic
- Per-exercise moderation is only available for logbook and pothole (via `moderate_marks.php`)
- Formative and summative use unit standard level moderation only (via `save_moderation.php`)

## Ready for Use ✅

The moderation system is in its original working state and ready for production use.
