<?php
// Simple test without mysqli dependency
echo "SDP Learners Debug Test\n";
echo "======================\n\n";

// Test with PDO instead of mysqli
try {
    $servername = "localhost";
    $username = "rlmsrlmsco_ezxcmacd_rlms";
    $password = "aV~4RP=_G{Uxm-Mp";
    $dbname = "rlmsrlmsco_ezxcmacd_rlms";

    $pdo = new PDO("mysql:host=$servername;dbname=$dbname;charset=utf8", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    echo "✅ Database connection successful\n\n";

    // Check what SDPs exist
    echo "1. Available SDPs:\n";
    echo "-----------------\n";
    $stmt = $pdo->query("SELECT sdp_id, sdp_name FROM sdp ORDER BY sdp_id");
    $sdps = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($sdps)) {
        echo "❌ No SDPs found!\n";
    } else {
        foreach ($sdps as $sdp) {
            echo "SDP ID: {$sdp['sdp_id']}, Name: {$sdp['sdp_name']}\n";
        }
    }
    echo "\n";

    // Check learner table structure
    echo "2. Learner table structure:\n";
    echo "---------------------------\n";
    $stmt = $pdo->query("DESCRIBE learnerdetails");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $has_sdp_id = false;
    foreach ($columns as $col) {
        if ($col['Field'] === 'sdp_id') {
            $has_sdp_id = true;
            echo "✅ learnerdetails.sdp_id exists: {$col['Type']}\n";
        }
    }
    
    if (!$has_sdp_id) {
        echo "❌ learnerdetails.sdp_id column missing!\n";
    }
    echo "\n";

    // Check total learners
    echo "3. Learner counts:\n";
    echo "------------------\n";
    $stmt = $pdo->query("SELECT COUNT(*) as total FROM learnerdetails");
    $total = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    echo "Total learners: $total\n";

    if ($has_sdp_id) {
        $stmt = $pdo->query("SELECT COUNT(*) as with_sdp FROM learnerdetails WHERE sdp_id IS NOT NULL AND sdp_id != 0");
        $with_sdp = $stmt->fetch(PDO::FETCH_ASSOC)['with_sdp'];
        echo "Learners with SDP ID: $with_sdp\n";

        // Show distribution by SDP
        $stmt = $pdo->query("SELECT sdp_id, COUNT(*) as count FROM learnerdetails WHERE sdp_id IS NOT NULL GROUP BY sdp_id ORDER BY sdp_id");
        $distribution = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        if (!empty($distribution)) {
            echo "\nLearners per SDP:\n";
            foreach ($distribution as $row) {
                echo "SDP {$row['sdp_id']}: {$row['count']} learners\n";
            }
        }
    }
    echo "\n";

    // Check sites table relationship
    echo "4. Sites-SDP relationship:\n";
    echo "--------------------------\n";
    $stmt = $pdo->query("SELECT COUNT(*) as total FROM sites");
    $total_sites = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    echo "Total sites: $total_sites\n";

    $stmt = $pdo->query("SELECT COUNT(*) as with_sdp FROM sites WHERE sdp_id IS NOT NULL AND sdp_id != 0");
    $sites_with_sdp = $stmt->fetch(PDO::FETCH_ASSOC)['with_sdp'];
    echo "Sites with SDP ID: $sites_with_sdp\n";

    // Check learners through sites relationship (like Flutter app does)
    echo "\n5. Learners through sites relationship:\n";
    echo "--------------------------------------\n";
    
    if (!empty($sdps)) {
        $first_sdp = $sdps[0]['sdp_id'];
        echo "Testing with SDP ID: $first_sdp\n";

        // Test the Flutter app's approach
        $stmt = $pdo->prepare("
            SELECT COUNT(*) as count
            FROM learnerdetails l
            LEFT JOIN class c ON l.classID = c.classID
            LEFT JOIN sites site ON c.siteID = site.siteID
            WHERE site.sdp_id = ?
        ");
        $stmt->execute([$first_sdp]);
        $flutter_count = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        echo "Flutter approach (through sites): $flutter_count learners\n";

        // Test the PHP API's approach
        $stmt = $pdo->prepare("
            SELECT COUNT(*) as count
            FROM learnerdetails l
            WHERE l.sdp_id = ?
        ");
        $stmt->execute([$first_sdp]);
        $api_count = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        echo "PHP API approach (direct): $api_count learners\n";

        if ($flutter_count != $api_count) {
            echo "⚠️  MISMATCH! The two approaches return different counts.\n";
            echo "This explains why you're seeing 'no learners'.\n";
        }
    }

} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
}

echo "\n=== Test Complete ===\n";
?>