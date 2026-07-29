<?php
/**
 * Verification Script - Learner Documents Fix
 * Tests that documents now load correctly for learner 16389
 */

session_start();
$_SESSION['sdp_id'] = 1; // Mock session

require_once __DIR__ . '/connection.php';

$learnerID = 16389;

echo "=== LEARNER DOCUMENTS FIX VERIFICATION ===\n";
echo "Learner ID: $learnerID\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// ── TEST THE FIXED QUERY ────────────────────────────────────────────────────
echo "--- TESTING FIXED DATABASE QUERY ---\n";

$st = $conn->prepare("
    SELECT * FROM learner_document 
    WHERE learner_id = ? 
    ORDER BY upload_date DESC 
    LIMIT 20
");

if (!$st) {
    echo "❌ Query preparation failed: " . $conn->error . "\n";
} else {
    $st->bind_param("s", $learnerID);
    $st->execute();
    $result = $st->get_result();
    
    $documents = [];
    while ($row = $result->fetch_assoc()) {
        $documents[] = $row;
    }
    $st->close();
    
    if (count($documents) === 0) {
        echo "❌ NO DOCUMENTS FOUND\n";
    } else {
        echo "✅ Found " . count($documents) . " document(s)\n\n";
        
        $docCount = 0;
        foreach ($documents as $doc) {
            $docCount++;
            echo "Document #$docCount:\n";
            
            // Extract fields
            $docType = htmlspecialchars($doc['document_type'] ?? 'Document');
            $docName = htmlspecialchars($doc['documentName'] ?? $doc['learner_document'] ?? 'Document');
            $uploadDate = isset($doc['upload_date']) ? date('d M Y', strtotime($doc['upload_date'])) : 'N/A';
            $status = htmlspecialchars($doc['status'] ?? 'Pending');
            
            // Determine display type
            $displayType = $docType;
            if (empty($docType) || $docType === 'Document') {
                if (stripos($docName, 'id') !== false || stripos($docName, 'poe') !== false) {
                    $displayType = 'ID Document';
                } elseif (stripos($docName, 'cv') !== false) {
                    $displayType = 'Curriculum Vitae (CV)';
                } elseif (stripos($docName, 'cert') !== false) {
                    $displayType = 'Certificate/Qualification';
                } elseif (stripos($docName, 'qual') !== false) {
                    $displayType = 'Qualification';
                } else {
                    $displayType = 'Supporting Document';
                }
            }
            
            echo "  Type: $displayType\n";
            echo "  Name: $docName\n";
            echo "  Upload Date: $uploadDate\n";
            echo "  Status: $status\n";
            echo "  Raw Type: $docType\n";
            echo "\n";
        }
    }
}

echo "=== VERIFICATION COMPLETE ===\n";
echo "✅ If documents are shown above, the fix is working!\n";
echo "The ARPL PDF should now display these documents on Page 4.\n";

$conn->close();
?>
