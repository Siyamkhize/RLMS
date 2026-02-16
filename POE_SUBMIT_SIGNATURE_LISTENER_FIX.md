# POE Submit Signature Listener Fix

## ISSUE IDENTIFIED
The biometric verification button was not becoming enabled even after providing the representative name and signature because the UI was not updating when the signature was drawn.

## ROOT CAUSE
The `_representativeSignatureController` did not have a listener attached to trigger UI updates when the signature was drawn or cleared. The UI was only rebuilding when the representative name text field changed, but not when the signature pad was used.

## SOLUTION IMPLEMENTED
Added a listener to the signature controller in the `initState()` method to trigger UI rebuilds whenever the signature changes.

### Changes Made:

1. **Added Signature Controller Listener**:
   ```dart
   _representativeSignatureController.addListener(() {
     setState(() {
       // This will trigger UI rebuild when signature is drawn or cleared
     });
   });
   ```

2. **Proper Listener Management**:
   - Added in `initState()` to start monitoring signature changes
   - Automatically disposed in `dispose()` method (already handled by controller disposal)

## HOW IT WORKS NOW:

1. **User enters representative name** → Text field `onChanged` triggers `setState()` → UI updates
2. **User draws signature** → Signature controller listener triggers `setState()` → UI updates  
3. **Button enabling logic** → Checks both name and signature status → Enables button when both are provided

## BUTTON ENABLING CONDITIONS:
The "Verify Learner Fingerprint" button will now be enabled when:
- `representativeController.text.trim().isNotEmpty` (name provided)
- `!_representativeSignatureController.isEmpty` (signature drawn)
- `!isLoading` (not currently processing)

## EXPECTED RESULT:
- Enter representative name → Signature pad becomes active
- Draw signature → Biometric verification button becomes enabled (blue color)
- Button shows proper guidance messages based on completion status

## FILES MODIFIED:
- `lib/poe_submit.dart` - Added signature controller listener

## TESTING:
1. Enter representative name → Signature pad should become active
2. Draw signature → Biometric verification button should become enabled and turn blue
3. Clear signature → Button should become disabled again
4. Clear name → Signature pad should become inactive