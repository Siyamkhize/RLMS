<?php
// Verification tool to compare what server sends vs what should be in local DB
include 'connection.php';

header('Content-Type: text/html; charset=utf-8');

echo "<!DOCTYPE html><html><head><meta charset='UTF-8'>";
echo "<title>Sync Data Verification</title>";
echo "<style>
body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
.container { max-width: 1400px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
.alert { padding: 15px; border-radius: 6px; margin: 15px 0; }
.alert-info { background: #d1ecf1; border-left: 4px solid #0c5460; color: #0c5460; }
.alert-success { background: #d4edda; border-left: 4px solid #155724; color: #155724; }
.alert-danger { background: #f8d7da; border-left: 4px solid #721c24; color: #721c24; }
.compare-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin: 20px 0; }
.panel { background: #f8f9fa; padding: 15px; border-radius: 6px; border: 2px solid #dee2e6; }
.panel h3 { margin-top: 0; color: #495057; }
.field-row { display: grid; grid-template-columns: 200px 1fr; gap: 10px; padding: 8px; border-bottom: 1px solid #e9ecef; }
.field-row:hover { background: #e9ecef; }
.field-name { font-weight: bold; color: #495057; }
.field-value { font-family: monospace; }
.match { color: #28a745; }
.mismatch { color: #dc3545; font-weight: bold; }
.null-value { color: #6c757d; font-style: italic; }
.empty-value { color: #dc3545; background: #fff3cd; padding: 2px 6px; border-radius: 3px; }
code { background: #f8f9fa; padding: 2px 6px; border-radius: 3px; }
.instructions { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; margin: 20px 0; }
.instructions h2 { margin-top: 0; }
.instructions ol { margin: 10px 0; padding-left: 20px; }
.instructions li { margin: 8px 0; }
.step-box { background: rgba(255,255,255,0.1); padding: 10px; border-radius: 6px; margin: 10px 0; }
</style></head><body>";

echo "<div class='container'>";
echo "<h1>🔍 Facilitator Sync Verification</h1>";

echo "<div class='alert alert-info'>";
echo "<strong>Purpose:</strong> This tool shows what data the server will send during sync. ";
echo "After syncing, your offline/local database should have EXACTLY the same values.";
echo "</div>";

try {
    $facilitator_id = isset($_GET['id']) ? intval($_GET['id']) : 60; // Default to ID 60
    
    echo "<div class='instructions'>";
    echo "<h2>📋 How to Verify Sync is Working</h2>";
    echo "<ol>";
    echo "<li><strong>Check Server Data Below</strong> - This is what should be synced</li>";
    echo "<li><strong>Run Sync in App</strong> - Go to app and trigger facilitator sync</li>";
    echo "<li><strong>Check Local Database</strong> - Open local SQLite database and query:";
    echo "<div class='step-box'><code>SELECT * FROM facilitator WHERE facilitator_id = $facilitator_id</code></div></li>";
    echo "<li><strong>Compare Values</strong> - Every field below should match your local database</li>";
    echo "</ol>";
    echo "<p><strong>✅ If they match:</strong> Sync is working correctly!</p>";
    echo "<p><strong>❌ If they don't match:</strong> Data is being lost during sync - check app logs</p>";
    echo "</div>";

    // Get facilitator data from server
    $stmt = $conn->prepare("SELECT * FROM facilitator WHERE facilitator_id = ?");
    $stmt->bind_param("i", $facilitator_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($row = $result->fetch_assoc()) {
        echo "<h2>📊 Server Data for Facilitator ID: $facilitator_id</h2>";
        
        echo "<div class='alert alert-success'>";
        echo "<strong>✓ Facilitator Found on Server</strong><br>";
        echo "Name: <strong>" . htmlspecialchars($row['firstName'] . ' ' . $row['lastName']) . "</strong><br>";
        echo "Email: <strong>" . htmlspecialchars($row['email']) . "</strong><br>";
        echo "Class ID: <strong>" . htmlspecialchars($row['classID']) . "</strong>";
        echo "</div>";

        // Show what will be synced
        echo "<h3>This is What Your Local Database Should Have After Sync:</h3>";
        echo "<div class='panel'>";
        echo "<table style='width: 100%; border-collapse: collapse;'>";
        echo "<tr style='background: #e9ecef; font-weight: bold;'>";
        echo "<td style='padding: 10px; border: 1px solid #dee2e6;'>Field Name</td>";
        echo "<td style='padding: 10px; border: 1px solid #dee2e6;'>Value (Server)</td>";
        echo "<td style='padding: 10px; border: 1px solid #dee2e6;'>Type</td>";
        echo "<td style='padding: 10px; border: 1px solid #dee2e6;'>Status</td>";
        echo "</tr>";

        foreach ($row as $key => $value) {
            echo "<tr>";
            echo "<td style='padding: 8px; border: 1px solid #dee2e6; font-weight: bold;'>$key</td>";
            echo "<td style='padding: 8px; border: 1px solid #dee2e6; font-family: monospace;'>";
            
            if ($value === null) {
                echo "<span class='null-value'>NULL</span>";
            } elseif ($value === '') {
                echo "<span class='empty-value'>EMPTY STRING</span>";
            } elseif (strlen($value) > 100) {
                echo htmlspecialchars(substr($value, 0, 100)) . "... <em>(" . strlen($value) . " total chars)</em>";
            } else {
                echo htmlspecialchars($value);
            }
            
            echo "</td>";
            echo "<td style='padding: 8px; border: 1px solid #dee2e6;'>" . gettype($value) . "</td>";
            
            // Status indicators
            echo "<td style='padding: 8px; border: 1px solid #dee2e6;'>";
            if (in_array($key, ['facilitator_id', 'firstName', 'lastName', 'email', 'classID'])) {
                if ($value === null || $value === '') {
                    echo "<span style='color: #dc3545;'>⚠️ CRITICAL - Should have value!</span>";
                } else {
                    echo "<span style='color: #28a745;'>✓ Has value</span>";
                }
            } elseif ($value === null || $value === '') {
                echo "<span style='color: #6c757d;'>○ Empty (OK)</span>";
            } else {
                echo "<span style='color: #28a745;'>✓ Has data</span>";
            }
            echo "</td>";
            echo "</tr>";
        }
        echo "</table>";
        echo "</div>";

        // Show JSON format that will be sent
        echo "<h3>JSON Format (What App Receives):</h3>";
        echo "<div style='background: #2d3436; color: #00b894; padding: 15px; border-radius: 6px; overflow-x: auto;'>";
        echo "<pre>" . htmlspecialchars(json_encode($row, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)) . "</pre>";
        echo "</div>";

        // Expected local database values
        echo "<h3>💾 Expected Local Database Values:</h3>";
        echo "<div class='alert alert-info'>";
        echo "After sync, when you run this query in your local SQLite database:";
        echo "<div class='step-box'><code>SELECT * FROM facilitator WHERE facilitator_id = $facilitator_id</code></div>";
        echo "You should see these EXACT values:";
        echo "<ul>";
        echo "<li><strong>facilitator_id:</strong> " . htmlspecialchars($row['facilitator_id']) . "</li>";
        echo "<li><strong>firstName:</strong> \"" . htmlspecialchars($row['firstName']) . "\" (NOT empty!)</li>";
        echo "<li><strong>lastName:</strong> \"" . htmlspecialchars($row['lastName']) . "\" (NOT empty!)</li>";
        echo "<li><strong>email:</strong> \"" . htmlspecialchars($row['email']) . "\"</li>";
        echo "<li><strong>password:</strong> \"" . htmlspecialchars(substr($row['password'], 0, 30)) . "...\" (hashed, NOT \"null\" string)</li>";
        echo "<li><strong>classID:</strong> " . htmlspecialchars($row['classID']) . "</li>";
        echo "</ul>";
        echo "</div>";

        // Troubleshooting
        echo "<h3>🔧 If Local Database Shows Different Values:</h3>";
        echo "<div class='alert alert-danger'>";
        echo "<strong>Problem Signs:</strong>";
        echo "<ul>";
        echo "<li>firstName is empty string or NULL → Data lost during sync</li>";
        echo "<li>lastName is empty string or NULL → Data lost during sync</li>";
        echo "<li>password is string \"null\" instead of hash → JSON parsing issue</li>";
        echo "<li>facilitator_id is different → Wrong record synced</li>";
        echo "</ul>";
        echo "<strong>Actions:</strong>";
        echo "<ol>";
        echo "<li>Check app sync logs for errors (see FACILITATOR_SYNC_DEBUG.md)</li>";
        echo "<li>Look for \"[FAC_SYNC] ⚠️ WARNING: firstName mismatch\" in logs</li>";
        echo "<li>Verify \"[FAC_SYNC] FIRST RECORD FROM SERVER\" shows correct values</li>";
        echo "<li>Check \"[FAC_SYNC] VERIFIED in DB\" matches expected values</li>";
        echo "</ol>";
        echo "</div>";

    } else {
        echo "<div class='alert alert-danger'>";
        echo "<strong>❌ Facilitator ID $facilitator_id not found on server!</strong><br>";
        echo "Try a different ID: <a href='?id=1'>ID 1</a> | <a href='?id=60'>ID 60</a> | <a href='view_all_facilitators.php'>View All</a>";
        echo "</div>";
    }

    $stmt->close();

    // Show all available facilitators
    echo "<hr>";
    echo "<h3>Available Facilitators to Test:</h3>";
    $allStmt = $conn->query("SELECT facilitator_id, firstName, lastName, email FROM facilitator ORDER BY facilitator_id");
    echo "<ul>";
    while ($fac = $allStmt->fetch_assoc()) {
        $current = ($fac['facilitator_id'] == $facilitator_id) ? " <strong>(CURRENT)</strong>" : "";
        echo "<li><a href='?id={$fac['facilitator_id']}'>ID {$fac['facilitator_id']}: {$fac['firstName']} {$fac['lastName']} ({$fac['email']})</a>$current</li>";
    }
    echo "</ul>";

} catch (Exception $e) {
    echo "<div class='alert alert-danger'>";
    echo "<strong>Error:</strong> " . htmlspecialchars($e->getMessage());
    echo "</div>";
}

$conn->close();

echo "</div></body></html>";
?>

