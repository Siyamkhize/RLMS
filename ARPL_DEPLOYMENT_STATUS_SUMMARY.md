# ARPL DEPLOYMENT STATUS SUMMARY

**Date:** July 14, 2026  
**Status:** Partially Deployed - Backend Fix Required  
**Issue:** ARPL assessors seeing normal assessor UI

---

## CURRENT STATUS

| Component | Status | Details |
|-----------|--------|---------|
| Flutter App | ✅ DEPLOYED | APK built, installed, online server configured |
| Backend PHP Files | ⏳ PENDING | 58 files need upload to `/mobile/` |
| Database Setup | ⏳ PENDING | 13 SQL files need execution (26 tables) |
| **CRITICAL FIX** | 🚨 REQUIRED | `mobile/get_classes.php` pathway field missing |
| OFO Codes | ✅ FIXED | 671101, 641201, 642601 correct throughout |

---

## WHAT'S WORKING

✅ App successfully connects to online server (https://rlms.rlms.co.za)  
✅ Login works without 404 errors  
✅ Server is accessible and responding  
✅ Flask/PHP infrastructure working  

---

## WHAT'S NOT WORKING

❌ ARPL assessors seeing normal assessor menu instead of ARPL menu  
❌ ARPL Toolkit not visible  
❌ Appendices (A-H) not showing  

---

## ROOT CAUSE

**File:** `mobile/get_classes.php` on online server  
**Issue:** Query not including `Project_pathway` field in response  
**Impact:** App cannot detect ARPL pathway type, defaults to normal assessor UI  

---

## THE IMMEDIATE FIX

### Must Deploy to Online Server Today:

**File:** `/mobile/get_classes.php`  
**Change:** Add `s.Project_pathway` to SELECT query

**Current (Wrong):**
```php
SELECT s.project_id, c.* 
FROM class c
JOIN sites s ON s.siteID = c.siteID
```

**Should Be:**
```php
SELECT s.project_id, s.Project_pathway, c.* 
FROM class c
JOIN sites s ON s.siteID = c.siteID
```

See: `URGENT_ONLINE_SERVER_FIX_REQUIRED.md` for complete fix

---

## DEPLOYMENT ROADMAP

### Phase 1: Quick Fix (TODAY - BLOCKING)
- [ ] Update `mobile/get_classes.php` on online server
- [ ] Test endpoint returns `Project_pathway`
- [ ] Retest ARPL assessor login
- [ ] Verify ARPL menu appears

### Phase 2: Backend Deployment (PLANNED)
- [ ] Upload 58 PHP endpoints to `/mobile/`
- [ ] Execute 13 SQL files (creates 26 tables)
- [ ] Verify all endpoints working

### Phase 3: Full Testing (AFTER Phase 2)
- [ ] Test complete ARPL workflow
- [ ] Verify PDF generation
- [ ] Test all appendices
- [ ] Confirm question display

---

## FILES AND TABLES NEEDED

### PHP Endpoints (58 Files)
```
GET (16):      get_arpl_*.php endpoints
SAVE (17):     save_arpl_*.php endpoints  
UTILITY (8):   check_arpl_*.php endpoints
WEB/API (17):  api/, web/ endpoints
```

See: `ARPL_DEPLOYMENT_FILE_LIST.txt`

### Database Tables (26 Total)
```
Core (4):           arpl_poe, arpl_papers, arpl_questions, arpl_trades
Competency (7):     activities & ratings for electrician, bricklayer, plumber
Assessment (7):     appendices C, D, G, I + trade recommendations
Application (4):    applications, experience, references, qualifications
Gap Analysis (4):   submissions, items, reports, tasks
```

See: `ARPL_DEPLOYMENT_CHECKLIST.md`

---

## TESTING STATUS

### What Was Tested
✅ Login to online server  
✅ Server connectivity  
✅ No 404 errors on login  

### What Needs Testing
❌ ARPL assessor receives ARPL menu  
❌ ARPL Toolkit loads  
❌ Appendices save correctly  
❌ PDF generation works  
❌ Questions display from database  

---

## CORRECT OFO CODES (VERIFIED)

| Trade | Code | Status |
|-------|------|--------|
| Electrician | 671101 | ✅ Correct |
| Bricklayer | 641201 | ✅ Correct |
| Plumber | 642601 | ✅ Correct |

All fixes from previous sessions are correct and in place.

---

## NEXT DEVELOPER TASKS

### Task 1: CRITICAL (Do First)
**Update `mobile/get_classes.php` on online server**
- Add `s.Project_pathway` to SELECT
- Test: curl endpoint and verify response
- Clear app cache and retest login
- **Expected:** ARPL menu appears

### Task 2: HIGH PRIORITY (Do Second)  
**Deploy remaining PHP endpoints**
- Upload 58 files to `/mobile/`
- Verify permissions (755/644)
- Test diagnostic endpoints

### Task 3: HIGH PRIORITY (Do Third)
**Create 26 database tables**
- Execute 13 SQL files in order
- Verify all tables created
- Check OFO codes are correct

### Task 4: FULL TESTING (After Tasks 1-3)
- Complete ARPL workflow
- Test all appendices
- Verify PDF generation
- Check data persistence

---

## DEPLOYMENT GUIDES CREATED

| Document | Purpose |
|----------|---------|
| `ARPL_ONLINE_DEPLOYMENT_SUMMARY.md` | Complete deployment overview |
| `ARPL_DEPLOYMENT_FILE_LIST.txt` | Exact file list with deployment locations |
| `URGENT_ONLINE_SERVER_FIX_REQUIRED.md` | CRITICAL FIX needed immediately |
| `ARPL_ASSESSOR_UI_FIX.md` | Detailed explanation of UI issue & solution |
| `ARPL_DEPLOYMENT_CHECKLIST.md` | Original deployment guide |
| `APK_BUILD_AND_INSTALLATION_COMPLETE.md` | APK build status |

---

## DEPLOYMENT TIMELINE

| Date | Time | Event |
|------|------|-------|
| 2026-07-14 | 11:55 AM | APK built & installed |
| 2026-07-14 | 12:00 PM | Tested login - ARPL menu missing |
| 2026-07-14 | 12:10 PM | Root cause identified |
| 2026-07-14 | 12:15 PM | Fix documented |
| 2026-07-14 | 12:20 PM | Awaiting online deployment |

---

## VERIFICATION COMMANDS

### Test API Endpoint
```bash
curl "https://rlms.rlms.co.za/mobile/get_classes.php?facilitator_id=123"
```

Should include: `"Project_pathway": "ARPL"`

### Clear App Cache
```bash
adb shell pm clear com.example.rlmss
```

### Test ARPL Login (After Fix)
1. Relogin with ARPL assessor credentials
2. Dashboard title should say "ARPL Dashboard"
3. Drawer menu should show ARPL items

---

## SUMMARY FOR HANDOFF

**Current Situation:**
- App is built and deployed
- Server is reachable
- Login works
- BUT: ARPL UI not showing because one API field is missing

**What's Needed:**
- ONE file update on online server: `mobile/get_classes.php`
- Add one SELECT field: `s.Project_pathway`
- That's it - then ARPL will work

**Effort:**
- 5 minutes to fix
- 2 minutes to test
- High impact fix

**Blockers:**
- None - can be fixed immediately

---

## RISK ASSESSMENT

| Risk | Likelihood | Severity | Mitigation |
|------|------------|----------|-----------|
| Fix breaks login | Low | High | Test with non-ARPL assessor first |
| Database down | Very Low | High | Have backup ready |
| Permissions wrong | Low | Medium | Verify file permissions after upload |

---

## SUCCESS CRITERIA

After deployment, these should be true:

- ✅ ARPL assessor login → ARPL Dashboard title
- ✅ Drawer menu shows ARPL-specific items
- ✅ Can navigate to ARPL Toolkit
- ✅ Can access all appendices
- ✅ Can save form data
- ✅ Can generate PDF with questions
- ✅ No 404 errors
- ✅ All trade data correct (671101, 641201, 642601)

---

## CONTACT/QUESTIONS

If issues arise:
1. Check `URGENT_ONLINE_SERVER_FIX_REQUIRED.md` for fix details
2. Review `ARPL_ASSESSOR_UI_FIX.md` for technical explanation
3. Test endpoint: `https://rlms.rlms.co.za/mobile/get_classes.php?facilitator_id=[ID]`
4. Verify response includes `Project_pathway` field

---

**Generated:** July 14, 2026  
**Status:** Ready for online server deployment  
**Next Step:** Apply CRITICAL FIX to `mobile/get_classes.php`

