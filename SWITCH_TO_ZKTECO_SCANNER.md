# Switch to ZKTeco Scanner - Quick Guide ✅

## Your App Already Supports ZKTeco!

Your app has **automatic dual scanner detection** built-in. No code changes needed!

---

## How to Switch to ZKTeco Scanner

### Step 1: Unplug Futronic Scanner
```
1. Close the app
2. Unplug the Futronic scanner from USB
3. Wait 5 seconds
```

### Step 2: Plug in ZKTeco Scanner
```
1. Connect ZKTeco scanner to USB port
2. Wait for Windows to recognize device (5-10 seconds)
3. Check Device Manager to confirm scanner is detected
```

### Step 3: Restart App
```
1. Launch your app
2. Go to enrollment page
3. App will automatically detect ZKTeco scanner
4. Status will show: activeScanner=zkteco
```

**That's it!** The app will automatically use ZKTeco instead of Futronic.

---

## How Auto-Detection Works

Your app checks for scanners in this order:

```
1. Check for ZKTeco scanner
   ↓
   ✅ Found? → Use ZKTeco
   ↓
   ❌ Not found? → Check for Futronic
   ↓
   ✅ Found? → Use Futronic
   ↓
   ❌ Not found? → Show "No scanner detected"
```

**Priority**: ZKTeco is checked FIRST, so if both are connected, ZKTeco will be used.

---

## What You'll See in Console

### When ZKTeco is Detected:
```
[DETECT] Checking ZKTeco scanner...
[DETECT] ZKTeco result: true
✅ ZKTeco scanner detected
activeScanner: zkteco
isSensorConnected: true
```

### When Futronic is Detected:
```
[DETECT] Checking ZKTeco scanner...
[DETECT] ZKTeco result: false
[DETECT] Checking Futronic scanner...
[DETECT] Futronic result: true
✅ Futronic scanner detected
activeScanner: futronic
isSensorConnected: true
```

### When No Scanner is Detected:
```
[DETECT] Checking ZKTeco scanner...
[DETECT] ZKTeco result: false
[DETECT] Checking Futronic scanner...
[DETECT] Futronic result: false
❌ No scanner detected
activeScanner: none
isSensorConnected: false
```

---

## Verify ZKTeco is Working

### Check Device Manager (Windows):
```
1. Press Win + X → Device Manager
2. Look for "ZKTeco" or "Biometric Devices"
3. Should show ZKTeco scanner without yellow warning icon
4. If yellow warning: Update driver
```

### Check in App:
```
1. Open enrollment page
2. Look at status message
3. Should show: "Scanner ready (zkteco)"
4. Try enrolling a fingerprint
5. Should work without errors
```

---

## ZKTeco Scanner Models Supported

Your app supports these ZKTeco models:
- ZK4500
- ZK6500
- ZK7500
- ZK8500
- SLK20R
- And other ZKTeco USB fingerprint scanners

---

## Troubleshooting ZKTeco

### Issue 1: ZKTeco Not Detected
**Solution**:
```
1. Check USB connection
2. Try different USB port
3. Install ZKTeco drivers from:
   https://www.zkteco.com/en/support_download
4. Restart computer
5. Restart app
```

### Issue 2: "Scanner Busy" Error
**Solution**:
```
1. Close any other fingerprint apps
2. Check Task Manager for ZKTeco processes
3. End those processes
4. Restart app
```

### Issue 3: Poor Fingerprint Quality
**Solution**:
```
1. Clean scanner surface with soft cloth
2. Ensure finger is dry (not sweaty)
3. Press finger firmly on scanner
4. Try different finger if one doesn't work
```

---

## Database Compatibility

### Good News: Templates are Scanner-Specific

Your database stores fingerprints in scanner-specific columns:
- `zkteco_left_template` - For ZKTeco scanner
- `zkteco_right_template` - For ZKTeco scanner
- `futronic_left_template` - For Futronic scanner
- `futronic_right_template` - For Futronic scanner

**This means**:
- ✅ You can switch between scanners anytime
- ✅ Fingerprints enrolled with ZKTeco work with ZKTeco
- ✅ Fingerprints enrolled with Futronic work with Futronic
- ✅ No data loss when switching scanners

**Important**: If you switch scanners, learners will need to re-enroll their fingerprints with the new scanner.

---

## Re-Enrollment Process

If switching from Futronic to ZKTeco:

```
1. Learners with Futronic fingerprints enrolled:
   - Will need to re-enroll with ZKTeco scanner
   - Old Futronic templates remain in database (not deleted)
   - Can switch back to Futronic anytime

2. How to re-enroll:
   - Go to enrollment page
   - Select learner
   - Click "Enroll Left Thumb" (with ZKTeco connected)
   - Click "Enroll Right Thumb"
   - Done! Learner now has ZKTeco templates
```

---

## Can I Use Both Scanners?

**Yes!** Your app supports using both scanners:

### Scenario 1: Different Locations
```
Location A: Use ZKTeco scanner
Location B: Use Futronic scanner

Each location enrolls learners with their scanner.
Database stores both types of templates.
```

### Scenario 2: Backup Scanner
```
Primary: ZKTeco scanner
Backup: Futronic scanner (if ZKTeco fails)

If ZKTeco scanner breaks, plug in Futronic.
Learners re-enroll with Futronic.
When ZKTeco is fixed, switch back.
```

### Scenario 3: Mixed Enrollment
```
Some learners enrolled with ZKTeco
Some learners enrolled with Futronic

App automatically uses correct templates for each learner.
Clock-in works with whichever scanner is connected.
```

---

## Performance Comparison

| Feature | ZKTeco | Futronic |
|---------|--------|----------|
| Speed | Fast | Fast |
| Accuracy | High | High |
| Reliability | Excellent | Good |
| Driver Support | Excellent | Good |
| Firmware Updates | Regular | Less frequent |
| Price | Moderate | Moderate |
| **Current Status** | ✅ Working | ❌ Firmware issue |

**Recommendation**: Use ZKTeco until Futronic firmware is updated.

---

## Quick Reference Commands

### Check Which Scanner is Active:
Look for this in console:
```
activeScanner: zkteco  ← ZKTeco is active
activeScanner: futronic  ← Futronic is active
activeScanner: none  ← No scanner detected
```

### Force Scanner Detection:
```
1. Restart app
2. Scanner detection runs automatically on startup
3. Check console for detection results
```

### Switch Scanners:
```
1. Close app
2. Unplug current scanner
3. Plug in new scanner
4. Restart app
5. New scanner auto-detected
```

---

## Summary

**Current Situation**:
- ❌ Futronic scanner: Firmware incompatible
- ✅ ZKTeco scanner: Ready to use

**Action Required**:
1. Unplug Futronic scanner
2. Plug in ZKTeco scanner
3. Restart app
4. Start enrolling with ZKTeco

**No Code Changes Needed**: Your app already supports both scanners automatically!

**Re-enrollment**: Learners will need to re-enroll fingerprints with ZKTeco scanner.

---

## Need Help?

**ZKTeco Support**:
- Website: https://www.zkteco.com/en/support
- Downloads: https://www.zkteco.com/en/support_download
- Email: support@zkteco.com

**Your App**:
- Check console logs for scanner detection
- Look for `activeScanner` status
- Verify `isSensorConnected: true`

---

## Next Steps

1. ✅ Unplug Futronic scanner
2. ✅ Plug in ZKTeco scanner  
3. ✅ Restart app
4. ✅ Verify ZKTeco is detected
5. ✅ Start enrolling fingerprints
6. ✅ Test clock-in with enrolled learners

**You're all set!** ZKTeco scanner will work immediately. 🎉
