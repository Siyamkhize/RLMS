# Random Monitoring Windows - COMPLETE

## ✅ Implementation Summary

Successfully implemented random monitoring times within specific time windows as requested.

## 🎲 New Random Monitoring Schedule

### Morning Session:
- **9:00-9:30 AM**: Random time for learner #1 (30-minute window)
- **10:30-11:00 AM**: Random time for learner #2 (30-minute window)

### Afternoon Session:
- **13:15-13:45 (1:15-1:45 PM)**: Random time for learner #3 (30-minute window)
- **14:00-15:15 (2:00-3:15 PM)**: Random time for learner #4 (75-minute window)

## 🔧 Key Changes Made

### 1. **Random Time Generation**
```dart
// Morning Learner 1: Random time between 9:00-9:30 AM
final morning1Start = today.add(const Duration(hours: 9)); // 9:00 AM
final morning1RandomMinutes = _random.nextInt(31); // 0-30 minutes
_scheduledPromptTimes['morning_learner_1'] = morning1Start.add(Duration(minutes: morning1RandomMinutes));

// Morning Learner 2: Random time between 10:30-11:00 AM
final morning2Start = today.add(const Duration(hours: 10, minutes: 30)); // 10:30 AM
final morning2RandomMinutes = _random.nextInt(31); // 0-30 minutes
_scheduledPromptTimes['morning_learner_2'] = morning2Start.add(Duration(minutes: morning2RandomMinutes));

// Afternoon Learner 1: Random time between 13:15-13:45 (1:15-1:45 PM)
final afternoon1Start = today.add(const Duration(hours: 13, minutes: 15)); // 1:15 PM
final afternoon1RandomMinutes = _random.nextInt(31); // 0-30 minutes
_scheduledPromptTimes['afternoon_learner_1'] = afternoon1Start.add(Duration(minutes: afternoon1RandomMinutes));

// Afternoon Learner 2: Random time between 14:00-15:15 (2:00-3:15 PM)
final afternoon2Start = today.add(const Duration(hours: 14)); // 2:00 PM
final afternoon2RandomMinutes = _random.nextInt(76); // 0-75 minutes (1 hour 15 minutes)
_scheduledPromptTimes['afternoon_learner_2'] = afternoon2Start.add(Duration(minutes: afternoon2RandomMinutes));
```

### 2. **Enhanced Debug Output**
```dart
debugPrint('[MONITORING_SERVICE] 🎲 Random monitoring times generated:');
debugPrint('[MONITORING_SERVICE] Morning Learner 1: ${DateFormat('HH:mm').format(_scheduledPromptTimes['morning_learner_1']!)} (9:00-9:30 window)');
debugPrint('[MONITORING_SERVICE] Morning Learner 2: ${DateFormat('HH:mm').format(_scheduledPromptTimes['morning_learner_2']!)} (10:30-11:00 window)');
debugPrint('[MONITORING_SERVICE] Afternoon Learner 1: ${DateFormat('HH:mm').format(_scheduledPromptTimes['afternoon_learner_1']!)} (13:15-13:45 window)');
debugPrint('[MONITORING_SERVICE] Afternoon Learner 2: ${DateFormat('HH:mm').format(_scheduledPromptTimes['afternoon_learner_2']!)} (14:00-15:15 window)');
```

## 📊 Time Window Details

| Session | Window | Duration | Random Range |
|---------|--------|----------|--------------|
| Morning Learner 1 | 9:00-9:30 AM | 30 minutes | 0-30 minutes |
| Morning Learner 2 | 10:30-11:00 AM | 30 minutes | 0-30 minutes |
| Afternoon Learner 1 | 13:15-13:45 | 30 minutes | 0-30 minutes |
| Afternoon Learner 2 | 14:00-15:15 | 75 minutes | 0-75 minutes |

## 🎯 How It Works

### Daily Process:
1. **Service Start**: When monitoring service starts for a class
2. **Learner Selection**: Randomly selects 4 learners who clocked in today
3. **Random Time Generation**: Generates random times within each specified window
4. **Schedule Assignment**: Assigns each learner to their random time slot
5. **Time Monitoring**: Checks every minute for scheduled prompt times
6. **Prompt Execution**: Calls learners at their randomly assigned times

### Example Random Schedule:
```
[MONITORING_SERVICE] 🎲 Random monitoring times generated:
[MONITORING_SERVICE] Morning Learner 1: 09:17 (9:00-9:30 window)
[MONITORING_SERVICE] Morning Learner 2: 10:43 (10:30-11:00 window)
[MONITORING_SERVICE] Afternoon Learner 1: 13:28 (13:15-13:45 window)
[MONITORING_SERVICE] Afternoon Learner 2: 14:52 (14:00-15:15 window)
```

## 🔄 Randomization Benefits

### ✅ **Unpredictable Timing**
- Learners cannot predict exact monitoring times
- Prevents gaming the system or preparation

### ✅ **Flexible Windows**
- Different window sizes for different sessions
- Accommodates varying operational needs

### ✅ **Fair Distribution**
- Each learner has equal chance within their window
- Random selection ensures fairness

### ✅ **Operational Efficiency**
- Avoids lunch break (12:00-13:15)
- Spreads monitoring throughout work periods

## 📋 Window Breakdown

### **Morning Windows:**
- **First Window (9:00-9:30)**: Early morning check after initial work period
- **Second Window (10:30-11:00)**: Mid-morning check before lunch prep

### **Afternoon Windows:**
- **First Window (13:15-13:45)**: Early afternoon check after lunch
- **Second Window (14:00-15:15)**: Extended afternoon window for flexibility

## 🚀 Usage

The system works automatically with the new random windows:

1. **Start Service**: `MonitoringService().startService(context, classID)`
2. **Automatic Selection**: System selects 4 random learners
3. **Random Time Generation**: Creates random times within specified windows
4. **Scheduled Prompts**: Learners are prompted at their random times
5. **Stop Service**: `MonitoringService().stopService()` to clean up

## 🔍 Debug Output Example

```
[MONITORING_SERVICE] 📋 Selected 2 morning + 2 afternoon learners
[MONITORING_SERVICE] 🌅 Morning Learner 1: John Doe (ID: 123)
[MONITORING_SERVICE] 🌅 Morning Learner 2: Jane Smith (ID: 456)
[MONITORING_SERVICE] 🌇 Afternoon Learner 1: Bob Johnson (ID: 789)
[MONITORING_SERVICE] 🌇 Afternoon Learner 2: Alice Brown (ID: 101)

[MONITORING_SERVICE] 🎲 Random monitoring times generated:
[MONITORING_SERVICE] Morning Learner 1: 09:17 (9:00-9:30 window)
[MONITORING_SERVICE] Morning Learner 2: 10:43 (10:30-11:00 window)
[MONITORING_SERVICE] Afternoon Learner 1: 13:28 (13:15-13:45 window)
[MONITORING_SERVICE] Afternoon Learner 2: 14:52 (14:00-15:15 window)

[MONITORING_SERVICE] ⏰ Time for morning_learner_1 - prompting learner 123
```

This implementation provides true randomization within your specified time windows while maintaining the structured approach to monitoring throughout the day.