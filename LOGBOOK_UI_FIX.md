# LogBook UI Overflow Fix

## Issue
Yellow warning stripes appearing on the right side of logbook items, indicating layout overflow.

## Root Cause
The `ListTile` widget with `Row` in the `trailing` property was causing horizontal overflow because:
1. Long unit standard names weren't being truncated
2. Multiple IconButtons in the trailing Row exceeded available space
3. Text wasn't wrapped properly

## Solution Applied

### 1. Replaced ListTile with Custom Row Layout
- Changed from `ListTile` to a custom `Row` widget wrapped in `Padding`
- Added `Expanded` widget around the text content to prevent overflow
- Set proper constraints on IconButtons

### 2. Text Overflow Handling
- Added `overflow: TextOverflow.ellipsis` to truncate long text
- Set `maxLines: 2` for exercise names
- Wrapped title text in `Expanded` widget

### 3. Icon Button Optimization
- Reduced icon sizes from default to 20px
- Added explicit `padding: EdgeInsets.all(8)` 
- Added `constraints: BoxConstraints()` to minimize button size
- Changed "COMPLETED" badge text to "DONE" for shorter width

### 4. Improved Layout Structure
```dart
Row(
  children: [
    Icon(...),                    // Fixed width
    SizedBox(width: 12),          // Fixed spacing
    Expanded(                     // Takes remaining space
      child: Column(
        children: [
          Text(...),              // Truncates if too long
          Text(...),              // Status text
        ],
      ),
    ),
    IconButton(...),              // Fixed width with constraints
    IconButton(...),              // Fixed width with constraints
  ],
)
```

## Changes Made

### Before:
- Used `ListTile` with `title`, `subtitle`, and `trailing`
- No text overflow handling
- Default IconButton sizes
- "COMPLETED" badge text

### After:
- Custom `Row` layout with `Expanded` text
- Text truncation with ellipsis
- Smaller, constrained IconButtons
- "DONE" badge text (shorter)
- Proper padding and spacing

## Result
✅ No more yellow overflow warnings
✅ Text truncates properly with ellipsis
✅ Icons fit within available space
✅ Responsive layout that adapts to screen width
✅ Cleaner, more compact appearance

## Testing
- Test with long unit standard names
- Test with long exercise names
- Test on different screen sizes
- Verify icons are clickable
- Verify text is readable when truncated
