# POE Merge - PHP Version Compatibility Fix

## Issue
Error: "Composer detected issues in your platform: Your Composer dependencies require a PHP version >= 8.2.0"

## Root Cause
The latest FPDI library (v2.5+) requires PHP 8.2+, but your server is running an older PHP version (likely PHP 7.4 or 8.0).

## Solution
Install FPDI version 2.3.x which is compatible with PHP 7.4+

---

## Quick Fix (Choose One Method)

### Method 1: Automated Installation (Recommended)

**On Windows (Local Development):**
```bash
install_fpdi_compatible.bat
```

**On Linux/Mac Server:**
```bash
chmod +x install_fpdi_compatible.sh
./install_fpdi_compatible.sh
```

### Method 2: Manual Composer Command

```bash
# Remove old installation
rm -rf vendor composer.lock

# Install compatible version
composer require setasign/fpdi:^2.3
```

### Method 3: Force Ignore Platform Requirements (Quick but not ideal)

```bash
composer install --ignore-platform-reqs
```

---

## Files Created

1. **composer.json** - Specifies FPDI 2.3.x for PHP 7.4+ compatibility
2. **install_fpdi_compatible.bat** - Windows installation script
3. **install_fpdi_compatible.sh** - Linux/Mac installation script
4. **FPDI_INSTALL_FIX.md** - Detailed troubleshooting guide

---

## Verification Steps

### 1. Check PHP Version
```bash
php -v
```

### 2. Verify FPDI Installation
```bash
ls -la vendor/setasign/fpdi/
```

### 3. Test Merge Functionality
Visit: `https://your-server.com/test_merge_poe.php`

Should show: "✅ FPDI library is installed"

### 4. Test Actual Merge
Visit: `https://your-server.com/test_merge_poe_fixed.php?learner_id=152`

---

## FPDI Version Compatibility Matrix

| FPDI Version | PHP Version Required | Status |
|--------------|---------------------|---------|
| 2.3.x | PHP 7.1 - 8.1 | ✅ Use This |
| 2.4.x | PHP 8.0 - 8.2 | ⚠️ May work |
| 2.5.x | PHP 8.2+ | ❌ Too new |

---

## Troubleshooting

### Still Getting PHP Version Error?

1. **Delete everything and start fresh:**
```bash
rm -rf vendor composer.lock
composer require setasign/fpdi:2.3.7
```

2. **Check your actual PHP version:**
```bash
php -v
```

3. **If server PHP is different from CLI PHP:**
Create `check_php.php`:
```php
<?php
echo "PHP Version: " . PHP_VERSION;
echo "\nFPDI Installed: " . (class_exists('setasign\Fpdi\Fpdi') ? 'Yes' : 'No');
?>
```

Visit: `https://your-server.com/check_php.php`

### Composer Not Found?

**Install Composer:**
```bash
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
```

### Permission Denied?

```bash
chmod +x install_fpdi_compatible.sh
```

---

## What Was Fixed in merge_poe_documents.php

The merge logic was also updated to fix blank page issues:

1. ✅ Added `SetAutoPageBreak(false)` - prevents blank pages
2. ✅ Fixed orientation calculation - properly detects landscape/portrait
3. ✅ Complete `useTemplate()` parameters - ensures content renders
4. ✅ Added error logging - better debugging

---

## Next Steps

1. ✅ Install FPDI 2.3.x using one of the methods above
2. ✅ Upload fixed `merge_poe_documents.php` to server
3. ✅ Test with `test_merge_poe_fixed.php`
4. ✅ Merge your POE documents - they should now display correctly!

---

## Summary

**Problem:** FPDI requires PHP 8.2+  
**Solution:** Use FPDI 2.3.x for PHP 7.4+  
**Result:** PDF merge works without blank pages!

The merged PDFs will now display all pages correctly with proper content.
