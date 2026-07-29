<?php
// Find bank-related tables and columns

require_once 'connection.php';

echo "=== FINDING BANK-RELATED TABLES AND COLUMNS ===\n\n";

try {
    echo "✓ Database connected successfully\n\n";
    
    // Find all tables with 'bank' in the name
    echo "1. FINDING BANK-RELATED TABLES:\n";
    $tables_query = "SHOW TABLES LIKE '%bank%'";
    $tables_result = $conn->query($tables_query);
    
    if ($tables_result->num_rows > 0) {
        while ($table = $tables_result->fetch_array()) {
            $table_name = $table[0];
            echo "Found table: $table_name\n";
            
            // Check structure
            $desc_query = "DESCRIBE $table_name";
            $desc_result = $conn->query($desc_query);
            echo "  Columns:\n";
            while ($col = $desc_result->fetch_assoc()) {
                echo "    - {$col['Field']} ({$col['Type']})\n";
            }
            echo "\n";
        }
    } else {
        echo "No tables with 'bank' found\n";
    }
    
    // Check learnerdetails table for bank-related columns
    echo "2. CHECKING LEARNERDETAILS TABLE FOR BANK COLUMNS:\n";
    $desc_query = "DESCRIBE learnerdetails";
    $desc_result = $conn->query($desc_query);
    
    echo "Bank-related columns in learnerdetails:\n";
    $bank_columns = [];
    while ($col = $desc_result->fetch_assoc()) {
        if (stripos($col['Field'], 'bank') !== false || 
            stripos($col['Field'], 'account') !== false ||
            stripos($col['Field'], 'branch') !== false) {
            echo "  - {$col['Field']} ({$col['Type']})\n";
            $bank_columns[] = $col['Field'];
        }
    }
    
    if (empty($bank_columns)) {
        echo "  No bank-related columns found in learnerdetails\n";
    }
    echo "\n";
    
    // Check for other possible tables
    echo "3. CHECKING OTHER POSSIBLE BANK TABLES:\n";
    $possible_tables = ['bank_details', 'learner_bank', 'banking', 'financial_details', 'payment_details'];
    
    foreach ($possible_tables as $table) {
        $check_query = "SHOW TABLES LIKE '$table'";
        $check_result = $conn->query($check_query);
        
        if ($check_result->num_rows > 0) {
            echo "✓ Table exists: $table\n";
            
            // Check structure
            $desc_query = "DESCRIBE $table";
            $desc_result = $conn->query($desc_query);
            echo "  Columns:\n";
            while ($col = $desc_result->fetch_assoc()) {
                echo "    - {$col['Field']} ({$col['Type']})\n";
            }
            
            // Check for learner 11453
            $learner_check = $conn->query("SELECT * FROM $table WHERE learner_id = '11453' OR LearnerID = '11453' LIMIT 1");
            if ($learner_check && $learner_check->num_rows > 0) {
                echo "  ✓ Found data for learner 11453\n";
                $data = $learner_check->fetch_assoc();
                echo "  Data: " . json_encode($data) . "\n";
            } else {
                echo "  ✗ No data found for learner 11453\n";
            }
            echo "\n";
        }
    }
    
    // Search all tables for bank-related columns
    echo "4. SEARCHING ALL TABLES FOR BANK COLUMNS:\n";
    $all_tables_query = "SHOW TABLES";
    $all_tables_result = $conn->query($all_tables_query);
    
    while ($table = $all_tables_result->fetch_array()) {
        $table_name = $table[0];
        
        $desc_query = "DESCRIBE $table_name";
        $desc_result = $conn->query($desc_query);
        
        $has_bank_cols = false;
        $bank_cols = [];
        
        while ($col = $desc_result->fetch_assoc()) {
            if (stripos($col['Field'], 'bank') !== false || 
                stripos($col['Field'], 'account') !== false ||
                stripos($col['Field'], 'branch') !== false ||
                stripos($col['Field'], 'financial') !== false) {
                $has_bank_cols = true;
                $bank_cols[] = $col['Field'];
            }
        }
        
        if ($has_bank_cols) {
            echo "Table: $table_name\n";
            echo "  Bank columns: " . implode(', ', $bank_cols) . "\n";
            
            // Check for learner 11453 if there's a learner column
            $learner_cols = ['learner_id', 'LearnerID', 'IDNumber'];
            foreach ($learner_cols as $learner_col) {
                $check_col = $conn->query("SHOW COLUMNS FROM $table_name LIKE '$learner_col'");
                if ($check_col && $check_col->num_rows > 0) {
                    $learner_check = $conn->query("SELECT * FROM $table_name WHERE $learner_col = '11453' LIMIT 1");
                    if ($learner_check && $learner_check->num_rows > 0) {
                        echo "  ✓ Found data for learner 11453 using $learner_col\n";
                        $data = $learner_check->fetch_assoc();
                        echo "  Sample: " . json_encode(array_slice($data, 0, 5)) . "\n";
                        break;
                    }
                }
            }
            echo "\n";
        }
    }
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}
?>