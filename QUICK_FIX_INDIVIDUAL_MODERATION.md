# Quick Fix: Individual Exercise Moderation

## Problem
Moderating formative also moderates summative for the same unit standard.

## Solution
Added `LIMIT 1` to UPDATE query in `save_moderation_status.php`

## Code Change

**File:** `save_moderation_status.php`  
**Line:** 58

**Before:**
```php
$sqlUpdate = "UPDATE marks SET approval_status = ?, moderator_status = ?, moderator_comment = ?, moderator_id = ?, moderation_date = NOW() WHERE learnerID = ? AND exercise = ?";
```

**After:**
```php
$sqlUpdate = "UPDATE marks SET approval_status = ?, moderator_status = ?, moderator_comment = ?, moderator_id = ?, moderation_date = NOW() WHERE learnerID = ? AND exercise = ? LIMIT 1";
```

## Why This Works

1. **Exact Match:** WHERE clause matches on `learnerID` AND `exercise` (exact exercise name)
2. **LIMIT 1:** Ensures only ONE record is updated per API call
3. **Separate Calls:** Each exercise moderation triggers a separate API call

## Example

### Formative Moderation
```json
{
  "learnerId": "123",
  "exerciseId": "13958 - Formative - Question 1",
  "moderation_status": "uphold"
}
```
→ Updates ONLY "13958 - Formative - Question 1"

### Summative Moderation
```json
{
  "learnerId": "123",
  "exerciseId": "13958 - Summative - Question 1",
  "moderation_status": "uphold"
}
```
→ Updates ONLY "13958 - Summative - Question 1"

## Testing

1. Moderate a formative question
2. Check summative is NOT moderated
3. Moderate a summative question
4. Check formative remains unchanged

## Files Modified
- `save_moderation_status.php`

## Documentation
- `MODERATION_INDIVIDUAL_EXERCISE_FIX.md` (detailed)
- `ALL_FIVE_TASKS_STATUS.md` (complete status)
