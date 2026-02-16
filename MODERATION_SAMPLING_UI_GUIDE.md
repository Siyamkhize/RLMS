# Moderation Sampling - UI Visual Guide

## Page Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  ← Back                    Moderator Dashboard                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  🔬 Moderation Sampling                                          │
│  Stratified random sampling for quality assurance                │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ 📊 Sampling Summary                                        │  │
│  │                                                             │  │
│  │ Sampling Method:           stratified_comprehensive        │  │
│  │ Total Learners with POE:   100                            │  │
│  │ Selected for Moderation:   25                             │  │
│  │ Sampling Rate:             25%                            │  │
│  │ Total Strata:              15                             │  │
│  │                                                             │  │
│  │ ✅ This is your existing assignment                        │  │
│  │                                                             │  │
│  │ ─────────────────────────────────────────────────────────  │  │
│  │ Stratification Dimensions:                                 │  │
│  │   ✓ Class                                                  │  │
│  │   ✓ Site                                                   │  │
│  │   ✓ POE Completeness (Complete/Partial/Incomplete)        │  │
│  │   ✓ Marking Status (Marked/Unmarked)                      │  │
│  │   ✓ Performance Level (High/Medium/Low/Not Assessed)      │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                   │
│  Strata Breakdown                                                │
│  Each row represents a unique combination of dimensions          │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Class    │ Site  │ POE Status │ Marking │ Perf.  │ Total │  │
│  ├──────────┼───────┼────────────┼─────────┼────────┼───────┤  │
│  │ Class A  │ S1    │ Complete   │ Marked  │ High   │  8    │  │
│  │          │       │  [Green]   │ [Blue]  │[Green] │       │  │
│  │          │       │            │         │        │ Sel: 2│  │
│  ├──────────┼───────┼────────────┼─────────┼────────┼───────┤  │
│  │ Class A  │ S1    │ Partial    │Unmarked │ Medium │  5    │  │
│  │          │       │ [Orange]   │ [Grey]  │[Orange]│       │  │
│  │          │       │            │         │        │ Sel: 2│  │
│  ├──────────┼───────┼────────────┼─────────┼────────┼───────┤  │
│  │ Class B  │ S2    │ Complete   │ Marked  │ Low    │  4    │  │
│  │          │       │  [Green]   │ [Blue]  │ [Red]  │       │  │
│  │          │       │            │         │        │ Sel: 1│  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                   │
│  Selected Learners                                               │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ ID  │ Name │ Class │ POE    │ Mark  │ Perf  │ Units │ Act │  │
│  ├─────┼──────┼───────┼────────┼───────┼───────┼───────┼─────┤  │
│  │ 123 │ John │ A     │Complete│Marked │ High  │  2    │[Mod]│  │
│  │     │ Doe  │       │[Green] │[Blue] │[Green]│       │     │  │
│  ├─────┼──────┼───────┼────────┼───────┼───────┼───────┼─────┤  │
│  │ 124 │ Jane │ A     │Partial │Unmark │Medium │  1    │[Mod]│  │
│  │     │Smith │       │[Orange]│[Grey] │[Orng] │       │     │  │
│  ├─────┼──────┼───────┼────────┼───────┼───────┼───────┼─────┤  │
│  │ 125 │ Bob  │ B     │Complete│Marked │ Low   │  2    │[Mod]│  │
│  │     │Jones │       │[Green] │[Blue] │ [Red] │       │     │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Color Legend

### POE Completeness Status
```
┌──────────────┬─────────┬─────────────────────────────┐
│ Status       │ Color   │ Meaning                     │
├──────────────┼─────────┼─────────────────────────────┤
│ Complete     │ 🟢 Green│ All unit standards uploaded │
│ Partial      │ 🟠 Orange│ Some unit standards missing│
│ Incomplete   │ 🔴 Red  │ No uploads                  │
└──────────────┴─────────┴─────────────────────────────┘
```

### Marking Status
```
┌──────────────┬─────────┬─────────────────────────────┐
│ Status       │ Color   │ Meaning                     │
├──────────────┼─────────┼─────────────────────────────┤
│ Marked       │ 🔵 Blue │ Work has been assessed      │
│ Unmarked     │ ⚪ Grey │ Work not yet assessed       │
└──────────────┴─────────┴─────────────────────────────┘
```

### Performance Level
```
┌──────────────┬─────────┬─────────────────────────────┐
│ Level        │ Color   │ Criteria                    │
├──────────────┼─────────┼─────────────────────────────┤
│ High         │ 🟢 Green│ Average marks ≥ 70%         │
│ Medium       │ 🟠 Orange│ Average marks 50-69%       │
│ Low          │ 🔴 Red  │ Average marks < 50%         │
│ Not Assessed │ ⚪ Grey │ No marks available          │
└──────────────┴─────────┴─────────────────────────────┘
```

## Interactive Elements

### 1. Sampling Summary Card
```
┌─────────────────────────────────────────┐
│ 📊 Sampling Summary                     │
│                                         │
│ • Shows total learners vs selected     │
│ • Displays sampling method              │
│ • Lists all stratification dimensions   │
│ • Indicates if assignment is existing   │
│                                         │
│ [Blue background, elevated card]        │
└─────────────────────────────────────────┘
```

### 2. Strata Breakdown Table
```
┌─────────────────────────────────────────┐
│ Strata Breakdown                        │
│ Each row = unique dimension combo       │
│                                         │
│ • Horizontally scrollable               │
│ • Color-coded status badges             │
│ • Shows counts and percentages          │
│ • Blue header row                       │
│                                         │
│ [White background, shadow elevation]    │
└─────────────────────────────────────────┘
```

### 3. Selected Learners Table
```
┌─────────────────────────────────────────┐
│ Selected Learners                       │
│                                         │
│ • Horizontally scrollable               │
│ • Color-coded status badges             │
│ • Purple "Moderate" buttons             │
│ • Purple header row                     │
│                                         │
│ [White background, shadow elevation]    │
└─────────────────────────────────────────┘
```

### 4. Moderate Button
```
┌──────────────┐
│  Moderate    │  ← Purple button
└──────────────┘
     ↓
Opens ModeratorMarkingPage
```

## User Flow

### First-Time Access
```
1. Login as Moderator
   ↓
2. Open Drawer Menu
   ↓
3. Click "Moderation Sampling"
   ↓
4. System generates sample
   ↓
5. See comprehensive breakdown
   ↓
6. Click "Moderate" on any learner
   ↓
7. Begin moderation
```

### Subsequent Access
```
1. Login as Moderator
   ↓
2. Open Drawer Menu
   ↓
3. Click "Moderation Sampling"
   ↓
4. See existing assignment
   ↓
5. Green indicator shows "existing"
   ↓
6. Same learners as before
   ↓
7. Continue moderation
```

## Status Indicators

### Existing Assignment
```
┌─────────────────────────────────────────┐
│ ✅ This is your existing assignment     │
│ [Green background, rounded corners]     │
└─────────────────────────────────────────┘
```

### Loading State
```
┌─────────────────────────────────────────┐
│           ⏳ Loading...                 │
│     [Circular progress indicator]       │
└─────────────────────────────────────────┘
```

### Error State
```
┌─────────────────────────────────────────┐
│           ⚠️ Error                      │
│     Error: Connection failed            │
│         [Retry Button]                  │
└─────────────────────────────────────────┘
```

## Badge Styles

### Complete Badge
```
┌──────────┐
│ Complete │  ← White text on green background
└──────────┘
```

### Partial Badge
```
┌──────────┐
│ Partial  │  ← White text on orange background
└──────────┘
```

### Marked Badge
```
┌──────────┐
│  Marked  │  ← White text on blue background
└──────────┘
```

### High Performance Badge
```
┌──────────┐
│   High   │  ← White text on green background
└──────────┘
```

## Responsive Design

### Mobile View
```
┌─────────────────────┐
│  ← Moderation       │
│                     │
│  📊 Summary         │
│  [Collapsed card]   │
│                     │
│  Strata Breakdown   │
│  [Horizontal scroll]│
│                     │
│  Learners           │
│  [Horizontal scroll]│
│                     │
└─────────────────────┘
```

### Tablet View
```
┌───────────────────────────────┐
│  ← Moderation Sampling        │
│                               │
│  📊 Summary    │  Dimensions  │
│  [Side by side layout]        │
│                               │
│  Strata Breakdown             │
│  [Full width table]           │
│                               │
│  Learners                     │
│  [Full width table]           │
│                               │
└───────────────────────────────┘
```

### Desktop View
```
┌─────────────────────────────────────────────────┐
│  ← Moderation Sampling                          │
│                                                 │
│  📊 Summary          │  Dimensions              │
│  [Side by side]      │  [Checklist]            │
│                                                 │
│  Strata Breakdown                               │
│  [Full width table, all columns visible]        │
│                                                 │
│  Selected Learners                              │
│  [Full width table, all columns visible]        │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Accessibility Features

### Screen Reader Support
- All badges have descriptive labels
- Tables have proper headers
- Buttons have clear labels
- Status indicators are announced

### Keyboard Navigation
- Tab through all interactive elements
- Enter to activate buttons
- Arrow keys in tables
- Escape to close dialogs

### High Contrast Mode
- All colors meet WCAG AA standards
- Text is readable on all backgrounds
- Focus indicators are visible
- Borders are clear

## Animation & Transitions

### Page Load
```
1. Fade in summary card (300ms)
2. Slide in strata table (400ms)
3. Fade in learners table (500ms)
```

### Button Hover
```
Moderate button:
- Hover: Darker purple
- Press: Scale 0.95
- Release: Scale 1.0
```

### Badge Appearance
```
- Fade in with parent row
- No individual animation
- Instant color change
```

## Print Layout

When printing the page:
```
┌─────────────────────────────────────────┐
│ Moderation Sampling Report              │
│ Date: [Current Date]                    │
│ Moderator: [ID]                         │
│                                         │
│ Summary                                 │
│ [All summary data]                      │
│                                         │
│ Strata Breakdown                        │
│ [Full table, all rows]                  │
│                                         │
│ Selected Learners                       │
│ [Full table, all rows]                  │
│                                         │
│ Page 1 of X                             │
└─────────────────────────────────────────┘
```

## Tips for Users

### Understanding the Display
1. **Summary Card**: Quick overview of your assignment
2. **Dimensions List**: Shows what factors were considered
3. **Strata Table**: Detailed breakdown of each group
4. **Learners Table**: Your actual moderation assignment

### Using Color Codes
- **Green**: Good status (complete, high performance)
- **Orange**: Moderate status (partial, medium performance)
- **Red**: Needs attention (incomplete, low performance)
- **Blue**: Marked/assessed
- **Grey**: Not yet assessed

### Navigation
1. Click "Moderate" to start moderating a learner
2. Use back button to return to sampling page
3. Your assignment persists across sessions
4. Same learners will appear each time

---

This UI provides a comprehensive, transparent, and user-friendly interface for moderators to understand and work with their stratified sample assignments.
