# 🔧 Fix Random Biometric Monitoring System

## ✅ What I Fixed

### 1. **Re-enabled Monitoring Features**
The monitoring system was temporarily disabled during build fixes. I've re-enabled:

- ✅ `lib/main.dart` - Random prompt service initialization
- ✅ `lib/clock_in_page.dart` - Monitoring mixin and initialization
- ✅ All monitoring imports and function calls

### 2. **Created Debug Version**
- ✅ `lib/services/random_prompt_service_debug.dart` - Enhanced logging
- ✅ `test_monitoring_system.php` - Database and system test
- ✅ `test_monitoring.bat` - Automated testing script

## 🚀 How to Test the System

### Step 1: Test Database Setup
```bash
# Run the test script
test_monitoring.bat
```

This will:
1. Check if monitoring table exists
2. Find clocked-in learners
3. Create a test prompt
4. Verify the system is working

### Step 2: Manual Testing
```bash
# Create a test prompt for learner ID 123
curl -X POST http://localhost/assessorReport2/mobile/create_monitoring_prompt.php \
  -d "learner_id=123" \
  -d "countdown_duration=60"

# Check if prompt exists
curl -X POST http://localhost/assessorReport2/mobile/check_monitoring_prompts.php \
  -d "learner_id=123"
```

### Step 3: Test in App
1. **Clock in a learner** using the app
2. **Create a prompt** using the curl command above
3. **Wait 30 seconds** (app checks every 30s)
4. **Minimize the app** - should vibrate and show notification
5. **Open the app** - should show full-screen prompt

## 🔍 Troubleshooting

### If No Vibration/Notification:
1. **Check notification permissions** in app settings
2. **Disable battery optimization** for the app
3. **Check if learner is clocked in**
4. **Verify network connection**

### If No Prompts Created:
1. **Check database connection**
2. **Verify monitoring table exists**
3. **Ensure learners are clocked in**
4. **Check PHP files are in correct directory**

### If App Crashes:
1. **Use debug version** of random prompt service
2. **Check logs** for specific errors
3. **Verify all imports** are correct

## 📋 Step-by-Step Setup

### 1. Database Setup
```sql
-- Run this SQL on your database
CREATE TABLE IF NOT EXISTS `monitoring` (
  `monitoring_id` int(11) NOT NULL AUTO_INCREMENT,
  `learner_id` int(11) NOT NULL,
  `prompt_type` enum('random_biometric','scheduled_check','manual_verification') NOT NULL DEFAULT 'random_biometric',
  `prompt_time` datetime NOT NULL,
  `countdown_duration` int(11) NOT NULL DEFAULT 180,
  `status` enum('pending','completed','failed','timeout') NOT NULL DEFAULT 'pending',
  `verification_time` datetime NULL,
  `verification_method` enum('fingerprint') NULL DEFAULT 'fingerprint',
  `response_time` varchar(10) NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`monitoring_id`),
  KEY `idx_learner_id` (`learner_id`),
  KEY `idx_prompt_time` (`prompt_time`),
  KEY `idx_status` (`status`),
  FOREIGN KEY (`learner_id`) REFERENCES `learnerdetails`(`LearnerID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2. Copy PHP Files
Copy these files to your server's mobile directory:
- `php/create_monitoring_prompt.php`
- `php/check_monitoring_prompts.php`
- `php/update_monitoring_status.php`
- `php/create_random_prompts_batch.php`
- `test_monitoring_system.php`

### 3. Build App
```bash
flutter clean
flutter pub get
flutter build apk
```

### 4. Test the System
```bash
# Run automated test
test_monitoring.bat

# Or test manually
curl -X POST http://your-server/mobile/test_monitoring_system.php
```

## 🎯 Expected Behavior

### When Working Correctly:
1. **Learner clocks in** → Monitoring starts automatically
2. **Administrator creates prompt** → Stored in database
3. **App checks every 30s** → Finds pending prompt
4. **Phone vibrates** → Shows notification
5. **User opens app** → Full-screen prompt appears
6. **Fingerprint verified** → Status updated to completed

### Debug Information:
The debug version logs everything:
```
[RANDOM_PROMPT_DEBUG] Starting monitoring for learner 123
[RANDOM_PROMPT_DEBUG] Periodic check for learner 123
[RANDOM_PROMPT_DEBUG] Server response status: 200
[RANDOM_PROMPT_DEBUG] Prompt found! Time remaining: 165 seconds
[RANDOM_PROMPT_DEBUG] App in background, showing notification and vibrating
```

## 🚨 Common Issues & Solutions

### Issue: "Monitoring table does not exist"
**Solution**: Run the SQL script to create the table

### Issue: "No clocked-in learners found"
**Solution**: Clock in a learner first, then create prompts

### Issue: "No vibration/notification"
**Solution**: 
1. Check notification permissions
2. Disable battery optimization
3. Ensure app is minimized when prompt arrives

### Issue: "App crashes on startup"
**Solution**: 
1. Check all imports are correct
2. Use debug version for detailed logs
3. Verify Flutter dependencies

## 📞 Quick Test Commands

```bash
# Test database and create prompt
curl -X POST http://localhost/assessorReport2/mobile/test_monitoring_system.php

# Create random prompts for 3 learners
curl -X POST http://localhost/assessorReport2/mobile/create_random_prompts_batch.php \
  -d "class_id=YOUR_CLASS_ID&num_prompts=3&countdown_duration=60"

# Check specific learner's prompts
curl -X POST http://localhost/assessorReport2/mobile/check_monitoring_prompts.php \
  -d "learner_id=123"
```

---

## ✅ Status: MONITORING SYSTEM RE-ENABLED AND READY TO TEST

The random biometric monitoring system is now fully enabled and ready to test. Run the test scripts to verify it's working correctly!
