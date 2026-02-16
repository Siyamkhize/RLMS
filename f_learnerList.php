<?php
// Include the database connection file
include 'facilitator_header.php'; // Adjust the path as necessary

// Start session and report
$classID = $_SESSION['classID'];

// Fetch class details
$classDetails = getClassDetails($classID, $conn);

if ($classDetails) {
    // Now you can safely access the associative array
    echo "Project ID: " . $classDetails['project_id'];
} else {
    echo "No class found for the provided Class ID.";
}
$selectedClassName = $classID; 

// Fetch site coordinates from database via class-site join
$siteQuery = "SELECT s.latitude, s.longitude FROM class c JOIN sites s ON c.siteID = s.siteID WHERE c.classID = ?";
$stmt = $conn->prepare($siteQuery);
$stmt->bind_param("s", $classID);
$stmt->execute();
$siteResult = $stmt->get_result();
$siteCoords = $siteResult->fetch_assoc();
$stmt->close();
?>

<!-- Body content starts here -->
<div class="container-fluid">
    <div class="d-flex flex-column-reverse">
        <div class="content-wrapper w-100">
            <!-- Cards Section -->
            <div class="container-fluid page-content">
                <div class="row">
                    <!-- Content Area -->
                    <div class="col-md-10 ms-auto padding-right">
                        <!-- Cards Section -->
                        <div class="page-header">
                            <h3 class="page-title">
                                <button class="btn btn-primary" onclick="goBack()">
                                    ← Back
                                </button>
                            </h3>
                        </div>
                        <!--SITE Profile Form-->
                        <div class="col-lg-12 grid-margin stretch-card">
                            <div class="card">
                                <div class="card-body">
                                    <h4 class="card-title">Learner List</h4>
                                    <?php
                                    // Call the function to get learner clocking details
                                    $result = getLearnerClockingDetails($selectedClassName, $conn);

                                    if ($result->num_rows > 0): ?>
                                        <div class="table-responsive">
                                            <table class="table table-striped">
                                                <thead>
                                                    <tr>
                                                        <th>Name</th>
                                                        <th>Surname</th>
                                                        <th>Clock In</th>
                                                        <th>Clock Out</th>
                                                        <th>Contact Time</th>
                                                        <th>Action</th>
                                                    </tr>
                                                </thead>
                                                <tbody>
                                                    <?php while($row = $result->fetch_assoc()): ?>
                                                        <tr>
                                                            <td><?php echo $row["Name"]; ?></td>
                                                            <td><?php echo $row["Surname"]; ?></td>

                                                            <!-- Clock In -->
                                                            <td>
                                                                <?php if(empty($row["clock_in_time"])): ?>
                                                                    <!-- Button to open the modal for signature pad -->
                                                                    <button type="button" class="btn btn-success" data-bs-toggle="modal" data-bs-target="#signatureModal-<?php echo $row['LearnerID']; ?>">Clock In</button>
                                                                <?php else: ?>
                                                                    <!-- Show the clock-in time -->
                                                                    <?php echo $row["clock_in_time"]; ?>
                                                                <?php endif; ?>
                                                            </td>

                                                            <!-- Clock Out -->
                                                            <td>
                                                                <?php if(empty($row["clock_out_time"])): ?>
                                                                    <!-- Only show clock out button if the learner has clocked in -->
                                                                    <?php if(!empty($row["clock_in_time"])): ?>
                                                                        <button type="button" class="btn btn-danger" data-bs-toggle="modal" data-bs-target="#clockoutSignatureModal-<?php echo $row['LearnerID']; ?>">Clock Out</button>
                                                                    <?php else: ?>
                                                                        <!-- Show a message that clocking out is not available yet -->
                                                                        <span>Clock in first</span>
                                                                    <?php endif; ?>
                                                                <?php else: ?>
                                                                    <!-- Show the clock-out time -->
                                                                    <?php echo $row["clock_out_time"]; ?>
                                                                <?php endif; ?>
                                                            </td>

                                                            <!-- Contact Time -->
                                                            <td>
                                                                <?php echo !empty($row["contact_time"]) ? $row["contact_time"] : "N/A"; ?>
                                                            </td>

                                                            <!-- Action buttons -->
                                                            <td>
                                                                <!-- Link to open the sick note upload modal -->
                                                                <a href="#" class="btn btn-link" data-bs-toggle="modal" data-bs-target="#sickNoteModal-<?php echo $row['LearnerID']; ?>" title="Upload Sick Note">
                                                                    <i class="fa fa-upload"></i>
                                                                </a>
                                                                <a href="print_test.php?LearnerID=<?php echo urlencode($row['LearnerID']); ?>&project_id=<?php echo $classDetails['project_id'];?>" class="btn btn-link">
                                                                    <i class="fa fa-calendar" title="View Calendar"></i>
                                                                </a>
                                                            </td>
                                                        </tr>

                                                        <!-- Modal for Clock In Signature Pad for each learner -->
                                                        <div class="modal fade" id="signatureModal-<?php echo $row['LearnerID']; ?>" tabindex="-1" aria-labelledby="signatureModalLabel-<?php echo $row['LearnerID']; ?>" aria-hidden="true">
                                                            <div class="modal-dialog modal-l">
                                                                <div class="modal-content">
                                                                    <div class="modal-header">
                                                                        <h5 class="modal-title" id="signatureModalLabel-<?php echo $row['LearnerID']; ?>">Sign to Clock In</h5>
                                                                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                                                                    </div>
                                                                    <div class="modal-body">
                                                                        <form id="clockin-form-<?php echo $row['LearnerID']; ?>" action="clockin.php" method="POST" onsubmit="return handleClockInWithGeofence(<?php echo $row['LearnerID']; ?>);">
                                                                            <input type="hidden" name="LearnerID" value="<?php echo $row['LearnerID']; ?>">
                                                                            <input type="hidden" name="clock_in" value="1">

                                                                            <!-- Signature Pad -->
                                                                            <canvas id="signature-pad-<?php echo $row['LearnerID']; ?>" width="400" height="200" style="border: 1px solid #000;"></canvas>
                                                                            <button type="button" class="btn btn-warning mt-2" onclick="clearSignature('<?php echo $row['LearnerID']; ?>')">Clear</button>

                                                                            <!-- Hidden input to store signature data -->
                                                                            <input type="hidden" name="signature" id="signature-<?php echo $row['LearnerID']; ?>">
                                                                        </form>
                                                                    </div>
                                                                    <div class="modal-footer">
                                                                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
                                                                        <button type="submit" class="btn btn-primary" form="clockin-form-<?php echo $row['LearnerID']; ?>">Clock In</button>
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        </div>

                                                        <!-- Modal for Clock Out Signature Pad for each learner -->
                                                        <div class="modal fade" id="clockoutSignatureModal-<?php echo $row['LearnerID']; ?>" tabindex="-1" aria-labelledby="clockoutSignatureModalLabel-<?php echo $row['LearnerID']; ?>" aria-hidden="true">
                                                            <div class="modal-dialog modal-l">
                                                                <div class="modal-content">
                                                                    <div class="modal-header">
                                                                        <h5 class="modal-title" id="clockoutSignatureModalLabel-<?php echo $row['LearnerID']; ?>">Sign to Clock Out</h5>
                                                                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                                                                    </div>
                                                                    <div class="modal-body">
                                                                        <form id="clockout-form-<?php echo $row['LearnerID']; ?>" action="clockout.php" method="POST" onsubmit="return handleClockOutWithGeofence(<?php echo $row['LearnerID']; ?>);">
                                                                            <input type="hidden" name="LearnerID" value="<?php echo $row['LearnerID']; ?>">
                                                                            <input type="hidden" name="clock_out" value="1">

                                                                            <!-- Signature Pad -->
                                                                            <canvas id="clockout-signature-pad-<?php echo $row['LearnerID']; ?>" width="400" height="200" style="border: 1px solid #000;"></canvas>
                                                                            <button type="button" class="btn btn-warning mt-2" onclick="clearClockOutSignature('<?php echo $row['LearnerID']; ?>')">Clear</button>
                                                                        </form>
                                                                    </div>
                                                                    <div class="modal-footer">
                                                                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
                                                                        <button type="submit" class="btn btn-primary" form="clockout-form-<?php echo $row['LearnerID']; ?>">Clock Out</button>
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        </div>

                                                        <!-- Modal for Sick Note Upload for each learner -->
                                                        <div class="modal fade" id="sickNoteModal-<?php echo $row['LearnerID']; ?>" tabindex="-1" aria-labelledby="sickNoteModalLabel-<?php echo $row['LearnerID']; ?>" aria-hidden="true">
                                                            <div class="modal-dialog">
                                                                <div class="modal-content">
                                                                    <div class="modal-header">
                                                                        <h5 class="modal-title" id="sickNoteModalLabel-<?php echo $row['LearnerID']; ?>">Upload Sick Note</h5>
                                                                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                                                                    </div>
                                                                    <div class="modal-body">
                                                                        <form action="upload_sicknote.php" method="POST" enctype="multipart/form-data" id="sicknote-form-<?php echo $row['LearnerID']; ?>">
                                                                            <input type="hidden" name="LearnerID" value="<?php echo $row['LearnerID']; ?>">

                                                                            <!-- File Input for Sick Note -->
                                                                            <div class="mb-3">
                                                                                <label for="sicknote-<?php echo $row['LearnerID']; ?>" class="form-label">Select Sick Note (PDF only)</label>
                                                                                <input 
                                                                                    type="file" 
                                                                                    name="sicknote" 
                                                                                    id="sicknote-<?php echo $row['LearnerID']; ?>" 
                                                                                    class="form-control" 
                                                                                    accept=".pdf,application/pdf" 
                                                                                    required>
                                                                            </div>

                                                                            <script>
                                                                            document.getElementById('sicknote-<?php echo $row['LearnerID']; ?>').addEventListener('change', function () {
                                                                                const file = this.files[0];
                                                                                if (file && file.type !== 'application/pdf') {
                                                                                    alert('Only PDF files are allowed.');
                                                                                    this.value = '';
                                                                                }
                                                                            });
                                                                            </script>

                                                                            <!-- Practice Name -->
                                                                            <div class="mb-3">
                                                                                <label for="practice_name-<?php echo $row['LearnerID']; ?>" class="form-label">Practice Name</label>
                                                                                <input type="text" name="practice_name" id="practice_name-<?php echo $row['LearnerID']; ?>" class="form-control" required>
                                                                            </div>
                                                                            <!-- New Practitioner Name Field -->
                                                                            <div class="mb-3">
                                                                                <label class="form-label">Practitioner Name</label>
                                                                                <input type="text" name="practitioner_name" class="form-control" required>
                                                                            </div>
                                                                            <!-- Medical Practitioner -->
                                                                            <div class="mb-3">
                                                                                <label class="form-label">
                                                                                    Medical Practitioner
                                                                                    <span data-bs-toggle="tooltip" title="Select who issued the sick note. Choose 'Other' if not listed." style="cursor: help; color: #0d6efd;">ⓘ</span>
                                                                                </label>
                                                                                <select class="form-select" name="practitioner" id="practitioner-<?php echo $row['LearnerID']; ?>" onchange="toggleOtherPractitioner(this, '<?php echo $row['LearnerID']; ?>')" required>
                                                                                    <option value="">Select</option>
                                                                                    <option value="Doctor">Doctor</option>
                                                                                    <option value="Nurse">Nurse</option>
                                                                                    <option value="Other">Other</option>
                                                                                </select>
                                                                                <input type="text" name="other_practitioner" id="other_practitioner-<?php echo $row['LearnerID']; ?>" class="form-control mt-2 d-none" placeholder="Please specify" />
                                                                            </div>

                                                                            <!-- Applicable Date Range -->
                                                                            <div class="mb-3">
                                                                                <label class="form-label">Applicable Date Range</label>
                                                                                <div class="d-flex gap-2">
                                                                                    <div class="flex-fill">
                                                                                        <label for="date_from-<?php echo $row['LearnerID']; ?>" class="form-label">From</label>
                                                                                        <input type="date" name="date_from" id="date_from-<?php echo $row['LearnerID']; ?>" class="form-control" required onchange="adjustToDate('<?php echo $row['LearnerID']; ?>')">
                                                                                    </div>
                                                                                    <div class="flex-fill">
                                                                                        <label for="date_to-<?php echo $row['LearnerID']; ?>" class="form-label">To</label>
                                                                                        <input type="date" name="date_to" id="date_to-<?php echo $row['LearnerID']; ?>" class="form-control" required>
                                                                                    </div>
                                                                                </div>
                                                                            </div>

                                                                            <button type="submit" class="btn btn-primary">Upload</button>
                                                                        </form>
                                                                    </div>
                                                                    <div class="modal-footer">
                                                                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        </div>

                                                    <?php endwhile; ?>
                                                </tbody>
                                            </table>
                                        </div>
                                    <?php else: ?>
                                        <p>No results found.</p>
                                    <?php endif; ?>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <?php include('sdp_footer.php'); ?>
    
    <!-- Signature Pad Library -->
    <script src="https://cdn.jsdelivr.net/npm/signature_pad@2.3.2/dist/signature_pad.min.js"></script>

    <!-- Bootstrap JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
      
    <!-- Geofencing and Signature Pad Scripts -->
    <script>
        // ==================== GEOFENCING CONFIGURATION ====================
        const GEOFENCE_RADIUS = 300; // meters
        const GPS_ACCURACY_THRESHOLD = 50; // meters

        // Site coordinates from PHP
        let siteLatitude = <?php echo isset($siteCoords['latitude']) ? $siteCoords['latitude'] : 'null'; ?>;
        let siteLongitude = <?php echo isset($siteCoords['longitude']) ? $siteCoords['longitude'] : 'null'; ?>;

        console.log('[GEOFENCE] Site coordinates:', siteLatitude, siteLongitude);

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

        // ==================== SIGNATURE PAD INITIALIZATION ====================
        const signaturePads = {};
        const clockOutSignaturePads = {};

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

        // Function to clear the clock-in signature pad
        function clearSignature(learnerID) {
            const canvas = document.getElementById('signature-pad-' + learnerID);
            const signaturePad = signaturePads[learnerID];
            if (signaturePad) {
                signaturePad.clear();
                console.log("Signature cleared for Clock-In LearnerID:", learnerID);
            }
        }

        // Function to clear the clock-out signature pad
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

        // ==================== SICK NOTE FORM HANDLERS ====================
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

            // Calculate 5 working days ago (excluding weekends)
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

            // Initialize Bootstrap tooltips
            const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
            tooltipTriggerList.map(function (tooltipTriggerEl) {
                return new bootstrap.Tooltip(tooltipTriggerEl);
            });
        });
    </script>