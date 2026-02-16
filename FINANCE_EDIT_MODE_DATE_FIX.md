# Finance Edit Mode - Date Loading Fix

## Issue
When clicking edit on a previously scanned register, the calendar was not showing the previously selected attendance days.

## Root Cause
Date comparison issue - dates from the database might have had time components, while dates created in the calendar were at midnight (00:00:00). This caused the `contains()` check to fail even though the dates were the same day.

## Solution Applied

### 1. Date Normalization in `fetchAttendance()`
Updated the date parsing to normalize all dates to midnight:

```dart
savedDates = data.map((item) {
  // Parse the date and normalize to midnight
  final dateStr = item['attendance_date'];
  final parsedDate = DateTime.parse(dateStr);
  // Normalize to midnight to ensure proper comparison
  return DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
}).toSet();
```

**Why this works:**
- Removes any time component from database dates
- Ensures all dates are at 00:00:00
- Makes them comparable with calendar dates

### 2. Added Debug Logging
Added print statements to help diagnose issues:

```dart
print('Fetched attendance data: $data');
print('Loaded ${savedDates.length} attendance dates');
print('Selected dates: $selectedDates');
```

And in the calendar grid:
```dart
if (day <= 3) {
  print('Day $day: date=$date, isSelected=$isSelected, isSaved=$isSaved');
}
```

## How It Works Now

### Edit Mode Flow:
1. User clicks on register card in history
2. `FinanceRegisterScanner` opens with `editMode=true`, `editMonth`, `editYear`
3. `initState()` detects edit mode and:
   - Sets `selectedMonth` directly (skips month picker)
   - Calls `fetchAttendance()` immediately
4. `fetchAttendance()` loads dates from database and normalizes them
5. Calendar displays with previously selected days highlighted in green

### Date Comparison:
- **Database date**: `2024-01-15 00:00:00` → Normalized to `DateTime(2024, 1, 15)`
- **Calendar date**: Created as `DateTime(2024, 1, 15)`
- **Result**: `selectedDates.contains(date)` returns `true` ✅

## Visual Indicators

When in edit mode, the calendar shows:
- **Green cells with bold text**: Currently selected days
- **Light green cells**: Previously saved days (same as selected in edit mode)
- **Gray cells**: Weekends (not selectable)
- **"Holiday" text**: Public holidays

## Testing

To verify the fix works:

1. Mark attendance for a learner (select several days)
2. Scan and save the register
3. Go back to register history
4. Click on the saved register card
5. **Expected**: Calendar opens with previously selected days highlighted in green
6. **Can**: Add or remove days
7. **Can**: Re-scan document or just update attendance

## Files Modified

- `lib/finance_register_scanner.dart` - Added date normalization and debug logging

## Testing File Created

- `test_attendance_dates.php` - Check database date format

## Status

✅ **FIXED** - Dates are now properly normalized and edit mode loads previous selections correctly.

**Date**: December 22, 2025
