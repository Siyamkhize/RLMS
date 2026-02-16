# POE Bulk Scan & Tag System

## Overview
This system allows you to scan documents once and tag multiple questions with the same evidence, then sync them to the server using the existing `sync_PoeOnline.php` endpoint.

## How It Works

### 1. **Scan Documents Once**
- Use camera or gallery to scan/upload documents
- Multiple images can be added to a single submission
- All images are stored locally in the app's POE directory

### 2. **Automatically Tag ALL Questions**
- ALL questions are automatically tagged (no manual selection needed)
- Simple and efficient - scan once, all questions tagged
- Each question will be linked to the same document(s)

### 3. **Local Storage**
- All tagged questions are saved to the local SQLite database
- Each question gets its own POE record with `synced=0`
- Same document path is shared across all tagged questions
- Works completely offline

### 4. **Sync to Server**
- Uses the existing `sync_PoeOnline.php` endpoint
- Each POE record is synced individually (one HTTP request per question)
- After successful sync, record is marked as `synced=1`
- Failed syncs remain `synced=0` for retry later

## Database Structure

```sql
poe (
  poe_id INTEGER PRIMARY KEY AUTOINCREMENT,
  learnerID INTEGER,
  exercise TEXT,           -- Question/exercise number
  type TEXT,              -- 'Formative', 'Summative', or 'LogBook'
  filePath TEXT,          -- Comma-separated paths for multiple images
  submitted_at TIMESTAMP,
  synced INTEGER DEFAULT 0,
  logbook_text TEXT
)
```

## Files Created/Modified

### New Files:
- **`lib/poe_bulk_scan_page.dart`** - Main POE bulk scan UI
  - Scan/upload documents
  - Select questions to tag
  - Save locally and sync to server

### Modified Files:
- **`lib/config.dart`** - Added sync endpoint configurations

### PHP Endpoint Used:
- **`C:\xampp\htdocs\assessorReport2\mobile\sync_PoeOnline.php`** - Existing endpoint for syncing POE records

## Usage Flow

1. **Navigate to POE Bulk Scan Page**
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => PoeBulkScanPage(
         learnerID: 123,
         unitStandard: 'US001',
         assessmentType: 'Formative', // or 'Summative' or 'LogBook'
         questions: questionsListForUnitStandard,
       ),
     ),
   );
   ```

2. **User scans documents**
   - Camera scan or gallery upload
   - Multiple images supported

3. **User selects questions**
   - Checkbox for each question
   - Select all / deselect all toggle

4. **Save & Sync**
   - Saves all tagged questions to local database
   - Syncs each question individually to server using `sync_PoeOnline.php`
   - Shows success/failure feedback

## Offline Support

- **Fully Offline**: Works without internet - saves locally
- **Auto-Sync**: When online, syncs unsynced records (synced=0)
- **Resilient**: Failed syncs remain local for retry

## Benefits

1. ✅ **Scan once, tag many** - Efficient evidence collection
2. ✅ **Offline capable** - Works without internet
3. ✅ **Uses existing endpoint** - No new server changes needed
4. ✅ **Smart sync** - Only syncs what hasn't been synced
5. ✅ **User-friendly** - Clear UI with select all/deselect options

## Example Scenario

**Learner completes 5 formative questions on paper:**
1. Facilitator scans the paper once (1 or multiple images)
2. All 5 questions are automatically tagged
3. Clicks "Save & Sync POE"
4. App creates 5 POE records (one per question) with same document
5. App syncs each record to server using `sync_PoeOnline.php`
6. All 5 questions now have evidence uploaded

**Before:** Had to scan documents 5 separate times
**After:** Scan once, all questions auto-tagged - done!

## Technical Details

### Sync Logic (Using sync_PoeOnline.php)
```dart
// For each selected question:
1. Save to local database (synced=0)
2. Send HTTP POST to sync_PoeOnline.php with:
   - learnerID
   - exercise (question number)
   - type (assessment type)
   - submitted_at (timestamp)
   - file (first image from scanned documents)
3. On success: Update local record (synced=1)
4. On failure: Keep synced=0 for retry
```

### Error Handling
- Network errors: Save locally, show info message
- Server errors: Save locally, show info message
- Success: Show success message with count
- Partial sync: Show which questions synced successfully

## Future Enhancements

- [ ] Background auto-sync for unsynced POE records
- [ ] Batch retry for failed syncs
- [ ] Compression for images before sync
- [ ] Progress indicator for multi-question sync

