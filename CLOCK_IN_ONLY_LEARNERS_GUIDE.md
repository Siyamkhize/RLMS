# Clock-In Only Learners - System Guide
## RLMSS Mobile Application

---

## OVERVIEW

This guide covers the management of **Clock-In Only Learners** - learners who are registered in the system primarily for attendance tracking without full enrollment in training programs. These learners appear in the learner list and their attendance data can be uploaded to the central system.

---

## CLOCK-IN ONLY LEARNER CHARACTERISTICS

### Definition
Clock-In Only Learners are individuals who:
- ✅ Have basic registration information (Name, ID Number, Contact)
- ✅ Can clock in/out for attendance tracking
- ✅ Appear in learner lists and attendance reports
- ❌ Are NOT enrolled in specific training programs
- ❌ Do NOT have POE (Portfolio of Evidence) requirements
- ❌ Do NOT have assessment records

### Use Cases
1. **Workplace Visitors** - Contractors, consultants, temporary staff
2. **Orientation Attendees** - People attending safety briefings or inductions
3. **Event Participants** - Workshop or seminar attendees
4. **Compliance Tracking** - Individuals requiring attendance records for regulatory purposes

---

## SYSTEM BEHAVIOR

### Learner List Display
Clock-In Only Learners will appear in the main learner list with:

**Visible Information:**
- Full Name (Surname, First Name)
- ID Number
- Contact Information
- Clock-In Status (Active/Inactive)
- Last Clock-In Date/Time
- Total Attendance Days

**Missing Information:**
- Training Program Details
- Assessment Status
- POE Progress
- Qualification Information

### Attendance Tracking
These learners follow the same attendance rules as regular learners:

**Clock-In Requirements:**
- ✅ Valid geolocation within designated area
- ✅ Fingerprint verification (if enabled)
- ✅ Time-based restrictions (working hours)
- ✅ Holiday and weekend handling

**Attendance Calculation:**
- Regular Days: Normal clock-in/out days
- Manual Days: Manually added attendance
- Sick Days: Recorded sick leave
- Holidays: Public holidays (counted but not required)
- Total Days: Sum of all attendance types

---

## DATA UPLOAD PROCESS

### Automatic Sync
Clock-In Only Learner data syncs automatically when online:

**Upload Frequency:**
- Real-time: When internet connection is available
- Batch Upload: Every 15 minutes for offline records
- Manual Sync: User-initiated sync from dashboard

**Data Uploaded:**
```json
{
  "learner_id": "12345",
  "id_number": "9001015800083",
  "clock_in_time": "2026-04-30 08:00:00",
  "clock_out_time": "2026-04-30 17:00:00",
  "location_lat": "-25.7479",
  "location_lng": "28.2293",
  "attendance_type": "regular",
  "sync_status": "uploaded"
}
```

### Manual Upload
For offline scenarios or forced sync:

1. **Navigate to Dashboard**
2. **Tap Sync Button** (circular arrow icon)
3. **Select "Upload Attendance Data"**
4. **Confirm upload** when prompted
5. **Monitor progress** in sync status widget

### Upload Status Indicators
- 🟢 **Green**: Successfully uploaded
- 🟡 **Yellow**: Pending upload (queued)
- 🔴 **Red**: Upload failed (retry required)
- ⚪ **Gray**: Not yet synced (offline)

---

## LEARNER LIST MANAGEMENT

### Filtering Clock-In Only Learners
To view only Clock-In Only Learners:

1. **Open Learner List Page**
2. **Tap Filter Icon** (funnel symbol)
3. **Select "Clock-In Only"** from filter options
4. **Apply Filter** to show filtered results

### Search Functionality
Search for Clock-In Only Learners using:
- **ID Number**: Full or partial ID search
- **Name**: Surname or first name
- **Contact**: Phone number or email
- **Last Activity**: Recent clock-in dates

### Bulk Operations
Available bulk actions for Clock-In Only Learners:
- **Export Attendance**: Generate CSV/Excel reports
- **Bulk Upload**: Force sync multiple records
- **Status Update**: Activate/deactivate multiple learners
- **Data Cleanup**: Remove old or duplicate records

---

## ATTENDANCE REPORTING

### Individual Reports
For each Clock-In Only Learner:

**Daily Report:**
- Clock-in/out times
- Total hours worked
- Break times (if recorded)
- Location verification status

**Weekly Report:**
- Days present/absent
- Total weekly hours
- Overtime calculations
- Holiday adjustments

**Monthly Report:**
- Attendance percentage
- Total working days
- Sick leave taken
- Public holidays

### Bulk Reports
Generate reports for multiple Clock-In Only Learners:

1. **Navigate to Reports Section**
2. **Select "Attendance Reports"**
3. **Choose "Clock-In Only Learners"**
4. **Set Date Range** (daily/weekly/monthly)
5. **Select Learners** (individual or all)
6. **Generate Report** (PDF/Excel format)

---

## TROUBLESHOOTING

### Common Issues

**Issue 1: Learner Not Appearing in List**
- ✅ Check if learner is marked as "Clock-In Only" in database
- ✅ Verify learner status is "Active"
- ✅ Refresh learner list (pull down to refresh)
- ✅ Check network connection for sync

**Issue 2: Clock-In Data Not Uploading**
- ✅ Verify internet connection
- ✅ Check sync status in dashboard
- ✅ Try manual sync from settings
- ✅ Restart app if sync is stuck

**Issue 3: Duplicate Learner Records**
- ✅ Check for multiple ID numbers for same person
- ✅ Use admin search to find duplicates
- ✅ Merge records using admin tools
- ✅ Contact system administrator if needed

**Issue 4: Attendance Calculation Errors**
- ✅ Verify clock-in/out times are correct
- ✅ Check holiday calendar settings
- ✅ Review manual attendance entries
- ✅ Recalculate totals from admin panel

### Error Messages

**"Learner not found in system"**
- Learner may not be properly registered
- Check learner registration status
- Verify ID number is correct

**"Upload failed - network error"**
- Internet connection issue
- Try again when connection is stable
- Data will be queued for next sync

**"Geolocation verification failed"**
- Learner is outside designated area
- Check GPS accuracy and location services
- Verify site boundaries are correct

---

## BEST PRACTICES

### Registration
1. **Complete Basic Information**: Ensure name, ID, and contact details are accurate
2. **Unique Identification**: Use official ID numbers to prevent duplicates
3. **Clear Classification**: Mark learners as "Clock-In Only" during registration
4. **Regular Updates**: Keep contact information current

### Attendance Management
1. **Daily Monitoring**: Check attendance reports daily for accuracy
2. **Exception Handling**: Document and resolve attendance discrepancies promptly
3. **Regular Sync**: Ensure data uploads regularly to prevent data loss
4. **Backup Procedures**: Maintain offline backups of critical attendance data

### Data Quality
1. **Regular Audits**: Review Clock-In Only learner data monthly
2. **Duplicate Prevention**: Check for duplicate registrations before adding new learners
3. **Status Updates**: Deactivate learners who no longer require tracking
4. **Archive Old Data**: Move historical data to archive after retention period

---

## INTEGRATION WITH MAIN SYSTEM

### Database Structure
Clock-In Only Learners use the same database tables as regular learners but with specific flags:

```sql
-- Learner table with Clock-In Only flag
learner (
  LearnerID INT PRIMARY KEY,
  IDNumber VARCHAR(13),
  Surname VARCHAR(100),
  Name VARCHAR(100),
  ClockInOnly BOOLEAN DEFAULT FALSE,
  Status ENUM('Active', 'Inactive'),
  CreatedDate DATETIME
)

-- Attendance table (shared with regular learners)
attendance (
  AttendanceID INT PRIMARY KEY,
  LearnerID INT,
  ClockInTime DATETIME,
  ClockOutTime DATETIME,
  AttendanceType ENUM('regular', 'manual', 'sick'),
  SyncStatus ENUM('pending', 'uploaded', 'failed')
)
```

### API Endpoints
Clock-In Only Learners use standard API endpoints with filtering:

- `GET /api/learners?type=clockin_only` - Fetch Clock-In Only learners
- `POST /api/attendance/upload` - Upload attendance data
- `GET /api/reports/attendance?learner_type=clockin_only` - Generate reports

### Sync Process
1. **Local Storage**: Data stored locally in SQLite database
2. **Queue Management**: Failed uploads queued for retry
3. **Conflict Resolution**: Server timestamp takes precedence
4. **Data Validation**: Server validates all uploaded data

---

## SECURITY CONSIDERATIONS

### Data Protection
- All learner data encrypted in local storage
- Secure HTTPS transmission for uploads
- Access controls based on user roles
- Audit trails for all data modifications

### Privacy Compliance
- Minimal data collection (only attendance-related)
- Consent tracking for data processing
- Right to deletion (GDPR compliance)
- Data retention policies enforced

---

## SUPPORT AND MAINTENANCE

### Regular Tasks
- **Weekly**: Review upload success rates
- **Monthly**: Audit Clock-In Only learner list
- **Quarterly**: Archive old attendance data
- **Annually**: Review and update procedures

### Contact Information
- **Technical Support**: IT Help Desk
- **System Administrator**: Database Admin
- **Training Coordinator**: Learning Management Team
- **Compliance Officer**: Data Protection Officer

---

*Document Version: 1.0*  
*Last Updated: April 30, 2026*  
*Next Review: July 30, 2026*