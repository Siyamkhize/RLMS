# Quick Test Guide - ARPL Toolkit Access

**Date:** July 8, 2026  
**Feature:** Navigation to ARPL Toolkit Viewer  
**Build:** app-debug.apk (installed)

---

## 🎯 What to Test

The "View Complete Toolkit" button now appears after successfully saving an Appendix H recommendation.

---

## 📋 Test Steps

### Test 1: Happy Path - View Toolkit

1. **Open app** on device
2. **Login** as facilitator
3. **Navigate:** Main Menu → ARPL Assessor → Appendix H
4. **Select learner:** Choose **learner 20286** from dropdown
5. **Fill form:**
   - Select recommendation status (Competent/Gap Closure/RPL)
   - Optionally add remarks
6. **Tap "Save Recommendation"**
7. **✅ VERIFY:** Success dialog appears with:
   ```
   ✓ Recommendation Saved
   
   Appendix H recommendation saved successfully!
   
   Would you like to view the complete ARPL 
   toolkit with all saved assessments?
   
   [Later]  [View Complete Toolkit]
   ```
8. **Tap "View Complete Toolkit"**
9. **✅ VERIFY:** Navigates to toolkit viewer page
10. **✅ VERIFY:** Shows 5 tabs at top:
    - Cover
    - Appendix B
    - Appendix D
    - Appendix E
    - Appendix H
11. **✅ VERIFY:** Cover tab shows:
    - Learner name and details
    - Green/red status indicators
    - Professional card layout
12. **Test navigation:**
    - Tap each tab
    - Verify data loads correctly
    - Check green checkmarks (✓) for saved items
13. **Tap back button**
14. **✅ VERIFY:** Returns to previous page

---

### Test 2: "Later" Button

1. Follow steps 1-7 above
2. **Tap "Later"** button
3. **✅ VERIFY:** Dialog closes
4. **✅ VERIFY:** Stays on Appendix H page (doesn't navigate)

---

## 📊 Expected Results

### Cover Tab Should Show:
```
══════════════════════════════════════
    ARPL TOOLKIT - ELECTRICIAN
══════════════════════════════════════

Candidate Information
┌─────────────────────────────────────┐
│ Name: [Learner Name]                │
│ ID Number: [ID]                     │
│ Class: [Class Name]                 │
│ Trade: Electrician                  │
│ OFO Code: 671101                    │
└─────────────────────────────────────┘

Assessment Progress
┌─────────────────────────────────────┐
│ ✓ Appendix B: Theory Assessment     │
│ ✓ Appendix D: Practical Assessment  │
│ ✓ Appendix E: Competency Scale      │
│ ✓ Appendix H: Recommendation        │
└─────────────────────────────────────┘
```

### Appendix B Tab Should Show:
- List of 15 activities
- Each activity shows:
  - Activity name
  - Rating level (if saved)
  - Green checkmark if rated
  - Comments (in green italic text)

### Appendix D Tab Should Show:
- List of 8 practical activities
- Similar format to Appendix B
- Ratings and comments

### Appendix E Tab Should Show:
- Competency scale ratings
- Rating levels (1-5 scale)
- Comments for each competency

### Appendix H Tab Should Show:
- Recommendation status
- Date saved
- Assessor details
- Additional remarks

---

## 🐛 What Could Go Wrong

### Issue 1: Dialog Doesn't Appear
**Symptom:** Old SnackBar shows instead of dialog  
**Cause:** Old APK still installed  
**Fix:** Uninstall app, reinstall APK

### Issue 2: Navigation Fails
**Symptom:** Button tap does nothing  
**Cause:** Missing learner/class ID  
**Fix:** Verify learner 20286 is selected

### Issue 3: Toolkit Shows No Data
**Symptom:** Tabs are empty  
**Cause:** No saved data for selected learner  
**Fix:** Use learner 20286 (has complete data)

### Issue 4: API Error
**Symptom:** Error message when loading toolkit  
**Cause:** Backend API not accessible  
**Fix:** Verify API endpoint is reachable:
```
http://192.168.0.57:8080/assessorReport2/mobile/get_arpl_toolkit_data.php
```

---

## 🎨 Visual Checklist

When viewing the toolkit, verify:

- [ ] Green checkmarks (✓) for saved items
- [ ] Red crosses (✗) for "No" responses
- [ ] Professional card-style layout
- [ ] RLMS green color (#006341) for headers
- [ ] Scrollable content if data exceeds screen
- [ ] Tab navigation works smoothly
- [ ] Back button returns to previous page

---

## 📱 Device Information

**Connected Device:** adb-RZ8X306F7TZ-mKvVzH  
**APK Location:** `C:\projects\rlmss\build\app\outputs\flutter-apk\app-debug.apk`  
**Installation Status:** ✅ Installed

---

## 🔄 Quick Reinstall (If Needed)

```bash
# From project root
cd C:\projects\rlmss

# Reinstall APK
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

---

## ✅ Test Completion Checklist

After testing, confirm:

- [ ] Dialog appears after saving Appendix H
- [ ] "View Complete Toolkit" button works
- [ ] "Later" button closes dialog
- [ ] Toolkit viewer loads all data
- [ ] All 5 tabs are accessible
- [ ] Green checkmarks show for saved items
- [ ] Back button returns to previous page
- [ ] No crashes or errors
- [ ] Professional visual appearance

---

## 📞 Test Data Reference

**Test Learner:**
- **ID:** 20286
- **Class ID:** 1
- **OFO Code:** 671101
- **Trade:** Electrician
- **Status:** Has complete saved data in all appendices

**API Endpoint:**
```
http://192.168.0.57:8080/assessorReport2/mobile/get_arpl_toolkit_data.php
```

**Test Parameters:**
```json
{
  "learnerID": 20286,
  "classID": 1,
  "ofoNumber": "671101"
}
```

---

## 🎉 Success Criteria

**Test passes if:**
1. ✅ Dialog appears with toolkit button
2. ✅ Button navigates to toolkit viewer
3. ✅ All 5 tabs load correctly
4. ✅ Data displays with proper formatting
5. ✅ No crashes or errors

---

**Ready to Test!** 🚀

Open the app and follow the test steps above.

---
