<?php
// Start output buffering
ob_start();
session_start();


// Check if user is logged in
if (!isset($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
    header("Location: login.php");
    exit();
}

// Enable error reporting for debugging
// Enable error reporting for debugging (only in development)
if (isset($_SERVER['REMOTE_ADDR']) && $_SERVER['REMOTE_ADDR'] === '127.0.0.1') {
    error_reporting(E_ALL);
    ini_set('display_errors', 0);
} else {
    error_reporting(E_ERROR | E_PARSE | E_CORE_ERROR | E_COMPILE_ERROR | E_USER_ERROR);
    ini_set('display_errors', 0);
}
ini_set('log_errors', 1);

// Include your DB connection
include 'connection.php';

// Include PhpSpreadsheet
require 'vendor/autoload.php';
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

// Handle temp_reports file serving (for progress.json and ZIP downloads)
if (isset($_GET['temp_file'])) {
    // Clear any output buffers
    while (ob_get_level()) {
        ob_end_clean();
    }
    
    $filename = basename($_GET['temp_file']);
    $filePath = __DIR__ . '/temp_reports/' . $filename;

    error_log("Temp file request: $filename, path: $filePath, exists: " . (file_exists($filePath) ? 'YES' : 'NO'));

    if (file_exists($filePath)) {
        $fileSize = filesize($filePath);
        error_log("File size: $fileSize bytes");
        
        // Set appropriate headers based on file type
        if (pathinfo($filename, PATHINFO_EXTENSION) === 'json') {
            header('Content-Type: application/json');
        } elseif (pathinfo($filename, PATHINFO_EXTENSION) === 'zip') {
            header('Content-Type: application/zip');
            header('Content-Disposition: attachment; filename="' . $filename . '"');
            header('Content-Length: ' . $fileSize);
        } else {
            header('Content-Type: application/octet-stream');
            header('Content-Length: ' . $fileSize);
        }

        header('Cache-Control: no-cache, no-store, must-revalidate');
        header('Pragma: no-cache');
        header('Expires: 0');

        // For large files, read in chunks
        if ($fileSize > 10 * 1024 * 1024) { // If larger than 10MB
            $handle = fopen($filePath, 'rb');
            while (!feof($handle)) {
                echo fread($handle, 8192);
                flush();
            }
            fclose($handle);
        } else {
            // For smaller files, use readfile
            readfile($filePath);
        }
        
        error_log("Served temp file: $filename ($fileSize bytes)");
        exit();
    } else {
        http_response_code(404);
        error_log("Temp file not found: $filename at $filePath");
        echo json_encode(['error' => 'File not found']);
        exit();
    }
}

// TEST: Database connection
if (!isset($conn) || $conn->connect_error) {
    error_log("Database connection failed: " . ($conn->connect_error ?? 'Connection not established'));
    die("Database Connection Failed: " . ($conn->connect_error ?? 'Unknown error'));
}
error_log("Database Test: Connection successful");

// Define constants
define('WEB_BASE_URL', '/');
define('DEFAULT_AVATAR', 'assets/img/avatar6.png');

// Function to get South African holidays
// Check if function already exists to prevent fatal errors
if (!function_exists('getSouthAfricanHolidays')) {
function getSouthAfricanHolidays($year) {
    $holidays = [];

    // New Year's Day
    $holidays[] = "$year-01-01";

    // Human Rights Day (March 21)
    $holidays[] = "$year-03-21";

    // Good Friday (calculate dynamically)
    $easter = easter_date($year);
    $goodFriday = date('Y-m-d', strtotime('-2 days', $easter));
    $holidays[] = $goodFriday;

    // Family Day (Easter Monday)
    $easterMonday = date('Y-m-d', strtotime('+1 day', $easter));
    $holidays[] = $easterMonday;

    // Freedom Day (April 27)
    $holidays[] = "$year-04-27";

    // Workers' Day (May 1)
    $holidays[] = "$year-05-01";

    // Youth Day (June 16)
    $holidays[] = "$year-06-16";

    // National Women's Day (August 9)
    $holidays[] = "$year-08-09";

    // Heritage Day (September 24)
    $holidays[] = "$year-09-24";

    // Day of Reconciliation (December 16)
    $holidays[] = "$year-12-16";

    // Christmas Day (December 25)
    $holidays[] = "$year-12-25";

    // Day of Goodwill (December 26)
    $holidays[] = "$year-12-26";

    return $holidays;
}
}

// Function to detect and validate signature from multiple sources
// Check if function already exists to prevent fatal errors
if (!function_exists('detectValidSignature')) {
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
}

// Function to generate calendar HTML
function generateCalendarHTML($attendanceByDate, $saHolidays, $year, $month, $approvedSickDates, $pendingSickDates, $rejectedSickDates) {
    $daysInMonth = cal_days_in_month(CAL_GREGORIAN, $month, $year);
    $firstDayOfWeek = date('w', strtotime("$year-$month-01"));
    
    $html = '<table class="table table-bordered table-sm" style="font-size: 8px;">
        <thead>
            <tr>
                <th>Sun</th>
                <th>Mon</th>
                <th>Tue</th>
                <th>Wed</th>
                <th>Thu</th>
                <th>Fri</th>
                <th>Sat</th>
            </tr>
        </thead>
        <tbody>';
    
    $day = 1;
    $currentDayOfWeek = 0;
    
    while ($day <= $daysInMonth) {
        if ($currentDayOfWeek == 0) {
            $html .= '<tr>';
        }
        
        if ($currentDayOfWeek < $firstDayOfWeek && $day == 1) {
            // Fill empty cells before the first day
            for ($i = 0; $i < $firstDayOfWeek; $i++) {
                $html .= '<td class="calendar-day"></td>';
                $currentDayOfWeek++;
            }
        }
        
        if ($day <= $daysInMonth) {
            $currentDate = sprintf('%04d-%02d-%02d', $year, $month, $day);
            $dayOfWeek = date('w', strtotime($currentDate));
            $isHoliday = in_array($currentDate, $saHolidays);
            $isWeekend = ($dayOfWeek == 0 || $dayOfWeek == 6);
            $isSickApproved = in_array($currentDate, $approvedSickDates);
            $isSickPending = in_array($currentDate, $pendingSickDates);
            $isSickRejected = in_array($currentDate, $rejectedSickDates);
            
            $class = 'calendar-day';
            $status = '';
            
            if ($isHoliday) {
                $class .= ' holiday';
                $status = 'Holiday';
            } elseif ($isWeekend) {
                $class .= ' weekend';
                $status = 'Weekend';
            } elseif ($isSickApproved) {
                $class .= ' sick-approved';
                $status = 'Sick (Approved)';
            } elseif ($isSickPending) {
                $class .= ' sick-pending';
                $status = 'Sick (Pending)';
            } elseif ($isSickRejected) {
                $class .= ' sick-rejected';
                $status = 'Sick (Rejected)';
            } elseif (isset($attendanceByDate[$currentDate])) {
                $attendance = $attendanceByDate[$currentDate];
                if ($attendance['status'] === 'present') {
                    $class .= ' present';
                    $status = 'Present';
                    if ($attendance['is_late']) {
                        $status .= ' (Late)';
                    }
                } else {
                    $class .= ' absent';
                    $status = 'Absent';
                }
            } else {
                $class .= ' absent';
                $status = 'Absent';
            }
            
            $html .= '<td class="' . $class . '">
                <small>' . $day . '</small>
                <small>' . $status . '</small>';
            
            if (isset($attendanceByDate[$currentDate]) && $attendanceByDate[$currentDate]['status'] === 'present') {
                $attendance = $attendanceByDate[$currentDate];
                if ($attendance['clock_in']) {
                    $html .= '<small>In: ' . substr($attendance['clock_in'], 0, 5) . '</small>';
                }
                if ($attendance['clock_out']) {
                    $html .= '<small>Out: ' . substr($attendance['clock_out'], 0, 5) . '</small>';
                }
            }
            
            $html .= '</td>';
        }
        
        $currentDayOfWeek++;
        if ($currentDayOfWeek == 7) {
            $html .= '</tr>';
            $currentDayOfWeek = 0;
        }
        
        $day++;
    }
    
    // Fill remaining cells in the last row
    while ($currentDayOfWeek < 7) {
        $html .= '<td class="calendar-day"></td>';
        $currentDayOfWeek++;
    }
    
    $html .= '</tbody></table>';
    return $html;
}



// Initialize error reporting for debugging (but suppress display)
error_reporting(E_ALL);
ini_set('display_errors', 0); // Errors will be logged, not displayed
ini_set('log_errors', 1);

// Check database connection
if ($conn->connect_error) {
    error_log("Connection failed: " . $conn->connect_error);
    die("Database connection error. Please contact the administrator.");
}

// Fetch all distinct districts for the dropdown filter
$districts = [];
$districtQuery = "SELECT DISTINCT District FROM sites ORDER BY District";
$districtResult = $conn->query($districtQuery);
if ($districtResult) {
    while ($d = $districtResult->fetch_assoc()) {
        $districts[] = $d['District'];
    }
} else {
    error_log("Error fetching districts: " . $conn->error);
    die("Error fetching districts. Please try again.");
}

// Fetch all distinct sites for the dropdown filter
$sites = [];
$siteQuery = "SELECT DISTINCT siteName FROM sites";
if (isset($_GET['district']) && !empty($_GET['district'])) {
    $siteQuery .= " WHERE District = '" . $conn->real_escape_string($_GET['district']) . "'";
}
$siteQuery .= " ORDER BY siteName";
$siteResult = $conn->query($siteQuery);
if ($siteResult) {
    while ($s = $siteResult->fetch_assoc()) {
        $sites[] = $s['siteName'];
    }
} else {
    error_log("Error fetching sites: " . $conn->error);
    die("Error fetching sites. Please try again.");
}

// Get selected filters
$selectedDistrict = isset($_GET['district']) ? $_GET['district'] : '';
$selectedSite = isset($_GET['site']) ? $_GET['site'] : '';
$idSearch = isset($_GET['id_search']) ? $_GET['id_search'] : '';
$startDate = isset($_GET['start_date']) ? $_GET['start_date'] : '';
$endDate = isset($_GET['end_date']) ? $_GET['end_date'] : '';
$attendanceFilters = isset($_GET['attendance_filter']) && is_array($_GET['attendance_filter']) ? $_GET['attendance_filter'] : [];

// Only load data if user has explicitly applied filters or clicked generate
$shouldLoadData = isset($_GET['generate']) || isset($_GET['search']) || !empty($selectedDistrict) || !empty($selectedSite) || !empty($idSearch) || !empty($attendanceFilters);

// Set default dates only if we should load data
if ($shouldLoadData) {
    if (empty($startDate)) {
        $startDate = date('Y-m-d', strtotime('-7 days'));
    }
    if (empty($endDate)) {
        $endDate = date('Y-m-d');
    }
}

// Modified: When 'all' is selected, exclude 'zero' unless explicitly selected
if (in_array('all', $attendanceFilters) && !in_array('zero', $attendanceFilters)) {
    $attendanceFilters = [
        'perfect', 'high', 'medium', 'low', 'very-low',
        'poor', 'very-poor', 'critical', 'minimal'
    ];
} elseif (in_array('all', $attendanceFilters) && in_array('zero', $attendanceFilters)) {
    $attendanceFilters = [
        'perfect', 'high', 'medium', 'low', 'very-low',
        'poor', 'very-poor', 'critical', 'minimal', 'zero'
    ];
}

// Validate date inputs only if we have dates
if ($shouldLoadData && !empty($startDate) && !empty($endDate)) {
    $startDateTime = new DateTime($startDate);
    $endDateTime = new DateTime($endDate);
    if ($startDateTime > $endDateTime) {
        $endDate = $startDate;
        $endDateTime = $startDateTime;
    }
}

// Initialize variables
$reportData = [];
$totalLearners = 0;
$totalAttendance = 0;
$totalPossible = 0;
$totalAmountDue = 0;
$dates = [];
$overallAttendancePercent = 0;

// Only load data if user has explicitly requested it
if ($shouldLoadData && !empty($startDate) && !empty($endDate)) {
    // Get all WEEKDAY dates in the range for column headers
    $currentDate = clone $startDateTime;
    while ($currentDate <= $endDateTime) {
        $dayOfWeek = $currentDate->format('N');
        if ($dayOfWeek < 6) {
            $dates[] = $currentDate->format('Y-m-d');
        }
        $currentDate->modify('+1 day');
    }

// Build the main query with activity_status filter
$sql = "
    SELECT
        s.District,
        s.project_id,
        ld.LearnerID,
        ld.Name,
        ld.Surname,
        ld.IDNumber,
        ld.PhoneNumber,
        ld.signature,
        ld.activity_statu,
        DATE(lc.clock_date) AS clock_date
    FROM sites s
    JOIN class c ON s.siteID = c.siteID
    JOIN learnerdetails ld ON c.classID = ld.classID
    LEFT JOIN (
        SELECT DISTINCT LearnerID, DATE(clock_date) as clock_date
        FROM learner_clocking 
        WHERE DATE(clock_date) BETWEEN '{$startDate}' AND '{$endDate}'
    ) lc ON ld.LearnerID = lc.LearnerID
    WHERE (ld.activity_statu = '' OR ld.activity_statu IS NULL)
";

$whereClauses = [];
if (!empty($selectedDistrict)) {
    $whereClauses[] = "s.District = '" . $conn->real_escape_string($selectedDistrict) . "'";
}
if (!empty($selectedSite)) {
    $whereClauses[] = "s.siteName = '" . $conn->real_escape_string($selectedSite) . "'";
}
if (isset($_GET['id_search']) && !empty($_GET['id_search'])) {
    $whereClauses[] = "ld.IDNumber = '" . $conn->real_escape_string($_GET['id_search']) . "'";
}
if (!empty($whereClauses)) {
    $sql .= " AND " . implode(" AND ", $whereClauses);
}

$sql .= " ORDER BY ld.Surname, ld.Name";

$result = $conn->query($sql);

if (!$result) {
    error_log("Error executing query: " . $conn->error);
    die("Error executing query. Please try again.");
}

// Organize data by learner
$reportData = [];
$totalLearners = 0;
$totalAttendance = 0;
$totalPossible = 0;
$totalAmountDue = 0; // Initialize total amount due

// Define rates
$dailyRate = 95.2391; // Daily rate calculated as 2000/21 ≈ 95.2391
$perfectAttendanceAmount = 2000.00; // Amount for 100% attendance

if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $learnerKey = $row['LearnerID'];
        
        if (!isset($reportData[$learnerKey])) {
            $reportData[$learnerKey] = [
                'name' => $row['Name'],
                'surname' => $row['Surname'],
                'id_number' => $row['IDNumber'],
                'phone_number' => $row['PhoneNumber'],
                'signature' => $row['signature'],
                'project_id' => $row['project_id'],
                'attendance' => []
            ];
        }
        
        if ($row['clock_date'] && !isset($reportData[$learnerKey]['attendance'][$row['clock_date']])) {
            $reportData[$learnerKey]['attendance'][$row['clock_date']] = true;
        }
    }
}

// Apply attendance filters and exclude learners with 0% attendance
$filteredReportData = [];
$filteredTotalLearners = 0;
$filteredTotalAttendance = 0;
$filteredTotalPossible = 0;
$filteredTotalAmountDue = 0; // Initialize filtered total amount due

foreach ($reportData as $learnerID => $learner) {
    $totalPresent = 0;
    foreach ($dates as $date) {
        if (isset($learner['attendance'][$date])) {
            $totalPresent++;
        }
    }
    
    // Skip learners with 0% attendance unless 'zero' filter is explicitly selected
    if ($totalPresent == 0 && !in_array('zero', $attendanceFilters)) {
        continue;
    }
    
    $attendancePercent = count($dates) > 0 ? round(($totalPresent / count($dates)) * 100, 1) : 0;
    $includeInFilter = empty($attendanceFilters);
    
    if (!empty($attendanceFilters)) {
        foreach ($attendanceFilters as $filter) {
            switch ($filter) {
                case 'perfect': if ($attendancePercent == 100) $includeInFilter = true; break;
                case 'high': if ($attendancePercent >= 90 && $attendancePercent < 100) $includeInFilter = true; break;
                case 'medium': if ($attendancePercent >= 70 && $attendancePercent < 90) $includeInFilter = true; break;
                case 'low': if ($attendancePercent >= 50 && $attendancePercent < 70) $includeInFilter = true; break;
                case 'very-low': if ($attendancePercent >= 40 && $attendancePercent < 50) $includeInFilter = true; break;
                case 'poor': if ($attendancePercent >= 30 && $attendancePercent < 40) $includeInFilter = true; break;
                case 'very-poor': if ($attendancePercent >= 20 && $attendancePercent < 30) $includeInFilter = true; break;
                case 'critical': if ($attendancePercent >= 10 && $attendancePercent < 20) $includeInFilter = true; break;
                case 'minimal': if ($attendancePercent > 0 && $attendancePercent < 10) $includeInFilter = true; break;
                case 'zero': if ($attendancePercent == 0) $includeInFilter = true; break;
            }
        }
    }
    
    if ($includeInFilter) {
        $filteredReportData[$learnerID] = $learner;
        $filteredTotalLearners++;
        $filteredTotalAttendance += $totalPresent;
        $filteredTotalPossible += count($dates);
        // Calculate amount due: R2000 for 100% attendance, otherwise daily rate
        $amountDue = ($attendancePercent == 100) ? $perfectAttendanceAmount : $totalPresent * $dailyRate;
        $filteredTotalAmountDue += $amountDue;
    }
}

$reportData = $filteredReportData;
$totalLearners = $filteredTotalLearners;
$totalAttendance = $filteredTotalAttendance;
$totalPossible = $filteredTotalPossible;
$totalAmountDue = $filteredTotalAmountDue;
} // End of $shouldLoadData condition

// Calculate overall attendance percent
$overallAttendancePercent = $totalPossible > 0 ? round(($totalAttendance / $totalPossible) * 100, 1) : 0;

// Handle Excel export
if (isset($_GET['export_excel']) && $_GET['export_excel'] == '1') {
// Create new Spreadsheet instance with full namespace
// Create new Spreadsheet instance with full namespace
// Create new Spreadsheet instance with full namespace
$spreadsheet = new \PhpOffice\PhpSpreadsheet\Spreadsheet();
    $sheet = $spreadsheet->getActiveSheet();
    $sheet->setTitle('Attendance Report');

    // Set headers
    $headers = [
        '#', 'Surname', 'Name', 'ID Number', 'Phone Number'
    ];
    foreach ($dates as $date) {
        $headers[] = date('M d D', strtotime($date));
    }
    $headers[] = 'Total Present';
    $headers[] = 'Attendance %';
    $headers[] = 'Daily Rate';
    $headers[] = 'Amount Due';

    // Write headers to Excel
    $sheet->fromArray($headers, NULL, 'A1');

    // Filter data for selected learners if specified
    $dataToExport = $reportData;
    if (isset($_GET['selected_learners']) && !empty($_GET['selected_learners'])) {
        $selectedLearnerIds = explode(',', $_GET['selected_learners']);
        $selectedLearnerIds = array_map('trim', $selectedLearnerIds);
        $dataToExport = array_filter($reportData, function($learner, $learnerID) use ($selectedLearnerIds) {
            return in_array($learnerID, $selectedLearnerIds);
        }, ARRAY_FILTER_USE_BOTH);
    }

    // Write data
    $rowNumber = 2; // Start from row 2 (after headers)
    foreach ($dataToExport as $learnerID => $learner) {
        $totalPresent = 0;
        foreach ($dates as $date) {
            if (isset($learner['attendance'][$date])) {
                $totalPresent++;
            }
        }
        $attendancePercent = count($dates) > 0 ? round(($totalPresent / count($dates)) * 100, 1) : 0;
        $amountDue = ($attendancePercent == 100) ? $perfectAttendanceAmount : $totalPresent * $dailyRate;

        $rowData = [
            $rowNumber - 1,
            $learner['surname'] ?? 'N/A',
            $learner['name'] ?? 'N/A',
            $learner['id_number'] ?? 'N/A',
            $learner['phone_number'] ?? 'N/A'
        ];
        foreach ($dates as $date) {
            $rowData[] = isset($learner['attendance'][$date]) ? 'Present' : 'Absent';
        }
        $rowData[] = $totalPresent . '/' . count($dates);
        $rowData[] = $attendancePercent . '%';
        $rowData[] = 'R ' . number_format($dailyRate, 2);
        $rowData[] = 'R ' . number_format($amountDue, 2);

        $sheet->fromArray($rowData, NULL, 'A' . $rowNumber);
        $rowNumber++;
    }

    // Calculate totals for exported data
    $exportedTotalAttendance = 0;
    $exportedTotalPossible = 0;
    $exportedTotalAmountDue = 0;
    
    foreach ($dataToExport as $learnerID => $learner) {
        $totalPresent = 0;
        foreach ($dates as $date) {
            if (isset($learner['attendance'][$date])) {
                $totalPresent++;
            }
        }
        $exportedTotalAttendance += $totalPresent;
        $exportedTotalPossible += count($dates);
        
        $attendancePercent = count($dates) > 0 ? round(($totalPresent / count($dates)) * 100, 1) : 0;
        $amountDue = ($attendancePercent == 100) ? $perfectAttendanceAmount : $totalPresent * $dailyRate;
        $exportedTotalAmountDue += $amountDue;
    }
    
    $exportedOverallAttendancePercent = $exportedTotalPossible > 0 ? round(($exportedTotalAttendance / $exportedTotalPossible) * 100, 1) : 0;
    
    // Add summary
    $summaryRow = $rowNumber + 1;
    $sheet->setCellValue('A' . $summaryRow, 'Summary');
    $sheet->setCellValue('B' . $summaryRow, 'Total Learners: ' . count($dataToExport) . (isset($_GET['selected_learners']) ? ' (Selected)' : ' (All)'));
    $sheet->setCellValue('C' . $summaryRow, 'Total Attendance: ' . $exportedTotalAttendance . '/' . $exportedTotalPossible);
    $sheet->setCellValue('D' . $summaryRow, 'Overall Attendance Rate: ' . $exportedOverallAttendancePercent . '%');
    $sheet->setCellValue('E' . $summaryRow, 'Total Amount Due: R ' . number_format($exportedTotalAmountDue, 2));

    // Auto-size columns
    foreach (range('A', $sheet->getHighestColumn()) as $col) {
        $sheet->getColumnDimension($col)->setAutoSize(true);
    }

    // Set headers for download
    $filename = 'Attendance_Report_' . date('Ymd_His');
    if (isset($_GET['selected_learners']) && !empty($_GET['selected_learners'])) {
        $filename .= '_Selected_' . count($dataToExport) . '_Learners';
    }
    $filename .= '.xlsx';
    
    header('Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    header('Content-Disposition: attachment;filename="' . $filename . '"');
    header('Cache-Control: max-age=0');

    $writer = new Xlsx($spreadsheet);
    $writer->save('php://output');
    exit();
}

// Diagnostic functions for troubleshooting
if (isset($_GET['test_db']) && $_GET['test_db'] == '1') {
    header('Content-Type: text/html; charset=utf-8');
    echo "<h1>🗄️ Database Test Results</h1>";

    // Test 1: Check database connection
    echo "<h3>Test 1: Database Connection</h3>";
    if ($conn->connect_error) {
        echo "❌ Database connection failed: " . $conn->connect_error;
        exit();
    } else {
        echo "✅ Database connection successful";
    }

    // Test 2: Check required tables
    echo "<h3>Test 2: Required Tables</h3>";
    $requiredTables = ['learner_clocking', 'learnerdetails'];
    foreach ($requiredTables as $table) {
        $result = $conn->query("SHOW TABLES LIKE '$table'");
        if ($result && $result->num_rows > 0) {
            echo "✅ Table '$table' exists<br>";
        } else {
            echo "❌ Table '$table' does not exist<br>";
        }
    }

    // Test 3: Sample data query
    echo "<h3>Test 3: Sample Data Query</h3>";
    $sampleQuery = "SELECT COUNT(*) as total FROM learner_clocking";
    $result = $conn->query($sampleQuery);
    if ($result) {
        $row = $result->fetch_assoc();
        echo "✅ Found " . $row['total'] . " records in learner_clocking table";
    } else {
        echo "❌ Query failed: " . $conn->error;
    }

    // Test 4: Check for sample learner data
    echo "<h3>Test 4: Sample Learner Data</h3>";
    $sampleLearnerQuery = "SELECT id, name, surname, id_number FROM learnerdetails LIMIT 5";
    $result = $conn->query($sampleLearnerQuery);
    if ($result && $result->num_rows > 0) {
        echo "✅ Found " . $result->num_rows . " learners in database:<br>";
        while ($row = $result->fetch_assoc()) {
            echo "- " . $row['surname'] . ", " . $row['name'] . " (ID: " . $row['id'] . ", ID Number: " . $row['id_number'] . ")<br>";
        }
    } else {
        echo "❌ No learner data found or query failed: " . $conn->error;
    }

    exit();
}

if (isset($_GET['test_html']) && $_GET['test_html'] == '1') {
    header('Content-Type: text/html; charset=utf-8');
    echo "<h1>📄 HTML Generation Test</h1>";

    // Get sample learner data using the same query structure as bulk download
    $sampleLearnerQuery = "
        SELECT DISTINCT
            s.District,
            s.project_id,
            ld.LearnerID,
            ld.Name,
            ld.Surname,
            ld.IDNumber,
            ld.PhoneNumber,
            ld.signature,
            ld.activity_statu,
            DATE(lc.clock_date) AS clock_date
        FROM sites s
        JOIN class c ON s.siteID = c.siteID
        JOIN learnerdetails ld ON c.classID = ld.classID
        LEFT JOIN (
            SELECT DISTINCT LearnerID, DATE(clock_date) as clock_date
            FROM learner_clocking
            WHERE DATE(clock_date) BETWEEN '" . date('Y-m-01') . "' AND '" . date('Y-m-t') . "'
        ) lc ON ld.LearnerID = lc.LearnerID
        WHERE (ld.activity_statu = '' OR ld.activity_statu IS NULL)
        LIMIT 1";

    $result = $conn->query($sampleLearnerQuery);

    if (!$result || $result->num_rows == 0) {
        echo "❌ No learner data found for testing";
        exit();
    }

    $row = $result->fetch_assoc();
    $learnerID = $row['LearnerID'];

    // Create the same data structure as bulk download
    $learner = [
        'name' => $row['Name'],
        'surname' => $row['Surname'],
        'id_number' => $row['IDNumber'],
        'phone_number' => $row['PhoneNumber'],
        'signature' => $row['signature'],
        'project_id' => $row['project_id'],
        'attendance' => []
    ];

    echo "<h3>Sample Learner Data:</h3>";
    echo "<pre>" . json_encode($learner, JSON_PRETTY_PRINT) . "</pre>";

    // Get attendance data for this learner
    $firstDayOfMonth = date('Y-m-01');
    $lastDayOfMonth = date('Y-m-t');
    $year = date('Y');
    $month = date('m');

    $attendanceQuery = "SELECT DATE(clocking_time) as date, TIME(clocking_time) as time, clocking_type, clocking_time FROM learner_clocking WHERE learner_id = ? AND DATE(clocking_time) BETWEEN ? AND ? ORDER BY clocking_time ASC";
    $stmt = $conn->prepare($attendanceQuery);
    if (!$stmt) {
        echo "❌ Failed to prepare attendance query: " . $conn->error;
        exit();
    }

    $stmt->bind_param("iss", $learnerID, $firstDayOfMonth, $lastDayOfMonth);
    $stmt->execute();
    $attendanceResult = $stmt->get_result();

    $attendanceRecords = [];
    while ($row = $attendanceResult->fetch_assoc()) {
        $attendanceRecords[] = $row;
    }
    $stmt->close();

    echo "<h3>Attendance Records Found: " . count($attendanceRecords) . "</h3>";
    if (!empty($attendanceRecords)) {
        echo "<pre>" . json_encode($attendanceRecords, JSON_PRETTY_PRINT) . "</pre>";
    }

    // Test HTML generation by directly including indivisual.php (same as View Report)
    echo "<h3>Testing HTML Generation:</h3>";
    try {
        // Store current GET parameters
        $originalGet = $_GET;

        // Set parameters that indivisual.php expects
        $_GET['LearnerID'] = $learnerID;
        $_GET['project_id'] = $learner['project_id'];
        $_GET['year'] = date('Y');
        $_GET['month'] = date('m');

        echo "🔧 Setting parameters:<br>";
        echo "- LearnerID: $learnerID<br>";
        echo "- project_id: " . ($learner['project_id'] ?? 'NULL') . "<br>";
        echo "- year: " . date('Y') . "<br>";
        echo "- month: " . date('m') . "<br><br>";

        // Check if parameters are valid
        if (empty($learnerID)) {
            echo "❌ ERROR: learnerID is empty<br>";
            exit();
        }
        if (empty($learner['project_id'])) {
            echo "❌ ERROR: project_id is empty in learner data<br>";
            echo "Full learner data: " . json_encode($learner) . "<br>";
            echo "Row data from query: " . json_encode($row) . "<br>";
            exit();
        }

        echo "✅ Parameters validated successfully<br>";
        echo "📄 Including indivisual.php...<br>";
        echo "Final GET parameters: " . json_encode($_GET) . "<br><br>";

        // Start output buffering to capture the HTML and any errors
        ob_start();

        // Capture any PHP errors/warnings that might occur
        $errorOutput = '';
        set_error_handler(function($errno, $errstr, $errfile, $errline) use (&$errorOutput) {
            $errorOutput .= "PHP Error [$errno]: $errstr in $errfile on line $errline\n";
        });

        // Include indivisual.php directly
        echo "🔄 Attempting to include indivisual.php...<br>";
        flush(); // Force output before including

        // Check if the file exists before including
        if (!file_exists('indivisual.php')) {
            echo "❌ indivisual.php file not found!<br>";
            exit();
        }

        echo "✅ indivisual.php file exists<br>";

        // Check database connection before including
        if (!$conn || $conn->connect_error) {
            echo "❌ Database connection failed before include: " . ($conn->connect_error ?? 'Unknown error') . "<br>";
        } else {
            echo "✅ Database connection OK before include<br>";
        }

        $includeResult = include('indivisual.php');

        echo "📋 Include result: " . ($includeResult ? "TRUE" : "FALSE") . "<br>";

        // Restore error handler
        restore_error_handler();

        // Get the captured output
        $htmlContent = ob_get_clean();

        if (!empty($errorOutput)) {
            echo "⚠️ PHP Errors/Warnings during include:<br>";
            echo "<pre style='background:#ffebee;padding:10px;border:1px solid #f44336;'>" . htmlspecialchars($errorOutput) . "</pre>";
        }

        echo "✅ indivisual.php included successfully<br>";
        echo "📏 HTML length: " . strlen($htmlContent) . " characters<br><br>";

        // Restore original GET parameters
        $_GET = $originalGet;

        if (empty($htmlContent)) {
            echo "❌ HTML content is empty<br>";
            echo "⚠️ Check if indivisual.php is outputting anything<br>";
        } else {
            echo "<details><summary>View Generated HTML (first 2000 chars)</summary>";
            echo "<pre style='max-height: 400px; overflow: auto;'>" . htmlspecialchars(substr($htmlContent, 0, 2000)) . "...</pre>";
            echo "</details><br>";

            // Also show if it contains expected elements
            if (strpos($htmlContent, '<html') !== false) {
                echo "✅ Contains HTML structure<br>";
            } else {
                echo "❌ Missing HTML structure<br>";
            }

            if (strpos($htmlContent, 'Attendance Report') !== false) {
                echo "✅ Contains attendance report content<br>";
            } else {
                echo "❌ Missing attendance report content<br>";
            }

            if (strpos($htmlContent, $learner['name'] ?? '') !== false || strpos($htmlContent, $learner['Name'] ?? '') !== false) {
                echo "✅ Contains learner name<br>";
            } else {
                echo "❌ Missing learner name<br>";
            }

            // Show the raw beginning of the content for debugging
            echo "<h4>Raw HTML Preview (first 500 chars):</h4>";
            echo "<textarea style='width:100%;height:150px;'>" . substr($htmlContent, 0, 500) . "</textarea>";
        }
    } catch (Exception $e) {
        echo "❌ HTML generation failed: " . $e->getMessage();
        echo "<br>Error details: " . $e->getTraceAsString();
    }

    exit();
}

if (isset($_GET['test_zip']) && $_GET['test_zip'] == '1') {
    header('Content-Type: text/html; charset=utf-8');
    echo "<h1>🔧 ZIP Functionality Test</h1>";

    // Test 1: Check ZIP extension
    echo "<h3>Test 1: ZIP Extension</h3>";
    if (!extension_loaded('zip')) {
        echo "❌ ZIP extension not loaded";
    } else {
        echo "✅ ZIP extension loaded";
    }

    // Test 2: Check ZipArchive class
    echo "<h3>Test 2: ZipArchive Class</h3>";
    if (!class_exists('ZipArchive')) {
        echo "❌ ZipArchive class not available";
    } else {
        echo "✅ ZipArchive class available";
    }

    // Test 3: Directory permissions
    echo "<h3>Test 3: Directory Permissions</h3>";
    $currentDir = __DIR__;
    echo "Current directory: $currentDir<br>";
    echo "Directory writable: " . (is_writable($currentDir) ? "✅ Yes" : "❌ No") . "<br>";

    // Test 4: Create test file
    echo "<h3>Test 4: File Creation Test</h3>";
    $testFile = $currentDir . "/test_file.txt";
    $testContent = "This is a test file created at " . date('Y-m-d H:i:s');

    if (file_put_contents($testFile, $testContent)) {
        echo "✅ Test file created successfully<br>";
        echo "File size: " . filesize($testFile) . " bytes<br>";

        // Test 5: ZIP creation
        echo "<h3>Test 5: ZIP Creation Test</h3>";
        $zipPath = $currentDir . "/test_zip.zip";
        $zip = new ZipArchive();

        if ($zip->open($zipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) === TRUE) {
            $zip->addFile($testFile, "test_file.txt");
            $zip->close();
            echo "✅ ZIP file created successfully<br>";
            echo "ZIP file size: " . filesize($zipPath) . " bytes<br>";

            // Cleanup
            unlink($testFile);
            unlink($zipPath);
            echo "🧹 Test files cleaned up<br>";
        } else {
            echo "❌ ZIP creation failed<br>";
        }
    } else {
        echo "❌ Could not create test file<br>";
    }

    exit();
}

// Simple bulk download - proxy to generate_bulk_reports.php and return JSON only
if (isset($_GET['export_pdf_bulk']) && $_GET['export_pdf_bulk'] == '1') {
    // Forward POST data to generate_bulk_reports.php
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, 'generate_bulk_reports.php');
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $_POST);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    header('Content-Type: application/json');
    http_response_code($httpCode);
    echo $response;
    exit();
}

// Handle PDF export
if (isset($_GET['export_pdf']) && $_GET['export_pdf'] == '1') {
    $mpdf = new \Mpdf\Mpdf(['mode' => 'utf-8', 'format' => 'A3-L']); // Landscape for wide table

    $stylesheet = '
        table { width: 100%; border-collapse: collapse; font-size: 10pt; }
        th, td { border: 1px solid #000; padding: 5px; text-align: center; }
        th { background: #f3f4f6; font-weight: bold; }
        .present { background: #34c759; color: #fff; }
        .absent { background: #f87171; color: #fff; }
        .percentage-excellent { background: #4ade80; color: #fff; }
        .percentage-good { background: #facc15; color: #2c3e50; }
        .percentage-poor { background: #f87171; color: #fff; }
        .stats-cell { background: #4e54a3; color: #fff; }
    ';

    $mpdf->WriteHTML('<style>' . $stylesheet . '</style>');

    $html = '<h1>Attendance Report</h1>';
    $html .= '<p>Period: ' . date('M d, Y', strtotime($startDate)) . ' to ' . date('M d, Y', strtotime($endDate)) . ' (Excluding Weekends)</p>';

    $html .= '<table>';
    $html .= '<thead>';
    $html .= '<tr>';
    $html .= '<th>#</th>';
    $html .= '<th>Surname</th>';
    $html .= '<th>Name</th>';
    $html .= '<th>ID Number</th>';
    $html .= '<th>Phone Number</th>';
    foreach ($dates as $date) {
        $html .= '<th>' . date('M d D', strtotime($date)) . '</th>';
    }
    $html .= '<th>Total Present</th>';
    $html .= '<th>Attendance %</th>';
    $html .= '<th>Daily Rate</th>';
    $html .= '<th>Amount Due</th>';
    $html .= '</tr>';
    $html .= '</thead>';
    $html .= '<tbody>';

    $rowNumber = 1;
    foreach ($reportData as $learnerID => $learner) {
        $totalPresent = 0;
        foreach ($dates as $date) {
            if (isset($learner['attendance'][$date])) {
                $totalPresent++;
            }
        }
        $attendancePercent = count($dates) > 0 ? round(($totalPresent / count($dates)) * 100, 1) : 0;
        $percentClass = $attendancePercent >= 90 ? 'percentage-excellent' : ($attendancePercent >= 70 ? 'percentage-good' : 'percentage-poor');
        $amountDue = ($attendancePercent == 100) ? $perfectAttendanceAmount : $totalPresent * $dailyRate;

        $html .= '<tr>';
        $html .= '<td>' . $rowNumber++ . '</td>';
        $html .= '<td>' . htmlspecialchars($learner['surname'] ?? 'N/A', ENT_QUOTES, 'UTF-8') . '</td>';
        $html .= '<td>' . htmlspecialchars($learner['name'] ?? 'N/A', ENT_QUOTES, 'UTF-8') . '</td>';
        $html .= '<td>' . htmlspecialchars($learner['id_number'] ?? 'N/A', ENT_QUOTES, 'UTF-8') . '</td>';
        $html .= '<td>' . htmlspecialchars($learner['phone_number'] ?? 'N/A', ENT_QUOTES, 'UTF-8') . '</td>';

        foreach ($dates as $date) {
            $class = isset($learner['attendance'][$date]) ? 'present' : 'absent';
            $content = isset($learner['attendance'][$date]) ? 'Present' : 'Absent';
            $html .= '<td class="' . $class . '">' . $content . '</td>';
        }

        $html .= '<td class="stats-cell">' . $totalPresent . '/' . count($dates) . '</td>';
        $html .= '<td class="stats-cell ' . $percentClass . '">' . $attendancePercent . '%</td>';
        $html .= '<td class="stats-cell">R ' . number_format($dailyRate, 2) . '</td>';
        $html .= '<td class="stats-cell">R ' . number_format($amountDue, 2) . '</td>';
        $html .= '</tr>';
    }

    $html .= '</tbody></table>';

    $html .= '<h2>Summary</h2>';
    $html .= '<p>Total Active Learners: ' . count($reportData) . '</p>';
    $html .= '<p>Total Attendance: ' . $totalAttendance . '/' . $totalPossible . '</p>';
    $html .= '<p>Overall Attendance Rate: ' . $overallAttendancePercent . '%</p>';
    $html .= '<p>Total Amount Due: R ' . number_format($totalAmountDue, 2) . '</p>';

    $mpdf->WriteHTML($html);
    $mpdf->Output('Attendance_Report_' . date('Ymd_His') . '.pdf', 'D');
    exit();
}

// Test ZIP functionality
if (isset($_GET['test_zip']) && $_GET['test_zip'] == '1') {
    error_log("=== ZIP FUNCTIONALITY TEST ===");

    // Test 1: Check if ZipArchive is available
    if (!class_exists('ZipArchive')) {
        die("❌ ZipArchive class not available");
    }
    echo "✅ ZipArchive class available<br>";

    // Test 2: Check directory permissions
    $testDir = __DIR__ . "/test_zip";
    if (!is_dir($testDir)) {
        mkdir($testDir, 0777, true);
    }

    if (!is_writable($testDir)) {
        die("❌ Test directory not writable: $testDir");
    }
    echo "✅ Directory writable: $testDir<br>";

    // Test 3: Create a test file
    $testFile = $testDir . "/test.txt";
    if (file_put_contents($testFile, "Test content") === false) {
        die("❌ Cannot create test file");
    }
    echo "✅ Test file created<br>";

    // Test 4: Create ZIP file
    $zipPath = __DIR__ . "/test_zip.zip";
    $zip = new ZipArchive();

    $result = $zip->open($zipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE);
    if ($result !== true) {
        die("❌ ZIP creation failed with code: $result");
    }
    echo "✅ ZIP file opened<br>";

    // Test 5: Add file to ZIP
    if (!$zip->addFile($testFile, "test.txt")) {
        $zip->close();
        die("❌ Cannot add file to ZIP");
    }
    echo "✅ File added to ZIP<br>";

    $zip->close();

    // Test 6: Verify ZIP file
    if (!file_exists($zipPath)) {
        die("❌ ZIP file not created");
    }

    $zipSize = filesize($zipPath);
    echo "✅ ZIP file created: $zipSize bytes<br>";

    // Cleanup
    unlink($testFile);
    rmdir($testDir);
    unlink($zipPath);

    echo "<h3>🎉 All ZIP tests passed!</h3>";
    exit();
}

// Test HTML generation
if (isset($_GET['test_html']) && $_GET['test_html'] == '1') {
    header('Content-Type: text/html; charset=utf-8');
    echo "<h1>📄 HTML Generation Test</h1>";

    // Get sample learner data using the same query structure as bulk download
    $sampleLearnerQuery = "
        SELECT DISTINCT
            s.District,
            s.project_id,
            ld.LearnerID,
            ld.Name,
            ld.Surname,
            ld.IDNumber,
            ld.PhoneNumber,
            ld.signature,
            ld.activity_statu,
            DATE(lc.clock_date) AS clock_date
        FROM sites s
        JOIN class c ON s.siteID = c.siteID
        JOIN learnerdetails ld ON c.classID = ld.classID
        LEFT JOIN (
            SELECT DISTINCT LearnerID, DATE(clock_date) as clock_date
            FROM learner_clocking
            WHERE DATE(clock_date) BETWEEN '" . date('Y-m-01') . "' AND '" . date('Y-m-t') . "'
        ) lc ON ld.LearnerID = lc.LearnerID
        WHERE (ld.activity_statu = '' OR ld.activity_statu IS NULL)
        LIMIT 1";

    $result = $conn->query($sampleLearnerQuery);

    if (!$result || $result->num_rows == 0) {
        echo "❌ No learner data found for testing";
        exit;
    }

    $row = $result->fetch_assoc();
    $learnerID = $row['LearnerID'];

    // Create the same data structure as bulk download
    $learner = [
        'name' => $row['Name'],
        'surname' => $row['Surname'],
        'id_number' => $row['IDNumber'],
        'phone_number' => $row['PhoneNumber'],
        'signature' => $row['signature'],
        'project_id' => $row['project_id'],
        'attendance' => []
    ];

    echo "<h3>Sample Learner Data:</h3>";
    echo "<pre>" . json_encode($learner, JSON_PRETTY_PRINT) . "</pre>";

    // Get attendance data for this learner
    $firstDayOfMonth = date('Y-m-01');
    $lastDayOfMonth = date('Y-m-t');
    $year = date('Y');
    $month = date('m');

    $attendanceQuery = "SELECT DATE(clocking_time) as date, TIME(clocking_time) as time, clocking_type, clocking_time FROM learner_clocking WHERE learner_id = ? AND DATE(clocking_time) BETWEEN ? AND ? ORDER BY clocking_time ASC";
    $stmt = $conn->prepare($attendanceQuery);
    if (!$stmt) {
        echo "❌ Failed to prepare attendance query: " . $conn->error;
        exit();
    }

    $stmt->bind_param("iss", $learnerID, $firstDayOfMonth, $lastDayOfMonth);
    $stmt->execute();
    $attendanceResult = $stmt->get_result();

    $attendanceRecords = [];
    while ($row = $attendanceResult->fetch_assoc()) {
        $attendanceRecords[] = $row;
    }
    $stmt->close();

    echo "<h3>Attendance Records Found: " . count($attendanceRecords) . "</h3>";
    if (!empty($attendanceRecords)) {
        echo "<pre>" . json_encode($attendanceRecords, JSON_PRETTY_PRINT) . "</pre>";
    }

    // Test HTML generation by directly including indivisual.php (same as View Report)
    echo "<h3>Testing HTML Generation:</h3>";
    try {
        // Store current GET parameters
        $originalGet = $_GET;

        // Set parameters that indivisual.php expects
        $_GET['LearnerID'] = $learnerID;
        $_GET['project_id'] = $learner['project_id'];
        $_GET['year'] = date('Y');
        $_GET['month'] = date('m');

        echo "🔧 Setting parameters:<br>";
        echo "- LearnerID: $learnerID<br>";
        echo "- project_id: " . ($learner['project_id'] ?? 'NULL') . "<br>";
        echo "- year: " . date('Y') . "<br>";
        echo "- month: " . date('m') . "<br><br>";

        // Check if parameters are valid
        if (empty($learnerID)) {
            echo "❌ ERROR: learnerID is empty<br>";
            exit();
        }
        if (empty($learner['project_id'])) {
            echo "❌ ERROR: project_id is empty in learner data<br>";
            echo "Full learner data: " . json_encode($learner) . "<br>";
            echo "Row data from query: " . json_encode($row) . "<br>";
            exit();
        }

        echo "✅ Parameters validated successfully<br>";
        echo "📄 Including indivisual.php...<br>";
        echo "Final GET parameters: " . json_encode($_GET) . "<br><br>";

        // Start output buffering to capture the HTML and any errors
        ob_start();

        // Capture any PHP errors/warnings that might occur
        $errorOutput = '';
        set_error_handler(function($errno, $errstr, $errfile, $errline) use (&$errorOutput) {
            $errorOutput .= "PHP Error [$errno]: $errstr in $errfile on line $errline\n";
        });

        // Include indivisual.php directly
        echo "🔄 Attempting to include indivisual.php...<br>";
        flush(); // Force output before including

        // Check if the file exists before including
        if (!file_exists('indivisual.php')) {
            echo "❌ indivisual.php file not found!<br>";
            exit();
        }

        echo "✅ indivisual.php file exists<br>";

        // Check database connection before including
        if (!$conn || $conn->connect_error) {
            echo "❌ Database connection failed before include: " . ($conn->connect_error ?? 'Unknown error') . "<br>";
        } else {
            echo "✅ Database connection OK before include<br>";
        }

        $includeResult = include('indivisual.php');

        echo "📋 Include result: " . ($includeResult ? "TRUE" : "FALSE") . "<br>";

        // Restore error handler
        restore_error_handler();

        // Get the captured output
        $htmlContent = ob_get_clean();

        if (!empty($errorOutput)) {
            echo "⚠️ PHP Errors/Warnings during include:<br>";
            echo "<pre style='background:#ffebee;padding:10px;border:1px solid #f44336;'>" . htmlspecialchars($errorOutput) . "</pre>";
        }

        echo "✅ indivisual.php included successfully<br>";
        echo "📏 HTML length: " . strlen($htmlContent) . " characters<br><br>";

        // Restore original GET parameters
        $_GET = $originalGet;

        if (empty($htmlContent)) {
            echo "❌ HTML content is empty<br>";
            echo "⚠️ Check if indivisual.php is outputting anything<br>";
        } else {
            echo "<details><summary>View Generated HTML (first 2000 chars)</summary>";
            echo "<pre style='max-height: 400px; overflow: auto;'>" . htmlspecialchars(substr($htmlContent, 0, 2000)) . "...</pre>";
            echo "</details><br>";

            // Also show if it contains expected elements
            if (strpos($htmlContent, '<html') !== false) {
                echo "✅ Contains HTML structure<br>";
            } else {
                echo "❌ Missing HTML structure<br>";
            }

            if (strpos($htmlContent, 'Attendance Report') !== false) {
                echo "✅ Contains attendance report content<br>";
            } else {
                echo "❌ Missing attendance report content<br>";
            }

            if (strpos($htmlContent, $learner['name'] ?? '') !== false || strpos($htmlContent, $learner['Name'] ?? '') !== false) {
                echo "✅ Contains learner name<br>";
            } else {
                echo "❌ Missing learner name<br>";
            }

            // Show the raw beginning of the content for debugging
            echo "<h4>Raw HTML Preview (first 500 chars):</h4>";
            echo "<textarea style='width:100%;height:150px;'>" . substr($htmlContent, 0, 500) . "</textarea>";
        }
    } catch (Exception $e) {
        echo "❌ HTML generation failed: " . $e->getMessage();
        echo "<br>Error details: " . $e->getTraceAsString();
    }

    exit();
}

// Test database queries
if (isset($_GET['test_db']) && $_GET['test_db'] == '1') {
    error_log("=== DATABASE QUERY TEST ===");

    echo "<h3>Database Query Test</h3>";

    // Test 1: Check learner_clocking table
    $clockingQuery = "SELECT COUNT(*) as total FROM learner_clocking";
    $result = $conn->query($clockingQuery);
    if ($result) {
        $row = $result->fetch_assoc();
        echo "✅ learner_clocking table: {$row['total']} records<br>";
    } else {
        echo "❌ learner_clocking table query failed: " . $conn->error . "<br>";
    }

    // Test 2: Check learnerdetails table
    $learnersQuery = "SELECT COUNT(*) as total FROM learnerdetails WHERE activity_statu = '' OR activity_statu IS NULL";
    $result = $conn->query($learnersQuery);
    if ($result) {
        $row = $result->fetch_assoc();
        echo "✅ Active learners: {$row['total']} records<br>";
    } else {
        echo "❌ learnerdetails table query failed: " . $conn->error . "<br>";
    }

    // Test 3: Check sample attendance query
    $year = date('Y');
    $month = date('m');
    $firstDayOfMonth = date('Y-m-01', strtotime("$year-$month-01"));
    $lastDayOfMonth = date('Y-m-t', strtotime("$year-$month-01"));

    $sampleAttendanceQuery = "SELECT lc.LearnerID, ld.Name, ld.Surname, COUNT(*) as attendance_count
                               FROM learner_clocking lc
                               JOIN learnerdetails ld ON lc.learner_id = ld.LearnerID
                               WHERE DATE(lc.clocking_time) BETWEEN ? AND ?
                               AND (ld.activity_statu = '' OR ld.activity_statu IS NULL)
                               GROUP BY lc.LearnerID, ld.Name, ld.Surname
                               LIMIT 5";

    $stmt = $conn->prepare($sampleAttendanceQuery);
    if ($stmt) {
        $stmt->bind_param("ss", $firstDayOfMonth, $lastDayOfMonth);
        $stmt->execute();
        $result = $stmt->get_result();

        echo "✅ Sample attendance query successful<br>";
        echo "<h4>Sample Results (last 5 learners with attendance):</h4>";
        echo "<table border='1' style='border-collapse: collapse;'><tr><th>Learner ID</th><th>Name</th><th>Surname</th><th>Attendance Count</th></tr>";

        while ($row = $result->fetch_assoc()) {
            echo "<tr><td>{$row['LearnerID']}</td><td>{$row['Name']}</td><td>{$row['Surname']}</td><td>{$row['attendance_count']}</td></tr>";
        }
        echo "</table>";

        $stmt->close();
    } else {
        echo "❌ Sample attendance query failed: " . $conn->error . "<br>";
    }

    // Test 4: Check current date range
    echo "<h4>Date Range Test:</h4>";
    echo "Current Year: $year<br>";
    echo "Current Month: $month<br>";
    echo "Date Range: $firstDayOfMonth to $lastDayOfMonth<br>";

    exit();
}

// REMOVED: Entire misplaced bulk download processing block
// The bulk download should only happen via AJAX when the user clicks the button
// All bulk download processing has been moved to generate_reports.php and should only trigger via AJAX
?>

<!DOCTYPE html>
<html>
<head>
    <title>Individual Learner Attendance Report</title>
    <style>
    * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body { 
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
    background: linear-gradient(135deg, #f5f7fa, #e4e9f0);
    min-height: 100vh;
    display: flex;
}

.sidebar {
    width: 280px;
    background: #ffffff;
    border-right: 1px solid #e0e4e8;
    padding: 2rem 0;
    display: flex;
    flex-direction: column;
    box-shadow: 5px 0 20px rgba(0, 0, 0, 0.1);
    position: fixed;
    height: 100vh;
    z-index: 1000;
    transition: transform 0.3s ease-in-out;
}

.sidebar-hidden {
    transform: translateX(-280px);
}

.logo-section {
    padding: 0 2rem 2rem;
    text-align: center;
    border-bottom: 1px solid #e0e4e8;
    margin-bottom: 2rem;
}

.logo {
    width: 120px;
    height: 120px;
    background: rgba(255, 255, 255, 0.9);
    border-radius: 15px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto 1rem;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
    cursor: pointer;
    transition: all 0.3s ease;
}

.logo:hover {
    transform: scale(1.05);
    box-shadow: 0 12px 35px rgba(0, 0, 0, 0.25);
}

.logo img {
    width: 100%;
    height: 100%;
    object-fit: contain;
    border-radius: 15px;
}

.nav-buttons {
    padding: 0 1rem;
    display: flex;
    flex-direction: column; 
    gap: 1rem;
}

.nav-btn {
    background: rgba(59, 130, 246, 0.1);
    border: 2px solid rgba(59, 130, 246, 0.3);
    color: #2c3e50;
    padding: 1rem 1.5rem;
    border-radius: 12px;
    cursor: pointer;
    transition: all 0.3s ease;
    font-size: 1rem;
    font-weight: 600;
    text-align: left;
    display: flex;
    align-items: center;
    gap: 0.75rem;
    text-decoration: none;
}

.nav-btn:hover {
    background: rgba(59, 130, 246, 0.2);
    border-color: rgba(59, 130, 246, 0.5);
    transform: translateY(-2px);
    box-shadow: 0 5px 15px rgba(0, 0, 0, 0.2);
}

.nav-btn.active {
    background: rgba(59, 130, 246, 0.25);
    border-color: rgba(59, 130, 246, 0.6);
    transform: translateY(-1px);
}

.nav-btn::before {
    content: '';
    width: 20px;
    height: 20px;
    background: #2c3e50;
    mask-size: contain;
    mask-repeat: no-repeat;
    mask-position: center;
}

.nav-btn.dashboard::before {
    mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='currentColor'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6' /%3E%3C/svg%3E");
}

.nav-btn.attendance::before {
    mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='currentColor'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4' /%3E%3C/svg%3E");
}

.nav-btn.logout::before {
    mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='currentColor'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M17 16l4-4m0 0l-4-4m4 4H7m5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h3a3 3 0 013 3v1' /%3E%3C/svg%3E");
}

.main-content {
    margin-left: 280px;
    width: calc(100% - 280px);
    min-height: 100vh;
    overflow-y: auto;
    transition: all 0.3s ease-in-out;
}

.main-content-expanded {
    margin-left: 0;
    width: 100%;
}

.floating-toggle-btn {
    display: none;
    position: fixed;
    top: 20px;
    left: 20px;
    background: linear-gradient(135deg, #3b82f6, #2563eb);
    color: white;
    border: none;
    border-radius: 50%;
    width: 50px;
    height: 50px;
    font-size: 24px;
    cursor: pointer;
    z-index: 1001;
    box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
    transition: all 0.3s ease;
}

.floating-toggle-btn:hover {
    background: linear-gradient(135deg, #2563eb, #1e40af);
    transform: scale(1.1);
}

.main-content-expanded .floating-toggle-btn {
    display: block;
}

.container {
    max-width: 1400px;
    margin: 0 auto;
    padding: 20px;
}

.header {
    background: #ffffff;
    backdrop-filter: blur(10px);
    border-radius: 15px;
    padding: 30px;
    margin-bottom: 30px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
    text-align: center;
    border: 1px solid #e5e7eb;
}

h1 { 
    color: #2c3e50;
    font-size: 2.5rem;
    font-weight: 700;
    margin-bottom: 10px;
    text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.subtitle {
    color: #6b7280;
    font-size: 1.1rem;
    font-weight: 300;
}

.filters { 
    background: #ffffff;
    backdrop-filter: blur(10px);
    margin-bottom: 30px; 
    padding: 25px; 
    border-radius: 15px;
    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
    border: 1px solid #e5e7eb;
}

.filters h3 {
    color: #2c3e50;
    margin-bottom: 20px;
    font-size: 1.3rem;
    font-weight: 600;
}

.filter-group { 
    display: inline-block; 
    margin-right: 25px; 
    margin-bottom: 15px;
    vertical-align: top;
}

.filter-label { 
    display: block;
    margin-bottom: 8px; 
    font-weight: 600;
    color: #2c3e50;
    font-size: 0.9rem;
}

select, input[type="date"], input[type="text"], input[type="number"], input[type="checkbox"] { 
    padding: 12px 15px;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    font-size: 14px;
    transition: all 0.3s ease;
    background: white;
    min-width: 150px;
}

input[type="checkbox"] {
    width: auto;
    vertical-align: middle;
    margin-right: 8px;
}

.multi-select-container {
    position: relative;
    min-width: 200px;
    max-width: 300px;
}

select[multiple] {
    width: 100%;
    height: 200px;
    padding: 10px;
    background: white;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    font-size: 14px;
}

select[multiple] option {
    padding: 8px 10px;
    border-bottom: 1px solid #f1f3f5;
    transition: background-color 0.2s;
}

select[multiple] option:hover {
    background-color: #f3f4f6;
}

select[multiple] option:checked {
    background: linear-gradient(135deg, #dbe9ff, #e8f0fe);
    color: #2c3e50;
}

select:focus, input[type="date"]:focus, input[type="text"]:focus, input[type="number"]:focus, input[type="checkbox"]:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

button, .view-report-btn { 
    padding: 12px 25px; 
    background: linear-gradient(135deg, #3b82f6, #2563eb);
    color: white; 
    border: none; 
    border-radius: 8px; 
    cursor: pointer;
    font-weight: 600;
    font-size: 14px;
    transition: all 0.3s ease;
    box-shadow: 0 4px 15px rgba(59, 130, 246, 0.3);
    margin: 0 5px;
    text-decoration: none;
    display: inline-block;
}

button:hover, .view-report-btn:hover { 
    background: linear-gradient(135deg, #2563eb, #1e40af);
    transform: translateY(-2px);
    box-shadow: 0 6px 20px rgba(59, 130, 246, 0.4);
}

.attendance-filter-section {
    background: rgba(59, 130, 246, 0.1);
    border: 2px dashed #3b82f6;
    border-radius: 10px;
    padding: 20px;
    margin-top: 20px;
}

.attendance-filter-section h4 {
    color: #2c3e50;
    margin-bottom: 15px;
    font-size: 1.1rem;
    display: flex;
    align-items: center;
    gap: 8px;
}

.attendance-filter-section h4::before {
    content: "📊";
}

.report-section {
    background: #ffffff;
    backdrop-filter: blur(10px);
    border-radius: 15px;
    margin-bottom: 30px;
    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
    overflow: hidden;
    border: 1px solid #e5e7eb;
}

.report-title {
    background: linear-gradient(135deg, #2c3e50, #34495e);
    color: white;
    padding: 20px 30px;
    font-size: 1.4rem;
    font-weight: 700;
    margin: 0;
    display: flex;
    align-items: center;
    gap: 15px;
}

.report-title::before {
    content: "📋";
    font-size: 1.2em;
}

.table-container {
    overflow-x: auto;
    padding: 0;
}

table { 
    width: 100%; 
    border-collapse: separate;
    border-spacing: 0;
    font-size: 14px;
    background: #ffffff;
    border-radius: 10px;
    overflow: hidden;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}

th, td { 
    border: 1px solid #e5e7eb;
    padding: 14px 10px;
    text-align: center;
    transition: background-color 0.3s ease;
}

th { 
    background: linear-gradient(135deg, #f3f4f6, #e5e7eb);
    font-weight: 600;
    position: sticky;
    top: 0;
    z-index: 10;
    color: #2c3e50;
    text-transform: uppercase;
    font-size: 12px;
    letter-spacing: 0.8px;
    border-top: none;
    border-bottom: 2px solid #d1d5db;
}

th:first-child, td:first-child {
    border-left: none;
}

th:last-child, td:last-child {
    border-right: none;
}

.learner-row {
    transition: all 0.3s ease;
}

.learner-row:nth-child(even) { 
    background: #f9fafb;
}

.learner-row:hover {
    background: #e8f0fe !important;
    box-shadow: inset 0 0 0 1px rgba(59, 130, 246, 0.2);
}

.learner-details { 
    text-align: left;
    white-space: nowrap;
    font-weight: 500;
    color: #2c3e50;
    padding-left: 12px;
}

.present { 
    background: linear-gradient(135deg, #34c759, #6ee7b7) !important;
    color: #ffffff;
    font-weight: 600;
    font-size: 15px;
    border-radius: 6px;
    padding: 4px 8px;
}

.absent { 
    background: linear-gradient(135deg, #f87171, #fca5a5) !important;
    color: #ffffff;
    font-weight: 600;
    font-size: 14px;
    border-radius: 6px;
    padding: 4px 8px;
}

.absent::before {
    content: "✗ ";
    display: inline-block;
    font-weight: bold;
}

.signature-img {
    max-width: 50px;
    max-height: 30px;
    vertical-align: middle;
    object-fit: contain;
    border-radius: 2px;
}

.date-header { 
    writing-mode: vertical-lr;
    text-orientation: mixed;
    min-width: 40px;
    font-size: 11px;
    font-weight: 600;
    color: #2c3e50;
    padding: 10px 4px;
}

.stats-cell {
    background: linear-gradient(135deg, #4e54a3, #ebb580) !important;
    color: #ffffff;
    font-weight: 600;
    font-size: 14px;
    border-radius: 4px;
}

.percentage-excellent { 
    background: linear-gradient(135deg, #4ade80, #86efac) !important;
    color: #ffffff;
    border-radius: 6px;
}

.percentage-good { 
    background: linear-gradient(135deg, #facc15, #fef08a) !important;
    color: #2c3e50;
    border-radius: 6px;
}

.percentage-poor { 
    background: linear-gradient(135deg, #f87171, #fca5a5) !important;
    color: #ffffff;
    border-radius: 6px;
}

.summary, .executive-summary { 
    margin: 20px 30px 30px 30px; 
    padding: 20px; 
    background: #f9fafb;
    border-radius: 10px;
    border-left: 5px solid #10b981;
    box-shadow: 0 4px 15px rgba(16, 185, 129, 0.1);
}

.summary-grid {
    display: flex;
    justify-content: space-between;
    gap: 10px;
    margin-top: 15px;
}

.summary-item {
    background: rgba(255, 255, 255, 0.7);
    padding: 15px;
    border-radius: 8px;
    text-align: center;
    border: 1px solid rgba(16, 185, 129, 0.2);
    flex: 1;
    display: flex;
    align-items: center;
    gap: 10px;
}

.summary-number {
    font-size: 1.5rem;
    font-weight: bold;
    color: #10b981;
    display: block;
}

.summary-label {
    color: #2c3e50;
    font-size: 1rem;
    font-weight: 500;
}

.no-data { 
    text-align: center; 
    padding: 60px 20px;
    color: #6b7280;
    background: #ffffff;
    backdrop-filter: blur(10px);
    border-radius: 15px;
    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
}

.no-data h3 {
    font-size: 1.5rem;
    margin-bottom: 15px;
    color: #2c3e50;
}

.legend {
    background: #ffffff;
    backdrop-filter: blur(10px);
    border-radius: 10px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
    border: 1px solid #e5e7eb;
}

.legend h4 {
    color: #2c3e50;
    margin-bottom: 15px;
    font-size: 1.1rem;
}

.legend-items {
    display: flex;
    gap: 20px;
    flex-wrap: wrap;
}

.legend-item {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 14px;
    color: #2c3e50;
}

.legend-color {
    width: 20px;
    height: 20px;
    border-radius: 4px;
    display: inline-block;
}

.error-message {
    background: linear-gradient(135deg, #f87171, #fca5a5);
    color: white;
    padding: 15px;
    border-radius: 8px;
    margin-bottom: 20px;
    text-align: center;
}

.debug-info {
    background: #fef3c7;
    border: 1px solid #fde68a;
    border-radius: 8px;
    padding: 15px;
    margin-bottom: 20px;
    font-family: monospace;
    font-size: 12px;
    color: #92400e;
}

@media (max-width: 768px) {
    body { flex-direction: column; }
    
    .sidebar {
        width: 100%;
        height: auto;
        position: relative;
        flex-direction: row;
        padding: 1rem;
        transform: translateX(0);
        background: #ffffff;
        border-right: 1px solid #e0e4e8;
    }
    
    .sidebar-hidden {
        transform: translateY(-100%);
    }
    
    .logo-section {
        padding: 0 1rem;
        border-bottom: none;
        border-right: 1px solid #e0e4e8;
        margin: 0 1rem 0 0;
    }
    
    .nav-buttons {
        flex-direction: row;
        flex: 1;
        padding: 0;
    }
    
    .main-content {
        margin-left: 0;
        width: 100%;
    }
    
    .container { padding: 10px; }
    h1 { font-size: 2rem; }
    .filter-group { display: block; margin-bottom: 15px; }
    .report-title { font-size: 1.1rem; padding: 15px 20px; }
    th, td { padding: 10px 6px; font-size: 12px; }
    .summary-grid { flex-direction: column; }
    .summary-item { text-align: left; }
    .signature-img { max-width: 40px; max-height: 25px; }
    .date-header { font-size: 10px; min-width: 30px; }
    .logo {
        width: 80px;
        height: 80px;
    }
    .floating-toggle-btn {
        top: 10px;
        left: 10px;
        width: 40px;
        height: 40px;
        font-size: 20px;
    }
    .view-report-btn {
        padding: 8px 15px;
        font-size: 12px;
    }
}

@keyframes slideIn {
    from {
        opacity: 0;
        transform: translateY(20px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}

.report-section, .executive-summary {
    animation: slideIn 0.6s ease-out;
}
@media print {
    body {
        background: #ffffff;
    }
    .sidebar, .filters, .nav-buttons, .nav-btn, .floating-toggle-btn {
        display: none;
    }
    .main-content {
        margin-left: 0;
        width: 100%;
    }
    .container {
        padding: 10px;
    }
    .header, .executive-summary, .legend, .report-section {
        box-shadow: none;
        border: 1px solid #e5e7eb;
        background: #ffffff;
    }
    .report-title {
        background: #2c3e50;
        color: white;
    }
    table {
        width: 100%;
        font-size: 12px;
    }
    th, td {
        padding: 8px;
        border: 1px solid #d1d5db;
    }
    .date-header {
        writing-mode: horizontal-tb;
        font-size: 10px;
    }
    .signature-img {
        max-width: 40px;
        max-height: 20px;
    }
    .summary {
        border-left: 3px solid #10b981;
        padding: 10px;
    }
    .view-report-btn {
        display: none;
    }
}
    </style>
</head>
<body>
    <div class="sidebar">
        <div class="logo-section">
            <div class="logo" onclick="toggleSidebar()">
                <img src="uploads/JCP.jpeg" alt="JCP Logo">
            </div>
        </div>
        
        <div class="nav-buttons">
            <a href="ecxecative_dashboard.php" class="nav-btn dashboard">Dashboard</a>
            <a href="attandence_tracking.php" class="nav-btn attendance active">Attendance Tracking</a>
            <a href="overall.php" class="nav-btn attendance active">Attendance</a>
            <button class="nav-btn logout" onclick="navigateToLogout()">Logout</button>
        </div>
    </div>

    <div class="main-content">
        <button class="floating-toggle-btn" onclick="toggleSidebar()" aria-label="Toggle Sidebar">→</button>
        <div class="container">
            <div class="header">
                <h1>📊 Individual Learner Attendance Report</h1>
                <p class="subtitle">Comprehensive attendance tracking and analytics</p>
            </div>

            <div class="filters">
                <h3>🔍 Filter Options</h3>
                <form method="GET" id="filterForm">
                    <div class="filter-group">
                        <label class="filter-label" for="district">District</label>
                        <select name="district" id="district" onchange="this.form.submit()">
                            <option value="">-- All Districts --</option>
                            <?php foreach ($districts as $district): ?>
                                <option value="<?= htmlspecialchars($district, ENT_QUOTES, 'UTF-8') ?>" <?= $district === $selectedDistrict ? 'selected' : '' ?>>
                                    <?= htmlspecialchars($district, ENT_QUOTES, 'UTF-8') ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    <div class="filter-group">
                        <label class="filter-label" for="site">Site</label>
                        <select name="site" id="site">
                            <option value="">-- All Sites --</option>
                            <?php foreach ($sites as $site): ?>
                                <option value="<?= htmlspecialchars($site, ENT_QUOTES, 'UTF-8') ?>" <?= $site === $selectedSite ? 'selected' : '' ?>>
                                    <?= htmlspecialchars($site, ENT_QUOTES, 'UTF-8') ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    <div class="filter-group">
                        <label class="filter-label" for="start_date">Start Date</label>
                        <input type="date" name="start_date" id="start_date" value="<?= htmlspecialchars($startDate, ENT_QUOTES, 'UTF-8') ?>">
                    </div>
                    <div class="filter-group">
                        <label class="filter-label" for="end_date">End Date</label>
                        <input type="date" name="end_date" id="end_date" value="<?= htmlspecialchars($endDate, ENT_QUOTES, 'UTF-8') ?>">
                    </div>
                    <div class="filter-group">
                        <label class="filter-label" for="id_search">Search by ID Number</label>
                        <input type="text" name="id_search" id="id_search" value="<?= isset($_GET['id_search']) ? htmlspecialchars($_GET['id_search'], ENT_QUOTES, 'UTF-8') : '' ?>" placeholder="Enter ID Number">
                    </div>
                    
                    <div class="attendance-filter-section">
                        <h4>Attendance Filters</h4>
                        <div class="filter-group">
                            <label class="filter-label" for="attendance_filter">Filter by Attendance Rate (Multiple Select)</label>
                            <div class="multi-select-container">
                                <select name="attendance_filter[]" id="attendance_filter" multiple>
                                    <option value="all" <?= in_array('all', $_GET['attendance_filter'] ?? []) ? 'selected' : '' ?>>All Attendance Rates (Excludes 0%)</option>
                                    <option value="perfect" <?= in_array('perfect', $attendanceFilters) ? 'selected' : '' ?>>Attendance (100%)</option>
                                    <option value="high" <?= in_array('high', $attendanceFilters) ? 'selected' : '' ?>>Attendance (90-99%)</option>
                                    <option value="medium" <?= in_array('medium', $attendanceFilters) ? 'selected' : '' ?>>Attendance (70-89%)</option>
                                    <option value="low" <?= in_array('low', $attendanceFilters) ? 'selected' : '' ?>>Attendance (50-69%)</option>
                                    <option value="very-low" <?= in_array('very-low', $attendanceFilters) ? 'selected' : '' ?>>Attendance (40-49%)</option>
                                    <option value="poor" <?= in_array('poor', $attendanceFilters) ? 'selected' : '' ?>>Attendance (30-39%)</option>
                                    <option value="very-poor" <?= in_array('very-poor', $attendanceFilters) ? 'selected' : '' ?>>Attendance (20-29%)</option>
                                    <option value="critical" <?= in_array('critical', $attendanceFilters) ? 'selected' : '' ?>>Attendance (10-19%)</option>
                                    <option value="minimal" <?= in_array('minimal', $attendanceFilters) ? 'selected' : '' ?>>Attendance (1-9%)</option>
                                    <option value="zero" <?= in_array('zero', $attendanceFilters) ? 'selected' : '' ?>>Attendance (0%)</option>
                                </select>
                            </div>
                        </div>
                    </div>
                    
                    <div class="filter-group">
                        <label class="filter-label">&nbsp;</label>
                        <button type="submit" name="generate">📈 Generate Report</button>
                        <!--<button type="submit" name="search" value="1">🔍 Search</button>-->
                        <!--<button type="submit" name="export_excel" value="1">📊 Export to Excel</button>-->
                        <button type="button" id="bulkDownloadBtn" onclick="startBulkDownloadNew()">📄 Bulk Reports (New Efficient API, Max 2000 Learners)</button>
                        <button type="button" id="bulkDownloadDocsBtn" onclick="startBulkDownloadDocuments()" style="background: linear-gradient(135deg, #10b981, #059669);">📎 Bulk Download Documents (Sick Notes & Manual Attendance)</button>
                        <!--<button type="submit" name="auto_bulk_pdfs" value="1">📥 Auto Download Individual PDFs</button>-->
                        
                        <!-- Selected Learners Export Options -->
                        <div style="margin-top: 10px; padding-top: 10px; border-top: 1px solid #ddd;">
                            <button type="button" id="exportSelectedBtn" onclick="exportSelectedLearners()" disabled>
                                📄 Export Selected Learners (<span id="selectedCount">0</span>)
                            </button>
                            <button type="button" id="exportSelectedExcelBtn" onclick="exportSelectedToExcel()" disabled>
                                📊 Export Selected to Excel (<span id="selectedCountExcel">0</span>)
                            </button>
                        </div>
                        <!--<a href="?test_zip=1" class="btn btn-info" style="margin-left: 10px;">🔧 Test ZIP Functionality</a>-->
                        <!--<a href="?test_html=1" class="btn btn-warning" style="margin-left: 10px;">📄 Test HTML Generation</a>-->
                        <!--<a href="?test_db=1" class="btn btn-success" style="margin-left: 10px;">🗄️ Test Database</a>-->
                        <!--<a href="?export_pdf_bulk=1&debug=1" class="btn btn-primary" style="margin-left: 10px;">🚀 Test Bulk Download</a>-->
                    </div>
                </form>
            </div>

            <?php if (!empty($reportData)): ?>
                <div class="executive-summary">
                    <strong>Executive Summary:</strong> 
                    Period: <?= date('M d, Y', strtotime($startDate)) ?> to <?= date('M d, Y', strtotime($endDate)) ?> (Excluding Weekends)
                    <?php if (!empty($attendanceFilters)): ?>
                        <br><em>Note: Results filtered by attendance criteria<?php if (!in_array('zero', $attendanceFilters)): ?>, excluding 0% attendance<?php endif; ?>. Only active learners included.</em>
                    <?php else: ?>
                        <br><em>Note: Excluding learners with 0% attendance and inactive learners.</em>
                    <?php endif; ?>
                    <div class="summary-grid">
                        <div class="summary-item">
                            <span class="summary-icon">👥</span>
                            <div>
                                <span class="summary-number" data-count="<?= number_format($totalLearners) ?>">0</span>
                                <span class="summary-label">Total Active Learners<?= (!empty($attendanceFilters)) ? ' (Filtered)' : '' ?></span>
                            </div>
                        </div>
                        <div class="summary-item">
                            <span class="summary-icon">📅</span>
                            <div>
                                <span class="summary-number" data-count="<?= number_format($totalAttendance) . '/' . number_format($totalPossible) ?>">0/0</span>
                                <span class="summary-label">Total Clock-ins</span>
                            </div>
                        </div>
                        <div class="summary-item">
                            <span class="summary-icon">📊</span>
                            <div>
                                <span class="summary-number" data-count="<?= $overallAttendancePercent ?>%">0%</span>
                                <span class="summary-label">Overall Attendance Rate</span>
                            </div>
                        </div>
                        <div class="summary-item">
                            <span class="summary-icon">💰</span>
                            <div>
                                <span class="summary-number" data-count="R <?= number_format($totalAmountDue, 2) ?>">R 0.00</span>
                                <span class="summary-label">Total Amount Due</span>
                            </div>
                        </div>
                    </div>
                </div>
            <?php endif; ?>

            <div class="legend">
                <h4>📋 Legend</h4>
                <div class="legend-items">
                    <div class="legend-item">
                        <span class="legend-color present"></span>
                        <span>Present (Signature)</span>
                    </div>
                    <div class="legend-item">
                        <span class="legend-color absent"></span>
                        <span>Absent (No clock record)</span>
                    </div>
                    <div class="legend-item">
                        <span class="legend-color" style="background: linear-gradient(135deg, #5eb380, #7cc294);"></span>
                        <span>Excellent (90%+)</span>
                    </div>
                    <div class="legend-item">
                        <span class="legend-color" style="background: linear-gradient(135deg, #e0a670, #ebb588);"></span>
                        <span>Good (70-89%)</span>
                    </div>
                    <div class="legend-item">
                        <span class="legend-color" style="background: linear-gradient(135deg, #c7706a, #d88a84);"></span>
                        <span>Needs Attention (<70%)</span>
                    </div>
                </div>
            </div>

            <?php if (!empty($reportData)): ?>
                <div class="report-section">
                    <h2 class="report-title">Learner Attendance</h2>
                    
                    <div class="table-container">
                        <table>
                            <thead>
                                <tr>
                                    <th rowspan="2" style="vertical-align: middle;">
                                        <input type="checkbox" id="selectAll" onchange="toggleAllLearners()" style="transform: scale(1.2);">
                                    </th>
                                    <th rowspan="2" style="vertical-align: middle;">#</th>
                                    <th rowspan="2" style="vertical-align: middle;">Surname</th>
                                    <th rowspan="2" style="vertical-align: middle;">Name</th>
                                    <th rowspan="2" style="vertical-align: middle;">ID Number</th>
                                    <th rowspan="2" style="vertical-align: middle;">Phone Number</th>
                                    <th colspan="<?= count($dates) ?>">Attendance Dates (Weekdays)</th>
                                    <th rowspan="2" style="vertical-align: middle;">Total Present</th>
                                    <th rowspan="2" style="vertical-align: middle;">Attendance %</th>
                                    <th rowspan="2" style="vertical-align: middle;">Daily Rate</th>
                                    <th rowspan="2" style="vertical-align: middle;">Amount Due</th>
                                    <th rowspan="2" style="vertical-align: middle;">Individual Attendance</th>
                                </tr>
                                <tr>
                                    <?php foreach ($dates as $date): ?>
                                        <th class="date-header"><?= date('M d', strtotime($date)) ?><br><?= date('D', strtotime($date)) ?></th>
                                    <?php endforeach; ?>
                                </tr>
                            </thead>
                            <tbody>
                                <?php $rowNumber = 1; ?>
                                <?php foreach ($reportData as $learnerID => $learner): ?>
                                    <?php 
                                    $totalPresent = 0;
                                    foreach ($dates as $date) {
                                        if (isset($learner['attendance'][$date])) {
                                            $totalPresent++;
                                        }
                                    }
                                    $attendancePercent = count($dates) > 0 ? round(($totalPresent / count($dates)) * 100, 1) : 0;
                                    $percentClass = $attendancePercent >= 90 ? 'percentage-excellent' : ($attendancePercent >= 70 ? 'percentage-good' : 'percentage-poor');
                                    // Calculate amount due: R2000 for 100% attendance, otherwise daily rate
                                    $amountDue = ($attendancePercent == 100) ? $perfectAttendanceAmount : $totalPresent * $dailyRate;
                                    ?>
                                    <tr class="learner-row">
                                        <td class="learner-details">
                                            <input type="checkbox" class="learner-checkbox" 
                                                   value="<?= htmlspecialchars($learnerID, ENT_QUOTES, 'UTF-8') ?>"
                                                   data-learner-name="<?= htmlspecialchars(($learner['surname'] ?? '') . ', ' . ($learner['name'] ?? ''), ENT_QUOTES, 'UTF-8') ?>"
                                                   onchange="updateSelectAllState()" style="transform: scale(1.2);">
                                        </td>
                                        <td class="learner-details"><?= $rowNumber++ ?></td>
                                        <td class="learner-details"><?= ($learner['surname'] === null || $learner['surname'] === '') ? 'N/A' : htmlspecialchars($learner['surname'], ENT_QUOTES, 'UTF-8') ?></td>
                                        <td class="learner-details"><?= ($learner['name'] === null || $learner['name'] === '') ? 'N/A' : htmlspecialchars($learner['name'], ENT_QUOTES, 'UTF-8') ?></td>
                                        <td class="learner-details"><?= ($learner['id_number'] === null || $learner['id_number'] === '') ? 'N/A' : htmlspecialchars($learner['id_number'], ENT_QUOTES, 'UTF-8') ?></td>
                                        <td class="learner-details"><?= ($learner['phone_number'] === null || $learner['phone_number'] === '') ? 'N/A' : htmlspecialchars($learner['phone_number'], ENT_QUOTES, 'UTF-8') ?></td>
                                        
                                        <?php foreach ($dates as $date): ?>
                                            <td class="<?= isset($learner['attendance'][$date]) ? 'present' : 'absent' ?>">
                                                <?php if (isset($learner['attendance'][$date])): ?>
                                                    <?php 
                                                    $signatureFile = $learner['signature'];
                                                    $serverPath = $_SERVER['DOCUMENT_ROOT'] . '/mobile/signatures/' . $signatureFile;
                                                    $webPath = '/mobile/signatures/' . $signatureFile;
                                                    if ($signatureFile && !empty($signatureFile) && preg_match('/\.(png|jpg|jpeg|gif)$/i', $signatureFile) && file_exists($serverPath)): ?>
                                                        <img src="<?= htmlspecialchars($webPath, ENT_QUOTES, 'UTF-8') ?>" alt="Signature" class="signature-img" onerror="this.src='';this.parentNode.innerHTML='✓✓';">
                                                    <?php else: ?>
                                                        ✓✓
                                                    <?php endif; ?>
                                                <?php else: ?>
                                                    ✗
                                                <?php endif; ?>
                                            </td>
                                        <?php endforeach; ?>
                                        
                                        <td class="stats-cell"><?= $totalPresent ?>/<?= count($dates) ?></td>
                                        <td class="stats-cell <?= $percentClass ?>"><?= $attendancePercent ?>%</td>
                                        <td class="stats-cell">R <?= number_format($dailyRate, 2) ?></td>
                                        <td class="stats-cell">R <?= number_format($amountDue, 2) ?></td>
                                        <td>
                                            <a href="indivisual.php?LearnerID=<?= htmlspecialchars($learnerID, ENT_QUOTES, 'UTF-8') ?>&project_id=<?= htmlspecialchars($learner['project_id'] ?? '', ENT_QUOTES, 'UTF-8') ?>" class="view-report-btn">View Report</a>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                    
                    <div class="summary">
                        <strong>Summary:</strong> 
                        <?= count($reportData) ?> active learners <?= (!empty($attendanceFilters)) ? '(filtered) ' : '' ?>enrolled | 
                        Period: <?= date('M d, Y', strtotime($startDate)) ?> to <?= date('M d, Y', strtotime($endDate)) ?> (Excluding Weekends)
                        <?php if (!empty($attendanceFilters)): ?>
                            <br><strong>Filters Applied:</strong> 
                            <?php
                            $filterLabels = [];
                            if (in_array('all', $_GET['attendance_filter'] ?? [])) {
                                $filterLabels[] = 'All Attendance Rates (Excludes 0%)';
                            } else {
                                foreach ($attendanceFilters as $filter) {
                                    switch ($filter) {
                                        case 'perfect': $filterLabels[] = 'Perfect Attendance (100%)'; break;
                                        case 'high': $filterLabels[] = 'High Attendance (90-99%)'; break;
                                        case 'medium': $filterLabels[] = 'Medium Attendance (70-89%)'; break;
                                        case 'low': $filterLabels[] = 'Low Attendance (50-69%)'; break;
                                        case 'very-low': $filterLabels[] = 'Very Low Attendance (40-49%)'; break;
                                        case 'poor': $filterLabels[] = 'Poor Attendance (30-39%)'; break;
                                        case 'very-poor': $filterLabels[] = 'Very Poor Attendance (20-29%)'; break;
                                        case 'critical': $filterLabels[] = 'Critical Attendance (10-19%)'; break;
                                        case 'minimal': $filterLabels[] = 'Minimal Attendance (1-9%)'; break;
                                        case 'zero': $filterLabels[] = 'No Attendance (0%)'; break;
                                    }
                                }
                            }
                            echo implode(', ', $filterLabels);
                            ?>
                            <?php if (!in_array('zero', $attendanceFilters)): ?>
                                <br><em>(Excluding 0% attendance and inactive learners)</em>
                            <?php endif; ?>
                        <?php else: ?>
                            <br><em>Excluding learners with 0% attendance and inactive learners</em>
                        <?php endif; ?>
                        <div class="summary-grid">
                            <div class="summary-item">
                                <span class="summary-icon">👥</span>
                                <div>
                                    <span class="summary-number" data-count="<?= count($reportData) ?>">0</span>
                                    <span class="summary-label">Total Active Learners<?= (!empty($attendanceFilters)) ? ' (Filtered)' : '' ?></span>
                                </div>
                            </div>
                            <div class="summary-item">
                                <span class="summary-icon">📅</span>
                                <div>
                                    <span class="summary-number" data-count="<?= $totalAttendance ?>/<?= $totalPossible ?>">0/0</span>
                                    <span class="summary-label">Total Attendance</span>
                                </div>
                            </div>
                            <div class="summary-item">
                                <span class="summary-icon">📊</span>
                                <div>
                                    <span class="summary-number" data-count="<?= $overallAttendancePercent ?>%">0%</span>
                                    <span class="summary-label">Overall Attendance Rate</span>
                                </div>
                            </div>
                            <div class="summary-item">
                                <span class="summary-icon">💰</span>
                                <div>
                                    <span class="summary-number" data-count="R <?= number_format($totalAmountDue, 2) ?>">R 0.00</span>
                                    <span class="summary-label">Total Amount Due</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                
            <?php else: ?>
                <div class="no-data">
                    <h3>No active learner data found for the selected criteria.</h3>
                    <p>Please adjust your filters and try again.</p>
                    <?php if (!empty($attendanceFilters)): ?>
                        <p><em>Note: Your attendance filters may be too restrictive. Try adjusting the attendance criteria.</em></p>
                    <?php endif; ?>
                    <?php if ($result && $result->num_rows === 0): ?>
                        <p>Debug: No records returned from query. Check database connection, table data, activity status (''/NULL vs Inactive), or filter parameters.</p>
                    <?php endif; ?>
                </div>
            <?php endif; ?>

            <?php 
            $conn->close(); 
            ob_end_flush();
            ?>
        </div>
    </div>

<script>
// Enhanced bulk download function using the new cURL-based API
function startBulkDownloadNew() {
    // Check if any learners are displayed
    const learnerRows = document.querySelectorAll('.learner-row');
    if (learnerRows.length === 0) {
        alert('No learners found. Please run a search first to display learners.');
        return;
    }

    // Extract learner IDs from the table
    const learnerIds = [];
    learnerRows.forEach(row => {
        const viewReportLink = row.querySelector('a[href*="indivisual.php"]');
        if (viewReportLink) {
            const href = viewReportLink.getAttribute('href');
            const learnerIdMatch = href.match(/LearnerID=(\d+)/);
            if (learnerIdMatch) {
                learnerIds.push(parseInt(learnerIdMatch[1]));
            }
        }
    });

    if (learnerIds.length === 0) {
        alert('No valid learner IDs found in the current results.');
        return;
    }

    if (learnerIds.length > 50) {
        if (!confirm(`You have selected ${learnerIds.length} learners. This may take a while. Continue?`)) {
            return;
        }
    }

    // Get filtered dates from form inputs or URL parameters
    const urlParams = new URLSearchParams(window.location.search);
    const startDateInput = document.getElementById('start_date');
    const endDateInput = document.getElementById('end_date');
    
    // Extract year and month from the form inputs or URL
    let filteredYear, filteredMonth;
    
    if (startDateInput && startDateInput.value) {
        const startDate = new Date(startDateInput.value);
        filteredYear = startDate.getFullYear();
        filteredMonth = startDate.getMonth() + 1;
    } else if (urlParams.get('start_date')) {
        const startDate = new Date(urlParams.get('start_date'));
        filteredYear = startDate.getFullYear();
        filteredMonth = startDate.getMonth() + 1;
    } else {
        // Default to current date
        filteredYear = new Date().getFullYear();
        filteredMonth = new Date().getMonth() + 1;
    }
    
    // Prepare the request data
    const requestData = {
        learner_ids: JSON.stringify(learnerIds),
        project_id: '76', // Default project ID based on the example URL
        year: filteredYear,
        month: filteredMonth
    };

    // Show loading indicator
    const button = document.getElementById('bulkDownloadBtn');
    const originalText = button.textContent;
    button.textContent = '⏳ Processing...';
    button.disabled = true;

    // Create progress display
    const progressDiv = document.createElement('div');
    progressDiv.id = 'bulkProgress';
    progressDiv.style.cssText = `
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        background: white;
        padding: 20px;
        border: 2px solid #3b82f6;
        border-radius: 10px;
        box-shadow: 0 4px 20px rgba(0,0,0,0.3);
        z-index: 10000;
        min-width: 300px;
        text-align: center;
    `;
    progressDiv.innerHTML = `
        <h3>🔄 Processing Bulk Reports</h3>
        <p>Fetching reports from live URL and converting to PDF...</p>
        <div style="margin: 15px 0;">
            <div style="background: #f0f0f0; border-radius: 10px; overflow: hidden;">
                <div id="progressBar" style="background: #3b82f6; height: 20px; width: 0%; transition: width 0.3s;"></div>
            </div>
        </div>
        <p id="progressText">Starting...</p>
        <small>Using enhanced cURL + mPDF technology</small>
    `;
    document.body.appendChild(progressDiv);

    // Use new high-performance processor for all exports
    document.getElementById('progressText').textContent = 'Initializing high-performance export...';
    
    if (learnerIds.length <= 100) {
        // Small batch: Direct fast processing
        console.log(`🚀 Using direct processing for ${learnerIds.length} learners`);
        startFastExport('fast_bulk_processor.php', requestData, progressDiv, button, originalText);
    } else if (learnerIds.length <= 500) {
        // Medium batch: Parallel processing
        console.log(`⚡ Using parallel processing for ${learnerIds.length} learners`);
        startFastExport('fast_bulk_processor.php', requestData, progressDiv, button, originalText);
    } else {
        // Large batch: Background job processing with system tests
        console.log(`🏭 Using background job processing for ${learnerIds.length} learners`);
        console.log(`🔍 Testing basic server response first...`);
        
        // Test basic server response first
        fetch('test_basic_response.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams(requestData)
        })
        .then(async response => {
            console.log(`🔍 Basic test - Status: ${response.status} ${response.statusText}`);
            console.log(`🔍 Basic test - Headers:`, response.headers.get('content-type'));
            
            const responseText = await response.text();
            console.log(`🔍 Basic test - Raw response:`, responseText.substring(0, 1000));
            
            if (!response.ok) {
                throw new Error(`Basic test failed: HTTP ${response.status}\n\nResponse: ${responseText}`);
            }
            
            const basicTest = JSON.parse(responseText);
            console.log(`🔍 Basic test - Parsed data:`, basicTest);
            
            if (basicTest.success) {
                console.log(`✅ Basic server response working`);
                console.log(`🔍 Auth status: ${basicTest.auth_status}`);
                console.log(`🔍 Database status: ${basicTest.database_status}`);
                
                if (basicTest.auth_status === 'NOT_LOGGED_IN') {
                    alert('Authentication error: You are not logged in. Please refresh the page and try again.');
                    // Cleanup
                    if (progressDiv && progressDiv.parentNode) {
                        progressDiv.parentNode.removeChild(progressDiv);
                    }
                    button.textContent = originalText;
                    button.disabled = false;
                    return;
                }
                
                if (basicTest.database_status !== 'CONNECTED') {
                    alert(`Database error: ${basicTest.database_error || 'Unknown database issue'}`);
                    // Cleanup
                    if (progressDiv && progressDiv.parentNode) {
                        progressDiv.parentNode.removeChild(progressDiv);
                    }
                    button.textContent = originalText;
                    button.disabled = false;
                    return;
                }
                
                console.log(`✅ All basic tests passed - testing fast processor next...`);
                
                // Test the fast processor with minimal test
                fetch('test_fast_processor_minimal.php', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: new URLSearchParams(requestData)
                })
                .then(async response => {
                    console.log(`🧪 Fast processor test - Status: ${response.status} ${response.statusText}`);
                    console.log(`🧪 Fast processor test - Headers:`, response.headers.get('content-type'));
                    
                    const responseText = await response.text();
                    console.log(`🧪 Fast processor test - Raw response:`, responseText.substring(0, 1000));
                    
                    if (!response.ok) {
                        throw new Error(`Fast processor test failed: HTTP ${response.status}\n\nResponse: ${responseText}`);
                    }
                    
                    const processorTest = JSON.parse(responseText);
                    console.log(`🧪 Fast processor test - Parsed data:`, processorTest);
                    
                    if (processorTest.success) {
                        console.log(`✅ Fast processor test passed - starting real background export`);
                        startBackgroundExport('fast_bulk_processor.php', requestData, progressDiv, button, originalText);
                    } else {
                        throw new Error(`Fast processor test failed: ${processorTest.error || 'Unknown error'}`);
                    }
                })
                .catch(error => {
                    console.error(`❌ Fast processor test failed:`, error);
                    alert(`Fast processor test failed: ${error.message}\n\nThe system has issues that prevent bulk exports.`);
                    
                    // Cleanup
                    if (progressDiv && progressDiv.parentNode) {
                        progressDiv.parentNode.removeChild(progressDiv);
                    }
                    button.textContent = originalText;
                    button.disabled = false;
                });
            } else {
                throw new Error(`Basic test failed: ${basicTest.error || 'Unknown error'}`);
            }
        })
        .catch(error => {
            console.error(`❌ Basic test failed:`, error);
            alert(`System test failed: ${error.message}\n\nCannot proceed with export.`);
            
            // Cleanup
            if (progressDiv && progressDiv.parentNode) {
                progressDiv.parentNode.removeChild(progressDiv);
            }
            button.textContent = originalText;
            button.disabled = false;
        });
    }
}

// Unified function to try bulk download with different endpoints
function tryBulkDownload(endpoint, requestData, progressDiv, button, originalText) {
    // Cache-buster to avoid proxy/cdn returning stale HTML
    const absolute = (/^https?:\/\//i).test(endpoint)
        ? endpoint
        : (window.location.origin + '/' + endpoint.replace(/^\/+/, ''));
    const url = absolute + (absolute.includes('?') ? '&' : '?') + '_=' + Date.now();
    return fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json'
        },
        credentials: 'same-origin',
        body: new URLSearchParams(requestData)
    })
    .then(async response => {
        const raw = await response.text();
        if (!response.ok) {
            // Surface raw response snippet to help debugging
            const snippet = raw ? raw.slice(0, 300) : '';
            throw new Error(`HTTP ${response.status} from ${endpoint}${snippet ? `\n\nResponse preview:\n${snippet}` : ''}`);
        }
        try {
            return JSON.parse(raw);
        } catch (e) {
            const snippet = raw ? raw.slice(0, 300) : '';
            throw new Error(`Invalid JSON from ${endpoint}${snippet ? `\n\nResponse preview:\n${snippet}` : ''}`);
        }
    })
    .then(data => {
        // Remove progress indicator
        if (document.getElementById('bulkProgress')) {
            document.body.removeChild(progressDiv);
        }
        
        // Reset button
        button.textContent = originalText;
        button.disabled = false;

        if (data.success) {
            // Show success message with detailed information
            const methodInfo = data.method_statistics ? 
                `\n\n📈 Method Statistics:\n${Object.entries(data.method_statistics).map(([method, count]) => `• ${method}: ${count} learners`).join('\n')}` : '';
            
            const successMsg = `
✅ Bulk export completed successfully!

📊 Results Summary:
• Total Processed: ${data.total_processed} learners
• Failed: ${data.total_failed} learners  
• ZIP File Size: ${data.zip_size_formatted || 'Unknown'}
• Data Source: ${data.data_source}
• Processing Method: ${data.processing_method}${methodInfo}

📁 ZIP File: ${data.zip_file}

The download should start automatically. If not, click OK to download manually.
            `;
            
            alert(successMsg);

            // Trigger automatic download
            if (data.zip_file) {
                const downloadUrl = `?temp_file=${encodeURIComponent(data.zip_file)}`;
                window.location.href = downloadUrl;
            }
        } else {
            throw new Error(data.error || 'Unknown error from server');
        }
    });

    // Simulate progress for better UX (since we don't have real-time progress)
    let progress = 0;
    const progressInterval = setInterval(() => {
        progress += Math.random() * 10;
        if (progress > 90) progress = 90; // Don't complete until we get response
        
        const progressBar = document.getElementById('progressBar');
        const progressText = document.getElementById('progressText');
        
        if (progressBar && progressText) {
            progressBar.style.width = progress + '%';
            
            if (progress < 30) {
                progressText.textContent = 'Fetching HTML from live URLs...';
            } else if (progress < 60) {
                progressText.textContent = 'Converting HTML to PDF...';
            } else if (progress < 90) {
                progressText.textContent = 'Creating ZIP archive...';
            }
        } else {
            clearInterval(progressInterval);
        }
    }, 500);

    // Clear interval after 60 seconds max
    setTimeout(() => clearInterval(progressInterval), 60000);
}

// Sidebar toggle function
function toggleSidebar() {
    const sidebar = document.querySelector('.sidebar');
    const mainContent = document.querySelector('.main-content');
    const floatingBtn = document.querySelector('.floating-toggle-btn');
    
    if (sidebar && mainContent) {
        sidebar.classList.toggle('sidebar-hidden');
        mainContent.classList.toggle('main-content-expanded');
        
        if (floatingBtn) {
            floatingBtn.style.display = sidebar.classList.contains('sidebar-hidden') ? 'block' : 'none';
        }
    }
}

// Navigation function
function navigateToLogout() {
    if (confirm('Are you sure you want to logout?')) {
        window.location.href = 'logout.php';
    }
}

// Auto-update summary numbers with animation
document.addEventListener('DOMContentLoaded', function() {
    const summaryNumbers = document.querySelectorAll('.summary-number[data-count]');
    
    summaryNumbers.forEach(element => {
        const target = element.getAttribute('data-count');
        const isPercentage = target.includes('%');
        const isCurrency = target.includes('R');
        const isFraction = target.includes('/');
        
        if (!isPercentage && !isCurrency && !isFraction && !isNaN(parseInt(target))) {
            animateNumber(element, 0, parseInt(target), 1000);
        } else {
            element.textContent = target;
        }
    });
});

function animateNumber(element, start, end, duration) {
    const startTime = performance.now();
    
    function update(currentTime) {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);
        
        const current = Math.floor(start + (end - start) * progress);
        element.textContent = current.toLocaleString();
        
        if (progress < 1) {
            requestAnimationFrame(update);
        }
    }
    
    requestAnimationFrame(update);
}

// ============================================
// LEARNER SELECTION FUNCTIONALITY
// ============================================

// Toggle all learners checkbox functionality
function toggleAllLearners() {
    const selectAll = document.getElementById('selectAll');
    const learnerCheckboxes = document.querySelectorAll('.learner-checkbox');
    
    learnerCheckboxes.forEach(checkbox => {
        checkbox.checked = selectAll.checked;
    });
    
    updateSelectedCount();
}

// Update the state of the "select all" checkbox
function updateSelectAllState() {
    const learnerCheckboxes = document.querySelectorAll('.learner-checkbox');
    const selectAll = document.getElementById('selectAll');
    const checkedCount = document.querySelectorAll('.learner-checkbox:checked').length;
    
    if (checkedCount === 0) {
        selectAll.indeterminate = false;
        selectAll.checked = false;
    } else if (checkedCount === learnerCheckboxes.length) {
        selectAll.indeterminate = false;
        selectAll.checked = true;
    } else {
        selectAll.indeterminate = true;
        selectAll.checked = false;
    }
    
    updateSelectedCount();
}

// Update the count of selected learners
function updateSelectedCount() {
    const checkedCount = document.querySelectorAll('.learner-checkbox:checked').length;
    document.getElementById('selectedCount').textContent = checkedCount;
    document.getElementById('selectedCountExcel').textContent = checkedCount;
    
    // Enable/disable export buttons based on selection
    const exportBtn = document.getElementById('exportSelectedBtn');
    const exportExcelBtn = document.getElementById('exportSelectedExcelBtn');
    
    if (checkedCount > 0) {
        exportBtn.disabled = false;
        exportExcelBtn.disabled = false;
        exportBtn.style.opacity = '1';
        exportExcelBtn.style.opacity = '1';
    } else {
        exportBtn.disabled = true;
        exportExcelBtn.disabled = true;
        exportBtn.style.opacity = '0.5';
        exportExcelBtn.style.opacity = '0.5';
    }
}

// Export selected learners to PDF reports
function exportSelectedLearners() {
    const selectedCheckboxes = document.querySelectorAll('.learner-checkbox:checked');
    
    if (selectedCheckboxes.length === 0) {
        alert('Please select at least one learner to export.');
        return;
    }
    
    if (selectedCheckboxes.length > 2000) {
        alert('Maximum 2000 learners can be processed at once. Please reduce your selection.');
        return;
    }
    
    if (!confirm(`You have selected ${selectedCheckboxes.length} learners. This may take a while. Continue?`)) {
        return;
    }
    
    // Collect selected learner IDs
    const learnerIds = Array.from(selectedCheckboxes).map(cb => cb.value);
    
    // Get filtered dates from form inputs or URL parameters
    const urlParams = new URLSearchParams(window.location.search);
    const startDateInput = document.getElementById('start_date');
    const projectId = urlParams.get('project_id') || '76';
    
    // Extract year and month from the form inputs or URL
    let year, month;
    if (startDateInput && startDateInput.value) {
        const startDate = new Date(startDateInput.value);
        year = startDate.getFullYear();
        month = startDate.getMonth() + 1;
    } else if (urlParams.get('start_date')) {
        const startDate = new Date(urlParams.get('start_date'));
        year = startDate.getFullYear();
        month = startDate.getMonth() + 1;
    } else {
        // Default to current date
        year = new Date().getFullYear();
        month = new Date().getMonth() + 1;
    }
    
    // Show progress indicator
    const exportBtn = document.getElementById('exportSelectedBtn');
    const originalText = exportBtn.textContent;
    exportBtn.textContent = '⏳ Processing...';
    exportBtn.disabled = true;
    
    // Create progress div
    const progressDiv = document.createElement('div');
    progressDiv.id = 'selectedProgressContainer';
    progressDiv.innerHTML = `
        <div style="position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); 
                    background: white; padding: 20px; border-radius: 8px; box-shadow: 0 4px 20px rgba(0,0,0,0.3); 
                    z-index: 10000; min-width: 300px; text-align: center;">
            <h3>Processing Selected Learners</h3>
            <div style="margin: 15px 0;">
                <div id="selectedProgressBar" style="width: 100%; height: 20px; background: #f0f0f0; border-radius: 10px; overflow: hidden;">
                    <div style="height: 100%; background: linear-gradient(90deg, #4CAF50, #45a049); width: 0%; transition: width 0.3s;"></div>
                </div>
                <p id="selectedProgressText">Preparing export...</p>
            </div>
        </div>
        <div style="position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 9999;"></div>
    `;
    document.body.appendChild(progressDiv);
    
    // Prepare request data
    const requestData = {
        learner_ids: JSON.stringify(learnerIds),
        project_id: projectId,
        year: year,
        month: month
    };
    
    // Use new high-performance processor for selected learners
    if (learnerIds.length <= 100) {
        console.log(`🚀 Using fast processing for ${learnerIds.length} selected learners`);
        startFastExport('fast_bulk_processor.php', requestData, progressDiv, exportBtn, originalText);
    } else if (learnerIds.length <= 500) {
        console.log(`⚡ Using parallel processing for ${learnerIds.length} selected learners`);
        startFastExport('fast_bulk_processor.php', requestData, progressDiv, exportBtn, originalText);
    } else {
        console.log(`🏭 Using background job for ${learnerIds.length} selected learners`);
        startBackgroundExport('fast_bulk_processor.php', requestData, progressDiv, exportBtn, originalText);
    }
}

// Export selected learners to Excel
function exportSelectedToExcel() {
    const selectedCheckboxes = document.querySelectorAll('.learner-checkbox:checked');
    
    if (selectedCheckboxes.length === 0) {
        alert('Please select at least one learner to export.');
        return;
    }
    
    // Get the selected learner IDs
    const selectedLearnerIds = Array.from(selectedCheckboxes).map(cb => cb.value);
    
    // Create a form and submit it to export only selected learners
    const form = document.createElement('form');
    form.method = 'GET';
    form.action = window.location.pathname;
    
    // Add current search parameters
    const urlParams = new URLSearchParams(window.location.search);
    for (const [key, value] of urlParams.entries()) {
        if (key !== 'export_excel') {
            const input = document.createElement('input');
            input.type = 'hidden';
            input.name = key;
            input.value = value;
            form.appendChild(input);
        }
    }
    
    // Add selected learner IDs
    const selectedInput = document.createElement('input');
    selectedInput.type = 'hidden';
    selectedInput.name = 'selected_learners';
    selectedInput.value = selectedLearnerIds.join(',');
    form.appendChild(selectedInput);
    
    // Add export excel flag
    const exportInput = document.createElement('input');
    exportInput.type = 'hidden';
    exportInput.name = 'export_excel';
    exportInput.value = '1';
    form.appendChild(exportInput);
    
    document.body.appendChild(form);
    form.submit();
    document.body.removeChild(form);
}

// Streaming Export Handler for large exports using fetch streaming
function startStreamingExport(endpoint, requestData, progressDiv, button, originalText) {
    // Update progress div to show streaming status - handle both progress div types
    const progressText = document.getElementById('selectedProgressText') || document.getElementById('progressText');
    const progressBar = progressDiv.querySelector('[style*="background: linear-gradient"]') || document.getElementById('progressBar');
    
    if (progressText) {
        progressText.textContent = 'Connecting to server...';
    }
    
    let progressCounter = 0;
    let totalLearners = JSON.parse(requestData.learner_ids).length;
    let completed = false;
    
    console.log(`🚀 Starting streaming export for ${totalLearners} learners...`);
    
    // Also listen for postMessage events (additional fallback)
    window.addEventListener('message', function(event) {
        if (event.data && event.data.type === 'export_complete') {
            console.log('📨 Received completion message:', event.data);
            if (!completed) {
                completed = true;
                const fileName = event.data.zip_file;
                
                // Create download link
                const downloadLink = document.createElement('a');
                downloadLink.href = `download_export.php?file=${encodeURIComponent(fileName)}`;
                downloadLink.download = fileName;
                downloadLink.style.display = 'none';
                document.body.appendChild(downloadLink);
                downloadLink.click();
                document.body.removeChild(downloadLink);
                
                cleanup();
                alert(`Export completed! ${event.data.total_processed} PDFs created. Download started.`);
            }
        }
    });
    
    // Use fetch with streaming to read response as it comes
    fetch(endpoint, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams(requestData)
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';
        
        function readStream() {
            return reader.read().then(({ done, value }) => {
                if (done) {
                    console.log('✅ Stream completed');
                    if (!completed) {
                        // Stream ended without completion signal
                        completed = true;
                        cleanup();
                        alert('Export may have completed. Please check your downloads.');
                    }
                    return;
                }
                
                // Decode the chunk and add to buffer
                const chunk = decoder.decode(value, { stream: true });
                
                // DEBUG: Log raw chunks received
                if (chunk.trim()) {
                    console.log('📦 Received chunk:', chunk.substring(0, 200) + (chunk.length > 200 ? '...' : ''));
                }
                
                buffer += chunk;
                
                // Process complete lines in buffer
                let lines = buffer.split('\n');
                buffer = lines.pop(); // Keep incomplete line in buffer
                
                for (let line of lines) {
                    if (line.trim()) {
                        console.log('📄 Processing line:', line.substring(0, 100) + (line.length > 100 ? '...' : ''));
                        processStreamLine(line);
                    }
                }
                
                // Continue reading
                return readStream();
            });
        }
        
        function processStreamLine(line) {
            // Look for progress comments
            const progressMatch = line.match(/<!--.*?Processing learner (\d+) of (\d+) \(([0-9.]+)%\).*?-->/);
            if (progressMatch) {
                const current = parseInt(progressMatch[1]);
                const total = parseInt(progressMatch[2]);
                const percent = parseFloat(progressMatch[3]);
                
                if (progressText) {
                    progressText.textContent = `Processing learner ${current} of ${total} (${percent}%)`;
                }
                if (progressBar) {
                    progressBar.style.width = Math.min(percent, 95) + '%';
                }
                
                console.log(`📊 Progress: ${current}/${total} (${percent}%)`);
            }
            
            // Look for console.log statements
            const consoleMatch = line.match(/<script>console\.log\('([^']+)'\);<\/script>/);
            if (consoleMatch) {
                console.log('📡 Server: ' + consoleMatch[1]);
            }
            
            // Look for completion
            if (line.includes('Export completed') && line.includes('PDFs created')) {
                const completedMatch = line.match(/(\d+) PDFs created/);
                const pdfCount = completedMatch ? completedMatch[1] : 'unknown';
                
                console.log(`✅ Export completed! ${pdfCount} PDFs created.`);
                completed = true;
                
                // Update progress to 100%
                if (progressText) {
                    progressText.textContent = `Export completed! ${pdfCount} PDFs created.`;
                }
                if (progressBar) {
                    progressBar.style.width = '100%';
                }
                
                // Look for download link in the stream
                const downloadMatch = line.match(/download_export\.php\?file=([^']+)/);
                if (downloadMatch) {
                    const fileName = downloadMatch[1];
                    console.log(`📥 Starting download: ${fileName}`);
                    
                    // Create a temporary download link and click it
                    const downloadLink = document.createElement('a');
                    downloadLink.href = `download_export.php?file=${fileName}`;
                    downloadLink.download = fileName;
                    downloadLink.style.display = 'none';
                    document.body.appendChild(downloadLink);
                    downloadLink.click();
                    document.body.removeChild(downloadLink);
                    
                    // Wait a moment then cleanup
                    setTimeout(() => {
                        cleanup();
                        alert(`Export completed successfully! ${pdfCount} PDFs created. Download should have started.`);
                    }, 1000);
                } else {
                    // Fallback if no download link found
                    setTimeout(() => {
                        cleanup();
                        alert(`Export completed! ${pdfCount} PDFs created. Please check your downloads folder or contact support.`);
                    }, 2000);
                }
            }
            
            // Look for errors
            if (line.includes('Export failed') || line.includes('alert(')) {
                const errorMatch = line.match(/alert\('([^']+)'\)/);
                const errorMsg = errorMatch ? errorMatch[1] : 'Unknown error occurred';
                
                console.error('❌ Export failed:', errorMsg);
                completed = true;
                cleanup();
                alert('Export failed: ' + errorMsg);
            }
        }
        
        return readStream();
    })
    .catch(error => {
        console.error('❌ Streaming error:', error);
        completed = true;
        cleanup();
        alert('Export failed: ' + error.message);
    });
    
    function cleanup() {
        if (progressDiv && progressDiv.parentNode) {
            progressDiv.parentNode.removeChild(progressDiv);
        }
        button.textContent = originalText;
        button.disabled = false;
    }
}

// Fast Export Handler - optimized for speed
function startFastExport(endpoint, requestData, progressDiv, button, originalText) {
    const progressText = document.getElementById('selectedProgressText') || document.getElementById('progressText');
    const progressBar = progressDiv.querySelector('[style*="background: linear-gradient"]') || document.getElementById('progressBar');
    
    console.log('🚀 Starting high-performance export...');
    
    if (progressText) {
        progressText.textContent = 'Starting high-performance export...';
    }
    
    fetch(endpoint, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams(requestData)
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';
        
        function readStream() {
            return reader.read().then(({ done, value }) => {
                if (done) {
                    console.log('✅ Fast export stream completed');
                    return;
                }
                
                const chunk = decoder.decode(value, { stream: true });
                buffer += chunk;
                
                let lines = buffer.split('\n');
                buffer = lines.pop();
                
                for (let line of lines) {
                    processFastExportLine(line, progressText, progressBar);
                }
                
                return readStream();
            });
        }
        
        return readStream();
    })
    .then(() => {
        // Cleanup
        if (progressDiv && progressDiv.parentNode) {
            progressDiv.parentNode.removeChild(progressDiv);
        }
        button.textContent = originalText;
        button.disabled = false;
    })
    .catch(error => {
        console.error('❌ Fast export failed:', error);
        
        if (progressDiv && progressDiv.parentNode) {
            progressDiv.parentNode.removeChild(progressDiv);
        }
        button.textContent = originalText;
        button.disabled = false;
        
        alert('Export failed: ' + error.message);
    });
}

function processFastExportLine(line, progressText, progressBar) {
    // Look for progress updates
    const progressMatch = line.match(/<!-- PROGRESS: (\d+)\/(\d+) \(([0-9.]+)%\) - (.+?) -->/);
    if (progressMatch) {
        const current = parseInt(progressMatch[1]);
        const total = parseInt(progressMatch[2]);
        const percent = parseFloat(progressMatch[3]);
        const message = progressMatch[4];
        
        if (progressText) {
            progressText.textContent = message;
        }
        if (progressBar) {
            progressBar.style.width = Math.min(percent, 95) + '%';
        }
        
        console.log(`⚡ Fast export progress: ${current}/${total} (${percent}%) - ${message}`);
    }
    
    // Look for completion
    if (line.includes('EXPORT_COMPLETED:')) {
        const fileMatch = line.match(/EXPORT_COMPLETED: (.+?) -->/);
        if (fileMatch) {
            const fileName = fileMatch[1];
            console.log(`✅ Fast export completed! File: ${fileName}`);
            
            // Trigger download
            window.location.href = `download_export.php?file=${encodeURIComponent(fileName)}`;
        }
    }
    
    // Look for console messages
    const consoleMatch = line.match(/<script>console\.log\('([^']+)'\);<\/script>/);
    if (consoleMatch) {
        console.log('📡 Server: ' + consoleMatch[1]);
    }
}

// Background Export Handler - for massive exports (500+)
function startBackgroundExport(endpoint, requestData, progressDiv, button, originalText) {
    const progressText = document.getElementById('selectedProgressText') || document.getElementById('progressText');
    const progressBar = progressDiv.querySelector('[style*="background: linear-gradient"]') || document.getElementById('progressBar');
    
    console.log('🏭 Starting background job export...');
    
    if (progressText) {
        progressText.textContent = 'Starting background job...';
    }
    
    fetch(endpoint, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams(requestData)
    })
    .then(async response => {
        console.log(`📡 Response status: ${response.status} ${response.statusText}`);
        console.log(`📡 Response headers:`, response.headers.get('content-type'));
        
        const responseText = await response.text();
        console.log(`📡 Raw response:`, responseText.substring(0, 500) + (responseText.length > 500 ? '...' : ''));
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}\n\nResponse: ${responseText.substring(0, 200)}`);
        }
        
        // Try to parse as JSON
        try {
            const data = JSON.parse(responseText);
            return data;
        } catch (parseError) {
            console.error('❌ JSON Parse Error:', parseError);
            console.error('❌ Raw response that failed to parse:', responseText);
            throw new Error(`Invalid JSON response from server:\n\n${responseText.substring(0, 300)}`);
        }
    })
    .then(data => {
        console.log(`📨 Parsed response data:`, data);
        
        if (data.success && data.job_id) {
            console.log(`🏭 Background job started: ${data.job_id}`);
            console.log(`⏱️ Estimated time: ${data.estimated_time}`);
            
            if (progressText) {
                progressText.textContent = `Background job started (${data.estimated_time})`;
            }
            
            // Start polling for job status
            pollBackgroundJob(data.job_id, progressText, progressBar, progressDiv, button, originalText);
        } else {
            throw new Error(data.error || 'Failed to start background job');
        }
    })
    .catch(error => {
        console.error('❌ Background export failed:', error);
        
        if (progressDiv && progressDiv.parentNode) {
            progressDiv.parentNode.removeChild(progressDiv);
        }
        button.textContent = originalText;
        button.disabled = false;
        
        alert('Export failed: ' + error.message);
    });
}

function pollBackgroundJob(jobId, progressText, progressBar, progressDiv, button, originalText) {
    const pollInterval = setInterval(() => {
        fetch(`check_job_status.php?job_id=${encodeURIComponent(jobId)}`)
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    const status = data.status;
                    
                    if (progressText) {
                        progressText.textContent = `Processing chunk ${status.current_chunk || 0} of ${status.total_chunks || 0} (${status.processed || 0} processed)`;
                    }
                    if (progressBar) {
                        progressBar.style.width = Math.min(status.progress || 0, 95) + '%';
                    }
                    
                    console.log(`🏭 Job progress: ${status.progress || 0}% (${status.processed || 0} processed)`);
                    
                    if (status.status === 'completed') {
                        clearInterval(pollInterval);
                        
                        if (progressText) {
                            progressText.textContent = `Export completed! ${status.processed} PDFs created.`;
                        }
                        if (progressBar) {
                            progressBar.style.width = '100%';
                        }
                        
                        console.log(`✅ Background job completed! ${status.processed} PDFs created.`);
                        console.log(`📋 Job status data:`, status);
                        
                        // Download the file
                        const downloadFile = status.zip_file || status.download_file;
                        if (downloadFile) {
                            console.log(`📥 Starting download of: ${downloadFile}`);
                            setTimeout(() => {
                                window.location.href = `download_export.php?file=${encodeURIComponent(downloadFile)}`;
                                
                                // Cleanup
                                if (progressDiv && progressDiv.parentNode) {
                                    progressDiv.parentNode.removeChild(progressDiv);
                                }
                                button.textContent = originalText;
                                button.disabled = false;
                                
                                alert(`Export completed! ${status.processed} PDFs created. Download starting...`);
                            }, 2000);
                        } else {
                            console.error(`❌ No download file found in status:`, status);
                            alert('Export completed but download file not found. Please check the server.');
                            
                            // Cleanup
                            if (progressDiv && progressDiv.parentNode) {
                                progressDiv.parentNode.removeChild(progressDiv);
                            }
                            button.textContent = originalText;
                            button.disabled = false;
                        }
                    } else if (status.status === 'error') {
                        clearInterval(pollInterval);
                        
                        console.error('❌ Background job failed:', status.message);
                        
                        if (progressDiv && progressDiv.parentNode) {
                            progressDiv.parentNode.removeChild(progressDiv);
                        }
                        button.textContent = originalText;
                        button.disabled = false;
                        
                        alert('Export failed: ' + status.message);
                    }
                }
            })
            .catch(error => {
                console.error('❌ Failed to check job status:', error);
            });
    }, 3000); // Check every 3 seconds
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
    updateSelectedCount();
});

// Bulk download documents (sick notes and manual attendance)
function startBulkDownloadDocuments() {
    // Check if any learners are displayed
    const learnerRows = document.querySelectorAll('.learner-row');
    if (learnerRows.length === 0) {
        alert('No learners found. Please run a search first to display learners.');
        return;
    }

    // Extract learner IDs from the table
    const learnerIds = [];
    learnerRows.forEach(row => {
        const viewReportLink = row.querySelector('a[href*="indivisual.php"]');
        if (viewReportLink) {
            const href = viewReportLink.getAttribute('href');
            const learnerIdMatch = href.match(/LearnerID=(\d+)/);
            if (learnerIdMatch) {
                learnerIds.push(parseInt(learnerIdMatch[1]));
            }
        }
    });

    if (learnerIds.length === 0) {
        alert('No valid learner IDs found in the current results.');
        return;
    }

    // Get date range and site info
    const urlParams = new URLSearchParams(window.location.search);
    const startDateInput = document.getElementById('start_date');
    const endDateInput = document.getElementById('end_date');
    const siteSelect = document.querySelector('select[name="site"]');
    
    const startDate = startDateInput ? startDateInput.value : (urlParams.get('start_date') || '');
    const endDate = endDateInput ? endDateInput.value : (urlParams.get('end_date') || '');
    const siteName = siteSelect ? siteSelect.options[siteSelect.selectedIndex].text : 'Site';
    
    if (!startDate || !endDate) {
        alert('Please select a date range first.');
        return;
    }

    if (!confirm(`Download all sick notes and manual attendance documents for ${learnerIds.length} learners?\n\nDate range: ${startDate} to ${endDate}`)) {
        return;
    }

    // Prepare the request data
    const requestData = {
        learner_ids: JSON.stringify(learnerIds),
        start_date: startDate,
        end_date: endDate,
        site_name: siteName
    };

    // Debug logging
    console.log('Bulk download request data:', requestData);
    console.log('Learner IDs:', learnerIds);
    console.log('Date range:', startDate, 'to', endDate);

    // Show loading indicator
    const button = document.getElementById('bulkDownloadDocsBtn');
    const originalText = button.textContent;
    button.textContent = '⏳ Processing...';
    button.disabled = true;

    // Create progress display
    const progressDiv = document.createElement('div');
    progressDiv.id = 'bulkDocsProgress';
    progressDiv.style.cssText = `
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        background: white;
        padding: 20px;
        border: 2px solid #10b981;
        border-radius: 10px;
        box-shadow: 0 4px 20px rgba(0,0,0,0.3);
        z-index: 10000;
        min-width: 300px;
        text-align: center;
    `;
    progressDiv.innerHTML = `
        <h3>📎 Collecting Documents</h3>
        <p>Gathering sick notes and manual attendance documents...</p>
        <div style="margin: 15px 0;">
            <div style="background: #f0f0f0; border-radius: 10px; overflow: hidden;">
                <div id="docsProgressBar" style="background: #10b981; height: 20px; width: 50%; transition: width 0.3s;"></div>
            </div>
        </div>
        <p id="docsProgressText">Processing ${learnerIds.length} learners...</p>
    `;
    document.body.appendChild(progressDiv);

    // Make the request
    fetch('bulk_download_documents.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json'
        },
        body: new URLSearchParams(requestData)
    })
    .then(async response => {
        const responseText = await response.text();
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${responseText}`);
        }
        
        try {
            return JSON.parse(responseText);
        } catch (e) {
            throw new Error(`Invalid JSON response: ${responseText.substring(0, 200)}`);
        }
    })
    .then(data => {
        if (data.success) {
            // Update progress
            document.getElementById('docsProgressBar').style.width = '100%';
            document.getElementById('docsProgressText').textContent = 
                `✅ Success! ${data.stats.total_documents} documents collected from ${data.stats.learners_processed} learners`;
            
            // Auto-download the ZIP file using direct download
            setTimeout(() => {
                // Try direct download first
                window.location.href = 'download_zip_direct.php?file=' + encodeURIComponent(data.filename);
                
                // Clean up after a delay
                setTimeout(() => {
                    if (progressDiv && progressDiv.parentNode) {
                        progressDiv.parentNode.removeChild(progressDiv);
                    }
                    button.textContent = originalText;
                    button.disabled = false;
                }, 2000);
            }, 1000);
        } else {
            throw new Error(data.error || 'Unknown error occurred');
        }
    })
    .catch(error => {
        console.error('Document download error:', error);
        alert(`Failed to download documents: ${error.message}`);
        
        // Clean up
        if (progressDiv && progressDiv.parentNode) {
            progressDiv.parentNode.removeChild(progressDiv);
        }
        button.textContent = originalText;
        button.disabled = false;
    });
}
</script>

</body>
</html>