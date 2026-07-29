# Sick Note - Revert to Old Calendar Format

## User Request
User wants to revert back to the old sick note UI format with:
1. **Calendar date picker** with Date From and Date To fields
2. **Validation happens inside calendar picker**
3. All the eligibility/validation logic from backend still applies

## Current Implementation (NEW - Needs to be Reverted)
- Single date selector with visual cards
- Practice name + Practitioner name + Practitioner type
- Document scanner button
- Validates last 5 working days
- Grays out dates where learner clocked in

## Old Implementation (RESTORE THIS)
Location: Need backup file or previous version

**UI Structure:**
- Learner Information card
- Sick Note Details section:
  - Practice Name field
  - Medical Practitioner field
  - Practitioner Type dropdown (Doctor)
  - **Date From (YYYY-MM-DD)** with calendar picker 📅
  - **Date To (YYYY-MM-DD)** with calendar picker 📅
  - Camera button to scan sick note
- Validation happens when date picker opens

## Backend (Keep As-Is)
- `mobile/get_sick_note_eligible_dates.php` - Fixed column names ✅
- `mobile/submit_sick_note.php` - Fixed column names ✅
- Both work correctly with proper validation

## Action Required
1. **Find old sick_note_page.dart** from backup or git history
2. **Replace** current `lib/sick_note_page.dart` with old version
3. **Keep** the backend PHP files (they're already fixed)
4. **Rebuild** APK

## Notes
- The new implementation works perfectly but user prefers the old calendar UI
- Backend validation is solid and should not be changed
- Just need to restore old Flutter UI with calendar date pickers
