# ✅ Class Filtering Deployment Checklist

Use this checklist to deploy and verify the moderator class filtering feature.

---

## 📋 PRE-DEPLOYMENT

- [ ] **Verify local file exists**
  - File: `get_learners_with_poe_assigned.php`
  - Location: Workspace root directory
  - Size: ~30KB (contains all class filtering code)

- [ ] **Verify you have server access**
  - FTP/SFTP credentials ready
  - OR cPanel access available
  - OR SSH access available

- [ ] **Backup existing file** (optional but recommended)
  - Download current `get_learners_with_poe_assigned.php` from server
  - Save as `get_learners_with_poe_assigned.php.backup`

---

## 🚀 DEPLOYMENT

- [ ] **Upload the file**
  - Upload `get_learners_with_poe_assigned.php` to server
  - Server path: Root directory (same location as other PHP files)
  - Overwrite existing file: YES
  - File permissions: 644 (readable by web server)

- [ ] **Verify file uploaded**
  - Check file exists on server
  - Check file size matches local file (~30KB)
  - Check file timestamp is recent

---

## ✅ VERIFICATION

### Step 1: Check Server Version
- [ ] **Open in browser:**
  ```
  https://rlms.rlms.co.za/check_server_version.php
  ```

- [ ] **Verify output shows:**
  - ✅ NEW VERSION DETECTED - File has class filtering code
  - ✅ getModeratorClasses() function is present
  - ✅ getAvailableLearnersByStrata() has moderatorId parameter
  - ✅ Class filtering logic is present
  - ✅ Server is UP TO DATE

### Step 2: Test Database Queries
- [ ] **Open in browser:**
  ```
  https://rlms.rlms.co.za/test_moderator_77_data.php
  ```

- [ ] **Verify output shows:**
  - Moderator's Allocated Classes: Class A (ID: 74)
  - Total Classes Allocated: 1
  - Learners with POE in Class A: 3 learners
  - Total Learners with POE: 3

### Step 3: Test API Endpoint
- [ ] **Open in browser:**
  ```
  https://rlms.rlms.co.za/get_learners_with_poe_assigned.php?moderator_id=77
  ```

- [ ] **Verify JSON response:**
  - `"status": "success"`
  - `"total_learners_with_poe": 3` (or similar)
  - `"selected_count": 1` (or similar, ~25% of total)
  - All learners have `"classID": "74"`
  - All learners have `"className": "Class A"`
  - No learners from other classes

### Step 4: Test Direct API Call
- [ ] **Open in browser:**
  ```
  https://rlms.rlms.co.za/test_moderator_class_filtering_direct.php
  ```

- [ ] **Verify output:**
  - Shows moderator's classes
  - Shows filtered learners
  - All learners from Class A only

---

## 📱 MOBILE APP TESTING

### Test with Moderator 77
- [ ] **Login to mobile app**
  - Username: (moderator 77's credentials)
  - Password: (moderator 77's password)

- [ ] **Navigate to ModeratorPage**
  - Open the moderation section
  - Trigger sampling (if needed)

- [ ] **Verify learners displayed**
  - Only learners from "Class A" are shown
  - Class name shows "Class A"
  - Site shows "Randgate hall"
  - No learners from other classes

- [ ] **Check learner details**
  - Each learner has correct class information
  - POE documents are accessible
  - Marks can be viewed/edited

### Test with Another Moderator (if available)
- [ ] **Login as different moderator**
  - Use credentials for another moderator

- [ ] **Verify class filtering**
  - Only sees learners from their allocated classes
  - Different classes than Moderator 77
  - No overlap with other moderators' classes

---

## 🔍 DATABASE VERIFICATION

### Check Facilitator Table
- [ ] **Run SQL query:**
  ```sql
  SELECT f.facilitator_id, f.classID, c.className, c.siteID
  FROM facilitator f
  LEFT JOIN class c ON f.classID = c.classID
  WHERE f.facilitator_id = '77';
  ```

- [ ] **Verify results:**
  - Shows 1 row (or more if multiple classes)
  - classID: 74
  - className: Class A
  - siteID: Randgate hall

### Check Moderator Assignments
- [ ] **Run SQL query:**
  ```sql
  SELECT ma.moderator_id, ma.learner_id, ma.class_id, 
         l.Name, l.Surname, c.className
  FROM moderator_assignments ma
  INNER JOIN learnerdetails l ON ma.learner_id = l.LearnerID
  LEFT JOIN class c ON ma.class_id = c.classID
  WHERE ma.moderator_id = '77';
  ```

- [ ] **Verify results:**
  - All assignments have class_id = 74
  - All learners are from Class A
  - No learners from other classes

---

## 🎯 ACCEPTANCE CRITERIA

### Functional Requirements
- [ ] Moderators only see learners from their allocated classes
- [ ] Sampling is performed within allocated classes only
- [ ] Each learner is assigned to only one moderator
- [ ] Assignments are persistent (same learners on subsequent requests)
- [ ] Stratified sampling works correctly within filtered learners

### Performance Requirements
- [ ] API responds within 5 seconds
- [ ] No timeout errors
- [ ] Database queries are optimized
- [ ] Mobile app loads learners quickly

### Data Integrity
- [ ] No learners from unallocated classes
- [ ] All assigned learners have valid class information
- [ ] Moderator assignments table has correct data
- [ ] No duplicate assignments

---

## 🐛 TROUBLESHOOTING

### Issue: Server shows OLD VERSION
**Solution:**
- Clear browser cache
- Check file was uploaded correctly
- Verify file permissions (should be 644)
- Check server has PHP 7.0+ installed

### Issue: No learners returned
**Check:**
- Does moderator have classes in facilitator table?
- Do those classes have learners with POE?
- Are learners already assigned to other moderators?

### Issue: Wrong learners shown
**Check:**
- Are classID values correct in facilitator table?
- Is the moderator_id parameter correct?
- Check database for data inconsistencies

### Issue: API returns error
**Check:**
- PHP error logs on server
- Database connection is working
- All required tables exist
- SQL queries are valid

---

## 📊 SUCCESS METRICS

After deployment, you should have:

✅ **Server Status:**
- File uploaded successfully
- Version check shows NEW VERSION
- No PHP errors in logs

✅ **API Functionality:**
- Returns correct learners for each moderator
- Filters by allocated classes only
- Stratified sampling works correctly
- Response time < 5 seconds

✅ **Mobile App:**
- Moderators see only their learners
- Class filtering is transparent to users
- No errors or crashes
- Performance is acceptable

✅ **Database:**
- Assignments table has correct data
- No orphaned records
- Class information is accurate
- No duplicate assignments

---

## 📝 POST-DEPLOYMENT

- [ ] **Monitor for 24 hours**
  - Check for any errors
  - Verify moderators can access their learners
  - Monitor API response times

- [ ] **Collect feedback**
  - Ask moderators if they see correct learners
  - Verify class filtering is working as expected
  - Check for any edge cases

- [ ] **Document any issues**
  - Record any problems encountered
  - Document solutions applied
  - Update documentation if needed

---

## ✅ DEPLOYMENT COMPLETE

Once all items are checked:

🎉 **Class filtering is LIVE!**

Moderators will now only see learners from their allocated classes, ensuring fair and accurate moderation sampling.

---

## 📞 Need Help?

If you encounter issues:
1. Review `DEPLOY_CLASS_FILTERING_NOW.md` for detailed instructions
2. Check `UPLOAD_REQUIRED_SUMMARY.md` for quick reference
3. Run `VERIFY_SERVER_UPLOAD.bat` for automated checks
4. Review PHP error logs on server
5. Test with `test_moderator_77_data.php` for database verification

The implementation is complete and tested. Follow this checklist to deploy successfully! 🚀
