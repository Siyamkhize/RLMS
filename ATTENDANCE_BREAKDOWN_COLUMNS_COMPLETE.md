# Attendance Breakdown Columns - Complete ✅

## Overview
Updated the attendance page to show **separate columns** for each attendance type, making it clear how the total days attended is calculated.

## New Column Layout

### Before (3 columns):
| Surname | Name | Days Attended | Daily Rate | Total Due |
|---------|------|---------------|------------|-----------|
| Doe     | John | 20/22         | R91        | R1,820    |

### After (8 columns):
| Surname | Name | Regular Days | Manual Days | Sick Days | Total Days | Daily Rate | Total Due |
|---------|------|--------------|-------------|-----------|------------|------------|-----------|
| Doe     | John | 15           | 3           | 2         | 20/22      | R91        | R1,820    |

## Column Details

### 1. **Surname** (Flex: 3)
- Learner's surname
- Bold text
- Shows 📱 icon if using local data

### 2. **Name** (Flex: 3)
- Learner's first name
- Regular text

### 3. **Regular Days** (Flex: 2)
- Days clocked via fingerprint/normal clocking
- **Blue color** (Blue.shade700)
- Source: `learner_clocking` table

### 4. **Manual Days** (Flex: 2)
- Approved manual attendance days
- **Purple color** (Purple.shade700)
- Source: `manual_clocking` table (status='Approved')
- Only counts approved records

### 5. **Sick Days** (Flex: 2)
- Approved sick note days
- **Orange color** (Orange.shade700)
- Source: `sick_note` table (status='APPROVED')

### 6. **Total Days** (Flex: 2)
- Format: `X/Y` (attended/expected)
- **Color coded by percentage:**
  - Green: >80% attendance
  - Orange: 50-80% attendance
  - Red: <50% attendance
- Bold text
- Calculation: Regular + Manual + Sick

### 7. **Daily Rate** (Flex: 2)
- Rate per day (R2000 ÷ working days)
- Small font (10px)
- Format: R91

### 8. **Total Due** (Flex: 2)
- Total stipend amount
- **Green color** (Green.shade700)
- Bold text
- Calculation: Total Days × Daily Rate

## Visual Design

### Color Coding
```dart
Regular Days:  Blue (#1565C0)    - Normal clocking
Manual Days:   Purple (#6A1B9A)  - Approved manual attendance
Sick Days:     Orange (#EF6C00)  - Approved sick notes
Total Days:    Green/Orange/Red  - Based on attendance %
Total Due:     Green (#2E7D32)   - Stipend amount
```

### Font Sizes
- Headers: 11px, bold
- Names: 12px
- Numbers: 10-11px
- Total Due: 11px, bold

### Row Styling
- Alternating background: White / Light Grey
- Bottom border: Grey.shade300
- Padding: 12px vertical, 8px horizontal

## Benefits

### 1. **Transparency**
Users can see exactly how attendance is calculated:
- Regular clocking: 15 days
- Manual attendance: 3 days
- Sick notes: 2 days
- **Total: 20 days**

### 2. **Easy Verification**
- Quickly spot if manual attendance was counted
- Verify sick notes are included
- Check regular clocking matches expectations

### 3. **Clear Breakdown**
No need for tooltips - everything is visible at a glance

### 4. **Color Coding**
- Blue = Regular (most common)
- Purple = Manual (special approval)
- Orange = Sick (medical)
- Green = Good attendance
- Red = Poor attendance

## Example Display

```
┌──────────┬──────┬─────────┬────────┬──────┬───────┬──────┬────────┐
│ Surname  │ Name │ Regular │ Manual │ Sick │ Total │ Rate │  Due   │
├──────────┼──────┼─────────┼────────┼──────┼───────┼──────┼────────┤
│ Doe      │ John │   15    │   3    │  2   │ 20/22 │ R91  │ R1,820 │
│ Smith    │ Jane │   18    │   0    │  1   │ 19/22 │ R91  │ R1,729 │
│ Brown 📱 │ Mike │   12    │   2    │  0   │ 14/22 │ R91  │ R1,274 │
└──────────┴──────┴─────────┴────────┴──────┴───────┴──────┴────────┘
```

## Offline Mode

When using local data (📱 icon shown):
- Regular Days: From local `learner_clocking` table
- Manual Days: From local `manual_clocking` table (approved only)
- Sick Days: Shows 0 (not available locally)
- Total: Regular + Manual

## Data Sources

### Online Mode (Server)
```php
// mobile/get_attendance.php returns:
{
  "days_clocked": 15,        // Regular clocking
  "manual_days_clocked": 3,  // Approved manual
  "sick_note_days": 2,       // Approved sick notes
  "total_days_attended": 20  // Sum of all
}
```

### Offline Mode (Local Database)
```dart
// lib/database_helper.dart queries:
- learner_clocking: Regular days
- manual_clocking: Approved manual days (status='Approved')
- sick_note: Not queried locally (shows 0)
```

## Calculation Logic

### Total Days Attended
```dart
totalDaysAttended = daysClocked + manualDaysClocked + sickNoteDays
```

### Total Due
```dart
dailyRate = 2000.00 / expectedWorkingDays
totalDue = totalDaysAttended × dailyRate
```

### Attendance Percentage
```dart
attendancePercent = (totalDaysAttended / expectedWorkingDays) × 100
```

### Color Determination
```dart
if (attendancePercent > 80) → Green
else if (attendancePercent > 50) → Orange
else → Red
```

## Header Layout

```
┌─────────────────────────────────────────────────────────────┐
│  April 2026                              Class: 123         │
│  Expected Days: 22        Daily Rate: R 90.91               │
│  Holidays in month: 1 day(s)                                │
├─────────────────────────────────────────────────────────────┤
│                    Learners: 45                             │
├──────┬──────┬────────┬────────┬──────┬───────┬──────┬──────┤
│Surname│Name │Regular │Manual  │Sick  │Total  │Daily │Total │
│      │     │Days    │Days    │Days  │Days   │Rate  │Due   │
└──────┴──────┴────────┴────────┴──────┴───────┴──────┴──────┘
```

## Mobile Responsiveness

The layout uses **flex values** to ensure proper spacing on mobile:
- Surname: 3 (wider for longer names)
- Name: 3 (wider for longer names)
- Regular Days: 2
- Manual Days: 2
- Sick Days: 2
- Total Days: 2
- Daily Rate: 2
- Total Due: 2

**Total Flex: 18 units** distributed across 8 columns

## Testing Checklist

### Display
- [ ] All 8 columns visible
- [ ] Headers aligned with data
- [ ] Color coding correct
- [ ] Font sizes readable

### Data Accuracy
- [ ] Regular days match clocking records
- [ ] Manual days only show approved
- [ ] Sick days only show approved
- [ ] Total = Regular + Manual + Sick

### Offline Mode
- [ ] 📱 icon appears
- [ ] Manual days loaded from local DB
- [ ] Sick days show 0 (not available)
- [ ] Total calculated correctly

### Edge Cases
- [ ] Zero manual attendance
- [ ] Zero sick days
- [ ] All zeros (no attendance)
- [ ] 100% attendance

## Files Modified

1. **`lib/attendance_page.dart`**
   - Updated table header to 8 columns
   - Updated `_buildTableRow()` to show separate columns
   - Removed tooltip (no longer needed)
   - Added color coding for each column type

## Status: ✅ READY FOR BUILD

All changes complete. The attendance page now clearly shows:
- Regular clocking days (blue)
- Manual attendance days (purple)
- Sick note days (orange)
- Total days with color-coded percentage
- Daily rate and total due

Users can now see exactly how the attendance total is made up!
