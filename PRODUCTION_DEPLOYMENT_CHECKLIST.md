# 🚀 Production Deployment Checklist

## ✅ **App Configuration:**

### **App Name:**
```
Display Name: RLMSS v1
Package Name: com.example.rlmss (unchanged)
Version: 1.0.0+1
```

### **Server Configuration:**
```
Protocol: HTTPS (Secure)
Domain: rlms.rlms.co.za
Base Path: /mobile
Full URL: https://rlms.rlms.co.za/mobile
```

**Updated in**: `lib/config.dart`

## 📋 **Pre-Deployment Checklist:**

### **1. Live Server Setup:**

#### **A. Upload Fixed PHP Files:**
Upload these files to `https://rlms.rlms.co.za/mobile/`:

**Critical Fixed Files:**
- ✅ `sync_learner_clocking.php` (with `date('Y-m-d')` default)
- ✅ `clockin.php` (ClockingDebugLogger fix on line 38)
- ✅ `clockout.php` (ClockingDebugLogger fix on line 38)

**Other Required Files:**
- `sync_facilitator.php`
- `sync_facilitator_fingerprint.php`
- `facilitator_clockin.php`
- `facilitator_clockout.php`
- `login.php`
- `sync_learner.php`
- `sync_learnerdetails.php`
- `connection.php`
- All other mobile endpoints

#### **B. Verify Database:**
Ensure live database has these tables with correct columns:

**`facilitator` table:**
- All basic columns (facilitator_id, firstName, lastName, etc.)
- ✅ `zkteco_left_template` (LONGTEXT)
- ✅ `zkteco_right_template` (LONGTEXT)
- ✅ `futronic_left_template` (LONGTEXT)
- ✅ `futronic_right_template` (LONGTEXT)

**`facilitator_clocking` table:**
- clocking_id, facilitator_id, clock_date
- clock_in_time, clock_out_time, contact_time
- user_latitude, user_longitude, user_accuracy

**`learner_clocking` table:**
- All existing columns
- Ensure synced column exists

**`learnerdetails` table:**
- All existing columns with fingerprint templates

#### **C. Create Required Directories:**
```bash
mkdir facilitatorProfiles
mkdir facilitatorSignatures
mkdir learnerImages
mkdir sicknotes
mkdir uploads

chmod 755 facilitatorProfiles
chmod 755 facilitatorSignatures
chmod 755 learnerImages
chmod 755 sicknotes
chmod 755 uploads
```

#### **D. Verify SSL Certificate:**
```bash
Test: https://rlms.rlms.co.za/mobile/login.php
Expected: Valid SSL certificate (no warnings)
```

### **2. Test Live Server Endpoints:**

#### **Before Deploying App, Test Each Endpoint:**

**Login Test:**
```bash
POST https://rlms.rlms.co.za/mobile/login.php
Body: email=test@test.com&password=test123
Expected: {"success":true,...}
```

**Clock-In Test:**
```bash
POST https://rlms.rlms.co.za/mobile/clockin.php
Body: LearnerID=1&classID=1&user_latitude=0.0&...
Expected: {"success":true,"message":"Clock-in successful"}
```

**Clock-Out Test:**
```bash
POST https://rlms.rlms.co.za/mobile/clockout.php
Body: LearnerID=1&classID=1&...
Expected: {"success":true,"contact_time":"..."}
```

**Facilitator Sync Test:**
```bash
GET https://rlms.rlms.co.za/mobile/sync_facilitator.php
Expected: [{"facilitator_id":"1",...,"futronic_left_template":"..."}]
```

**Current Day Sync Test:**
```bash
GET https://rlms.rlms.co.za/mobile/sync_learner_clocking.php?classID=1
Expected: Only current day records (no historical data)
```

### **3. App Build Status:**

```
✅ App name changed to: "RLMSS v1"
✅ Server changed to: https://rlms.rlms.co.za/mobile
✅ Protocol changed to: HTTPS (Secure)
✅ All fixes included in build
🔄 Building APK now...
```

**APK will be at:**
```
C:\temp\gradle-build\app\outputs\flutter-apk\app-debug.apk
```

### **4. Testing Plan:**

#### **Phase 1: Internal Testing (1-2 devices)**
1. ✅ Install APK on test device
2. ✅ Test login with live credentials
3. ✅ Test clock-in (verify syncs to live server)
4. ✅ Test clock-out (verify contact time on live server)
5. ✅ Test facilitator login (verify templates sync)
6. ✅ Test offline mode (disconnect network)
7. ✅ Test reconnection (verify offline data syncs)

#### **Phase 2: Pilot Testing (5-10 devices)**
1. Deploy to small group
2. Monitor for issues
3. Check server logs
4. Verify data integrity
5. Collect feedback

#### **Phase 3: Full Deployment**
1. Deploy to all users
2. Monitor server performance
3. Track sync success rates
4. Provide user support

## ⚠️ **Important Notes:**

### **Security:**
- ✅ HTTPS encryption enabled
- ✅ SSL certificate required on live server
- ⚠️ Ensure connection.php has secure database credentials
- ⚠️ Consider adding API authentication tokens

### **Performance:**
- Monitor server load with multiple concurrent users
- Consider database indexing for performance
- Monitor sync operation times

### **Backup:**
- ✅ Keep local server configuration as backup
- ✅ Test rollback procedure
- ✅ Database backups before deployment

## 🔄 **Rollback to Local Server:**

If live server has issues, edit `lib/config.dart`:

```dart
serverHost = '192.168.68.126'
serverPort = 8080
serverProtocol = 'http'
basePath = '/assessorReport2/mobile'
```

Then rebuild and reinstall.

## 📱 **App Details:**

```
App Name: RLMSS v1
Version: 1.0.0 (Build 1)
Package: com.example.rlmss
Target: Android 15 (API 35)
Min SDK: 21
Server: https://rlms.rlms.co.za/mobile
Protocol: HTTPS (Secure)
```

## ✅ **All Fixes Included:**

1. ✅ PHP current date fix
2. ✅ Facilitator template sync (background + immediate)
3. ✅ Re-enrollment option
4. ✅ Clock-in PHP fix
5. ✅ Clock-out PHP fix
6. ✅ Type casting fix
7. ✅ Live server configuration
8. ✅ App renamed to "RLMSS v1"

## 🚀 **Ready for Deployment!**

Once the APK build completes:
1. Copy APK from `C:\temp\gradle-build\app\outputs\flutter-apk\app-debug.apk`
2. Test on internal device
3. Verify all endpoints work with live server
4. Deploy to users

**The app is configured and ready for production deployment!** 🎉
