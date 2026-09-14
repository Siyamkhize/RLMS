<?php
// Site Admin Management Backend
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
date_default_timezone_set('Africa/Johannesburg');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

try {
    include 'connection.php';
    
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed: " . ($conn->connect_error ?? "Connection not initialized"));
    }
    
    $response = array("success" => false, "message" => "Unknown error occurred");
    
    if ($_SERVER["REQUEST_METHOD"] == "GET") {
        $action = $_GET['action'] ?? '';
        
        switch ($action) {
            case 'list_site_admins':
                // Get all site administrators
                $sql = "SELECT 
                            admin_id,
                            first_name,
                            last_name,
                            email,
                            phone,
                            role,
                            status,
                            created_at,
                            updated_at,
                            last_login,
                            can_manage_sites,
                            can_assign_learners,
                            can_view_geofencing_logs,
                            assigned_sites
                        FROM site_admin 
                        ORDER BY created_at DESC";
                
                $result = $conn->query($sql);
                
                if ($result) {
                    $admins = [];
                    while ($row = $result->fetch_assoc()) {
                        $admins[] = $row;
                    }
                    
                    $response['success'] = true;
                    $response['admins'] = $admins;
                    $response['count'] = count($admins);
                    $response['message'] = 'Site administrators retrieved successfully';
                } else {
                    throw new Exception("Failed to retrieve site administrators: " . $conn->error);
                }
                break;
                
            case 'get_site_admin':
                $adminId = $_GET['admin_id'] ?? null;
                
                if (!$adminId) {
                    $response['message'] = 'Admin ID is required';
                    break;
                }
                
                $stmt = $conn->prepare("SELECT * FROM site_admin WHERE admin_id = ?");
                $stmt->bind_param("i", $adminId);
                
                if ($stmt->execute()) {
                    $result = $stmt->get_result();
                    $admin = $result->fetch_assoc();
                    
                    if ($admin) {
                        $response['success'] = true;
                        $response['admin'] = $admin;
                        $response['message'] = 'Site administrator retrieved successfully';
                    } else {
                        $response['message'] = 'Site administrator not found';
                    }
                } else {
                    throw new Exception("Failed to retrieve site administrator: " . $stmt->error);
                }
                $stmt->close();
                break;
                
            default:
                $response['message'] = 'Invalid action specified';
        }
    }
    
    if ($_SERVER["REQUEST_METHOD"] == "POST") {
        $action = $_POST['action'] ?? '';
        
        switch ($action) {
            case 'create_site_admin':
                // Validate required fields
                $firstName = trim($_POST['first_name'] ?? '');
                $lastName = trim($_POST['last_name'] ?? '');
                $email = trim($_POST['email'] ?? '');
                $password = $_POST['password'] ?? '';
                
                if (empty($firstName) || empty($lastName) || empty($email) || empty($password)) {
                    $response['message'] = 'First name, last name, email, and password are required';
                    break;
                }
                
                // Validate email format
                if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                    $response['message'] = 'Invalid email format';
                    break;
                }
                
                // Check if email already exists
                $checkStmt = $conn->prepare("SELECT admin_id FROM site_admin WHERE email = ?");
                $checkStmt->bind_param("s", $email);
                $checkStmt->execute();
                $existingAdmin = $checkStmt->get_result()->fetch_assoc();
                $checkStmt->close();
                
                if ($existingAdmin) {
                    $response['message'] = 'Email address already exists';
                    break;
                }
                
                // Get other form data
                $phone = trim($_POST['phone'] ?? '');
                $status = $_POST['status'] ?? 'active';
                $canManageSites = isset($_POST['can_manage_sites']) ? 1 : 0;
                $canAssignLearners = isset($_POST['can_assign_learners']) ? 1 : 0;
                $canViewGeofencingLogs = isset($_POST['can_view_geofencing_logs']) ? 1 : 0;
                
                // Process assigned sites
                $assignedSites = $_POST['assigned_sites'] ?? '[]';
                $assignedSitesArray = json_decode($assignedSites, true);
                
                // If no sites selected, set to null (means all sites)
                $assignedSitesJson = empty($assignedSitesArray) ? null : json_encode($assignedSitesArray);
                
                // Hash password
                $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
                
                // Insert new site admin
                $stmt = $conn->prepare("
                    INSERT INTO site_admin (
                        first_name, 
                        last_name, 
                        email, 
                        password, 
                        phone, 
                        status, 
                        can_manage_sites, 
                        can_assign_learners, 
                        can_view_geofencing_logs, 
                        assigned_sites
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ");
                
                $stmt->bind_param(
                    "ssssssiiis", 
                    $firstName, 
                    $lastName, 
                    $email, 
                    $hashedPassword, 
                    $phone, 
                    $status, 
                    $canManageSites, 
                    $canAssignLearners, 
                    $canViewGeofencingLogs, 
                    $assignedSitesJson
                );
                
                if ($stmt->execute()) {
                    $adminId = $conn->insert_id;
                    
                    $response['success'] = true;
                    $response['message'] = "Site admin '$firstName $lastName' created successfully";
                    $response['admin_id'] = $adminId;
                    $response['assigned_sites_count'] = count($assignedSitesArray);
                } else {
                    throw new Exception("Failed to create site admin: " . $stmt->error);
                }
                $stmt->close();
                break;
                
            case 'update_site_admin':
                $adminId = $_POST['admin_id'] ?? null;
                
                if (!$adminId) {
                    $response['message'] = 'Admin ID is required';
                    break;
                }
                
                // Validate required fields
                $firstName = trim($_POST['first_name'] ?? '');
                $lastName = trim($_POST['last_name'] ?? '');
                $email = trim($_POST['email'] ?? '');
                
                if (empty($firstName) || empty($lastName) || empty($email)) {
                    $response['message'] = 'First name, last name, and email are required';
                    break;
                }
                
                // Validate email format
                if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                    $response['message'] = 'Invalid email format';
                    break;
                }
                
                // Check if email already exists for another admin
                $checkStmt = $conn->prepare("SELECT admin_id FROM site_admin WHERE email = ? AND admin_id != ?");
                $checkStmt->bind_param("si", $email, $adminId);
                $checkStmt->execute();
                $existingAdmin = $checkStmt->get_result()->fetch_assoc();
                $checkStmt->close();
                
                if ($existingAdmin) {
                    $response['message'] = 'Email address already exists for another admin';
                    break;
                }
                
                // Get other form data
                $phone = trim($_POST['phone'] ?? '');
                $status = $_POST['status'] ?? 'active';
                $canManageSites = isset($_POST['can_manage_sites']) ? 1 : 0;
                $canAssignLearners = isset($_POST['can_assign_learners']) ? 1 : 0;
                $canViewGeofencingLogs = isset($_POST['can_view_geofencing_logs']) ? 1 : 0;
                
                // Process assigned sites
                $assignedSites = $_POST['assigned_sites'] ?? '[]';
                $assignedSitesArray = json_decode($assignedSites, true);
                $assignedSitesJson = empty($assignedSitesArray) ? null : json_encode($assignedSitesArray);
                
                // Update site admin (without password)
                $stmt = $conn->prepare("
                    UPDATE site_admin SET 
                        first_name = ?, 
                        last_name = ?, 
                        email = ?, 
                        phone = ?, 
                        status = ?, 
                        can_manage_sites = ?, 
                        can_assign_learners = ?, 
                        can_view_geofencing_logs = ?, 
                        assigned_sites = ?,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE admin_id = ?
                ");
                
                $stmt->bind_param(
                    "sssssiiiisi", 
                    $firstName, 
                    $lastName, 
                    $email, 
                    $phone, 
                    $status, 
                    $canManageSites, 
                    $canAssignLearners, 
                    $canViewGeofencingLogs, 
                    $assignedSitesJson,
                    $adminId
                );
                
                if ($stmt->execute()) {
                    if ($stmt->affected_rows > 0) {
                        $response['success'] = true;
                        $response['message'] = "Site admin '$firstName $lastName' updated successfully";
                    } else {
                        $response['success'] = true;
                        $response['message'] = "No changes made to site admin";
                    }
                } else {
                    throw new Exception("Failed to update site admin: " . $stmt->error);
                }
                $stmt->close();
                break;
                
            case 'toggle_status':
                $adminId = $_POST['admin_id'] ?? null;
                $newStatus = $_POST['status'] ?? null;
                
                if (!$adminId || !$newStatus) {
                    $response['message'] = 'Admin ID and status are required';
                    break;
                }
                
                if (!in_array($newStatus, ['active', 'inactive'])) {
                    $response['message'] = 'Invalid status. Must be active or inactive';
                    break;
                }
                
                $stmt = $conn->prepare("UPDATE site_admin SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE admin_id = ?");
                $stmt->bind_param("si", $newStatus, $adminId);
                
                if ($stmt->execute()) {
                    if ($stmt->affected_rows > 0) {
                        $response['success'] = true;
                        $response['message'] = "Site admin status updated to $newStatus";
                    } else {
                        $response['message'] = 'Site admin not found or no changes made';
                    }
                } else {
                    throw new Exception("Failed to update status: " . $stmt->error);
                }
                $stmt->close();
                break;
                
            case 'delete_site_admin':
                $adminId = $_POST['admin_id'] ?? null;
                
                if (!$adminId) {
                    $response['message'] = 'Admin ID is required';
                    break;
                }
                
                // Get admin details before deletion
                $getStmt = $conn->prepare("SELECT first_name, last_name FROM site_admin WHERE admin_id = ?");
                $getStmt->bind_param("i", $adminId);
                $getStmt->execute();
                $adminData = $getStmt->get_result()->fetch_assoc();
                $getStmt->close();
                
                if (!$adminData) {
                    $response['message'] = 'Site admin not found';
                    break;
                }
                
                // Delete site admin
                $stmt = $conn->prepare("DELETE FROM site_admin WHERE admin_id = ?");
                $stmt->bind_param("i", $adminId);
                
                if ($stmt->execute()) {
                    if ($stmt->affected_rows > 0) {
                        $response['success'] = true;
                        $response['message'] = "Site admin '{$adminData['first_name']} {$adminData['last_name']}' deleted successfully";
                    } else {
                        $response['message'] = 'Site admin not found';
                    }
                } else {
                    throw new Exception("Failed to delete site admin: " . $stmt->error);
                }
                $stmt->close();
                break;
                
            case 'change_password':
                $adminId = $_POST['admin_id'] ?? null;
                $newPassword = $_POST['new_password'] ?? '';
                
                if (!$adminId || empty($newPassword)) {
                    $response['message'] = 'Admin ID and new password are required';
                    break;
                }
                
                if (strlen($newPassword) < 6) {
                    $response['message'] = 'Password must be at least 6 characters long';
                    break;
                }
                
                $hashedPassword = password_hash($newPassword, PASSWORD_DEFAULT);
                
                $stmt = $conn->prepare("UPDATE site_admin SET password = ?, updated_at = CURRENT_TIMESTAMP WHERE admin_id = ?");
                $stmt->bind_param("si", $hashedPassword, $adminId);
                
                if ($stmt->execute()) {
                    if ($stmt->affected_rows > 0) {
                        $response['success'] = true;
                        $response['message'] = "Password updated successfully";
                    } else {
                        $response['message'] = 'Site admin not found';
                    }
                } else {
                    throw new Exception("Failed to update password: " . $stmt->error);
                }
                $stmt->close();
                break;
                
            default:
                $response['message'] = 'Invalid action specified';
        }
    }
    
} catch (Exception $e) {
    $response = [
        'success' => false,
        'message' => 'Error: ' . $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ];
    error_log("ERROR in manage_site_admins.php: " . $e->getMessage());
}

echo json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
?>