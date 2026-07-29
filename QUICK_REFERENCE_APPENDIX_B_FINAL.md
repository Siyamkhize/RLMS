# ✅ Appendix B - Quick Reference (FINAL)

## Status
✅ **PRODUCTION READY** with correct ratings table

---

## Trade-Specific Ratings Tables

| Trade | OFO Code | Activity Table | **Ratings Table** |
|-------|----------|---|---|
| Electrician | 671101 | arplappxb_electrician_activities | **arplappxe_electrician_activity_ratings** ✅ |
| Bricklaying | 641201 | arplappxb_bricklaying_activities | arplappxe_bricklaying_activity_ratings |
| Plumbing | 642601 | arplappxb_plumbing_activities | arplappxb_activity_ratings |

---

## Test URLs

**Electrician Learner 16389** (No ratings):
```
http://localhost:8080/web/web/web/arpl_pdf.php?learnerID=16389&classID=782&ofo_code=671101
```
→ Page 6: 22 activities, all "Not rated"

**Electrician Learner 20286** (With ratings):
```
http://localhost:8080/web/web/web/arpl_pdf.php?learnerID=20286&classID=782&ofo_code=671101
```
→ Page 6: 22 activities, 14 rated [4-5], 8 "Not rated"

---

## Ratings Query

```sql
SELECT activities.*, ratings.competency_scale_id as rating
FROM arplappxb_electrician_activities activities
LEFT JOIN arplappxe_electrician_activity_ratings ratings ON (
    ratings.activity_id = activities.activity_id
    AND ratings.learnerID = 20286
    AND ratings.ofo_number = '671101'
)
```

**Result**: 22 activities + 14 ratings ✅

---

## Files Updated

✅ `/web/arpl_pdf.php` - Source code updated  
✅ `/web/web/web/arpl_pdf.php` - Production deployed

---

## What Changed

**Before**: Used `arplappxb_activity_ratings` (wrong for electrician)  
**After**: Uses `arplappxe_electrician_activity_ratings` (correct) ✅

---

## Display Format

| Status | Display |
|--------|---------|
| Rated | `[4]` (green badge) |
| Unrated | `Not rated` (gray) |

---

**Ready to test!** 🚀
