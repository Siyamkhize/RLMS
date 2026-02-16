# FPDI Installation Fix for PHP < 8.2

## Problem
The latest FPDI version requires PHP 8.2+, but your server is running an older PHP version.

## Solution
Install FPDI version 2.3.x which is compatible with PHP 7.4+

## Installation Steps

### Option 1: Using the provided composer.json (Recommended)

1. Upload `composer.json` to your server root directory

2. SSH into your server and run:
```bash
cd /path/to/your/project
composer install
```

### Option 2: Manual Installation

If you already have composer installed, run:
```bash
composer require setasign/fpdi:^2.3
```

### Option 3: Force specific version

If you're still getting errors, force the exact version:
```bash
composer require setasign/fpdi:2.3.7
```

### Option 4: Ignore platform requirements (Quick fix, not recommended)

If you need a quick fix and can't change versions:
```bash
composer install --ignore-platform-reqs
```

## Verify Installation

After installation, check that FPDI is installed:

```bash
ls -la vendor/setasign/fpdi/
```

You should see the FPDI library files.

## Test the Installation

Run the test file:
```
https://your-server.com/test_merge_poe.php
```

It should show "✅ FPDI library is installed"

## PHP Version Compatibility

- **FPDI 2.3.x**: PHP 7.1 - 8.1 ✅ (Use this)
- **FPDI 2.4.x**: PHP 8.0 - 8.2
- **FPDI 2.5.x**: PHP 8.2+ (Latest, requires PHP 8.2)

## Check Your PHP Version

To check your server's PHP version:
```bash
php -v
```

Or create a file `phpinfo.php`:
```php
<?php phpinfo(); ?>
```

Then visit: `https://your-server.com/phpinfo.php`

## Troubleshooting

### Error: "Your Composer dependencies require a PHP version >= 8.2.0"

**Solution**: Delete `composer.lock` and `vendor/` folder, then reinstall:
```bash
rm -rf vendor composer.lock
composer install
```

### Error: "composer: command not found"

**Solution**: Install Composer first:
```bash
curl -sS https://getcomposer.org/installer | php
php composer.phar install
```

### Error: "Cannot find autoload.php"

**Solution**: Make sure composer install completed successfully:
```bash
composer install --no-dev
```

## Alternative: Manual FPDI Installation (No Composer)

If you can't use Composer:

1. Download FPDI 2.3.7 from: https://github.com/Setasign/FPDI/releases/tag/v2.3.7

2. Extract to your project:
```
/vendor/setasign/fpdi/
```

3. Update merge_poe_documents.php to manually include FPDI:
```php
require_once __DIR__ . '/vendor/setasign/fpdi/src/autoload.php';
```

## Summary

The key is to use **FPDI 2.3.x** which is compatible with PHP 7.4+, not the latest version which requires PHP 8.2+.

After fixing, your PDF merge should work correctly!
