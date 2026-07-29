<?php
/**
 * Verify Qualification ID and OFO Code Mapping
 * Shows the correct relationship between OFO codes and qualification IDs
 */

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: text/html; charset=utf-8');

// Check if connection.php exists
if (!file_exists('connection.php')) {
    die("<h1>Error</h1><p>connection.php file not found in: " . getcwd() . "</p>");
}

include('connection.php');

// Check if database connection was successful
if (!isset($conn) || !$conn) {
    die("<h1>Error</h1><p>Database connection failed!</p>");
}

echo "<html><head><title>Qualification-OFO Mapping Verification</title>";
echo "<style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #006341; }
    h2 { color: #0066cc; margin-top: 30px; }
    table { border-collapse: collapse; margin: 10px 0; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
    th { background-color: #006341; color: white; }
    .info { background-color: #f0f8ff; padding: 10px; margin: 10px 0; border-left: 4px solid #0066cc; }
    .success { color: green; font-weight: bold; }
    .warning { color: orange; font-weight: bold; }
</style></head><body>";

echo "<h1>🔍 Qualification ID and OFO Code Verification</h1>";

// ══════════════════════════════════════════════════════════════════════════════
// CHECK: What qualification_ids have unit standards?
// ══════════════════════════════════════════════════════════════════════════════
echo "<h2>📚 Qualification IDs with Unit Standards</h2>";

echo "<h3>Standard Unit Standards Table (for Bricklayer & Plumber):</h3>";

$sql = "
    SELECT 
        qualification_id,
        COUNT(*) as unit_standard_count,
        MIN(id) as first_unit_standard_id,
        MIN(unit_standard_name) as sample_name
    FROM  unitstandard
    GROUP BY qualification_id
    ORDER BY qualification_id
";

$result = $conn->query($sql);

if ($result && $result->num_rows > 0) {
    echo "<table>";
    echo "<tr><th>Qualification ID</th><th>Unit Standards Count</th><th>Sample Unit Standard</th><th>Sample Name</th></tr>";
    
    while ($row = $result->fetch_assoc()) {
        echo "<tr>";
        echo "<td><strong>{$row['qualification_id']}</strong></td>";
        echo "<td>{$row['unit_standard_count']}</td>";
        echo "<td>{$row['first_unit_standard_id']}</td>";
        echo "<td>" . substr($row['sample_name'], 0, 60) . "...</td>";
        echo "</tr>";
    }
    echo "</table>";
} else {
    echo "<p>No unit standards found in database.</p>";
}

echo "<h3>Occupational Unit Standards Table (for Electrician):</h3>";

// Check if occupational_unit_standards table exists
$checkTable = $conn->query("SHOW TABLES LIKE 'occupational_unit_standards'");

if ($checkTable && $checkTable->num_rows > 0) {
    // First check what columns exist in this table
    $columnsCheck = $conn->query("SHOW COLUMNS FROM occupational_unit_standards LIKE '%unit%standard%'");
    $hasUnitStandardId = false;
    $hasId = false;
    
    if ($columnsCheck) {
        while ($col = $columnsCheck->fetch_assoc()) {
            if ($col['Field'] == 'unit_standard_id') {
                $hasUnitStandardId = true;
            }
            if ($col['Field'] == 'id') {
                $hasId = true;
            }
        }
    }
    
    // Choose the correct column name
    $idColumn = $hasUnitStandardId ? 'unit_standard_id' : 'id';
    
    $sql = "
        SELECT 
            qualification_id,
            COUNT(*) as unit_standard_count,
            MIN($idColumn) as first_unit_standard_id,
            MIN(unit_standard_name) as sample_name
        FROM occupational_unit_standards
        GROUP BY qualification_id
        ORDER BY qualification_id
    ";

    $result = $conn->query($sql);

    if ($result && $result->num_rows > 0) {
        echo "<table>";
        echo "<tr><th>Qualification ID</th><th>Unit Standards Count</th><th>Sample Unit Standard</th><th>Sample Name</th></tr>";
        
        while ($row = $result->fetch_assoc()) {
            echo "<tr>";
            echo "<td><strong>{$row['qualification_id']}</strong></td>";
            echo "<td>{$row['unit_standard_count']}</td>";
            echo "<td>{$row['first_unit_standard_id']}</td>";
            echo "<td>" . substr($row['sample_name'], 0, 60) . "...</td>";
            echo "</tr>";
        }
        echo "</table>";
    } else {
        echo "<p>No occupational unit standards found in database.</p>";
    }
} else {
    echo "<p class='warning'>Table 'occupational_unit_standards' does not exist.</p>";
}

// ══════════════════════════════════════════════════════════════════════════════
// CHECK: ARPL Access Recommendation Tables
// ══════════════════════════════════════════════════════════════════════════════
echo "<h2>🎯 ARPL Access Recommendation Table Data</h2>";

$tables = [
    'arplbricklayer_access_recommendation' => 'Bricklayer',
    'arplelectrician_access_recommendation' => 'Electrician',
    'arplplumber_access_recommendation' => 'Plumber'
];

echo "<table>";
echo "<tr><th>Table</th><th>Trade</th><th>Records</th><th>OFO Codes Found</th></tr>";

foreach ($tables as $table => $tradeName) {
    // Check if table exists
    $checkTable = $conn->query("SHOW TABLES LIKE '$table'");
    
    if ($checkTable && $checkTable->num_rows > 0) {
        // Get count
        $result = $conn->query("SELECT COUNT(*) as cnt FROM $table");
        $count = $result ? $result->fetch_assoc()['cnt'] : 0;
        
        // Get unique OFO codes
        $ofoResult = $conn->query("SELECT DISTINCT OFOCode FROM $table WHERE OFOCode IS NOT NULL AND OFOCode != ''");
        $ofoCodes = [];
        if ($ofoResult) {
            while ($row = $ofoResult->fetch_assoc()) {
                $ofoCodes[] = $row['OFOCode'];
            }
        }
        
        echo "<tr>";
        echo "<td>$table</td>";
        echo "<td>$tradeName</td>";
        echo "<td>$count</td>";
        echo "<td>" . (empty($ofoCodes) ? '<em>No OFO codes</em>' : implode(', ', $ofoCodes)) . "</td>";
        echo "</tr>";
    } else {
        echo "<tr>";
        echo "<td>$table</td>";
        echo "<td>$tradeName</td>";
        echo "<td colspan='2'><span class='warning'>Table does not exist</span></td>";
        echo "</tr>";
    }
}

echo "</table>";

// ══════════════════════════════════════════════════════════════════════════════
// RECOMMENDED MAPPING
// ══════════════════════════════════════════════════════════════════════════════
echo "<h2>✅ Recommended Configuration Based on Your Data</h2>";

echo "<div class='info'>";
echo "<h3>Trade Configuration:</h3>";
echo "<table>";
echo "<tr><th>Trade</th><th>OFO Code</th><th>Qualification ID</th><th>Unit Standards Available</th></tr>";

$trades = [
    ['name' => 'Bricklayer', 'ofo' => '641201', 'qual' => '65409'],
    ['name' => 'Electrician', 'ofo' => '671101', 'qual' => '91761'],
    ['name' => 'Plumber', 'ofo' => '642601', 'qual' => '65409']
];

foreach ($trades as $trade) {
    // Check correct table based on trade
    if ($trade['name'] === 'Electrician') {
        // Electrician uses occupational_unit_standards table
        $checkUS = $conn->query("SELECT COUNT(*) as cnt FROM occupational_unit_standards WHERE qualification_id = {$trade['qual']}");
    } else {
        // Bricklayer and Plumber use standard unitstandard table
        $checkUS = $conn->query("SELECT COUNT(*) as cnt FROM unitstandard WHERE qualification_id = {$trade['qual']}");
    }
    $usCount = $checkUS ? $checkUS->fetch_assoc()['cnt'] : 0;
    
    echo "<tr>";
    echo "<td><strong>{$trade['name']}</strong></td>";
    echo "<td>{$trade['ofo']}</td>";
    echo "<td>{$trade['qual']}</td>";
    echo "<td>" . ($usCount > 0 ? "<span class='success'>$usCount unit standards</span>" : "<span class='warning'>0 unit standards</span>") . "</td>";
    echo "</tr>";
}

echo "</table>";
echo "</div>";

// ══════════════════════════════════════════════════════════════════════════════
// SUMMARY
// ══════════════════════════════════════════════════════════════════════════════
echo "<h2>📋 Summary</h2>";

echo "<div class='info'>";
echo "<h3>Key Findings:</h3>";
echo "<ul>";
echo "<li><strong>Bricklayer:</strong> OFO 641201 → Qualification ID 65409 (uses <code>unitstandard</code> table)</li>";
echo "<li><strong>Electrician:</strong> OFO 671101 → Qualification ID 91761 (uses <code>occupational_unit_standards</code> table)</li>";
echo "<li><strong>Plumber:</strong> OFO 642601 → Qualification ID 65409 (uses <code>unitstandard</code> table, SAME as Bricklayer)</li>";
echo "</ul>";

echo "<p><strong>Important Notes:</strong></p>";
echo "<ul>";
echo "<li>Bricklayer and Plumber use the SAME qualification ID (65409), which means they share the same unit standards from the <code>unitstandard</code> table.</li>";
echo "<li>Electrician uses a different table (<code>occupational_unit_standards</code>) with qualification ID 91761.</li>";
echo "</ul>";
echo "</div>";

$conn->close();

echo "<hr>";
echo "<p style='color: #666; font-size: 12px;'>Generated: " . date('Y-m-d H:i:s') . "</p>";
echo "</body></html>";
?>
