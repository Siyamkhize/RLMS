<?php

require_once __DIR__ . '/../security_functions.php';
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST');
header('Access-Control-Allow-Headers: Content-Type');

// Database connection
require_once 'connection.php';

try {
    // Get parameters
    $classID = isset($_GET['classID']) ? $_GET['classID'] : null;
    $month = isset($_GET['month']) ? $_GET['month'] : date('Y-m');
    $learnerID = isset($_GET['learnerID']) ? $_GET['learnerID'] : null;
    
    if (!$classID) {
        echo json_encode(['error' => 'classID is required']);
        exit;
    }
    
    // Parse month to get first and last day
    $firstDay = $month . '-01';
    $lastDay = date('Y-m-t', strtotime($firstDay));
    
    // South African holidays function
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
        return $holidays;
    }
    
    // Get holidays for the month
    $year = (int)date('Y', strtotime($firstDay));
    $allHolidays = getSouthAfricanHolidays($year);
    
    // Get all WEEKDAY dates in the month (Monday-Friday)
    $dates = [];
    $publicHolidaysInRange = [];
    $currentDate = new DateTime($firstDay);
    $endDate = new DateTime($lastDay);
    
    while ($currentDate <= $endDate) {
        $dayOfWeek = $currentDate->format('N');
        $dateStr = $currentDate->format('Y-m-d');
        
        if ($dayOfWeek < 6) { // Weekday (Monday-Friday)
            $dates[] = $dateStr;
            
            // Check if this date is a holiday
            if (isset($allHolidays[$dateStr])) {
                $publicHolidaysInRange[$dateStr] = $allHolidays[$dateStr];
            }
        }
        $currentDate->modify('+1 day');
    }
    
    $totalWorkingDays = count($dates);
    
    // Get all learners
    $learnerQuery = "SELECT LearnerID, Name, Surname, classID FROM learnerdetails WHERE classID = ?";
    if ($learnerID) {
        $learnerQuery .= " AND LearnerID = ?";
        $stmt = $conn->prepare($learnerQuery);
        $stmt->bind_param("ii", $classID, $learnerID);
    } else {
        $stmt = $conn->prepare($learnerQuery);
        $stmt->bind_param("i", $classID);
    }
    $stmt->execute();
    $result = $stmt->get_result();
    $learners = [];
    while ($row = $result->fetch_assoc()) {
        $learners[] = $row;
    }
    $stmt->close();
    
    $results = [];
    
    foreach ($learners as $learner) {
        $lid = $learner['LearnerID'];
        
        // Get regular clocking attendance - count unique dates only where BOTH clock in AND clock out exist
        // AND exclude weekends (DAYOFWEEK: 1=Sunday, 7=Saturday)
        $clockingQuery = "SELECT DATE(clock_date) as clock_date 
                         FROM learner_clocking 
                         WHERE LearnerID = ? 
                         AND DATE(clock_date) >= ? AND DATE(clock_date) <= ?
                         AND clock_in_time IS NOT NULL 
                         AND clock_out_time IS NOT NULL
                         AND clock_in_time != '' 
                         AND clock_out_time != ''
                         AND clock_in_time != '00:00:00'
                         AND clock_out_time != '00:00:00'
                         AND DAYOFWEEK(clock_date) BETWEEN 2 AND 6
                         GROUP BY DATE(clock_date)";
        $stmt = $conn->prepare($clockingQuery);
        $stmt->bind_param("iss", $lid, $firstDay, $lastDay);
        $stmt->execute();
        $result = $stmt->get_result();
        $clockingDates = [];
        while ($row = $result->fetch_assoc()) {
            $clockingDates[] = $row['clock_date'];
        }
        $stmt->close();
        
        // Get manual clocking attendance (only approved) - count unique dates only
        // AND exclude weekends (DAYOFWEEK: 1=Sunday, 7=Saturday)
        $manualQuery = "SELECT DATE(clock_date) as clock_date
                       FROM manual_clocking 
                       WHERE LearnerID = ? 
                       AND DATE(clock_date) >= ? AND DATE(clock_date) <= ?
                       AND (status = 'Approved' OR status = 'approved' OR status = 'APPROVED')
                       AND DAYOFWEEK(clock_date) BETWEEN 2 AND 6
                       GROUP BY DATE(clock_date)";
        $stmt = $conn->prepare($manualQuery);
        $stmt->bind_param("iss", $lid, $firstDay, $lastDay);
        $stmt->execute();
        $result = $stmt->get_result();
        $manualDates = [];
        while ($row = $result->fetch_assoc()) {
            $manualDates[] = $row['clock_date'];
        }
        $stmt->close();
        
        // Get sick note dates (approved or N/A status)
        $sickQuery = "SELECT date_from, date_to, status
                     FROM sick_note
                     WHERE learner_id = ? 
                     AND status IN ('APPROVED', 'N/A')
                     AND ((date_from BETWEEN ? AND ?) OR (date_to BETWEEN ? AND ?) OR (date_from <= ? AND date_to >= ?))";
        $stmt = $conn->prepare($sickQuery);
        $stmt->bind_param("issssss", $lid, $firstDay, $lastDay, $firstDay, $lastDay, $firstDay, $lastDay);
        $stmt->execute();
        $result = $stmt->get_result();
        $sickDates = [];
        while ($row = $result->fetch_assoc()) {
            $start = new DateTime($row['date_from']);
            $end = new DateTime($row['date_to']);
            $monthStart = new DateTime($firstDay);
            $monthEnd = new DateTime($lastDay);
            
            // Get the overlap period
            $actualStart = max($start, $monthStart);
            $actualEnd = min($end, $monthEnd);
            
            // Generate all dates in the sick note period
            $current = clone $actualStart;
            while ($current <= $actualEnd) {
                $dateStr = $current->format('Y-m-d');
                $dayOfWeek = $current->format('N');
                // Only count weekdays
                if ($dayOfWeek < 6 && !in_array($dateStr, $sickDates)) {
                    $sickDates[] = $dateStr;
                }
                $current->modify('+1 day');
            }
        }
        $stmt->close();
        
        // Combine all attendance (regular + manual, excluding duplicates)
        $allAttendanceDates = array_unique(array_merge($clockingDates, $manualDates));
        
        // Check if learner has ANY actual attendance
        $hasAnyAttendance = count($allAttendanceDates) > 0;
        
        // Count present days
        $actualPresentDays = 0;
        $sickNoteDays = 0;
        
        foreach ($dates as $date) {
            if (isset($publicHolidaysInRange[$date])) {
                // Public holiday - count as present only if learner has any attendance
                if ($hasAnyAttendance) {
                    $actualPresentDays++;
                }
            } elseif (in_array($date, $allAttendanceDates)) {
                // Regular or manual attendance
                $actualPresentDays++;
            } elseif (in_array($date, $sickDates)) {
                // Sick note (only count if not already counted as attendance)
                $sickNoteDays++;
            }
        }
        
        $totalDaysAttended = $actualPresentDays + $sickNoteDays;
        $attendancePercent = $totalWorkingDays > 0 ? round(($totalDaysAttended / $totalWorkingDays) * 100, 1) : 0;
        
        // Calculate amount due based on overall_old.php logic
        $perfectAttendanceAmount = 2000.00;
        $dailyRate = $totalWorkingDays > 0 ? ($perfectAttendanceAmount / $totalWorkingDays) : 0;
        
        // If 100% attendance, give full R2000, otherwise calculate based on days attended
        if ($attendancePercent == 100) {
            $amountDue = $perfectAttendanceAmount;
        } else {
            $amountDue = $totalDaysAttended * $dailyRate;
        }
        
        $results[] = [
            'LearnerID' => $learner['LearnerID'],
            'Name' => $learner['Name'],
            'Surname' => $learner['Surname'],
            'classID' => $learner['classID'],
            'days_clocked' => count($clockingDates),
            'manual_days_clocked' => count($manualDates),
            'sick_note_days' => $sickNoteDays,
            'total_days_attended' => $totalDaysAttended,
            'total_working_days' => $totalWorkingDays,
            'attendance_percentage' => $attendancePercent,
            'daily_rate' => round($dailyRate, 2),
            'amount_due' => round($amountDue, 2)
        ];
    }
    
    // Sort results by surname and name
    usort($results, function($a, $b) {
        $surnameCompare = strcmp($a['Surname'], $b['Surname']);
        if ($surnameCompare !== 0) return $surnameCompare;
        return strcmp($a['Name'], $b['Name']);
    });
    
    // Return results
    echo json_encode([
        'success' => true,
        'month' => $month,
        'classID' => $classID,
        'total_working_days' => $totalWorkingDays,
        'data' => $results
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'line' => $e->getLine()
    ]);
} catch (Error $e) {
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'line' => $e->getLine()
    ]);
}
?>
