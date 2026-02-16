# Quick Start - Pothole Checklist Scanning

## 🚀 Deploy in 5 Minutes

### Step 1: Database (1 min)
```bash
mysql -u root -p rlms < create_pothole_checklist_scanned_table.sql
```

### Step 2: Upload PHP Files (2 min)
Copy to server `/mobile/` directory:
- `upload_scanned_pothole_checklist.php`
- `check_pothole_checklist_status.php`

### Step 3: Create Upload Folder (1 min)
```bash
mkdir -p uploads/pothole_checklists
chmod 777 uploads/pothole_checklists
```

### Step 4: Test (1 min)
1. Open app
2. Go to Pothole Checklist page
3. Click "Open Checklist"
4. Try scanning a document

✅ **Done!**

---

## 📱 How Users Use It

### Option 1: Scan Physical Document
```
1. Click "Open Checklist"
2. Select "Scan Document"
3. Take photo of checklist
4. Done! (works offline)
```

### Option 2: Fill Digital Form
```
1. Click "Open Checklist"
2. Select "Fill Form"
3. Complete checklist
4. Click "Save"
```

### View Existing Checklist
```
1. Click "Open Checklist"
2. System shows "Checklist Found"
3. Click "View Checklist"
4. Document opens
```

---

## 🔧 Quick Troubleshooting

### Scanner won't open?
→ Check camera permissions

### Document not syncing?
→ Check internet connection
→ Verify server URL in config.dart

### Upload fails?
→ Check folder permissions: `chmod 777 uploads/pothole_checklists/`

### Can't view document?
→ Ensure PDF viewer installed on device

---

## 📊 Quick Checks

### Verify Database
```sql
SELECT COUNT(*) FROM pothole_checklist_scanned_documents;
```

### Check Uploads
```bash
ls -lh uploads/pothole_checklists/
```

### Test API
```bash
curl "https://rlms.rlms.co.za/mobile/check_pothole_checklist_status.php?learner_id=123&assessor_id=456&assessment_date=2025-11-04"
```

---

## 📚 Full Documentation

- **Complete Guide**: `POTHOLE_CHECKLIST_SCANNING_GUIDE.md`
- **Deployment**: `POTHOLE_CHECKLIST_DEPLOYMENT.md`
- **Summary**: `POTHOLE_SCANNING_SUMMARY.md`

---

## ✅ Success Checklist

- [ ] Database table created
- [ ] PHP files uploaded
- [ ] Upload folder created with permissions
- [ ] App tested (scan document)
- [ ] App tested (fill form)
- [ ] App tested (view checklist)
- [ ] Offline mode tested
- [ ] Auto-sync verified

---

## 🎯 Key Features

✅ Scan physical checklists
✅ Fill digital forms
✅ View existing checklists
✅ Works offline
✅ Auto-syncs when online
✅ No data loss

---

**Need Help?** Check the full documentation files!
