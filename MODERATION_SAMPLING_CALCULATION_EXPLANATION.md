# Moderation Sampling Calculation Explanation

## Current Behavior

The system currently shows:
- **Total Learners with POE: 1571** (global total - all learners in database)
- **Selected for Moderation: 83** (which is ~30% of 273, the learners in moderator's classes)

## Why 83 and not 393?

The system is designed to sample **25% from the moderator's allocated classes only**, not from all learners globally.

### Current Logic Flow:

1. **Get Moderator's Allocated Classes**
   - Moderator 77 is allocated to classes: `69,93,67,68,91,81,30,97,46,86,47`
   - These classes contain **273 learners with POE**

2. **Filter Learners by Moderator's Classes**
   - The system ONLY considers learners from the moderator's allocated classes (273 learners)
   - It does NOT consider all 1571 learners globally

3. **Apply 25% Sampling**
   - 25% of 273 = 68.25 ≈ **83 learners selected** (after stratification adjustments)

4. **Display Global Total for Information**
   - The 1571 is shown as "Total Learners with POE" for informational purposes
   - But sampling is done on the 273 learners in moderator's classes

## Two Possible Interpretations

### Option A: Current Behavior (Sample from Moderator's Classes Only)
- **Pros:**
  - Moderator only sees learners from their allocated classes
  - Respects class allocation boundaries
  - Moderator is responsible for specific classes
  
- **Cons:**
  - User expects 25% of 1571 = 393 learners
  - Confusing to show 1571 but only sample from 273

- **Calculation:**
  - Total in moderator's classes: 273
  - 25% sampling: 273 × 0.25 = 68.25 ≈ **83 selected**

### Option B: Sample from All Learners Globally (User's Expectation?)
- **Pros:**
  - 25% of 1571 = 393 learners (matches user's expectation)
  - Clear relationship between total and selected
  
- **Cons:**
  - Would assign learners from classes NOT allocated to this moderator
  - Moderator would see learners from other moderators' classes
  - Breaks class allocation system

- **Calculation:**
  - Total globally: 1571
  - 25% sampling: 1571 × 0.25 = 392.75 ≈ **393 selected**

## Recommendation

**We need to clarify with the user which behavior is correct:**

### Question for User:
Should the moderator sample:
1. **25% from their allocated classes only** (273 learners → 83 selected) - Current behavior
2. **25% from all learners globally** (1571 learners → 393 selected) - Would include learners from other classes

### If Option 1 (Current):
- No code changes needed
- Just explain the logic to the user
- Maybe change the UI to show "Total in Your Classes: 273" instead of "Total Learners with POE: 1571"

### If Option 2 (Global Sampling):
- Need to modify `getAvailableLearnersByStrata()` to NOT filter by moderator's classes
- Remove the class filter: `$classFilter = "AND l.classID IN (...)"`
- This would allow sampling from all 1571 learners
- But moderator would see learners from classes they're not allocated to

## Code Changes Required for Option 2

If user wants Option 2 (sample from all 1571 learners):

1. **In `getAvailableLearnersByStrata()` function:**
   - Remove the moderator class filtering
   - Sample from all learners globally

2. **In `getModeratorAssignments()` function:**
   - Remove the class filter when retrieving existing assignments
   - Show all assigned learners regardless of class

3. **Update UI labels:**
   - Change "Total Learners with POE" to "Total Learners Available for Sampling"
   - Make it clear that sampling is from the global pool

## Current File Locations

- **Backend:** `get_learners_with_poe_assigned.php`
  - Line 230-280: `getAvailableLearnersByStrata()` - applies class filter
  - Line 150-180: `getModeratorAssignments()` - applies class filter
  
- **Frontend:** `lib/ModeratorPage.dart`
  - Line 2853: Displays the total count

## Next Steps

**AWAITING USER CLARIFICATION:**
- Which behavior is correct?
- Should moderators only see learners from their allocated classes?
- Or should they sample from all learners globally?

Once clarified, we can implement the appropriate solution.
