# Moderator Quick Guide: Uphold/Withdraw Functionality

## What is Moderation?

Moderation is the process where moderators review marks entered by assessors and either:
- **Uphold** the marks (approve them)
- **Withdraw** the marks (reject them)

**Important**: Withdrawing marks does NOT delete them. The marks remain in the system but are marked as "Withdrawn" for quality assurance purposes.

## How to Use

### Step 1: Navigate to Learner POE
1. Open the ModeratorPage
2. Select a learner
3. Navigate to the POE tab

### Step 2: View Assessments
You'll see three main sections:
- **Unit Standards** (Formative/Summative)
- **LogBook**
- **Pothole Checklist**

### Step 3: Review Marks
Each exercise shows:
- Exercise name
- Marks scored by assessor
- Current moderation status (if any)
- Assessor comments (if any)

### Step 4: Take Action
1. Click on an exercise to expand it
2. Review the marks and assessor comments
3. Click either:
   - **Uphold** button (green) - to approve
   - **Withdraw** button (red) - to reject

### Step 5: Add Comment (Optional)
1. A dialog will appear
2. Add a comment explaining your decision (optional but recommended for withdrawals)
3. Click "Confirm Uphold" or "Confirm Withdraw"

### Step 6: Verify
- The exercise will update to show your moderation status
- A green checkmark indicates "Upheld"
- A red X indicates "Withdrawn"
- Your comment will be displayed below the exercise

## Visual Indicators

| Icon | Color | Meaning |
|------|-------|---------|
| ✅ | Green | Upheld |
| ❌ | Red | Withdrawn |
| 📋 | Blue | Not yet moderated |
| ⏳ | Orange | Not yet marked by assessor |

## Button States

- **Active** (colored): You can click to perform the action
- **Disabled** (grayed out): Already in that state
- **Hidden**: Marks not yet entered by assessor

## Important Notes

### ✅ DO:
- Review all marks carefully before moderating
- Add comments when withdrawing marks
- Check assessor comments for context
- Verify marks match the assessment criteria

### ❌ DON'T:
- Rush through moderation
- Withdraw without explanation
- Moderate without reviewing the full assessment
- Change your decision without proper justification

## What Happens When You Withdraw?

1. **Marks are preserved**: Original marks remain in database
2. **Status is updated**: `moderator_status` set to "Withdrawn"
3. **Comment is saved**: Your explanation is recorded
4. **Timestamp is logged**: Date and time of moderation
5. **Moderator is tracked**: Your ID is recorded

## Frequently Asked Questions

### Q: Can I change my moderation decision?
A: Currently, once you uphold or withdraw, the button for that action is disabled. Future updates may allow changing decisions.

### Q: What if I accidentally withdraw marks?
A: Contact your system administrator. The marks are not deleted and can be restored.

### Q: Do I need to add a comment?
A: Comments are optional but highly recommended, especially when withdrawing marks.

### Q: Can I moderate marks that haven't been entered yet?
A: No. The Uphold/Withdraw buttons only appear after the assessor has entered marks.

### Q: What's the difference between Uphold and Approve?
A: They mean the same thing. "Uphold" is the term used in this system.

### Q: Can I see who moderated an exercise?
A: Yes, the moderator ID is tracked in the database. Future updates may display this in the UI.

## Troubleshooting

### Problem: Buttons don't appear
**Solution**: Check if marks have been entered by the assessor. Buttons only appear for marked exercises.

### Problem: Action doesn't save
**Solution**: 
1. Check your internet connection
2. Verify you're logged in as a moderator
3. Check the browser console for errors
4. Contact system administrator

### Problem: Can't see moderation status
**Solution**: Refresh the page or navigate away and back to the POE tab.

## Best Practices

1. **Review Thoroughly**: Check all evidence before moderating
2. **Be Consistent**: Apply the same standards to all learners
3. **Document Decisions**: Always add comments for withdrawals
4. **Communicate**: Discuss concerns with assessors
5. **Track Progress**: Keep notes on moderation patterns

## Support

For technical issues or questions:
- Contact your system administrator
- Refer to the full implementation documentation
- Check the test files for API examples

## Version
Version 1.0 - Initial Implementation
