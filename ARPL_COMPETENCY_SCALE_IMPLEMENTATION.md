# ARPL Competency Scale - Implementation Guide

## Overview

This implementation creates a table-based ARPL assessment system for OFO 671101 (Electrician) with:
- **Competency Scale** (Appendix B): 5-level proficiency scale
- **22 Activities**: Electrician assessment activities
- **Activity Ratings**: Track learner competency levels per activity

---

## Database Structure

### Table 1: `arpl_competency_scale`
Stores the competency proficiency levels (1-5)

```sql
CREATE TABLE arpl_competency_scale (
    scale_id INT PRIMARY KEY,
    proficiency_level VARCHAR(100),
    description TEXT,
    knowledge_criteria TEXT,
    competency_evidence TEXT,
    created_at TIMESTAMP
)
```

**Data Example:**
| Level | Proficiency | Description | Evidence |
|-------|-------------|-------------|----------|
| 1 | Fundamental | Can identify basic concepts | Performs under close supervision |
| 2 | Novice | Exposed to topic, minimal knowledge | Applies with guidance |
| 3 | Advanced | Has required knowledge | Applies independently |
| 4 | Expert | Can teach others | Expert in skill |
| 5 | Expert (Authority) | Full knowledge & authority | Recognized authority |

### Table 2: `arpl_activities`
Master list of 22 assessment activities

```sql
CREATE TABLE arpl_activities (
    activity_id INT AUTO_INCREMENT PRIMARY KEY,
    activity_number INT,
    activity_name VARCHAR(255),
    ofo_number INT,
    appendix_section VARCHAR(50),
    created_at TIMESTAMP
)
```

**Activities (1-22):**
1. Health, Safety, Quality and Assessment
2. Equipment, Supplies, Personnel
3. Produce and Materials
4. Mechanics of electricity
5. Electrics and Wires
6. Electrical Systems
7. AC Lights
8. AC Apparatus
9. Alternators and Components
10. Electrical Batteries
... (up to 22)

### Table 3: `arpl_activity_ratings`
Stores ratings for each learner per activity

```sql
CREATE TABLE arpl_activity_ratings (
    activity_rating_id INT AUTO_INCREMENT PRIMARY KEY,
    learnerID INT NOT NULL,
    ofo_number INT,
    activity_id INT,
    activity_name VARCHAR(255),
    rating_score INT (1-5),
    competency_scale_id INT (references scale_id),
    assessor_id INT,
    rating_date TIMESTAMP,
    comments TEXT,
    FOREIGN KEY (learnerID) REFERENCES learnerdetails(learnerID),
    FOREIGN KEY (competency_scale_id) REFERENCES arpl_competency_scale(scale_id)
)
```

---

## Data Flow

### 1. Display Competency Scale
```
User opens ARPL Assessment
  ↓
Fetch competency_scale table
  ↓
Display as reference table (levels 1-5)
  ↓
Show proficiency levels with colors
```

### 2. Display Activities with Ratings
```
User selects learner & OFO
  ↓
Fetch arpl_activities (all 22 activities)
  ↓
Fetch arpl_activity_ratings (for this learner)
  ↓
Join activity data with ratings
  ↓
Display table with activities and current ratings
```

### 3. Save Activity Rating
```
User selects activity and rate (1-5)
  ↓
POST to save_arpl_activity_rating.php
  ↓
Server stores/updates rating
  ↓
Stores competency_scale_id = rating_score
  ↓
Return updated rating details
```

---

## Setup Instructions

### Step 1: Run Database Setup
```bash
php setup_arpl_competency_scale.php
```

This will:
- Create `arpl_competency_scale` table with 5 levels
- Create `arpl_activities` table with 22 activities
- Create `arpl_activity_ratings` table
- Populate competency scale data
- Populate activity list

### Step 2: API Endpoints Ready

**Get Competency Data:**
```
GET /mobile/get_arpl_competency_data.php?learnerID=16389&ofo_number=671101
```

Response:
```json
{
  "status": "success",
  "competency_scale": [...],
  "activities": [...],
  "activity_ratings": [...],
  "total_activities": 22,
  "rated_activities": 5
}
```

**Save Activity Rating:**
```
POST /mobile/save_arpl_activity_rating.php
```

Request body:
```json
{
  "learnerID": 16389,
  "ofo_number": 671101,
  "activity_id": 1,
  "activity_name": "Health, Safety, Quality...",
  "rating_score": 3,
  "assessor_id": 123,
  "comments": "Shows good understanding"
}
```

### Step 3: Add to Flutter Navigation

In your ARPL page, add button to open competency scale:

```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArplCompetencyScalePage(
          learnerID: 16389,
          learnerName: 'Lungisani Cele',
          ofoNumber: 671101,
          tradeName: 'Electrician',
        ),
      ),
    );
  },
  child: const Text('View Competency Scale'),
)
```

---

## UI Display

### Page 1: Competency Scale Reference
Shows table with levels 1-5 and their descriptions

| Level | Proficiency | Description |
|-------|-------------|-------------|
| 🔴 1 | Fundamental | Can identify basic concepts |
| 🟠 2 | Novice | Exposed to topic, minimal knowledge |
| 🟡 3 | Advanced | Has required knowledge |
| 🟢 4 | Expert | Can teach others |
| 🟢 5 | Expert (Authority) | Full knowledge & authority |

### Page 2: Activity Ratings Table
Shows all 22 activities with current ratings

| No | Activity | Rating | Proficiency Level | Date |
|----|----------|--------|-------------------|------|
| 1 | Health, Safety, Quality... | 3 | Advanced | 07/07/2026 |
| 2 | Equipment, Supplies... | - | - | - |
| 3 | Produce and Materials | 4 | Expert | 07/07/2026 |

---

## Color Coding

Rating scores use color indicators:
- **Level 1 (Red)**: Fundamental - Basic understanding
- **Level 2 (Orange)**: Novice - Some knowledge
- **Level 3 (Yellow)**: Advanced - Full knowledge
- **Level 4 (Green)**: Expert - Can teach
- **Level 5 (Dark Green)**: Expert Authority - Recognized authority

---

## Key Relationships

### Rating Score → Competency Scale
When saving a rating:
```
rating_score = 3
  ↓
competency_scale_id = 3
  ↓
Lookup scale_id = 3 in arpl_competency_scale
  ↓
Get "Advanced" proficiency level
```

### Activity → Rating → Competency Level
```
Activity 1: "Health, Safety, Quality..."
  ↓
User rates: 3
  ↓
System stores: rating_score = 3, competency_scale_id = 3
  ↓
Display: Activity 1 - Rating 3 - "Advanced"
```

---

## Features

✅ Display competency scale reference  
✅ Show all 22 activities  
✅ Display current ratings per activity  
✅ Show proficiency level name for each rating  
✅ Track assessment date and assessor  
✅ Support comments/notes  
✅ Color-coded proficiency levels  
✅ Progress tracking (rated activities / total)  
✅ Update/edit existing ratings  

---

## Integration with ARPL Pages

This system integrates with existing ARPL module:
1. User navigates to learner in ARPL
2. Option to view "Competency Scale Assessment"
3. Opens `ArplCompetencyScalePage`
4. Shows all activities and ratings
5. Can add/update ratings directly

---

## Files Created

1. **Database Setup**
   - `setup_arpl_competency_scale.php` - Creates tables & data

2. **API Endpoints**
   - `mobile/get_arpl_competency_data.php` - Fetch competency & activity data
   - `mobile/save_arpl_activity_rating.php` - Save/update ratings

3. **Flutter UI**
   - `lib/ArplCompetencyScalePage.dart` - Display and manage competency assessments

---

## Next Steps

1. ✅ Run `setup_arpl_competency_scale.php` to create tables
2. ✅ Test API endpoints with Postman/browser
3. ✅ Integrate page into ARPL navigation
4. ✅ Test with learner 16389
5. ✅ Rebuild APK and deploy

---

## Testing

### Test Data
- **Learner**: 16389 (Lungisani Cele)
- **OFO**: 671101 (Electrician)
- **Activities**: 22 (all pre-loaded)
- **Competency Levels**: 5 (1-5)

### Test Scenario
1. Open competency scale page for learner 16389
2. See all 22 activities listed
3. See competency scale reference (1-5 levels)
4. Rate Activity 1 as level 3
5. System shows "Advanced" proficiency
6. Rating date auto-filled
7. Navigate away and back → rating persists

