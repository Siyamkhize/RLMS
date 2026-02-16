# Flutter Dependencies for POE Document Scanner

## Required Dependencies

Good news! You already have all the required dependencies in your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Already installed - no changes needed!
  http: ^1.0.0                       # HTTP requests
  flutter_doc_scanner: ^0.0.8        # Document scanner
  pdf: ^3.6.0                        # PDF generation
  image: ^4.0.18                     # Image processing
  path_provider: ^2.1.5              # File system paths
```

**No additional dependencies needed!** The POE scanner uses packages you already have.

## Installation Steps

### 1. No Changes Needed!
Your `pubspec.yaml` already has all required dependencies.

### 2. Just Build
```bash
flutter pub get
flutter build apk
```

### 3. Verify Installation
```bash
flutter pub deps
```

Look for:
- ✓ flutter_doc_scanner 0.0.8
- ✓ pdf 3.6.0
- ✓ image 4.0.18
- ✓ path_provider 2.1.5

## Android Permissions

The scanner needs camera permissions. These should already be in your `AndroidManifest.xml`, but verify:

**File:** `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Camera permission for document scanning -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    
    <!-- Storage permissions -->
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    
    <application>
        <!-- Your app configuration -->
    </application>
</manifest>
```

## iOS Permissions (if needed)

**File:** `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan documents</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to save scanned documents</string>
```

## Troubleshooting

### "Package not found"
```bash
flutter clean
flutter pub get
```

### "Version conflict"
If you get version conflicts, try:
```yaml
dependency_overrides:
  image: ^4.0.17
```

### "Build failed"
1. Clean build:
```bash
flutter clean
flutter pub get
flutter build apk
```

2. Check Gradle version (should be 7.0+):
**File:** `android/gradle/wrapper/gradle-wrapper.properties`
```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-7.5-all.zip
```

### "Scanner not opening"
1. Check camera permissions in AndroidManifest.xml
2. Test on physical device (not emulator)
3. Grant camera permission when app asks

## Testing Dependencies

After building, test that everything works:

```dart
// Test imports
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

// Test scanner
final scannedDoc = await FlutterDocScanner().getScanDocuments();
print('Scanned document: $scannedDoc');
```

## How the Scanner Works

The POE scanner uses `flutter_doc_scanner` which:
- Opens camera for document scanning
- Allows scanning one page at a time
- After each page, asks "Scan more?"
- Continues until user clicks "Done" or reaches 195 pages
- Converts all pages to a single PDF
- Uploads using chunked upload for large files

## Build Commands

### Debug Build
```bash
flutter build apk --debug
```

### Release Build
```bash
flutter build apk --release
```

### Install on Device
```bash
flutter install
```

## Verification Checklist

- [ ] Dependencies added to pubspec.yaml
- [ ] `flutter pub get` completed successfully
- [ ] No version conflicts
- [ ] Camera permissions in AndroidManifest.xml
- [ ] App builds without errors
- [ ] Scanner opens on device
- [ ] Can scan multiple pages
- [ ] PDF generation works
- [ ] Upload completes successfully

## Next Steps

1. ✅ Add dependencies
2. ✅ Run `flutter pub get`
3. ✅ Build app
4. ✅ Test scanner
5. ✅ Test upload with small document (10 pages)
6. ✅ Test upload with large document (100+ pages)

## Support

If you encounter issues:
1. Check Flutter version: `flutter --version` (should be 3.0+)
2. Check Dart version: `dart --version` (should be 2.17+)
3. Update Flutter: `flutter upgrade`
4. Clean and rebuild: `flutter clean && flutter pub get`
