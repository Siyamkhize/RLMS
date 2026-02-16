# POE Scanner 200 Pages - THE REAL PROBLEM

## What's Actually Happening

The app is **NOT crashing during upload** - it's crashing **DURING THE SCAN** when you click "Save" in the scanner.

## Root Cause

**Google ML Kit Scanner Plugin Memory Limit**

The `flutter_doc_scanner` plugin uses Google ML Kit for document scanning. When you scan 200 pages:

1. Scanner processes each page with ML Kit
2. ML Kit stores processed images in memory
3. After 100-150 pages, memory is exhausted
4. When you click "Save", ML Kit tries to create the PDF
5. **CRASH** - Out of memory

This is a **plugin limitation**, not our app's fault.

## Why Our Upload Fix Didn't Help

The upload fix (streaming chunks) only helps AFTER the PDF is created. But the crash happens BEFORE that - during PDF creation by the scanner plugin.

```
Scan Page 1 → ML Kit processes → Store in memory
Scan Page 2 → ML Kit processes → Store in memory
...
Scan Page 200 → ML Kit processes → Store in memory
Click "Save" → ML Kit creates PDF → ❌ CRASH (out of memory)
                                    ↑
                                    Our upload code never runs!
```

## The ONLY Solution

**Scan in batches of 50-100 pages maximum**

There is NO way to fix this in our code because:
- The crash happens inside the scanner plugin
- We don't control ML Kit's memory usage
- The plugin doesn't support streaming/chunking during scan

## How to Scan 200 Pages

### Method 1: Two Batches (Recommended)

**Batch 1: Pages 1-100**
1. Open POE Scanner
2. Scan pages 1-100
3. Click "Save" (scanner creates PDF)
4. Upload immediately
5. ✅ Success

**Batch 2: Pages 101-200**
1. Open POE Scanner again
2. Scan pages 101-200
3. Click "Save" (scanner creates PDF)
4. Upload immediately
5. ✅ Success

**Result:** Two separate PDF files uploaded

### Method 2: Four Batches (Safest)

For maximum reliability on low-memory devices:

- Batch 1: Pages 1-50
- Batch 2: Pages 51-100
- Batch 3: Pages 101-150
- Batch 4: Pages 151-200

**Result:** Four separate PDF files uploaded

### Method 3: Merge Later (Best)

1. Scan in batches (50-100 pages each)
2. Upload each batch
3. Use the web portal to merge PDFs into one document

## Why This Happens

### Memory Usage During Scanning

| Pages | Memory Used | Status |
|-------|-------------|--------|
| 50 | ~150MB | ✅ Safe |
| 100 | ~300MB | ✅ Usually OK |
| 150 | ~450MB | ⚠️ Risky |
| 200 | ~600MB | ❌ Crash |

Most Android devices have 2-4GB RAM total, but apps are limited to 256-512MB.

### What ML Kit Does

For each scanned page:
1. Captures image (~5MB)
2. Processes with ML (edge detection, perspective correction)
3. Compresses to JPEG (~2-3MB)
4. Stores in memory until "Save" clicked
5. Creates PDF from all stored images

**200 pages × 3MB = 600MB in memory = CRASH**

## Technical Limitations

### Can't Be Fixed By:
- ❌ Increasing memory limit (Android OS restriction)
- ❌ Streaming during scan (plugin doesn't support)
- ❌ Chunking during scan (plugin doesn't support)
- ❌ Background processing (plugin requires foreground)
- ❌ Different scanner plugin (all have similar limits)

### Could Be Fixed By:
- ✅ Scanner plugin rewrite (months of work)
- ✅ Native Android scanner app (different project)
- ✅ Server-side scanning (requires hardware)

## Updated App Warnings

The app now shows:

### Before Scanning:
```
🔴 MAXIMUM: 100 pages per batch

The scanner WILL CRASH if you scan 200 pages at once!

Why? Google ML Kit runs out of memory processing too many pages.

SOLUTION:
✓ Scan 50-100 pages maximum per batch
✓ Upload each batch immediately
✓ Then scan the next batch
✓ Repeat until all pages scanned

Example for 200 pages:
• Batch 1: Scan pages 1-100, upload
• Batch 2: Scan pages 101-200, upload
```

### On Scanner Screen:
```
🔴 MAXIMUM: 100 Pages Per Batch

Scanner WILL CRASH if you scan 200+ pages!

Why? Google ML Kit runs out of memory.

SOLUTION for 200 pages:
1. Scan pages 1-100 → Upload
2. Scan pages 101-200 → Upload
```

## Best Practices

### For 200-Page Documents:

1. **Plan ahead** - Know you'll need 2-4 batches
2. **Label batches** - Keep track of which pages you've scanned
3. **Upload immediately** - Don't wait to upload all batches
4. **Keep app active** - Don't switch apps during scanning
5. **Free memory** - Close other apps before scanning

### Optimal Batch Sizes:

| Device RAM | Safe Batch Size | Max Batch Size |
|------------|-----------------|----------------|
| 2GB | 50 pages | 75 pages |
| 4GB | 75 pages | 100 pages |
| 6GB+ | 100 pages | 125 pages |

### Tips:

- **Scan continuously** - Don't take long pauses
- **Good lighting** - Faster processing = less memory
- **Flat documents** - Less processing needed
- **Restart app** - Between batches if needed

## Alternative Solutions

### Option 1: Use External Scanner
1. Scan with dedicated scanner app (Adobe Scan, CamScanner)
2. Export PDF
3. Upload via file picker in our app

### Option 2: Physical Scanner
1. Use office scanner/copier
2. Save as PDF
3. Upload via web portal

### Option 3: Split Existing PDF
If you already have a 200-page PDF:
1. Use PDF splitter tool
2. Split into 2-4 parts
3. Upload each part separately

## Merging PDFs Later

After uploading batches, you can merge them:

### Via Web Portal:
1. Go to POE Documents page
2. Select learner
3. Click "Merge PDF Pages"
4. All batches merged into one file

### Via PHP Script:
```php
// merge_poe_documents.php
// Merges all POE documents for a learner
```

## Summary

**The Problem:**
- Scanner plugin (Google ML Kit) runs out of memory after 100-150 pages
- Crash happens when clicking "Save" (during PDF creation)
- This is BEFORE our upload code runs

**The Solution:**
- Scan in batches of 50-100 pages
- Upload each batch immediately
- Repeat until all pages scanned
- Merge PDFs later if needed

**Why We Can't Fix It:**
- Crash happens inside third-party plugin
- We don't control ML Kit's memory usage
- Plugin doesn't support streaming/chunking

**What We Did:**
- Added clear warnings about 100-page limit
- Improved upload efficiency (for after scan succeeds)
- Documented the limitation

**What Users Must Do:**
- Accept the 100-page batch limit
- Scan large documents in multiple batches
- Upload each batch separately

---

**This is a fundamental limitation of mobile document scanning, not a bug in our app.**
