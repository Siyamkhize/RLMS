# POE Multi-Part Document Merging System

## 🎯 Overview

This system allows users to scan large POE documents in batches (e.g., 50 pages at a time) and then merge them into a single PDF for viewing or downloading.

## ✨ Features

1. **Scan in Batches** - Scan 50-100 pages at a time to avoid scanner limitations
2. **Mark as Parts** - Each batch is marked as "Part 1", "Part 2", etc.
3. **Merge Documents** - Combine multiple parts into one complete PDF
4. **View All Documents** - See all POE documents for a learner
5. **Download Merged PDF** - Get the complete document as one file

## 📊 Workflow

### Step 1: Scan First Batch (Pages 1-50)
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PoeDocumentScanner(
      learnerId: 12345,
      learnerName: 'John Doe',
      partNumber: 1,      // Mark as Part 1
      totalParts: 4,      // Total expected parts
    ),
  ),
);
```

**Result:** Document uploaded as "POE_PART" with note "Part 1 of 4"

### Step 2: Scan Remaining Batches
Repeat for pages 51-100 (Part 2), 101-150 (Part 3), 151-195 (Part 4)

### Step 3: View & Merge Documents
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PoeDocumentManager(
      learnerId: 12345,
      learnerName: 'John Doe',
    ),
  ),
);
```

**Actions:**
1. See all 4 parts listed
2. Select parts to merge (checkbox selection)
3. Tap "Merge Documents" button
4. System creates one complete PDF with all pages

### Step 4: Download Complete Document
- Merged document is marked as "POE_MERGED"
- Original parts are marked as "merged" (not deleted)
- Download the complete PDF

## 🗂️ Database Structure

### Document Types
- `POE` - Single complete document
- `POE_PART` - Part of a multi-part document
- `POE_MERGED` - Merged document created from multiple parts

### Status Values
- `active` - Available for viewing/merging
- `merged` - Part that has been merged into another document
- `archived` - Old document
- `deleted` - Soft deleted

## 📁 Files Created

### Flutter App
1. **lib/poe_document_scanner.dart** (Updated)
   - Added `partNumber` and `totalParts` parameters
   - Marks documents as POE_PART when part number is provided
   - Adds part info to notes field

2. **lib/poe_document_manager.dart** (New)
   - Lists all POE documents for a learner
   - Checkbox selection for merging
   - Merge button and progress indicator
   - View/download/delete options

### PHP Server
1. **merge_poe_documents.php** (New)
   - Merges multiple PDFs into one
   - Uses FPDI library for PDF manipulation
   - Marks original documents as merged
   - Creates new merged document record

### Database
- No schema changes needed
- Uses existing `poe_documents` table
- New document types: POE_PART, POE_MERGED

## 🔧 Installation

### 1. Install FPDI Library (PHP)
```bash
cd /path/to/your/server
composer require setasign/fpdi
```

Or download manually from: https://www.setasign.com/products/fpdi/downloads/

### 2. Upload PHP Files
```bash
# Upload to server
scp merge_poe_documents.php user@server:/path/to/mobile/
```

### 3. Update Flutter App
```bash
# Add new files to your project
# lib/poe_document_manager.dart is already created
# lib/poe_document_scanner.dart is already updated

flutter pub get
flutter build apk --release
```

## 💻 Usage Examples

### Example 1: Scan 195-Page Document in 4 Parts

```dart
// Part 1: Pages 1-50
await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PoeDocumentScanner(
      learnerId: learner.id,
      learnerName: learner.name,
      partNumber: 1,
      totalParts: 4,
    ),
  ),
);

// Part 2: Pages 51-100
await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PoeDocumentScanner(
      learnerId: learner.id,
      learnerName: learner.name,
      partNumber: 2,
      totalParts: 4,
    ),
  ),
);

// Part 3: Pages 101-150
await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PoeDocumentScanner(
      learnerId: learner.id,
      learnerName: learner.name,
      partNumber: 3,
      totalParts: 4,
    ),
  ),
);

// Part 4: Pages 151-195
await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PoeDocumentScanner(
      learnerId: learner.id,
      learnerName: learner.name,
      partNumber: 4,
      totalParts: 4,
    ),
  ),
);

// Now merge all parts
await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PoeDocumentManager(
      learnerId: learner.id,
      learnerName: learner.name,
    ),
  ),
);
```

### Example 2: Add Buttons to Learner Details Page

```dart
// In sdp_learners_page.dart or similar

Row(
  children: [
    Expanded(
      child: ElevatedButton.icon(
        onPressed: () => _scanPOEPart(1, 4),
        icon: Icon(Icons.document_scanner),
        label: Text('Scan Part 1'),
      ),
    ),
    SizedBox(width: 8),
    Expanded(
      child: ElevatedButton.icon(
        onPressed: () => _viewAllDocuments(),
        icon: Icon(Icons.folder),
        label: Text('View All'),
      ),
    ),
  ],
)

void _scanPOEPart(int partNumber, int totalParts) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PoeDocumentScanner(
        learnerId: widget.learner['id'],
        learnerName: widget.learner['name'],
        partNumber: partNumber,
        totalParts: totalParts,
      ),
    ),
  );
}

void _viewAllDocuments() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PoeDocumentManager(
        learnerId: widget.learner['id'],
        learnerName: widget.learner['name'],
      ),
    ),
  );
}
```

## 🔄 API Endpoints

### 1. Merge Documents
**POST** `/merge_poe_documents.php`

**Request:**
```json
{
  "document_ids": [1, 2, 3, 4],
  "learner_id": "12345",
  "mark_originals_as_merged": true
}
```

**Response:**
```json
{
  "success": true,
  "message": "Documents merged successfully",
  "merged_document": {
    "id": 5,
    "file_name": "POE_12345_merged_1703001234.pdf",
    "file_path": "uploads/poe_documents/POE_12345_merged_1703001234.pdf",
    "file_size": 75894321,
    "page_count": 195,
    "source_documents": 4
  }
}
```

### 2. List Documents for Merging
**GET** `/merge_poe_documents.php?learner_id=12345`

**Response:**
```json
{
  "success": true,
  "documents": [
    {
      "id": 1,
      "file_name": "POE_12345_part1.pdf",
      "page_count": 50,
      "status": "active"
    },
    {
      "id": 2,
      "file_name": "POE_12345_part2.pdf",
      "page_count": 50,
      "status": "active"
    }
  ],
  "total_documents": 2
}
```

## 🎨 UI Features

### Document List
- ✅ Checkbox selection for merging
- ✅ Visual indication of selected documents
- ✅ Shows file size and page count
- ✅ Displays upload date
- ✅ Marks merged documents with strikethrough
- ✅ Highlights merged documents with badge
- ✅ Pull to refresh

### Merge Button
- ✅ Only appears when 2+ documents selected
- ✅ Shows count of selected documents
- ✅ Confirmation dialog before merging
- ✅ Progress indicator during merge
- ✅ Success message after merge

### Document Actions
- 📄 View - Open PDF viewer
- ⬇️ Download - Download to device
- 🗑️ Delete - Remove document

## ⚠️ Important Notes

### Scanner Limitations
- Google ML Kit scanner fails with 100+ pages
- **Solution:** Scan in batches of 50-100 pages
- Each batch uploads successfully
- Merge batches into one complete document

### Merge Process
1. Original parts are NOT deleted
2. Original parts are marked as "merged"
3. New merged document is created
4. Merged document has type "POE_MERGED"
5. Notes field tracks source document IDs

### File Storage
- All PDFs stored in `uploads/poe_documents/`
- Merged PDFs have naming: `POE_{learner_id}_merged_{timestamp}.pdf`
- Original parts remain on server (for backup)

## 🧪 Testing

### Test Scenario 1: Scan & Merge 4 Parts
1. Scan Part 1 (50 pages) ✅
2. Scan Part 2 (50 pages) ✅
3. Scan Part 3 (50 pages) ✅
4. Scan Part 4 (45 pages) ✅
5. Open document manager ✅
6. Select all 4 parts ✅
7. Tap "Merge Documents" ✅
8. Verify merged PDF has 195 pages ✅

### Test Scenario 2: View Merged Document
1. Open document manager ✅
2. See merged document with "MERGED DOCUMENT" badge ✅
3. See original parts with strikethrough ✅
4. Download merged document ✅
5. Verify all pages present ✅

## 📝 Deployment Checklist

### Server
- [ ] Install FPDI library (`composer require setasign/fpdi`)
- [ ] Upload `merge_poe_documents.php`
- [ ] Test merge endpoint with curl/Postman
- [ ] Verify file permissions on uploads directory
- [ ] Check PHP memory limit (256MB recommended)

### Flutter App
- [ ] Add `lib/poe_document_manager.dart`
- [ ] Update `lib/poe_document_scanner.dart`
- [ ] Add navigation to document manager
- [ ] Test scanning with part numbers
- [ ] Test merge functionality
- [ ] Build and deploy APK

### Database
- [ ] No changes needed (uses existing table)
- [ ] Verify POE_PART and POE_MERGED types work
- [ ] Test status updates (active → merged)

## ✅ Summary

**Problem:** Scanner fails with 195 pages

**Solution:** 
1. Scan in batches of 50-100 pages
2. Mark each batch as a "part"
3. Merge parts into one complete PDF
4. Download/view the merged document

**Benefits:**
- ✅ Works within scanner limitations
- ✅ Each batch uploads quickly
- ✅ Can resume if interrupted
- ✅ Final result is one complete PDF
- ✅ Original parts kept as backup

**User Experience:**
1. User scans Part 1 → Uploads successfully
2. User scans Part 2 → Uploads successfully
3. User scans Part 3 → Uploads successfully
4. User scans Part 4 → Uploads successfully
5. User opens document manager
6. User selects all 4 parts
7. User taps "Merge Documents"
8. System creates one complete 195-page PDF
9. User downloads complete document

**Perfect solution for large documents!** 🎉
