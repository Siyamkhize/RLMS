# Test Guide - Moderator PDF Viewer

## Quick Test Steps

### 1. Navigate to Scanned Document
1. Open the app as a Moderator
2. Go to Moderator Dashboard
3. Select a class
4. Select a learner who has a scanned pothole checklist
5. Tap "View Marks"
6. Go to "POE Details" tab
7. Expand "Pothole Checklist" section

### 2. Open PDF
1. You should see "Scanned Document" with a PDF icon
2. Tap on "Scanned Document"
3. **Expected:** PDF viewer page opens (not a dialog)
4. **Expected:** Loading indicator shows while downloading
5. **Expected:** PDF renders and displays

### 3. Test PDF Features
1. **Swipe up/down** to navigate pages
2. **Pinch to zoom** in and out
3. Check **page counter** updates as you navigate
4. Tap **"Open in external app"** icon (top right)
5. **Expected:** PDF opens in device's PDF app

### 4. Test Document Info
Verify the info card shows:
- ✅ Learner ID
- ✅ Assessment Date
- ✅ Total pages
- ✅ Current page number

### 5. Test Error Handling
1. Turn off WiFi/data
2. Try to open a PDF
3. **Expected:** Error message with "Retry" button
4. Turn on WiFi/data
5. Tap "Retry"
6. **Expected:** PDF loads successfully

## What Should Happen

### ✅ Success Indicators
- PDF viewer page opens (full screen)
- PDF content is visible and readable
- Can navigate through all pages
- Page counter updates correctly
- Can zoom in/out smoothly
- External app option works

### ❌ Failure Indicators
- Dialog shows instead of PDF viewer
- Blank screen or loading forever
- Error message appears immediately
- Cannot navigate pages
- PDF is corrupted or unreadable

## Common Issues and Solutions

### Issue: Dialog Shows Instead of PDF
**Cause:** Old code still in place
**Solution:** Rebuild the app completely

### Issue: PDF Not Loading
**Cause:** Incorrect URL construction
**Check:** Console logs for "DEBUG PDF:" messages
**Solution:** Verify document path format

### Issue: "Cannot open PDF"
**Cause:** Network issue or invalid URL
**Check:** 
- Internet connection
- Server is accessible
- Document path is correct

### Issue: Blank PDF Page
**Cause:** Corrupted PDF or wrong file type
**Check:** Try opening in external app
**Solution:** Re-scan the document

## Console Logs to Check

Look for these debug messages:
```
DEBUG: _viewPotholeChecklist called with type=scanned
DEBUG: Opening scanned PDF
DEBUG: Full PDF URL: https://...
DEBUG PDF: Downloading from https://...
DEBUG PDF: Downloaded to /data/...
```

If you see errors:
```
DEBUG PDF: Error downloading: [error details]
```

## Test Scenarios

### Scenario 1: Normal Flow
- Learner has scanned checklist
- Good internet connection
- PDF opens and displays correctly

### Scenario 2: Slow Connection
- Learner has scanned checklist
- Slow internet connection
- Loading indicator shows longer
- PDF eventually loads

### Scenario 3: No Connection
- Learner has scanned checklist
- No internet connection
- Error message appears
- Retry button available

### Scenario 4: Invalid Document
- Document path is wrong
- Error message appears
- Can go back to previous screen

## Comparison Test

### Before Fix
1. Tap on scanned document
2. Dialog appears with text info
3. No PDF viewing capability
4. Must close dialog

### After Fix
1. Tap on scanned document
2. PDF viewer page opens
3. Full PDF viewing capability
4. Can navigate, zoom, share

## Success Criteria

✅ PDF viewer opens (not dialog)
✅ PDF content is visible
✅ All pages are accessible
✅ Zoom works properly
✅ External app option works
✅ Error handling works
✅ Loading indicator shows
✅ Document info is correct

## Reporting Issues

If you find issues, provide:
1. Screenshot of the problem
2. Console logs (DEBUG messages)
3. Learner ID being tested
4. Document path from logs
5. Device and OS version
6. Network condition

## Expected Behavior Summary

| Action | Expected Result |
|--------|----------------|
| Tap scanned document | PDF viewer opens |
| PDF loads | Content visible |
| Swipe up/down | Navigate pages |
| Pinch zoom | Zoom in/out |
| Tap external app | Opens in PDF app |
| No internet | Error with retry |
| Invalid URL | Error message |
| Back button | Returns to POE tab |

## Status
✅ Ready for Testing

The PDF viewer is now fully functional and ready for user testing.
