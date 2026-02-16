# Pothole Checklist Moderation - Quick Guide

## ✅ IMPLEMENTATION COMPLETE

The pothole checklist now supports **per-unit-standard moderation** with separate Uphold/Withdraw decisions for each unit standard and one shared moderator comment.

## How to Use

### For Moderators

1. **Navigate to Pothole Checklist**
   - Open Moderator Dashboard
   - Select a class and learner
   - Go to "POE Details" tab
   - Expand "Pothole Checklist" section

2. **Review Each Unit Standard**
   - You'll see two unit standards: **13958** and **14555**
   - Each shows:
     - Marks scored (out of 50)
     - Assessor's comment
     - Current moderation status (if already moderated)

3. **Make Moderation Decision**
   - For **Unit Standard 13958**: Select "Uphold" or "Withdraw" from dropdown
   - For **Unit Standard 14555**: Select "Uphold" or "Withdraw" from dropdown
   - Each decision is saved immediately
   - You'll see a success message after each selection

4. **Add Moderator Comment**
   - Scroll to the "Shared Moderator Comment" section
   - Enter your comment (applies to both unit standards)
   - Click "Update Comment for All Unit Standards"
   - Comment is saved for both unit standards

5. **Update Later**
   - You can change decisions at any time
   - You can edit the comment at any time
   - Existing values are preserved

## Key Features

✅ **Independent Decisions** - Uphold one unit standard, withdraw another

✅ **Shared Comment** - One comment for both unit standards

✅ **Immediate Save** - No need to click a separate "Save" button for decisions

✅ **Visual Feedback** - Green for upheld, red for withdrawn

✅ **Edit Anytime** - Change decisions and comments as needed

## Example Scenario

**Scenario**: Unit Standard 13958 is good, but Unit Standard 14555 needs work

1. Select "Uphold" for Unit Standard 13958 ✅
2. Select "Withdraw" for Unit Standard 14555 ❌
3. Enter comment: "Unit Standard 13958 meets all requirements. Unit Standard 14555 requires additional evidence for criteria 2 and 3."
4. Click "Update Comment for All Unit Standards"
5. Done! ✅

## Technical Details

- **Backend**: Uses existing `moderate_marks.php` endpoint
- **Database**: Stores in `logbook_marks` table
- **Status Values**: 'upheld' or 'withdrawn'
- **Comment**: Shared TEXT field for both unit standards

## Troubleshooting

**Q: I don't see the pothole checklist section**
- A: The learner may not have completed a pothole checklist yet

**Q: The dropdown doesn't show my previous selection**
- A: Refresh the page - the data should load from the database

**Q: I want to change my decision**
- A: Simply select a different option from the dropdown - it will update immediately

**Q: Can I have different comments for each unit standard?**
- A: No, the comment is shared. However, you can mention both unit standards in your comment (see example above)

## Support

If you encounter any issues, check:
1. Network connection
2. Browser console for errors
3. Database connection

All moderation data is stored in the `logbook_marks` table with columns:
- `moderator_status`
- `moderator_comment`
- `moderator_id`
- `moderation_date`
