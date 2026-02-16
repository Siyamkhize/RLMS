# POE Document Merge Solution - Complete Implementation

## 🎯 Your Question

> "So if we scan in batches of 50 pages, until the full file is finished, we will be able to merge it into one full POE file when we want to view or download it?"

## ✅ Answer: YES!

I've implemented a complete system that allows you to:
1. Scan documents in batches (50-100 pages each)
2. Upload each batch separately
3. Merge all batches into one complete PDF
4. View/download the merged document

## 🚀 How It Works

### Step 1: Scan in Batches
```
User scans pages 1-50   → Upload as Part 1 ✅
User scans pages 51-100 → Upload as Part 2 ✅
User scans pages 101-150 → Upload as Part 3 ✅
User scans pages 151-195 → Upload as Part 4 ✅
```

Each batch:
- Uploads successfully (no scanner limitations)
- Marked as "POE_PART" in database
- Labeled as "Part 1 of 4", "Part 2 of 4", etc.

### Step 2: View All Documents
User opens "POE Document Manager" and sees:
```
☐ POE_12345_part1.pdf (50 pages) - Part 1 of 4
☐ POE_12345_part2.pdf (50 pages) - Part 2 of 4
☐ POE_12345_part3.pdf (50 pages) - Part 3 of 4
☐ POE_12345_part4.pdf (45 pages) - Part 4 of 4
```

### Step 3: Select & Merge
User:
1. Checks all 4 parts ✅
2. Taps "Merge 4 Documents" button
3. Confirms merge action
4. System merges PDFs on server

### Step 4: Result
New merged document created:
```
✅ POE_12345_merged_1703001234.pdf (195 pages)
   - Type: POE_MERGED
   - Size: 70 MB
   - All pages from all parts combined
```

Original parts:
```
☑ POE_12345_part1.pdf (merged) - strikethrough
☑ POE_12345_part2.pdf (merged) - strikethrough
☑ POE_12345_part3.pdf (merged) - strikethrough
☑ POE_12345_part4.pdf (merged) - strikethrough
```

### Step 5: Download
User downloads the merged PDF and gets one complete 195-page document!

## 📁 Files Created

### Flutter App (3 files)

1. **lib/poe_document_scanner.dart** (Updated)
   - Added `partNumber` parameter
   - Added `totalParts` parameter
   - Marks documents as "POE_PART" when scanning batches
   - Shows "Part X of Y" in UI

2. **lib/poe_document_manager.dart** (New)
   - Lists all POE documents for a learner
   - Checkbox selection for multiple documents
   - "Merge Documents" button
   - Shows merged status
   - View/download/delete options

### PHP Server (2 files)

3. **merge_poe_documents.php** (New)
   - Merges multiple PDFs into one
   - Uses FPDI library for PDF manipulation
   - Creates new merged document in database
   - Marks original parts as "merged"

4. **test_merge_poe.php** (New)
   - Tests merge functionality
   - Checks FPDI installation
   - Lists documents available for merging
   - Simulates merge operations

### Documentation (2 files)

5. **POE_MULTI_PART_MERGE_GUIDE.md** (New)
   - Complete usage guide
   - Code examples
   - API documentation
   - Deployment checklist

6. **install_fpdi.sh** (New)
   - Installation script for FPDI library
   - Automated setup

## 🔧 Installation Steps

### 1. Server Setup (5 minutes)

```bash
# SSH into your server
ssh user@rlms.rlms.co.za

# Navigate to mobile directory
cd /path/to/mobile

# Install FPDI library
composer require setasign/fpdi

# Upload PHP files
# - merge_poe_documents.php
# - test_merge_poe.php

# Test installation
curl https://rlms.rlms.co.za/mobile/test_merge_poe.php
```

### 2. Flutter App Update (10 minutes)

```bash
# Files already created in your project:
# - lib/poe_document_scanner.dart (updated)
# - lib/poe_document_manager.dart (new)

# Build new APK
flutter clean
flutter pub get
flutter build apk --release

# Install on device
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 3. Test the System (5 minutes)

1. Open app
2. Go to learner details
3. Scan Part 1 (50 pages) → Upload ✅
4. Scan Part 2 (50 pages) → Upload ✅
5. Open "View Documents"
6. Select both parts
7. Tap "Merge Documents"
8. Download merged PDF ✅

## 💻 Code Examples

### Example 1: Scan with Part Numbers

```dart
// In your learner details page, add buttons for each part

ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PoeDocumentScanner(
          learnerId: learner.id,
          learnerName: learner.name,
          partNumber: 1,      // This is Part 1
          totalParts: 4,      // Out of 4 total parts
        ),
      ),
    );
  },
  child: Text('Scan Part 1'),
)
```

### Example 2: View & Merge Documents

```dart
// Add button to view all documents

ElevatedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PoeDocumentManager(
          learnerId: learner.id,
          learnerName: learner.name,
        ),
      ),
    );
  },
  icon: Icon(Icons.folder),
  label: Text('View POE Documents'),
)
```

## 🎨 User Interface

### Document Manager Screen

```
┌─────────────────────────────────────┐
│ POE Documents              [Merge]  │
├─────────────────────────────────────┤
│ John Doe                            │
│ Learner ID: 12345                   │
├─────────────────────────────────────┤
│ 💡 Tip: Select multiple documents   │
│    to merge them into one PDF       │
├─────────────────────────────────────┤
│ ☐ POE_12345_part1.pdf              │
│   📄 18.5 MB • 50 pages             │
│   22/12/2025 14:30                  │
│   Part 1 of 4                       │
├─────────────────────────────────────┤
│ ☐ POE_12345_part2.pdf              │
│   📄 17.8 MB • 50 pages             │
│   22/12/2025 14:45                  │
│   Part 2 of 4                       │
├─────────────────────────────────────┤
│ ☐ POE_12345_part3.pdf              │
│   📄 18.2 MB • 50 pages             │
│   22/12/2025 15:00                  │
│   Part 3 of 4                       │
├─────────────────────────────────────┤
│ ☐ POE_12345_part4.pdf              │
│   📄 16.1 MB • 45 pages             │
│   22/12/2025 15:15                  │
│   Part 4 of 4                       │
└─────────────────────────────────────┘
```

After selecting all 4:

```
┌─────────────────────────────────────┐
│ 4 documents selected      [Clear]   │
├─────────────────────────────────────┤
│ ☑ POE_12345_part1.pdf (selected)   │
│ ☑ POE_12345_part2.pdf (selected)   │
│ ☑ POE_12345_part3.pdf (selected)   │
│ ☑ POE_12345_part4.pdf (selected)   │
├─────────────────────────────────────┤
│  [Merge 4 Documents]                │
└─────────────────────────────────────┘
```

After merging:

```
┌─────────────────────────────────────┐
│ POE Documents                       │
├─────────────────────────────────────┤
│ ✅ POE_12345_merged_170300.pdf     │
│   📄 70.6 MB • 195 pages            │
│   22/12/2025 15:20                  │
│   [MERGED DOCUMENT]                 │
├─────────────────────────────────────┤
│ ☑ POE_12345_part1.pdf (merged)     │
│ ☑ POE_12345_part2.pdf (merged)     │
│ ☑ POE_12345_part3.pdf (merged)     │
│ ☑ POE_12345_part4.pdf (merged)     │
└─────────────────────────────────────┘
```

## 📊 Technical Details

### Database Changes
**No schema changes needed!** Uses existing `poe_documents` table.

New document types:
- `POE` - Single complete document
- `POE_PART` - Part of multi-part document
- `POE_MERGED` - Merged document

New status values:
- `active` - Available for use
- `merged` - Part that was merged

### PDF Merging Process
1. Fetch document records from database
2. Verify all belong to same learner
3. Load PDF files from server
4. Use FPDI to merge PDFs page by page
5. Save merged PDF to server
6. Create new database record
7. Mark original parts as "merged"

### File Naming
- Parts: `POE_{learner_id}_{timestamp}_{unique}.pdf`
- Merged: `POE_{learner_id}_merged_{timestamp}.pdf`

## ✅ Benefits

### For Users
- ✅ No scanner limitations (scan in small batches)
- ✅ Each batch uploads quickly
- ✅ Can resume if interrupted
- ✅ Final result is one complete PDF
- ✅ Easy to manage multiple documents

### For System
- ✅ Works within Google ML Kit limitations
- ✅ Reliable uploads (smaller files)
- ✅ Original parts kept as backup
- ✅ Flexible (can merge any documents)
- ✅ No data loss

## 🧪 Testing Checklist

- [ ] Install FPDI on server
- [ ] Upload merge_poe_documents.php
- [ ] Test merge endpoint with test_merge_poe.php
- [ ] Update Flutter app
- [ ] Scan Part 1 (50 pages)
- [ ] Scan Part 2 (50 pages)
- [ ] Open document manager
- [ ] Select both parts
- [ ] Merge documents
- [ ] Verify merged PDF has 100 pages
- [ ] Download merged PDF
- [ ] Verify all pages present

## 🎯 Summary

**Question:** Can we merge scanned batches into one file?

**Answer:** YES! ✅

**How:**
1. Scan in batches (50-100 pages each)
2. Each batch uploads as "Part X of Y"
3. Open document manager
4. Select all parts
5. Tap "Merge Documents"
6. Download complete merged PDF

**Result:**
- One complete 195-page PDF
- All pages from all batches
- Ready to view or download
- Original parts kept as backup

**Status:** Fully implemented and ready to deploy! 🚀

## 📞 Support

If you need help:
1. Run `test_merge_poe.php` to check installation
2. Check server logs for errors
3. Verify FPDI is installed
4. Test with 2 small documents first
5. Then test with full 195-page document

**Everything is ready - just install FPDI and deploy!** 🎉
