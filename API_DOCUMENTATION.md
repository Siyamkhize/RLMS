# ARPL Trade API Documentation
**Version:** 1.0  
**Date:** July 9, 2026

---

## Endpoint: Get Class Trade Information

### Overview
Retrieves trade information for a specific class, including OFO number and trade name. Used by mobile app to determine which ARPL form to display.

### URL
```
POST https://rlms.rlms.co.za/mobile/get_class_trade_info.php
```

### Method
- **POST** (Recommended - sends JSON body)
- **GET** (Also supported - query parameters)

### Request Headers
```
Content-Type: application/json
```

---

## Request Examples

### JSON Body (POST)
```json
{
  "classID": 783
}
```

### Query Parameters (GET)
```
GET https://rlms.rlms.co.za/mobile/get_class_trade_info.php?classID=783
```

### PHP Form Data (POST)
```
classID: 783
```

---

## Response Format

### Success Response (HTTP 200)
```json
{
  "status": "success",
  "classID": 783,
  "className": "Bricklaying",
  "trade_id": 4,
  "trade_name": "Bricklaying",
  "ofo_number": "671103",
  "siteName": "Training Site Name"
}
```

### Error Response (HTTP 400)
```json
{
  "status": "error",
  "message": "Class not found with ID: 999"
}
```

---

## Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | "success" or "error" |
| `classID` | integer | The requested class ID |
| `className` | string | Human-readable class name |
| `trade_id` | integer | Reference to arpl_trades table |
| `trade_name` | string | Trade name (e.g., "Bricklaying") |
| `ofo_number` | string | OFO qualification number |
| `siteName` | string | Training site name |
| `message` | string | Error message (on error) |

---

## OFO Number Mapping

| OFO Number | Trade Name | Form Page |
|------------|-----------|-----------|
| 671101 | Electrician | ArplToolkitViewerPage |
| 671102 | Plumber | ArplToolkitPlumberPage |
| 671103 | Bricklayer | ArplToolkitBricklayerPage |

---

## Database Query

```sql
SELECT 
  c.classID,
  c.className,
  c.trade_id,
  t.trade_name,
  t.ofo_number,
  s.siteName
FROM class c
LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
LEFT JOIN sites s ON c.siteID = s.siteID
WHERE c.classID = ?
LIMIT 1
```

### Related Tables
- `class` - Contains classID, className, trade_id, siteID
- `arpl_trades` - Contains trade_id, trade_name, ofo_number
- `sites` - Contains siteID, siteName

---

## Usage Examples

### JavaScript/Dart
```dart
Future<Map<String, dynamic>> getClassTradeInfo(int classID) async {
  final response = await http.post(
    Uri.parse('https://rlms.rlms.co.za/mobile/get_class_trade_info.php'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'classID': classID}),
  );
  
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to get class trade info');
  }
}
```

### cURL
```bash
curl -X POST https://rlms.rlms.co.za/mobile/get_class_trade_info.php \
  -H "Content-Type: application/json" \
  -d '{"classID": 783}'
```

### PHP
```php
$classID = 783;
$data = json_encode(['classID' => $classID]);

$ch = curl_init('https://rlms.rlms.co.za/mobile/get_class_trade_info.php');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$response = json_decode(curl_exec($ch), true);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);
```

---

## Test Cases

### Test 1: Valid Bricklaying Class
**Request:**
```json
{"classID": 783}
```

**Expected Response:**
```json
{
  "status": "success",
  "classID": 783,
  "className": "Bricklaying",
  "trade_id": 4,
  "trade_name": "Bricklaying",
  "ofo_number": "671103",
  "siteName": "..."
}
```

### Test 2: Valid Electrician Class
**Request:**
```json
{"classID": 782}
```

**Expected Response:**
```json
{
  "status": "success",
  "classID": 782,
  "className": "lowest",
  "trade_id": 1,
  "trade_name": "Electrician",
  "ofo_number": "671101",
  "siteName": "..."
}
```

### Test 3: Invalid Class ID
**Request:**
```json
{"classID": 99999}
```

**Expected Response:**
```json
{
  "status": "error",
  "message": "Class not found with ID: 99999"
}
```

### Test 4: Missing Parameter
**Request:**
```json
{}
```

**Expected Response:**
```json
{
  "status": "error",
  "message": "Missing or invalid classID parameter"
}
```

---

## Error Handling

### HTTP Status Codes
- **200 OK** - Request successful (check `status` field in JSON for success/error)
- **400 Bad Request** - Invalid parameters or database error

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Missing or invalid classID parameter" | ClassID not provided or not a number | Send valid classID as integer |
| "Class not found with ID: XXX" | ClassID doesn't exist in database | Verify classID exists in class table |
| Connection timeout | Server not responding | Check server connectivity |
| Database error | Connection issue | Check database connection |

---

## Performance Notes

- **Response Time:** 50-200ms typical
- **Database Query:** Uses indexed columns (classID, trade_id)
- **Caching:** Recommended to cache results for 1+ hour (trade assignments rarely change)

---

## Implementation in ARPL Toolkit

### Dart Integration
```dart
// In ViewCompleteToolkitPage._fetchOfoForClass()
Future<String?> _fetchOfoForClass(String classId) async {
  try {
    print('[TOOLKIT_DEBUG] Fetching OFO for classID: $classId');

    final response = await http.post(
      Uri.parse(
        'https://rlms.rlms.co.za/mobile/get_class_trade_info.php',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'classID': int.parse(classId)}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success' && data['ofo_number'] != null) {
        return data['ofo_number'].toString();
      }
    }
    return '671101'; // Default to Electrician
  } catch (e) {
    print('[TOOLKIT_DEBUG] Exception: $e');
    return '671101';
  }
}
```

---

## Related Endpoints

### Get All ARPL Toolkit Data
```
POST /mobile/get_arpl_toolkit_data.php
```
Returns complete toolkit including all appendices

### Save Appendix F Assessment
```
POST /mobile/save_arpl_appendix_f_assessment.php
```
Saves practical assessment results

---

## File Location

**Server Path:** `/var/www/html/mobile/get_class_trade_info.php`  
**Repository Path:** `mobile/get_class_trade_info.php`  
**Lines:** ~70  

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-07-09 | Initial release |

---

## Support

For issues or improvements, refer to:
- API_TRADE_FIX_COMPLETE.md - Full technical documentation
- QUICK_TEST_GUIDE.md - Quick testing guide
- ArplAssessorPage.dart - Dart implementation

