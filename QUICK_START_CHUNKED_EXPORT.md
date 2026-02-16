# Quick Start: Chunked Bulk Export (2000+ Learners)

## 🚀 5-Minute Setup

### Step 1: Upload Files (2 minutes)

Upload these 3 files to your server:

1. **bulk_export_chunked.php** - Backend processor
2. **bulk_download_chunked.js** - Frontend script  
3. **bulk_down_register.php** - Updated main file

### Step 2: Set Permissions (1 minute)

```bash
chmod 755 bulk_export_chunked.php
chmod 755 bulk_download_chunked.js
mkdir -p temp_reports
chmod 777 temp_reports
```

### Step 3: Test (2 minutes)

1. Upload `test_chunked_export.php`
2. Open it in browser: `https://yoursite.com/test_chunked_export.php`
3. Click "Run Test" on Test 4 (API Endpoint Test)
4. Should see ✅ green checkmark

### Step 4: Use It!

1. Go to `bulk_down_register.php`
2. Apply filters (district, site, dates)
3. Click **"📄 Bulk Download (2000+ Learners Supported)"**
4. Wait for progress bar
5. ZIP downloads automatically!

## ✨ What You Get

Your ZIP file contains:

```
bulk_reports_20241101_143022.zip
├── reports/
│   ├── report_1001.pdf
│   ├── report_1002.pdf
│   └── ... (all learner reports)
├── sick_notes/
│   ├── 1001_sicknote_doc1.pdf
│   └── ... (sick note documents)
├── manual_registers/
│   ├── 1001_manual_register.pdf
│   └── ... (manual attendance registers)
└── SUMMARY.txt (export summary)
```

## 📊 How Long Does It Take?

| Learners | Time |
|----------|------|
| 10       | 10-20 seconds |
| 50       | 1-2 minutes |
| 100      | 2-4 minutes |
| 500      | 10-15 minutes |
| 1000     | 20-30 minutes |
| 2000     | 40-60 minutes |

## ❓ Troubleshooting

### Problem: Button doesn't work

**Fix**: Clear browser cache (Ctrl+F5)

### Problem: "Session not found"

**Fix**: 
```bash
chmod 777 temp_reports
```

### Problem: Progress stuck at 0%

**Fix**: 
1. Press F12 (open console)
2. Look for errors
3. Verify `bulk_download_chunked.js` loaded

### Problem: ZIP file empty

**Fix**: Check PHP error logs for mPDF errors

## 🎯 Key Differences from Old System

| Old System | New Chunked System |
|------------|-------------------|
| ❌ Times out after 133 learners | ✅ Handles 2000+ learners |
| ❌ No progress indicator | ✅ Real-time progress bar |
| ❌ All-or-nothing processing | ✅ Processes in small chunks |
| ❌ Gateway timeout errors | ✅ No timeout issues |

## 💡 Pro Tips

1. **For best performance**: Process during off-peak hours
2. **For large batches**: Start with 100 learners to test
3. **Monitor progress**: Keep browser tab open during export
4. **Check results**: Open ZIP and verify SUMMARY.txt

## ✅ Success Checklist

- [ ] Files uploaded
- [ ] Permissions set
- [ ] Test passed
- [ ] Button appears on page
- [ ] Progress bar shows
- [ ] ZIP downloads
- [ ] ZIP contains reports
- [ ] Documents included

## 🆘 Need Help?

1. Run `test_chunked_export.php` - all tests should pass
2. Check browser console (F12) for errors
3. Check PHP error logs
4. Verify all 3 files are uploaded

---

**That's it!** You're ready to export 2000+ learner reports without timeouts! 🎉
