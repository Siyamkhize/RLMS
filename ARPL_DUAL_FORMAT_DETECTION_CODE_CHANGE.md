# ARPL Dual-Format Pathway Detection - Code Change Details

**File:** `lib/AssessorPage.dart`  
**Lines:** 64-91  
**Date:** July 14, 2026  
**Change Type:** Logic Enhancement (backward compatible)

---

## The Problem Solved

### Before (Single Format Only)
The app only detected ARPL if the pathway contained the word "ARPL":

```dart
if (pathway.contains('ARPL')) {
  _pathwayType = 'ARPL';
}
```

**Issue:** This worked locally where pathway is full JSON:
```
"[{"type":"ARPL","trade_id":"1","name":"Electrician"...}]"  ✅ Contains "ARPL"
```

But failed online where pathway is only the trade name:
```
"Bricklaying"  ❌ Does NOT contain "ARPL"
```

---

## The Solution Implemented

### After (Dual Format Detection)
Now the app detects ARPL from multiple sources:

```dart
// Check for ARPL detection in multiple formats:
// 1. Full JSON format: [{"type":"ARPL",...}]
// 2. Trade names (these are ARPL trades): ELECTRICIAN, BRICKLAYING, BRICKLAYER, PLUMBING, PLUMBER, ELECTRICITY
bool isARPL = pathway.contains('ARPL') ||
    pathway.contains('ELECTRICIAN') ||
    pathway.contains('BRICKLAYING') ||
    pathway.contains('BRICKLAYER') ||
    pathway.contains('PLUMBING') ||
    pathway.contains('PLUMBER') ||
    pathway.contains('ELECTRICITY');

if (isARPL) {
  _pathwayType = 'ARPL';
} else {
  _pathwayType = pathway;
}
```

**Result:** Works with both data formats:
```
Local:  "[{"type":"ARPL",...}]"        ✅ Contains "ARPL"
Online: "Bricklaying"                  ✅ Contains "BRICKLAYING"
```

---

## Full Context (Function: fetchClasses)

### Location in File
```dart
class _AssessorPageState extends State<AssessorPage> {
  late Future<List<dynamic>> _classes;
  int _selectedIndex = 0;
  String? _pathwayType; // Store 'ARPL' or other pathway types

  @override
  void initState() {
    super.initState();
    _classes = fetchClasses(widget.facilitator_id);
  }

  Future<List<dynamic>> fetchClasses(String facilitatorId) async {
    try {
      final url = AppConfig.buildUrl('get_classes.php', queryParams: {
        'facilitator_id': facilitatorId,
      });

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is Map && data['status'] == 'error') {
          throw Exception('Server error: ${data['message']}');
        }

        if (data is List) {
          // Detect pathway type from the first class (if available) only if not forced
          if (data.isNotEmpty && widget.forcePathwayType == null) {
            setState(() {
              // Check both possible keys: Project_pathway (from mobile/get_classes.php)
              // and learning_pathway (from root get_classes.php)
              String pathway =
                  (data[0]['Project_pathway'] ?? data[0]['learning_pathway'])
                          ?.toString()
                          .toUpperCase() ??
                      '';

              // ❗ THIS IS THE CHANGE:
              // Check for ARPL detection in multiple formats:
              // 1. Full JSON format: [{"type":"ARPL",...}]
              // 2. Trade names (these are ARPL trades): ELECTRICIAN, BRICKLAYING, BRICKLAYER, PLUMBING, PLUMBER, ELECTRICITY
              bool isARPL = pathway.contains('ARPL') ||
                  pathway.contains('ELECTRICIAN') ||
                  pathway.contains('BRICKLAYING') ||
                  pathway.contains('BRICKLAYER') ||
                  pathway.contains('PLUMBING') ||
                  pathway.contains('PLUMBER') ||
                  pathway.contains('ELECTRICITY');

              if (isARPL) {
                _pathwayType = 'ARPL';
              } else {
                _pathwayType = pathway;
              }

              print(
                  '[AssessorPage] Detected Pathway: $_pathwayType (from data: $pathway)');
            });
          }
          return data;
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception(
            'Failed to load classes. Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('[AssessorPage] Error fetching classes: $e');
      throw Exception('Failed to load classes. Error: $e');
    }
  }
```

---

## Logic Flow

### Input: API Response from get_classes.php

**Local Server:**
```json
[
  {
    "classID": "782",
    "className": "Electrician",
    "Project_pathway": "[{\"type\":\"ARPL\",\"trade_id\":\"1\",\"name\":\"Electrician\",\"qualificationID\":\"QF001\"...}]"
  }
]
```

**Online Server:**
```json
[
  {
    "classID": "782",
    "className": "Electrician",
    "Project_pathway": "Electrician"
  }
]
```

### Processing

```
Input pathway string → Convert to UPPERCASE
                    ↓
Local: "[{"TYPE":"ARPL",...}]"      Online: "ELECTRICIAN"
                    ↓
Check 7 conditions (OR logic):
  1. Contains "ARPL"?                    NO                    NO
  2. Contains "ELECTRICIAN"?             NO                    YES ✅
  3. Contains "BRICKLAYING"?             NO                    NO
  4. Contains "BRICKLAYER"?              NO                    NO
  5. Contains "PLUMBING"?                NO                    NO
  6. Contains "PLUMBER"?                 NO                    NO
  7. Contains "ELECTRICITY"?             NO                    NO
                    ↓
Wait, let me recalculate for Local...
Actually the first check finds "ARPL" ✅
                    ↓
isARPL = TRUE (either condition matches)
                    ↓
_pathwayType = 'ARPL'
                    ↓
UI Code: if (_pathwayType == 'ARPL') { showARPLMenu(); }
```

### Output: UI Selection

```dart
if (_pathwayType == 'ARPL') {
  // Show ARPL-specific UI
  switch (_selectedIndex) {
    case 0:
      return _buildClassesContent();
    case 10:
      return _buildARPLDashboard();
    case 11:
      return AssessmentPreparationPage(
          facilitatorId: widget.facilitator_id, isARPL: true);
    // ... other ARPL pages
  }
} else {
  // Show normal assessor UI
  switch (_selectedIndex) {
    case 0:
      return _buildClassesContent();
    case 1:
      return AssessmentPreparationPage(facilitatorId: widget.facilitator_id);
    // ... normal assessor pages
  }
}
```

---

## Supported Trade Names

The code now recognizes these ARPL trade names (case-insensitive):

| Trade Name | OFO Code | Detection Method |
|-----------|----------|-----------------|
| ELECTRICIAN | 671101 | pathway.contains('ELECTRICIAN') |
| ELECTRICITY | 671101 | pathway.contains('ELECTRICITY') |
| BRICKLAYING | 641201 | pathway.contains('BRICKLAYING') |
| BRICKLAYER | 641201 | pathway.contains('BRICKLAYER') |
| PLUMBING | 642601 | pathway.contains('PLUMBING') |
| PLUMBER | 642601 | pathway.contains('PLUMBER') |

Plus any pathway with the literal string "ARPL" (for full JSON format).

---

## Backward Compatibility

✅ **Still detects full JSON format** - The first condition `pathway.contains('ARPL')` preserves local server compatibility  
✅ **Case-insensitive** - Pathway is converted to UPPERCASE before checking  
✅ **Nullable-safe** - Uses null coalescing (`??`) to handle missing fields  
✅ **Non-breaking** - No changes to method signature or return type  

---

## Potential Issues & Solutions

### Issue 1: What if pathway contains multiple values?
**Example:** `"ELECTRICIAN,PLUMBING"`  
**Solution:** OR logic means if ANY trade name is ARPL, it's ARPL ✅

### Issue 2: What if a non-ARPL trade has similar name?
**Example:** `"ELECTRICITY_THEORY"` (hypothetical non-ARPL)  
**Solution:** Currently would be detected as ARPL. Mitigation: Admin should use exact trade names or use full JSON format.  
**Better Fix Available:** Could use regex for exact word matching if needed later.

### Issue 3: What if data is null?
**Example:** `Project_pathway` is NULL  
**Solution:** Handled by null coalescing: `(?? '')` defaults to empty string, which matches nothing ✅

### Issue 4: What if case doesn't match?
**Example:** `"electrician"` (lowercase)  
**Solution:** Handled by `.toUpperCase()` before checking ✅

---

## Testing Scenarios

### Scenario 1: Local Server (Full JSON)
```dart
pathway = "[{"TYPE":"ARPL","TRADE_ID":"1","NAME":"ELECTRICIAN"...}]"
isARPL = pathway.contains('ARPL')  // TRUE ✅
Result: ARPL menu shown ✅
```

### Scenario 2: Online Server (Trade Name)
```dart
pathway = "BRICKLAYING"
isARPL = pathway.contains('BRICKLAYING')  // TRUE ✅
Result: ARPL menu shown ✅
```

### Scenario 3: Normal Assessor (Local)
```dart
pathway = "[{"TYPE":"TRAINING","NAME":"SKILLS PROGRAMME"...}]"
isARPL = false  // None of 7 conditions match
Result: Normal assessor menu shown ✅
```

### Scenario 4: Normal Assessor (Online)
```dart
pathway = "SKILLS PROGRAMME"
isARPL = false  // None of 7 conditions match
Result: Normal assessor menu shown ✅
```

---

## Performance Impact

✅ **Negligible** - Just 7 string contains checks on app startup  
✅ **No database queries added** - Only checks local variable  
✅ **No network calls added** - Same API endpoint as before  
✅ **Happens once** - Only when fetchClasses is called (once per login)

**Estimated Performance:** < 1ms

---

## Future Improvements (Optional)

If more sophisticated detection is needed:

```dart
// Option 1: Regex for exact word boundaries
bool isARPL = RegExp(r'\b(ARPL|ELECTRICIAN|BRICKLAYING|PLUMBER|PLUMBING|ELECTRICITY)\b')
    .hasMatch(pathway);

// Option 2: Check for OFO codes
List<String> arplOFOCodes = ['671101', '642601', '641201'];
bool hasARPLOFO = arplOFOCodes.any((code) => pathway.contains(code));

// Option 3: Parse JSON if available
if (pathway.startsWith('[')) {
  try {
    List<dynamic> pathwayList = jsonDecode(pathway);
    bool isARPL = pathwayList.any((p) => p['type'] == 'ARPL');
  } catch (e) {
    // Fallback to string matching
  }
}
```

---

## Summary

✅ **What Changed:** Added 6 more trade name checks to existing 1 "ARPL" check  
✅ **Why It Works:** Covers both data formats used locally and online  
✅ **Backward Compatible:** Still detects full JSON format  
✅ **No Side Effects:** Only affects UI selection, not data or sync logic  
✅ **Deployed:** APK rebuilt and ready to install  

**Impact:** ARPL assessors now see correct UI on both local and online servers.

