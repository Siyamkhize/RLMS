# Fixed: Pothole Checklist URL Path

## Problem Identified
The Flutter app was requesting:
```
https://rlms.rlms.co.za/mobile/php/view_pothole_checklists.php
```

But the correct path is:
```
https://rlms.rlms.co.za/mobile/view_pothole_checklists.php
```

The `/php/` subdirectory doesn't exist on the server.

## Error Log
```
DEBUG Pothole: Response status 404
DEBUG Pothole: Response body <!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN"><html><head>
```

This is a 404 Not Found error (HTML error page).

## Fix Applied

### lib/AssessorPage.dart
Changed:
```dart
final url = '${AppConfig.baseUrl}/php/view_pothole_checklists.php?learner_id=${widget.learnerId}';
```

To:
```dart
final url = '${AppConfig.baseUrl}/view_pothole_checklists.php?learner_id=${widget.learnerId}';
```

## Result
The app now correctly requests:
```
https://rlms.rlms.co.za/mobile/view_pothole_checklists.php?learner_id=75
```

## Testing
1. Restart the Flutter app
2. Navigate to the POE tab for learner ID 75
3. Check the debug logs - should now see:
   ```
   DEBUG Pothole: Response status 200
   DEBUG Pothole: Found checklist on server, type=scanned (or system)
   ```
4. The "View Pothole Checklist" button should now appear

## Status
✅ **FIXED**

The URL path has been corrected. The checklist should now display properly.
