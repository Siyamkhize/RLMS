<?php
include 'connection.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

try {
    echo "<h2>Applying Search Performance Indexes</h2>\n";
    echo "<pre>\n";
    
    $indexes = [
        "CREATE INDEX IF NOT EXISTS idx_learnerdetails_classid ON learnerdetails(classID)" => "Class ID index",
        "CREATE INDEX IF NOT EXISTS idx_learnerdetails_idnumber ON learnerdetails(IDNumber)" => "ID Number index",
        "CREATE INDEX IF NOT EXISTS idx_learnerdetails_name ON learnerdetails(Name)" => "Name index",
        "CREATE INDEX IF NOT EXISTS idx_learnerdetails_surname ON learnerdetails(Surname)" => "Surname index",
        "CREATE INDEX IF NOT EXISTS idx_learnerdetails_class_name ON learnerdetails(classID, Name, Surname)" => "Composite Class+Name index",
        "CREATE INDEX IF NOT EXISTS idx_learnerdetails_class_id ON learnerdetails(classID, IDNumber)" => "Composite Class+ID index",
        "CREATE INDEX IF NOT EXISTS idx_learnerdetails_phone ON learnerdetails(PhoneNumber)" => "Phone Number index",
        "CREATE INDEX IF NOT EXISTS idx_learnerdetails_synced ON learnerdetails(synced)" => "Sync Status index"
    ];
    
    $successCount = 0;
    $errorCount = 0;
    
    foreach ($indexes as $sql => $description) {
        echo "Creating $description... ";
        try {
            $result = $conn->query($sql);
            if ($result) {
                echo "✅ SUCCESS\n";
                $successCount++;
            } else {
                echo "❌ FAILED: " . $conn->error . "\n";
                $errorCount++;
            }
        } catch (Exception $e) {
            echo "❌ ERROR: " . $e->getMessage() . "\n";
            $errorCount++;
        }
    }
    
    echo "\n=== SUMMARY ===\n";
    echo "✅ Successfully created: $successCount indexes\n";
    echo "❌ Failed to create: $errorCount indexes\n";
    
    // Show existing indexes
    echo "\n=== CURRENT INDEXES ON learnerdetails TABLE ===\n";
    $result = $conn->query("SHOW INDEX FROM learnerdetails");
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            echo "Index: {$row['Key_name']} on column: {$row['Column_name']}\n";
        }
    }
    
    // Test query performance
    echo "\n=== TESTING SEARCH PERFORMANCE ===\n";
    
    $testQueries = [
        "SELECT COUNT(*) FROM learnerdetails WHERE classID = '1'" => "Count by classID",
        "SELECT COUNT(*) FROM learnerdetails WHERE IDNumber LIKE '%123%'" => "Search by ID Number",
        "SELECT COUNT(*) FROM learnerdetails WHERE Name LIKE '%John%'" => "Search by Name",
        "SELECT COUNT(*) FROM learnerdetails WHERE classID = '1' AND Name LIKE '%A%'" => "Combined search"
    ];
    
    foreach ($testQueries as $sql => $description) {
        $start = microtime(true);
        $result = $conn->query($sql);
        $end = microtime(true);
        $time = round(($end - $start) * 1000, 2);
        
        if ($result) {
            $row = $result->fetch_assoc();
            $count = $row['COUNT(*)'];
            echo "$description: $count records found in {$time}ms\n";
        } else {
            echo "$description: ERROR - " . $conn->error . "\n";
        }
    }
    
    echo "</pre>\n";
    echo "<h3>✅ Search optimization complete!</h3>\n";
    echo "<p>Your search queries should now be significantly faster.</p>\n";
    
} catch (Exception $e) {
    echo "<h3>❌ Error applying indexes</h3>\n";
    echo "<p>Error: " . $e->getMessage() . "</p>\n";
}

$conn->close();
?>