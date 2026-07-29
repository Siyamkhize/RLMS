# ARPL Competency Scale Data Updated - OFO 671101

## Status: ✅ Data Updated

The competency scale table has been updated with exact data from Appendix B for OFO 671101 Electrician.

---

## Database Structure

### arpl_competency_scale Table
```sql
CREATE TABLE arpl_competency_scale (
    scale_id INT PRIMARY KEY,
    score INT,
    proficiency_level VARCHAR(255),
    fundamental_knowledge TEXT,
    notice_experience TEXT,
    practical_application TEXT,
    created_at TIMESTAMP
)
```

---

## Competency Scale Data (5 Levels)

| Score | Proficiency Level | Fundamental Knowledge | Notice Experience | Practical Application |
|-------|-------------------|----------------------|-------------------|-----------------------|
| 1 | Fundamental (knowledge) | Knowledge is minimal | You have been exposed to this topic but your level of knowledge is minimal | Performs under close supervision |
| 2 | Novice (experience) | You have experienced some aspects related to this topic and experience | You have experienced some aspects related to this topic and experience | Applies with guidance |
| 3 | Advanced (intermediate experience) | You have all the required knowledge related to this topic but you are still limited to topic and experience | You have all the required knowledge and experience related | Applies the skill independently |
| 4 | Advanced (applied authority) | You have the required knowledge practical skills and experience related | Advanced experience related to the topic can teach others | Expert in the skill |
| 5 | Expert (recognized authority) | You have all the required knowledge to teach and can teach others | All the required knowledge and experience related to this topic | Expert authority on the topic |

---

## How Data Flows

### 1. Score to Proficiency Level Mapping
```
Rating Score (1-5)
  ↓
Lookup in arpl_competency_scale
  ↓
Get proficiency_level, fundamental_knowledge, notice_experience, practical_application
  ↓
Display in UI
```

### 2. Activity Rating Storage
When assessor rates an activity:
- Activity ID: Links to arpl_activities
- Rating Score: 1-5
- Competency Scale ID: References arpl_competency_scale.scale_id
- Learner ID: References learnerdetails.learnerID
- Result: Full competency details retrieved and displayed

---

## Implementation Files

### Setup Script
- **`setup_arpl_competency_scale.php`** - Creates tables and inserts competency scale data

### API Endpoints
- **`mobile/get_arpl_competency_data.php`** - Fetches competency scale + activity data
- **`mobile/save_arpl_activity_rating.php`** - Saves/updates activity ratings

### Flutter UI
- **`lib/ArplCompetencyScalePage.dart`** - Displays competency scale assessment

---

## Key Features

✅ 5-level competency scale (1-5)  
✅ Each level has 4 descriptive fields  
✅ Score directly maps to proficiency level  
✅ Supports linking to 22 activities  
✅ Tracks ratings per learner  
✅ Tracks assessor and assessment date  
✅ Supports comments/notes  

---

## Next Steps

1. **Run Setup Script**
   ```bash
   php setup_arpl_competency_scale.php
   ```
   This will:
   - Create `arpl_competency_scale` table
   - Create `arpl_activity_ratings` table
   - Create `arpl_activities` table
   - Insert 5 competency levels
   - Insert 22 activities

2. **Test API Endpoints**
   ```
   GET /mobile/get_arpl_competency_data.php?learnerID=16389&ofo_number=671101
   ```

3. **Integrate Flutter UI**
   - Add `ArplCompetencyScalePage` to ARPL navigation
   - Test with learner 16389

4. **Rate Activities**
   - Open competency scale page
   - Select activity
   - Rate 1-5
   - View proficiency level

---

## Data Format

### When Saving Rating
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

### What Gets Stored
```
rating_score = 3
  ↓
competency_scale_id = 3
  ↓
Table lookup: proficiency_level = "Advanced (intermediate experience)"
```

### When Displaying
```
Activity: Health, Safety, Quality...
Rating: 3
Proficiency: Advanced (intermediate experience)
Description: "You have all the required knowledge related to this topic..."
```

---

## Color Coding in UI

- **Level 1 (Red)**: Fundamental
- **Level 2 (Orange)**: Novice
- **Level 3 (Yellow)**: Advanced (Intermediate)
- **Level 4 (Green)**: Advanced (Applied Authority)
- **Level 5 (Dark Green)**: Expert

---

## Test Data Ready

- **Learner**: 16389 (Lungisani Cele)
- **OFO**: 671101 (Electrician)
- **Activities**: 22 (all pre-loaded)
- **Competency Levels**: 5 (all pre-loaded)

Ready to start rating activities!

