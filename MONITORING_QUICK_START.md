# 🚀 Monitoring System - Quick Start Guide

## ✅ You Already Have:
- ✅ Monitoring table created in database
- ✅ All PHP files in place
- ✅ Flutter app with monitoring enabled

## 🎯 Quick Test (5 Minutes)

### **Step 1: Test Your Setup**
```bash
curl http://localhost/assessorReport2/mobile/test_monitoring_complete.php
```

**Expected Output:**
```json
{
  "success": true,
  "message": "✅ All tests passed! Monitoring system is ready.",
  "summary": {
    "total": 8,
    "passed": 6,
    "failed": 0,
    "skipped": 2
  }
}
```

### **Step 2: Build Your App**
```bash
BUILD_ALL_FEATURES.bat
```

### **Step 3: Clock In a Learner**
1. Open the app
2. Navigate to your class
3. Clock in any learner using fingerprint
4. **Note the Learner ID** (you'll need it)

### **Step 4: Create Test Prompt**
```bash
# Replace 123 with your learner ID
curl -X POST http://localhost/assessorReport2/mobile/create_monitoring_prompt.php \
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

### **Step 5: Wait and Watch**
```
After 30 seconds (app checks every 30s):
  1. Phone should vibrate
  2. Notification should appear: "⚠️ Biometric Verification Required"
  3. Open app → Full-screen prompt appears
  4. Countdown timer shows: 00:60 (60 seconds)
  5. Place finger on scanner
  6. Success! Prompt dismissed
```

## 🎯 Real-World Usage

### **Random Spot Check (3 Learners)**
```bash
curl -X POST http://localhost/assessorReport2/mobile/create_random_prompts_batch.php \
  -d "class_id=YOUR_CLASS_ID" \
  -d "num_prompts=3" \
  -d "countdown_duration=180"
```

This will:
- Find all learners currently clocked in for that class
- Randomly select 3 learners
- Create prompts for each
- Each has 3 minutes to verify

### **Scheduled Checks (Every Hour)**
Create a Windows Task Scheduler task or use cron:

**Windows (Task Scheduler):**
```batch
@echo off
curl -X POST http://your-server.com/mobile/create_random_prompts_batch.php -d "class_id=ABC123&num_prompts=3&countdown_duration=180"
```

**Linux (Cron):**
```bash
# Every hour, prompt 3 random learners
0 * * * * curl -X POST http://your-server.com/mobile/create_random_prompts_batch.php -d "class_id=ABC123&num_prompts=3&countdown_duration=180"
```

## 📊 Check Compliance

### **View Pending Prompts:**
```sql
SELECT 
    m.monitoring_id,
    m.learner_id,
    CONCAT(ld.firstName, ' ', ld.lastName) as name,
    m.prompt_time,
    m.countdown_duration,
    m.status
FROM monitoring m
JOIN learnerdetails ld ON m.learner_id = ld.LearnerID
WHERE m.status = 'pending'
ORDER BY m.prompt_time DESC;
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

**Example Output:**
```
status      | count | percentage
------------|-------|------------
completed   | 85    | 85.00
failed      | 10    | 10.00
timeout     | 5     | 5.00
```

### **Average Response Time:**
```sql
SELECT 
    AVG(response_time) as avg_seconds,
    MIN(response_time) as fastest,
    MAX(response_time) as slowest
FROM monitoring
WHERE status = 'completed';
```

## ⚠️ Troubleshooting

### **Issue: No vibration or notification**
**Solutions:**
1. Check notification permissions in app settings
2. Disable battery optimization for the app
3. Make sure learner is clocked in
4. Verify prompt was created: `SELECT * FROM monitoring WHERE status='pending'`

### **Issue: Prompt not showing in app**
**Solutions:**
1. Wait 30 seconds (app checks every 30s)
2. Check app logs for: `[RANDOM_PROMPT_DEBUG]`
3. Verify internet connection
4. Check prompt exists for that learner_id

### **Issue: "No clocked-in learners found"**
**Solution:**
- Clock in at least one learner first
- Prompts only work for currently clocked-in learners

## 🎮 Testing Tips

### **Quick Test (30 seconds):**
```bash
# 1. Clock in learner ID 123
# 2. Create prompt with short countdown
curl -X POST http://localhost/assessorReport2/mobile/create_monitoring_prompt.php \
  -d "learner_id=123" \
  -d "countdown_duration=30"

# 3. Wait 30 seconds
# 4. Should vibrate and show notification
```

### **Batch Test (Multiple Learners):**
```bash
# 1. Clock in 5+ learners
# 2. Create random batch
curl -X POST http://localhost/assessorReport2/mobile/create_random_prompts_batch.php \
  -d "class_id=YOUR_CLASS" \
  -d "num_prompts=3" \
  -d "countdown_duration=60"

# 3. All 3 selected learners should get prompts
```

## 📱 What Learners See

### **1. App in Foreground:**
```
Countdown timer appears immediately
"⚠️ Biometric Verification Required"
Timer: 02:45 (Blue)
"Place your finger on the scanner"
[Verify Now Button]
```

### **2. App in Background:**
```
Phone vibrates: buzz-buzz-buzz-buzz
Notification: "⚠️ Biometric Verification Required - Please verify within 2m 45s"
Tap notification → Full-screen prompt
```

### **3. Successful Verification:**
```
"✅ Verification successful!"
Prompt dismissed
Can continue using app
```

### **4. Failed Verification:**
```
"❌ Fingerprint not recognized. Please try again."
Can retry until timeout
```

### **5. Timeout:**
```
"⏰ Time expired! Verification failed."
Status: timeout
```

## ✅ Success Checklist

- [ ] Monitoring table exists in database
- [ ] PHP files uploaded to server
- [ ] Test script passes all tests
- [ ] App built and installed
- [ ] Learner clocked in
- [ ] Test prompt created
- [ ] Phone vibrates after 30s
- [ ] Notification appears
- [ ] Full-screen prompt shows
- [ ] Fingerprint verification works
- [ ] Prompt dismissed on success

## 🎯 Next Steps

1. **Test with one learner first**
2. **Verify vibration and notifications work**
3. **Check database for completed status**
4. **Set up scheduled random checks**
5. **Monitor compliance rates**

---

**Your monitoring system is ready! Test it with one learner first, then deploy to your class.** 🎉

**Quick Test Command:**
```bash
curl http://localhost/assessorReport2/mobile/test_monitoring_complete.php
```