# Build Failed - Disk Space Issue

## Error
```
java.io.IOException: There is not enough space on the disk
```

## Problem
Your C: drive is out of space. Flutter build needs temporary space for compilation.

## Solution - Free Up Disk Space

### Option 1: Clean Flutter Build Cache (Quick - 5 minutes)
```cmd
flutter clean
```

This will delete:
- `build/` directory (~500MB-2GB)
- `.dart_tool/` caches

### Option 2: Clean Gradle Cache (Recommended - 10 minutes)
```cmd
# Delete Gradle temporary files
rmdir /s /q "%USERPROFILE%\.gradle\.tmp"

# Delete Gradle caches (can be large!)
rmdir /s /q "%USERPROFILE%\.gradle\caches"
```

This can free up **several GB** of space!

### Option 3: Clean Windows Temp Files (30 minutes)
```cmd
# Run Disk Cleanup
cleanmgr

# Or manually delete temp files
del /s /q %TEMP%\*
```

### Option 4: Check Disk Space
```cmd
# See how much space you have
dir C:\ | findstr "bytes free"
```

**You need at least 5-10GB free space** for Flutter builds.

## After Freeing Space

### Step 1: Clean Project
```cmd
cd C:\projects\rlmss
flutter clean
```

### Step 2: Get Dependencies
```cmd
flutter pub get
```

### Step 3: Build APK
```cmd
flutter build apk --release
```

## Quick Win - Delete Old APKs

If you have old APK files, delete them:
```cmd
del /s /q C:\projects\rlmss\build\*.apk
```

## Alternative - Build on Different Drive

If you have another drive with more space (D:, E:, etc.):

1. Move project to that drive
2. Build there instead

## What's Taking Up Space?

Common culprits:
- **Downloads folder** - Clean out old downloads
- **Recycle Bin** - Empty it
- **Android SDK** - Old platform versions
- **Gradle caches** - Can be 5-10GB!
- **Flutter build** - Old build artifacts

## Immediate Action

**Do this NOW:**
```cmd
# 1. Clean Flutter
flutter clean

# 2. Clean Gradle temp
rmdir /s /q "%USERPROFILE%\.gradle\.tmp"

# 3. Try build again
flutter build apk --release
```

This should free up enough space to complete the build.

## If Still Failing

If still out of space:
1. Check available space: `wmic logicaldisk get size,freespace,caption`
2. Run Windows Disk Cleanup utility
3. Move large files to external drive
4. Uninstall unused programs

**You need to free up disk space before you can build the APK!**
