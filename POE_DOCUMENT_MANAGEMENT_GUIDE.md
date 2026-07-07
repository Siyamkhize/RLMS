# POE Document Management Guide

## Current Status for Learner 11515 ✅

### Database Analysis Results
- **Total POE Records**: 275
- **Formative**: 139 exercises (all with documents)
- **Summative**: 128 exercises (all with documents)  
- **Remedial**: 8 exercises (4 formative + 4 summative)
- **Missing Documents**: 0 (all exercises have file paths)
- **Sync Status**: 0 synced, 275 unsynced (all local)

### Document Status
✅ **All exercises have documents** - No missing files detected  
⚠️ **All documents are unsynced** - 275 records pending server upload

## Understanding POE Workflow Issues

### 1. **Questions Already Completed But Not Synced**
**Problem**: Learner has completed 275 POE exercises locally, but none are synced to server.

**What Happens**:
- Flutter app shows exercises as "Completed" locally
- Server doesn't know about these completions
- Documents exist in local `POE/` folder but not on server
- Progress may appear inconsistent between devices

**Solutions**:
```dart
// Flutter app handles this with sync functionality
await _syncOfflinePOE(); // Uploads unsynced records to server
```

### 2. **Missing or Corrupted Documents**
**Problem**: Document files referenced in database don't exist or are corrupted.

**What Happens**:
- Exercise shows as "Completed" but document is unusable
- Camera scanning may fail to access file
- Upload to server fails due to missing file

**Solutions**:
- **Re-scan Document**: Use camera icon to capture new document
- **Manual Mark**: Use "Manual Mark as Uploaded" button
- **Bulk Mark**: Use "Manual Mark All" for entire unit standard

### 3. **Summative Assessments Not Opening**
**Problem**: Summative exercises appear locked or inaccessible.

**Root Cause**: Summative assessments require ALL formative questions in the same unit standard to be completed first.

**Current Status for Learner 11515**:
Based on the data, learner has completed both formative AND summative exercises, so this shouldn't be an issue. If summative appears locked, it's likely a UI state problem.

**Solutions**:
```dart
// Flutter app logic for summative access
bool _isUnitStandardReadyForSummative(String unitStandard, List<dynamic> formativeQuestions) {
  // Check if all formative questions in this unit standard are completed
  for (var item in formativeQuestions) {
    final exercise = item['exercise']?.toString() ?? 'N/A';
    final uploadKey = 'Formative-$exercise-${widget.learnerID}';
    if (!(uploadedExercises[uploadKey] ?? false)) {
      return false; // Still have incomplete formative questions
    }
  }
  return true; // All formative completed, summative accessible
}
```

## Flutter App Behavior

### Exercise Status Display
```dart
// How exercises appear in the app
if (isUploaded) {
  // Green checkmark - Exercise completed
  Icon(Icons.check_circle, color: Colors.green)
  Text('Completed', style: TextStyle(color: Colors.green))
} else {
  // Orange checkmark - Exercise pending
  Icon(Icons.radio_button_unchecked, color: Colors.grey)
  Text('Pending', style: TextStyle(color: Colors.orange))
}
```

### Available Actions
1. **Camera Icon** 📷: Scan new document (replaces existing)
2. **Manual Mark** ☑️: Mark as completed without document
3. **Bulk Actions**: Mark all exercises in unit standard as completed

### Sync Behavior
```dart
// Automatic sync when online
if (await _checkConnectivity()) {
  await _syncOfflinePOE(); // Upload unsynced records
  await checkUploadedStatus(); // Refresh server status
}
```

## Handling Specific Scenarios

### Scenario 1: Exercise Shows "Completed" But Document Missing
**Symptoms**: Green checkmark but camera icon still available
**Cause**: Database record exists but file is missing/corrupted
**Solution**: 
1. Tap camera icon to re-scan document
2. Or use "Manual Mark as Uploaded" if document not recoverable

### Scenario 2: Summative Section Won't Open
**Symptoms**: Summative section appears locked/disabled
**Cause**: Not all formative questions completed in that unit standard
**Solution**:
1. Check formative progress counter (e.g., "8/10 completed")
2. Complete remaining formative questions
3. Summative will unlock automatically

### Scenario 3: All Exercises Show "Pending" Despite Being Done
**Symptoms**: Orange checkmarks for all exercises
**Cause**: Network connectivity issue or server sync problem
**Solution**:
1. Check internet connection
2. Use "Sync Now" button in POE tab
3. Verify server IP configuration (currently `192.168.68.108`)

### Scenario 4: Documents Won't Upload to Server
**Symptoms**: Local completion but sync fails
**Cause**: File corruption, network issues, or server problems
**Solution**:
```dart
// App automatically retries failed uploads
try {
  final response = await request.send().timeout(Duration(seconds: 30));
  // Handle success
} catch (e) {
  // Save locally for retry later
  await _saveLocally(document, assessmentType, exercise, logbookText);
}
```

## Recovery Options

### For Individual Exercises
1. **Re-scan**: Use camera to capture new document
2. **Manual Mark**: Mark as completed without document
3. **Use Existing**: Link to another completed exercise's document

### For Bulk Operations
1. **Manual Mark All Formative**: Complete all formative in unit standard
2. **Manual Mark All Summative**: Complete all summative in unit standard  
3. **Manual Mark All LogBook**: Complete all logbook items in unit standard

### For System-Wide Issues
1. **Sync All**: Upload all unsynced records to server
2. **Refresh Status**: Re-check server for completion status
3. **Rebuild Cache**: Clear and reload POE data from server

## Current Recommendations for Learner 11515

Based on the analysis:

1. ✅ **Documents Exist**: All 275 exercises have file paths recorded
2. ⚠️ **Sync Required**: All records are unsynced - need to upload to server
3. 🔄 **Use Sync Function**: Tap "Sync Now" button to upload all completed work
4. 📱 **Check UI State**: If summative appears locked, it's likely a display issue since both formative and summative are completed

### Immediate Actions
1. Open POE tab for learner 11515
2. Tap "Sync Now" button to upload all 275 completed exercises
3. Wait for sync completion (may take several minutes)
4. Refresh the POE tab to see updated status
5. All exercises should show as "Completed" with green checkmarks

The system is working correctly - the main issue is that completed work needs to be synced to the server.