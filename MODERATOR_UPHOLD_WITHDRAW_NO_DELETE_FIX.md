# Moderator Uphold/Withdraw Fix - No Deletion

## Issue Fixed
When moderators selected "Uphold" or "Withdraw" for formative/summative assessments:
- **Uphold** was returning "invalid moderation status" error
- **Withdraw** was working but **deleting records** from the database instead of just updating the status

## Root Cause
1. **Validation Issue**: PHP was only accepting exact case-sensitive matches ('Uphold' and 'Withdrawn'), but Flutter was sending 'Uphold' or 'Withdrawn'
2. **Deletion Logic**: The old code had logic that deleted records when status was 'Disapproved' (mapped from 'Withdrawn')

## Changes Made

### File: `save_moderation_status.php`

#### 1. Improved Status Validation (Case-Insensitive)
```php
// OLD - Case-sensitive, limited acceptance
if ($moderationStatus === 'Upheld') {
    $moderationStatus = 'Uphold';
}
$approvalStatus = ($moderationStatus === 'Uphold') ? 'Approved' : 
                  (($moderationStatus === 'Withdrawn') ? 'Disapproved' : null);

// NEW - Case-insensitive, accepts multiple variations
$moderationStatusLower = strtolower(trim($moderationStatus));

if ($moderationStatusLower === 'uphold' || $moderationStatusLower === 'upheld') {
    $approvalStatus = 'Approved';
    $moderatorStatusValue = 'upheld';
} elseif ($moderationStatusLower === 'withdrawn' || $moderationStatusLower === 'withdraw') {
    $approvalStatus = 'Disapproved';
    $moderatorStatusValue = 'withdrawn';
} else {
    echo json_encode(["status" => "error", "message" => "Invalid moderation status: '$moderationStatus'. Expected 'Uphold', 'Upheld', 'Withdrawn', or 'Withdraw'."]);
    exit();
}
```

#### 2. Removed Deletion Logic
The entire deletion block (100+ lines) that deleted records from `marks` and `poe` tables has been removed.

#### 3. Update-Only Approach
Now **both Uphold and Withdraw** simply update the database fields:
```php
// Update the approval_status and moderator comment (no deletion)
$sqlUpdate = "UPDATE marks SET 
    approval_status = ?, 
    moderator_status = ?, 
    moderator_comment = ?, 
    moderator_id = ?, 
    moderation_date = NOW() 
WHERE learnerID = ? AND exercise = ?";
```

## Database Updates

### For "Uphold" Decision:
- `approval_status` = 'Approved'
- `moderator_status` = 'upheld'
- `moderator_comment` = (moderator's comment)
- `moderator_id` = (moderator's ID)
- `moderation_date` = NOW()

### For "Withdraw" Decision:
- `approval_status` = 'Disapproved'
- `moderator_status` = 'withdrawn'
- `moderator_comment` = (moderator's comment)
- `moderator_id` = (moderator's ID)
- `moderation_date` = NOW()

## Accepted Status Values
The system now accepts (case-insensitive):
- **Uphold**: 'uphold', 'upheld', 'Uphold', 'Upheld', 'UPHOLD', 'UPHELD'
- **Withdraw**: 'withdraw', 'withdrawn', 'Withdraw', 'Withdrawn', 'WITHDRAW', 'WITHDRAWN'

## Testing Instructions

1. **Test Uphold**:
   - Select a formative or summative assessment
   - Choose "Uphold" from the moderation decision dropdown
   - Verify: Success message appears
   - Verify: Record is updated in database (not deleted)
   - Verify: `approval_status` = 'Approved', `moderator_status` = 'upheld'

2. **Test Withdraw**:
   - Select a formative or summative assessment
   - Choose "Withdraw" from the moderation decision dropdown
   - Verify: Success message appears
   - Verify: Record is updated in database (not deleted)
   - Verify: `approval_status` = 'Disapproved', `moderator_status` = 'withdrawn'

3. **Verify No Deletion**:
   - Check database before and after moderation
   - Confirm records remain in `marks` table
   - Confirm records remain in `poe` table
   - Confirm files remain on server

## Files Modified
- `save_moderation_status.php` - Fixed validation and removed deletion logic

## Status
✅ **COMPLETE** - Both Uphold and Withdraw now work correctly and only update status (no deletion)
