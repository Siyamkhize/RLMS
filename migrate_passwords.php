<?php
/**
 * Password Migration Script
 * Migrates MD5 and plaintext passwords to bcrypt
 * 
 * IMPORTANT: Run this ONCE before deploying secure login
 * Usage: php migrate_passwords.php
 */

require_once 'includes/security.php';
require_once 'includes/db_secure.php';

echo "=== Password Migration Script ===\n\n";

try {
    $db = Database::getInstance();
    $conn = $db->getConnection();
    
    // Migrate SDP passwords
    echo "Migrating SDP passwords...\n";
    $sdpQuery = "SELECT sdp_id, email, password FROM sdp";
    $result = $conn->query($sdpQuery);
    
    $sdpMigrated = 0;
    $sdpSkipped = 0;
    
    while ($row = $result->fetch_assoc()) {
        // Check if already bcrypt (starts with $2y$)
        if (substr($row['password'], 0, 4) === '$2y$') {
            $sdpSkipped++;
            continue;
        }
        
        // Generate bcrypt hash from existing password
        // Note: This assumes the stored value IS the password
        // If it's MD5, users will need to reset passwords
        $newHash = Security::hashPassword($row['password']);
        
        $updateStmt = $conn->prepare("UPDATE sdp SET password = ? WHERE sdp_id = ?");
        $updateStmt->bind_param('ss', $newHash, $row['sdp_id']);
        $updateStmt->execute();
        $updateStmt->close();
        
        $sdpMigrated++;
        echo "  Migrated SDP: {$row['email']}\n";
    }
    
    echo "SDP: $sdpMigrated migrated, $sdpSkipped already secure\n\n";
    
    // Migrate Facilitator passwords
    echo "Migrating Facilitator passwords...\n";
    $facQuery = "SELECT facilitator_id, email, password FROM facilitator";
    $result = $conn->query($facQuery);
    
    $facMigrated = 0;
    $facSkipped = 0;
    
    while ($row = $result->fetch_assoc()) {
        if (substr($row['password'], 0, 4) === '$2y$') {
            $facSkipped++;
            continue;
        }
        
        $newHash = Security::hashPassword($row['password']);
        
        $updateStmt = $conn->prepare("UPDATE facilitator SET password = ? WHERE facilitator_id = ?");
        $updateStmt->bind_param('ss', $newHash, $row['facilitator_id']);
        $updateStmt->execute();
        $updateStmt->close();
        
        $facMigrated++;
        echo "  Migrated Facilitator: {$row['email']}\n";
    }
    
    echo "Facilitator: $facMigrated migrated, $facSkipped already secure\n\n";
    
    // Migrate Account User passwords
    echo "Migrating Account User passwords...\n";
    $accQuery = "SELECT account_id, username, email, password FROM account_user";
    $result = $conn->query($accQuery);
    
    $accMigrated = 0;
    $accSkipped = 0;
    
    while ($row = $result->fetch_assoc()) {
        if (substr($row['password'], 0, 4) === '$2y$') {
            $accSkipped++;
            continue;
        }
        
        $newHash = Security::hashPassword($row['password']);
        
        $updateStmt = $conn->prepare("UPDATE account_user SET password = ? WHERE account_id = ?");
        $updateStmt->bind_param('si', $newHash, $row['account_id']);
        $updateStmt->execute();
        $updateStmt->close();
        
        $accMigrated++;
        echo "  Migrated Account User: {$row['username']}\n";
    }
    
    echo "Account User: $accMigrated migrated, $accSkipped already secure\n\n";
    
    echo "=== Migration Complete ===\n";
    echo "Total migrated: " . ($sdpMigrated + $facMigrated + $accMigrated) . "\n";
    echo "Total skipped: " . ($sdpSkipped + $facSkipped + $accSkipped) . "\n\n";
    
    echo "IMPORTANT NOTES:\n";
    echo "1. If passwords were stored as MD5 hashes, users will need to reset their passwords\n";
    echo "2. Update your login.php to use login_secure.php\n";
    echo "3. Test login functionality before deploying\n";
    echo "4. Delete this script after successful migration\n";
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    exit(1);
}
?>
