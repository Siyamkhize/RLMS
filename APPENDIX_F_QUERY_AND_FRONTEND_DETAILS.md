# Appendix F: Query and Frontend Details

## The Queries Being Used

### DELETE Query (Before Save)
**File:** `mobile/save_appendix_f_data.php` - Line 96 & 153

```sql
-- Knowledge Section
DELETE FROM arpl_appendix_f_knowledge 
WHERE learnerID = 11701 AND ofoNumber = '641201';

-- Practical Section  
DELETE FROM arpl_appendix_f_practical_tasks 
WHERE learnerID = 11701 AND ofoNumber = '641201';
```

**Column Used:** `ofoNumber` (camelCase) ✅

### INSERT Query (Save New Data)
```sql
INSERT INTO arpl_appendix_f_knowledge 
(learnerID, ofoNumber, question_number, question_text, candidate_score, percentage, assessor_id)
VALUES (11701, '641201', 1, 'Question text...', 0, 0.0, 6);
```

**Column Used:** `ofoNumber` (camelCase) ✅

### SELECT Query (Load Data)
**File:** `mobile/get_appendix_f_data.php` - Line 70 & 105

```sql
SELECT id, question_number, question_text, candidate_score, percentage, 
       assessor_id, created_at, updated_at
FROM arpl_appendix_f_knowledge
WHERE learnerID = 11701 AND ofoNumber = '641201'
ORDER BY question_number ASC;
```

**Column Used:** `ofoNumber` (camelCase) ✅

## Frontend Page Code

### File: `lib/ArplToolkitViewerPage.dart`

#### Save Function (Lines 420-540)
```dart
Future<void> _saveAllChanges() async {
  setState(() {
    _isSaving = true;
  });

  try {
    // ══════════════════════════════════════════════════════════
    // APPENDIX F - SAVE TO NEW REDESIGNED ENDPOINT
    // ══════════════════════════════════════════════════════════
    if (_knowledgeQuestions.isNotEmpty ||
        _practicalTasks.isNotEmpty ||
        _workplaceObservations.isNotEmpty) {
      
      // Build URL from config
      final appendixFUrl = AppConfig.saveAppendixFDataUrl;
      // Result: https://rlms.rlms.co.za/mobile/save_appendix_f_data.php
      
      // Build payload
      final appendixFData = {
        'learnerID': widget.learnerID,        // Example: 11701
        'ofoNumber': widget.ofoNumber,        // Example: '641201'
        'assessor_id': 6,
        'knowledge': _knowledgeQuestions.map((q) => q.toJson()).toList(),
        'practical': _practicalTasks.map((t) => t.toJson()).toList(),
        'workplace_observations': _workplaceObservations.map((o) => o.toJson()).toList(),
      };

      // Make POST request
      final responseF = await http.post(
        Uri.parse(appendixFUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(appendixFData),
      );

      if (responseF.statusCode != 200) {
        // ERROR HANDLING - This is where user sees the error
        String errorMsg = 'Failed to save Appendix F: ${responseF.statusCode}';
        try {
          final errorData = jsonDecode(responseF.body);
          if (errorData['message'] != null) {
            errorMsg = '${errorData['message']}';  // ⚠️ Error shown to user
          }
        } catch (e) {
          // Can't parse error
        }
        throw Exception(errorMsg);
      }
    }

    // Success!
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Changes saved successfully'),
        backgroundColor: Color(0xFF006341),
      ),
    );
  } catch (e) {
    // ⚠️ ERROR DISPLAYED HERE
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error saving: $e'),  // User sees this
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

#### Load Function (Lines 200-350)
```dart
Future<void> _loadAppendixFData() async {
  try {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/get_appendix_f_data.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'learnerID': widget.learnerID,  // Example: 11701
        'ofoNumber': widget.ofoNumber,  // Example: '641201'
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        // Load data into UI
        setState(() {
          _knowledgeQuestions.clear();
          for (var item in data['data']['knowledge']) {
            _knowledgeQuestions.add(KnowledgeQuestion(...));
          }
          // ... load practical and observations
        });
      }
    }
  } catch (e) {
    print('❌ Error loading Appendix F data: $e');
  }
}
```

## How Error Message Reaches User

```
1. User clicks "Save" button
   ↓
2. Flutter calls: POST https://rlms.rlms.co.za/mobile/save_appendix_f_data.php
   ↓
3. PHP receives JSON payload with ofoNumber='641201'
   ↓
4. PHP tries: DELETE FROM arpl_appendix_f_knowledge WHERE ... AND ofoNumber = '641201'
   ↓
5a. IF database has column "ofoNumber" → DELETE succeeds ✅
5b. IF database has column "ofo_number" → DELETE fails with MySQL error ❌
   ↓
6. PHP returns JSON response:
   {
     "status": "error",
     "message": "Unknown column 'ofoNumber' in 'where clause'"
   }
   ↓
7. Flutter receives error response (statusCode = 400 or 500)
   ↓
8. Flutter shows red SnackBar: "Error saving: Unknown column 'ofoNumber' in 'where clause'"
```

## The Problem

**IF** the error message says "Unknown column ofoNumber", it means:

1. **PHP code is using:** `ofoNumber` (camelCase) ✅ Correct
2. **Database has column named:** `ofo_number` (snake_case) ❌ Wrong!

**Solution:** The database column name needs to be changed from `ofo_number` to `ofoNumber`

OR

**IF** the database already has `ofoNumber`, then the error is coming from somewhere else (cached file, different server, etc.)

## Next Action

Run this query on production database to confirm column name:
```sql
SHOW COLUMNS FROM arpl_appendix_f_knowledge WHERE Field LIKE '%ofo%';
SHOW COLUMNS FROM arpl_appendix_f_practical_tasks WHERE Field LIKE '%ofo%';
SHOW COLUMNS FROM arpl_appendix_f_workplace_observations WHERE Field LIKE '%ofo%';
```

**Expected result:** Field = `ofoNumber`
**If you see:** Field = `ofo_number` → Database needs ALTER TABLE to rename column
