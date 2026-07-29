# ARPL Paper Selection - New UI Visual Guide

## Navigation Path with Paper Counts

```
┌──────────────────────────────────────────────────────────────┐
│                     ARPL PORTFOLIO                            │
└──────────────────────────────────────────────────────────────┘
                            ↓
            SELECT PATHWAY (if multiple)
                            ↓
            SELECT TRADE (Electrical, Plumbing, etc.)
                            ↓
        ┌────────────────────────────────────────┐
        │       SELECT SECTION TYPE               │
        ├────────────────────────────────────────┤
        │  ┌──────────────┐  ┌──────────────┐   │
        │  │  📄 THEORY   │  │ 🔧 PRACTICAL │   │
        │  │  3 papers    │  │  2 papers    │   │
        │  └──────────────┘  └──────────────┘   │
        └────────────────────────────────────────┘
                            ↓
        ┌────────────────────────────────────────┐
        │       SELECT PAPER                      │
        │  📋 Available Papers: 3                │
        ├────────────────────────────────────────┤
        │ ┌──────────────────────────────────┐  │
        │ │ 1│ Apply Health & Safety          │  │
        │ │  │ 5 questions                    │  │
        │ ├──────────────────────────────────┤  │
        │ │ 2│ Electrical Circuits             │  │
        │ │  │ 3 questions                    │  │
        │ ├──────────────────────────────────┤  │
        │ │ 3│ Wiring Systems                 │  │
        │ │  │ 7 questions                    │  │
        │ └──────────────────────────────────┘  │
        └────────────────────────────────────────┘
                            ↓
        ┌────────────────────────────────────────┐
        │      UPLOAD QUESTIONS                   │
        │  Paper: Apply Health & Safety           │
        ├────────────────────────────────────────┤
        │  📄 Apply Health & Safety              │
        │  Trade: Electrical                     │
        │  ─────────────────────────────────────│
        │  Total Questions: 5                    │
        │  Remaining: 2          ← Shows progress│
        │  Status: In Progress   ← Color-coded  │
        │─────────────────────────────────────────
        │  ☐ Question 1                          │
        │  ☐ Question 2                          │
        │  ☑ Question 3                          │
        │  ☑ Question 4                          │
        │  ☐ Question 5                          │
        │─────────────────────────────────────────
        │  [📤 Scan All Questions (2)]           │
        └────────────────────────────────────────┘
                            ↓
                    SCAN & UPLOAD
                            ↓
                   ✅ COMPLETE
                   Back to paper selection
```

---

## Screen-by-Screen Breakdown

### SCREEN 1: Section Selector
```
┌─────────────────────────────────────────┐
│ ◀  Select Section Type                  │
│    Trade: Electrical                    │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │           📄                     │   │
│  │        THEORY                    │   │
│  │     3 papers                     │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │           🔧                     │   │
│  │       PRACTICAL                  │   │
│  │     2 papers                     │   │
│  └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

**Key Features:**
- Shows how many papers per section
- Grid layout with icons
- Easy to tap, large touch targets
- Clear visual distinction

---

### SCREEN 2: Paper Selector
```
┌─────────────────────────────────────────┐
│ ◀  Select Paper                         │
│    Electrical - Theory                  │
├─────────────────────────────────────────┤
│ ┌──────────────────────────────────┐   │
│ │ 📋 Available Papers: 3           │   │
│ └──────────────────────────────────┘   │
├─────────────────────────────────────────┤
│ ┌──────────────────────────────────┐   │
│ │ 1│ Apply Health & Safety        ▶ │   │
│ │  │ 5 questions                  │   │
│ ├──────────────────────────────────┤   │
│ │ 2│ Electrical Circuits            ▶ │   │
│ │  │ 3 questions                  │   │
│ ├──────────────────────────────────┤   │
│ │ 3│ Wiring Systems                 ▶ │   │
│ │  │ 7 questions                  │   │
│ └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Key Features:**
- Summary card shows total papers
- Paper number badges (1, 2, 3)
- Question count for each paper
- Clear paper titles
- Arrow indicator for interaction

---

### SCREEN 3: Upload Questions
```
┌─────────────────────────────────────────┐
│ ◀  Upload Questions                     │
│    Apply Health & Safety                │
├─────────────────────────────────────────┤
│ ┌──────────────────────────────────┐   │
│ │ 📄 Apply Health & Safety          │   │
│ │ Trade: Electrical                │   │
│ ├──────────────────────────────────┤   │
│ │ Total Questions    Remaining     │   │
│ │      5                  2        │   │
│ │                                 │   │
│ │ Status: In Progress              │   │
│ └──────────────────────────────────┘   │
├─────────────────────────────────────────┤
│ ☐ Q1. Identify hazards                │
│ ☐ Q2. Risk assessment                 │
│ ☑ Q3. Control measures                │
│ ☑ Q4. Incident reporting              │
│ ☐ Q5. Emergency procedures            │
├─────────────────────────────────────────┤
│                                         │
│ 📤 Scan All Questions (2)              │
│                                         │
└─────────────────────────────────────────┘
```

**Key Features:**
- Paper name in header
- Info card with statistics
- Progress tracking (Remaining: 2)
- Status indicator (In Progress)
- Checkmarks show completed questions
- Upload button shows count remaining

---

## Color Coding

### Status Colors

| Status | Color | Meaning |
|--------|-------|---------|
| Not Started | 🔴 Red | No questions uploaded |
| In Progress | 🟡 Orange | Some questions uploaded |
| Complete | 🟢 Green | All questions uploaded |

### Section Colors

| Element | Color |
|---------|-------|
| Section Headers | Deep Purple |
| Section Cards | White with Purple accents |
| Paper Count | Deep Purple background |
| Badges | Deep Purple/100 |

---

## Data Display Examples

### Example 1: Multiple Papers
```
Pathway: ARPL
Trade: Plumbing
Section: Theory
Papers Available: 4

Paper 1: "Plumbing Systems"           → 6 questions
Paper 2: "Pipe Installation"           → 4 questions
Paper 3: "Safety & Hygiene"            → 5 questions
Paper 4: "Maintenance & Repair"        → 3 questions

Total: 18 questions
```

### Example 2: Upload Progress
```
Paper: "Electrical Safety"
Total Questions: 5
Uploaded: 3 ✅
Remaining: 2 📤

Q1 ✅ Equipment handling
Q2 ✅ Lockout procedures
Q3 ✅ Fire safety
Q4 ☐ Emergency response
Q5 ☐ First aid
```

---

## Benefits of New UI

### For First-Time Users
✅ Clear visual hierarchy  
✅ Easy to understand flow  
✅ Questions clearly labeled  
✅ Progress evident  

### For Experienced Users
✅ Quick paper identification  
✅ Efficient navigation  
✅ Paper counts at a glance  
✅ Status tracking obvious  

### For Troubleshooting
✅ Debug info easily visible  
✅ Paper names clearly shown  
✅ Question counts accurate  
✅ Progress tracking clear  

---

## Before vs After Comparison

### BEFORE: Basic List
```
Select Paper
- Apply Health & Safety
- Electrical Circuits  
- Wiring Systems

(No indication of question count)
(No progress tracking)
```

### AFTER: Enhanced List
```
Select Paper
📋 Available Papers: 3

1 │ Apply Health & Safety
  │ 5 questions

2 │ Electrical Circuits
  │ 3 questions

3 │ Wiring Systems
  │ 7 questions
```

**Improvements:**
- Paper count shown
- Question count per paper
- Paper numbers for easy reference
- Better visual organization
- Clear indicators

---

## Implementation Details

### Technology
- Flutter Material Design
- ListTile components
- Card widgets
- Grid layout
- Color-coded status

### File Modified
- `lib/ArplHierarchicalNavigatorPage.dart`

### Build Required
- Rebuild APK after changes
- No database schema changes
- No API endpoint changes
- Backward compatible

---

## Testing Steps

1. **Open ARPL Portfolio**
   - See pathway selection if multiple available

2. **Select Trade**
   - Navigate to section selection

3. **Section Screen**
   - ✅ Should see grid with two cards
   - ✅ Cards should show paper counts
   - ✅ Should be able to tap cards

4. **Paper Screen**
   - ✅ Should see list of papers
   - ✅ Each paper shows question count
   - ✅ Should be numbered 1, 2, 3...
   - ✅ Summary should show total count

5. **Question Screen**
   - ✅ Should show paper name in header
   - ✅ Info card should show progress
   - ✅ Remaining questions should update
   - ✅ Status should show "In Progress"

---

## User Quick-Start Guide

### How to Upload Your Portfolio

1. **Tap ARPL Portfolio** in your app
2. **Select Your Trade** (e.g., Electrical)
3. **Choose Section** (Theory or Practical)
   - See how many papers available
4. **Pick a Paper**
   - See how many questions to answer
5. **Scan & Upload**
   - See progress (X questions remaining)
6. **Repeat** for all papers

---

**Status**: ✅ Complete & Ready  
**Last Updated**: July 6, 2026
