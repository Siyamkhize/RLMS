# Diagnosing Why Appendix I Data Is Not Showing

## The Problem
Appendix I recommendations are not displaying in the PDF, even though:
- ✓ Data exists in the database
- ✓ Queries work when tested directly
- ✓ Code syntax is valid

## Possible Causes

### 1. **OFO Code Not Being Passed Correctly**

**Symptom**: PDF defaults to Plumber (642601) instead of Electrician (671101)

**How to Check**: Look at the URL you're using to generate the PDF
```
WRONG: /web/arpl_pdf.php?learnerID=20286&classID=782
       (missing ofo_code parameter - defaults to 642601)

CORRECT: /web/arpl_pdf.php?learnerID=20286&classID=782&ofo_code=671101
         (includes ofo_code - will query electrician table)
```

**Solution**: Make sure the URL includes `&ofo_code=671101` for Electrician

---

### 2. **ClassID Is Wrong or Missing**

**Symptom**: PDF won't load at all, or shows error

**Check**: The PDF requires classID. If missing, it tries to look it up from learnerID.
```
MUST HAVE: learnerID AND classID
Optional: ofo_code (defaults to 642601 if not provided)
```

---

### 3. **Data Exists but Not for This Specific Learner in This Trade**

**What We Know**:
- Learner 20286 has data in `arplelectrician_access_recommendation`
- But maybe that learner is NOT enrolled in Electrician trade class
- So when the PDF loads with default Plumber (642601), it won't find data

**Check**: Verify learner's actual trade
```sql
SELECT c.className, s.qualification_id 
FROM class c 
JOIN sites s ON c.siteID = s.siteID 
WHERE c.classID = (
  SELECT classID FROM learnerdetails WHERE LearnerID = 20286 LIMIT 1
)
```

---

## How to Fix

### Step 1: Generate PDF with Correct OFO Code

If generating for Electrician learner 20286, use:
```
http://localhost:8080/web/arpl_pdf.php?learnerID=20286&classID=782&ofo_code=671101
```

### Step 2: Check the Debug Output

The debug line at the bottom of Appendix I now shows:
```
DEBUG: OFO: 671101, Learner: 20286, Table: arplelectrician_access_recommendation, FOUND
```

If you see `NOT_FOUND` instead of `FOUND`, then the query isn't finding the record.

### Step 3: Verify Database Has Data

Run this query:
```sql
SELECT * FROM arplelectrician_access_recommendation 
WHERE LearnerID = 20286
LIMIT 1;
```

Must return at least 1 row.

---

## Common Issues & Solutions

| Symptom | Cause | Solution |
|---------|-------|----------|
| Appendix I shows "Not Yet Recorded" | OFO code doesn't match learner's trade | Add correct `&ofo_code=` to URL |
| Appendix I shows "Not Yet Recorded" | Query finds no data | Verify data exists in correct table |
| DEBUG shows "NOT_FOUND" | Data exists but not retrieving | Check table name and LearnerID match |
| DEBUG shows "FALLBACK_NOT_FOUND" | OFO code not in mapping | Update `$ofoToTable` array |

---

## Quick Fix

**Most likely cause**: You're not passing the `ofo_code` parameter in the URL.

**Solution**: When generating PDF for Electrician learner, include:
```
&ofo_code=671101
```

**Example URL**:
```
http://localhost:8080/web/arpl_pdf.php?learnerID=20286&classID=782&ofo_code=671101
```

---

## Verification Checklist

- [ ] URL includes `learnerID` parameter
- [ ] URL includes `classID` parameter  
- [ ] URL includes `&ofo_code=671101` (for Electrician)
- [ ] PDF loads without error
- [ ] Appendix I shows debug info at bottom
- [ ] Debug info shows "FOUND" not "NOT_FOUND"
- [ ] Recommendation data displays in Appendix I

If any checkbox fails, that's the issue.

---

## Files to Check

**For Development**: 
- Look for how the PDF is being called/linked from the web interface
- Make sure `ofo_code` is being passed from wherever the PDF link is generated

**Current State**:
- Query logic: ✓ Working (tested)
- Display logic: ✓ Updated with debug info
- Database: ✓ Has data

**The Issue**: Almost certainly the URL parameters being passed.

---

## Next Steps

1. **Look at where the PDF link is generated** - Find the code that creates the link to `arpl_pdf.php`
2. **Make sure it includes the OFO code** - Should pass `&ofo_code=` parameter
3. **Test the direct URL** - Try the example URL above manually
4. **Check the debug output** - It will tell you exactly what's happening

---

**The bottom line**: The code works. The data exists. If Appendix I isn't showing data, the PDF is being called with the wrong parameters (wrong OFO code or wrong learner).
