<?php
// View all facilitator data from server database
include 'connection.php';

header('Content-Type: text/html; charset=utf-8');

echo "<!DOCTYPE html>";
echo "<html><head>";
echo "<meta charset='UTF-8'>";
echo "<title>All Facilitator Data</title>";
echo "<style>
body { 
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
    margin: 0;
    padding: 20px;
    background-color: #f5f5f5;
}
.container {
    max-width: 100%;
    background: white;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}
h1 { 
    color: #2c3e50;
    border-bottom: 3px solid #3498db;
    padding-bottom: 10px;
}
.summary {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 20px;
    border-radius: 8px;
    margin: 20px 0;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 15px;
}
.summary-item {
    background: rgba(255,255,255,0.1);
    padding: 15px;
    border-radius: 6px;
}
.summary-item h3 {
    margin: 0 0 5px 0;
    font-size: 14px;
    opacity: 0.9;
}
.summary-item p {
    margin: 0;
    font-size: 24px;
    font-weight: bold;
}
table { 
    border-collapse: collapse; 
    width: 100%; 
    margin-top: 20px;
    background: white;
}
th, td { 
    border: 1px solid #ddd; 
    padding: 12px; 
    text-align: left;
    font-size: 13px;
}
th { 
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    font-weight: 600;
    position: sticky;
    top: 0;
    z-index: 10;
}
tr:nth-child(even) { 
    background-color: #f8f9fa; 
}
tr:hover {
    background-color: #e9ecef;
    cursor: pointer;
}
.null { 
    color: #999; 
    font-style: italic;
    background-color: #fff3cd;
    padding: 2px 6px;
    border-radius: 3px;
}
.empty { 
    color: #d63031; 
    font-weight: bold;
    background-color: #ffe0e0;
    padding: 2px 6px;
    border-radius: 3px;
}
.value { 
    color: #2d3436; 
}
.truncated {
    max-width: 200px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}
.badge {
    display: inline-block;
    padding: 3px 8px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
}
.badge-success { background-color: #d4edda; color: #155724; }
.badge-warning { background-color: #fff3cd; color: #856404; }
.badge-danger { background-color: #f8d7da; color: #721c24; }
.detail-row {
    display: none;
    background-color: #f8f9fa;
}
.detail-row td {
    padding: 20px;
}
.detail-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 15px;
}
.detail-field {
    background: white;
    padding: 12px;
    border-radius: 6px;
    border-left: 3px solid #667eea;
}
.detail-field strong {
    display: block;
    color: #667eea;
    margin-bottom: 5px;
    font-size: 12px;
    text-transform: uppercase;
}
.json-export {
    background: #2d3436;
    color: #00b894;
    padding: 15px;
    border-radius: 6px;
    margin: 20px 0;
    overflow-x: auto;
    font-family: 'Courier New', monospace;
    font-size: 12px;
}
.btn {
    padding: 10px 20px;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-weight: 600;
    margin: 5px;
    text-decoration: none;
    display: inline-block;
}
.btn-primary {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
}
.btn-success {
    background: linear-gradient(135deg, #84fab0 0%, #8fd3f4 100%);
    color: #2d3436;
}
</style>
<script>
function toggleDetails(id) {
    const row = document.getElementById('detail-' + id);
    if (row.style.display === 'table-row') {
        row.style.display = 'none';
    } else {
        row.style.display = 'table-row';
    }
}
function copyJSON() {
    const jsonData = document.getElementById('json-data').textContent;
    navigator.clipboard.writeText(jsonData).then(() => {
        alert('JSON copied to clipboard!');
    });
}
</script>
</head><body>";

echo "<div class='container'>";
echo "<h1>📊 All Facilitator Data - Server Database</h1>";

try {
    // Get total count
    $countStmt = $conn->prepare("SELECT COUNT(*) as total FROM facilitator");
    $countStmt->execute();
    $totalCount = $countStmt->get_result()->fetch_assoc()['total'];
    
    // Get counts by status
    $activeCount = 0;
    $withFingerprints = 0;
    $withPasswords = 0;
    
    // Query all facilitator data
    $stmt = $conn->prepare("SELECT * FROM facilitator ORDER BY facilitator_id");
    $stmt->execute();
    $result = $stmt->get_result();

    $facilitators = [];
    while ($row = $result->fetch_assoc()) {
        $facilitators[] = $row;
        
        // Count stats
        if (!empty($row['email'])) $activeCount++;
        if (!empty($row['zkteco_left_template']) || !empty($row['zkteco_right_template']) || 
            !empty($row['futronic_left_template']) || !empty($row['futronic_right_template'])) {
            $withFingerprints++;
        }
        if (!empty($row['password'])) $withPasswords++;
    }

    // Display summary
    echo "<div class='summary'>";
    echo "<div class='summary-item'><h3>Total Facilitators</h3><p>$totalCount</p></div>";
    echo "<div class='summary-item'><h3>With Email</h3><p>$activeCount</p></div>";
    echo "<div class='summary-item'><h3>With Password</h3><p>$withPasswords</p></div>";
    echo "<div class='summary-item'><h3>With Fingerprints</h3><p>$withFingerprints</p></div>";
    echo "</div>";

    // Export buttons
    echo "<div style='margin: 20px 0;'>";
    echo "<button class='btn btn-success' onclick='copyJSON()'>📋 Copy JSON</button>";
    echo "<a href='sync_facilitator.php' class='btn btn-primary' target='_blank'>🔄 View Sync Endpoint</a>";
    echo "</div>";

    if (count($facilitators) > 0) {
        // JSON Export
        echo "<details>";
        echo "<summary style='cursor: pointer; padding: 10px; background: #f8f9fa; border-radius: 6px; margin: 10px 0;'><strong>📄 JSON Export (Click to expand)</strong></summary>";
        echo "<div class='json-export'>";
        echo "<pre id='json-data'>" . htmlspecialchars(json_encode($facilitators, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)) . "</pre>";
        echo "</div>";
        echo "</details>";

        // Table view
        echo "<h2>Facilitator Records</h2>";
        echo "<table>";
        
        // Table header - simplified view
        echo "<tr>";
        echo "<th>ID</th>";
        echo "<th>Name</th>";
        echo "<th>Role</th>";
        echo "<th>Email</th>";
        echo "<th>Class ID</th>";
        echo "<th>Phone</th>";
        echo "<th>Status</th>";
        echo "<th>Actions</th>";
        echo "</tr>";
        
        // Table rows
        foreach ($facilitators as $facilitator) {
            $id = $facilitator['facilitator_id'];
            $fullName = trim(($facilitator['firstName'] ?? '') . ' ' . ($facilitator['lastName'] ?? ''));
            $hasPassword = !empty($facilitator['password']);
            $hasFingerprints = !empty($facilitator['zkteco_left_template']) || !empty($facilitator['zkteco_right_template']) || 
                               !empty($facilitator['futronic_left_template']) || !empty($facilitator['futronic_right_template']);
            
            echo "<tr onclick='toggleDetails($id)' style='cursor: pointer;'>";
            echo "<td><strong>$id</strong></td>";
            echo "<td>" . htmlspecialchars($fullName) . "</td>";
            echo "<td>" . htmlspecialchars($facilitator['role'] ?? '') . "</td>";
            echo "<td>" . htmlspecialchars($facilitator['email'] ?? '') . "</td>";
            echo "<td>" . htmlspecialchars($facilitator['classID'] ?? '') . "</td>";
            echo "<td>" . htmlspecialchars($facilitator['phoneNumber'] ?? '') . "</td>";
            echo "<td>";
            if ($hasPassword) echo "<span class='badge badge-success'>Has Password</span> ";
            if ($hasFingerprints) echo "<span class='badge badge-success'>Has Fingerprints</span>";
            if (!$hasPassword && !$hasFingerprints) echo "<span class='badge badge-warning'>Incomplete</span>";
            echo "</td>";
            echo "<td><button class='btn btn-primary' style='padding: 5px 10px; font-size: 11px;' onclick='event.stopPropagation(); toggleDetails($id)'>View Details</button></td>";
            echo "</tr>";
            
            // Detail row
            echo "<tr id='detail-$id' class='detail-row'>";
            echo "<td colspan='8'>";
            echo "<div class='detail-grid'>";
            
            foreach ($facilitator as $key => $value) {
                echo "<div class='detail-field'>";
                echo "<strong>" . htmlspecialchars($key) . "</strong>";
                
                if ($value === null) {
                    echo "<span class='null'>NULL</span>";
                } elseif ($value === '') {
                    echo "<span class='empty'>(empty string)</span>";
                } else {
                    // Special handling for long fields
                    if (in_array($key, ['zkteco_left_template', 'zkteco_right_template', 'futronic_left_template', 'futronic_right_template'])) {
                        $len = strlen($value);
                        echo "<span class='value'>$len characters</span><br>";
                        echo "<small style='color: #666;'>" . htmlspecialchars(substr($value, 0, 100)) . "...</small>";
                    } elseif ($key === 'password') {
                        echo "<span class='value'>" . htmlspecialchars(substr($value, 0, 30)) . "... (" . strlen($value) . " chars)</span>";
                    } else {
                        echo "<span class='value'>" . htmlspecialchars($value) . "</span>";
                    }
                }
                
                echo "</div>";
            }
            
            echo "</div>";
            echo "</td>";
            echo "</tr>";
        }
        echo "</table>";

    } else {
        echo "<div style='padding: 40px; text-align: center; background: #fff3cd; border-radius: 8px; margin: 20px 0;'>";
        echo "<h2 style='color: #856404;'>⚠️ No facilitator records found</h2>";
        echo "<p>The facilitator table is empty.</p>";
        echo "</div>";
    }

    $stmt->close();
} catch (Exception $e) {
    echo "<div style='background-color: #f8d7da; color: #721c24; padding: 20px; border-radius: 8px; border-left: 4px solid #f5c6cb;'>";
    echo "<h2>❌ Error</h2>";
    echo "<p><strong>Message:</strong> " . htmlspecialchars($e->getMessage()) . "</p>";
    echo "</div>";
}

$conn->close();

echo "</div>";
echo "</body></html>";
?>

