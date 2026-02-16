# Security Deployment Guide

## Overview

This guide walks you through deploying the comprehensive security fixes for the RLMS system. Follow these steps carefully to ensure a smooth transition.

## Pre-Deployment Checklist

- [ ] Backup entire database
- [ ] Backup all PHP files
- [ ] Test on staging environment first
- [ ] Schedule maintenance window
- [ ] Notify users of downtime

## Step 1: Generate Encryption Keys

```bash
# Generate AES encryption key (32 bytes)
openssl rand -base64 32

# Generate session encryption key (32 bytes)
openssl rand -base64 32

# Save these keys securely - you'll need them for .env file
```

## Step 2: Create .env File

```bash
# Copy example file
cp .env.example .env

# Edit .env file
nano .env
```

Fill in your values:
```env
DB_HOST=localhost
DB_USERNAME=your_actual_username
DB_PASSWORD=your_actual_password
DB_NAME=rlmss

AES_ENCRYPTION_KEY=<paste_key_from_step_1>
SESSION_ENCRYPTION_KEY=<paste_key_from_step_1>

ENVIRONMENT=production
ENABLE_DEBUG=false
SESSION_TIMEOUT=1800

API_RATE_LIMIT=100
API_RATE_WINDOW=60

MAX_UPLOAD_SIZE=209715200
UPLOAD_PATH=/var/secure_uploads/

FORCE_HTTPS=true
HSTS_MAX_AGE=31536000
```

**CRITICAL:** Never commit .env to git!

## Step 3: Set File Permissions

```bash
# Secure .env file
chmod 600 .env
chown www-data:www-data .env

# Secure includes directory
chmod 755 includes/
chmod 644 includes/*.php

# Make migration script executable
chmod 700 migrate_passwords.php
```

## Step 4: Migrate Passwords

```bash
# Run password migration
php migrate_passwords.php

# Review output carefully
# If any errors, fix before proceeding
```

## Step 5: Update .htaccess

```bash
# Backup current .htaccess
cp .htaccess .htaccess.backup

# Replace with secure version
cp .htaccess_secure .htaccess

# Test Apache configuration
sudo apachectl configtest

# If OK, reload Apache
sudo systemctl reload apache2
```

## Step 6: Remove Debug Files

```bash
# Create backup directory
mkdir ../rlms_debug_backup
mv debug_*.php ../rlms_debug_backup/
mv test_*.php ../rlms_debug_backup/
mv check_*.php ../rlms_debug_backup/
mv fix_*.php ../rlms_debug_backup/
mv diagnose_*.php ../rlms_debug_backup/

# Keep only essential test files if needed
# But NEVER in production!
```

## Step 7: Update Database Connection

```bash
# Backup old connection file
cp connection.php connection.php.old

# Update all PHP files to use new secure connection
# Find files using old connection:
grep -r "include.*connection\.php" *.php

# Replace with:
# require_once 'includes/db_secure.php';
# $db = Database::getInstance();
```

## Step 8: Update Login Endpoint

```bash
# Update mobile app config to use new login endpoint
# In lib/config.dart:
static String get loginUrl => '$baseUrl/login_secure.php';
```

## Step 9: Enable Database Encryption (MySQL 5.7.11+)

```sql
-- Connect to MySQL as root
mysql -u root -p

-- Enable encryption for sensitive tables
ALTER TABLE learnerdetails ENCRYPTION='Y';
ALTER TABLE account_user ENCRYPTION='Y';
ALTER TABLE facilitator ENCRYPTION='Y';
ALTER TABLE sdp ENCRYPTION='Y';
ALTER TABLE bankdetails ENCRYPTION='Y';
ALTER TABLE poe_documents ENCRYPTION='Y';

-- Verify encryption
SELECT TABLE_SCHEMA, TABLE_NAME, CREATE_OPTIONS 
FROM information_schema.TABLES 
WHERE CREATE_OPTIONS LIKE '%ENCRYPTION%';
```

## Step 10: Encrypt Sensitive Columns

Create migration script for existing data:

```php
<?php
// encrypt_sensitive_data.php
require_once 'includes/security.php';
require_once 'includes/db_secure.php';

$db = Database::getInstance();

// Encrypt ID numbers
$query = "SELECT LearnerID, IDNumber FROM learnerdetails WHERE IDNumber IS NOT NULL";
$results = $db->select($query);

foreach ($results as $row) {
    $encrypted = Security::encrypt($row['IDNumber']);
    $db->update(
        "UPDATE learnerdetails SET IDNumber = ? WHERE LearnerID = ?",
        'ss',
        [$encrypted, $row['LearnerID']]
    );
}

echo "Encrypted " . count($results) . " ID numbers\n";
?>
```

## Step 11: Configure SSL Certificate

```bash
# Install Let's Encrypt certificate
sudo apt-get install certbot python3-certbot-apache
sudo certbot --apache -d rlms.rlms.co.za

# Auto-renewal
sudo certbot renew --dry-run
```

## Step 12: Test Security

### Test 1: HTTPS Enforcement
```bash
curl -I http://rlms.rlms.co.za
# Should redirect to HTTPS
```

### Test 2: Security Headers
```bash
curl -I https://rlms.rlms.co.za
# Check for:
# - Strict-Transport-Security
# - X-Frame-Options
# - X-Content-Type-Options
# - Content-Security-Policy
```

### Test 3: Login
```bash
# Test with valid credentials
curl -X POST https://rlms.rlms.co.za/login_secure.php \
  -d "email=test@example.com&password=testpass"

# Should return JSON with success: true
```

### Test 4: Rate Limiting
```bash
# Try 11 failed logins rapidly
for i in {1..11}; do
  curl -X POST https://rlms.rlms.co.za/login_secure.php \
    -d "email=test@example.com&password=wrong"
done

# 11th request should return 429 Too Many Requests
```

### Test 5: SQL Injection Protection
```bash
# Try SQL injection
curl -X POST https://rlms.rlms.co.za/login_secure.php \
  -d "email=admin' OR '1'='1&password=anything"

# Should return 401 Unauthorized, not expose data
```

## Step 13: Monitor Logs

```bash
# Watch security log
tail -f /var/log/php_errors.log | grep SECURITY

# Watch Apache error log
tail -f /var/log/apache2/error.log

# Watch access log for suspicious activity
tail -f /var/log/apache2/access.log | grep -E "(sqlmap|nikto|nmap)"
```

## Step 14: Update Mobile App

### Update pubspec.yaml
```yaml
dependencies:
  sqflite_sqlcipher: ^2.2.1  # Encrypted SQLite
  flutter_secure_storage: ^9.0.0  # Secure key storage
```

### Update database_helper.dart
```dart
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Generate encryption key
final storage = FlutterSecureStorage();
String? dbPassword = await storage.read(key: 'db_password');
if (dbPassword == null) {
  dbPassword = base64Encode(List<int>.generate(32, (i) => Random.secure().nextInt(256)));
  await storage.write(key: 'db_password', value: dbPassword);
}

// Open encrypted database
final database = await openDatabase(
  path,
  password: dbPassword,
  version: 1,
);
```

## Step 15: Post-Deployment Verification

- [ ] All users can log in successfully
- [ ] HTTPS is enforced (no HTTP access)
- [ ] Security headers are present
- [ ] Rate limiting works
- [ ] File uploads work
- [ ] Database queries work
- [ ] Mobile app connects successfully
- [ ] No debug files accessible
- [ ] Logs show no errors

## Step 16: Ongoing Maintenance

### Daily
- Monitor security logs for suspicious activity
- Check failed login attempts

### Weekly
- Review access logs
- Update SSL certificates if needed
- Check for security updates

### Monthly
- Rotate encryption keys (advanced)
- Review user permissions
- Audit database access
- Test backup restoration

## Rollback Plan

If issues occur:

```bash
# 1. Restore .htaccess
cp .htaccess.backup .htaccess
sudo systemctl reload apache2

# 2. Restore connection.php
cp connection.php.old connection.php

# 3. Restore database backup
mysql -u root -p rlmss < backup.sql

# 4. Notify users
# 5. Investigate issues
# 6. Fix and retry
```

## Security Checklist

After deployment, verify:

- [ ] HTTPS enforced everywhere
- [ ] All passwords use bcrypt
- [ ] No MD5 or plaintext passwords
- [ ] Database credentials in .env only
- [ ] .env not in git
- [ ] All debug files removed
- [ ] Security headers present
- [ ] Rate limiting active
- [ ] SQL injection protected (prepared statements)
- [ ] File uploads validated
- [ ] Session security enabled
- [ ] CSRF protection active
- [ ] Audit logging enabled
- [ ] Database encryption enabled
- [ ] Sensitive columns encrypted
- [ ] Mobile database encrypted

## Support

If you encounter issues:

1. Check logs: `/var/log/php_errors.log`
2. Review Apache logs: `/var/log/apache2/error.log`
3. Test individual components
4. Rollback if necessary
5. Document issues for troubleshooting

## Next Steps

After successful deployment:

1. Schedule penetration test
2. Obtain security certification
3. Document security procedures
4. Train staff on security practices
5. Implement monitoring alerts
6. Create incident response plan

---

**IMPORTANT:** Keep this guide secure and update it as you make changes to the security infrastructure.
