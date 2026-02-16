// Geofencing for Web Version - 300 meter radius check
// Add this script to your learner list page

// Configuration
const GEOFENCE_RADIUS = 300; // meters
const GPS_ACCURACY_THRESHOLD = 50; // meters

// Get site coordinates from PHP (you'll need to pass these from your PHP)
let siteLatitude = null;
let siteLongitude = null;

// Function to set site coordinates (call this from PHP)
function setSiteCoordinates(lat, lon) {
    siteLatitude = parseFloat(lat);
    siteLongitude = parseFloat(lon);
    console.log('[GEOFENCE] Site coordinates set:', siteLatitude, siteLongitude);
}

// Calculate distance between two coordinates using Haversine formula
function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371000; // Earth radius in meters
    const phi1 = lat1 * Math.PI / 180;
    const phi2 = lat2 * Math.PI / 180;
    const deltaPhi = (lat2 - lat1) * Math.PI / 180;
    const deltaLambda = (lon2 - lon1) * Math.PI / 180;

    const a = Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
              Math.cos(phi1) * Math.cos(phi2) *
              Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c; // Distance in meters
}

// Check if user is within geofence
async function checkGeofence() {
    return new Promise((resolve, reject) => {
        // Check if site coordinates are set
        if (!siteLatitude || !siteLongitude) {
            reject({
                error: 'NO_SITE_COORDS',
                message: 'Site coordinates not configured. Please contact administrator.'
            });
            return;
        }

        // Check if geolocation is supported
        if (!navigator.geolocation) {
            reject({
                error: 'NOT_SUPPORTED',
                message: 'Geolocation is not supported by your browser.'
            });
            return;
        }

        console.log('[GEOFENCE] Requesting location...');

        // Get current position
        navigator.geolocation.getCurrentPosition(
            (position) => {
                const userLat = position.coords.latitude;
                const userLon = position.coords.longitude;
                const accuracy = position.coords.accuracy;

                console.log('[GEOFENCE] User location:', userLat, userLon);
                console.log('[GEOFENCE] GPS accuracy:', accuracy, 'meters');

                // Check GPS accuracy
                if (accuracy > GPS_ACCURACY_THRESHOLD) {
                    reject({
                        error: 'POOR_ACCURACY',
                        message: `GPS accuracy too low (${Math.round(accuracy)}m). Please ensure GPS is enabled and try again.`,
                        accuracy: accuracy
                    });
                    return;
                }

                // Calculate distance to site
                const distance = calculateDistance(userLat, userLon, siteLatitude, siteLongitude);
                console.log('[GEOFENCE] Distance to site:', Math.round(distance), 'meters');

                // Check if within radius
                if (distance > GEOFENCE_RADIUS) {
                    reject({
                        error: 'OUTSIDE_GEOFENCE',
                        message: `You are ${Math.round(distance)} meters away. You must be within ${GEOFENCE_RADIUS} meters of the site to clock in/out.`,
                        distance: distance,
                        userLat: userLat,
                        userLon: userLon,
                        accuracy: accuracy
                    });
                    return;
                }

                // Success - within geofence
                console.log('[GEOFENCE] ✅ Within geofence - clocking allowed');
                resolve({
                    success: true,
                    userLat: userLat,
                    userLon: userLon,
                    accuracy: accuracy,
                    distance: distance
                });
            },
            (error) => {
                console.error('[GEOFENCE] Error getting location:', error);
                
                let message = 'Unable to get your location. ';
                switch(error.code) {
                    case error.PERMISSION_DENIED:
                        message += 'Please allow location access in your browser settings.';
                        break;
                    case error.POSITION_UNAVAILABLE:
                        message += 'Location information is unavailable.';
                        break;
                    case error.TIMEOUT:
                        message += 'Location request timed out. Please try again.';
                        break;
                    default:
                        message += 'An unknown error occurred.';
                }
                
                reject({
                    error: 'LOCATION_ERROR',
                    message: message,
                    code: error.code
                });
            },
            {
                enableHighAccuracy: true,
                timeout: 10000,
                maximumAge: 0
            }
        );
    });
}

// Modified handleClockIn function with geofencing
async function handleClockInWithGeofence(learnerID) {
    const canvas = document.getElementById('signature-pad-' + learnerID);
    let signaturePad = signaturePads[learnerID];

    // Check if the signature pad is initialized
    if (!signaturePad) {
        signaturePad = new SignaturePad(canvas);
        signaturePads[learnerID] = signaturePad;
        console.log("SignaturePad initialized for Clock-In LearnerID:", learnerID);
    }

    // Check if the signature pad is empty
    if (signaturePad.isEmpty()) {
        alert("Please provide a signature before clocking in.");
        console.log("Signature is empty for Clock-In LearnerID:", learnerID);
        return false;
    }

    // Show loading message
    const submitBtn = document.querySelector(`#clockin-form-${learnerID} button[type="submit"]`);
    const originalText = submitBtn.innerHTML;
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Checking location...';

    try {
        // Check geofence
        const geoData = await checkGeofence();
        
        // Add GPS coordinates to form
        const form = document.getElementById('clockin-form-' + learnerID);
        
        // Remove old hidden inputs if they exist
        ['user_latitude', 'user_longitude', 'user_accuracy'].forEach(name => {
            const oldInput = form.querySelector(`input[name="${name}"]`);
            if (oldInput) oldInput.remove();
        });
        
        // Add new hidden inputs with GPS data
        const latInput = document.createElement('input');
        latInput.type = 'hidden';
        latInput.name = 'user_latitude';
        latInput.value = geoData.userLat;
        form.appendChild(latInput);
        
        const lonInput = document.createElement('input');
        lonInput.type = 'hidden';
        lonInput.name = 'user_longitude';
        lonInput.value = geoData.userLon;
        form.appendChild(lonInput);
        
        const accInput = document.createElement('input');
        accInput.type = 'hidden';
        accInput.name = 'user_accuracy';
        accInput.value = geoData.accuracy;
        form.appendChild(accInput);

        // Convert the signature to a data URL and set it in the hidden input
        const signatureInput = document.getElementById('signature-' + learnerID);
        signatureInput.value = signaturePad.toDataURL();
        console.log("Signature data URL for Clock-In:", signatureInput.value);

        // Restore button
        submitBtn.disabled = false;
        submitBtn.innerHTML = originalText;

        return true; // Allow form submission
    } catch (error) {
        // Restore button
        submitBtn.disabled = false;
        submitBtn.innerHTML = originalText;

        // Show error message
        alert(error.message || 'Geofencing check failed. Please try again.');
        console.error('[GEOFENCE] Error:', error);
        return false; // Prevent form submission
    }
}

// Modified handleClockOut function with geofencing
async function handleClockOutWithGeofence(learnerID) {
    const canvas = document.getElementById('clockout-signature-pad-' + learnerID);
    let signaturePad = clockOutSignaturePads[learnerID];

    // Check if the signature pad is initialized
    if (!signaturePad) {
        signaturePad = new SignaturePad(canvas);
        clockOutSignaturePads[learnerID] = signaturePad;
        console.log("SignaturePad initialized for Clock-Out LearnerID:", learnerID);
    }

    // Check if the signature pad is empty
    if (signaturePad.isEmpty()) {
        alert("Please provide a signature before clocking out.");
        console.log("Signature is empty for Clock-Out LearnerID:", learnerID);
        return false;
    }

    // Show loading message
    const submitBtn = document.querySelector(`#clockout-form-${learnerID} button[type="submit"]`);
    const originalText = submitBtn.innerHTML;
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Checking location...';

    try {
        // Check geofence
        const geoData = await checkGeofence();
        
        // Add GPS coordinates to form
        const form = document.getElementById('clockout-form-' + learnerID);
        
        // Remove old hidden inputs if they exist
        ['user_latitude', 'user_longitude', 'user_accuracy'].forEach(name => {
            const oldInput = form.querySelector(`input[name="${name}"]`);
            if (oldInput) oldInput.remove();
        });
        
        // Add new hidden inputs with GPS data
        const latInput = document.createElement('input');
        latInput.type = 'hidden';
        latInput.name = 'user_latitude';
        latInput.value = geoData.userLat;
        form.appendChild(latInput);
        
        const lonInput = document.createElement('input');
        lonInput.type = 'hidden';
        lonInput.name = 'user_longitude';
        lonInput.value = geoData.userLon;
        form.appendChild(lonInput);
        
        const accInput = document.createElement('input');
        accInput.type = 'hidden';
        accInput.name = 'user_accuracy';
        accInput.value = geoData.accuracy;
        form.appendChild(accInput);

        // Restore button
        submitBtn.disabled = false;
        submitBtn.innerHTML = originalText;

        return true; // Allow form submission
    } catch (error) {
        // Restore button
        submitBtn.disabled = false;
        submitBtn.innerHTML = originalText;

        // Show error message
        alert(error.message || 'Geofencing check failed. Please try again.');
        console.error('[GEOFENCE] Error:', error);
        return false; // Prevent form submission
    }
}
