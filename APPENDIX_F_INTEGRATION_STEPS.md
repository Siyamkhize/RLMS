# Appendix F Integration - Step-by-Step Instructions

**IMPORTANT:** Before making ANY Flutter changes, ensure backend is ready:

## 🔴 STEP 0: BACKEND SETUP (DO THIS FIRST!)

### A. Create Database Tables
```bash
# Upload and run this SQL file:
create_appendix_f_redesign_tables.sql

# This creates 3 tables:
# - arpl_appendix_f_knowledge
# - arpl_appendix_f_practical_tasks
# - arpl_appendix_f_workplace_observations
```

### B. Upload PHP Endpoints
```bash
# Upload these 2 files to your server:
mobile/get_appendix_f_data.php
mobile/save_appendix_f_data.php

# Test they work:
https://rlms.rlms.co.za/mobile/get_appendix_f_data.php
https://rlms.rlms.co.za/mobile/save_appendix_f_data.php
```

### C. Verify Setup (Optional but Recommended)
```bash
# Upload and visit:
mobile/test_appendix_f_setup.php

# URL:
https://rlms.rlms.co.za/mobile/test_appendix_f_setup.php

# Should return: "ready": true
```

---

## ✅ STEP 1: ADD NEW CLASSES TO ArplToolkitViewerPage.dart

**Location:** After the imports, before the `class ArplToolkitViewerPage` declaration

**Add these 3 classes:**

```dart
// ═══════════════════════════════════════════════════════════════════════
// APPENDIX F DATA CLASSES
// ═══════════════════════════════════════════════════════════════════════

class KnowledgeQuestion {
  int questionNumber;
  TextEditingController questionController;
  TextEditingController scoreController;
  TextEditingController percentageController;
  
  KnowledgeQuestion({
    required this.questionNumber,
    String? questionText,
    int? score,
    double? percentage,
  }) : 
    questionController = TextEditingController(text: questionText ?? ''),
    scoreController = TextEditingController(text: score?.toString() ?? ''),
    percentageController = TextEditingController(text: percentage?.toString() ?? '');
  
  void dispose() {
    questionController.dispose();
    scoreController.dispose();
    percentageController.dispose();
  }
  
  Map<String, dynamic> toJson() {
    return {
      'question_number': questionNumber,
      'question_text': questionController.text,
      'candidate_score': int.tryParse(scoreController.text) ?? 0,
      'percentage': double.tryParse(percentageController.text) ?? 0.0,
    };
  }
}

class PracticalTask {
  int taskNumber;
  TextEditingController taskNameController;
  TextEditingController scoreController;
  TextEditingController percentageController;
  
  PracticalTask({
    required this.taskNumber,
    String? taskName,
    int? score,
    double? percentage,
  }) :
    taskNameController = TextEditingController(text: taskName ?? ''),
    scoreController = TextEditingController(text: score?.toString() ?? ''),
    percentageController = TextEditingController(text: percentage?.toString() ?? '');
  
  void dispose() {
    taskNameController.dispose();
    scoreController.dispose();
    percentageController.dispose();
  }
  
  Map<String, dynamic> toJson() {
    return {
      'task_number': taskNumber,
      'task_name': taskNameController.text,
      'candidate_score': int.tryParse(scoreController.text) ?? 0,
      'percentage': double.tryParse(percentageController.text) ?? 0.0,
    };
  }
}

class WorkplaceObservation {
  int activityId;
  String taskObserved;
  int technicalKnowledge;
  int interpretationOfInstructions;
  int teamWorkAttitude;
  
  WorkplaceObservation({
    required this.activityId,
    required this.taskObserved,
    this.technicalKnowledge = 1,
    this.interpretationOfInstructions = 1,
    this.teamWorkAttitude = 1,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'activity_id': activityId,
      'task_observed': taskObserved,
      'technical_knowledge': technicalKnowledge,
      'interpretation_of_instructions': interpretationOfInstructions,
      'team_work_attitude': teamWorkAttitude,
    };
  }
}
```

---

## ✅ STEP 2: ADD STATE VARIABLES

**Location:** In `_ArplToolkitViewerPageState` class, find where the old Appendix F controllers are declared

**FIND these lines (around line 55-70):**
```dart
// Appendix F controllers - Knowledge section (8 questions)
final List<TextEditingController> _knowledgeQuestions =
    List.generate(8, (_) => TextEditingController());
final List<TextEditingController> _knowledgeScores =
    List.generate(8, (_) => TextEditingController());
// ... more controllers
```

**REPLACE with:**
```dart
// Appendix F - NEW dynamic lists
List<KnowledgeQuestion> _knowledgeQuestions = [];
List<PracticalTask> _practicalTasks = [];
List<WorkplaceObservation> _workplaceObservations = [];
bool _isLoadingAppendixF = false;
```

**DELETE all these old controller declarations:**
- `_knowledgeQuestions` (List<TextEditingController>)
- `_knowledgeScores`
- `_knowledgePercentages`
- `_practicalTasks` (List<TextEditingController>)
- `_practicalScores`
- `_practicalPercentages`
- `_workplaceObservationTechKnowledge`
- `_workplaceObservationInterpretation`
- `_workplaceObservationTeamWork`
- `_assessorSignatureDate`
- `_candidateSignatureDate`
- `_witnessSignatureDate`

---

## ✅ STEP 3: ADD LOAD METHOD

**Location:** After `_loadToolkitData()` method

**ADD this complete method:**

```dart
Future<void> _loadAppendixFData() async {
  setState(() {
    _isLoadingAppendixF = true;
  });
  
  try {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/mobile/get_appendix_f_data.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'learnerID': widget.learnerID,
        'ofoNumber': widget.ofoNumber,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data['status'] == 'success') {
        setState(() {
          // Load knowledge questions
          _knowledgeQuestions.clear();
          if (data['data']['knowledge'] != null) {
            for (var item in data['data']['knowledge']) {
              _knowledgeQuestions.add(KnowledgeQuestion(
                questionNumber: item['question_number'],
                questionText: item['question_text'],
                score: item['candidate_score'],
                percentage: item['percentage'].toDouble(),
              ));
            }
          }
          
          // Load practical tasks
          _practicalTasks.clear();
          if (data['data']['practical'] != null) {
            for (var item in data['data']['practical']) {
              _practicalTasks.add(PracticalTask(
                taskNumber: item['task_number'],
                taskName: item['task_name'],
                score: item['candidate_score'],
                percentage: item['percentage'].toDouble(),
              ));
            }
          }
          
          // Load workplace observations
          _workplaceObservations.clear();
          if (data['data']['workplace_observations'] != null) {
            for (var item in data['data']['workplace_observations']) {
              _workplaceObservations.add(WorkplaceObservation(
                activityId: item['activity_id'],
                taskObserved: item['task_observed'],
                technicalKnowledge: item['technical_knowledge'],
                interpretationOfInstructions: item['interpretation_of_instructions'],
                teamWorkAttitude: item['team_work_attitude'],
              ));
            }
          }
          
          _isLoadingAppendixF = false;
        });
      }
    }
  } catch (e) {
    print('Error loading Appendix F data: $e');
    setState(() {
      _isLoadingAppendixF = false;
    });
  }
}
```

---

## ✅ STEP 4: UPDATE initState()

**FIND (around line 95):**
```dart
@override
void initState() {
  super.initState();
  _tabController = TabController(length: 11, vsync: this);
  _loadToolkitData();
}
```

**CHANGE TO:**
```dart
@override
void initState() {
  super.initState();
  _tabController = TabController(length: 11, vsync: this);
  _loadToolkitData();
  // Load Appendix F data separately
  Future.delayed(Duration(milliseconds: 500), () {
    _loadAppendixFData();
  });
}
```

---

## ✅ STEP 5: UPDATE dispose()

**FIND the dispose method, remove old Appendix F dispose code:**

**FIND:**
```dart
// Dispose Appendix F controllers
_knowledgeQuestions.forEach((c) => c.dispose());
_knowledgeScores.forEach((c) => c.dispose());
// ... etc
```

**REPLACE with:**
```dart
// Dispose NEW Appendix F
_knowledgeQuestions.forEach((q) => q.dispose());
_practicalTasks.forEach((t) => t.dispose());
```

---

## ✅ STEP 6: REPLACE _buildAppendixF() METHOD

This is a BIG file to output. I'll create it as a separate file you can copy from.

Creating `APPENDIX_F_NEW_BUILD_METHOD.dart`...

---

Due to size limits, I'll create the new build method in a separate file. Please wait...
