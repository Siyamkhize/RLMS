# ARPL Theory Papers Setup - Complete

## Overview

The ARPL (Advanced Recognition of Prior Learning) Electrician qualification now has **5 theory papers** set up in the database. Each question is mapped to its corresponding paper.

## Database Structure

### Tables Used

1. **arpl_trades** - Stores available trades/qualifications
2. **arpl_papers** - Stores theory and practical papers with metadata
3. **arpl_questions** - Stores individual questions linked to papers

### Electrician Qualification (OFO 671101)

#### 5 Theory Papers:

| Paper # | Title | Total Marks | Passing Score | Duration | Status |
|---------|-------|-------------|---------------|----------|--------|
| 1 | Basic Electrical Safety | 100 | 60 | 120 min | ✅ Set up (21 Q's) |
| 2 | Electrical Theory and Calculations | 100 | 60 | 120 min | ✅ Set up (0 Q's) |
| 3 | Electrical Installation and Wiring | 100 | 60 | 120 min | ✅ Set up (0 Q's) |
| 4 | Testing, Commissioning and Maintenance | 100 | 60 | 120 min | ✅ Set up (0 Q's) |
| 5 | Legislation, Regulations and Practice | 100 | 60 | 120 min | ✅ Set up (0 Q's) |

## Paper Descriptions

### Paper 1: Basic Electrical Safety
Covers fundamental electrical safety principles, hazards identification, risk mitigation, and personal protective equipment requirements.

**Questions:** 21 questions already exist from previous data
- Currently contains: 21 questions with 29 total marks

### Paper 2: Electrical Theory and Calculations
Theory of electricity, Ohm's Law, circuit analysis, three-phase power calculations, and electrical circuit design.

**Questions:** Ready for questions to be added
- Covers: Ohm's Law, power calculations, AC/DC current, circuit analysis, voltage drop

### Paper 3: Electrical Installation and Wiring
Wiring systems, installation methods, cable sizing per SANS 1416, earthing and bonding requirements, and distribution design.

**Questions:** Ready for questions to be added
- Covers: Cable sizing, installation methods, earthing/bonding, circuit design, outlet requirements

### Paper 4: Testing, Commissioning and Maintenance
Equipment testing procedures, commissioning plans, preventive maintenance schedules, and test result interpretation.

**Questions:** Ready for questions to be added
- Covers: Megohmmeter tests, fault loop impedance tests, commissioning plans, maintenance schedules

### Paper 5: Legislation, Regulations and Practice
SANS 1416 compliance, electrical regulations, ECSA registration, professional responsibilities, and technical documentation.

**Questions:** Ready for questions to be added
- Covers: SANS 1416 requirements, electrician registration, professional responsibilities, compliance analysis

## Data Structure in JSON Format

```json
{
  "pathways": {
    "ARPL": {
      "qualifications": {
        "Electrician": {
          "theory_papers": {
            "Basic Electrical Safety": {
              "paper_number": 1,
              "total_marks": 100,
              "passing_score": 60,
              "duration_minutes": 120,
              "questions": {
                "count": 21,
                "total_marks": 29
              }
            },
            "Electrical Theory and Calculations": {
              "paper_number": 2,
              "total_marks": 100,
              "passing_score": 60,
              "duration_minutes": 120,
              "questions": {
                "count": 0
              }
            },
            "Electrical Installation and Wiring": {
              "paper_number": 3,
              "total_marks": 100,
              "passing_score": 60,
              "duration_minutes": 120,
              "questions": {
                "count": 0
              }
            },
            "Testing, Commissioning and Maintenance": {
              "paper_number": 4,
              "total_marks": 100,
              "passing_score": 60,
              "duration_minutes": 120,
              "questions": {
                "count": 0
              }
            },
            "Legislation, Regulations and Practice": {
              "paper_number": 5,
              "total_marks": 100,
              "passing_score": 60,
              "duration_minutes": 120,
              "questions": {
                "count": 0
              }
            }
          },
          "total_papers": 5
        }
      }
    }
  }
}
```

## API Endpoints

### 1. Setup/Verify Papers
**Endpoint:** `/mobile/setup_arpl_electrician_papers.php`
- Creates or updates the 5 theory papers for Electrician
- Verifies trade exists and sets up papers

### 2. Verify Papers Structure
**Endpoint:** `/mobile/verify_arpl_theory_papers.php`
- Returns the complete hierarchy structure with papers and questions
- Shows question counts for each paper
- Returns JSON in proper hierarchy format

### 3. Check All ARPL Papers
**Endpoint:** `/mobile/check_arpl_papers.php`
- Lists all ARPL papers (theory and practical)
- Shows paper structure and question summaries
- Useful for debugging and verification

## How Questions Map to Papers

Each question in the `arpl_questions` table has:
- `paper_id` - Links to the `arpl_papers` table
- `question_number` - Sequential number within that paper (1-5)
- `marks` - Points awarded for that question
- `question_type` - Type: 'Theory', 'Practical', 'MCQ', etc.
- `difficulty_level` - Easy, Medium, Hard

**Example mapping:**
```
Paper 1 (Basic Electrical Safety) - ID: 11
  ├─ Question 1: "Identify electrical hazards" (5 marks)
  ├─ Question 2: "Explain LOTO procedures" (10 marks)
  ├─ Question 3: "Calculate safe distance" (8 marks)
  ├─ Question 4: "Describe PPE requirements" (7 marks)
  └─ Question 5: "Analyze workplace scenario" (10 marks)
```

## Adding Questions to Papers

To add questions for papers 2-5, use a script similar to the pattern in Paper 1:

```sql
INSERT INTO `arpl_questions` 
  (paper_id, trade_id, question_number, question_text, specific_outcome, assessment_criteria, marks, question_type, difficulty_level)
VALUES 
  (12, 1, 1, 'State Ohms Law...', 'Ohm\\'s Law application', 'Correctly applies formula I=V/R', 10, 'Theory', 'Easy');
```

## Current Status

✅ **Completed:**
- 5 theory papers created for Electrician (OFO 671101)
- Paper metadata configured (marks, passing scores, durations)
- Paper 1 has 21 existing questions
- Database structure verified

📋 **Next Steps:**
- Add questions for Papers 2-5 (approximately 5 questions per paper)
- Set passing scores and question weightings
- Link assessment criteria to each question
- Enable learner assessment through the app

## Testing

To verify the setup:

1. **Check papers exist:**
   ```
   SELECT * FROM `arpl_papers` WHERE trade_ofo_code = '671101' AND paper_type = 'theory'
   ```

2. **Check papers with question count:**
   ```
   SELECT ap.paper_number, ap.paper_title, COUNT(aq.id) as question_count
   FROM arpl_papers ap
   LEFT JOIN arpl_questions aq ON ap.id = aq.paper_id
   WHERE ap.trade_ofo_code = '671101' AND ap.paper_type = 'theory'
   GROUP BY ap.id
   ```

3. **Use verify endpoint:**
   - Visit: `/mobile/verify_arpl_theory_papers.php`
   - Returns complete hierarchy with all papers and question counts

## Files Created

1. **setup_arpl_electrician_papers.php** - Setup/update papers
2. **verify_arpl_theory_papers.php** - Verify and return hierarchy
3. **check_arpl_papers.php** - Check all papers in database
4. **create_arpl_theory_papers.sql** - SQL migration script

## Notes

- Trade ID for Electrician: 1
- Trade OFO Code: 671101
- Paper type: 'theory' (distinguishes from practical papers)
- All 5 papers have identical structure and are ready for learner assessment
- Questions are optional but recommended for complete implementation
