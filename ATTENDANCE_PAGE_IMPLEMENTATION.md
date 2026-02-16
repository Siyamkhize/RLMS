# Monthly Attendance & Stipend Calculator

## Summary
Created a comprehensive monthly attendance tracking system with automatic stipend calculations, working days computation, and holiday support.

## Key Features

### 1. Monthly Attendance View
- Shows all learners in the class (no duplicates)
- Displays attendance for the entire selected month
- Counts distinct attendance dates per learner
- Automatically excludes weekends from working days calculation

### 2. Working Days Calculation
- Automatically calculates working days per month (excludes weekends)
- Each month has its own working days count
- Example: January 2024 = 23 working days, February 2024 = 21 working days

### 3. Holiday Support
- Public holidays that fall on working days are counted as attended
- Includes South African public holidays:
  - New Year's Day (Jan 1)
  - Human Rights Day (Mar 21)
  - Freedom Day (Apr 27)
  - Workers' Day (May 1)
  - Youth Day (Jun 16)
  - National Women's Day (Aug 9)
  - Heritage Day (Sep 24)
  - Day of Reconciliation (Dec 16)
  - Christmas Day (Dec 25)
  - Day of Goodwill (Dec 26)
- Holidays on weekends are not counted
- Custom holidays can be added to the system

### 4. Stipend Calculations
- **Total Stipend**: R 2000 (configurable)
- **Daily Rate**: Total Stipend ÷ Expected Working Days
  - Example: R 2000 ÷ 21 days = R 95.24 per day
- **Total Due**: Daily Rate × Days Attended (including holidays)
  - Example: R 95.24 × 5 days = R 476.19

### 5. Table Format Display
Columns displayed in order:
1. **Surname** - Learner's surname
2. **Name** - Learner's first name
3. **ID Number** - Learner ID
4. **Days Attended** - Actual days attended + holidays
5. **Expected Days** - Total working days in the month
6. **Daily Rate** - Calculated rate per day
7. **Total Due** - Amount owed to learner

### 6. Visual Features
- Color-coded attendance rates:
  - Green: >80% attendance
  - Orange: 50-80% attendance
  - Red: <50% attendance
- Alternating row colors for easy reading
- Summary statistics at the top
- Month selector with calendar picker
- Configurable stipend amount

## Usage

### View Monthly Attendance
1. Open Dashboard
2. Tap menu icon (☰)
3. Select "Attendance"
4. View current month's attendance

### Change Month
1. Tap calendar icon in top-right
2. Select desired month
3. Data automatically refreshes

### Adjust Stipend Amount
1. Tap money icon ($) in top-right
2. Enter new total stipend amount
3. Tap "Update"
4. All calculations automatically recalculate

### Understanding the Display
- **Expected Days**: Working days in the month (excludes weekends)
- **Days Attended**: Actual attendance + holidays on working days
- **Daily Rate**: Stipend ÷ Expected Days
- **Total Due**: Daily Rate × Days Attended

## Example Calculation

**Scenario**: January 2024
- Total Stipend: R 2000
- Working Days: 23 (excludes weekends)
- Holidays: 1 (New Year's Day on Monday)
- Expected Days: 23
- Daily Rate: R 2000 ÷ 23 = R 86.96

**Learner A**:
- Attended: 15 days
- Holidays: 1 day (automatically added)
- Total Days: 16 days
- Total Due: R 86.96 × 16 = R 1,391.36

**Learner B**:
- Attended: 20 days
- Holidays: 1 day (automatically added)
- Total Days: 21 days
- Total Due: R 86.96 × 21 = R 1,826.16

## Technical Implementation

### Database Query
- Queries `learnerdetails` and `learner_clocking` tables
- Groups by learner to count distinct attendance dates
- Filters by classID and date range
- Orders by Surname, Name

### Holiday Logic
- Checks if date is a public holiday
- Only counts holidays that fall on working days (Mon-Fri)
- Automatically adds holiday count to each learner's attendance

### Working Days Algorithm
```
For each day in month:
  If day is Monday-Friday:
    workingDays++
```

### Stipend Calculation
```
dailyRate = totalStipend / expectedWorkingDays
daysAttended = actualAttendance + holidaysOnWorkingDays
totalDue = dailyRate × daysAttended
```

## Benefits
1. **Accurate Calculations**: Automatic daily rate calculation based on actual working days
2. **Fair Distribution**: Holidays are counted as attended for all learners
3. **Monthly Flexibility**: Each month calculated independently with its own working days
4. **Easy Tracking**: Table format shows all information at a glance
5. **Configurable**: Stipend amount can be adjusted per month if needed
