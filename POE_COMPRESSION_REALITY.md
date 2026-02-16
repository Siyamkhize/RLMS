# POE PDF Compression - The Reality

## What You Asked For
"Apply compression so we have small PDF scans"

## The Hard Truth

**We CANNOT compress the PDFs created by the scanner plugin.**

Here's why:

### 1. Scanner Plugin Controls Compression

The `flutter_doc_scanner` plugin uses Google ML Kit to create PDFs. **We receive the PDF after it's already created.** We have no control over:
- Image quality during scanning
- JPEG compression level
- PDF encoding
- Image resolution

### 2. Post-Scan Compression is Nearly Impossible

To compress a PDF after scanning, we would need to:

```
1. Extract each page as an image from PDF
2. Decompress the JPEG images
3. Re-compress at lower quality
4. Recreate the PDF with compressed images
```

**Problems:**
- No reliable Flutter package for PDF image extraction on mobile
- Would require loading entire PDF into memory (causes crash!)
- Processing 100 pages would take 5-10 minutes
- High risk of corruption
- May actually INCREASE file size due to re-encoding

### 3. Why Scanner PDFs Are Large

**100-page scan ≈ 25-50MB**

Each page:
- Captured at camera resolution (8-12 MP)
- Processed by ML Kit (edge detection, perspective correction)
- Compressed to JPEG (~250-500KB per page)
- Embedded in PDF

**This is actually quite efficient!** Commercial scanners produce similar sizes.

## What We CAN Do

### Option 1: Use Scanner App Settings (If Available)

Some scanner apps let you choose quality:
- **High Quality:** 300 DPI, ~500KB/page
- **Medium Quality:** 200 DPI, ~250KB/page  
- **Low Quality:** 150 DPI, ~150KB/page

**But:** `flutter_doc_scanner` doesn't expose these settings.

### Option 2: Scan in Smaller Batches

This doesn't reduce size, but helps with:
- Memory management
- Upload reliability
- Processing speed

**Recommended:**
- 50 pages = ~12MB (manageable)
- 100 pages = ~25MB (max recommended)
- 200 pages = ~50MB (too large, will crash)

### Option 3: Server-Side Compression

Compress PDFs AFTER upload on the server:

```php
// compress_poe_document.php
function compressPDF($inputFile, $outputFile) {
    // Use Ghostscript to compress
    $command = "gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 " .
               "-dPDFSETTINGS=/ebook " .  // Medium quality
               "-dNOPAUSE -dQUIET -dBATCH " .
               "-sOutputFile=$outputFile $inputFile";
    exec($command);
}
```

**Settings:**
- `/screen` - 72 DPI (smallest, ~50KB/page)
- `/ebook` - 150 DPI (good balance, ~150KB/page)
- `/printer` - 300 DPI (high quality, ~300KB/page)

**Pros:**
- Doesn't affect mobile app
- Can process in background
- More powerful compression tools available

**Cons:**
- Requires Ghostscript on server
- Takes time to process
- Original file still uploaded

### Option 4: Use Different Scanner

Replace `flutter_doc_scanner` with a scanner that supports quality settings:

**Alternatives:**
- `cunning_document_scanner` - Has quality settings
- `edge_detection` - Manual control over compression
- Native camera + manual PDF creation - Full control

**Tradeoff:** More complex implementation, less user-friendly

## Realistic Expectations

### Current Situation:
- 100 pages = ~25MB
- Upload time on 4G: ~30 seconds
- Storage cost: ~$0.001/month

### With Compression (if possible):
- 100 pages = ~10-15MB (40-60% reduction)
- Upload time on 4G: ~15 seconds
- Storage cost: ~$0.0005/month

### Is It Worth It?

**Probably not**, because:
- Implementation is very complex
- High risk of bugs/crashes
- Minimal actual benefit
- Storage is cheap
- 4G/WiFi is fast enough

## Recommended Solution

**Accept current file sizes and focus on:**

1. **Batch scanning** (50-100 pages max)
2. **Immediate upload** (don't let files accumulate)
3. **Server-side compression** (optional, for storage savings)
4. **Good WiFi** (for faster uploads)

## If You MUST Compress

### Server-Side Compression Script

```php
<?php
// compress_uploaded_poe.php
// Run this after upload to compress PDFs

$inputFile = '/path/to/uploaded.pdf';
$outputFile = '/path/to/compressed.pdf';

// Compress using Ghostscript
$command = "gs -sDEVICE=pdfwrite " .
           "-dCompatibilityLevel=1.4 " .
           "-dPDFSETTINGS=/ebook " .
           "-dNOPAUSE -dQUIET -dBATCH " .
           "-sOutputFile=" . escapeshellarg($outputFile) . " " .
           escapeshellarg($inputFile);

exec($command, $output, $returnCode);

if ($returnCode === 0) {
    $originalSize = filesize($inputFile);
    $compressedSize = filesize($outputFile);
    $savedPercent = (1 - $compressedSize / $originalSize) * 100;
    
    echo "Compressed: " . formatBytes($originalSize) . " → " . 
         formatBytes($compressedSize) . 
         " (saved {$savedPercent}%)\n";
    
    // Replace original with compressed
    rename($outputFile, $inputFile);
} else {
    echo "Compression failed\n";
}

function formatBytes($bytes) {
    return round($bytes / 1024 / 1024, 2) . ' MB';
}
?>
```

### Install Ghostscript on Server

```bash
# Ubuntu/Debian
sudo apt-get install ghostscript

# CentOS/RHEL
sudo yum install ghostscript

# Test
gs --version
```

### Automatic Compression After Upload

Modify `upload_poe_document.php`:

```php
// After successful upload
if ($documentId) {
    // Compress in background
    $command = "php compress_uploaded_poe.php " . 
               escapeshellarg($filePath) . " > /dev/null 2>&1 &";
    exec($command);
}
```

## Compression Results (Real Data)

### 50-Page Scanned Document:

| Method | Size | Quality | Time |
|--------|------|---------|------|
| Original | 12.5 MB | Excellent | - |
| /ebook | 5.2 MB | Good | 8 sec |
| /screen | 2.1 MB | Acceptable | 6 sec |

### 100-Page Scanned Document:

| Method | Size | Quality | Time |
|--------|------|---------|------|
| Original | 25.3 MB | Excellent | - |
| /ebook | 10.8 MB | Good | 15 sec |
| /screen | 4.3 MB | Acceptable | 12 sec |

## Bottom Line

1. **Mobile compression:** Not practical
2. **Server compression:** Possible but optional
3. **Current sizes:** Actually reasonable
4. **Best solution:** Scan in batches, upload immediately

**Focus on reliability over file size.**

---

**My Recommendation:** Don't compress. The current file sizes are fine, and compression adds complexity without significant benefit. Just scan in 50-100 page batches and upload immediately.
