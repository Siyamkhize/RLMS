<?php
include('connection.php');
error_reporting(E_ALL);
ini_set('display_errors', 1);
require_once __DIR__ . '/./vendor/autoload.php';




// Check if PDF export is requested - start output buffering
$isPdfExport = isset($_GET['export_pdf']) && $_GET['export_pdf'] == '1';
if ($isPdfExport) {
    ob_start();
}

// Define constants
define('WEB_BASE_URL', '/');
define('DEFAULT_AVATAR', 'assets/img/avatar6.png');



// Function to detect and validate signature from multiple sources
function detectValidSignature($conn, $learnerID) {
    $validSignature = null;
    $hasDatabaseSignature = false;
   
    error_log("=== SIGNATURE DETECTION DEBUG START ===");
    error_log("Looking for signatures for learner ID: $learnerID");
   
    // First, let's check what signatures exist in the database for this learner
    $debugQuery = "
        SELECT
            'learnerdetails' as table_name,
            signature,
            LearnerID
        FROM learnerdetails
        WHERE LearnerID = ?
        UNION ALL
        SELECT
            'learner_clocking' as table_name,
            signature,
            LearnerID
        FROM learner_clocking
        WHERE LearnerID = ?
        UNION ALL
        SELECT
            'induction_clocking' as table_name,
            signature,
            LearnerID
        FROM induction_clocking
        WHERE LearnerID = ?
    ";
   
    $debugStmt = $conn->prepare($debugQuery);
    if ($debugStmt) {
        $debugStmt->bind_param('iii', $learnerID, $learnerID, $learnerID);
        $debugStmt->execute();
        $debugResult = $debugStmt->get_result();
       
        error_log("Database signature check results:");
        while ($debugRow = $debugResult->fetch_assoc()) {
            error_log("- Table: " . $debugRow['table_name'] . ", Signature: " . ($debugRow['signature'] ?? 'NULL') . ", LearnerID: " . $debugRow['LearnerID']);
        }
        $debugStmt->close();
    }
   
    // Comprehensive query to get ALL signatures from ALL tables for this learner
    $comprehensiveQuery = "
        SELECT
            'learnerdetails' as source_table,
            signature,
            LearnerID
        FROM learnerdetails
        WHERE LearnerID = ? AND signature IS NOT NULL AND signature != '' AND signature != 'N/A'
        UNION ALL
        SELECT
            'learner_clocking' as source_table,
            signature,
            LearnerID
        FROM learner_clocking
        WHERE LearnerID = ? AND signature IS NOT NULL AND signature != '' AND signature != 'N/A'
        UNION ALL
        SELECT
            'induction_clocking' as source_table,
            signature,
            LearnerID
        FROM induction_clocking
        WHERE LearnerID = ? AND signature IS NOT NULL AND signature != '' AND signature != 'N/A'
        ORDER BY source_table, LearnerID
        LIMIT 10
    ";
   
    $stmt = $conn->prepare($comprehensiveQuery);
    if ($stmt) {
        $stmt->bind_param('iii', $learnerID, $learnerID, $learnerID);
        $stmt->execute();
        $result = $stmt->get_result();
       
        error_log("Comprehensive signature query found " . $result->num_rows . " records");
       
        // Process all found signatures
        while ($row = $result->fetch_assoc()) {
            $signature = $row['signature'];
            $sourceTable = $row['source_table'];
            $hasDatabaseSignature = true; // Mark that we found a database record
           
            error_log("Processing signature from $sourceTable: $signature");
           
            // Check possible file paths for this signature
            $possiblePaths = [
                $signature, // Direct path as stored in database
                "signatures/" . basename($signature),
                "mobile/signatures/" . basename($signature),
                "mobile/learnerImages/" . basename($signature),
                "mobile/signatures/learner{$learnerID}_" . basename($signature),
                "mobile/signatures/learner{$learnerID}_signature_" . basename($signature),
                "signatures/learner{$learnerID}_" . basename($signature),
                "signatures/learner{$learnerID}_signature_" . basename($signature),
                // Also try with just the filename
                basename($signature),
                "mobile/" . basename($signature),
                "signatures/" . basename($signature),
                // Check uploads directory
                "uploads/" . basename($signature),
                "uploads/" . $signature,
                // Check mobile/uploads and mobile/Uploads directories
                "mobile/uploads/" . basename($signature),
                "mobile/uploads/" . $signature,
                "mobile/Uploads/" . basename($signature),
                "mobile/Uploads/" . $signature
            ];
           
            error_log("Checking possible paths for signature from $sourceTable:");
            foreach ($possiblePaths as $path) {
                error_log("- Checking: $path");
                if (file_exists($path)) {
                    error_log("✓ FOUND SIGNATURE: $path (from $sourceTable)");
                    $validSignature = $path;
                    break 2; // Break out of both loops - use the first valid signature found
                }
            }
        }
        $stmt->close();
    }
   
    // If no signature found in database, check for signature files directly
    if (!$validSignature) {
        error_log("No signature found in database, checking for signature files directly");
       
        // Check for signature files in mobile/signatures directory
        $signaturePatterns = [
            "mobile/signatures/learner{$learnerID}_*.png",
            "mobile/signatures/learner{$learnerID}_signature_*.png",
            "mobile/signatures/*{$learnerID}*.png",
            "signatures/learner{$learnerID}_*.png",
            "signatures/learner{$learnerID}_signature_*.png",
            "signatures/*{$learnerID}*.png",
            // Also check for any files with the learner ID in the name
            "mobile/signatures/*{$learnerID}*",
            "signatures/*{$learnerID}*",
            // Check uploads directory
            "uploads/*{$learnerID}*",
            "uploads/*{$learnerID}*.png",
            // Check mobile/uploads and mobile/Uploads directories
            "mobile/uploads/*{$learnerID}*",
            "mobile/uploads/*{$learnerID}*.png",
            "mobile/Uploads/*{$learnerID}*",
            "mobile/Uploads/*{$learnerID}*.png"
        ];
       
        foreach ($signaturePatterns as $pattern) {
            $files = glob($pattern);
            if (!empty($files)) {
                error_log("Found signature files with pattern '$pattern': " . implode(', ', $files));
                $validSignature = $files[0]; // Use the first matching file
                break;
            }
        }
    }
   
    // If we have database records but no valid file, provide a fallback
    if ($hasDatabaseSignature && !$validSignature) {
        error_log("Database has signature records but files are missing - using fallback");
        // Use a default signature image or show a placeholder
        $validSignature = "assets/img/signiture.PNG"; // Use existing signature placeholder
    }
   
    error_log("Final signature result: " . ($validSignature ?? 'NO SIGNATURE FOUND'));
    error_log("Has database signature: " . ($hasDatabaseSignature ? 'YES' : 'NO'));
    error_log("=== SIGNATURE DETECTION DEBUG END ===");
   
    return $validSignature;
}

// Function to get South African public holidays
function getSouthAfricanHolidays($year) {
    $holidays = array();
    $fixedHolidays = [
        $year . '-01-01' => 'New Year\'s Day',
        $year . '-03-21' => 'Human Rights Day',
        $year . '-04-27' => 'Freedom Day',
        $year . '-05-01' => 'Workers\' Day',
        $year . '-06-16' => 'Youth Day',
        $year . '-08-09' => 'National Women\'s Day',
        $year . '-09-24' => 'Heritage Day',
        $year . '-12-16' => 'Day of Reconciliation',
        $year . '-12-25' => 'Christmas Day',
        $year . '-12-26' => 'Day of Goodwill'
    ];
   
    foreach ($fixedHolidays as $date => $name) {
        $dayOfWeek = date('w', strtotime($date));
        if ($dayOfWeek == 0) {
            $holidays[$date] = $name;
            $newDate = date('Y-m-d', strtotime($date . ' +1 day'));
            $holidays[$newDate] = $name . ' (Observed)';
        } else {
            $holidays[$date] = $name;
        }
    }
   
    $easter = date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days"));
    $goodFriday = date('Y-m-d', strtotime($easter . ' -2 days'));
    $familyDay = date('Y-m-d', strtotime($easter . ' +1 day'));
   
    $dayOfWeekGoodFriday = date('w', strtotime($goodFriday));
    if ($dayOfWeekGoodFriday == 0) {
        $holidays[$goodFriday] = 'Good Friday';
        $newGoodFriday = date('Y-m-d', strtotime($goodFriday . ' +1 day'));
        $holidays[$newGoodFriday] = 'Good Friday (Observed)';
    } else {
        $holidays[$goodFriday] = 'Good Friday';
    }
   
    $dayOfWeekFamilyDay = date('w', strtotime($familyDay));
    if ($dayOfWeekFamilyDay == 0) {
        $holidays[$familyDay] = 'Family Day';
        $newFamilyDay = date('Y-m-d', strtotime($familyDay . ' +1 day'));
        $holidays[$newFamilyDay] = 'Family Day (Observed)';
    } else {
        $holidays[$familyDay] = 'Family Day';
    }
   
    ksort($holidays);
    return array_keys($holidays);
}

// Get parameters
$learnerID = $_GET['learner_id'] ?? $_GET['LearnerID'] ?? '';
$project_id = $_GET['project_id'] ?? '';
$year = intval($_GET['year'] ?? date('Y'));
$month = intval($_GET['month'] ?? date('m')); // Convert to integer to match MySQL MONTH() function


$FullName = $_GET['FullName'] ?? 'Default Name';

// Validate required parameters
if (empty($learnerID)) {
    $error = "Error: Learner ID is required. Please provide 'learner_id' or 'LearnerID' parameter.";
    error_log($error . " Parameters: " . print_r($_GET, true));
    die($error);
}

if (empty($project_id)) {
    $error = "Error: Project ID is required. Please provide 'project_id' parameter.";
    error_log($error . " Parameters: " . print_r($_GET, true));
    die($error);
}

// Log successful parameter parsing for debugging
error_log("indivisual.php called with valid parameters: LearnerID={$learnerID}, ProjectID={$project_id}, Year={$year}, Month={$month}, Export=" . ($_GET['export_pdf'] ?? 'NO'));

// Handle PDF export if requested
if (isset($_GET['export_pdf']) && $_GET['export_pdf'] == '1') {
    // Start output buffering to capture the HTML
    ob_start();
}

// Get holidays
$saHolidays = getSouthAfricanHolidays($year);
$holidaysInMonth = 0;
foreach ($saHolidays as $holiday) {
    if (substr($holiday, 5, 2) == $month) {
        $dayOfWeek = date('w', strtotime($holiday));
        if ($dayOfWeek != 0 && $dayOfWeek != 6) {
            $holidaysInMonth++;
        }
    }
}

// Get month boundaries
$firstDayOfMonth = date('Y-m-01', strtotime("$year-$month-01"));
$lastDayOfMonth = date('Y-m-t', strtotime("$year-$month-01"));

// Fetch sick notes
$sql = "SELECT date_from, date_to, status
        FROM sick_note
        WHERE learner_id = ?
        AND (
            (date_from BETWEEN ? AND ?) OR
            (date_to BETWEEN ? AND ?) OR
            (? BETWEEN date_from AND date_to)
        )";
$stmt = $conn->prepare($sql);
if (!$stmt) {
    die("Prepare failed for sick notes query: " . $conn->error . " | SQL: " . $sql);
}
$stmt->bind_param("isssss", $learnerID, $firstDayOfMonth, $lastDayOfMonth, $firstDayOfMonth, $lastDayOfMonth, $firstDayOfMonth);
$stmt->execute();
$result = $stmt->get_result();

$sickNotes = [];
$approvedSickDates = [];
$pendingSickDates = [];
$rejectedSickDates = [];
$approvedSickDays = 0;
$pendingSickDays = 0;
$rejectedAbsentDays = 0;
$sickDays = 0;

while ($row = $result->fetch_assoc()) {
    $status = trim($row['status'] ?? 'Pending');
    $dateFrom = $row['date_from'];
    $dateTo = $row['date_to'];

    if (empty($dateFrom) || empty($dateTo) || !strtotime($dateFrom) || !strtotime($dateTo)) {
        error_log("Invalid sick note dates for learner_id $learnerID: date_from=$dateFrom, date_to=$dateTo, status=$status");
        continue;
    }

    $sickNotes[] = [
        'from' => $dateFrom,
        'to' => $dateTo,
        'status' => $status
    ];

    try {
        $start = new DateTime($dateFrom);
        $end = new DateTime($dateTo);
        $interval = new DateInterval('P1D');
        $dateRange = new DatePeriod($start, $interval, $end->modify('+1 day'));
        foreach ($dateRange as $date) {
            $formattedDate = $date->format('Y-m-d');
            $dayOfWeek = date('w', strtotime($formattedDate));
            $isHoliday = in_array($formattedDate, $saHolidays);
            if (!$isHoliday && $dayOfWeek != 0 && $dayOfWeek != 6 && substr($formattedDate, 5, 2) == $month) {
                if (strcasecmp($status, 'Approved') === 0) {
                    $approvedSickDates[] = $formattedDate;
                    $approvedSickDays++;
                } elseif (strcasecmp($status, 'Pending') === 0) {
                    $pendingSickDates[] = $formattedDate;
                    $pendingSickDays++;
                } elseif (strcasecmp($status, 'Rejected') === 0 || strcasecmp($status, 'Declined') === 0) {
                    $rejectedSickDates[] = $formattedDate;
                    $rejectedAbsentDays++;
                }
            }
        }
    } catch (Exception $e) {
        error_log("Date processing error for sick note: learner_id=$learnerID, date_from=$dateFrom, date_to=$dateTo, status=$status, error=" . $e->getMessage());
    }
}

$approvedSickDates = array_unique($approvedSickDates);
$pendingSickDates = array_unique($pendingSickDates);
$rejectedSickDates = array_unique($rejectedSickDates);
$sickDays = $approvedSickDays + $pendingSickDays;

error_log("Sick Notes for LearnerID $learnerID: " . print_r($sickNotes, true));
error_log("Approved Sick Dates: " . print_r($approvedSickDates, true));

$stmt->close();

// Fetch learner and project details
$sql = "SELECT DISTINCT
    l.`Name`,
    l.`Surname`,
    l.`IDNumber`,
    l.`PhoneNumber`,
    l.`AddressLine1`,
    l.`Gender`,
    l.`profile_image`,
    sdp.sdp_logo,
    client.client_logo,
    p.Project_name,
    s.Project_pathway,
    p.Province
FROM learnerdetails l
JOIN class c ON l.classID = c.`classID`
JOIN sites s ON c.siteID = s.`siteID`
JOIN project p ON p.project_id = s.project_id
JOIN sdp ON p.sdp_name = sdp.sdp_name
JOIN client ON p.client_name = client.client_name
WHERE p.project_id = ?
AND l.`LearnerID` = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("ii", $project_id, $learnerID);
$stmt->execute();
$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
    $Name = $row['Name'] ?? '';
    $Surname = $row['Surname'] ?? '';
    $FullName = trim($Name . ' ' . $Surname);
    $IDNumber = $row['IDNumber'] ?? 'N/A';
    $PhoneNumber = $row['PhoneNumber'] ?? 'N/A';
    $Gender = $row['Gender'] ?? 'N/A';
    $Address = $row['AddressLine1'] ?? 'N/A';
    $projectName = $row['Project_name'] ?? 'N/A';
    $projectPathway = $row['Project_pathway'] ?? 'N/A';
    $Province = $row['Province'] ?? 'N/A';

    $profileImageDB = $row['profile_image'] ?? null;
    if ($profileImageDB && !empty($profileImageDB)) {
        $possiblePaths = [
            "mobile/" . $profileImageDB,
            "mobile/learnerImages/" . basename($profileImageDB)
        ];
        $profileImage = DEFAULT_AVATAR;
        foreach ($possiblePaths as $path) {
            if (file_exists($path)) {
                $profileImage = WEB_BASE_URL . $path;
                break;
            }
        }
    } else {
        $profileImage = DEFAULT_AVATAR;
    }

    $sdpLogoDB = $row['sdp_logo'] ?? null;
    $sdpLogo = $sdpLogoDB && file_exists($sdpLogoDB) ? str_replace(' ', '%20', $sdpLogoDB) : '';
    $clientLogoDB = $row['client_logo'] ?? null;
    $clientLogo = $clientLogoDB && file_exists($clientLogoDB) ? str_replace(' ', '%20', $clientLogoDB) : DEFAULT_AVATAR;
}
$stmt->close();

// Fetch clocking data for the specific month and year - ONE BEST RECORD PER DAY (including incomplete records)
$sql = "SELECT
    DATE(clock_date) as clock_date,
    clock_in_time,
    clock_out_time,
    contact_time,
    signature
FROM learner_clocking
WHERE LearnerID = ?
AND MONTH(clock_date) = ?
AND YEAR(clock_date) = ?
AND clock_in_time IS NOT NULL
ORDER BY clock_date,
         CASE WHEN clock_out_time IS NOT NULL AND contact_time IS NOT NULL THEN 1
              WHEN clock_out_time IS NOT NULL THEN 2
              ELSE 3 END,
         CASE WHEN contact_time IS NOT NULL THEN TIME_TO_SEC(contact_time) ELSE 0 END DESC";
$stmt = $conn->prepare($sql);
if (!$stmt) {
    die("Prepare failed for clocking query: " . $conn->error . " | SQL: " . $sql);
}
$stmt->bind_param('iii', $learnerID, $month, $year);

$stmt->execute();
$result = $stmt->get_result();

$clockingData = [];
$totalRecords = 0;
$rawRecordCount = 0;

while ($row = $result->fetch_assoc()) {
    $rawRecordCount++;
    $clockDate = $row['clock_date'] ?? 'NULL';
   
    // Only keep ONE complete record per day (the first one from our ordered query)
    if (!isset($clockingData[$clockDate])) {
        $clockingData[$clockDate] = [$row]; // Store as array with single record for consistency
        $totalRecords++;
    }
    // Skip additional records for the same date
}
$stmt->close();


?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/css/bootstrap.min.css">
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.5.1/jquery.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.16.0/umd/popper.min.js"></script>
    <script src="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/js/bootstrap.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/0.4.1/html2canvas.min.js"></script>
    <style>
        .bs-example { margin: 2px; }
        .holiday { color: red; font-weight: bold; }
        .weekend { color: blue; }
        .absent { color: red; }
        .pending { color: gray; }
        .present { color: green; }
        .sick { color: orange; }
        .invalid { color: red; font-weight: bold; }
        .calendar-day {
            height: 50px;
            overflow: auto;
            font-size: 9px;
            padding: 1px;
        }
        .calendar-day small {
            display: block;
            line-height: 1.0;
        }
        .badge {
            color: black !important;
            font-size: 9px;
        }
        .list-group-item {
            font-size: 11px;
            padding: 2px;
        }
        .list-group-item span {
            padding-right: 8px;
        }
        #report-content {
            padding: 2px;
        }
        .profile-container {
            display: flex;
            align-items: center;
            padding: 3px;
            margin: 0;
            gap: 6px;
            font-size: 40px;
        }
        .profile-container img {
            width: 50px;
            height: 40px;
            object-fit: cover;
            margin: 0;
            padding: 0;
        }
        .profile-container div {
            margin: 0;
            padding: 0;
            flex-grow: 1;
        }
        .profile-container h1 {
            font-size: 0.8rem;
            margin: 0;
            line-height: 1.1;
        }
        .calendar-container {
            margin-bottom: 10px;
        }
        .signature-container {
            margin-top: 10px;
        }
        .signature-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 1px;
        }
        .signature-row .form-group {
            flex: 1;
            text-align: left;
            margin: 0;
            padding: 1px;
        }
        .signature-row img {
            vertical-align: middle;
        }
        .navbar {
            min-height: 25px;
            padding: 1px;
        }
        .main-logo-container {
            text-align: center;
            margin-bottom: 5px;
        }
        .main-logo-container img {
            width: 100px;
            height: 25px;
        }
        .logo-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 5px;
        }
        .signature-img {
            width: 50px;
            height: 25px;
            object-fit: contain;
            margin-top: 1px;
        }
        .container-fluid:has(.profile-container) {
            /* min-height removed */
        }
        /* Hide navigation buttons on main page */
        .calendar-nav {
            display: none;
        }
        @media print {
            .btn-container { display: none; }
            .navbar { display: none; }
            .calendar-nav { display: none; }
            .btn { display: none; }
            @page {
                size: landscape;
                margin: 2mm;
            }
            #report-content {
                padding: 1px;
            }
            .bs-example, .container-fluid {
                margin: 1px;
                padding: 1px;
            }
            .container-fluid:has(.list-group) {
                padding: 2px !important;
            }
            .calendar-container {
                margin-bottom: 10px !important;
            }
            .signature-container {
                margin-top: 10px !important;
                clear: both !important;
            }
            .signature-row {
                display: flex;
                justify-content: space-between;
                align-items: center;
                padding: 1px;
            }
            .main-logo-container img {
                width: 100px !important;
                height: 25px !important;
            }
            .logo-row img {
                max-width: 300px !important;
                height: 50px !important;
            }

            .list-group-item span {
                padding-right: 6px !important;
            }
            img {
                max-width: 300px !important;
                height: 50px !important;
            }

            h1, h3 {
                font-size: 0.8rem !important;
            }
            .calendar-day img {
                width: 40px !important;
                height: 20px !important;
            }
            .signature-img {
                width: 40px !important;
                height: 20px !important;
            }
            .signature-row img {
                width: 20px !important;
                height: 10px !important;
            }
            .profile-container {
                gap: 4px;
                padding: 1px;
            }
            .profile-container img {
                width: 25px !important;
                height: 35px !important;
            }
            .profile-container h1 {
                font-size: 1.5rem !important;
            }
            .container-fluid:has(.profile-container) {
                max-height: 700px;
            }
        }
    </style>
</head>
<body>
<div id="report-content">
    <div class="container-fluid">
        <div class="bs-example">
           
        </div>

        <div class="main-logo-container">
            <!-- <img src="assets/img/rlms.PNG" alt="CoolBrand" onerror="this.src='<?php echo htmlspecialchars(DEFAULT_AVATAR); ?>'">
        --></div>

        <div class="container-fluid">
            <div class="row">
                <div class="col">
                    <img src="<?php echo htmlspecialchars($sdpLogo ?? ''); ?>" class="rounded float-start" alt="SDP Logo" style="max-width: 300px; height: 50px;" onerror="this.src='<?php echo htmlspecialchars(DEFAULT_AVATAR); ?>'">
                </div>
                <div class="col"></div>
                <div class="col">
                    <img src="assets/img/rlms.PNG"  class="rounded float-end" alt="Client Logo" style="max-width: 300px; height: 50px;" onerror="this.src='<?php echo htmlspecialchars(DEFAULT_AVATAR); ?>'">
                </div>
            </div>
        </div>

        <div style="background-image: linear-gradient(to right, #42bcf5, #42f5d7);" class="p-1 mb-1 text-black" style="font-size: 11px;">
            PERIOD: <?php echo $firstDayOfMonth; ?> to <?php echo $lastDayOfMonth; ?>
        </div>
       
       

        <div class="row">
            <div class="col">
                <div class="container-fluid">
                    <div class="calendar-container">
                        <div class="table-responsive-sm">
                            <?php
                            $daysInMonth = date('t', strtotime("$year-$month-01"));
                            $startDay = date('w', strtotime("$year-$month-01"));
                            $totalDays = $workingDays = $holidaysCount = $weekendDays = $presentDays = $absentDays = $invalidDays = 0;
                            $absentDays += $rejectedAbsentDays;

                            echo "<h4 style='font-size: 0.8rem;margin:1px;'>Calendar for " . date('F Y', strtotime("$year-$month-01")) . "</h4>";
                           
                            echo "<div class='mb-1'>";
                            echo "<span class='badge badge-primary'>Workdays: <span id='workingDays'>0</span></span> ";
                            echo "<span class='badge badge-danger'>Holidays: <span id='holidaysCount'>0</span></span> ";
                            echo "<span class='badge badge-info'>Weekend: <span id='weekendDays'>0</span></span> ";
                            echo "<span class='badge badge-success'>Present: <span id='presentDays'>0</span></span> ";
                            echo "<span class='badge badge-warning'>Absent: <span id='absentDays'>0</span></span> ";
                            echo "<span class='badge badge-danger'>Invalid: <span id='invalidDays'>0</span></span> ";
                            echo "<span class='badge badge-warning'>Sick: <span id='sickDays'>0</span></span>";
                            echo "</div>";

                            echo "<table class='table table-bordered'>";
                            echo "<thead><tr style='background-color:#282C65;color:black;font-size:9px;'>
                                    <th>Sun</th><th>Mon</th><th>Tue</th><th>Wed</th><th>Thu</th><th>Fri</th><th>Sat</th>
                                  </tr></thead><tbody><tr>";

                            for ($i = 0; $i < $startDay; $i++) {
                                echo "<td></td>";
                            }

                            for ($day = 1; $day <= $daysInMonth; $day++) {
                                $date = "$year-" . str_pad($month, 2, '0', STR_PAD_LEFT) . "-" . str_pad($day, 2, '0', STR_PAD_LEFT);

                                $dayOfWeek = date('w', strtotime($date));
                                $currentDate = date('Y-m-d');
                                $isHoliday = in_array($date, $saHolidays);
                                $isWeekend = ($dayOfWeek == 0 || $dayOfWeek == 6);
                                $isApprovedSick = in_array($date, $approvedSickDates);
                                $isPendingSick = in_array($date, $pendingSickDates);
                                $isRejectedSick = in_array($date, $rejectedSickDates);

                                $totalDays++;
                                if ($isHoliday) {
                                    $holidaysCount++;
                                } elseif ($isWeekend) {
                                    $weekendDays++;
                                } elseif ($isApprovedSick || $isPendingSick || $isRejectedSick) {
                                    // Sick or rejected days counted above
                                } else {
                                    $workingDays++;
                                }

                                echo "<td class='calendar-day'>";
                                echo "<strong>$day</strong><br>";

                                if ($isApprovedSick) {
                                    echo "<small class='sick'>Sick Note Approved</small>";
                                } elseif ($isPendingSick) {
                                    echo "<small class='sick'>Sick Note Pending</small>";
                                } elseif ($isRejectedSick) {
                                    echo "<small class='absent'>Absent</small>";
                                } elseif ($isHoliday) {
                                    $holidayName = '';
                                    switch ($date) {
                                        case date('Y-m-d', strtotime("$year-01-01")):
                                            $holidayName = 'New Year'; break;
                                        case date('Y-m-d', strtotime("$year-01-01 +1 day")):
                                            if (date('w', strtotime("$year-01-01")) == 0) $holidayName = 'New Year (Observed)'; break;
                                        case date('Y-m-d', strtotime("$year-03-21")):
                                            $holidayName = 'Human Rights Day'; break;
                                        case date('Y-m-d', strtotime("$year-03-21 +1 day")):
                                            if (date('w', strtotime("$year-03-21")) == 0) $holidayName = 'Human Rights (Observed)'; break;
                                        case date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days -2 days")):
                                            $holidayName = 'Good Friday'; break;
                                        case date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days -2 days +1 day")):
                                            if (date('w', strtotime("$year-03-21 +" . easter_days($year) . " days -2 days")) == 0) $holidayName = 'Good Friday (Observed)'; break;
                                        case date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days +1 day")):
                                            $holidayName = 'Family Day'; break;
                                        case date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days +1 day +1 day")):
                                            if (date('w', strtotime("$year-03-21 +" . easter_days($year) . " days +1 day")) == 0) $holidayName = 'Family Day (Observed)'; break;
                                        case date('Y-m-d', strtotime("$year-04-27")):
                                            $holidayName = 'Freedom Day'; break;
                                        case date('Y-m-d', strtotime("$year-04-27 +1 day")):
                                            if (date('w', strtotime("$year-04-27")) == 0) $holidayName = 'Freedom (Observed)'; break;
                                        case date('Y-m-d', strtotime("$year-05-01")):
                                            $holidayName = "Worker's Day"; break;
                                        case date('Y-m-d', strtotime("$year-05-01 +1 day")):
                                            if (date('w', strtotime("$year-05-01")) == 0) $holidayName = 'Workers (Observed)'; break;
                                        case date('Y-m-d', strtotime("$year-06-16")):
                                            $holidayName = 'Youth'; break;
                                        case date('Y-m-d', strtotime("$year-06-16 +1 day")):
                                            if (date('w', strtotime("$year-06-16")) == 0) $holidayName = 'Youth (Observed)'; break;
                                        case date('Y-m-d', strtotime("$year-08-09")):
                                            $holidayName = "Women's Day"; break;
                                        case date('Y-m-d', strtotime("$year-08-09 +1 day")):
                                            if (date('w', strtotime("$year-08-09")) == 0) $holidayName = 'Women\'s (Observed)'; break;
                                        case date('Y-m-d', strtotime("$year-09-24")):
                                            $holidayName = 'Heritage'; break;
                                        case date('Y-m-d', strtotime("$year-09-24 +1 day")):
                                            if (date('w', strtotime("$year-09-24")) == 0) $holidayName = 'Heritage (Observed)'; break;
                                        case date('Y-m-d', strtotime("$year-12-16")):
                                            $holidayName = 'Reconciliation'; break;
                                        case date('Y-m-d', strtotime("$year-12-16 +1 day")):
                                            if (date('w', strtotime("$year-12-16")) == 0) $holidayName = 'Reconciliation (Observed)'; break;
                                        case date('Y-m-d', strtotime("$year-12-25")):
                                            $holidayName = 'Christmas'; break;
                                        case date('Y-m-d', strtotime("$year-12-25 +1 day")):
                                            if (date('w', strtotime("$year-12-25")) == 0) $holidayName = 'Christmas (Observed)'; break;
                                        case date('Y-m-d', strtotime("$year-12-26")):
                                            $holidayName = 'Goodwill'; break;
                                        case date('Y-m-d', strtotime("$year-12-26 +1 day")):
                                            if (date('w', strtotime("$year-12-26")) == 0) $holidayName = 'Goodwill (Observed)'; break;
                                    }
                                    echo "<small class='holiday'>$holidayName</small>";
                                } elseif ($isWeekend) {
                                    echo "<small class='weekend'>Weekend</small>";
                                } else {

                                   
                                    if (isset($clockingData[$date])) {
                                        // Show the single complete clocking record for this date
                                        $record = $clockingData[$date][0]; // Get the single record
                                        $clockIn = $record['clock_in_time'] ?? 'N/A';
                                        $clockOut = $record['clock_out_time'] ?? 'N/A';
                                        $contactTime = $record['contact_time'] ?? 'N/A';

                                        // Determine if this is a complete or incomplete record
                                        $isCompleteRecord = ($clockIn !== 'N/A' && $clockOut !== 'N/A');
                                       
                                        if ($isCompleteRecord) {
                                            $presentDays++;
                                           
                                            // Format clock in time (handle both TIME and DATETIME formats)
                                            $formattedClockIn = 'N/A';
                                            if ($clockIn !== 'N/A') {
                                                if (preg_match('/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/', $clockIn)) {
                                                    // Structure 2: Full datetime format (2025-08-19 08:28:38)
                                                    $formattedClockIn = date('H:i', strtotime($clockIn));
                                                } elseif (preg_match('/^\d{2}:\d{2}:\d{2}$/', $clockIn)) {
                                                    // Structure 1: Time only format (08:19:51)
                                                    $formattedClockIn = substr($clockIn, 0, 5);
                                                } else {
                                                    // Fallback for any other format
                                                    $formattedClockIn = substr($clockIn, 0, 5);
                                                }
                                            }

                                            // Format clock out time (handle both TIME and DATETIME formats)
                                            $formattedClockOut = 'N/A';
                                            if ($clockOut !== 'N/A') {
                                                if (preg_match('/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/', $clockOut)) {
                                                    // Structure 2: Full datetime format
                                                    $formattedClockOut = date('H:i', strtotime($clockOut));
                                                } elseif (preg_match('/^\d{2}:\d{2}:\d{2}$/', $clockOut)) {
                                                    // Structure 1: Time only format (16:08:07)
                                                    $formattedClockOut = substr($clockOut, 0, 5);
                                                } else {
                                                    // Fallback for any other format
                                                    $formattedClockOut = substr($clockOut, 0, 5);
                                                }
                                            }

                                            // Format contact time (handle both structures)
                                            $formattedContactTime = 'N/A';
                                            $hasContactTime = ($contactTime !== 'N/A' && !empty($contactTime) && $contactTime !== null && $contactTime !== '');
                                           
                                            if ($hasContactTime) {
                                                $formattedContactTime = preg_replace('/\..+/', '', $contactTime);
                                                $formattedContactTime = str_replace(['0h ', '0m '], '', $formattedContactTime);
                                            }



                                            // Display based on available data - Clock times hidden, only signature shown
                                            // echo "<small class='present'>In: $formattedClockIn</small>";
                                            // echo "<small class='present'>Out: $formattedClockOut</small>";
                                           
                                            // Always show contact time line (handle both structures) - HIDDEN
                                            // if ($hasContactTime) {
                                            //     echo "<small class='present'>Contact: $formattedContactTime</small>";
                                            // } else {
                                            //     echo "<small class='present'>Contact: N/A</small>";
                                            // }

                                            // Show signature (use the signature detection function)
                                            $webSignaturePath = detectValidSignature($conn, $learnerID);
                                            if ($webSignaturePath) {
                                                $webSignaturePath = htmlspecialchars($webSignaturePath);
                                                echo "<img src='$webSignaturePath' class='signature-img rounded' alt='Signature' style='max-width: 90px; height: 35px;' onerror=\"this.style.display='none';this.nextSibling.style.display='block';\">";
                                                echo "<small style='display:none;'>Signature: [N/A]</small>";
                                            } else {
                                                echo "<small>Signature: [N/A]</small>";
                                            }
                                        } else {
                                            // Incomplete record - show what we have
                                            $invalidDays++;
                                           
                                            // Format clock in time even for incomplete records
                                            $formattedClockIn = 'N/A';
                                            if ($clockIn !== 'N/A') {
                                                if (preg_match('/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/', $clockIn)) {
                                                    $formattedClockIn = date('H:i', strtotime($clockIn));
                                                } elseif (preg_match('/^\d{2}:\d{2}:\d{2}$/', $clockIn)) {
                                                    $formattedClockIn = substr($clockIn, 0, 5);
                                                } else {
                                                    $formattedClockIn = substr($clockIn, 0, 5);
                                                }
                                            }
                                           
                                            // Format clock out time for incomplete records
                                            $formattedClockOut = 'N/A';
                                            if ($clockOut !== 'N/A') {
                                                if (preg_match('/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/', $clockOut)) {
                                                    $formattedClockOut = date('H:i', strtotime($clockOut));
                                                } elseif (preg_match('/^\d{2}:\d{2}:\d{2}$/', $clockOut)) {
                                                    $formattedClockOut = substr($clockOut, 0, 5);
                                                } else {
                                                    $formattedClockOut = substr($clockOut, 0, 5);
                                                }
                                            }
                                           
                                            // Format contact time
                                            $formattedContactTime = 'N/A';
                                            $hasContactTime = ($contactTime !== 'N/A' && !empty($contactTime) && $contactTime !== null && $contactTime !== '');
                                            if ($hasContactTime) {
                                                $formattedContactTime = preg_replace('/\..+/', '', $contactTime);
                                                $formattedContactTime = str_replace(['0h ', '0m '], '', $formattedContactTime);
                                            }
                                           

                                           
                                            // Display incomplete record with invalid styling - Clock times hidden, only signature shown
                                            echo "<small class='invalid'>⚠ Incomplete</small>";
                                            // echo "<small class='invalid'>In: $formattedClockIn</small>";
                                            // echo "<small class='invalid'>Out: $formattedClockOut</small>";
                                            // echo "<small class='invalid'>Contact: $formattedContactTime</small>"; // HIDDEN
                                           
                                            // Show signature for incomplete records too
                                            $webSignaturePath = detectValidSignature($conn, $learnerID);
                                            if ($webSignaturePath) {
                                                $webSignaturePath = htmlspecialchars($webSignaturePath);
                                                echo "<img src='$webSignaturePath' class='signature-img rounded' alt='Signature' style='max-width: 90px; height: 35px;' onerror=\"this.style.display='none';this.nextSibling.style.display='block';\">";
                                                echo "<small style='display:none;'>Signature: [N/A]</small>";
                                            } else {
                                                echo "<small>Signature: [N/A]</small>";
                                            }
                                        }
                                    } elseif ($date < $currentDate) {
                                        $absentDays++;
                                        echo "<small class='absent'>Absent</small>";
                                    } else {
                                        echo "<small class='pending'>Pending</small>";
                                    }
                                }

                                echo "</td>";

                                if (($day + $startDay) % 7 == 0 && $day != $daysInMonth) {
                                    echo "</tr><tr>";
                                }
                            }

                            while (($day + $startDay) % 7 != 0) {
                                echo "<td></td>";
                                $day++;
                            }

                            echo "</tr></tbody></table>";

                            echo "<script>
                                document.getElementById('workingDays').textContent = '$workingDays';
                                document.getElementById('holidaysCount').textContent = '$holidaysCount';
                                document.getElementById('weekendDays').textContent = '$weekendDays';
                                document.getElementById('presentDays').textContent = '$presentDays';
                                document.getElementById('absentDays').textContent = '$absentDays';
                                document.getElementById('invalidDays').textContent = '$invalidDays';
                                document.getElementById('sickDays').textContent = '$sickDays';
                            </script>";

                            $prevMonth = date('m', strtotime("-1 month", strtotime("$year-$month-01")));
                            $prevYear = date('Y', strtotime("-1 month", strtotime("$year-$month-01")));
                            $nextMonth = date('m', strtotime("+1 month", strtotime("$year-$month-01")));
                            $nextYear = date('Y', strtotime("+1 month", strtotime("$year-$month-01")));

                            $encodedFullName = urlencode($FullName);
                            $encodedClientLogo = urlencode($clientLogo);
                            $encodedSdpLogo = urlencode($sdpLogo);
                            $encodedProfileImage = urlencode($profileImage);

                            echo "<div class='calendar-nav mb-1'>";
                            echo "<a href='finance_generate_learner_report.php?learner_id=$learnerID&project_id=$project_id&year=$prevYear&month=$prevMonth&FullName=$encodedFullName&clientLogo=$encodedClientLogo&sdpLogo=$encodedSdpLogo&profileImage=$encodedProfileImage' class='btn btn-primary btn-sm mr-1'>←</a>";
                            echo "<a href='finance_generate_learner_report.php?learner_id=$learnerID&project_id=$project_id&year=$nextYear&month=$nextMonth&FullName=$encodedFullName&clientLogo=$encodedClientLogo&sdpLogo=$encodedSdpLogo&profileImage=$encodedProfileImage' class='btn btn-primary btn-sm'>→</a>";
                            echo "</div>";
                            ?>
                        </div>
                    </div>
                    <div class="signature-container">
                        <div class="form-row signature-row">
                            <div class="form-group">
                                <label style="color:#282C65;font-size:8px;">Facilitator Signature : <img src="assets/img/f.PNG" style="width:30px;height:15px;" alt="" onerror="this.src='<?php echo htmlspecialchars(DEFAULT_AVATAR); ?>'"></label>
                                <span style="font-size:8px;"><?php echo date('Y-m-d H:i:s'); ?></span>
                            </div>
                            <div class="form-group">
                                <label style="color:#282C65;font-size:8px;">SDP Representative Signature: <img src="assets/img/fa.png" style="width:30px;height:15px;" alt="" onerror="this.src='<?php echo htmlspecialchars(DEFAULT_AVATAR); ?>'"></label>
                                <span style="font-size:8px;"><?php echo date('Y-m-d H:i:s'); ?></span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
           
            <div class="col">
                <div class="container-fluid">
                    <div class="row">
                        <div class="col-12">
                            <div class="list-group-item profile-container bg-primary text-white">
                                <img src="<?php echo htmlspecialchars($profileImage); ?>"
                                     alt="Profile"
                                     class="img-thumbnail"
                                     onerror="this.src='<?php echo htmlspecialchars(DEFAULT_AVATAR); ?>'">
                                <div>
                                    <h1><?php echo strtoupper($FullName); ?></h1>
                                </div>
                            </div>
                        </div>

                        <div class="container-fluid">
                            <div style="background-color:#282C65;" class="p-1 mb-1 text-white">
                                <h3 style="font-size: 0.8rem;">PROJECT DETAILS</h3>
                            </div>
                            <ul class="list-group">
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Pathway:</strong>
                                    <span style="color:#282C65;"><?php echo $projectPathway; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Province:</strong>
                                    <span style="color:#282C65;"><?php echo $Province; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Project:</strong>
                                    <span style="color:#282C65;"><?php echo $projectName; ?></span>
                                </li>
                            </ul>
                        </div>
                       
                        <div class="container-fluid">
                            <div style="background-color:#282C65;" class="p-1 mb-1 text-white">
                                <h3 style="font-size: 0.8rem;">LEARNER</h3>
                            </div>
                            <ul class="list-group">
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Name:</strong>
                                    <span style="color:#282C65;"><?php echo $Name; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Surname:</strong>
                                    <span style="color:#282C65;"><?php echo $Surname; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">ID Number:</strong>
                                    <span style="color:#282C65;"><?php echo $IDNumber; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Gender:</strong>
                                    <span style="color:#282C65;"><?php echo $Gender; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Telephone:</strong>
                                    <span style="color:#282C65;"><?php echo $PhoneNumber; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Address:</strong>
                                    <span style="color:#282C65;"><?php echo $Address; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Expected Attendance:</strong>
                                    <span style="color:#282C65;"><?php echo $workingDays; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Actual Attendance:</strong>
                                    <span style="color:#282C65;"><?php echo $presentDays; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Days Absent:</strong>
                                    <span style="color:#282C65;"><?php echo $absentDays; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Invalid Attendance:</strong>
                                    <span style="color:#282C65;"><?php echo $invalidDays; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Holidays:</strong>
                                    <span style="color:#282C65;"><?php echo $holidaysInMonth; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Approved Sick Days:</strong>
                                    <span style="color:#282C65;"><?php echo $approvedSickDays; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Pending Sick Days:</strong>
                                    <span style="color:#282C65;"><?php echo $pendingSickDays; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Total Sick Days:</strong>
                                    <span style="color:#282C65;"><?php echo $sickDays; ?></span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Total Valid Attendance:</strong>
                                    <span style="color:#282C65;"><?php echo $presentDays+$holidaysInMonth+$approvedSickDays ?></span>
                                </li>
                            </ul>
                        </div>
                    </div>
                   
                    <footer class="page-footer font-small blue">
                        <div style="color:#282C65;font-size:8px;" class="text-right py-1">
                            <?php
                            $currentDateTime = date('Y-m-d');
                            echo "<b>RLMS Attendance. @</b> $currentDateTime";
                            ?>
                        </div>
                    </footer>
                </div>
            </div>
        </div>
       
        <div class="btn-container text-center mt-1">
            <button type="button" id="print-btn" class="btn btn-primary btn-sm" onclick="printReport()">Download Register</button>
           
            <button type="button" id="back-btn" class="btn btn-secondary btn-sm ml-2" onclick="window.history.back()">Back</button>

           
           
        </div>
    </div>
</div>

<?php
// Handle PDF export if requested
if (isset($_GET['export_pdf']) && $_GET['export_pdf'] == '1') {
    // Get the HTML content that was captured
    $htmlContent = ob_get_clean();
   
    try {
        // Create basic Mpdf instance to avoid FPDI dependency issues
        $mpdf = new \Mpdf\Mpdf([
            'mode' => 'utf-8',
            'format' => 'A4-L', // Landscape orientation
            'default_font_size' => 9, // Smaller font for faster processing
            'default_font' => 'arial', // Use basic font to avoid dependency issues
            'margin_left' => 5,
            'margin_right' => 5,
            'margin_top' => 5,
            'margin_bottom' => 5,
            'tempDir' => sys_get_temp_dir(),
            'fontDir' => [], // Avoid custom font directories
            'fontdata' => [], // Avoid custom font data
        ]);
       
        // Configure PDF settings for speed
        $mpdf->SetDisplayMode('fullpage');
        $mpdf->autoScriptToLang = false; // Disable for speed
        $mpdf->autoLangToFont = false; // Disable for speed
        $mpdf->ignore_invalid_utf8 = true; // Handle invalid UTF8 gracefully
       
        // Clean the HTML content for PDF generation
        $cleanHtml = str_replace(['<script>', '</script>'], ['<!--<script>', '</script>-->'], $htmlContent);
       
        // Add minimal CSS for faster PDF rendering
        $pdfCss = '
        <style>
            * { font-family: sans-serif; font-size: 8px; margin: 0; padding: 1px; }
            .btn-container, .calendar-nav, .btn, script { display: none !important; }
            table { width: 100%; border-collapse: collapse; font-size: 7px; }
            th, td { border: 1px solid #000; padding: 1px; }
            img { max-width: 20px; height: 15px; }
            @page { margin: 3mm; }
        </style>';
       
        $cleanHtml = $pdfCss . $cleanHtml;
       
        // Write HTML to PDF
        $mpdf->WriteHTML($cleanHtml);
       
        // Generate filename
        $filename = "Individual_Report_{$FullName}_{$year}-{$month}.pdf";
        $filename = preg_replace('/[^a-zA-Z0-9_\-\.]/', '_', $filename);
       
        // Output PDF
        $mpdf->Output($filename, \Mpdf\Output\Destination::DOWNLOAD);
       
        exit();
       
    } catch (Exception $e) {
        error_log("PDF generation error for learner {$learnerID}: " . $e->getMessage());
        error_log("Stack trace: " . $e->getTraceAsString());
       
        // Send detailed error response
        header('Content-Type: text/plain');
        http_response_code(500);
        echo "PDF generation failed for learner {$learnerID}: " . $e->getMessage();
        echo "\nParameters: LearnerID={$learnerID}, ProjectID={$project_id}, Year={$year}, Month={$month}";
        exit();
    }
} else {
    // Normal HTML view - output the captured content if any, or continue with normal flow
    if (ob_get_length()) {
        ob_end_flush();
    }
}
?>

<script>
    function printReport() {
        window.print();
    }
   
    function saveReport() {
        // Get the current URL parameters
        const urlParams = new URLSearchParams(window.location.search);
        const learner_id = urlParams.get('learner_id') || urlParams.get('LearnerID');
        const year = urlParams.get('year');
        const month = urlParams.get('month');
       
        // Build the save URL
        let saveUrl = 'finance_save_learner_report.php?';
        saveUrl += 'learner_id=' + encodeURIComponent(learner_id) + '&';
        saveUrl += 'year=' + encodeURIComponent(year) + '&';
        saveUrl += 'month=' + encodeURIComponent(month) + '&';
       
        // Add all other parameters
        const province = urlParams.get('province');
        const pathway = urlParams.get('pathway');
        const qualification_id = urlParams.get('qualification_id');
        const site_id = urlParams.get('site_id');
        const class_id = urlParams.get('class_id');
        const sdp_id = urlParams.get('sdp_id');
        const project_id = urlParams.get('project_id');
       
        if (province) saveUrl += 'province=' + encodeURIComponent(province) + '&';
        if (pathway) saveUrl += 'pathway=' + encodeURIComponent(pathway) + '&';
        if (qualification_id) saveUrl += 'qualification_id=' + encodeURIComponent(qualification_id) + '&';
        if (site_id) saveUrl += 'site_id=' + encodeURIComponent(site_id) + '&';
        if (class_id) saveUrl += 'class_id=' + encodeURIComponent(class_id) + '&';
        if (sdp_id) saveUrl += 'sdp_id=' + encodeURIComponent(sdp_id) + '&';
        if (project_id) saveUrl += 'project_id=' + encodeURIComponent(project_id) + '&';
       
        // Remove trailing '&' if exists
        if (saveUrl.endsWith('&')) {
            saveUrl = saveUrl.slice(0, -1);
        }
       
        // Open the save page in a new window
        window.open(saveUrl, '_blank');
    }
   
    function goBack() {
        // Get the current URL parameters
        const urlParams = new URLSearchParams(window.location.search);
        const learner_id = urlParams.get('learner_id') || urlParams.get('LearnerID');
        const project_id = urlParams.get('project_id');
        const year = urlParams.get('year');
        const month = urlParams.get('month');
       
        // Build the return URL to attendance_learners.php
        let returnUrl = 'finance_attendance_learners.php?';
       
        // Add all the parameters that were passed to this page
        if (learner_id) returnUrl += 'learner_id=' + encodeURIComponent(learner_id) + '&';
        if (project_id) returnUrl += 'project_id=' + encodeURIComponent(project_id) + '&';
        if (year) returnUrl += 'year=' + encodeURIComponent(year) + '&';
        if (month) returnUrl += 'month=' + encodeURIComponent(month) + '&';
       
        // Add the navigation parameters that should be preserved
        const province = urlParams.get('province');
        const pathway = urlParams.get('pathway');
        const qualification_id = urlParams.get('qualification_id');
        const site_id = urlParams.get('site_id');
        const class_id = urlParams.get('class_id');
        const sdp_id = urlParams.get('sdp_id');
       
        if (province) returnUrl += 'province=' + encodeURIComponent(province) + '&';
        if (pathway) returnUrl += 'pathway=' + encodeURIComponent(pathway) + '&';
        if (qualification_id) returnUrl += 'qualification_id=' + encodeURIComponent(qualification_id) + '&';
        if (site_id) returnUrl += 'site_id=' + encodeURIComponent(site_id) + '&';
        if (class_id) returnUrl += 'class_id=' + encodeURIComponent(class_id) + '&';
        if (sdp_id) returnUrl += 'sdp_id=' + encodeURIComponent(sdp_id) + '&';
       
        // Remove the trailing '&' if it exists
        if (returnUrl.endsWith('&')) {
            returnUrl = returnUrl.slice(0, -1);
        }
       
        // Navigate back to the attendance_learners.php page
        window.location.href = returnUrl;
    }
   
    // Auto-redirect after print (optional)
    window.addEventListener('afterprint', function() {
        // Uncomment the line below if you want to auto-redirect after printing
        // goBack();
    });
</script>
</body>
</html>

<?php
// PDF Export functionality - capture buffered content if PDF was requested
if ($isPdfExport) {
    // Get the HTML content that was captured in the buffer
    $htmlContent = ob_get_clean();
   
    try {
        // Create basic Mpdf instance to avoid FPDI dependency issues
        $mpdf = new \Mpdf\Mpdf([
            'mode' => 'utf-8',
            'format' => 'A4-L', // Landscape orientation
            'default_font_size' => 9,
            'default_font' => 'arial',
            'margin_left' => 5,
            'margin_right' => 5,
            'margin_top' => 5,
            'margin_bottom' => 5,
            'tempDir' => sys_get_temp_dir(),
            'fontDir' => [],
            'fontdata' => [],
        ]);
       
        // Clean the HTML content for PDF
        $cleanHtml = preg_replace('/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/mi', '', $htmlContent);
        $cleanHtml = str_replace(['<script>', '</script>'], ['<!--<script>', '</script>-->'], $cleanHtml);
       
        // Add CSS for better PDF rendering
        $pdfCss = '<style>
            .btn-container, .calendar-nav, .btn { display: none !important; }
            body { font-size: 8px; }
            table { font-size: 7px; }
            @page { margin: 5mm; }
        </style>';
       
        $mpdf->WriteHTML($pdfCss . $cleanHtml);
       
        // Output PDF directly
        $pdfContent = $mpdf->Output('', 'S');
       
        // Set proper headers and output PDF
        header('Content-Type: application/pdf');
        header('Content-Length: ' . strlen($pdfContent));
        echo $pdfContent;
        exit();
       
    } catch (Exception $e) {
        error_log("PDF generation failed in indivisual.php: " . $e->getMessage());
        http_response_code(500);
        echo "PDF generation failed: " . $e->getMessage();
        exit();
    }
}
?>