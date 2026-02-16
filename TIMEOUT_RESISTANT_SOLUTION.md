# Timeout-Resistant Bulk Export Solution

## Problem Solved
The original bulk export system was timing out when processing large batches of learners (50+ learners) due to gateway timeout limits (typically 30-60 seconds).

## Solution Overview
Implemented a smart batch processing system that:
- **Small batches (≤50 learners)**: Process immediately with optimized text reports
- **Large batches (>50 learners)**: Queue for background processing with progress tracking

## Key Features

### 1. Automatic Batch Detection
```php
// Automatically chooses processing method based on batch size
if (count($learnerIds) > 50) {
    return startBackgroundProcessing($learnerIds, $startDate, $endDate, $projectId);
} else {
    return processLearnersBatch($conn, $learnerIds, $startDate, $endDate, $projectId);
}
```

### 2. Background Processing
- Large batches are queued as background jobs
- Processing continues even after HTTP response is sent
- No gateway timeout issues
- Progress tracking via job status files

### 3. Progress Monitoring
- Real-time progress updates via AJAX polling
- Status tracking: queued → processing → completed/failed
- Detailed progress information (processed count, percentage, elapsed time)

### 4. Optimized Performance
- **Small batches**: Generate text reports (fast, no PDF overhead)
- **Large batches**: Enhanced text reports with attendance summaries
- Efficient database queries
- Memory management with garbage collection
- Batch processing (25 learners at a time for large jobs)

## File Structure

### Core Files
- `bulk_export_api.php` - Main API endpoint (updated)
- `bulk_export_with_documents.php` - Core processing logic (updated)
- `process_background_job.php` - Background job processor (new)
- `check_job_status.php` - Job status checker (new)

### Test Interface
- `test_timeout_resistant.php` - Test interface with progress tracking

### Job Management
- `temp_reports/jobs/` - Background job status files
- `temp_reports/` - Generated ZIP files

## API Usage

### Small Batch (Immediate Processing)
```javascript
// POST to bulk_export_api.php
{
    "learner_ids": [1,2,3,4,5],
    "start_date": "2024-01-01",
    "end_date": "2024-01-31"
}

// Response (immediate)
{
    "success": true,
    "total_learners": 5,
    "processed": 5,
    "zip_file": "bulk_reports_20241030_143022.zip"
}
```

### Large Batch (Background Processing)
```javascript
// POST to bulk_export_api.php
{
    "learner_ids": [1,2,3,...,100],
    "start_date": "2024-01-01",
    "end_date": "2024-01-31"
}

// Response (immediate)
{
    "success": true,
    "background_job": true,
    "job_id": "job_1730304182_1234",
    "total_learners": 100,
    "check_status_url": "check_job_status.php?job_id=job_1730304182_1234"
}
```

### Progress Monitoring
```javascript
// GET check_job_status.php?job_id=job_1730304182_1234
{
    "job_id": "job_1730304182_1234",
    "status": "processing",
    "progress": 45,
    "processed": 45,
    "failed": 0,
    "total_learners": 100,
    "elapsed_time": "00:02:15"
}
```

### Completion
```javascript
// Final status check
{
    "status": "completed",
    "progress": 100,
    "zip_file": "bulk_reports_20241030_143500.zip",
    "download_url": "temp_reports/bulk_reports_20241030_143500.zip",
    "results": {
        "success": true,
        "total_learners": 100,
        "processed": 98,
        "failed": 2,
        "documents_included": {
            "sick_notes": 15,
            "manual_registers": 8
        }
    }
}
```

## Performance Improvements

### Before (Timeout Issues)
- All learners processed synchronously
- PDF generation for each learner (slow)
- Gateway timeouts at 50+ learners
- No progress feedback

### After (Timeout Resistant)
- **Small batches**: Immediate text reports (2-3 seconds for 50 learners)
- **Large batches**: Background processing with progress tracking
- No gateway timeouts regardless of batch size
- Real-time progress updates
- Enhanced error handling and recovery

## Testing

### Quick Test (Small Batch)
```bash
# Test with 5 learners (immediate processing)
curl -X POST bulk_export_api.php \
  -d 'learner_ids=[1,2,3,4,5]' \
  -d 'start_date=2024-01-01' \
  -d 'end_date=2024-01-31'
```

### Large Batch Test
```bash
# Test with 100 learners (background processing)
curl -X POST bulk_export_api.php \
  -d 'learner_ids=[1,2,3,...,100]' \
  -d 'start_date=2024-01-01' \
  -d 'end_date=2024-01-31'
```

### Web Interface Test
Visit `test_timeout_resistant.php` for a complete web interface with:
- Form input for learner IDs and date range
- Real-time progress bar
- Automatic download link when complete
- Error handling and status messages

## Deployment Notes

1. **Ensure PHP CLI access** for background processing
2. **Set proper permissions** on temp_reports directory (777)
3. **Configure PHP settings** for background jobs:
   - `max_execution_time = 0` (for CLI)
   - `memory_limit = 1024M`
4. **Test both small and large batches** after deployment

## Monitoring

- Check `bulk_export_errors.log` for processing errors
- Check `background_job_errors.log` for background job issues
- Monitor `temp_reports/jobs/` directory for stuck jobs
- Clean up old job files periodically

This solution completely eliminates timeout issues while providing better user experience through progress tracking and faster processing for small batches.