# Moderator Page - Quick Reference Guide

## What Changed?

The ModeratorPage now has **full viewing functionality** for LogBook and Pothole Checklist, matching the AssessorPage capabilities.

## LogBook Feature

### What It Does
- Shows all logbook entries for a learner
- Displays exercises organized by unit standard
- Shows marks scored for each exercise
- Visual indicators for marking status

### How to Use
1. Navigate to Moderator Dashboard
2. Select a class
3. Select a learner → "View Marks"
4. Go to "POE Details" tab
5. Expand "LogBook" section
6. Expand any unit standard to see exercises

### What You'll See
- 📘 Blue book icon for LogBook section
- Unit standard names as expandable items
- Exercise names with marks
- ✅ Green check = Marked
- ⏳ Orange pending = Not marked

## Pothole Checklist Feature

### What It Does
- Checks if learner has a pothole checklist
- Shows checklist type (scanned PDF or system form)
- Displays full checklist details
- Shows all checklist items with pass/fail status

### How to Use
1. Navigate to Moderator Dashboard
2. Select a class
3. Select a learner → "View Marks"
4. Go to "POE Details" tab
5. Expand "Pothole Checklist" section
6. Tap on the checklist to view details

### What You'll See
- 🔧 Orange construction icon for Pothole Checklist
- "Scanned Document" or "System Generated Form"
- Tap to open dialog with full details
- Checklist items with ✅ (pass) or ❌ (fail) icons
- Learner info, venue, and assessment date

## API Endpoints

### LogBook Data
```
GET get_poe.php?learnerId={learnerId}
```
Returns POE structure with logbook data

### Pothole Checklist
```
GET view_pothole_checklists.php?learner_id={learnerId}
```
Returns checklist status, type, and data

## Troubleshooting

### LogBook Not Showing
- Check if learner has POE data
- Verify `get_poe.php` endpoint is accessible
- Check browser console for errors
- Look for "No POE data found" message

### Pothole Checklist Not Showing
- Check if learner has completed pothole assessment
- Verify `view_pothole_checklists.php` endpoint is accessible
- Check server logs for errors
- Look for "No pothole checklist found" message

### Debug Logging
All debug messages are prefixed with:
- `[ModeratorPOETab]` for POE-related logs
- `DEBUG Pothole:` for checklist-related logs
- `DEBUG:` for view-related logs

## Key Differences from AssessorPage

| Feature | AssessorPage | ModeratorPage |
|---------|-------------|---------------|
| View LogBook | ✅ | ✅ |
| View Pothole Checklist | ✅ | ✅ |
| Submit Marks | ✅ | ❌ |
| Add Comments | ✅ | ❌ |
| Edit Marks | ✅ | ❌ |
| Full PDF Viewer | ✅ | ❌ |

Moderators can **view** all assessment data but cannot **modify** it.

## Testing Checklist

- [ ] LogBook displays for learners with entries
- [ ] LogBook shows "No data" for learners without entries
- [ ] Pothole checklist displays for learners with assessments
- [ ] Pothole checklist shows "Not found" for learners without assessments
- [ ] Scanned document info displays correctly
- [ ] System checklist displays correctly
- [ ] Loading indicators show during data fetch
- [ ] Error messages display when server is unreachable
- [ ] All icons and visual indicators work correctly

## Support

If you encounter issues:
1. Check browser console for error messages
2. Verify API endpoints are accessible
3. Check server logs for backend errors
4. Review debug logs in console
5. Verify learner has assessment data

## Status
✅ **Ready for Testing**

All functionality has been implemented and is ready for user testing.
