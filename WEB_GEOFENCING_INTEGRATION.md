## Web Geofencing Integration Guide

### Files Created:
1. **`geofencing_web.js`** - JavaScript geofencing logic

### Integration Steps:

#### Step 1: Add the geofencing script to your learner_list.php

Find this line in your file:
```html
<script src="https://cdn.jsdelivr.net/npm/signature_pad@2.3.2/dist/signature_pad.min.js"></script>
```

Add AFTER it:
```html
<script src="geofencing_web.js"></script>
```

#### Step 2: Set site coordinates from PHP

Add this PHP code near the top of your file (after `$classDetails = getClassDetails...`):

```php
<?php
// Get site coordinates for geofencing
$siteCoords = null;
$stmt = $conn->prepare("SELECT s.latitude, s.longitude FROM class c JOIN sites s ON c.siteID = s.siteID WHERE c.classID = ?");
$stmt->bind_param("s", $classID);
$stmt->execute();
$result = $stmt->get_result();
if ($row = $result->fetch_assoc()) {
    $siteCoords = $row;
}
$stmt->close();
?>
```

#### Step 3: Initialize geofencing in JavaScript

Find this line in your JavaScript:
```javascript
// Initialize signature pads for clock-in and clock-out
const signaturePads = {};
```

Add BEFORE it:
```javascript
<?php if ($siteCoords): ?>
// Set site coordinates for geofencing
setSiteCoordinates(<?php echo $siteCoords['latitude']; ?>, <?php echo $siteCoords['longitude']; ?>);
<?php else: ?>
console.error('[GEOFENCE] No site coordinates found for class <?php echo $classID; ?>');
<?php endif; ?>
```

#### Step 4: Update form onsubmit handlers

Find these lines:
```html
<form id="clockin-form-<?php echo $row['LearnerID']; ?>" action="clockin.php" method="POST" onsubmit="return handleClockIn(<?php echo $row['LearnerID']; ?>);">
```

Change to:
```html
<form id="clockin-form-<?php echo $row['LearnerID']; ?>" action="clockin.php" method="POST" onsubmit="return handleClockInWithGeofence(<?php echo $row['LearnerID']; ?>);">
```

And:
```html
<form id="clockout-form-<?php echo $row['LearnerID']; ?>" action="clockout.php" method="POST" onsubmit="return handleClockOut(<?php echo $row['LearnerID']; ?>);">
```

Change to:
```html
<form id="clockout-form-<?php echo $row['LearnerID']; ?>" action="clockout.php" method="POST" onsubmit="return handleClockOutWithGeofence(<?php echo $row['LearnerID']; ?>);">
```

---

### Complete Integration Example:

Here's what the key sections should look like after integration:

```php
<?php
// Include the database connection file
include 'facilitator_header.php';

// Start session and report
$classID = $_SESSION['classID'];

// Fetch class details
$classDetails = getClassDetails($classID, $conn);

// Get site coordinates for geofencing
$siteCoords = null;
$stmt = $conn->prepare("SELECT s.latitude, s.longitude FROM class c JOIN sites s ON c.siteID = s.siteID WHERE c.classID = ?");
$stmt->bind_param("s", $classID);
$stmt->execute();
$result = $stmt->get_result();
if ($row = $result->fetch_assoc()) {
    $siteCoords = $row;
}
$stmt->close();

$selectedClassName = $classID;
?>

<!-- Your HTML content here -->

<!-- At the bottom, before closing </body> -->
<script src="https://cdn.jsdelivr.net/npm/signature_pad@2.3.2/dist/signature_pad.min.js"></script>
<script src="geofencing_web.js"></script>
<script>
<?php if ($siteCoords): ?>
// Set site coordinates for geofencing
setSiteCoordinates(<?php echo $siteCoords['latitude']; ?>, <?php echo $siteCoords['longitude']; ?>);
<?php else: ?>
console.error('[GEOFENCE] No site coordinates found for class <?php echo $classID; ?>');
alert('Warning: Site coordinates not configured. Geofencing will not work. Please contact administrator.');
<?php endif; ?>

// Initialize signature pads for clock-in and clock-out
const signaturePads = {};
const clockOutSignaturePads = {};

// Keep your existing clearSignature and clearClockOutSignature functions
function clearSignature(learnerID) {
    const canvas = document.getElementById('signature-pad-' + learnerID);
    const signaturePad = signaturePads[learnerID];
    if (signaturePad) {
        signaturePad.clear();
        console.log("Signature cleared for Clock-In LearnerID:", learnerID);
    }
}

function clearClockOutSignature(learnerID) {
    const canvas = document.getElementById('clockout-signature-pad-' + learnerID);
    const signaturePad = clockOutSignaturePads[learnerID];
    if (signaturePad) {
        signaturePad.clear();
        console.log("Signature cleared for Clock-Out LearnerID:", learnerID);
    }
}

// Initialize signature pad each time the modal is shown
document.querySelectorAll('.modal').forEach(function(modal) {
    modal.addEventListener('shown.bs.modal', function(event) {
        const modalID = event.target.id;
        let learnerID;
        
        if (modalID.includes('signatureModal-')) {
            learnerID = modalID.split('signatureModal-')[1];
            const canvas = document.getElementById('signature-pad-' + learnerID);
            if (!signaturePads[learnerID]) {
                signaturePads[learnerID] = new SignaturePad(canvas);
                console.log("SignaturePad initialized for Clock-In LearnerID:", learnerID);
            }
        } else if (modalID.includes('clockoutSignatureModal-')) {
            learnerID = modalID.split('clockoutSignatureModal-')[1];
            const canvas = document.getElementById('clockout-signature-pad-' + learnerID);
            if (!clockOutSignaturePads[learnerID]) {
                clockOutSignaturePads[learnerID] = new SignaturePad(canvas);
                console.log("SignaturePad initialized for Clock-Out LearnerID:", learnerID);
            }
        }
    });
});

// Your existing date and practitioner handling functions
function toggleOtherPractitioner(select, learnerId) {
    const otherInput = document.getElementById('other_practitioner-' + learnerId);
    if (select.value === 'Other') {
        otherInput.classList.remove('d-none');
        otherInput.setAttribute('required', 'required');
    } else {
        otherInput.classList.add('d-none');
        otherInput.removeAttribute('required');
    }
}

function adjustToDate(learnerId) {
    const fromDate = document.getElementById('date_from-' + learnerId);
    const toDate = document.getElementById('date_to-' + learnerId);
    if (fromDate.value) {
        toDate.min = fromDate.value;
    }
}

// Limit date_from to not be earlier than 5 working days from today
document.addEventListener('DOMContentLoaded', function () {
    const dateFromInputs = document.querySelectorAll("input[name='date_from']");
    const today = new Date();
    let workingDays = 0;
    let minDate = new Date(today);

    while (workingDays < 5) {
        minDate.setDate(minDate.getDate() - 1);
        const day = minDate.getDay();
        if (day !== 0 && day !== 6) {
            workingDays++;
        }
    }

    const minDateStr = minDate.toISOString().split('T')[0];
    dateFromInputs.forEach(input => {
        input.setAttribute('min', minDateStr);
    });
});
</script>
```

---

### What This Does:

1. **Gets site coordinates** from database based on classID
2. **Initializes geofencing** with site coordinates
3. **Checks location** when user clicks Clock In/Out
4. **Validates distance** - must be within 300 meters
5. **Adds GPS coordinates** to form submission
6. **Shows clear error messages** if outside geofence

---

### User Experience:

**Clock-In Flow:**
1. User clicks "Clock In" button
2. User signs signature pad
3. User clicks "Clock In" submit button
4. Button shows "Checking location..." with spinner
5. Browser requests location permission (first time only)
6. System checks if within 300 meters
7. If YES → Form submits with GPS coordinates ✅
8. If NO → Shows error with distance ❌

**Error Messages:**
- "You are 450 meters away. You must be within 300 meters..."
- "GPS accuracy too low (85m). Please ensure GPS is enabled..."
- "Please allow location access in your browser settings."
- "Site coordinates not configured. Please contact administrator."

---

### Testing:

1. **Test at site (within 300m):**
   - Should allow clock-in/out
   - GPS coordinates should be sent to server

2. **Test away from site (>300m):**
   - Should deny clock-in/out
   - Should show distance in error message

3. **Test with GPS disabled:**
   - Should show permission error
   - Should not allow clock-in/out

4. **Check browser console:**
   - Should see `[GEOFENCE]` log messages
   - Should see GPS coordinates and distance

---

### Browser Compatibility:

Works on:
- ✅ Chrome/Edge (desktop & mobile)
- ✅ Firefox (desktop & mobile)
- ✅ Safari (desktop & mobile)
- ✅ Opera

Requires:
- HTTPS connection (geolocation requires secure context)
- Location permission granted by user

---

### Troubleshooting:

**"Geolocation is not supported"**
- Browser doesn't support geolocation API
- Try a modern browser

**"Please allow location access"**
- User denied location permission
- Check browser settings → Site permissions → Location

**"Site coordinates not configured"**
- Sites table doesn't have coordinates
- Run: `UPDATE sites SET latitude=-26.123456, longitude=28.123456 WHERE siteID='YOUR_SITE_ID';`

**GPS coordinates not being sent to server**
- Check browser console for errors
- Verify geofencing_web.js is loaded
- Check form has hidden inputs for GPS data

---

### Security Notes:

1. **HTTPS Required** - Geolocation API only works on HTTPS
2. **User Permission** - Browser will ask user for location permission
3. **Client-Side Check** - This is a client-side check (can be bypassed by tech-savvy users)
4. **Server-Side Validation** - Your PHP files already validate GPS coordinates server-side
5. **Audit Trail** - GPS coordinates are logged in clocking_log table

---

### Summary:

✅ Web version now has same geofencing as mobile app
✅ 300-meter radius enforced
✅ GPS coordinates sent to server
✅ Clear error messages
✅ Works on all modern browsers
✅ Requires HTTPS and location permission
