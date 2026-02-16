# 🔍 Debug Logging Setup for Auto Clock-Out Investigation

## 📋 **Overview**

I've created a comprehensive logging system to identify what's causing the auto clock-out issue. This will capture **every clocking activity** and help us pinpoint the exact source of the problem.

## 📁 **Files Created**

### **Core Logging System:**
1. **`clocking_debug_logger.php`** - Main logging class with comprehensive tracking
2. **`get_clocking_data_debug.php`** - Enhanced version of get_clocking_data.php with logging
3. **`clockin_debug.php`** - Enhanced clockin.php with detailed logging  
4. **`clockout_debug.php`** - Enhanced clockout.php with detailed logging
5. **`database_monitor.php`** - Database analysis and trigger detection
6. **`log_analyzer.php`** - Web-based log analysis tool

## 🚀 **Setup Instructions**

### **Step 1: Create Logs Directory**
```bash
mkdir logs
chmod 755 logs
```

### **Step 2: Replace Your Scripts (Temporarily)**
**Backup your originals first, then:**

```bash
# Backup originals
cp get_clocking_data.php get_clocking_data_original.php
cp clockin.php clockin_original.php  
cp clockout.php clockout_original.php

# Use debug versions
cp get_clocking_data_debug.php get_clocking_data.php
cp clockin_debug.php clockin.php
cp clockout_debug.php clockout.php
```

### **Step 3: Test the Setup**
1. **Visit:** `https://your-server.com/mobile/database_monitor.php`
2. **Check for:** Triggers, procedures, events that might cause auto clock-outs
3. **Visit:** `https://your-server.com/mobile/log_analyzer.php`
4. **Verify:** Logging directory is writable

## 🔍 **How to Investigate**

### **Step 1: Reproduce the Issue**
1. **Clock in a test learner** using your app
2. **Wait 2-3 minutes** (past the auto clock-out time)
3. **Check if auto clock-out occurs**

### **Step 2: Analyze the Logs**
1. **Visit:** `https://your-server.com/mobile/log_analyzer.php`
2. **Look for red alerts:** Auto clock-out patterns
3. **Check critical events:** Database state changes
4. **Review timestamps:** Sequence of events

### **Step 3: Monitor Database**
1. **Check:** `database_monitor.php` for triggers/procedures
2. **Look for:** Patterns in recent clocking data
3. **Identify:** 2-minute session patterns

## 🎯 **What the Logs Will Show**

### **🔴 Critical Alerts:**
- **`AUTO CLOCK-OUT DETECTED`** - Direct evidence of unwanted clock-outs
- **`EXACTLY_2_MINUTES`** - Sessions that match your reported pattern
- **`RETURNING CLOCK-OUT TIME FOR EXISTING SESSION`** - Server sending unwanted data

### **📊 Useful Information:**
- **Request details** - Who/what is making requests
- **Database state changes** - Before/after comparisons  
- **Query execution** - All database operations
- **Response data** - What's being sent to clients

### **🚨 Patterns to Look For:**
- **Short sessions (< 5 minutes)**
- **Exactly 2-minute sessions**
- **Clock-out without user action**
- **Database triggers firing**
- **Unexpected server responses**

## 📋 **Sample Investigation Workflow**

### **1. Check Database Structure**
```
Visit: database_monitor.php
Look for: Triggers on learner_clocking table
Check: Recent suspicious sessions
```

### **2. Reproduce the Issue**
```
1. Clock in learner ID 123
2. Note the exact time
3. Wait 2-3 minutes  
4. Check if auto clock-out occurs
```

### **3. Analyze the Logs**
```
Visit: log_analyzer.php
Filter: Show all events for today
Look for: Learner ID 123 events
Check: Timeline of events
```

### **4. Identify the Source**
```
Check sequence:
- Clock-in request logged
- Periodic data fetch
- Unexpected clock-out appears
- Source of clock-out identified
```

## 🔧 **Log Levels**

- **`DEBUG`** - Detailed operation info
- **`INFO`** - General information  
- **`WARNING`** - Potential issues
- **`ERROR`** - Actual errors
- **`CRITICAL`** - Auto clock-out events, serious issues

## 📈 **Expected Findings**

This logging will help identify:

1. **Database triggers** auto-generating clock-outs
2. **Server scripts** filling missing data
3. **Sync processes** overwriting local state  
4. **Third-party processes** modifying data
5. **App logic** causing unwanted requests

## ⚠️ **Important Notes**

### **Performance Impact:**
- Logging adds minimal overhead
- Files rotate daily automatically
- Only enable during investigation

### **Security:**
- Logs contain learner IDs and activities
- Secure the logs/ directory
- Remove debug versions after investigation

### **Cleanup:**
```bash
# After investigation, restore originals
cp get_clocking_data_original.php get_clocking_data.php
cp clockin_original.php clockin.php
cp clockout_original.php clockout.php
```

## 🎯 **Next Steps**

1. **Setup the logging system** (15 minutes)
2. **Reproduce the auto clock-out** with logging active
3. **Analyze the results** using log_analyzer.php
4. **Identify the root cause** from the detailed logs
5. **Apply targeted fix** based on findings

This comprehensive logging will definitively show us **exactly when, how, and why** learners are being automatically clocked out!