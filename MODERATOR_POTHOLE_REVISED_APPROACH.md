# Revised Approach - Moderator Pothole Checklist

## User Requirement Clarification

The moderator should see:
1. **Full Pothole Checklist** - Exactly as shown in AssessorPage
2. **All Marks** - LogBook marks and Pothole checklist marks (READ-ONLY)
3. **Decision Options** - Uphold or Withdraw (not Approve/Disapprove)
4. **Comment** - Required when withdrawing

## Key Differences from Initial Implementation

### Initial (Incorrect):
- Only showed summary marks
- Simple approve/disapprove form
- No checklist details visible

### Revised (Correct):
- Shows complete pothole checklist with all items
- Shows LogBook unit standards with marks
- Shows pothole evidence images
- Moderator reviews everything then decides: Uphold or Withdraw
- Uses same view components as AssessorPage but in read-only mode

## Implementation Plan

1. Reuse `PotholeChecklistViewPage` from AssessorPage
2. Modify it to show "Uphold/Withdraw" instead of marks entry
3. Fetch complete checklist data (not just marks summary)
4. Display everything in read-only mode
5. Add Uphold/Withdraw decision at the bottom

## Database - No Changes Needed

The `marks` table already has:
- `approval_status` ENUM('Approved', 'Disapproved') 
- `comment` VARCHAR(256)

We'll map:
- **Uphold** → `approval_status = 'Approved'`
- **Withdraw** → `approval_status = 'Disapproved'`

## Next Steps

1. Update ModeratorPage to navigate to full checklist view
2. Fetch complete checklist data (same as assessor)
3. Display in read-only mode
4. Add Uphold/Withdraw decision form at bottom
5. Save to marks table with approval_status

This matches the assessor workflow but for moderation instead of marking.
