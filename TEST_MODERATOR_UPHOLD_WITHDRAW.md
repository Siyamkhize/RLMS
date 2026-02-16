# Test Guide: Moderator Uphold/Withdraw Individual Exercises

## What Was Fixed
The "Uphold" and "Withdraw" buttons for individual mark records now correctly send the exercise question text to identify which record to update.

## Test Steps

### 1. Login as Moderator
- Use your moderator credentials to login

### 2. Navigate to Learner 1277
- Go to Classes → Select a class → Find learner 1277
- Click "View Marks" for learner 1277

### 3. Expand Assessment Sections
- Expand "Formative" or "Summative" sections
- You should see individual exercises like:
  - "Define a safe site"
  - "What are safety hazards?"
  - etc.

### 4. Test Individual Exercise Moderation
For each exercise card:

**Test Uphold:**
1. Expand an exercise card
2. Select "Uphold" from the "Moderation Decision" dropdown
3. Expected result: 
   - Success message: "Exercise uphold successfully!"
   - The exercise should show a green checkmark icon
   - The marks table should have `approval_status = 'Approved'` for that exercise

**Test Withdraw:**
1. Expand a different exercise card
2. Select "Withdraw" from the "Moderation Decision" dropdown
3. Expected result:
   - Success message: "Exercise withdrawn successfully!"
   - The exercise should disappear from the list (record deleted)
   - The associated PDF file should be deleted from the server

### 5. Verify Database Changes

**For Uphold:**
```sql
SELECT id, learnerID, exercise, approval_status 
FROM marks 
WHERE learnerID = '1277' AND exercise = 'Define a safe site';
```
Should show `approval_status = 'Approved'`

**For Withdraw:**
```sql
SELECT id, learnerID, exercise 
FROM marks 
WHERE learnerID = '1277' AND exercise = 'What are safety hazards?';
```
Should return no results (record deleted)

### 6. Check Debug Log
The PHP creates a `debug.log` file with detailed information:
```bash
tail -f debug.log
```

You should see entries like:
```
Before any operation for learnerID 1277: [{"id":"123","learnerID":"1277","exercise":"Define a safe site","approval_status":"Pending"}]
Rows updated: 1
After update for learnerID 1277: [{"id":"123","learnerID":"1277","exercise":"Define a safe site","approval_status":"Approved"}]
```

## Expected Behavior

### Uphold Action
- ✅ Record remains in database
- ✅ `approval_status` changes to 'Approved'
- ✅ Green checkmark icon appears
- ✅ Success message displayed

### Withdraw Action
- ✅ Record deleted from `marks` table
- ✅ Record deleted from `poe` table
- ✅ Associated PDF file deleted
- ✅ Exercise disappears from list
- ✅ Success message displayed

## Common Issues

### "No record found to update"
- **Cause:** Exercise name doesn't match exactly
- **Solution:** Check that the exercise text in the database matches what's being sent
- **Debug:** Check `debug.log` to see what's being searched for

### "Missing required parameters"
- **Cause:** One of learnerId, exerciseId, or moderation_status is missing
- **Solution:** Check browser console for the request payload
- **Debug:** Verify all three parameters are being sent

### Exercise still shows after Withdraw
- **Cause:** Deletion failed or page not refreshed
- **Solution:** Check database to confirm deletion, refresh the page
- **Debug:** Check `debug.log` for deletion confirmation

## Success Criteria
✅ Can uphold individual exercises
✅ Can withdraw individual exercises  
✅ Database updates correctly
✅ UI updates immediately
✅ No error messages
✅ Debug log shows correct operations

## Files Involved
- `lib/ModeratorPage.dart` - Flutter frontend
- `save_moderation_status.php` - PHP backend
- `marks` table - Stores mark records
- `poe` table - Stores POE file references
