# Finance Register System - Deployment Checklist

## Pre-Deployment

### 1. Database Setup
- [ ] Run `create_learner_registers_table.sql` on your database
- [ ] Verify `learner_registers` table exists
- [ ] Add `role` column to `users` table if not exists
- [ ] Create at least one finance user

```sql
-- Create finance user
INSERT INTO users (email, password, role, name, surname) 
VALUES ('finance@mtl.com', MD5('YourSecurePassword'), 'finance', 'Finance', 'Department');
```

### 2. Server Files Upload
Upload these PHP files to `rlms.rlms.co.za/mobile/`:

- [ ] `get_finance_classes.php`
- [ ] `get_finance_learners.php`
- [ ] `get_learner_registers.php`
- [ ] `upload_learner_register.php`
- [ ] `test_finance_system.php` (for testing)

### 3. Directory Setup
Create upload directory on server:

```bash
mkdir -p uploads/registers
chmod 777 uploads/registers
```

Or via PHP/cPanel File Manager:
- Create folder: `uploads/registers`
- Set permissions: 777

### 4. Flutter App Update
- [ ] Verify all finance files are in `lib/` folder:
  - `finance_dashboard.dart`
  - `finance_learner_list.dart`
  - `finance_register_scanner.dart`
- [ ] Verify `main.dart` has finance import and routing
- [ ] Run `flutter pub get`
- [ ] Run `flutter clean`
- [ ] Build APK: `flutter build apk`

## Testing

### 1. Test PHP Endpoints
Visit: `https://rlms.rlms.co.za/mobile/test_finance_system.php`

Check all tests pass:
- [ ] ✓ Classes fetched
- [ ] ✓ Learners fetched
- [ ] ✓ Registers fetched
- [ ] ✓ Database table exists
- [ ] ✓ Upload directory exists and writable
- [ ] ✓ Finance user exists

### 2. Test Individual Endpoints

**Get Classes:**
```bash
curl https://rlms.rlms.co.za/mobile/get_finance_classes.php
```

**Get Learners:**
```bash
curl "https://rlms.rlms.co.za/mobile/get_finance_learners.php?classID=1"
```

**Get Registers:**
```bash
curl "https://rlms.rlms.co.za/mobile/get_learner_registers.php?learner_id=123"
```

**Upload Register (test):**
```bash
curl -X POST https://rlms.rlms.co.za/mobile/upload_learner_register.php \
  -F "learner_id=123" \
  -F "class_id=1" \
  -F "finance_id=1" \
  -F "register_month=1" \
  -F "register_year=2024" \
  -F "register_file=@test_image.jpg"
```

### 3. Test App Login
- [ ] Install APK on test device
- [ ] Login with finance credentials
- [ ] Should see Finance Dashboard
- [ ] Should see list of classes

### 4. Test Full Flow
- [ ] Select a class
- [ ] See list of learners
- [ ] Tap "Scan" button on a learner
- [ ] Month/Year picker appears
- [ ] Select month (Year = 2024)
- [ ] Document scanner opens
- [ ] Scan a test document
- [ ] Upload succeeds
- [ ] Register appears in list
- [ ] Register count updates

## Post-Deployment

### 1. Verify Data
- [ ] Check database for new records in `learner_registers`
- [ ] Check `uploads/registers/` for uploaded files
- [ ] Verify file naming: `register_{learner_id}_{year}_{month}_{timestamp}.{ext}`

### 2. Security Check
- [ ] Verify only finance users can access finance pages
- [ ] Test with non-finance user (should not see finance option)
- [ ] Check file upload size limits
- [ ] Verify SQL injection protection

### 3. Performance Check
- [ ] Test with multiple classes (10+)
- [ ] Test with multiple learners (50+)
- [ ] Test with multiple registers per learner (12+)
- [ ] Check page load times

## Troubleshooting

### Issue: Finance Dashboard Not Showing
**Check:**
1. User role is exactly 'finance' (case-sensitive)
2. `main.dart` has finance import
3. App was rebuilt after changes

### Issue: "No classes found"
**Check:**
1. `classes` table has data
2. `get_finance_classes.php` is uploaded
3. Database connection works

### Issue: Upload Fails
**Check:**
1. `uploads/registers/` directory exists
2. Directory has 777 permissions
3. PHP `upload_max_filesize` is sufficient (check php.ini)
4. PHP `post_max_size` is sufficient

### Issue: Scanner Not Working
**Check:**
1. Camera permissions granted
2. `flutter_doc_scanner` in pubspec.yaml
3. Device has camera
4. Android permissions in AndroidManifest.xml

## Rollback Plan

If issues occur:

1. **Remove finance access:**
```sql
UPDATE users SET role = 'learner' WHERE role = 'finance';
```

2. **Remove finance files from server:**
- Delete uploaded PHP files
- Keep database table (data preserved)

3. **Revert app:**
- Deploy previous APK version
- Or rebuild without finance changes

## Maintenance

### Regular Tasks
- [ ] Monitor upload directory size
- [ ] Clean old test uploads
- [ ] Backup `learner_registers` table
- [ ] Review finance user access logs

### Monthly Tasks
- [ ] Check disk space in `uploads/registers/`
- [ ] Archive old registers (optional)
- [ ] Review and optimize database queries

## Support Contacts

**Technical Issues:**
- Database: [DBA Contact]
- Server: [Server Admin Contact]
- App: [Developer Contact]

**User Issues:**
- Finance Department: [Finance Contact]
- Training: [Training Contact]

## Documentation

- Full documentation: `FINANCE_REGISTER_SYSTEM.md`
- API details: See documentation file
- Database schema: `create_learner_registers_table.sql`

## Sign-Off

- [ ] Database setup verified by: _________________ Date: _______
- [ ] Server files uploaded by: _________________ Date: _______
- [ ] App tested by: _________________ Date: _______
- [ ] Finance user trained by: _________________ Date: _______
- [ ] Production deployment approved by: _________________ Date: _______

## Notes

_Add any deployment-specific notes here:_

---

**Deployment Date:** _______________
**Deployed By:** _______________
**Version:** 1.0.0
