# Offline Functionality Test Guide

## ✅ All Features Work Offline

All the new features work completely offline because they use client-side logic and local database:

### 1. Gender Auto-Population - ✅ OFFLINE
- **How it works**: Mathematical calculation from ID number
- **No server needed**: Pure client-side logic
- **Test**: Turn off WiFi, enter ID, gender auto-fills

### 2. Bank Code Auto-Fill - ✅ OFFLINE
- **How it works**: Uses local `_bankCodes` map stored in Flutter app
- **No server needed**: All bank codes stored locally
- **Test**: Turn off WiFi, select bank, code auto-fills

### 3. Account Type Dropdown - ✅ OFFLINE
- **How it works**: Uses local `_accountTypes` list stored in Flutter app
- **No server needed**: All account types stored locally
- **Test**: Turn off WiFi, dropdown shows all 9 options

### 4. Duplicate Check - ✅ OFFLINE
- **How it works**: Queries local SQLite database via `DatabaseHelper().checkLearnerExistsInProject()`
- **No server needed**: Checks local database only
- **Test**: Turn off WiFi, enter duplicate ID, dialog appears

### 5. Form Pre-fill on Update - ✅ OFFLINE
- **How it works**: Retrieves data from local SQLite database
- **No server needed**: All learner data stored locally
- **Test**: Turn off WiFi, enter existing ID, form pre-fills

---

## Offline Testing Steps

### Test 1: Gender Auto-Population (Offline)
1. **Turn off WiFi/Mobile Data**
2. Open Add Learner page
3. Enter ID: `9001015800089`
4. **Expected**: Gender dropdown shows "Male" ✅
5. Clear and enter: `9001014800088`
6. **Expected**: Gender dropdown shows "Female" ✅

### Test 2: Bank Code Auto-Fill (Offline)
1. **Keep WiFi/Mobile Data OFF**
2. Scroll to Banking Details
3. Select "ABSA Bank" from dropdown
4. **Expected**: Branch Code shows `632005` ✅
5. Select "Standard Bank"
6. **Expected**: Branch Code changes to `051001` ✅
7. **Expected**: Branch Code field is grey (read-only) ✅

### Test 3: Account Type Dropdown (Offline)
1. **Keep WiFi/Mobile Data OFF**
2. Click "Account Type" dropdown
3. **Expected**: Shows all 9 options ✅
   - Savings, Cheque, Current, Transmission
   - Fixed Deposit, Money Market, Student
   - Business, Trust

### Test 4: Duplicate Check (Offline)
1. **Keep WiFi/Mobile Data OFF**
2. First, add a learner with ID `1234567890123`
3. Submit (saves to local database)
4. Try to add another learner with same ID
5. **Expected**: Dialog appears immediately ✅
6. **Expected**: Shows existing learner name and details ✅

### Test 5: Form Pre-fill (Offline)
1. **Keep WiFi/Mobile Data OFF**
2. Enter ID of existing learner
3. Dialog appears: "Learner Already Exists"
4. Click "Yes, Update"
5. **Expected**: Form pre-fills with ALL existing data ✅
   - Name, Surname, Contact, Address
   - School details, Next of kin
   - Bank details (if any)

### Test 6: Save Learner (Offline)
1. **Keep WiFi/Mobile Data OFF**
2. Fill in all learner details
3. Submit form
4. **Expected**: Success message ✅
5. **Expected**: Message says "saved locally" or "will sync when online" ✅
6. **Expected**: Learner appears in learner list ✅

### Test 7: Sync When Back Online
1. **Turn WiFi/Mobile Data back ON**
2. Open learner list or trigger sync
3. **Expected**: Offline learners sync to server ✅
4. **Expected**: Success message ✅

---

## Why Everything Works Offline

### Client-Side Features (No Server Required):
```
✅ Gender Extraction
   └─ JavaScript/Dart calculation
   └─ ID substring(6, 10) < 5000 ? Female : Male

✅ Bank Code Mapping
   └─ Local Map in Flutter
   └─ _bankCodes['ABSA Bank'] = '632005'

✅ Account Types
   └─ Local List in Flutter
   └─ ['Savings', 'Cheque', 'Current', ...]

✅ Duplicate Check
   └─ Local SQLite Query
   └─ SELECT * FROM learnerdetails WHERE IDNumber = ? AND project_id = ?

✅ Form Pre-fill
   └─ Local SQLite Query
   └─ SELECT * FROM learnerdetails WHERE LearnerID = ?
```

### Server-Side Features (Require Internet):
```
❌ Initial Data Sync (downloading existing learners)
❌ Uploading new learners to server
❌ Syncing updates to server

✅ BUT: All saved locally first, synced later when online
```

---

## Offline Indicators

The app already shows offline status in various ways:
- SnackBar messages: "Saved locally, will sync when online"
- Sync button shows pending sync count
- Console logs show offline operations

---

## Data Flow

### Online Mode:
```
User enters data
  ↓
Gender/Bank auto-fill (client-side) ✅
  ↓
Duplicate check (local DB) ✅
  ↓
Save to local DB ✅
  ↓
Sync to server ✅
  ↓
Mark as synced ✅
```

### Offline Mode:
```
User enters data
  ↓
Gender/Bank auto-fill (client-side) ✅
  ↓
Duplicate check (local DB) ✅
  ↓
Save to local DB ✅
  ↓
Mark as unsynced (synced=0) ✅
  ↓
[Wait for internet]
  ↓
Auto-sync when online ✅
```

---

## Verification Checklist

Test offline functionality:
- [ ] Gender auto-fills when ID entered (offline)
- [ ] Bank code auto-fills when bank selected (offline)
- [ ] Account type dropdown works (offline)
- [ ] Duplicate check works (offline)
- [ ] Form pre-fills for existing learner (offline)
- [ ] Can save new learner (offline)
- [ ] Learner appears in list (offline)
- [ ] Data syncs when back online

---

## Technical Details

### Local Storage:
- **SQLite Database**: Stores all learner data
- **Flutter App Memory**: Stores bank codes, account types
- **No Cache Expiry**: Data persists indefinitely

### Sync Mechanism:
- **Smart Sync**: Only syncs unsynced records (synced=0)
- **Bidirectional**: Syncs from server and to server
- **Conflict Resolution**: Server data takes precedence
- **Retry Logic**: Auto-retries failed syncs

### Database Tables:
```sql
-- Learner data
learnerdetails (synced=0 when offline)

-- Bank data
bankdetails (synced=0 when offline)

-- Project/Class data (for duplicate check)
class, sites, project
```

---

## Common Questions

**Q: Do I need internet to use these features?**
A: No! All features work completely offline.

**Q: What happens to data saved offline?**
A: Saved to local database, automatically syncs when online.

**Q: Can I check for duplicates offline?**
A: Yes! Checks local database for duplicates in same project.

**Q: Do bank codes work offline?**
A: Yes! All bank codes stored in the app.

**Q: Can I update existing learners offline?**
A: Yes! Updates local database, syncs to server when online.

**Q: How long can I work offline?**
A: Indefinitely! Data persists until synced.

**Q: What if I add same learner on two devices offline?**
A: Server will detect duplicate when syncing and handle appropriately.

---

## Status: ✅ FULLY OFFLINE CAPABLE

All new features work completely offline with automatic sync when online!
