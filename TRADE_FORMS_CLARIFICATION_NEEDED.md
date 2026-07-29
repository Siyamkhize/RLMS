# Trade-Specific ARPL Forms - Clarification Questions

**Goal:** Create Electrician, Bricklayer, and Plumber versions of ARPL forms

---

## Quick Confirmation Needed

### Question 1: Task Content
For **Bricklayer** and **Plumber**, should I use:

**Option A:** Generic placeholder tasks (14 tasks each for Appendix F)
```
Example Bricklayer:
1. Prepare materials
2. Layout work
3. Build wall section 1
... (generic numbered tasks)
14. Cleanup
```

**Option B:** Specific realistic tasks for the trade
```
Example Bricklayer:
1. Prepare mortar and materials
2. Build cavity walls  
3. Build corner details
4. Lay decorative bonds
5. Point and finish joints
... (trade-specific realistic tasks)
```

**My Recommendation:** Option B (realistic tasks) - More useful for actual assessments

---

### Question 2: Content Depth
For **Appendix B, C, D, E** (Activities, Curriculum, Criteria, Ratings), should I:

**Option A:** Keep exact same structure as Electrician (just change trade name)
- Faster to implement
- All content generic
- Less customization

**Option B:** Create trade-specific content
- Longer to implement
- More accurate to trade requirements
- Better for assessors

**My Recommendation:** Option A for MVP, then Option B later if needed

---

### Question 3: Database
Current database has single tables. Do I need to:

**Option A:** Create trade-specific table versions
- `arpl_appendix_f_electrician`
- `arpl_appendix_f_bricklayer`
- `arpl_appendix_f_plumber`
- etc.

**Option B:** Keep single tables and add `trade_id` column
- Simpler schema
- Easier to query
- Less duplication

**My Recommendation:** Option B (add trade_id column)

---

### Question 4: Implementation Order
Should I create:

**Option A:** All three forms (Electrician, Bricklayer, Plumber) immediately
- Takes ~30 minutes
- Complete system ready
- More work upfront

**Option B:** Bricklayer first, then Plumber later
- Takes ~15 minutes now
- Can add Plumber when needed
- Phased approach

**My Recommendation:** Option A (all three now for consistency)

---

## Summary of Defaults I'll Use

If you don't specify otherwise, I'll implement with:

1. **Realistic trade-specific tasks** for each trade
2. **Trade-generic content** for Appendices B, C, D, E (add trade customization later)
3. **Option B** - Add trade_id to existing tables (simpler than new tables)
4. **Option A** - Create all three trade forms now

---

## Simple Approval Checklist

Just check the boxes for what you want:

```
CONTENT DEPTH:
☐ Realistic trade-specific tasks (Recommended)
☐ Generic placeholder tasks

CUSTOMIZATION:
☐ Generic content for all appendices (Quick implementation)
☐ Trade-specific content for all appendices (More work)

DATABASE:
☐ Add trade_id to existing tables (Recommended)
☐ Create separate tables per trade

IMPLEMENTATION:
☐ Create all three trades now
☐ Create Bricklayer now, Plumber later

PROCEED:
☐ Yes, proceed with defaults (Option 1 above)
☐ Let me customize first
```

---

## What I'll Create (If You Say "Proceed")

### New Files
1. `ArplToolkitRouter.dart` - Smart router based on OFO
2. `ArplToolkitElectricianPage.dart` - Current form renamed
3. `ArplToolkitBricklayerPage.dart` - Bricklayer version with realistic tasks
4. `ArplToolkitPlumberPage.dart` - Plumber version with realistic tasks

### Modified Files
1. Navigation code - Point to router instead of viewer
2. Database queries - Support trade filtering (if Option B chosen)

### Build Time
- ~25 minutes total
- ~20 minute APK build

---

## Next: Just Confirm

**What trade-specific tasks do you want?**

Provide comma-separated lists like:
```
Electrician: (keep current or list new ones)
Bricklayer: task1, task2, task3, ..., task13
Plumber: task1, task2, task3, ..., task13
```

Or just say: **"Use realistic defaults"** and I'll implement with best practices.

---

**Ready to proceed?** Just let me know! 🚀

