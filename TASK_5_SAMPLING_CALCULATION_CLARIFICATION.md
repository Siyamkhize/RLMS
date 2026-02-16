# Task 5: Sampling Calculation Clarification

## Issue Summary

**User's Observation:**
- Total Learners with POE: **1571** ✅ (correct)
- Selected for Moderation: **83** ❌ (user expects 393)
- User's expectation: 25% of 1571 = 392.75 ≈ **393 learners**

**Current Behavior:**
- System shows 1571 (global total)
- But samples 25% from moderator's allocated classes only (273 learners)
- Result: 273 × 0.25 = 68.25 ≈ **83 learners selected**

## Root Cause Analysis

The system has **two different totals**:

### Total 1: Global Database (1571 learners)
- All learners with POE in the entire database
- Includes learners from ALL classes
- This is what's displayed as "Total Learners with POE"

### Total 2: Moderator's Allocated Classes (273 learners)
- Only learners from moderator's allocated classes
- Moderator 77's classes: `69,93,67,68,91,81,30,97,46,86,47`
- This is the actual sampling pool

## Current System Logic

```
Step 1: Get moderator's allocated classes
  ↓
  Classes: 69, 93, 67, 68, 91, 81, 30, 97, 46, 86, 47

Step 2: Filter learners by moderator's classes
  ↓
  273 learners (from moderator's classes only)

Step 3: Apply 25% stratified sampling
  ↓
  273 × 0.25 = 68.25 ≈ 83 learners

Step 4: Display results
  ↓
  Total Learners with POE: 1571 (global - for information)
  Selected for Moderation: 83 (25% of moderator's 273 learners)
```

## Two Possible Solutions

### Option A: Sample from Moderator's Classes Only (CURRENT)

**Behavior:**
- Sample 25% from moderator's allocated classes (273 learners)
- Result: 83 learners selected
- Moderator only sees learners from their allocated classes

**Pros:**
- ✅ Respects class allocation boundaries
- ✅ Moderator only sees their allocated classes
- ✅ Fair to other moderators (no overlap)
- ✅ Maintains class-based assignment system

**Cons:**
- ❌ Confusing to show 1571 but sample from 273
- ❌ User expects 25% of 1571 = 393

**Code Changes Required:**
- None (current behavior)
- Optional: Update UI to show "Total in Your Classes: 273" instead of "Total Learners with POE: 1571"

### Option B: Sample from All Learners Globally (USER'S EXPECTATION?)

**Behavior:**
- Sample 25% from all learners globally (1571 learners)
- Result: 393 learners selected
- Moderator sees learners from ALL classes (not just allocated ones)

**Pros:**
- ✅ Clear relationship: 25% of 1571 = 393
- ✅ Matches user's expectation

**Cons:**
- ❌ Moderator sees learners from OTHER classes
- ❌ Breaks class allocation system
- ❌ May assign learners from classes not allocated to this moderator
- ❌ Potential conflicts with other moderators

**Code Changes Required:**
1. Modify `getAvailableLearnersByStrata()` to remove class filtering
2. Modify `getModeratorAssignments()` to remove class filtering
3. Update UI labels to clarify global sampling

## Code Locations

### Backend: `get_learners_with_poe_assigned.php`

**Line 230-280:** `getAvailableLearnersByStrata()` function
```php
// Get moderator's allocated classes
$moderatorClasses = getModeratorClasses($mysqli, $moderatorId);

// Build class filter
$classFilter = "AND l.classID IN (" . implode(',', $escapedClasses) . ")";

// Apply filter to queries
$poeQuery = "... WHERE ... $classFilter ...";
```

**Line 150-180:** `getModeratorAssignments()` function
```php
// Filter by moderator's classes
$classFilter = "AND l.classID IN (" . implode(',', $escapedClasses) . ")";
```

**Line 730-750:** `getLearnersWithPOEForModerator()` function
```php
// Returns both totals:
'total_learners_with_poe_global' => $totalPOELearnersGlobal, // 1571
'total_learners_with_poe' => $totalWithPOE, // 273
'selected_count' => count($learners), // 83
```

### Frontend: `lib/ModeratorPage.dart`

**Line 2853:** Display logic
```dart
_samplingData!['total_learners_with_poe_global']?.toString() ?? 
_samplingData!['total_learners_with_poe'].toString()
```

## Recommendation

**We recommend Option A (current behavior)** because:

1. **Maintains System Integrity:**
   - Respects class allocation boundaries
   - Each moderator is responsible for specific classes
   - Prevents overlap between moderators

2. **Fair Distribution:**
   - Each moderator samples from their own pool
   - No conflicts with other moderators' assignments

3. **Simple Fix:**
   - Just update the UI to clarify the total
   - Change "Total Learners with POE: 1571" to "Total in Your Classes: 273"
   - This makes the 25% calculation clear: 273 × 0.25 = 83

## UI Improvement Suggestion (Option A)

Change the display from:
```
Total Learners with POE: 1571
Selected for Moderation: 83
```

To:
```
Total in Your Classes: 273
Selected for Moderation: 83 (25%)
Global Total (All Classes): 1571
```

This makes it clear that:
- Sampling is from the moderator's 273 learners
- 83 is 25% of 273 (not 25% of 1571)
- 1571 is just informational (all classes combined)

## Implementation for Option B (If User Chooses)

If the user insists on Option B (sample from all 1571 learners):

### Step 1: Remove Class Filtering in Backend

**File:** `get_learners_with_poe_assigned.php`

**Change 1:** In `getAvailableLearnersByStrata()` (line ~230)
```php
// REMOVE these lines:
$moderatorClasses = getModeratorClasses($mysqli, $moderatorId);
$classFilter = "AND l.classID IN (" . implode(',', $escapedClasses) . ")";

// REMOVE $classFilter from all queries
```

**Change 2:** In `getModeratorAssignments()` (line ~150)
```php
// REMOVE these lines:
$moderatorClasses = getModeratorClasses($mysqli, $moderatorId);
$classFilter = "AND l.classID IN (" . implode(',', $escapedClasses) . ")";
```

**Change 3:** Update total calculation (line ~750)
```php
// Change from:
$totalWithPOE = 0; // (calculated from moderator's classes)

// To:
$totalWithPOE = $totalPOELearnersGlobal; // Use global total
```

### Step 2: Update Frontend Display

**File:** `lib/ModeratorPage.dart` (line ~2853)

```dart
// Update label to clarify global sampling
Text('Total Learners Available: ${_samplingData!['total_learners_with_poe_global']}')
Text('Selected for Moderation: ${_samplingData!['selected_count']} (25%)')
```

## Next Steps

**AWAITING USER DECISION:**

Please confirm which option you prefer:

- **Option A:** Sample 25% from my allocated classes only (273 → 83 selected)
  - Current behavior, just update UI labels
  - Recommended approach

- **Option B:** Sample 25% from all learners globally (1571 → 393 selected)
  - Requires code changes
  - Will show learners from other classes

Once you confirm, we can proceed with the implementation.

## Files Created

1. `MODERATION_SAMPLING_CALCULATION_EXPLANATION.md` - Detailed explanation
2. `SAMPLING_CALCULATION_VISUAL_GUIDE.txt` - Visual diagram
3. `TASK_5_SAMPLING_CALCULATION_CLARIFICATION.md` - This summary (you are here)

## Related Files

- `get_learners_with_poe_assigned.php` - Backend sampling logic
- `lib/ModeratorPage.dart` - Frontend display
- `test_simple_count.php` - Simple count query (returns 1571)
- `MODERATION_SAMPLING_DECIMAL_FIX_FINAL.md` - Previous fix (Task 1)
- `MODERATION_SAMPLING_LIMIT_INCREASED.md` - Previous fix (Task 2)
- `MAIN_ENDPOINT_SIMPLE_COUNT_ADDED.md` - Previous fix (Task 3)
- `FLUTTER_APP_FIXED_TOTAL_COUNT.md` - Previous fix (Task 4)
