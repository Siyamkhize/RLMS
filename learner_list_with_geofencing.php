<?php
// Include the database connection file
include 'facilitator_header.php'; // Adjust the path as necessary

// Start session and report
$classID = $_SESSION['classID'];

// Fetch class details
$classDetails = getClassDetails($classID, $conn);
if ($classDetails) {
    // Now you can safely access the associative array
    echo "Project ID: " . $classDetails['project_id'];
} else {
    echo "No class found for the provided Class ID.";
}

$selectedClassName = $classID;
?>

<!-- Body content starts here -->
<div class="container-fluid">
    <div class="d-flex flex-column-reverse">
        <div class="content-wrapper w-100">
            <!-- Cards Section -->
            <div class="container-fluid page-content">
                <div class="row">
                    <!-- Content Area -->
                    <div class="col-md-10 ms-auto padding-right">
                        <!-- Cards Section -->
                        <div class="page-header">
                            <h3 class="page-title">
                                <button class="btn btn-primary" onclick="goBack()">← Back</button>
                            </h3>
                        </div>

                        <!--SITE Profile Form-->
                        <div class="col-lg-12 grid-margin stretch-card">
                            <div class="card">
          