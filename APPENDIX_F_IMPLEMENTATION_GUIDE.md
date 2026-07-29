# Appendix F Redesign - Implementation Guide

**Date:** July 15, 2026  
**Status:** 🎯 READY FOR IMPLEMENTATION  
**Priority:** HIGH (B/D/E now working, F is next)

---

## 📋 OVERVIEW

Appendix F has been completely redesigned with **3 distinct sections**:

1. **Knowledge Assessment** - Dynamic questions (add/remove rows)
2. **Practical Tasks** - Dynamic tasks (add/remove rows)
3. **Workplace Observation** - Activities from database with dropdowns

---

## 🗄️ STEP 1: CREATE DATABASE TABLES

### Upload and Run SQL Script
```bash
UPLOAD: create_appendix_f_redesign_tables.sql
RUN SQL: Execute the script to create 3 new tables
```

**Tables Created:**
- `arpl_appendix_f_knowledge` - Stores dynamic knowledge questions
- `arpl_appendix_f_practical_tasks` - Stores dynamic practical tasks
- `arpl_appendix_f_workplace_observations` - Stores observation ratings

---

## 📡 STEP 2: UPLOAD PHP ENDPOINTS

### Files to Upload:
```
1. mobile/get_appendix_f_data.php - Loads all 3 sections
2. mobile/save_appendix_f_data.php - Saves all 3 sections
```

### Test Endpoints:
```bash
# Test Load
curl -X POST https://rlms.rlms.co.za/mobile/get_appendix_f_data.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID":11701,"ofoNumber":"641201"}'

# Test Save
curl -X POST https://rlms.rlms.co.za/mobile/save_appendix_f_data.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID":11701,"ofoNumber":"641201","knowledge":[],"practical":[],"workplace_observations":[]}'
```

---

## 📱 STEP 3: UPDATE FLUTTER CODE

### Files to Modify:
1. **`lib/ArplToolkitViewerPage.dart`**

### Changes Required:

#### A. Add New Classes (Top of State Class)
Copy from `AppendixFRedesigned.dart`:
- `class KnowledgeQuestion`
- `class PracticalTask`
- `class WorkplaceObservation`

#### B. Add State Variables
Replace the old Appendix F controllers with:
```dart
List<KnowledgeQuestion> _knowledgeQuestions = [];
List<PracticalTask> _practicalTasks = [];
List<WorkplaceObservation> _workplaceObservations = [];
bool _isLoadingAppendixF = false;
```

#### C. Remove Old Controllers (Delete These)
```dart
// DELETE - No longer needed:
final List<TextEditingController> _knowledgeQuestions = List.generate(8, (_) => TextEditingController());
final List<TextEditingController> _knowledgeScores = List.generate(8, (_) => TextEditingController());
final List<TextEditingController> _knowledgePercentages = List.generate(8, (_) => TextEditingController());
final List<TextEditingController> _practicalTasks = List.generate(13, (_) => TextEditingController());
final List<TextEditingController> _practicalScores = List.generate(13, (_) => TextEditingController());
final List<TextEditingController> _practicalPercentages = List.generate(13, (_) => TextEditingController());
final List<TextEditingController> _workplaceObservationTechKnowledge = List.generate(13, (_) => TextEditingController());
final List<TextEditingController> _workplaceObservationInterpretation = List.generate(13, (_) => TextEditingController());
final List<TextEditingController> _workplaceObservationTeamWork = List.generate(13, (_) => TextEditingController());
```

#### D. Add Load Method
Copy `_loadAppendixFData()` from `AppendixFRedesigned.dart`

#### E. Replace _buildAppendixF() Method
Replace entire `_buildAppendixF()` method with new version from `AppendixFRedesigned.dart`, including:
- `_buildKnowledgeSectionNew()`
- `_buildPracticalSectionNew()`
- `_buildWorkplaceObservationNew()`
- `_getRatingText()` helper

#### F. Update initState()
Add after `_loadToolkitData()`:
```dart
@override
void initState() {
  super.initState();
  _tabController = TabController(length: 11, vsync: this);
  _loadToolkitData();
  _loadAppendixFData(); // ADD THIS LINE
}
```

#### G. Update dispose()
Replace old Appendix F dispose code with:
```dart
@override
void dispose() {
  _tabController?.dispose();
  _tradeSpecializationController.dispose();
  _appendixBComments.forEach((key, controller) => controller.dispose());
  _appendixEComments.forEach((key, controller) => controller.dispose());

  // NEW: Dispose Appendix F
  _knowledgeQuestions.forEach((q) => q.dispose());
  _practicalTasks.forEach((t) => t.dispose());
  
  // REMOVE OLD:
  // _knowledgeQuestions.forEach((c) => c.dispose());
  // _knowledgeScores.forEach((c) => c.dispose());
  // etc...

  super.dispose();
}
```

#### H. Update _saveAllChanges()
Find the section where you save B/D/E, and add Appendix F save logic after it.

Replace the commented-out Appendix F save section with:
```dart
// ══════════════════════════════════════════════════════════
// SAVE APPENDIX F (REDESIGNED)
// ══════════════════════════════════════════════════════════
if (_knowledgeQuestions.isNotEmpty || _practicalTasks.isNotEmpty || _workplaceObservations.isNotEmpty) {
  final appendixFData = {
    'learnerID': widget.learnerID,
    'ofoNumber': widget.ofoNumber,
    'assessor_id': 6, // TODO: Get from logged-in facilitator
    'knowledge': _knowledgeQuestions.map((q) => q.toJson()).toList(),
    'practical': _practicalTasks.map((t) => t.toJson()).toList(),
    'workplace_observations': _workplaceObservations.map((o) => o.toJson()).toList(),
  };
  
  final responseF = await http.post(
    Uri.parse('${AppConfig.baseUrl}/mobile/save_appendix_f_data.php'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(appendixFData),
  );
  
  if (responseF.statusCode != 200) {
    throw Exception('Failed to save Appendix F: ${responseF.statusCode}');
  }
  
  final dataF = jsonDecode(responseF.body);
  if (dataF['status'] != 'success') {
    throw Exception(dataF['message'] ?? 'Appendix F save failed');
  }
}
```

#### I. Update _populateControllers()
Remove the old Appendix F population code (lines that populate the 13-row controllers)

---

## 🧪 STEP 4: TESTING

### Test Checklist:

#### 1. Load Appendix F
- [ ] Open View Complete Toolkit
- [ ] Navigate to Appx F tab
- [ ] Verify 3 sections display correctly
- [ ] Verify workplace activities load from database

#### 2. Test Knowledge Section (Dynamic)
- [ ] Tap "Add Question" button
- [ ] Add multiple questions
- [ ] Fill in question text, score, percentage
- [ ] Delete a question
- [ ] Verify numbering updates correctly

#### 3. Test Practical Section (Dynamic)
- [ ] Tap "Add Task" button
- [ ] Add multiple tasks
- [ ] Fill in task name, score, percentage
- [ ] Delete a task
- [ ] Verify numbering updates correctly

#### 4. Test Workplace Observation (Dropdowns)
- [ ] Verify all trade activities appear
- [ ] Change dropdown values (Fair/Good/Excellent)
- [ ] Verify all 3 columns have dropdowns
- [ ] Check values persist correctly

#### 5. Test Save
- [ ] Add data to all 3 sections
- [ ] Tap "Save All Changes"
- [ ] Verify success message
- [ ] Reload toolkit
- [ ] Verify all data persisted correctly

#### 6. Test View Mode
- [ ] Toggle to view mode (eye icon)
- [ ] Verify data displays correctly
- [ ] Verify no edit controls visible
- [ ] Verify dropdowns show as text

#### 7. Test Different Trades
- [ ] Test with Bricklayer (641201)
- [ ] Test with Plumber (671201) if available
- [ ] Test with Electrician (671101) if available
- [ ] Verify correct activities load for each trade

---

## 📊 UI COMPARISON

### OLD Appendix F:
❌ Fixed 13-row hardcoded structure  
❌ Text fields for everything  
❌ No add/remove functionality  
❌ Confusing structure  
❌ Didn't match requirements  

### NEW Appendix F:
✅ **Section 1: Knowledge** - Dynamic questions with add/remove  
✅ **Section 2: Practical** - Dynamic tasks with add/remove  
✅ **Section 3: Workplace** - Activities from database with dropdowns  
✅ Clean, intuitive UI  
✅ Matches ARPL requirements  
✅ Proper data persistence  

---

## 🎨 UI FEATURES

### Knowledge & Practical Sections:
- ➕ "Add Question/Task" button (only in edit mode)
- 🗑️ Delete button for each row (only in edit mode)
- 📊 DataTable format with horizontal scrolling
- 📝 Text input fields for all columns
- 🔢 Automatic numbering

### Workplace Observation Section:
- 📋 Task names loaded from database (read-only)
- 📊 DataTable format with horizontal scrolling
- 🔽 Dropdowns for 3 rating columns:
  - **Technical Knowledge**
  - **Interpretation of Instructions**
  - **Team Work Attitude**
- 🎯 Rating values: 1=Fair, 2=Good, 3=Excellent
- ✅ Auto-saves with other sections

---

## 🔧 TROUBLESHOOTING

### Issue: "Table doesn't exist" error
**Solution:** Run `create_appendix_f_redesign_tables.sql` to create tables

### Issue: "No activities available" in Workplace Observation
**Solution:** Check if `arplappxe_bricklaying_activities` table has data for your trade

### Issue: Dropdowns not showing
**Solution:** Verify you're in edit mode (tap edit icon in top right)

### Issue: Save fails with 400 error
**Solution:** Check browser console for detailed error. Verify all 3 PHP files are uploaded correctly

### Issue: Data doesn't persist after reload
**Solution:** Check database tables were created correctly. Run diagnostic:
```sql
SELECT COUNT(*) FROM arpl_appendix_f_knowledge WHERE learnerID = 11701;
SELECT COUNT(*) FROM arpl_appendix_f_practical_tasks WHERE learnerID = 11701;
SELECT COUNT(*) FROM arpl_appendix_f_workplace_observations WHERE learnerID = 11701;
```

---

## 📁 FILES SUMMARY

### Created Files:
1. ✅ `create_appendix_f_redesign_tables.sql` - Database schema
2. ✅ `mobile/get_appendix_f_data.php` - Load endpoint
3. ✅ `mobile/save_appendix_f_data.php` - Save endpoint
4. ✅ `lib/AppendixFRedesigned.dart` - New Flutter implementation (reference)
5. ✅ `APPENDIX_F_IMPLEMENTATION_GUIDE.md` - This guide

### Files to Modify:
1. 📝 `lib/ArplToolkitViewerPage.dart` - Replace Appendix F section

### Files to Upload to Server:
1. ⬆️ `create_appendix_f_redesign_tables.sql` → Run once
2. ⬆️ `mobile/get_appendix_f_data.php`
3. ⬆️ `mobile/save_appendix_f_data.php`

---

## ✅ SUCCESS CRITERIA

After implementation:
- ✓ Database tables created
- ✓ PHP endpoints working
- ✓ Flutter UI displays all 3 sections
- ✓ Can add/remove knowledge questions dynamically
- ✓ Can add/remove practical tasks dynamically
- ✓ Workplace activities load from database
- ✓ Dropdowns work for observation ratings
- ✓ Save works for all 3 sections
- ✓ Data persists after reload
- ✓ Works for all trades (Bricklayer, Plumber, Electrician)

---

## 🚀 DEPLOYMENT STEPS (Quick Reference)

```bash
# 1. Upload SQL and run
Upload: create_appendix_f_redesign_tables.sql
Execute in database

# 2. Upload PHP endpoints
Upload: mobile/get_appendix_f_data.php
Upload: mobile/save_appendix_f_data.php

# 3. Update Flutter code
Edit: lib/ArplToolkitViewerPage.dart
Follow steps A-I in STEP 3 above

# 4. Rebuild app
flutter clean
flutter pub get
flutter run

# 5. Test
Login → View Complete Toolkit → Appx F tab
Add questions, tasks, rate observations
Save and verify
```

---

**Created:** July 15, 2026  
**Last Updated:** July 15, 2026  
**Status:** Ready for implementation  
**Estimated Time:** 2-3 hours for full implementation and testing

