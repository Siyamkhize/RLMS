# Quick Reference - Moderator Class Filtering

## 🎯 What Changed?
Moderation sampling now filters learners by moderator's allocated classes.

## 📁 Files Modified
- `get_learners_with_poe_assigned.php`

## 📁 Files Created
- `test_moderator_class_filtering.php`
- Documentation files (5 files)

## 🔑 Key Requirement
**Moderators MUST be in the `facilitator` table with their class assignments!**

## 🚀 Quick Deploy

### 1. Upload File
```bash
# Upload to server
get_learners_with_poe_assigned.php
```

### 2. Verify Database
```sql
-- Check moderator has classes
SELECT * FROM facilitator WHERE facilitator_id = 'YOUR_ID';
```

### 3. Test
```
http://your-server/test_moderator_class_filtering.php?moderator_id=YOUR_ID
```

### 4. Verify in App
- Login as moderator
- Check learners shown
- Verify classes match

## 🔍 Quick Checks

### Check Moderator Classes
```sql
SELECT f.classID, c.className
FROM facilitator f
LEFT JOIN class c ON f.classID = c.classID
WHERE f.facilitator_id = '123';
```

### Check Learners in Classes
```sql
SELECT COUNT(DISTINCT l.LearnerID)
FROM learnerdetails l
INNER JOIN poe p ON l.LearnerID = p.learnerID
WHERE p.filePath IS NOT NULL
AND l.classID IN (
    SELECT classID FROM facilitator WHERE facilitator_id = '123'
);
```

### Check Assignments
```sql
SELECT ma.learner_id, l.Name, l.Surname, l.classID, c.className
FROM moderator_assignments ma
INNER JOIN learnerdetails l ON ma.learner_id = l.LearnerID
LEFT JOIN class c ON l.classID = c.classID
WHERE ma.moderator_id = '123';
```

## ⚠️ Common Issues

### No Learners Shown
**Cause:** Moderator not in `facilitator` table
**Fix:** Add moderator to `facilitator` with their classes

### Wrong Learners Shown
**Cause:** Incorrect class assignments
**Fix:** Update `facilitator` table with correct classes

### API Error
**Cause:** Database connection or query issue
**Fix:** Check PHP error logs

## 📊 How It Works

```
Moderator Request
    ↓
Get Moderator's Classes (from facilitator table)
    ↓
Filter Learners (only from moderator's classes)
    ↓
Stratified Sampling (25% from each stratum)
    ↓
Assign to Moderator
    ↓
Return Filtered Learners
```

## ✅ Success Indicators

- ✅ Moderators see only their class learners
- ✅ Test script passes all checks
- ✅ No API errors
- ✅ Sampling still works (25% per stratum)
- ✅ Mobile app shows correct learners

## 🔄 Rollback

If issues occur:
1. Restore previous `get_learners_with_poe_assigned.php`
2. No database changes to revert
3. System returns to showing all learners

## 📞 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Moderator sees 0 learners | Check `facilitator` table |
| Wrong classes shown | Verify class assignments |
| API error | Check PHP logs |
| Slow performance | Check database indexes |
| Test script fails | Verify database connection |

## 🎓 Key Concepts

**Facilitator Table:** Links moderators to classes
**Class Filtering:** Only learners from moderator's classes
**Stratified Sampling:** 25% from each stratum (within filtered pool)
**Persistent Assignment:** Once assigned, learners stay with moderator

## 📝 Quick SQL Reference

```sql
-- Add moderator to class
INSERT INTO facilitator (facilitator_id, classID) 
VALUES ('123', 'CLASS_A');

-- Remove moderator from class
DELETE FROM facilitator 
WHERE facilitator_id = '123' AND classID = 'CLASS_A';

-- View all moderator-class assignments
SELECT f.facilitator_id, f.classID, c.className
FROM facilitator f
LEFT JOIN class c ON f.classID = c.classID
ORDER BY f.facilitator_id, c.className;

-- Count learners per moderator's classes
SELECT 
    f.facilitator_id,
    f.classID,
    c.className,
    COUNT(DISTINCT l.LearnerID) as learner_count
FROM facilitator f
LEFT JOIN class c ON f.classID = c.classID
LEFT JOIN learnerdetails l ON c.classID = l.classID
LEFT JOIN poe p ON l.LearnerID = p.learnerID AND p.filePath IS NOT NULL
GROUP BY f.facilitator_id, f.classID, c.className;
```

## 🔗 Related Files

- `MODERATION_SAMPLING_CLASS_FILTERING_COMPLETE.md` - Full documentation
- `DEPLOY_MODERATOR_CLASS_FILTERING.md` - Deployment guide
- `MODERATOR_CLASS_FILTERING_SUMMARY.md` - Summary
- `MODERATOR_CLASS_FILTERING_FLOW.txt` - Visual diagram
- `MODERATOR_CLASS_FILTERING_CHECKLIST.md` - Detailed checklist

## 📅 Implementation Info

**Date:** January 30, 2026
**Status:** Complete
**Version:** 1.0
**Backward Compatible:** Yes
**Database Changes:** None

---

**Need Help?** Check the full documentation files or run the test script.
