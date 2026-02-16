# 🔴 TIMEOUT ISSUE - Performance Problem Detected

## Current Problem
The API is timing out after 30 seconds when processing just 3 learners. This indicates a serious performance bottleneck.

## 🔍 Diagnosis Steps

### Step 1: Run Simple Test
Upload and visit: `test_simple_api.php`

This will test:
- ✅ API file accessibility (should be instant)
- ✅ GET request (should be <1 second)
- ✅ Database connection (should be <1 second)
- ✅ Document fetching for 1 learner (should be <2 seconds)
- ✅ Individual query performance (should be <100ms each)

### Step 2: Identify the Bottleneck

**If GET request is fast but POST times out:**
→ Issue is in the processing logic (likely database queries or file operations)

**If database queries are slow (>1 second):**
→ Need to add database indexes or optimize queries

**If getLearnerDocuments is slow (>5 seconds):**
→ File system issue or too many file checks

## 🎯 Most Likely Issues

### Issue 1: Missing Database Indexes
**Symptom**: Queries take >1 second
**Solution**: Add indexes to speed up queries

```sql
-- Add indexes for better performance
CREATE INDEX idx_sick_note_learner_dates ON sick_note(learner_id, date_from, date_to);
CREATE INDEX idx_manual_clocking_learner_date ON manual_clocking(LearnerID, clock_date);
CREATE INDEX idx_learnerdetails_class ON learnerdetails(classID);
CREATE INDEX idx_class_site ON class(siteID);
```

### Issue 2: Too Many File System Checks
**Symptom**: getLearnerDocuments takes >5 seconds
**Solution**: The function checks multiple paths for each file. With many documents, this adds up.

**Quick Fix**: Reduce the number of path checks or cache results.

### Issue 3: N+1 Query Problem
**Symptom**: Processing time increases linearly with learner count
**Solution**: Fetch all data in bulk queries instead of per-learner queries.

## 🚀 Quick Fixes

### Fix 1: Optimize Database Queries

Instead of querying per learner, fetch all at once:

```php
// BAD: Query per learner (slow)
foreach ($learnerIds as $id) {
    $docs = getLearnerDocuments($conn, $id, $start, $end);
}

// GOOD: Query all at once (fast)
$allDocs = getAllLearnerDocuments($conn, $learnerIds, $start, $end);
```

### Fix 2: Skip File Existence Checks

If files are consistently in one location, skip the multiple path checks:

```php
// Instead of checking 10 paths, check just 1
$filePath = 'mobile/sicknotes/' . basename($document_path);
if (file_exists($filePath)) {
    // Use it
}
```

### Fix 3: Process in Smaller Batches

Instead of processing all 133 learners at once:

```php
// Process in batches of 10
$batchSize = 10;
for ($i = 0; $i < count($learnerIds); $i += $batchSize) {
    $batch = array_slice($learnerIds, $i, $batchSize);
    processBatch($batch);
}
```

## 📊 Expected Performance

**Target times:**
- 1 learner: <2 seconds
- 10 learners: <10 seconds
- 100 learners: <60 seconds
- 133 learners: <90 seconds

**Current times:**
- 3 learners: >30 seconds (TIMEOUT) ❌

This is 10x slower than expected!

## 🔧 Immediate Actions

### Action 1: Run Simple Test
```
Visit: https://rlms.rlms.co.za/test_simple_api.php
```

This will show you:
- Which queries are slow
- If file operations are slow
- If database connection is slow

### Action 2: Check Query Performance

If queries are slow, add indexes:
```sql
-- Run these in your database
CREATE INDEX idx_sick_note_learner_dates ON sick_note(learner_id, date_from, date_to);
CREATE INDEX idx_manual_clocking_learner_date ON manual_clocking(LearnerID, clock_date);
```

### Action 3: Simplify for Now

**Temporary workaround**: Skip document inclusion for now, just generate reports:

Comment out document fetching in `bulk_export_with_documents.php`:
```php
// Temporarily skip documents to test performance
// $documents = getLearnerDocuments($conn, $learnerID, $startDate, $endDate);
$documents = ['sick_notes' => [], 'manual_registers' => []];
```

This will tell us if the issue is with document fetching or report generation.

## 🎯 Testing Sequence

1. **Run test_simple_api.php**
   - Identify which operation is slow
   - Check query times
   - Check file operation times

2. **Add database indexes** (if queries are slow)
   - Run the CREATE INDEX commands
   - Test again

3. **Simplify document fetching** (if file ops are slow)
   - Reduce path checks
   - Cache file locations

4. **Test with 1 learner**
   - Should complete in <5 seconds
   - If not, there's still an issue

5. **Test with 10 learners**
   - Should complete in <30 seconds
   - If not, need more optimization

6. **Test with 133 learners**
   - Should complete in <2 minutes
   - If not, process in batches

## 📝 What to Look For

### In test_simple_api.php:

**Good results:**
```
GET Request: 0.5s ✅
Database query: 0.05s ✅
getLearnerDocuments: 1.2s ✅
All queries: <100ms ✅
```

**Bad results:**
```
GET Request: 0.5s ✅
Database query: 5.2s ❌ (SLOW!)
getLearnerDocuments: 15.3s ❌ (VERY SLOW!)
Sick notes query: 2.1s ❌ (SLOW!)
```

If you see slow results, that's your bottleneck!

## 🆘 Emergency Workaround

If you need bulk download to work NOW:

**Option 1**: Skip documents temporarily
- Comment out document fetching
- Just generate report summaries
- Add documents back later after optimization

**Option 2**: Reduce batch size
- Process only 10 learners at a time
- User clicks "Bulk Download" multiple times
- Not ideal but works

**Option 3**: Use existing reports
- If you have individual reports already generated
- Just ZIP them up without regenerating
- Much faster

## 📞 Next Steps

1. Upload `test_simple_api.php`
2. Visit it to see results
3. Identify the slow operation
4. Apply the appropriate fix
5. Test again

The simple test will tell us exactly what's slow!

---

**TL;DR**: The script is 10x slower than expected. Run `test_simple_api.php` to find out why.
