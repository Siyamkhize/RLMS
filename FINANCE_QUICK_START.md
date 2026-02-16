# Finance Register System - Quick Start Guide

## For Finance Users

### Login
1. Open the RLMSS app
2. Enter your finance credentials
3. Tap "Login"
4. You'll see the Finance Dashboard

### View Classes
- Finance Dashboard shows all classes
- Each card displays:
  - Class name
  - Number of learners
- Tap any class to view its learners

### View Learners
- See all learners in the selected class
- Each learner card shows:
  - Name and surname
  - ID number
  - Number of registers scanned
- Tap "Scan" button to scan a register

### Scan a Register
1. Tap "Scan" button for a learner
2. **Select Month and Year:**
   - Year is fixed to 2024
   - Choose month from dropdown (January - December)
   - Tap "Continue"
3. **Scan Document:**
   - Camera opens automatically
   - Position register in frame
   - Tap capture button
   - Adjust corners if needed
   - Tap "Done" or "✓"
4. **Upload:**
   - Register uploads automatically
   - Success message appears
   - Register appears in list

### View Register History
- After scanning, see all registers for that learner
- Each register shows:
  - Month and Year (e.g., "January 2024")
  - Upload date
  - File name
  - Green checkmark

### Tips
- ✓ Pull down to refresh any list
- ✓ One register per month per learner
- ✓ Scanning same month again replaces old register
- ✓ Good lighting improves scan quality
- ✓ Hold device steady while scanning

## For Administrators

### Create Finance User
```sql
INSERT INTO users (email, password, role, name, surname) 
VALUES ('finance@mtl.com', MD5('password'), 'finance', 'Finance', 'User');
```

### Check Upload Directory
```bash
ls -la uploads/registers/
```

Should show files like:
```
register_123_2024_01_1234567890.jpg
register_123_2024_02_1234567891.jpg
```

### View Database Records
```sql
SELECT * FROM learner_registers ORDER BY uploaded_at DESC LIMIT 10;
```

### Test System
Visit: `https://rlms.rlms.co.za/mobile/test_finance_system.php`

## Common Questions

**Q: Can I scan multiple registers for one learner?**
A: Yes! Each learner can have up to 12 registers (one per month).

**Q: What if I scan the wrong month?**
A: Scan again with the correct month. It will replace the old one.

**Q: Can I change the year?**
A: No, year is fixed to 2024 as per requirements.

**Q: What file formats are supported?**
A: JPG, PNG - the scanner automatically saves as JPG.

**Q: How do I delete a register?**
A: Currently not supported. Contact administrator.

**Q: Can I view the scanned image?**
A: Not in current version. Feature planned for future.

**Q: What if upload fails?**
A: Check internet connection and try again. Contact support if persists.

## Troubleshooting

### "No classes found"
- Contact administrator
- Classes may not be set up yet

### "Scanner not working"
- Grant camera permission
- Check device has camera
- Restart app

### "Upload failed"
- Check internet connection
- Try again
- Contact support if persists

### "Login failed"
- Verify credentials
- Check role is 'finance'
- Contact administrator

## Support

**Technical Support:**
- Email: support@mtl.com
- Phone: [Support Number]

**Training:**
- Request training session
- Video tutorials: [Link]

## Quick Reference

| Action | Steps |
|--------|-------|
| Login | Email → Password → Login |
| View Classes | Auto-shown after login |
| View Learners | Tap class card |
| Scan Register | Tap "Scan" → Select month → Scan → Done |
| Refresh | Pull down on any list |
| Go Back | Tap back arrow |
| Logout | Back to login screen |

## Best Practices

1. **Scan in good lighting** - Better image quality
2. **Hold steady** - Avoid blurry images
3. **Check month** - Verify before scanning
4. **Confirm upload** - Wait for success message
5. **Regular backups** - Administrator should backup data

## Version
- **Version:** 1.0.0
- **Date:** December 20, 2024
- **System:** Finance Register Scanner

---

**Need Help?** Contact your system administrator or support team.
