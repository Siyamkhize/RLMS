# ARPL Toolkit Complete Data Flow Documentation

## Overview
This document shows how data flows from database tables through the backend API endpoint to the Flutter frontend, and how it gets saved back to the database.

---

## PART 1: DATA RETRIEVAL FLOW (Database → Frontend)

### Step 1: Frontend Request
**File:** `lib/ArplToolkitViewerPage.dart` (Lines 115-145)

```dart
Future<void> _loadToolkitData() async {
  final response = await http.post(
    Uri.parse(AppConfig.getArplToolkitDataUrl),  // Points to get_arpl_toolkit_data.php
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'learnerID': widget.learnerID,
      'classID': widget.classID,
      'ofoNumber': widget.ofoNumber,
    }),
  );
  
  final data = jsonDecode(response.body);
  setState(() {
    _toolkitData = ArplToolkitData.fromJson(data);
    _populateControllers();  // Fill form fields with loaded data
  });
}
```

---

### Step 2: Backend Endpoint - Data Retrieval
**File:** `mobile/get_arpl_toolkit_data.php`

#### **LEARNER & CLASS DATA**
```php
// Get learner details from learnerdetails table
$stmt = $conn->prepare("
    SELECT 
        LearnerID, Title, Name, Surname, IDNumber, DateOfBirth,
        PhoneNumber, Email, Gender, Race, Language,
        AddressLine1, AddressLine2, AddressLine3, PostalCode
    FROM learnerdetails
    WHERE LearnerID = ?
");
$stmt->bind_param('i', $learnerID);
$stmt->execute();
$response['learner'] = $stmt->get_result()->fetch_assoc();

// Get class and site info
$stmt = $conn->prepare("
    SELECT c.className, c.classID, s.siteName, s.province, s.district,
           p.Project_name, provider.provider_name, provider.accreditation_n
    FROM class c
    LEFT JOIN sites s ON c.siteID = s.siteID
    LEFT JOIN project p ON c.projectID = p.projectID
    LEFT JOIN provider ON p.providerID = provider.providerID
    WHERE c.classID = ?
");
$response['class_info'] = $stmt->get_result()->fetch_assoc();
```

---

#### **APPENDIX A: Application Form**
```php
// Tables: arpl_appendix_a
$stmt = $conn->prepare("
    SELECT 
        specialization, postal_address1, postal_address2, postal_code,
        fax_number, currently_employed, self_employed, current_employer,
        position_job_title, employer_address, reference, employer_tel,
        employer_fax, employer_cell, employer_email, employment_history,
        candidate_signature, signature_date
    FROM arpl_appendix_a
    WHERE learnerID = ? AND ofo_number = ?
    LIMIT 1
");
$stmt->bind_param('is', $learnerID, $ofoNumber);
$stmt->execute();
$response['appendixA'] = $stmt->get_result()->fetch_assoc();
```

**Data Flow to Frontend:**
- App displays employment history (auto-decoded from JSON)
- Specialization field pre-filled
- Employment status checkboxes set

---

#### **APPENDIX B: Self-Evaluation (Competency Ratings 1-5)**
```php
// Step 1: Get all activities for this trade
$stmt = $conn->prepare("
    SELECT activity_id, activity_number, activity_name
    FROM arplappxb_electrician_activities
    ORDER BY activity_number ASC
");
$appendixB_activities = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

// Step 2: Get learner's saved ratings
$stmt = $conn->prepare("
    SELECT 
        aar.activity_id,
        aar.competency_scale_id as rating_score,
        aar.comments,
        aar.rating_date,
        acs.proficiency_level,
        acs.description as scale_description
    FROM arplappxb_activity_ratings aar
    LEFT JOIN arpl_competency_scale acs ON aar.competency_scale_id = acs.score
    WHERE aar.learnerID = ?
");
$stmt->bind_param('i', $learnerID);
$stmt->execute();
$ratingsMap = [];
while ($row = $stmt->get_result()->fetch_assoc()) {
    $ratingsMap[$row['activity_id']] = $row;
}

// Step 3: Merge activities with ratings
foreach ($appendixB_activities as $activity) {
    $activityData = $activity;
    if (isset($ratingsMap[$activity['activity_id']])) {
        $activityData['rating'] = $ratingsMap[$activity['activity_id']];
        $activityData['has_rating'] = true;
    }
    $response['appendixB'][] = $activityData;
}
```

**Data Returned:**
```json
{
  "appendixB": [
    {
      "activity_id": 1,
      "activity_name": "Activity Name",
      "has_rating": true,
      "rating": {
        "rating_score": 4,
        "comments": "User comment",
        "proficiency_level": "Advanced",
        "scale_description": "Advanced"
      }
    }
  ]
}
```

**Data Flow to Frontend:**
- `_appendixBRatings` map stores selected rating (1-5)
- `_appendixBComments` TextEditingControllers filled with comments
- Radio buttons set to saved rating

---

#### **APPENDIX C: Trade Curriculum**
```php
// Tables: arpl_appendix_c
$stmt = $conn->prepare("
    SELECT 
        curriculum_overview, module_summary, learning_outcomes, additional_notes
    FROM arpl_appendix_c
    WHERE learnerID = ? AND ofo_number = ?
    LIMIT 1
");
$stmt->bind_param('is', $learnerID, $ofoNumber);
$response['appendixC'] = $stmt->get_result()->fetch_assoc();
```

**Data Flow:** Text fields auto-populated with curriculum details

---

#### **APPENDIX D: Practical Skills Assessment (Yes/No)**
```php
// Tables: arpl_appendix_d (single row with 22 activity columns)
$stmt = $conn->prepare("
    SELECT * FROM arpl_appendix_d
    WHERE learnerID = ?
    ORDER BY id DESC LIMIT 1
");
$stmt->bind_param('i', $learnerID);
$appendixD = $stmt->get_result()->fetch_assoc();

// Extract 22 activity responses
$response['appendixD'] = [];
for ($i = 1; $i <= 22; $i++) {
    $field = 'activity_' . $i;
    if (isset($appendixD[$field])) {
        $response['appendixD'][$field] = $appendixD[$field];  // 'yes' or 'no'
    }
}
```

**Data Flow:** Yes/No toggle buttons set based on stored values

---

#### **APPENDIX E: Workplace Experience (Competency Ratings 1-5)**
```php
// Tables: arplappxe_electrician_activities, arplappxe_electrician_activity_ratings
// Same pattern as Appendix B - activities + ratings joined

$stmt = $conn->prepare("
    SELECT activity_id, activity_number, activity_name
    FROM arplappxe_electrician_activities
    WHERE ofo_number = ?
");
$appendixE_activities = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

$stmt = $conn->prepare("
    SELECT 
        activity_id, competency_scale_id as rating_score,
        comments, rating_date
    FROM arplappxe_electrician_activity_ratings
    WHERE learnerID = ? AND ofo_number = ?
");
$stmt->bind_param('is', $learnerID, $ofoNumber);
$ratingsMapE = [];
while ($row = $stmt->get_result()->fetch_assoc()) {
    $ratingsMapE[$row['activity_id']] = $row;
}

// Merge and return
```

**Data Flow:** Same as Appendix B - rating numbers and comments displayed

---

#### **APPENDIX F: Practical Assessment Evaluation ⭐ MAIN FOCUS**
```php
// Tables: arpl_appendix_f, arpl_appendix_f_practical_tasks, 
//         arpl_appendix_f_workplace_observations

// 1. Main assessment record
$stmt = $conn->prepare("
    SELECT 
        learnerID, ofo_number, assessor_name, candidate_name,
        witness_name, assessor_signature, candidate_signature,
        witness_signature, assessment_date, authorized_date,
        created_at, updated_at
    FROM arpl_appendix_f
    WHERE learnerID = ? AND ofo_number = ?
    LIMIT 1
");
$stmt->bind_param('is', $learnerID, $ofoNumber);
$appendixF = $stmt->get_result()->fetch_assoc();

if ($appendixF) {
    // 2. Get practical tasks (13 rows)
    $stmt = $conn->prepare("
        SELECT task_number, task_name, score, percentage
        FROM arpl_appendix_f_practical_tasks
        WHERE learnerID = ? AND ofo_number = ?
        ORDER BY task_number ASC
    ");
    $stmt->bind_param('is', $learnerID, $ofoNumber);
    $stmt->execute();
    $appendixF['practical_tasks'] = [];
    while ($row = $stmt->get_result()->fetch_assoc()) {
        $appendixF['practical_tasks'][] = $row;
    }
    
    // 3. Get workplace observations (13 rows with electrical activities)
    $stmt = $conn->prepare("
        SELECT 
            observation_number, task_observed, technical_knowledge,
            interpretation, team_work
        FROM arpl_appendix_f_workplace_observations
        WHERE learnerID = ? AND ofo_number = ?
        ORDER BY observation_number ASC
    ");
    $stmt->bind_param('is', $learnerID, $ofoNumber);
    $stmt->execute();
    $appendixF['workplace_observations'] = [];
    while ($row = $stmt->get_result()->fetch_assoc()) {
        $appendixF['workplace_observations'][] = $row;
    }
}

$response['appendixF'] = $appendixF;
```

**Data Returned:**
```json
{
  "appendixF": {
    "assessor_name": "John Doe",
    "candidate_name": "Jane Smith",
    "assessment_date": "2026-07-09",
    "practical_tasks": [
      {
        "task_number": 1,
        "task_name": "Install electrical circuit",
        "score": 85,
        "percentage": 85.0
      },
      // ... 12 more tasks
    ],
    "workplace_observations": [
      {
        "observation_number": 1,
        "task_observed": "Wire ways and wiring",
        "technical_knowledge": "Good",
        "interpretation": "Excellent",
        "team_work": "Fair"
      },
      // ... 12 more observations
    ]
  }
}
```

**Data Flow to Frontend:**
- `_practicalTasks`, `_practicalScores`, `_practicalPercentages` controllers filled
- `_workplaceObservationTechKnowledge`, `_workplaceObservationInterpretation`, `_workplaceObservationTeamWork` controllers filled
- Date fields populated

---

#### **APPENDIX G: Appeals Form**
```php
// Tables: arpl_appendix_g
$stmt = $conn->prepare("
    SELECT 
        appeal_subject, grounds_for_appeal, moderator_name,
        appeal_status, assessor_findings, candidate_signature,
        assessor_signature, candidate_signed_at, assessor_signed_at,
        candidate_date, assessor_date
    FROM arpl_appendix_g
    WHERE learnerID = ? AND ofo_number = ?
    ORDER BY created_at DESC LIMIT 1
");
$response['appendixG'] = $stmt->get_result()->fetch_assoc();
```

**Data Flow:** Appeal details and signature fields pre-populated

---

#### **APPENDIX H: Access Recommendation**
```php
// Tables: appxh_acrelectrician (reference), 
//         arplelectrician_access_recommendation (learner data),
//         arpl_gap_analysis_unit_standards (gap analysis)

// 1. Get ACR items (4 assessment types)
$stmt = $conn->prepare("SELECT ACRID, AssessmentType FROM appxh_acrelectrician");
$response['appendixH']['items'] = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

// 2. Get learner's recommendations
$stmt = $conn->prepare("
    SELECT 
        RecommendationID, ACRID, Trade, OFOCode, Status,
        Remarks, CreatedAt, UpdatedAt
    FROM arplelectrician_access_recommendation
    WHERE LearnerID = ?
");
$stmt->bind_param('i', $learnerID);
$response['appendixH']['recommendations'] = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

// 3. Get gap analysis unit standards (if table exists)
$stmt = $conn->prepare("
    SELECT * FROM arpl_gap_analysis_unit_standards
    WHERE learner_id = ?
    ORDER BY created_at DESC
");
$response['appendixH']['gap_standards'] = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
```

**Data Flow:** Recommendations and gap standards displayed

---

#### **APPENDIX I: Statement of Results**
```php
// Tables: arpl_appendix_i
$stmt = $conn->prepare("
    SELECT 
        provider_type, knowledge_result, practical_result,
        workplace_result, overall_competency_rating,
        assessor_name, assessor_reg_number, certification_date,
        additional_notes
    FROM arpl_appendix_i
    WHERE learnerID = ? AND ofo_number = ?
    LIMIT 1
");
$response['appendixI'] = $stmt->get_result()->fetch_assoc();
```

**Data Flow:** Results and competency rating displayed

---

#### **APPENDIX J: Pre-Assessment Agreement**
```php
// Tables: arpl_appendix_j
$stmt = $conn->prepare("
    SELECT 
        understands_process, consents_to_assessment, understands_rights,
        confirms_accuracy, understands_criteria, agrees_to_terms,
        candidate_signature, witness_name, witness_signature,
        agreement_date
    FROM arpl_appendix_j
    WHERE learnerID = ? AND ofo_number = ?
    LIMIT 1
");
$response['appendixJ'] = $stmt->get_result()->fetch_assoc();
```

**Data Flow:** Agreement checkboxes set to saved state

---

### Step 3: Data Population in Frontend
**File:** `lib/ArplToolkitViewerPage.dart` (Lines 146-210)

```dart
void _populateControllers() {
  if (_toolkitData == null) return;
  
  // Appendix B: Populate ratings and comments
  for (var rating in _toolkitData!.appendixB) {
    if (rating.hasRating) {
      _appendixBRatings[rating.activityId] = rating.competencyScaleId;
      _appendixBComments[rating.activityId] = 
          TextEditingController(text: rating.comments);
    }
  }
  
  // Appendix F: Populate practical tasks (13 rows)
  if (_toolkitData!.appendixF != null) {
    final f = _toolkitData!.appendixF!;
    
    // Populate practical section
    for (int i = 0; i < 13; i++) {
      _practicalTasks[i].clear();
      _practicalScores[i].clear();
      _practicalPercentages[i].clear();
      
      if (i < f.practicalTasks.length) {
        final task = f.practicalTasks[i];
        _practicalTasks[i].text = task.taskName;
        _practicalScores[i].text = task.score.toString();
        _practicalPercentages[i].text = task.percentage.toString();
      }
    }
    
    // Populate workplace observation section
    for (int i = 0; i < 13; i++) {
      _workplaceObservationTechKnowledge[i].clear();
      _workplaceObservationInterpretation[i].clear();
      _workplaceObservationTeamWork[i].clear();
      
      if (i < f.workplaceObservations.length) {
        final obs = f.workplaceObservations[i];
        _workplaceObservationTechKnowledge[i].text = obs.technicalKnowledge;
        _workplaceObservationInterpretation[i].text = obs.interpretation;
        _workplaceObservationTeamWork[i].text = obs.teamWork;
      }
    }
  }
}
```

---

## PART 2: DATA SAVE FLOW (Frontend → Database)

### Step 1: Frontend Save Request
**File:** `lib/ArplToolkitViewerPage.dart` (Lines 211-310)

```dart
Future<void> _saveAllChanges() async {
  // Build data from form fields (TextEditingControllers)
  
  // Appendix F practical tasks (read from controllers)
  final practicalTasks = List.generate(13, (index) => {
    'taskNumber': index + 1,
    'taskName': _practicalTasks[index].text,
    'score': int.tryParse(_practicalScores[index].text) ?? 0,
    'percentage': double.tryParse(_practicalPercentages[index].text) ?? 0.0,
  });
  
  // Appendix F workplace observations (read from controllers)
  final workplaceObservations = List.generate(13, (index) => {
    'observationNumber': index + 1,
    'taskObserved': 'Electrical Activity ${index + 1}',
    'technicalKnowledge': _workplaceObservationTechKnowledge[index].text,
    'interpretation': _workplaceObservationInterpretation[index].text,
    'teamWork': _workplaceObservationTeamWork[index].text,
  });
  
  // Send to backend
  final response = await http.post(
    Uri.parse('${AppConfig.baseUrl}/mobile/save_arpl_appendix_f_assessment.php'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'learnerID': widget.learnerID,
      'ofoNumber': widget.ofoNumber,
      'practicalTasks': practicalTasks,
      'workplaceObservations': workplaceObservations,
      'assessmentDate': _assessorSignatureDate.text,
    }),
  );
}
```

---

### Step 2: Backend Save Endpoint
**File:** `mobile/save_arpl_appendix_f_assessment.php`

```php
// 1. Save main Appendix F record
$stmt = $conn->prepare("
    INSERT INTO arpl_appendix_f 
    (learnerID, ofo_number, assessor_name, candidate_name, 
     witness_name, assessment_date, authorized_date)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
    assessor_name = VALUES(assessor_name),
    assessment_date = VALUES(assessment_date),
    updated_at = CURRENT_TIMESTAMP
");
$stmt->bind_param('issssss', $learnerID, $ofoNumber, $assessorName, 
                  $candidateName, $witnessName, $assessmentDate, $authorizedDate);
$stmt->execute();

// 2. Delete old practical tasks
$stmt = $conn->prepare("
    DELETE FROM arpl_appendix_f_practical_tasks
    WHERE learnerID = ? AND ofo_number = ?
");
$stmt->bind_param('is', $learnerID, $ofoNumber);
$stmt->execute();

// 3. Insert new practical tasks (13 rows)
$stmt = $conn->prepare("
    INSERT INTO arpl_appendix_f_practical_tasks
    (learnerID, ofo_number, task_number, task_name, score, percentage)
    VALUES (?, ?, ?, ?, ?, ?)
");
foreach ($practicalTasks as $task) {
    $taskNum = intval($task['taskNumber']);
    $taskName = $task['taskName'];
    $score = intval($task['score']);
    $percentage = floatval($task['percentage']);
    
    $stmt->bind_param('isisid', $learnerID, $ofoNumber, 
                      $taskNum, $taskName, $score, $percentage);
    $stmt->execute();
}

// 4. Delete old workplace observations
$stmt = $conn->prepare("
    DELETE FROM arpl_appendix_f_workplace_observations
    WHERE learnerID = ? AND ofo_number = ?
");
$stmt->execute();

// 5. Insert new workplace observations (13 rows)
$stmt = $conn->prepare("
    INSERT INTO arpl_appendix_f_workplace_observations
    (learnerID, ofo_number, observation_number, task_observed, 
     technical_knowledge, interpretation, team_work)
    VALUES (?, ?, ?, ?, ?, ?, ?)
");
foreach ($workplaceObservations as $obs) {
    $obsNum = intval($obs['observationNumber']);
    $taskObs = $obs['taskObserved'];
    $techKnowledge = $obs['technicalKnowledge'];
    $interpretation = $obs['interpretation'];
    $teamWork = $obs['teamWork'];
    
    $stmt->bind_param('isissss', $learnerID, $ofoNumber, $obsNum,
                      $taskObs, $techKnowledge, $interpretation, $teamWork);
    $stmt->execute();
}

echo json_encode(['status' => 'success', 'message' => 'Data saved']);
```

---

### Step 3: Reload and Display
```dart
// After successful save, reload data
await _loadToolkitData();  // Calls backend endpoint
// Returns fresh data from database
// _populateControllers() fills form fields with saved values
// User sees "✓ Changes saved successfully" + data immediately displayed
```

---

## DATABASE TABLES REFERENCE

### Appendix A
- **Table:** `arpl_appendix_a`
- **Columns:** specialization, postal_address1, postal_address2, postal_code, fax_number, currently_employed, self_employed, current_employer, position_job_title, employer_address, reference, employer_tel, employer_fax, employer_cell, employer_email, employment_history (JSON), candidate_signature, signature_date

### Appendix B
- **Tables:** 
  - `arplappxb_electrician_activities` (reference of activities)
  - `arplappxb_activity_ratings` (learner ratings)
  - `arpl_competency_scale` (rating descriptions)

### Appendix C
- **Table:** `arpl_appendix_c`
- **Columns:** curriculum_overview, module_summary, learning_outcomes, additional_notes

### Appendix D
- **Table:** `arpl_appendix_d`
- **Columns:** activity_1 through activity_22 (each stores 'yes' or 'no')

### Appendix E
- **Tables:**
  - `arplappxe_electrician_activities` (reference of activities)
  - `arplappxe_electrician_activity_ratings` (learner ratings)

### Appendix F ⭐
- **Tables:**
  - `arpl_appendix_f` (main record: assessor_name, candidate_name, assessment_date, etc.)
  - `arpl_appendix_f_practical_tasks` (13 tasks: task_number, task_name, score, percentage)
  - `arpl_appendix_f_workplace_observations` (13 observations: observation_number, task_observed, technical_knowledge, interpretation, team_work)

### Appendix G
- **Table:** `arpl_appendix_g`
- **Columns:** appeal_subject, grounds_for_appeal, moderator_name, appeal_status, assessor_findings, etc.

### Appendix H
- **Tables:**
  - `appxh_acrelectrician` (reference of ACR components)
  - `arplelectrician_access_recommendation` (learner recommendations)
  - `arpl_gap_analysis_unit_standards` (gap analysis)

### Appendix I
- **Table:** `arpl_appendix_i`
- **Columns:** provider_type, knowledge_result, practical_result, workplace_result, overall_competency_rating, etc.

### Appendix J
- **Table:** `arpl_appendix_j`
- **Columns:** understands_process, consents_to_assessment, understands_rights, confirms_accuracy, understands_criteria, agrees_to_terms, candidate_signature, witness_name, witness_signature, agreement_date

---

## DATA FLOW DIAGRAM

```
┌─────────────────────────────────────────────────────────────┐
│                    ARPL TOOLKIT FLOW                        │
└─────────────────────────────────────────────────────────────┘

RETRIEVAL (User opens form):
┌────────────────┐
│ Flutter App    │
│ _loadToolkitData()
└────────┬────────┘
         │ HTTP POST (learnerID, classID, ofoNumber)
         ↓
┌────────────────────────────────────────┐
│ get_arpl_toolkit_data.php              │
│ ✓ Queries ALL 10 appendix tables       │
└────────┬────────────────────────────────┘
         │ JSON response (all appendices + data)
         ↓
┌────────────────┐
│ Flutter App    │
│ _populateControllers()
│ ✓ Fill TextEditingControllers
│ ✓ Display data in form fields
└────────────────┘

SAVING (User clicks Save):
┌────────────────┐
│ Flutter App    │
│ _saveAllChanges()
│ ✓ Read from controllers
└────────┬────────┘
         │ HTTP POST (practicalTasks, workplaceObservations)
         ↓
┌──────────────────────────────────────────┐
│ save_arpl_appendix_f_assessment.php      │
│ ✓ Save to arpl_appendix_f (main)         │
│ ✓ Delete old tasks → Insert new tasks    │
│ ✓ Delete old observations → Insert new   │
└────────┬──────────────────────────────────┘
         │ JSON response (success)
         ↓
┌────────────────┐
│ Flutter App    │
│ _loadToolkitData() [RELOAD]
└────────┬────────┘
         │ HTTP POST (reload fresh data)
         ↓
┌────────────────────────────────────────┐
│ get_arpl_toolkit_data.php              │
│ ✓ Query database (get saved data)
└────────┬────────────────────────────────┘
         │ JSON response (with saved data)
         ↓
┌────────────────┐
│ Flutter App    │
│ _populateControllers()
│ ✓ Controllers filled with saved data
│ ✓ Form displays saved data ✓
└────────────────┘
```

---

## KEY ENDPOINTS

| Endpoint | Method | Purpose | Request | Response |
|----------|--------|---------|---------|----------|
| `mobile/get_arpl_toolkit_data.php` | POST | Retrieve all appendix data | `{learnerID, classID, ofoNumber}` | All 10 appendices with data |
| `mobile/save_arpl_toolkit_edits.php` | POST | Save Appendix B, D, E | `{learnerID, appendixB, appendixD, appendixE}` | Success/Error |
| `mobile/save_arpl_appendix_f_assessment.php` | POST | Save Appendix F | `{learnerID, practicalTasks, workplaceObservations, dates}` | Success/Error |

---

## TESTING DATA PERSISTENCE

1. **Open Toolkit** → Data loads from database
2. **Enter data in form** (e.g., practical task names, scores)
3. **Click Save button** → "✓ Changes saved successfully"
4. **Form refreshes** → Your data appears in form fields ✓
5. **Close and reopen** → Data persists ✓

