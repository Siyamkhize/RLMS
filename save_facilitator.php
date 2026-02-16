<?php
// save_facilitator.php

include 'connection.php';

error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    echo json_encode(["success" => false, "message" => "Connection failed: " . $conn->connect_error]);
    exit();
}

$signatureDir = "facilitatorSignatures/";
$baseUrl = "https://rlms.mtltechnical.co.za/mobile";

if (!is_dir($signatureDir)) {
    mkdir($signatureDir, 0755, true);
}

$input = file_get_contents('php://input');
$data = json_decode($input, true);

error_log("Received data: " . print_r($data, true));

if (json_last_error() !== JSON_ERROR_NONE) {
    echo json_encode(["success" => false, "message" => "Invalid JSON data: " . json_last_error_msg()]);
    exit();
}

if (!isset($data['classID']) || empty($data['classID'])) {
    echo json_encode(["success" => false, "message" => "classID is required"]);
    exit();
}

$classID = $conn->real_escape_string($data['classID']);
$phoneNumber = isset($data['phoneNumber']) ? $conn->real_escape_string($data['phoneNumber']) : null;
$IDNumber = isset($data['IDNumber']) ? $conn->real_escape_string($data['IDNumber']) : null;
$assessorNo = isset($data['assessorNo']) ? $conn->real_escape_string($data['assessorNo']) : null;
$assessorExpiryDate = isset($data['assessorExpiryDate']) ? $conn->real_escape_string($data['assessorExpiryDate']) : null;
$f_signature_base64 = isset($data['f_signature']) ? $data['f_signature'] : null;

// Get facilitator_id
$facilitator_id = null;
$stmt = $conn->prepare("SELECT facilitator_id, f_signature FROM facilitator WHERE classID = ?");
$stmt->bind_param("s", $classID);
$stmt->execute();
$result = $stmt->get_result();
$oldSignaturePath = null;
if ($result->num_rows > 0) {
    $row = $result->fetch_assoc();
    $facilitator_id = $row['facilitator_id'];
    $oldSignaturePath = $row['f_signature'];
}
$stmt->close();

// Handle signature image
$signaturePath = null;
$signatureUrl = null;
if ($f_signature_base64 && !empty($f_signature_base64)) {
    try {
        $f_signature_base64 = preg_replace('#^data:image/\w+;base64,#i', '', $f_signature_base64);
        $signatureData = base64_decode($f_signature_base64);
        if ($signatureData === false) {
            echo json_encode(["success" => false, "message" => "Invalid base64 signature data"]);
            exit();
        }

        $imageInfo = getimagesizefromstring($signatureData);
        if ($imageInfo === false) {
            echo json_encode(["success" => false, "message" => "Invalid signature image format"]);
            exit();
        }

        $allowedTypes = ['image/png' => 'png', 'image/jpeg' => 'jpg', 'image/gif' => 'gif', 'image/webp' => 'webp'];
        $mimeType = $imageInfo['mime'];
        if (!isset($allowedTypes[$mimeType])) {
            echo json_encode(["success" => false, "message" => "Unsupported signature image format"]);
            exit();
        }

        $extension = $allowedTypes[$mimeType];
        $signatureImageName = time() . '_' . ($facilitator_id ?? $classID) . '_signature.' . $extension;
        $signaturePath = $signatureDir . $signatureImageName;

        if (file_put_contents($signaturePath, $signatureData) === false) {
            echo json_encode(["success" => false, "message" => "Failed to save signature image"]);
            exit();
        }

        chmod($signaturePath, 0644);
        $signatureUrl = $baseUrl . '/' . $signaturePath;

        error_log("Signature saved to: " . $signaturePath);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Error processing signature: " . $e->getMessage()]);
        exit();
    }
}

$exists = $facilitator_id !== null;

if ($exists) {
    // UPDATE operation for only selected fields
    $updateFields = [];
    $updateValues = [];
    $types = "";

    if ($phoneNumber !== null && $phoneNumber !== '') {
        $updateFields[] = "phoneNumber = ?";
        $updateValues[] = $phoneNumber;
        $types .= "s";
    }
    if ($IDNumber !== null && $IDNumber !== '') {
        $updateFields[] = "IDNumber = ?";
        $updateValues[] = $IDNumber;
        $types .= "s";
    }
    if ($assessorNo !== null && $assessorNo !== '') {
        $updateFields[] = "assessorNo = ?";
        $updateValues[] = $assessorNo;
        $types .= "s";
    }
    if ($assessorExpiryDate !== null && $assessorExpiryDate !== '') {
        $updateFields[] = "assessorExpiryDate = ?";
        $updateValues[] = $assessorExpiryDate;
        $types .= "s";
    }
    if ($signaturePath !== null) {
        $updateFields[] = "f_signature = ?";
        $updateValues[] = $signaturePath;
        $types .= "s";
    }

    if (!empty($updateFields)) {
        $sql = "UPDATE facilitator SET " . implode(", ", $updateFields) . " WHERE classID = ?";
        $updateValues[] = $classID;
        $types .= "s";

        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            echo json_encode(["success" => false, "message" => "SQL prepare error: " . $conn->error]);
            exit();
        }

        $stmt->bind_param($types, ...$updateValues);

        if ($stmt->execute()) {
            if ($signaturePath && $oldSignaturePath && $oldSignaturePath !== $signaturePath && file_exists($oldSignaturePath)) {
                unlink($oldSignaturePath);
            }
            echo json_encode([
                "success" => true,
                "message" => "Facilitator data updated successfully",
                "signature_url" => $signatureUrl,
                "affected_rows" => $stmt->affected_rows
            ], JSON_UNESCAPED_SLASHES);
        } else {
            if ($signaturePath && file_exists($signaturePath)) {
                unlink($signaturePath);
            }
            echo json_encode(["success" => false, "message" => "Database error: " . $stmt->error]);
        }
        $stmt->close();
    } else {
        echo json_encode(["success" => true, "message" => "No fields to update"]);
    }

} else {
    // INSERT operation
    $sql = "INSERT INTO facilitator (classID, phoneNumber, IDNumber, assessorNo, assessorExpiryDate, f_signature)
            VALUES (?, ?, ?, ?, ?, ?)";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        echo json_encode(["success" => false, "message" => "SQL prepare error: " . $conn->error]);
        exit();
    }

    $stmt->bind_param("ssssss", $classID, $phoneNumber, $IDNumber, $assessorNo, $assessorExpiryDate, $signaturePath);

    if ($stmt->execute()) {
        echo json_encode([
            "success" => true,
            "message" => "Facilitator data inserted successfully",
            "signature_url" => $signatureUrl,
            "facilitator_id" => $conn->insert_id
        ], JSON_UNESCAPED_SLASHES);
    } else {
        if ($signaturePath && file_exists($signaturePath)) {
            unlink($signaturePath);
        }
        echo json_encode(["success" => false, "message" => "Database error: " . $stmt->error]);
    }
    $stmt->close();
}

$conn->close();
?>
