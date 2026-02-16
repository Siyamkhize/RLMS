# Deploy Pothole Per-Unit-Standard Moderation

## Quick Deployment Guide

### What Changed
The pothole checklist moderation now allows moderators to:
- **Uphold or Withdraw each unit standard (13958 and 14555) separately**
- **Add ONE shared moderator comment** that applies to all unit standards

### Files Modified
1. `lib/ModeratorPage.dart` - Updated UI and added new methods

### Backend Files (No Changes Required)
- `moderate_marks.php` - Already supports the required functionality
- `logbook_marks` table - Already has moderation columns

### Deployment Steps

#### 1. Build the App
```bash
flutter clean
flutter pub get
flutter build apk --release
```

#### 2. Test Before Deployment
- Open the app in debug mode
- Navigate to Moderator Dashboard
- Select a class and learner with pothole checklist
- Verify:
  - Each unit standard shows separate dropdown
  - Selecting "Uphold" or "Withdraw" saves immediately
  - Shared comment field appears at the end
  - "Save Comment" button updates all unit standards
  - Status displays correctly with color coding

#### 3. Deploy to Production
- Copy the APK to your distribution location
- Install on moderator devices
- Notify moderators of the new feature

### User Instructions for Moderators

**New Workflow:**
1. Open learner's POE details
2. Scroll to "Pothole Checklist" section
3. For each unit standard (13958 and 14555):
   - Review the marks and assessor comments
   - Select "Uphold" or "Withdraw" from the dropdown
   - Decision saves automatically
4. Add your moderator comments in the shared field at the bottom
5. Click "Save Comment" to apply to all unit standards

**Key Points:**
- Each unit standard can have a different decision (one upheld, one withdrawn)
- The comment field is shared - it applies to both unit standards
- You can change decisions and update comments at any time
- Green = Upheld, Red = Withdrawn

### Verification

After deployment, verify:
- [ ] Moderators can see separate dropdowns for each unit standard
- [ ] Selecting a decision saves immediately
- [ ] Shared comment field is visible
- [ ] Saving comment updates all unit standards
- [ ] Status displays correctly
- [ ] Database records are updated correctly

### Database Verification Query

```sql
-- Check moderation status for a learner's pothole checklist
SELECT 
    learner_id,
    unit_standard_id,
    marks,
    moderator_status,
    moderator_comment,
    moderator_id,
    moderation_date
FROM logbook_marks
WHERE learner_id = 'LEARNER_ID_HERE'
AND unit_standard_id IN ('13958', '14555')
ORDER BY unit_standard_id;
```

### Rollback Plan

If issues occur:
1. Revert to previous APK version
2. The database changes are backward compatible
3. Old app version will still work with existing data

### Support

If moderators report issues:
1. Check network connectivity
2. Verify `moderate_marks.php` is accessible
3. Check database for moderation columns
4. Review app logs for error messages

## Status
✅ Ready for deployment
