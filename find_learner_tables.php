<?php
// Find learner tables and CV-related columns

// Database connection
$servername = "localhost";
$username = "root";
$password = "";
$dbname = "rlmsrlmsco_ezxcmacd_rlms";

echo "=== FINDING LEARNER TABLES AND CV COLUMNS ===\n\n";

try {
    $pdo = new PDO("mysql:host=$servername;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "✓ Database connected successfully\n\n";
    
    // Find all tables with 'learner' in the name
    echo "1. FINDING LEARNER-RELATED TABLES:\n";
    $tables_query = "SHOW TABLES LIKE '%learner%'";
    $tables_result = $pdo->query($tables_query);
    $learner_tables = $tables_result->fetchAll(PDO::FETCH_COLUMN);
    
    if ($learner_tables) {
        foreach ($learner_tables as $table) {
            echo "Found table: $table\n";
        }
    } else {
        echo "No tables with 'learner' found\n";
    }
    echo "\n";
    
    // Also check for common variations
    echo "2. CHECKING OTHER POSSIBLE TABLE NAMES:\n";
    $possible_tables = ['learners', 'learner', 'learnerdetails', 'learner_details', 'students', 'users'];
    
    foreach ($possible_tables as $table) {
        try {
            $check_query = "SHOW TABLES LIKE '$table'";
            $check_result = $pdo->query($check_query);
            if ($check_result->rowCount() > 0) {
                echo "✓ Table exists: $table\n";
                
                // Check for CV-related columns
                $columns_query = "DESCRIBE $table";
                $columns_result = $pdo->query($columns_query);
                $columns = $columns_result->fetchAll(PDO::FETCH_ASSOC);
                
                echo "  CV-related columns:\n";
                foreach ($columns as $column) {
                    if (stripos($column['Field'], 'cv') !== false || 
                        stripos($column['Field'], 'document') !== false ||
                        stripos($column['Field'], 'file') !== false) {
                        echo "    - {$column['Field']} ({$column['Type']})\n";
                    }
                }
                
                // Check if learner 11453 exists in this table
                $learner_check = $pdo->prepare("SELECT * FROM $table WHERE LearnerID = ? OR IDNumber = ? OR id = ? LIMIT 1");
                $learner_check->execute(['11453', '11453', '11453']);
                $learner = $learner_check->fetch(PDO::FETCH_ASSOC);
                
                if ($learner) {
                    echo "  ✓ Learner 11453 found in this table!\n";
                    echo "  Sample data: " . json_encode(array_slice($learner, 0, 5)) . "\n";
                } else {
                    echo "  ✗ Learner 11453 not found in this table\n";
                }
                echo "\n";
            }
        } catch (Exception $e) {
            // Table doesn't exist, continue
        }
    }
    
    // Check for document-related tables
    echo "3. CHECKING DOCUMENT-RELATED TABLES:\n";
    $doc_tables_query = "SHOW TABLES LIKE '%document%'";
    $doc_tables_result = $pdo->query($doc_tables_query);
    $doc_tables = $doc_tables_result->fetchAll(PDO::FETCH_COLUMN);
    
    if ($doc_tables) {
        foreach ($doc_tables as $table) {
            echo "Found document table: $table\n";
            
            // Check structure
            $columns_query = "DESCRIBE $table";
            $columns_result = $pdo->query($columns_query);
            $columns = $columns_result->fetchAll(PDO::FETCH_ASSOC);
            
            echo "  Columns:\n";
            foreach ($columns as $column) {
                echo "    - {$column['Field']} ({$column['Type']})\n";
            }
            
            // Check for learner 11453
            try {
                $doc_check = $pdo->prepare("SELECT * FROM $table WHERE learner_id = ? OR LearnerID = ? LIMIT 1");
                $doc_check->execute(['11453', '11453']);
                $doc = $doc_check->fetch(PDO::FETCH_ASSOC);
                
                if ($doc) {
                    echo "  ✓ Documents found for learner 11453!\n";
                    echo "  Sample: " . json_encode($doc) . "\n";
                }
            } catch (Exception $e) {
                // Column doesn't exist, continue
            }
            echo "\n";
        }
    } else {
        echo "No document tables found\n";
    }
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}
?>