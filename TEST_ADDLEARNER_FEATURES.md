# Test Guide for AddLearnerPage Features

## IMPORTANT: Full App Restart Required!

The changes are in the code, but you MUST do a **FULL APP RESTART** (not hot reload) for them to take effect:

1. **Stop the app completely** in your IDE
2. **Rebuild and run** the app fresh
3. Hot reload will NOT work for these changes

## Feature 1: Gender Auto-Population

### Test Steps:
1. Open Add Learner page
2. Enter a valid 13-digit SA ID number
3. **Expected Result**: Gender dropdown should automatically select:
   - "Female" if ID positions 7-10 are 0000-4999
   - "Male" if ID positions 7-10 are 5000-9999

### Test IDs:
- **Male ID**: `9001015800089` (positions 7-10 = 5800 → Male)
- **Female ID**: `9001014800088` (positions 7-10 = 4800 → Female)

### Code Location:
```dart
// Line 283 in AddLearnerPage.dart
String gender = genderCode < 5000 ? 'Female' : 'Male';

// Line 304
_selectedGender = gender; // Auto-populate gender
```

## Feature 2: Early Duplicate Detection

### Test Steps:
1. Add a learner with ID `1234567890123` to a class
2. Try to add another learner with same ID to SAME project
3. **Expected Result**: Dialog appears immediately after entering ID:
   ```
   Learner Already Exists
   
   A learner with ID Number 1234567890123 already exists in this project.
   
   Name: John Doe
   Class: Class A
   Site: Site Name
   
   Do you want to update this learner's details?
   
   [No, Discard Changes]  [Yes, Update]
   ```

### Test Options:
- Click "No, Discard Changes" → ID field clears, form resets
- Click "Yes, Update" → Form pre-fills with existing learner data

### Code Location:
```dart
// Line 308-370 in AddLearnerPage.dart
final existingLearner = await dbHelper.checkLearnerExistsInProject(
  idNumber,
  widget.classID,
);
```

## Feature 3: Bank Code Auto-Population

### Test Steps:
1. Scroll to Banking Details section
2. Click "Bank Name" dropdown
3. Select "ABSA Bank"
4. **Expected Result**: Branch Code field automatically fills with `632005`
5. Branch Code field should be grey (read-only)

### All Bank Codes:
| Bank Name | Branch Code |
|-----------|-------------|
| ABSA Bank | 632005 |
| Capitec Bank | 470010 |
| First National Bank | 250655 |
| Nedbank | 198765 |
| Standard Bank | 051001 |
| Investec Bank | 580105 |
| Discovery Bank | 679000 |
| TymeBank | 678910 |
| African Bank | 430000 |
| Bidvest Bank | 462005 |

### Code Location:
```dart
// Line 649-659 in AddLearnerPage.dart
_buildDropdownField('Bank Name', _selectedBank, _banks, (value) {
  setState(() {
    _selectedBank = value;
    // Auto-populate bank code when bank is selected
    if (value != null && _bankCodes.containsKey(value)) {
      _bankBranchCodeController.text = _bankCodes[value]!;
    } else {
      _bankBranchCodeController.text = '';
    }
  });
}),
```

## Feature 4: Account Type Dropdown

### Test Steps:
1. Scroll to Banking Details section
2. Click "Account Type" dropdown
3. **Expected Result**: Dropdown shows these options:
   - Savings
   - Cheque
   - Current
   - Transmission
   - Fixed Deposit
   - Money Market
   - Student
   - Business
   - Trust

### Code Location:
```dart
// Line 660-670 in AddLearnerPage.dart
_buildDropdownField(
    'Account Type',
    _bankAccountTypeController.text.isEmpty
        ? null
        : _bankAccountTypeController.text,
    _accountTypes, (value) {
  setState(() {
    _bankAccountTypeController.text = value ?? '';
  });
}),
```

## Troubleshooting

### Gender Not Auto-Populating?
1. **Check**: Did you do a full app restart? (Hot reload won't work)
2. **Check**: Is the ID number exactly 13 digits?
3. **Check**: Does the ID pass validation (valid date, checksum)?
4. **Debug**: Add `print('Gender set to: $gender');` on line 304

### Bank Code Not Auto-Filling?
1. **Check**: Did you do a full app restart?
2. **Check**: Are you selecting from the dropdown (not typing)?
3. **Check**: Is the bank name exactly matching (e.g., "ABSA Bank" not "ABSA")?
4. **Debug**: Add `print('Bank selected: $value, Code: ${_bankCodes[value]}');` on line 653

### Duplicate Check Not Working?
1. **Check**: Did you do a full app restart?
2. **Check**: Is the learner in the SAME project?
3. **Check**: Is the database synced?
4. **Debug**: Check console for `[DB] Found X existing learner(s) in same project`

## Verification Checklist

- [ ] Full app restart completed
- [ ] Gender auto-populates when ID entered
- [ ] Duplicate dialog shows for existing learner
- [ ] "No, Discard Changes" clears form
- [ ] "Yes, Update" pre-fills form
- [ ] Bank code auto-fills when bank selected
- [ ] Branch code field is read-only (grey)
- [ ] Account type is dropdown (not text field)
- [ ] All features work in learner_list_page.dart too

## Code Verification

All code is in place:
- ✅ `_extractFromIdAndCheckDuplicate()` method exists (line 273)
- ✅ Gender extraction logic present (line 283)
- ✅ Gender setting in setState (line 304)
- ✅ Duplicate check logic (line 308)
- ✅ Bank codes map defined (line 115)
- ✅ Bank dropdown with auto-fill (line 649)
- ✅ Account types list (line 102)
- ✅ Account type dropdown (line 660)
- ✅ Branch code read-only (line 672)

## If Still Not Working

1. Clean build:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. Check Flutter version:
   ```bash
   flutter --version
   ```

3. Verify no syntax errors:
   ```bash
   flutter analyze lib/AddLearnerPage.dart
   ```

4. Check console output for errors when entering ID

## Success Indicators

When working correctly, you should see:
1. Gender dropdown changes immediately after 13th digit of ID
2. Dialog appears immediately if duplicate found
3. Bank code fills instantly when bank selected
4. Branch code field has grey background
5. Account type shows dropdown with 9 options
