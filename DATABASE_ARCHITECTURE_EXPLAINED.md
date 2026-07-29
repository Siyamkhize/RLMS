# 📊 DATABASE ARCHITECTURE - VISUAL GUIDE
**Date:** July 22, 2026

---

## 🎯 THE KEY INSIGHT

### Why Electrician is Different:

```
┌─────────────────────────────────────────────────────────────┐
│  BRICKLAYER & PLUMBER (Share Everything)                    │
│  ═══════════════════════════════════════════════════════    │
│                                                              │
│  OFO Codes:    641201 (Bricklayer)  +  642601 (Plumber)    │
│                           ↓                                  │
│  Qualification ID:        65409  (SAME!)                    │
│                           ↓                                  │
│  Table:            unitstandard                             │
│                           ↓                                  │
│  Records:           35 unit standards                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  ELECTRICIAN (Uses Different System)                         │
│  ═══════════════════════════════════════                    │
│                                                              │
│  OFO Code:              671101                              │
│                           ↓                                  │
│  Qualification ID:      91761  (DIFFERENT!)                 │
│                           ↓                                  │
│  Table:    occupational_unit_standards  (DIFFERENT TABLE!)  │
│                           ↓                                  │
│  Records:           22 unit standards                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🗂️ TABLE RELATIONSHIPS

### Complete Database Structure:

```
┌────────────────────────────────────────────────────────────────────┐
│                     MASTER UNIT STANDARDS                          │
│  ════════════════════════════════════════════════════════════     │
│                                                                    │
│  ┌─────────────────────────┐    ┌──────────────────────────────┐ │
│  │  unitstandard            │    │ occupational_unit_standards  │ │
│  ├─────────────────────────┤    ├──────────────────────────────┤ │
│  │ qualification_id: 65409 │    │ qualification_id: 91761      │ │
│  │ unit_standard_id        │    │ unit_standard_id             │ │
│  │ unit_standard_name      │    │ unit_standard_name           │ │
│  │ credits                 │    │ credits                      │ │
│  │                         │    │                              │ │
│  │ Used by:                │    │ Used by:                     │ │
│  │   • Bricklayer          │    │   • Electrician              │ │
│  │   • Plumber             │    │                              │ │
│  │                         │    │                              │ │
│  │ Records: 35             │    │ Records: 22                  │ │
│  └─────────────────────────┘    └──────────────────────────────┘ │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
                              ↓
                    LEARNER ASSIGNMENTS
                              ↓
┌────────────────────────────────────────────────────────────────────┐
│                 TRADE-SPECIFIC GAP CLOSURE TABLES                  │
│  ════════════════════════════════════════════════════════════     │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  arplbricklayer_gap_unit_standards                           │ │
│  ├──────────────────────────────────────────────────────────────┤ │
│  │  learner_id, unit_standard_id, qualification_id: 65409       │ │
│  │  References: unitstandard table                              │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  arplelectrician_gap_unit_standards                          │ │
│  ├──────────────────────────────────────────────────────────────┤ │
│  │  learner_id, unit_standard_id, qualification_id: 91761       │ │
│  │  References: occupational_unit_standards table               │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  arplplumber_gap_unit_standards                              │ │
│  ├──────────────────────────────────────────────────────────────┤ │
│  │  learner_id, unit_standard_id, qualification_id: 65409       │ │
│  │  References: unitstandard table (SAME as Bricklayer)         │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 WORKFLOW VISUALIZATION

### How Gap Closure Works:

```
STEP 1: Assessor Opens Appendix H
         ↓
┌────────────────────────────────┐
│ Rate 4 Assessment Components   │
│  1. Portfolio of Evidence      │
│  2. Interview                  │
│  3. Practical Assessment       │
│  4. Overall Result ←── KEY!    │
└────────────────────────────────┘
         ↓
STEP 2: Assessor Selects Overall Result
         ↓
┌────────────────────────────────────────────────────────┐
│ Overall Result Options:                                │
│  • Not Ready                                           │
│  • Recommended                                         │
│  • Recommended for Gap Closure ←── Triggers gap UI    │
└────────────────────────────────────────────────────────┘
         ↓
STEP 3: IF "Recommended for Gap Closure" Selected
         ↓
┌────────────────────────────────────────────────────────┐
│ BACKEND QUERY (Trade-Specific):                       │
│                                                        │
│ Bricklayer:                                            │
│   SELECT * FROM unitstandard                           │
│   WHERE qualification_id = 65409                       │
│   → Returns 35 unit standards                          │
│                                                        │
│ Electrician:                                           │
│   SELECT * FROM occupational_unit_standards            │
│   WHERE qualification_id = 91761                       │
│   → Returns 22 unit standards                          │
│                                                        │
│ Plumber:                                               │
│   SELECT * FROM unitstandard                           │
│   WHERE qualification_id = 65409                       │
│   → Returns 35 unit standards (same as Bricklayer)     │
│                                                        │
└────────────────────────────────────────────────────────┘
         ↓
STEP 4: Display Gap Closure UI
         ↓
┌────────────────────────────────────────────────────────┐
│ Gap Closure Section (Conditional - only if selected)  │
│  ☐ Unit Standard 1                                    │
│  ☐ Unit Standard 2                                    │
│  ☐ Unit Standard 3                                    │
│  ... (list continues)                                 │
└────────────────────────────────────────────────────────┘
         ↓
STEP 5: Assessor Selects Which Unit Standards Learner Needs
         ↓
STEP 6: Save to Database
         ↓
┌────────────────────────────────────────────────────────┐
│ 2 Tables Updated:                                      │
│                                                        │
│ 1. arpl{trade}_access_recommendation                  │
│    → Stores the 4 ACR ratings + overall result        │
│                                                        │
│ 2. arpl{trade}_gap_unit_standards                     │
│    → Stores selected unit standards for learner       │
│    → Each selected unit standard = 1 row              │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## 📋 COMPARISON TABLE

### Trade-by-Trade Breakdown:

| Aspect | Bricklayer | Electrician | Plumber |
|--------|-----------|------------|---------|
| **OFO Code** | 641201 | 671101 | 642601 |
| **Qualification ID** | 65409 | 91761 | 65409 |
| **Unit Standards Table** | `unitstandard` | `occupational_unit_standards` | `unitstandard` |
| **# Unit Standards** | 35 | 22 | 35 (shared) |
| **Access Table** | `arplbricklayer_access_recommendation` | `arplelectrician_access_recommendation` | `arplplumber_access_recommendation` |
| **Gap Table** | `arplbricklayer_gap_unit_standards` | `arplelectrician_gap_unit_standards` | `arplplumber_gap_unit_standards` |
| **PHP Endpoints** | ✅ Deployed | 📦 Ready to deploy | 📦 Ready to deploy |
| **Flutter UI** | ✅ Working | ⏳ Not implemented | ⏳ Not implemented |

---

## 🔍 WHY THIS ARCHITECTURE?

### Historical Context:

**Old System:**
- All trades used `unitstandard` table
- Simple but limited

**New System (Occupational Framework):**
- Electricians moved to new qualification framework
- Uses `occupational_unit_standards` table instead
- Different qualification ID (91761 vs 65409)
- More flexible, aligns with industry standards

**Result:**
- Bricklayer & Plumber: Still use old system (qualification 65409, `unitstandard` table)
- Electrician: Uses new system (qualification 91761, `occupational_unit_standards` table)

---

## 🎓 PRACTICAL EXAMPLE

### Real Learner Scenario:

```
Learner: John Smith (Electrician, ID 11701)
═══════════════════════════════════════════════

1. Assessor reviews John's portfolio (Appendix H)

2. Assessor rates:
   - Portfolio: Recommended
   - Interview: Recommended
   - Practical: Recommended
   - Overall: Recommended for Gap Closure ← Needs some unit standards

3. System queries database:
   Query: SELECT * FROM occupational_unit_standards WHERE qualification_id = 91761
   Result: Returns 22 electrician unit standards

4. System shows UI with 22 checkboxes:
   ☐ 123456 - Install and maintain electrical systems
   ☐ 123457 - Perform electrical testing
   ☐ 123458 - Wire distribution boards
   ... (19 more)

5. Assessor selects 3 unit standards John needs to complete

6. System saves:
   Table 1: arplelectrician_access_recommendation
     - LearnerID: 11701
     - ACRID: 4 (Overall Result)
     - Status: "Recommended for Gap Closure"

   Table 2: arplelectrician_gap_unit_standards
     - Row 1: learner_id=11701, unit_standard_id=123456, status=Pending
     - Row 2: learner_id=11701, unit_standard_id=123457, status=Pending
     - Row 3: learner_id=11701, unit_standard_id=123458, status=Pending

7. John now has a clear list of what he needs to complete!
```

---

## ✅ SUMMARY

### Key Points to Remember:

1. **OFO Code ≠ Qualification ID**
   - OFO Code: Occupational code (industry classification)
   - Qualification ID: Educational framework identifier

2. **Electrician Uses Different Table**
   - Table: `occupational_unit_standards` (NOT `unitstandard`)
   - Qualification: 91761 (NOT 65409)
   - This is CORRECT and by design!

3. **Bricklayer & Plumber Share Data**
   - Same table: `unitstandard`
   - Same qualification: 65409
   - Same 35 unit standards
   - This is also CORRECT!

4. **Each Trade Has 2 Tables**
   - `arpl{trade}_access_recommendation` - Stores ACR ratings
   - `arpl{trade}_gap_unit_standards` - Stores selected unit standards

5. **Backend is Trade-Aware**
   - Each trade has its own PHP endpoints
   - Endpoints query correct table for that trade
   - No risk of cross-contamination

---

**Understanding this architecture is key to successful deployment!**

If you have questions about any part of this, ask before proceeding with deployment.
