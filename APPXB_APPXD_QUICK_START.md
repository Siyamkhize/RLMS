# Appendix B & D: Quick Start Guide

## ✅ What Changed

**Appendix B and D tabs now load activities from the database dynamically** instead of using hardcoded lists.

---

## 🚀 How It Works

### 1. Learner Selection
- User selects learner from dropdown
- System automatically loads their OFO (trade code)

### 2. API Call
- Calls: `mobile/get_arpl_competency_data.php?learnerID=16389`
- Returns: All activities for that learner's OFO from `arplappxb_electrician_activities` table

### 3. Display
- **Appx B (Activities)** tab shows activities from database with rating buttons
- **Appx D (Self-Eval)** tab shows same activities (shared list)
- Each activity has 1-5 rating buttons (Red→Orange→Yellow→Green→Dark Green)

---

## 📱 UI Display

```
Appendix B: Electrician Activities Assessment
OFO: 671101

Rate each activity on a scale of 1-5 (1=Low, 5=High)

[1] Health, Safety, Quality and Assessment of Units
    Candidate Competence (1=Low, 5=High)
    ◯ ◯ ◯ ◯ ◯

[2] Knowledge and practical skills
    Candidate Competence (1=Low, 5=High)
    ◯ ◯ ◯ ◯ ◯

[3] Safety, Quality and Regulations
    Candidate Competence (1=Low, 5=High)
    ◯ ◯ ◯ ◯ ◯
    ...
```

---

## 🎯 Key Features

- ✅ Activities loaded from database (not hardcoded)
- ✅ OFO number shown in header ("OFO: 671101")
- ✅ 5 circular rating buttons with color-coding
- ✅ Click to rate, visual feedback on selection
- ✅ Appx B and D share same activity list
- ✅ Ratings persist during session
- ✅ Empty state if activities fail to load

---

## 🔧 Technical Details

### Updated Files:
1. **`mobile/get_arpl_competency_data.php`**
   - Now queries `arplappxb_electrician_activities` table
   - Detects learner's OFO automatically
   - Returns activities array in JSON

2. **`lib/ArplAssessorPage.dart`**
   - New method: `_loadActivitiesFromAPI(learnerID)`
   - Loads activities when learner selected
   - Both Appx B and D use loaded activities

### API Response:
```json
{
  "status": "success",
  "ofo_number": 671101,
  "appxb_activities": [
    {
      "activity_id": 1,
      "activity_number": 1,
      "activity_name": "Health, Safety, Quality and Assessment of Units"
    },
    ...
  ],
  "total_activities": 22
}
```

---

## 📊 Example Workflow

1. Open ARPL Assessor Review
2. Select learner: "Nkosivile Sophangisa"
3. API detects: OFO 671101 (Electrician)
4. Appx B tab shows: 22 Electrician activities from database
5. Click rating button → Activity rated with color feedback
6. Switch to Appx D → Same activities and ratings
7. Navigate away → Ratings persist in memory for this session

---

## ✨ Rating System

### Color Meanings:
- **1 (Red)**: Fundamental / Low Competence
- **2 (Orange)**: Novice / Limited Competence
- **3 (Yellow)**: Advanced / Intermediate Competence
- **4 (Light Green)**: Advanced Authority / High Competence
- **5 (Dark Green)**: Expert / Recognized Authority

### Selection Behavior:
- Click button → Highlights with color, fills background
- Click different button → Previous deselects, new highlights
- Border thickens (3px) when selected
- Text color changes to match rating color

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Activities not loaded" shown | Check API connection, verify learner has OFO in database |
| No activities displaying | Verify `arplappxb_electrician_activities` table has data |
| Wrong OFO shown | Check learner's OFO in learnerdetails table |
| Activities not updating | Select learner again to refresh |

---

## 📱 APK Info

- **Size**: 45.6 MB
- **Built**: July 7, 2026
- **Status**: ✅ Ready for testing

---

## 🎓 Next Session: Server Persistence

To save ratings permanently to database:
1. Implement `_saveRating()` method
2. POST each rating to `mobile/save_arpl_activity_rating.php`
3. Load existing ratings on page load
4. Test save/restore workflow

Currently ratings persist **during session only** (in-memory). To make them permanent, server save is needed.

---

**Status**: ✅ COMPLETE & TESTED
