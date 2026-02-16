# Moderator Comment System - Visual Guide

## New UI Structure

### Before (Old System)
```
Formative
├── Exercise 1
│   ├── Marks: 8/10
│   ├── View Answer button
│   └── [Moderation dialog with comment per exercise]
├── Exercise 2
│   ├── Marks: 9/10
│   ├── View Answer button
│   └── [Moderation dialog with comment per exercise]
└── Exercise 3
    ├── Marks: 7/10
    ├── View Answer button
    └── [Moderation dialog with comment per exercise]
```

### After (New System - Matches Assessor Pattern)
```
Formative
├── Exercise 1
│   ├── Marks: 8/10
│   └── View Answer button
├── Exercise 2
│   ├── Marks: 9/10
│   └── View Answer button
├── Exercise 3
│   ├── Marks: 7/10
│   └── View Answer button
├── ─────────────────────────────
├── 📝 Assessor Comments:
│   └── "Good understanding of concepts. Minor errors in calculation."
├── ─────────────────────────────
├── Moderator Comment
│   ├── [Text field for comment]
│   └── [Uphold] [Withdraw] buttons
```

## Comment Display Examples

### Assessor Comment Box
```
┌─────────────────────────────────────────┐
│ 💬 Assessor Comments:                   │
│                                         │
│ The learner demonstrated excellent      │
│ understanding of the formative          │
│ assessment requirements. All exercises  │
│ were completed with good quality.       │
└─────────────────────────────────────────┘
```

### Moderator Comment Section
```
┌─────────────────────────────────────────┐
│ Moderator Comment                       │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Enter your moderation comments for  │ │
│ │ formative assessments               │ │
│ │                                     │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ [✓ Uphold]  [✗ Withdraw]               │
└─────────────────────────────────────────┘
```

## Workflow Comparison

### Assessor Workflow
1. Mark all exercises in Formative
2. Add ONE comment for entire Formative section
3. Submit marks and comment
4. Repeat for Summative
5. Repeat for Logbook

### Moderator Workflow (Now Matches!)
1. Review all exercises in Formative
2. Read assessor's comment
3. Add ONE moderation comment for entire Formative section
4. Click Uphold or Withdraw
5. Repeat for Summative
6. Repeat for Logbook

## Key Differences from Old System

| Aspect | Old System | New System |
|--------|-----------|------------|
| Comment Frequency | Per exercise | Per assessment type |
| Assessor Comments | Not visible | Visible in blue box |
| Comment Location | In moderation dialog | After all exercises |
| Pattern | Different from assessor | Same as assessor |
| Efficiency | Multiple comments needed | Single comment per type |

## Color Coding

- **Blue Box** = Assessor Comments (read-only)
- **White Box** = Moderator Comment (editable)
- **Green Button** = Uphold decision
- **Red Button** = Withdraw decision

## Example Scenario

**Learner:** John Doe  
**Assessment Type:** Formative  
**Exercises:** 3 exercises (all marked by assessor)

**Moderator sees:**
1. Exercise 1: 8/10 - Can view learner's answer
2. Exercise 2: 9/10 - Can view learner's answer
3. Exercise 3: 7/10 - Can view learner's answer
4. **Assessor Comment:** "Good work overall, minor calculation errors"
5. **Moderator Comment Field:** [Empty or existing comment]
6. **Actions:** [Uphold] or [Withdraw]

**Moderator action:**
- Reads all exercises
- Reads assessor's comment
- Enters: "Assessment is fair and accurate. Marks are appropriate."
- Clicks **Uphold**
- Comment is saved for ALL formative exercises

## Benefits

✅ **Efficiency**: Comment once instead of 3 times  
✅ **Context**: See assessor's reasoning  
✅ **Consistency**: Same workflow as assessor  
✅ **Clarity**: Clear visual separation  
✅ **Simplicity**: Less clicking, faster moderation
