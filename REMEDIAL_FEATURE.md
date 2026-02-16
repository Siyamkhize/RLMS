# Remedial Section Feature

## Overview

Added an optional Remedial section for each unit standard to document additional support or re-assessment activities.

## Key Features

### 1. **Optional - No Restrictions**
- ✅ Does NOT block progress
- ✅ Does NOT require completion before moving to next unit
- ✅ Can be done at any time
- ✅ Independent of formative/summative completion

### 2. **Per Unit Standard**
- Each unit standard has its own remedial section
- Located after Summative section
- Clearly marked as "Optional"

### 3. **Same Offline Functionality**
- ✅ Works offline
- ✅ Saves locally when no internet
- ✅ Syncs automatically when online
- ✅ Shows in pending sync banner

### 4. **Visual Design**
- **Purple color** to distinguish from formative (blue) and summative (orange)
- **"Optional" badge** to indicate it's not required
- **Clear description** explaining its purpose

## UI Structure

```
Unit Standard Name
├── Formative (Blue)
│   ├── Questions list
│   └── Scan All Formative button
├── Summative (Orange)
│   ├── Questions list
│   └── Scan All Summative button
└── Remedial (Optional) (Purple)  ← NEW
    ├── Description
    └── Scan Remedial Document button
```

## How It Works

### User Flow:
1. User expands unit standard
2. Sees Formative, Summative, and Remedial sections
3. Remedial section shows:
   - "Remedial (Optional)" title with purple badge
   - Description: "Remedial assessments are optional and do not block progress..."
   - "Scan Remedial Document" button

### Scanning Remedial:
1. Click "Scan Remedial Document"
2. Signature verification
3. Choose camera or gallery
4. Scan document
5. Document saved as type: "Remedial"
6. Exercise name: "Remedial-{UnitStandardName}"

### Online:
- Uploads to server immediately
- Saved with type: "Remedial"
- Shows success message

### Offline:
- Saves to local database
- Shows orange "Saved offline" notification
- Appears in pending sync banner
- Syncs when back online

## Database Storage

### POE Table:
```sql
INSERT INTO poe (
  learnerID,
  type,           -- 'Remedial'
  exercise,       -- 'Remedial-Unit Standard Name'
  filePath,       -- Path to scanned document
  synced,         -- 0 (offline) or 1 (synced)
  submitted_at
)
```

### Example:
```
learnerID: 123
type: Remedial
exercise: Remedial-Apply Health and Safety Practices
filePath: /path/to/document.pdf
synced: 0
```

## Key Differences from Formative/Summative

| Aspect | Formative/Summative | Remedial |
|--------|---------------------|----------|
| Required | ✅ Yes | ❌ No (Optional) |
| Blocks progress | ✅ Yes | ❌ No |
| Multiple questions | ✅ Yes | ❌ No (single document) |
| Sequence enforcement | ✅ Yes | ❌ No (can do anytime) |
| Color | Blue/Orange | Purple |

## Use Cases

### 1. Re-Assessment
Learner failed formative/summative and needs to redo it. Scan the re-assessment document as remedial.

### 2. Additional Support
Learner needed extra tutoring or support. Document the additional work done.

### 3. Supplementary Evidence
Additional proof of competence beyond the standard assessments.

### 4. Intervention Documentation
Document any interventions or additional training provided.

## Technical Implementation

### Method: `_openRemedialCamera()`
- Takes unit standard name as parameter
- No sequence checking (always allowed)
- No prerequisite checking
- Saves as type: "Remedial"
- Exercise name: "Remedial-{UnitStandard}"

### Key Code:
```dart
Future<void> _openRemedialCamera(BuildContext context, String unitStandard) async {
  // No restrictions - always allowed
  // Signature verification
  // Scan document
  // Save as type: 'Remedial'
  // Exercise: 'Remedial-$unitStandard'
}
```

## Console Logging

When scanning remedial:
```
[REMEDIAL] Opening remedial camera for unit standard: Apply Health and Safety
[REMEDIAL] Uploaded to server successfully
```

Or offline:
```
[REMEDIAL] Opening remedial camera for unit standard: Apply Health and Safety
[POE_OFFLINE] Document saved to: /path/to/file
[POE_OFFLINE] Saved locally: learnerID=123, exercise=Remedial-Apply Health and Safety, type=Remedial
```

## Benefits

✅ **Flexibility** - Can document additional work without restrictions
✅ **Optional** - Doesn't force users to complete unnecessary steps
✅ **Clear** - Clearly marked as optional
✅ **Consistent** - Works same way as other POE types
✅ **Offline-ready** - Full offline support
✅ **Trackable** - Appears in sync status and reports

## Testing

### Test 1: Scan Remedial Online
1. Expand unit standard
2. Expand "Remedial (Optional)" section
3. Click "Scan Remedial Document"
4. Scan document
5. **Expected:** Document uploads to server ✅

### Test 2: Scan Remedial Offline
1. Go offline
2. Expand unit standard
3. Expand "Remedial (Optional)" section
4. Click "Scan Remedial Document"
5. Scan document
6. **Expected:** Document saves locally ✅
7. **Expected:** Orange notification shown ✅
8. **Expected:** Appears in pending sync banner ✅

### Test 3: Remedial Doesn't Block Progress
1. Skip remedial section
2. Move to next unit standard
3. **Expected:** Can proceed without any restrictions ✅

### Test 4: Multiple Remedials
1. Scan remedial for Unit Standard 1
2. Scan remedial for Unit Standard 2
3. **Expected:** Both saved independently ✅

## Server-Side Considerations

The server should handle "Remedial" type the same way as other POE types:
- Accept uploads with type: "Remedial"
- Store in POE table
- Include in reports
- Mark as optional in reporting

## Future Enhancements (Optional)

- Allow multiple remedial documents per unit standard
- Add remedial-specific notes/comments
- Link remedial to specific formative/summative questions
- Remedial completion statistics in reports

## Summary

The Remedial section provides a flexible, optional way to document additional support and re-assessment activities without blocking learner progress. It integrates seamlessly with the existing POE system and works fully offline.

**Key Point:** Remedial is completely optional and never restricts or blocks anything! 🎉
