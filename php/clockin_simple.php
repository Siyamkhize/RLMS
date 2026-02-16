<?php
// Simple working clockin.php script
header('Content-Type: application/json');

// Set timezone
date_default_timezone_set('Africa/Johannesburg');

// Error reporting
ini_set('display_errors', 0);
error_reporting(E_ALL);

try {
    include 'connection.php';
    
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed");
    }

    $response = array("success" => false, "message" => "Unknown error occurred");

    if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_POST['clock_in'])) {
        
        // Extract and validate input data
        $learnerID = $_POST['LearnerID'] ?? null;
        $currentTime = date('Y-m-d H:i:s');
        $currentDate = date('Y-m-d');
        $isSynced = isset($_POST['isSynced']) ? (int)$_POST['isSynced'] : 0;
        $userLatitude = isset($_POST['user_latitude']) ? floatval($_POST['user_latitude']) : 0.0;
        $userLongitude = isset($_POST['user_longitude']) ? floatval($_POST['user_longitude']) : 0.0;
        $userAccuracy = isset($_POST['user_accuracy']) ? floatval($_POST['user_accuracy']) : 50.0;
        $classID = $_POST['classID'] ?? null;

        // Log the attempt
        file_put_contents('debug_clockin.log', "Clock-in attempt: LearnerID=$learnerID, ClassID=$classID, Time=$currentTime" . PHP_EOL, FILE_APPEND);

        // Validate required fields
        if (empty($learnerID) || empty($classID)) {
            $response['message'] = "Missing required fields: LearnerID or ClassID";
            echo json_encode($response);
            exit;
        }

        // Check if learner exists
        $stmt = $conn->prepare("SELECT LearnerID FROM learnerdetails WHERE LearnerID = ?");
        $stmt->bind_param("i", $learnerID);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows == 0) {
            $response['message'] = "Learner not found";
            echo json_encode($response);
            $stmt->close();
            exit;
        }
        $stmt->close();

        // Check if already clocked in today
        $stmt = $conn->prepare("SELECT clock_in_time, clock_out_time, contact_time FROM learner_clocking WHERE LearnerID = ? AND clock_date = ?");
        $stmt->bind_param("is", $learnerID, $currentDate);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows > 0) {
            $row = $result->fetch_assoc();
            if (!empty($row['clock_in_time'])) {
                $response['success'] = true;
                $response['message'] = "Already clocked in today at " . $row['clock_in_time'];
                $response['clock_in_time'] = $row['clock_in_time'];
                $response['clock_out_time'] = $row['clock_out_time'];
                $response['contact_time'] = $row['contact_time'];
                echo json_encode($response);
                $stmt->close();
                exit;
            }
        }
        $stmt->close();

        // Insert new clock-in record
        $stmt = $conn->prepare("INSERT INTO learner_clocking (LearnerID, clock_date, clock_in_time, synced, user_latitude, user_longitude, user_accuracy) VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE clock_in_time = VALUES(clock_in_time), synced = VALUES(synced), user_latitude = VALUES(user_latitude), user_longitude = VALUES(user_longitude), user_accuracy = VALUES(user_accuracy)");
        
        if (!$stmt) {
            $response['message'] = "Database prepare error: " . $conn->error;
            echo json_encode($response);
            exit;
        }

        $stmt->bind_param("issiddd", $learnerID, $currentDate, $currentTime, $isSynced, $userLatitude, $userLongitude, $userAccuracy);
        
        if ($stmt->execute()) {
            // Handle signature if provided
            $signatureSaved = true;
            if (isset($_POST['signature']) && !empty($_POST['signature'])) {
                try {
                    $signatureBase64 = preg_replace('#^data:image/\w+;base64,#i', '', $_POST['signature']);
                    $signatureImage = base64_decode($signatureBase64, true);
                    
                    if ($signatureImage !== false) {
                        $signatureFileName = "learner{$learnerID}_" . time() . ".png";
                        $signatureFilePath = "signatures/" . $signatureFileName;

                        // Create signatures directory if it doesn't exist
                        if (!is_dir('signatures')) {
                            mkdir('signatures', 0755, true);
                        }

                        if (file_put_contents($signatureFilePath, $signatureImage)) {
                            // Update the record with signature filename
                            $updateStmt = $conn->prepare("UPDATE learner_clocking SET signature = ? WHERE LearnerID = ? AND clock_date = ?");
                            $updateStmt->bind_param("sis", $signatureFileName, $learnerID, $currentDate);
                            $updateStmt->execute();
                            $updateStmt->close();
                        } else {
                            $signatureSaved = false;
                        }
                    } else {
                        $signatureSaved = false;
                    }
                } catch (Exception $e) {
                    $signatureSaved = false;
                    file_put_contents('debug_clockin.log', "Signature error: " . $e->getMessage() . PHP_EOL, FILE_APPEND);
                }
            }

            $response['success'] = true;
            $response['message'] = 'Clock-in successful' . ($signatureSaved ? '' : ' (signature not saved)');
            $response['clock_in_time'] = $currentTime;
            $response['clock_out_time'] = null;
            $response['contact_time'] = null;
            
            file_put_contents('debug_clockin.log', "Success: LearnerID=$learnerID clocked in at $currentTime" . PHP_EOL, FILE_APPEND);
            
        } else {
            $response['message'] = "Failed to record clock-in: " . $stmt->error;
            file_put_contents('debug_clockin.log', "Error: " . $stmt->error . PHP_EOL, FILE_APPEND);
        }

        $stmt->close();

    } else {
        $response['message'] = "Invalid request method or missing clock_in parameter";
    }

    echo json_encode($response);

} catch (Exception $e) {
    $errorResponse = [
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage()
    ];
    
    file_put_contents('debug_clockin.log', "Exception: " . $e->getMessage() . " in " . $e->getFile() . " at line " . $e->getLine() . PHP_EOL, FILE_APPEND);
    
    http_response_code(500);
    echo json_encode($errorResponse);
}

if (isset($conn)) {
    $conn->close();
}
?>
