<?php
require 'sdp_header.php';

// Set user_role from session for compatibility
$user_role = $_SESSION['role'] ?? '';

// Allow both Admin and SDP roles to access this page
$allowed_roles = ['Admin', 'SDP', 'admin', 'sdp'];
if (!in_array($user_role, $allowed_roles)) {
    header("Location: index.php");
    exit();
}

// Handle different user types - for now, treat Admin users as having access to all SDPs
if (in_array($user_role, ['SDP', 'sdp'])) {
    // SDP users use their session SDP name
    $user_sdp_name = $sdp_name;
} else {
    // Admin users can see all SDPs - we'll use the SDP name from the header
    $user_sdp_name = $sdp_name;
}

// Handle class assignment
$success_message = $error_message = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['assign_class'])) {
    $learner_id = $_POST['learner_id'] ?? '';
    $class_id = $_POST['class_id'] ?? '';
    
    if (!empty($learner_id) && !empty($class_id)) {
        try {
            $update_sql = "UPDATE learnerdetails SET classID = ? WHERE LearnerID = ?";
            $update_stmt = $conn->prepare($update_sql);
            $update_stmt->bind_param('ii', $class_id, $learner_id);
            
            if ($update_stmt->execute()) {
                $success_message = "Learner successfully assigned to class!";
            } else {
                $error_message = "Failed to assign learner to class.";
            }
            $update_stmt->close();
        } catch (Exception $e) {
            $error_message = "Error: " . $e->getMessage();
        }
    } else {
        $error_message = "Please select a class.";
    }
}

// Handle bulk class assignment
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['bulk_assign'])) {
    $selected_learners = $_POST['selected_learners'] ?? [];
    $bulk_class_id = $_POST['bulk_class_id'] ?? '';
    
    if (!empty($selected_learners) && !empty($bulk_class_id)) {
        try {
            $success_count = 0;
            $error_count = 0;
            
            $update_sql = "UPDATE learnerdetails SET classID = ? WHERE LearnerID = ?";
            $update_stmt = $conn->prepare($update_sql);
            
            foreach ($selected_learners as $learner_id) {
                $update_stmt->bind_param('ii', $bulk_class_id, $learner_id);
                if ($update_stmt->execute()) {
                    $success_count++;
                } else {
                    $error_count++;
                }
            }
            $update_stmt->close();
            
            if ($success_count > 0) {
                $success_message = "Successfully assigned {$success_count} learner(s) to class!";
                if ($error_count > 0) {
                    $success_message .= " ({$error_count} failed)";
                }
            } else {
                $error_message = "Failed to assign learners to class.";
            }
        } catch (Exception $e) {
            $error_message = "Error: " . $e->getMessage();
        }
    } else {
        $error_message = "Please select learners and a class for bulk assignment.";
    }
}

// Get filter parameters
$site_filter = $_GET['site_id'] ?? 'all';
$district_filter = $_GET['district'] ?? 'all';
$municipality_filter = $_GET['municipality'] ?? 'all';
$ward_filter = $_GET['ward'] ?? 'all';
$councillor_filter = $_GET['councillor'] ?? 'all';
$search_term = $_GET['search'] ?? '';
$page = max(1, intval($_GET['page'] ?? 1));
$per_page = 25;
$offset = ($page - 1) * $per_page;

// Build WHERE clause for filters
$where_conditions = [];
$params = [];
$param_types = '';

// SDP filter (only for SDP users, admins see all)
if (in_array($user_role, ['SDP', 'sdp'])) {
    $where_conditions[] = "p.sdp_name = ?";
    $params[] = $user_sdp_name;
    $param_types .= 's';
}

// Site filter
if ($site_filter !== 'all') {
    $where_conditions[] = "s.siteID = ?";
    $params[] = $site_filter;
    $param_types .= 'i';
}

// District filter
if ($district_filter !== 'all') {
    $where_conditions[] = "ll.district_name = ?";
    $params[] = $district_filter;
    $param_types .= 's';
}

// Municipality filter
if ($municipality_filter !== 'all') {
    $where_conditions[] = "ll.local_municipality_name = ?";
    $params[] = $municipality_filter;
    $param_types .= 's';
}

// Ward filter
if ($ward_filter !== 'all') {
    $where_conditions[] = "la.Ward = ?";
    $params[] = $ward_filter;
    $param_types .= 's';
}

// Councillor filter
if ($councillor_filter !== 'all') {
    $where_conditions[] = "la.councillor = ?";
    $params[] = $councillor_filter;
    $param_types .= 's';
}

// Search filter
if (!empty($search_term)) {
    $where_conditions[] = "(ld.Name LIKE ? OR ld.Surname LIKE ? OR ld.IDNumber LIKE ?)";
    $search_param = "%$search_term%";
    $params[] = $search_param;
    $params[] = $search_param;
    $params[] = $search_param;
    $param_types .= 'sss';
}

$where_clause = !empty($where_conditions) ? 'WHERE ' . implode(' AND ', $where_conditions) : '';

// Get total count for pagination
$count_sql = "
    SELECT COUNT(DISTINCT ld.LearnerID) as total
    FROM learnerdetails ld
    LEFT JOIN class cl ON ld.classID = cl.class_id
    LEFT JOIN sites st ON cl.siteID = st.siteID
    LEFT JOIN project p ON st.project_id = p.project_id
    LEFT JOIN learner_assignments la ON ld.LearnerID = la.LearnerID
    LEFT JOIN (
        SELECT learner_id, 
               COUNT(*) as total_docs,
               SUM(CASE WHEN status = 'Approved' THEN 1 ELSE 0 END) as approved_docs
        FROM learner_document 
        GROUP BY learner_id
    ) doc_summary ON ld.LearnerID = doc_summary.learner_id
    WHERE doc_summary.total_docs > 0 
    AND doc_summary.total_docs = doc_summary.approved_docs
    AND ld.Email IS NOT NULL AND ld.Email != '' 
    AND ld.DateOfBirth IS NOT NULL 
    AND ld.Gender IS NOT NULL AND ld.Gender != ''
";

// Add additional WHERE conditions if they exist
// Build base WHERE conditions for approved learners without classes
$base_conditions = [
    "doc_summary.total_docs > 0",
    "doc_summary.total_docs = doc_summary.approved_docs",
    "ld.Email IS NOT NULL AND ld.Email != ''",
    "ld.DateOfBirth IS NOT NULL",
    "ld.Gender IS NOT NULL AND ld.Gender != ''",
    "(ld.classID IS NULL OR ld.classID = 0 OR ld.classID = '')"
];

// Add filter conditions if they exist
$all_conditions = array_merge($where_conditions, $base_conditions);
$where_clause = 'WHERE ' . implode(' AND ', $all_conditions);

// Get total count for pagination
$count_sql = "
    SELECT COUNT(DISTINCT ld.LearnerID) as total
    FROM learnerdetails ld
    LEFT JOIN learner_assignments la ON ld.LearnerID = la.LearnerID
    LEFT JOIN project p ON la.projectID = p.project_id
    LEFT JOIN sites s ON p.project_id = s.project_id
    LEFT JOIN learner_location ll ON ld.LearnerID = ll.learner_id
    LEFT JOIN (
        SELECT 
            learner_id, 
            COUNT(*) as total_docs,
            SUM(CASE WHEN status = 'Approved' THEN 1 ELSE 0 END) as approved_docs
        FROM learner_document 
        GROUP BY learner_id
    ) doc_summary ON ld.LearnerID = doc_summary.learner_id
    $where_clause
";

$count_stmt = $conn->prepare($count_sql);
if (!empty($params)) {
    $count_stmt->bind_param($param_types, ...$params);
}
$count_stmt->execute();
$total_records = $count_stmt->get_result()->fetch_assoc()['total'];
$total_pages = ceil($total_records / $per_page);
$count_stmt->close();

// Main query to get approved learners - FIXED TO AVOID DUPLICATES
$sql = "
    SELECT 
        ld.LearnerID, 
        ld.Name, 
        ld.Surname, 
        ld.IDNumber,
        ld.PhoneNumber,
        ld.Email,
        ld.classID,
        MAX(la.Ward) as Ward,
        MAX(la.councillor) as councillor,
        MAX(ll.district_name) as district_name,
        MAX(ll.local_municipality_name) as local_municipality_name,
        MAX(s.siteID) as siteID,
        MAX(s.siteName) as siteName,
        MAX(p.sdp_name) as sdp_name,
        MAX(doc_summary.total_docs) as total_docs,
        MAX(doc_summary.approved_docs) as approved_docs,
        MAX(cl.className) as className
    FROM learnerdetails ld
    LEFT JOIN learner_assignments la ON ld.LearnerID = la.LearnerID
    LEFT JOIN project p ON la.projectID = p.project_id
    LEFT JOIN sites s ON p.project_id = s.project_id
    LEFT JOIN learner_location ll ON ld.LearnerID = ll.learner_id
    LEFT JOIN class cl ON ld.classID = cl.classID
    LEFT JOIN (
        SELECT 
            learner_id, 
            COUNT(*) as total_docs,
            SUM(CASE WHEN status = 'Approved' THEN 1 ELSE 0 END) as approved_docs
        FROM learner_document 
        GROUP BY learner_id
    ) doc_summary ON ld.LearnerID = doc_summary.learner_id
    $where_clause
    GROUP BY ld.LearnerID, ld.Name, ld.Surname, ld.IDNumber, ld.PhoneNumber, ld.Email, ld.classID
    ORDER BY ld.LearnerID DESC
    LIMIT ? OFFSET ?
";

$stmt = $conn->prepare($sql);

// Create separate parameter arrays for main query
$main_params = $params; // Copy the filter parameters
$main_params[] = $per_page;
$main_params[] = $offset;
$main_param_types = $param_types . 'ii';

// Always bind parameters (filter params + pagination params)
$stmt->bind_param($main_param_types, ...$main_params);
$stmt->execute();
$learners = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
$stmt->close();

// Get available sites for filter dropdown
if (in_array($user_role, ['SDP', 'sdp'])) {
    // SDP users see only their sites
    $sites_sql = "SELECT DISTINCT s.siteID, s.siteName 
                  FROM sites s 
                  LEFT JOIN project p ON s.project_id = p.project_id 
                  WHERE p.sdp_name = ? 
                  ORDER BY s.siteName";
    $sites_stmt = $conn->prepare($sites_sql);
    $sites_stmt->bind_param('s', $user_sdp_name);
} else {
    // Admin users see all sites
    $sites_sql = "SELECT DISTINCT siteID, siteName FROM sites ORDER BY siteName";
    $sites_stmt = $conn->prepare($sites_sql);
}
$sites_stmt->execute();
$sites = $sites_stmt->get_result()->fetch_all(MYSQLI_ASSOC);
$sites_stmt->close();

// Get classes for each site (for dropdowns)
$classes_by_site = [];
foreach ($sites as $site) {
    $classes_sql = "SELECT c.classID, c.className 
                    FROM class c 
                    WHERE c.siteID = ? 
                    ORDER BY c.className";
    $classes_stmt = $conn->prepare($classes_sql);
    $classes_stmt->bind_param('i', $site['siteID']);
    $classes_stmt->execute();
    $classes_by_site[$site['siteID']] = $classes_stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $classes_stmt->close();
}

// If a specific site is selected, get classes for that site only
$selected_site_classes = [];
if ($site_filter !== 'all') {
    $selected_site_classes = $classes_by_site[$site_filter] ?? [];
}

// Get location filter options
$districts = [];
$municipalities = [];
$wards = [];
$councillors = [];

try {
    // Get districts
    if (in_array($user_role, ['SDP', 'sdp'])) {
        $districts_sql = "SELECT DISTINCT ll.district_name 
                         FROM learner_location ll
                         LEFT JOIN learner_assignments la ON ll.learner_id = la.LearnerID
                         LEFT JOIN project p ON la.projectID = p.project_id 
                         WHERE p.sdp_name = ? AND ll.district_name IS NOT NULL AND ll.district_name != '' 
                         ORDER BY ll.district_name";
        $districts_stmt = $conn->prepare($districts_sql);
        $districts_stmt->bind_param('s', $user_sdp_name);
    } else {
        $districts_sql = "SELECT DISTINCT district_name FROM learner_location WHERE district_name IS NOT NULL AND district_name != '' ORDER BY district_name";
        $districts_stmt = $conn->prepare($districts_sql);
    }
    $districts_stmt->execute();
    $districts_result = $districts_stmt->get_result();
    while ($row = $districts_result->fetch_assoc()) {
        $districts[] = $row['district_name'];
    }
    $districts_stmt->close();

    // Get municipalities
    if (in_array($user_role, ['SDP', 'sdp'])) {
        $municipalities_sql = "SELECT DISTINCT ll.local_municipality_name 
                              FROM learner_location ll
                              LEFT JOIN learner_assignments la ON ll.learner_id = la.LearnerID
                              LEFT JOIN project p ON la.projectID = p.project_id 
                              WHERE p.sdp_name = ? AND ll.local_municipality_name IS NOT NULL AND ll.local_municipality_name != '' 
                              ORDER BY ll.local_municipality_name";
        $municipalities_stmt = $conn->prepare($municipalities_sql);
        $municipalities_stmt->bind_param('s', $user_sdp_name);
    } else {
        $municipalities_sql = "SELECT DISTINCT local_municipality_name FROM learner_location WHERE local_municipality_name IS NOT NULL AND local_municipality_name != '' ORDER BY local_municipality_name";
        $municipalities_stmt = $conn->prepare($municipalities_sql);
    }
    $municipalities_stmt->execute();
    $municipalities_result = $municipalities_stmt->get_result();
    while ($row = $municipalities_result->fetch_assoc()) {
        $municipalities[] = $row['local_municipality_name'];
    }
    $municipalities_stmt->close();

    // Get wards
    if (in_array($user_role, ['SDP', 'sdp'])) {
        $wards_sql = "SELECT DISTINCT la.Ward 
                     FROM learner_assignments la 
                     LEFT JOIN project p ON la.projectID = p.project_id 
                     WHERE p.sdp_name = ? AND la.Ward IS NOT NULL AND la.Ward != '' 
                     ORDER BY la.Ward";
        $wards_stmt = $conn->prepare($wards_sql);
        $wards_stmt->bind_param('s', $user_sdp_name);
    } else {
        $wards_sql = "SELECT DISTINCT Ward FROM learner_assignments WHERE Ward IS NOT NULL AND Ward != '' ORDER BY Ward";
        $wards_stmt = $conn->prepare($wards_sql);
    }
    $wards_stmt->execute();
    $wards_result = $wards_stmt->get_result();
    while ($row = $wards_result->fetch_assoc()) {
        $wards[] = $row['Ward'];
    }
    $wards_stmt->close();

    // Get councillors
    if (in_array($user_role, ['SDP', 'sdp'])) {
        $councillors_sql = "SELECT DISTINCT la.councillor 
                           FROM learner_assignments la 
                           LEFT JOIN project p ON la.projectID = p.project_id 
                           WHERE p.sdp_name = ? AND la.councillor IS NOT NULL AND la.councillor != '' 
                           ORDER BY la.councillor";
        $councillors_stmt = $conn->prepare($councillors_sql);
        $councillors_stmt->bind_param('s', $user_sdp_name);
    } else {
        $councillors_sql = "SELECT DISTINCT councillor FROM learner_assignments WHERE councillor IS NOT NULL AND councillor != '' ORDER BY councillor";
        $councillors_stmt = $conn->prepare($councillors_sql);
    }
    $councillors_stmt->execute();
    $councillors_result = $councillors_stmt->get_result();
    while ($row = $councillors_result->fetch_assoc()) {
        $councillors[] = $row['councillor'];
    }
    $councillors_stmt->close();

} catch (Exception $e) {
    error_log("Error fetching location filters: " . $e->getMessage());
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Unassigned Approved Learners - Class Assignment</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/@mdi/font@7.4.47/css/materialdesignicons.min.css" rel="stylesheet">
</head>

<style>
/* Force layout fix with highest priority */
body {
    margin: 0;
    padding: 0;
}

.container-fluid.page-content {
    background: linear-gradient(135deg, #f8fafc 0%, #e3e9f7 100%);
    min-height: 100vh;
    margin-left: 300px !important;
    width: calc(100% - 300px) !important;
    padding: 20px !important;
}

/* Mobile responsive */
@media (max-width: 768px) {
    .container-fluid.page-content {
        margin-left: 0 !important;
        width: 100% !important;
        padding: 15px !important;
    }
}

.stats-card {
    background: linear-gradient(135deg, #28a745 0%, #20c997 100%);
    color: white;
    border-radius: 15px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 4px 15px rgba(0,0,0,0.1);
}

.filter-card {
    background: white;
    border-radius: 15px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

.learner-card {
    background: white;
    border-radius: 10px;
    padding: 20px;
    margin-bottom: 15px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    border-left: 4px solid #28a745;
}

.approved-badge {
    background: #d4edda;
    color: #155724;
    padding: 4px 12px;
    border-radius: 15px;
    font-size: 0.8rem;
    font-weight: 600;
}

.class-assignment {
    background: #f8f9fa;
    border-radius: 8px;
    padding: 15px;
    margin-top: 10px;
}

.current-class {
    background: #e7f3ff;
    color: #0066cc;
    padding: 4px 12px;
    border-radius: 15px;
    font-size: 0.8rem;
    font-weight: 600;
}

.bulk-assignment-card {
    background: #f8f9ff;
    border: 2px dashed #6c757d;
    border-radius: 15px;
    padding: 20px;
    margin-bottom: 20px;
}

.learner-checkbox {
    transform: scale(1.2);
    margin-right: 10px;
}

.learner-card.selected {
    border-left-color: #007bff;
    background: #f8f9ff;
}

#bulkAssignBtn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}
</style>

<!-- Body content starts here -->
<div class="container-fluid">
  <div class="d-flex flex-column-reverse">
    <div class="content-wrapper w-100">
      <div class="container-fluid page-content">
        <div class="row">
          <div class="col-12">
        
        <!-- Header -->
        <div class="d-flex justify-content-between align-items-center mb-4">
            <div>
                <h2 class="mb-1">Unassigned Approved Learners - Class Assignment</h2>
                <p class="text-muted">Assign approved learners without classes to classes within their sites</p>
            </div>
        </div>

        <!-- Success/Error Messages -->
        <?php if ($success_message): ?>
            <div class="alert alert-success alert-dismissible fade show" role="alert">
                <i class="mdi mdi-check-circle me-2"></i>
                <?php echo htmlspecialchars($success_message); ?>
                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
            </div>
        <?php endif; ?>
        <?php if ($error_message): ?>
            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                <i class="mdi mdi-alert-circle me-2"></i>
                <?php echo htmlspecialchars($error_message); ?>
                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
            </div>
        <?php endif; ?>

        <!-- Statistics Card -->
        <div class="stats-card">
            <div class="row text-center">
                <div class="col-md-6">
                    <h3 class="mb-1"><?php echo number_format($total_records); ?></h3>
                    <p class="mb-0">Unassigned Approved Learners</p>
                </div>
                <div class="col-md-6">
                    <h3 class="mb-1"><?php echo count($sites); ?></h3>
                    <p class="mb-0">Active Sites</p>
                </div>
            </div>
        </div>

        <!-- Filters -->
        <div class="filter-card">
            <h5 class="mb-3"><i class="mdi mdi-filter me-2"></i>Filters</h5>
            <form method="GET" class="row g-3">
                <div class="col-md-6">
                    <label for="search" class="form-label">Search Unassigned Approved Learners</label>
                    <div class="input-group">
                        <input type="text" name="search" id="search" class="form-control" placeholder="Search by Name, Surname, or ID Number..." value="<?php echo htmlspecialchars($search_term); ?>">
                        <button type="submit" class="btn btn-primary">
                            <i class="mdi mdi-magnify me-1"></i>Search
                        </button>
                    </div>
                </div>
                <div class="col-md-3">
                    <label for="site_id" class="form-label">Site</label>
                    <select name="site_id" id="site_id" class="form-select">
                        <option value="all">All Sites</option>
                        <?php foreach ($sites as $site): ?>
                            <option value="<?php echo $site['siteID']; ?>" <?php echo $site_filter == $site['siteID'] ? 'selected' : ''; ?>>
                                <?php echo htmlspecialchars($site['siteName']); ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="col-md-3">
                    <label for="district" class="form-label">District</label>
                    <select name="district" id="district" class="form-select">
                        <option value="all">All Districts</option>
                        <?php foreach ($districts as $district): ?>
                            <option value="<?php echo htmlspecialchars($district); ?>" <?php echo $district_filter == $district ? 'selected' : ''; ?>>
                                <?php echo htmlspecialchars($district); ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="col-md-3">
                    <label for="municipality" class="form-label">Local Municipality</label>
                    <select name="municipality" id="municipality" class="form-select">
                        <option value="all">All Municipalities</option>
                        <?php foreach ($municipalities as $municipality): ?>
                            <option value="<?php echo htmlspecialchars($municipality); ?>" <?php echo $municipality_filter == $municipality ? 'selected' : ''; ?>>
                                <?php echo htmlspecialchars($municipality); ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="col-md-3">
                    <label for="ward" class="form-label">Ward</label>
                    <select name="ward" id="ward" class="form-select">
                        <option value="all">All Wards</option>
                        <?php foreach ($wards as $ward): ?>
                            <option value="<?php echo htmlspecialchars($ward); ?>" <?php echo $ward_filter == $ward ? 'selected' : ''; ?>>
                                <?php echo htmlspecialchars($ward); ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="col-md-3">
                    <label for="councillor" class="form-label">Councillor</label>
                    <select name="councillor" id="councillor" class="form-select">
                        <option value="all">All Councillors</option>
                        <?php foreach ($councillors as $councillor): ?>
                            <option value="<?php echo htmlspecialchars($councillor); ?>" <?php echo $councillor_filter == $councillor ? 'selected' : ''; ?>>
                                <?php echo htmlspecialchars($councillor); ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="col-md-3">
                    <button type="button" class="btn btn-secondary" onclick="clearFilters()" style="margin-top: 32px;">
                        <i class="mdi mdi-filter-remove me-1"></i>Clear Filters
                    </button>
                </div>
            </form>
        </div>

        <!-- Bulk Assignment Section -->
        <div class="filter-card">
            <h5 class="mb-3"><i class="mdi mdi-account-multiple me-2"></i>Bulk Class Assignment</h5>
            <form method="POST" id="bulkAssignForm">
                <div class="row g-3 align-items-end">
                    <div class="col-md-6">
                        <label for="bulk_class_id" class="form-label">Select Class for Bulk Assignment</label>
                        <select name="bulk_class_id" id="bulk_class_id" class="form-select" required>
                            <option value="">Select Class...</option>
                            <?php if ($site_filter !== 'all' && !empty($selected_site_classes)): ?>
                                <!-- Show classes from selected site filter -->
                                <?php foreach ($selected_site_classes as $class): ?>
                                    <option value="<?php echo $class['classID']; ?>">
                                        <?php echo htmlspecialchars($class['className']); ?>
                                    </option>
                                <?php endforeach; ?>
                            <?php else: ?>
                                <!-- Show all available classes when no site filter -->
                                <?php foreach ($sites as $site): ?>
                                    <?php if (isset($classes_by_site[$site['siteID']]) && !empty($classes_by_site[$site['siteID']])): ?>
                                        <optgroup label="<?php echo htmlspecialchars($site['siteName']); ?>">
                                            <?php foreach ($classes_by_site[$site['siteID']] as $class): ?>
                                                <option value="<?php echo $class['classID']; ?>">
                                                    <?php echo htmlspecialchars($class['className']); ?>
                                                </option>
                                            <?php endforeach; ?>
                                        </optgroup>
                                    <?php endif; ?>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </select>
                    </div>
                    <div class="col-md-3">
                        <button type="submit" name="bulk_assign" class="btn btn-success" id="bulkAssignBtn" disabled>
                            <i class="mdi mdi-account-multiple-plus me-1"></i>Assign Selected (<span id="selectedCount">0</span>)
                        </button>
                    </div>
                    <div class="col-md-3">
                        <div class="form-check">
                            <input class="form-check-input" type="checkbox" id="selectAll">
                            <label class="form-check-label" for="selectAll">
                                Select All Learners
                            </label>
                        </div>
                    </div>
                </div>
            </form>
        </div>

        <!-- Results Info -->
        <div class="d-flex justify-content-between align-items-center mb-3">
            <div>
                <span class="text-muted">
                    Showing <?php echo number_format(count($learners)); ?> of <?php echo number_format($total_records); ?> unassigned approved learners
                    (Page <?php echo $page; ?> of <?php echo $total_pages; ?>)
                </span>
            </div>
        </div>

        <!-- Approved Learners List -->
        <div class="learners-container">
            <?php if (empty($learners)): ?>
                <div class="text-center py-5">
                    <i class="mdi mdi-account-check" style="font-size: 4rem; color: #28a745;"></i>
                    <h5 class="mt-3 text-muted">No Unassigned Approved Learners Found</h5>
                    <p class="text-muted">No learners with all documents approved and no class assignment match your search criteria.</p>
                </div>
            <?php else: ?>
                <?php foreach ($learners as $learner): ?>
                    <div class="learner-card">
                        <div class="row align-items-center">
                            <div class="col-md-1">
                                <div class="form-check">
                                    <input class="form-check-input learner-checkbox" type="checkbox" name="selected_learners[]" value="<?php echo $learner['LearnerID']; ?>" id="learner_<?php echo $learner['LearnerID']; ?>">
                                    <label class="form-check-label" for="learner_<?php echo $learner['LearnerID']; ?>">
                                        <span class="visually-hidden">Select learner</span>
                                    </label>
                                </div>
                            </div>
                            <div class="col-md-7">
                                <div class="d-flex justify-content-between align-items-start mb-2">
                                    <h6 class="mb-1">
                                        <?php echo htmlspecialchars($learner['Name'] . ' ' . $learner['Surname']); ?>
                                        <span class="approved-badge">
                                            ✓ All Documents Approved (<?php echo $learner['total_docs']; ?>)
                                        </span>
                                    </h6>
                                </div>
                                
                                <div class="row mb-2">
                                    <div class="col-sm-3">
                                        <small class="text-muted">ID Number:</small><br>
                                        <span><?php echo htmlspecialchars($learner['IDNumber']); ?></span>
                                    </div>
                                    <div class="col-sm-3">
                                        <small class="text-muted">Site:</small><br>
                                        <span><?php echo htmlspecialchars($learner['siteName']); ?></span>
                                    </div>
                                    <div class="col-sm-3">
                                        <small class="text-muted">District:</small><br>
                                        <span><?php echo htmlspecialchars($learner['district_name'] ?? 'Not specified'); ?></span>
                                    </div>
                                    <div class="col-sm-3">
                                        <small class="text-muted">Municipality:</small><br>
                                        <span><?php echo htmlspecialchars($learner['local_municipality_name'] ?? 'Not specified'); ?></span>
                                    </div>
                                </div>
                                
                                <div class="row mb-2">
                                    <div class="col-sm-3">
                                        <small class="text-muted">Ward:</small><br>
                                        <span><?php echo htmlspecialchars($learner['Ward'] ?? 'Not specified'); ?></span>
                                    </div>
                                    <div class="col-sm-3">
                                        <small class="text-muted">Councillor:</small><br>
                                        <span><?php echo htmlspecialchars($learner['councillor'] ?? 'Not specified'); ?></span>
                                    </div>
                                    <div class="col-sm-3">
                                        <small class="text-muted">Current Class:</small><br>
                                        <span class="text-muted">Not assigned</span>
                                    </div>
                                    <div class="col-sm-3">
                                        <!-- Empty column for spacing -->
                                    </div>
                                </div>
                            </div>
                            
                            <div class="col-md-4">
                                <div class="class-assignment">
                                    <h6 class="mb-2"><i class="mdi mdi-school me-1"></i>Assign to Class</h6>
                                    <form method="POST" class="d-flex gap-2">
                                        <input type="hidden" name="learner_id" value="<?php echo $learner['LearnerID']; ?>">
                                        <select name="class_id" class="form-select form-select-sm" required>
                                            <option value="">Select Class...</option>
                                            <?php if ($site_filter !== 'all' && !empty($selected_site_classes)): ?>
                                                <!-- Show classes from selected site filter -->
                                                <?php foreach ($selected_site_classes as $class): ?>
                                                    <option value="<?php echo $class['classID']; ?>" <?php echo $learner['classID'] == $class['classID'] ? 'selected' : ''; ?>>
                                                        <?php echo htmlspecialchars($class['className']); ?>
                                                    </option>
                                                <?php endforeach; ?>
                                            <?php elseif ($site_filter === 'all' && isset($classes_by_site[$learner['siteID']])): ?>
                                                <!-- Show classes from learner's associated site when no site filter is selected -->
                                                <?php foreach ($classes_by_site[$learner['siteID']] as $class): ?>
                                                    <option value="<?php echo $class['classID']; ?>" <?php echo $learner['classID'] == $class['classID'] ? 'selected' : ''; ?>>
                                                        <?php echo htmlspecialchars($class['className']); ?>
                                                    </option>
                                                <?php endforeach; ?>
                                            <?php else: ?>
                                                <option disabled>
                                                    <?php echo $site_filter !== 'all' ? 'No classes available for selected site' : 'No classes available'; ?>
                                                </option>
                                            <?php endif; ?>
                                        </select>
                                        <button type="submit" name="assign_class" class="btn btn-success btn-sm">
                                            <i class="mdi mdi-check"></i>
                                        </button>
                                    </form>
                                </div>
                            </div>
                        </div>
                    </div>
                <?php endforeach; ?>
            <?php endif; ?>
        </div>

        <!-- Pagination -->
        <?php if ($total_pages > 1): ?>
            <div class="d-flex justify-content-center mt-4">
                <nav aria-label="Learners pagination">
                    <ul class="pagination">
                        <?php if ($page > 1): ?>
                            <li class="page-item">
                                <a class="page-link" href="?<?php echo http_build_query(array_merge($_GET, ['page' => $page - 1])); ?>">Previous</a>
                            </li>
                        <?php endif; ?>
                        
                        <?php 
                        $start_page = max(1, $page - 2);
                        $end_page = min($total_pages, $page + 2);
                        
                        for ($i = $start_page; $i <= $end_page; $i++): 
                        ?>
                            <li class="page-item <?php echo $i === $page ? 'active' : ''; ?>">
                                <a class="page-link" href="?<?php echo http_build_query(array_merge($_GET, ['page' => $i])); ?>"><?php echo $i; ?></a>
                            </li>
                        <?php endfor; ?>
                        
                        <?php if ($page < $total_pages): ?>
                            <li class="page-item">
                                <a class="page-link" href="?<?php echo http_build_query(array_merge($_GET, ['page' => $page + 1])); ?>">Next</a>
                            </li>
                        <?php endif; ?>
                    </ul>
                </nav>
            </div>
        <?php endif; ?>
        
          </div>
        </div>
      </div>
    </div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script>
    // Auto-submit form when filters change
    document.addEventListener('DOMContentLoaded', function() {
        const filterSelects = ['site_id', 'district', 'municipality', 'ward', 'councillor'];
        
        filterSelects.forEach(function(selectId) {
            const selectElement = document.getElementById(selectId);
            if (selectElement) {
                selectElement.addEventListener('change', function() {
                    this.form.submit();
                });
            }
        });
        
        // Auto-dismiss alerts
        setTimeout(function() {
            const alerts = document.querySelectorAll('.alert');
            alerts.forEach(function(alert) {
                const bsAlert = new bootstrap.Alert(alert);
                bsAlert.close();
            });
        }, 5000);
        
        // Bulk assignment functionality
        const selectAllCheckbox = document.getElementById('selectAll');
        const learnerCheckboxes = document.querySelectorAll('.learner-checkbox');
        const bulkAssignBtn = document.getElementById('bulkAssignBtn');
        const selectedCountSpan = document.getElementById('selectedCount');
        const bulkAssignForm = document.getElementById('bulkAssignForm');
        
        // Update selected count and button state
        function updateBulkAssignState() {
            const selectedCheckboxes = document.querySelectorAll('.learner-checkbox:checked');
            const count = selectedCheckboxes.length;
            
            selectedCountSpan.textContent = count;
            bulkAssignBtn.disabled = count === 0;
            
            // Update select all checkbox state
            if (count === 0) {
                selectAllCheckbox.indeterminate = false;
                selectAllCheckbox.checked = false;
            } else if (count === learnerCheckboxes.length) {
                selectAllCheckbox.indeterminate = false;
                selectAllCheckbox.checked = true;
            } else {
                selectAllCheckbox.indeterminate = true;
                selectAllCheckbox.checked = false;
            }
        }
        
        // Select all functionality
        selectAllCheckbox.addEventListener('change', function() {
            learnerCheckboxes.forEach(function(checkbox) {
                checkbox.checked = selectAllCheckbox.checked;
            });
            updateBulkAssignState();
        });
        
        // Individual checkbox change
        learnerCheckboxes.forEach(function(checkbox) {
            checkbox.addEventListener('change', updateBulkAssignState);
        });
        
        // Bulk assignment form submission
        bulkAssignForm.addEventListener('submit', function(e) {
            const selectedCheckboxes = document.querySelectorAll('.learner-checkbox:checked');
            const bulkClassId = document.getElementById('bulk_class_id').value;
            
            if (selectedCheckboxes.length === 0) {
                e.preventDefault();
                alert('Please select at least one learner.');
                return;
            }
            
            if (!bulkClassId) {
                e.preventDefault();
                alert('Please select a class.');
                return;
            }
            
            // Confirm bulk assignment
            const learnerNames = [];
            selectedCheckboxes.forEach(function(checkbox) {
                const learnerCard = checkbox.closest('.learner-card');
                const nameElement = learnerCard.querySelector('h6');
                if (nameElement) {
                    learnerNames.push(nameElement.textContent.split('✓')[0].trim());
                }
            });
            
            const className = document.getElementById('bulk_class_id').selectedOptions[0].text;
            const confirmMessage = `Are you sure you want to assign ${selectedCheckboxes.length} learner(s) to "${className}"?\n\nSelected learners:\n${learnerNames.slice(0, 5).join('\n')}${learnerNames.length > 5 ? '\n... and ' + (learnerNames.length - 5) + ' more' : ''}`;
            
            if (!confirm(confirmMessage)) {
                e.preventDefault();
            }
        });
        
        // Initial state update
        updateBulkAssignState();
    });
    
    // Clear filters function
    function clearFilters() {
        const url = new URL(window.location);
        url.searchParams.delete('site_id');
        url.searchParams.delete('district');
        url.searchParams.delete('municipality');
        url.searchParams.delete('ward');
        url.searchParams.delete('councillor');
        url.searchParams.delete('search');
        url.searchParams.delete('page');
        window.location.href = url.toString();
    }
</script>

</html>