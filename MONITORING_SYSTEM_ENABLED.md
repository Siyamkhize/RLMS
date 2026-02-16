# ✅ Random Monitoring System - NOW ENABLED!

## 🎯 What Was Done

Re-enabled the random biometric monitoring system that was temporarily disabled during testing.

## 📋 What's Active Now

### **1. Background Monitoring Service** ✅
- Checks for prompts every 30 seconds
- Runs even when app is minimized
- Automatic phone vibration and notifications

### **2. Full-Screen Verification Prompt** ✅
- Cannot be dismissed
- Countdown timer (3 minutes default)
- Color-coded urgency (Blue → Orange → Red)
- Fingerprint verification required

### **3. Backend API Integration** ✅
- Create prompts for specific learners
- Create random batch prompts for class
- Check for pending prompts
- Update prompt status

## 🚀 How to Test

### **Step 1: Create Monitoring Table**
Run this SQL on your server database:

```sql
-- File: create_monitoring_table.sql
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
  PRIMARY KEY (`monitoring_id`),
  KEY `idx_learner_id` (`learner_id`),
  KEY `idx_prompt_time` (`prompt_time`),
  KEY `idx_status` (`status`),
  FOREIGN KEY (`learner_id`) REFERENCES `learnerdetails`(`LearnerID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### **Step 2: Upload PHP Files**
Copy these files to your server's `mobile/` directory:
- `php/create_monitoring_prompt.php`
- `php/check_monitoring_prompts.php`
- `php/update_monitoring_status.php`
- `php/create_random_prompts_batch.php`

### **Step 3: Test Single Prompt**
Create a test prompt for a specific learner:

```bash
curl -X POST http://your-server.com/mobile/create_monitoring_prompt.php \
  -d "learner_id=123" \
  -d "countdown_duration=60"
```

**Expected Response:**
```json
{
  "success": true,
  "monitoring_id": 1,
  "message": "Monitoring prompt created successfully"
}
```

### **Step 4: Test Random Batch Prompts**
Create prompts for 3 random learners in a class:

```bash
curl -X POST http://your-server.com/mobile/create_random_prompts_batch.php \
  -d "class_id=YOUR_CLASS_ID" \
  -d "num_prompts=3" \
  -d "countdown_duration=180"
```

**Expected Response:**
```json
{
  "success": true,
  "created": [
    {
      "monitoring_id": 1,
      "learner_id": 123,
      "name": "John Doe",
      "prompt_time": "2024-01-15 10:30:00"
    },
    {
      "monitoring_id": 2,
      "learner_id": 456,
      "name": "Jane Smith",
      "prompt_time": "2024-01-15 10:30:00"
    },
    {
      "monitoring_id": 3,
      "learner_id": 789,
      "name": "Bob Wilson",
      "prompt_time": "2024-01-15 10:30:00"
    }
  ],
  "message": "Created 3 random monitoring prompts"
}
```

### **Step 5: Test in App**

#### **A. Test App Monitoring:**
1. Build and install the app
2. Clock in a learner (this starts monitoring)
3. Create a prompt for that learner using the curl command
4. Wait 30 seconds (app checks every 30s)
5. **Expected:** Phone vibrates, notification appears

#### **B. Test Full-Screen Prompt:**
1. Minimize the app after clocking in
2. Create a prompt
3. Wait for notification
4. Open the app
5. **Expected:** Full-screen prompt with countdown timer

#### **C. Test Verification:**
1. When prompt appears, place finger on scanner
2. **If match:** "Verification successful!" → Prompt disappears
3. **If no match:** "Try again" → Can retry
4. **If timeout:** "Time expired!" → Status: timeout

## 📱 How It Works

### **When Learner Clocks In:**
```dart
// Monitoring starts automatically
initMonitoring(learnerId);
// Checks for prompts every 30 seconds
```

### **When Prompt Created on Server:**
```
1. Admin creates prompt via PHP API
2. Stored in monitoring table (status=pending)
3. Learner's app checks every 30 seconds
4. Finds pending prompt
5. Vibrates phone + shows notification
6. When app opened, shows full-screen prompt
```

### **When Learner Verifies:**
```
1. Places finger on scanner
2. Fingerprint matched → Success
3. Status updated to 'completed'
4. Response time recorded
5. Prompt dismissed
```

## 🔧 Configuration

### **Check Frequency:**
Default: Every 30 seconds
Location: `lib/services/random_prompt_service.dart`
```dart
Timer.periodic(const Duration(seconds: 30), (timer) {
  _checkForPrompts();
});
```

### **Countdown Duration:**
Default: 180 seconds (3 minutes)
Can be customized when creating prompt:
```bash
-d "countdown_duration=300"  # 5 minutes
-d "countdown_duration=60"   # 1 minute (for testing)
```

### **Vibration Pattern:**
Default: 500ms-1000ms-500ms-1000ms
Location: `lib/services/random_prompt_service.dart`
```dart
await Vibration.vibrate(
  pattern: [500, 1000, 500, 1000],
  intensities: [128, 255, 128, 255],
);
```

## 📊 Database Tracking

### **Check Pending Prompts:**
```sql
SELECT * FROM monitoring WHERE status = 'pending';
```

### **Check Completion Rate:**
```sql
SELECT 
  status,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM monitoring), 2) as percentage
FROM monitoring
GROUP BY status;
```

### **Check Response Times:**
```sql
SELECT 
  AVG(CAST(response_time AS UNSIGNED)) as avg_response_time,
  MIN(CAST(response_time AS UNSIGNED)) as fastest,
  MAX(CAST(response_time AS UNSIGNED)) as slowest
FROM monitoring
WHERE status = 'completed';
```

## ⚠️ Important Notes

### **1. Permissions Required:**
Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

### **2. Dependencies Required:**
Check `pubspec.yaml` has:
```yaml
dependencies:
  vibration: ^1.8.4
  flutter_local_notifications: ^17.2.3
```

### **3. Only Clocked-In Learners:**
- Monitoring only starts after successful clock-in
- Stops when learner clocks out or app is closed

### **4. Random Selection:**
- Batch prompts select random learners from those currently clocked in
- No duplicates in same batch

## 🎯 Use Cases

### **Use Case 1: Spot Check**
Create prompt for specific learner:
```bash
curl -X POST .../create_monitoring_prompt.php \
  -d "learner_id=123" \
  -d "countdown_duration=120"
```

### **Use Case 2: Random Compliance Check**
Create prompts for 5 random learners:
```bash
curl -X POST .../create_random_prompts_batch.php \
  -d "class_id=ABC123" \
  -d "num_prompts=5" \
  -d "countdown_duration=180"
```

### **Use Case 3: Scheduled Checks**
Use cron job to create random prompts:
```bash
# Every hour, prompt 3 random learners
0 * * * * curl -X POST .../create_random_prompts_batch.php -d "class_id=ABC123&num_prompts=3&countdown_duration=180"
```

## ✅ Summary

**Monitoring System is NOW ACTIVE:**
- ✅ Background checking every 30 seconds
- ✅ Phone vibration and notifications
- ✅ Full-screen verification prompts
- ✅ Countdown timers with color coding
- ✅ Automatic status tracking
- ✅ Response time recording

**Next Steps:**
1. Build the app: `BUILD_FINAL.bat`
2. Create monitoring table on server
3. Upload PHP files
4. Test with a single prompt
5. Test with random batch prompts

**The monitoring system is ready to prevent attendance fraud!** 🎉
