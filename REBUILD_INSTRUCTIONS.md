# Complete Rebuild Instructions

## The code IS in the file, but you need a FULL REBUILD!

All changes are present in `lib/AddLearnerPage.dart`:
- ✅ `_extractFromIdAndCheckDuplicate` method exists (line 273)
- ✅ Gender auto-population code: `_selectedGender = gender;` (line 304)
- ✅ ID field calls the method: `onChanged: _extractFromIdAndCheckDuplicate` (line 595)
- ✅ Bank code auto-fill: `_bankBranchCodeController.text = _bankCodes[value]!;` (line 653)

## CRITICAL: You MUST do these steps IN ORDER:

### Step 1: Stop Everything
```bash
# Stop the running app completely
# Press Ctrl+C in terminal or Stop button in IDE
```

### Step 2: Clean Build
```bash
flutter clean
```

### Step 3: Get Dependencies
```bash
flutter pub get
```

### Step 4: Rebuild and Run
```bash
flutter run
```

## Why Hot Reload Doesn't Work

Hot reload (pressing 'r') or hot restart (pressing 'R') will NOT work for these changes because:
1. We added new methods (`_extractFromIdAndCheckDuplicate`)
2. We added new state variables (`_isValidSAId`, `_bankCodes`, `_accountTypes`)
3. We changed widget structure (added `_buildTextFieldWithOnChanged`)

These require a FULL REBUILD from scratch.

## Test After Rebuild

### Test 1: Gender Auto-Population
1. Open Add Learner page
2. Type ID: `9001015800089` (Male - digits 7-10 = 5800)
3. **Expected**: Gender dropdown should show "Male" selected
4. Clear and type: `9001014800088` (Female - digits 7-10 = 4800)
5. **Expected**: Gender dropdown should show "Female" selected

### Test 2: Bank Code Auto-Fill
1. Scroll to Banking Details
2. Click "Bank Name" dropdown
3. Select "ABSA Bank"
4. **Expected**: Branch Code field shows `632005` and is grey (read-only)
5. Try "Standard Bank"
6. **Expected**: Branch Code changes to `051001`

### Test 3: Duplicate Check
1. Add a learner with ID `1234567890123`
2. Try to add another with same ID in same project
3. **Expected**: Dialog appears immediately after typing 13th digit

## If Still Not Working After Rebuild

### Check Console Output
When you type the ID number, you should see in console:
```
Gender set to: Male
```

### Add Debug Print
If you don't see the console output, add this line in `lib/AddLearnerPage.dart` at line 305:
```dart
_selectedGender = gender; // Auto-populate gender
_isValidSAId = true;
print('DEBUG: Gender set to: $gender, _selectedGender: $_selectedGender'); // ADD THIS LINE
```

Then rebuild and check console.

### Verify File Saved
Make sure the file is saved:
1. Check for unsaved indicator (dot) in IDE tab
2. Press Ctrl+S to save
3. Rebuild again

## Common Mistakes

❌ **DON'T**: Press 'r' or 'R' in terminal (hot reload won't work)
❌ **DON'T**: Just restart the app (need full rebuild)
❌ **DON'T**: Skip `flutter clean` (old build cache will be used)

✅ **DO**: Stop app → `flutter clean` → `flutter pub get` → `flutter run`
✅ **DO**: Wait for full build to complete
✅ **DO**: Test on fresh app launch

## Verification Checklist

After rebuild, verify these files have the changes:

```bash
# Check if method exists
grep -n "_extractFromIdAndCheckDuplicate" lib/AddLearnerPage.dart

# Check if gender is set
grep -n "_selectedGender = gender" lib/AddLearnerPage.dart

# Check if bank code is set
grep -n "_bankBranchCodeController.text = _bankCodes" lib/AddLearnerPage.dart
```

All three should return line numbers. If they don't, the file wasn't saved properly.

## Last Resort

If nothing works:
1. Close your IDE completely
2. Delete the `build` folder manually
3. Reopen IDE
4. Run: `flutter clean && flutter pub get && flutter run`
