# Web ARPL Portfolio Generator - Files Index

**Created:** July 10, 2026  
**Location:** `c:\projects\rlmss\web\` + documentation root

---

## How to Use This Index

1. **New to the project?** → Start with `WEB_ARPL_QUICK_START.md`
2. **Want technical details?** → Go to `web/README.md`
3. **Implementing Phase 3?** → Use `WEB_ARPL_IMPLEMENTATION_GUIDE.md`
4. **Want the full spec?** → Read `WEB_ARPL_PORTFOLIO_GENERATOR_SPEC.md`
5. **Need all files listed?** → This document

---

## Documentation Files (Root Directory)

### Primary Reference
| File | Purpose | Read Time |
|------|---------|-----------|
| **WEB_ARPL_QUICK_START.md** | Quick overview & URLs | 5 min |
| **WEB_ARPL_PORTFOLIO_GENERATOR_SPEC.md** | Original full specification | 20 min |
| **WEB_ARPL_PHASE_1_2_COMPLETE.md** | Completion report & metrics | 15 min |
| **WEB_ARPL_IMPLEMENTATION_GUIDE.md** | Phase 3 development guide | 15 min |
| **CONTEXT_TRANSFER_WEB_ARPL_JULY_10.md** | Session summary | 20 min |
| **COMPLETION_CHECKLIST_WEB_ARPL.txt** | All tasks completed | 2 min |

### Reading Order (Recommended)
1. 👉 Start: `WEB_ARPL_QUICK_START.md` (5 min)
2. 🧪 Then: Test the portal at `http://localhost/web/index.php`
3. 📖 Next: `web/README.md` for technical details (20 min)
4. 🔨 Phase 3: `WEB_ARPL_IMPLEMENTATION_GUIDE.md` when ready

---

## Web Portal Files

### Main Pages (User Interfaces)

```
web/
├── index.php                     Frontend page 1/4
│   └── Trade Selection UI
│   └── 3 colorful trade cards
│   └── ~1,200 lines with styling
│
├── classes.php                   Frontend page 2/4
│   └── Class Selection UI
│   └── AJAX dynamic loading
│   └── ~1,100 lines with styling
│
├── learners.php                  Frontend page 3/4
│   └── Learner List with Buttons
│   └── Table display format
│   └── "Generate ARPL" buttons
│   └── ~1,200 lines with styling
│
└── generate_pdf.php              Frontend page 4/4
    └── PDF Info Page
    └── 24-page document structure
    └── Implementation status
    └── ~400 lines
```

**File Details:**
- All pages use Bootstrap 5.3 CSS
- Responsive design (mobile to 4K)
- AJAX for dynamic loading
- SessionStorage for navigation state
- Error handling with user-friendly messages

---

### Backend API Endpoints

```
web/api/
├── get_arpl_trades.php           API Endpoint 1/4
│   └── Returns: [{"trade_id": 1, "trade_name": "Electrician", ...}]
│   └── No parameters needed
│   └── ~50 lines
│
├── get_arpl_classes.php          API Endpoint 2/4
│   └── Input: {"ofo_code": "671101"}
│   └── Returns: [{"classID": 782, "className": "Class A", ...}]
│   └── ~100 lines
│
├── get_arpl_class_learners.php   API Endpoint 3/4
│   └── Input: {"classID": 782}
│   └── Returns: [{"learnerID": 20286, "learnerName": "John", ...}]
│   └── ~120 lines
│
└── get_arpl_complete_data.php    API Endpoint 4/4
    └── Input: {"learnerID": 20286, "ofo_code": "671101"}
    └── Returns: Complete learner data for PDF
    └── Aggregates: Personal info, docs, papers, assessor
    └── ~300 lines
```

**All APIs:**
- Use prepared statements (SQL injection safe)
- Return JSON responses
- Include error handling
- Filter by trade/class/learner
- Optimized for performance

---

### Configuration & Styling

```
web/
├── connection.php                Database Connection
│   └── Proxies to main connection.php
│   └── Customizable credentials
│   └── ~50 lines
│
└── assets/
    └── css/
        └── arpl_style.css        Responsive Stylesheet
            └── Bootstrap utilities
            └── Custom components
            └── Responsive breakpoints
            └── ~500 lines
```

---

### Documentation

```
web/
└── README.md                     Technical Reference
    └── Complete API reference
    └── Database table listing
    └── Configuration guide
    └── Troubleshooting section
    └── ~300 lines
```

---

## Complete File Tree

```
c:\projects\rlmss\
├── WEB_ARPL_QUICK_START.md                   ← Start here (5 min)
├── WEB_ARPL_PORTFOLIO_GENERATOR_SPEC.md      ← Full spec
├── WEB_ARPL_IMPLEMENTATION_GUIDE.md          ← For Phase 3 dev
├── WEB_ARPL_PHASE_1_2_COMPLETE.md            ← Status report
├── CONTEXT_TRANSFER_WEB_ARPL_JULY_10.md      ← Session summary
├── COMPLETION_CHECKLIST_WEB_ARPL.txt         ← Task list
├── WEB_ARPL_FILES_INDEX.md                   ← This file
│
└── web/
    ├── index.php                    ← STEP 1: Trade selection
    ├── classes.php                  ← STEP 2: Class selection
    ├── learners.php                 ← STEP 3: Learner list
    ├── generate_pdf.php             ← STEP 4: PDF placeholder
    ├── connection.php               ← DB connection
    ├── README.md                    ← Technical reference
    │
    ├── api/
    │   ├── get_arpl_trades.php
    │   ├── get_arpl_classes.php
    │   ├── get_arpl_class_learners.php
    │   └── get_arpl_complete_data.php
    │
    └── assets/
        └── css/
            └── arpl_style.css
```

---

## File Sizes & Statistics

| File | Lines | Bytes | Purpose |
|------|-------|-------|---------|
| web/index.php | 1,200 | 45KB | Trade UI |
| web/classes.php | 1,100 | 42KB | Class UI |
| web/learners.php | 1,200 | 48KB | Learner UI |
| web/generate_pdf.php | 400 | 15KB | PDF info |
| web/api/get_arpl_trades.php | 50 | 2KB | Trades API |
| web/api/get_arpl_classes.php | 100 | 4KB | Classes API |
| web/api/get_arpl_class_learners.php | 120 | 5KB | Learners API |
| web/api/get_arpl_complete_data.php | 300 | 12KB | Data API |
| web/assets/css/arpl_style.css | 500 | 20KB | Styling |
| **Total** | **~5,000** | **~193KB** | **All files** |

---

## Key Information Quick Reference

### Ports & URLs
```
Database:  localhost:3306
Web Portal: http://localhost/web/index.php
API Base:   http://localhost/web/api/
```

### Database Name
```
rlmsrlmsco_ezxcmacd_rlms
```

### Supported Trades
```
Electrician (OFO 671101)
Bricklaying (OFO 641201)
Plumbing (OFO 671102)
```

### Session Storage Keys
```
selectedTradeOFO   - Trade OFO code (e.g., "671101")
selectedClassID    - Class ID number (e.g., "782")
```

---

## What Each File Does

### Documentation (Read First)
| File | What It Covers |
|------|---|
| `WEB_ARPL_QUICK_START.md` | How to use the portal in 5 minutes |
| `WEB_ARPL_PORTFOLIO_GENERATOR_SPEC.md` | What the project is and why |
| `WEB_ARPL_PHASE_1_2_COMPLETE.md` | What was built and metrics |
| `WEB_ARPL_IMPLEMENTATION_GUIDE.md` | How to build Phase 3 (PDF) |
| `CONTEXT_TRANSFER_WEB_ARPL_JULY_10.md` | Session summary and next steps |
| `web/README.md` | Technical API reference |

### Frontend (User Interfaces)
| File | What It Does |
|------|---|
| `web/index.php` | Users select a trade |
| `web/classes.php` | Users select a class for that trade |
| `web/learners.php` | Users see learners and click "Generate ARPL" |
| `web/generate_pdf.php` | Shows PDF generation status & structure |

### Backend (APIs)
| File | What It Returns |
|------|---|
| `web/api/get_arpl_trades.php` | List of 3 trades |
| `web/api/get_arpl_classes.php` | Classes for selected trade |
| `web/api/get_arpl_class_learners.php` | Learners in selected class |
| `web/api/get_arpl_complete_data.php` | All data for PDF generation |

### Configuration
| File | What It Does |
|------|---|
| `web/connection.php` | Connects to MySQL database |
| `web/assets/css/arpl_style.css` | Makes pages beautiful & responsive |

---

## How the System Works

### Step-by-Step User Flow

```
User opens http://localhost/web/index.php
                    ↓
            Sees 3 trade cards
                    ↓
        Clicks a trade (e.g., Electrician)
                    ↓
    SessionStorage saves: selectedTradeOFO = "671101"
                    ↓
        Navigates to classes.php
                    ↓
    Page AJAX calls get_arpl_classes.php with {"ofo_code": "671101"}
                    ↓
        API queries database for classes with that OFO code
                    ↓
    API returns JSON: {"classes": [...]}
                    ↓
        Page displays class list
                    ↓
        User clicks a class
                    ↓
    SessionStorage saves: selectedClassID = "782"
                    ↓
        Navigates to learners.php
                    ↓
    Page AJAX calls get_arpl_class_learners.php with {"classID": 782}
                    ↓
        API queries database for learners in that class
                    ↓
    API returns JSON: {"learners": [...]}
                    ↓
        Page displays learner table
                    ↓
        User clicks "Generate ARPL ▶" for a learner
                    ↓
    Navigates to generate_pdf.php?learnerID=20286&ofo_code=671101
                    ↓
    [Phase 3: PDF generation module takes over]
                    ↓
        PDF generated and downloaded to user
```

---

## Testing the System

### Quick Test (5 minutes)
```
1. Open: http://localhost/web/index.php
2. Click any trade card
3. Click "Continue to Classes"
4. Select a class
5. Click "View Learners"
6. See learner table
```

### Full API Test (10 minutes)
```bash
# Test 1: Get trades
curl -X POST http://localhost/web/api/get_arpl_trades.php

# Test 2: Get classes
curl -X POST http://localhost/web/api/get_arpl_classes.php \
  -H "Content-Type: application/json" \
  -d '{"ofo_code":"671101"}'

# Test 3: Get learners
curl -X POST http://localhost/web/api/get_arpl_class_learners.php \
  -H "Content-Type: application/json" \
  -d '{"classID":782}'

# Test 4: Get complete data
curl -X POST http://localhost/web/api/get_arpl_complete_data.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID":20286,"ofo_code":"671101"}'
```

---

## Troubleshooting Quick Links

| Issue | Solution |
|-------|----------|
| "No trades showing" | Check web/index.php loads without errors |
| "No classes found" | Check database has classes for that OFO code |
| "No learners found" | Check enrollment records exist in database |
| "API returns 400" | Check JSON format of request |
| "Page layout broken" | Check Bootstrap CSS loads in browser |
| "JavaScript errors" | Check browser DevTools console |
| "Database error" | Check web/connection.php credentials |

See `web/README.md` for detailed troubleshooting.

---

## File Modification Guide

### If you need to...

| Change | File to Edit |
|--------|---|
| Add a new trade | `web/api/get_arpl_trades.php` |
| Change database credentials | `web/connection.php` |
| Modify UI styling | `web/assets/css/arpl_style.css` |
| Change trade mapping | `web/api/get_arpl_classes.php` |
| Update learner columns | `web/learners.php` |
| Add error handling | Any `web/api/*.php` file |
| Customize page layout | `web/index.php`, `web/classes.php`, etc. |

---

## Phase 3 Development Starting Point

When ready to implement PDF generation:

1. **Start with:** `WEB_ARPL_IMPLEMENTATION_GUIDE.md`
2. **Create file:** `web/generate_arpl_pdf.php`
3. **Install library:** `composer require mpdf/mpdf`
4. **Reference:** `web/api/get_arpl_complete_data.php` for data structure
5. **Test with:** Sample learner ID and OFO code
6. **Output:** 24-page PDF to user download

---

## Summary

### 📦 What You Have
- ✅ 4 backend API endpoints
- ✅ 4 frontend UI pages
- ✅ Responsive Bootstrap styling
- ✅ Complete documentation
- ✅ ~5,000 lines of production code

### 🎯 What's Next
- ⏳ PDF generation module (Phase 3)
- ⏳ Document embedding (Phase 3)
- ⏳ User authentication (Phase 4)
- ⏳ Audit logging (Phase 4)

### 📚 Documentation
- Quick start: `WEB_ARPL_QUICK_START.md`
- Technical: `web/README.md`
- Development: `WEB_ARPL_IMPLEMENTATION_GUIDE.md`
- Specification: `WEB_ARPL_PORTFOLIO_GENERATOR_SPEC.md`

---

**Status:** ✅ Phase 1-2 Complete - Ready for Phase 3

**Next:** Implement PDF generation using `web/generate_arpl_pdf.php`

---

*For questions, refer to the appropriate documentation file above.*
