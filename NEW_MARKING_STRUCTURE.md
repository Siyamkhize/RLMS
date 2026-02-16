# New Marking Structure - POE Tab

## Visual Hierarchy

```
POE Details
│
├── 📚 Pathway 1
│   └── 🎓 Qualification 1
│       ├── 📋 Unit Standard 1
│       │   ├── ▶ Formative
│       │   │   ├── Exercise 1
│       │   │   ├── Exercise 2
│       │   │   └── [Comments & Submit]
│       │   └── ▶ Summative
│       │       ├── Exercise 1
│       │       ├── Exercise 2
│       │       └── [Comments & Submit]
│       │
│       └── 📋 Unit Standard 2
│           ├── ▶ Formative
│           └── ▶ Summative
│
├── 📚 Pathway 2
│   └── 🎓 Qualification 2
│       └── 📋 Unit Standard 3
│           ├── ▶ Formative
│           └── ▶ Summative
│
├── 📖 LogBook (Separate Section)
│   ├── 📋 Unit Standard 1 (LogBook)
│   │   ├── LogBook Exercise 1
│   │   ├── LogBook Exercise 2
│   │   └── [Comments & Submit]
│   │
│   └── 📋 Unit Standard 2 (LogBook)
│       ├── LogBook Exercise 1
│       └── [Comments & Submit]
│
└── 🔧 Pothole Checklist (Separate Section)
    ├── View Checklist (Scanned or System)
    ├── Marks Input
    ├── Comments
    └── [Submit Marks]
```

## Key Changes

### Before (Old Structure):
```
Unit Standard
├── Formative
├── Summative
└── LogBook  ❌ (nested under each unit standard)
```

### After (New Structure):
```
1. Unit Standards
   ├── Formative
   └── Summative

2. LogBook (Separate) ✅
   └── All LogBook Unit Standards

3. Pothole Checklist (Separate) ✅
   └── View & Mark
```

## Benefits

1. **Clear Separation** - Each major assessment type has its own section
2. **Better Organization** - LogBook items are grouped together
3. **Easy Navigation** - Assessors can quickly find what they need
4. **Consistent Flow** - Follows logical assessment progression
5. **Scalable** - Easy to add more sections in the future

## User Experience

### Assessor Workflow:

1. **Open POE Tab** → See all pathways/qualifications
2. **Expand Unit Standards** → Mark Formative and Summative
3. **Scroll to LogBook Section** → Mark all logbook items together
4. **Scroll to Pothole Checklist** → View and mark checklist

### Visual Indicators:

- 📚 **Pathway** - Top level grouping
- 🎓 **Qualification** - Second level
- 📋 **Unit Standard** - Individual standards
- 📖 **LogBook** - Separate section with book icon
- 🔧 **Pothole Checklist** - Separate section with construction icon

## Implementation Details

### Modified Methods:

1. **`build()`** - Now builds three main sections
2. **`_buildAssessmentTypeTiles()`** - Only shows Formative & Summative
3. **`_buildLogBookSection()`** - NEW! Collects and displays all logbook items
4. **`_buildPotholeChecklistMainSection()`** - NEW! Separate pothole checklist section

### Data Flow:

```
POE Data
├── Pathways → Qualifications → Unit Standards
│   └── Extract: Formative & Summative
│
├── Collect all LogBook items from all unit standards
│   └── Display in separate section
│
└── Check for Pothole Checklist
    └── Display in separate section
```

## Testing Checklist

- [ ] Unit standards show only Formative and Summative
- [ ] LogBook section appears separately after unit standards
- [ ] All logbook items from all unit standards are collected
- [ ] Pothole Checklist section appears last
- [ ] Each section can be expanded/collapsed independently
- [ ] Marking functionality works in all sections
- [ ] Comments can be submitted for each section
- [ ] Visual icons display correctly

## Future Enhancements

Potential additions to this structure:

1. **Practical Assessments** - Another separate section
2. **Workplace Assessments** - For on-site evaluations
3. **Portfolio of Evidence** - Document uploads
4. **Final Assessment** - Overall marking summary
5. **Moderation** - Moderator review section

## Code Location

**File:** `lib/AssessorPage.dart`

**Key Methods:**
- Line ~2110: `build()` method with new structure
- Line ~2200: `_buildAssessmentTypeTiles()` (Formative & Summative only)
- Line ~2280: `_buildLogBookSection()` (NEW)
- Line ~2350: `_buildPotholeChecklistMainSection()` (NEW)
- Line ~2360: `_buildPotholeChecklistSection()` (existing, now called from main section)
