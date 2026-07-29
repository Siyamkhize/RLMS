<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

include('connection.php');

echo "<h2>Add unitStandard Column and Fix Existing Data</h2>";

// Check if connection is successful
if ($conn->connect_error) {
    echo "<p style='color: red;'>Connection failed: " . htmlspecialchars($conn->connect_error) . "</p>";
    exit;
}

echo "<p>Connected to database successfully.</p>";

// Step 1: Check if unitStandard column exists
echo "<h3>Step 1: Checking if unitStandard column exists...</h3>";
$checkColumnQuery = "SHOW COLUMNS FROM poe LIKE 'unitStandard'";
$columnResult = $conn->query($checkColumnQuery);

if ($columnResult && $columnResult->num_rows > 0) {
    echo "<p style='color: green;'>✅ unitStandard column already exists.</p>";
} else {
    echo "<p style='color: orange;'>⚠️ unitStandard column does not exist. Adding it now...</p>";
    
    // Add the unitStandard column
    $addColumnQuery = "ALTER TABLE poe ADD COLUMN unitStandard TEXT NULL AFTER type";
    if ($conn->query($addColumnQuery)) {
        echo "<p style='color: green;'>✅ Successfully added unitStandard column to POE table.</p>";
    } else {
        echo "<p style='color: red;'>❌ Error adding unitStandard column: " . htmlspecialchars($conn->error) . "</p>";
        $conn->close();
        exit;
    }
}

// Function to extract unit standard from exercise name
function extractUnitStandardFromExercise($exercise) {
    // Pattern 1: "All Questions - 9964 - Apply health and safety to a work area"
    if (preg_match('/All\s+Questions\s*-\s*(\d{4,10})\s*-\s*(.+)/', $exercise, $matches)) {
        $unitId = $matches[1];
        $unitName = trim($matches[2]);
        return "$unitId - $unitName";
    }
    
    // Pattern 2: "All Formative Questions - 9964"
    if (preg_match('/All\s+\w+\s+Questions\s*-\s*(\d{4,10})/', $exercise, $matches)) {
        $unitId = $matches[1];
        return getUnitStandardName($unitId);
    }
    
    // Pattern 3: "All Questions - 9964"
    if (preg_match('/All\s+Questions\s*-\s*(\d{4,10})/', $exercise, $matches)) {
        $unitId = $matches[1];
        return getUnitStandardName($unitId);
    }
    
    // Pattern 4: Individual questions that might contain unit standard ID
    // Look for 4-5 digit numbers that match known unit standards
    if (preg_match('/\b(9964|9965|9962|9968|14580|14555|13958|9986|9966|14336)\b/', $exercise, $matches)) {
        $unitId = $matches[1];
        return getUnitStandardName($unitId);
    }
    
    // Pattern 5: Check if exercise matches known question patterns
    $questionPatterns = [
        // 9964 patterns
        '/define.*safe.*site/i' => '9964',
        '/hazards?/i' => '9964',
        '/safety.*hazards?/i' => '9964',
        '/ppe.*supplied/i' => '9964',
        '/fire.*extinguisher/i' => '9964',
        '/health.*safety.*plan/i' => '9964',
        '/workman.*compensation/i' => '9964',
        '/ohs.*act/i' => '9964',
        '/incidents.*report/i' => '9964',
        '/unsafe.*conditions/i' => '9964',
        '/people.*covered.*act/i' => '9964',
        '/regulations.*minister/i' => '9964',
        '/medical.*practioner/i' => '9964',
        
        // 9965 patterns
        '/first.*aid/i' => '9965',
        '/render.*basic.*first.*aid/i' => '9965',
        
        // 9962 patterns
        '/calculate.*construction.*quantities/i' => '9962',
        '/work.*plan/i' => '9962',
        '/production.*rate/i' => '9962',
        '/resources.*consider/i' => '9962',
        '/square.*meters.*brickwork/i' => '9962',
        '/volume.*box/i' => '9962',
        '/percentage/i' => '9962',
        '/quotation.*cement.*bricks/i' => '9962',
        '/units.*measure/i' => '9962',
        '/formula.*calculating/i' => '9962',
        
        // 9968 patterns
        '/procure.*materials/i' => '9968',
        '/tools.*equipment/i' => '9968',
        
        // 14580 patterns
        '/construction.*drawings/i' => '14580',
        '/interpret.*drawings/i' => '14580',
        '/specifications/i' => '14580',
        '/scale.*1:1/i' => '14580',
    ];
    
    foreach ($questionPatterns as $pattern => $unitId) {
        if (preg_match($pattern, $exercise)) {
            return getUnitStandardName($unitId);
        }
    }
    
    return null;
}

// Function to get unit standard name from database
function getUnitStandardName($unitId) {
    global $conn;
    
    // Try to get from unitstandard table
    $query = "SELECT name FROM unitstandard WHERE id = ?";
    $stmt = $conn->prepare($query);
    if ($stmt) {
        $stmt->bind_param('i', $unitId);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($row = $result->fetch_assoc()) {
            return "$unitId - " . $row['name'];
        }
    }
    
    // Fallback to comprehensive unit standards mapping
    $commonUnits = [
        '9964' => '9964 - Apply health and safety procedures',
        '9965' => '9965 - Render basic first aid',
        '9962' => '9962 - Calculate construction quantities to develop a work plan',
        '9968' => '9968 - Procure materials, tools and equipment',
        '14580' => '14580 - Read and interpret construction drawings and specifications',
        '14555' => '14555 - Perform basic construction calculations',
        '13958' => '13958 - Demonstrate knowledge of construction materials',
        '9986' => '9986 - Apply construction technology',
        '9966' => '9966 - Demonstrate knowledge of construction processes',
        '14336' => '14336 - Apply construction quality control'
    ];
    
    return $commonUnits[$unitId] ?? "$unitId - Unit Standard";
}

// Step 2: Get all POE records with NULL or empty unitStandard and join with assessments
echo "<h3>Step 2: Finding records to update using assessments table join...</h3>";

// First, let's see what we're working with
$countQuery = "SELECT COUNT(*) as total FROM poe WHERE unitStandard IS NULL OR unitStandard = ''";
$countResult = $conn->query($countQuery);
$totalRecords = $countResult->fetch_assoc()['total'];
echo "<p>Total POE records with missing unit standards: $totalRecords</p>";

// Join POE with assessments to get proper unit standard information
$query = "
    SELECT DISTINCT
        p.poe_id,
        p.learnerID,
        p.exercise,
        p.type,
        p.unitStandard as current_unit_standard,
        a.unit_standard_id,
        us.name as unit_standard_name,
        CONCAT(a.unit_standard_id, ' - ', COALESCE(us.name, 'Unit Standard')) as new_unit_standard
    FROM poe p
    LEFT JOIN assessments a ON (
        p.exercise = a.exercise 
        AND p.type = CASE 
            WHEN a.question_type = 'Practical' THEN 'LogBook'
            WHEN a.assessment_type = 'FormativeRemedial' THEN 'FormativeRemedial'
            WHEN a.assessment_type = 'SummativeRemedial' THEN 'SummativeRemedial'
            ELSE a.assessment_type 
        END
    )
    LEFT JOIN unitstandard us ON a.unit_standard_id = us.id
    WHERE (p.unitStandard IS NULL OR p.unitStandard = '')
    AND a.unit_standard_id IS NOT NULL
    ORDER BY p.submitted_at DESC
";

$result = $conn->query($query);

if (!$result) {
    echo "<p style='color: red;'>Error executing join query: " . htmlspecialchars($conn->error) . "</p>";
    
    // Fallback: try a simpler approach for bulk uploads
    echo "<h4>Trying fallback approach for bulk uploads...</h4>";
    $fallbackQuery = "
        SELECT 
            poe_id,
            learnerID,
            exercise,
            type,
            unitStandard as current_unit_standard
        FROM poe 
        WHERE (unitStandard IS NULL OR unitStandard = '')
        AND exercise LIKE 'All%Questions%'
        ORDER BY submitted_at DESC
    ";
    
    $result = $conn->query($fallbackQuery);
    if (!$result) {
        echo "<p style='color: red;'>Fallback query also failed: " . htmlspecialchars($conn->error) . "</p>";
        $conn->close();
        exit;
    }
}

$recordsToUpdate = [];
$joinMatches = [];

while ($row = $result->fetch_assoc()) {
    // For joined results, we have the unit standard from assessments table
    if (isset($row['new_unit_standard']) && !empty($row['new_unit_standard'])) {
        $recordsToUpdate[] = [
            'id' => $row['poe_id'],
            'exercise' => $row['exercise'],
            'current_unit_standard' => $row['current_unit_standard'] ?? 'NULL',
            'new_unit_standard' => $row['new_unit_standard'],
            'learner_id' => $row['learnerID'],
            'type' => $row['type'],
            'unit_standard_id' => $row['unit_standard_id'],
            'method' => 'JOIN'
        ];
        
        $joinMatches[$row['unit_standard_id']] = $row['new_unit_standard'];
    } else {
        // Fallback to pattern matching for bulk uploads
        $unitStandard = extractUnitStandardFromExercise($row['exercise']);
        if ($unitStandard) {
            $recordsToUpdate[] = [
                'id' => $row['poe_id'],
                'exercise' => $row['exercise'],
                'current_unit_standard' => $row['current_unit_standard'] ?? 'NULL',
                'new_unit_standard' => $unitStandard,
                'learner_id' => $row['learnerID'],
                'type' => $row['type'],
                'unit_standard_id' => 'PATTERN',
                'method' => 'PATTERN'
            ];
        }
    }
}

echo "<h3>Records to Update: " . count($recordsToUpdate) . "</h3>";

// Show join matching summary
if (!empty($joinMatches)) {
    echo "<h4>Unit Standards Found via Database Join:</h4>";
    echo "<table border='1' style='border-collapse: collapse; width: 100%;'>";
    echo "<tr><th>Unit Standard ID</th><th>Full Unit Standard Name</th></tr>";
    foreach ($joinMatches as $unitId => $unitStandard) {
        echo "<tr>";
        echo "<td>" . htmlspecialchars($unitId) . "</td>";
        echo "<td>" . htmlspecialchars($unitStandard) . "</td>";
        echo "</tr>";
    }
    echo "</table><br>";
}

// Show method breakdown
$joinCount = count(array_filter($recordsToUpdate, function($r) { return $r['method'] === 'JOIN'; }));
$patternCount = count(array_filter($recordsToUpdate, function($r) { return $r['method'] === 'PATTERN'; }));

echo "<h4>Update Method Breakdown:</h4>";
echo "<p>✅ Records matched via database JOIN: $joinCount</p>";
echo "<p>⚠️ Records matched via pattern matching: $patternCount</p>";

// Step 3: Update the records
if (!empty($recordsToUpdate)) {
    echo "<h3>Step 3: Updating records...</h3>";
    echo "<table border='1' style='border-collapse: collapse; width: 100%;'>";
    echo "<tr><th>ID</th><th>Learner ID</th><th>Type</th><th>Exercise</th><th>Current Unit Standard</th><th>New Unit Standard</th><th>Method</th><th>Status</th></tr>";
    
    $updateCount = 0;
    $errorCount = 0;
    
    foreach ($recordsToUpdate as $record) {
        echo "<tr>";
        echo "<td>" . htmlspecialchars($record['id']) . "</td>";
        echo "<td>" . htmlspecialchars($record['learner_id']) . "</td>";
        echo "<td>" . htmlspecialchars($record['type']) . "</td>";
        echo "<td>" . htmlspecialchars(substr($record['exercise'], 0, 60)) . "...</td>";
        echo "<td>" . htmlspecialchars($record['current_unit_standard']) . "</td>";
        echo "<td>" . htmlspecialchars($record['new_unit_standard']) . "</td>";
        echo "<td>" . htmlspecialchars($record['method']) . "</td>";
        
        // Update the record
        $updateQuery = "UPDATE poe SET unitStandard = ? WHERE poe_id = ?";
        $updateStmt = $conn->prepare($updateQuery);
        $updateStmt->bind_param('si', $record['new_unit_standard'], $record['id']);
        
        if ($updateStmt->execute()) {
            echo "<td style='color: green;'>✅ UPDATED</td>";
            $updateCount++;
        } else {
            echo "<td style='color: red;'>❌ ERROR: " . htmlspecialchars($updateStmt->error) . "</td>";
            $errorCount++;
        }
        
        echo "</tr>";
    }
    
    echo "</table>";
    
    echo "<h3>Summary:</h3>";
    echo "<p>✅ Successfully updated: $updateCount records</p>";
    echo "<p>❌ Errors: $errorCount records</p>";
    
    if ($updateCount > 0) {
        echo "<div style='background: #d4edda; border: 1px solid #c3e6cb; padding: 10px; margin: 10px 0;'>";
        echo "<h4>✅ Fix Applied Successfully!</h4>";
        echo "<p>The POE table has been updated with:</p>";
        echo "<ul>";
        echo "<li>✅ Added unitStandard column to the table</li>";
        echo "<li>✅ Updated $updateCount existing records with proper unit standard information</li>";
        echo "</ul>";
        echo "<p><strong>Next steps:</strong></p>";
        echo "<ul>";
        echo "<li>The Flutter app should now be able to match uploaded questions correctly</li>";
        echo "<li>Questions that were uploaded should now show as completed with green checkmarks</li>";
        echo "<li>Test the app to verify the fix is working</li>";
        echo "<li>Future uploads will automatically include unit standard information</li>";
        echo "</ul>";
        echo "</div>";
    }
} else {
    echo "<p>No records found that need updating.</p>";
}

$conn->close();
?>