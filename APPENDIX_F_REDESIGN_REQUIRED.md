# Appendix F - Redesign Required

**Date:** July 15, 2026  
**Status:** 🔴 NEEDS REDESIGN  
**Priority:** Medium (after B/D/E are working)

---

## 📋 CURRENT ISSUE

Appendix F save is getting 400 error because the structure doesn't match requirements.

---

## ✅ REQUIRED STRUCTURE

### Section 1: Knowledge Assessment
**Purpose:** Assess theoretical knowledge through written questions

**UI Table:**
| Question | Candidate Score | Percentage% | Actions |
|----------|----------------|-------------|---------|
| (text input) | (number input) | (number input) | [Delete] |

**Features:**
- ➕ "Add Question" button to add more rows
- Dynamic list (can add/remove rows)
- Save to: `arpl_appendix_f_knowledge` table (or similar)

**Columns needed:**
```
- id
- learnerID
- ofoNumber
- question_number
- question_text
- candidate_score
- percentage
- created_at
```

---

### Section 2: Practical Assessment
**Purpose:** Assess hands-on practical tasks

**UI Table:**
| Task Name | Candidate Score | Percentage% | Actions |
|-----------|----------------|-------------|---------|
| (text input) | (number input) | (number input) | [Delete] |

**Features:**
- ➕ "Add Task" button to add more rows
- Dynamic list (can add/remove rows)
- Save to: `arpl_appendix_f_practical_tasks` table (or similar)

**Columns needed:**
```
- id
- learnerID
- ofoNumber
- task_number
- task_name
- candidate_score
- percentage
- created_at
```

---

### Section 3: Workplace Observation
**Purpose:** Evaluate workplace performance on actual trade activities

**UI Table (READ-ONLY tasks from database):**
| Task Observed | Technical Knowledge | Interpretation of Instructions | Team Work Attitude |
|---------------|---------------------|-------------------------------|-------------------|
| (from DB: arplappxe_bricklaying_activities) | ▼ Dropdown | ▼ Dropdown | ▼ Dropdown |

**Dropdown Values:**
- `1` = Fair
- `2` = Good
- `3` = Excellent

**Data Source:**
- Tasks come from: `arplappxe_bricklaying_activities` table
- Table columns: `id`, `activityName`, `ofo_number`, etc.
- Load all activities for the learner's OFO code

**Save to:** `arpl_appendix_f_workplace_observations` table

**Columns needed:**
```
- id
- learnerID
- ofoNumber
- activity_id (FK to arplappxe_bricklaying_activities)
- task_observed (activity name)
- technical_knowledge (1, 2, or 3)
- interpretation_of_instructions (1, 2, or 3)
- team_work_attitude (1, 2, or 3)
- created_at
- updated_at
```

---

## 🗄️ DATABASE SCHEMA CHANGES NEEDED

### 1. Create Knowledge Table
```sql
CREATE TABLE IF NOT EXISTS arpl_appendix_f_knowledge (
    id INT AUTO_INCREMENT PRIMARY KEY,
    learnerID INT NOT NULL,
    ofoNumber VARCHAR(10) NOT NULL,
    question_number INT NOT NULL,
    question_text TEXT,
    candidate_score INT DEFAULT 0,
    percentage DECIMAL(5,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_question (learnerID, ofoNumber, question_number)
);
```

### 2. Create Practical Tasks Table (if doesn't exist)
```sql
CREATE TABLE IF NOT EXISTS arpl_appendix_f_practical_tasks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    learnerID INT NOT NULL,
    ofoNumber VARCHAR(10) NOT NULL,
    task_number INT NOT NULL,
    task_name VARCHAR(255),
    candidate_score INT DEFAULT 0,
    percentage DECIMAL(5,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_task (learnerID, ofoNumber, task_number)
);
```

### 3. Update Workplace Observations Table
```sql
CREATE TABLE IF NOT EXISTS arpl_appendix_f_workplace_observations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    learnerID INT NOT NULL,
    ofoNumber VARCHAR(10) NOT NULL,
    activity_id INT NOT NULL,
    task_observed VARCHAR(255),
    technical_knowledge TINYINT DEFAULT 1 COMMENT '1=Fair, 2=Good, 3=Excellent',
    interpretation_of_instructions TINYINT DEFAULT 1 COMMENT '1=Fair, 2=Good, 3=Excellent',
    team_work_attitude TINYINT DEFAULT 1 COMMENT '1=Fair, 2=Good, 3=Excellent',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_observation (learnerID, ofoNumber, activity_id)
);
```

---

## 📱 FLUTTER UI CHANGES NEEDED

### Current State
- Fixed number of controllers (13 hardcoded)
- Text fields for observations
- No dynamic add/remove

### Required Changes

1. **Make Knowledge section dynamic:**
   ```dart
   List<KnowledgeQuestion> knowledgeQuestions = [];
   
   class KnowledgeQuestion {
     TextEditingController questionController;
     TextEditingController scoreController;
     TextEditingController percentageController;
   }
   
   void addKnowledgeQuestion() {
     setState(() {
       knowledgeQuestions.add(KnowledgeQuestion(...));
     });
   }
   ```

2. **Make Practical section dynamic:**
   ```dart
   List<PracticalTask> practicalTasks = [];
   
   class PracticalTask {
     TextEditingController taskNameController;
     TextEditingController scoreController;
     TextEditingController percentageController;
   }
   
   void addPracticalTask() {
     setState(() {
       practicalTasks.add(PracticalTask(...));
     });
   }
   ```

3. **Load Workplace Observation tasks from database:**
   ```dart
   List<WorkplaceObservation> workplaceObservations = [];
   
   Future<void> loadWorkplaceActivities() async {
     final response = await http.post(
       Uri.parse('${AppConfig.baseUrl}/get_arpl_activities.php'),
       body: jsonEncode({'ofoNumber': widget.ofoNumber}),
     );
     
     // Parse and create observations with dropdowns
     // Each has 3 dropdowns: technical, interpretation, teamwork
   }
   ```

4. **Use dropdowns for observations:**
   ```dart
   DropdownButton<int>(
     value: observation.technicalKnowledge,
     items: [
       DropdownMenuItem(value: 1, child: Text('Fair')),
       DropdownMenuItem(value: 2, child: Text('Good')),
       DropdownMenuItem(value: 3, child: Text('Excellent')),
     ],
     onChanged: (value) {
       setState(() {
         observation.technicalKnowledge = value!;
       });
     },
   )
   ```

---

## 🔧 PHP ENDPOINT CHANGES NEEDED

### New Endpoint: `get_arpl_activities.php`
```php
// GET activities for workplace observation section
// Returns list of activities from arplappxe_bricklaying_activities
```

### Update: `save_arpl_appendix_f_assessment.php`
Need to handle 3 separate sections:
```php
if (isset($data['knowledge'])) {
    // Save knowledge questions
    // INSERT/UPDATE arpl_appendix_f_knowledge table
}

if (isset($data['practicalTasks'])) {
    // Save practical tasks
    // INSERT/UPDATE arpl_appendix_f_practical_tasks table
}

if (isset($data['workplaceObservations'])) {
    // Save workplace observations with dropdown values (1, 2, or 3)
    // INSERT/UPDATE arpl_appendix_f_workplace_observations table
}
```

---

## 🎯 IMPLEMENTATION PLAN

### Phase 1: Database Setup
- [ ] Create/update database tables
- [ ] Verify `arplappxe_bricklaying_activities` has correct data
- [ ] Create indexes for performance

### Phase 2: Backend API
- [ ] Create `get_arpl_activities.php` endpoint
- [ ] Update `save_arpl_appendix_f_assessment.php` to handle all 3 sections
- [ ] Add validation for dropdown values (1, 2, 3 only)

### Phase 3: Flutter UI
- [ ] Redesign Appendix F tab layout
- [ ] Implement dynamic Knowledge section with add/remove
- [ ] Implement dynamic Practical section with add/remove
- [ ] Load activities from database for Workplace Observation
- [ ] Implement dropdowns for 3 rating columns
- [ ] Update save logic to send correct data structure

### Phase 4: Testing
- [ ] Test adding/removing knowledge questions
- [ ] Test adding/removing practical tasks
- [ ] Test workplace observation dropdowns
- [ ] Test saving all 3 sections
- [ ] Verify data persists correctly

---

## 📊 EXPECTED DATA STRUCTURE

### Save Request Body
```json
{
  "learnerID": 11701,
  "ofoNumber": "641201",
  "knowledge": [
    {
      "question_number": 1,
      "question_text": "What is the ratio for mortar?",
      "candidate_score": 85,
      "percentage": 85.0
    },
    {
      "question_number": 2,
      "question_text": "Name 3 types of bricks",
      "candidate_score": 90,
      "percentage": 90.0
    }
  ],
  "practicalTasks": [
    {
      "task_number": 1,
      "task_name": "Build a corner",
      "candidate_score": 88,
      "percentage": 88.0
    },
    {
      "task_number": 2,
      "task_name": "Lay face bricks",
      "candidate_score": 92,
      "percentage": 92.0
    }
  ],
  "workplaceObservations": [
    {
      "activity_id": 1,
      "task_observed": "Reinforced Concrete Construction",
      "technical_knowledge": 3,
      "interpretation_of_instructions": 2,
      "team_work_attitude": 3
    },
    {
      "activity_id": 2,
      "task_observed": "Arch Construction",
      "technical_knowledge": 2,
      "interpretation_of_instructions": 3,
      "team_work_attitude": 2
    }
  ]
}
```

---

## ⚠️ CURRENT BLOCKER

The existing Appendix F code is trying to save hardcoded structures that don't match this design. To proceed:

1. **Option A:** Comment out Appendix F save until redesign is complete
2. **Option B:** Create temporary placeholder that accepts current structure
3. **Option C:** Prioritize this redesign before releasing

**Recommendation:** Option A - Focus on getting B/D/E working perfectly first, then tackle F as a separate feature.

---

## 🔗 RELATED FILES

- `lib/ArplToolkitViewerPage.dart` - Main UI (needs major changes)
- `mobile/save_arpl_appendix_f_assessment.php` - Save endpoint (needs rewrite)
- `mobile/get_arpl_toolkit_data.php` - Load endpoint (needs to load activities)
- `create_arpl_appendix_f_tables.sql` - Database schema (needs updates)

---

**NEXT STEPS:**
1. Upload current `save_arpl_toolkit_edits.php` fix for B/D/E
2. Test and confirm B/D/E are working
3. Create separate task for Appendix F redesign
4. Implement changes in phases as outlined above

---

**Last Updated:** July 15, 2026  
**Created By:** Kiro AI Assistant
