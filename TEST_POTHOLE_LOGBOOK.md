# Testing Pothole Checklist LogBook Unit Standards

## Quick Test Steps

### 1. Test the API Endpoint

Upload `test_pothole_logbook.php` to your server and access it:

```
https://rlms.rlms.co.za/mobile/test_pothole_logbook.php?learner_id=YOUR_LEARNER_ID
```

**What to check:**
- ✅ Should show 2 unit standards (14336 and 9968) if learner has logbook
- ✅ Database table `logbook_marks` should exist
- ✅ API returns status 'success'

### 2. Test in Flutter App

1. **Open the app** and navigate to Pothole Checklist
2. **Select a learner** who has logbook unit standards
3. **Scroll down** past the assessment criteria section
4. **Look for the orange "LogBook" card**

### 3. Test Collapsible Behavior

**Main LogBook Section:**
- Tap the "LogBook" header (orange card with book icon)
- Should expand to show unit standards
- Tap again to collapse

**Individual Unit Standards:**
- Tap "14336 - Maintain records on a construction site"
- Should expand to show mark input field
- Tap "9968 - Procure materials, tools and equipment"
- Should expand to show mark input field

### 4. Test Marking

1. **Expand a unit standard**
2. **Enter a mark** (0-100) in the input field
3. **Repeat for other unit standards**
4. **Save the checklist** using the "Save Checklist" button
5. **Check the test page** to verify marks were saved

### 5. Test View Mode

1. **Open an existing checklist** (one that's already saved)
2. **LogBook section should load** with previously saved marks
3. **In view mode**, input fields should be read-only
4. **Click "Edit Checklist"** to enable editing

## Expected Behavior

### Visual Design
```
┌─────────────────────────────────────┐
│ 📖 LogBook                      ▼   │  ← Tap to expand/collapse
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ 14336 - Maintain records...  ▼ │ │  ← Tap to expand
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 9968 - Procure materials...   ▼ │ │  ← Tap to expand
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### When Expanded
```
┌─────────────────────────────────────┐
│ 📖 LogBook                      ▲   │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ 14336 - Maintain records...  ▲ │ │
│ │                                 │ │
│ │ ⭐ Mark (0-100): [____]         │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 9968 - Procure materials...   ▼ │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

## Troubleshooting

### LogBook Section Not Showing

**Possible causes:**
1. Learner has no logbook unit standards
2. API endpoint not returning data
3. Network error

**Check:**
```
https://rlms.rlms.co.za/mobile/get_logbook_unit_standards.php?learner_id=YOUR_ID
```

Should return:
```json
{
  "status": "success",
  "data": [
    {
      "unit_standard_id": "14336",
      "unit_standard_name": "Maintain records on a construction site",
      "unit_standard_number": "14336"
    },
    {
      "unit_standard_id": "9968",
      "unit_standard_name": "Procure materials, tools and equipment",
      "unit_standard_number": "9968"
    }
  ]
}
```

### Marks Not Saving

**Check:**
1. Database table exists: `logbook_marks`
2. API endpoint accessible: `save_logbook_marks.php`
3. Check Flutter console for errors
4. Verify marks are between 0-100

**Test manually:**
```bash
curl -X POST https://rlms.rlms.co.za/mobile/save_logbook_marks.php \
  -H "Content-Type: application/json" \
  -d '{
    "learner_id": "YOUR_ID",
    "assessor_id": "ASSESSOR_ID",
    "assessment_date": "2025-11-07",
    "unit_standards_marks": [
      {"unit_standard_id": "14336", "marks": 85},
      {"unit_standard_id": "9968", "marks": 90}
    ]
  }'
```

### Marks Not Loading

**Check:**
```
https://rlms.rlms.co.za/mobile/get_logbook_marks.php?learner_id=YOUR_ID&assessor_id=ASSESSOR_ID&assessment_date=2025-11-07
```

Should return:
```json
{
  "status": "success",
  "data": {
    "14336": 85,
    "9968": 90
  }
}
```

## Database Verification

Run this SQL to check saved marks:

```sql
SELECT * FROM logbook_marks 
WHERE learner_id = 'YOUR_LEARNER_ID' 
ORDER BY created_at DESC;
```

## Success Criteria

✅ LogBook section appears in orange card
✅ Can expand/collapse main LogBook section
✅ Can expand/collapse individual unit standards
✅ Can enter marks (0-100) for each unit standard
✅ Marks save successfully when checklist is saved
✅ Marks load correctly when viewing existing checklist
✅ View mode disables mark input fields
✅ Edit mode enables mark input fields

## Test Checklist

- [ ] Upload test_pothole_logbook.php to server
- [ ] Access test page with learner ID
- [ ] Verify 2 unit standards are returned
- [ ] Verify database table exists
- [ ] Open Flutter app
- [ ] Navigate to Pothole Checklist
- [ ] Verify LogBook section appears
- [ ] Test expand/collapse main section
- [ ] Test expand/collapse unit standards
- [ ] Enter marks for both unit standards
- [ ] Save checklist
- [ ] Verify marks saved in database
- [ ] Reload checklist
- [ ] Verify marks loaded correctly
- [ ] Test view mode (read-only)
- [ ] Test edit mode (editable)

## Notes

- Only learners with logbook unit standards will see this section
- The section is hidden if no unit standards are found
- Marks are validated to be between 0-100
- Marks are saved when the main checklist is saved
- The design matches the reference image with collapsible accordion style

## Status

🎉 **READY FOR TESTING**

Run the test file and follow the steps above to verify everything works correctly!
