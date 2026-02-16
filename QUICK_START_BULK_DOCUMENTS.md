# 🚀 Quick Start - Bulk Download with Documents

## What's New?
Your bulk download now automatically includes:
- 📄 **Sick Notes** from the filtered date period
- 📋 **Manual Registers** from the filtered date period

## How to Use (3 Steps)

### Step 1: Test the Setup
Open in browser: `test_bulk_documents.php`
- ✅ Verify all tests pass
- ✅ Check database tables exist
- ✅ Confirm file paths are correct

### Step 2: Try a Small Export
1. Go to bulk download page
2. Set date range (e.g., October 2025)
3. Filter to 5-10 learners
4. Click "Bulk Download"
5. Check the ZIP file contents

### Step 3: Use for Production
- Set your filters as normal
- Click "Bulk Download"
- Get ZIP file with:
  - Reports
  - Sick notes
  - Manual registers
  - Summary

## ZIP File Structure
```
bulk_reports_20251030_123456.zip
├── reports/              ← Learner reports
├── sick_notes/          ← Sick notes for date range
├── manual_registers/    ← Manual registers for date range
└── SUMMARY.txt          ← Export summary
```

## Database Tables Used
- `sick_note` → Sick notes
- `manual_clocking` → Manual registers
- `learnerdetails` → Learner info

## File Paths
- Sick notes: `/public_html/mobile/sicknotes/`
- Manual registers: `/public_html/uploads/`

## Troubleshooting

### No documents in ZIP?
→ Run `test_bulk_documents.php` to check:
  - Database has records
  - Files exist on disk
  - Paths are correct

### ZIP not downloading?
→ Check:
  - ZipArchive extension: `php -m | grep zip`
  - Directory permissions: `temp_reports/`
  - Error log: `bulk_export_errors.log`

### Slow performance?
→ Try:
  - Smaller batch size
  - Shorter date range
  - Check server resources

## Quick Test Command
```bash
# Test API directly
curl -X POST http://your-domain.com/bulk_export_api.php \
  -d "learner_ids=[123,456]" \
  -d "start_date=2025-10-01" \
  -d "end_date=2025-10-31"
```

## Support Files
- 📖 Full docs: `BULK_DOWNLOAD_WITH_DOCUMENTS.md`
- 📋 Summary: `BULK_DOWNLOAD_IMPLEMENTATION_SUMMARY.md`
- 🧪 Test: `test_bulk_documents.php`

## That's It! 🎉
Your bulk download now includes all documents automatically.
