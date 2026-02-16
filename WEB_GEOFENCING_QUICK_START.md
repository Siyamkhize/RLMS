# Web Geofencing - Quick Start

## 🎯 Add Geofencing to Your Web Version

### Files Created:
- **`geofencing_web.js`** - Geofencing JavaScript
- **`WEB_GEOFENCING_INTEGRATION.md`** - Full integration guide

---

## 🚀 Quick Integration (5 Steps)

### Step 1: Upload geofencing_web.js
Upload `geofencing_web.js` to your web server (same folder as your learner list page)

### Step 2: Add Script Tag
In your learner list PHP file, find:
```html
<script src="https://cdn.jsdelivr.net/npm/signature_pad@2.3.2/dist/signature_pad.min.js"></script>
```

Add after it:
```html
<script src="geofencing_web.js"></script>
```

### Step 3: Get Site Coordinates
Add this PHP code after `$classDetails = getClassDetails...`:
```php
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
```

### Step 4: Initialize Geofencing
In your JavaScript section, add BEFORE `const signaturePads = {}`:
```javascript
<?php if ($siteCoords): ?>
setSiteCoordinates(<?php echo $siteCoords['latitude']; ?>, <?php echo $siteCoords['longitude']; ?>);
<?php else: ?>
console.error('[GEOFENCE] No site coordinates found');
alert('Warning: Site coordinates not configured. Please contact administrator.');
<?php endif; ?>
```

### Step 5: Update Form Handlers
Change:
```html
onsubmit="return handleClockIn(<?php echo $row['LearnerID']; ?>);"
```
To:
```html
onsubmit="return handleClockInWithGeofence(<?php echo $row['LearnerID']; ?>);"
```

And:
```html
onsubmit="return handleClockOut(<?php echo $row['LearnerID']; ?>);"
```
To:
```html
onsubmit="return handleClockOutWithGeofence(<?php echo $row['LearnerID']; ?>);"
```

---

## ✅ Done!

Your web version now has:
- ✅ 300-meter geofencing
- ✅ GPS coordinate capture
- ✅ Clear error messages
- ✅ Same functionality as mobile app

---

## 🧪 Test It

1. **At site (within 300m):** Should allow clock-in/out
2. **Away from site (>300m):** Should deny with distance message
3. **Check console:** Should see `[GEOFENCE]` logs

---

## ⚠️ Requirements

- HTTPS connection (required for geolocation)
- Modern browser (Chrome, Firefox, Safari, Edge)
- Location permission granted by user
- Site coordinates in database

---

## 📞 Troubleshooting

**"Site coordinates not configured"**
```sql
UPDATE sites SET latitude=-26.123456, longitude=28.123456 WHERE siteID='YOUR_SITE_ID';
```

**"Please allow location access"**
- User needs to grant location permission in browser

**Not working on HTTP**
- Geolocation requires HTTPS
- Use HTTPS or test on localhost

---

See **`WEB_GEOFENCING_INTEGRATION.md`** for detailed instructions!
