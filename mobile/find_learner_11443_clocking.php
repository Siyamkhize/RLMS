<?php
/**
 * Comprehensive Search for Learner 11443 Clocking Records
 * Searches all possible tables and databases
 */

require_once __DIR__ . '/../connection.php';
header('Content-Type: text/plain; charset=UTF-8');

echo "=== COMPREHENSIVE CLOCKING SEARCH ===\n";
echo "Learner ID: 11443\n";
echo "Search Date: 2026-09-11\n";
echo "Current Time: " . date('Y-m-d H:i:s') . "\n\n";

// 1. Check learner_clocking table (main table)
echo "--- TABLE: learner_clocking ---\n";
$sql1 = "SELECT * FROM learner_clocking WHERE LearnerID = 11443 ORDER BY clock_in_time DESC LIMIT 5";
$result1 = $conn->query($sql1);
if ($result1 && $result1->num_rows > 0) {
    echo "✓ Found {$result1->num_rows} record(s):\n";
    while ($row = $result1->fetch_assoc()) {
        echo "\n";
        foreach ($row as $key => $value) {
            echo "  $key: " . ($value ?? '(null)') . "\n";
        }
    }
} else {
    echo "✗ NO RECORDS\n";
}

// 2. Check if there's a 'clocking' table
echo "\n--- TABLE: clocking (if exists) ---\n";
$check_clocking = $conn->query("SHOW TABLES LIKE 'clocking'");
if ($check_clocking && $check_clocking->num_rows > 0) {
    $sql2 = "SELECT * FROM clocking WHERE learner_id = 11443 ORDER BY clock_in_time DESC LIMIT 5";
    $result2 = $conn->query($sql2);
    if ($result2 && $result2->num_rows > 0) {
        echo "✓ Found {$result2->num_rows} record(s):\n";
        while ($row = $result2->fetch_assoc()) {
            echo "\n";
            foreach ($row as $key => $value) {
                echo "  $key: " . ($value ?? '(null)') . "\n";
            }
        }
    } else {
        echo "✗ NO RECORDS\n";
    }
} else {
    echo "✗ Table does not exist\n";
}

// 3. Check attendance table
echo "\n--- TABLE: attendance ---\n";
$check_attendance = $conn->query("SHOW TABLES LIKE 'attendance'");
if ($check_attendance && $check_attendance->num_rows > 0) {
    $sql3 = "SELECT * FROM attendance WHERE LearnerID = 11443 AND AttendanceDate = '2026-09-11' LIMIT 5";
    $result3 = $conn->query($sql3);
    if ($result3 && $result3->num_rows > 0) {
        echo "✓ Found {$result3->num_rows} record(s):\n";
        while ($row = $result3->fetch_assoc()) {
            echo "\n";
            foreach ($row as $key => $value) {
                echo "  $key: " . ($value ?? '(null)') . "\n";
            }
        }
    } else {
        echo "✗ NO RECORDS for 2026-09-11\n";
    }
} else {
    echo "✗ Table does not exist\n";
}

// 4. Check ALL dates for this learner in learner_clocking
echo "\n--- ALL CLOCKING DATES FOR LEARNER 11443 ---\n";
$sql4 = "SELECT DATE(clock_date) as date, COUNT(*) as count FROM learner_clocking WHERE LearnerID = 11443 GROUP BY DATE(clock_date) ORDER BY date DESC LIMIT 10";
$result4 = $conn->query($sql4);
if ($result4 && $result4->num_rows > 0) {
    echo "Recent clocking dates:\n";
    while ($row = $result4->fetch_assoc()) {
        echo "  {$row['date']}: {$row['count']} record(s)\n";
    }
} else {
    echo "✗ No clocking records found for this learner at all\n";
}

// 5. Check if learner exists
echo "\n--- LEARNER VERIFICATION ---\n";
$sql5 = "SELECT LearnerID, Name, Surname, IDNumber FROM learners WHERE LearnerID = 11443";
$result5 = $conn->query($sql5);
if ($result5 && $result5->num_rows > 0) {
    $learner = $result5->fetch_assoc();
    echo "✓ Learner exists:\n";
    echo "  Name: {$learner['Name']} {$learner['Surname']}\n";
    echo "  ID Number: {$learner['IDNumber']}\n";
} else {
    echo "✗ Learner NOT FOUND in database!\n";
}

// 6. Show all tables that might contain clocking data
echo "\n--- AVAILABLE CLOCKING-RELATED TABLES ---\n";
$sql6 = "SHOW TABLES LIKE '%clock%'";
$result6 = $conn->query($sql6);
if ($result6 && $result6->num_rows > 0) {
    while ($row = $result6->fetch_array()) {
        echo "  - {$row[0]}\n";
    }
} else {
    echo "  (none found)\n";
}

$conn->close();
?>
