<?php
/**
 * ARPL Endpoints & Database Tables Identification Script
 * 
 * Purpose: Identify all ARPL-related PHP endpoints and database tables
 * that need to be uploaded to the online server
 * 
 * Usage: Run this script to generate a comprehensive list
 * Output: Lists all files to upload and SQL tables to create
 */

echo "========================================\n";
echo "ARPL SYSTEM - UPLOAD IDENTIFICATION\n";
echo "========================================\n\n";

// ============================================
// PART 1: IDENTIFY ALL ARPL MOBILE ENDPOINTS
// ============================================
echo "PART 1: ARPL MOBILE ENDPOINTS (.php files)\n";
echo "Location: /mobile/\n";
echo "=========================================\n\n";

$mobile_dir = __DIR__ . '/mobile';
$arpl_endpoints = [];

if (is_dir($mobile_dir)) {
    $files = scandir($mobile_dir);
    foreach ($files as $file) {
        if (strpos(strtolower($file), 'arpl') !== false && substr($file, -4) === '.php') {
            $arpl_endpoints[] = $file;
        }
    }
}

// Sort endpoints
sort($arpl_endpoints);

echo "GET ENDPOINTS (Read/Retrieve Data):\n";
echo "───────────────────────────────────\n";
$get_endpoints = [];
foreach ($arpl_endpoints as $endpoint) {
    if (strpos($endpoint, 'get_') === 0) {
        $get_endpoints[] = $endpoint;
        echo "  ✓ " . $endpoint . "\n";
    }
}

echo "\nSAVE/POST ENDPOINTS (Write/Create Data):\n";
echo "──────────────────────────────────────\n";
$save_endpoints = [];
foreach ($arpl_endpoints as $endpoint) {
    if (strpos($endpoint, 'save_') === 0) {
        $save_endpoints[] = $endpoint;
        echo "  ✓ " . $endpoint . "\n";
    }
}

echo "\nCHECK/DIAGNOSTIC ENDPOINTS (Verification):\n";
echo "─────────────────────────────────────────\n";
$check_endpoints = [];
foreach ($arpl_endpoints as $endpoint) {
    if (strpos($endpoint, 'check_') === 0 || strpos($endpoint, 'debug_') === 0 || strpos($endpoint, 'diagnose_') === 0 || strpos($endpoint, 'verify_') === 0) {
        $check_endpoints[] = $endpoint;
        echo "  ✓ " . $endpoint . "\n";
    }
}

echo "\nOTHER ARPL ENDPOINTS:\n";
echo "──────────────────\n";
$other_endpoints = [];
foreach ($arpl_endpoints as $endpoint) {
    if (!in_array($endpoint, $get_endpoints) && 
        !in_array($endpoint, $save_endpoints) && 
        !in_array($endpoint, $check_endpoints)) {
        $other_endpoints[] = $endpoint;
        echo "  ✓ " . $endpoint . "\n";
    }
}

// ============================================
// PART 2: SUMMARY OF ALL ENDPOINTS
// ============================================
echo "\n\nPART 2: COMPLETE ENDPOINT LIST\n";
echo "===============================\n\n";

echo "Total ARPL Endpoints: " . count($arpl_endpoints) . "\n\n";

echo "ENDPOINTS TO UPLOAD (Copy to online server):\n";
echo "──────────────────────────────────────────\n";
foreach ($arpl_endpoints as $endpoint) {
    echo "  - /assessorReport2/mobile/" . $endpoint . "\n";
}

// ============================================
// PART 3: IDENTIFY DATABASE TABLES
// ============================================
echo "\n\nPART 3: ARPL DATABASE TABLES\n";
echo "============================\n\n";

$arpl_tables = [
    'Core Tables' => [
        'arpl_poe' => 'Main POE unified table (theory & practical papers)',
        'arpl_papers' => 'Paper definitions and templates',
        'arpl_questions' => 'Assessment questions for each paper',
        'arpl_trades' => 'Trade definitions (Electrician, Bricklayer, Plumber)',
    ],
    'Competency Tables' => [
        'arpl_competency_scale' => 'Rating scale (1-4 competency levels)',
        'arplappxb_electrician_activities' => 'Electrician Appendix B activities',
        'arplappxb_bricklaying_activities' => 'Bricklaying Appendix B activities',
        'arplappxb_plumbing_activities' => 'Plumbing Appendix B activities',
        'arplappxe_electrician_activity_ratings' => 'Electrician Appendix E ratings',
        'arplappxe_bricklaying_activity_ratings' => 'Bricklaying Appendix E ratings',
        'arplappxb_activity_ratings' => 'Activity ratings (Plumbing)',
    ],
    'Assessment Form Tables' => [
        'arpl_appendix_c' => 'Appendix C - Self Evaluation',
        'arpl_appendix_d' => 'Appendix D - Practical Skills Assessment',
        'arpl_appendix_g' => 'Appendix G - Assessment Agreement',
        'arpl_appendix_i' => 'Appendix I - Access Recommendation (Generic)',
        'arplelectrician_access_recommendation' => 'Appendix H - Electrician Access Recommendation',
        'arplbricklayer_access_recommendation' => 'Appendix H - Bricklayer Access Recommendation',
        'arplplumber_access_recommendation' => 'Appendix H - Plumber Access Recommendation',
    ],
    'Application & Work Experience' => [
        'arpl_applications_v3' => 'ARPL Application forms',
        'arpl_work_experience_v3' => 'Work experience records',
        'arpl_references_v3' => 'References provided',
        'arpl_qualifications_v3' => 'Qualifications submitted',
    ],
    'Gap Analysis Tables' => [
        'gap_analysis_submissions' => 'Gap analysis submissions',
        'gap_analysis_submission_items' => 'Gap analysis line items',
        'gap_analysis_report' => 'Gap analysis report templates',
        'arpl_bricklayer_gap_tasks' => 'Bricklayer gap closure tasks',
    ],
];

foreach ($arpl_tables as $category => $tables) {
    echo "$category:\n";
    echo str_repeat("─", strlen($category)) . "\n";
    foreach ($tables as $table => $description) {
        echo "  ✓ $table\n";
        echo "    → $description\n";
    }
    echo "\n";
}

// ============================================
// PART 4: SQL SETUP FILES
// ============================================
echo "\nPART 4: SQL SETUP FILES\n";
echo "=======================\n\n";

$sql_files = [
    'create_arpl_theory_papers.sql' => 'Creates arpl_trades, arpl_papers, arpl_questions for Electrician',
    'create_arpl_separate_tables.sql' => 'Creates separate ARPL tables',
    'create_arpl_poe_unified_table.sql' => 'Creates main arpl_poe unified table',
    'create_arpl_appendix_d_table.sql' => 'Creates Appendix D table',
    'create_arpl_appendix_f_tables.sql' => 'Creates Appendix F tables',
    'create_bricklayer_appendix_tables.sql' => 'Creates Bricklayer-specific tables',
    'create_bricklayer_gap_closure_tables.sql' => 'Creates gap closure tables',
    'create_plumber_access_recommendation.sql' => 'Creates Plumber recommendation table',
    'insert_questions_electrician_theory.sql' => 'Inserts Electrician theory questions',
    'insert_questions_electrician_practical.sql' => 'Inserts Electrician practical questions',
    'insert_questions_bricklayer_theory.sql' => 'Inserts Bricklayer theory questions',
    'insert_questions_bricklayer_practical.sql' => 'Inserts Bricklayer practical questions',
    'insert_bricklayer_questions.sql' => 'Additional Bricklayer questions',
];

echo "SQL Files (Run on online server database):\n";
echo "────────────────────────────────────────\n";
foreach ($sql_files as $file => $description) {
    echo "  ✓ $file\n";
    echo "    → $description\n";
}

// ============================================
// PART 5: GENERATION COMMANDS
// ============================================
echo "\n\nPART 5: UPLOAD COMMANDS\n";
echo "=======================\n\n";

echo "STEP 1: Copy all ARPL mobile endpoints to server\n";
echo "──────────────────────────────────────────────\n";
echo "Commands for Windows (replace with your FTP/SFTP):\n\n";

echo "# Copy GET endpoints:\n";
foreach ($get_endpoints as $endpoint) {
    echo "copy c:\\projects\\rlmss\\mobile\\" . $endpoint . " /online_server/assessorReport2/mobile/\n";
}

echo "\n# Copy SAVE endpoints:\n";
foreach ($save_endpoints as $endpoint) {
    echo "copy c:\\projects\\rlmss\\mobile\\" . $endpoint . " /online_server/assessorReport2/mobile/\n";
}

echo "\n\nSTEP 2: Create database tables on online server\n";
echo "────────────────────────────────────────────\n";
echo "Run these SQL files in order:\n\n";

$order = [
    'create_arpl_theory_papers.sql',
    'create_arpl_separate_tables.sql',
    'create_arpl_poe_unified_table.sql',
    'create_arpl_appendix_d_table.sql',
    'create_arpl_appendix_f_tables.sql',
    'create_bricklayer_appendix_tables.sql',
    'create_bricklayer_gap_closure_tables.sql',
    'create_plumber_access_recommendation.sql',
    'insert_questions_electrician_theory.sql',
    'insert_questions_electrician_practical.sql',
    'insert_questions_bricklayer_theory.sql',
    'insert_questions_bricklayer_practical.sql',
];

foreach ($order as $i => $file) {
    echo ($i + 1) . ". $file\n";
}

// ============================================
// PART 6: FILE COUNTS AND SUMMARY
// ============================================
echo "\n\nPART 6: SUMMARY\n";
echo "===============\n\n";

echo "Total Endpoints to Upload: " . count($arpl_endpoints) . "\n";
echo "  - GET endpoints: " . count($get_endpoints) . "\n";
echo "  - SAVE endpoints: " . count($save_endpoints) . "\n";
echo "  - Other endpoints: " . (count($get_endpoints) + count($save_endpoints) + count($check_endpoints)) . "\n";

$total_tables = 0;
foreach ($arpl_tables as $category => $tables) {
    $total_tables += count($tables);
}

echo "\nTotal Database Tables: " . $total_tables . "\n";
foreach ($arpl_tables as $category => $tables) {
    echo "  - " . $category . ": " . count($tables) . " tables\n";
}

echo "\nSQL Setup Files: " . count($sql_files) . "\n";

// ============================================
// PART 7: EXPORT LIST TO FILE
// ============================================
echo "\n\nPART 7: EXPORT LISTS\n";
echo "====================\n\n";

// Export endpoints list
$endpoints_file = __DIR__ . '/ARPL_ENDPOINTS_FOR_UPLOAD.txt';
$endpoints_content = "ARPL MOBILE ENDPOINTS FOR UPLOAD\n";
$endpoints_content .= "Generated: " . date('Y-m-d H:i:s') . "\n\n";
$endpoints_content .= "Total Endpoints: " . count($arpl_endpoints) . "\n\n";
$endpoints_content .= "GET ENDPOINTS:\n";
$endpoints_content .= str_repeat("─", 50) . "\n";
foreach ($get_endpoints as $ep) {
    $endpoints_content .= "/assessorReport2/mobile/" . $ep . "\n";
}
$endpoints_content .= "\nSAVE ENDPOINTS:\n";
$endpoints_content .= str_repeat("─", 50) . "\n";
foreach ($save_endpoints as $ep) {
    $endpoints_content .= "/assessorReport2/mobile/" . $ep . "\n";
}
$endpoints_content .= "\nOTHER ENDPOINTS:\n";
$endpoints_content .= str_repeat("─", 50) . "\n";
foreach ($check_endpoints as $ep) {
    $endpoints_content .= "/assessorReport2/mobile/" . $ep . "\n";
}

file_put_contents($endpoints_file, $endpoints_content);
echo "✓ Endpoints list exported to: ARPL_ENDPOINTS_FOR_UPLOAD.txt\n";

// Export tables list
$tables_file = __DIR__ . '/ARPL_DATABASE_TABLES_FOR_UPLOAD.txt';
$tables_content = "ARPL DATABASE TABLES FOR UPLOAD\n";
$tables_content .= "Generated: " . date('Y-m-d H:i:s') . "\n\n";
$tables_content .= "Total Tables: " . $total_tables . "\n\n";

foreach ($arpl_tables as $category => $tables) {
    $tables_content .= $category . " (" . count($tables) . " tables)\n";
    $tables_content .= str_repeat("─", strlen($category) + 20) . "\n";
    foreach ($tables as $table => $description) {
        $tables_content .= "  • $table\n";
        $tables_content .= "    $description\n";
    }
    $tables_content .= "\n";
}

file_put_contents($tables_file, $tables_content);
echo "✓ Tables list exported to: ARPL_DATABASE_TABLES_FOR_UPLOAD.txt\n";

// Export SQL files list
$sql_file = __DIR__ . '/ARPL_SQL_FILES_FOR_UPLOAD.txt';
$sql_content = "ARPL SQL FILES FOR UPLOAD\n";
$sql_content .= "Generated: " . date('Y-m-d H:i:s') . "\n\n";
$sql_content .= "Total SQL Files: " . count($sql_files) . "\n\n";
$sql_content .= "Run in this order:\n\n";

foreach ($order as $i => $file) {
    $sql_content .= ($i + 1) . ". " . $file . "\n";
}

file_put_contents($sql_file, $sql_content);
echo "✓ SQL files list exported to: ARPL_SQL_FILES_FOR_UPLOAD.txt\n";

echo "\n\nAll identification complete!\n";
echo "Check the exported files for complete lists.\n";
?>
