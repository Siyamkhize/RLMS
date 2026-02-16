# Moderator Pothole Checklist - Quick Reference Card

## 🎯 What This Does
Allows moderators to review and approve/disapprove pothole checklist marks assigned by assessors.

## 📋 Quick Facts
- **Marks:** View only (cannot edit)
- **Approval:** Can approve or disapprove
- **Comments:** Required for disapproval
- **Data:** Never deleted, only updated
- **Status:** Visible to all users

## 🚀 How to Use (Moderator)

### Step 1: Navigate
```
ModeratorPage → Drawer → "Pothole Checklist"
```

### Step 2: Select Class
```
Click "Select" on desired class
```

### Step 3: View Learners
```
Button colors indicate status:
- Grey: No marks yet
- Orange: Needs moderation
- Green: Approved
- Red: Disapproved
```

### Step 4: Moderate
```
1. Click "Moderate" button
2. Review marks (read-only)
3. Select: Approved OR Disapproved
4. Add comment (required for disapproval)
5. Click "Save Moderation"
```

## 📊 Database Changes

### New Columns in `pothole_checklist_marks`:
```sql
approval_status ENUM('Approved', 'Disapproved') NULL
comment VARCHAR(256) NULL
```

### Migration Command:
```bash
mysql -u user -p database < add_moderation_columns_to_pothole_marks.sql
```

## 🔧 Files to Deploy

### PHP (Upload to server):
- ✅ `php/save_pothole_moderation.php` (NEW)
- ✅ `php/get_pothole_checklist_marks.php` (REPLACE)

### Flutter (Rebuild app):
- ✅ `lib/ModeratorPage.dart` (UPDATED)

## 🧪 Quick Test

### Test Approval:
1. Login as moderator
2. Navigate to Pothole Checklist
3. Select class with marked learners
4. Click "Moderate" on a learner
5. Select "Approved"
6. Click "Save Moderation"
7. ✓ Should show success message
8. ✓ Button should turn green

### Test Disapproval:
1. Click "Moderate" on another learner
2. Select "Disapproved"
3. Try to save (should fail - no comment)
4. Add comment: "Needs revision"
5. Click "Save Moderation"
6. ✓ Should show success message
7. ✓ Button should turn red

## ⚠️ Important Rules

### ✅ DO:
- Review marks carefully before deciding
- Provide clear comments for disapproval
- Check all learners in a class
- Save after each decision

### ❌ DON'T:
- Try to edit marks (read-only)
- Disapprove without comment
- Delete records manually
- Skip validation steps

## 🔍 Button States Explained

| Button | Color | Meaning | Action |
|--------|-------|---------|--------|
| No Marks | Grey | Assessor hasn't marked | Wait for assessor |
| Moderate | Orange | Needs your review | Click to moderate |
| View (Approved) | Green | You approved it | Click to view only |
| View (Disapproved) | Red | You disapproved it | Click to view only |

## 📝 Validation Rules

1. **Status:** Must select Approved or Disapproved
2. **Comment:** Required when disapproving
3. **Length:** Comment max 256 characters
4. **Record:** Must have existing marks to moderate

## 🐛 Common Issues

### "No marks record found"
**Fix:** Assessor needs to mark first

### "Please select approval status"
**Fix:** Choose Approved or Disapproved

### "Please provide a comment for withdrawal"
**Fix:** Add comment when disapproving

### PHP file not found
**Fix:** Check file uploaded to correct path

## 📞 API Endpoints

### Get Marks:
```
GET /mobile/get_pothole_checklist_marks.php
?learner_id=12345&assessor_id=67890&assessment_date=2026-01-19
```

### Save Moderation:
```
POST /mobile/save_pothole_moderation.php
Body: {
  "learner_id": "12345",
  "assessment_date": "2026-01-19",
  "approval_status": "Approved",
  "comment": "Marks are appropriate"
}
```

## 🔄 Rollback (If Needed)

### Database:
```sql
ALTER TABLE pothole_checklist_marks 
DROP COLUMN approval_status, 
DROP COLUMN comment;
```

### PHP:
```bash
rm save_pothole_moderation.php
# Restore old get_pothole_checklist_marks.php
```

### App:
```bash
# Reinstall previous APK
```

## 📚 Full Documentation

For detailed information:
- **Implementation:** `MODERATOR_POTHOLE_CHECKLIST_IMPLEMENTATION.md`
- **Deployment:** `DEPLOY_MODERATOR_POTHOLE_CHECKLIST.md`
- **Summary:** `MODERATOR_POTHOLE_IMPLEMENTATION_SUMMARY.md`
- **Flow Diagram:** `MODERATOR_POTHOLE_FLOW_DIAGRAM.txt`

## ✅ Deployment Checklist

- [ ] Run SQL migration
- [ ] Upload PHP files
- [ ] Rebuild Flutter app
- [ ] Test approval workflow
- [ ] Test disapproval workflow
- [ ] Verify status persists
- [ ] Check button states
- [ ] Monitor for errors

## 🎓 Training Points

### For Moderators:
1. You review assessor's work
2. You cannot change marks
3. You approve or disapprove
4. Comments help assessors improve
5. Status is visible to everyone

### For Assessors:
1. Your marks are reviewed
2. Approved = Good job
3. Disapproved = Needs revision
4. Check moderator comments
5. Learn from feedback

## 💡 Tips

- Review all learners in a class together
- Be consistent in your decisions
- Provide constructive feedback
- Check marks against criteria
- Document your reasoning

## 🎯 Success Metrics

Deployment successful when:
- ✅ Can view marks
- ✅ Can approve/disapprove
- ✅ Status saves correctly
- ✅ Comments save correctly
- ✅ No data loss
- ✅ Buttons show correct state

---

**Version:** 1.0  
**Date:** January 19, 2026  
**Status:** Ready for Deployment
