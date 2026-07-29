# ARPL Trade-Specific Forms Implementation Plan

**Date:** July 9, 2026  
**Objective:** Create trade-specific ARPL assessment forms for Electrician, Bricklayer, and Plumber

---

## Architecture Overview

### Current System
- Single `ArplToolkitViewerPage.dart` for all trades
- Trade name determined by `_getTradeName(ofoNumber)` method
- All content generic/trade-agnostic

### New System
- **Trade Router** (`ArplToolkitRouter.dart`) - Entry point, checks OFO and routes to correct form
- **Trade-Specific Pages:**
  - `ArplToolkitElectricianPage.dart` (OFO: 671101)
  - `ArplToolkitBricklayerPage.dart` (OFO: 671103)
  - `ArplToolkitPlumberPage.dart` (OFO: 671102)

---

## OFO Mappings

```
671101 → Electrician
671102 → Plumber
671103 → Bricklayer
671104 → Carpenter (future)
671105 → Welder (future)
```

---

## Implementation Steps

### Phase 1: Create Trade Router (5 min)
✅ Create `ArplToolkitRouter.dart`
- Accepts: learnerID, classID, ofoNumber
- Logic: Check OFO → Route to correct page
- Default: Route to Electrician if OFO unknown

### Phase 2: Create Electrician Page (5 min)
✅ Copy current `ArplToolkitViewerPage.dart` → `ArplToolkitElectricianPage.dart`
- Rename class: `ArplToolkitViewerPageState` → `ArplToolkitElectricianPageState`
- Update trade-specific content as needed

### Phase 3: Create Bricklayer Page (10 min)
✅ Duplicate Electrician page → `ArplToolkitBricklayerPage.dart`
- Rename class to `ArplToolkitBricklayerPageState`
- Update task lists for bricklaying (Appendix F)
- Update practical criteria (Appendix D)
- Update activities (Appendix B, E)

### Phase 4: Create Plumber Page (10 min)
✅ Duplicate Electrician page → `ArplToolkitPlumberPage.dart`
- Rename class to `ArplToolkitPlumberPageState`
- Update task lists for plumbing
- Update practical criteria
- Update activities

### Phase 5: Update Navigation (2 min)
✅ Modify navigation calls to use router instead of viewer directly

---

## Database Considerations

### Current Tables
- `arpl_appendix_a` - Cover page
- `arpl_appendix_b` - Activities & Outcomes
- `arpl_appendix_c` - Curriculum Content
- `arpl_appendix_d` - Practical Criteria
- `arpl_appendix_e` - Ratings
- `arpl_appendix_f` - Knowledge/Practical/Workplace
- `arpl_appendix_g` - Observation Schedule
- `arpl_appendix_h` - Recommendations
- `arpl_appendix_i` - Reflection
- `arpl_appendix_j` - Employer Sign-off

### Trade-Specific Content
Options:
1. **Single tables with trade_id column** (Recommended for Phase 2)
   - Easier to manage
   - Less code duplication
   - Flexible for future trades

2. **Separate tables per trade** (Current approach)
   - `arpl_appendix_b_electrician`, `arpl_appendix_b_bricklayer`, etc.
   - More complex but fully isolated

**Recommendation:** Option 1 (add trade_id to existing tables)

---

## Task Lists by Trade

### Appendix F - Electrician (Current)
**Knowledge (8 questions):**
1. Electrical safety principles
2. Circuit analysis and design
3. Power distribution systems
4. Wiring and cable installation
5. Fault diagnosis and rectification
6. Testing and commissioning
7. Industry standards and codes
8. Energy efficiency

**Practical (13 tasks):**
1. Install domestic wiring
2. Test circuit continuity
3. Install switchboards
4. Commission power systems
5. Fault diagnosis
6. Cable termination
7. Cable tray installation
8. Grounding installation
9. Light fixture installation
10. Motor control circuits
11. Appliance installation
12. Load calculations
13. Safety device testing

**Workplace Observation (13 activities):**
Same 13 tasks with Tech Knowledge, Interpretation, Teamwork ratings

---

### Appendix F - Bricklayer (New)
**Knowledge (8 questions):**
1. Building materials and durability
2. Mortar composition and mixing
3. Bricklaying techniques and methods
4. Structural principles and load bearing
5. Quality control and standards
6. Health and safety in bricklaying
7. Building codes and regulations
8. Environmental considerations

**Practical (13 tasks):**
1. Prepare mortar and materials
2. Layout brickwork patterns
3. Build cavity walls
4. Build solid walls
5. Build corner details
6. Build openings (windows/doors)
7. Lay decorative bonds
8. Point and finish joints
9. Install lintels and reinforcement
10. Build piers and columns
11. Quality inspections
12. Scaffold use and safety
13. Cleanup and site management

**Workplace Observation (13 activities):**
Same 13 tasks with Tech Knowledge, Interpretation, Teamwork ratings

---

### Appendix F - Plumber (New)
**Knowledge (8 questions):**
1. Water supply systems and regulations
2. Drainage and waste systems
3. Pipe materials and selection
4. Joining and soldering techniques
5. Sanitary appliance installation
6. Heating systems basics
7. Health and safety in plumbing
8. Customer service and professionalism

**Practical (13 tasks):**
1. Pipe cutting and preparation
2. Copper tube bending
3. Soldering and brazing
4. Compression fitting installation
5. Threaded pipe installation
6. Waste pipe installation
7. Traps and ventilation
8. Tap and valve installation
9. Toilet pan installation
10. Shower and bath installation
11. Inspection and testing
12. Pressure testing systems
13. Maintenance and repairs

**Workplace Observation (13 activities):**
Same 13 tasks with Tech Knowledge, Interpretation, Teamwork ratings

---

## File Structure

```
lib/
├── ArplToolkitRouter.dart (NEW - Router for all trades)
├── ArplToolkitElectricianPage.dart (NEW - Renamed from current)
├── ArplToolkitBricklayerPage.dart (NEW - Duplicate with trade content)
├── ArplToolkitPlumberPage.dart (NEW - Duplicate with trade content)
└── [Keep old ArplToolkitViewerPage.dart as backup initially]

mobile/
├── get_arpl_toolkit_data.php (Already handles OFO check)
├── save_arpl_*.php (Already handles saves)
└── [May need trade_id parameter additions]
```

---

## Implementation Roadmap

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Create Trade Router | 5 min | Ready |
| 2 | Create Electrician Page | 5 min | Ready |
| 3 | Create Bricklayer Page | 10 min | Ready |
| 4 | Create Plumber Page | 10 min | Ready |
| 5 | Update Navigation | 2 min | Ready |
| 6 | Database Updates (Optional) | 10 min | Optional |
| 7 | Testing | 15 min | Ready |

**Total Time:** ~57 minutes (without database changes)

---

## Trade-Specific Content Details

### Common Structure (All Trades)
- Appendix A: Application Form (candidate info - same for all)
- Appendix B: Activities & Outcomes (trade-specific)
- Appendix C: Curriculum Content (trade-specific)
- Appendix D: Practical Criteria (trade-specific)
- Appendix E: Ratings (same structure, trade-specific content)
- Appendix F: Knowledge/Practical/Workplace (trade-specific tasks)
- Appendix G: Observation Schedule (same structure)
- Appendix H: Recommendations (same structure)
- Appendix I: Reflection (same structure)
- Appendix J: Employer Sign-off (same structure)

---

## Testing Plan

### Test Case 1: Electrician (671101)
1. Open form with OFO 671101
2. Verify electrician tasks shown
3. Verify electrician content in all appendices
4. Save and reload
5. Verify data persisted correctly

### Test Case 2: Bricklayer (671103)
1. Open form with OFO 671103
2. Verify bricklayer tasks shown
3. Verify bricklayer content in all appendices
4. Save and reload
5. Verify data persisted correctly

### Test Case 3: Plumber (671102)
1. Open form with OFO 671102
2. Verify plumber tasks shown
3. Verify plumber content in all appendices
4. Save and reload
5. Verify data persisted correctly

### Test Case 4: Unknown OFO
1. Open form with OFO 999999
2. Should default to Electrician or show error
3. Verify graceful handling

---

## Benefits

✅ **Scalable:** Easy to add new trades
✅ **Maintainable:** Each trade is independent
✅ **Flexible:** Trade-specific customization possible
✅ **Future-proof:** Can add more trades (Carpenter, Welder, etc.)
✅ **Clean:** Separation of concerns

---

## Next Steps

1. User confirms trade list and content
2. Start implementation with Trade Router
3. Create and test each trade-specific page
4. Update navigation
5. Full system testing

---

**Status:** Ready for Implementation ✅
**Approval:** Awaiting user confirmation

