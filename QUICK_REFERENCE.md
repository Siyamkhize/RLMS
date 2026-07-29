# Quick Reference Card
**Upload & Test - July 23, 2026**

---

## 📦 3 Files to Upload

```
1. mobile/get_arpl_hierarchy.php          → /public_html/mobile/
2. mobile/get_sick_note_eligible_dates.php → /public_html/mobile/
3. mobile/submit_sick_note.php            → /public_html/mobile/
```

---

## 📂 Directory to Create

```bash
mkdir -p /public_html/uploads/sick_notes
chmod 755 /public_html/uploads/sick_notes
```

---

## 🧪 Quick Tests

### Test 1: ARPL Hierarchy (Browser)
```
https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701
```
**Look for:** `"Bricklayer"` in qualifications (not "Electrician")

### Test 2: Sick Note Eligibility (cURL)
```bash
curl -X POST https://rlms.rlms.co.za/mobile/get_sick_note_eligible_dates.php -d "learner_id=11701"
```
**Look for:** `"status": "success"` and list of dates

### Test 3: Device ARPL Test
1. Login as ARPL Assessor
2. Click on Bricklayer class
3. Click on learner
4. **Verify:** Card shows "Bricklayer" not "Electrician"

### Test 4: Device Sick Note Test
1. Login as learner (ID: 11701)
2. Navigate to Sick Note page
3. Select a date from calendar
4. Upload PDF
5. **Verify:** Success message appears

---

## 🔍 Quick Checks

### Database Check (ARPL Trades)
```sql
SELECT * FROM arpl_trades;
```

### Database Check (Class Trade ID)
```sql
SELECT classID, className, trade_id FROM class WHERE classID = 797;
```

### Device Logs (ARPL)
```bash
adb logcat | findstr ARPL
```
**Look for:** `"From arpl_trades table - Trade: Bricklayer"`

---

## ⚠️ Critical Notes

- **Column names:** Use `LearnerID` (PascalCase) not `learner_id`
- **Date columns:** `clock_date` not `timestamp` or `date`
- **File permissions:** PHP=644, Directories=755
- **Clear cache:** May need to clear PHP opcache after upload

---

## 🎯 Expected Behavior

### ARPL Hierarchy:
- ✅ Shows dynamic trade from database
- ✅ Works for ALL trades (not just Electrician)
- ✅ Debug logs show correct trade name

### Sick Note:
- ✅ First-time learners rejected
- ✅ Last 5 working days calculated
- ✅ PDF upload saves to server
- ✅ Record in database with status='PENDING'

---

## 📖 Full Documentation

- **Detailed:** `SESSION_SUMMARY_JULY_23_2026.md`
- **Upload Guide:** `UPLOAD_INSTRUCTIONS.md`
- **Action Plan:** `NEXT_STEPS_ACTION_PLAN.md`

---

## 🚀 Ready to Go!

All files are ready for upload. See full documentation for detailed instructions.
