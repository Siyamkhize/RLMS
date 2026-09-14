<?php
/**
 * Learner Agreement Portal
 * Allows learners to access their agreements by entering their ID Number
 */

// Start session and output buffering
session_start();
ob_start();

// Include database connection
require_once 'connection.php';

// Error reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Initialize variables
$error_message = '';
$success_message = '';
$agreements = [];
$id_number = '';
$searched = false;

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['search_agreements'])) {
    $id_number = trim($_POST['id_number'] ?? '');
    
    // Validate ID Number
    if (empty($id_number)) {
        $error_message = 'Please enter your ID Number.';
    } elseif (!preg_match('/^[0-9]{13}$/', $id_number)) {
        $error_message = 'Please enter a valid 13-digit South African ID Number.';
    } else {
        $searched = true;
        
        // First, get learner details from learnerdetails table
        $learner_stmt = $conn->prepare("
            SELECT 
                ld.LearnerID,
                ld.Name,
                ld.Surname,
                ld.IDNumber,
                ld.PhoneNumber
            FROM learnerdetails ld
            WHERE ld.IDNumber = ?
            LIMIT 1
        ");
        
        if ($learner_stmt) {
            $learner_stmt->bind_param('s', $id_number);
            $learner_stmt->execute();
            $learner_result = $learner_stmt->get_result();
            
            if ($learner_result->num_rows > 0) {
                $learner = $learner_result->fetch_assoc();
                $learner_id = $learner['LearnerID'];
                
                // Now search for agreements in stored_agreement_pdfs table
                $stmt = $conn->prepare("
                    SELECT 
                        id,
                        learner_id,
                        learner_name,
                        project_id,
                        document_type,
                        pdf_filename,
                        pdf_path,
                        file_size,
                        generated_date,
                        year,
                        month
                    FROM stored_agreement_pdfs
                    WHERE learner_id = ?
                    ORDER BY generated_date DESC
                ");
                
                if ($stmt) {
                    $stmt->bind_param('s', $learner_id);
                    $stmt->execute();
                    $result = $stmt->get_result();
                    
                    if ($result->num_rows > 0) {
                        while ($row = $result->fetch_assoc()) {
                            $agreements[] = $row;
                        }
                        $success_message = 'Found ' . count($agreements) . ' agreement(s) for ' . htmlspecialchars($learner['Name'] . ' ' . $learner['Surname']);
                    } else {
                        $error_message = 'No learner agreements found for this ID Number. Please contact your administrator if you believe this is an error.';
                    }
                    $stmt->close();
                } else {
                    $error_message = 'Database error: Unable to search for agreements.';
                }
            } else {
                $error_message = 'No learner found with this ID Number. Please verify your ID Number and try again.';
            }
            $learner_stmt->close();
        } else {
            $error_message = 'Database error: Unable to search for learner details.';
        }
    }
}

// Handle download request
if (isset($_GET['download']) && isset($_GET['id'])) {
    $agreement_id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT);
    $id_number_verify = trim($_GET['verify'] ?? '');
    
    if ($agreement_id && $id_number_verify) {
        // Verify the ID number matches the agreement
        $stmt = $conn->prepare("
            SELECT 
                sap.pdf_path,
                sap.pdf_filename,
                sap.learner_id
            FROM stored_agreement_pdfs sap
            JOIN learnerdetails ld ON sap.learner_id = ld.LearnerID
            WHERE sap.id = ? AND ld.IDNumber = ?
        ");
        
        if ($stmt) {
            $stmt->bind_param('is', $agreement_id, $id_number_verify);
            $stmt->execute();
            $result = $stmt->get_result();
            
            if ($result->num_rows > 0) {
                $pdf = $result->fetch_assoc();
                $file_path = $pdf['pdf_path'];
                
                // Check if file exists
                if (file_exists($file_path)) {
                    // Set headers for download
                    header('Content-Type: application/pdf');
                    header('Content-Disposition: attachment; filename="' . basename($pdf['pdf_filename']) . '"');
                    header('Content-Length: ' . filesize($file_path));
                    header('Cache-Control: no-cache, must-revalidate');
                    header('Pragma: public');
                    
                    // Clear output buffer
                    ob_end_clean();
                    
                    // Read and output file
                    readfile($file_path);
                    exit;
                } else {
                    $error_message = 'File not found. Please contact your administrator.';
                }
            } else {
                $error_message = 'Unauthorized access or invalid agreement ID.';
            }
            $stmt->close();
        }
    }
}

// Handle view request (inline PDF viewing)
if (isset($_GET['view']) && isset($_GET['id'])) {
    $agreement_id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT);
    $id_number_verify = trim($_GET['verify'] ?? '');
    
    if ($agreement_id && $id_number_verify) {
        // Verify the ID number matches the agreement
        $stmt = $conn->prepare("
            SELECT 
                sap.pdf_path,
                sap.pdf_filename,
                sap.learner_id
            FROM stored_agreement_pdfs sap
            JOIN learnerdetails ld ON sap.learner_id = ld.LearnerID
            WHERE sap.id = ? AND ld.IDNumber = ?
        ");
        
        if ($stmt) {
            $stmt->bind_param('is', $agreement_id, $id_number_verify);
            $stmt->execute();
            $result = $stmt->get_result();
            
            if ($result->num_rows > 0) {
                $pdf = $result->fetch_assoc();
                $file_path = $pdf['pdf_path'];
                
                // Check if file exists
                if (file_exists($file_path)) {
                    // Set headers for inline viewing
                    header('Content-Type: application/pdf');
                    header('Content-Disposition: inline; filename="' . basename($pdf['pdf_filename']) . '"');
                    header('Content-Length: ' . filesize($file_path));
                    header('Cache-Control: no-cache, must-revalidate');
                    header('Pragma: public');
                    
                    // Clear output buffer
                    ob_end_clean();
                    
                    // Read and output file
                    readfile($file_path);
                    exit;
                } else {
                    $error_message = 'File not found. Please contact your administrator.';
                }
            } else {
                $error_message = 'Unauthorized access or invalid agreement ID.';
            }
            $stmt->close();
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Learner Agreement Portal</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .container {
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            max-width: 900px;
            width: 100%;
            overflow: hidden;
        }

        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }

        .header h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }

        .header p {
            font-size: 14px;
            opacity: 0.9;
        }

        .content {
            padding: 40px;
        }

        .search-form {
            margin-bottom: 30px;
        }

        .form-group {
            margin-bottom: 20px;
        }

        .form-group label {
            display: block;
            font-weight: 600;
            margin-bottom: 8px;
            color: #333;
        }

        .form-group input {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }

        .form-group input:focus {
            outline: none;
            border-color: #667eea;
        }

        .btn {
            display: inline-block;
            padding: 12px 30px;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
            text-decoration: none;
            text-align: center;
        }

        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            width: 100%;
        }

        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }

        .btn-secondary {
            background: #4caf50;
            color: white;
            margin-right: 10px;
        }

        .btn-secondary:hover {
            background: #45a049;
        }

        .btn-info {
            background: #2196F3;
            color: white;
        }

        .btn-info:hover {
            background: #0b7dda;
        }

        .alert {
            padding: 15px 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .alert-error {
            background: #fee;
            color: #c33;
            border-left: 4px solid #c33;
        }

        .alert-success {
            background: #efe;
            color: #3c3;
            border-left: 4px solid #3c3;
        }

        .alert-info {
            background: #e3f2fd;
            color: #1976d2;
            border-left: 4px solid #1976d2;
        }

        .agreements-list {
            margin-top: 30px;
        }

        .agreement-card {
            background: #f9f9f9;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 15px;
            transition: all 0.3s;
        }

        .agreement-card:hover {
            border-color: #667eea;
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.2);
        }

        .agreement-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
            flex-wrap: wrap;
            gap: 10px;
        }

        .agreement-title {
            font-size: 18px;
            font-weight: 600;
            color: #333;
        }

        .agreement-date {
            font-size: 14px;
            color: #666;
        }

        .agreement-details {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 15px;
        }

        .detail-item {
            display: flex;
            flex-direction: column;
        }

        .detail-label {
            font-size: 12px;
            color: #888;
            margin-bottom: 4px;
        }

        .detail-value {
            font-size: 14px;
            font-weight: 600;
            color: #333;
        }

        .agreement-actions {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }

        .icon {
            font-size: 20px;
        }

        .empty-state {
            text-align: center;
            padding: 40px 20px;
            color: #888;
        }

        .empty-state-icon {
            font-size: 64px;
            margin-bottom: 20px;
            opacity: 0.5;
        }

        @media (max-width: 768px) {
            .content {
                padding: 20px;
            }

            .header h1 {
                font-size: 24px;
            }

            .agreement-actions {
                flex-direction: column;
            }

            .btn {
                width: 100%;
                margin-right: 0 !important;
            }
        }

        .instructions {
            background: #f0f4ff;
            border-left: 4px solid #667eea;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 25px;
        }

        .instructions h3 {
            color: #667eea;
            margin-bottom: 10px;
            font-size: 16px;
        }

        .instructions ul {
            margin-left: 20px;
            color: #555;
        }

        .instructions li {
            margin-bottom: 5px;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📄 Learner Agreement Portal</h1>
            <p>Access and download your learner agreements</p>
        </div>

        <div class="content">
            <?php if (!$searched): ?>
                <div class="instructions">
                    <h3>How to Access Your Agreement:</h3>
                    <ul>
                        <li>Enter your 13-digit South African ID Number</li>
                        <li>Click "Search My Agreements"</li>
                        <li>View or download your agreement(s)</li>
                    </ul>
                </div>
            <?php endif; ?>

            <?php if ($error_message): ?>
                <div class="alert alert-error">
                    <span class="icon">⚠️</span>
                    <span><?php echo htmlspecialchars($error_message); ?></span>
                </div>
            <?php endif; ?>

            <?php if ($success_message): ?>
                <div class="alert alert-success">
                    <span class="icon">✅</span>
                    <span><?php echo htmlspecialchars($success_message); ?></span>
                </div>
            <?php endif; ?>

            <div class="search-form">
                <form method="POST" action="">
                    <div class="form-group">
                        <label for="id_number">ID Number</label>
                        <input 
                            type="text" 
                            id="id_number" 
                            name="id_number" 
                            placeholder="Enter your 13-digit ID Number"
                            maxlength="13"
                            pattern="[0-9]{13}"
                            value="<?php echo htmlspecialchars($id_number); ?>"
                            required
                        >
                    </div>
                    <button type="submit" name="search_agreements" class="btn btn-primary">
                        🔍 Search My Agreements
                    </button>
                </form>
            </div>

            <?php if ($searched && count($agreements) > 0): ?>
                <div class="agreements-list">
                    <h2 style="margin-bottom: 20px; color: #333;">Your Agreements</h2>
                    
                    <?php foreach ($agreements as $agreement): ?>
                        <div class="agreement-card">
                            <div class="agreement-header">
                                <div class="agreement-title">
                                    <?php echo htmlspecialchars($agreement['document_type']); ?>
                                </div>
                                <div class="agreement-date">
                                    Generated: <?php echo date('d M Y, H:i', strtotime($agreement['generated_date'])); ?>
                                </div>
                            </div>

                            <div class="agreement-details">
                                <div class="detail-item">
                                    <span class="detail-label">Learner Name</span>
                                    <span class="detail-value"><?php echo htmlspecialchars($agreement['learner_name']); ?></span>
                                </div>
                                <div class="detail-item">
                                    <span class="detail-label">File Name</span>
                                    <span class="detail-value"><?php echo htmlspecialchars($agreement['pdf_filename']); ?></span>
                                </div>
                                <div class="detail-item">
                                    <span class="detail-label">File Size</span>
                                    <span class="detail-value">
                                        <?php echo number_format($agreement['file_size'] / 1024, 2); ?> KB
                                    </span>
                                </div>
                                <?php if ($agreement['year'] && $agreement['month']): ?>
                                <div class="detail-item">
                                    <span class="detail-label">Period</span>
                                    <span class="detail-value">
                                        <?php echo date('F Y', mktime(0, 0, 0, $agreement['month'], 1, $agreement['year'])); ?>
                                    </span>
                                </div>
                                <?php endif; ?>
                            </div>

                            <div class="agreement-actions">
                                <a href="?view=1&id=<?php echo $agreement['id']; ?>&verify=<?php echo urlencode($id_number); ?>" 
                                   class="btn btn-info" 
                                   target="_blank">
                                    👁️ View Agreement
                                </a>
                                <a href="?download=1&id=<?php echo $agreement['id']; ?>&verify=<?php echo urlencode($id_number); ?>" 
                                   class="btn btn-secondary">
                                    📥 Download PDF
                                </a>
                            </div>
                        </div>
                    <?php endforeach; ?>
                </div>
            <?php elseif ($searched && count($agreements) === 0 && !$error_message): ?>
                <div class="empty-state">
                    <div class="empty-state-icon">📭</div>
                    <h3>No Agreements Found</h3>
                    <p>We couldn't find any agreements for the provided ID Number.</p>
                    <p style="margin-top: 10px;">Please contact your administrator if you believe this is an error.</p>
                </div>
            <?php endif; ?>
        </div>
    </div>

    <script>
        // Format ID number input to accept only numbers
        document.getElementById('id_number').addEventListener('input', function(e) {
            this.value = this.value.replace(/[^0-9]/g, '');
        });

        // Validate ID number length before submission
        document.querySelector('form').addEventListener('submit', function(e) {
            const idNumber = document.getElementById('id_number').value;
            if (idNumber.length !== 13) {
                e.preventDefault();
                alert('Please enter a valid 13-digit ID Number.');
            }
        });
    </script>
</body>
</html>
