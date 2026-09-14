<?php
/**
 * Submit Sick Note with Server-Side Validation
 * 
 * Validates:
 * 1. Learner eligibility (has clocking history)
 * 2. Date is within last 5 working days
 * 3. Date has no existing attendance record
 * 4. Sick note document is uploaded
 */

include('../connection.php');
header('Content-Type: application/json');

// Input validation
$learner_id = isset($_POST['learner_id']) ? intval($_POST['learner_id']) : 0;
$date_from = isset($_POST['date_from']) ? trim($_POST['date_from']) : '';
$date_to = isset($_POST['date_to']) ? trim($_POST['date_to']) : '';
$practice_name = isset($_POST['practice_name']) ? trim($_POST['practice_name']) : '';
$practitioner_name = isset($_POST['practitioner_name']) ? trim($_POST['practitioner_name']) : '';

if ($learner_id <= 0) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Invalid learner ID',
        'error_code' => 'INVALID_LEARNER_ID'
    ]);
    exit;
}

if (empty($date_from)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Date is required',
        'error_code' => 'MISSING_DATE'
    ]);
    exit;
}

// If date_to is not provided, use date_from
if (empty($date_to)) {
    $date_to = $date_from;
}

/**
 * SA Public Holidays (same as in get_eligible_dates.php)
 */
function getSAPublicHolidays($year) {
    $holidays = [];
    
    $fixed = [
        "$year-01-01" => "New Year's Day",
        "$year-03-21" => "Human Rights Day",
        "$year-04-27" => "Freedom Day",
        "$year-05-01" => "Workers' Day",
        "$year-06-16" => "Youth Day",
        "$year-08-09" => "National Women's Day",
        "$year-09-24" => "Heritage Day",
        "$year-12-16" => "Day of Reconciliation",
        "$year-12-25" => "Christmas Day",
        "$year-12-26" => "Day of Goodwill"
    ];
    
    foreach ($fixed as $date => $name) {
        $dayOfWeek = date('w', strtotime($date));
        
        if ($date === "$year-12-26") {
            $holidays[$date] = $name;
        } elseif ($dayOfWeek == 0) {
            $mondayDate = date('Y-m-d', strtotime($date . ' +1 day'));
            $holidays[$mondayDate] = $name . " (observed)";
        } elseif ($dayOfWeek == 6) {
            $mondayDate = date('Y-m-d', strtotime($date . ' +2 days'));
            $holidays[$mondayDate] = $name . " (observed)";
        } else {
            $holidays[$date] = $name;
        }
    }
    
    $easter = easter_date($year);
    $goodFriday = date('Y-m-d', strtotime('-2 days', $easter));
    $familyDay = date('Y-m-d', strtotime('+1 day', $easter));
    
    $holidays[$goodFriday] = "Good Friday";
    $holidays[$familyDay] = "Family Day";
    
    return $holidays;
}

function getLast5WorkingDays() {
    $workingDays = [];
    $date = new DateTime();
    $currentYear = intval($date->format('Y'));
    $holidays = getSAPublicHolidays($currentYear);
    $prevYearHolidays = getSAPublicHolidays($currentYear - 1);
    $allHolidays = array_merge($holidays, $prevYearHolidays);
    
    $attempts = 0;
    $maxAttempts = 30;
    
    while (count($workingDays) < 5 && $attempts < $maxAttempts) {
        $dateStr = $date->format('Y-m-d');
        $dayOfWeek = intval($date->format('w'));
        
        $isWeekend = ($dayOfWeek == 0 || $dayOfWeek == 6);
        $isHoliday = isset($allHolidays[$dateStr]);
        
        if (!$isWeekend && !$isHoliday) {
            $workingDays[] = $dateStr;
        }
        
        $date->modify('-1 day');
        $attempts++;
    }
    
    return $workingDays;
}

try {
    // ═══════════════════════════════════════════════════════════
    // SERVER-SIDE VALIDATION 1: ELIGIBILITY GATE
    // ═══════════════════════════════════════════════════════════
    
    $sql1 = "SELECT COUNT(*) as count FROM learner_clocking WHERE LearnerID = ?";
    $stmt1 = $conn->prepare($sql1);
    $stmt1->bind_param("i", $learner_id);
    $stmt1->execute();
    $result1 = $stmt1->get_result();
    $row1 = $result1->fetch_assoc();
    $hasLearnerClocking = ($row1['count'] > 0);
    $stmt1->close();
    
    $sql2 = "SELECT COUNT(*) as count FROM manual_clocking 
             WHERE LearnerID = ? 
             AND status = 'Approved'";
    $stmt2 = $conn->prepare($sql2);
    $stmt2->bind_param("i", $learner_id);
    $stmt2->execute();
    $result2 = $stmt2->get_result();
    $row2 = $result2->fetch_assoc();
    $hasApprovedManualClocking = ($row2['count'] > 0);
    $stmt2->close();
    
    if (!$hasLearnerClocking && !$hasApprovedManualClocking) {
        echo json_encode([
            'status' => 'error',
            'message' => 'You are a first time learner, you are not able to upload a sick note.',
            'error_code' => 'NOT_ELIGIBLE'
        ]);
        exit;
    }
    
    // ═══════════════════════════════════════════════════════════
    // SERVER-SIDE VALIDATION 2: DATE WITHIN LAST 5 WORKING DAYS
    // ═══════════════════════════════════════════════════════════
    
    $validDates = getLast5WorkingDays();
    
    if (!in_array($date_from, $validDates)) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Selected date is not within the last 5 working days. Please select a valid date.',
            'error_code' => 'INVALID_DATE_RANGE',
            'valid_dates' => $validDates,
            'submitted_date' => $date_from
        ]);
        exit;
    }
    
    // ═══════════════════════════════════════════════════════════
    // SERVER-SIDE VALIDATION 3: NO EXISTING ATTENDANCE RECORD
    // ═══════════════════════════════════════════════════════════
    
    $sql3 = "SELECT COUNT(*) as count FROM learner_clocking 
             WHERE LearnerID = ? AND DATE(clock_date) = ?";
    $stmt3 = $conn->prepare($sql3);
    $stmt3->bind_param("is", $learner_id, $date_from);
    $stmt3->execute();
    $result3 = $stmt3->get_result();
    $row3 = $result3->fetch_assoc();
    $hasClockedIn = ($row3['count'] > 0);
    $stmt3->close();
    
    if ($hasClockedIn) {
        echo json_encode([
            'status' => 'error',
            'message' => 'You already clocked in on this date. Sick note cannot be submitted.',
            'error_code' => 'ALREADY_CLOCKED_IN',
            'date' => $date_from
        ]);
        exit;
    }
    
    $sql4 = "SELECT COUNT(*) as count FROM manual_clocking 
             WHERE LearnerID = ? AND DATE(clock_date) = ?
             AND status = 'Approved'";
    $stmt4 = $conn->prepare($sql4);
    $stmt4->bind_param("is", $learner_id, $date_from);
    $stmt4->execute();
    $result4 = $stmt4->get_result();
    $row4 = $result4->fetch_assoc();
    $hasApprovedManual = ($row4['count'] > 0);
    $stmt4->close();
    
    if ($hasApprovedManual) {
        echo json_encode([
            'status' => 'error',
            'message' => 'You have an approved manual clocking record on this date. Sick note cannot be submitted.',
            'error_code' => 'APPROVED_MANUAL_EXISTS',
            'date' => $date_from
        ]);
        exit;
    }
    
    // Check if sick note already exists for this date
    $sql5 = "SELECT COUNT(*) as count FROM sick_note 
             WHERE learner_id = ? 
             AND ? BETWEEN date_from AND date_to";
    $stmt5 = $conn->prepare($sql5);
    $stmt5->bind_param("is", $learner_id, $date_from);
    $stmt5->execute();
    $result5 = $stmt5->get_result();
    $row5 = $result5->fetch_assoc();
    $hasSickNote = ($row5['count'] > 0);
    $stmt5->close();
    
    if ($hasSickNote) {
        echo json_encode([
            'status' => 'error',
            'message' => 'A sick note already exists for this date.',
            'error_code' => 'SICK_NOTE_EXISTS',
            'date' => $date_from
        ]);
        exit;
    }
    
    // ═══════════════════════════════════════════════════════════
    // SERVER-SIDE VALIDATION 4: DOCUMENT UPLOAD
    // ═══════════════════════════════════════════════════════════
    
    $document_path = null;
    
    if (isset($_FILES['document']) && $_FILES['document']['error'] === UPLOAD_ERR_OK) {
        $upload_dir = 'sicknotes/';
        
        // Create directory if it doesn't exist
        if (!is_dir($upload_dir)) {
            mkdir($upload_dir, 0755, true);
        }
        
        $file_extension = strtolower(pathinfo($_FILES['document']['name'], PATHINFO_EXTENSION));
        $allowed_extensions = ['pdf'];
        
        if (!in_array($file_extension, $allowed_extensions)) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Invalid file type. Only PDF files are allowed (scanned documents).',
                'error_code' => 'INVALID_FILE_TYPE'
            ]);
            exit;
        }
        
        // Generate unique filename
        $filename = 'sick_note_' . $learner_id . '_' . date('Ymd_His') . '.' . $file_extension;
        $file_path = $upload_dir . $filename;
        
        if (move_uploaded_file($_FILES['document']['tmp_name'], $file_path)) {
            $document_path = 'sicknotes/' . $filename;
        } else {
            echo json_encode([
                'status' => 'error',
                'message' => 'Failed to upload document. Please try again.',
                'error_code' => 'UPLOAD_FAILED'
            ]);
            exit;
        }
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'Sick note document is required.',
            'error_code' => 'DOCUMENT_REQUIRED'
        ]);
        exit;
    }
    
    // ═══════════════════════════════════════════════════════════
    // INSERT SICK NOTE RECORD
    // ═══════════════════════════════════════════════════════════
    
    $sql_insert = "INSERT INTO sick_note 
                   (learner_id, document_path, practice_name, practitioner_name, date_from, date_to, status, upload_date) 
                   VALUES (?, ?, ?, ?, ?, ?, 'PENDING', NOW())";
    
    $stmt_insert = $conn->prepare($sql_insert);
    $stmt_insert->bind_param("isssss", 
        $learner_id, 
        $document_path, 
        $practice_name, 
        $practitioner_name,
        $date_from,
        $date_to
    );
    
    if ($stmt_insert->execute()) {
        $note_id = $conn->insert_id;
        $stmt_insert->close();
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Sick note submitted successfully and is pending approval.',
            'note_id' => $note_id,
            'date_from' => $date_from,
            'date_to' => $date_to,
            'document_path' => $document_path
        ]);
    } else {
        $stmt_insert->close();
        
        // Delete uploaded file if database insert fails
        if ($document_path && file_exists($document_path)) {
            unlink($document_path);
        }
        
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to save sick note. Please try again.',
            'error_code' => 'DATABASE_ERROR',
            'debug' => $conn->error
        ]);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Server error: ' . $e->getMessage(),
        'error_code' => 'SERVER_ERROR'
    ]);
}

$conn->close();
