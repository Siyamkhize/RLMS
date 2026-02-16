# 🔍 Random Biometric Verification System - Complete Explanation

## 🎯 Purpose
The system randomly prompts learners who are clocked in to verify their identity using fingerprint scanning. This ensures learners are actually present and not just "clocked in" by someone else.

## 📊 How It Works - Step by Step

### 1. **Database Setup**
```sql
-- Creates monitoring table to track prompts
CREATE TABLE monitoring (
  monitoring_id INT PRIMARY KEY AUTO_INCREMENT,
  learner_id INT NOT NULL,
  prompt_type ENUM('random_biometric','scheduled_check','manual_verification'),
  prompt_time DATETIME NOT NULL,
  countdown_duration INT DEFAULT 180, -- 3 minutes
  status ENUM('pending','completed','failed','timeout'),
  verification_time DATETIME NULL,
  response_time VARCHAR(10) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 2. **Creating Random Prompts**

#### **Option A: Single Learner Prompt**
```bash
curl -X POST http://your-server.com/mobile/create_monitoring_prompt.php \
  -d "learner_id=123" \
  -d "countdown_duration=180"
```

#### **Option B: Random Batch Prompts** (Recommended)
```bash
curl -X POST http://your-server.com/mobile/create_random_prompts_batch.php \
  -d "class_id=ABC123" \
  -d "num_prompts=3" \
  -d "countdown_duration=180"
```

**This will:**
1. Find all learners currently clocked in for that class
2. Randomly select 3 learners
3. Create prompts for each selected learner
4. Set 3-minute countdown timer

### 3. **App Monitoring Process**

#### **A. Automatic Start**
When a learner clocks in successfully:
```dart
// In clock_in_page.dart
await DatabaseHelper().insertClocking(dbData);
initMonitoring(learnerId); // Starts monitoring for this learner
```

#### **B. Background Checking**
The app checks for prompts every 30 seconds:
```dart
// In random_prompt_service.dart
Timer.periodic(const Duration(seconds: 30), (timer) {
  _checkForPrompts(); // Check if learner has pending prompts
});
```

#### **C. Prompt Detection**
```dart
Future<void> _checkForPrompts() async {
  final response = await http.post(
    Uri.parse('${AppConfig.baseUrl}/check_monitoring_prompts.php'),
    body: {'learner_id': _currentLearnerId.toString()},
  );
  
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data['has_prompt'] == true) {
      // Show notification and vibration
      await _showPromptNotification(prompt);
      await _vibratePhone();
    }
  }
}
```

### 4. **User Experience Flow**

#### **When Learner is Out of App:**
1. **Phone Vibrates** - Pattern: 500ms-1000ms-500ms-1000ms
2. **Notification Appears** - "⚠️ Biometric Verification Required"
3. **Full-screen Alert** - Cannot be dismissed
4. **Countdown Timer** - Shows time remaining (3 minutes default)

#### **When Learner Opens App:**
1. **Full-screen Prompt** appears immediately
2. **Countdown Timer** - Color changes: Blue → Orange → Red
3. **Fingerprint Scanner** - Must verify within time limit
4. **Cannot Dismiss** - Must complete or timeout

### 5. **Verification Process**

#### **Success Flow:**
```
1. Learner opens app
2. Full-screen prompt appears
3. Places finger on scanner
4. Fingerprint matches
5. ✅ "Verification successful!"
6. Status updated to 'completed'
7. Learner continues using app
```

#### **Failure Flow:**
```
1. Learner opens app
2. Full-screen prompt appears
3. Places wrong finger OR doesn't verify in time
4. ❌ "Verification failed!"
5. Status updated to 'failed' or 'timeout'
6. May be required to try again
```

### 6. **Server Endpoints**

#### **Check Prompts:**
```php
// check_monitoring_prompts.php
POST /check_monitoring_prompts.php
Body: learner_id=123

Response:
{
  "success": true,
  "has_prompt": true,
  "current_prompt": {
    "monitoring_id": 456,
    "learner_id": 123,
    "time_remaining": 150,
    "countdown_duration": 180
  }
}
```

#### **Update Status:**
```php
// update_monitoring_status.php
POST /update_monitoring_status.php
Body: 
  monitoring_id=456
  status=completed
  response_time=45

Response:
{
  "success": true,
  "message": "Monitoring status updated successfully"
}
```

## 🔄 Complete Workflow Example

### **Step 1: Administrator Creates Random Prompts**
```bash
# Create prompts for 3 random learners in class ABC123
curl -X POST http://server.com/mobile/create_random_prompts_batch.php \
  -d "class_id=ABC123&num_prompts=3&countdown_duration=180"
```

**Server Response:**
```json
{
  "success": true,
  "created": [
    {
      "monitoring_id": 101,
      "learner_id": 123,
      "name": "John Smith",
      "prompt_time": "2024-01-15 10:30:00"
    },
    {
      "monitoring_id": 102,
      "learner_id": 456,
      "name": "Jane Doe", 
      "prompt_time": "2024-01-15 10:30:00"
    },
    {
      "monitoring_id": 103,
      "learner_id": 789,
      "name": "Bob Wilson",
      "prompt_time": "2024-01-15 10:30:00"
    }
  ],
  "message": "Created 3 random prompts"
}
```

### **Step 2: Learners' Apps Check for Prompts**
Every 30 seconds, each learner's app checks:
```dart
// John's app checks
POST /check_monitoring_prompts.php
Body: learner_id=123

// Response shows John has a prompt
{
  "success": true,
  "has_prompt": true,
  "current_prompt": {
    "monitoring_id": 101,
    "time_remaining": 165
  }
}
```

### **Step 3: Phone Alerts User**
- **John's phone vibrates**
- **Notification appears**: "⚠️ Biometric Verification Required - 2m 45s remaining"
- **John minimizes the app**

### **Step 4: User Opens App**
- **Full-screen prompt appears**
- **Countdown timer**: 02:45, 02:44, 02:43...
- **Scanner ready**: "Place your finger on the scanner"

### **Step 5: Verification**
- **John places finger on scanner**
- **Fingerprint matches**
- **Success**: "✅ Verification successful!"
- **Status updated**: `completed` with response time 45 seconds

### **Step 6: Compliance Tracking**
```sql
-- Check compliance rates
SELECT 
  status,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM monitoring), 2) as percentage
FROM monitoring
GROUP BY status;

-- Results:
-- completed: 85%
-- failed: 10%
-- timeout: 5%
```

## 🎛️ Configuration Options

### **Timing Settings:**
```dart
// Check frequency (how often to look for prompts)
Timer.periodic(const Duration(seconds: 30), ...)

// Default countdown duration
countdown_duration=180  // 3 minutes

// Notification vibration pattern
pattern: [500, 1000, 500, 1000]  // milliseconds
```

### **Prompt Creation:**
```php
// Number of random learners to prompt
num_prompts=3

// Countdown time in seconds
countdown_duration=180  // 3 minutes
countdown_duration=300  // 5 minutes
countdown_duration=60   // 1 minute (for testing)
```

## 📈 Benefits

### **For Compliance:**
- ✅ Ensures learners are actually present
- ✅ Prevents proxy clock-ins
- ✅ Random timing prevents gaming the system
- ✅ Detailed audit trail of verification attempts

### **For Learners:**
- ✅ Clear instructions and countdown
- ✅ Visual and haptic feedback
- ✅ Reasonable time limits
- ✅ User-friendly error messages

### **For Administrators:**
- ✅ Easy to create random prompts
- ✅ Compliance reporting
- ✅ Response time tracking
- ✅ Failed verification alerts

## 🚨 Important Notes

1. **Random Selection**: The system randomly selects from currently clocked-in learners
2. **No Duplicates**: Won't create multiple prompts for the same learner
3. **Time Limits**: Prompts expire after countdown duration
4. **Background Checking**: Works even when app is minimized
5. **Offline Support**: Prompts stored locally if network unavailable

---

**This system ensures learners are actually present and prevents attendance fraud through random biometric verification!**
