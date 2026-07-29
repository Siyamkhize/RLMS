# ARPL Hierarchy Workflow - CONFIRMED ✅
**Date: July 23, 2026**

---

## ✅ Current Implementation is Correct

The workflow in `mobile/get_arpl_hierarchy.php` **already follows the exact logic you described**:

---

## 📊 Database Structure

```
class table
├─ classID
├─ className
├─ trade_id (FK)
└─ siteID

arpl_trades table
├─ trade_id (PK)
├─ trade_name ("Bricklaying", "Plumbing", "Electrician")
└─ ofo_number ("641201", "642601", "671101")

arpl_papers table
├─ id (PK)
├─ trade_ofo_code (FK to arpl_trades.ofo_number)
├─ paper_title ("Theory Paper 1", "Practical Paper 1", etc.)
├─ paper_number (1, 2, 3, etc.)
├─ paper_type ("theory", "practical")
└─ total_marks (100)

arpl_questions table
├─ id (PK)
├─ paper_id (FK to arpl_papers.id)
├─ question_number (1, 2, 3, etc.)
├─ specific_outcome
├─ assessment_criteria
├─ question_text (exercise)
└─ marks
```

---

## 🔄 Workflow Steps (Currently Implemented)

### Step 1: Get Trade Information
```php
// Get learner → class → trade_id
SELECT * FROM learnerdetails WHERE LearnerID = ?

// JOIN class with arpl_trades
SELECT 
    c.*,
    t.trade_name,        -- "Bricklaying"
    t.ofo_number         -- "641201"
FROM class c
LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
WHERE c.classID = ?
```

**Result:** `$qualName = "Bricklaying"`, `$classOfo = "641201"`

---

### Step 2: Get Papers for This Trade
```php
SELECT * FROM arpl_papers 
WHERE trade_ofo_code = '641201'  -- Bricklaying OFO
ORDER BY paper_number, paper_type
```

**Result:** All papers for Bricklaying trade

**Example:**
```
id=1, trade_ofo_code='641201', paper_title='Theory Paper 1', paper_type='theory', paper_number=1
id=2, trade_ofo_code='641201', paper_title='Theory Paper 2', paper_type='theory', paper_number=2
id=3, trade_ofo_code='641201', paper_title='Practical Paper 1', paper_type='practical', paper_number=1
```

---

### Step 3: Group Papers by Type
```php
// Loop through papers and organize by paper_type
foreach ($papersById as $paperId => $paper) {
    $paperType = strtolower($paper['paper_type']); // 'theory' or 'practical'
    $groupKey = str_contains($paperType, 'practical') 
        ? 'practical_papers' 
        : 'theory_papers';
    
    $data['pathways']['ARPL']['qualifications'][$qualName][$groupKey][$paperName] = [
        'paper_id' => $paperId,
        'paper_number' => $paper['paper_number'],
        'paper_type' => $paperType,
        'total_marks' => $paper['total_marks'],
        'questions' => []  // Will be filled in next step
    ];
}
```

**Result Structure:**
```json
{
  "pathways": {
    "ARPL": {
      "qualifications": {
        "Bricklaying": {
          "theory_papers": {
            "Theory Paper 1": {
              "paper_id": 1,
              "paper_number": 1,
              "paper_type": "theory",
              "total_marks": 100,
              "questions": []
            },
            "Theory Paper 2": {
              "paper_id": 2,
              "paper_number": 2,
              "paper_type": "theory",
              "total_marks": 100,
              "questions": []
            }
          },
          "practical_papers": {
            "Practical Paper 1": {
              "paper_id": 3,
              "paper_number": 1,
              "paper_type": "practical",
              "total_marks": 100,
              "questions": []
            }
          }
        }
      }
    }
  }
}
```

---

### Step 4: Get Questions for Each Paper
```php
SELECT * FROM arpl_questions 
ORDER BY paper_id, question_number
```

**Then link questions to papers via `paper_id`:**
```php
while ($row = $questionsResult->fetch_assoc()) {
    $questionPaperId = $row['paper_id'];  // e.g., 1 (Theory Paper 1)
    
    // Find the paper this question belongs to
    if (isset($papersById[$questionPaperId])) {
        $paper = $papersById[$questionPaperId];
        $paperType = strtolower($paper['paper_type']);
        $groupKey = str_contains($paperType, 'practical') 
            ? 'practical_papers' 
            : 'theory_papers';
        $paperName = $paper['paper_title'];
        
        // Add question to the correct paper
        $data['pathways']['ARPL']['qualifications'][$qualName][$groupKey][$paperName]['questions'][] = [
            'question_number' => $row['question_number'],
            'specific_outcome' => $row['specific_outcome'],
            'assessment_criteria' => $row['assessment_criteria'],
            'exercise' => $row['question_text'],
            'marks' => $row['marks']
        ];
    }
}
```

**Result:** Questions grouped under their respective papers

---

## 📱 UI Hierarchy (Frontend Display)

```
Bricklaying Portfolio
│
├─ Theory Papers
│  ├─ Theory Paper 1 (paper_id=1)
│  │  ├─ Question 1 (paper_id=1, question_number=1)
│  │  ├─ Question 2 (paper_id=1, question_number=2)
│  │  └─ Question 3 (paper_id=1, question_number=3)
│  │
│  └─ Theory Paper 2 (paper_id=2)
│     ├─ Question 1 (paper_id=2, question_number=1)
│     └─ Question 2 (paper_id=2, question_number=2)
│
└─ Practical Papers
   └─ Practical Paper 1 (paper_id=3)
      ├─ Question 1 (paper_id=3, question_number=1)
      ├─ Question 2 (paper_id=3, question_number=2)
      └─ Question 3 (paper_id=3, question_number=3)
```

---

## 🔍 Example Data Flow

### For Bricklaying Class (classID=797):

**1. Get Trade:**
```sql
SELECT c.*, t.trade_name, t.ofo_number
FROM class c
LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
WHERE c.classID = 797
```
**Result:** `trade_name = "Bricklaying"`, `ofo_number = "641201"`

**2. Get Papers:**
```sql
SELECT * FROM arpl_papers WHERE trade_ofo_code = '641201'
```
**Result:** 5 papers (3 theory, 2 practical)

**3. Get Questions:**
```sql
SELECT * FROM arpl_questions WHERE paper_id IN (1,2,3,4,5)
```
**Result:** 50 questions distributed across 5 papers

**4. Final Structure:**
```
Bricklaying
├─ Theory Papers
│  ├─ Theory Paper 1 (10 questions)
│  ├─ Theory Paper 2 (10 questions)
│  └─ Theory Paper 3 (10 questions)
└─ Practical Papers
   ├─ Practical Paper 1 (10 questions)
   └─ Practical Paper 2 (10 questions)
```

---

## ✅ Confirmation: Logic is Correct

The current implementation **exactly matches** your description:

1. ✅ After clocking → Get trade name from `arpl_trades` via JOIN
2. ✅ Use OFO code to query `arpl_papers` WHERE `trade_ofo_code = OFO`
3. ✅ Group papers by `paper_type` (theory/practical)
4. ✅ Under each section, show Paper 1, Paper 2, etc.
5. ✅ Use `paper_id` to link questions from `arpl_questions`
6. ✅ Questions belong to OFO + paper_type + paper_number

---

## 🎯 What Needs to Happen

**The logic is already correct!**

**You just need to:**
1. Upload `mobile/get_arpl_hierarchy.php` to server
2. Test on device
3. Verify it works as expected

**No code changes needed** - the workflow is already implemented exactly as you described! ✅

---

## 📊 Database Query Summary

```sql
-- Step 1: Get trade
SELECT c.*, t.trade_name, t.ofo_number
FROM class c
LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
WHERE c.classID = ?

-- Step 2: Get papers for this trade
SELECT * FROM arpl_papers 
WHERE trade_ofo_code = ?  -- OFO from step 1
ORDER BY paper_number, paper_type

-- Step 3: Get all questions
SELECT * FROM arpl_questions 
ORDER BY paper_id, question_number

-- Step 4: Link questions to papers via paper_id
-- (done in PHP code)
```

---

**Status:** ✅ **Workflow Confirmed Correct**
**Next Action:** Upload to server and test
**Expected Result:** Bricklaying class shows Bricklaying papers, not Electrician
