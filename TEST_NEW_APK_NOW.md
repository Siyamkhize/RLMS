# 🧪 TEST NEW APK - Quick Checklist

**APK Status**: ✅ INSTALLED on your phone  
**What to Test**: ARPL upload with the fix applied

---

## Test Right Now (5 minutes)

### 1. Open App ✓
- Tap RLMSS app
- App should launch normally

### 2. Navigate to ARPL ✓
- Dashboard → ARPL (or direct menu)
- Select learner
- You should see trade selection screen

### 3. Upload Theory Paper ✓
- Select a trade/OFO (e.g., 9964)
- Click **Theory** section
- Select a paper
- Capture/scan PDF
- Click upload
- **Expected**: "✅ Uploaded" message (not error)

### 4. Check Database ✓
**Quick SQL Query**:
```sql
SELECT * FROM arpl_poe 
WHERE learnerID = [your_learner_id]
ORDER BY created_at DESC LIMIT 1;
```

**Look For**:
- ✓ ofo_number is populated (not NULL)
- ✓ paper_number is 1
- ✓ section_type is 'theory'
- ✓ question_count has a number
- ✓ upload_status is 'uploaded'

**If ALL filled** → ✅ FIX WORKS!

### 5. Try Practical Paper ✓
- Back in app
- Select trade
- Click **Practical** section
- Upload paper
- Check database for section_type = 'practical'

---

## If Testing Successful

### Next Steps:
1. Install APK on all other test devices
2. Test uploads on multiple devices
3. Verify ratings can be added
4. Deploy to production

### Command to Share APK:
```
Location: c:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk
Transfer to other devices and tap to install
```

---

## If Something Fails

### Upload Error Message?
- **Check**: Database connection working
- **Check**: Server at 192.168.0.57:8080 is accessible
- **Check**: PHP error log for errors

### Data Not in Database?
- **Check**: App actually sent data (network working?)
- **Check**: Database table exists: `SELECT * FROM arpl_poe LIMIT 1;`
- **Check**: learnerID valid: `SELECT * FROM learnerdetails WHERE LearnerID = [your_id];`

### Data in DB but NULL Fields?
- **Issue**: App still not sending all parameters
- **Solution**: Rebuild APK again (code change might not have been saved)

---

## Quick Verification

### Fastest Test:
```bash
# 1. Verify app installed
adb devices

# 2. Check logcat for app messages
adb logcat | grep -i arpl

# 3. Verify database
mysql -u root -p -e "SELECT * FROM arpl_poe LIMIT 1;" rlmsrlmsco_ezxcmacd_rlms
```

---

## Expected Behavior - After Fix

| Action | Before Fix | After Fix |
|--------|-----------|-----------|
| Upload theory | Fails or NULLs | ✅ Success |
| Database record | Incomplete | ✅ Complete |
| ofo_number | NULL | ✅ 9964 |
| paper_number | NULL | ✅ 1 |
| section_type | NULL | ✅ 'theory' |
| question_count | NULL | ✅ 15 |
| Frontend shows | ❌ No | ✅ Yes |

---

## Report Back With

Please test and let me know:
1. ✓ App launches?
2. ✓ Upload succeeds without error?
3. ✓ Data appears in database?
4. ✓ All 4 fields populated (ofo_number, paper_number, section_type, question_count)?
5. ✓ Theory paper shows 'theory' in section_type?
6. ✓ Practical paper shows 'practical' in section_type?

---

**Testing Status**: 🟢 READY - New APK installed and waiting for your test!
