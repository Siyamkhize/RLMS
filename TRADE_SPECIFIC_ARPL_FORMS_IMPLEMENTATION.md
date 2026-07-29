# Trade-Specific ARPL Toolkit Forms Implementation

**Date:** July 9, 2026  
**Status:** ✅ PHASE 1 & 2 COMPLETE - Ready for Database Migration and Testing

---

## Overview

Implemented trade-specific ARPL Toolkit Assessment Forms for three trades:
- **Electrician** (OFO 671101) - Existing refactored form
- **Bricklayer** (OFO 671103) - New trade-specific form
- **Plumber** (OFO 671102) - New trade-specific form

---

## Architecture Summary

### Database Structure
- **Electrician:** Uses original tables (`arpl_appendix_*`)
- **Bricklayer:** Uses `arpl_appendix_*_bricklayer` tables
- **Plumber:** Uses `arpl_appendix_*_plumber` tables

Each trade has separate database tables for:
- Appendix F: Practical Assessment Evaluation (Main + Practical Tasks + Workplace Observations)
- Appendix A: Application Form
- Appendix C: Trade Curriculum
- Appendix D: Practical Skills
- Appendix G: Appeals Form
- Appendix I: Statement of Results
- Appendix J: Pre-Assessment Agreement

### Smart Routing
- **ArplToolkitRouter**: Routes to correct toolkit based on OFO number
- **Automatic Trade Detection**: System checks learner's OFO and loads appropriate form
- **Trade Parameters**: All API calls include trade parameter for database routing

### OFO Mappings
```
671101 → Electrician (default)
671102 → Plumber
671103 → Bricklayer
```

---

## Files Created/Modified

### Phase 1: SQL Migration Scripts
✅ Created: `create_arpl_bricklayer_tables.sql`
- 9 tables for Bricklayer trade
- Identical schema to Electrician tables, renamed for bricklayer

✅ Created: `create_arpl_plumber_tables.sql`
- 9 tables for Plumber trade
- Identical schema to Electrician tables, renamed for plumber

**TODO:** Execute SQL scripts against production database

### Phase 2: PHP API Updates
✅ Updated: `mobile/get_arpl_toolkit_data.php`
- Added trade parameter support
- Added helper functions: `getTradeName()` and `getTableName()`
- Routes all queries to trade-specific tables
- Auto-detects trade from OFO if not provided

✅ Updated: `mobile/save_arpl_appendix_f_assessment.php`
- Added trade parameter support
- Routes saves to trade-specific tables
- Dynamic table name construction
- Includes trade in response

✅ Updated: `lib/config.dart`
- Added `getArplSaveToolkitDataUrl` config endpoint

### Phase 3: Dart Frontend Pages
✅ Created: `lib/ArplToolkitRouter.dart`
- Smart routing based on OFO number
- Directs to electrician/bricklayer/plumber pages
- Falls back to electrician if unknown trade

✅ Created: `lib/ArplToolkitBricklayerPage.dart`
- Full bricklayer-specific form
- 13 bricklaying-specific practical tasks
- 13 workplace observations
- Bricklayer trade identifier

✅ Created: `lib/ArplToolkitPlumberPage.dart`
- Full plumber-specific form
- 13 plumbing-specific practical tasks
- 13 workplace observations
- Plumber trade identifier

✅ Updated: `lib/ArplToolkitViewerPage.dart`
- Now used exclusively for Electrician (already existed)
- No changes needed - works as-is

✅ Updated: `lib/ArplAssessorPage.dart`
- Changed 3 navigation imports from `ArplToolkitViewerPage` to `ArplToolkitRouter`
- All toolkit navigation now routes through router for intelligent trade selection
- Maintains backward compatibility with existing code

---

## Practical Tasks by Trade

### Bricklayer (13 Tasks)
1. Reading and interpreting architectural drawings and specifications
2. Setting out brickwork with appropriate measuring and marking tools
3. Preparing and mixing mortar to required consistency
4. Building cavity walls and demonstrating knowledge of cavity tie placement
5. Building solid walls with proper bonding patterns
6. Constructing arches and openings
7. Pointing and jointing brickwork to specifications
8. Building in lintels, wall plates, and other components
9. Constructing brick piers and chimney stacks
10. Building curved brickwork and special features
11. Applying protective treatments and finishes
12. Health, safety, and environmental compliance in brickwork
13. Quality control and defect rectification in brickwork

### Plumber (13 Tasks)
1. Reading and interpreting plumbing plans, drawings and specifications
2. Selecting and using appropriate plumbing tools and equipment safely
3. Preparing and assembling copper pipe components and systems
4. Preparing and assembling plastic (PVC/HDPE) pipe components and systems
5. Identifying and managing different water supply systems (cold water, hot water)
6. Installing and testing sanitation systems (waste and drainage)
7. Identifying and using appropriate fittings, valves and controls
8. Installing and testing central heating systems
9. Identifying and resolving common plumbing defects and failures
10. Complying with plumbing codes, regulations and environmental requirements
11. Health, safety and environmental compliance in plumbing work
12. Quality control and testing in plumbing installations
13. Customer communication and project completion procedures

---

## Build Status

✅ **BUILD SUCCESSFUL**
- APK: `build/app/outputs/flutter-apk/app-debug.apk`
- All Dart syntax errors resolved
- All property names corrected (lowercaselearner properties)
- All imports updated correctly
- Ready for installation and testing

---

## How the System Works

### 1. Loading Toolkit Data
```
ArplAssessorPage 
  ↓ (Select learner with OFO)
ArplToolkitRouter (checks OFO: 671101/671102/671103)
  ↓
Routes to appropriate page:
  - 671101 → ArplToolkitViewerPage (Electrician)
  - 671102 → ArplToolkitPlumberPage (Plumber)
  - 671103 → ArplToolkitBricklayerPage (Bricklayer)
  ↓
PHP: get_arpl_toolkit_data.php
  - Receives: learnerID, classID, ofoNumber, trade
  - Auto-detects trade if not provided
  - Routes queries to appropriate trade tables
  - Returns trade-specific data
```

### 2. Saving Assessment Data
```
Toolkit Page (User enters scores/observations)
  ↓
Save button triggers save
  ↓
Dart Page builds payload with trade parameter
  ↓
PHP: save_arpl_appendix_f_assessment.php
  - Receives: learnerID, ofoNumber, trade, tasks, observations
  - Routes INSERT statements to trade-specific tables
  - Saves practically tasks and observations for the trade
  ↓
Response: Success/Error with trade confirmation
```

### 3. Database Routing
```
getTradeName(ofoNumber) → Returns: 'electrician', 'bricklayer', or 'plumber'
  ↓
getTableName(appendix, trade) → Returns appropriate table name
  ↓
Example:
- getTableName('f', 'bricklayer') → 'arpl_appendix_f_bricklayer'
- getTableName('f_tasks', 'plumber') → 'arpl_appendix_f_practical_tasks_plumber'
```

---

## Migration Checklist

### ✅ Completed
- [x] SQL migration scripts created (Bricklayer & Plumber)
- [x] PHP API updated for trade routing
- [x] Config file updated with save endpoint
- [x] Dart router created
- [x] Bricklayer page created
- [x] Plumber page created
- [x] Navigation updated in ArplAssessorPage
- [x] Build successful (no errors)

### ⏳ TODO (Next Phase)
- [ ] Execute SQL migration scripts on development database
- [ ] Test data loading for each trade
- [ ] Test data saving for each trade
- [ ] Install APK on device and verify routing
- [ ] Test trade-specific task lists display correctly
- [ ] Test offline sync with trade-specific tables
- [ ] Create backup/restore scripts for trade tables
- [ ] Deploy to production database
- [ ] Update staff training materials

---

## Testing Recommendations

### Unit Testing
```dart
// Test trade detection
getTradeName('671101') == 'electrician' ✓
getTradeName('671102') == 'plumber' ✓
getTradeName('671103') == 'bricklayer' ✓

// Test table name generation
getTableName('f', 'bricklayer') contains '_bricklayer' ✓
getTableName('f_tasks', 'plumber') contains 'plumber' ✓
```

### Integration Testing
1. Load learner with OFO 671101 → Electrician form loads
2. Load learner with OFO 671102 → Plumber form loads
3. Load learner with OFO 671103 → Bricklayer form loads
4. Enter data in form → Save to correct trade table
5. Reload learner → Data appears from correct trade table

### Device Testing
1. Install APK on device
2. Select electrician learner → Form shows electrician tasks
3. Select plumber learner → Form shows plumber tasks
4. Select bricklayer learner → Form shows bricklayer tasks
5. Verify offline sync uses trade tables

---

## Configuration Summary

### Environment
- **Server:** 192.168.0.57:8080 (local dev)
- **Base Path:** /assessorReport2/mobile
- **Protocol:** HTTP (local) / HTTPS (production)

### Database
- **Electrician tables:** No suffix
- **Bricklayer tables:** `_bricklayer` suffix
- **Plumber tables:** `_plumber` suffix

---

## Rollback Plan

If issues occur:
1. Revert navigation in ArplAssessorPage to use `ArplToolkitViewerPage` directly
2. Keep trade-specific pages for future use
3. Remove trait parameter from PHP calls
4. All changes are backward compatible

---

## Next Steps

1. **Database Migration:** Execute SQL scripts to create trade tables
2. **Testing:** Verify each trade form works correctly
3. **Data Population:** Ensure existing assessments can be imported by trade
4. **Sync Integration:** Test offline sync with new tables
5. **Deployment:** Roll out to production with backup plan

---

## Notes for Development Team

- All code follows existing patterns in the project
- Trade detection is automatic via OFO number
- No manual trade selection needed - fully intelligent routing
- API is backward compatible (trade parameter optional)
- PHP helper functions can be extracted to config/utilities if needed
- Database migration scripts are idempotent (safe to run multiple times)

**Key Achievement:** Three completely separate assessment workflows managed transparently through intelligent routing - no manual intervention needed from assessors.
