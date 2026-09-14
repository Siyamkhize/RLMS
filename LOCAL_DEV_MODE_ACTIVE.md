# ✅ Local Development Mode ACTIVE

**Date**: September 14, 2026  
**Status**: **LOCAL DEV MODE ENABLED**

---

## 📍 Current Configuration

### Active Settings:
```dart
serverHost = '192.168.0.84'  // Local dev IP
serverPort = 8080             // HTTP port
serverProtocol = 'http'       // No HTTPS for local
basePath = '/assessorReport2/mobile'
```

### Base URL:
```
http://192.168.0.84:8080/assessorReport2/mobile
```

---

## ⚠️ Prerequisites

### 1. **Phone and PC on Same Wi-Fi**
- Ensure your Android phone is connected to the **same Wi-Fi network** as your development PC
- Your PC IP address must be `192.168.0.84`

### 2. **Local Server Running**
- Start XAMPP/WAMP/LAMP on your PC
- Ensure Apache is running on port `8080`
- Ensure MySQL is running
- Place the PHP files in: `C:\xampp\htdocs\assessorReport2\mobile\` (or equivalent)

### 3. **Firewall Configuration**
- Allow incoming connections on port `8080` in Windows Firewall
- To open firewall:
  1. Open Windows Defender Firewall
  2. Click "Advanced settings"
  3. Click "Inbound Rules" → "New Rule"
  4. Select "Port" → Next
  5. Enter `8080` → Next
  6. Allow the connection → Next
  7. Give it a name (e.g., "XAMPP Port 8080") → Finish

---

## 🧪 Testing the Configuration

### 1. **Verify PC IP Address**
Open Command Prompt and run:
```powershell
ipconfig
```
Look for your Wi-Fi adapter's IPv4 Address. It should be `192.168.0.84`.

**If it's different**, update `lib/config.dart` with the correct IP.

### 2. **Test Server Accessibility**
From your phone's browser, navigate to:
```
http://192.168.0.84:8080/assessorReport2/mobile/login.php
```

You should see either:
- A JSON response (if login.php is set up for API)
- A login page
- **NOT** a connection timeout or "site can't be reached" error

### 3. **Build New APK**
The config change requires rebuilding the app:

```powershell
cd c:\projects\rlmss
flutter clean
flutter build apk --release
```

APK location: `build\app\outputs\flutter-apk\app-release.apk`

### 4. **Install on Device**
Transfer the APK to your phone and install it.

---

## 🔄 Switching Back to Live Server

When you want to switch back to the live server:

1. Open `lib/config.dart`
2. Comment out the local dev section:
   ```dart
   // static const String serverHost = '192.168.0.84';
   // static const int serverPort = 8080;
   // static const String serverProtocol = 'http';
   // static const String basePath = '/assessorReport2/mobile';
   ```

3. Uncomment the live server section:
   ```dart
   static const String serverHost = 'rlms.rlms.co.za';
   static const int serverPort = 443;
   static const String serverProtocol = 'https';
   static const String basePath = '/mobile';
   ```

4. Rebuild the APK

---

## 🐛 Troubleshooting

### Issue: "Connection refused" or timeout
**Solution**:
- Check if Apache is running on port 8080
- Verify firewall allows port 8080
- Confirm phone is on same Wi-Fi
- Try accessing `http://192.168.0.84:8080` from phone browser

### Issue: "404 Not Found"
**Solution**:
- Verify PHP files exist in `C:\xampp\htdocs\assessorReport2\mobile\`
- Check that the path in Apache config is correct
- Verify `basePath` in config.dart matches your actual folder structure

### Issue: "Network error" in app
**Solution**:
- Check if you rebuilt the APK after config change
- Verify authentication endpoints are accessible
- Check Apache/MySQL error logs

### Issue: API returns errors
**Solution**:
- Check PHP error logs in `C:\xampp\apache\logs\error.log`
- Verify database connection in `connection.php`
- Ensure database tables exist and are populated

---

## 📝 What's Next?

1. **Start your local server** (XAMPP/WAMP)
2. **Verify connectivity** from phone browser
3. **Build new APK** with local config
4. **Test the new query queue & lazy loading features!**

---

## ⚙️ Current Features Active

With this local dev build, you can test:

✅ **Query Queue Service** - Max 3 concurrent requests  
✅ **Lazy Loading** - Pagination for learner lists  
✅ **Paginated Endpoints** - `get_learners.php`, `get_sdp_learners.php`  
✅ **Security Fixes** - Authentication, rate limiting, input validation

---

**Status**: 🟢 **READY TO BUILD & TEST**  
**Next Step**: `flutter build apk --release`
