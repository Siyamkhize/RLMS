# 🚨 CRITICAL: Database Connection Issue Found!

**Date:** July 21, 2026  
**Issue:** HTTP 500 error from backend  
**Root Cause:** `connection.php` has XAMPP credentials (won't work on production server)

---

## The Problem

Your local `mobile/connection.php` file has these credentials:

```php
$servername = "localhost";
$username = "root";          // ❌ XAMPP default
$password = "";               // ❌ Empty password
$dbname = "rlmsrlmsco_ezxcmacd_rlms";
```

**These credentials work on your local XAMPP**, but the **production server** (rlms.rlms.co.za) has **different database credentials**.

---

## Why Backend Returns HTTP 500

When `verify_fingerprint_and_get_signature.php` runs on the server:

1. It tries to load `connection.php` ✅
2. `connection.php` tries to connect with `root` user ❌
3. Database connection fails (wrong username/password) ❌
4. PHP throws exception ❌
5. Server returns HTTP 500 error ❌

---

## The Solution

**You need to check what `connection.php` looks like ON THE SERVER** (not locally).

The server version should have different credentials, like:

```php
$servername = "localhost";
$username = "rlmsrlms_dbuser";    // ✅ Real cPanel username
$password = "ActualPassword123";   // ✅ Real database password  
$dbname = "rlmsrlmsco_ezxcmacd_rlms";
```

---

## How to Check Server's connection.php

### Method 1: Download via FTP/cPanel

1. **Login to cPanel** → File Manager
2. **Navigate to:** `/public_html/mobile/`
3. **Find:** `connection.php`
4. **Right-click** → View or Edit
5. **Check the credentials** (username and password)

### Method 2: Create Test File

Upload this file to check what's on server:

**File:** `mobile/show_connection_config.php`

```php
<?php
header('Content-Type: text/plain');

$connectionFile = __DIR__ . '/connection.php';

if (file_exists($connectionFile)) {
    echo "connection.php EXISTS\n\n";
    echo "Content:\n";
    echo "==================\n";
    echo file_get_contents($connectionFile);
} else {
    echo "connection.php NOT FOUND\n";
}
?>
```

Then access: `https://rlms.rlms.co.za/mobile/show_connection_config.php`

**⚠️ Delete this file after viewing! It exposes database credentials.**

---

## Most Likely Scenario

The server **already has** a working `connection.php` with correct credentials.

**DO NOT upload your local `connection.php` to the server!** 

Your local file has XAMPP credentials that won't work on production.

---

## What To Do Now

### Option 1: Backend File Has Wrong Require Path (Most Likely)

Check line 38 of `verify_fingerprint_and_get_signature.php`:

```php
require_once 'connection.php';
```

This looks for `connection.php` in the **same folder**.

If the server's `connection.php` is in a **different location**, this will fail.

**Fix:**

Change to absolute path:

```php
require_once __DIR__ . '/connection.php';
```

Or if connection.php is in parent folder:

```php
require_once __DIR__ . '/../connection.php';
```

### Option 2: Check If Other Mobile Files Work

Test an existing mobile endpoint that uses `connection.php`:

```javascript
fetch('https://rlms.rlms.co.za/mobile/get_classes.php', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({facilitator_id: 6})
}).then(r => r.json()).then(d => console.log(d));
```

**If this works**, it means:
- ✅ `connection.php` exists and works
- ✅ Database credentials are correct
- ❌ Our new file has a different issue

**If this also fails with 500**, then:
- ❌ Server connection.php has a problem

---

## Next Steps

1. **Test existing endpoint** (`get_classes.php`) - Does it work?

2. **If yes**: Our file needs to match how other files load connection.php

3. **If no**: Need to fix server's connection.php first

---

## Quick Fix For Now

I'll create a version of `verify_fingerprint_and_get_signature.php` that uses the same connection pattern as other mobile files.

Let me check how `get_classes.php` loads the connection...

