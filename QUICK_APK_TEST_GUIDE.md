# 🚀 Quick APK Testing Guide - 5 Minutes to Verify

**Last Updated**: July 12, 2026

---

## ⚡ Quick Start (5 Steps)

### Step 1: Connect Device & Install APK (2 mins)
```bash
adb install -r "c:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk"
```

### Step 2: Launch App & Login (1 min)
- Open RLMSS app
- Username: `admin` (or test user)
- Password: (check credentials)
- Tap Login

### Step 3: Navigate to ARPL Assessor (1 min)
- Tap Dashboard
- Tap "Assessor"
- Tap "ARPL Assessment"

### Step 4: Select a Learner (1 min)
- Search for: `Lungisani Cele` or ID `16389`
- Tap to select
- Choose trade: `Electrician (671101)`

### Step 5: Verify Data Loads (1 min)
- ✅ Appendix A (Application) shows data
- ✅ Appendix B (Competency) shows scale
- ✅ All other appendices load
- ✅ No "404" or "Connection Error"

---

## 🔍 Verify Each Appendix (2 mins)

| Appendix | What to Check | Expected Result |
|----------|---------------|-----------------|
| A - Application | Name, ID, employment history | Data from database shows |
| B - Competency | Scale values (1-5) | Competency scale loads |
| C - Curriculum | Unit standards | List shows |
| D - Gap Analysis | Yes/No checkboxes | 22 items visible |
| E - Workplace Eval | Activity ratings | Ratings form loads |
| F - Practical Assess | Assessment form | Form fields appear |
| G - Assessment Agr | Agreement text | Text displays |
| H - Appeals | Appeal form | Form ready |
| I - Access Recommend | Recommendation form | Form loads |

---

## 💾 Test Data Saving (2 mins)

1. Go to Appendix B (Competency Scale)
2. Change a value
3. Tap "Save"
4. ✅ See "Success" message
5. ✅ Value persists (reload to verify)

---

## ⚠️ If Something Breaks

| Error | Quick Fix |
|-------|-----------|
| **404 Not Found** | Check server running: `python -m flask run` |
| **Connection refused** | Check IP: should be `192.168.0.57:8080` in `lib/config.dart` |
| **No data shown** | Verify learner ID 16389 exists in database |
| **Save fails** | Check app logs: `adb logcat -s flutter` |
| **App crashes** | Check logs: `adb logcat *:E` |

---

## 📊 Database Verification

All data should be saving to correct tables:

```bash
# Verify from database:
mysql -u root rlmsrlmsco_ezxcmacd_rlms

# Check if data exists:
SELECT * FROM arpl_appendix_c WHERE learnerID=16389;
SELECT * FROM arpl_appendix_d WHERE learnerID=16389;
SELECT * FROM arplelectrician_access_recommendation WHERE LearnerID=16389;
```

---

## ✅ Sign-Off Checklist

- [ ] APK installed successfully
- [ ] App launches without crashing
- [ ] Login works
- [ ] ARPL page loads
- [ ] Learner search works
- [ ] All 9 appendices show data
- [ ] Save function works
- [ ] Data appears in database

---

## 🎯 Success Criteria

✅ **PASS** if:
- App runs without crashes
- All appendices load
- Data saves to database
- No 404 errors
- Multi-trade support works (test with 641201, 642601)

❌ **FAIL** if:
- App crashes on ARPL page
- Appendices show "No data"
- Save returns error
- Database tables empty
- 404 errors on endpoints

---

**Status**: Ready to Test ✅  
**APK Location**: `c:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk`  
**Database**: `rlmsrlmsco_ezxcmacd_rlms`
