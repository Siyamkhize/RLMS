# FACILITATOR USER MANUAL AND TRAINING GUIDE
## RLMSS Mobile Application

---

## TABLE OF CONTENTS

1. [Getting Started](#getting-started)
2. [Dashboard Overview](#dashboard-overview)
3. [Learner Management](#learner-management)
4. [Attendance Tracking](#attendance-tracking)
5. [Assessment & POE](#assessment--poe)
6. [Material Management](#material-management)
7. [Reporting](#reporting)
8. [Troubleshooting](#troubleshooting)
9. [Training Modules](#training-modules)
10. [Best Practices](#best-practices)

---

## GETTING STARTED

### System Requirements
- **Device**: Android tablet/smartphone (Android 8.0+)
- **Storage**: Minimum 2GB free space
- **Network**: WiFi or mobile data connection
- **Hardware**: Camera, GPS, fingerprint scanner (optional)

### First Time Setup

#### 1. Installation
```bash
# APK Installation (via ADB)
adb install -r app-release.apk

# Or manual installation
# 1. Enable "Unknown Sources" in Android settings
# 2. Copy APK to device
# 3. Tap APK file to install
```

#### 2. Initial Login
1. **Launch App** from device home screen
2. **Enter Credentials**:
   - Username: [Provided by Administrator]
   - Password: [Temporary password - must change on first login]
3. **Select Role**: Choose "Facilitator" from dropdown
4. **Accept Terms**: Read and accept usage terms
5. **Complete Profile**: Add profile photo and contact details

#### 3. Offline Setup
1. **Download Base Data**: Sync learner lists, courses, and materials
2. **Configure Location**: Set up geofencing for your training site
3. **Test Features**: Verify camera, scanner, and fingerprint functionality
4. **Backup Setup**: Configure automatic data backup preferences

---

## DASHBOARD OVERVIEW

### Main Dashboard Layout

```
┌─────────────────────────────────────┐
│  RLMSS Facilitator Dashboard       │
├─────────────────────────────────────┤
│  👤 Welcome, [Facilitator Name]     │
│  📍 Site: [Training Location]       │
│  📅 Today: [Current Date]           │
├─────────────────────────────────────┤
│  📊 Quick Stats                     │
│  • Active Learners: 25             │
│  • Present Today: 22                │
│  • Pending Assessments: 8          │
│  • Materials Issued: 15            │
├─────────────────────────────────────┤
│  🔧 Quick Actions                   │
│  [Clock In] [Take Attendance]      │
│  [Add Learner] [Issue Materials]   │
│  [Assessments] [Generate Report]   │
├─────────────────────────────────────┤
│  📱 Navigation Menu                 │
│  • Learners    • Attendance        │
│  • Assessments • Materials         │
│  • Reports     • Settings          │
└─────────────────────────────────────┘
```

### Status Indicators
- 🟢 **Green**: System online, all functions available
- 🟡 **Yellow**: Limited connectivity, some features offline
- 🔴 **Red**: Offline mode, local operations only
- 🔄 **Spinning**: Syncing data with server

### Notification Center
- 📬 **New Messages**: System announcements and updates
- ⚠️ **Alerts**: Urgent issues requiring attention
- 📋 **Tasks**: Pending assessments and administrative tasks
- 🔔 **Reminders**: Scheduled activities and deadlines

---

## LEARNER MANAGEMENT

### Viewing Learner Lists

#### All Learners View
1. **Navigate**: Tap "Learners" from main menu
2. **Filter Options**:
   - All Learners
   - Active Only
   - Clock-In Only
   - By Training Program
   - By Assessment Status

#### Learner Details
Tap any learner to view:
- **Personal Information**: Name, ID, contact details
- **Training Progress**: Enrolled courses, completion status
- **Attendance Summary**: Days present, absent, sick leave
- **Assessment Records**: Completed and pending assessments
- **Material Allocation**: Issued PPE and learning materials

### Adding New Learners

#### Quick Registration
1. **Tap "Add Learner"** from dashboard
2. **Scan ID Document** (or enter manually)
3. **Complete Basic Info**:
   - Full Name
   - ID Number
   - Contact Details
   - Emergency Contact
4. **Take Profile Photo**
5. **Assign to Program** (or mark as Clock-In Only)
6. **Save and Sync**

#### Bulk Import
1. **Navigate**: Settings → Data Management → Import Learners
2. **Select File**: Choose CSV/Excel file
3. **Map Fields**: Match columns to system fields
4. **Validate Data**: Review for errors or duplicates
5. **Import**: Process and sync to server

### Learner Profile Management

#### Updating Information
- **Edit Profile**: Tap pencil icon on learner details
- **Photo Update**: Tap profile photo to retake
- **Contact Changes**: Update phone/email as needed
- **Status Changes**: Active/Inactive/Graduated

#### Enrollment Management
- **Add to Program**: Enroll in additional training courses
- **Transfer**: Move between programs or sites
- **Withdraw**: Remove from program (with reason)
- **Graduate**: Mark as successfully completed

---

## ATTENDANCE TRACKING

### Daily Attendance Process

#### Morning Setup
1. **Arrive Early**: Be at site 30 minutes before start time
2. **Check Equipment**: Verify tablet, scanner, network connection
3. **Review Schedule**: Check expected learners for the day
4. **Prepare Materials**: Set up attendance sheets and equipment

#### Clock-In Process
```
Learner Arrival → ID Verification → Fingerprint Scan → 
Location Check → Attendance Recorded → Welcome Message
```

**Step-by-Step:**
1. **Learner Approaches**: Greet and request identification
2. **Verify Identity**: Check ID document against system record
3. **Fingerprint Scan**: Place finger on scanner (if available)
4. **Location Verification**: System checks GPS coordinates
5. **Record Attendance**: System logs clock-in time
6. **Confirmation**: Show success message to learner

#### Manual Attendance Entry
For system failures or special circumstances:

1. **Navigate**: Attendance → Manual Entry
2. **Select Learner**: Choose from dropdown list
3. **Set Time**: Enter actual arrival time
4. **Add Reason**: Explain why manual entry was needed
5. **Supervisor Approval**: Get authorization if required
6. **Save Entry**: Record and flag for review

### Attendance Monitoring

#### Real-Time Dashboard
Monitor throughout the day:
- **Present Count**: Number currently on site
- **Late Arrivals**: Learners arriving after start time
- **Early Departures**: Unexpected clock-outs
- **Missing Learners**: Expected but not present

#### Attendance Exceptions
Handle special cases:
- **Sick Leave**: Record with medical certificate
- **Authorized Absence**: Pre-approved leave
- **Emergency Departure**: Early leaving with reason
- **Make-up Sessions**: Additional time to compensate

### Clock-Out Process
End of day procedures:

1. **Announce Departure**: Give 15-minute warning
2. **Verify Completion**: Check all activities finished
3. **Clock-Out Learners**: Process departures systematically
4. **Final Count**: Ensure all learners have left
5. **Upload Data**: Sync attendance to server
6. **Generate Report**: Create daily attendance summary

---

## ASSESSMENT & POE

### Assessment Types

#### Formative Assessment
**Purpose**: Ongoing evaluation during training
**Frequency**: Weekly or per module
**Method**: 
- Practical demonstrations
- Oral questioning
- Observation checklists
- Short quizzes

#### Summative Assessment
**Purpose**: Final evaluation of competence
**Frequency**: End of course/unit standard
**Method**:
- Comprehensive practical test
- Written examination
- Portfolio review
- Workplace simulation

### Conducting Assessments

#### Pre-Assessment Setup
1. **Schedule Assessment**: Book time slot in system
2. **Prepare Materials**: Gather tools, equipment, checklists
3. **Review Criteria**: Study assessment standards
4. **Set Up Space**: Arrange assessment area
5. **Brief Learner**: Explain process and expectations

#### During Assessment
```
Introduction → Explanation → Demonstration → 
Learner Performance → Observation → Scoring → 
Feedback → Documentation
```

**Assessment Flow:**
1. **Welcome Learner**: Put at ease, explain process
2. **Review Requirements**: Go through assessment criteria
3. **Demonstrate if Needed**: Show expected performance
4. **Observe Performance**: Watch learner complete tasks
5. **Take Notes**: Record observations and evidence
6. **Score Against Criteria**: Mark competent/not yet competent
7. **Provide Feedback**: Explain results and next steps
8. **Document Results**: Complete assessment forms

#### Post-Assessment
1. **Complete Paperwork**: Fill all required forms
2. **Upload Evidence**: Photos, videos, documents
3. **Update System**: Record results in learner profile
4. **Plan Remediation**: If not competent, plan additional training
5. **Sync Data**: Upload to central system

### Portfolio of Evidence (POE)

#### POE Components
- **Assessment Records**: All assessment results
- **Evidence Photos**: Visual proof of competence
- **Workplace Documents**: Job cards, safety records
- **Reflection Sheets**: Learner self-assessment
- **Supervisor Reports**: Workplace feedback

#### Managing POE
1. **Create Portfolio**: Set up digital folder for learner
2. **Collect Evidence**: Gather throughout training period
3. **Organize Documents**: Sort by unit standard/module
4. **Quality Check**: Ensure all evidence is valid
5. **Submit for Moderation**: Send to external moderator

#### Digital POE Process
```
Evidence Collection → Digital Capture → 
System Upload → Quality Review → 
Moderation Submission → Final Approval
```

---

## MATERIAL MANAGEMENT

### Material Types

#### Personal Protective Equipment (PPE)
- Safety helmets
- Safety boots
- High-visibility vests
- Safety glasses
- Gloves
- Harnesses

#### Learning Materials
- Textbooks and manuals
- Workbooks and worksheets
- DVDs and digital content
- Tools and equipment
- Stationery supplies

#### Consumables
- Writing materials
- Practice materials
- Test materials
- Certificates and forms

### Material Issuance Process

#### Standard Issuance
1. **Check Allocation**: Verify learner entitlement
2. **Select Items**: Choose appropriate sizes/types
3. **Scan Barcodes**: Record items being issued
4. **Learner Signature**: Get acknowledgment of receipt
5. **Update Inventory**: Reduce stock levels
6. **Generate Receipt**: Print/email confirmation

#### Bulk Issuance
For new intake groups:
1. **Prepare Lists**: Generate material requirements
2. **Pre-pack Items**: Organize by learner
3. **Set Up Station**: Arrange efficient distribution
4. **Process Group**: Issue to multiple learners
5. **Batch Update**: Update all records simultaneously

### Inventory Management

#### Stock Monitoring
- **Daily Checks**: Monitor critical stock levels
- **Weekly Reports**: Generate inventory summaries
- **Reorder Alerts**: System notifications for low stock
- **Audit Trails**: Track all material movements

#### Returns and Exchanges
1. **Inspect Returned Items**: Check condition and completeness
2. **Update Records**: Mark items as returned
3. **Process Exchanges**: Handle size/type changes
4. **Refurbish if Needed**: Clean and repair items
5. **Return to Stock**: Make available for reissue

---

## REPORTING

### Daily Reports

#### Attendance Report
**Generated**: End of each training day
**Contents**:
- Learner attendance summary
- Late arrivals and early departures
- Absentees with reasons
- Total hours per learner
- Exceptions and notes

#### Activity Report
**Generated**: End of each training day
**Contents**:
- Training activities completed
- Assessments conducted
- Materials issued
- Issues encountered
- Next day planning

### Weekly Reports

#### Progress Report
**Generated**: End of each week
**Contents**:
- Individual learner progress
- Module completion rates
- Assessment results summary
- Attendance patterns
- Performance concerns

#### Resource Utilization
**Generated**: End of each week
**Contents**:
- Material usage statistics
- Equipment utilization
- Facility usage patterns
- Cost analysis
- Efficiency metrics

### Monthly Reports

#### Comprehensive Summary
**Generated**: End of each month
**Contents**:
- Overall program progress
- Learner achievement rates
- Resource consumption
- Quality metrics
- Recommendations

### Generating Reports

#### Standard Reports
1. **Navigate**: Reports → Select Report Type
2. **Set Parameters**: Choose date range, learners, filters
3. **Generate**: Click "Create Report" button
4. **Review**: Check data accuracy and completeness
5. **Export**: Save as PDF/Excel for distribution
6. **Share**: Email to stakeholders as required

#### Custom Reports
1. **Navigate**: Reports → Custom Report Builder
2. **Select Data**: Choose fields and tables
3. **Set Filters**: Define criteria and conditions
4. **Format Output**: Choose layout and styling
5. **Save Template**: Store for future use
6. **Generate**: Create and export report

---

## TROUBLESHOOTING

### Common Issues

#### Connectivity Problems
**Symptoms**: Slow sync, failed uploads, offline indicators
**Solutions**:
1. Check WiFi/mobile data connection
2. Restart network adapter
3. Move to area with better signal
4. Switch between WiFi and mobile data
5. Contact IT support if persistent

#### Scanner Issues
**Symptoms**: Fingerprint not recognized, barcode scan fails
**Solutions**:
1. Clean scanner surface
2. Ensure good lighting
3. Hold steady during scan
4. Try alternative scanning angle
5. Use manual entry if scanner fails

#### App Performance
**Symptoms**: Slow response, crashes, freezing
**Solutions**:
1. Close other apps to free memory
2. Restart the application
3. Clear app cache and data
4. Restart device
5. Reinstall app if necessary

#### Data Sync Issues
**Symptoms**: Data not uploading, conflicts, duplicates
**Solutions**:
1. Check network connectivity
2. Force manual sync
3. Resolve data conflicts
4. Clear sync queue
5. Contact system administrator

### Error Messages

#### "Network Connection Failed"
- **Cause**: No internet connectivity
- **Solution**: Check network settings, try different connection
- **Workaround**: Continue in offline mode, sync later

#### "Authentication Failed"
- **Cause**: Invalid credentials or session expired
- **Solution**: Re-login with correct credentials
- **Prevention**: Don't share login details, change passwords regularly

#### "Insufficient Storage Space"
- **Cause**: Device storage full
- **Solution**: Delete unnecessary files, move photos to cloud
- **Prevention**: Regular cleanup, monitor storage usage

#### "Scanner Hardware Error"
- **Cause**: Hardware malfunction or driver issue
- **Solution**: Restart device, check hardware connections
- **Workaround**: Use manual entry methods

### Emergency Procedures

#### System Failure During Assessment
1. **Continue Assessment**: Don't stop the process
2. **Paper Backup**: Use manual forms
3. **Document Everything**: Take detailed notes
4. **Photo Evidence**: Use device camera
5. **Enter Later**: Input data when system restored

#### Network Outage
1. **Switch to Offline Mode**: Continue operations locally
2. **Inform Learners**: Explain situation
3. **Use Backup Procedures**: Manual processes
4. **Document Issues**: Note all problems
5. **Sync When Restored**: Upload all data

---

## TRAINING MODULES

### Module 1: System Basics (2 hours)
**Objectives**: Understand system navigation and basic functions
**Content**:
- System overview and architecture
- Login and security procedures
- Dashboard navigation
- Basic data entry
- Offline/online modes

**Practical Exercises**:
- Navigate through all main screens
- Add a test learner record
- Practice data entry forms
- Switch between online/offline modes

### Module 2: Learner Management (3 hours)
**Objectives**: Master learner registration and management
**Content**:
- Learner registration process
- Profile management
- Photo capture techniques
- Data validation
- Bulk operations

**Practical Exercises**:
- Register 5 new learners
- Update existing profiles
- Practice photo capture
- Import learner data from spreadsheet

### Module 3: Attendance Tracking (2 hours)
**Objectives**: Efficiently manage daily attendance
**Content**:
- Clock-in/out procedures
- Manual attendance entry
- Exception handling
- Attendance reporting
- Troubleshooting common issues

**Practical Exercises**:
- Process mock attendance session
- Handle various exception scenarios
- Generate attendance reports
- Practice troubleshooting steps

### Module 4: Assessment & POE (4 hours)
**Objectives**: Conduct assessments and manage portfolios
**Content**:
- Assessment planning and setup
- Conducting fair assessments
- Evidence collection
- POE management
- Quality assurance

**Practical Exercises**:
- Plan and conduct mock assessment
- Collect and organize evidence
- Create digital portfolio
- Practice feedback techniques

### Module 5: Material Management (2 hours)
**Objectives**: Manage material issuance and inventory
**Content**:
- Material types and categories
- Issuance procedures
- Inventory tracking
- Returns and exchanges
- Stock management

**Practical Exercises**:
- Issue materials to learners
- Process returns and exchanges
- Generate inventory reports
- Practice stock counting

### Module 6: Reporting & Analytics (2 hours)
**Objectives**: Generate and interpret reports
**Content**:
- Report types and purposes
- Report generation process
- Data interpretation
- Custom report creation
- Stakeholder communication

**Practical Exercises**:
- Generate standard reports
- Create custom report
- Interpret data trends
- Present findings to group

### Module 7: Advanced Features (3 hours)
**Objectives**: Utilize advanced system capabilities
**Content**:
- Advanced search and filtering
- Bulk operations
- Data import/export
- System integration
- Customization options

**Practical Exercises**:
- Perform complex searches
- Execute bulk operations
- Import/export data
- Customize system settings

### Module 8: Troubleshooting & Support (2 hours)
**Objectives**: Resolve common issues independently
**Content**:
- Common problem identification
- Troubleshooting methodology
- Emergency procedures
- Support escalation
- Preventive maintenance

**Practical Exercises**:
- Diagnose simulated problems
- Practice emergency procedures
- Role-play support scenarios
- Create troubleshooting checklist

---

## BEST PRACTICES

### Daily Operations

#### Morning Routine
1. **Arrive 30 minutes early** to set up equipment
2. **Check system status** and connectivity
3. **Review daily schedule** and expected learners
4. **Test equipment** (scanner, camera, network)
5. **Prepare materials** for the day's activities

#### During Training
1. **Monitor attendance** throughout the day
2. **Document activities** and progress
3. **Handle exceptions** promptly and fairly
4. **Maintain equipment** and workspace
5. **Engage with learners** professionally

#### End of Day
1. **Complete attendance** records
2. **Upload all data** to server
3. **Secure equipment** and materials
4. **Generate reports** as required
5. **Plan next day** activities

### Data Quality

#### Accuracy
- **Double-check entries** before saving
- **Verify learner identity** before recording attendance
- **Use consistent naming** conventions
- **Validate data** before submission
- **Regular audits** of data quality

#### Completeness
- **Fill all required fields** completely
- **Collect all evidence** for assessments
- **Document exceptions** thoroughly
- **Maintain complete records** for each learner
- **Regular backup** of important data

#### Timeliness
- **Enter data immediately** when possible
- **Sync regularly** throughout the day
- **Meet reporting deadlines** consistently
- **Update records promptly** when changes occur
- **Communicate delays** to stakeholders

### Professional Development

#### Continuous Learning
- **Attend training sessions** regularly
- **Stay updated** on system changes
- **Learn from colleagues** and share knowledge
- **Practice new features** in test environment
- **Seek feedback** on performance

#### Quality Improvement
- **Monitor performance metrics** regularly
- **Identify improvement opportunities** proactively
- **Implement best practices** consistently
- **Share successful strategies** with team
- **Participate in quality reviews** actively

---

## SUPPORT CONTACTS

### Technical Support
- **Help Desk**: ext. 2345 or helpdesk@rlmss.co.za
- **System Administrator**: admin@rlmss.co.za
- **Emergency Support**: +27 11 123 4567 (24/7)

### Training Support
- **Training Manager**: training@rlmss.co.za
- **Assessment Coordinator**: assessment@rlmss.co.za
- **Quality Assurance**: qa@rlmss.co.za

### Administrative Support
- **HR Department**: hr@rlmss.co.za
- **Finance Department**: finance@rlmss.co.za
- **Compliance Officer**: compliance@rlmss.co.za

---

## APPENDICES

### Appendix A: Keyboard Shortcuts
- **Ctrl + S**: Save current form
- **Ctrl + F**: Search/Find
- **Ctrl + N**: New record
- **Ctrl + R**: Refresh data
- **F5**: Sync with server

### Appendix B: Error Codes
- **E001**: Network connection failed
- **E002**: Authentication error
- **E003**: Data validation failed
- **E004**: Hardware malfunction
- **E005**: Insufficient permissions

### Appendix C: File Formats
- **Import**: CSV, Excel (.xlsx), XML
- **Export**: PDF, Excel (.xlsx), CSV, Word (.docx)
- **Images**: JPG, PNG (max 5MB)
- **Documents**: PDF (max 10MB)

---

*Manual Version: 2.0*  
*Last Updated: April 30, 2026*  
*Next Review: July 30, 2026*  
*Training Certification Valid: 12 months*