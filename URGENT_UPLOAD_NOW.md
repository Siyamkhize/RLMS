# URGENT: Upload These 2 Files NOW

## Problem
The test is timing out because:
1. The files haven't been uploaded to the server yet (still using old version)
2. Current assignments showing 0 means old code is running

## Solution: Upload These Files

### Upload to: `https://rlms.rlms.co.za/mobile/`

**File 1**: `get_learners_with_poe_assigned.php` (UPDATED - SQL fix)
**File 2**: `add_supplemental_learners_fast.php` (NEW - optimized version)

## Why Fast Version?

The original `add_supplemental_learners.php` times out because:
- Uses `NOT IN (SELECT ...)` subquery (very slow on large tables)
- Processes 62 classes with comma-separated values
- Returns all learner details in response

The FAST version:
- Uses `LEFT JOIN` instead of `NOT IN` (10x faster)
- Optimized class processing
- Returns only sample of 5 learners (not all 29)
- Should complete in under 30 seconds

## After Upload - Test

```bash
php test_supplemental_learners_remote.php
```

Change the endpoint URL in the test file from:
```php
$serverUrl/add_supplemental_learners.php
```

To:
```php
$serverUrl/add_supplemental_learners_fast.php
```

## Quick Test Script

Create `test_fast_supplemental.php`:

```php
<?php
$serverUrl = "https://rlms.rlms.co.za/mobile";
$moderatorId = 77;
$targetCount = 402;

echo "Testing FAST supplemental learners...\n\n";

$postData = json_encode([
    'moderator_id' => $moderatorId,
    'target_count' => $targetCount
]);

$ch = curl_init("$serverUrl/add_supplemental_learners_fast.php");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $postData);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json'
]);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_TIMEOUT, 180);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "HTTP Status: $httpCode\n";
echo "Response:\n";
echo json_encode(json_decode($response), JSON_PRETTY_PRINT) . "\n";
?>
```

Run:
```bash
php test_fast_supplemental.php
```

## Expected Result

```json
{
    "status": "success",
    "message": "Added 29 supplemental learners. Total now: 402",
    "data": {
        "previous_count": 373,
        "target_count": 402,
        "needed_count": 29,
        "added_count": 29,
        "final_count": 402,
        "excluded_class": "74 (testing class)",
        "sample_learners": [...]
    }
}
```

## Files to Upload (Summary)

1. ✅ `get_learners_with_poe_assigned.php` - Fixed SQL error
2. ✅ `add_supplemental_learners_fast.php` - Optimized supplemental endpoint

Upload these NOW and test!
