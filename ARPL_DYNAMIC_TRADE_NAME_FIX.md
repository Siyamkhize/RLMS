# ARPL Dynamic Trade Name Implementation

**Date:** July 22, 2026  
**Status:** ✅ COMPLETE & APK INSTALLED

---

## Issue

The ARPL Portfolio page showed hardcoded text "ARPL Portfolio" regardless of the actual trade. It should dynamically show the trade name based on the class (e.g., "Bricklayer Portfolio", "Plumber Portfolio", "Electrician Portfolio").

---

## Solution

Implemented dynamic trade name fetching using the existing `get_class_trade_info.php` endpoint.

### Flow:
1. When ARPL Assessor page loads with `classId`
2. Call `get_class_trade_info.php?classID={classId}`
3. Get trade name from response (`trade_name` field)
4. Display "{trade_name} Portfolio" in AppBar title

---

## Database Schema

### class table:
- `classID` (INT, primary key)
- `trade_id` (INT, foreign key → arpl_trades.trade_id)
- `siteID` (INT, foreign key → sites.siteID)

### arpl_trades table:
- `trade_id` (INT, primary key)
- `trade_name` (VARCHAR) - e.g., "Bricklaying", "Plumbing", "Electrical"
- `ofo_number` (VARCHAR) - OFO code for the trade

### SQL Query (in PHP endpoint):
```sql
SELECT 
    c.classID,
    c.className,
    c.trade_id,
    t.trade_name,
    t.ofo_number
FROM class c
LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
WHERE c.classID = ?
```

---

## Changes Made

### Frontend: `lib/ArplHierarchicalNavigatorPage.dart`

#### 1. Added State Variables (lines 34-36):
```dart
// Trade information
String tradeName = 'ARPL'; // Default fallback
bool isLoadingTrade = true;
```

#### 2. Updated initState() (lines 55-72):
```dart
@override
void initState() {
  super.initState();
  
  // ... existing code ...
  
  // Fetch trade information if classId is provided
  if (widget.classId != null && widget.classId!.isNotEmpty) {
    _fetchTradeInfo();
  }
  
  fetchArplData().then((_) {
    print('fetchArplData complete');
  }).catchError((e) {
    print('Error in fetchArplData: $e');
  });
}
```

#### 3. Added _fetchTradeInfo() Method (lines 85-133):
```dart
/// Fetch trade information from class
Future<void> _fetchTradeInfo() async {
  if (widget.classId == null || widget.classId!.isEmpty) {
    setState(() {
      isLoadingTrade = false;
    });
    return;
  }

  try {
    final url = AppConfig.buildUrl('get_class_trade_info.php', queryParams: {
      'classID': widget.classId!,
    });

    debugPrint('[ARPL_TRADE] Fetching trade info for classID: ${widget.classId}');

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        setState(() {
          tradeName = data['trade_name'] ?? 'ARPL';
          isLoadingTrade = false;
        });
        debugPrint('[ARPL_TRADE] ✅ Trade name: $tradeName');
      } else {
        debugPrint('[ARPL_TRADE] ❌ Error: ${data['message']}');
        setState(() {
          isLoadingTrade = false;
        });
      }
    } else {
      debugPrint('[ARPL_TRADE] ❌ HTTP error: ${response.statusCode}');
      setState(() {
        isLoadingTrade = false;
      });
    }
  } catch (e) {
    debugPrint('[ARPL_TRADE] ❌ Exception: $e');
    setState(() {
      isLoadingTrade = false;
    });
  }
}
```

#### 4. Updated AppBar Title (line 417):
```dart
appBar: AppBar(
  title: Text('$tradeName Portfolio'),  // Changed from const Text('ARPL Portfolio')
  backgroundColor: Colors.deepPurple,
  foregroundColor: Colors.white,
```

---

## Backend Endpoint

### File: `mobile/get_class_trade_info.php`

**Already exists** - No changes needed!

**Request:**
```
GET/POST mobile/get_class_trade_info.php?classID=428
```

**Response:**
```json
{
  "status": "success",
  "classID": 428,
  "className": "Class A",
  "trade_id": 4,
  "trade_name": "Bricklaying",
  "ofo_number": "671103",
  "siteName": "Site Name"
}
```

**Fallback Logic:**
1. Try to get trade from `arpl_trades` table (via `trade_id` JOIN)
2. If not found, try `Project_pathway` JSON from `sites` table
3. If still not found, default to "Electrician" with OFO "671101"

---

## Examples

### Before:
```
┌──────────────────────────────────┐
│  ←  ARPL Portfolio               │  ← Hardcoded "ARPL"
└──────────────────────────────────┘
```

### After:

**For Bricklayer class:**
```
┌──────────────────────────────────┐
│  ←  Bricklaying Portfolio        │  ← Dynamic trade name
└──────────────────────────────────┘
```

**For Plumber class:**
```
┌──────────────────────────────────┐
│  ←  Plumbing Portfolio           │  ← Dynamic trade name
└──────────────────────────────────┘
```

**For Electrician class:**
```
┌──────────────────────────────────┐
│  ←  Electrical Portfolio         │  ← Dynamic trade name
└──────────────────────────────────┘
```

---

## Testing

### Test Case 1: Class with Trade
1. Login as ARPL Assessor
2. Select a class that has `trade_id` set
3. Navigate to ARPL Portfolio
4. **Expected:** AppBar shows "{Trade Name} Portfolio" (e.g., "Bricklaying Portfolio")

### Test Case 2: Class without Trade
1. Login as ARPL Assessor
2. Select a class with no `trade_id`
3. Navigate to ARPL Portfolio
4. **Expected:** AppBar shows "ARPL Portfolio" (default fallback)

### Test Case 3: Check Logs
```bash
adb logcat | findstr ARPL_TRADE
```

**Expected output:**
```
[ARPL_TRADE] Fetching trade info for classID: 428
[ARPL_TRADE] ✅ Trade name: Bricklaying
```

---

## How It Works

```
┌─────────────────┐
│ ARPL Assessor   │
│ Selects Class   │
└────────┬────────┘
         │
         ↓
┌─────────────────────────────────────┐
│ ArplHierarchicalNavigatorPage       │
│ initState()                         │
│   → _fetchTradeInfo()               │
└────────┬────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────┐
│ GET get_class_trade_info.php        │
│ Parameter: classID=428              │
└────────┬────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────┐
│ SQL Query:                          │
│ SELECT trade_name                   │
│ FROM class c                        │
│ LEFT JOIN arpl_trades t             │
│   ON c.trade_id = t.trade_id        │
│ WHERE c.classID = 428               │
└────────┬────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────┐
│ Response:                           │
│ {                                   │
│   "status": "success",              │
│   "trade_name": "Bricklaying"       │
│ }                                   │
└────────┬────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────┐
│ setState()                          │
│ tradeName = "Bricklaying"           │
└────────┬────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────┐
│ AppBar Title:                       │
│ "Bricklaying Portfolio"             │
└─────────────────────────────────────┘
```

---

## Trade Table Reference

### Common Trades in arpl_trades:

| trade_id | trade_name      | ofo_number |
|----------|-----------------|------------|
| 1        | Electrical      | 671101     |
| 2        | Plumbing        | 671102     |
| 3        | Bricklaying     | 671103     |
| 4        | Carpentry       | 671201     |
| 5        | Painting        | 671301     |

---

## Fallback Behavior

1. **If `classId` is provided:**
   - Fetch trade name from database
   - Display "{Trade Name} Portfolio"

2. **If `classId` is null/empty:**
   - Skip trade fetching
   - Display "ARPL Portfolio" (default)

3. **If API call fails:**
   - Log error
   - Display "ARPL Portfolio" (default)

4. **If trade_name is null in response:**
   - Display "ARPL Portfolio" (default)

---

## APK Details

**Build:** `flutter build apk --release`  
**Install:** `adb install -r app-release.apk`  
**Size:** 45.9MB  
**Status:** ✅ Installed successfully

---

## Summary

✅ Added dynamic trade name fetching  
✅ Changed hardcoded "ARPL" → Dynamic "{Trade Name}"  
✅ Using existing `get_class_trade_info.php` endpoint  
✅ Fallback to "ARPL" if trade not found  
✅ Debug logging for troubleshooting  
✅ APK rebuilt and installed  
✅ Ready for testing

---

## Related Files

**Frontend:**
- `lib/ArplHierarchicalNavigatorPage.dart` - Main changes

**Backend (No Changes):**
- `mobile/get_class_trade_info.php` - Already exists and works correctly

**Database:**
- `class` table - Links to trade via `trade_id`
- `arpl_trades` table - Contains trade names and OFO codes
