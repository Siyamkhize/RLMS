<?php
/**
 * Get Eligible Dates for Sick Note Upload
 * 
 * Returns:
 * - Eligibility status (first-time learner check)
 * - List of selectable dates (last 5 working days with missing attendance)
 * - SA public holidays for reference
 */

include('connection.php');
header('Content-Type: application/json');

// Input validation
$learner_id = isset($_POST['learner_id']) ? intval($_POST['learner_id']) : 0;

if ($learner_id <= 0) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Invalid learner ID'
    ]);
    exit;
}

/**
 * SA Public Holidays 2024-2027
 * Fixed dates + Sunday->Monday, Saturday->Monday rules (except 26 Dec)
 */
function getSAPublicHolidays($year) {
    $holidays = [];
    
    // Fixed holidays
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
        
        // Exception: December 26 stays fixed even on weekends
        if ($date === "$year-12-26") {
            $holidays[$date] = $name;
        }
        // Sunday -> move to Monday
        elseif ($dayOfWeek == 0) {
            $mondayDate = date('Y-m-d', strtotime($date . ' +1 day'));
            $holidays[$mondayDate] = $name . " (observed)";
        }
        // Saturday -> move to Monday
        elseif ($dayOfWeek == 6) {
            $mondayDate = date('Y-m-d', strtotime($date . ' +2 days'));
            $holidays[$mondayDate] = $name . " (observed)";
        }
        // Weekday -> keep as-is
        else {
            $holidays[$date] = $name;
        }
    }
    
    // Easter-based holidays (Good Friday, Family Day)
    $easter = easter_date($year);
    $goodFriday = date('Y-m-d', strtotime('-2 days', $easter));
    $familyDay = date('Y-m-d', strtotime('+1 day', $easter));
    
    $holidays[$goodFriday] = "Good Friday";
    $holidays[$familyDay] = "Family Day";
    
    return $holidays;
}

/**
 * Get last 5 working days (excluding weekends and public holidays)
 * Returns array of dates in Y-m-d format
 */
function getLast5WorkingDays() {
    $workingDays = [];
    $date = new DateTime();
    $currentYear = intval($date->format('Y'));
    $holidays = getSAPublicHolidays($currentYear);
    
    // Also get previous year holidays in case we're in early January
    $prevYearHolidays = getSAPublicHolidays($currentYear - 1);
    $allHolidays = array_merge($holidays, $prevYearHolidays);
    
    $attempts = 0;
    $maxAttempts = 30; // Safety limit (5 working days could span ~2 weeks)
    
    while (count($workingDays) < 5 && $attempts < $maxAttempts) {
        $dateStr = $date->format('Y-m-d');
        $dayOfWeek = intval($date->format('w'));
        
        // Check if it's a working day
        $isWeekend = ($dayOfWeek == 0 || $dayOfWeek == 6); // Sunday or Saturday
        $isHoliday = isset($allHolidays[$dateStr]);
        
        if (!$isWeekend && !$isHoliday) {
            $workingDays[] = $dateStr;
        }
        
        // Move to previous day
        $date->modify('-1 day');
        $attempts++;
    }
    
    return $workingDays;
}

try {
    // ═══════════════════════════════════════════════════════════
    // STEP 1: ELIGIBILITY GATE
    // ═══════════════════════════════════════════════════════════
    
    // Check if learner has any clocking history
    $sql1 = "SELECT COUNT(*) as count FROM learner_clocking WHERE LearnerID = ?";
    $stmt1 = $conn->prepare($sql1);
    $stmt1->bind_param("i", $learner_id);
    $stmt1->execute();
    $result1 = $stmt1->get_result();
    $row1 = $result1->fetch_assoc();
    $hasLearnerClocking = ($row1['count'] > 0);
    $stmt1->close();
    
    // Check if learner has any approved manual clocking
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
    
    $isEligible = ($hasLearnerClocking || $hasApprovedManualClocking);
    
    if (!$isEligible) {
        echo json_encode([
            'status' => 'error',
            'message' => 'You are a first time learner, you are not able to upload a sick note.',
            'is_eligible' => false,
            'reason' => 'no_clocking_history'
        ]);
        exit;
    }
    
    // ═══════════════════════════════════════════════════════════
    // STEP 2: BUILD CANDIDATE DATE RANGE
    // ═══════════════════════════════════════════════════════════
    
    $candidateDates = getLast5WorkingDays();
    
    // ═══════════════════════════════════════════════════════════
    // STEP 3: FILTER TO ONLY "MISSING ATTENDANCE" DAYS
    // ═══════════════════════════════════════════════════════════
    
    $selectableDates = [];
    
    foreach ($candidateDates as $date) {
        // Check if learner clocked in on this date
        $sql3 = "SELECT COUNT(*) as count FROM learner_clocking 
                 WHERE LearnerID = ? AND DATE(clock_date) = ?";
        $stmt3 = $conn->prepare($sql3);
        $stmt3->bind_param("is", $learner_id, $date);
        $stmt3->execute();
        $result3 = $stmt3->get_result();
        $row3 = $result3->fetch_assoc();
        $hasClockedIn = ($row3['count'] > 0);
        $stmt3->close();
        
        // Check if learner has approved manual clocking on this date
        $sql4 = "SELECT COUNT(*) as count FROM manual_clocking 
                 WHERE LearnerID = ? AND DATE(clock_date) = ?
                 AND status = 'Approved'";
        $stmt4 = $conn->prepare($sql4);
        $stmt4->bind_param("is", $learner_id, $date);
        $stmt4->execute();
        $result4 = $stmt4->get_result();
        $row4 = $result4->fetch_assoc();
        $hasApprovedManual = ($row4['count'] > 0);
        $stmt4->close();
        
        // Check if sick note already exists for this date (check if date falls in range)
        $sql5 = "SELECT COUNT(*) as count FROM sick_note 
                 WHERE learner_id = ? 
                 AND ? BETWEEN date_from AND date_to";
        $stmt5 = $conn->prepare($sql5);
        $stmt5->bind_param("is", $learner_id, $date);
        $stmt5->execute();
        $result5 = $stmt5->get_result();
        $row5 = $result5->fetch_assoc();
        $hasSickNote = ($row5['count'] > 0);
        $stmt5->close();
        
        // Date is selectable only if NO attendance record exists
        if (!$hasClockedIn && !$hasApprovedManual && !$hasSickNote) {
            $selectableDates[] = [
                'date' => $date,
                'formatted' => date('D, d M Y', strtotime($date)),
                'is_selectable' => true
            ];
        } else {
            // Include in response but mark as not selectable (for UI graying)
            $reason = [];
            if ($hasClockedIn) $reason[] = 'clocked_in';
            if ($hasApprovedManual) $reason[] = 'approved_manual';
            if ($hasSickNote) $reason[] = 'sick_note_exists';
            
            $selectableDates[] = [
                'date' => $date,
                'formatted' => date('D, d M Y', strtotime($date)),
                'is_selectable' => false,
                'reason' => implode(', ', $reason)
            ];
        }
    }
    
    // ═══════════════════════════════════════════════════════════
    // RESPONSE
    // ═══════════════════════════════════════════════════════════
    
    echo json_encode([
        'status' => 'success',
        'is_eligible' => true,
        'dates' => $selectableDates,
        'candidate_dates' => $candidateDates,
        'message' => 'Eligible to upload sick note'
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}

$conn->close();
