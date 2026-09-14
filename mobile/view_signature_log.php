<?php
/**
 * LIGHTWEIGHT SIGNATURE CHANGE VIEWER
 * Shows which PHP endpoint removed/changed signature data
 * Auto-refreshes every 10 seconds
 */

include 'connection.php';
header('Content-Type: text/html; charset=utf-8');

$autoRefresh = isset($_GET['refresh']) ? $_GET['refresh'] : 10;
$limit = isset($_GET['limit']) ? intval($_GET['limit']) : 50;

?>
<!DOCTYPE html>
<html>
<head>
    <title>Signature Change Tracker</title>
    <meta http-equiv="refresh" content="<?php echo $autoRefresh; ?>">
    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .header {
            background: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            margin: 0 0 10px 0;
            color: #333;
        }
        .stats {
            display: flex;
            gap: 20px;
            margin-top: 15px;
        }
        .stat-box {
            background: #f8f9fa;
            padding: 10px 15px;
            border-radius: 5px;
            border-left: 4px solid #007bff;
        }
        .stat-label {
            font-size: 12px;
            color: #666;
            text-transform: uppercase;
        }
        .stat-value {
            font-size: 24px;
            font-weight: bold;
            color: #333;
        }
        table {
            width: 100%;
            background: white;
            border-collapse: collapse;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        th {
            background: #343a40;
            color: white;
            padding: 12px;
            text-align: left;
            font-weight: 600;
            font-size: 13px;
            text-transform: uppercase;
        }
        td {
            padding: 10px 12px;
            border-bottom: 1px solid #dee2e6;
            font-size: 14px;
        }
        tr:hover {
            background: #f8f9fa;
        }
        .removed {
            background: #f8d7da !important;
            font-weight: bold;
        }
        .added {
            background: #d4edda !important;
        }
        .changed {
            background: #fff3cd !important;
        }
        .script-name {
            font-weight: bold;
            color: #dc3545;
            font-family: monospace;
        }
        .value {
            font-family: monospace;
            font-size: 12px;
            max-width: 300px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        .empty {
            color: #999;
            font-style: italic;
        }
        .field {
            padding: 3px 8px;
            border-radius: 3px;
            font-size: 11px;
            font-weight: bold;
            display: inline-block;
        }
        .field-signature { background: #e7f3ff; color: #0056b3; }
        .field-witness { background: #fff3cd; color: #856404; }
        .field-initials { background: #d4edda; color: #155724; }
        .field-profile { background: #f8d7da; color: #721c24; }
        .controls {
            background: white;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .controls a {
            padding: 8px 15px;
            background: #007bff;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            margin-right: 10px;
            font-size: 13px;
        }
        .controls a:hover {
            background: #0056b3;
        }
        .timestamp {
            color: #666;
            font-size: 12px;
        }
        .no-data {
            text-align: center;
            padding: 40px;
            color: #999;
            font-size: 16px;
        }
    </style>
</head>
<body>

<div class="header">
    <h1>🔍 Signature Change Tracker</h1>
    <p style="margin: 5px 0; color: #666;">Shows which PHP endpoint caused signature/initials data changes</p>
    <div class="stats">
        <?php
        // Get total changes count
        $totalResult = $conn->query("SELECT COUNT(*) as total FROM signature_change_log");
        $total = $totalResult ? $totalResult->fetch_assoc()['total'] : 0;
        
        // Get removals count (when new_value is NULL or empty)
        $removalsResult = $conn->query("SELECT COUNT(*) as removals FROM signature_change_log WHERE new_value IS NULL OR new_value = ''");
        $removals = $removalsResult ? $removalsResult->fetch_assoc()['removals'] : 0;
        
        // Get last change timestamp
        $lastChangeResult = $conn->query("SELECT MAX(change_timestamp) as last_change FROM signature_change_log");
        $lastChange = $lastChangeResult ? $lastChangeResult->fetch_assoc()['last_change'] : 'Never';
        ?>
        <div class="stat-box">
            <div class="stat-label">Total Changes</div>
            <div class="stat-value"><?php echo $total; ?></div>
        </div>
        <div class="stat-box" style="border-left-color: #dc3545;">
            <div class="stat-label">Data Removals</div>
            <div class="stat-value" style="color: #dc3545;"><?php echo $removals; ?></div>
        </div>
        <div class="stat-box" style="border-left-color: #28a745;">
            <div class="stat-label">Last Change</div>
            <div class="stat-value" style="font-size: 14px;"><?php echo $lastChange ? date('H:i:s', strtotime($lastChange)) : 'Never'; ?></div>
        </div>
    </div>
</div>

<div class="controls">
    <a href="?refresh=5&limit=<?php echo $limit; ?>">⚡ 5s Refresh</a>
    <a href="?refresh=10&limit=<?php echo $limit; ?>">🔄 10s Refresh</a>
    <a href="?refresh=30&limit=<?php echo $limit; ?>">⏱️ 30s Refresh</a>
    <a href="?refresh=0&limit=<?php echo $limit; ?>">⏸️ No Refresh</a>
    <span style="margin: 0 20px; color: #999;">|</span>
    <a href="?refresh=<?php echo $autoRefresh; ?>&limit=20">20 rows</a>
    <a href="?refresh=<?php echo $autoRefresh; ?>&limit=50">50 rows</a>
    <a href="?refresh=<?php echo $autoRefresh; ?>&limit=100">100 rows</a>
</div>

<?php
// Get recent changes with learner details
$query = "
SELECT 
    scl.*,
    ld.IDNumber,
    ld.Name,
    ld.Surname
FROM signature_change_log scl
LEFT JOIN learnerdetails ld ON scl.learner_id = ld.LearnerID
ORDER BY scl.change_timestamp DESC
LIMIT ?
";

$stmt = $conn->prepare($query);
$stmt->bind_param('i', $limit);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    echo "<table>";
    echo "<thead><tr>";
    echo "<th>Time</th>";
    echo "<th>Learner</th>";
    echo "<th>Field</th>";
    echo "<th>Old Value</th>";
    echo "<th>New Value</th>";
    echo "<th>⚠️ PHP Script (Culprit)</th>";
    echo "</tr></thead>";
    echo "<tbody>";
    
    while ($row = $result->fetch_assoc()) {
        // Determine row class based on change type
        $rowClass = '';
        if (empty($row['new_value']) && !empty($row['old_value'])) {
            $rowClass = 'removed'; // Data was removed
        } elseif (empty($row['old_value']) && !empty($row['new_value'])) {
            $rowClass = 'added'; // Data was added
        } else {
            $rowClass = 'changed'; // Data was changed
        }
        
        echo "<tr class='$rowClass'>";
        
        // Timestamp
        echo "<td class='timestamp'>" . date('Y-m-d H:i:s', strtotime($row['change_timestamp'])) . "</td>";
        
        // Learner info
        $learnerName = $row['Name'] . ' ' . $row['Surname'];
        $learnerID = $row['IDNumber'] ?: 'ID: ' . $row['learner_id'];
        echo "<td><strong>$learnerName</strong><br><small>$learnerID</small></td>";
        
        // Field with color coding
        $fieldClass = '';
        if (strpos($row['field_name'], 'signature') !== false && strpos($row['field_name'], 'witness') === false) {
            $fieldClass = 'field-signature';
        } elseif (strpos($row['field_name'], 'witness') !== false) {
            $fieldClass = 'field-witness';
        } elseif (strpos($row['field_name'], 'initials') !== false) {
            $fieldClass = 'field-initials';
        } elseif (strpos($row['field_name'], 'profile') !== false) {
            $fieldClass = 'field-profile';
        }
        echo "<td><span class='field $fieldClass'>" . htmlspecialchars($row['field_name']) . "</span></td>";
        
        // Old value
        $oldValue = $row['old_value'];
        if (empty($oldValue)) {
            echo "<td class='value empty'>(empty)</td>";
        } else {
            echo "<td class='value'>" . htmlspecialchars($oldValue) . "</td>";
        }
        
        // New value
        $newValue = $row['new_value'];
        if (empty($newValue)) {
            echo "<td class='value empty'>(REMOVED)</td>";
        } else {
            echo "<td class='value'>" . htmlspecialchars($newValue) . "</td>";
        }
        
        // PHP script (the culprit!)
        $script = $row['php_script'] ?: 'unknown';
        echo "<td class='script-name'>" . htmlspecialchars($script) . "</td>";
        
        echo "</tr>";
    }
    
    echo "</tbody></table>";
} else {
    echo "<div class='no-data'>";
    echo "<p><strong>📭 No changes recorded yet</strong></p>";
    echo "<p>The tracker is active. Changes will appear here automatically.</p>";
    echo "</div>";
}

$stmt->close();
$conn->close();
?>

<div style="margin-top: 20px; padding: 15px; background: white; border-radius: 8px; font-size: 12px; color: #666;">
    <strong>Legend:</strong>
    <span style="background: #f8d7da; padding: 3px 8px; margin: 0 5px;">Red = Data Removed</span>
    <span style="background: #d4edda; padding: 3px 8px; margin: 0 5px;">Green = Data Added</span>
    <span style="background: #fff3cd; padding: 3px 8px; margin: 0 5px;">Yellow = Data Changed</span>
</div>

</body>
</html>
