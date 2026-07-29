# Online Bank Details Check Endpoint

## Overview
This endpoint provides **ONLINE DATABASE** checking of bank details in real-time. It checks the **SERVER DATABASE DIRECTLY** - not the local app database. This completely bypasses any local sync issues and provides immediate access to the current server state.

## Key Features
- ✅ **Online Database Only** - Checks server database directly
- ✅ **No Local Dependency** - Bypasses app's local database completely  
- ✅ **Real-time Server Data** - Always current, no sync delays
- ✅ **Sync-Independent** - Works regardless of local sync status

## Endpoint Details
- **File**: `mobile/check_bank_details.php`
- **Methods**: GET, POST
- **Database**: **ONLINE/SERVER DATABASE** (not local)
- **Purpose**: Real-time server bank details check

## Usage

### GET Request
```
GET mobile/check_bank_details.php?learner_id=11453
```

### POST Request
```
POST mobile/check_bank_details.php
Content-Type: application/json

{
    "learner_id": "11453"
}
```

## Response Format

### Success Response (Bank Details Only)
```json
{
    "success": true,
    "learner_id": "11453",
    "has_bank_details": true,
    "bank_details": {
        "bank_id": 3317,
        "bank_name": "ABSA Bank",
        "bank_type": "Cheque",
        "account_number": "265",
        "bank_code": "632005",
        "synced": 1
    },
    "source": "online_database",
    "timestamp": "2026-04-09 15:10:44"
}
```

### No Bank Details Response
```json
{
    "success": true,
    "learner_id": "11453",
    "has_bank_details": false,
    "bank_details": null,
    "source": "online_database",
    "timestamp": "2026-04-09 15:10:44"
}
```

### Error Response
```json
{
    "success": false,
    "error": "learner_id is required"
}
```

## Integration with App

### How to Use in Flutter App

1. **Call this endpoint** when checking if bank details exist
2. **Don't wait for sync** - get immediate results
3. **Use the response** to determine if bank capture is needed

### Example Flutter Integration
```dart
Future<bool> checkBankDetailsExist(String learnerId) async {
  try {
    final response = await http.post(
      Uri.parse('${Config.baseUrl}/mobile/check_bank_details.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'learner_id': learnerId}),
    );
    
    final data = json.decode(response.body);
    
    if (data['success'] && data['has_bank_details']) {
      // Bank details exist - don't ask user to capture
      return true;
    } else {
      // No bank details - ask user to capture
      return false;
    }
  } catch (e) {
    // Error - fallback to existing workflow
    return false;
  }
}
```

## Benefits

1. **Real-time Check**: No waiting for sync
2. **Immediate Response**: App knows instantly if bank details exist
3. **Better UX**: No unnecessary bank capture requests
4. **Non-disruptive**: Doesn't change existing workflow, just adds check

## Test Results

✅ **Tested for learner 11453**:
- Bank details found: ABSA Bank, Cheque account #265
- Bank confirmation document: Present
- Response time: Immediate
- Status: Working perfectly

## Usage Recommendation

Call this endpoint **before** showing bank capture form:
1. User opens learner details
2. App calls `check_bank_details.php`
3. If `has_bank_details: true` → Skip bank capture
4. If `has_bank_details: false` → Show bank capture form

This solves the sync issue by providing real-time server data without changing the existing offline workflow.