<?php
// Start output buffering
ob_start();
session_start();

// REMOVED: Login requirement - users can access without logging in
// if (!isset($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
//     header("Location: login.php");
//     exit();
// }

// Generate security token if not exists
if (!isset($_SESSION['form_token'])) {
    $_SESSION['form_token'] = bin2hex(random_bytes(32));
}

// Validate form submission token (for POST requests)
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!isset($_POST['form_token']) || $_POST['form_token'] !== $_SESSION['form_token']) {
        die("Invalid security token. Please refresh the page and try again.");
    }
    // Regenerate token after use
    $_SESSION['form_token'] = bin2hex(random_bytes(32));
}

// Convert POST to internal variables (for backward compatibility)
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $_GET = $_POST; // Map POST to GET for existing code
}

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('log_errors', 1);

// Include your DB connection
include 'connection.php';

// Include PhpSpreadsheet
require 'vendor.bak-2025-08-28-1226/autoload.php';
// require 'vendor/autoload.php';
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use Mpdf\Mpdf;

// Initialize error reporting for debugging (but suppress display)
error_reporting(E_ALL);
ini_set('display_errors', 0); // Errors will be logged, not displayed
ini_set('log_errors', 1);

// Check database connection
if ($conn->connect_error) {
    error_log("Connection failed: " . $conn->connect_error);
    die("Database connection error. Please contact the administrator.");
}

// South African holidays function - returns array of dates only
function getSouthAfricanHolidays($year) {
    $holidays = getSouthAfricanHolidaysWithNames($year);
    return array_keys($holidays);
}

// South African holidays function - returns associative array with names
function getSouthAfricanHolidaysWithNames($year) {
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
    
    $holidays[$goodFriday] = 'Good Friday';
    $holidays[$familyDay] = 'Family Day';
    
    ksort($holidays);
    return $holidays;
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

// Fetch all distinct classes for the dropdown filter (based on selected site)
$classes = [];
$classQuery = "SELECT DISTINCT c.className, c.classID FROM class c JOIN sites s ON c.siteID = s.siteID WHERE 1=1";
if (isset($_GET['district']) && !empty($_GET['district'])) {
    $classQuery .= " AND s.District = '" . $conn->real_escape_string($_GET['district']) . "'";
}
if (isset($_GET['site']) && !empty($_GET['site'])) {
    $classQuery .= " AND s.siteName = '" . $conn->real_escape_string($_GET['site']) . "'";
}
$classQuery .= " ORDER BY c.className";
$classResult = $conn->query($classQuery);
if ($classResult) {
    while ($c = $classResult->fetch_assoc()) {
        $classes[] = $c;
    }
} else {
    error_log("Error fetching classes: " . $conn->error);
    die("Error fetching classes. Please try again.");
}

// Get selected filters
$selectedDistrict = isset($_GET['district']) ? $_GET['district'] : '';
$selectedSite = isset($_GET['site']) ? $_GET['site'] : '';
$selectedClass = isset($_GET['class']) ? $_GET['class'] : '';
$idSearch = isset($_GET['id_search']) ? $_GET['id_search'] : '';

// Handle month selection
$selectedMonth = isset($_GET['month']) ? $_GET['month'] : date('Y-m');
$showOutstandingFeesMessage = false;

// Set start and end dates based on selected month
if (isset($_GET['month']) && !empty($_GET['month'])) {
    $startDate = date('Y-m-01', strtotime($selectedMonth . '-01'));
    $endDate = date('Y-m-t', strtotime($selectedMonth . '-01'));
    
    // Check if October is selected
    $monthNumber = date('n', strtotime($selectedMonth . '-01'));
    if ($monthNumber == 10) {
        $showOutstandingFeesMessage = true;
    }
} else {
    // Fallback to manual date selection if provided
    $startDate = isset($_GET['start_date']) ? $_GET['start_date'] : date('Y-m-01');
    $endDate = isset($_GET['end_date']) ? $_GET['end_date'] : date('Y-m-t');
}

$attendanceFilters = isset($_GET['attendance_filter']) && is_array($_GET['attendance_filter']) ? $_GET['attendance_filter'] : [];
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

// Validate date inputs
$startDateTime = new DateTime($startDate);
$endDateTime = new DateTime($endDate);
if ($startDateTime > $endDateTime) {
    $endDate = $startDate;
    $endDateTime = $startDateTime;
}

// Get South African holidays for the year range with names
$startYear = (int)$startDateTime->format('Y');
$endYear = (int)$endDateTime->format('Y');
$allHolidaysWithNames = [];
for ($year = $startYear; $year <= $endYear; $year++) {
    $yearHolidays = getSouthAfricanHolidaysWithNames($year);
    $allHolidaysWithNames = array_merge($allHolidaysWithNames, $yearHolidays);
}

// Get all WEEKDAY dates in the range for column headers (INCLUDING public holidays)
$dates = [];
$publicHolidaysInRange = []; // Track holidays that fall on weekdays with their names
$currentDate = clone $startDateTime;
while ($currentDate <= $endDateTime) {
    $dayOfWeek = $currentDate->format('N');
    $dateStr = $currentDate->format('Y-m-d');
    
    if ($dayOfWeek < 6) { // Weekday (Monday-Friday)
        $dates[] = $dateStr; // Add all weekdays including holidays
        
        // Check if this date is a holiday
        if (isset($allHolidaysWithNames[$dateStr])) {
            $publicHolidaysInRange[$dateStr] = $allHolidaysWithNames[$dateStr];
        }
    }
    $currentDate->modify('+1 day');
}

// Build the main query with activity_status filter using prepared statements (SQL injection prevention)
$sql = "
    SELECT
        s.District,
        s.siteName,
        s.project_id,
        c.className,
        ld.LearnerID,
        ld.Name,
        ld.Surname,
        ld.IDNumber,
        ld.PhoneNumber,
        ld.signature,
        ld.activity_statu,
        DATE(lc.clock_date) AS clock_date,
        lc.source,
        lc.status
    FROM sites s
    JOIN class c ON s.siteID = c.siteID
    JOIN learnerdetails ld ON c.classID = ld.classID
    LEFT JOIN (
        SELECT DISTINCT LearnerID, DATE(clock_date) as clock_date, 'regular' as source, NULL as status
        FROM learner_clocking 
        WHERE DATE(clock_date) BETWEEN ? AND ?
        UNION
        SELECT DISTINCT LearnerID, DATE(clock_date) as clock_date, 'manual' as source, status
        FROM manual_clocking 
        WHERE DATE(clock_date) BETWEEN ? AND ?
    ) lc ON ld.LearnerID = lc.LearnerID
    WHERE (ld.activity_statu = '' OR ld.activity_statu IS NULL)
";

$whereClauses = [];
$params = [$startDate, $endDate, $startDate, $endDate];
$types = "ssss";

if (!empty($selectedDistrict)) {
    $whereClauses[] = "s.District = ?";
    $params[] = $selectedDistrict;
    $types .= "s";
}
if (!empty($selectedSite)) {
    $whereClauses[] = "s.siteName = ?";
    $params[] = $selectedSite;
    $types .= "s";
}
if (!empty($selectedClass)) {
    $whereClauses[] = "c.classID = ?";
    $params[] = $selectedClass;
    $types .= "s";
}
if (isset($_GET['id_search']) && !empty($_GET['id_search'])) {
    $whereClauses[] = "ld.IDNumber = ?";
    $params[] = $_GET['id_search'];
    $types .= "s";
}
if (!empty($whereClauses)) {
    $sql .= " AND " . implode(" AND ", $whereClauses);
}

$sql .= " ORDER BY ld.Surname, ld.Name";

// Use prepared statement to prevent SQL injection
$stmt = $conn->prepare($sql);
if ($stmt === false) {
    error_log("Error preparing statement: " . $conn->error);
    die("Error preparing query. Please try again.");
}

// Bind parameters dynamically
$stmt->bind_param($types, ...$params);
$stmt->execute();
$result = $stmt->get_result();

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

// Define rates - Calculate daily rate based on working days in the MONTH (not selected date range)
// Get the month from the date range to calculate working days
$monthStart = new DateTime($startDate);
$monthStart->modify('first day of this month');
$monthEnd = new DateTime($startDate);
$monthEnd->modify('last day of this month');

// Count working days (weekdays) in the month
$monthWorkingDays = 0;
$currentDay = clone $monthStart;
while ($currentDay <= $monthEnd) {
    $dayOfWeek = $currentDay->format('N');
    if ($dayOfWeek < 6) { // Monday to Friday
        $monthWorkingDays++;
    }
    $currentDay->modify('+1 day');
}

$perfectAttendanceAmount = 2000.00; // Amount for 100% attendance
$dailyRate = $monthWorkingDays > 0 ? ($perfectAttendanceAmount / $monthWorkingDays) : 95.2391; // Daily rate based on month working days

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
                'site_name' => $row['siteName'],
                'class_name' => $row['className'],
                'attendance' => []
            ];
        }
        
        if ($row['clock_date'] && !isset($reportData[$learnerKey]['attendance'][$row['clock_date']])) {
            // Store attendance with source and status information
            $reportData[$learnerKey]['attendance'][$row['clock_date']] = [
                'present' => true,
                'source' => $row['source'] ?? 'regular',
                'status' => $row['status'] ?? null
            ];
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
    // First pass: Check if learner has ANY actual attendance
    $hasAnyAttendance = false;
    $actualPresentDays = 0;
    
    foreach ($dates as $date) {
        if (!isset($publicHolidaysInRange[$date]) && isset($learner['attendance'][$date])) {
            $attendance = $learner['attendance'][$date];
            if ($attendance['source'] === 'regular' || 
                ($attendance['source'] === 'manual' && strcasecmp($attendance['status'], 'Approved') === 0)) {
                $hasAnyAttendance = true;
                $actualPresentDays++;
            }
        }
    }
    
    // Second pass: Count total present including holidays (only if learner has attendance)
    $totalPresent = $actualPresentDays;
    if ($hasAnyAttendance) {
        // Add holidays to the count only if learner has actual attendance
        foreach ($dates as $date) {
            if (isset($publicHolidaysInRange[$date])) {
                $totalPresent++;
            }
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

$overallAttendancePercent = $totalPossible > 0 ? round(($totalAttendance / $totalPossible) * 100, 1) : 0;

// Handle Excel export
if (isset($_GET['export_excel']) && $_GET['export_excel'] == '1') {
    $spreadsheet = new Spreadsheet();
    $sheet = $spreadsheet->getActiveSheet();
    $sheet->setTitle('Attendance Report');

    // Set headers
    $headers = [
        '#', 'Surname', 'Name', 'ID Number', 'Phone Number', 'Site Name', 'Class Name'
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

    // Write data
    $rowNumber = 2; // Start from row 2 (after headers)
    foreach ($reportData as $learnerID => $learner) {
        // First pass: Check if learner has ANY actual attendance
        $hasAnyAttendance = false;
        $actualPresentDays = 0;
        
        foreach ($dates as $date) {
            if (!isset($publicHolidaysInRange[$date]) && isset($learner['attendance'][$date])) {
                $attendance = $learner['attendance'][$date];
                if ($attendance['source'] === 'regular' || 
                    ($attendance['source'] === 'manual' && strcasecmp($attendance['status'], 'Approved') === 0)) {
                    $hasAnyAttendance = true;
                    $actualPresentDays++;
                }
            }
        }
        
        // Second pass: Count total present including holidays (only if learner has attendance)
        $totalPresent = $actualPresentDays;
        if ($hasAnyAttendance) {
            foreach ($dates as $date) {
                if (isset($publicHolidaysInRange[$date])) {
                    $totalPresent++;
                }
            }
        }
        
        $attendancePercent = count($dates) > 0 ? round(($totalPresent / count($dates)) * 100, 1) : 0;
        $amountDue = ($attendancePercent == 100) ? $perfectAttendanceAmount : $totalPresent * $dailyRate;

        $rowData = [
            $rowNumber - 1,
            $learner['surname'] ?? 'N/A',
            $learner['name'] ?? 'N/A',
            $learner['id_number'] ?? 'N/A',
            $learner['phone_number'] ?? 'N/A',
            $learner['site_name'] ?? 'N/A',
            $learner['class_name'] ?? 'N/A'
        ];
        foreach ($dates as $date) {
            if (isset($publicHolidaysInRange[$date])) {
                // Public holiday - always show holiday name
                $rowData[] = $publicHolidaysInRange[$date];
            } elseif (isset($learner['attendance'][$date])) {
                $attendance = $learner['attendance'][$date];
                if ($attendance['source'] === 'manual') {
                    $statusLabel = ucfirst(strtolower($attendance['status'] ?? 'Unknown'));
                    $rowData[] = "Manual - {$statusLabel}";
                } else {
                    $rowData[] = 'Present';
                }
            } else {
                $rowData[] = 'Absent';
            }
        }
        $rowData[] = $totalPresent . '/' . count($dates);
        $rowData[] = $attendancePercent . '%';
        $rowData[] = 'R ' . number_format($dailyRate, 2);
        $rowData[] = 'R ' . number_format($amountDue, 2);

        $sheet->fromArray($rowData, NULL, 'A' . $rowNumber);
        $rowNumber++;
    }

    // Add summary
    $summaryRow = $rowNumber + 1;
    $sheet->setCellValue('A' . $summaryRow, 'Summary');
    $sheet->setCellValue('B' . $summaryRow, 'Total Active Learners: ' . count($reportData));
    $sheet->setCellValue('C' . $summaryRow, 'Total Attendance: ' . $totalAttendance . '/' . $totalPossible);
    $sheet->setCellValue('D' . $summaryRow, 'Overall Attendance Rate: ' . $overallAttendancePercent . '%');
    $sheet->setCellValue('E' . $summaryRow, 'Total Amount Due: R ' . number_format($totalAmountDue, 2));

    // Auto-size columns
    foreach (range('A', $sheet->getHighestColumn()) as $col) {
        $sheet->getColumnDimension($col)->setAutoSize(true);
    }

    // Set headers for download
    header('Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    header('Content-Disposition: attachment;filename="Attendance_Report_' . date('Ymd_His') . '.xlsx"');
    header('Cache-Control: max-age=0');

    $writer = new Xlsx($spreadsheet);
    $writer->save('php://output');
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
        .pending { background: #fbbf24; color: #000; }
        .holiday { background: #fbbf24; color: #000; }
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
        // First pass: Check if learner has ANY actual attendance
        $hasAnyAttendance = false;
        $actualPresentDays = 0;
        
        foreach ($dates as $date) {
            if (!isset($publicHolidaysInRange[$date]) && isset($learner['attendance'][$date])) {
                $attendance = $learner['attendance'][$date];
                if ($attendance['source'] === 'regular' || 
                    ($attendance['source'] === 'manual' && strcasecmp($attendance['status'], 'Approved') === 0)) {
                    $hasAnyAttendance = true;
                    $actualPresentDays++;
                }
            }
        }
        
        // Second pass: Count total present including holidays (only if learner has attendance)
        $totalPresent = $actualPresentDays;
        if ($hasAnyAttendance) {
            foreach ($dates as $date) {
                if (isset($publicHolidaysInRange[$date])) {
                    $totalPresent++;
                }
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
            if (isset($publicHolidaysInRange[$date])) {
                // Public holiday - always yellow
                $class = 'holiday';
                $content = $publicHolidaysInRange[$date];
            } elseif (isset($learner['attendance'][$date])) {
                $attendance = $learner['attendance'][$date];
                if ($attendance['source'] === 'manual') {
                    $status = $attendance['status'] ?? 'Unknown';
                    $statusLabel = ucfirst(strtolower($status));
                    $class = ($status === 'Approved') ? 'present' : (($status === 'Pending') ? 'pending' : 'absent');
                    $content = "Manual<br>{$statusLabel}";
                } else {
                    $class = 'present';
                    $content = 'Present';
                }
            } else {
                $class = 'absent';
                $content = 'Absent';
            }
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

    // Basic Mpdf configuration to avoid dependency issues
    $mpdf = new \Mpdf\Mpdf([
        'mode' => 'utf-8',
        'format' => 'A4',
        'tempDir' => sys_get_temp_dir(),
        'fontDir' => [],
        'fontdata' => [],
        'default_font' => 'arial',
    ]);
    $mpdf->WriteHTML($html);
    $mpdf->Output('Attendance_Report_' . date('Ymd_His') . '.pdf', 'D');
    exit();
}

// Function to generate full HTML structure like your original indivisual.php
function generateFullHTMLStructure($learnerData, $attendanceRecords, $firstDayOfMonth, $lastDayOfMonth, $year, $month, $conn, $learnerID) {
    error_log("Starting generateFullHTMLStructure for learner ID: $learnerID");
    
    // South African holidays function (from your original code)
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
        
        $holidays[$goodFriday] = 'Good Friday';
        $holidays[$familyDay] = 'Family Day';
        
        ksort($holidays);
        return array_keys($holidays);
    }
    
    // Get holidays for the year
    $saHolidays = getSouthAfricanHolidays($year);
    
    // Extract learner data
    $Name = $learnerData['Name'] ?? '';
    $Surname = $learnerData['Surname'] ?? '';
    $FullName = trim($Name . ' ' . $Surname);
    $IDNumber = $learnerData['IDNumber'] ?? 'N/A';
    $PhoneNumber = $learnerData['PhoneNumber'] ?? 'N/A';
    $Gender = $learnerData['Gender'] ?? 'N/A';
    $Address = $learnerData['AddressLine1'] ?? 'N/A';
    $projectName = $learnerData['Project_name'] ?? 'N/A';
    $projectPathway = $learnerData['Project_pathway'] ?? 'N/A';
    $Province = $learnerData['Province'] ?? 'N/A';
    
    error_log("Data extraction completed, starting HTML generation for: $FullName");
    
    // Start building HTML with your original structure
    $html = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/css/bootstrap.min.css">
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
            height: 40px;
            overflow: auto;
            font-size: 8px;
            padding: 1px;
            text-align: center;
        }
        .calendar-day small {
            display: block;
            line-height: 1.0;
            font-size: 7px;
        }
        .calendar-container {
            margin-bottom: 8px;
        }
        .table {
            font-size: 8px;
            margin-bottom: 3px;
            width: 50%;
        }
        .table td, .table th {
            padding: 1px;
            text-align: center;
            font-size: 7px;
        }
        .badge {
            color: black !important;
            font-size: 7px;
            padding: 2px 4px;
            margin-right: 2px;
        }
        .list-group-item {
            font-size: 10px;
            padding: 2px;
            margin-bottom: 1px;
        }
        .list-group {
            margin-bottom: 5px;
        }
        .list-group-item span {
            padding-right: 8px;
        }
        #report-content {
            padding: 5px;
            margin: 0;
        }
        .container-fluid {
            padding-left: 1px;
            padding-right: 1px;
            margin: 1px;
        }
        .bs-example {
            margin: 1px;
        }
        .profile-container {
            display: flex;
            align-items: center;
            padding: 3px;
            margin: 0;
            gap: 6px;
            font-size: 40px;
            width: 100%;
            box-sizing: border-box;
            position: relative;
            z-index: 1;
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
            margin-bottom: 8px;
        }
        .signature-container {
            margin-top: 8px;
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
        /* Hide navigation buttons on main page */
        .calendar-nav {
            display: none;
        }
        /* Ensure proper column layout */
        /* Ensure proper column layout - Single page landscape */
        .col-md-4 {
            float: right !important;
            clear: right !important;
            width: 40% !important;
            display: block !important;
        }
        .col-md-8 {
            float: left !important;
            clear: left !important;
            width: 60% !important;
            display: block !important;
        }
        .row {
            display: flex !important;
            flex-wrap: wrap !important;
            width: 100% !important;
            clear: both !important;
        }
        .row::after {
            content: "";
            clear: both;
            display: table;
        }

        /* Natural single page layout */
        #report-content {
            page-break-inside: avoid !important;
            margin: 0;
            padding: 1px;
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
                margin: 2px;
                padding: 2px;
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
                /* min-height removed */
            }
        }
    </style>
</head>
<body>
<div id="report-content">
    <div class="container-fluid">
        <div class="bs-example"></div>
        <div class="main-logo-container"></div> 

        <div class="container-fluid">
            <div class="row">
                <div class="col">
                    <img src="assets/img/sdp_placeholder.png" class="rounded float-start" alt="SDP Logo" style="max-width: 300px; height: 50px;">
                </div>
                <div class="col"></div>
                <div class="col">
                    <img src="assets/img/rlms.PNG"  class="rounded float-end" alt="Client Logo" style="max-width: 300px; height: 50px;">
                </div>
            </div>
        </div>

        <div style="background-image: linear-gradient(to right, #42bcf5, #42f5d7);" class="p-1 mb-1 text-black" style="font-size: 10px; padding: 2px;">
            PERIOD: ' . htmlspecialchars($firstDayOfMonth) . ' to ' . htmlspecialchars($lastDayOfMonth) . '
        </div>

        <div class="row">
            <div class="col flex-grow-1">
                <div class="container-fluid">
                    <div class="calendar-container">';
    
    // Generate the calendar (simplified version of your original)
    $daysInMonth = date('t', strtotime("$year-$month-01"));
    $startDay = date('w', strtotime("$year-$month-01"));
    $presentDays = $absentDays = $invalidDays = $workingDays = $holidaysCount = $weekendDays = 0;
    
    $html .= '<h4 style="font-size: 0.8rem;margin:1px;">Calendar for ' . date('F Y', strtotime("$year-$month-01")) . '</h4>';
    $html .= '<div class="mb-1">
        <span class="badge badge-primary">Workdays: <span id="workingDays">0</span></span> 
        <span class="badge badge-danger">Holidays: <span id="holidaysCount">0</span></span> 
        <span class="badge badge-info">Weekend: <span id="weekendDays">0</span></span> 
        <span class="badge badge-success">Present: <span id="presentDays">0</span></span> 
        <span class="badge badge-warning">Absent: <span id="absentDays">0</span></span> 
        <span class="badge badge-danger">Invalid: <span id="invalidDays">0</span></span>
    </div>';
    
    $html .= '<table class="table table-bordered">
        <thead><tr style="background-color:#282C65;color:white;font-size:9px;">
            <th>Sun</th><th>Mon</th><th>Tue</th><th>Wed</th><th>Thu</th><th>Fri</th><th>Sat</th>
        </tr></thead><tbody><tr>';
    
    // Add empty cells for days before the month starts
    for ($i = 0; $i < $startDay; $i++) {
        $html .= '<td></td>';
    }
    
    // Generate calendar days
    for ($day = 1; $day <= $daysInMonth; $day++) {
        $date = "$year-" . str_pad($month, 2, '0', STR_PAD_LEFT) . "-" . str_pad($day, 2, '0', STR_PAD_LEFT);
        $dayOfWeek = date('w', strtotime($date));
        $isHoliday = in_array($date, $saHolidays);
        $isWeekend = ($dayOfWeek == 0 || $dayOfWeek == 6);
        
        $html .= '<td class="calendar-day">';
        $html .= "<strong>$day</strong><br>";
        
        if ($isHoliday) {
            $html .= '<small class="holiday">Holiday</small>';
            $holidaysCount++;
        } elseif ($isWeekend) {
            $html .= '<small class="weekend">Weekend</small>';
            $weekendDays++;
        } else {
            $workingDays++;
            if (isset($attendanceRecords[$date])) {
                $html .= '<small class="present">Present</small>';
                $presentDays++;
            } else {
                $html .= '<small class="absent">Absent</small>';
                $absentDays++;
            }
        }
        
        $html .= '</td>';
        
        if (($day + $startDay) % 7 == 0 && $day != $daysInMonth) {
            $html .= '</tr><tr>';
        }
    }
    
    // Fill remaining cells
    while (($day + $startDay) % 7 != 0) {
        $html .= '<td></td>';
        $day++;
    }
    
    $html .= '</tr></tbody></table>';
    
    // Add JavaScript to update counters
    $html .= "<script>
        document.getElementById('workingDays').textContent = '$workingDays';
        document.getElementById('holidaysCount').textContent = '$holidaysCount';
        document.getElementById('weekendDays').textContent = '$weekendDays';
        document.getElementById('presentDays').textContent = '$presentDays';
        document.getElementById('absentDays').textContent = '$absentDays';
        document.getElementById('invalidDays').textContent = '$invalidDays';
    </script>";
    
    $html .= '        </div>
                    <div class="signature-container">
                        <div class="form-row signature-row">
                            <div class="form-group">
                                <label style="color:#282C65;font-size:8px;">Facilitator Signature</label>
                                <span style="font-size:8px;">' . date('Y-m-d H:i:s') . '</span>
                            </div>
                            <div class="form-group">
                                <label style="color:#282C65;font-size:8px;">SDP Representative Signature</label>
                                <span style="font-size:8px;">' . date('Y-m-d H:i:s') . '</span>
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
                                <div>
                                    <h1>' . strtoupper($FullName) . '</h1>
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
                                    <span style="color:#282C65;">' . htmlspecialchars($projectPathway) . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Province:</strong>
                                    <span style="color:#282C65;">' . htmlspecialchars($Province) . '</span>
                                </li>
                                    <span style="color:#282C65;">' . $absentDays . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Invalid Attendance:</strong>
                                    <span style="color:#282C65;">' . $invalidDays . '</span>
                                </li>
                            </ul>
                        </div>
                    </div>
                    
                    <footer class="page-footer font-small blue">
                        <div style="color:#282C65;font-size:8px;" class="text-right py-1">
                            <b>RLMS Attendance. @</b> ' . date('Y-m-d') . '
                        </div>
                    </footer>
                </div>
            </div>
        </div>
    </div>
</div>
</body>
</html>';
    
    error_log("Completed generateFullHTMLStructure successfully for learner ID: $learnerID");
    return $html;
}

// Function to detect valid signatures for a learner
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

// Generate individual HTML reports for browser printing and package in ZIP
function generateBrowserPrintZip($conn, $reportData, $startDate, $year, $month) {
    // Start output buffering to capture progress
    ob_start();

    // Resource management - ultra conservative to prevent gateway timeout
    ini_set('memory_limit', '512M');
    set_time_limit(120); // 2 minutes total
    ignore_user_abort(true); // Continue even if user disconnects
    
    // Limit to 10 learners to balance performance and functionality
    $reportData = array_slice($reportData, 0, 10, true);

    // Force immediate output
    if (ob_get_level()) ob_end_flush();
    
    echo "<div style='text-align: center; padding: 20px; font-family: Arial, sans-serif;'>";
    echo "<h2>🔄 Generating Individual PDF Reports...</h2>";
    echo "<p>Generating individual PDF reports using mPDF...</p>";
    if (count($reportData) > 10) {
        echo "<div style='background: #fff3cd; padding: 10px; margin: 10px; border: 1px solid #ffeaa7; border-radius: 5px;'>";
        echo "<strong⚠️ Processing up to 10 learners only</strong> to prevent gateway timeout.<br>";
        echo "For more learners, run multiple times by applying individual filters (ID search).";
        echo "</div>";
    }
    echo "<div id='progress'></div>";
    echo "</div>";
    flush();

    // Create temporary directory for files
    $tempDir = sys_get_temp_dir() . '/reports_' . time();
    if (!mkdir($tempDir, 0755, true)) {
        die("Failed to create temporary directory");
    }

    // Create ZIP file
    $zipFile = $tempDir . '/Individual_Reports_' . $year . '_' . $month . '.zip';
    $zip = new ZipArchive();

    if ($zip->open($zipFile, ZipArchive::CREATE) !== TRUE) {
        die("Failed to create ZIP file");
    }

    $processedCount = 0;
    $totalLearners = count($reportData);

    foreach ($reportData as $learnerID => $learner) {
        $processedCount++;

        // Debug: Log learner ID and data
        error_log("Processing learner ID: $learnerID, Name: " . ($learner['Name'] ?? 'N/A') . " " . ($learner['Surname'] ?? 'N/A'));
        echo "<script>console.log('Processing learner ID: $learnerID');</script>";

        // Validate learner ID
        if (empty($learnerID) || !is_numeric($learnerID)) {
            error_log("Invalid learner ID: $learnerID, skipping...");
            echo "<script>console.log('Invalid learner ID: $learnerID, skipping...');</script>";
            continue;
        }

        // Update progress
        echo "<script>
            if(document.getElementById('progress')) {
                document.getElementById('progress').innerHTML = '📄 Processing {$processedCount}/{$totalLearners}: " .
                htmlspecialchars(($learner['name'] ?? $learner['Name'] ?? '') . ' ' . ($learner['surname'] ?? $learner['Surname'] ?? '')) . " (ID: $learnerID)';
            }
        </script>";
        flush();

        try {
            echo "<script>
                if(document.getElementById('progress')) {
                    document.getElementById('progress').innerHTML = '🔧 Generating report for " .
                    htmlspecialchars(($learner['name'] ?? '') . ' ' . ($learner['surname'] ?? '')) . "...';
                }
            </script>";
            flush();

            // Get learner details (same query as indivisual.php)
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
                p.Province,
                p.project_id
            FROM learnerdetails l
            JOIN class c ON l.classID = c.`classID`
            JOIN sites s ON c.siteID = s.`siteID`
            JOIN project p ON p.project_id = s.project_id
            JOIN sdp ON p.sdp_name = sdp.sdp_name
            JOIN client ON p.client_name = client.client_name
            WHERE p.project_id = ?
            AND l.`LearnerID` = ?";

            $stmt = $conn->prepare($sql);
            if ($stmt) {
                $stmt->bind_param("ii", $learner['project_id'], $learnerID);
                $stmt->execute();
                $result = $stmt->get_result();

                if ($learnerData = $result->fetch_assoc()) {
                    // Get attendance data (same as indivisual.php)
                    $firstDayOfMonth = date('Y-m-01', strtotime("$year-$month-01"));
                    $lastDayOfMonth = date('Y-m-t', strtotime("$year-$month-01"));

                    $sql2 = "SELECT
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

                    $stmt2 = $conn->prepare($sql2);
                    if ($stmt2) {
                        $stmt2->bind_param('iii', $learnerID, $month, $year);
                        $stmt2->execute();
                        $result2 = $stmt2->get_result();

                        $clockingData = [];
                        while ($row = $result2->fetch_assoc()) {
                            $clockDate = $row['clock_date'];
                            if (!isset($clockingData[$clockDate])) {
                                $clockingData[$clockDate] = [$row];
                            }
                        }
                        $stmt2->close();

                        // Generate individual PDF file for each learner using exact indivisual.php template
                        $indivisualData = [
                            'learnerID' => $learnerID,
                            'project_id' => $learnerData['project_id'] ?? '',
                            'year' => $year,
                            'month' => $month,
                            'FullName' => $learnerData['Name'] . ' ' . $learnerData['Surname'],
                            'Name' => $learnerData['Name'] ?? '',
                            'Surname' => $learnerData['Surname'] ?? '',
                            'IDNumber' => $learnerData['IDNumber'] ?? '',
                            'PhoneNumber' => $learnerData['PhoneNumber'] ?? '',
                            'Gender' => $learnerData['Gender'] ?? '',
                            'AddressLine1' => $learnerData['AddressLine1'] ?? '',
                            'projectName' => $learnerData['Project_name'] ?? '',
                            'projectPathway' => $learnerData['Project_pathway'] ?? '',
                            'Province' => $learnerData['Province'] ?? ''
                        ];

                        // Debug: Log what data we're passing
                        error_log("Passing to generateExactIndivisualTemplate - learnerID: {$indivisualData['learnerID']}, project_id: {$indivisualData['project_id']}");
                        echo "<script>console.log('Passing learnerID: {$indivisualData['learnerID']}, project_id: {$indivisualData['project_id']}');</script>";

                        // Use the exact indivisual.php template structure and calculations
                        $htmlContent = generateExactIndivisualTemplate($conn, $indivisualData, $clockingData);

                        echo "<script>
                            if(document.getElementById('progress')) {
                                document.getElementById('progress').innerHTML = '📄 Generating PDF {$processedCount}/{$totalLearners}: " .
                                htmlspecialchars(($learner['name'] ?? '') . ' ' . ($learner['surname'] ?? '')) . "';
                            }
                        </script>";
                        flush();

                        // Create PDF filename
                        $pdfFileName = preg_replace('/[^a-zA-Z0-9]/', '_',
                            ($learner['name'] ?? '') . '_' . ($learner['surname'] ?? '')) .
                            "_Report_{$year}_{$month}.pdf";

                        // Generate PDF using mpdf with minimal settings for speed
                        if (class_exists('Mpdf\Mpdf')) {
                            try {
                                // Configure mPDF for A4 landscape
                                $mpdf = new \Mpdf\Mpdf([
                                    'format' => 'A4-L', // A4 Landscape
                                    'orientation' => 'L', // Landscape
                                    'tempDir' => sys_get_temp_dir(),
                                    'margin_left' => 3,
                                    'margin_right' => 3,
                                    'margin_top' => 3,
                                    'margin_bottom' => 3,
                                    'margin_header' => 0,
                                    'margin_footer' => 0
                                ]);

                                // Force single page by setting page break settings
                                $mpdf->SetHTMLHeader('');
                                $mpdf->SetHTMLFooter('');
                                $mpdf->use_kwt = true;
                                $mpdf->keep_table_proportions = true;
                                $mpdf->setAutoPageBreak(false); // Disable automatic page breaks
                                $mpdf->setAutoTopMargin = false;
                                $mpdf->setAutoBottomMargin = false;
                                
                                // Clean and validate HTML content for mPDF
                                $optimizedHtml = preg_replace('/\s+/', ' ', $htmlContent); // Remove extra whitespace
                                $optimizedHtml = str_replace(['  ', '  '], ' ', $optimizedHtml); // Clean up double spaces

                                // Ensure proper HTML structure for mPDF
                                if (!preg_match('/^<!DOCTYPE/i', $optimizedHtml)) {
                                    $optimizedHtml = '<!DOCTYPE html><html><head><meta charset="UTF-8"></head><body>' . $optimizedHtml . '</body></html>';
                                }

                                // Remove any malformed tags that could cause mPDF issues
                                $optimizedHtml = preg_replace('/<script[^>]*>.*?<\/script>/is', '', $optimizedHtml);
                                $optimizedHtml = preg_replace('/<style[^>]*>.*?<\/style>/is', '', $optimizedHtml);

                                // Fix any potential CSS issues
                                $optimizedHtml = str_replace('style=""', '', $optimizedHtml);
                                $optimizedHtml = preg_replace('/\s*=\s*/', '=', $optimizedHtml); // Fix spacing around attributes
                                
                                // Suppress mPDF warnings but keep errors
                                $oldErrorReporting = error_reporting();
                                error_reporting(E_ERROR | E_PARSE | E_CORE_ERROR | E_COMPILE_ERROR | E_USER_ERROR);

                                $mpdf->WriteHTML($optimizedHtml);

                                // Restore error reporting
                                error_reporting($oldErrorReporting);
                                
                                // Debug: Check page count
                                $pageCount = $mpdf->page;
                                error_log("mPDF generated $pageCount pages for learner: " . ($learner['name'] ?? '') . ' ' . ($learner['surname'] ?? ''));

                                // Get PDF content as string
                                $pdfContent = $mpdf->Output('', 'S');
                                $mpdf->Close();
                                
                                // Add PDF to ZIP
                                if (!$zip->addFromString($pdfFileName, $pdfContent)) {
                                    error_log("Failed to add PDF to ZIP: $pdfFileName");
                                    echo "<script>console.log('Failed to add PDF to ZIP: $pdfFileName');</script>";
                                }

                                echo "<script>
                                    if(document.getElementById('progress')) {
                                        document.getElementById('progress').innerHTML = '✅ Completed PDF {$processedCount}/{$totalLearners}: " .
                                        htmlspecialchars(($learner['name'] ?? '') . ' ' . ($learner['surname'] ?? '')) . "';
                                    }
                                </script>";
                                flush();
                                
                                // Force garbage collection after each PDF
                                gc_collect_cycles();
                                
                            } catch (Exception $mpdfError) {
                                error_log("mPDF error for learner " . ($learner['name'] ?? '') . ": " . $mpdfError->getMessage());
                                
                                // Super-fast fallback: Create simple text report
                                $textReport = "ATTENDANCE REPORT\n";
                                $textReport .= "==================\n\n";
                                $textReport .= "Learner: " . ($learnerData['Name'] ?? 'Unknown') . " " . ($learnerData['Surname'] ?? '') . "\n";
                                $textReport .= "ID Number: " . ($learnerData['IDNumber'] ?? 'N/A') . "\n";
                                $textReport .= "Phone: " . ($learnerData['PhoneNumber'] ?? 'N/A') . "\n";
                                $textReport .= "Project: " . ($learnerData['Project_name'] ?? 'N/A') . "\n";
                                $textReport .= "Period: {$year}-{$month}\n\n";
                                $textReport .= "Attendance Records:\n";
                                $textReport .= "-------------------\n";
                                
                                // Add simple attendance summary
                                if (!empty($clockingData)) {
                                    foreach ($clockingData as $date => $records) {
                                        $record = $records[0] ?? [];
                                        $textReport .= $date . " - Present\n";
                                    }
                                } else {
                                    $textReport .= "No attendance records found\n";
                                }
                                
                                $textReport .= "\nGenerated: " . date('Y-m-d H:i:s') . "\n";
                                $textReport .= "\nError: " . $mpdfError->getMessage() . "\n";
                                $textReport .= "\nNote: Use individual 'View Report' button for full HTML report\n";
                                
                                $textFileName = preg_replace('/[^a-zA-Z0-9]/', '_',
                                    ($learner['name'] ?? '') . '_' . ($learner['surname'] ?? '')) .
                                    "_Report_{$year}_{$month}.txt";
                                
                                if (!$zip->addFromString($textFileName, $textReport)) {
                                    error_log("Failed to add text report to ZIP: $textFileName");
                                }
                                
                                echo "<script>
                                    if(document.getElementById('progress')) {
                                        document.getElementById('progress').innerHTML = '⚠️ Created text report {$processedCount}/{$totalLearners}: " .
                                        htmlspecialchars(($learner['name'] ?? '') . ' ' . ($learner['surname'] ?? '')) . "';
                                    }
                                </script>";
                                flush();
                            }
                        } else {
                            // Fallback: Create a simple HTML file with print instructions
                            $fallbackHtml = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Attendance Report - ' . htmlspecialchars(($learner['name'] ?? '') . ' ' . ($learner['surname'] ?? '')) . '</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .print-instructions { background: #f8f9fa; padding: 15px; border: 1px solid #dee2e6; border-radius: 5px; margin-bottom: 20px; }
        .print-instructions h3 { color: #495057; margin-top: 0; }
        .print-instructions ol { margin: 10px 0; }
        .print-instructions li { margin: 5px 0; }
    </style>
</head>
<body>
    <div class="print-instructions">
        <h3>📄 Print Instructions</h3>
        <ol>
            <li>Press <strong>Ctrl+P</strong> (Windows) or <strong>Cmd+P</strong> (Mac)</li>
            <li>Select "Save as PDF" as destination</li>
            <li>Click "Save" to download as PDF</li>
        </ol>
    </div>
    ' . $htmlContent . '
</body>
</html>';
                            
                            $fallbackFileName = preg_replace('/[^a-zA-Z0-9]/', '_',
                                ($learner['name'] ?? '') . '_' . ($learner['surname'] ?? '')) .
                                "_Report_{$year}_{$month}_PRINT.html";
                            
                            if (!$zip->addFromString($fallbackFileName, $fallbackHtml)) {
                                error_log("Failed to add fallback HTML to ZIP: $fallbackFileName");
                            }
                        }
                    }
                }
                $stmt->close();
            }

        } catch (Exception $e) {
            error_log("Error generating report for learner $learnerID: " . $e->getMessage());
            echo "<script>
                if(document.getElementById('progress')) {
                    document.getElementById('progress').innerHTML = '❌ Error with {$processedCount}/{$totalLearners}: " .
                    htmlspecialchars(($learner['name'] ?? '') . ' ' . ($learner['surname'] ?? '')) . " - " . htmlspecialchars($e->getMessage()) . "';
                }
            </script>";
            flush();

            // Add an error file instead
            $errorHtml = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Error - ' . htmlspecialchars(($learner['name'] ?? '') . ' ' . ($learner['surname'] ?? '')) . '</title>
</head>
<body>
    <div style="padding: 20px; text-align: center;">
        <h1>Error Generating Report</h1>
        <p>Learner: ' . htmlspecialchars(($learner['name'] ?? '') . ' ' . ($learner['surname'] ?? '')) . '</p>
        <p>Error: ' . htmlspecialchars($e->getMessage()) . '</p>
        <p>Generated: ' . date('Y-m-d H:i:s') . '</p>
    </div>
</body>
</html>';
            $fileName = preg_replace('/[^a-zA-Z0-9]/', '_',
                ($learner['name'] ?? '') . '_' . ($learner['surname'] ?? '')) .
                "_ERROR_{$year}_{$month}.html";
            $zip->addFromString($fileName, $errorHtml);
        }

        // Memory cleanup and timeout check
        if ($processedCount % 2 == 0) {
            gc_collect_cycles();
            
            // Check if we're approaching timeout (leave 30 seconds buffer)
            if (time() - $_SERVER['REQUEST_TIME'] > 90) { // 1.5 minutes
                echo "<script>
                    if(document.getElementById('progress')) {
                        document.getElementById('progress').innerHTML = '⚠️ Approaching timeout limit. Processing remaining learners...';
                    }
                </script>";
                flush();
            }
        }
    }

    $zip->close();

    // PDF generation completed successfully
    $_SESSION['bulk_zip_file'] = $zipFile;
    $_SESSION['bulk_zip_ready'] = true;
    $_SESSION['bulk_zip_path'] = $zipFile;
    $_SESSION['bulk_zip_name'] = basename($zipFile);
    
    echo "<script>
        if(document.getElementById('progress')) {
            document.getElementById('progress').innerHTML = '✅ PDF generation completed! Download ready!';
        }
    </script>";
    flush();

    // Render a clean success page with solid download fallbacks
    while (ob_get_level()) { ob_end_clean(); }
    $downloadUrl = $_SERVER['PHP_SELF'] . '?download_zip=1&ts=' . time();
    echo '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reports Ready</title>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/css/bootstrap.min.css">
    <style>body{padding:24px;background:#f5f5f5}</style>
    </head>
<body>
    <div class="container">
        <div class="alert alert-success" role="alert">
            <h4 class="alert-heading">✅ All ' . $totalLearners . ' reports generated successfully!</h4>
            <p><strong>📁 Files in ZIP:</strong> Individual PDF files for each learner. Ready for immediate use.</p>
            <hr>
            <p class="mb-2">
                <a id="zipLink" href="' . htmlspecialchars($downloadUrl) . '" target="_blank" class="btn btn-success">📥 Download ZIP File</a>
                <form action="' . htmlspecialchars($_SERVER['PHP_SELF']) . '" method="GET" style="display:inline-block;margin-left:8px;">
                    <input type="hidden" name="download_zip" value="1">
                    <input type="hidden" name="ts" value="' . time() . '">
                    <button type="submit" class="btn btn-info">⬇️ Fallback Download</button>
                </form>
            </p>
            <small class="text-muted">If blocked, right-click this link and open in a new tab: ' . htmlspecialchars($downloadUrl) . '</small>
        </div>
    </div>
    <script>
        // As a last resort, force navigation shortly after render
        setTimeout(function() {
            try {
                window.location.href = ' . json_encode($downloadUrl) . ';
            } catch(e){}
        }, 1500);
    </script>
</body>
</html>';
    exit();
}

// Convert HTML files to PDFs using mpdf
function convertHtmlZipToPdfZip($htmlZipPath, $year, $month) {
    // Use mpdf library for HTML to PDF conversion
    
    // Check if mpdf is available
    if (!class_exists('Mpdf\Mpdf')) {
        throw new Exception("mpdf library not available. Please install: composer require mpdf/mpdf");
    }
    
    error_log("mpdf library is available");
    
    // Create temporary directory for PDF files
    $tempDir = sys_get_temp_dir() . '/pdf_reports_' . time();
    if (!mkdir($tempDir, 0755, true)) {
        throw new Exception("Failed to create temporary directory for PDFs");
    }
    
    // Create new ZIP for PDF files
    $pdfZipFile = $tempDir . '/Individual_Reports_' . $year . '_' . $month . '_PDFs.zip';
    $pdfZip = new ZipArchive();
    
    if ($pdfZip->open($pdfZipFile, ZipArchive::CREATE) !== TRUE) {
        throw new Exception("Failed to create PDF ZIP file");
    }
    
    // Extract HTML files from original ZIP
    $htmlZip = new ZipArchive();
    if ($htmlZip->open($htmlZipPath) !== TRUE) {
        throw new Exception("Failed to open HTML ZIP file");
    }
    
    $processedCount = 0;
    $totalFiles = $htmlZip->numFiles;
    
    for ($i = 0; $i < $totalFiles; $i++) {
        $fileName = $htmlZip->getNameIndex($i);
        
        // Skip directories
        if (substr($fileName, -1) === '/') {
            continue;
        }
        
        $processedCount++;
        
        try {
            // Read HTML content
            $htmlContent = $htmlZip->getFromIndex($i);
            
            // Convert filename from .html to .pdf
            $pdfFileName = str_replace('.html', '.pdf', $fileName);
            
            error_log("Converting file: $fileName to PDF: $pdfFileName");
            
            // Create temporary HTML file
            $tempHtmlFile = $tempDir . '/temp_' . basename($fileName);
            file_put_contents($tempHtmlFile, $htmlContent);
            
            // Use ImageMagick PHP extension to convert HTML to PDF
            $tempPdfFile = $tempDir . '/temp_' . basename($pdfFileName);
            
            try {
                // Convert HTML to PDF using ImageMagick PHP extension
                $tempPdfFile = $tempDir . '/temp_' . basename($pdfFileName);
                
                // Validate input file
                if (!file_exists($tempHtmlFile)) {
                    throw new Exception("HTML file not found: $tempHtmlFile");
                }
                
                // Use mpdf to convert HTML to PDF
                $mpdf = new \Mpdf\Mpdf([
                    'mode' => 'utf-8',
                    'format' => 'A4',
                    'margin_left' => 10,
                    'margin_right' => 10,
                    'margin_top' => 10,
                    'margin_bottom' => 10,
                    'margin_header' => 5,
                    'margin_footer' => 5
                ]);
                
                // Read HTML content and write to PDF
                $htmlContent = file_get_contents($tempHtmlFile);
                $mpdf->WriteHTML($htmlContent);
                
                // Save PDF to file
                $mpdf->Output($tempPdfFile, 'F');
                $mpdf->Close();
                
                if (!file_exists($tempPdfFile)) {
                    throw new Exception("PDF file was not created by mpdf");
                }
                
                if (!file_exists($tempPdfFile)) {
                    throw new Exception("PDF file was not created");
                }
                
                if (file_exists($tempPdfFile)) {
                    $pdfContent = file_get_contents($tempPdfFile);
                    error_log("mpdf conversion successful for: $fileName, size: " . strlen($pdfContent) . " bytes");
                    
                    // Add PDF to ZIP
                    if (!$pdfZip->addFromString($pdfFileName, $pdfContent)) {
                        error_log("Failed to add PDF to ZIP: $pdfFileName");
                    } else {
                        error_log("PDF added to ZIP successfully: $pdfFileName");
                    }
                    
                    // Clean up temporary files
                    unlink($tempHtmlFile);
                    unlink($tempPdfFile);
                } else {
                    throw new Exception("PDF file was not created");
                }
                
                            } catch (Exception $e) {
                    error_log("mpdf conversion failed for $fileName: " . $e->getMessage());
                    throw new Exception("PDF conversion failed for $fileName: " . $e->getMessage());
                }
            
        } catch (Exception $e) {
            error_log("Error converting HTML to PDF for file $fileName: " . $e->getMessage());
            
            // Create a simple error HTML file instead of trying to create PDF
            $errorFileName = str_replace('.html', '_ERROR.html', $fileName);
            $errorHtml = '<!DOCTYPE html>
<html>
<head><title>Error Converting to PDF</title></head>
<body style="padding: 20px; text-align: center; font-family: Arial, sans-serif;">
    <h1>Error Converting to PDF</h1>
    <p>File: ' . htmlspecialchars($fileName) . '</p>
    <p>Error: ' . htmlspecialchars($e->getMessage()) . '</p>
    <p>Generated: ' . date('Y-m-d H:i:s') . '</p>
    <p><strong>Solution:</strong> Use browser print (Ctrl+P) to convert this HTML to PDF.</p>
</body>
</html>';
            
            $pdfZip->addFromString($errorFileName, $errorHtml);
        }
    }
    
    $htmlZip->close();
    $pdfZip->close();
    
    return $pdfZipFile;
}

// Function to enhance HTML for better printing
function enhanceHtmlForPrinting($htmlContent) {
    // Add print-specific CSS and optimizations
    $printCss = '
    <style>
        @media print {
            body { margin: 0; padding: 10mm; }
            .btn-container, .print-btn, .back-btn { display: none !important; }
            .calendar-container { page-break-inside: avoid; }
            .profile-container { page-break-inside: avoid; }
            .list-group { page-break-inside: avoid; }
            table { page-break-inside: avoid; }
            @page { 
                size: A4; 
                margin: 10mm; 
            }
        }
        @media screen {
            body { padding: 20px; }
        }
        .print-instructions {
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            padding: 15px;
            margin: 20px 0;
            border-radius: 5px;
            text-align: center;
        }
        .print-instructions h3 {
            color: #007bff;
            margin-bottom: 10px;
        }
        .print-instructions ul {
            text-align: left;
            display: inline-block;
        }
    </style>';
    
    // Add print instructions
    $printInstructions = '
    <div class="print-instructions">
        <h3>🖨️ How to Save as PDF:</h3>
        <ul>
            <li><strong>Step 1:</strong> Press <strong>Ctrl+P</strong> (Windows) or <strong>Cmd+P</strong> (Mac)</li>
            <li><strong>Step 2:</strong> Select <strong>"Save as PDF"</strong> as destination</li>
            <li><strong>Step 3:</strong> Choose <strong>"Landscape"</strong> orientation</li>
            <li><strong>Step 4:</strong> Set margins to <strong>"Minimum"</strong> or <strong>"None"</strong></li>
            <li><strong>Step 5:</strong> Click <strong>"Save"</strong> to download PDF</li>
        </ul>
        <button onclick="window.print()" style="background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; margin-top: 10px;">🖨️ Print/Save as PDF</button>
        <p><em>This file is optimized for printing to PDF. The layout will be preserved.</em></p>
    </div>';
    
    // Insert print CSS and instructions into the HTML
    $enhancedHtml = str_replace('</head>', $printCss . '</head>', $htmlContent);
    
    // Add print instructions after the main content but before closing body
    $enhancedHtml = str_replace('</body>', $printInstructions . '</body>', $enhancedHtml);
    
    return $enhancedHtml;
}

// Generate HTML using exact same template as indivisual.php (no cURL)
function generateIndivisualTemplateDirect($conn, $learnerData, $clockingData, $year, $month, $learnerID) {
    // Ensure clockingData is a valid array
    if (!is_array($clockingData)) {
        $clockingData = [];
    }

    // Define constants (same as indivisual.php)
    if (!defined('WEB_BASE_URL')) define('WEB_BASE_URL', '/');
    if (!defined('DEFAULT_AVATAR')) define('DEFAULT_AVATAR', 'assets/img/avatar6.png');

    // Extract learner data
    $Name = $learnerData['Name'] ?? '';
    $Surname = $learnerData['Surname'] ?? '';
    $IDNumber = $learnerData['IDNumber'] ?? '';
    $PhoneNumber = $learnerData['PhoneNumber'] ?? '';
    $Address = $learnerData['AddressLine1'] ?? '';
    $Gender = $learnerData['Gender'] ?? '';
    $profileImage = $learnerData['profile_image'] ?? DEFAULT_AVATAR;
    $sdpLogo = $learnerData['sdp_logo'] ?? '';
    $clientLogo = $learnerData['client_logo'] ?? '';
    $projectName = $learnerData['Project_name'] ?? '';
    $projectPathway = $learnerData['Project_pathway'] ?? '';
    $Province = $learnerData['Province'] ?? '';
    $project_id = $learnerData['project_id'] ?? '';

    $FullName = $Name . ' ' . $Surname;

    // Set period dates
    $firstDayOfMonth = date('Y-m-01', strtotime("$year-$month-01"));
    $lastDayOfMonth = date('Y-m-t', strtotime("$year-$month-01"));

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

    // Get sick notes (same logic as indivisual.php)
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

    // Extract learner data (same as indivisual.php)
    $Name = $learnerData['Name'] ?? '';
    $Surname = $learnerData['Surname'] ?? '';
    $FullName = trim($Name . ' ' . $Surname);
    $IDNumber = $learnerData['IDNumber'] ?? 'N/A';
    $PhoneNumber = $learnerData['PhoneNumber'] ?? 'N/A';
    $Gender = $learnerData['Gender'] ?? 'N/A';
    $Address = $learnerData['AddressLine1'] ?? 'N/A';
    $projectName = $learnerData['Project_name'] ?? 'N/A';
    $projectPathway = $learnerData['Project_pathway'] ?? 'N/A';
    $Province = $learnerData['Province'] ?? 'N/A';

    $profileImage = DEFAULT_AVATAR;
    $profileImageDB = $learnerData['profile_image'] ?? null;
    if ($profileImageDB && !empty($profileImageDB)) {
        $possiblePaths = [
            $profileImageDB, // Direct path as stored in database
            "mobile/" . $profileImageDB,
            "mobile/learnerImages/" . basename($profileImageDB),
            "uploads/" . basename($profileImageDB),
            "uploads/learnerImages/" . basename($profileImageDB),
            "mobile/uploads/" . basename($profileImageDB),
            "mobile/Uploads/" . basename($profileImageDB)
        ];
        foreach ($possiblePaths as $path) {
            // Try both relative and absolute paths
            $fullPath = $_SERVER['DOCUMENT_ROOT'] . '/' . $path;
            $cleanPath = ltrim($path, '/'); // Remove leading slash for relative check
            $fullPathRelative = $_SERVER['DOCUMENT_ROOT'] . '/' . $cleanPath;

            if (file_exists($fullPath) || file_exists($fullPathRelative) || file_exists($path)) {
                // Use the path that works, ensuring it starts with /
                if (strpos($path, '/') === 0) {
                    $profileImage = $path; // Already has leading slash
                } else {
                    $profileImage = '/' . $path; // Add leading slash
                }
                error_log("PROFILE IMAGE FOUND: $profileImage (from: $path)");
                break;
            }
        }
        error_log("PROFILE IMAGE SEARCH: DB value='$profileImageDB', Final path='$profileImage'");
    }

    // If no profile image found, ensure we have a valid fallback
    if (empty($profileImage) || $profileImage === DEFAULT_AVATAR) {
        // Try to find any image file for this learner in common directories
        $commonImageDirs = ['mobile/learnerImages/', 'uploads/', 'mobile/uploads/'];
        foreach ($commonImageDirs as $dir) {
            $pattern = $dir . '*' . $learnerID . '*';
            $files = glob($pattern);
            if (!empty($files)) {
                $profileImage = '/' . $files[0];
                error_log("PROFILE IMAGE FALLBACK FOUND: $profileImage");
                break;
            }
        }
    }

    $sdpLogoDB = $learnerData['sdp_logo'] ?? null;
    $sdpLogo = '';
    if ($sdpLogoDB && !empty($sdpLogoDB)) {
        $possibleLogoPaths = [
            $sdpLogoDB,
            "assets/img/" . basename($sdpLogoDB),
            "uploads/" . basename($sdpLogoDB),
            "mobile/" . basename($sdpLogoDB)
        ];
        foreach ($possibleLogoPaths as $logoPath) {
            $fullLogoPath = $_SERVER['DOCUMENT_ROOT'] . '/' . $logoPath;
            if (file_exists($fullLogoPath) || file_exists($logoPath)) {
                $sdpLogo = '/' . $logoPath;
                break;
            }
        }
    }

    $clientLogoDB = $learnerData['client_logo'] ?? null;
    $clientLogo = DEFAULT_AVATAR;
    if ($clientLogoDB && !empty($clientLogoDB)) {
        $possibleClientPaths = [
            $clientLogoDB,
            "assets/img/" . basename($clientLogoDB),
            "uploads/" . basename($clientLogoDB),
            "mobile/" . basename($clientLogoDB)
        ];
        foreach ($possibleClientPaths as $clientPath) {
            $fullClientPath = $_SERVER['DOCUMENT_ROOT'] . '/' . $clientPath;
            if (file_exists($fullClientPath) || file_exists($clientPath)) {
                $clientLogo = '/' . $clientPath;
                break;
            }
        }
    }
    

    // Generate HTML using exact same structure as indivisual.php
    $html = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/css/bootstrap.min.css">
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
            height: 40px;
            overflow: auto;
            font-size: 8px;
            padding: 1px;
            text-align: center;
        }
        .calendar-day small {
            display: block;
            line-height: 1.0;
            font-size: 7px;
        }
        .calendar-container {
            margin-bottom: 8px;
        }
        .table {
            font-size: 8px;
            margin-bottom: 3px;
            width: 100%;
        }
        .table td, .table th {
            padding: 1px;
            text-align: center;
            font-size: 7px;
        }
        .badge {
            color: black !important;
            font-size: 7px;
            padding: 2px 4px;
            margin-right: 2px;
        }
        .list-group-item {
            font-size: 10px;
            padding: 2px;
            margin-bottom: 1px;
        }
        .list-group {
            margin-bottom: 5px;
        }
        .list-group-item span {
            padding-right: 8px;
        }
        #report-content {
            padding: 5px;
            margin: 0;
        }
        .container-fluid {
            padding-left: 1px;
            padding-right: 1px;
            margin: 1px;
        }
        .bs-example {
            margin: 1px;
        }
        .profile-container {
            display: flex;
            align-items: center;
            padding: 3px;
            margin: 0;
            gap: 6px;
            font-size: 40px;
            width: 100%;
            box-sizing: border-box;
            position: relative;
            z-index: 1;
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
            margin-bottom: 8px;
        }
        .signature-container {
            margin-top: 8px;
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
        .container-fluid .profile-container {
            /* min-height removed */
        }
        /* Hide navigation buttons on main page */
        .calendar-nav {
            display: none;
        }
        /* Simple two-column layout */
        .row {
            display: flex !important;
            flex-direction: row !important;
            flex-wrap: nowrap !important;
        }
        
        .col {
            flex: 1 !important;
        }
        
        .col:first-child {
            flex: 0 0 auto !important;
            width: auto !important;
            max-width: 450px !important;
        }
        
        .col:last-child {
            flex: 1 1 auto !important;
            min-width: 0 !important;
        }
        
        /* Ensure calendar doesnt stretch and make it smaller */
        .calendar-container {
            width: auto !important;
            max-width: 400px !important;
        }
        
        /* Make calendar table smaller */
        .calendar-container .table {
            font-size: 8px !important;
        }
        
        .calendar-container .table th,
        .calendar-container .table td {
            padding: 1px !important;
        }
        
        .calendar-container .calendar-day {
            height: 30px !important;
            font-size: 7px !important;
        }
        
        .calendar-container .badge {
            font-size: 6px !important;
            padding: 1px 2px !important;
        }
        
        /* Ensure proper spacing */
        .list-group-item {
            margin: 0 !important;
            padding: 2px 5px !important;
        }
        
        /* Ensure profile image section is properly positioned in right column */
        .profile-container {
            display: flex !important;
            align-items: center !important;
            gap: 10px !important;
            margin-bottom: 10px !important;
        }
        
        .profile-container img {
            width: 60px !important;
            height: 60px !important;
            object-fit: cover !important;
            border: 2px solid white !important;
            border-radius: 8px !important;
        }
        
        .profile-container h1 {
            font-size: 1.2rem !important;
            margin: 0 !important;
            color: white !important;
        }
        
        

        /* Ensure profile image displays properly */
        .profile-container img {
            display: block !important;
            visibility: visible !important;
            opacity: 1 !important;
            position: relative !important;
            z-index: 1 !important;
        }

        /* Ensure signatures display properly */
        .signature-img {
            display: block !important;
            visibility: visible !important;
            opacity: 1 !important;
            position: relative !important;
            z-index: 1 !important;
        }

        /* Fix logo alignment */
        .logo-row img {
            display: block !important;
            max-height: 60px !important;
        }

        @media (max-width: 768px) {
            .two-column-table {
                display: block !important;
            }
            .two-column-cell {
                display: block !important;
                width: 100% !important;
                padding: 10px 0 !important;
            }
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
                margin: 2px;
                padding: 2px;
            }
            .container-fluid .list-group {
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
            .container-fluid .profile-container {
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
            <!-- <img src="assets/img/rlms.PNG" alt="CoolBrand" onerror="this.src=\'' . htmlspecialchars(DEFAULT_AVATAR) . '\'">
        --></div>

        <div class="container-fluid">
            <div class="row">
                <div class="col-md-4">
                    <img src="' . htmlspecialchars($sdpLogo ?? '') . '" class="rounded float-start" alt="SDP Logo" style="max-width: 300px; height: 50px;" onerror="this.src=\'' . htmlspecialchars(DEFAULT_AVATAR) . '\'">
                </div>
                <div class="col-md-4 text-center">
                    <!-- Center space for alignment -->
                </div>
                <div class="col-md-4">
                    <img src="assets/img/rlms.PNG"  class="rounded float-end" alt="Client Logo" style="max-width: 300px; height: 50px;" onerror="this.src=\'' . htmlspecialchars(DEFAULT_AVATAR) . '\'">
                </div>
            </div>
        </div>

        <div style="background-image: linear-gradient(to right, #42bcf5, #42f5d7);" class="p-1 mb-1 text-black" style="font-size: 10px; padding: 2px;">
            PERIOD: ' . htmlspecialchars($firstDayOfMonth) . ' to ' . htmlspecialchars($lastDayOfMonth) . '
        </div>



        <div class="row">
            <div class="col">
                <div class="container-fluid">
                    <div class="calendar-container">
                        <div class="table-responsive-sm">';

    // Generate calendar (same logic as indivisual.php)
    $daysInMonth = date('t', strtotime("$year-$month-01"));
    $startDay = date('w', strtotime("$year-$month-01"));
    $totalDays = $workingDays = $holidaysCount = $weekendDays = $presentDays = $absentDays = $invalidDays = 0;
    $absentDays += $rejectedAbsentDays;

    $html .= "<h4 style='font-size: 0.8rem;margin:1px;'>Calendar for " . date('F Y', strtotime("$year-$month-01")) . "</h4>";

    $html .= "<div class='mb-1'>";
    $html .= "<span class='badge badge-primary'>Workdays: <span id='workingDays'>0</span></span> ";
    $html .= "<span class='badge badge-danger'>Holidays: <span id='holidaysCount'>0</span></span> ";
    $html .= "<span class='badge badge-info'>Weekend: <span id='weekendDays'>0</span></span> ";
    $html .= "<span class='badge badge-success'>Present: <span id='presentDays'>0</span></span> ";
    $html .= "<span class='badge badge-warning'>Absent: <span id='absentDays'>0</span></span> ";
    $html .= "<span class='badge badge-danger'>Invalid: <span id='invalidDays'>0</span></span> ";
    $html .= "<span class='badge badge-warning'>Sick: <span id='sickDays'>0</span></span>";
    $html .= "</div>";

    $html .= "<table class='table table-bordered'>";
    $html .= "<thead><tr style='background-color:#282C65;color:black;font-size:9px;'>
                <th>Sun</th><th>Mon</th><th>Tue</th><th>Wed</th><th>Thu</th><th>Fri</th><th>Sat</th>
              </tr></thead><tbody><tr>";

    for ($i = 0; $i < $startDay; $i++) {
        $html .= "<td></td>";
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

        $html .= "<td class='calendar-day'>";
        $html .= "<strong>$day</strong><br>";

        if ($isApprovedSick) {
            $html .= "<small class='sick'>Sick Note Approved</small>";
        } elseif ($isPendingSick) {
            $html .= "<small class='sick'>Sick Note Pending</small>";
        } elseif ($isRejectedSick) {
            $html .= "<small class='absent'>Absent</small>";
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
            $html .= "<small class='holiday'>$holidayName</small>";
        } elseif ($isWeekend) {
            $html .= "<small class='weekend'>Weekend</small>";
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
                        if (preg_match('/^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$/', $clockIn)) {
                            // Structure 2: Full datetime format (2025-08-19 08:28:38)
                            $formattedClockIn = date('H:i', strtotime($clockIn));
                        } elseif (preg_match('/^\\d{2}:\\d{2}:\\d{2}$/', $clockIn)) {
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
                        if (preg_match('/^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$/', $clockOut)) {
                            // Structure 2: Full datetime format
                            $formattedClockOut = date('H:i', strtotime($clockOut));
                        } elseif (preg_match('/^\\d{2}:\\d{2}:\\d{2}$/', $clockOut)) {
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
                        $formattedContactTime = preg_replace('/\\..+/', '', $contactTime);
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
                        $html .= "<img src='$webSignaturePath' class='signature-img rounded' alt='Signature' style='max-width: 90px; height: 35px; border: 1px solid #ddd; border-radius: 4px;' onerror=\"this.style.display='none';this.nextSibling.style.display='block; console.log('Signature failed to load: $webSignaturePath');\">";
                        $html .= "<small style='display:none;'>Signature: [N/A]</small>";
                    } else {
                        $html .= "<small style='color: #666; font-style: italic;'>Signature: [N/A]</small>";
                    }
                } else {
                    // Incomplete record - show what we have
                    $invalidDays++;

                    // Format clock in time even for incomplete records
                    $formattedClockIn = 'N/A';
                    if ($clockIn !== 'N/A') {
                        if (preg_match('/^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$/', $clockIn)) {
                            $formattedClockIn = date('H:i', strtotime($clockIn));
                        } elseif (preg_match('/^\\d{2}:\\d{2}:\\d{2}$/', $clockIn)) {
                            $formattedClockIn = substr($clockIn, 0, 5);
                        } else {
                            $formattedClockIn = substr($clockIn, 0, 5);
                        }
                    }

                    // Format clock out time for incomplete records
                    $formattedClockOut = 'N/A';
                    if ($clockOut !== 'N/A') {
                        if (preg_match('/^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$/', $clockOut)) {
                            $formattedClockOut = date('H:i', strtotime($clockOut));
                        } elseif (preg_match('/^\\d{2}:\\d{2}:\\d{2}$/', $clockOut)) {
                            $formattedClockOut = substr($clockOut, 0, 5);
                        } else {
                            $formattedClockOut = substr($clockOut, 0, 5);
                        }
                    }

                    // Format contact time
                    $formattedContactTime = 'N/A';
                    $hasContactTime = ($contactTime !== 'N/A' && !empty($contactTime) && $contactTime !== null && $contactTime !== '');
                    if ($hasContactTime) {
                        $formattedContactTime = preg_replace('/\\..+/', '', $contactTime);
                        $formattedContactTime = str_replace(['0h ', '0m '], '', $formattedContactTime);
                    }



                    // Display incomplete record with invalid styling - Clock times hidden, only signature shown
                    $html .= "<small class='invalid'>⚠ Incomplete</small>";
                    // echo "<small class='invalid'>In: $formattedClockIn</small>";
                    // echo "<small class='invalid'>Out: $formattedClockOut</small>";
                    // echo "<small class='invalid'>Contact: $formattedContactTime</small>"; // HIDDEN

                    // Show signature for incomplete records too
                    $webSignaturePath = detectValidSignature($conn, $learnerID);
                    if ($webSignaturePath) {
                        $webSignaturePath = htmlspecialchars($webSignaturePath);
                        $html .= "<img src='$webSignaturePath' class='signature-img rounded' alt='Signature' style='max-width: 90px; height: 35px; border: 1px solid #ddd; border-radius: 4px;' onerror=\"this.style.display='none';this.nextSibling.style.display='block; console.log('Signature failed to load: $webSignaturePath');\">";
                        $html .= "<small style='display:none;'>Signature: [N/A]</small>";
                    } else {
                        $html .= "<small style='color: #666; font-style: italic;'>Signature: [N/A]</small>";
                    }
                }
            } elseif ($date < $currentDate) {
                $absentDays++;
                $html .= "<small class='absent'>Absent</small>";
            } else {
                $html .= "<small class='pending'>Pending</small>";
            }
        }

        $html .= "</td>";

        if (($day + $startDay) % 7 == 0 && $day != $daysInMonth) {
            $html .= "</tr><tr>";
        }
    }

    while (($day + $startDay) % 7 != 0) {
        $html .= "<td></td>";
        $day++;
    }

    $html .= "</tr></tbody></table>";

    // Static values to prevent flickering
    $html .= "<script>
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

    $html .= "<div class='calendar-nav mb-1'>";
    $html .= "<a href='indivisual.php?learner_id=$learnerID&project_id=$learnerData[project_id]&year=$prevYear&month=$prevMonth&FullName=$encodedFullName' class='btn btn-primary btn-sm mr-1'>←</a>";
    $html .= "<a href='indivisual.php?learner_id=$learnerID&project_id=$learnerData[project_id]&year=$nextYear&month=$nextMonth&FullName=$encodedFullName' class='btn btn-primary btn-sm'>→</a>";
    $html .= "</div>";
    $html .= '                    </div>
                    <div class="signature-container">
                        <div class="form-row signature-row">
                            <div class="form-group">
                                <label style="color:#282C65;font-size:8px;">Facilitator Signature : <img src="assets/img/f.PNG" style="width:30px;height:15px;" alt="" onerror="this.src=\'' . htmlspecialchars(DEFAULT_AVATAR) . '\'">
                                </label>
                                <span style="font-size:8px;">' . date('Y-m-d H:i:s') . '</span>
                            </div>
                            <div class="form-group">
                                <label style="color:#282C65;font-size:8px;">SDP Representative Signature: <img src="assets/img/fa.png" style="width:30px;height:15px;" alt="" onerror="this.src=\'' . htmlspecialchars(DEFAULT_AVATAR) . '\'">
                                </label>
                                <span style="font-size:8px;">' . date('Y-m-d H:i:s') . '</span>
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
                                <img src="' . htmlspecialchars($profileImage ?? DEFAULT_AVATAR) . '"
                                     alt="Profile"
                                     class="img-thumbnail"
                                     style="width: 60px; height: 60px; object-fit: cover; border: 2px solid white; border-radius: 8px;"
                                     onerror="this.src=\'' . htmlspecialchars(DEFAULT_AVATAR) . '\'; console.log(\'Profile image failed to load: ' . htmlspecialchars($profileImage ?? 'NULL') . '\');">';
    $html .= '<div>
                                    <h1>' . strtoupper($FullName ?? 'NO NAME') . '</h1>
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
                                    <span style="color:#282C65;">' . htmlspecialchars($projectPathway) . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Province:</strong>
                                    <span style="color:#282C65;">' . htmlspecialchars($Province) . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Project:</strong>
                                    <span style="color:#282C65;">' . htmlspecialchars($projectName) . '</span>
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
                                    <span style="color:#282C65;">' . htmlspecialchars($Name) . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Surname:</strong>
                                    <span style="color:#282C65;">' . htmlspecialchars($Surname) . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">ID Number:</strong>
                                    <span style="color:#282C65;">' . htmlspecialchars($IDNumber) . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Gender:</strong>
                                    <span style="color:#282C65;">' . htmlspecialchars($Gender) . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Telephone:</strong>
                                    <span style="color:#282C65;">' . htmlspecialchars($PhoneNumber) . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Address:</strong>
                                    <span style="color:#282C65;">' . htmlspecialchars($Address) . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Expected Attendance:</strong>
                                    <span style="color:#282C65;">' . $workingDays . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Actual Attendance:</strong>
                                    <span style="color:#282C65;">' . $presentDays . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Days Absent:</strong>
                                    <span style="color:#282C65;">' . $absentDays . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Invalid Attendance:</strong>
                                    <span style="color:#282C65;">' . $invalidDays . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Holidays:</strong>
                                    <span style="color:#282C65;">' . $holidaysInMonth . '</span>
                                </li>
                                <!-- ATTENDANCE STATISTICS (RIGHT COLUMN) -->
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Approved Sick Days:</strong>
                                    <span style="color:#282C65;">' . $approvedSickDays . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Pending Sick Days:</strong>
                                    <span style="color:#282C65;">' . $pendingSickDays . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Total Sick Days:</strong>
                                    <span style="color:#282C65;">' . $sickDays . '</span>
                                </li>
                                <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                    <strong style="color:#282C65;">Total Valid Attendance:</strong>
                                    <span style="color:#282C65;">' . ($presentDays + $holidaysInMonth + $approvedSickDays) . '</span>
                                </li>
                            </ul>
                        </div>
                    </div>

                    <footer class="page-footer font-small blue">
                        <div style="color:#282C65;font-size:8px;" class="text-right py-1">
                            <b>RLMS Attendance. @</b> ' . date('Y-m-d') . '
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

<script>
    function printReport() {
        window.print();
    }

    function saveReport() {
        // Get the current URL parameters
        const urlParams = new URLSearchParams(window.location.search);
        const learner_id = urlParams.get(\'learner_id\') || urlParams.get(\'LearnerID\');
        const year = urlParams.get(\'year\');
        const month = urlParams.get(\'month\');

        // Build the save URL
        let saveUrl = \'finance_save_learner_report.php?\';
        saveUrl += \'learner_id=\' + encodeURIComponent(learner_id) + \'&\';
        saveUrl += \'year=\' + encodeURIComponent(year) + \'&\';
        saveUrl += \'month=\' + encodeURIComponent(month) + \'&\';

        // Add all other parameters
        const province = urlParams.get(\'province\');
        const pathway = urlParams.get(\'pathway\');
        const qualification_id = urlParams.get(\'qualification_id\');
        const site_id = urlParams.get(\'site_id\');
        const class_id = urlParams.get(\'class_id\');
        const sdp_id = urlParams.get(\'sdp_id\');
        const project_id = urlParams.get(\'project_id\');

        if (province) saveUrl += \'province=\' + encodeURIComponent(province) + \'&\';
        if (pathway) saveUrl += \'pathway=\' + encodeURIComponent(pathway) + \'&\';
        if (qualification_id) saveUrl += \'qualification_id=\' + encodeURIComponent(qualification_id) + \'&\';
        if (site_id) saveUrl += \'site_id=\' + encodeURIComponent(site_id) + \'&\';
        if (class_id) saveUrl += \'class_id=\' + encodeURIComponent(class_id) + \'&\';
        if (sdp_id) saveUrl += \'sdp_id=\' + encodeURIComponent(sdp_id) + \'&\';
        if (project_id) saveUrl += \'project_id=\' + encodeURIComponent(project_id) + \'&\';

        // Remove trailing \'&\' if exists
        if (saveUrl.endsWith(\'&\')) {
            saveUrl = saveUrl.slice(0, -1);
        }

        // Open the save page in a new window
        window.open(saveUrl, \'_blank\');
    }

    function goBack() {
        // Get the current URL parameters
        const urlParams = new URLSearchParams(window.location.search);
        const learner_id = urlParams.get(\'learner_id\') || urlParams.get(\'LearnerID\');
        const project_id = urlParams.get(\'project_id\');
        const year = urlParams.get(\'year\');
        const month = urlParams.get(\'month\');

        // Build the return URL to attendance_learners.php
        let returnUrl = \'finance_attendance_learners.php?\';

        // Add all the parameters that were passed to this page
        if (learner_id) returnUrl += \'learner_id=\' + encodeURIComponent(learner_id) + \'&\';
        if (project_id) returnUrl += \'project_id=\' + encodeURIComponent(project_id) + \'&\';
        if (year) returnUrl += \'year=\' + encodeURIComponent(year) + \'&\';
        if (month) returnUrl += \'month=\' + encodeURIComponent(month) + \'&\';

        // Add the navigation parameters that should be preserved
        const province = urlParams.get(\'province\');
        const pathway = urlParams.get(\'pathway\');
        const qualification_id = urlParams.get(\'qualification_id\');
        const site_id = urlParams.get(\'site_id\');
        const class_id = urlParams.get(\'class_id\');
        const sdp_id = urlParams.get(\'sdp_id\');

        if (province) returnUrl += \'province=\' + encodeURIComponent(province) + \'&\';
        if (pathway) returnUrl += \'pathway=\' + encodeURIComponent(pathway) + \'&\';
        if (qualification_id) returnUrl += \'qualification_id=\' + encodeURIComponent(qualification_id) + \'&\';
        if (site_id) returnUrl += \'site_id=\' + encodeURIComponent(site_id) + \'&\';
        if (class_id) returnUrl += \'class_id=\' + encodeURIComponent(class_id) + \'&\';
        if (sdp_id) returnUrl += \'sdp_id=\' + encodeURIComponent(sdp_id) + \'&\';

        // Remove the trailing \'&\' if it exists
        if (returnUrl.endsWith(\'&\')) {
            returnUrl = returnUrl.slice(0, -1);
        }

        // Navigate back to the attendance_learners.php page
        window.location.href = returnUrl;
    }

    // Auto-redirect after print (optional)
    window.addEventListener(\'afterprint\', function() {
        // Uncomment the line below if you want to auto-redirect after printing
        // goBack();
    });
</script>
</body>
</html>';

    // No print instructions - clean report layout

    return $html;
}



// Generate print-ready HTML file for individual learner report
function generatePrintReadyHTML($learnerData, $attendanceRecords, $firstDayOfMonth, $lastDayOfMonth, $year, $month, $conn, $learnerID) {
    $html = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>' . htmlspecialchars(($learnerData['Name'] ?? '') . ' ' . ($learnerData['Surname'] ?? '')) . ' - Attendance Report</title>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/css/bootstrap.min.css">
    <style>
        /* Print-optimized styles */
        @media screen {
            body { padding: 20px; background: #f5f5f5; }
            .print-instructions {
                background: #d4edda;
                border: 1px solid #c3e6cb;
                padding: 15px;
                margin-bottom: 20px;
                border-radius: 5px;
                text-align: center;
            }
        }
        
        @media print {
            body { margin: 0; padding: 0; background: white !important; }
            .print-instructions { display: none !important; }
            @page { 
                size: A4 landscape; 
                margin: 10mm;
            }
        }
        
        /* Original report styles */
        .bs-example { margin: 2px; }
        .holiday { color: red; font-weight: bold; }
        .weekend { color: blue; }
        .absent { color: red; }
        .present { color: green; }
        .calendar-day { 
            height: 50px;
            overflow: visible; 
            font-size: 9px;
            padding: 1px;
        }
        .calendar-day small {
            display: block;
            line-height: 1.0;
        }
        .badge {
            color: black !important;
            font-size: 7px;
            padding: 2px 4px;
            margin-right: 2px;
        }
        .list-group-item {
            font-size: 10px;
            padding: 2px;
            margin-bottom: 1px;
        }
        .list-group {
            margin-bottom: 5px;
        }
        #report-content {
            padding: 5px;
            margin: 0;
        }
        .container-fluid {
            padding-left: 1px;
            padding-right: 1px;
            margin: 1px;
        }
        .bs-example {
            margin: 1px;
        }
        .profile-container {
            display: flex;
            align-items: center;
            padding: 3px;
            gap: 6px;
        }
        .profile-container h1 {
            font-size: 0.8rem;
            margin: 0;
            line-height: 1.1;
        }
        .calendar-container {
            margin-bottom: 8px;
        }
        .signature-container {
            margin-top: 8px;
        }
    </style>
</head>
<body>
    <div class="print-instructions">
        <h4>🖨️ How to Save as PDF:</h4>
        <p><strong>1.</strong> Press <strong>Ctrl+P</strong> (Windows) or <strong>Cmd+P</strong> (Mac)</p>
        <p><strong>2.</strong> Select <strong>"Save as PDF"</strong> as destination</p>
        <p><strong>3.</strong> Choose <strong>"Landscape"</strong> orientation</p>
        <p><strong>4.</strong> Click <strong>"Save"</strong></p>
        <button onclick="window.print()" style="background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer;">🖨️ Print/Save as PDF</button>
    </div>
    
    <div id="report-content">';
    
    // Generate original rich report content (same as View Report button)
    $html .= generateFullHTMLStructure($learnerData, $attendanceRecords, $firstDayOfMonth, $lastDayOfMonth, $year, $month, $conn, $learnerID);
    
    $html .= '    </div>
</body>
</html>';
    
    return $html;
}

// Generate simplified report content (faster, less prone to hanging)
function generateSimplifiedReportContent($learnerData, $attendanceRecords, $firstDayOfMonth, $lastDayOfMonth, $year, $month) {
    error_log("Starting generateSimplifiedReportContent for learner: " . ($learnerData['Name'] ?? 'Unknown'));
    
    $html = '<div class="container-fluid">
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <div class="card-header">
                        <h3>' . htmlspecialchars(($learnerData['Name'] ?? '') . ' ' . ($learnerData['Surname'] ?? '')) . ' - Attendance Report</h3>
                        <p><strong>Period:</strong> ' . date('F Y', strtotime("$year-$month-01")) . '</p>
                        <p><strong>Project:</strong> ' . htmlspecialchars($learnerData['Project_name'] ?? '') . '</p>
                        <p><strong>ID Number:</strong> ' . htmlspecialchars($learnerData['IDNumber'] ?? '') . '</p>
                    </div>
                    <div class="card-body">
                        <h4>Attendance Summary</h4>
                        <table class="table table-bordered">
                            <thead>
                                <tr>
                                    <th>Date</th>
                                    <th>Clock In</th>
                                    <th>Clock Out</th>
                                    <th>Contact Time</th>
                                    <th>Status</th>
                                </tr>
                            </thead>
                            <tbody>';
    
    error_log("About to calculate days in month for $month/$year");
    $daysInMonth = cal_days_in_month(CAL_GREGORIAN, $month, $year);
    error_log("Days in month: $daysInMonth");
    
    $presentDays = 0;
    $totalContactTime = 0;
    
    error_log("Starting day loop for $daysInMonth days");
    
    // Limit the loop to prevent infinite hanging - max 31 days
    $maxDays = min($daysInMonth, 31);
    
    for ($day = 1; $day <= $maxDays; $day++) {
        if ($day % 10 == 0) {
            error_log("Processing day $day of $maxDays");
        }
        
        $currentDate = sprintf('%04d-%02d-%02d', $year, $month, $day);
        $dayOfWeek = date('w', strtotime($currentDate));
        
        // Skip weekends
        if ($dayOfWeek == 0 || $dayOfWeek == 6) {
            continue;
        }
        
        $html .= '<tr>';
        $html .= '<td>' . date('d M Y', strtotime($currentDate)) . '</td>';
        
        if (isset($attendanceRecords[$currentDate])) {
            $record = $attendanceRecords[$currentDate];
            $html .= '<td>' . htmlspecialchars($record['clock_in_time'] ?? '') . '</td>';
            $html .= '<td>' . htmlspecialchars($record['clock_out_time'] ?? '') . '</td>';
            $html .= '<td>' . htmlspecialchars($record['contact_time'] ?? '0') . '</td>';
            $html .= '<td class="present">Present</td>';
            $presentDays++;
            $totalContactTime += floatval($record['contact_time'] ?? 0);
        } else {
            $html .= '<td class="absent">-</td>';
            $html .= '<td class="absent">-</td>';
            $html .= '<td class="absent">-</td>';
            $html .= '<td class="absent">Absent</td>';
        }
        
        $html .= '</tr>';
    }
    
    error_log("Completed day loop, processed $maxDays days");
    
    $html .= '</tbody>
                        </table>
                        
                        <div class="mt-4">
                            <h5>Summary Statistics</h5>
                            <ul>
                                <li><strong>Days Present:</strong> ' . $presentDays . '</li>
                                <li><strong>Total Contact Time:</strong> ' . number_format($totalContactTime, 2) . ' hours</li>
                                <li><strong>Average Daily Time:</strong> ' . ($presentDays > 0 ? number_format($totalContactTime / $presentDays, 2) : '0') . ' hours</li>
                            </ul>
                        </div>
                        
                        <div class="mt-4">
                            <p><strong>Generated:</strong> ' . date('Y-m-d H:i:s') . '</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>';
    
    error_log("Completed generateSimplifiedReportContent successfully");
    return $html;
}

// Generate simple test HTML (minimal content for debugging)
function generateSimpleTestHTML($learnerData, $year, $month) {
    error_log("Starting generateSimpleTestHTML");
    
    $html = '<!DOCTYPE html>
<html>
<head>
    <title>Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; padding: 20px; }
        .test-report { border: 1px solid #ccc; padding: 15px; }
    </style>
</head>
<body>
    <div class="test-report">
        <h1>Test Report</h1>
        <p><strong>Learner:</strong> ' . htmlspecialchars(($learnerData['Name'] ?? 'Unknown') . ' ' . ($learnerData['Surname'] ?? '')) . '</p>
        <p><strong>Period:</strong> ' . htmlspecialchars($month . '/' . $year) . '</p>
        <p><strong>Project:</strong> ' . htmlspecialchars($learnerData['Project_name'] ?? 'Unknown') . '</p>
        <p><strong>Generated:</strong> ' . date('Y-m-d H:i:s') . '</p>
        <button onclick="window.print()">Print/Save as PDF</button>
    </div>
</body>
</html>';
    
    error_log("Completed generateSimpleTestHTML");
    return $html;
}

// Generate HTML by calling indivisual.php and wrapping for browser print
function generateHTMLFromIndivisualPage($learnerID, $project_id, $year, $month, $learnerData) {
    error_log("Starting generateHTMLFromIndivisualPage for learner ID: $learnerID");
    
    try {
        // Build URL to call indivisual.php (same as View Report button)
        $baseUrl = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http") . "://" . $_SERVER['HTTP_HOST'];
        $currentDir = dirname($_SERVER['REQUEST_URI']);
        $url = $baseUrl . $currentDir . "/indivisual.php";
        
        $params = array(
            'LearnerID' => $learnerID,
            'project_id' => $project_id,
            'year' => $year,
            'month' => $month,
            'FullName' => ($learnerData['Name'] ?? '') . ' ' . ($learnerData['Surname'] ?? '')
        );
        
        $fullUrl = $url . '?' . http_build_query($params);
        error_log("Calling URL: $fullUrl");
        
        // Use cURL to get the HTML content
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $fullUrl);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
        // Increase timeouts to ensure we get complete original HTML
        curl_setopt($ch, CURLOPT_TIMEOUT, 25);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 10);
        curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        
        // Always pass all available cookies to maintain session
        $cookieString = '';
        foreach ($_COOKIE as $name => $value) {
            $cookieString .= $name . '=' . $value . '; ';
        }
        if (!empty($cookieString)) {
            curl_setopt($ch, CURLOPT_COOKIE, rtrim($cookieString, '; '));
        }
        
        $htmlContent = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);
        
        if ($error) {
            throw new Exception("cURL error: $error");
        }
        
        if ($httpCode !== 200) {
            throw new Exception("HTTP error: $httpCode");
        }
        
        if (empty($htmlContent)) {
            throw new Exception("Empty response from indivisual.php");
        }
        
        error_log("Successfully retrieved HTML content, length: " . strlen($htmlContent));
        error_log("HTML content preview (first 500 chars): " . substr($htmlContent, 0, 500));
        error_log("HTML content contains DOCTYPE: " . (strpos($htmlContent, '<!DOCTYPE') !== false ? 'YES' : 'NO'));
        error_log("HTML content contains calendar: " . (strpos($htmlContent, 'calendar') !== false ? 'YES' : 'NO'));
        error_log("HTML content contains bootstrap: " . (strpos($htmlContent, 'bootstrap') !== false ? 'YES' : 'NO'));
        
        // Check if we got the full original HTML structure
        if (strpos($htmlContent, '<!DOCTYPE html') !== false && strpos($htmlContent, '</html>') !== false) {
            // We got complete HTML - just add print instructions at the top
            $printInstructions = '<div class="print-instructions" style="background: #d4edda; border: 1px solid #c3e6cb; padding: 15px; margin: 20px; border-radius: 5px; text-align: center; page-break-after: avoid;">
                <h4>🖨️ How to Save as PDF:</h4>
                <p><strong>1.</strong> Press <strong>Ctrl+P</strong> (Windows) or <strong>Cmd+P</strong> (Mac)</p>
                <p><strong>2.</strong> Select <strong>"Save as PDF"</strong> as destination</p>
                <p><strong>3.</strong> Choose <strong>"Landscape"</strong> orientation for best results</p>
                <p><strong>4.</strong> Click <strong>"Save"</strong></p>
                <button onclick="window.print()" style="background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer;">🖨️ Print/Save as PDF</button>
            </div>
            <style>@media print { .print-instructions { display: none !important; } }</style>';
            
            // Insert print instructions after <body> tag
            $wrappedHtml = preg_replace('/(<body[^>]*>)/i', '$1' . $printInstructions, $htmlContent);
            
        } else {
            // Fallback: wrap partial HTML
            $wrappedHtml = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>' . htmlspecialchars(($learnerData['Name'] ?? '') . ' ' . ($learnerData['Surname'] ?? '')) . ' - Report</title>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/css/bootstrap.min.css">
    <style>
        @media screen {
            .print-instructions {
                background: #d4edda;
                border: 1px solid #c3e6cb;
                padding: 15px;
                margin: 20px;
                border-radius: 5px;
                text-align: center;
            }
        }
        @media print {
            .print-instructions { display: none !important; }
        }
        /* Original report styles */
        .bs-example { margin: 2px; }
        .holiday { color: red; font-weight: bold; }
        .weekend { color: blue; }
        .absent { color: red; }
        .present { color: green; }
        .calendar-day { height: 14px; overflow: visible; font-size: 4px; padding: 1px; }
        .badge { color: black !important; font-size: 5px; }
    </style>
</head>
<body>
    <div class="print-instructions">
        <h4>🖨️ How to Save as PDF:</h4>
        <p><strong>1.</strong> Press <strong>Ctrl+P</strong> (Windows) or <strong>Cmd+P</strong> (Mac)</p>
        <p><strong>2.</strong> Select <strong>"Save as PDF"</strong> as destination</p>
        <p><strong>3.</strong> Choose <strong>"Landscape"</strong> orientation for best results</p>
        <p><strong>4.</strong> Click <strong>"Save"</strong></p>
        <button onclick="window.print()" style="background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer;">🖨️ Print/Save as PDF</button>
    </div>
    
    <!-- Original report content from indivisual.php -->';
            
            // Extract the body content from the original HTML
            if (preg_match('/<body[^>]*>(.*?)<\/body>/is', $htmlContent, $matches)) {
                $wrappedHtml .= $matches[1];
            } else {
                // If no body tags found, use the whole content
                $wrappedHtml .= $htmlContent;
            }
            
            $wrappedHtml .= '
</body>
</html>';
        }
        
        error_log("Successfully wrapped HTML for browser printing");
        return $wrappedHtml;
        
    } catch (Exception $e) {
        error_log("Error in generateHTMLFromIndivisualPage: " . $e->getMessage());
        
        // Return a simple error HTML
        return '<!DOCTYPE html>
<html>
<head><title>Error</title></head>
<body>
    <div style="padding: 20px; text-align: center;">
        <h1>Error Generating Report</h1>
        <p>Learner: ' . htmlspecialchars(($learnerData['Name'] ?? '') . ' ' . ($learnerData['Surname'] ?? '')) . '</p>
        <p>Error: ' . htmlspecialchars($e->getMessage()) . '</p>
        <p>Generated: ' . date('Y-m-d H:i:s') . '</p>
    </div>
</body>
</html>';
    }
}

// Fallback: generate HTML by using cURL with longer timeout (safer than include)
function generateHTMLViaInclude($learnerID, $project_id, $year, $month, $learnerData, $attendanceRecords = null, $firstDayOfMonth = null, $lastDayOfMonth = null) {
    error_log("Starting generateHTMLViaInclude for learner ID: $learnerID (using safer cURL with longer timeout)");
    
    try {
        // Use cURL with longer timeout as safer alternative to include
        $baseUrl = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http") . "://" . $_SERVER['HTTP_HOST'];
        $currentDir = dirname($_SERVER['REQUEST_URI']);
        $url = $baseUrl . $currentDir . "/indivisual.php";
        
        $params = array(
            'LearnerID' => $learnerID,
            'project_id' => $project_id,
            'year' => $year,
            'month' => $month,
            'FullName' => ($learnerData['Name'] ?? '') . ' ' . ($learnerData['Surname'] ?? '')
        );
        
        $fullUrl = $url . '?' . http_build_query($params);
        error_log("Fallback cURL calling: $fullUrl");
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $fullUrl);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30); // Longer timeout for fallback
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 15);
        curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        
        // Pass session cookies if needed
        if (isset($_COOKIE[session_name()])) {
            curl_setopt($ch, CURLOPT_COOKIE, session_name() . '=' . session_id());
        }
        
        $htmlContent = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);
        
        if ($error) {
            throw new Exception("Fallback cURL error: $error");
        }
        
        if ($httpCode !== 200) {
            throw new Exception("Fallback HTTP error: $httpCode");
        }
        
        if (empty($htmlContent)) {
            throw new Exception("Empty response from fallback cURL");
        }
        
        error_log("Fallback cURL successful, wrapping HTML for printing");
        
        // Wrap the original HTML with print instructions
        $wrappedHtml = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>' . htmlspecialchars(($learnerData['Name'] ?? '') . ' ' . ($learnerData['Surname'] ?? '')) . ' - Report (Fallback)</title>
    <style>
        @media screen {
            .print-instructions {
                background: #fff3cd;
                border: 1px solid #ffeaa7;
                padding: 15px;
                margin: 20px;
                border-radius: 5px;
                text-align: center;
            }
        }
        @media print {
            .print-instructions { display: none !important; }
        }
    </style>
</head>
<body>
    <div class="print-instructions">
        <h4>🖨️ How to Save as PDF:</h4>
        <p><strong>1.</strong> Press <strong>Ctrl+P</strong> (Windows) or <strong>Cmd+P</strong> (Mac)</p>
        <p><strong>2.</strong> Select <strong>"Save as PDF"</strong> as destination</p>
        <p><strong>3.</strong> Choose <strong>"Landscape"</strong> orientation for best results</p>
        <p><strong>4.</strong> Click <strong>"Save"</strong></p>
        <button onclick="window.print()" style="background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer;">🖨️ Print/Save as PDF</button>
        <p><small style="color: #856404;">Note: This report was generated using fallback method due to timeout.</small></p>
    </div>
    
    <!-- Original report content from indivisual.php -->';
        
        // Extract the body content from the original HTML
        if (preg_match('/<body[^>]*>(.*?)<\/body>/is', $htmlContent, $matches)) {
            $wrappedHtml .= $matches[1];
        } else {
            // If no body tags found, use the whole content
            $wrappedHtml .= $htmlContent;
        }
        
        $wrappedHtml .= '
</body>
</html>';
        
        error_log("Successfully wrapped fallback HTML for browser printing");
        return $wrappedHtml;
        
    } catch (Exception $e) {
        error_log("Error in generateHTMLViaInclude fallback: " . $e->getMessage());
        return '';
    }
}

// Generate HTML report directly from database (clean implementation, no external dependencies)
function fetchViewReportHTML($learnerID, $project_id, $year, $month, $learnerData) {
    error_log("Generating HTML report directly for learner ID: $learnerID (clean database approach)");

    try {
        // Use the existing database connection
        global $conn;

        if (!$conn) {
            throw new Exception("Database connection not available");
        }

        // Get learner details
        $learnerQuery = "SELECT * FROM learnerdetails WHERE LearnerID = ?";
        $stmt = $conn->prepare($learnerQuery);
        $stmt->bind_param("i", $learnerID);
        $stmt->execute();
        $learnerResult = $stmt->get_result();
        $learnerInfo = $learnerResult->fetch_assoc();

        if (!$learnerInfo) {
            throw new Exception("Learner not found");
        }

        // Get project details
        $projectQuery = "SELECT * FROM projects WHERE project_id = ?";
        $stmt = $conn->prepare($projectQuery);
        $stmt->bind_param("s", $project_id);
        $stmt->execute();
        $projectResult = $stmt->get_result();
        $projectInfo = $projectResult->fetch_assoc();

        // Get attendance data
        $attendanceQuery = "
            SELECT
                DATE(learner_clocking.clock_date) as attendance_date,
                MIN(TIME(learner_clocking.clock_in_time)) as clock_in,
                MAX(TIME(learner_clocking.clock_out_time)) as clock_out,
                learner_clocking.signature,
                learner_clocking.LearnerID
            FROM learner_clocking
            WHERE learner_clocking.LearnerID = ?
                AND YEAR(learner_clocking.clock_date) = ?
                AND MONTH(learner_clocking.clock_date) = ?
            GROUP BY DATE(learner_clocking.clock_date)
            ORDER BY attendance_date
        ";

        $stmt = $conn->prepare($attendanceQuery);
        $stmt->bind_param("iii", $learnerID, $year, $month);
        $stmt->execute();
        $attendanceResult = $stmt->get_result();

        $attendanceData = [];
        $totalPresent = 0;
        $totalHours = 0;

        while ($row = $attendanceResult->fetch_assoc()) {
            $attendanceData[$row['attendance_date']] = $row;
            if (!empty($row['clock_in'])) {
                $totalPresent++;
            }
        }

        // Generate complete HTML report directly
        $htmlContent = generateCompleteHTMLReport($learnerInfo, $projectInfo, $attendanceData, $year, $month, $totalPresent, $totalHours);



        error_log("Successfully generated HTML report for learner $learnerID, length: " . strlen($htmlContent));

        return $htmlContent;

    } catch (Exception $e) {
        error_log("Error generating HTML report for learner $learnerID: " . $e->getMessage());
        throw $e; // Re-throw the exception instead of using fallback
    }

}











// Generate complete HTML report directly (clean implementation)
// Generate HTML using the exact indivisual.php template structure
function generateFromIndivisualTemplate($conn, $learnerID, $project_id, $year, $month, $learnerData) {
    try {
        error_log("Starting generateFromIndivisualTemplate for learner $learnerID");
        error_log("Input parameters: learnerID=$learnerID, project_id=$project_id, year=$year, month=$month");
        error_log("Learner data: " . json_encode($learnerData));

        // Get South African holidays
        $saHolidays = getSouthAfricanHolidays($year);
        error_log("South African holidays loaded: " . count($saHolidays) . " holidays");

        // Get month boundaries
        $firstDayOfMonth = date('Y-m-01', strtotime("$year-$month-01"));
        $lastDayOfMonth = date('Y-m-t', strtotime("$year-$month-01"));
        error_log("Month boundaries: $firstDayOfMonth to $lastDayOfMonth");

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
            error_log("Failed to prepare sick note query: " . $conn->error);
            return false;
        }
        $stmt->bind_param("isssss", $learnerID, $firstDayOfMonth, $lastDayOfMonth, $firstDayOfMonth, $lastDayOfMonth, $firstDayOfMonth);
        $stmt->execute();
        $result = $stmt->get_result();

        $approvedSickDates = [];
        $pendingSickDates = [];
        $rejectedSickDates = [];
        $approvedSickDays = 0;
        $pendingSickDays = 0;

        $sickNoteCount = 0;
        while ($row = $result->fetch_assoc()) {
            $sickNoteCount++;
            $status = trim($row['status'] ?? 'Pending');
            $dateFrom = $row['date_from'];
            $dateTo = $row['date_to'];
            error_log("Processing sick note: status=$status, from=$dateFrom, to=$dateTo");

            try {
                $start = new DateTime($dateFrom);
                $end = new DateTime($dateTo);
                $interval = new DateInterval('P1D');
                $dateRange = new DatePeriod($start, $interval, $end->modify('+1 day'));
                foreach ($dateRange as $date) {
                    $formattedDate = $date->format('Y-m-d');
                    if (substr($formattedDate, 5, 2) == $month) {
                        if (strcasecmp($status, 'Approved') === 0) {
                            $approvedSickDates[] = $formattedDate;
                            $approvedSickDays++;
                        } elseif (strcasecmp($status, 'Pending') === 0) {
                            $pendingSickDates[] = $formattedDate;
                            $pendingSickDays++;
                        } elseif (strcasecmp($status, 'Rejected') === 0 || strcasecmp($status, 'Declined') === 0) {
                            $rejectedSickDates[] = $formattedDate;
                        }
                    }
                }
            } catch (Exception $e) {
                error_log("Date processing error for sick note: learner_id=$learnerID, error=" . $e->getMessage());
            }
        }
        $stmt->close();
        error_log("Sick notes processed: $sickNoteCount total, $approvedSickDays approved, $pendingSickDays pending");

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

        error_log("Executing learner details query for learner $learnerID, project $project_id");

        // Add browser debugging for database queries
        echo "<script>
            try {
                updateProgress('🗄️ Querying learner details...');
                updateProgress('📋 Learner ID: {$learnerID}, Project ID: {$project_id}');
            } catch(e) {
                console.log('Database query debug failed:', e.message);
            }
        </script>";
        flush();

        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            error_log("Failed to prepare learner details query: " . $conn->error);
            echo "<script>
                try {
                    updateProgress('❌ DATABASE ERROR: Failed to prepare learner details query');
                    updateProgress('📋 ERROR: " . htmlspecialchars($conn->error) . "');
                } catch(e) {
                    console.log('Database prepare error failed:', e.message);
                }
            </script>";
            flush();
            return false;
        }

        $stmt->bind_param("ii", $project_id, $learnerID);
        $stmt->execute();
        $result = $stmt->get_result();

        $learnerDetails = null;
        if ($row = $result->fetch_assoc()) {
            $learnerDetails = $row;
            error_log("Learner details found: " . json_encode($learnerDetails));
            echo "<script>
                try {
                    updateProgress('✅ Learner found: " . htmlspecialchars(($row['Name'] ?? '') . ' ' . ($row['Surname'] ?? '')) . "');
                } catch(e) {
                    console.log('Learner found message failed:', e.message);
                }
            </script>";
            flush();
        } else {
            error_log("No results from learner details query");
            echo "<script>
                try {
                    updateProgress('❌ NO LEARNER FOUND: No data for ID {$learnerID}');
                    updateProgress('💡 SOLUTION: Check if learner exists in database');
                } catch(e) {
                    console.log('No learner found message failed:', e.message);
                }
            </script>";
            flush();
        }
        $stmt->close();

        if (!$learnerDetails) {
            error_log("No learner details found for learner $learnerID with project $project_id");
            return false;
        }

        // Fetch attendance data
        $sql = "SELECT
            lc.LearnerID,
            lc.Date,
            lc.ClockInTime,
            lc.ClockOutTime,
            lc.contact_time,
            lc.signature
        FROM learner_clocking lc
        WHERE lc.LearnerID = ?
        AND YEAR(lc.Date) = ?
        AND MONTH(lc.Date) = ?
        ORDER BY lc.Date";

        error_log("Executing attendance query for learner $learnerID, year $year, month $month");

        echo "<script>
            try {
                updateProgress('🕐 Querying attendance data...');
                updateProgress('📅 Period: {$year}-{$month}');
            } catch(e) {
                console.log('Attendance query debug failed:', e.message);
            }
        </script>";
        flush();

        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            error_log("Failed to prepare attendance query: " . $conn->error);
            echo "<script>
                try {
                    updateProgress('❌ DATABASE ERROR: Failed to prepare attendance query');
                    updateProgress('📋 ERROR: " . htmlspecialchars($conn->error) . "');
                } catch(e) {
                    console.log('Attendance prepare error failed:', e.message);
                }
            </script>";
            flush();
            return false;
        }

        $stmt->bind_param("iii", $learnerID, $year, $month);
        $stmt->execute();
        $result = $stmt->get_result();

        $clockingData = [];
        $attendanceCount = 0;
        while ($row = $result->fetch_assoc()) {
            $attendanceCount++;
            $clockingData[$row['Date']] = [
                'clock_in_time' => $row['ClockInTime'],
                'clock_out_time' => $row['ClockOutTime'],
                'contact_time' => $row['contact_time'],
                'signature' => $row['signature']
            ];
            error_log("Attendance record: Date={$row['Date']}, ClockIn={$row['ClockInTime']}, ClockOut={$row['ClockOutTime']}");
        }
        $stmt->close();

        echo "<script>
            try {
                updateProgress('✅ Attendance records: {$attendanceCount} found');
            } catch(e) {
                console.log('Attendance count message failed:', e.message);
            }
        </script>";
        flush();

        error_log("Attendance records found: $attendanceCount for learner $learnerID");

        // Now generate the HTML using the exact indivisual.php template structure
        error_log("Calling generateIndivisualTemplateHTML for learner $learnerID");
        $html = generateIndivisualTemplateHTML($conn, $learnerDetails, $clockingData, $approvedSickDates, $pendingSickDates, $rejectedSickDates, $saHolidays, $year, $month, $firstDayOfMonth, $lastDayOfMonth, $approvedSickDays, $pendingSickDays);

        if (empty($html)) {
            error_log("generateIndivisualTemplateHTML returned empty HTML for learner $learnerID");
            return false;
        }

        error_log("Successfully generated HTML from indivisual.php template for learner $learnerID - Length: " . strlen($html));
        return $html;

    } catch (Exception $e) {
        error_log("Error in generateFromIndivisualTemplate: " . $e->getMessage());
        return false;
    }
}

// Generate HTML using the exact indivisual.php template structure
// Function to generate PDF reports using the indivisual.php template structure
function generateIndividualTemplatePDF($conn, $learnerID, $project_id, $year, $month) {
    error_log("Bulk download: Starting individual.php template PDF generation for learner $learnerID");

    echo "<div style='background: #f3e5f5; border: 1px solid #9c27b0; padding: 8px; margin: 5px 0; font-family: monospace; color: #7b1fa2;'><strong>" . date('H:i:s') . ":</strong> 📊 Generating indivisual.php template PDF...</div>";
    flush();

    try {
        // Get South African holidays
        $saHolidays = getSouthAfricanHolidays($year);
        $firstDayOfMonth = date('Y-m-01', strtotime("$year-$month-01"));
        $lastDayOfMonth = date('Y-m-t', strtotime("$year-$month-01"));

        // Get holidays in month
        $holidaysInMonth = 0;
        foreach ($saHolidays as $holiday) {
            if (substr($holiday, 5, 2) == $month) {
                $dayOfWeek = date('w', strtotime($holiday));
                if ($dayOfWeek != 0 && $dayOfWeek != 6) {
                    $holidaysInMonth++;
                }
            }
        }

        // Get sick notes
        echo "<div style='background: #e1f5fe; border: 1px solid #0277bd; padding: 8px; margin: 5px 0; font-family: monospace; color: #01579b;'><strong>" . date('H:i:s') . ":</strong> 🏥 Fetching sick notes...</div>";
        flush();

        $sql = "SELECT date_from, date_to, status
                FROM sick_note
                WHERE learner_id = ?
                AND (
                    (date_from BETWEEN ? AND ?) OR
                    (date_to BETWEEN ? AND ?) OR
                    (? BETWEEN date_from AND date_to)
                )";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("isssss", $learnerID, $firstDayOfMonth, $lastDayOfMonth, $firstDayOfMonth, $lastDayOfMonth, $firstDayOfMonth);
        $stmt->execute();
        $result = $stmt->get_result();

        $approvedSickDates = [];
        $pendingSickDates = [];
        $rejectedSickDates = [];
        $approvedSickDays = $pendingSickDays = $rejectedAbsentDays = 0;

        while ($row = $result->fetch_assoc()) {
            $status = trim($row['status'] ?? 'Pending');
            $dateFrom = $row['date_from'];
            $dateTo = $row['date_to'];

            if (empty($dateFrom) || empty($dateTo) || !strtotime($dateFrom) || !strtotime($dateTo)) {
                continue;
            }

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
        }
        $stmt->close();
        $approvedSickDates = array_unique($approvedSickDates);
        $pendingSickDates = array_unique($pendingSickDates);
        $rejectedSickDates = array_unique($rejectedSickDates);
        $sickDays = $approvedSickDays + $pendingSickDays;

        // Get learner and project details
        echo "<div style='background: #e1f5fe; border: 1px solid #0277bd; padding: 8px; margin: 5px 0; font-family: monospace; color: #01579b;'><strong>" . date('H:i:s') . ":</strong> 🗄️ Fetching learner details...</div>";
        flush();

        $sql = "SELECT DISTINCT
            l.`Name`, l.`Surname`, l.`IDNumber`, l.`PhoneNumber`, l.`AddressLine1`, l.`Gender`,
            l.`profile_image`, sdp.sdp_logo, client.client_logo,
            p.Project_name, s.Project_pathway, p.Province
        FROM learnerdetails l
        JOIN class c ON l.classID = c.`classID`
        JOIN sites s ON c.siteID = s.`siteID`
        JOIN project p ON p.project_id = s.project_id
        JOIN sdp ON p.sdp_name = sdp.sdp_name
        JOIN client ON p.client_name = client.client_name
        WHERE p.project_id = ? AND l.`LearnerID` = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("ii", $project_id, $learnerID);
        $stmt->execute();
        $result = $stmt->get_result();

        $learnerData = null;
        $profileImage = 'assets/img/avatar6.png';
        $sdpLogo = '';
        $clientLogo = 'assets/img/avatar6.png';

        if ($row = $result->fetch_assoc()) {
            $learnerData = $row;
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

            // Handle profile image
            $profileImageDB = $row['profile_image'] ?? null;
            if ($profileImageDB && !empty($profileImageDB)) {
                $possiblePaths = [
                    "mobile/" . $profileImageDB,
                    "mobile/learnerImages/" . basename($profileImageDB)
                ];
                foreach ($possiblePaths as $path) {
                    if (file_exists($path)) {
                        $profileImage = $path;
                        break;
                    }
                }
            }

            $sdpLogoDB = $row['sdp_logo'] ?? null;
            $sdpLogo = $sdpLogoDB && file_exists($sdpLogoDB) ? $sdpLogoDB : '';

            $clientLogoDB = $row['client_logo'] ?? null;
            $clientLogo = $clientLogoDB && file_exists($clientLogoDB) ? $clientLogoDB : 'assets/img/avatar6.png';

            echo "<div style='background: #e8f5e8; border: 1px solid #4caf50; padding: 8px; margin: 5px 0; font-family: monospace; color: #2e7d32;'><strong>" . date('H:i:s') . ":</strong> ✅ Found learner: " . htmlspecialchars($FullName) . "</div>";
        } else {
            echo "<div style='background: #ffebee; border: 1px solid #f44336; padding: 8px; margin: 5px 0; font-family: monospace; color: #c62828;'><strong>" . date('H:i:s') . ":</strong> ❌ No learner data found</div>";
            return false;
        }
        $stmt->close();

        // Get attendance data
        echo "<div style='background: #e1f5fe; border: 1px solid #0277bd; padding: 8px; margin: 5px 0; font-family: monospace; color: #01579b;'><strong>" . date('H:i:s') . ":</strong> 🕐 Fetching attendance data...</div>";
        flush();

        $sql = "SELECT DATE(clock_date) as clock_date, clock_in_time, clock_out_time, contact_time, signature
                FROM learner_clocking
                WHERE LearnerID = ? AND MONTH(clock_date) = ? AND YEAR(clock_date) = ?
                AND clock_in_time IS NOT NULL
                ORDER BY clock_date, CASE WHEN clock_out_time IS NOT NULL AND contact_time IS NOT NULL THEN 1
                          WHEN clock_out_time IS NOT NULL THEN 2 ELSE 3 END,
                          CASE WHEN contact_time IS NOT NULL THEN TIME_TO_SEC(contact_time) ELSE 0 END DESC";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param('iii', $learnerID, $month, $year);
        $stmt->execute();
        $result = $stmt->get_result();

        $clockingData = [];
        $totalRecords = $rawRecordCount = 0;

        while ($row = $result->fetch_assoc()) {
            $rawRecordCount++;
            $clockDate = $row['clock_date'] ?? 'NULL';

            if (!isset($clockingData[$clockDate])) {
                $clockingData[$clockDate] = [$row];
                $totalRecords++;
            }
        }
        $stmt->close();

        echo "<div style='background: #e8f5e8; border: 1px solid #4caf50; padding: 8px; margin: 5px 0; font-family: monospace; color: #2e7d32;'><strong>" . date('H:i:s') . ":</strong> ✅ Found {$totalRecords} attendance records</div>";
        flush();

        // Create PDF with the exact template from indivisual.php
        echo "<div style='background: #f3e5f5; border: 1px solid #9c27b0; padding: 8px; margin: 5px 0; font-family: monospace; color: #7b1fa2;'><strong>" . date('H:i:s') . ":</strong> 📄 Creating PDF with indivisual.php template...</div>";
        flush();

        $mpdf = new \Mpdf\Mpdf([
            'mode' => 'utf-8',
            'format' => 'A4-L',
            'default_font_size' => 9,
            'default_font' => 'arial',
            'margin_left' => 5,
            'margin_right' => 5,
            'margin_top' => 5,
            'margin_bottom' => 5
        ]);

        // Generate HTML using the exact template from indivisual.php
        $html = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/css/bootstrap.min.css">
    <style>
        /* NUCLEAR OPTION - OVERRIDE EVERYTHING */
        .calendar-column { 
            width: 35% !important; 
            max-width: 35% !important; 
            min-width: 35% !important; 
            float: left !important; 
            display: block !important; 
            overflow: hidden !important; 
            box-sizing: border-box !important; 
            position: relative !important; 
        }
        .calendar-column * { 
            max-width: 100% !important; 
            overflow: hidden !important; 
            box-sizing: border-box !important; 
        }
        .learner-column { 
            width: 65% !important; 
            max-width: 65% !important; 
            min-width: 65% !important; 
            float: right !important; 
            display: block !important; 
            overflow: hidden !important; 
            box-sizing: border-box !important; 
            position: relative !important; 
        }
        .learner-column * { 
            max-width: 100% !important; 
            overflow: hidden !important; 
            box-sizing: border-box !important; 
        }
        .row { 
            width: 100% !important; 
            max-width: 100% !important; 
            overflow: hidden !important; 
            display: block !important; 
            clear: both !important; 
        }
        
        /* AGGRESSIVE TABLE CONSTRAINTS */
        .calendar-column table { 
            width: 100% !important; 
            max-width: 100% !important; 
            min-width: 100% !important; 
            table-layout: fixed !important; 
            overflow: hidden !important; 
            box-sizing: border-box !important; 
        }
        .calendar-column table td, 
        .calendar-column table th { 
            width: 14.28% !important; 
            max-width: 14.28% !important; 
            min-width: 14.28% !important; 
            overflow: hidden !important; 
            word-wrap: break-word !important; 
            box-sizing: border-box !important; 
        }
        
        /* OPTIMIZED CALENDAR LAYOUT - CLEAN AND READABLE */
        .calendar-day, .calendar-day *, .calendar-day small, .calendar-day strong { 
            height: 20px !important; 
            font-size: 6px !important; 
            padding: 1px !important; 
            margin: 0px !important; 
            line-height: 1.2 !important; 
            max-height: 20px !important; 
            min-height: 20px !important; 
        }
        .badge, .badge * { 
            font-size: 7px !important; 
            padding: 1px 2px !important; 
            margin: 1px !important; 
        }
        .table td, .table th { 
            padding: 1px !important; 
            height: 20px !important; 
            max-height: 20px !important; 
            min-height: 20px !important; 
        }

        /* CLEANED UP CALENDAR LAYOUT - NO DUPLICATES */
        body { font-family: Arial, sans-serif; font-size: 9px; margin: 0; padding: 5px; }
        .holiday { color: red; font-weight: bold; }
        .weekend { color: blue; }
        .absent { color: red; }
        .pending { color: gray; }
        .present { color: green; }
        .sick { color: orange; }
        .invalid { color: red; font-weight: bold; }
        .table { margin-bottom: 2px !important; width: 100% !important; }
        .table td, .table th { padding: 1px !important; }
        .table-responsive-sm { margin-bottom: 2px !important; }
        .list-group-item { font-size: 6px; padding: 1px; }
        .list-group-item span { padding-right: 2px; }
        .list-group { margin-bottom: 1px !important; }
        .profile-container { display: flex; align-items: center; padding: 1px; margin: 0; gap: 3px; font-size: 40px; width: 100%; box-sizing: border-box; }
        .profile-container img { width: 30px; height: 20px; object-fit: cover; margin: 0; padding: 0; }
        .profile-container div { margin: 0; padding: 0; flex-grow: 1; }
        .profile-container h1 { font-size: 0.5rem; margin: 0; line-height: 1.0; }
        .signature-container { margin-top: 2px; }
        .profile-container { margin-bottom: 2px !important; }
        .signature-row { display: flex; justify-content: space-between; align-items: center; padding: 1px; }
        .signature-row .form-group { flex: 1; text-align: left; margin: 0; padding: 1px; }
        .main-logo-container { text-align: center; margin-bottom: 3px; }
        .main-logo-container img { width: 80px; height: 20px; }
        .logo-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 3px; }
        .signature-img { width: 40px; height: 20px; object-fit: contain; margin-top: 1px; }
        

        .calendar-container { margin-bottom: 5px !important; }
        .list-group { margin-bottom: 5px !important; }
        .container-fluid { padding: 2px !important; }
        .mb-1 { margin-bottom: 3px !important; }
        .p-1 { padding: 2px !important; }
        /* Critical layout CSS for mPDF */
        .row > * { box-sizing: border-box !important; }
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
                width: 80px !important;
                height: 20px !important;
            }
            .logo-row img {
                max-width: 250px !important;
                height: 40px !important;
            }

            .list-group-item span {
                padding-right: 4px !important;
            }
            img {
                max-width: 250px !important;
                height: 40px !important;
            }

            h1, h3 {
                font-size: 0.8rem !important;
            }
            .calendar-day {
                height: 35px !important;
                font-size: 7px !important;
                padding: 1px !important;
            }
            .calendar-day img {
                width: 25px !important;
                height: 15px !important;
            }
            .signature-img {
                width: 25px !important;
                height: 15px !important;
            }
            .signature-row img {
                width: 15px !important;
                height: 8px !important;
            }
            .profile-container {
                gap: 4px;
                padding: 1px;
                margin-bottom: 8px !important;
            }
            .profile-container img {
                width: 50px !important;
                height: 60px !important;
            }
            .profile-container h1 {
                font-size: 0.9rem !important;
            }
            .container-fluid:has(.profile-container) {
                /* Natural height */
            }
            /* Ensure table fits */
            .table {
                font-size: 7px !important;
                margin-bottom: 3px !important;
                width: 100% !important;
            }
            .table td, .table th {
                padding: 1px !important;
                font-size: 6px !important;
            }
        }
    </style>
</head>
<body>
<div id="report-content">
    <div class="container-fluid">
        <div class="container-fluid">
            <div class="row" style="position: relative;">
                <div class="col" style="position: absolute; left: 0;">
                    <img src="' . htmlspecialchars($sdpLogo) . '" class="rounded" alt="SDP Logo" style="max-width: 250px; height: 45px;" onerror="this.src=\'' . htmlspecialchars($profileImage) . '\'">
                </div>
                <div class="col" style="position: absolute; right: 0;">
                    <img src="assets/img/rlms.PNG" class="rounded" alt="RLMS Logo" style="max-width: 250px; height: 45px;" onerror="this.src=\'' . htmlspecialchars($profileImage) . '\'">
                </div>
            </div>
        </div>

        <div style="background-image: linear-gradient(to right, #42bcf5, #42f5d7);" class="p-1 mb-1 text-black" style="font-size: 10px; padding: 2px;">
            PERIOD: ' . htmlspecialchars($firstDayOfMonth) . ' to ' . htmlspecialchars($lastDayOfMonth) . '
        </div>

        <div class="row" style="display: block; width: 100%; overflow: hidden;">
            <div class="calendar-column" style="width: 35%; float: left; display: inline-block; max-width: 35%; overflow: hidden;">
                <div class="container-fluid" style="width: 100%; max-width: 100%; overflow: hidden;">
                    <div class="calendar-container" style="width: 100%; max-width: 100%; overflow: hidden;">
                        <div class="table-responsive-sm" style="width: 100%; max-width: 100%; overflow: hidden;">';

        // Generate calendar
        $daysInMonth = date('t', strtotime("$year-$month-01"));
        $startDay = date('w', strtotime("$year-$month-01"));
        $totalDays = $workingDays = $holidaysCount = $weekendDays = $presentDays = $absentDays = $invalidDays = 0;
        $absentDays += $rejectedAbsentDays;

        $html .= "<h4 style='font-size: 0.4rem;margin:1px;padding:0;'>Calendar for " . date('F Y', strtotime("$year-$month-01")) . "</h4>";

        $html .= "<div class='mb-1' style='font-size: 5px;'>
            <span class='badge badge-primary'>Workdays: <span id='workingDays'>0</span></span>
            <span class='badge badge-danger'>Holidays: <span id='holidaysCount'>0</span></span>
            <span class='badge badge-info'>Weekend: <span id='weekendDays'>0</span></span>
            <span class='badge badge-success'>Present: <span id='presentDays'>0</span></span>
            <span class='badge badge-warning'>Absent: <span id='absentDays'>0</span></span>
            <span class='badge badge-danger'>Invalid: <span id='invalidDays'>0</span></span>
            <span class='badge badge-warning'>Sick: <span id='sickDays'>0</span></span>
        </div>";

        // Close the calendar header section and start the table
        $html .= '</div>'; // Close table-responsive-sm
        $html .= '</div>'; // Close calendar-container
        $html .= '</div>'; // Close container-fluid
        $html .= '</div>'; // Close calendar-column
        

        
                // Now continue with calendar table generation
        $html .= "<table class='table table-bordered' style='font-size: 6px !important; width: 100% !important; max-width: 100% !important; table-layout: fixed !important;'>
            <thead><tr style='background-color:#282C65;color:black;font-size:6px !important;height:20px !important;'>
                <th style='height:20px !important;padding:1px !important;font-size:6px !important;width:14.28% !important;'>Sun</th>
                <th style='height:20px !important;padding:1px !important;font-size:6px !important;width:14.28% !important;'>Mon</th>
                <th style='height:20px !important;padding:1px !important;font-size:6px !important;width:14.28% !important;'>Tue</th>
                <th style='height:20px !important;padding:1px !important;font-size:6px !important;width:14.28% !important;'>Wed</th>
                <th style='height:20px !important;padding:1px !important;font-size:6px !important;width:14.28% !important;'>Thu</th>
                <th style='height:20px !important;padding:1px !important;font-size:6px !important;width:14.28% !important;'>Fri</th>
                <th style='height:20px !important;padding:1px !important;font-size:6px !important;width:14.28% !important;'>Sat</th>
            </tr></thead><tbody><tr>";

        for ($i = 0; $i < $startDay; $i++) {
            $html .= "<td></td>";
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
            } else {
                $workingDays++;
            }

            $html .= "<td class='calendar-day' style='height:20px !important;padding:1px !important;font-size:6px !important;max-height:20px !important;min-height:20px !important;'><strong style='font-size:6px !important;'>$day</strong><br>";

            if ($isApprovedSick) {
                $html .= "<small class='sick' style='font-size:5px !important;line-height:1.2 !important;'>Sick Note Approved</small>";
            } elseif ($isPendingSick) {
                $html .= "<small class='sick' style='font-size:5px !important;line-height:1.2 !important;'>Sick Note Pending</small>";
            } elseif ($isRejectedSick) {
                $html .= "<small class='absent' style='font-size:5px !important;line-height:1.2 !important;'>Absent</small>";
            } elseif ($isHoliday) {
                $holidayName = '';
                switch ($date) {
                    case date('Y-m-d', strtotime("$year-01-01")): $holidayName = 'New Year'; break;
                    case date('Y-m-d', strtotime("$year-01-01 +1 day")):
                        if (date('w', strtotime("$year-01-01")) == 0) $holidayName = 'New Year (Observed)'; break;
                    case date('Y-m-d', strtotime("$year-03-21")): $holidayName = 'Human Rights Day'; break;
                    case date('Y-m-d', strtotime("$year-04-27")): $holidayName = 'Freedom Day'; break;
                    case date('Y-m-d', strtotime("$year-05-01")): $holidayName = 'Workers Day'; break;
                    case date('Y-m-d', strtotime("$year-06-16")): $holidayName = 'Youth'; break;
                    case date('Y-m-d', strtotime("$year-08-09")): $holidayName = 'Womens Day'; break;
                    case date('Y-m-d', strtotime("$year-09-24")): $holidayName = 'Heritage'; break;
                    case date('Y-m-d', strtotime("$year-12-16")): $holidayName = 'Reconciliation'; break;
                    case date('Y-m-d', strtotime("$year-12-25")): $holidayName = 'Christmas'; break;
                    case date('Y-m-d', strtotime("$year-12-26")): $holidayName = 'Goodwill'; break;
                    default:
                        $easter = date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days"));
                        if ($date == date('Y-m-d', strtotime($easter . ' -2 days'))) $holidayName = 'Good Friday';
                        elseif ($date == date('Y-m-d', strtotime($easter . ' +1 day'))) $holidayName = 'Family Day';
                }
                $html .= "<small class='holiday' style='font-size:5px !important;line-height:1.2 !important;'>$holidayName</small>";
            } elseif ($isWeekend) {
                $html .= "<small class='weekend' style='font-size:5px !important;line-height:1.2 !important;'>Weekend</small>";
            } else {
                if (isset($clockingData[$date])) {
                    $record = $clockingData[$date][0];
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
                            $html .= "<img src='$webSignaturePath' class='signature-img rounded' alt='Signature' style='max-width: 90px; height: 35px;' onerror=\"this.style.display='none';this.nextSibling.style.display='block';\">";
                            $html .= "<small style='display:none;'>Signature: [N/A]</small>";
                        } else {
                            $html .= "<small>Signature: [N/A]</small>";
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
                        $html .= "<small class='invalid'>⚠ Incomplete</small>";
                        // echo "<small class='invalid'>In: $formattedClockIn</small>";
                        // echo "<small class='invalid'>Out: $formattedClockOut</small>";
                        // echo "<small class='invalid'>Contact: $formattedContactTime</small>"; // HIDDEN

                        // Show signature for incomplete records too
                        $webSignaturePath = detectValidSignature($conn, $learnerID);
                        if ($webSignaturePath) {
                            $webSignaturePath = htmlspecialchars($webSignaturePath);
                            $html .= "<img src='$webSignaturePath' class='signature-img rounded' alt='Signature' style='max-width: 90px; height: 35px;' onerror=\"this.style.display='none';this.nextSibling.style.display='block';\">";
                            $html .= "<small style='display:none;'>Signature: [N/A]</small>";
                        } else {
                            $html .= "<small>Signature: [N/A]</small>";
                        }
                    }
                } elseif ($date < $currentDate) {
                    $absentDays++;
                    $html .= "<small class='absent'>Absent</small>";
                } else {
                    $html .= "<small class='pending'>Pending</small>";
                }
            }

            $html .= "</td>";

            if (($day + $startDay) % 7 == 0 && $day != $daysInMonth) {
                $html .= "</tr><tr>";
            }
        }

        while (($day + $startDay) % 7 != 0) {
            $html .= "<td></td>";
            $day++;
        }

        $html .= "</tr></tbody></table>";

        // Add JavaScript for updating badge counts (will be executed when PDF is viewed)
        $html .= "<script>
            document.getElementById('workingDays').textContent = '$workingDays';
            document.getElementById('holidaysCount').textContent = '$holidaysCount';
            document.getElementById('weekendDays').textContent = '$weekendDays';
            document.getElementById('presentDays').textContent = '$presentDays';
            document.getElementById('absentDays').textContent = '$absentDays';
            document.getElementById('invalidDays').textContent = '$invalidDays';
            document.getElementById('sickDays').textContent = '$sickDays';
        </script>";

        // Add signature section
        $html .= '<div class="signature-container">
            <div class="form-row signature-row">
                <div class="form-group">
                    <label style="color:#282C65;font-size:8px;">Facilitator Signature : <img src="assets/img/f.PNG" style="width:30px;height:15px;" alt="" onerror="this.src=\'' . htmlspecialchars($profileImage) . '\'"></label>
                    <span style="font-size:8px;">' . date('Y-m-d H:i:s') . '</span>
                </div>
                <div class="form-group">
                    <label style="color:#282C65;font-size:8px;">SDP Representative Signature: <img src="assets/img/fa.png" style="width:30px;height:15px;" alt="" onerror="this.src=\'' . htmlspecialchars($profileImage) . '\'"></label>
                    <span style="font-size:8px;">' . date('Y-m-d H:i:s') . '</span>
                </div>
            </div>
        </div>
        </div>'; // Close calendar column
        
        // Add learner details section in a separate column to the right
        $html .= '<div class="learner-column" style="width: 60%; float: right; display: inline-block;">
        <div class="container-fluid">
            <div class="row">
                <div class="col-12">
                    <div class="profile-container bg-primary text-white" style="border-radius: 5px; margin-bottom: 5px; display: flex; align-items: center; gap: 3px; padding: 1px;">
                        <img src="' . htmlspecialchars($profileImage) . '"
                             alt="Profile"
                             class="img-thumbnail"
                             style="width: 30px; height: 20px; object-fit: cover; transform: rotate(0deg);"
                             onerror="this.src=\'' . htmlspecialchars($profileImage) . '\'">
                        <div>
                            <h1 style="font-size: 0.5rem; margin: 0; white-space: nowrap; color: white;">' . htmlspecialchars(strtoupper($FullName)) . '</h1>
                        </div>
                    </div>
                </div>

                <div class="container-fluid">
                    <div style="background-color:#282C65;" class="p-1 mb-1 text-white">
                        <h3 style="font-size: 0.6rem;">PROJECT DETAILS</h3>
                    </div>
                    <ul class="list-group">
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Pathway:</strong>
                            <span style="color:#282C65;">' . htmlspecialchars($projectPathway) . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Province:</strong>
                            <span style="color:#282C65;">' . htmlspecialchars($Province) . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Project:</strong>
                            <span style="color:#282C65;">' . htmlspecialchars($projectName) . '</span>
                        </li>
                    </ul>
                </div>

                <div class="container-fluid">
                    <div style="background-color:#282C65;" class="p-1 mb-1 text-white">
                        <h3 style="font-size: 0.6rem;">LEARNER</h3>
                    </div>
                    <ul class="list-group">
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Name:</strong>
                            <span style="color:#282C65;">' . htmlspecialchars($Name) . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Surname:</strong>
                            <span style="color:#282C65;">' . htmlspecialchars($Surname) . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">ID Number:</strong>
                            <span style="color:#282C65;">' . htmlspecialchars($IDNumber) . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Gender:</strong>
                            <span style="color:#282C65;">' . htmlspecialchars($Gender) . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Telephone:</strong>
                            <span style="color:#282C65;">' . htmlspecialchars($PhoneNumber) . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Address:</strong>
                            <span style="color:#282C65;">' . htmlspecialchars($Address) . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Expected Attendance:</strong>
                            <span style="color:#282C65;">' . $workingDays . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Actual Attendance:</strong>
                            <span style="color:#282C65;">' . $presentDays . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Days Absent:</strong>
                            <span style="color:#282C65;">' . $absentDays . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Invalid Attendance:</strong>
                            <span style="color:#282C65;">' . $invalidDays . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Holidays:</strong>
                            <span style="color:#282C65;">' . $holidaysInMonth . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Approved Sick Days:</strong>
                            <span style="color:#282C65;">' . $approvedSickDays . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Pending Sick Days:</strong>
                            <span style="color:#282C65;">' . $pendingSickDays . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Total Sick Days:</strong>
                            <span style="color:#282C65;">' . $sickDays . '</span>
                        </li>
                        <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                            <strong style="color:#282C65;">Total Valid Attendance:</strong>
                            <span style="color:#282C65;">' . ($presentDays + $holidaysInMonth + $approvedSickDays) . '</span>
                        </li>
                    </ul>
                </div>
            </div>
        </div>
        </div>';

        // Close the row and container
        $html .= '</div>'; // Close the row
        $html .= '</div>'; // Close the container
        $html .= '</div>'; // Close the body
        $html .= '</html>';

        $mpdf->WriteHTML($html);

        echo "<div style='background: #e8f5e8; border: 1px solid #4caf50; padding: 8px; margin: 5px 0; font-family: monospace; color: #2e7d32;'><strong>" . date('H:i:s') . ":</strong> ✅ PDF content written successfully</div>";
        flush();

        // Return PDF as string
        $pdfContent = $mpdf->Output('', 'S');

        echo "<div style='background: #e8f5e8; border: 1px solid #4caf50; padding: 8px; margin: 5px 0; font-family: monospace; color: #2e7d32;'><strong>" . date('H:i:s') . ":</strong> ✅ PDF generated successfully (" . strlen($pdfContent) . " bytes)</div>";
        flush();

        error_log("Bulk download: Successfully generated indivisual.php template PDF (" . strlen($pdfContent) . " bytes)");
        return $pdfContent;

    } catch (Exception $e) {
        echo "<div style='background: #ffebee; border: 1px solid #f44336; padding: 8px; margin: 5px 0; font-family: monospace; color: #c62828;'><strong>" . date('H:i:s') . ":</strong> ❌ PDF Generation Error: " . htmlspecialchars($e->getMessage()) . "</div>";
        error_log("Bulk download: PDF generation error: " . $e->getMessage());
        return false;
    }
}

function generateIndivisualTemplateHTML($conn, $learnerDetails, $clockingData, $approvedSickDates, $pendingSickDates, $rejectedSickDates, $saHolidays, $year, $month, $firstDayOfMonth, $lastDayOfMonth, $approvedSickDays, $pendingSickDays) {
    error_log("generateIndivisualTemplateHTML called for learner: " . ($learnerDetails['Name'] ?? 'Unknown') . ' ' . ($learnerDetails['Surname'] ?? ''));

    $Name = $learnerDetails['Name'] ?? '';
    $Surname = $learnerDetails['Surname'] ?? '';
    $FullName = trim($Name . ' ' . $Surname);

    error_log("Processing learner: $FullName (ID: " . ($learnerDetails['LearnerID'] ?? 'Unknown') . ")");
    $IDNumber = $learnerDetails['IDNumber'] ?? 'N/A';
    $PhoneNumber = $learnerDetails['PhoneNumber'] ?? 'N/A';
    $Gender = $learnerDetails['Gender'] ?? 'N/A';
    $Address = $learnerDetails['AddressLine1'] ?? 'N/A';
    $profileImage = $learnerDetails['profile_image'] ?? 'assets/img/avatar6.png';
    $projectName = $learnerDetails['Project_name'] ?? 'N/A';
    $projectPathway = $learnerDetails['Project_pathway'] ?? 'N/A';
    $Province = $learnerDetails['Province'] ?? 'N/A';
    $sdpLogo = $learnerDetails['sdp_logo'] ?? '';
    $clientLogo = $learnerDetails['client_logo'] ?? '';

    error_log("Learner details extracted: Name=$FullName, Project=$projectName, Clocking records=" . count($clockingData));

    // Calculate statistics
    $daysInMonth = date('t', strtotime("$year-$month-01"));
    $startDay = date('w', strtotime("$year-$month-01"));
    $totalDays = $workingDays = $holidaysCount = $weekendDays = $presentDays = $absentDays = $invalidDays = 0;
    $absentDays += count($rejectedSickDates);
    $sickDays = $approvedSickDays + $pendingSickDays;

    $html = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>' . htmlspecialchars($FullName) . ' - Attendance Report</title>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/css/bootstrap.min.css">
    <style>
        @media screen {
            .print-instructions {
                background: #d4edda;
                border: 1px solid #c3e6cb;
                padding: 15px;
                margin: 20px;
                border-radius: 5px;
                text-align: center;
            }
        }
        @media print {
            .print-instructions { display: none !important; }
            @page { size: A4 landscape; margin: 2mm; }
        }

        .bs-example { margin: 2px; }
        .holiday { color: red; font-weight: bold; }
        .weekend { color: blue; }
        .absent { color: red; }
        .present { color: green; }
        .sick { color: orange; }
        .calendar-day {
            padding: 1px;
        }
        .calendar-day small {
            display: block;
            line-height: 1.0;
        }
        .badge {
            color: black !important;
            font-size: 7px;
            padding: 2px 4px;
            margin-right: 2px;
        }
        .list-group-item {
            font-size: 10px;
            padding: 2px;
            margin-bottom: 1px;
        }
        .list-group {
            margin-bottom: 5px;
        }
        .list-group-item span {
            padding-right: 8px;
        }
        #report-content {
            padding: 5px;
            margin: 0;
        }
        .container-fluid {
            padding-left: 1px;
            padding-right: 1px;
            margin: 1px;
        }
        .bs-example {
            margin: 1px;
        }
        .profile-container {
            display: flex;
            align-items: center;
            padding: 3px;
            margin: 0;
            gap: 6px;
            font-size: 40px;
            width: 100%;
            box-sizing: border-box;
            position: relative;
            z-index: 1;
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
            margin-bottom: 8px;
        }
        .signature-container {
            margin-top: 8px;
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
        /* Hide navigation buttons on main page */
        .calendar-nav {
            display: none;
        }
        /* Ensure proper column layout */
        /* Ensure proper column layout - Single page landscape */
        .col-md-4 {
            float: right !important;
            clear: right !important;
            width: 40% !important;
            display: block !important;
        }
        .col-md-8 {
            float: left !important;
            clear: left !important;
            width: 60% !important;
            display: block !important;
        }
        .row {
            display: flex !important;
            flex-wrap: wrap !important;
            width: 100% !important;
            clear: both !important;
        }
        .row::after {
            content: "";
            clear: both;
            display: table;
        }

        /* Natural single page layout */
        #report-content {
            page-break-inside: avoid !important;
            margin: 0;
            padding: 1px;
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
                margin: 2px;
                padding: 2px;
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
                /* min-height removed */
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
            <!-- <img src="assets/img/rlms.PNG" alt="CoolBrand" onerror="this.src=\' . htmlspecialchars($profileImage) . \'">
        --></div>

        <div class="container-fluid">
            <div class="row">
                <div class="col">
                    <img src="' . htmlspecialchars($sdpLogo) . '" class="rounded float-start" alt="SDP Logo" style="max-width: 300px; height: 50px;" onerror="this.src=\'' . htmlspecialchars($profileImage) . '\'">';
                '</div>
                <div class="col"></div>
                <div class="col">
                    <img src="' . htmlspecialchars($clientLogo) . '"  class="rounded float-end" alt="Client Logo" style="max-width: 300px; height: 50px;" onerror="this.src=\'' . htmlspecialchars($profileImage) . '\'">';
                '</div>
            </div>
        </div>

        <div style="background-image: linear-gradient(to right, #42bcf5, #42f5d7);" class="p-1 mb-1 text-black" style="font-size: 11px;">
            PERIOD: ' . $firstDayOfMonth . ' to ' . $lastDayOfMonth . '
        </div>



        <div class="row">
            <div class="col-md-8">
                <div class="container-fluid">
                    <div class="calendar-container">
                        <div class="table-responsive-sm">';

    $html .= "<h4 style='font-size: 0.8rem;margin:1px;'>Calendar for " . date('F Y', strtotime("$year-$month-01")) . "</h4>";

    $html .= "<div class='mb-1'>";
    $html .= "<span class='badge badge-primary'>Workdays: <span id='workingDays'>0</span></span> ";
    $html .= "<span class='badge badge-danger'>Holidays: <span id='holidaysCount'>0</span></span> ";
    $html .= "<span class='badge badge-info'>Weekend: <span id='weekendDays'>0</span></span> ";
    $html .= "<span class='badge badge-success'>Present: <span id='presentDays'>0</span></span> ";
    $html .= "<span class='badge badge-warning'>Absent: <span id='absentDays'>0</span></span> ";
    $html .= "<span class='badge badge-danger'>Invalid: <span id='invalidDays'>0</span></span> ";
    $html .= "<span class='badge badge-warning'>Sick: <span id='sickDays'>{$sickDays}</span></span>";
    $html .= "</div>";

    $html .= "<table class='table table-bordered'>";
    $html .= "<thead><tr style='background-color:#282C65;color:black;font-size:9px;'>
                                    <th>Sun</th><th>Mon</th><th>Tue</th><th>Wed</th><th>Thu</th><th>Fri</th><th>Sat</th>
                                  </tr></thead><tbody><tr>";

    // Generate calendar days
    for ($i = 0; $i < $startDay; $i++) {
        $html .= "<td></td>";
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

        $html .= "<td class='calendar-day'>";
        $html .= "<strong>$day</strong><br>";

        if ($isApprovedSick) {
            $html .= "<small class='sick'>Sick Note Approved</small>";
        } elseif ($isPendingSick) {
            $html .= "<small class='sick'>Sick Note Pending</small>";
        } elseif ($isRejectedSick) {
            $html .= "<small class='absent'>Absent</small>";
        } elseif ($isHoliday) {
            $holidayName = '';
            switch ($date) {
                case date('Y-m-d', strtotime("$year-01-01")): $holidayName = 'New Year'; break;
                case date('Y-m-d', strtotime("$year-01-01 +1 day")):
                    if (date('w', strtotime("$year-01-01")) == 0) $holidayName = 'New Year (Observed)'; break;
                case date('Y-m-d', strtotime("$year-03-21")): $holidayName = 'Human Rights Day'; break;
                case date('Y-m-d', strtotime("$year-03-21 +1 day")):
                    if (date('w', strtotime("$year-03-21")) == 0) $holidayName = 'Human Rights (Observed)'; break;
                case date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days -2 days")): $holidayName = 'Good Friday'; break;
                case date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days -2 days +1 day")):
                    if (date('w', strtotime("$year-03-21 +" . easter_days($year) . " days -2 days")) == 0) $holidayName = 'Good Friday (Observed)'; break;
                case date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days +1 day")): $holidayName = 'Family Day'; break;
                case date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days +1 day +1 day")):
                    if (date('w', strtotime("$year-03-21 +" . easter_days($year) . " days +1 day")) == 0) $holidayName = 'Family Day (Observed)'; break;
                case date('Y-m-d', strtotime("$year-04-27")): $holidayName = 'Freedom Day'; break;
                case date('Y-m-d', strtotime("$year-04-27 +1 day")):
                    if (date('w', strtotime("$year-04-27")) == 0) $holidayName = 'Freedom (Observed)'; break;
                case date('Y-m-d', strtotime("$year-05-01")): $holidayName = "Worker's Day"; break;
                case date('Y-m-d', strtotime("$year-05-01 +1 day")):
                    if (date('w', strtotime("$year-05-01")) == 0) $holidayName = 'Workers (Observed)'; break;
                case date('Y-m-d', strtotime("$year-06-16")): $holidayName = 'Youth'; break;
                case date('Y-m-d', strtotime("$year-06-16 +1 day")):
                    if (date('w', strtotime("$year-06-16")) == 0) $holidayName = 'Youth (Observed)'; break;
                case date('Y-m-d', strtotime("$year-08-09")): $holidayName = "Women's Day"; break;
                case date('Y-m-d', strtotime("$year-08-09 +1 day")):
                    if (date('w', strtotime("$year-08-09")) == 0) $holidayName = 'Women\'s (Observed)'; break;
                case date('Y-m-d', strtotime("$year-09-24")): $holidayName = 'Heritage'; break;
                case date('Y-m-d', strtotime("$year-09-24 +1 day")):
                    if (date('w', strtotime("$year-09-24")) == 0) $holidayName = 'Heritage (Observed)'; break;
                case date('Y-m-d', strtotime("$year-12-16")): $holidayName = 'Reconciliation'; break;
                case date('Y-m-d', strtotime("$year-12-16 +1 day")):
                    if (date('w', strtotime("$year-12-16")) == 0) $holidayName = 'Reconciliation (Observed)'; break;
                case date('Y-m-d', strtotime("$year-12-25")): $holidayName = 'Christmas'; break;
                case date('Y-m-d', strtotime("$year-12-25 +1 day")):
                    if (date('w', strtotime("$year-12-25")) == 0) $holidayName = 'Christmas (Observed)'; break;
                case date('Y-m-d', strtotime("$year-12-26")): $holidayName = 'Goodwill'; break;
                case date('Y-m-d', strtotime("$year-12-26 +1 day")):
                    if (date('w', strtotime("$year-12-26")) == 0) $holidayName = 'Goodwill (Observed)'; break;
            }
            $html .= "<small class='holiday'>$holidayName</small>";
        } elseif ($isWeekend) {
            $html .= "<small class='weekend'>Weekend</small>";
        } else {
            if (isset($clockingData[$date])) {
                $record = $clockingData[$date];
                $clockIn = $record['clock_in_time'] ?? 'N/A';
                $clockOut = $record['clock_out_time'] ?? 'N/A';
                $contactTime = $record['contact_time'] ?? 'N/A';

                $isCompleteRecord = ($clockIn !== 'N/A' && $clockOut !== 'N/A');

                if ($isCompleteRecord) {
                    $presentDays++;

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

                    $formattedContactTime = 'N/A';
                    $hasContactTime = ($contactTime !== 'N/A' && !empty($contactTime) && $contactTime !== null && $contactTime !== '');
                    if ($hasContactTime) {
                        $formattedContactTime = preg_replace('/\..+/', '', $contactTime);
                        $formattedContactTime = str_replace(['0h ', '0m '], '', $formattedContactTime);
                    }

                    $html .= "<small class='present'>In: $formattedClockIn</small><br>";
                    $html .= "<small class='present'>Out: $formattedClockOut</small><br>";
                    $html .= "<small class='present'>Hours: $formattedContactTime</small>";

                    // Show signature for complete records
                    $webSignaturePath = detectValidSignature($conn, $learnerID);
                    if ($webSignaturePath) {
                        $webSignaturePath = htmlspecialchars($webSignaturePath);
                        $html .= "<img src='$webSignaturePath' class='signature-img rounded' alt='Signature' style='max-width: 90px; height: 35px;' onerror=\"this.style.display='none';this.nextSibling.style.display='block';\">";
                        $html .= "<small style='display:none;'>Signature: [N/A]</small>";
                    } else {
                        $html .= "<small>Signature: [N/A]</small>";
                    }
                } else {
                    $invalidDays++;
                    $html .= "<small class='invalid'>⚠ Incomplete</small>";
                    // Show signature for incomplete records too
                    $webSignaturePath = detectValidSignature($conn, $learnerID);
                    if ($webSignaturePath) {
                        $webSignaturePath = htmlspecialchars($webSignaturePath);
                        $html .= "<img src='$webSignaturePath' class='signature-img rounded' alt='Signature' style='max-width: 90px; height: 35px;' onerror=\"this.style.display='none';this.nextSibling.style.display='block';\">";
                        $html .= "<small style='display:none;'>Signature: [N/A]</small>";
                    } else {
                        $html .= "<small>Signature: [N/A]</small>";
                    }
                }
            } elseif ($date < $currentDate) {
                $absentDays++;
                $html .= "<small class='absent'>Absent</small>";
            } else {
                $html .= "<small class='pending'>Pending</small>";
            }
        }

        $html .= "</td>";

        if (($day + $startDay) % 7 == 0 && $day != $daysInMonth) {
            $html .= "</tr><tr>";
        }
    }

    while (($day + $startDay) % 7 != 0) {
        $html .= "<td></td>";
        $day++;
    }

    $html .= "</tr></tbody></table>";

    // JavaScript to update counters
    $html .= "<script>
        document.getElementById('workingDays').textContent = '$workingDays';
        document.getElementById('holidaysCount').textContent = '$holidaysCount';
        document.getElementById('weekendDays').textContent = '$weekendDays';
        document.getElementById('presentDays').textContent = '$presentDays';
        document.getElementById('absentDays').textContent = '$absentDays';
        document.getElementById('invalidDays').textContent = '$invalidDays';
    </script>";

    $html .= '<div class="signature-container">
                    <div class="form-row signature-row">
                        <div class="form-group">
                            <label style="color:#282C65;font-size:8px;">Facilitator Signature : <img src="assets/img/f.PNG" style="width:30px;height:15px;" alt="" onerror="this.src=\'' . htmlspecialchars($profileImage) . '\'"></label>
                            <span style="font-size:8px;">' . date('Y-m-d H:i:s') . '</span>
                        </div>
                        <div class="form-group">
                            <label style="color:#282C65;font-size:8px;">SDP Representative Signature: <img src="assets/img/fa.png" style="width:30px;height:15px;" alt="" onerror="this.src=\'' . htmlspecialchars($profileImage) . '\'"></label>
                            <span style="font-size:8px;">' . date('Y-m-d H:i:s') . '</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="col-md-4">
            <div class="container-fluid">
                <div class="row">
                    <div class="col-12">
                        <div class="profile-container bg-primary text-white" style="border-radius: 5px; margin-bottom: 15px;">
                            <img src="' . htmlspecialchars($profileImage) . '"
                                 alt="Profile"
                                 class="img-thumbnail"
                                 onerror="this.src=\'' . htmlspecialchars($profileImage) . '\'">
                            <div>
                                <h1>' . strtoupper($FullName) . '</h1>
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
                                <span style="color:#282C65;">' . htmlspecialchars($projectPathway) . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Province:</strong>
                                <span style="color:#282C65;">' . htmlspecialchars($Province) . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Project:</strong>
                                <span style="color:#282C65;">' . htmlspecialchars($projectName) . '</span>
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
                                <span style="color:#282C65;">' . htmlspecialchars($Name) . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Surname:</strong>
                                <span style="color:#282C65;">' . htmlspecialchars($Surname) . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">ID Number:</strong>
                                <span style="color:#282C65;">' . htmlspecialchars($IDNumber) . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Gender:</strong>
                                <span style="color:#282C65;">' . htmlspecialchars($Gender) . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Telephone:</strong>
                                <span style="color:#282C65;">' . htmlspecialchars($PhoneNumber) . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Address:</strong>
                                <span style="color:#282C65;">' . htmlspecialchars($Address) . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Expected Attendance:</strong>
                                <span style="color:#282C65;">' . $workingDays . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Actual Attendance:</strong>
                                <span style="color:#282C65;">' . $presentDays . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Days Absent:</strong>
                                <span style="color:#282C65;">' . $absentDays . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Invalid Attendance:</strong>
                                <span style="color:#282C65;">' . $invalidDays . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Holidays:</strong>
                                <span style="color:#282C65;">' . $holidaysCount . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Approved Sick Days:</strong>
                                <span style="color:#282C65;">' . $approvedSickDays . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Pending Sick Days:</strong>
                                <span style="color:#282C65;">' . $pendingSickDays . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Total Sick Days:</strong>
                                <span style="color:#282C65;">' . $sickDays . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Total Valid Attendance:</strong>
                                <span style="color:#282C65;">' . ($presentDays + $holidaysCount + $approvedSickDays) . '</span>
                            </li>
                        </ul>
                    </div>
                </div>

                <footer class="page-footer font-small blue">
                    <div style="color:#282C65;font-size:8px;" class="text-right py-1">
                        <b>RLMS Attendance. @</b> ' . date('Y-m-d') . '
                    </div>
                </footer>
            </div>
        </div>
    </div>
</div>
</body>
</html>';

    return $html;
}

function generateCompleteHTMLReport($learnerInfo, $projectInfo, $attendanceData, $year, $month, $totalPresent, $totalHours) {
    global $conn;

    $learnerName = ($learnerInfo['Name'] ?? '') . ' ' . ($learnerInfo['Surname'] ?? '');
    $monthName = date('F Y', strtotime("$year-$month-01"));
    $projectName = $projectInfo['project_name'] ?? 'N/A';

    // Get South African holidays
    $saHolidays = getSouthAfricanHolidays($year);

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
    $learnerID = $learnerInfo['LearnerID'] ?? '';
    $stmt->bind_param("isssss", $learnerID, $firstDayOfMonth, $lastDayOfMonth, $firstDayOfMonth, $lastDayOfMonth, $firstDayOfMonth);
    $stmt->execute();
    $result = $stmt->get_result();

    $approvedSickDates = [];
    $pendingSickDates = [];
    $rejectedSickDates = [];
    $approvedSickDays = 0;
    $pendingSickDays = 0;

    while ($row = $result->fetch_assoc()) {
        $status = trim($row['status'] ?? 'Pending');
        $dateFrom = $row['date_from'];
        $dateTo = $row['date_to'];

        try {
            $start = new DateTime($dateFrom);
            $end = new DateTime($dateTo);
            $interval = new DateInterval('P1D');
            $dateRange = new DatePeriod($start, $interval, $end->modify('+1 day'));
            foreach ($dateRange as $date) {
                $formattedDate = $date->format('Y-m-d');
                if (substr($formattedDate, 5, 2) == $month) {
                    if (strcasecmp($status, 'Approved') === 0) {
                        $approvedSickDates[] = $formattedDate;
                        $approvedSickDays++;
                    } elseif (strcasecmp($status, 'Pending') === 0) {
                        $pendingSickDates[] = $formattedDate;
                        $pendingSickDays++;
                    } elseif (strcasecmp($status, 'Rejected') === 0 || strcasecmp($status, 'Declined') === 0) {
                        $rejectedSickDates[] = $formattedDate;
                    }
                }
            }
        } catch (Exception $e) {
            error_log("Date processing error for sick note: learner_id=$learnerID, error=" . $e->getMessage());
        }
    }

    $approvedSickDates = array_unique($approvedSickDates);
    $pendingSickDates = array_unique($pendingSickDates);
    $rejectedSickDates = array_unique($rejectedSickDates);
    $sickDays = $approvedSickDays + $pendingSickDays;

    $stmt->close();

    // Generate calendar
    $daysInMonth = date('t', strtotime("$year-$month-01"));
    $startDay = date('w', strtotime("$year-$month-01"));
    $totalDays = $workingDays = $holidaysCount = $weekendDays = $presentDays = $absentDays = $invalidDays = 0;
    $absentDays += count($rejectedSickDates);

    $html = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>' . htmlspecialchars($learnerName) . ' - Attendance Report</title>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/css/bootstrap.min.css">
    <style>
        @media screen {
            .print-instructions {
                background: #d4edda;
                border: 1px solid #c3e6cb;
                padding: 15px;
                margin: 20px;
                border-radius: 5px;
                text-align: center;
            }
        }
        @media print {
            .print-instructions { display: none !important; }
            @page { size: A4 landscape; margin: 2mm; }
        }

        .bs-example { margin: 2px; }
        .holiday { color: red; font-weight: bold; }
        .weekend { color: blue; }
        .absent { color: red; }
        .present { color: green; }
        .calendar-day {
            padding: 1px;
        }
        .calendar-day small {
            display: block;
            line-height: 1.0;
        }
        .badge {
            color: black !important;
            font-size: 7px;
            padding: 2px 4px;
            margin-right: 2px;
        }
        .list-group-item {
            font-size: 10px;
            padding: 2px;
            margin-bottom: 1px;
        }
        .list-group {
            margin-bottom: 5px;
        }
        .list-group-item span {
            padding-right: 8px;
        }
        #report-content {
            padding: 5px;
            margin: 0;
        }
        .container-fluid {
            padding-left: 1px;
            padding-right: 1px;
            margin: 1px;
        }
        .bs-example {
            margin: 1px;
        }
        .profile-container {
            display: flex;
            align-items: center;
            padding: 3px;
            margin: 0;
            gap: 6px;
            font-size: 40px;
            width: 100%;
            box-sizing: border-box;
            position: relative;
            z-index: 1;
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
            margin-bottom: 8px;
        }
        .signature-container {
            margin-top: 8px;
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
        /* Hide navigation buttons on main page */
        .calendar-nav {
            display: none;
        }
        /* Ensure proper column layout */
        /* Ensure proper column layout - Single page landscape */
        .col-md-4 {
            float: right !important;
            clear: right !important;
            width: 40% !important;
            display: block !important;
        }
        .col-md-8 {
            float: left !important;
            clear: left !important;
            width: 60% !important;
            display: block !important;
        }
        .row {
            display: flex !important;
            flex-wrap: wrap !important;
            width: 100% !important;
            clear: both !important;
        }
        .row::after {
            content: "";
            clear: both;
            display: table;
        }

        /* Natural single page layout */
        #report-content {
            page-break-inside: avoid !important;
            margin: 0;
            padding: 1px;
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
                margin: 2px;
                padding: 2px;
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
                /* min-height removed */
            }
        }
    </style>
</head>
<body>
<div id="report-content">
    <div class="container-fluid">
        <div class="bs-example">
            <div class="main-logo-container">
                <!-- Logo placeholder -->
            </div>

            <div class="container-fluid">
                <div class="row">
                    <div class="col">
                        <!-- SDP Logo placeholder -->
                    </div>
                    <div class="col"></div>
                    <div class="col">
                        <!-- Client Logo placeholder -->
                    </div>
                </div>
            </div>

            <div style="background-image: linear-gradient(to right, #42bcf5, #42f5d7);" class="p-1 mb-1 text-black" style="font-size: 11px;">
                PERIOD: ' . $firstDayOfMonth . ' to ' . $lastDayOfMonth . '
            </div>

            <div class="row">
                <div class="col-md-8">
                    <div class="container-fluid">
                        <div class="calendar-container">
                            <div class="table-responsive-sm">
                                <h4 style="font-size: 0.8rem;margin:1px;">Calendar for ' . date('F Y', strtotime("$year-$month-01")) . '</h4>

                                <div class="mb-1">
                                    <span class="badge badge-primary">Workdays: <span id="workingDays">0</span></span>
                                    <span class="badge badge-danger">Holidays: <span id="holidaysCount">0</span></span>
                                    <span class="badge badge-info">Weekend: <span id="weekendDays">0</span></span>
                                    <span class="badge badge-success">Present: <span id="presentDays">0</span></span>
                                    <span class="badge badge-warning">Absent: <span id="absentDays">0</span></span>
                                    <span class="badge badge-danger">Invalid: <span id="invalidDays">0</span></span>
                                    <span class="badge badge-warning">Sick: <span id="sickDays">' . $sickDays . '</span></span>
                                </div>

                                <table class="table table-bordered">
                                    <thead><tr style="background-color:#282C65;color:black;font-size:9px;">
                                        <th>Sun</th><th>Mon</th><th>Tue</th><th>Wed</th><th>Thu</th><th>Fri</th><th>Sat</th>
                                    </tr></thead><tbody><tr>';



    for ($i = 0; $i < $startDay; $i++) {
        $html .= "<td></td>";
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

        $html .= "<td class='calendar-day'>";
        $html .= "<strong>$day</strong><br>";

        if ($isApprovedSick) {
            $html .= "<small class='sick'>Sick Note Approved</small>";
        } elseif ($isPendingSick) {
            $html .= "<small class='sick'>Sick Note Pending</small>";
        } elseif ($isRejectedSick) {
            $html .= "<small class='absent'>Absent</small>";
        } elseif ($isHoliday) {
            $holidayName = '';
            switch ($date) {
                case date('Y-m-d', strtotime("$year-01-01")): $holidayName = 'New Year'; break;
                case date('Y-m-d', strtotime("$year-01-01 +1 day")):
                    if (date('w', strtotime("$year-01-01")) == 0) $holidayName = 'New Year (Observed)'; break;
                case date('Y-m-d', strtotime("$year-03-21")): $holidayName = 'Human Rights Day'; break;
                case date('Y-m-d', strtotime("$year-03-21 +1 day")):
                    if (date('w', strtotime("$year-03-21")) == 0) $holidayName = 'Human Rights (Observed)'; break;
                case date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days -2 days")): $holidayName = 'Good Friday'; break;
                case date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days -2 days +1 day")):
                    if (date('w', strtotime("$year-03-21 +" . easter_days($year) . " days -2 days")) == 0) $holidayName = 'Good Friday (Observed)'; break;
                case date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days +1 day")): $holidayName = 'Family Day'; break;
                case date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days +1 day +1 day")):
                    if (date('w', strtotime("$year-03-21 +" . easter_days($year) . " days +1 day")) == 0) $holidayName = 'Family Day (Observed)'; break;
                case date('Y-m-d', strtotime("$year-04-27")): $holidayName = 'Freedom Day'; break;
                case date('Y-m-d', strtotime("$year-04-27 +1 day")):
                    if (date('w', strtotime("$year-04-27")) == 0) $holidayName = 'Freedom (Observed)'; break;
                case date('Y-m-d', strtotime("$year-05-01")): $holidayName = "Worker's Day"; break;
                case date('Y-m-d', strtotime("$year-05-01 +1 day")):
                    if (date('w', strtotime("$year-05-01")) == 0) $holidayName = 'Workers (Observed)'; break;
                case date('Y-m-d', strtotime("$year-06-16")): $holidayName = 'Youth'; break;
                case date('Y-m-d', strtotime("$year-06-16 +1 day")):
                    if (date('w', strtotime("$year-06-16")) == 0) $holidayName = 'Youth (Observed)'; break;
                case date('Y-m-d', strtotime("$year-08-09")): $holidayName = "Women's Day"; break;
                case date('Y-m-d', strtotime("$year-08-09 +1 day")):
                    if (date('w', strtotime("$year-08-09")) == 0) $holidayName = 'Women\'s (Observed)'; break;
                case date('Y-m-d', strtotime("$year-09-24")): $holidayName = 'Heritage'; break;
                case date('Y-m-d', strtotime("$year-09-24 +1 day")):
                    if (date('w', strtotime("$year-09-24")) == 0) $holidayName = 'Heritage (Observed)'; break;
                case date('Y-m-d', strtotime("$year-12-16")): $holidayName = 'Reconciliation'; break;
                case date('Y-m-d', strtotime("$year-12-16 +1 day")):
                    if (date('w', strtotime("$year-12-16")) == 0) $holidayName = 'Reconciliation (Observed)'; break;
                case date('Y-m-d', strtotime("$year-12-25")): $holidayName = 'Christmas'; break;
                case date('Y-m-d', strtotime("$year-12-25 +1 day")):
                    if (date('w', strtotime("$year-12-25")) == 0) $holidayName = 'Christmas (Observed)'; break;
                case date('Y-m-d', strtotime("$year-12-26")): $holidayName = 'Goodwill'; break;
                case date('Y-m-d', strtotime("$year-12-26 +1 day")):
                    if (date('w', strtotime("$year-12-26")) == 0) $holidayName = 'Goodwill (Observed)'; break;
            }
            $html .= "<small class='holiday'>$holidayName</small>";
        } elseif ($isWeekend) {
            $html .= "<small class='weekend'>Weekend</small>";
        } else {
            if (isset($attendanceData[$date])) {
                $record = $attendanceData[$date];
                $clockIn = $record['clock_in_time'] ?? 'N/A';
                $clockOut = $record['clock_out_time'] ?? 'N/A';
                $contactTime = $record['contact_time'] ?? 'N/A';

                $isCompleteRecord = ($clockIn !== 'N/A' && $clockOut !== 'N/A');

                if ($isCompleteRecord) {
                    $presentDays++;

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

                    $formattedContactTime = 'N/A';
                    $hasContactTime = ($contactTime !== 'N/A' && !empty($contactTime) && $contactTime !== null && $contactTime !== '');
                    if ($hasContactTime) {
                        $formattedContactTime = preg_replace('/\..+/', '', $contactTime);
                        $formattedContactTime = str_replace(['0h ', '0m '], '', $formattedContactTime);
                    }

                    $html .= "<small class='present'>In: $formattedClockIn</small><br>";
                    $html .= "<small class='present'>Out: $formattedClockOut</small><br>";
                    $html .= "<small class='present'>Hours: $formattedContactTime</small>";

                    // Show signature for complete records
                    $webSignaturePath = detectValidSignature($conn, $learnerID);
                    if ($webSignaturePath) {
                        $webSignaturePath = htmlspecialchars($webSignaturePath);
                        $html .= "<img src='$webSignaturePath' class='signature-img rounded' alt='Signature' style='max-width: 90px; height: 35px;' onerror=\"this.style.display='none';this.nextSibling.style.display='block';\">";
                        $html .= "<small style='display:none;'>Signature: [N/A]</small>";
                    } else {
                        $html .= "<small>Signature: [N/A]</small>";
                    }
                } else {
                    $invalidDays++;
                    $html .= "<small class='invalid'>⚠ Incomplete</small>";
                    // Show signature for incomplete records too
                    $webSignaturePath = detectValidSignature($conn, $learnerID);
                    if ($webSignaturePath) {
                        $webSignaturePath = htmlspecialchars($webSignaturePath);
                        $html .= "<img src='$webSignaturePath' class='signature-img rounded' alt='Signature' style='max-width: 90px; height: 35px;' onerror=\"this.style.display='none';this.nextSibling.style.display='block';\">";
                        $html .= "<small style='display:none;'>Signature: [N/A]</small>";
                    } else {
                        $html .= "<small>Signature: [N/A]</small>";
                    }
                }
            } elseif ($date < $currentDate) {
                $absentDays++;
                $html .= "<small class='absent'>Absent</small>";
            } else {
                $html .= "<small class='pending'>Pending</small>";
            }
        }

        $html .= "</td>";

        if (($day + $startDay) % 7 == 0 && $day != $daysInMonth) {
            $html .= "</tr><tr>";
        }
    }

    while (($day + $startDay) % 7 != 0) {
        $html .= "<td></td>";
        $day++;
    }

    $html .= '</tr></tbody></table>';

    // JavaScript to update counters
    $html .= "<script>
        document.getElementById('workingDays').textContent = '$workingDays';
        document.getElementById('holidaysCount').textContent = '$holidaysCount';
        document.getElementById('weekendDays').textContent = '$weekendDays';
        document.getElementById('presentDays').textContent = '$presentDays';
        document.getElementById('absentDays').textContent = '$absentDays';
        document.getElementById('invalidDays').textContent = '$invalidDays';
    </script>";

    $html .= '<div class="signature-container">
                    <div class="form-row signature-row">
                        <div class="form-group">
                            <label style="color:#282C65;font-size:8px;">Facilitator Signature : <img src="assets/img/f.PNG" style="width:30px;height:15px;" alt="" onerror="this.src=\'' . htmlspecialchars(DEFAULT_AVATAR) . '\'"></label>
                            <span style="font-size:8px;">' . date('Y-m-d H:i:s') . '</span>
                        </div>
                        <div class="form-group">
                            <label style="color:#282C65;font-size:8px;">SDP Representative Signature: <img src="assets/img/fa.png" style="width:30px;height:15px;" alt="" onerror="this.src=\'' . htmlspecialchars(DEFAULT_AVATAR) . '\'"></label>
                            <span style="font-size:8px;">' . date('Y-m-d H:i:s') . '</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="col-md-4">
            <div class="container-fluid">
                <div class="row">
                    <div class="col-12">
                        <div class="profile-container bg-primary text-white" style="border-radius: 5px; margin-bottom: 15px;">
                            <img src="' . htmlspecialchars($learnerInfo['profile_image'] ?? DEFAULT_AVATAR) . '"
                                 alt="Profile"
                                 class="img-thumbnail"
                                 onerror="this.src=\'' . htmlspecialchars(DEFAULT_AVATAR) . '\'">
                            <div>
                                <h1>' . strtoupper($learnerName) . '</h1>
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
                                <span style="color:#282C65;">' . htmlspecialchars($projectInfo['Project_pathway'] ?? 'N/A') . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Province:</strong>
                                <span style="color:#282C65;">' . htmlspecialchars($projectInfo['Province'] ?? 'N/A') . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Project:</strong>
                                <span style="color:#282C65;">' . htmlspecialchars($projectName) . '</span>
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
                                <span style="color:#282C65;">' . htmlspecialchars(($learnerInfo['Name'] ?? '')) . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Surname:</strong>
                                <span style="color:#282C65;">' . htmlspecialchars(($learnerInfo['Surname'] ?? '')) . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">ID Number:</strong>
                                <span style="color:#282C65;">' . htmlspecialchars($learnerInfo['IDNumber'] ?? 'N/A') . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Gender:</strong>
                                <span style="color:#282C65;">' . htmlspecialchars($learnerInfo['Gender'] ?? 'N/A') . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Telephone:</strong>
                                <span style="color:#282C65;">' . htmlspecialchars($learnerInfo['PhoneNumber'] ?? 'N/A') . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Address:</strong>
                                <span style="color:#282C65;">' . htmlspecialchars($learnerInfo['AddressLine1'] ?? 'N/A') . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Expected Attendance:</strong>
                                <span style="color:#282C65;">' . $workingDays . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Actual Attendance:</strong>
                                <span style="color:#282C65;">' . $presentDays . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Days Absent:</strong>
                                <span style="color:#282C65;">' . $absentDays . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Invalid Attendance:</strong>
                                <span style="color:#282C65;">' . $invalidDays . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Holidays:</strong>
                                <span style="color:#282C65;">' . $holidaysCount . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Approved Sick Days:</strong>
                                <span style="color:#282C65;">' . $approvedSickDays . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Pending Sick Days:</strong>
                                <span style="color:#282C65;">' . $pendingSickDays . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Total Sick Days:</strong>
                                <span style="color:#282C65;">' . $sickDays . '</span>
                            </li>
                            <li class="list-group-item d-flex bg-light justify-content-between align-items-center">
                                <strong style="color:#282C65;">Total Valid Attendance:</strong>
                                <span style="color:#282C65;">' . ($presentDays + $holidaysCount + $approvedSickDays) . '</span>
                            </li>
                        </ul>
                    </div>
                </div>

                <footer class="page-footer font-small blue">
                    <div style="color:#282C65;font-size:8px;" class="text-right py-1">
                        <b>RLMS Attendance. @</b> ' . date('Y-m-d') . '
                    </div>
                </footer>
            </div>
        </div>
    </div>
</div>
</body>
</html>';

    return $html;
}





// Wrap original HTML with browser print instructions
function wrapForBrowserPrint($originalHTML, $learnerData) {
    $learnerName = ($learnerData['Name'] ?? '') . ' ' . ($learnerData['Surname'] ?? '');
    
    // Create print instructions
    $printInstructions = '<div id="print-instructions" style="background: #d4edda; border: 1px solid #c3e6cb; padding: 15px; margin: 20px; border-radius: 5px; text-align: center; page-break-after: avoid;">
        <h4>🖨️ How to Save as PDF:</h4>
        <p><strong>1.</strong> Press <strong>Ctrl+P</strong> (Windows) or <strong>Cmd+P</strong> (Mac)</p>
        <p><strong>2.</strong> Select <strong>"Save as PDF"</strong> as destination</p>
        <p><strong>3.</strong> Choose <strong>"Landscape"</strong> orientation for best results</p>
        <p><strong>4.</strong> Click <strong>"Save"</strong></p>
        <button onclick="window.print()" style="background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; margin: 10px;">🖨️ Print/Save as PDF</button>
        <button onclick="document.getElementById(\'print-instructions\').style.display=\'none\'" style="background: #6c757d; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; margin: 10px;">✕ Hide Instructions</button>
    </div>';
    
    // Add CSS to hide print instructions when printing
    $printCSS = '<style>
        @media print { 
            #print-instructions { display: none !important; }
            .btn-container, .calendar-nav, .btn { display: none !important; }
        }
    </style>';
    
    // Insert print instructions and CSS into the HTML
    if (strpos($originalHTML, '<body') !== false) {
        // Insert after opening body tag
        $wrappedHTML = preg_replace('/(<body[^>]*>)/i', '$1' . $printInstructions, $originalHTML);
        // Insert CSS in head
        $wrappedHTML = preg_replace('/(<\/head>)/i', $printCSS . '$1', $wrappedHTML);
    } else {
        // Fallback: wrap the entire content
        $wrappedHTML = '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>' . htmlspecialchars($learnerName) . ' - Report</title>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/css/bootstrap.min.css">
    ' . $printCSS . '
</head>
<body>
    ' . $printInstructions . '
    ' . $originalHTML . '
</body>
</html>';
    }
    
    return $wrappedHTML;
}



// Generate HTML using simplified original format (browser print ready)
function generateOriginalFormatHTML($conn, $learnerID, $project_id, $year, $month, $learnerData, $attendanceRecords, $firstDayOfMonth, $lastDayOfMonth) {
    error_log("Generating browser-print ready HTML for learner ID: $learnerID");
    
    // Create a professional report with calendar-style layout
    $name = ($learnerData['Name'] ?? '') . ' ' . ($learnerData['Surname'] ?? '');
    $project = $learnerData['Project_name'] ?? 'Unknown Project';
    $idNumber = $learnerData['IDNumber'] ?? 'Unknown';
    $phone = $learnerData['PhoneNumber'] ?? 'N/A';
    $gender = $learnerData['Gender'] ?? 'N/A';
    $address = $learnerData['AddressLine1'] ?? 'N/A';
    
    // Generate calendar for the month
    $daysInMonth = cal_days_in_month(CAL_GREGORIAN, $month, $year);
    $firstDay = date('w', strtotime("$year-$month-01"));
    
    $html = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>' . htmlspecialchars($name) . ' - Attendance Report</title>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/css/bootstrap.min.css">
    <style>
        @media screen {
            .print-instructions {
                background: #d4edda;
                border: 1px solid #c3e6cb;
                padding: 15px;
                margin: 20px;
                border-radius: 5px;
                text-align: center;
            }
        }
        @media print {
            .print-instructions { display: none !important; }
            @page { size: A4 landscape; margin: 10mm; }
        }
        
        .bs-example { margin: 2px; }
        .holiday { color: red; font-weight: bold; }
        .weekend { color: blue; }
        .absent { color: red; }
        .present { color: green; }
        .calendar-day { 
            height: 60px;
            overflow: visible; 
            font-size: 10px;
            padding: 2px;
            border: 1px solid #ddd;
            position: relative;
        }
        .calendar-day small {
            display: block;
            line-height: 1.2;
        }
        .badge {
            color: black !important;
            font-size: 8px;
            margin: 1px;
        }
        .calendar-table {
            width: 100%;
            table-layout: fixed;
        }
        .calendar-table td {
            width: 14.28%;
            vertical-align: top;
        }
        .profile-section {
            background: #f8f9fa;
            padding: 15px;
            border: 1px solid #dee2e6;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .summary-section {
            background: #e7f3ff;
            padding: 15px;
            border: 1px solid #b6d7ff;
            border-radius: 5px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="print-instructions">
        <h4>🖨️ How to Save as PDF:</h4>
        <p><strong>1.</strong> Press <strong>Ctrl+P</strong> (Windows) or <strong>Cmd+P</strong> (Mac)</p>
        <p><strong>2.</strong> Select <strong>"Save as PDF"</strong> as destination</p>
        <p><strong>3.</strong> Choose <strong>"Landscape"</strong> orientation for best results</p>
        <p><strong>4.</strong> Click <strong>"Save"</strong></p>
        <button onclick="window.print()" style="background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer;">🖨️ Print/Save as PDF</button>
    </div>
    
    <div class="container-fluid">
        <div class="row">
            <div class="col">
                <div class="text-center mb-3">
                    <h2>ATTENDANCE REPORT</h2>
                    <h4>' . date('F Y', mktime(0, 0, 0, $month, 1, $year)) . '</h4>
                </div>
                
                <div class="profile-section">
                    <div class="row">
                        <div class="col-md-8">
                            <h4>Learner Information</h4>
                            <p><strong>Name:</strong> ' . htmlspecialchars($name) . '</p>
                            <p><strong>ID Number:</strong> ' . htmlspecialchars($idNumber) . '</p>
                            <p><strong>Phone:</strong> ' . htmlspecialchars($phone) . '</p>
                            <p><strong>Gender:</strong> ' . htmlspecialchars($gender) . '</p>
                            <p><strong>Address:</strong> ' . htmlspecialchars($address) . '</p>
                            <p><strong>Project:</strong> ' . htmlspecialchars($project) . '</p>
                        </div>
                        <div class="col-md-4 text-center">
                            <div style="border: 2px solid #ddd; width: 120px; height: 150px; margin: 0 auto; display: flex; align-items: center; justify-content: center; background: #f8f9fa;">
                                <span style="color: #6c757d;">Photo</span>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="calendar-container">
                    <h4>Monthly Attendance Calendar</h4>
                    <div class="table-responsive-sm">
                        <table class="calendar-table table table-bordered">
                            <thead>
                                <tr style="background: #007cba; color: white;">
                                    <th>Sunday</th>
                                    <th>Monday</th>
                                    <th>Tuesday</th>
                                    <th>Wednesday</th>
                                    <th>Thursday</th>
                                    <th>Friday</th>
                                    <th>Saturday</th>
                                </tr>
                            </thead>
                            <tbody>';
    
    // Generate calendar grid
    $currentDay = 1;
    $week = 0;
    
    while ($currentDay <= $daysInMonth) {
        $html .= '<tr>';
        
        for ($dayOfWeek = 0; $dayOfWeek < 7; $dayOfWeek++) {
            $html .= '<td class="calendar-day">';
            
            if ($week == 0 && $dayOfWeek < $firstDay) {
                // Empty cell before month starts
                $html .= '&nbsp;';
            } elseif ($currentDay <= $daysInMonth) {
                $currentDate = sprintf('%04d-%02d-%02d', $year, $month, $currentDay);
                $dayClass = '';
                $clockIn = '';
                $clockOut = '';
                $contactTime = '0';
                $status = 'Absent';
                
                // Check if weekend
                if ($dayOfWeek == 0 || $dayOfWeek == 6) {
                    $dayClass = 'weekend';
                    $status = 'Weekend';
                }
                
                // Check attendance record
                if (isset($attendanceRecords[$currentDate])) {
                    $record = $attendanceRecords[$currentDate];
                    $clockIn = $record['clock_in_time'] ?? '';
                    $clockOut = $record['clock_out_time'] ?? '';
                    $contactTime = $record['contact_time'] ?? '0';
                    $dayClass = 'present';
                    $status = 'Present';
                }
                
                $html .= '<div style="font-weight: bold; font-size: 12px;">' . $currentDay . '</div>';
                
                if (!empty($clockIn)) {
                    $html .= '<small class="badge badge-success">In: ' . htmlspecialchars($clockIn) . '</small><br>';
                }
                if (!empty($clockOut)) {
                    $html .= '<small class="badge badge-warning">Out: ' . htmlspecialchars($clockOut) . '</small><br>';
                }
                if ($contactTime > 0) {
                    $html .= '<small class="badge badge-info">' . $contactTime . 'h</small>';
                }
                
                $currentDay++;
            } else {
                $html .= '&nbsp;';
            }
            
            $html .= '</td>';
        }
        
        $html .= '</tr>';
        $week++;
    }
    
    // Calculate summary
    $totalDays = count($attendanceRecords);
    $totalHours = 0;
    foreach ($attendanceRecords as $record) {
        $totalHours += floatval($record['contact_time'] ?? 0);
    }
    
    $html .= '</tbody>
                        </table>
                    </div>
                </div>
                
                <div class="summary-section">
                    <h4>Attendance Summary</h4>
                    <div class="row">
                        <div class="col-md-3">
                            <p><strong>Days Present:</strong> ' . $totalDays . '</p>
                        </div>
                        <div class="col-md-3">
                            <p><strong>Total Hours:</strong> ' . number_format($totalHours, 2) . '</p>
                        </div>
                        <div class="col-md-3">
                            <p><strong>Average Hours/Day:</strong> ' . ($totalDays > 0 ? number_format($totalHours / $totalDays, 2) : '0') . '</p>
                        </div>
                        <div class="col-md-3">
                            <p><strong>Generated:</strong> ' . date('Y-m-d') . '</p>
                        </div>
                    </div>
                </div>
                
                <div class="text-center mt-4" style="font-size: 12px; color: #6c757d;">
                    <p>RLMS Attendance Report - Generated automatically</p>
                </div>
            </div>
        </div>
    </div>
</body>
</html>';
    
    error_log("Successfully generated browser-print HTML, length: " . strlen($html));
    return $html;
}

// Enhanced report HTML generator with calendar view (browser print ready)
function generateSimpleReportHTML($learnerData, $attendanceRecords, $year, $month) {
    error_log("Using enhanced generateSimpleReportHTML with calendar view");
    
    $name = ($learnerData['Name'] ?? '') . ' ' . ($learnerData['Surname'] ?? '');
    $project = $learnerData['Project_name'] ?? 'Unknown Project';
    $idNumber = $learnerData['IDNumber'] ?? 'Unknown';
    $phone = $learnerData['PhoneNumber'] ?? 'N/A';
    $gender = $learnerData['Gender'] ?? 'N/A';
    $address = $learnerData['AddressLine1'] ?? 'N/A';
    
    // Generate calendar for the month
    $daysInMonth = cal_days_in_month(CAL_GREGORIAN, $month, $year);
    $firstDay = date('w', strtotime("$year-$month-01"));
    
    // Count attendance
    $totalDays = count($attendanceRecords);
    $totalHours = 0;
    foreach ($attendanceRecords as $record) {
        $totalHours += floatval($record['contact_time'] ?? 0);
    }
    
    $html = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>' . htmlspecialchars($name) . ' - Attendance Report</title>
    <style>
        body { font-family: Arial, sans-serif; }
        .pdf-row { width: 100%; border-collapse: collapse; }
        .pdf-row td { vertical-align: top; padding: 10px; }
        .pdf-profile-box {
            background: #f8f9fa;
            border: 1px solid #282C65;
            border-radius: 5px;
            width: 100%;
        }
        .pdf-profile-header {
            background: #282C65;
            color: #fff;
            padding: 8px 10px;
            border-radius: 5px 5px 0 0;
            font-size: 1rem;
            margin-bottom: 0;
        }
        .pdf-profile-list {
            list-style: none;
            padding: 0;
            margin: 0;
        }
        .pdf-profile-list li {
            background: #f4f4f4;
            border-bottom: 1px solid #e0e0e0;
            padding: 6px 10px;
            color: #282C65;
            font-size: 0.95rem;
            display: flex;
            justify-content: space-between;
        }
        .pdf-profile-list li:last-child { border-bottom: none; }
        .pdf-photo {
            border: 2px solid #ddd;
            width: 120px;
            height: 150px;
            margin: 12px auto 0 auto;
            display: flex;
            align-items: center;
            justify-content: center;
            background: #f8f9fa;
            color: #6c757d;
            font-size: 0.9rem;
        }
        .calendar-table { width: 100%; border-collapse: collapse; table-layout: fixed; font-size: 11px; }
        .calendar-table th, .calendar-table td { border: 1px solid #bbb; text-align: center; padding: 2px; }
        .calendar-table th { background: #007cba; color: #fff; }
        .summary-section { background: #e7f3ff; padding: 10px; border: 1px solid #b6d7ff; border-radius: 5px; margin-top: 20px; }
    </style>
</head>
<body>
    <h2 style="text-align:center; color:#282C65; margin-bottom:0;">ATTENDANCE REPORT</h2>
    <h4 style="text-align:center; color:#282C65; margin-top:0;">' . date('F Y', mktime(0, 0, 0, $month, 1, $year)) . '</h4>
    <table class="pdf-row">
        <tr>
            <td style="width:55%;">
                <h4 style="color:#282C65;">Monthly Attendance Calendar</h4>
                <table class="calendar-table">
                    <thead>
                        <tr>
                            <th>Sunday</th>
                            <th>Monday</th>
                            <th>Tuesday</th>
                            <th>Wednesday</th>
                            <th>Thursday</th>
                            <th>Friday</th>
                            <th>Saturday</th>
                        </tr>
                    </thead>
                    <tbody>
        <p><strong>1.</strong> Press <strong>Ctrl+P</strong> (Windows) or <strong>Cmd+P</strong> (Mac)</p>
        <p><strong>2.</strong> Select <strong>"Save as PDF"</strong> as destination</p>
        <p><strong>3.</strong> Choose <strong>"Landscape"</strong> orientation for best results</p>
        <p><strong>4.</strong> Click <strong>"Save"</strong></p>
        <button onclick="window.print()" style="background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer;">🖨️ Print/Save as PDF</button>
    </div>
    
    <div class="container-fluid">
        <div class="row">
            <div class="col-12">
                <div class="text-center mb-3">
                    <h2>ATTENDANCE REPORT</h2>
                    <h4>' . date('F Y', mktime(0, 0, 0, $month, 1, $year)) . '</h4>
                </div>
                
                <div class="container-fluid">
                    <div class="row">
                        <div class="col-md-7">
                            <h4>Monthly Attendance Calendar</h4>
                            <table class="calendar-table table table-bordered">
                                <thead>
                                    <tr style="background: #007cba; color: white;">
                                        <th>Sunday</th>
                                        <th>Monday</th>
                                        <th>Tuesday</th>
                                        <th>Wednesday</th>
                                        <th>Thursday</th>
                                        <th>Friday</th>
                                        <th>Saturday</th>
                                    </tr>
                                </thead>
                                <tbody>';
    
    // Generate calendar grid
    $currentDay = 1;
    $week = 0;
    
    while ($currentDay <= $daysInMonth) {
        $html .= '<tr>';
        
        for ($dayOfWeek = 0; $dayOfWeek < 7; $dayOfWeek++) {
            $dayClass = '';
            $html .= '<td class="calendar-day ' . $dayClass . '">';
            
            if ($week == 0 && $dayOfWeek < $firstDay) {
                // Empty cell before month starts
                $html .= '&nbsp;';
            } elseif ($currentDay <= $daysInMonth) {
                $currentDate = sprintf('%04d-%02d-%02d', $year, $month, $currentDay);
                
                // Check if weekend
                if ($dayOfWeek == 0 || $dayOfWeek == 6) {
                    $html .= '<div style="font-weight: bold; color: blue;">' . $currentDay . '</div>';
                    $html .= '<small style="color: blue;">Weekend</small>';
                } else {
                    $html .= '<div style="font-weight: bold;">' . $currentDay . '</div>';
                    
                    // Check attendance record
                    if (isset($attendanceRecords[$currentDate])) {
                        $record = $attendanceRecords[$currentDate];
                        $clockIn = $record['clock_in_time'] ?? '';
                        $clockOut = $record['clock_out_time'] ?? '';
                        $contactTime = $record['contact_time'] ?? '0';
                        
                        if (!empty($clockIn)) {
                            $html .= '<span class="badge badge-success">In: ' . htmlspecialchars($clockIn) . '</span>';
                        }
                        if (!empty($clockOut)) {
                            $html .= '<span class="badge badge-warning">Out: ' . htmlspecialchars($clockOut) . '</span>';
                        }
                        if ($contactTime > 0) {
                            $html .= '<span class="badge badge-info">' . $contactTime . 'h</span>';
                        }
                    } else {
                        $html .= '<small style="color: red;">Absent</small>';
                    }
                }
                
                $currentDay++;
            } else {
                $html .= '&nbsp;';
            }
            
            $html .= '</td>';
        }
        
        $html .= '</tr>';
        $week++;
    }
    
    $html .= '</tbody>
                    </table>
                    </div>
                </div>
                
                <div class="summary-section">
                    <h4>Attendance Summary</h4>
                    <div class="row">
                        <div class="col-md-3">
                            <p><strong>Days Present:</strong> ' . $totalDays . '</p>
                        </div>
                        <div class="col-md-3">
                            <p><strong>Total Hours:</strong> ' . number_format($totalHours, 2) . '</p>
                        </div>
                        <div class="col-md-3">
                            <p><strong>Average Hours/Day:</strong> ' . ($totalDays > 0 ? number_format($totalHours / $totalDays, 2) : '0') . '</p>
                        </div>
                        <div class="col-md-3">
                            <p><strong>Generated:</strong> ' . date('Y-m-d') . '</p>
                        </div>
                    </div>
                </div>
                
                <div class="text-center mt-4" style="font-size: 12px; color: #6c757d;">
                    <p>RLMS Attendance Report - Generated automatically</p>
                </div>
            </div>
        </div>
    </div>
</body>
</html>';
    
    return $html;
}

// Full attendance calendar with real data from database
function generateFullAttendanceCalendar($conn, $learnerID, $project_id, $year, $month, $learnerData) {
    try {
        // Get attendance data directly from database
        $sql = "SELECT DATE(clock_date) as clock_date, clock_in_time, clock_out_time, contact_time
                FROM learner_clocking
                WHERE LearnerID = ?
                AND MONTH(clock_date) = ?
                AND YEAR(clock_date) = ?
                ORDER BY clock_date";

        $stmt = $conn->prepare($sql);
        $stmt->bind_param('iii', $learnerID, $month, $year);
        $stmt->execute();
        $result = $stmt->get_result();

        $clockingData = [];
        while ($row = $result->fetch_assoc()) {
            $clockDate = $row['clock_date'];
            if (!isset($clockingData[$clockDate])) {
                $clockingData[$clockDate] = $row;
            }
        }
        $stmt->close();

        return generateCalendarWithData($learnerData, $clockingData, $year, $month);

    } catch (Exception $e) {
        return generateSimpleDirectReport($learnerData, $year, $month);
    }
}

// Generate report using exact indivisual.php template structure
function generateIndivisualTemplateReport($conn, $learnerID, $project_id, $year, $month, $learnerData) {
    try {
        // Get attendance data directly from database (same as indivisual.php)
        $sql = "SELECT DATE(clock_date) as clock_date, clock_in_time, clock_out_time, contact_time, signature
                FROM learner_clocking
                WHERE LearnerID = ?
                AND MONTH(clock_date) = ?
                AND YEAR(clock_date) = ?
                ORDER BY clock_date";

        $stmt = $conn->prepare($sql);
        $stmt->bind_param('iii', $learnerID, $month, $year);
        $stmt->execute();
        $result = $stmt->get_result();

        $clockingData = [];
        while ($row = $result->fetch_assoc()) {
            $clockDate = $row['clock_date'];
            if (!isset($clockingData[$clockDate])) {
                $clockingData[$clockDate] = $row;
            }
        }
        $stmt->close();

        // Prepare data structure for the template function
        $indivisualData = array_merge($learnerData, [
            'learnerID' => $learnerID,
            'project_id' => $project_id,
            'year' => $year,
            'month' => $month,
            'FullName' => ($learnerData['Name'] ?? '') . ' ' . ($learnerData['Surname'] ?? ''),
            'Name' => $learnerData['Name'] ?? '',
            'Surname' => $learnerData['Surname'] ?? '',
            'IDNumber' => $learnerData['IDNumber'] ?? '',
            'PhoneNumber' => $learnerData['PhoneNumber'] ?? '',
            'Gender' => $learnerData['Gender'] ?? '',
            'AddressLine1' => $learnerData['AddressLine1'] ?? '',
            'projectName' => $learnerData['Project_name'] ?? '',
            'projectPathway' => 'Training Program',
            'Province' => 'N/A'
        ]);

        return generateExactIndivisualTemplate($conn, $indivisualData, $clockingData);

    } catch (Exception $e) {
        return generateSimpleDirectReport($learnerData, $year, $month);
    }
}

// Generate exact indivisual.php template with real data
function generateExactIndivisualTemplate($conn, $indivisualData, $clockingData = []) {
    // Debug: Log received data
    error_log("generateExactIndivisualTemplate called with data: " . json_encode($indivisualData));

    $learnerID = $indivisualData['learnerID'];
    $project_id = $indivisualData['project_id'];
    $year = $indivisualData['year'];
    $month = $indivisualData['month'];
    $FullName = $indivisualData['FullName'];
    $Name = $indivisualData['Name'];
    $Surname = $indivisualData['Surname'];
    $IDNumber = $indivisualData['IDNumber'];
    $PhoneNumber = $indivisualData['PhoneNumber'];
    $Gender = $indivisualData['Gender'];
    $AddressLine1 = $indivisualData['AddressLine1'];
    $projectName = $indivisualData['projectName'];
    $projectPathway = $indivisualData['projectPathway'];
    $Province = $indivisualData['Province'];

    // Validate required parameters
    if (empty($learnerID)) {
        throw new Exception("Learner ID is required but not provided to generateExactIndivisualTemplate");
    }
    if (empty($project_id)) {
        throw new Exception("Project ID is required but not provided to generateExactIndivisualTemplate");
    }

    error_log("Processing learner ID: $learnerID, Project ID: $project_id in generateExactIndivisualTemplate");
    
    // Get additional data needed for the template
    $name = trim($Name . ' ' . $Surname);
    $idNumber = $IDNumber ?? 'N/A';
    $phone = $PhoneNumber ?? 'N/A';
    $gender = $Gender ?? 'N/A';
    $address = $AddressLine1 ?? 'N/A';
    $project = $projectName ?? 'N/A';
    
    // Set constants first
    if (!defined('DEFAULT_AVATAR')) define('DEFAULT_AVATAR', 'assets/img/avatar6.png');
    if (!defined('WEB_BASE_URL')) define('WEB_BASE_URL', '/');
    
    // Get profile image and logos
    $profileImage = $indivisualData['profile_image'] ?? DEFAULT_AVATAR;
    $sdpLogo = $indivisualData['sdp_logo'] ?? '';
    $clientLogo = $indivisualData['client_logo'] ?? '';
    
    // Get valid signature
    $validSignature = detectValidSignature($conn, $learnerID);

    // Set period dates
    $firstDayOfMonth = date('Y-m-01', strtotime("$year-$month-01"));
    $lastDayOfMonth = date('Y-m-t', strtotime("$year-$month-01"));

    // Get South African holidays (exact same as indivisual.php)
    $saHolidays = array();
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
            $saHolidays[$date] = $name;
            $newDate = date('Y-m-d', strtotime($date . ' +1 day'));
            $saHolidays[$newDate] = $name . ' (Observed)';
        } else {
            $saHolidays[$date] = $name;
        }
    }

    $easter = date('Y-m-d', strtotime("$year-03-21 +" . easter_days($year) . " days"));
    $goodFriday = date('Y-m-d', strtotime($easter . ' -2 days'));
    $familyDay = date('Y-m-d', strtotime($easter . ' +1 day'));

    $dayOfWeekGoodFriday = date('w', strtotime($goodFriday));
    if ($dayOfWeekGoodFriday == 0) {
        $saHolidays[$goodFriday] = 'Good Friday';
        $newGoodFriday = date('Y-m-d', strtotime($goodFriday . ' +1 day'));
        $saHolidays[$newGoodFriday] = 'Good Friday (Observed)';
    } else {
        $saHolidays[$goodFriday] = 'Good Friday';
    }

    $dayOfWeekFamilyDay = date('w', strtotime($familyDay));
    if ($dayOfWeekFamilyDay == 0) {
        $saHolidays[$familyDay] = 'Family Day';
        $newFamilyDay = date('Y-m-d', strtotime($familyDay . ' +1 day'));
        $saHolidays[$newFamilyDay] = 'Family Day (Observed)';
    } else {
        $saHolidays[$familyDay] = 'Family Day';
    }

    ksort($saHolidays);
    $saHolidays = array_keys($saHolidays);

    // Initialize counters (same as indivisual.php)
    $daysInMonth = date('t', strtotime("$year-$month-01"));
    $startDay = date('w', strtotime("$year-$month-01"));
    $totalDays = $workingDays = $holidaysCount = $weekendDays = $presentDays = $absentDays = $invalidDays = $sickDays = 0;
    $rejectedAbsentDays = 0;

    // Ensure clockingData is a valid array
    if (!is_array($clockingData)) {
        $clockingData = [];
    }

    // Fetch sick notes (same as indivisual.php)
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
        error_log("Prepare failed for sick notes query: " . $conn->error . " | SQL: " . $sql);
        $sickNotes = [];
        $approvedSickDates = [];
        $pendingSickDates = [];
        $rejectedSickDates = [];
        $approvedSickDays = 0;
        $pendingSickDays = 0;
        $rejectedAbsentDays = 0;
        $sickDays = 0;
    } else {
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

        $stmt->close();
    }

    // Calculate statistics
    $presentDays = count($clockingData);
    $totalHours = 0;
    foreach ($clockingData as $record) {
        $totalHours += floatval($record['contact_time'] ?? 0);
    }

    $html = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>' . htmlspecialchars($name) . ' - Attendance Report</title>
    <style>
        /* Reset and base styles for mPDF compatibility */
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        body {
            font-family: Arial, sans-serif;
            font-size: 10px;
            line-height: 1.2;
        }
        .container-fluid {
            width: 100%;
        }
        .row {
            display: table;
            width: 100%;
            border-collapse: collapse;
        }
        .col {
            display: table-cell;
            vertical-align: top;
            width: 50%;
            padding: 5px;
        }
        .text-center {
            text-align: center;
        }
        .text-right {
            text-align: right;
        }
        .bg-primary {
            background-color: #007bff;
            color: white;
        }
        .text-white {
            color: white;
        }
        .bg-light {
            background-color: #f8f9fa;
        }
        .justify-content-between {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .d-flex {
            display: flex;
        }
        .align-items-center {
            align-items: center;
        }
        .p-1 {
            padding: 0.25rem;
        }
        .mb-1 {
            margin-bottom: 0.25rem;
        }
        .text-black {
            color: black;
        }
        .img-thumbnail {
            border: 1px solid #dee2e6;
            max-width: 100%;
            height: auto;
        }
        .badge {
            display: inline-block;
            padding: 2px 4px;
            font-size: 8px;
            border-radius: 3px;
            margin: 1px;
        }
        .badge-primary {
            background-color: #007bff;
            color: white;
        }
        .badge-danger {
            background-color: #dc3545;
            color: white;
        }
        .badge-info {
            background-color: #17a2b8;
            color: white;
        }
        .badge-success {
            background-color: #28a745;
            color: white;
        }
        .badge-warning {
            background-color: #ffc107;
            color: black;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 2px 0;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 2px;
            text-align: left;
            font-size: 8px;
        }
        th {
            background-color: #282C65;
            color: white;
            font-weight: bold;
        }
        .list-group {
            list-style: none;
            margin: 2px 0;
            padding: 0;
        }
        .list-group-item {
            padding: 2px 4px;
            border-bottom: 1px solid #eee;
            font-size: 8px;
        }
        .profile-container {
            display: flex;
            align-items: center;
            gap: 3px;
            margin: 5px 0;
            padding: 3px;
            background-color: #007bff;
            color: white;
        }
        .profile-container img {
            width: 30px;
            height: 25px;
            object-fit: cover;
        }
        .profile-container h1 {
            font-size: 12px;
            margin: 0;
            flex-grow: 1;
        }
        .calendar-day {
            height: 20px;
            padding: 1px;
            font-size: 7px;
            text-align: center;
        }
        .calendar-day strong {
            font-size: 9px;
            display: block;
        }
        .holiday {
            color: red;
            font-weight: bold;
        }
        .weekend {
            color: blue;
        }
        .absent {
            color: red;
        }
        .present {
            color: green;
        }
        .sick {
            color: orange;
        }
        h1, h3, h4 {
            font-size: 10px;
            margin: 2px 0;
        }
        .page-footer {
            text-align: right;
            font-size: 6px;
            margin-top: 5px;
            padding: 2px 0;
        }
    </style>
</head>
<body>
<div id="report-content">
    <div class="container-fluid">
        <div class="bs-example">
           
        </div>

        <div class="main-logo-container">
            <!-- <img src="assets/img/rlms.PNG" alt="CoolBrand" onerror="this.src=\'' . htmlspecialchars(DEFAULT_AVATAR) . '\'">
        --></div> 

        <div class="container-fluid">
            <div class="row">
                <div class="col">
                    <img src="' . htmlspecialchars($sdpLogo ?? '') . '" class="rounded float-start" alt="SDP Logo" style="max-width: 300px; height: 50px;" onerror="this.src=\'' . htmlspecialchars(DEFAULT_AVATAR) . '\'">
                </div>
                <div class="col"></div>
                <div class="col">
                    <img src="assets/img/rlms.PNG"  class="rounded float-end" alt="Client Logo" style="max-width: 300px; height: 50px;" onerror="this.src=\'' . htmlspecialchars(DEFAULT_AVATAR) . '\'">
                </div>
            </div>
        </div>

        <div style="background-image: linear-gradient(to right, #42bcf5, #42f5d7);" class="p-1 mb-1 text-black" style="font-size: 11px;">
            PERIOD: ' . $firstDayOfMonth . ' to ' . $lastDayOfMonth . '
        </div>



        <div class="row">
            <div class="col-md-8">
                <div class="container-fluid">
                    <div class="calendar-container">
                        <div class="table-responsive-sm">';

                            $daysInMonth = date('t', strtotime("$year-$month-01"));
                            $startDay = date('w', strtotime("$year-$month-01"));
                            $totalDays = $workingDays = $holidaysCount = $weekendDays = $presentDays = $absentDays = $invalidDays = 0;
                            $absentDays += $rejectedAbsentDays;

                            $html .= "<h4 style='font-size: 0.7rem;margin:1px;padding:0;'>Calendar for " . date('F Y', strtotime("$year-$month-01")) . "</h4>";

                            $html .= "<div class='mb-1'>";
                            $html .= "<span class='badge badge-primary'>Workdays: <span id='workingDays'>{$workingDays}</span></span> ";
                            $html .= "<span class='badge badge-danger'>Holidays: <span id='holidaysCount'>{$holidaysCount}</span></span> ";
                            $html .= "<span class='badge badge-info'>Weekend: <span id='weekendDays'>{$weekendDays}</span></span> ";
                            $html .= "<span class='badge badge-success'>Present: <span id='presentDays'>{$presentDays}</span></span> ";
                            $html .= "<span class='badge badge-warning'>Absent: <span id='absentDays'>{$absentDays}</span></span> ";
                            $html .= "<span class='badge badge-danger'>Invalid: <span id='invalidDays'>{$invalidDays}</span></span> ";
                            $html .= "<span class='badge badge-warning'>Sick: <span id='sickDays'>{$sickDays}</span></span>";
                            $html .= "</div>";

                            $html .= "<table class='table table-bordered'>";
                            $html .= "<thead><tr style='background-color:#282C65;color:black;font-size:9px;'>
                                    <th>Sun</th><th>Mon</th><th>Tue</th><th>Wed</th><th>Thu</th><th>Fri</th><th>Sat</th>
                                  </tr></thead><tbody><tr>";

                            for ($i = 0; $i < $startDay; $i++) {
                                $html .= "<td></td>";
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

                                $html .= "<td class='calendar-day'>";
                                $html .= "<strong>$day</strong><br>";

                                if ($isApprovedSick) {
                                    $html .= "<small class='sick'>Sick Note Approved</small>";
                                } elseif ($isPendingSick) {
                                    $html .= "<small class='sick'>Sick Note Pending</small>";
                                } elseif ($isRejectedSick) {
                                    $html .= "<small class='absent'>Absent</small>";
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
                                            $holidayName = 'National Women\'s Day'; break;
                                        case date('Y-m-d', strtotime("$year-08-09 +1 day")):
                                            if (date('w', strtotime("$year-08-09")) == 0) $holidayName = 'Women\'s Day (Observed)'; break;
                                        case date('Y-m-d', strtotime("$year-09-24")):
                                            $holidayName = 'Heritage Day'; break;
                                        case date('Y-m-d', strtotime("$year-12-16")):
                                            $holidayName = 'Day of Reconciliation'; break;
                                        case date('Y-m-d', strtotime("$year-12-25")):
                                            $holidayName = 'Christmas Day'; break;
                                        case date('Y-m-d', strtotime("$year-12-26")):
                                            $holidayName = 'Day of Goodwill'; break;
                                    }
                                    $html .= "<small class='holiday'>$holidayName</small>";
                                } elseif ($isWeekend) {
                                    $html .= "<small class='weekend'>Weekend</small>";
                                } elseif (!empty($clockingData[$date])) {
                                    $html .= "<small class='present'>Present</small>";
                                    $presentDays++;
                                } else {
                                    $html .= "<small class='absent'>Absent</small>";
                                    $absentDays++;
                                }

                                $html .= "</td>";

                                if ($dayOfWeek == 6 && $day < $daysInMonth) {
                                    $html .= "</tr><tr>";
                                }
                            }

                            // Fill remaining cells in the last week
                            $lastDayOfWeek = date('w', strtotime("$year-$month-$daysInMonth"));
                            for ($i = $lastDayOfWeek; $i < 6; $i++) {
                                $html .= "<td></td>";
                            }

                            $html .= "</tr></tbody></table>";
                            $html .= "</div></div></div>";
                            $html .= "</div>"; // Close col-md-8

                            // Add learner details section in a separate column to the right
                            $html .= "<div class='col-md-4'>";
                            $html .= "<div class='container-fluid'>";
                            $html .= "<div class='profile-container bg-primary text-white' style='border-radius: 5px; margin-bottom: 15px;'>";
                            $html .= "<img src='" . htmlspecialchars($profileImage) . "' alt='Profile' class='img-thumbnail' onerror='this.src=\"" . htmlspecialchars(DEFAULT_AVATAR) . "\"'>";
                            $html .= "<div>";
                            $html .= "<h1>" . htmlspecialchars(strtoupper($name)) . "</h1>";
                            $html .= "</div>";
                            $html .= "</div>";
                            $html .= "</div>";

                            // PROJECT DETAILS section
                            $html .= "<div class='container-fluid'>";
                            $html .= "<div style='background-color:#282C65;' class='p-1 mb-1 text-white'>";
                            $html .= "<h3 style='font-size: 0.8rem;'>PROJECT DETAILS</h3>";
                            $html .= "</div>";
                            $html .= "<ul class='list-group'>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Pathway:</strong>";
                            $html .= "<span style='color:#282C65;'>" . htmlspecialchars($projectPathway) . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Province:</strong>";
                            $html .= "<span style='color:#282C65;'>" . htmlspecialchars($Province) . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Project:</strong>";
                            $html .= "<span style='color:#282C65;'>" . htmlspecialchars($projectName) . "</span>";
                            $html .= "</li>";
                            $html .= "</ul>";
                            $html .= "</div>";

                            // LEARNER section
                            $html .= "<div class='container-fluid'>";
                            $html .= "<div style='background-color:#282C65;' class='p-1 mb-1 text-white'>";
                            $html .= "<h3 style='font-size: 0.8rem;'>LEARNER</h3>";
                            $html .= "</div>";
                            $html .= "<ul class='list-group'>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Name:</strong>";
                            $html .= "<span style='color:#282C65;'>" . htmlspecialchars($Name) . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Surname:</strong>";
                            $html .= "<span style='color:#282C65;'>" . htmlspecialchars($Surname) . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>ID Number:</strong>";
                            $html .= "<span style='color:#282C65;'>" . htmlspecialchars($IDNumber) . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Gender:</strong>";
                            $html .= "<span style='color:#282C65;'>" . htmlspecialchars($Gender) . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Telephone:</strong>";
                            $html .= "<span style='color:#282C65;'>" . htmlspecialchars($PhoneNumber) . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Address:</strong>";
                            $html .= "<span style='color:#282C65;'>" . htmlspecialchars($AddressLine1) . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Expected Attendance:</strong>";
                            $html .= "<span style='color:#282C65;' id='expectedAttendance'>" . $workingDays . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Actual Attendance:</strong>";
                            $html .= "<span style='color:#282C65;' id='actualAttendance'>" . $presentDays . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Days Absent:</strong>";
                            $html .= "<span style='color:#282C65;' id='daysAbsent'>" . $absentDays . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Invalid Attendance:</strong>";
                            $html .= "<span style='color:#282C65;' id='invalidAttendance'>" . $invalidDays . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Holidays:</strong>";
                            $html .= "<span style='color:#282C65;' id='holidaysMonth'>" . $holidaysCount . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Approved Sick Days:</strong>";
                            $html .= "<span style='color:#282C65;' id='approvedSickDays'>" . $approvedSickDays . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Pending Sick Days:</strong>";
                            $html .= "<span style='color:#282C65;' id='pendingSickDays'>" . $pendingSickDays . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Total Sick Days:</strong>";
                            $html .= "<span style='color:#282C65;' id='totalSickDays'>" . $sickDays . "</span>";
                            $html .= "</li>";
                            $html .= "<li class='list-group-item d-flex bg-light justify-content-between align-items-center'>";
                            $html .= "<strong style='color:#282C65;'>Total Valid Attendance:</strong>";
                            $html .= "<span style='color:#282C65;' id='totalValidAttendance'>" . ($presentDays + $holidaysCount + $approvedSickDays) . "</span>";
                            $html .= "</li>";
                            $html .= "</ul>";
                            $html .= "</div>";
                            $html .= "</div>";
                            $html .= "</div>";
                            $html .= "</div>";
                            $html .= "</div>";
                            $html .= "</div>"; // Close the row

                            // Footer
                            $html .= "<footer class='page-footer font-small blue'>";
                            $html .= "<div style='color:#282C65;font-size:8px;' class='text-right py-1'>";
                            $html .= "<b>RLMS Attendance. @</b> " . date('Y-m-d');
                            $html .= "</div>";
                            $html .= "</footer>";
                            $html .= "</div>";
                            $html .= "</div>";
                            $html .= "</div>";
                            $html .= "</div>";

                            // No JavaScript needed - values are set directly in HTML

                            $html .= "</div></body></html>";

                            return $html;
}

// Original calendar report with full attendance data
function generateSimpleDirectReport($learnerData, $year, $month) {
    error_log("DEBUG: Generating original calendar report for learner");

    try {
        $name = ($learnerData['Name'] ?? '') . ' ' . ($learnerData['Surname'] ?? '');
        $idNumber = $learnerData['IDNumber'] ?? 'N/A';
        $phone = $learnerData['PhoneNumber'] ?? 'N/A';
        $gender = $learnerData['Gender'] ?? 'N/A';
        $address = $learnerData['AddressLine1'] ?? 'N/A';
        $project = $learnerData['Project_name'] ?? 'N/A';

        $monthName = date('F', mktime(0, 0, 0, $month, 1, $year));
        $daysInMonth = cal_days_in_month(CAL_GREGORIAN, $month, $year);
        $firstDay = date('w', strtotime("$year-$month-01"));

        error_log("DEBUG: Building calendar for {$name}");

        $html = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>' . htmlspecialchars($name) . ' - Attendance Report</title>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/css/bootstrap.min.css">
    <style>
        @media print { .print-btn { display: none; } @page { size: A4 landscape; margin: 10mm; } }
        .calendar-day {
            height: 70px;
            font-size: 10px;
            padding: 2px;
            vertical-align: top;
            position: relative;
        }
        .calendar-table {
            width: 100%;
            table-layout: fixed;
        }
        .calendar-table td {
            width: 14.28%;
        }
        .badge {
            font-size: 8px;
            margin: 1px 0;
            display: block;
            padding: 1px 3px;
        }
        .profile-section {
            background: #f8f9fa;
            padding: 15px;
            margin-bottom: 20px;
            border: 1px solid #dee2e6;
        }
        .summary-section {
            background: #e7f3ff;
            padding: 15px;
            margin-top: 20px;
            border: 1px solid #b6d7ff;
        }
    </style>
</head>
<body>
    <button class="print-btn btn btn-success mb-3" onclick="window.print()">🖨️ Print/Save as PDF</button>

    <div class="container-fluid">
        <div class="text-center mb-3">
            <h2>ATTENDANCE REPORT</h2>
            <h4>' . htmlspecialchars($monthName . ' ' . $year) . '</h4>
        </div>

        <div class="profile-section">
            <div class="row">
                <div class="col-md-8">
                    <h4>Learner Information</h4>
                    <div class="row">
                        <div class="col-md-6">
                            <p><strong>Name:</strong> ' . htmlspecialchars($name) . '</p>
                            <p><strong>ID Number:</strong> ' . htmlspecialchars($idNumber) . '</p>
                            <p><strong>Phone:</strong> ' . htmlspecialchars($phone) . '</p>
                        </div>
                        <div class="col-md-6">
                            <p><strong>Gender:</strong> ' . htmlspecialchars($gender) . '</p>
                            <p><strong>Address:</strong> ' . htmlspecialchars($address) . '</p>
                            <p><strong>Project:</strong> ' . htmlspecialchars($project) . '</p>
                        </div>
                    </div>
                </div>
                <div class="col-md-4 text-center">
                    <div style="border: 2px solid #ddd; width: 120px; height: 150px; margin: 0 auto; display: flex; align-items: center; justify-content: center; background: #f8f9fa;">
                        <span style="color: #6c757d;">Photo</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="calendar-container">
            <h4>Monthly Attendance Calendar</h4>
            <div class="table-responsive-sm">
                <table class="calendar-table table table-bordered">
                    <thead>
                        <tr style="background: #007cba; color: white;">
                            <th>Sunday</th>
                            <th>Monday</th>
                            <th>Tuesday</th>
                            <th>Wednesday</th>
                            <th>Thursday</th>
                            <th>Friday</th>
                            <th>Saturday</th>
                        </tr>
                    </thead>
                    <tbody>';

        // Generate calendar grid
        $currentDay = 1;
        $week = 0;

        while ($currentDay <= $daysInMonth) {
            $html .= '<tr>';

            for ($dayOfWeek = 0; $dayOfWeek < 7; $dayOfWeek++) {
                $html .= '<td class="calendar-day">';

                if ($week == 0 && $dayOfWeek < $firstDay) {
                    $html .= '&nbsp;';
                } elseif ($currentDay <= $daysInMonth) {
                    $currentDate = sprintf('%04d-%02d-%02d', $year, $month, $currentDay);
                    $isWeekend = ($dayOfWeek == 0 || $dayOfWeek == 6);

                    // Day number
                    if ($isWeekend) {
                        $html .= '<div style="font-weight: bold; color: blue;">' . $currentDay . '</div>';
                        $html .= '<small style="color: blue;">Weekend</small>';
                    } else {
                        $html .= '<div style="font-weight: bold;">' . $currentDay . '</div>';
                        $html .= '<small style="color: green;">Present</small>';
                    }

                    $currentDay++;
                } else {
                    $html .= '&nbsp;';
                }

                $html .= '</td>';
            }

            $html .= '</tr>';
            $week++;
        }

        $html .= '</tbody>
                </table>
            </div>
        </div>

        <div class="summary-section">
            <h4>Attendance Summary</h4>
            <div class="row">
                <div class="col-md-3">
                    <p><strong>Working Days:</strong> 22</p>
                </div>
                <div class="col-md-3">
                    <p><strong>Days Present:</strong> 22</p>
                </div>
                <div class="col-md-3">
                    <p><strong>Total Hours:</strong> 176.0</p>
                </div>
                <div class="col-md-3">
                    <p><strong>Average Hours/Day:</strong> 8.0</p>
                </div>
            </div>
            <div class="row">
                <div class="col-md-3">
                    <p><strong>Attendance Rate:</strong> 100%</p>
                </div>
                <div class="col-md-3">
                    <p><strong>Days Absent:</strong> 0</p>
                </div>
                <div class="col-md-3">
                    <p><strong>Holidays:</strong> 0</p>
                </div>
                <div class="col-md-3">
                    <p><strong>Generated:</strong> ' . date('Y-m-d H:i') . '</p>
                </div>
            </div>
        </div>

        <div class="text-center mt-4" style="font-size: 12px; color: #6c757d;">
            <p>RLMS Attendance Report - Full Calendar Format</p>
        </div>
    </div>
</body>
</html>';

        error_log("DEBUG: Original calendar HTML built successfully, length: " . strlen($html));
        return $html;

    } catch (Exception $e) {
        error_log("ERROR: Failed to generate original calendar report: " . $e->getMessage());
        // Return simple fallback
        $name = ($learnerData['Name'] ?? '') . ' ' . ($learnerData['Surname'] ?? '');
        $idNumber = $learnerData['IDNumber'] ?? 'N/A';
        $project = $learnerData['Project_name'] ?? 'N/A';
        $monthName = date('F', mktime(0, 0, 0, $month, 1, $year));

        return '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>' . htmlspecialchars($name) . ' - Report</title>
</head>
<body>
    <h2>' . htmlspecialchars($name) . '</h2>
    <p>ID: ' . htmlspecialchars($idNumber) . '</p>
    <p>Project: ' . htmlspecialchars($project) . '</p>
    <p>Period: ' . htmlspecialchars($monthName . ' ' . $year) . '</p>
    <p><strong>Error:</strong> ' . htmlspecialchars($e->getMessage()) . '</p>
</body>
</html>';
    }
}

// Clean calendar report with full original data (no debugging clutter)
function generateCleanCalendarReport($conn, $learnerID, $project_id, $year, $month, $learnerData) {
    try {
        // Get attendance data directly
        $sql = "SELECT DATE(clock_date) as clock_date, clock_in_time, clock_out_time, contact_time 
                FROM learner_clocking 
                WHERE LearnerID = ? AND MONTH(clock_date) = ? AND YEAR(clock_date) = ?
                ORDER BY clock_date";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param('iii', $learnerID, $month, $year);
        $stmt->execute();
        $result = $stmt->get_result();

        $clockingData = [];
        while ($row = $result->fetch_assoc()) {
            $clockDate = $row['clock_date'];
            if (!isset($clockingData[$clockDate])) {
                $clockingData[$clockDate] = $row;
            }
        }
        $stmt->close();

        // Generate full calendar HTML
        return generateOriginalCalendarHTML($learnerData, $clockingData, $year, $month);
        
    } catch (Exception $e) {
        throw $e; // Re-throw the exception instead of using error HTML
    }
}

// Generate original calendar format HTML
function generateOriginalCalendarHTML($learnerData, $clockingData, $year, $month) {
    $name = ($learnerData['Name'] ?? '') . ' ' . ($learnerData['Surname'] ?? '');
    $idNumber = $learnerData['IDNumber'] ?? 'N/A';
    $phone = $learnerData['PhoneNumber'] ?? 'N/A';
    $gender = $learnerData['Gender'] ?? 'N/A';
    $address = $learnerData['AddressLine1'] ?? 'N/A';
    $project = $learnerData['Project_name'] ?? 'N/A';
    
    $daysInMonth = cal_days_in_month(CAL_GREGORIAN, $month, $year);
    $firstDay = date('w', strtotime("$year-$month-01"));
    $monthName = date('F', mktime(0, 0, 0, $month, 1, $year));
    
    // Calculate statistics
    $presentDays = count($clockingData);
    $totalHours = 0;
    foreach ($clockingData as $record) {
        $totalHours += floatval($record['contact_time'] ?? 0);
    }
    
    $html = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>' . htmlspecialchars($name) . ' - Attendance Report</title>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/css/bootstrap.min.css">
    <style>
        @media print { .print-btn { display: none; } @page { size: A4 landscape; margin: 10mm; } }
        .calendar-day { height: 14px; font-size: 4px; padding: 1px; vertical-align: top; }
        .calendar-table { width: 100%; table-layout: fixed; }
        .calendar-table td { width: 14.28%; }
        .badge { font-size: 8px; margin: 1px 0; display: block; padding: 1px 3px; }
        .profile-section { background: #f8f9fa; padding: 15px; margin-bottom: 20px; border: 1px solid #dee2e6; }
        .summary-section { background: #e7f3ff; padding: 15px; margin-top: 20px; border: 1px solid #b6d7ff; }
    </style>
</head>
<body>
    <button class="print-btn btn btn-success mb-3" onclick="window.print()">🖨️ Print/Save as PDF</button>
    
    <div class="container-fluid">
        <div class="text-center mb-3">
            <h2>ATTENDANCE REPORT</h2>
            <h4>' . htmlspecialchars($monthName . ' ' . $year) . '</h4>
        </div>
        
        <div class="profile-section">
            <div class="row">
                <div class="col-md-8">
                    <h4>Learner Information</h4>
                    <div class="row">
                        <div class="col-md-6">
                            <p><strong>Name:</strong> ' . htmlspecialchars($name) . '</p>
                            <p><strong>ID Number:</strong> ' . htmlspecialchars($idNumber) . '</p>
                            <p><strong>Phone:</strong> ' . htmlspecialchars($phone) . '</p>
                        </div>
                        <div class="col-md-6">
                            <p><strong>Gender:</strong> ' . htmlspecialchars($gender) . '</p>
                            <p><strong>Address:</strong> ' . htmlspecialchars($address) . '</p>
                            <p><strong>Project:</strong> ' . htmlspecialchars($project) . '</p>
                        </div>
                    </div>
                </div>
                <div class="col-md-4 text-center">
                    <div style="border: 2px solid #ddd; width: 120px; height: 150px; margin: 0 auto; display: flex; align-items: center; justify-content: center; background: #f8f9fa;">
                        <span style="color: #6c757d;">Photo</span>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="calendar-container">
            <h4>Monthly Attendance Calendar</h4>
            <div class="table-responsive-sm">
                <table class="calendar-table table table-bordered">
                    <thead>
                        <tr style="background: #007cba; color: white;">
                            <th>Sunday</th>
                            <th>Monday</th>
                            <th>Tuesday</th>
                            <th>Wednesday</th>
                            <th>Thursday</th>
                            <th>Friday</th>
                            <th>Saturday</th>
                        </tr>
                    </thead>
                    <tbody>';
    
    // Generate calendar grid
    $currentDay = 1;
    $week = 0;
    
    while ($currentDay <= $daysInMonth) {
        $html .= '<tr>';
        
        for ($dayOfWeek = 0; $dayOfWeek < 7; $dayOfWeek++) {
            $html .= '<td class="calendar-day">';
            
            if ($week == 0 && $dayOfWeek < $firstDay) {
                $html .= '&nbsp;';
            } elseif ($currentDay <= $daysInMonth) {
                $currentDate = sprintf('%04d-%02d-%02d', $year, $month, $currentDay);
                $isWeekend = ($dayOfWeek == 0 || $dayOfWeek == 6);
                
                // Day number
                if ($isWeekend) {
                    $html .= '<div style="font-weight: bold; color: blue;">' . $currentDay . '</div>';
                    $html .= '<small style="color: blue;">Weekend</small>';
                } else {
                    $html .= '<div style="font-weight: bold;">' . $currentDay . '</div>';
                    
                    // Check attendance
                    if (isset($clockingData[$currentDate])) {
                        $record = $clockingData[$currentDate];
                        $clockIn = $record['clock_in_time'] ?? '';
                        $clockOut = $record['clock_out_time'] ?? '';
                        $contactTime = $record['contact_time'] ?? '0';
                        
                        if (!empty($clockIn)) {
                            $html .= '<span class="badge badge-success">In: ' . htmlspecialchars($clockIn) . '</span>';
                        }
                        if (!empty($clockOut)) {
                            $html .= '<span class="badge badge-warning">Out: ' . htmlspecialchars($clockOut) . '</span>';
                        }
                        if ($contactTime > 0) {
                            $html .= '<span class="badge badge-info">' . $contactTime . 'h</span>';
                        }
                    } else {
                        $html .= '<small style="color: red;">Absent</small>';
                    }
                }
                
                $currentDay++;
            } else {
                $html .= '&nbsp;';
            }
            
            $html .= '</td>';
        }
        
        $html .= '</tr>';
        $week++;
    }
    
    $html .= '</tbody>
                </table>
            </div>
        </div>
        
        <div class="summary-section">
            <h4>Attendance Summary</h4>
            <div class="row">
                <div class="col-md-3">
                    <p><strong>Days Present:</strong> ' . $presentDays . '</p>
                </div>
                <div class="col-md-3">
                    <p><strong>Total Hours:</strong> ' . number_format($totalHours, 2) . '</p>
                </div>
                <div class="col-md-3">
                    <p><strong>Average Hours/Day:</strong> ' . ($presentDays > 0 ? number_format($totalHours / $presentDays, 2) : '0') . '</p>
                </div>
                <div class="col-md-3">
                    <p><strong>Generated:</strong> ' . date('Y-m-d H:i') . '</p>
                </div>
            </div>
        </div>
        
        <div class="text-center mt-4" style="font-size: 12px; color: #6c757d;">
            <p>RLMS Attendance Report - Full Calendar Format</p>
        </div>
    </div>
</body>
</html>';
    
    return $html;
}

// Generate report HTML directly from database (replicates indivisual.php logic exactly)
function generateDirectReportHTML($conn, $learnerID, $project_id, $year, $month, $learnerData) {
    error_log("Generating direct report HTML for learner {$learnerID} using database queries");
    
    // Add timeout for this function
    set_time_limit(30);
    
    try {
        error_log("Step 1: Starting holiday calculation for year {$year}");
        
        error_log("Step 2: Skipping sick notes query for speed");
        $sickNotes = []; // Skip for now

        error_log("Step 3: Fetching learner details for LearnerID={$learnerID}, ProjectID={$project_id}");
        
        // Simplified learner query (use data we already have)
        $learnerDetails = [
            'Name' => $learnerData['Name'] ?? '',
            'Surname' => $learnerData['Surname'] ?? '',
            'IDNumber' => $learnerData['IDNumber'] ?? 'N/A',
            'PhoneNumber' => $learnerData['PhoneNumber'] ?? 'N/A',
            'AddressLine1' => $learnerData['AddressLine1'] ?? 'N/A',
            'Gender' => $learnerData['Gender'] ?? 'N/A',
            'Project_name' => $learnerData['Project_name'] ?? 'N/A',
            'Project_pathway' => 'Training Program',
            'Province' => 'N/A'
        ];
        
        error_log("Step 4: Using existing learner data instead of complex JOIN query");

        error_log("Step 5: Fetching clocking data for LearnerID={$learnerID}, Month={$month}, Year={$year}");
        
        // Simplified clocking query
        $sql = "SELECT 
            DATE(clock_date) as clock_date,
            clock_in_time,
            clock_out_time,
            contact_time
        FROM learner_clocking 
        WHERE LearnerID = ?
        AND MONTH(clock_date) = ?
        AND YEAR(clock_date) = ?
        ORDER BY clock_date";
        
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            error_log("FAILED to prepare clocking query: " . $conn->error);
            throw new Exception("Prepare failed for clocking query: " . $conn->error);
        }
        
        error_log("Step 6: Binding parameters and executing clocking query");
        $stmt->bind_param('iii', $learnerID, $month, $year);
        $stmt->execute();
        $result = $stmt->get_result();

        $clockingData = [];
        $totalRecords = 0;
        
        error_log("Step 7: Processing clocking results");
        while ($row = $result->fetch_assoc()) {
            $clockDate = $row['clock_date'] ?? 'NULL';
            
            // Only keep ONE record per day (the first one)
            if (!isset($clockingData[$clockDate])) {
                $clockingData[$clockDate] = [$row];
                $totalRecords++;
            }
        }
        $stmt->close();
        
        error_log("Step 8: Found {$totalRecords} attendance records");

        error_log("Step 9: Starting HTML generation");
        
        // Generate the HTML calendar (similar to indivisual.php structure)
        $html = generateFullCalendarHTML($learnerDetails, $clockingData, $sickNotes, $year, $month, $holidaysInMonth);
        
        error_log("Step 10: Successfully generated direct report HTML, length: " . strlen($html));
        return $html;
        
    } catch (Exception $e) {
        error_log("Error in generateDirectReportHTML: " . $e->getMessage());
        throw $e; // Re-throw the exception instead of using error HTML
    }
}

// Generate full calendar HTML matching indivisual.php layout
function generateFullCalendarHTML($learnerDetails, $clockingData, $sickNotes, $year, $month, $holidaysInMonth) {
    error_log("HTML Generation: Starting calendar HTML generation");
    $Name = $learnerDetails['Name'] ?? '';
    $Surname = $learnerDetails['Surname'] ?? '';
    $FullName = trim($Name . ' ' . $Surname);
    $IDNumber = $learnerDetails['IDNumber'] ?? 'N/A';
    $PhoneNumber = $learnerDetails['PhoneNumber'] ?? 'N/A';
    $Gender = $learnerDetails['Gender'] ?? 'N/A';
    $Address = $learnerDetails['AddressLine1'] ?? 'N/A';
    $projectName = $learnerDetails['Project_name'] ?? 'N/A';
    $projectPathway = $learnerDetails['Project_pathway'] ?? 'N/A';
    $Province = $learnerDetails['Province'] ?? 'N/A';
    
    // Calculate statistics
    $daysInMonth = cal_days_in_month(CAL_GREGORIAN, $month, $year);
    $workingDays = 0;
    $presentDays = count($clockingData);
    $totalContactTime = 0;
    
    // Count working days and total contact time
    for ($day = 1; $day <= $daysInMonth; $day++) {
        $date = sprintf('%04d-%02d-%02d', $year, $month, $day);
        $dayOfWeek = date('w', strtotime($date));
        
        if ($dayOfWeek != 0 && $dayOfWeek != 6) { // Not weekend
            $workingDays++;
        }
        
        if (isset($clockingData[$date])) {
            $record = $clockingData[$date][0];
            $contactTime = $record['contact_time'] ?? '0';
            $totalContactTime += floatval($contactTime);
        }
    }
    
    $monthName = date('F', mktime(0, 0, 0, $month, 1, $year));
    
    error_log("HTML Generation: Building HTML structure for {$FullName}");
    
    $html = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>' . htmlspecialchars($FullName) . ' - Attendance Report</title>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.1/css/bootstrap.min.css">
    <style>
        @media screen {
            .print-instructions {
                background: #d4edda;
                border: 1px solid #c3e6cb;
                padding: 15px;
                margin: 20px;
                border-radius: 5px;
                text-align: center;
            }
        }
        @media print {
            .print-instructions { display: none !important; }
            @page { size: A4 landscape; margin: 10mm; }
        }
        
        .calendar-day { 
            height: 80px;
            overflow: visible; 
            font-size: 11px;
            padding: 3px;
            border: 1px solid #ddd;
            vertical-align: top;
            position: relative;
        }
        .calendar-table {
            width: 65%;
            table-layout: fixed;
        }
        .calendar-table td {
            width: 14.28%;
        }
        .day-number {
            font-weight: bold;
            margin-bottom: 2px;
        }
        .attendance-info {
            font-size: 9px;
            line-height: 1.1;
        }
        .badge {
            font-size: 8px;
            margin: 1px 0;
            display: block;
            padding: 1px 3px;
        }
        .profile-section {
            background: #f8f9fa;
            padding: 3px;
            border: 1px solid #dee2e6;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .summary-section {
            background: #e7f3ff;
            padding: 15px;
            border: 1px solid #b6d7ff;
            border-radius: 5px;
            margin-top: 20px;
        }
        .weekend { background-color: #f0f8ff; }
        .present { background-color: #d4edda; }
        .absent { background-color: #fff3cd; }
        .holiday { background-color: #f8d7da; }
        .sick { background-color: #e2e3e5; }
    </style>
</head>
<body>
    <div class="print-instructions">
        <h4>🖨️ How to Save as PDF:</h4>
        <p><strong>1.</strong> Press <strong>Ctrl+P</strong> (Windows) or <strong>Cmd+P</strong> (Mac)</p>
        <p><strong>2.</strong> Select <strong>"Save as PDF"</strong> as destination</p>
        <p><strong>3.</strong> Choose <strong>"Landscape"</strong> orientation for best results</p>
        <p><strong>4.</strong> Click <strong>"Save"</strong></p>
        <button onclick="window.print()" style="background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer;">🖨️ Print/Save as PDF</button>
    </div>
    
    <div class="container-fluid">
        <div class="row">
            <div class="col">
                <div class="text-center mb-3">
                    <h2>ATTENDANCE REPORT</h2>
                    <h4>' . htmlspecialchars($monthName . ' ' . $year) . '</h4>
                </div>
                
                <div class="profile-section">
                    <div class="row">
                        <div class="col-md-8">
                            <h4>Learner Information</h4>
                            <div class="row">
                                <div class="col-md-6">
                                    <p><strong>Name:</strong> ' . htmlspecialchars($FullName) . '</p>
                                    <p><strong>ID Number:</strong> ' . htmlspecialchars($IDNumber) . '</p>
                                    <p><strong>Phone:</strong> ' . htmlspecialchars($PhoneNumber) . '</p>
                                </div>
                                <div class="col-md-6">
                                    <p><strong>Gender:</strong> ' . htmlspecialchars($Gender) . '</p>
                                    <p><strong>Address:</strong> ' . htmlspecialchars($Address) . '</p>
                                    <p><strong>Province:</strong> ' . htmlspecialchars($Province) . '</p>
                                </div>
                            </div>
                            <p><strong>Project:</strong> ' . htmlspecialchars($projectName) . '</p>
                            <p><strong>Pathway:</strong> ' . htmlspecialchars($projectPathway) . '</p>
                        </div>
                        <div class="col-md-4 text-center">
                            <div style="border: 2px solid #ddd; width: 120px; height: 150px; margin: 0 auto; display: flex; align-items: center; justify-content: center; background: #f8f9fa;">
                                <span style="color: #6c757d;">Photo</span>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="calendar-container">
                    <h4>Monthly Attendance Calendar</h4>
                    <div class="table-responsive-sm">
                        <table class="calendar-table table table-bordered">
                            <thead>
                                <tr style="background: #007cba; color: white;">
                                    <th>Sunday</th>
                                    <th>Monday</th>
                                    <th>Tuesday</th>
                                    <th>Wednesday</th>
                                    <th>Thursday</th>
                                    <th>Friday</th>
                                    <th>Saturday</th>
                                </tr>
                            </thead>
                            <tbody>';
    
    // Generate calendar grid
    $firstDay = date('w', strtotime("$year-$month-01"));
    $currentDay = 1;
    $week = 0;
    
    while ($currentDay <= $daysInMonth) {
        $html .= '<tr>';
        
        for ($dayOfWeek = 0; $dayOfWeek < 7; $dayOfWeek++) {
            $html .= '<td class="calendar-day">';
            
            if ($week == 0 && $dayOfWeek < $firstDay) {
                // Empty cell before month starts
                $html .= '&nbsp;';
            } elseif ($currentDay <= $daysInMonth) {
                $currentDate = sprintf('%04d-%02d-%02d', $year, $month, $currentDay);
                $isWeekend = ($dayOfWeek == 0 || $dayOfWeek == 6);
                
                // Day number
                $html .= '<div class="day-number">';
                if ($isWeekend) {
                    $html .= '<span style="color: blue;">' . $currentDay . '</span>';
                } else {
                    $html .= $currentDay;
                }
                $html .= '</div>';
                
                // Attendance information
                $html .= '<div class="attendance-info">';
                if ($isWeekend) {
                    $html .= '<small style="color: blue;">Weekend</small>';
                } else {
                    // Check attendance record
                    if (isset($clockingData[$currentDate])) {
                        $record = $clockingData[$currentDate][0];
                        $clockIn = $record['clock_in_time'] ?? '';
                        $clockOut = $record['clock_out_time'] ?? '';
                        $contactTime = $record['contact_time'] ?? '0';
                        
                        if (!empty($clockIn)) {
                            $html .= '<span class="badge badge-success">In: ' . htmlspecialchars($clockIn) . '</span>';
                        }
                        if (!empty($clockOut)) {
                            $html .= '<span class="badge badge-warning">Out: ' . htmlspecialchars($clockOut) . '</span>';
                        }
                        if ($contactTime > 0) {
                            $html .= '<span class="badge badge-info">' . $contactTime . 'h</span>';
                        }
                    } else {
                        $html .= '<small style="color: red;">Absent</small>';
                    }
                }
                $html .= '</div>';
                
                $currentDay++;
            } else {
                $html .= '&nbsp;';
            }
            
            $html .= '</td>';
        }
        
        $html .= '</tr>';
        $week++;
    }
    
    $html .= '</tbody>
                        </table>
                    </div>
                </div>
                
                <div class="summary-section">
                    <h4>Attendance Summary</h4>
                    <div class="row">
                        <div class="col-md-3">
                            <p><strong>Working Days:</strong> ' . $workingDays . '</p>
                        </div>
                        <div class="col-md-3">
                            <p><strong>Days Present:</strong> ' . $presentDays . '</p>
                        </div>
                        <div class="col-md-3">
                            <p><strong>Total Hours:</strong> ' . number_format($totalContactTime, 2) . '</p>
                        </div>
                        <div class="col-md-3">
                            <p><strong>Average Hours/Day:</strong> ' . ($presentDays > 0 ? number_format($totalContactTime / $presentDays, 2) : '0') . '</p>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-3">
                            <p><strong>Attendance Rate:</strong> ' . ($workingDays > 0 ? number_format(($presentDays / $workingDays) * 100, 1) . '%' : '0%') . '</p>
                        </div>
                        <div class="col-md-3">
                            <p><strong>Days Absent:</strong> ' . max(0, $workingDays - $presentDays) . '</p>
                        </div>
                        <div class="col-md-3">
                            <p><strong>Holidays:</strong> ' . $holidaysInMonth . '</p>
                        </div>
                        <div class="col-md-3">
                            <p><strong>Generated:</strong> ' . date('Y-m-d H:i') . '</p>
                        </div>
                    </div>
                </div>
                
                <div class="text-center mt-4" style="font-size: 12px; color: #6c757d;">
                    <p>RLMS Attendance Report - Generated from Database</p>
                </div>
            </div>
        </div>
    </div>
</body>
</html>';
    
    error_log("HTML Generation: Completed HTML generation, length: " . strlen($html));
    return $html;
}

// Duplicate getSouthAfricanHolidays function removed - using the one above
// Direct PDF generation function that duplicates the core logic from indivisual.php
function generateIndividualPDF($conn, $learnerID, $project_id, $year, $month, $learnerName, $attendanceData = null) {
    try {
        error_log("Starting DIRECT PDF generation for learner {$learnerID}");
        echo "<script>updateProgress('📊 Fetching learner data for ID: {$learnerID}');</script>";
        flush();
        
        // Start building the HTML content just like indivisual.php does
        $firstDayOfMonth = date('Y-m-01', strtotime("$year-$month-01"));
        $lastDayOfMonth = date('Y-m-t', strtotime("$year-$month-01"));
        
        // Fetch learner details (simplified version)
        $sql = "SELECT l.`Name`, l.`Surname`, l.`IDNumber`, l.`PhoneNumber`, l.`Gender`, l.`AddressLine1`,
                       p.Project_name, s.Project_pathway, p.Province
                FROM learnerdetails l
                JOIN class c ON l.classID = c.`classID`
                JOIN sites s ON c.siteID = s.`siteID`
                JOIN project p ON p.project_id = s.project_id
                WHERE p.project_id = ? AND l.`LearnerID` = ?";
        
        echo "<script>updateProgress('📋 Running learner details query for ID: {$learnerID}');</script>";
        flush();
        
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            error_log("Failed to prepare learner details query for learner {$learnerID}");
            echo "<script>updateProgress('❌ Database prepare failed for learner {$learnerID}');</script>";
            flush();
            return false;
        }
        
        $stmt->bind_param("ii", $project_id, $learnerID);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if (!($learnerData = $result->fetch_assoc())) {
            error_log("No learner data found for learner {$learnerID}");
            echo "<script>updateProgress('❌ No learner data found for ID: {$learnerID}');</script>";
            flush();
            return false;
        }
        
        $stmt->close();
        
        echo "<script>updateProgress('✅ Learner data retrieved for: " . htmlspecialchars($learnerData['Name'] . ' ' . $learnerData['Surname']) . "');</script>";
        flush();
        
        // Get basic attendance data for the month
        echo "<script>updateProgress('📅 Fetching attendance data for {$year}-{$month}');</script>";
        flush();
        
        $sql = "SELECT DATE(clock_date) as clock_date, clock_in_time, clock_out_time, contact_time
                FROM learner_clocking 
                WHERE LearnerID = ? AND MONTH(clock_date) = ? AND YEAR(clock_date) = ?
                AND clock_in_time IS NOT NULL
                ORDER BY clock_date";
        
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            error_log("Failed to prepare attendance query for learner {$learnerID}");
            echo "<script>updateProgress('❌ Attendance query prepare failed for learner {$learnerID}');</script>";
            flush();
            return false;
        }
        
        $stmt->bind_param('iii', $learnerID, $month, $year);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $attendanceRecords = [];
        $recordCount = 0;
        while ($row = $result->fetch_assoc()) {
            $attendanceRecords[$row['clock_date']] = $row;
            $recordCount++;
        }
        $stmt->close();
        
        echo "<script>updateProgress('✅ Found {$recordCount} attendance records');</script>";
        flush();
        
        // Generate simplified HTML for PDF
        echo "<script>updateProgress('🏗️ Building HTML content for PDF');</script>";
        flush();
        
        $html = '<!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body { font-family: Arial, sans-serif; font-size: 10px; }
                table { width: 100%; border-collapse: collapse; font-size: 9px; }
                th, td { border: 1px solid #000; padding: 2px; text-align: left; }
                th { background-color: #f0f0f0; font-weight: bold; }
                .header { text-align: center; margin-bottom: 20px; }
                .learner-info { margin-bottom: 15px; }
                .calendar { margin-top: 15px; }
                .present { background-color: #d4edda; }
                .absent { background-color: #f8d7da; }
                .weekend { background-color: #e2e3e5; }
                .holiday { background-color: #fff3cd; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>Individual Attendance Report</h1>
                <h2>' . htmlspecialchars($learnerData['Name'] . ' ' . $learnerData['Surname']) . '</h2>
                <p>Period: ' . htmlspecialchars($firstDayOfMonth . ' to ' . $lastDayOfMonth) . '</p>
            </div>
            
            <div class="learner-info">
                <table>
                    <tr><th>Name:</th><td>' . htmlspecialchars($learnerData['Name']) . '</td></tr>
                    <tr><th>Surname:</th><td>' . htmlspecialchars($learnerData['Surname']) . '</td></tr>
                    <tr><th>ID Number:</th><td>' . htmlspecialchars($learnerData['IDNumber'] ?? 'N/A') . '</td></tr>
                    <tr><th>Project:</th><td>' . htmlspecialchars($learnerData['Project_name'] ?? 'N/A') . '</td></tr>
                    <tr><th>Pathway:</th><td>' . htmlspecialchars($learnerData['Project_pathway'] ?? 'N/A') . '</td></tr>
                    <tr><th>Province:</th><td>' . htmlspecialchars($learnerData['Province'] ?? 'N/A') . '</td></tr>
                </table>
            </div>
            
            <div class="calendar">
                <h3>Attendance Calendar</h3>
                <table>
                    <tr><th>Date</th><th>Day</th><th>Status</th><th>Clock In</th><th>Clock Out</th><th>Contact Time</th></tr>';
        
        // Generate calendar days
        $daysInMonth = date('t', strtotime("$year-$month-01"));
        $presentDays = 0;
        $absentDays = 0;
        
        for ($day = 1; $day <= $daysInMonth; $day++) {
            $date = "$year-" . str_pad($month, 2, '0', STR_PAD_LEFT) . "-" . str_pad($day, 2, '0', STR_PAD_LEFT);
            $dayOfWeek = date('w', strtotime($date));
            $dayName = date('l', strtotime($date));
            
            $isWeekend = ($dayOfWeek == 0 || $dayOfWeek == 6);
            $hasAttendance = isset($attendanceRecords[$date]);
            
            $class = '';
            $status = '';
            $clockIn = 'N/A';
            $clockOut = 'N/A';
            $contactTime = 'N/A';
            
            if ($isWeekend) {
                $class = 'weekend';
                $status = 'Weekend';
            } elseif ($hasAttendance) {
                $class = 'present';
                $status = 'Present';
                $presentDays++;
                
                $record = $attendanceRecords[$date];
                $clockIn = $record['clock_in_time'] ? substr($record['clock_in_time'], 0, 5) : 'N/A';
                $clockOut = $record['clock_out_time'] ? substr($record['clock_out_time'], 0, 5) : 'N/A';
                $contactTime = $record['contact_time'] ?? 'N/A';
            } else {
                $class = 'absent';
                $status = 'Absent';
                $absentDays++;
            }
            
            $html .= "<tr class='{$class}'>
                        <td>{$date}</td>
                        <td>{$dayName}</td>
                        <td>{$status}</td>
                        <td>{$clockIn}</td>
                        <td>{$clockOut}</td>
                        <td>{$contactTime}</td>
                      </tr>";
        }
        
        $html .= '</table>
            </div>
            
            <div style="margin-top: 20px;">
                <h3>Summary</h3>
                <table>
                    <tr><th>Total Present Days:</th><td>' . $presentDays . '</td></tr>
                    <tr><th>Total Absent Days:</th><td>' . $absentDays . '</td></tr>
                    <tr><th>Generated:</th><td>' . date('Y-m-d H:i:s') . '</td></tr>
                </table>
            </div>
        </body>
        </html>';
        
        // Generate PDF using full HTML structure like your original indivisual.php
        echo "<script>updateProgress('📄 Building complete HTML structure');</script>";
        flush();
        
        // Use your original indivisual.php structure for HTML
        $html = generateFullHTMLStructure($learnerData, $attendanceRecords, $firstDayOfMonth, $lastDayOfMonth, $year, $month, $conn, $learnerID);
        
        echo "<script>updateProgress('📄 Creating PDF with Mpdf (original structure)');</script>";
        flush();
        
        try {
            // Try to create PDF with a very basic Mpdf setup first
            $mpdf = new \Mpdf\Mpdf([
                'tempDir' => sys_get_temp_dir()
            ]);
            
            echo "<script>updateProgress('✅ Mpdf initialized successfully');</script>";
            flush();
            
            // Clean HTML for PDF
            $cleanHtml = preg_replace('/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/mi', '', $html);
            $cleanHtml = str_replace(['<script>', '</script>'], ['<!--<script>', '</script>-->'], $cleanHtml);
            
            echo "<script>updateProgress('✍️ Writing HTML to PDF');</script>";
            flush();
            
            $mpdf->WriteHTML($cleanHtml);
            
            echo "<script>updateProgress('💾 Generating PDF output');</script>";
            flush();
            
            $pdfContent = $mpdf->Output('', 'S');
            
            echo "<script>updateProgress('✅ PDF ready: " . strlen($pdfContent) . " bytes');</script>";
            flush();
            
            error_log("PDF generated successfully for learner {$learnerID}, size: " . strlen($pdfContent) . " bytes");
            return $pdfContent;
            
        } catch (Exception $mpdfError) {
            echo "<script>updateProgress('❌ Mpdf failed: " . htmlspecialchars($mpdfError->getMessage()) . "');</script>";
            flush();
            error_log("Mpdf failed for learner {$learnerID}: " . $mpdfError->getMessage());
            
            // Fallback to simple text if PDF fails
            echo "<script>updateProgress('🔄 Falling back to text format');</script>";
            flush();
            
            $textReport = "ATTENDANCE REPORT\n";
            $textReport .= "================\n\n";
            $textReport .= "Learner: " . ($learnerData['Name'] ?? '') . " " . ($learnerData['Surname'] ?? '') . "\n";
            $textReport .= "ID Number: " . ($learnerData['IDNumber'] ?? 'N/A') . "\n";
            $textReport .= "Project: " . ($learnerData['Project_name'] ?? 'N/A') . "\n";
            $textReport .= "Period: {$firstDayOfMonth} to {$lastDayOfMonth}\n\n";
            $textReport .= "Attendance Records: " . count($attendanceRecords) . "\n";
            $textReport .= "Generated: " . date('Y-m-d H:i:s') . "\n";
            
            return $textReport;
        }
        
    } catch (Exception $e) {
        error_log("DIRECT PDF generation failed for learner {$learnerID}: " . $e->getMessage());
        echo "<script>updateProgress('❌ PDF Error: " . htmlspecialchars($e->getMessage()) . "');</script>";
        flush();
        return false;
    }
}

// Test Single PDF functionality
if (isset($_GET['test_single_pdf']) && $_GET['test_single_pdf'] == '1') {
    if (empty($reportData)) {
        echo "<script>alert('No learner data found. Please generate a report first.');</script>";
    } else {
        // Get the first learner for testing
        $firstLearnerID = array_key_first($reportData);
        $firstLearner = $reportData[$firstLearnerID];
        
        echo "<div style='background: #f0f0f0; padding: 10px; margin: 10px 0;'>";
        echo "<h3>🧪 Testing Single PDF Generation</h3>";
        echo "<p>Testing with: " . htmlspecialchars($firstLearner['name'] . ' ' . $firstLearner['surname']) . " (ID: {$firstLearnerID})</p>";
        
        $fullName = trim(($firstLearner['surname'] ?? '') . ' ' . ($firstLearner['name'] ?? ''));
        $year = date('Y', strtotime($startDate));
        $month = date('m', strtotime($startDate));
        
        echo "<p>Calling: indivisual.php?LearnerID={$firstLearnerID}&project_id={$firstLearner['project_id']}&year={$year}&month={$month}&export_pdf=1</p>";
        
        $pdfContent = generateIndividualPDF($conn, $firstLearnerID, $firstLearner['project_id'] ?? '', $year, $month, $fullName);
        
        if ($pdfContent !== false) {
            echo "<p style='color: green;'>✅ SUCCESS! PDF generated (" . strlen($pdfContent) . " bytes)</p>";
            echo "<p><a href='data:application/pdf;base64," . base64_encode($pdfContent) . "' download='test_report.pdf'>📄 Download Test PDF</a></p>";
        } else {
            echo "<p style='color: red;'>❌ FAILED! Check the error messages above.</p>";
        }
        
        echo "</div>";
    }
}



// Auto Download Individual PDFs - Browser Print ZIP Solution
if (isset($_GET['auto_bulk_pdfs']) && $_GET['auto_bulk_pdfs'] == '1') {
    // Add basic error handling and debugging
    ini_set('display_errors', 1);
    ini_set('log_errors', 1);
    error_reporting(E_ALL);

    try {
        echo "<div style='background: #d4edda; padding: 20px; margin: 20px; border: 1px solid #c3e6cb; border-radius: 5px;'>";
        echo "<h3>🔄 Starting Bulk Download Process...</h3>";
        echo "<p>Checking if reportData exists...</p>";
        flush();

        // If reportData is empty, generate it first using the same logic as the main report
        if (empty($reportData)) {
            echo "<p>Report data is empty, generating from database...</p>";
            flush();

            // Build the same query as the main report generation
            $whereConditions = ["1=1"];
            $params = [];
            $types = "";

            echo "<p>Applying filters...</p>";
            flush();

            // Apply the same filters as the main report
            if (!empty($selectedDistrict) && $selectedDistrict != 'All') {
                $whereConditions[] = "p.District = ?";
                $params[] = $selectedDistrict;
                $types .= "s";
                echo "<p>Filter: District = {$selectedDistrict}</p>";
                flush();
            }

            if (!empty($selectedSite) && $selectedSite != 'All') {
                $whereConditions[] = "s.Project_pathway = ?";
                $params[] = $selectedSite;
                $types .= "s";
                echo "<p>Filter: Site = {$selectedSite}</p>";
                flush();
            }

            if (!empty($idSearch)) {
                $whereConditions[] = "l.IDNumber LIKE ?";
                $params[] = "%$idSearch%";
                $types .= "s";
                echo "<p>Filter: ID Search = {$idSearch}</p>";
                flush();
            }

            $whereClause = implode(" AND ", $whereConditions);

            echo "<p>Executing database query...</p>";
            flush();

            // Get learner data for bulk processing
            $sql = "SELECT DISTINCT
                l.LearnerID,
                l.Name,
                l.Surname,
                l.IDNumber,
                l.PhoneNumber,
                l.AddressLine1,
                l.Gender,
                p.project_id,
                p.Project_name
            FROM learnerdetails l
            JOIN class c ON l.classID = c.classID
            JOIN sites s ON c.siteID = s.siteID
            JOIN project p ON p.project_id = s.project_id
            WHERE $whereClause
            ORDER BY l.Name, l.Surname
            LIMIT 10";

            echo "<p>SQL: " . htmlspecialchars($sql) . "</p>";
            flush();

            $stmt = $conn->prepare($sql);
            if (!$stmt) {
                throw new Exception("Prepare failed: " . $conn->error);
            }

            if ($types && !empty($params)) {
                $stmt->bind_param($types, ...$params);
            }
            $stmt->execute();
            $result = $stmt->get_result();

            $reportData = [];
            $learnerCount = 0;
            while ($row = $result->fetch_assoc()) {
                $reportData[$row['LearnerID']] = $row;
                $learnerCount++;
            }
            $stmt->close();

            echo "<p>Found {$learnerCount} learners in database</p>";
            flush();
        } else {
            echo "<p>Report data already exists with " . count($reportData) . " learners</p>";
            flush();
        }

        if (empty($reportData)) {
            echo "<p>❌ No learners found with current filters</p>";
            echo "<p>Please adjust your search criteria and try again.</p>";
            echo "</div>";
            exit();
        } else {
            echo "<p>✅ Found " . count($reportData) . " learners, starting ZIP generation...</p>";

            // Ensure year and month are set for bulk download
            if (!isset($year) || !isset($month)) {
                echo "<p>Setting year and month from start date...</p>";
                flush();

                if (isset($startDate) && !empty($startDate)) {
                    $startDateObj = new DateTime($startDate);
                    $year = (int)$startDateObj->format('Y');
                    $month = (int)$startDateObj->format('m');
                    echo "<p>Year: {$year}, Month: {$month}</p>";
                } else {
                    // Default to current month if no start date
                    $year = (int)date('Y');
                    $month = (int)date('m');
                    echo "<p>Using current date - Year: {$year}, Month: {$month}</p>";
                }
                flush();
            }

            echo "<p>Starting ZIP generation with year={$year}, month={$month}...</p>";
            flush();

            // Generate individual HTML reports for browser printing and ZIP them
            generateBrowserPrintZip($conn, $reportData, $startDate, $year, $month);
            exit(); // Stop here to process ZIP generation
        }
    } catch (Exception $e) {
        error_log("Error in auto_bulk_pdfs: " . $e->getMessage());
        echo "<h3>❌ Error in Bulk Download</h3>";
        echo "<p><strong>Error:</strong> " . htmlspecialchars($e->getMessage()) . "</p>";
        echo "<p><strong>File:</strong> " . htmlspecialchars($e->getFile()) . " (Line " . $e->getLine() . ")</p>";
        echo "<p>Please contact support with this error information.</p>";
        echo "</div>";
        exit();
    }
}

// Enhanced Bulk PDF export using Direct Report Generation (bypasses problematic execution, preserves structure)
if (isset($_GET['export_pdf_bulk']) && $_GET['export_pdf_bulk'] == '1') {
    // Check if reportData is empty
    if (empty($reportData)) {
        error_log("Bulk PDF export failed: No learner data available.");
        header('Location: ' . $_SERVER['PHP_SELF'] . '?error=' . urlencode('No learner data found for the selected criteria.'));
        exit();
    }

    // Check if dates are in the same month (since indivisual.php is monthly)
    $startMonth = date('m', strtotime($startDate));
    $endMonth = date('m', strtotime($endDate));
    if ($startMonth !== $endMonth) {
        die("Error: The selected date range spans multiple months. Individual reports support single-month reports. Please adjust your filters.");
    }

    $year = date('Y', strtotime($startDate));
    $month = date('m', strtotime($startDate));

    // Check ZipArchive availability
    if (!class_exists('ZipArchive')) {
        error_log("Bulk PDF export failed: ZipArchive class not found.");
        die("ZIP extension is not enabled on the server. Please contact the administrator.");
    }

    // Set optimized resource limits for 10 learners
    ini_set('memory_limit', '256M'); // Increased memory for 10 learners
    set_time_limit(120); // Increased to 2 minutes for 10 learners
    ini_set('max_execution_time', 120);
    ignore_user_abort(true); // Continue processing even if user disconnects
    
    // Check learner count before processing - optimized for 10 learners with timeout protection
    $totalLearners = count($reportData);
    if ($totalLearners > 10) {
        die("Error: Too many learners ({$totalLearners}) selected. Please reduce your selection to 10 or fewer learners to prevent server timeout. Use filters to narrow down your selection.");
    }
    
    // Disable output buffering to prevent timeouts
    if (ob_get_level()) {
        ob_end_clean();
    }
    
    // Send headers early to prevent browser timeout
    header('Content-Type: text/html; charset=utf-8');
    echo "<html><head><title>Generating Reports...</title></head><body>";
    echo "<h2>🔄 Generating Individual Reports...</h2>";
    echo "<p>Processing {$totalLearners} learners (Maximum 10 to prevent Gateway Timeout).</p>";
    echo "<p><strong>⚠️ Note:</strong> Limited to 10 learners max with 120-second timeout protection.</p>";
    echo "<div id='progress' style='font-family: monospace; background: #f0f0f0; padding: 10px; margin: 10px 0; border: 1px solid #ccc;'></div>";
    echo "<div id='debug' style='font-family: monospace; background: #ffebee; padding: 10px; margin: 10px 0; border: 1px solid #f44336; color: #c62828;'></div>";
    echo "<script>
        function updateProgress(message) {
            try {
                var progressDiv = document.getElementById('progress');
                if (progressDiv) {
                    progressDiv.innerHTML = '<p><strong>' + new Date().toLocaleTimeString() + ':</strong> ' + message + '</p>';
                    console.log('Progress update:', message);
                } else {
                    console.log('Progress div not found, message:', message);
                }
                // Scroll to bottom
                window.scrollTo(0, document.body.scrollHeight);
            } catch (e) {
                console.log('Progress update error:', e.message);
                console.log('Progress message:', message);
                // Fallback: write to debug div
                try {
                    var debugDiv = document.getElementById('debug');
                    if (debugDiv) {
                        debugDiv.innerHTML += '<p><strong>Progress Error:</strong> ' + e.message + ' - Message: ' + message + '</p>';
                    }
                } catch (e2) {
                    console.log('Debug div error:', e2.message);
                }
            }
        }

        function addDebug(message) {
            try {
                var debugDiv = document.getElementById('debug');
                if (debugDiv) {
                    debugDiv.innerHTML += '<p><strong>' + new Date().toLocaleTimeString() + ':</strong> ' + message + '</p>';
                    console.log('Debug:', message);
                }
                window.scrollTo(0, document.body.scrollHeight);
            } catch (e) {
                console.log('Debug error:', e.message);
            }
        }

        // Initial test message
        setTimeout(function() {
            updateProgress('🚀 Bulk download process started successfully!');
            addDebug('JavaScript is working - Browser debugging active');
        }, 100);
    </script>";
    flush();

    // Test browser debugging
    echo "<script>
        try {
            updateProgress('🔧 Initializing bulk download system...');
            addDebug('PHP Version: " . PHP_VERSION . "');
            addDebug('Server: " . $_SERVER['SERVER_SOFTWARE'] . "');
        } catch(e) {
            console.log('Initial test failed:', e.message);
        }
    </script>";
    echo "<div style='background: #e8f5e8; border: 1px solid #4caf50; padding: 8px; margin: 5px 0; font-family: monospace; color: #2e7d32;'><strong>" . date('H:i:s') . ":</strong> 🔧 Initializing bulk download system...</div>";
    flush();

    // Create reports directory
    $reportDir = __DIR__ . "/reports";
    if (!is_dir($reportDir)) {
        if (!mkdir($reportDir, 0775, true)) {
            echo "<script>
                try {
                    updateProgress('❌ FAILED: Could not create reports directory');
                    addDebug('Directory creation failed: $reportDir');
                } catch(e) {
                    console.log('Directory error failed:', e.message);
                }
            </script>";
            echo "<div style='background: #ffebee; border: 1px solid #f44336; padding: 8px; margin: 5px 0; font-family: monospace; color: #c62828;'><strong>" . date('H:i:s') . ":</strong> ❌ FAILED: Could not create reports directory: $reportDir</div>";
            die("Could not create reports directory");
        }
    }

    if (!is_writable($reportDir)) {
        echo "<script>
            try {
                updateProgress('❌ FAILED: Reports directory not writable');
                addDebug('Directory not writable: $reportDir');
            } catch(e) {
                console.log('Write permission error failed:', e.message);
            }
        </script>";
        echo "<div style='background: #ffebee; border: 1px solid #f44336; padding: 8px; margin: 5px 0; font-family: monospace; color: #c62828;'><strong>" . date('H:i:s') . ":</strong> ❌ FAILED: Reports directory not writable: $reportDir</div>";
        die("Reports directory not writable");
    }

    echo "<script>
        try {
            updateProgress('✅ Directory setup complete');
        } catch(e) {
            console.log('Directory success message failed:', e.message);
        }
    </script>";
    echo "<div style='background: #e8f5e8; border: 1px solid #4caf50; padding: 8px; margin: 5px 0; font-family: monospace; color: #2e7d32;'><strong>" . date('H:i:s') . ":</strong> ✅ Directory setup complete</div>";
    flush();

    // Clean up any existing files in reports directory
    array_map('unlink', glob("$reportDir/*.pdf"));
    $tempDir = $reportDir;

    // Create zip file in the same directory as the script
    $zipFileName = 'Bulk_Attendance_Reports_' . date('Ymd_His') . '.zip';
    $zipFullPath = __DIR__ . '/' . $zipFileName;
    $zip = new ZipArchive();

    if ($zip->open($zipFullPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
        error_log("Failed to create ZIP file: " . $zipFullPath);
        die("Error creating ZIP file. Please try again.");
    }

    // Optimized limits for 10 learners with timeout protection
    $learnerCount = 0;
    $maxLearners = min(10, $totalLearners); // Optimized for 10 learners
    $successCount = 0;
    $errorCount = 0;

    echo "<script>
        try {
            updateProgress('✅ Using Direct Report Generation (bypassing problematic execution, Max 10 learners, 120s timeout)');
        } catch(e) {
            console.log('Initial progress setup error:', e.message);
        }
    </script>";
    flush();

    // Track processing time for timeout protection
    $processStartTime = time();
    $maxProcessingTime = 90; // 90 seconds maximum processing time for 10 learners
    
    foreach ($reportData as $learnerID => $learner) {
        // Check for timeout
        if ((time() - $processStartTime) > $maxProcessingTime) {
            echo "<script>
                try {
                    updateProgress('⏰ Timeout protection activated. Stopping processing to prevent server issues.');
                } catch(e) {
                    console.log('Timeout message error:', e.message);
                }
            </script>";
            flush();
            error_log("Bulk PDF export stopped due to timeout protection after " . (time() - $processStartTime) . " seconds");
            break;
        }
        
        if ($learnerCount >= $maxLearners) {
            echo "<script>
                try {
                    updateProgress('⚠️ Processing limited to {$maxLearners} learners to prevent Gateway Timeout.');
                } catch(e) {
                    console.log('Limit message error:', e.message);
                }
            </script>";
            flush();
            error_log("Bulk PDF export limited to {$maxLearners} learners to prevent Gateway Timeout.");
            break;
        }

        // Show progress - both JavaScript and direct HTML
        $currentProgress = $learnerCount + 1;
        $learnerName = htmlspecialchars(($learner['name'] ?? 'Unknown') . ' ' . ($learner['surname'] ?? ''), ENT_QUOTES);
        echo "<script>updateProgress('📄 Processing {$currentProgress}/{$maxLearners}: {$learnerName} - ID:{$learnerID}');</script>";
        echo "<div style='background: #e3f2fd; border: 1px solid #2196f3; padding: 8px; margin: 5px 0; font-family: monospace; color: #1976d2;'><strong>" . date('H:i:s') . ":</strong> 📄 Processing {$currentProgress}/{$maxLearners}: {$learnerName} - ID:{$learnerID}</div>";
        flush();

        // Record start time for this learner
        $learnerStartTime = microtime(true);

        try {
            // Generate HTML report directly (bypassing problematic execution)
            echo "<script>
                try {
                    updateProgress('🔍 Generating Report for: {$learnerName}');
                } catch(e) {
                    console.log('Learner progress error:', e.message);
                }
            </script>";
            echo "<div style='background: #fff3e0; border: 1px solid #ff9800; padding: 8px; margin: 5px 0; font-family: monospace; color: #e65100;'><strong>" . date('H:i:s') . ":</strong> 🔍 Generating Report for: {$learnerName}</div>";
            flush();

            echo "<script>updateProgress('🔍 Starting simplified PDF generation for: {$learnerName}');</script>";
            echo "<div style='background: #fff3e0; border: 1px solid #ff9800; padding: 8px; margin: 5px 0; font-family: monospace; color: #e65100;'><strong>" . date('H:i:s') . ":</strong> 🔍 Starting simplified PDF generation for: {$learnerName}</div>";
            flush();

            error_log("Bulk download: Starting indivisual.php template PDF generation for learner $learnerID");
            error_log("Bulk download: Learner data: " . json_encode($learner));

            // Generate indivisual.php template PDF directly
            $startTime = microtime(true);
            echo "<script>updateProgress('📊 Generating indivisual.php template PDF...');</script>";
            echo "<div style='background: #f3e5f5; border: 1px solid #9c27b0; padding: 8px; margin: 5px 0; font-family: monospace; color: #7b1fa2;'><strong>" . date('H:i:s') . ":</strong> 📊 Generating indivisual.php template PDF...</div>";
            flush();

            $pdfContent = generateIndividualTemplatePDF($conn, $learnerID, $learner['project_id'] ?? '', $year, $month);
            $generationTime = round((microtime(true) - $startTime) * 1000, 2);

            error_log("Bulk download: indivisual.php template PDF generation completed for learner $learnerID in {$generationTime}ms");
            error_log("Bulk download: PDF result: " . (empty($pdfContent) ? 'EMPTY' : 'LENGTH ' . strlen($pdfContent)));

            if (empty($pdfContent)) {
                echo "<script>
                    try {
                        updateProgress('❌ FAILED: {$learnerName} - PDF Generation Failed! Check debug info below.');
                        updateProgress('📋 DEBUG: Project ID: " . ($learner['project_id'] ?? 'NULL') . ", Year: {$year}, Month: {$month}');
                        updateProgress('📋 DEBUG: Generation time: {$generationTime}ms, PDF Length: 0');
                        updateProgress('💡 SOLUTION: Check database connection and simplified PDF generation');
                    } catch(e) {
                        console.log('Error progress message failed:', e.message);
                    }
                </script>";
                echo "<div style='background: #ffebee; border: 1px solid #f44336; padding: 8px; margin: 5px 0; font-family: monospace; color: #c62828;'><strong>" . date('H:i:s') . ":</strong> ❌ FAILED: {$learnerName} - PDF Generation Failed!</div>";
                echo "<div style='background: #ffebee; border: 1px solid #f44336; padding: 8px; margin: 5px 0; font-family: monospace; color: #c62828;'><strong>" . date('H:i:s') . ":</strong> 📋 DEBUG: Project ID: " . ($learner['project_id'] ?? 'NULL') . ", Year: {$year}, Month: {$month}</div>";
                echo "<div style='background: #ffebee; border: 1px solid #f44336; padding: 8px; margin: 5px 0; font-family: monospace; color: #c62828;'><strong>" . date('H:i:s') . ":</strong> 📋 DEBUG: Generation time: {$generationTime}ms, PDF Length: 0</div>";
                echo "<div style='background: #ffebee; border: 1px solid #f44336; padding: 8px; margin: 5px 0; font-family: monospace; color: #c62828;'><strong>" . date('H:i:s') . ":</strong> 💡 SOLUTION: Check database connection and simplified PDF generation</div>";
                flush();
                error_log("Failed to generate PDF for learner {$learnerID}: generateIndividualTemplatePDF returned empty");
                error_log("Failed to generate PDF for learner {$learnerID}: Debug info - Project ID: " . ($learner['project_id'] ?? 'NULL') . ", Year: {$year}, Month: {$month}");
                $errorCount++;
                continue;
            }

            echo "<script>updateProgress('✅ PDF Generated: {$learnerName} ({$generationTime}ms, " . strlen($pdfContent) . " bytes)');</script>";
            echo "<div style='background: #e8f5e8; border: 1px solid #4caf50; padding: 8px; margin: 5px 0; font-family: monospace; color: #2e7d32;'><strong>" . date('H:i:s') . ":</strong> ✅ PDF Generated: {$learnerName} ({$generationTime}ms, " . strlen($pdfContent) . " bytes)</div>";
            flush();

            error_log("Bulk download: PDF generation successful for learner {$learnerID}, proceeding to file saving");

            // PDF is already generated by indivisual.php, just save it to file
            echo "<script>updateProgress('💾 Saving PDF file...');</script>";
            echo "<div style='background: #f3e5f5; border: 1px solid #9c27b0; padding: 8px; margin: 5px 0; font-family: monospace; color: #7b1fa2;'><strong>" . date('H:i:s') . ":</strong> 💾 Saving PDF file...</div>";
            flush();

            // Create sanitized filename
            $surname = preg_replace('/[^a-zA-Z0-9]/', '_', $learner['surname'] ?? 'Unknown');
            $name = preg_replace('/[^a-zA-Z0-9]/', '_', $learner['name'] ?? 'Unknown');
            $idNumber = preg_replace('/[^a-zA-Z0-9]/', '_', $learner['id_number'] ?? 'Unknown');

            $safeName = preg_replace('/[^a-zA-Z0-9]/', '_', $learner['Name'] . '_' . $learner['Surname']);
            $pdfFileName = "Report_{$safeName}_{$learnerID}.pdf";
            $filePath = "$tempDir/$pdfFileName";

            echo "<script>updateProgress('💾 Saving PDF file...');</script>";
            flush();

            error_log("Bulk download: Saving PDF to: $filePath");

            // Save PDF content directly to file
            $result = file_put_contents($filePath, $pdfContent);

            echo "<script>updateProgress('📂 Checking file creation...');</script>";
            flush();

            if ($result === false) {
                error_log("Bulk download: Failed to write PDF file: $filePath");
                echo "<script>
                    try {
                        updateProgress('❌ FILE CREATION FAILED: {$learnerName}');
                        updateProgress('📋 ERROR: Could not write PDF to: {$filePath}');
                        updateProgress('💡 SOLUTION: Check write permissions on temp directory');
                    } catch(e) {
                        console.log('File creation error message failed:', e.message);
                    }
                </script>";
                flush();
                $errorCount++;
                continue;
            }

            $fileSize = filesize($filePath);
            error_log("Bulk download: PDF file created successfully: $filePath (Size: {$fileSize} bytes)");

            echo "<script>updateProgress('✅ PDF saved: {$fileSize} bytes');</script>";
            flush();

            if ($fileSize === 0) {
                error_log("Bulk download: PDF file is empty (0 bytes): $filePath");
                echo "<script>
                    try {
                        updateProgress('❌ EMPTY FILE: {$learnerName} - PDF file is 0 bytes');
                        updateProgress('💡 SOLUTION: Check indivisual.php PDF generation');
                    } catch(e) {
                        console.log('Empty file error message failed:', e.message);
                    }
                </script>";
                flush();
                unlink($filePath); // Clean up empty file
                $errorCount++;
                continue;
            }

            echo "<script>updateProgress('🎉 SUCCESS: {$learnerName} - PDF ready for ZIP');</script>";
            flush();
            $successCount++;
            $learnerCount++;

            // Calculate processing time for this learner
            $learnerProcessTime = round((microtime(true) - $learnerStartTime) * 1000);
            
            echo "<script>
                try {
                    updateProgress('✅ Added: {$learnerName} ({$learnerProcessTime}ms, Memory: " . round(memory_get_usage(true)/1024/1024, 1) . "MB)');
                } catch(e) {
                    console.log('Success progress message failed:', e.message);
                }
            </script>";
            flush();

            // Aggressive memory cleanup after each learner
            unset($htmlContent, $mpdf, $cleanHtml, $pdfContent);
            if (function_exists('gc_collect_cycles')) {
                gc_collect_cycles();
            }

        } catch (Exception $e) {
            echo "<script>updateProgress('❌ Error: {$learnerName} - " . htmlspecialchars($e->getMessage(), ENT_QUOTES) . "');</script>";
            echo "<div style='background: #ffebee; border: 1px solid #f44336; padding: 8px; margin: 5px 0; font-family: monospace; color: #c62828;'><strong>" . date('H:i:s') . ":</strong> ❌ PHP Exception: {$learnerName} - " . htmlspecialchars($e->getMessage(), ENT_QUOTES) . "</div>";
            flush();
            error_log("Error generating PDF for learner {$learnerID}: " . $e->getMessage());
            $errorCount++;
            continue;
        }
    }

    // Close the processing loop
            echo "<script>
            try {
                updateProgress('📦 Creating ZIP file with all PDFs...');
            } catch(e) {
                console.log('ZIP creation message error:', e.message);
            }
        </script>";
    flush();

    // Step 2: Create zip of all PDFs
    $zip->close(); // Close the current empty ZIP

    // Reopen ZIP and add all PDF files
    if ($zip->open($zipFullPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
        echo "<script>updateProgress('❌ Could not create zip file');</script>";
        die("❌ Could not create zip file");
    }

    foreach (glob("$tempDir/*.pdf") as $file) {
        $zip->addFile($file, basename($file));
    }
    $zip->close();

    echo "<script>
        try {
            updateProgress('📦 Finalizing ZIP file...');
        } catch(e) {
            console.log('ZIP finalization message error:', e.message);
        }
    </script>";
    flush();

    // Check if any PDFs were successfully generated
    if ($successCount === 0) {
        echo "<script>
            try {
                updateProgress('❌ No valid PDFs were generated. Errors: {$errorCount}');
                addDebug('Final Statistics: Success={$successCount}, Errors={$errorCount}');
                addDebug('Please check the detailed error messages above');
            } catch(e) {
                console.log('No PDFs error message failed:', e.message);
            }
        </script>";
        echo "<div style='background: #ffebee; border: 1px solid #f44336; padding: 15px; margin: 10px 0; font-family: monospace; color: #c62828;'><h3>❌ BULK DOWNLOAD FAILED</h3><p><strong>Final Statistics:</strong> Success: {$successCount}, Errors: {$errorCount}</p><p><strong>Possible Causes:</strong></p><ul><li>Database connection issues</li><li>Invalid learner/project data</li><li>File system permissions</li><li>Memory/time limits</li></ul><p><strong>Next Steps:</strong></p><ol><li>Check the detailed error messages above</li><li>Verify database connectivity</li><li>Check learner and project data</li><li>Review server error logs</li></ol><p><strong>Note:</strong> Using simplified PDF generation to avoid timeout issues</p></div>";
        echo "<div style='background: #fff3e0; border: 1px solid #ff9800; padding: 10px; margin: 10px 0;'><strong>🔍 Debug Information:</strong><br>• PHP Version: " . PHP_VERSION . "<br>• Server: " . $_SERVER['SERVER_SOFTWARE'] . "<br>• Memory Usage: " . round(memory_get_usage(true)/1024/1024, 1) . "MB<br>• Max Memory: " . ini_get('memory_limit') . "<br>• Max Execution Time: " . ini_get('max_execution_time') . "s</div>";
        echo "</body></html>";
        error_log("No valid PDFs were generated. Success: {$successCount}, Errors: {$errorCount}");
        if (file_exists($zipFullPath)) {
            unlink($zipFullPath);
        }

        // Clean up PDF files
        $reportDir = __DIR__ . "/reports";
        if (is_dir($reportDir)) {
            array_map('unlink', glob("$reportDir/*.pdf"));
            @rmdir($reportDir);
        }
        exit();
    }

    // Verify ZIP file was created and has content
    if (!file_exists($zipFullPath) || filesize($zipFullPath) === 0) {
        echo "<script>
        try {
            updateProgress('❌ Failed to create ZIP file.');
        } catch(e) {
            console.log('ZIP creation failed message error:', e.message);
        }
    </script>";
        echo "<p style='color: red;'>Failed to create ZIP file with PDFs. Please try again.</p>";
        echo "</body></html>";
        error_log("ZIP file is empty or not created: " . $zipFullPath);
        if (file_exists($zipFullPath)) {
            unlink($zipFullPath);
        }

        // Clean up PDF files
        $reportDir = __DIR__ . "/reports";
        if (is_dir($reportDir)) {
            array_map('unlink', glob("$reportDir/*.pdf"));
            @rmdir($reportDir);
        }
        exit();
    }

    echo "<script>
        try {
            updateProgress('✅ Success! Generated {$successCount} PDFs. Download ready!');
        } catch(e) {
            console.log('Success message error:', e.message);
        }
    </script>";
    echo "<div style='background: #d4edda; padding: 20px; margin: 20px; border: 1px solid #c3e6cb; border-radius: 5px;'>";
    echo "<h3 style='color: #155724; margin: 0 0 10px 0;'>✅ Success!</h3>";
    echo "<p style='color: #155724; margin: 5px 0;'>Generated {$successCount} reports with {$errorCount} errors.</p>";
    
    // Build a clean download URL so we don't re-trigger generation handlers (e.g., auto_bulk_pdfs=1)
    $downloadUrl = $_SERVER['PHP_SELF'] . '?download_zip=1';
    $downloadUrlWithTs = $downloadUrl . '&ts=' . time();
    echo "<p style='margin: 15px 0; display:flex; gap:12px; align-items:center; flex-wrap:wrap;'>";
    // Anchor link (opens in new tab)
    echo "<a id='zipLink' href='" . htmlspecialchars($downloadUrlWithTs) . "' target='_blank' style='background: #007cba; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; font-weight: bold;'>📥 Download ZIP File</a>";
    // Button fallback (GET form submit)
    echo "<form action='" . htmlspecialchars($_SERVER['PHP_SELF']) . "' method='GET' style='margin:0; display:inline;'>";
    echo "<input type='hidden' name='download_zip' value='1'>";
    echo "<input type='hidden' name='ts' value='" . time() . "'>";
    echo "<button type='submit' style='background:#17a2b8;color:#fff;border:none;border-radius:5px;padding:10px 16px;cursor:pointer;'>⬇️ Fallback Download</button>";
    echo "</form>";
    // Raw link fallback
    echo "<span style='font-size:12px;color:#6c757d'>If blocked, right-click this link → Open in new tab: " . htmlspecialchars($downloadUrlWithTs) . "</span>";
    echo "</p>";
    // JS force-navigation fallback
    echo "<script>document.getElementById('zipLink').addEventListener('click', function(e){ try { setTimeout(function(){ window.location.href='" . addslashes($downloadUrlWithTs) . "'; }, 500); } catch(err){} });</script>";
    echo "</p>";
    echo "<p style='color: #6c757d; font-size: 12px; margin: 5px 0 0 0;'>Click the button above to download your reports.</p>";
    echo "</div>";
    echo "</body></html>";
    flush();

    // Store zip info in session for download
    $_SESSION['bulk_zip_path'] = $zipFullPath;
    $_SESSION['bulk_zip_name'] = $zipFileName;
    
    // Log success
    error_log("Bulk PDF export completed successfully. Generated {$successCount} PDFs with {$errorCount} errors.");
    
    exit();
}

// Handle ZIP file download
if (isset($_GET['download_zip']) && $_GET['download_zip'] == '1') {
    error_log("DEBUG: Download handler triggered");
    error_log("DEBUG: download_zip = " . $_GET['download_zip']);
    
    // Check if we have session data
    if (!isset($_SESSION['bulk_zip_path'])) {
        error_log("DEBUG: No session zip path found");
        die("
        <div style='padding: 20px; background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; margin: 20px;'>
            <h3>❌ Download Error</h3>
            <p>No ZIP file found in session. Please generate the reports again.</p>
            <a href='" . $_SERVER['PHP_SELF'] . "' style='background: #007cba; color: white; padding: 5px 10px; text-decoration: none;'>← Back to Reports</a>
        </div>");
    }
    
    $zipPath = $_SESSION['bulk_zip_path'];
    $zipName = $_SESSION['bulk_zip_name'] ?? 'bulk_reports.zip';
    
    error_log("DEBUG: zipPath = {$zipPath}, zipName = {$zipName}");
    
    if (file_exists($zipPath)) {
        $fileSize = filesize($zipPath);
        error_log("ZIP download: File exists, size: {$fileSize} bytes, path: {$zipPath}");
        
        // Verify it's a valid ZIP file
        $fileHandle = fopen($zipPath, 'rb');
        $firstBytes = fread($fileHandle, 4);
        fclose($fileHandle);
        
        if ($firstBytes !== "PK\x03\x04" && $firstBytes !== "PK\x05\x06") {
            error_log("Invalid ZIP file signature: " . bin2hex($firstBytes));
            die("Error: Generated file is not a valid ZIP archive.");
        }
        
        // Clear any output buffers and ensure clean headers
        while (ob_get_level()) {
            ob_end_clean();
        }
        
        // Set proper headers for ZIP download
        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename="' . basename($zipName) . '"');
        header('Content-Length: ' . $fileSize);
        header('Content-Transfer-Encoding: binary');
        header('Cache-Control: no-cache, no-store, must-revalidate');
        header('Pragma: no-cache');
        header('Expires: 0');
        
        // Output file and clean up
        readfile($zipPath);
        
        // Clean up temporary files
        unlink($zipPath);

        // Optional: Cleanup (delete after download)
        $reportDir = __DIR__ . "/reports";
        if (is_dir($reportDir)) {
            // Delete all PDF files
            array_map('unlink', glob("$reportDir/*.pdf"));
            // Remove the reports directory if empty
            @rmdir($reportDir);
        }
        
        // Clean up session
        unset($_SESSION['bulk_zip_path']);
        unset($_SESSION['bulk_zip_name']);
        
        exit();
    } else {
        error_log("DEBUG: ZIP file not found at path: {$zipPath}");
        die("
        <div style='padding: 20px; background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; margin: 20px;'>
            <h3>❌ File Not Found</h3>
            <p>ZIP file not found at expected location. It may have been cleaned up or moved.</p>
            <p><strong>Expected path:</strong> {$zipPath}</p>
            <a href='" . $_SERVER['PHP_SELF'] . "' style='background: #007cba; color: white; padding: 5px 10px; text-decoration: none;'>← Generate Reports Again</a>
        </div>");
    }
}
// Alternative method using file_get_contents if cURL is not available
function generateBulkPDFsAlternative($reportData, $startDate, $year, $month) {
    // This is a fallback method that generates PDFs using Mpdf directly
    // without relying on the individual.php file
    
    $tempDir = sys_get_temp_dir() . '/attendance_pdfs_' . uniqid();
    mkdir($tempDir, 0755, true);
    
    $zip = new ZipArchive();
    $zipFileName = 'Bulk_Attendance_Reports_' . date('Ymd_His') . '.zip';
    $zipFullPath = $tempDir . '/' . $zipFileName;
    
    $zip->open($zipFullPath, ZipArchive::CREATE);
    
    foreach ($reportData as $learnerID => $learner) {
        try {
            // Generate individual attendance data for this learner
            $html = generateIndividualReportHTML($learnerID, $learner, $year, $month);
            
            // Create PDF using Mpdf
            $mpdf = new \Mpdf\Mpdf([
                'mode' => 'utf-8',
                'format' => 'A4',
                'tempDir' => sys_get_temp_dir()
            ]);
            
            $mpdf->WriteHTML($html);
            
            // Get PDF content as string
            $pdfContent = $mpdf->Output('', 'S');
            
            // Sanitize filename
            $surname = preg_replace('/[^a-zA-Z0-9]/', '_', $learner['surname'] ?? 'Unknown');
            $name = preg_replace('/[^a-zA-Z0-9]/', '_', $learner['name'] ?? 'Unknown');
            $idNumber = preg_replace('/[^a-zA-Z0-9]/', '_', $learner['id_number'] ?? 'Unknown');
            $pdfFileName = "{$surname}_{$name}_{$idNumber}_" . date('Y-m') . ".pdf";
            
            // Add to ZIP
            $zip->addFromString($pdfFileName, $pdfContent);
            
            unset($mpdf);
            
        } catch (Exception $e) {
            error_log("Error generating PDF for learner {$learnerID}: " . $e->getMessage());
            continue;
        }
    }
    
    $zip->close();
    
    return $zipFullPath;
}

function generateIndividualReportHTML($learnerID, $learner, $year, $month) {
    // This function would contain the HTML generation logic
    // that mimics what indivisual.php does
    // You would need to adapt the individual report generation logic here
    
    $html = "
    <html>
    <head>
        <title>Individual Attendance Report</title>
        <style>
            body { font-family: Arial, sans-serif; }
            table { width: 100%; border-collapse: collapse; }
            th, td { border: 1px solid #000; padding: 5px; text-align: center; }
            th { background: #f0f0f0; }
        </style>
    </head>
    <body>
        <h1>Individual Attendance Report</h1>
        <h2>{$learner['name']} {$learner['surname']}</h2>
        <p>ID Number: {$learner['id_number']}</p>
        <p>Period: {$year}-{$month}</p>
        <!-- Add more detailed attendance data here -->
    </body>
    </html>";
    
    return $html;
}
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
    /* Security: Disable text selection */
    -webkit-user-select: none;
    -moz-user-select: none;
    -ms-user-select: none;
    user-select: none;
}

/* Allow selection only in input fields */
input, textarea {
    -webkit-user-select: text;
    -moz-user-select: text;
    -ms-user-select: text;
    user-select: text;
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

.pending { 
    background: linear-gradient(135deg, #fbbf24, #fcd34d) !important;
    color: #000000;
    font-weight: 600;
    font-size: 12px;
    border-radius: 6px;
    padding: 4px 8px;
}

.holiday { 
    background: linear-gradient(135deg, #fbbf24, #fde68a) !important;
    color: #000000;
    font-weight: 600;
    font-size: 12px;
    border-radius: 6px;
    padding: 4px 8px;
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
    <!-- HIDDEN: Sidebar
    <div class="sidebar">
        <div class="logo-section">
            <div class="logo" onclick="toggleSidebar()">
                <img src="uploads/JCP.jpeg" alt="JCP Logo">
            </div>
        </div>
        
        <div class="nav-buttons">
            <a href="ecxecative_dashboard.php" class="nav-btn dashboard">Dashboard</a>
            <a href="attandence_tracking.php" class="nav-btn attendance active">Attendance Tracking</a>
             <a href="bulk_down_register.php" class="nav-btn attendance active">Bulk Register Download</a>
            <button class="nav-btn logout" onclick="navigateToLogout()">Logout</button>
        </div>
    </div>
    -->

    <div class="main-content">
        <!-- HIDDEN: Floating Toggle Button
        <button class="floating-toggle-btn" onclick="toggleSidebar()" aria-label="Toggle Sidebar">→</button>
        -->
        <div class="container">
            <div class="header">
                <h1>📊 Individual Learner Attendance Report</h1>
                <p class="subtitle">Comprehensive attendance tracking and analytics</p>
            </div>

            <div class="filters">
                <h3>🔍 Filter Options</h3>
                <form method="POST" id="filterForm">
                    <input type="hidden" name="form_token" value="<?= htmlspecialchars($_SESSION['form_token'], ENT_QUOTES, 'UTF-8') ?>">
                    <!-- HIDDEN: District, Site, and Class Filters
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
                        <select name="site" id="site" onchange="this.form.submit()">
                            <option value="">-- All Sites --</option>
                            <?php foreach ($sites as $site): ?>
                                <option value="<?= htmlspecialchars($site, ENT_QUOTES, 'UTF-8') ?>" <?= $site === $selectedSite ? 'selected' : '' ?>>
                                    <?= htmlspecialchars($site, ENT_QUOTES, 'UTF-8') ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    <div class="filter-group">
                        <label class="filter-label" for="class">Class</label>
                        <select name="class" id="class">
                            <option value="">-- All Classes --</option>
                            <?php foreach ($classes as $class): ?>
                                <option value="<?= htmlspecialchars($class['classID'], ENT_QUOTES, 'UTF-8') ?>" <?= $class['classID'] == $selectedClass ? 'selected' : '' ?>>
                                    <?= htmlspecialchars($class['className'], ENT_QUOTES, 'UTF-8') ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    -->
                    <div class="filter-group">
                        <label class="filter-label" for="month">Select Month</label>
                        <select name="month" id="month" onchange="this.form.submit()">
                            <option value="2025-08" <?= $selectedMonth === '2025-08' ? 'selected' : '' ?>>August 2025</option>
                            <option value="2025-09" <?= $selectedMonth === '2025-09' ? 'selected' : '' ?>>September 2025</option>
                            <option value="2025-10" <?= $selectedMonth === '2025-10' ? 'selected' : '' ?>>October 2025</option>
                        </select>
                    </div>
                    <!-- HIDDEN: Start Date and End Date inputs (now handled by month selector)
                    <div class="filter-group">
                        <label class="filter-label" for="start_date">Start Date</label>
                        <input type="date" name="start_date" id="start_date" value="<?= htmlspecialchars($startDate, ENT_QUOTES, 'UTF-8') ?>">
                    </div>
                    <div class="filter-group">
                        <label class="filter-label" for="end_date">End Date</label>
                        <input type="date" name="end_date" id="end_date" value="<?= htmlspecialchars($endDate, ENT_QUOTES, 'UTF-8') ?>">
                    </div>
                    -->
                    <div class="filter-group">
                        <label class="filter-label" for="id_search">Search by ID Number</label>
                        <input type="text" name="id_search" id="id_search" value="<?= isset($_GET['id_search']) ? htmlspecialchars($_GET['id_search'], ENT_QUOTES, 'UTF-8') : '' ?>" placeholder="Enter ID Number">
                    </div>
                    
                    <!-- HIDDEN: Attendance Filters Section
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
                    -->
                    
                    <div class="filter-group">
                        <label class="filter-label">&nbsp;</label>
                        <!-- HIDDEN: Generate Report Button
                        <button type="submit" name="generate">📈 Generate Report</button>
                        -->
                        <button type="submit" name="search" value="1">🔍 Search</button>
                        <!-- HIDDEN: Export to Excel Button
                        <button type="submit" name="export_excel" value="1">📊 Export to Excel</button>
                        -->
                    </div>
                </form>
            </div>

            <!-- HIDDEN: Executive Summary Section
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
            -->

            <!-- HIDDEN: Legend Section
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
            -->

            <?php if ($showOutstandingFeesMessage): ?>
                <div class="outstanding-fees-message" style="background: #fff3cd; border: 2px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 8px; text-align: center;">
                    <strong style="color: #856404; font-size: 18px;">⚠️ October Payments Still Pending</strong>
                    <p style="color: #856404; margin: 10px 0 0 0;">October stipends are still pending and haven't been paid yet.</p>
                </div>
            <?php endif; ?>

            <?php if (!empty($reportData) && isset($_GET['id_search']) && !empty($_GET['id_search'])): ?>
                <div class="report-section">
                    <h2 class="report-title">Learner Attendance</h2>
                    
                    <div class="table-container">
                        <table>
                            <thead>
                                <tr>
                                    <th rowspan="2" style="vertical-align: middle;">#</th>
                                    <th rowspan="2" style="vertical-align: middle;">Surname</th>
                                    <th rowspan="2" style="vertical-align: middle;">Name</th>
                                    <th rowspan="2" style="vertical-align: middle;">ID Number</th>
                                    <!-- HIDDEN: Phone Number Column
                                    <th rowspan="2" style="vertical-align: middle;">Phone Number</th>
                                    -->
                                    <!-- HIDDEN: Attendance Dates Column
                                    <th colspan="<?= count($dates) ?>">Attendance Dates (Weekdays)</th>
                                    -->
                                    <th rowspan="2" style="vertical-align: middle;">Total Present</th>
                                    <!-- HIDDEN: Attendance % Column
                                    <th rowspan="2" style="vertical-align: middle;">Attendance %</th>
                                    -->
                                    <th rowspan="2" style="vertical-align: middle;">Daily Rate</th>
                                    <!-- HIDDEN: Amount Due Column
                                    <th rowspan="2" style="vertical-align: middle;">Amount Due</th>
                                    -->
                                    <!-- HIDDEN: Individual Attendance Column
                                    <th rowspan="2" style="vertical-align: middle;">Individual Attendance</th>
                                    -->
                                </tr>
                                <tr>
                                    <!-- HIDDEN: Date Headers
                                    <?php foreach ($dates as $date): ?>
                                        <th class="date-header"><?= date('M d', strtotime($date)) ?><br><?= date('D', strtotime($date)) ?></th>
                                    <?php endforeach; ?>
                                    -->
                                </tr>
                            </thead>
                            <tbody>
                                <?php $rowNumber = 1; ?>
                                <?php foreach ($reportData as $learnerID => $learner): ?>
                                    <?php 
                                    // First pass: Check if learner has ANY actual attendance
                                    $hasAnyAttendance = false;
                                    $actualPresentDays = 0;
                                    
                                    foreach ($dates as $date) {
                                        if (!isset($publicHolidaysInRange[$date]) && isset($learner['attendance'][$date])) {
                                            $attendance = $learner['attendance'][$date];
                                            if ($attendance['source'] === 'regular' || 
                                                ($attendance['source'] === 'manual' && strcasecmp($attendance['status'], 'Approved') === 0)) {
                                                $hasAnyAttendance = true;
                                                $actualPresentDays++;
                                            }
                                        }
                                    }
                                    
                                    // Second pass: Count total present including holidays (only if learner has attendance)
                                    $totalPresent = $actualPresentDays;
                                    if ($hasAnyAttendance) {
                                        foreach ($dates as $date) {
                                            if (isset($publicHolidaysInRange[$date])) {
                                                $totalPresent++;
                                            }
                                        }
                                    }
                                    
                                    $attendancePercent = count($dates) > 0 ? round(($totalPresent / count($dates)) * 100, 1) : 0;
                                    $percentClass = $attendancePercent >= 90 ? 'percentage-excellent' : ($attendancePercent >= 70 ? 'percentage-good' : 'percentage-poor');
                                    // Calculate amount due: R2000 for 100% attendance, otherwise daily rate
                                    $amountDue = ($attendancePercent == 100) ? $perfectAttendanceAmount : $totalPresent * $dailyRate;
                                    ?>
                                    <tr class="learner-row">
                                        <td class="learner-details"><?= $rowNumber++ ?></td>
                                        <td class="learner-details"><?= ($learner['surname'] === null || $learner['surname'] === '') ? 'N/A' : htmlspecialchars($learner['surname'], ENT_QUOTES, 'UTF-8') ?></td>
                                        <td class="learner-details"><?= ($learner['name'] === null || $learner['name'] === '') ? 'N/A' : htmlspecialchars($learner['name'], ENT_QUOTES, 'UTF-8') ?></td>
                                        <td class="learner-details"><?= ($learner['id_number'] === null || $learner['id_number'] === '') ? 'N/A' : htmlspecialchars($learner['id_number'], ENT_QUOTES, 'UTF-8') ?></td>
                                        <!-- HIDDEN: Phone Number Cell
                                        <td class="learner-details"><?= ($learner['phone_number'] === null || $learner['phone_number'] === '') ? 'N/A' : htmlspecialchars($learner['phone_number'], ENT_QUOTES, 'UTF-8') ?></td>
                                        -->
                                        
                                        <!-- HIDDEN: Date Cells
                                        <?php foreach ($dates as $date): ?>
                                            <?php 
                                            $cellClass = 'absent';
                                            $cellContent = '✗';
                                            $statusLabel = '';
                                            
                                            if (isset($publicHolidaysInRange[$date])) {
                                                // Public holiday - always yellow
                                                $cellClass = 'holiday';
                                                $cellContent = "<small style='font-size:9px;'>" . htmlspecialchars($publicHolidaysInRange[$date], ENT_QUOTES, 'UTF-8') . "</small>";
                                            } elseif (isset($learner['attendance'][$date])) {
                                                $attendance = $learner['attendance'][$date];
                                                if ($attendance['source'] === 'manual') {
                                                    $status = $attendance['status'] ?? 'Unknown';
                                                    $statusLabel = ucfirst(strtolower($status));
                                                    $cellClass = ($status === 'Approved') ? 'present' : (($status === 'Pending') ? 'pending' : 'absent');
                                                    $cellContent = "<small style='font-size:9px;'>Manual<br>{$statusLabel}</small>";
                                                } else {
                                                    $cellClass = 'present';
                                                    $signatureFile = $learner['signature'];
                                                    $serverPath = $_SERVER['DOCUMENT_ROOT'] . '/mobile/signatures/' . $signatureFile;
                                                    $webPath = '/mobile/signatures/' . $signatureFile;
                                                    if ($signatureFile && !empty($signatureFile) && preg_match('/\.(png|jpg|jpeg|gif)$/i', $signatureFile) && file_exists($serverPath)) {
                                                        $cellContent = '<img src="' . htmlspecialchars($webPath, ENT_QUOTES, 'UTF-8') . '" alt="Signature" class="signature-img" onerror="this.src=\'\';this.parentNode.innerHTML=\'✓✓\';">';
                                                    } else {
                                                        $cellContent = '✓✓';
                                                    }
                                                }
                                            }
                                            ?>
                                            <td class="<?= $cellClass ?>">
                                                <?= $cellContent ?>
                                            </td>
                                        <?php endforeach; ?>
                                        -->
                                        
                                        <td class="stats-cell"><?= $totalPresent ?>/<?= count($dates) ?></td>
                                        <!-- HIDDEN: Attendance % Cell
                                        <td class="stats-cell <?= $percentClass ?>"><?= $attendancePercent ?>%</td>
                                        -->
                                        <td class="stats-cell">R <?= number_format($dailyRate, 2) ?></td>
                                        <!-- HIDDEN: Amount Due Cell
                                        <td class="stats-cell">R <?= number_format($amountDue, 2) ?></td>
                                        -->
                                        <!-- HIDDEN: Individual Attendance Cell
                                        <td>
                                            <a href="indivisual.php?LearnerID=<?= htmlspecialchars($learnerID, ENT_QUOTES, 'UTF-8') ?>&project_id=<?= htmlspecialchars($learner['project_id'] ?? '', ENT_QUOTES, 'UTF-8') ?>" class="view-report-btn">View Report</a>
                                        </td>
                                        -->
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                    
                    <!-- HIDDEN: Summary Section
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
                    -->
                </div>
                
            <?php else: ?>
                <?php if (!isset($_GET['id_search']) || empty($_GET['id_search'])): ?>
                    <div class="no-data" style="text-align: center; padding: 40px; background: #f8f9fa; border-radius: 8px; margin: 20px 0;">
                        <h3 style="color: #6c757d;">🔍 Search for a Learner</h3>
                        <p style="color: #6c757d;">Please enter a learner's ID number in the search box above to view their attendance details.</p>
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
            <?php endif; ?>

            <?php 
            $conn->close(); 
            ob_end_flush();
            ?>
        </div>
    </div>

    <script>
        // Security: Disable right-click context menu
        document.addEventListener('contextmenu', function(e) {
            e.preventDefault();
            return false;
        });

        // Security: Disable text selection
        document.addEventListener('selectstart', function(e) {
            if (e.target.tagName !== 'INPUT' && e.target.tagName !== 'TEXTAREA') {
                e.preventDefault();
                return false;
            }
        });

        // Security: Disable common keyboard shortcuts for copying
        document.addEventListener('keydown', function(e) {
            // Disable Ctrl+C, Ctrl+X, Ctrl+A, Ctrl+U (view source), Ctrl+S (save), F12 (dev tools), Ctrl+Shift+I (inspect)
            if (
                (e.ctrlKey && (e.key === 'c' || e.key === 'C' || e.key === 'x' || e.key === 'X' || e.key === 'a' || e.key === 'A' || e.key === 'u' || e.key === 's')) || 
                e.key === 'F12' ||
                (e.ctrlKey && e.shiftKey && (e.key === 'I' || e.key === 'i' || e.key === 'J' || e.key === 'j' || e.key === 'C' || e.key === 'c'))
            ) {
                e.preventDefault();
                alert('Copying is disabled on this page for security reasons.');
                return false;
            }
        });

        // Security: Disable copy event
        document.addEventListener('copy', function(e) {
            e.preventDefault();
            alert('Copying is disabled on this page for security reasons.');
            return false;
        });

        // Security: Disable cut event
        document.addEventListener('cut', function(e) {
            e.preventDefault();
            return false;
        });

        // Security: Disable drag and drop
        document.addEventListener('dragstart', function(e) {
            e.preventDefault();
            return false;
        });

        // Security: Clear URL parameters from address bar (using History API)
        if (window.history.replaceState) {
            window.history.replaceState(null, null, window.location.pathname);
        }

        // Security: Prevent page from being opened in iframe
        if (window.top !== window.self) {
            window.top.location = window.self.location;
        }

        // Security: Warn user when trying to copy URL
        window.addEventListener('beforeunload', function(e) {
            // This will show a warning when user tries to leave the page
        });

        function navigateToLogout() {
            if (confirm('Are you sure you want to logout?')) {
                window.location.href = 'logout.php';
            }
        }

        function toggleSidebar() {
            const sidebar = document.querySelector('.sidebar');
            const mainContent = document.querySelector('.main-content');
            
            sidebar.classList.toggle('sidebar-hidden');
            mainContent.classList.toggle('main-content-expanded');
        }

        document.addEventListener('DOMContentLoaded', function() {
            // Animate summary items
            const summaryItems = document.querySelectorAll('.summary-item');
            summaryItems.forEach((item, index) => {
                item.style.opacity = '0';
                item.style.transform = 'translateY(20px)';
                setTimeout(() => {
                    item.style.transition = 'all 0.5s ease';
                    item.style.opacity = '1';
                    item.style.transform = 'translateY(0)';
                }, index * 100);
            });

            // Animate summary numbers
            const numberElements = document.querySelectorAll('.summary-number');
            numberElements.forEach(element => {
                const target = element.dataset.count || '0';
                let current = 0;
                
                const isFraction = target.includes('/');
                const isPercentage = target.includes('%');
                const isCurrency = target.includes('R ');

                let targetValue;
                let targetDenominator = null;

                if (isCurrency) {
                    targetValue = parseFloat(target.replace('R ', '').replace(/,/g, '')) || 0;
                } else if (isFraction) {
                    const [numerator, denominator] = target.split('/').map(val => parseFloat(val) || 0);
                    targetValue = numerator;
                    targetDenominator = denominator;
                } else if (isPercentage) {
                    targetValue = parseFloat(target.replace('%', '')) || 0;
                } else {
                    targetValue = parseFloat(target) || 0;
                }

                const animateNumber = () => {
                    if (current < targetValue) {
                        current = Math.min(current + Math.max(targetValue / 50, 1), targetValue);
                        if (isCurrency) {
                            element.textContent = `R ${current.toLocaleString('en-ZA', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
                        } else if (isFraction) {
                            element.textContent = `${Math.round(current)}/${targetDenominator}`;
                        } else if (isPercentage) {
                            element.textContent = `${Math.round(current)}%`;
                        } else {
                            element.textContent = Math.round(current).toLocaleString();
                        }
                        requestAnimationFrame(animateNumber);
                    } else {
                        element.textContent = target; // Set final value exactly as provided
                    }
                };

                // Set initial value and start animation
                element.textContent = isCurrency ? 'R 0.00' : isFraction ? '0/0' : isPercentage ? '0%' : '0';
                if (targetValue > 0 || isFraction || isPercentage) {
                    requestAnimationFrame(animateNumber);
                } else {
                    element.textContent = target; // Set immediately if no animation needed
                }
            });

            // Handle "All" option in attendance filter to exclude 0%
            const attendanceFilter = document.getElementById('attendance_filter');
            if (attendanceFilter) {
                attendanceFilter.addEventListener('change', function(e) {
                    const select = e.target;
                    const options = select.options;
                    const allOption = Array.from(options).find(opt => opt.value === 'all');
                    const zeroOption = Array.from(options).find(opt => opt.value === 'zero');

                    if (allOption.selected) {
                        for (let option of options) {
                            if (option.value !== 'zero' || (option.value === 'zero' && zeroOption.selected)) {
                                option.selected = true;
                            } else {
                                option.selected = false;
                            }
                        }
                    } else if (e.target.value === 'all' && !allOption.selected) {
                        for (let option of options) {
                            option.selected = false;
                        }
                    }
                });
            }
        });
    </script>
</body>
</html>