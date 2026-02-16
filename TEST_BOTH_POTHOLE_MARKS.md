# Test Guide: Both Pothole Marks Display

## Quick Test Steps

### 1. Verify Database Has Both Unit Standards
```sql
SELECT 
    learner_id,
    unit_standard_id,
    marks,
    moderator_status,
    assessor_comment
FROM logbook_marks 
WHERE learner_id = '1233' 
  AND unit_standard_id IN ('13958', '14555')
ORDER BY unit_standard_id ASC;
```

**Expected Result:**
```
learner_id | unit_standard_id | marks | moderator_status | assessor_comment
-----------|------------------|-------|------------------|------------------
1233       | 13958            | 43    | NULL             | Check all
1233       | 14555            | 49    | NULL             | NULL
```

### 2. Test Backend API
```bash
curl "http://your-server/php/view_pothole_checklists.php?learner_id=1233"
```

**Expected Response:**
```json
{
  "status": "success",
  "data": {
    "id": "...",
    "type": "scanned",
    "learner_id": "1233",
    "unit_standards": [
      {
        "unit_standard_id": "13958",
        "marks": 43,
        "moderator_status": "",
        "moderator_comment": "",
        "assessor_comment": "Check all"
      },
      {
        "unit_standard_id": "14555",
        "marks": 49,
        "moderator_status": "",
        "moderator_comment": "",
        "assessor_comment": ""
      }
    ]
  }
}
```

### 3. Test Frontend Display

**Steps:**
1. Open the app
2. Login as moderator
3. Navigate to: Moderator Dashboard → Classes → Select Class → View Learner
4. Go to "POE Details" tab
5. Scroll to "Pothole Checklist" section
6. Expand the section

**Expected Display:**
```
Pothole Checklist
├─ Scanned Document
│  └─ 2 Unit Standard(s) marked
│
├─ [Card] Unit Standard: 13958
│  ├─ Marks: 43 / 100
│  ├─ [Blue Box] Assessor Comment: Check all
│  └─ (No moderation status yet)
│
└─ [Card] Unit Standard: 14555
   ├─ Marks: 49 / 100
   └─ (No assessor comment)
```

### 4. Test Moderation Actions

**Steps:**
1. In the Pothole Checklist section
2. Click "Uphold" or "Withdraw" button
3. Enter moderation comment
4. Submit

**Expected:**
- Moderation should apply to ALL unit standards
- Both unit standards should show the same moderation status
- Refresh the page to verify status persists

## Test Cases

### Test Case 1: Both Unit Standards Present
- **Setup:** Learner 1233 has marks for both 13958 and 14555
- **Expected:** 2 separate cards displayed
- **Status:** ✅ Should work with the fix

### Test Case 2: Only One Unit Standard
- **Setup:** Learner has marks for only 13958
- **Expected:** 1 card displayed
- **Status:** ✅ Should work (backward compatible)

### Test Case 3: No Marks Yet
- **Setup:** Learner has no marks in logbook_marks table
- **Expected:** "Tap to view" message, no marks displayed
- **Status:** ✅ Should work

### Test Case 4: Scanned Document Type
- **Setup:** Checklist type is "scanned"
- **Expected:** Both unit standards displayed with marks
- **Status:** ✅ Should work

### Test Case 5: System Generated Type
- **Setup:** Checklist type is "system"
- **Expected:** Both unit standards displayed with marks
- **Status:** ✅ Should work

## Verification Checklist

- [ ] Database query returns 2 rows for learner 1233
- [ ] API response contains `unit_standards` array with 2 items
- [ ] Frontend displays "2 Unit Standard(s) marked"
- [ ] Frontend shows 2 separate cards
- [ ] Card 1 shows "Unit Standard: 13958" with marks 43
- [ ] Card 2 shows "Unit Standard: 14555" with marks 49
- [ ] Assessor comments display correctly
- [ ] Moderator status displays correctly (if moderated)
- [ ] No errors in console/logs
- [ ] App doesn't crash when viewing pothole checklist

## Common Issues

### Issue 1: Only One Unit Standard Shows
**Cause:** Database only has one unit standard marked
**Solution:** Assessor needs to mark both unit standards

### Issue 2: API Returns Empty Array
**Cause:** No marks in database for this learner
**Solution:** Assessor needs to mark the pothole checklist first

### Issue 3: Frontend Shows Old Format
**Cause:** App cache or old code
**Solution:** 
- Clear app cache
- Rebuild the app
- Force refresh

## Debug Commands

### Check API Response
```bash
# Test with curl
curl -v "http://your-server/php/view_pothole_checklists.php?learner_id=1233"

# Or use browser
http://your-server/php/view_pothole_checklists.php?learner_id=1233
```

### Check Flutter Logs
```dart
// Add this in _buildPotholeChecklistContent()
print('Unit Standards: ${data?['unit_standards']}');
print('Unit Standards Count: ${data?['unit_standards']?.length}');
```

### Check Database
```sql
-- Count unit standards per learner
SELECT 
    learner_id,
    COUNT(*) as unit_standard_count
FROM logbook_marks 
WHERE unit_standard_id IN ('13958', '14555')
GROUP BY learner_id;
```

## Success Criteria

✅ **Backend:** Returns array with 2 unit standards
✅ **Frontend:** Displays 2 separate cards
✅ **Data:** Each card shows correct marks and comments
✅ **UI:** Clear visual separation between unit standards
✅ **Functionality:** Moderation actions work correctly

