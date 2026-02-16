# Facilitator Unit Standards Debug & Fix

## Issue Identified
The facilitator issue form was showing "No unit standards found" because of missing API endpoints and parameter mismatches.

## Root Causes Found

### 1. Missing API Endpoint
- **Problem**: `getFacilitatordetails.php` file was missing
- **Impact**: Facilitator details couldn't be loaded, preventing unit standards fetch
- **Fix**: Created `getFacilitatordetails.php` with proper class-to-facilitator mapping

### 2. Parameter Mismatch
- **Problem**: `get_facilitator_material_status.php` expected `facilitatorID` but received `classID`
- **Impact**: Previous submissions couldn't be loaded
- **Fix**: Updated PHP file to accept `classID` and lookup facilitator internally

### 3. Response Format Mismatch
- **Problem**: API response format didn't match expected structure from `material_copy.dart`
- **Impact**: Unit standards selections and previous submissions not displayed correctly
- **Fix**: Updated response format to include `checkboxStatus`, `quantities`, `representatives`, and `regularMaterials`

## Files Created/Modified

### 1. Created: `getFacilitatordetails.php`
```php
// New endpoint to fetch facilitator details by classID
// Returns: facilitator info, class info, qualification name
```

### 2. Modified: `get_facilitator_material_status.php`
- Changed parameter from `facilitatorID` to `classID`
- Added facilitator lookup from class table
- Updated response format to match expected structure
- Added proper error handling

### 3. Created: Debug Files
- `test_facilitator_unit_standards.php` - Basic unit standards test
- `test_facilitator_unit_standards_complete.php` - Comprehensive test suite

## Testing Steps

### 1. Test API Endpoints
```bash
# Test facilitator details
curl "https://your-domain.com/getFacilitatordetails.php?classID=1"

# Test material status
curl "https://your-domain.com/get_facilitator_material_status.php?classID=1"
```

### 2. Test Unit Standards Database Query
```bash
# Run the complete test
https://your-domain.com/test_facilitator_unit_standards_complete.php?classID=1
```

### 3. Test Different Classes
Try different classID values (1-20) to find classes with unit standards data.

## Expected Behavior After Fix

1. **Facilitator Details Load**: Form should populate facilitator name, class name, qualification
2. **Unit Standards Display**: Available unit standards should appear in dropdown selection
3. **Previous Submissions**: Any previously issued materials should show with quantities
4. **Form Submission**: Unit standards can be selected and submitted successfully

## Debugging Commands

### Check if class has unit standards:
```sql
SELECT 
  c.classID,
  c.className,
  pr.Project_pathway
FROM class c
LEFT JOIN sites s ON c.siteID = s.siteID
LEFT JOIN project pr ON s.project_id = pr.project_id
WHERE c.classID = 1;
```

### Check facilitator material issues:
```sql
SELECT * FROM facilitator_material_issues 
WHERE class_id = '1' 
ORDER BY created_at DESC;
```

## Next Steps

1. **Deploy Files**: Upload the new/modified PHP files to server
2. **Test Endpoints**: Use the debug files to verify API responses
3. **Test Mobile App**: Verify unit standards now appear in facilitator form
4. **Monitor Logs**: Check for any remaining errors in app logs

## Status
✅ **API Endpoints Fixed**
✅ **Parameter Mapping Corrected**  
✅ **Response Format Updated**
🔄 **Ready for Testing**

The facilitator unit standards should now work correctly, matching the functionality in `material_copy.dart`.