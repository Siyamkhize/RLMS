# Pothole Checklist Moderation - UI Guide

## Visual Structure

### Before (Old UI)
```
┌─────────────────────────────────────────┐
│ Pothole Checklist                       │
├─────────────────────────────────────────┤
│ [View Checklist Button]                 │
│                                         │
│ Unit Standard 13958: 45/50             │
│ Unit Standard 14555: 48/50             │
│                                         │
│ Moderator Comments: [Text Field]       │
│ Moderation Decision: [Dropdown]         │
│ [Submit Button]                         │
│                                         │
│ ❌ Problem: One decision for both       │
└─────────────────────────────────────────┘
```

### After (New UI)
```
┌─────────────────────────────────────────┐
│ Pothole Checklist                       │
├─────────────────────────────────────────┤
│ [View Checklist Button]                 │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 📋 Unit Standard: 13958             │ │
│ │ Marks: 45 / 50                      │ │
│ │                                     │ │
│ │ 💬 Assessor Comment:                │ │
│ │ "Good understanding of concepts"    │ │
│ │                                     │ │
│ │ Moderation Decision                 │ │
│ │ [-- Select Decision --  ▼]          │ │
│ │ • Uphold                            │ │
│ │ • Withdraw                          │ │
│ │                                     │ │
│ │ ✅ Current Status: UPHELD           │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 📋 Unit Standard: 14555             │ │
│ │ Marks: 48 / 50                      │ │
│ │                                     │ │
│ │ 💬 Assessor Comment:                │ │
│ │ "Excellent practical application"   │ │
│ │                                     │ │
│ │ Moderation Decision                 │ │
│ │ [-- Select Decision --  ▼]          │ │
│ │ • Uphold                            │ │
│ │ • Withdraw                          │ │
│ │                                     │ │
│ │ ✅ Current Status: UPHELD           │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ═══════════════════════════════════════ │
│                                         │
│ Moderator Comment                       │
│ (Shared for all Unit Standards)        │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ [Text Field - Multi-line]           │ │
│ │ "Both unit standards demonstrate    │ │
│ │  competence. Assessor marks are     │ │
│ │  appropriate and well justified."   │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ [💾 Save Comment]                       │
│                                         │
│ ✅ Solution: Separate decisions!       │
└─────────────────────────────────────────┘
```

## Color Coding

### Status Indicators

**Upheld (Green)**
```
┌─────────────────────────────────┐
│ ✅ Current Status: UPHELD       │
│ Background: Light Green         │
│ Border: Green                   │
└─────────────────────────────────┘
```

**Withdrawn (Red)**
```
┌─────────────────────────────────┐
│ ❌ Current Status: WITHDRAWN    │
│ Background: Light Red           │
│ Border: Red                     │
└─────────────────────────────────┘
```

**Assessor Comment (Blue)**
```
┌─────────────────────────────────┐
│ 💬 Assessor Comment:            │
│ "Comment text here..."          │
│ Background: Light Blue          │
│ Border: Blue                    │
└─────────────────────────────────┘
```

## User Interactions

### 1. Selecting Moderation Decision

**Step 1: Click Dropdown**
```
┌─────────────────────────────────┐
│ Moderation Decision             │
│ [-- Select Decision --  ▼]      │
└─────────────────────────────────┘
```

**Step 2: Choose Option**
```
┌─────────────────────────────────┐
│ [-- Select Decision --  ▼]      │
├─────────────────────────────────┤
│ -- Select Decision --           │
│ ✓ Uphold                        │ ← Click here
│   Withdraw                      │
└─────────────────────────────────┘
```

**Step 3: Auto-Save**
```
┌─────────────────────────────────┐
│ ✅ Snackbar Message:            │
│ "Unit Standard 13958 upheld     │
│  successfully!"                 │
└─────────────────────────────────┘
```

### 2. Adding Shared Comment

**Step 1: Type Comment**
```
┌─────────────────────────────────┐
│ Moderator Comment               │
│ (Shared for all Unit Standards) │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ [Cursor here]               │ │
│ │ Type your comments...       │ │
│ │                             │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

**Step 2: Click Save**
```
┌─────────────────────────────────┐
│ [💾 Save Comment] ← Click       │
└─────────────────────────────────┘
```

**Step 3: Confirmation**
```
┌─────────────────────────────────┐
│ ✅ Snackbar Message:            │
│ "Moderator comment saved        │
│  successfully!"                 │
└─────────────────────────────────┘
```

## Example Scenarios

### Scenario 1: Uphold Both Unit Standards
```
Unit Standard 13958: ✅ UPHELD
Unit Standard 14555: ✅ UPHELD
Comment: "Both assessments are accurate and well-documented."
```

### Scenario 2: Uphold One, Withdraw Another
```
Unit Standard 13958: ✅ UPHELD
Unit Standard 14555: ❌ WITHDRAWN
Comment: "US 13958 is acceptable. US 14555 requires reassessment due to insufficient evidence."
```

### Scenario 3: Withdraw Both
```
Unit Standard 13958: ❌ WITHDRAWN
Unit Standard 14555: ❌ WITHDRAWN
Comment: "Both assessments need to be redone. Evidence does not meet the required standards."
```

## Mobile View Considerations

### Portrait Mode
- Each unit standard card stacks vertically
- Dropdown and status display full width
- Comment field spans full width
- Save button centered

### Landscape Mode
- Same vertical stacking (no side-by-side)
- Maintains readability
- Scrollable content

## Accessibility Features

- **Clear Labels**: Each field has descriptive labels
- **Color + Icons**: Status uses both color and icons (✅/❌)
- **Touch Targets**: Buttons and dropdowns are large enough
- **Feedback**: Snackbar messages confirm actions
- **Scrollable**: Content scrolls if it exceeds screen height

## Technical Notes

### State Management
- Each dropdown uses `StatefulBuilder` for local state
- Shared comment uses `StatefulBuilder` for text field
- Main widget refreshes after successful save

### Data Flow
```
User Action → Flutter Method → HTTP Request → PHP Endpoint
     ↓              ↓               ↓              ↓
  Dropdown    _submitPothole   moderate_marks   Database
  Selection   UnitStandard     .php             Update
              Moderation()
     ↓              ↓               ↓              ↓
  Response ← JSON Response ← SQL Update ← logbook_marks
     ↓
  Snackbar + UI Refresh
```

## Best Practices for Moderators

1. **Review First**: View the checklist before making decisions
2. **Read Assessor Comments**: Consider assessor's notes
3. **Decide Per Unit Standard**: Each can be different
4. **Add Detailed Comments**: Explain your decisions
5. **Save Comment**: Don't forget to click "Save Comment"
6. **Verify Status**: Check that status displays correctly

## Troubleshooting

### Issue: Dropdown doesn't save
- **Check**: Network connection
- **Check**: Server is accessible
- **Look for**: Error snackbar message

### Issue: Comment not saving
- **Check**: Clicked "Save Comment" button
- **Check**: Network connection
- **Verify**: Both unit standards updated

### Issue: Status not displaying
- **Check**: Data was fetched successfully
- **Refresh**: Pull down to refresh
- **Verify**: Database has moderation data

## Summary

✅ **Separate decisions** for each unit standard
✅ **Shared comment** applies to all
✅ **Clear visual feedback** with colors and icons
✅ **Easy to use** with dropdowns and buttons
✅ **Real-time updates** with auto-refresh
